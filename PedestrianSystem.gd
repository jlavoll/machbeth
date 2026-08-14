extends Node3D
class_name PedestrianSystem

# ==============================================================================
# CYBERPUNK PEDESTRIAN CROWD SYSTEM (PedestrianSystem.gd)
# ==============================================================================
# Spawns distance-pooled neon stick/cylinder pedestrian figurines walking on
# sidewalks, crosswalks, Cyber Parks, and Parking Lots.

@export var max_pedestrians: int = 24
@export var spawn_radius: float = 80.0
@export var despawn_radius: float = 120.0
@export var walk_speed: float = 2.5

# ==============================================================================
# PEDESTRIAN STATE MACHINE ENUM
# ==============================================================================
enum PedState { IDLE, WALKING, QUEUING, EVADING, SHELTERING, STROLLING, DISTRACTED }

# Pedestrian instances pool
var active_pedestrians: Array[Node3D] = []
var active_park_dancers: Array[Node3D] = []
var active_dodgy_characters: Array[Node3D] = []
var active_gang_members: Array[Node3D] = []
var active_narrow_street_residents: Array[Node3D] = []
var active_delivery_recipients: Array[Node3D] = []

var active_concert_crowd: Array[Node3D] = []

# New Archetype Tracking Arrays
var active_street_vendors: Array[Node3D] = []
var active_fixers: Array[Node3D] = []
var active_buskers: Array[Node3D] = []
var active_tech_drones: Array[Node3D] = []
var active_joggers: Array[Node3D] = []

# Gang color themes & faction names
var gang_color_themes: Array[Color] = [
	Color(0.9, 0.1, 0.1),  # The Red Crows (Crimson Red)
	Color(0.0, 0.4, 1.0),  # The Blue Seagulls (Cobalt Blue)
	Color(1.0, 0.8, 0.0),  # The Yellow Hawks (Amber Gold)
	Color(0.2, 0.9, 0.1)   # The Toxic Vipers (Acid Green)
]

var gang_faction_names: Array[String] = [
	"RED CROWS",
	"BLUE SEAGULLS",
	"YELLOW HAWKS",
	"TOXIC VIPERS"
]

# Mesh templates
var body_mesh_template: CapsuleMesh
var head_mesh_template: SphereMesh
var crown_mesh_template: CylinderMesh

@onready var player_car = $"../PlayerCar"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Neon color palette for pedestrian emission shaders
var neon_colors: Array[Color] = [
	Color(0.0, 0.85, 1.0),  # Cyan
	Color(1.0, 0.0, 0.8),   # Hot Magenta
	Color(1.0, 0.8, 0.0),   # Amber Yellow
	Color(0.2, 1.0, 0.4)    # Emerald Green
]

# Party Dancer glowing colors (Vibrant Neon Gold, Purple, & Electric Violet)
var dancer_colors: Array[Color] = [
	Color(1.0, 0.7, 0.0),   # Radiant Gold
	Color(0.8, 0.1, 1.0),   # Cyber Violet
	Color(1.0, 0.2, 0.5),   # Neon Rose
	Color(0.0, 1.0, 0.8)    # Aqua Mint
]

# ==============================================================================
# INITIALIZATION & TEMPLATES
# ==============================================================================

func _ready() -> void:
	rng.randomize()
	_create_pedestrian_templates()
	_spawn_initial_pedestrians()
	call_deferred("_spawn_park_dance_groups")
	call_deferred("_spawn_parking_lot_gangs")
	call_deferred("_spawn_narrow_street_residents")
	call_deferred("_spawn_new_archetypes")
	call_deferred("_spawn_concert_crowd")

	# Wire quest event listener to DialogueSystem
	call_deferred("_connect_dialogue_signals")

func _connect_dialogue_signals() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if is_instance_valid(dialogue_sys):
		dialogue_sys.dialogue_choice_selected.connect(_on_dialogue_choice_selected)
		dialogue_sys.dialogue_ended.connect(_on_dialogue_ended)

var _pending_quest_delivery_complete: bool = false

func _on_dialogue_choice_selected(_choice_index: int, target_node_id: String) -> void:
	if target_node_id == "quest_accepted":
		_trigger_delivery_quest_start()
	elif target_node_id == "deliver_package":
		_pending_quest_delivery_complete = true

func _on_dialogue_ended() -> void:
	if _pending_quest_delivery_complete:
		_pending_quest_delivery_complete = false
		_trigger_delivery_quest_complete()

func _trigger_delivery_quest_start() -> void:
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	var x_cuts: Array = city_gen.active_x_streets if is_instance_valid(city_gen) and "active_x_streets" in city_gen else [-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0]
	var z_cuts: Array = city_gen.active_z_streets if is_instance_valid(city_gen) and "active_z_streets" in city_gen else [-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0]

	# Pick a random street intersection/corridor across the city grid
	var random_x: float = x_cuts[rng.randi() % x_cuts.size()]
	var random_z: float = z_cuts[rng.randi() % z_cuts.size()]

	# Shift 6m onto sidewalk slate (away from street center)
	var sidewalk_target := Vector3(random_x + 6.0, 0.0, random_z + 6.0)

	# Ensure target location is clear of water bodies
	if is_instance_valid(city_gen) and city_gen.has_method("_is_position_in_water"):
		if city_gen._is_position_in_water(sidewalk_target):
			sidewalk_target = city_gen._find_safe_land_position(sidewalk_target)

	spawn_delivery_recipient(sidewalk_target)
	
	var overmap = get_parent().get_node_or_null("TacticalOvermapManager")
	if is_instance_valid(overmap):
		overmap.delivery_target_pos = sidewalk_target
		overmap.has_active_delivery = true
	print("[QUEST] Delivery Quest Started! Delivery recipient spawned dynamically on sidewalk at: ", sidewalk_target)

func _trigger_delivery_quest_complete() -> void:
	var overmap = get_parent().get_node_or_null("TacticalOvermapManager")
	if is_instance_valid(overmap):
		overmap.has_active_delivery = false
		
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	
	for rec in active_delivery_recipients:
		if is_instance_valid(rec):
			# Set linger timer: wait 2.5 seconds AFTER dialogue closes before driving off
			rec.set_meta("linger_timer", 2.5)
			rec.set_meta("is_preparing_exit", true)
			
			# Dynamically calculate custom multi-segment exit route from recipient's random position
			var waypoints: Array[Vector3] = []
			var current_p: Vector3 = rec.global_position

			var x_cuts: Array = city_gen.active_x_streets if is_instance_valid(city_gen) and "active_x_streets" in city_gen else [-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0]
			var z_cuts: Array = city_gen.active_z_streets if is_instance_valid(city_gen) and "active_z_streets" in city_gen else [-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0]

			# Step A: Find nearest street corridor to step out off sidewalk onto road
			var nearest_x: float = x_cuts[0]
			var min_dx: float = 999.0
			for xc in x_cuts:
				var dx: float = abs(current_p.x - xc)
				if dx < min_dx:
					min_dx = dx
					nearest_x = xc

			var nearest_z: float = z_cuts[0]
			var min_dz: float = 999.0
			for zc in z_cuts:
				var dz: float = abs(current_p.z - zc)
				if dz < min_dz:
					min_dz = dz
					nearest_z = zc

			# Determine nearest city edge boundary (North, South, East, West) to exit cleanly
			var exit_target := Vector3.ZERO
			var dist_east: float = abs(285.0 - current_p.x)
			var dist_west: float = abs(-285.0 - current_p.x)
			var dist_north: float = abs(-285.0 - current_p.z)
			var dist_south: float = abs(285.0 - current_p.z)
			var min_edge_dist: float = minf(minf(dist_east, dist_west), minf(dist_north, dist_south))

			# Waypoint 1: Move from sidewalk to street center line
			waypoints.append(Vector3(nearest_x, 0.0, current_p.z))

			# Waypoint 2 & 3: Navigate along grid corridor to nearest city exit boundary
			if min_edge_dist == dist_east:
				waypoints.append(Vector3(nearest_x, 0.0, nearest_z))
				waypoints.append(Vector3(285.0, 0.0, nearest_z))
			elif min_edge_dist == dist_west:
				waypoints.append(Vector3(nearest_x, 0.0, nearest_z))
				waypoints.append(Vector3(-285.0, 0.0, nearest_z))
			elif min_edge_dist == dist_north:
				waypoints.append(Vector3(nearest_x, 0.0, nearest_z))
				waypoints.append(Vector3(nearest_x, 0.0, -285.0))
			else:
				waypoints.append(Vector3(nearest_x, 0.0, nearest_z))
				waypoints.append(Vector3(nearest_x, 0.0, 285.0))

			# Water check: verify no waypoint step lands in water, detour if needed
			if is_instance_valid(city_gen) and city_gen.has_method("_is_position_in_water"):
				for i in range(waypoints.size()):
					if city_gen._is_position_in_water(waypoints[i]):
						waypoints[i] = city_gen._find_safe_land_position(waypoints[i])

			rec.set_meta("exit_waypoints", waypoints)
			rec.set_meta("current_waypoint_index", 0)

			# Mount guy onto the motorcycle mesh visually
			var bike = rec.get_node_or_null("ParkedMotorcycle")
			if bike:
				bike.position = Vector3.ZERO # Align motorcycle directly beneath character

	# Trigger Lady M incoming neural text confirmation!
	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("trigger_mission_complete_text"):
		neural_comms.trigger_mission_complete_text()

	print("[QUEST] Delivery Quest Completed! Recipient will linger for 2.5s and ride custom exit route...")

func _create_pedestrian_templates() -> void:
	# Slim Cylinder/Capsule Body (0.3m diameter, 1.2m tall)
	body_mesh_template = CapsuleMesh.new()
	body_mesh_template.radius = 0.15
	body_mesh_template.height = 1.2

	# Glowing Head Sphere (0.3m diameter)
	head_mesh_template = SphereMesh.new()
	head_mesh_template.radius = 0.18
	head_mesh_template.height = 0.36

	# Glowing Halo/Crown mesh for dancers
	crown_mesh_template = CylinderMesh.new()
	crown_mesh_template.top_radius = 0.22
	crown_mesh_template.bottom_radius = 0.22
	crown_mesh_template.height = 0.04

# ==============================================================================
# SPAWNING & POOLING LOOP
# ==============================================================================

func _spawn_initial_pedestrians() -> void:
	for i in range(max_pedestrians):
		_spawn_pedestrian(true) # Initial citywide population distribution

func _spawn_pedestrian(is_initial_citywide_spawn: bool = false) -> void:
	if not is_instance_valid(player_car):
		return

	var ped_node = CharacterBody3D.new()
	ped_node.name = "NeonPedestrian"

	var neon_color: Color = neon_colors[rng.randi() % neon_colors.size()]

	# Material: Dark body with vibrant neon emission head & trim
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.05, 0.05, 0.08)

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = neon_color
	head_mat.emission_enabled = true
	head_mat.emission = neon_color
	head_mat.emission_energy_multiplier = 3.5

	# Body Mesh Instance
	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh_template
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0.0, 0.6, 0.0)
	ped_node.add_child(body_inst)

	# Head Mesh Instance
	var head_inst = MeshInstance3D.new()
	head_inst.mesh = head_mesh_template
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 1.35, 0.0)
	ped_node.add_child(head_inst)

	# Collision Capsule
	var col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.2
	cap_shape.height = 1.5
	col_shape.shape = cap_shape
	col_shape.position = Vector3(0.0, 0.75, 0.0)
	ped_node.add_child(col_shape)

	# Flashlight Handheld Prop & Beam
	var flashlight_node = Node3D.new()
	flashlight_node.name = "Flashlight"
	flashlight_node.position = Vector3(0.18, 0.65, 0.15) # Held in right hand extending forward
	ped_node.add_child(flashlight_node)

	var torch_mesh_inst = MeshInstance3D.new()
	var torch_mesh = CylinderMesh.new()
	torch_mesh.top_radius = 0.04
	torch_mesh.bottom_radius = 0.03
	torch_mesh.height = 0.22
	torch_mesh_inst.mesh = torch_mesh
	torch_mesh_inst.rotation_degrees = Vector3(90, 0, 0)
	var torch_mat = StandardMaterial3D.new()
	torch_mat.albedo_color = Color(0.2, 0.2, 0.25)
	torch_mat.metallic = 0.8
	torch_mesh_inst.material_override = torch_mat
	flashlight_node.add_child(torch_mesh_inst)

	var torch_light = SpotLight3D.new()
	torch_light.name = "FlashlightSpot"
	torch_light.position = Vector3(0.0, 0.0, 0.12)
	torch_light.light_color = neon_color
	torch_light.light_energy = 0.0 # Default off
	torch_light.light_volumetric_fog_energy = 1.2
	torch_light.spot_range = 14.0
	torch_light.spot_angle = 32.0
	torch_light.spot_attenuation = 0.8
	flashlight_node.add_child(torch_light)

	# Position across entire city grid on initial spawn, or around player during gameplay loop
	var spawn_pos: Vector3 = Vector3.ZERO
	var valid_spawn: bool = false
	var attempts: int = 0
	var city_gen = $"../CityGenerator"

	while not valid_spawn and attempts < 15:
		attempts += 1
		if is_initial_citywide_spawn:
			# Distribute across full 440m x 440m city blocks, sidewalks, and parks
			spawn_pos = Vector3(rng.randf_range(-220.0, 220.0), 0.0, rng.randf_range(-220.0, 220.0))
		else:
			var angle: float = rng.randf_range(0, TAU)
			var test_dist: float = rng.randf_range(spawn_radius * 0.5, spawn_radius)
			spawn_pos = _get_player_world_position() + Vector3(cos(angle) * test_dist, 0.0, sin(angle) * test_dist)

		# Direct geometric AABB check against active river boxes
		if is_instance_valid(city_gen) and city_gen.has_method("_is_position_in_water"):
			if not city_gen._is_position_in_water(spawn_pos):
				valid_spawn = true
		else:
			valid_spawn = true

	ped_node.position = spawn_pos

	# Assign target destination objective (e.g. cross street to a specific building/park/lot center)
	var target_destination: Vector3 = _pick_new_pedestrian_target_objective(spawn_pos)
	var walk_dir: Vector3 = (target_destination - spawn_pos).normalized()
	if walk_dir.length() < 0.1:
		walk_dir = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()

	ped_node.set_meta("target_destination", target_destination)
	ped_node.set_meta("walk_direction", walk_dir)
	
	# Explicit State Machine Initialization (PedState.WALKING or PedState.DISTRACTED)
	var is_distracted: bool = (rng.randf() < 0.18) # 18% chance for phone/holo-deck distraction
	var initial_state: PedState = PedState.DISTRACTED if is_distracted else PedState.WALKING
	ped_node.set_meta("state", initial_state)

	# Personality Roll: 75% Rule-Abiding Citizens (Walk on Sidewalks), 25% Anarchistic Street Roamers
	var is_rule_abiding: bool = (rng.randf() > 0.25)
	ped_node.set_meta("is_rule_abiding", is_rule_abiding)
	ped_node.set_meta("flashlight_on", false)
	ped_node.set_meta("flashlight_delay_timer", 0.0)
	ped_node.set_meta("flashlight_reaction_lag", rng.randf_range(0.3, 3.2))

	# Holo-Phone Prop for Distracted Pedestrians
	if is_distracted:
		var phone_inst = MeshInstance3D.new()
		var phone_box = BoxMesh.new()
		phone_box.size = Vector3(0.08, 0.015, 0.14)
		phone_inst.mesh = phone_box
		phone_inst.position = Vector3(0.0, 1.0, 0.22)
		var phone_mat = StandardMaterial3D.new()
		phone_mat.albedo_color = neon_color
		phone_mat.emission_enabled = true
		phone_mat.emission = neon_color
		phone_mat.emission_energy_multiplier = 6.0
		phone_inst.material_override = phone_mat
		ped_node.add_child(phone_inst)

	add_child(ped_node)
	active_pedestrians.append(ped_node)

