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

# Pedestrian instances pool
var active_pedestrians: Array[Node3D] = []
var active_park_dancers: Array[Node3D] = []

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
	# Personality Roll: 75% Rule-Abiding Citizens (Walk on Sidewalks), 25% Anarchistic Street Roamers
	var is_rule_abiding: bool = (rng.randf() > 0.25)
	ped_node.set_meta("is_rule_abiding", is_rule_abiding)
	ped_node.set_meta("flashlight_on", false)
	ped_node.set_meta("flashlight_delay_timer", 0.0)
	ped_node.set_meta("flashlight_reaction_lag", rng.randf_range(0.3, 3.2))

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

	# Clear existing dancers if any
	for dancer in active_park_dancers:
		if is_instance_valid(dancer):
			dancer.queue_free()
	active_park_dancers.clear()

	var dance_styles: Array[String] = ["CIRCLE", "PARTNERS", "LINE"]
	var style_idx: int = 0

	for park in park_boxes:
		var center_2d: Vector2 = park.get_center()
		var center_pos: Vector3 = Vector3(center_2d.x, 0.0, center_2d.y)
		var style: String = dance_styles[style_idx % dance_styles.size()]
		style_idx += 1

		match style:
			"CIRCLE":
				_spawn_circle_dance_group(center_pos, 8)
			"PARTNERS":
				_spawn_partner_dance_group(center_pos, 3) # 3 couples (6 dancers)
			"LINE":
				_spawn_line_dance_group(center_pos, 6)

		# Spawn a "dodgy character" hanging out under one of the corner streetlamps in the park
		_spawn_dodgy_park_character(park)

func _create_single_dancer(pos: Vector3, neon_color: Color, dance_style: String, group_center: Vector3, index: int, total_count: int) -> CharacterBody3D:
	var ped_node = CharacterBody3D.new()
	ped_node.name = "ParkDancer"
	ped_node.global_position = pos

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
		var dist_to_car: float = dancer.global_position.distance_to(player_pos)
		var is_threatened: bool = dist_to_car < 14.0 and (player_speed > 2.0 or dist_to_car < 6.0)

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
	ped_node.global_position = char_pos

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
	ember_mesh.radius = 0.016
	ember_mesh.height = 0.032
	ember_inst.mesh = ember_mesh
	ember_inst.position = Vector3(0.0, 0.0, 0.045)
	var ember_mat = StandardMaterial3D.new()
	var ember_color: Color = Color(1.0, 0.35, 0.0)
	ember_mat.albedo_color = ember_color
	ember_mat.emission_enabled = true
	ember_mat.emission = ember_color
	ember_mat.emission_energy_multiplier = 8.0
	ember_inst.material_override = ember_mat
	cig_node.add_child(ember_inst)

	# Small Ember Light source
	var ember_light = OmniLight3D.new()
	ember_light.light_color = ember_color
	ember_light.light_energy = 1.5
	ember_light.omni_range = 1.2
	ember_light.position = Vector3(0.0, 0.0, 0.05)
	cig_node.add_child(ember_light)

	# Face towards streetlamp pole / park corner, looking cool & shady
	ped_node.look_at(lamp_pos, Vector3.UP)
	ped_node.rotate_object_local(Vector3.UP, PI) # Back against lamp pole, looking outward into park

	add_child(ped_node)
	active_park_dancers.append(ped_node)
