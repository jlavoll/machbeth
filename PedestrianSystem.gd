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

# Mesh templates
var body_mesh_template: CapsuleMesh
var head_mesh_template: SphereMesh

@onready var player_car = $"../PlayerCar"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Neon color palette for pedestrian emission shaders
var neon_colors: Array[Color] = [
	Color(0.0, 0.85, 1.0),  # Cyan
	Color(1.0, 0.0, 0.8),   # Hot Magenta
	Color(1.0, 0.8, 0.0),   # Amber Yellow
	Color(0.2, 1.0, 0.4)    # Emerald Green
]

# ==============================================================================
# INITIALIZATION & TEMPLATES
# ==============================================================================

func _ready() -> void:
	rng.randomize()
	_create_pedestrian_templates()
	_spawn_initial_pedestrians()

func _create_pedestrian_templates() -> void:
	# Slim Cylinder/Capsule Body (0.3m diameter, 1.2m tall)
	body_mesh_template = CapsuleMesh.new()
	body_mesh_template.radius = 0.15
	body_mesh_template.height = 1.2

	# Glowing Head Sphere (0.3m diameter)
	head_mesh_template = SphereMesh.new()
	head_mesh_template.radius = 0.18
	head_mesh_template.height = 0.36

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
			spawn_pos = player_car.global_position + Vector3(cos(angle) * test_dist, 0.0, sin(angle) * test_dist)

		# Direct geometric AABB check against active river boxes
		if is_instance_valid(city_gen) and city_gen.has_method("_is_position_in_water"):
			if not city_gen._is_position_in_water(spawn_pos):
				valid_spawn = true
		else:
			valid_spawn = true

	ped_node.global_position = spawn_pos

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

func _process(delta: float) -> void:
	if not is_instance_valid(player_car):
		return

	var player_pos: Vector3 = player_car.global_position

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

					# Filter out Parking Lots, Parks, CyberRivers, and Trees
					var is_park_or_lot: bool = false
					if "ParkingLot" in collider.name or "Park" in collider.name or "River" in collider.name or "Tree" in collider.name:
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
			# --------------------------------------------------------------------------
			var city_vfx = $"../CityVisualEffects"
			var is_darkest_stages: bool = false
			if is_instance_valid(city_vfx) and city_vfx.get("current_city_light_stage") != null:
				# Stage 3: DARK_BUILDINGS, Stage 4: PITCH_BLACK
				is_darkest_stages = (int(city_vfx.current_city_light_stage) >= 3)

			var flashlight_spot = ped.get_node_or_null("Flashlight/FlashlightSpot")
			if is_instance_valid(flashlight_spot):
				var target_energy: float = 6.5 if is_darkest_stages else 0.0
				flashlight_spot.light_energy = move_toward(flashlight_spot.light_energy, target_energy, delta * 15.0)

			# --------------------------------------------------------------------------
			# ANIMATION: NORMAL WALKING BOB VS IMPATIENT AGITATED SHELTER BOPPING
			# --------------------------------------------------------------------------
			var phase: float = ped.get_meta("anim_phase", 0.0)
			if is_sheltered:
				# Fast, impatient jittery/agitated bopping while waiting under building shelter
				phase += delta * 16.0
				ped.set_meta("anim_phase", phase)
				ped.position.y = abs(sin(phase)) * 0.12 + (sin(phase * 0.5) * 0.03)
			else:
				# Standard walking oscillation
				phase += delta * (8.0 if ped.velocity.length() <= walk_speed else 14.0)
				ped.set_meta("anim_phase", phase)
				ped.position.y = abs(sin(phase)) * 0.1