# Helper selecting a target destination objective (Cyber Park, Parking Lot, or Sidewalk Block)
func _pick_new_pedestrian_target_objective(start_pos: Vector3) -> Vector3:
	var city_gen = $"../CityGenerator"
	if is_instance_valid(city_gen) and city_gen.get("active_x_streets") != null and city_gen.active_x_streets.size() > 1:
		# Pick a target point along sidewalk edges (nearest street cut + 8.5m sidewalk offset)
		var x_cuts: Array = city_gen.active_x_streets
		var z_cuts: Array = city_gen.active_z_streets
		var target_x: float = x_cuts[rng.randi() % x_cuts.size()] + (8.5 if rng.randf() > 0.5 else -8.5)
		var target_z: float = z_cuts[rng.randi() % z_cuts.size()] + (8.5 if rng.randf() > 0.5 else -8.5)
		return Vector3(target_x, 0.0, target_z)

	var angle: float = rng.randf_range(0, TAU)
	var dist: float = rng.randf_range(30.0, 70.0)
	return start_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

# ==============================================================================
# PROCESS LOOP & WALKING BOBBING MOTION
# ==============================================================================

## Returns the current world position of the player — car or on-foot figure
func _get_player_world_position() -> Vector3:
	if is_instance_valid(player_car) and player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		return player_car.on_foot_node.global_position
	return player_car.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(player_car):
		return

	# Track actual player position — car position when driving, on-foot node when walking
	var player_pos: Vector3 = _get_player_world_position()

	for i in range(active_pedestrians.size() - 1, -1, -1):
		var ped = active_pedestrians[i]
		if not is_instance_valid(ped):
			active_pedestrians.remove_at(i)
			continue

		var ped_pos: Vector3 = ped.global_position
		var distance_to_player: float = ped_pos.distance_to(player_pos)
		var is_out_of_bounds: bool = abs(ped_pos.x) > 250.0 or abs(ped_pos.z) > 250.0

		if distance_to_player > despawn_radius or is_out_of_bounds:
			ped.queue_free()
			active_pedestrians.remove_at(i)
			_spawn_pedestrian()
		else:
			var walk_dir: Vector3 = ped.get_meta("walk_direction", Vector3.FORWARD)
			var current_ped_speed: float = walk_speed

			# --------------------------------------------------------------------------
			# 0. WEATHER SHELTER SEEKING (RAIN LOGIC)
			# --------------------------------------------------------------------------
			var weather_system = $"../WeatherSystem"
			var is_raining: bool = false
			if is_instance_valid(weather_system):
				var w_type = weather_system.current_weather
				is_raining = (w_type == weather_system.WeatherType.NEON_RAIN or w_type == weather_system.WeatherType.GLITCH_STORM)

			var space_state = get_world_3d().direct_space_state
			var nearest_building_pos: Vector3 = Vector3.ZERO
			var is_near_shelter: bool = false

			# Raycast in 8 compass directions to detect nearest building shelter wall
			var city_gen = $"../CityGenerator"
			for check_angle in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
				var rad: float = deg_to_rad(check_angle)
				var ray_dir: Vector3 = Vector3(cos(rad), 0.0, sin(rad))
				var query = PhysicsRayQueryParameters3D.create(ped_pos + Vector3(0.0, 1.0, 0.0), ped_pos + Vector3(0.0, 1.0, 0.0) + ray_dir * 20.0)
				var result = space_state.intersect_ray(query)
				if result and result.has("collider") and result["collider"] is StaticBody3D:
					var collider = result["collider"]
					var hit_pos: Vector3 = result["position"]
					hit_pos.y = ped_pos.y

					# Filter out Parking Lots, Parks, CyberRivers, Trees, and Food Trucks
					var is_park_or_lot: bool = false
					if "ParkingLot" in collider.name or "Park" in collider.name or "River" in collider.name or "Tree" in collider.name or "FoodTruck" in collider.name:
						is_park_or_lot = true
					elif is_instance_valid(city_gen):
						# Geometric check against active park & parking lot bounding boxes
						if city_gen.get("active_park_boxes") != null:
							for p_box in city_gen.active_park_boxes:
								if p_box.has_point(Vector2(hit_pos.x, hit_pos.z)):
									is_park_or_lot = true
									break
						if not is_park_or_lot and city_gen.get("active_lot_boxes") != null:
							for l_box in city_gen.active_lot_boxes:
								if l_box.has_point(Vector2(hit_pos.x, hit_pos.z)):
									is_park_or_lot = true
									break

					if not is_park_or_lot:
						if nearest_building_pos == Vector3.ZERO or ped_pos.distance_to(hit_pos) < ped_pos.distance_to(nearest_building_pos):
							nearest_building_pos = hit_pos
						if ped_pos.distance_to(hit_pos) < 2.5:
							is_near_shelter = true

			var is_sheltered: bool = false
			if is_raining:
				if is_near_shelter:
					is_sheltered = true
				elif nearest_building_pos != Vector3.ZERO:
					# Run fast sprint (3.0x speed) towards building shelter!
					walk_dir = (nearest_building_pos - ped_pos).normalized()
					current_ped_speed = walk_speed * 3.0
					ped.set_meta("walk_direction", walk_dir)

			# --------------------------------------------------------------------------
			# 1. TARGET OBJECTIVE PROGRESS (WALKING TOWARD DESTINATION)
			# --------------------------------------------------------------------------
			if not is_raining:
				var target_dest: Vector3 = ped.get_meta("target_destination", ped_pos + walk_dir * 10.0)
				if ped_pos.distance_to(target_dest) < 3.0:
					target_dest = _pick_new_pedestrian_target_objective(ped_pos)
					ped.set_meta("target_destination", target_dest)
					walk_dir = (target_dest - ped_pos).normalized()
					ped.set_meta("walk_direction", walk_dir)
					ped.set_meta("street_exposure_timer", 0.0) # Reset street exposure timer on new objective

			# --------------------------------------------------------------------------
			# 2. MID-STREET SELF-AWARENESS & SIDEWALK LATCHING FOR RULE-ABIDING CITIZENS
			# --------------------------------------------------------------------------
			var is_rule_abiding: bool = ped.get_meta("is_rule_abiding", true)
			var is_near_building: bool = nearest_building_pos != Vector3.ZERO and ped_pos.distance_to(nearest_building_pos) < 7.0

			if not is_raining and not is_near_building and is_rule_abiding:
				# Rule-Abiding Citizen exposed in the middle of a street!
				var exposure_timer: float = ped.get_meta("street_exposure_timer", 0.0) + delta
				var awareness_delay: float = ped.get_meta("street_awareness_delay", 3.0)
				ped.set_meta("street_exposure_timer", exposure_timer)

				# If lingering in mid-street past reaction delay grace period, hurry to nearest sidewalk building!
				if exposure_timer > awareness_delay:
					current_ped_speed = walk_speed * 1.6 # Hurry up to sidewalk
			else:
				# Safe near building sidewalk or Anarchistic Roamer! Reset exposure timer
				ped.set_meta("street_exposure_timer", 0.0)

			# --------------------------------------------------------------------------
			# 3. RULE: RUN OUT OF THE WAY IF ANY CAR (PLAYER OR TRAFFIC) APPROACHES (< 18m)
			# --------------------------------------------------------------------------
			var threatening_car_forward: Vector3 = Vector3.ZERO
			var threatening_car_pos: Vector3 = Vector3.ZERO
			var is_threatened: bool = false

			# Check PlayerCar threat
			var player_forward_dir: Vector3 = -player_car.global_transform.basis.z.normalized()
			var vec_from_player: Vector3 = (ped_pos - player_pos).normalized()
			var player_speed: float = player_car.current_speed if "current_speed" in player_car else player_car.velocity.length()

			if distance_to_player < 18.0 and player_forward_dir.dot(vec_from_player) > 0.75 and player_speed > 3.0:
				threatening_car_forward = player_forward_dir
				threatening_car_pos = player_pos
				is_threatened = true
			else:
				# Check ambient traffic cars threat
				var traffic_system = $"../TrafficSystem"
				if is_instance_valid(traffic_system) and traffic_system.get("active_traffic_cars") != null:
					for traffic_car in traffic_system.active_traffic_cars:
						if is_instance_valid(traffic_car):
							var t_pos: Vector3 = traffic_car.global_position
							var t_dist: float = ped_pos.distance_to(t_pos)
							if t_dist < 18.0:
								var t_forward: Vector3 = traffic_car.get_meta("drive_direction", Vector3.FORWARD)
								var vec_from_t: Vector3 = (ped_pos - t_pos).normalized()
								if t_forward.dot(vec_from_t) > 0.75:
									threatening_car_forward = t_forward
									threatening_car_pos = t_pos
									is_threatened = true
									break

			if is_threatened:
				var sidestep_dir: Vector3 = threatening_car_forward.cross(Vector3.UP).normalized()
				var vec_to_ped: Vector3 = (ped_pos - threatening_car_pos).normalized()
				if vec_to_ped.dot(sidestep_dir) < 0.0:
					sidestep_dir = -sidestep_dir
				walk_dir = sidestep_dir
				current_ped_speed = walk_speed * 3.2 # Triple speed sprint dodge!
				ped.set_meta("walk_direction", walk_dir)
				is_sheltered = false
			
			# Turn pedestrian around if approaching city grid perimeter boundary (+/-240m)
			if abs(ped_pos.x) > 240.0:
				walk_dir.x = -sign(ped_pos.x)
				ped.set_meta("walk_direction", walk_dir.normalized())
			if abs(ped_pos.z) > 240.0:
				walk_dir.z = -sign(ped_pos.z)
				ped.set_meta("walk_direction", walk_dir.normalized())

			if is_sheltered:
				ped.velocity = Vector3.ZERO
			else:
				ped.velocity = walk_dir * current_ped_speed
			
			# Move pedestrian and check for collisions
			var collided: bool = ped.move_and_slide()
			
			# Rule: Pedestrians cannot walk in water! Turn around if hitting a CyberRiver water barrier or wall
			if collided:
				for collision_idx in range(ped.get_slide_collision_count()):
					var collision = ped.get_slide_collision(collision_idx)
					var collider = collision.get_collider()
					if is_instance_valid(collider) and ("CyberRiver" in collider.name or collider is StaticBody3D):
						# Bounce / reverse walking direction away from water
						var new_dir: Vector3 = (walk_dir.bounce(collision.get_normal()) + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))).normalized()
						ped.set_meta("walk_direction", new_dir)
						break

			# Face movement direction if moving
			if ped.velocity.length_squared() > 0.1:
				var look_target: Vector3 = ped_pos + Vector3(ped.velocity.x, 0.0, ped.velocity.z)
				ped.look_at(look_target, Vector3.UP)

			# --------------------------------------------------------------------------
			# FLASHLIGHT ACTIVATION (TWO DARKEST 'L' STAGES: DARK_BUILDINGS = 3, PITCH_BLACK = 4)
			# Staggered asynchronous turning on/off matching car headlights
			# --------------------------------------------------------------------------
			var city_vfx = $"../CityVisualEffects"
			var is_darkest_stages: bool = false
			if is_instance_valid(city_vfx) and city_vfx.get("current_city_light_stage") != null:
				# Stage 3: DARK_BUILDINGS, Stage 4: PITCH_BLACK
				is_darkest_stages = (int(city_vfx.current_city_light_stage) >= 3)

			var flashlight_spot: SpotLight3D = ped.get_node_or_null("Flashlight/FlashlightSpot") as SpotLight3D
			if is_instance_valid(flashlight_spot):
				var flashlight_on: bool  = ped.get_meta("flashlight_on",          false)
				var delay_timer: float  = ped.get_meta("flashlight_delay_timer",  0.0)
				var reaction_lag: float = ped.get_meta("flashlight_reaction_lag", 1.0)

				if is_darkest_stages != flashlight_on:
					delay_timer += delta
					ped.set_meta("flashlight_delay_timer", delay_timer)
					if delay_timer >= reaction_lag:
						ped.set_meta("flashlight_on",          is_darkest_stages)
						ped.set_meta("flashlight_delay_timer", 0.0)
				else:
					ped.set_meta("flashlight_delay_timer", 0.0)

				var current_on: bool = ped.get_meta("flashlight_on", false)
				var target_energy: float = 6.5 if current_on else 0.0
				flashlight_spot.light_energy = move_toward(flashlight_spot.light_energy, target_energy, delta * 15.0)

			# --------------------------------------------------------------------------
			# ANIMATION: NORMAL WALKING BOB VS IMPATIENT AGITATED SHELTER BOPPING VS FOOD TRUCK ORDERING
			# --------------------------------------------------------------------------
			var is_in_food_queue: bool = ped.has_meta("food_truck_queue_target")
			var queue_slot: int = ped.get_meta("queue_slot_index", -1)

			var phase: float = ped.get_meta("anim_phase", 0.0)
			if is_in_food_queue and queue_slot == 0 and not is_raining:
				# Customer #1 at counter window: gentle friendly bopping (chatting & ordering food)
				phase += delta * 7.0
				ped.set_meta("anim_phase", phase)
				ped.position.y = abs(sin(phase)) * 0.05 + (sin(phase * 0.5) * 0.015)
				# Order timer countdown: 4 to 7 seconds at counter window
				var order_timer: float = ped.get_meta("food_order_timer", 5.0) - delta
				ped.set_meta("food_order_timer", order_timer)
				if order_timer <= 0.0:
					# Received food! Depart queue and become a regular roaming pedestrian
					ped.remove_meta("food_truck_queue_target")
					ped.remove_meta("queue_slot_index")
					ped.remove_meta("queue_personality")
					ped.set_meta("food_cooldown_timer", 90.0) # 90-second cooldown before wanting food again
					var new_dest: Vector3 = _pick_new_pedestrian_target_objective(ped_pos)
					ped.set_meta("target_destination", new_dest)
					ped.set_meta("walk_direction", (new_dest - ped_pos).normalized())
			elif is_in_food_queue and queue_slot > 0:
				# Waiting in line — behaviour driven by personality stamped at queue-join time
				var personality: String = ped.get_meta("queue_personality", "bouncy")
				if personality == "bouncy":
					# Agitated, impatient bouncer: fast jittery hop
					phase += delta * 14.0
					ped.set_meta("anim_phase", phase)
					ped.position.y = abs(sin(phase)) * 0.1 + sin(phase * 0.4) * 0.025
				else:
					# Chill personality: slow lazy sway, barely moves
					phase += delta * 1.8
					ped.set_meta("anim_phase", phase)
					ped.position.y = abs(sin(phase)) * 0.018 + sin(phase * 0.3) * 0.008
			elif is_sheltered:
				# Fast, impatient jittery/agitated bopping while waiting under building shelter
				phase += delta * 16.0
				ped.set_meta("anim_phase", phase)
				ped.position.y = abs(sin(phase)) * 0.12 + (sin(phase * 0.5) * 0.03)
			else:
				# Standard walking oscillation
				phase += delta * (8.0 if ped.velocity.length() <= walk_speed else 14.0)
				ped.set_meta("anim_phase", phase)
				ped.position.y = abs(sin(phase)) * 0.1

	_update_concert_crowd(delta)
	_manage_food_truck_queues(delta)

