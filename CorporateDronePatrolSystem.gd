extends Node

# ==============================================================================
# CORPORATE DRONE PATROL SYSTEM (CorporateDronePatrolSystem.gd)
# ==============================================================================
# Manages aerial corporate surveillance drone patrols flying along street corridors,
# scanning alleyways with spotlights, and detecting illegal player vehicle tech.

@export var corporate_drone_patrol_count: int = 5
@export var drone_cruising_altitude: float = 14.0
@export var drone_flight_speed: float = 8.5
@export var spotlight_detection_radius: float = 7.5

@onready var player_car_node = $"../PlayerCar"
@onready var city_generator_node = $"../CityGenerator"

var active_corporate_patrol_drones: Array[Node3D] = []

func _ready() -> void:
	call_deferred("_initialize_corporate_drone_patrols")

func _initialize_corporate_drone_patrols() -> void:
	if not is_instance_valid(city_generator_node):
		return

	var street_x_coordinates: Array[float] = city_generator_node.active_x_streets
	var street_z_coordinates: Array[float] = city_generator_node.active_z_streets

	if street_x_coordinates.size() == 0 or street_z_coordinates.size() == 0:
		return

	for drone_index in range(corporate_drone_patrol_count):
		var initial_x_coordinate: float = street_x_coordinates[drone_index % street_x_coordinates.size()]
		var initial_z_coordinate: float = street_z_coordinates[drone_index % street_z_coordinates.size()]
		var initial_drone_position = Vector3(initial_x_coordinate, drone_cruising_altitude, initial_z_coordinate)

		var single_drone_root = _construct_surveillance_drone_mesh_and_lights(initial_drone_position)
		add_child(single_drone_root)
		active_corporate_patrol_drones.append(single_drone_root)

func _construct_surveillance_drone_mesh_and_lights(spawn_world_position: Vector3) -> Node3D:
	var drone_root_node = Node3D.new()
	drone_root_node.name = "CorporateSurveillanceDrone"
	drone_root_node.position = spawn_world_position

	# Store custom drone state in metadata
	drone_root_node.set_meta("patrol_target_position", spawn_world_position)
	drone_root_node.set_meta("alley_scan_timer", 0.0)
	drone_root_node.set_meta("is_player_suspicious", false)

	# 1. Main Drone Chassis Mesh (Sleek Stealth Hex Box)
	var drone_chassis_instance = MeshInstance3D.new()
	drone_chassis_instance.name = "DroneChassisMesh"
	var chassis_box_mesh = BoxMesh.new()
	chassis_box_mesh.size = Vector3(1.6, 0.4, 1.6)
	drone_chassis_instance.mesh = chassis_box_mesh

	var chassis_material = StandardMaterial3D.new()
	chassis_material.albedo_color = Color(0.04, 0.05, 0.08) # Corporate matte black
	chassis_material.metallic = 0.9
	chassis_material.roughness = 0.2
	drone_chassis_instance.material_override = chassis_material
	drone_root_node.add_child(drone_chassis_instance)

	# 2. Glowing Status LED Strips (Cyan Ambient / Red Hostile)
	var status_led_mesh_instance = MeshInstance3D.new()
	status_led_mesh_instance.name = "DroneStatusLEDMesh"
	var led_ring_box_mesh = BoxMesh.new()
	led_ring_box_mesh.size = Vector3(1.7, 0.1, 1.7)
	status_led_mesh_instance.mesh = led_ring_box_mesh

	var led_material = StandardMaterial3D.new()
	var cyan_color = Color(0.0, 0.8, 1.0)
	led_material.albedo_color = cyan_color
	led_material.emission_enabled = true
	led_material.emission = cyan_color
	led_material.emission_energy_multiplier = 5.0
	status_led_mesh_instance.material_override = led_material
	drone_root_node.add_child(status_led_mesh_instance)

	# 3. Downward Corporate Spotlight Scan Cone
	var surveillance_spotlight = SpotLight3D.new()
	surveillance_spotlight.name = "SurveillanceSpotLight"
	surveillance_spotlight.position = Vector3(0.0, -0.2, 0.0)
	surveillance_spotlight.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # Point straight down
	surveillance_spotlight.light_color = Color(0.1, 0.7, 1.0)
	surveillance_spotlight.light_energy = 16.0
	surveillance_spotlight.spot_range = 22.0
	surveillance_spotlight.spot_angle = 35.0
	surveillance_spotlight.light_volumetric_fog_energy = 2.5 # Visible volumetric scan beam
	drone_root_node.add_child(surveillance_spotlight)

	return drone_root_node