# Manages 3-10 customer line queues outside active city food trucks
func _manage_food_truck_queues(delta: float) -> void:
	var city_gen = $"../CityGenerator"
	if not is_instance_valid(city_gen) or city_gen.get("active_food_trucks") == null:
		return

	for truck in city_gen.active_food_trucks:
		if not is_instance_valid(truck):
			continue

		var truck_pos: Vector3 = truck.global_position
		# Counter window position extends off the right side of truck (Vector3(1.6, 0.0, 0.0) relative)
		var counter_pos: Vector3 = truck.global_transform * Vector3(1.6, 0.0, 0.0)
		counter_pos.y = 0.0
		var queue_dir: Vector3 = truck.global_transform.basis.x.normalized() # Line forms outward perpendicular to counter window

		# Gather existing pedestrians currently in line for this truck
		var queued_peds: Array[CharacterBody3D] = []
		for ped in active_pedestrians:
			if is_instance_valid(ped) and ped.has_meta("food_truck_queue_target") and ped.get_meta("food_truck_queue_target") == truck:
				queued_peds.append(ped)

		# Sort line by slot index or distance to counter window
		queued_peds.sort_custom(func(a, b):
			return a.get_meta("queue_slot_index", 99) < b.get_meta("queue_slot_index", 99)
		)

		# Assign updated slot positions and guide queue step-forwards
		for idx in range(queued_peds.size()):
			var q_ped = queued_peds[idx]
			q_ped.set_meta("queue_slot_index", idx)
			var slot_pos: Vector3 = counter_pos + queue_dir * (float(idx) * 1.1)
			q_ped.set_meta("target_destination", slot_pos)
			
			if q_ped.global_position.distance_to(slot_pos) > 0.5:
				var move_dir: Vector3 = (slot_pos - q_ped.global_position).normalized()
				q_ped.set_meta("walk_direction", move_dir)
				q_ped.velocity = move_dir * walk_speed
			else:
				q_ped.velocity = Vector3.ZERO
				q_ped.look_at(counter_pos if idx == 0 else counter_pos + queue_dir * (float(idx - 1) * 1.1), Vector3.UP)

		# Auto-Refill Line: Maintain between 3 and 8 waiting customers in line at each food truck!
		var target_line_size: int = truck.get_meta("target_line_size", 0)
		if target_line_size == 0:
			target_line_size = rng.randi_range(3, 8)
			truck.set_meta("target_line_size", target_line_size)

		if queued_peds.size() < target_line_size:
			# Find nearest unassigned wandering pedestrian within 45m (who is not on food cooldown)
			var candidate_ped: CharacterBody3D = null
			var closest_dist: float = 999.0
			for ped in active_pedestrians:
				if is_instance_valid(ped) and not ped.has_meta("food_truck_queue_target"):
					var cooldown: float = ped.get_meta("food_cooldown_timer", 0.0)
					if cooldown > 0.0:
						cooldown -= delta
						ped.set_meta("food_cooldown_timer", cooldown)
						continue # Skip pedestrians on food cooldown!

					var d: float = ped.global_position.distance_to(counter_pos)
					if d < 45.0 and d < closest_dist:
						closest_dist = d
						candidate_ped = ped

			if candidate_ped != null:
				candidate_ped.set_meta("food_truck_queue_target", truck)
				candidate_ped.set_meta("queue_slot_index", queued_peds.size())
				candidate_ped.set_meta("food_order_timer", rng.randf_range(4.0, 7.0))
				# Stamp personality: 70% bouncy/agitated, 30% chill/relaxed
				var personality: String = "bouncy" if rng.randf() < 0.7 else "chill"
				candidate_ped.set_meta("queue_personality", personality)

	_update_park_dancers(delta)
	_update_parking_lot_gangs(delta)
	_update_narrow_street_residents(delta)
	_update_delivery_recipients(delta)
	_update_archetype_behaviors(delta)

func _update_delivery_recipients(delta: float) -> void:
	var to_remove: Array[Node3D] = []
	for rec in active_delivery_recipients:
		if not is_instance_valid(rec):
			continue

		# Handle 2.5 second linger delay AFTER closing dialogue before driving off
		if rec.get_meta("is_preparing_exit", false):
			var timer: float = rec.get_meta("linger_timer", 2.5)
			timer -= delta
			rec.set_meta("linger_timer", timer)
			if timer <= 0.0:
				rec.set_meta("is_preparing_exit", false)
				rec.set_meta("is_driving_away", true)
			continue

		if rec.get_meta("is_driving_away", false):
			var waypoints: Array = rec.get_meta("exit_waypoints", [])
			var wp_index: int = rec.get_meta("current_waypoint_index", 0)

			if waypoints.is_empty():
				# Fallback direct destination
				var exit_pos: Vector3 = Vector3(285.0, 0.0, rec.global_position.z)
				waypoints = [exit_pos]
				rec.set_meta("exit_waypoints", waypoints)

			if wp_index < waypoints.size():
				var target_wp: Vector3 = waypoints[wp_index]
				var drive_dir: Vector3 = (target_wp - rec.global_position).normalized()
				drive_dir.y = 0.0
				
				# Drive away at motorcycle speed (16 m/s)
				var drive_speed: float = 16.0
				
				# Raycast obstacle check to steer around building corners if needed
				var space_state = rec.get_world_3d().direct_space_state
				var ray_query = PhysicsRayQueryParameters3D.create(rec.global_position + Vector3(0, 0.5, 0), rec.global_position + Vector3(0, 0.5, 0) + drive_dir * 4.0)
				ray_query.exclude = [rec.get_rid()]
				var ray_result = space_state.intersect_ray(ray_query)
				if not ray_result.is_empty():
					# Obstacle detected ahead: deflect steering 45 degrees sideways to skirt building edge
					var normal = ray_result.normal
					drive_dir = (drive_dir + Vector3(normal.z, 0.0, -normal.x)).normalized()

				rec.velocity = drive_dir * drive_speed
				rec.move_and_slide()

				# Smoothly align orientation towards active waypoint direction
				if drive_dir.length_squared() > 0.01:
					var look_target: Vector3 = rec.global_position + drive_dir
					rec.look_at(look_target, Vector3.UP)

				# Wheel spinning animation
				var bike = rec.get_node_or_null("ParkedMotorcycle")
				if bike:
					for child in bike.get_children():
						if child is MeshInstance3D and child.mesh is CylinderMesh:
							child.rotate_x(delta * 25.0)

				# Advance to next waypoint upon reaching current target
				if rec.global_position.distance_to(target_wp) < 5.0:
					wp_index += 1
					rec.set_meta("current_waypoint_index", wp_index)

			# Despawn cleanly once final waypoint is reached or past city boundary
			if wp_index >= waypoints.size() or abs(rec.global_position.x) > 275.0 or abs(rec.global_position.z) > 275.0:
				to_remove.append(rec)
				rec.queue_free()

	for rem in to_remove:
		active_delivery_recipients.erase(rem)

# ==============================================================================
# UNIQUE PARK DANCE GROUPS (Circle / Line / Partner Couples)
# ==============================================================================

func _spawn_park_dance_groups() -> void:
	var city_gen = $"../CityGenerator"
	if not is_instance_valid(city_gen) or city_gen.get("active_park_boxes") == null:
		return

	var park_boxes: Array[Rect2] = city_gen.active_park_boxes
	if park_boxes.is_empty():
		return

	# Clear existing dancers and dodgy characters if any
	for dancer in active_park_dancers:
		if is_instance_valid(dancer):
			dancer.queue_free()
	active_park_dancers.clear()

	for dodgy in active_dodgy_characters:
		if is_instance_valid(dodgy):
			dodgy.queue_free()
	active_dodgy_characters.clear()

	# Target Park 1 (MONUMENT Park) for a randomized park dance group (Hare Krishna Circle, Partner Couples, or Line Dancers)!
	var monument_park_rect: Rect2 = park_boxes[0]
	var center_2d: Vector2 = monument_park_rect.get_center()
	var center_pos: Vector3 = Vector3(center_2d.x, 0.0, center_2d.y)

	var dance_styles: Array[String] = ["CIRCLE", "PARTNERS", "LINE"]
	var selected_style: String = dance_styles[rng.randi() % dance_styles.size()]

	match selected_style:
		"CIRCLE":
			_spawn_circle_dance_group(center_pos, 8) # Hare Krishna dance circle!
		"PARTNERS":
			_spawn_partner_dance_group(center_pos, 3) # 3 couples (6 dancers)!
		"LINE":
			_spawn_line_dance_group(center_pos, 6) # Rhythmic line dancers!

	_spawn_dodgy_park_character(monument_park_rect)

func _create_single_dancer(pos: Vector3, neon_color: Color, dance_style: String, group_center: Vector3, index: int, total_count: int) -> CharacterBody3D:
	var ped_node = CharacterBody3D.new()
	ped_node.name = "ParkDancer"

	# Distinct glowing material with holographic halo/crown
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.08, 0.08, 0.12)

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = neon_color
	head_mat.emission_enabled = true
	head_mat.emission = neon_color
	head_mat.emission_energy_multiplier = 4.5

	# Body Mesh Instance
	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh_template
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0.0, 0.6, 0.0)
	ped_node.add_child(body_inst)

	# Head Mesh Instance
	var head_inst = MeshInstance3D.new()
	head_inst.mesh = head_mesh_template
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 1.35, 0.0)
	ped_node.add_child(head_inst)

	# Unique Party Halo/Crown above head
	var crown_inst = MeshInstance3D.new()
	crown_inst.mesh = crown_mesh_template
	crown_inst.material_override = head_mat
	crown_inst.position = Vector3(0.0, 1.62, 0.0)
	ped_node.add_child(crown_inst)

	# Collision Capsule so dancer can dodge / detect physical collisions
	var col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.25
	cap_shape.height = 1.5
	col_shape.shape = cap_shape
	col_shape.position = Vector3(0.0, 0.75, 0.0)
	ped_node.add_child(col_shape)

	# Metadata for dance math & panic state
	ped_node.set_meta("is_park_dancer", true)
	ped_node.set_meta("dance_style", dance_style)
	ped_node.set_meta("group_center", group_center)
	ped_node.set_meta("dancer_index", index)
	ped_node.set_meta("total_dancers", total_count)
	ped_node.set_meta("dance_phase", rng.randf_range(0.0, TAU))

	add_child(ped_node)
	ped_node.global_position = pos
	active_park_dancers.append(ped_node)
	return ped_node

func _spawn_circle_dance_group(center: Vector3, count: int) -> void:
	var radius: float = 3.5
	for i in range(count):
		var angle: float = (float(i) / float(count)) * TAU
		var offset: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var color: Color = dancer_colors[i % dancer_colors.size()]
		var dancer = _create_single_dancer(center + offset, color, "CIRCLE", center, i, count)
		dancer.look_at(center, Vector3.UP)

func _spawn_partner_dance_group(center: Vector3, couple_count: int) -> void:
	var radius: float = 4.0
	var total_count: int = couple_count * 2
	for i in range(couple_count):
		var angle: float = (float(i) / float(couple_count)) * TAU
		var couple_center: Vector3 = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		
		var color1: Color = dancer_colors[(i * 2) % dancer_colors.size()]
		var color2: Color = dancer_colors[(i * 2 + 1) % dancer_colors.size()]
		
		# Partner 1 & Partner 2 facing each other
		var d1 = _create_single_dancer(couple_center + Vector3(-0.75, 0.0, 0.0), color1, "PARTNERS", couple_center, i * 2, total_count)
		var d2 = _create_single_dancer(couple_center + Vector3(0.75, 0.0, 0.0), color2, "PARTNERS", couple_center, i * 2 + 1, total_count)
		
		d1.look_at(d2.global_position, Vector3.UP)
		d2.look_at(d1.global_position, Vector3.UP)

func _spawn_line_dance_group(center: Vector3, count: int) -> void:
	var spacing: float = 1.2
	var start_x: float = -((float(count) - 1.0) * spacing) / 2.0
	for i in range(count):
		var pos: Vector3 = center + Vector3(start_x + float(i) * spacing, 0.0, 0.0)
		var color: Color = dancer_colors[i % dancer_colors.size()]
		var dancer = _create_single_dancer(pos, color, "LINE", center, i, count)
		dancer.rotation_degrees = Vector3(0, 0, 0) # Facing forward together

func _spawn_concert_crowd() -> void:
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	var active_event_id: String = "RELIGIOUS_RALLY" # Default to RELIGIOUS_RALLY!
	if is_instance_valid(campaign_mgr) and campaign_mgr.active_daily_event.has("id"):
		active_event_id = campaign_mgr.active_daily_event.get("id", "RELIGIOUS_RALLY")

	# Spawn crowd when PARK_CONCERT or RELIGIOUS_RALLY is active today!
	if active_event_id != "PARK_CONCERT" and active_event_id != "RELIGIOUS_RALLY":
		return

	var city_gen = get_parent().get_node_or_null("CityGenerator")
	var stage_pos: Vector3 = Vector3(-80.0, 0.0, 0.0) # Default
	if is_instance_valid(city_gen):
		var actual_stage = city_gen.find_child("CyberParkConcertStage", true, false)
		if is_instance_valid(actual_stage):
			stage_pos = actual_stage.global_position
		elif city_gen.get("active_park_boxes") != null and city_gen.active_park_boxes.size() > 0:
			var p_idx: int = 1 if city_gen.active_park_boxes.size() > 1 else 0
			var park_rect: Rect2 = city_gen.active_park_boxes[p_idx]
			var park_center = Vector3(park_rect.position.x + park_rect.size.x / 2.0, 0.0, park_rect.position.y + park_rect.size.y / 2.0)
			stage_pos = park_center + Vector3(-park_rect.size.x * 0.35, 0.0, 0.0)

	# Crowd Audience Zone: In front of the concert stage facing West towards the performers!
	# Stage platform is at stage_pos + Vector3(4.0, 0, 0)
	var crowd_count: int = rng.randi_range(28, 42) # Dense hyped concert crowd!
	var crowd_colors: Array[Color] = [
		Color(1.0, 0.0, 0.8),  # Cyber Pink
		Color(0.0, 0.85, 1.0), # Neon Cyan
		Color(1.0, 0.85, 0.0), # Electric Gold
		Color(0.7, 0.1, 1.0),  # Synth Purple
		Color(0.1, 1.0, 0.4)   # Laser Green
	]

	for i in range(crowd_count):
		# Spread crowd across audience plaza (8m to 25m in front of stage edge)
		var cx: float = stage_pos.x + 6.0 + rng.randf_range(2.0, 22.0)
		var cz: float = stage_pos.z + rng.randf_range(-12.0, 12.0)
		var pos: Vector3 = Vector3(cx, 0.0, cz)

		var crowd_guy = CharacterBody3D.new()
		crowd_guy.name = "ConcertCrowdFan_%d" % i

		var g_color: Color = crowd_colors[i % crowd_colors.size()]
		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.position = Vector3(0.0, 0.6, 0.0)
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.06, 0.06, 0.09)
		body_inst.material_override = b_mat
		crowd_guy.add_child(body_inst)

		var head_inst = MeshInstance3D.new()
		head_inst.name = "HeadMesh"
		head_inst.mesh = head_mesh_template
		head_inst.position = Vector3(0.0, 1.35, 0.0)
		var h_mat = StandardMaterial3D.new()
		h_mat.albedo_color = g_color
		h_mat.emission_enabled = true
		h_mat.emission = g_color
		h_mat.emission_energy_multiplier = 3.5
		head_inst.material_override = h_mat
		crowd_guy.add_child(head_inst)

		if active_event_id == "RELIGIOUS_RALLY":
			# Glowing Holy Halo/Crown for Devout Religious Crowd!
			var halo = MeshInstance3D.new()
			halo.mesh = crown_mesh_template
			halo.position = Vector3(0.0, 1.62, 0.0)
			halo.material_override = h_mat
			crowd_guy.add_child(halo)
		else:
			# Neon Cyber-Shades / Glow Visor for Concert Goers!
			var visor = MeshInstance3D.new()
			var v_box = BoxMesh.new()
			v_box.size = Vector3(0.26, 0.08, 0.16)
			visor.mesh = v_box
			visor.position = Vector3(-0.12, 1.37, 0.0) # Facing West (-X)
			visor.material_override = h_mat
			crowd_guy.add_child(visor)

		crowd_guy.position = pos
		crowd_guy.look_at(stage_pos + Vector3(0.0, 1.2, 0.0), Vector3.UP) # Facing stage preacher / band!
		crowd_guy.set_meta("base_pos", pos)
		crowd_guy.set_meta("fan_idx", i)
		crowd_guy.set_meta("event_id", active_event_id)

		add_child(crowd_guy)
		active_concert_crowd.append(crowd_guy)

	print("[PEDESTRIANS] Spawned %d %s Fans in Cyber Park Plaza!" % [active_concert_crowd.size(), active_event_id])