func _process(delta_time_step: float) -> void:
	if not is_instance_valid(city_generator_node) or active_corporate_patrol_drones.size() == 0:
		return

	var street_x_coordinates: Array[float] = city_generator_node.active_x_streets
	var street_z_coordinates: Array[float] = city_generator_node.active_z_streets

	if street_x_coordinates.size() == 0 or street_z_coordinates.size() == 0:
		return

	for drone_instance in active_corporate_patrol_drones:
		if not is_instance_valid(drone_instance):
			continue

		var current_drone_position: Vector3 = drone_instance.position
		var patrol_target_position: Vector3 = drone_instance.get_meta("patrol_target_position")
		var alley_scan_timer: float = drone_instance.get_meta("alley_scan_timer")

		# Handle Alley Inspection Hover Pause
		if alley_scan_timer > 0.0:
			alley_scan_timer -= delta_time_step
			drone_instance.set_meta("alley_scan_timer", alley_scan_timer)
			# Gently wobble spotlight during inspection
			var spotlight_node: SpotLight3D = drone_instance.get_node_or_null("SurveillanceSpotLight")
			if is_instance_valid(spotlight_node):
				spotlight_node.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.003) * 12.0
			continue

		# Move Drone toward patrol target
		var horizontal_distance_to_target = Vector2(patrol_target_position.x - current_drone_position.x, patrol_target_position.z - current_drone_position.z)
		if horizontal_distance_to_target.length() < 2.0:
			# Target reached — pick next street intersection along current street axis to prevent diagonal cuts across buildings!
			if randf() < 0.35:
				# Pause for 3 seconds over alley/street intersection to perform scan
				drone_instance.set_meta("alley_scan_timer", 3.0)
			else:
				# 50% chance to travel along X street corridor, 50% along Z street corridor (Manhattan street grid navigation)
				var new_target_position = Vector3.ZERO
				if randf() < 0.5:
					# Keep Z current, pick new X along street
					var next_x_coord: float = street_x_coordinates[randi() % street_x_coordinates.size()]
					new_target_position = Vector3(next_x_coord, drone_cruising_altitude, current_drone_position.z)
				else:
					# Keep X current, pick new Z along street
					var next_z_coord: float = street_z_coordinates[randi() % street_z_coordinates.size()]
					new_target_position = Vector3(current_drone_position.x, drone_cruising_altitude, next_z_coord)

				drone_instance.set_meta("patrol_target_position", new_target_position)
		else:
			var movement_direction_vector = Vector3(horizontal_distance_to_target.x, 0.0, horizontal_distance_to_target.y).normalized()
			drone_instance.position += movement_direction_vector * drone_flight_speed * delta_time_step
			drone_instance.look_at(drone_instance.position + movement_direction_vector, Vector3.UP)

		# Check for Player Vehicle Detection under spotlight beam
		if is_instance_valid(player_car_node):
			var distance_to_player_vehicle = Vector2(current_drone_position.x - player_car_node.global_position.x, current_drone_position.z - player_car_node.global_position.z).length()
			var spotlight_node: SpotLight3D = drone_instance.get_node_or_null("SurveillanceSpotLight")
			var status_led_mesh: MeshInstance3D = drone_instance.get_node_or_null("DroneStatusLEDMesh")

			if distance_to_player_vehicle < spotlight_detection_radius:
				# Locked onto player vehicle! Transition to hostile red alert scan
				if is_instance_valid(spotlight_node):
					spotlight_node.light_color = Color(1.0, 0.05, 0.1) # Hostile Alert Red
				if is_instance_valid(status_led_mesh):
					var red_led_material = StandardMaterial3D.new()
					red_led_material.albedo_color = Color(1.0, 0.1, 0.1)
					red_led_material.emission_enabled = true
					red_led_material.emission = Color(1.0, 0.1, 0.1)
					red_led_material.emission_energy_multiplier = 8.0
					status_led_mesh.material_override = red_led_material
			else:
				# Normal scanning state (Cyan)
				if is_instance_valid(spotlight_node):
					spotlight_node.light_color = Color(0.1, 0.7, 1.0)
				if is_instance_valid(status_led_mesh):
					var cyan_led_material = StandardMaterial3D.new()
					cyan_led_material.albedo_color = Color(0.0, 0.8, 1.0)
					cyan_led_material.emission_enabled = true
					cyan_led_material.emission = Color(0.0, 0.8, 1.0)
					cyan_led_material.emission_energy_multiplier = 5.0
					status_led_mesh.material_override = cyan_led_material