func _update_concert_crowd(delta: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	
	# Fetch Preacher state from StagePerformers if RELIGIOUS_RALLY is active
	var performers_node: Node = null
	var is_religious_active: bool = false
	
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	if is_instance_valid(city_gen):
		performers_node = city_gen.find_child("StagePerformers", true, false)
		if not is_instance_valid(performers_node):
			performers_node = city_gen.find_child("StageCyberBand", true, false) # Fallback
		if is_instance_valid(performers_node) and performers_node.has_meta("routine_type"):
			is_religious_active = true

	for fan in active_concert_crowd:
		if not is_instance_valid(fan):
			continue
		var base_p: Vector3 = fan.get_meta("base_pos", fan.position)
		var idx: int = fan.get_meta("fan_idx", 0)

		if is_religious_active:
			# CALL-AND-RESPONSE TIMING ENGINE:
			# [0.0s - 1.8s] Preacher acts on stage while Crowd watches attentively & stays still!
			# [1.8s - 2.5s] Brief pause in still reverence!
			# [2.5s - 4.5s] Crowd mimicks Preacher's exact move in unison!
			# [4.5s - 5.0s] Reset pause!
			var cycle_time: float = performers_node.get_meta("cycle_time", 0.0)
			var action_color: Color = performers_node.get_meta("action_color", Color(1.0, 0.85, 0.0))
			var active_action_jump: float = performers_node.get_meta("active_action_jump", 0.0)
			var active_action_sway: float = performers_node.get_meta("active_action_sway", 0.0)
			var active_action_tilt: float = performers_node.get_meta("active_action_tilt", 0.0)

			var crowd_jump: float = 0.0
			var crowd_sway: float = 0.0
			var crowd_tilt: float = 0.0
			var crowd_color: Color = Color(0.12, 0.12, 0.18) # Quiet default state

			if cycle_time >= 2.5 and cycle_time <= 4.5:
				# --- CROWD MIMICKS PREACHER'S ACTION IN UNISON ---
				crowd_jump = active_action_jump * 0.85
				crowd_sway = active_action_sway * 0.85
				crowd_tilt = active_action_tilt * 0.75
				crowd_color = action_color
			else:
				# Crowd stays still during Preacher's solo & second pause
				crowd_jump = 0.0
				crowd_sway = 0.0
				crowd_tilt = 0.0
				crowd_color = Color(0.12, 0.12, 0.18) # Resting amber/gray glow

			fan.position = Vector3(base_p.x, base_p.y + crowd_jump, base_p.z + crowd_sway)
			fan.rotation_degrees = Vector3(crowd_tilt, fan.rotation_degrees.y, 0.0)

			# Apply head glow color
			var head_node = fan.get_node_or_null("HeadMesh")
			if is_instance_valid(head_node) and is_instance_valid(head_node.material_override):
				var h_mat = head_node.material_override as StandardMaterial3D
				if is_instance_valid(h_mat):
					h_mat.albedo_color = crowd_color
					h_mat.emission = crowd_color
		else:
			# Hyped concert jumping, arm waving, and headbanging!
			var jump_y: float = abs(sin(time * 10.0 + idx * 0.4)) * 0.28
			var sway_z: float = sin(time * 5.0 + idx * 0.7) * 0.12
			fan.position = Vector3(base_p.x, base_p.y + jump_y, base_p.z + sway_z)

# Procedural dance routine updates for all park dancers with car dodge & safe return logic
func _update_park_dancers(delta: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var beat_fast: float = time * 12.0 # ~115 BPM rhythm
	var beat_slow: float = time * 3.0

	var player_pos: Vector3 = _get_player_world_position()
	var player_speed: float = player_car.linear_velocity.length() if is_instance_valid(player_car) and player_car is RigidBody3D else (player_car.current_speed if is_instance_valid(player_car) and "current_speed" in player_car else 0.0)

	for dancer in active_park_dancers:
		if not is_instance_valid(dancer):
			continue

		var style: String = dancer.get_meta("dance_style", "CIRCLE")
		var idx: int = dancer.get_meta("dancer_index", 0)
		var total: int = dancer.get_meta("total_dancers", 8)
		var center: Vector3 = dancer.get_meta("group_center", Vector3.ZERO)
		var phase: float = dancer.get_meta("dance_phase", 0.0)

		# ----------------------------------------------------------------------
		# CAR THREAT REACTION (Scare / Dodge when vehicle gets within 14m)
		# ----------------------------------------------------------------------
		var is_on_foot: bool = is_instance_valid(player_car) and player_car.is_on_foot
		var dist_to_car: float = dancer.global_position.distance_to(player_pos)
		var is_threatened: bool = (not is_on_foot) and dist_to_car < 14.0 and (player_speed > 2.0 or dist_to_car < 6.0)

		var panic_timer: float = dancer.get_meta("panic_timer", 0.0)
		if is_threatened:
			panic_timer = 3.5 # Panic for 3.5 seconds before feeling safe to return to dance
			dancer.set_meta("panic_timer", panic_timer)
		elif panic_timer > 0.0:
			panic_timer -= delta
			dancer.set_meta("panic_timer", panic_timer)

		if panic_timer > 0.0:
			# Flee / Scatter outwards away from car threat!
			var flee_dir: Vector3 = (dancer.global_position - player_pos).normalized()
			flee_dir.y = 0.0
			if flee_dir.length_squared() < 0.01:
				flee_dir = Vector3.FORWARD

			dancer.velocity = flee_dir * (walk_speed * 2.8) # Fast sprint dodge
			dancer.move_and_slide()

			# Fast panic hop animation
			dancer.position.y = abs(sin(beat_fast * 1.5 + phase)) * 0.25
			var look_target: Vector3 = dancer.global_position + flee_dir
			dancer.look_at(look_target, Vector3.UP)
			continue # Skip dance routine while panicked

		# ----------------------------------------------------------------------
		# SAFE ROUTINE: DANCING FORMATION (Circle / Partner / Line)
		# ----------------------------------------------------------------------
		var target_pos: Vector3 = dancer.global_position
		match style:
			"CIRCLE":
				var circle_radius: float = 3.5
				var rotation_speed: float = 0.4
				var current_angle: float = (float(idx) / float(total)) * TAU + (time * rotation_speed)
				target_pos = center + Vector3(cos(current_angle) * circle_radius, 0.0, sin(current_angle) * circle_radius)

			"PARTNERS":
				var partner_offset: float = 0.75
				var spin_speed: float = 1.8
				var is_partner_a: bool = (idx % 2 == 0)
				var dir_mult: float = 1.0 if is_partner_a else -1.0
				
				var spin_angle: float = (time * spin_speed * dir_mult) + (float(idx / 2) * 1.5)
				var rel_x: float = cos(spin_angle) * partner_offset
				var rel_z: float = sin(spin_angle) * partner_offset
				target_pos = center + Vector3(rel_x, 0.0, rel_z)

			"LINE":
				var spacing: float = 1.2
				var start_x: float = -((float(total) - 1.0) * spacing) / 2.0
				var base_x: float = start_x + float(idx) * spacing
				var side_step: float = sin(beat_slow) * 0.4
				var forward_step: float = abs(cos(beat_slow)) * 0.3
				target_pos = center + Vector3(base_x + side_step, 0.0, forward_step)

		# Smooth return step back to assigned dance formation position after scattering
		if dancer.global_position.distance_to(target_pos) > 0.3:
			var return_dir: Vector3 = (target_pos - dancer.global_position).normalized()
			dancer.velocity = return_dir * (walk_speed * 1.5)
			dancer.move_and_slide()
			dancer.position.y = abs(sin(beat_fast + phase)) * 0.15
			var look_target: Vector3 = dancer.global_position + return_dir
			dancer.look_at(look_target, Vector3.UP)
		else:
			# In position: execute exact dance routine visuals & rotations
			dancer.global_position = target_pos
			match style:
				"CIRCLE":
					dancer.position.y = abs(sin(beat_fast + phase)) * 0.22
					var look_pos: Vector3 = Vector3(center.x, dancer.global_position.y, center.z)
					dancer.look_at(look_pos, Vector3.UP)
					dancer.rotate_object_local(Vector3.UP, PI)
				"PARTNERS":
					dancer.position.y = abs(sin(beat_fast * 0.8 + phase)) * 0.15
					var is_partner_a: bool = (idx % 2 == 0)
					var rel_x: float = target_pos.x - center.x
					var rel_z: float = target_pos.z - center.z
					var partner_pos: Vector3 = center - Vector3(rel_x, 0.0, rel_z)
					dancer.look_at(Vector3(partner_pos.x, dancer.global_position.y, partner_pos.z), Vector3.UP)
				"LINE":
					dancer.position.y = abs(sin(beat_fast + phase)) * 0.18
					var turn_phase: int = int(time * 0.8) % 4
					dancer.rotation_degrees = Vector3(0, turn_phase * 90.0, 0)

	# --- Update Dodgy Park Characters (Smoke exhales & cigarette ember pulse) ---
	for dodgy in active_dodgy_characters:
		if not is_instance_valid(dodgy):
			continue
		var smoke_node = dodgy.get_node_or_null("Cigarette/SmokePuff")
		var ember_light = dodgy.get_node_or_null("Cigarette/OmniLight3D")
		if smoke_node and smoke_node.material_override is StandardMaterial3D:
			# Exhale cycle every ~4.5 seconds
			var cycle: float = fmod(time + 1.2, 4.5)
			if cycle < 1.2:
				# Exhaling puff drifting upward and scaling
				var t: float = cycle / 1.2
				var alpha: float = sin(t * PI) * 0.45
				smoke_node.material_override.albedo_color.a = alpha
				smoke_node.position = Vector3(0.0, 0.04 + t * 0.35, 0.10 + t * 0.15)
				smoke_node.scale = Vector3.ONE * (1.0 + t * 2.2)
				if ember_light:
					ember_light.light_energy = 5.0 + sin(t * PI) * 8.0 # Bright glow drag when taking a puff
			else:
				smoke_node.material_override.albedo_color.a = 0.0
				smoke_node.position = Vector3(0.0, 0.04, 0.10)
				smoke_node.scale = Vector3.ONE
				if ember_light:
					ember_light.light_energy = 4.0

# Spawns a "dodgy character" leaning against / hanging under a park streetlamp with a glowing cigarette & smoke puff particle effects
func _spawn_dodgy_park_character(park: Rect2) -> void:
	var center_2d: Vector2 = park.get_center()
	var center_pos: Vector3 = Vector3(center_2d.x, 0.0, center_2d.y)
	
	var half_w: float = park.size.x / 2.0 - 1.5
	var half_h: float = park.size.y / 2.0 - 1.5

	# Pick one of the 4 park corner streetlamps
	var corners: Array[Vector3] = [
		center_pos + Vector3(-half_w, 0.0, -half_h),
		center_pos + Vector3(half_w, 0.0, -half_h),
		center_pos + Vector3(half_w, 0.0, half_h),
		center_pos + Vector3(-half_w, 0.0, half_h)
	]
	var lamp_pos: Vector3 = corners[rng.randi() % corners.size()]
	
	# Position character right next to streetlamp pole (0.7m offset towards park center)
	var dir_to_center: Vector3 = (center_pos - lamp_pos).normalized()
	var char_pos: Vector3 = lamp_pos + dir_to_center * 0.7

	var ped_node = CharacterBody3D.new()
	ped_node.name = "DodgyParkCharacter"
	ped_node.set_meta("is_dodgy", true)

	# Dark shady coat material with dim crimson / deep amber accents
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.04, 0.04, 0.05) # Charcoal trenchcoat

	var head_mat = StandardMaterial3D.new()
	var dim_red: Color = Color(0.9, 0.15, 0.1) # Dim shady red emission head
	head_mat.albedo_color = dim_red
	head_mat.emission_enabled = true
	head_mat.emission = dim_red
	head_mat.emission_energy_multiplier = 2.0

	# Body Mesh Instance
	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh_template
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0.0, 0.6, 0.0)
	ped_node.add_child(body_inst)

	# Head Mesh Instance
	var head_inst = MeshInstance3D.new()
	head_inst.mesh = head_mesh_template
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 1.35, 0.0)
	ped_node.add_child(head_inst)

	# Collision Capsule
	var col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.3
	cap_shape.height = 1.5
	col_shape.shape = cap_shape
	col_shape.position = Vector3(0.0, 0.75, 0.0)
	ped_node.add_child(col_shape)

	# --- CIGARETTE PROP & GLOWING EMBER TIP ---
	var cig_node = Node3D.new()
	cig_node.name = "Cigarette"
	cig_node.position = Vector3(0.0, 1.32, 0.16) # Held near mouth/head
	ped_node.add_child(cig_node)

	# Cigarette stick mesh
	var cig_mesh_inst = MeshInstance3D.new()
	var cig_mesh = CylinderMesh.new()
	cig_mesh.top_radius = 0.012
	cig_mesh.bottom_radius = 0.012
	cig_mesh.height = 0.09
	cig_mesh_inst.mesh = cig_mesh
	cig_mesh_inst.rotation_degrees = Vector3(90, 0, 0)
	var cig_mat = StandardMaterial3D.new()
	cig_mat.albedo_color = Color(0.9, 0.9, 0.85)
	cig_mesh_inst.material_override = cig_mat
	cig_node.add_child(cig_mesh_inst)

	# Glowing Ember Tip (High Orange Emission Light)
	var ember_inst = MeshInstance3D.new()
	var ember_mesh = SphereMesh.new()
	ember_mesh.radius = 0.04
	ember_mesh.height = 0.08
	ember_inst.mesh = ember_mesh
	ember_inst.position = Vector3(0.0, 0.0, 0.06)
	var ember_mat = StandardMaterial3D.new()
	var ember_color: Color = Color(1.0, 0.3, 0.0) # Bright Neon Orange Ember
	ember_mat.albedo_color = ember_color
	ember_mat.emission_enabled = true
	ember_mat.emission = ember_color
	ember_mat.emission_energy_multiplier = 12.0
	ember_inst.material_override = ember_mat
	cig_node.add_child(ember_inst)

	# Small Ember Light source
	var ember_light = OmniLight3D.new()
	ember_light.light_color = ember_color
	ember_light.light_energy = 5.0
	ember_light.omni_range = 3.0
	ember_light.position = Vector3(0.0, 0.0, 0.06)
	cig_node.add_child(ember_light)

	# --- SMOKE PUFF MESH (Low-spec periodic exhales) ---
	var smoke_inst = MeshInstance3D.new()
	smoke_inst.name = "SmokePuff"
	var smoke_mesh = SphereMesh.new()
	smoke_mesh.radius = 0.06
	smoke_mesh.height = 0.12
	smoke_inst.mesh = smoke_mesh
	smoke_inst.position = Vector3(0.0, 0.04, 0.10)
	var smoke_mat = StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.85, 0.9, 0.95, 0.0) # Starts invisible
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_inst.material_override = smoke_mat
	cig_node.add_child(smoke_inst)

	add_child(ped_node)
	ped_node.global_position = char_pos

	# Face towards streetlamp pole / park corner, looking cool & shady
	ped_node.look_at(lamp_pos, Vector3.UP)
	ped_node.rotate_object_local(Vector3.UP, PI) # Back against lamp pole, looking outward into park

	active_dodgy_characters.append(ped_node)
	print("[PARK DANCERS] Spawned DodgyParkCharacter at ", char_pos, " near streetlamp ", lamp_pos)

# ==============================================================================
# INDEPENDENT PARKING LOT GANG SYSTEM
# ==============================================================================

func _spawn_parking_lot_gangs() -> void:
	var city_gen = $"../CityGenerator"
	if not is_instance_valid(city_gen) or city_gen.get("active_lot_boxes") == null:
		return

	var lot_boxes: Array[Rect2] = city_gen.active_lot_boxes
	if lot_boxes.is_empty():
		return

	# Clear existing gang members if any
	for member in active_gang_members:
		if is_instance_valid(member):
			member.queue_free()
	active_gang_members.clear()

	var color_idx: int = 0
	for lot in lot_boxes:
		# Pick 1 unified color theme for this gang (Blood Red, Cyber Purple, etc.)
		var theme_color: Color = gang_color_themes[color_idx % gang_color_themes.size()]
		color_idx += 1

		var center_2d: Vector2 = lot.get_center()
		var lot_center: Vector3 = Vector3(center_2d.x, 0.0, center_2d.y)
		var gang_size: int = rng.randi_range(4, 7)

		# Spawn Leader + Members hanging around parking lot
		for i in range(gang_size):
			var is_leader: bool = (i == 0)
			
			# Gang member position offset around lot
			var angle: float = (float(i) / float(gang_size)) * TAU + rng.randf_range(-0.3, 0.3)
			var radius: float = rng.randf_range(3.0, 8.0) if not is_leader else rng.randf_range(1.0, 3.0)
			var member_pos: Vector3 = lot_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

			var ped_node = CharacterBody3D.new()
			ped_node.name = "GangLeader" if is_leader else "GangMember"

			# Body Material: Dark tactical jacket
			var body_mat = StandardMaterial3D.new()
			body_mat.albedo_color = Color(0.05, 0.05, 0.07)

			# Head Material: Shared gang color theme! Leader is significantly brighter/radiant!
			var head_mat = StandardMaterial3D.new()
			head_mat.albedo_color = theme_color
			head_mat.emission_enabled = true
			head_mat.emission = theme_color
			head_mat.emission_energy_multiplier = 7.0 if is_leader else 2.5 # Leader is much brighter!

			# Body Mesh Instance
			var body_inst = MeshInstance3D.new()
			body_inst.mesh = body_mesh_template
			body_inst.material_override = body_mat
			body_inst.position = Vector3(0.0, 0.6, 0.0)
			ped_node.add_child(body_inst)

			# Head Mesh Instance (Leader slightly larger head sphere)
			var head_inst = MeshInstance3D.new()
			if is_leader:
				var leader_head_mesh = SphereMesh.new()
				leader_head_mesh.radius = 0.22
				leader_head_mesh.height = 0.44
				head_inst.mesh = leader_head_mesh
			else:
				head_inst.mesh = head_mesh_template

			head_inst.material_override = head_mat
			head_inst.position = Vector3(0.0, 1.35 if not is_leader else 1.4, 0.0)
			ped_node.add_child(head_inst)

			# Collision Capsule
			var col_shape = CollisionShape3D.new()
			var cap_shape = CapsuleShape3D.new()
			cap_shape.radius = 0.25
			cap_shape.height = 1.5
			col_shape.shape = cap_shape
			col_shape.position = Vector3(0.0, 0.75, 0.0)
			ped_node.add_child(col_shape)

			# Gang AI metadata
			var faction_name: String = gang_faction_names[color_idx % gang_faction_names.size()]
			ped_node.set_meta("is_gang_member", true)
			ped_node.set_meta("is_leader", is_leader)
			ped_node.set_meta("gang_faction_name", faction_name)
			ped_node.set_meta("lot_rect", lot)
			ped_node.set_meta("lot_center", lot_center)
			ped_node.set_meta("home_pos", member_pos)
			
			# Staggered interest delay: Leader walks FIRST (1.2s delay); followers start independently at random times (3.0s to 7.5s)
			ped_node.set_meta("interest_delay", 1.2 if is_leader else rng.randf_range(3.0, 7.5))
			ped_node.set_meta("interest_timer", 0.0)
			
			# Individual speed variation: Leader moves with purposeful pace (0.45x walk_speed), members vary between 0.25x and 0.55x walk_speed
			var member_speed: float = walk_speed * (0.45 if is_leader else rng.randf_range(0.25, 0.55))
			ped_node.set_meta("move_speed", member_speed)

			# Lurk distance stop offset (Leader comes close 2.2m; members lurk behind at 5.0m - 11.0m)
			ped_node.set_meta("lurk_stop_distance", 2.2 if is_leader else rng.randf_range(5.0, 11.0))
			ped_node.set_meta("walk_phase", rng.randf_range(0.0, TAU))

			add_child(ped_node)
			ped_node.global_position = member_pos

			# Face towards lot center initially
			ped_node.look_at(lot_center, Vector3.UP)

			active_gang_members.append(ped_node)

# Spawns a delivery recipient character waiting by a parked motorcycle outside a specified building location
func spawn_delivery_recipient(target_pos: Vector3) -> CharacterBody3D:
	# Clear previous recipient if any
	for old_rec in active_delivery_recipients:
		if is_instance_valid(old_rec):
			old_rec.queue_free()
	active_delivery_recipients.clear()

	var recipient := CharacterBody3D.new()
	recipient.name = "DeliveryRecipient"

	# Radiant Cyan Head & Sleek Leather Jacket
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.05, 0.08, 0.12)
	var head_mat = StandardMaterial3D.new()
	var cyan_color := Color(0.0, 1.0, 0.85)
	head_mat.albedo_color = cyan_color
	head_mat.emission_enabled = true
	head_mat.emission = cyan_color
	head_mat.emission_energy_multiplier = 3.0

	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh_template
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0.0, 0.6, 0.0)
	recipient.add_child(body_inst)

	var head_inst = MeshInstance3D.new()
	head_inst.mesh = head_mesh_template
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 1.35, 0.0)
	recipient.add_child(head_inst)

	var col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.3
	cap_shape.height = 1.5
	col_shape.shape = cap_shape
	col_shape.position = Vector3(0.0, 0.75, 0.0)
	recipient.add_child(col_shape)

	# --- PARKED MOTORCYCLE PROP ---
	var bike_node := Node3D.new()
	bike_node.name = "ParkedMotorcycle"
	bike_node.position = Vector3(1.2, 0.0, 0.0) # Parked right beside recipient
	
	# Main chassis mesh
	var bike_body = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.6, 0.8, 1.8)
	bike_body.mesh = box_mesh
	bike_body.position = Vector3(0.0, 0.5, 0.0)
	var bike_mat = StandardMaterial3D.new()
	bike_mat.albedo_color = Color(0.02, 0.02, 0.03)
	bike_body.material_override = bike_mat
	bike_node.add_child(bike_body)

	# Neon accent stripe on bike
	var stripe = MeshInstance3D.new()
	var stripe_mesh = BoxMesh.new()
	stripe_mesh.size = Vector3(0.62, 0.1, 1.6)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, 0.7, 0.0)
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(1.0, 0.85, 0.0)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(1.0, 0.85, 0.0)
	stripe_mat.emission_energy_multiplier = 4.0
	stripe.material_override = stripe_mat
	bike_node.add_child(stripe)

	# Front & rear wheels
	for z_off in [-0.6, 0.6]:
		var wheel = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.15
		wheel.mesh = cyl
		wheel.rotation_degrees = Vector3(0, 0, 90)
		wheel.position = Vector3(0.0, 0.3, z_off)
		bike_node.add_child(wheel)

	recipient.add_child(bike_node)

	add_child(recipient)
	recipient.global_position = target_pos
	recipient.set_meta("is_delivery_recipient", true)
	active_delivery_recipients.append(recipient)
	return recipient

func _update_parking_lot_gangs(delta: float) -> void:
	var player_pos: Vector3 = _get_player_world_position()

	for member in active_gang_members:
		if not is_instance_valid(member):
			continue

		var lot: Rect2 = member.get_meta("lot_rect", Rect2())
		var home_pos: Vector3 = member.get_meta("home_pos", Vector3.ZERO)
		var is_leader: bool = member.get_meta("is_leader", false)
		var delay_limit: float = member.get_meta("interest_delay", 3.0)
		var lurk_dist: float = member.get_meta("lurk_stop_distance", 6.0)
		var current_speed: float = member.get_meta("move_speed", walk_speed * 0.35)

		# Check if player is inside this parking lot (2D Rect2 check)
		var player_in_lot: bool = lot.has_point(Vector2(player_pos.x, player_pos.z))

		var interest_timer: float = member.get_meta("interest_timer", 0.0)
		if player_in_lot:
			interest_timer += delta
		else:
			# Player left parking lot: interest cools off
			interest_timer = move_toward(interest_timer, 0.0, delta * 1.5)
		member.set_meta("interest_timer", interest_timer)

		var is_interested: bool = interest_timer >= delay_limit
		var target_dest: Vector3 = home_pos

		if is_interested:
			# Calculate vector from member to player
			var dist_to_player: float = member.global_position.distance_to(player_pos)
			if dist_to_player > lurk_dist:
				# Walk towards player until reaching assigned lurking distance limit
				var approach_dir: Vector3 = (player_pos - member.global_position).normalized()
				approach_dir.y = 0.0
				target_dest = member.global_position + approach_dir * 2.0
				
				var move_dir: Vector3 = (target_dest - member.global_position).normalized()
				member.velocity = move_dir * current_speed
				member.move_and_slide()

				# Face player while approaching
				var look_target: Vector3 = Vector3(player_pos.x, member.global_position.y, player_pos.z)
				if member.global_position.distance_to(look_target) > 0.1:
					member.look_at(look_target, Vector3.UP)
			else:
				# Reached lurking distance: stop and stare at player menacingly
				member.velocity = Vector3.ZERO
				var look_target: Vector3 = Vector3(player_pos.x, member.global_position.y, player_pos.z)
				if member.global_position.distance_to(look_target) > 0.1:
					member.look_at(look_target, Vector3.UP)
		else:
			# Not interested / chilling at home position in parking lot
			if member.global_position.distance_to(home_pos) > 0.5:
				var return_dir: Vector3 = (home_pos - member.global_position).normalized()
				member.velocity = return_dir * (walk_speed * 0.4)
				member.move_and_slide()
				var look_target: Vector3 = Vector3(home_pos.x, member.global_position.y, home_pos.z)
				if member.global_position.distance_to(look_target) > 0.1:
					member.look_at(look_target, Vector3.UP)
			else:
				member.velocity = Vector3.ZERO

# ==============================================================================
# INDEPENDENT NARROW STREET RESIDENTS (Alley / Narrow Corridor Solitary Locals)
# ==============================================================================

func _spawn_narrow_street_residents() -> void:
	var city_gen = $"../CityGenerator"
	if not is_instance_valid(city_gen) or city_gen.get("active_alley_corridors") == null:
		return

	var alley_corridors: Array = city_gen.active_alley_corridors
	if alley_corridors.is_empty():
		return

	# Clear existing narrow street residents if any
	for resident in active_narrow_street_residents:
		if is_instance_valid(resident):
			resident.queue_free()
	active_narrow_street_residents.clear()

	# Head color variants for narrow street residents: Dark Red or Dark Blue
	var resident_head_colors: Array[Color] = [
		Color(0.7, 0.08, 0.08), # Dark Crimson Red
		Color(0.05, 0.15, 0.7)  # Dark Cobalt Blue
	]

	# Each narrow street corridor is claimed by 1 resident (stationary solitary local)
	for alley in alley_corridors:
		var axis: String = alley["axis"]
		var pos_fixed: float = alley["pos_fixed"]
		var min_val: float = alley["min"]
		var max_val: float = alley["max"]

		# Spawn position: Hugging building wall (4.2m offset from corridor center line)
		var wall_side: float = -4.2 if rng.randf() > 0.5 else 4.2
		var mid_var: float = rng.randf_range(min_val + 6.0, max_val - 6.0)
		
		var spawn_pos: Vector3 = Vector3(pos_fixed + wall_side, 0.0, mid_var) if axis == "Z" else Vector3(mid_var, 0.0, pos_fixed + wall_side)

		var head_color: Color = resident_head_colors[rng.randi() % resident_head_colors.size()]

		var ped_node = CharacterBody3D.new()
		ped_node.name = "NarrowStreetResident"

		# Body Material: Weathered dark slate coat
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.04, 0.04, 0.06)

		# Head Material: Dim Dark Red / Dark Blue glow
		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = head_color
		head_mat.emission_enabled = true
		head_mat.emission = head_color
		head_mat.emission_energy_multiplier = 2.2 # Dim mysterious head glow

		# Body Mesh Instance
		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.material_override = body_mat
		body_inst.position = Vector3(0.0, 0.6, 0.0)
		ped_node.add_child(body_inst)

		# Head Mesh Instance
		var head_inst = MeshInstance3D.new()
		head_inst.mesh = head_mesh_template
		head_inst.material_override = head_mat
		head_inst.position = Vector3(0.0, 1.35, 0.0)
		ped_node.add_child(head_inst)

		# Collision Capsule
		var col_shape = CollisionShape3D.new()
		var cap_shape = CapsuleShape3D.new()
		cap_shape.radius = 0.25
		cap_shape.height = 1.5
		col_shape.shape = cap_shape
		col_shape.position = Vector3(0.0, 0.75, 0.0)
		ped_node.add_child(col_shape)

		# Resident Metadata & Stroll Routine State
		ped_node.set_meta("is_street_resident", true)
		ped_node.set_meta("home_pos", spawn_pos)
		ped_node.set_meta("alley_data", alley)
		ped_node.set_meta("flee_timer", 0.0)
		ped_node.set_meta("stroll_timer", rng.randf_range(6.0, 16.0)) # Next stroll in 6-16s
		ped_node.set_meta("stroll_state", "IDLE")
		ped_node.set_meta("stroll_target", spawn_pos)
		ped_node.set_meta("stroll_phase", rng.randf_range(0.0, TAU))
		# 35% of narrow street residents are tipsy/drunk stumblers who occasionally trip over and pick themselves back up!
		ped_node.set_meta("is_tipsy_stumbler", rng.randf() < 0.35)
		ped_node.set_meta("fall_timer", 0.0)

		add_child(ped_node)
		ped_node.global_position = spawn_pos

		# Facing direction facing slightly out into alley from building wall
		var facing_dir: Vector3 = Vector3(0.0, 0.0, -wall_side).normalized() if axis == "Z" else Vector3(-wall_side, 0.0, 0.0).normalized()
		ped_node.look_at(spawn_pos + facing_dir, Vector3.UP)

		active_narrow_street_residents.append(ped_node)
	
	print("[STREET RESIDENTS] Spawned ", active_narrow_street_residents.size(), " solitary narrow street residents in alleys.")

func _update_narrow_street_residents(delta: float) -> void:
	# Check distance to player vehicle
	var car_pos: Vector3 = player_car.global_position if is_instance_valid(player_car) else Vector3.ZERO
	var car_speed: float = player_car.linear_velocity.length() if is_instance_valid(player_car) and player_car is RigidBody3D else (player_car.current_speed if is_instance_valid(player_car) and "current_speed" in player_car else 0.0)

	for resident in active_narrow_street_residents:
		if not is_instance_valid(resident):
			continue

		var home_pos: Vector3 = resident.get_meta("home_pos", Vector3.ZERO)
		var alley: Dictionary = resident.get_meta("alley_data", {})
		var dist_to_car: float = resident.global_position.distance_to(car_pos)

		# CAR DANGER REACTION: Only runs away from CARS (if car gets within 16m and is moving or near 6m)
		# Ignores on-foot player completely!
		var is_threatened_by_car: bool = dist_to_car < 16.0 and (car_speed > 2.0 or dist_to_car < 6.0)

		var flee_timer: float = resident.get_meta("flee_timer", 0.0)
		if is_threatened_by_car:
			flee_timer = 4.0 # Flee away from car for 4 seconds
			resident.set_meta("flee_timer", flee_timer)
		elif flee_timer > 0.0:
			flee_timer -= delta
			resident.set_meta("flee_timer", flee_timer)

		if flee_timer > 0.0:
			# Sprint-flee away from car along narrow street corridor
			var flee_dir: Vector3 = (resident.global_position - car_pos).normalized()
			flee_dir.y = 0.0
			if flee_dir.length_squared() < 0.01:
				flee_dir = Vector3.FORWARD

			resident.velocity = flee_dir * (walk_speed * 2.8) # Fast escape sprint
			resident.move_and_slide()

			# Fast panic animation step
			var beat_fast: float = Time.get_ticks_msec() / 1000.0 * 14.0
			resident.position.y = abs(sin(beat_fast)) * 0.2
			var look_target: Vector3 = resident.global_position + flee_dir
			if resident.global_position.distance_to(look_target) > 0.1:
				resident.look_at(look_target, Vector3.UP)
		else:
			# SAFE AT HOME: Stationary or doing periodic mini-strolls (tiny circle / corner check)
			var stroll_state: String = resident.get_meta("stroll_state", "IDLE")
			var stroll_timer: float = resident.get_meta("stroll_timer", 10.0) - delta
			resident.set_meta("stroll_timer", stroll_timer)

			if stroll_state == "IDLE":
				if stroll_timer <= 0.0:
					# Trigger a new stroll: 60% chance tiny circle stroll, 40% chance corner check
					stroll_state = "CIRCLE_STROLL" if rng.randf() < 0.6 else "CORNER_CHECK"
					resident.set_meta("stroll_state", stroll_state)
					resident.set_meta("stroll_phase", 0.0)
					resident.set_meta("stroll_duration", rng.randf_range(4.0, 7.0))
				else:
					# Standard idle standing against wall
					resident.velocity = Vector3.ZERO
					if resident.global_position.distance_to(home_pos) > 0.3:
						var return_dir: Vector3 = (home_pos - resident.global_position).normalized()
						resident.velocity = return_dir * (walk_speed * 0.8)
						resident.move_and_slide()
						var look_target: Vector3 = resident.global_position + return_dir
						if resident.global_position.distance_to(look_target) > 0.1:
							resident.look_at(look_target, Vector3.UP)
					else:
						resident.global_position = home_pos

			elif stroll_state == "FALLEN":
				# Stumbled & fell over! Lie on ground for a couple of seconds before picking self back up
				var fall_t: float = resident.get_meta("fall_timer", 0.0) + delta
				resident.set_meta("fall_timer", fall_t)
				resident.velocity = Vector3.ZERO
				
				if fall_t < 2.5:
					# Lying flat on ground (tilted 85 degrees roll)
					resident.rotation_degrees.z = move_toward(resident.rotation_degrees.z, 85.0, delta * 300.0)
					resident.position.y = 0.1
				elif fall_t < 4.0:
					# Picking self back up! (Struggling tilt back to 0 degrees)
					var getup_progress: float = (fall_t - 2.5) / 1.5
					resident.rotation_degrees.z = lerpf(85.0, 0.0, getup_progress)
					resident.position.y = abs(sin(getup_progress * PI)) * 0.08
				else:
					# Fully recovered! Stand upright and return to IDLE
					resident.rotation_degrees.z = 0.0
					resident.position.y = 0.0
					resident.set_meta("stroll_state", "IDLE")
					resident.set_meta("stroll_timer", rng.randf_range(10.0, 22.0))

			elif stroll_state == "CIRCLE_STROLL":
				# Tiny 2m circle stroll near home wall — tipsy stumbler has a 25% chance to trip halfway!
				var dur: float = resident.get_meta("stroll_duration", 5.0)
				var phase: float = resident.get_meta("stroll_phase", 0.0) + delta
				resident.set_meta("stroll_phase", phase)

				var is_stumbler: bool = resident.get_meta("is_tipsy_stumbler", false)
				if is_stumbler and phase > dur * 0.45 and phase < dur * 0.55 and rng.randf() < 0.25:
					# Trip & fall over!
					resident.set_meta("stroll_state", "FALLEN")
					resident.set_meta("fall_timer", 0.0)
				elif phase >= dur:
					# Finished circle stroll: return to IDLE
					resident.set_meta("stroll_state", "IDLE")
					resident.set_meta("stroll_timer", rng.randf_range(12.0, 25.0))
				else:
					var circle_r: float = 1.8
					var angle: float = (phase / dur) * TAU
					var target: Vector3 = home_pos + Vector3(cos(angle) * circle_r, 0.0, sin(angle) * circle_r)
					
					var move_dir: Vector3 = (target - resident.global_position).normalized()
					resident.velocity = move_dir * (walk_speed * 0.45) # Slow lazy stroll
					resident.move_and_slide()
					
					var anim_beat: float = Time.get_ticks_msec() / 1000.0 * 6.0
					resident.position.y = abs(sin(anim_beat)) * 0.04
					var look_target: Vector3 = resident.global_position + move_dir
					if resident.global_position.distance_to(look_target) > 0.1:
						resident.look_at(look_target, Vector3.UP)

			elif stroll_state == "CORNER_CHECK":
				# Takes a few steps to the alley mouth/corner, looks around, then returns
				var dur: float = resident.get_meta("stroll_duration", 6.0)
				var phase: float = resident.get_meta("stroll_phase", 0.0) + delta
				resident.set_meta("stroll_phase", phase)

				if phase >= dur:
					# Finished checking corner: return to IDLE
					resident.set_meta("stroll_state", "IDLE")
					resident.set_meta("stroll_timer", rng.randf_range(12.0, 25.0))
				else:
					# Step out towards alley mouth corner, pause to look, then walk back
					var mid_point: float = dur * 0.5
					var corner_offset: Vector3 = Vector3(3.5, 0.0, 0.0) if alley.get("axis", "Z") == "Z" else Vector3(0.0, 0.0, 3.5)
					var corner_target: Vector3 = home_pos + corner_offset

					if phase < mid_point:
						# Walking to corner
						var move_dir: Vector3 = (corner_target - resident.global_position).normalized()
						resident.velocity = move_dir * (walk_speed * 0.5)
						resident.move_and_slide()
						var anim_beat: float = Time.get_ticks_msec() / 1000.0 * 6.0
						resident.position.y = abs(sin(anim_beat)) * 0.04
						var look_target: Vector3 = resident.global_position + move_dir
						if resident.global_position.distance_to(look_target) > 0.1:
							resident.look_at(look_target, Vector3.UP)
					else:
						# Walking back to home wall
						var return_dir: Vector3 = (home_pos - resident.global_position).normalized()
						resident.velocity = return_dir * (walk_speed * 0.5)
						resident.move_and_slide()
						var anim_beat: float = Time.get_ticks_msec() / 1000.0 * 6.0
						resident.position.y = abs(sin(anim_beat)) * 0.04
						var look_target: Vector3 = resident.global_position + return_dir
						if resident.global_position.distance_to(look_target) > 0.1:
							resident.look_at(look_target, Vector3.UP)

# ==============================================================================
# NEW ARCHETYPES: VENDORS, FIXERS, BUSKERS, TECH DRONES, JOGGERS
# ==============================================================================

var active_hq_guards: Array[CharacterBody3D] = []

func _spawn_new_archetypes() -> void:
	var city_gen = $"../CityGenerator"
	if not is_instance_valid(city_gen):
		return

	# 1. STREET VENDORS & HAWKING TRADERS (Spawn near food trucks & crosswalk corners)
	_spawn_street_vendors(city_gen)

	# 2. FIXERS & INFORMANTS (Pairs in dark alcoves/alleys)
	_spawn_fixers_and_informants(city_gen)

	# 3. STREET MUSICIANS / BUSKERS (Parks & wide sidewalks with synth pod)
	_spawn_street_buskers(city_gen)

	# 4. MAINTENANCE / REPAIR DRONES & TECHS (Kneeling near streetlights/building bases)
	_spawn_tech_drones(city_gen)

	# 5. JOGGERS / CYBER-RUNNERS (Park perimeter loops & sidewalks at 2.2x speed)
	_spawn_cyber_joggers(city_gen)

	# 6. DUNCAN DYNAMICS HQ SECURITY GUARDS (Posted outside building entrance)
	_spawn_hq_security_guards(city_gen)

func _spawn_street_vendors(city_gen) -> void:
	var target_boxes: Array[Rect2] = []
	if city_gen.get("active_park_boxes") != null:
		target_boxes.append_array(city_gen.active_park_boxes)
	if city_gen.get("active_lot_boxes") != null:
		target_boxes.append_array(city_gen.active_lot_boxes)

	var count: int = min(target_boxes.size(), 4)
	for i in range(count):
		var box: Rect2 = target_boxes[i]
		var center_2d: Vector2 = box.get_center()
		var pos: Vector3 = Vector3(center_2d.x + 8.0, 0.0, center_2d.y - 8.0)

		# Water safety check for street vendor cart!
		if is_instance_valid(city_gen) and city_gen.has_method("_is_position_in_water"):
			if city_gen._is_position_in_water(pos):
				pos = city_gen._find_safe_land_position(pos)

		var vendor_node = CharacterBody3D.new()
		vendor_node.name = "StreetVendor"

		var color: Color = Color(1.0, 0.5, 0.0) # Radiant Amber Orange
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.1, 0.08, 0.05)
		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = color
		head_mat.emission_enabled = true
		head_mat.emission = color
		head_mat.emission_energy_multiplier = 4.0

		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.material_override = body_mat
		body_inst.position = Vector3(0.0, 0.6, 0.0)
		vendor_node.add_child(body_inst)

		var head_inst = MeshInstance3D.new()
		head_inst.mesh = head_mesh_template
		head_inst.material_override = head_mat
		head_inst.position = Vector3(0.0, 1.35, 0.0)
		vendor_node.add_child(head_inst)

		# Vendor Cart Prop
		var cart_inst = MeshInstance3D.new()
		var cart_box = BoxMesh.new()
		cart_box.size = Vector3(1.2, 0.9, 0.8)
		cart_inst.mesh = cart_box
		cart_inst.position = Vector3(0.0, 0.45, 0.7)
		var cart_mat = StandardMaterial3D.new()
		cart_mat.albedo_color = Color(0.15, 0.15, 0.2)
		cart_inst.material_override = cart_mat
		vendor_node.add_child(cart_inst)

		vendor_node.set_meta("shout_timer", rng.randf_range(3.0, 8.0))
		add_child(vendor_node)
		vendor_node.global_position = pos
		active_street_vendors.append(vendor_node)

func _spawn_fixers_and_informants(city_gen) -> void:
	if city_gen.get("active_alley_corridors") == null or city_gen.active_alley_corridors.is_empty():
		return

	var count: int = min(city_gen.active_alley_corridors.size(), 3)
	for i in range(count):
		var alley: Dictionary = city_gen.active_alley_corridors[i]
		var pos_fixed: float = alley["pos_fixed"]
		var min_val: float = alley["min"]
		var base_pos: Vector3 = Vector3(pos_fixed, 0.0, min_val + 10.0) if alley["axis"] == "Z" else Vector3(min_val + 10.0, 0.0, pos_fixed)

		# Pair of 2 Fixers in dark conversation
		for p in range(2):
			var fixer_node = CharacterBody3D.new()
			fixer_node.name = "FixerInformant"
			var offset: Vector3 = Vector3(-0.6 if p == 0 else 0.6, 0.0, 0.0)

			var glitch_red: Color = Color(0.8, 0.0, 0.2)
			var body_mat = StandardMaterial3D.new()
			body_mat.albedo_color = Color(0.02, 0.02, 0.03)

			var head_mat = StandardMaterial3D.new()
			head_mat.albedo_color = glitch_red
			head_mat.emission_enabled = true
			head_mat.emission = glitch_red
			head_mat.emission_energy_multiplier = 3.0

			var body_inst = MeshInstance3D.new()
			body_inst.mesh = body_mesh_template
			body_inst.material_override = body_mat
			body_inst.position = Vector3(0.0, 0.6, 0.0)
			fixer_node.add_child(body_inst)

			var head_inst = MeshInstance3D.new()
			head_inst.mesh = head_mesh_template
			head_inst.material_override = head_mat
			head_inst.position = Vector3(0.0, 1.35, 0.0)
			fixer_node.add_child(head_inst)

			fixer_node.set_meta("home_pos", base_pos + offset)
			fixer_node.set_meta("glitch_timer", 0.0)
			fixer_node.set_meta("partner_index", p)

			add_child(fixer_node)
			fixer_node.global_position = base_pos + offset

			# Face each other
			var partner_pos: Vector3 = base_pos + Vector3(0.6 if p == 0 else -0.6, 0.0, 0.0)
			fixer_node.look_at(partner_pos, Vector3.UP)

			active_fixers.append(fixer_node)

func _spawn_street_buskers(city_gen) -> void:
	if city_gen.get("active_park_boxes") == null or city_gen.active_park_boxes.is_empty():
		return

	for park in city_gen.active_park_boxes:
		var center_2d: Vector2 = park.get_center()
		var busker_pos: Vector3 = Vector3(center_2d.x - 6.0, 0.0, center_2d.y - 6.0)

		var busker_node = CharacterBody3D.new()
		busker_node.name = "StreetBusker"

		var magenta: Color = Color(1.0, 0.0, 0.6)
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.08, 0.05, 0.1)

		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = magenta
		head_mat.emission_enabled = true
		head_mat.emission = magenta
		head_mat.emission_energy_multiplier = 5.0

		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.material_override = body_mat
		body_inst.position = Vector3(0.0, 0.6, 0.0)
		busker_node.add_child(body_inst)

		var head_inst = MeshInstance3D.new()
		head_inst.mesh = head_mesh_template
		head_inst.material_override = head_mat
		head_inst.position = Vector3(0.0, 1.35, 0.0)
		busker_node.add_child(head_inst)

		# Synth Pod / Keytar Prop
		var synth_inst = MeshInstance3D.new()
		var synth_box = BoxMesh.new()
		synth_box.size = Vector3(0.9, 0.1, 0.35)
		synth_inst.mesh = synth_box
		synth_inst.position = Vector3(0.0, 0.9, 0.3)
		var synth_mat = StandardMaterial3D.new()
		synth_mat.albedo_color = magenta
		synth_mat.emission_enabled = true
		synth_mat.emission = magenta
		synth_mat.emission_energy_multiplier = 4.0
		synth_inst.material_override = synth_mat
		busker_node.add_child(synth_inst)

		add_child(busker_node)
		busker_node.global_position = busker_pos
		active_buskers.append(busker_node)

func _spawn_tech_drones(city_gen) -> void:
	if city_gen.get("active_park_boxes") == null or city_gen.active_park_boxes.is_empty():
		return

	for park in city_gen.active_park_boxes:
		var center_2d: Vector2 = park.get_center()
		var pos: Vector3 = Vector3(center_2d.x + 12.0, 0.0, center_2d.y + 12.0)

		var tech_node = CharacterBody3D.new()
		tech_node.name = "TechDrone"

		var yellow: Color = Color(1.0, 0.8, 0.0)
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.1, 0.1, 0.05)

		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = yellow
		head_mat.emission_enabled = true
		head_mat.emission = yellow
		head_mat.emission_energy_multiplier = 3.0

		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.material_override = body_mat
		body_inst.position = Vector3(0.0, 0.4, 0.0) # Kneeling height
		tech_node.add_child(body_inst)

		var head_inst = MeshInstance3D.new()
		head_inst.mesh = head_mesh_template
		head_inst.material_override = head_mat
		head_inst.position = Vector3(0.0, 0.95, 0.0)
		tech_node.add_child(head_inst)

		# Work Spotlight
		var spot = SpotLight3D.new()
		spot.name = "TechSpotlight"
		spot.light_color = yellow
		spot.light_energy = 8.0
		spot.spot_range = 6.0
		spot.spot_angle = 35.0
		spot.position = Vector3(0.0, 0.8, 0.2)
		spot.rotation_degrees = Vector3(-45, 0, 0)
		tech_node.add_child(spot)

		tech_node.set_meta("spark_timer", 0.0)
		add_child(tech_node)
		tech_node.global_position = pos
		active_tech_drones.append(tech_node)

func _spawn_cyber_joggers(city_gen) -> void:
	# Spawn 4 Cyber-Runners along park loops at 2.2x speed
	if city_gen.get("active_park_boxes") == null or city_gen.active_park_boxes.is_empty():
		return

	for park in city_gen.active_park_boxes:
		var center_2d: Vector2 = park.get_center()
		var center_pos: Vector3 = Vector3(center_2d.x, 0.0, center_2d.y)

		for j in range(2):
			var jogger_node = CharacterBody3D.new()
			jogger_node.name = "CyberJogger"

			var cyan: Color = Color(0.0, 1.0, 0.9) if j == 0 else Color(0.2, 1.0, 0.3)
			var body_mat = StandardMaterial3D.new()
			body_mat.albedo_color = Color(0.05, 0.1, 0.1)

			var head_mat = StandardMaterial3D.new()
			head_mat.albedo_color = cyan
			head_mat.emission_enabled = true
			head_mat.emission = cyan
			head_mat.emission_energy_multiplier = 4.5

			var body_inst = MeshInstance3D.new()
			body_inst.mesh = body_mesh_template
			body_inst.material_override = body_mat
			body_inst.position = Vector3(0.0, 0.6, 0.0)
			jogger_node.add_child(body_inst)

			var head_inst = MeshInstance3D.new()
			head_inst.mesh = head_mesh_template
			head_inst.material_override = head_mat
			head_inst.position = Vector3(0.0, 1.35, 0.0)
			jogger_node.add_child(head_inst)

			jogger_node.set_meta("park_center", center_pos)
			jogger_node.set_meta("jog_angle", float(j) * PI)
			add_child(jogger_node)
			jogger_node.global_position = center_pos + Vector3(float(j * 4), 0.0, 0.0)
			active_joggers.append(jogger_node)

func _spawn_hq_security_guards(city_gen) -> void:
	if city_gen.get("hq_door_pos") == null or city_gen.hq_door_pos == Vector3.ZERO:
		return

	var door_pos: Vector3 = city_gen.hq_door_pos

	# Clear previous guards if any
	for g in active_hq_guards:
		if is_instance_valid(g):
			g.queue_free()
	active_hq_guards.clear()

	# Spawn 2 Fife Security Guards flanking the HQ entrance portal
	for i in range(2):
		var side_offset: Vector3 = Vector3(-2.4 if i == 0 else 2.4, 0.0, 0.5)
		var guard_pos: Vector3 = door_pos + side_offset

		var guard_node = CharacterBody3D.new()
		guard_node.name = "HQSecurityGuard"

		# Dark Tactical Armor with Radiant Red Shielding & Visor
		var body_mat = StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.04, 0.04, 0.07) # Dark Obsidian Tactical Armor

		var visor_red: Color = Color(1.0, 0.1, 0.1)
		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = visor_red
		head_mat.emission_enabled = true
		head_mat.emission = visor_red
		head_mat.emission_energy_multiplier = 5.0 # High intensity security visor glow

		# Body Mesh Instance
		var body_inst = MeshInstance3D.new()
		body_inst.mesh = body_mesh_template
		body_inst.material_override = body_mat
		body_inst.position = Vector3(0.0, 0.6, 0.0)
		guard_node.add_child(body_inst)

		# Head / Helmet Mesh Instance
		var head_inst = MeshInstance3D.new()
		head_inst.mesh = head_mesh_template
		head_inst.material_override = head_mat
		head_inst.position = Vector3(0.0, 1.35, 0.0)
		guard_node.add_child(head_inst)

		# Tactical Shoulder Armor Pads
		for side in [-0.28, 0.28]:
			var pad_inst = MeshInstance3D.new()
			var pad_box = BoxMesh.new()
			pad_box.size = Vector3(0.22, 0.22, 0.22)
			pad_inst.mesh = pad_box
			pad_inst.position = Vector3(side, 1.05, 0.0)
			pad_inst.material_override = body_mat
			guard_node.add_child(pad_inst)

		# Security Scanner Light Beam
		var scanner_spot = SpotLight3D.new()
		scanner_spot.name = "GuardScanner"
		scanner_spot.light_color = visor_red
		scanner_spot.light_energy = 6.0
		scanner_spot.spot_range = 8.0
		scanner_spot.spot_angle = 30.0
		scanner_spot.position = Vector3(0.0, 1.35, 0.2)
		scanner_spot.rotation_degrees = Vector3(-15, 0, 0)
		guard_node.add_child(scanner_spot)

		guard_node.set_meta("is_security_guard", true)
		guard_node.set_meta("home_pos", guard_pos)
		guard_node.set_meta("scan_timer", rng.randf_range(0.0, 4.0))

		add_child(guard_node)
		guard_node.global_position = guard_pos

		# Face outward towards the street (-Z or +Z direction away from doorway)
		guard_node.look_at(guard_pos + Vector3(0.0, 0.0, 5.0), Vector3.UP)
		active_hq_guards.append(guard_node)

	print("[HQ GUARDS] Posted 2 Fife Security Guards outside Duncan Dynamics HQ.")

# ==============================================================================
# ARCHETYPE UPDATE AI LOOPS
# ==============================================================================

func _update_archetype_behaviors(delta: float) -> void:
	var player_pos: Vector3 = _get_player_world_position()
	var time: float = Time.get_ticks_msec() / 1000.0

	# 0. HQ SECURITY GUARDS: Scan sweeping & player tracking
	for guard in active_hq_guards:
		if is_instance_valid(guard):
			var home_pos: Vector3 = guard.get_meta("home_pos", guard.global_position)
			var dist_to_player: float = guard.global_position.distance_to(player_pos)

			if dist_to_player <= 10.0:
				# Track player with security visor scanner when near entrance
				var look_target: Vector3 = Vector3(player_pos.x, guard.global_position.y, player_pos.z)
				if guard.global_position.distance_to(look_target) > 0.1:
					guard.look_at(look_target, Vector3.UP)
			else:
				# Idle scanning sweep back and forth
				var scan_t: float = guard.get_meta("scan_timer", 0.0) + delta
				guard.set_meta("scan_timer", scan_t)
				var sweep_yaw: float = sin(scan_t * 1.2) * 45.0
				guard.rotation_degrees.y = sweep_yaw

	# 1. STREET VENDORS: Periodic head-tilt shout animation
	for vendor in active_street_vendors:
		if is_instance_valid(vendor):
			var timer: float = vendor.get_meta("shout_timer", 5.0) - delta
			if timer <= 0.0:
				timer = rng.randf_range(4.0, 9.0)
				vendor.rotation_degrees.y += rng.randf_range(-30.0, 30.0)
			vendor.set_meta("shout_timer", timer)

	# 2. FIXERS: Glitch head emission & silence on player approach
	for fixer in active_fixers:
		if is_instance_valid(fixer):
			var home_pos: Vector3 = fixer.get_meta("home_pos", Vector3.ZERO)
			var dist: float = fixer.global_position.distance_to(player_pos)
			var head: MeshInstance3D = fixer.get_child(1) as MeshInstance3D
			
			if dist < 6.0:
				# Player approaches: break off conversation, step back & turn away
				fixer.velocity = (fixer.global_position - player_pos).normalized() * (walk_speed * 0.4)
				fixer.move_and_slide()
				var look_away: Vector3 = fixer.global_position + (fixer.global_position - player_pos).normalized()
				if fixer.global_position.distance_to(look_away) > 0.1:
					fixer.look_at(look_away, Vector3.UP)
			else:
				# Glitch head emission pulse
				if is_instance_valid(head) and head.material_override:
					var mat: StandardMaterial3D = head.material_override
					mat.emission_energy_multiplier = 3.0 + sin(time * 25.0) * 1.5

	# 3. BUSKERS: Rhythm-synced head bob & pulse
	for busker in active_buskers:
		if is_instance_valid(busker):
			busker.position.y = abs(sin(time * 10.0)) * 0.08

	# 4. TECH DRONES: Periodic spark light pulse
	for tech in active_tech_drones:
		if is_instance_valid(tech):
			var spot: SpotLight3D = tech.get_node_or_null("TechSpotlight") as SpotLight3D
			if is_instance_valid(spot):
				spot.light_energy = 8.0 + sin(time * 30.0) * 4.0

	# 5. JOGGERS: Fast 2.2x perimeter loop running
	for jogger in active_joggers:
		if is_instance_valid(jogger):
			var center: Vector3 = jogger.get_meta("park_center", Vector3.ZERO)
			var angle: float = jogger.get_meta("jog_angle", 0.0) + delta * 0.6
			jogger.set_meta("jog_angle", angle)

			var r: float = 12.0
			var target_pos: Vector3 = center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
			var move_dir: Vector3 = (target_pos - jogger.global_position).normalized()
			jogger.velocity = move_dir * (walk_speed * 2.2) # 5.5 m/s fast jog
			jogger.move_and_slide()

			# Fast vertical bounce oscillation
			jogger.position.y = abs(sin(time * 16.0)) * 0.15
			var look_target: Vector3 = jogger.global_position + move_dir
			if jogger.global_position.distance_to(look_target) > 0.1:
				jogger.look_at(look_target, Vector3.UP)

# Checks for nearest character/NPC within 3.5m and opens identification dialogue
func _try_trigger_character_dialogue(player_pos: Vector3, dialogue_sys: DialogueSystem) -> bool:
	if not is_instance_valid(dialogue_sys):
		return false

	var all_nodes: Array[Node3D] = []
	all_nodes.append_array(active_pedestrians)
	all_nodes.append_array(active_park_dancers)
	all_nodes.append_array(active_dodgy_characters)
	all_nodes.append_array(active_gang_members)
	all_nodes.append_array(active_narrow_street_residents)
	all_nodes.append_array(active_delivery_recipients)
	all_nodes.append_array(active_street_vendors)
	all_nodes.append_array(active_fixers)
	all_nodes.append_array(active_buskers)
	all_nodes.append_array(active_tech_drones)
	all_nodes.append_array(active_joggers)

	var closest_node: Node3D = null
	var min_dist: float = 3.5 # Interaction range

	for node in all_nodes:
		if is_instance_valid(node):
			var d: float = node.global_position.distance_to(player_pos)
			if d < min_dist:
				min_dist = d
				closest_node = node

	if closest_node == null:
		return false

	# Identify character archetype & load dedicated JSON dialogue asset
	var char_name: String = closest_node.name
	var is_dodgy_meta: bool = closest_node.get_meta("is_dodgy", false)
	var is_gang_meta: bool = closest_node.get_meta("is_gang_member", false) or "Gang" in char_name
	var is_leader: bool = closest_node.get_meta("is_leader", false)
	
	var is_delivery_recipient: bool = closest_node.get_meta("is_delivery_recipient", false)
	var json_path: String = ""

	if is_delivery_recipient or "Delivery" in char_name:
		json_path = "res://scripts/delivery_contact.json"
	elif "Dodgy" in char_name or is_dodgy_meta:
		json_path = "res://scripts/mr_dodgy.json"
	elif is_gang_meta:
		json_path = "res://scripts/gang_leader.json" if is_leader else "res://scripts/gang_member.json"
	elif "Fixer" in char_name:
		json_path = "res://scripts/fixer.json"
	elif "NarrowStreet" in char_name:
		json_path = "res://scripts/narrow_street_resident.json"
	elif "Dancer" in char_name:
		json_path = "res://scripts/park_dancer.json"
	elif "Vendor" in char_name:
		json_path = "res://scripts/street_vendor.json"
	elif "Busker" in char_name:
		json_path = "res://scripts/street_busker.json"
	elif "Tech" in char_name:
		json_path = "res://scripts/tech_drone.json"
	elif "Jogger" in char_name:
		json_path = "res://scripts/cyber_jogger.json"

	if json_path != "" and FileAccess.file_exists(json_path):
		print("[DIALOGUE INTERACT] Launching dialogue JSON: ", json_path)
		var start_node: String = "start"
		
		# Check if player is already running an active quest in QuestManager
		var quest_mgr = get_parent().get_node_or_null("QuestManager")
		var has_active_quest: bool = is_instance_valid(quest_mgr) and quest_mgr.active_quest_id != ""

		if is_gang_meta and is_leader and has_active_quest:
			# Snarky refusal: gang leader refuses new job request while player is already on a mission!
			start_node = "busy_with_quest"
		elif is_delivery_recipient:
			# Check proximity & headlight orientation of player car relative to recipient
			if is_instance_valid(player_car) and not player_car.is_on_foot:
				var dist_to_contact: float = player_car.global_position.distance_to(closest_node.global_position)
				if dist_to_contact < 14.0:
					var car_facing: Vector3 = -player_car.global_transform.basis.z
					var dir_to_contact: Vector3 = (closest_node.global_position - player_car.global_position).normalized()
					if car_facing.dot(dir_to_contact) > 0.6:
						start_node = "blinded"
		
		# Set dynamic gang leader speaker display name based on faction (Red Crows, Blue Seagulls, etc.)
		if is_gang_meta and closest_node.has_meta("gang_faction_name"):
			var f_name: String = closest_node.get_meta("gang_faction_name", "RED CROWS")
			var leader_tag: String = " LEADER" if is_leader else " MEMBER"
			dialogue_sys.start_dialogue(json_path, start_node)
			if is_instance_valid(dialogue_sys._speaker_name_label):
				dialogue_sys._speaker_name_label.text = f_name + leader_tag
			return true

		dialogue_sys.start_dialogue(json_path, start_node)
		return true

	# Fallback generic citizen dialogue dictionary if no specific JSON file exists
	var fallback_dict: Dictionary = {
		"speaker_display_name": char_name.to_upper(),
		"speaker_subtitle": "CYBERPUNK CITIZEN",
		"speaker_color": "#00FFD5",
		"nodes": {
			"start": {
				"text": "Yeah? What do you want, stranger?",
				"choices": [
					{
						"text": "[OK]",
						"target": "exit"
					}
				]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(fallback_dict)
	return true
