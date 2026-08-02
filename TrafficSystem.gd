extends Node3D
class_name TrafficSystem

# ==============================================================================
# AMBIENT CITY TRAFFIC SYSTEM WITH ASTAR3D PATHFINDING (TrafficSystem.gd)
# ==============================================================================
# Vehicles are assigned a true AStar3D-calculated path through the city's street
# intersection network. Intersections from CityGenerator are nodes; segments are
# edges. Broadway avenues are weighted lower so commuter traffic prefers them.
# All existing behaviour (headlights, wheels, tilt, bounce, rest, U-turn rules)
# is fully retained and layered on top of the pathfinding movement.

@export var max_ambient_cars: int = 6
@export var spawn_radius_distance: float = 140.0
@export var despawn_radius_distance: float = 270.0
@export var base_traffic_speed: float = 12.0

# Vehicle mesh templates
var commuter_mesh: BoxMesh
var hauler_mesh: BoxMesh
var enforcer_mesh: BoxMesh

# Vehicle pool
var active_traffic_cars: Array[Node3D] = []

# References
@onready var player_car = $"../PlayerCar"
@onready var city_generator = $"../CityGenerator"

# ==============================================================================
# ASTAR3D GRAPH INFRASTRUCTURE
# ==============================================================================
var astar_grid: AStar3D = AStar3D.new()
var grid_node_map: Dictionary = {} # Maps Vector2i(ix, iz) -> AStar point_id
var valid_spawn_node_ids: Array[int] = [] # Pre-filtered drivable AStar node IDs (no parks/water)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ==============================================================================
# HELPER: DUAL-WHISKER OBSTACLE AVOIDANCE STEERING
# ==============================================================================
# Fires three raycasts (centre + left + right whiskers) ahead of the car.
# Returns a lateral avoidance vector to blend into the current drive direction.
func _get_obstacle_avoidance_steering(car: CharacterBody3D, drive_dir: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var car_pos: Vector3 = car.global_position + Vector3(0.0, 0.5, 0.0)
	var car_speed: float = car.get_meta("speed", base_traffic_speed)
	var look_ahead: float = max(8.0, car_speed * 1.2)

	var left_whisker_dir: Vector3 = drive_dir.rotated(Vector3.UP, deg_to_rad(25.0))
	var right_whisker_dir: Vector3 = drive_dir.rotated(Vector3.UP, deg_to_rad(-25.0))

	var q_left = PhysicsRayQueryParameters3D.create(car_pos, car_pos + left_whisker_dir * (look_ahead * 0.7), 1 | 2 | 4, [car])
	var q_right = PhysicsRayQueryParameters3D.create(car_pos, car_pos + right_whisker_dir * (look_ahead * 0.7), 1 | 2 | 4, [car])

	var res_l = space_state.intersect_ray(q_left)
	var res_r = space_state.intersect_ray(q_right)

	var avoid_steering: Vector3 = Vector3.ZERO
	if res_l.size() > 0:
		avoid_steering += drive_dir.cross(Vector3.UP)  # Steer Right (away from left obstacle)
	if res_r.size() > 0:
		avoid_steering -= drive_dir.cross(Vector3.UP)  # Steer Left (away from right obstacle)

	if avoid_steering.length_squared() > 0.001:
		return avoid_steering.normalized()
	return Vector3.ZERO

# ==============================================================================
# HELPER: QUADRATIC BEZIER CORNER INTERPOLATION
# ==============================================================================
# Smooths the car's path direction when transitioning between two AStar segments.
# p0 = previous waypoint, p1 = current corner node, p2 = next waypoint, t = blend [0..1]
func _interpolate_corner(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0: Vector3 = p0.lerp(p1, t)
	var q1: Vector3 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	rng.randomize()
	_create_vehicle_mesh_templates()
	# Defer graph build so CityGenerator finishes spawning streets first
	call_deferred("_build_astar_city_network")

# ==============================================================================
# 1. ASTAR3D CITY NETWORK GENERATION
# ==============================================================================

func _build_astar_city_network() -> void:
	if not is_instance_valid(city_generator):
		push_warning("TrafficSystem: CityGenerator missing. Falling back to basic spawning.")
		_spawn_initial_traffic_pool()
		return

	var x_cuts: Array = city_generator.get("active_x_streets")
	var z_cuts: Array = city_generator.get("active_z_streets")

	if x_cuts == null or z_cuts == null or x_cuts.size() == 0 or z_cuts.size() == 0:
		_spawn_initial_traffic_pool()
		return

	astar_grid.clear()
	grid_node_map.clear()
	valid_spawn_node_ids.clear()

	var broadway_x: float = city_generator.get("active_broadway_x") if city_generator.get("active_broadway_x") != null else -9999.0
	var broadway_z: float = city_generator.get("active_broadway_z") if city_generator.get("active_broadway_z") != null else -9999.0

	var point_id: int = 0

	# Register all street intersections as AStar3D nodes
	for ix in range(x_cuts.size()):
		for iz in range(z_cuts.size()):
			var world_pos: Vector3 = Vector3(x_cuts[ix], 0.5, z_cuts[iz])
			astar_grid.add_point(point_id, world_pos)

			# Broadway avenues get lower weight — AStar3D will prefer them as arterial routes
			var on_broadway: bool = (abs(world_pos.x - broadway_x) < 16.0 or abs(world_pos.z - broadway_z) < 16.0)
			if on_broadway:
				astar_grid.set_point_weight_scale(point_id, 0.6) # Preferred high-speed arterial

			# Disable nodes that fall inside parks, parking lots, or water — cars will never spawn or route here
			var node_is_blocked: bool = false
			if is_instance_valid(city_generator):
				var in_park_or_lot: bool = city_generator.has_method("_is_position_in_park_or_lot") and city_generator._is_position_in_park_or_lot(world_pos)
				var in_water: bool = city_generator.has_method("_is_position_in_water") and city_generator._is_position_in_water(world_pos)
				if in_park_or_lot or in_water:
					astar_grid.set_point_disabled(point_id, true)
					node_is_blocked = true

			# Track valid spawn nodes (enabled, drivable intersections only)
			if not node_is_blocked:
				valid_spawn_node_ids.append(point_id)

			grid_node_map[Vector2i(ix, iz)] = point_id
			point_id += 1

	# Connect adjacent intersection nodes (bidirectional street segments)
	for ix in range(x_cuts.size()):
		for iz in range(z_cuts.size()):
			var current_id: int = grid_node_map[Vector2i(ix, iz)]

			# Connect East (+X) neighbor
			if ix + 1 < x_cuts.size():
				var east_id: int = grid_node_map[Vector2i(ix + 1, iz)]
				astar_grid.connect_points(current_id, east_id, true)

			# Connect South (+Z) neighbor
			if iz + 1 < z_cuts.size():
				var south_id: int = grid_node_map[Vector2i(ix, iz + 1)]
				astar_grid.connect_points(current_id, south_id, true)

	print("[TrafficSystem] AStar3D graph built: ", astar_grid.get_point_count(), " nodes, ", valid_spawn_node_ids.size(), " valid spawn points.")
	_spawn_initial_traffic_pool()

# ==============================================================================
# 2. PATH ROUTING & ASSIGNMENT
# ==============================================================================

# Assigns a fresh AStar3D path from current position to a random distant intersection
# and immediately pre-orients the car toward its first waypoint
func _assign_new_astar_path(car: Node3D) -> void:
	if astar_grid.get_point_count() == 0 or valid_spawn_node_ids.size() < 2:
		return

	var start_id: int = astar_grid.get_closest_point(car.global_position)

	# Pick a random valid destination from pre-filtered drivable nodes
	var dest_id: int = valid_spawn_node_ids[rng.randi() % valid_spawn_node_ids.size()]
	var tries: int = 0
	while dest_id == start_id and tries < 10:
		dest_id = valid_spawn_node_ids[rng.randi() % valid_spawn_node_ids.size()]
		tries += 1

	var path: PackedVector3Array = astar_grid.get_point_path(start_id, dest_id)
	if path.size() > 1:
		car.set_meta("astar_path", path)
		car.set_meta("astar_path_index", 1)

		# Pre-orient car toward its first waypoint immediately (no confused first frame!)
		var first_wp: Vector3 = path[1]
		first_wp.y = car.global_position.y
		var initial_dir: Vector3 = (first_wp - car.global_position)
		initial_dir.y = 0.0
		if initial_dir.length_squared() > 0.01:
			initial_dir = initial_dir.normalized()
			car.set_meta("drive_direction", initial_dir)
			car.look_at(car.global_position + initial_dir, Vector3.UP)

	car.set_meta("is_resting_at_target", false)
	car.set_meta("rest_timer", 0.0)

# ==============================================================================
# 3. MESH SETUP & VEHICLE SPAWNING
# ==============================================================================

func _create_vehicle_mesh_templates() -> void:
	# 1. Commuter Pod (1.6m x 0.7m x 2.0m)
	commuter_mesh = BoxMesh.new()
	commuter_mesh.size = Vector3(1.6, 0.7, 2.0)

	# 2. Corporate Hauler Truck (2.4m x 1.8m x 4.5m)
	hauler_mesh = BoxMesh.new()
	hauler_mesh.size = Vector3(2.4, 1.8, 4.5)

	# 3. Enforcer Patrol Car (1.8m x 0.8m x 2.2m)
	enforcer_mesh = BoxMesh.new()
	enforcer_mesh.size = Vector3(1.8, 0.8, 2.2)

func _spawn_initial_traffic_pool() -> void:
	for i in range(max_ambient_cars):
		_spawn_ambient_car(true)

func _spawn_ambient_car(is_initial_citywide_spawn: bool = false) -> void:
	if not is_instance_valid(player_car):
		return

	var car_node = CharacterBody3D.new()
	car_node.name = "AmbientTrafficCar"

	# Pick vehicle archetype: 70% Commuter, 20% Hauler, 10% Enforcer
	var roll: float = rng.randf()
	var mesh_instance = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	var car_size: Vector3 = Vector3.ZERO

	if roll < 0.7:
		mesh_instance.mesh = commuter_mesh
		car_size = commuter_mesh.size
		mat.albedo_color = Color(0.04, 0.04, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.85, 1.0) # Cyan accent
		mat.emission_energy_multiplier = 1.5
	else: # elif roll < 0.9:  # (Enforcer disabled — 30% hauler for now)
		mesh_instance.mesh = hauler_mesh
		car_size = hauler_mesh.size
		mat.albedo_color = Color(0.08, 0.06, 0.04)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.0) # Amber banner
		mat.emission_energy_multiplier = 2.0
	#else:
	#	# ENFORCER PATROL CAR (re-enable when ready)
	#	mesh_instance.mesh = enforcer_mesh
	#	car_size = enforcer_mesh.size
	#	mat.albedo_color = Color(0.02, 0.02, 0.04)
	#	mat.emission_enabled = true
	#	mat.emission = Color(1.0, 0.0, 0.8) # Neon Pink siren
	#	mat.emission_energy_multiplier = 4.0

	var wheel_radius: float = 0.35
	var wheel_width: float = 0.25
	# Car body elevation: bottom of body rests on top of wheel axles
	var body_y_offset: float = wheel_radius * 1.5 + (car_size.y / 2.0)

	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(0.0, body_y_offset, 0.0)
	car_node.add_child(mesh_instance)

	# --------------------------------------------------------------------------
	# GLOWING RED TAIL-LIGHT BAR (rear bumper)
	# --------------------------------------------------------------------------
	var tail_light_instance = MeshInstance3D.new()
	var tail_box_mesh = BoxMesh.new()
	tail_box_mesh.size = Vector3(car_size.x * 0.85, 0.25, 0.15)
	tail_light_instance.mesh = tail_box_mesh
	tail_light_instance.position = Vector3(0.0, body_y_offset - (car_size.y / 4.0), car_size.z / 2.0 + 0.05)
	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(1.0, 0.0, 0.1)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.0, 0.15)
	tail_mat.emission_energy_multiplier = 5.0
	tail_light_instance.material_override = tail_mat
	car_node.add_child(tail_light_instance)

	# --------------------------------------------------------------------------
	# 4 CYBER WHEELS (mounted at ground level Y = wheel_radius)
	# --------------------------------------------------------------------------
	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = wheel_radius
	wheel_mesh.bottom_radius = wheel_radius
	wheel_mesh.height = wheel_width

	var wheel_mat = StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.02, 0.02, 0.04)

	var wheel_y_offset: float = wheel_radius
	var wheel_offset_half_width: float = car_size.x / 2.0 - (wheel_width / 4.0)
	var wheel_offset_half_depth: float = car_size.z / 3.0

	var wheel_positions: Array[Vector3] = [
		Vector3(-wheel_offset_half_width, wheel_y_offset, -wheel_offset_half_depth), # Front Left
		Vector3(wheel_offset_half_width,  wheel_y_offset, -wheel_offset_half_depth), # Front Right
		Vector3(-wheel_offset_half_width, wheel_y_offset,  wheel_offset_half_depth), # Rear Left
		Vector3(wheel_offset_half_width,  wheel_y_offset,  wheel_offset_half_depth)  # Rear Right
	]
	for wheel_pos in wheel_positions:
		var wheel_inst = MeshInstance3D.new()
		wheel_inst.mesh = wheel_mesh
		wheel_inst.material_override = wheel_mat
		wheel_inst.position = wheel_pos
		wheel_inst.rotation_degrees = Vector3(0.0, 0.0, 90.0) # Cylinder horizontal along axle
		car_node.add_child(wheel_inst)

	# --------------------------------------------------------------------------
	# HEADLIGHT SpotLight3D (randomized reaction lag for dark-stage activation)
	# --------------------------------------------------------------------------
	var spot = SpotLight3D.new()
	spot.name = "TrafficCarSpotLight"
	spot.position = Vector3(0.0, body_y_offset, -car_size.z / 2.0 - 0.1)
	spot.light_color = Color(0.9, 0.95, 1.0)
	spot.light_energy = 0.0
	spot.spot_range = 35.0
	spot.spot_angle = 35.0
	car_node.add_child(spot)

	# Collision: Layer 2 (Traffic), Mask: 1 (World) + 2 (Traffic) + 4 (Obstacles)
	car_node.collision_layer = 2
	car_node.collision_mask = 1 | 2 | 4
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = car_size
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, body_y_offset, 0.0)
	car_node.add_child(col_shape)

	# Snap spawn position directly onto a pre-validated drivable AStar intersection node
	var spawn_pos: Vector3 = Vector3.ZERO
	if valid_spawn_node_ids.size() > 0:
		# Pick a random pre-filtered valid node — guaranteed clean intersection, no parks or water
		var spawn_node_id: int = valid_spawn_node_ids[rng.randi() % valid_spawn_node_ids.size()]
		spawn_pos = astar_grid.get_point_position(spawn_node_id)
		spawn_pos.y = 0.0 # Ground level
	elif is_instance_valid(player_car):
		# Fallback only if AStar graph not yet ready
		var rand_angle: float = rng.randf_range(0, TAU)
		spawn_pos = player_car.global_position + Vector3(cos(rand_angle) * spawn_radius_distance, 0.0, sin(rand_angle) * spawn_radius_distance)

	car_node.global_position = spawn_pos

	# Per-car metadata
	var archetype: String = "commuter" if roll < 0.7 else "hauler" # "enforcer" disabled — see commented spawn block above
	car_node.set_meta("archetype", archetype)
	car_node.set_meta("speed", base_traffic_speed * rng.randf_range(0.8, 1.2))
	car_node.set_meta("headlight_reaction_delay", rng.randf_range(0.4, 3.5))
	car_node.set_meta("headlight_timer", 0.0)
	car_node.set_meta("headlights_on", false)
	car_node.set_meta("current_bank_roll", 0.0) # Smoothed body roll
	car_node.set_meta("current_pitch", 0.0)     # Smoothed nose pitch
	car_node.set_meta("stuck_timer", 0.0)
	car_node.set_meta("stuck_recovery_stage", 0)
	car_node.set_meta("astar_path", PackedVector3Array())
	car_node.set_meta("astar_path_index", 0)
	car_node.set_meta("is_resting_at_target", false)
	car_node.set_meta("rest_timer", 0.0)
	# Drive direction initially forward (will snap to first AStar path segment on first frame)
	car_node.set_meta("drive_direction", Vector3.FORWARD)
	car_node.set_meta("prev_rot_y", 0.0)
	car_node.set_meta("corner_blend_t", 0.0) # Bezier corner interpolation progress

	add_child(car_node)
	spot.rotation_degrees = Vector3(0.0, 0.0, 0.0) # Headlight faces forward local -Z

	# Assign initial AStar path immediately if graph is ready
	if astar_grid.get_point_count() > 0:
		_assign_new_astar_path(car_node)
	else:
		car_node.look_at(car_node.global_position + car_node.get_meta("drive_direction"), Vector3.UP)

	active_traffic_cars.append(car_node)

# ==============================================================================
# 4. PROCESS LOOP
# ==============================================================================

func _process(delta: float) -> void:
	if not is_instance_valid(player_car):
		return

	var player_pos: Vector3 = player_car.global_position

	# Determine if city lighting is in a dark stage for headlight management
	var vfx_node = $"../CityVisualEffects"
	var is_dark_stage: bool = false
	if is_instance_valid(vfx_node) and "current_city_light_stage" in vfx_node:
		is_dark_stage = vfx_node.current_city_light_stage >= 1

	for i in range(active_traffic_cars.size() - 1, -1, -1):
		var car = active_traffic_cars[i]
		if not is_instance_valid(car):
			active_traffic_cars.remove_at(i)
			continue

		# ------------------------------------------------------------------
		# HEADLIGHT REACTION LAG (randomized delay before turning on/off)
		# ------------------------------------------------------------------
		var spot_light: SpotLight3D = car.get_node_or_null("TrafficCarSpotLight") as SpotLight3D
		var headlights_on: bool = car.get_meta("headlights_on", false)
		var hl_delay: float = car.get_meta("headlight_reaction_delay", 1.0)
		var hl_timer: float = car.get_meta("headlight_timer", 0.0)

		if is_dark_stage != headlights_on:
			hl_timer += delta
			car.set_meta("headlight_timer", hl_timer)
			if hl_timer >= hl_delay:
				car.set_meta("headlights_on", is_dark_stage)
				car.set_meta("headlight_timer", 0.0)
				if is_instance_valid(spot_light):
					spot_light.light_energy = 8.0 if is_dark_stage else 0.0
		else:
			car.set_meta("headlight_timer", 0.0)

		var car_pos: Vector3 = car.global_position
		var distance_to_player: float = car_pos.distance_to(player_pos)
		var is_out_of_bounds: bool = abs(car_pos.x) > 250.0 or abs(car_pos.z) > 250.0

		# Despawn / recycle cars that drift too far or exit city bounds
		if distance_to_player > despawn_radius_distance or is_out_of_bounds:
			car.queue_free()
			active_traffic_cars.remove_at(i)
			_spawn_ambient_car()
			continue

		var base_speed: float = car.get_meta("speed", base_traffic_speed)
		var current_speed: float = base_speed
		var space_state = get_world_3d().direct_space_state

		# ------------------------------------------------------------------
		# 1. ASTAR3D PATH FOLLOWING — Drive from waypoint to waypoint
		# ------------------------------------------------------------------
		var is_resting: bool = car.get_meta("is_resting_at_target", false)
		if is_resting:
			# Destination rest pause (2.5 seconds parked)
			var rest_timer: float = car.get_meta("rest_timer", 0.0) + delta
			car.set_meta("rest_timer", rest_timer)
			if rest_timer >= 2.5:
				_assign_new_astar_path(car)
			else:
				current_speed = 0.0

		var astar_path: PackedVector3Array = car.get_meta("astar_path", PackedVector3Array())
		var path_idx: int = car.get_meta("astar_path_index", 0)

		# If path exhausted, assign a new route (triggers rest pause first via _assign_new_astar_path)
		if astar_path.size() == 0 or path_idx >= astar_path.size():
			if not is_resting:
				car.set_meta("is_resting_at_target", true)
				car.set_meta("rest_timer", 0.0)
				current_speed = 0.0
		else:
			var target_waypoint: Vector3 = astar_path[path_idx]
			target_waypoint.y = car_pos.y # Horizontal movement only

			# Arrived at current waypoint — advance to next
			if car_pos.distance_to(target_waypoint) < 3.5:
				path_idx += 1
				car.set_meta("astar_path_index", path_idx)

				if path_idx >= astar_path.size():
					# Reached final destination — begin rest pause
					car.set_meta("is_resting_at_target", true)
					car.set_meta("rest_timer", 0.0)
					current_speed = 0.0
				else:
					target_waypoint = astar_path[path_idx]
					target_waypoint.y = car_pos.y

			# Compute drive direction toward next waypoint with Bezier corner smoothing
			if path_idx < astar_path.size() and not is_resting:
				var raw_drive_dir: Vector3 = (target_waypoint - car_pos)
				raw_drive_dir.y = 0.0
				if raw_drive_dir.length_squared() > 0.01:
					var drive_dir_towards_wp: Vector3 = raw_drive_dir.normalized()

					# Quadratic Bezier corner smoothing when a previous waypoint exists
					if path_idx >= 2:
						var corner_t: float = car.get_meta("corner_blend_t", 0.0)
						corner_t = clamp(corner_t + delta * 3.5, 0.0, 1.0) # Blend speed
						car.set_meta("corner_blend_t", corner_t)
						var p0: Vector3 = astar_path[path_idx - 2]
						var p1: Vector3 = astar_path[path_idx - 1]
						var p2: Vector3 = target_waypoint
						var bezier_target: Vector3 = _interpolate_corner(p0, p1, p2, corner_t)
						bezier_target.y = car_pos.y
						var bezier_dir: Vector3 = (bezier_target - car_pos).normalized()
						if bezier_dir.length_squared() > 0.01:
							drive_dir_towards_wp = bezier_dir
					else:
						car.set_meta("corner_blend_t", 0.0) # Reset for next corner

					car.set_meta("drive_direction", drive_dir_towards_wp)
					car.look_at(car.global_position + drive_dir_towards_wp, Vector3.UP)

		var drive_dir: Vector3 = car.get_meta("drive_direction", Vector3.FORWARD)
		var archetype: String = car.get_meta("archetype", "commuter")

		# ------------------------------------------------------------------
		# ENFORCER PURSUIT: Chase player when within 40m
		# ------------------------------------------------------------------
		if archetype == "enforcer" and player_pos.distance_to(car_pos) < 40.0:
			var pursuit_dir: Vector3 = (player_pos - car_pos)
			pursuit_dir.y = 0.0
			if pursuit_dir.length_squared() > 0.01:
				var pursuit_drive: Vector3 = pursuit_dir.normalized()
				car.set_meta("drive_direction", pursuit_drive)
				drive_dir = pursuit_drive
				car.look_at(car.global_position + pursuit_drive, Vector3.UP)
				# Boost enforcer speed during pursuit!
				current_speed = base_speed * 1.4

		# ------------------------------------------------------------------
		# DUAL-WHISKER AVOIDANCE: Blend lateral steering to avoid obstacles
		# ------------------------------------------------------------------
		var avoid_vec: Vector3 = _get_obstacle_avoidance_steering(car, drive_dir, space_state)
		if avoid_vec.length_squared() > 0.001:
			# Blend 35% avoidance into current drive direction so path-following still wins
			var blended_dir: Vector3 = (drive_dir + avoid_vec * 0.35).normalized()
			blended_dir.y = 0.0
			if blended_dir.length_squared() > 0.01:
				drive_dir = blended_dir
				car.set_meta("drive_direction", drive_dir)
				car.look_at(car.global_position + drive_dir, Vector3.UP)

		# ------------------------------------------------------------------
		# 2. RIGHT-HAND LANE CENTERING (Latch onto correct lane within street)
		# ------------------------------------------------------------------
		if is_instance_valid(city_generator) and city_generator.get("active_x_streets") != null:
			var x_cuts: Array = city_generator.active_x_streets
			var z_cuts: Array = city_generator.active_z_streets

			if abs(drive_dir.z) > 0.5:
				# Driving North/South — latch to nearest X street + right-hand lane offset
				var nearest_x: float = car_pos.x
				var min_dx: float = 9999.0
				for x_val in x_cuts:
					var dx: float = abs(car_pos.x - x_val)
					if dx < min_dx:
						min_dx = dx
						nearest_x = x_val
				var lane_target_x: float = nearest_x + (4.0 if drive_dir.z < 0.0 else -4.0)
				car_pos.x = move_toward(car_pos.x, lane_target_x, delta * 3.5)
				car.global_position = car_pos

			elif abs(drive_dir.x) > 0.5:
				# Driving East/West — latch to nearest Z street + right-hand lane offset
				var nearest_z: float = car_pos.z
				var min_dz: float = 9999.0
				for z_val in z_cuts:
					var dz: float = abs(car_pos.z - z_val)
					if dz < min_dz:
						min_dz = dz
						nearest_z = z_val
				var lane_target_z: float = nearest_z + (4.0 if drive_dir.x > 0.0 else -4.0)
				car_pos.z = move_toward(car_pos.z, lane_target_z, delta * 3.5)
				car.global_position = car_pos

		# ------------------------------------------------------------------
		# 3. VEHICLE-TO-VEHICLE BRAKING (Forward whisker raycast, 12m range)
		# ------------------------------------------------------------------
		var forward_query = PhysicsRayQueryParameters3D.create(
			car_pos + Vector3(0.0, 0.5, 0.0),
			car_pos + Vector3(0.0, 0.5, 0.0) + drive_dir * 12.0)
		forward_query.exclude = [car]
		var forward_res = space_state.intersect_ray(forward_query)
		if forward_res and forward_res.has("collider"):
			var hit_node = forward_res["collider"]
			if hit_node is CharacterBody3D:
				var hit_dist: float = car_pos.distance_to(forward_res["position"])
				if hit_dist < 6.0:
					current_speed = 0.0      # Full stop brake
				else:
					current_speed = base_speed * 0.35 # Slow crawl

		# ------------------------------------------------------------------
		# 4. CITY BOUNDARY PERIMETER TURNAROUND (stay inside city, reassign path)
		# ------------------------------------------------------------------
		if abs(car_pos.x) > 215.0 and sign(drive_dir.x) == sign(car_pos.x):
			_assign_new_astar_path(car)
			drive_dir = car.get_meta("drive_direction", Vector3.FORWARD)

		if abs(car_pos.z) > 215.0 and sign(drive_dir.z) == sign(car_pos.z):
			_assign_new_astar_path(car)
			drive_dir = car.get_meta("drive_direction", Vector3.FORWARD)

		# ------------------------------------------------------------------
		# 5. VISUAL BODY DYNAMICS (BANKING ROLL & NOSE PITCH)
		# ------------------------------------------------------------------
		var car_mesh: MeshInstance3D = car.get_child(0) as MeshInstance3D
		if is_instance_valid(car_mesh):
			var prev_rot_y: float = car.get_meta("prev_rot_y", car.rotation.y)
			var yaw_turn_rate: float = (car.rotation.y - prev_rot_y) / delta
			car.set_meta("prev_rot_y", car.rotation.y)

			var speed_ratio: float = clamp(current_speed / base_speed, 0.0, 1.2)
			var target_roll: float = clamp(-yaw_turn_rate * 0.15, -deg_to_rad(8.5), deg_to_rad(8.5)) * speed_ratio
			var target_pitch: float = deg_to_rad(4.0) if current_speed < (base_speed * 0.4) else 0.0

			var current_roll: float = lerp(car.get_meta("current_bank_roll", 0.0), target_roll, delta * 8.0)
			var current_pitch: float = lerp(car.get_meta("current_pitch", 0.0), target_pitch, delta * 8.0)
			car.set_meta("current_bank_roll", current_roll)
			car.set_meta("current_pitch", current_pitch)
			car_mesh.rotation.z = current_roll
			car_mesh.rotation.x = current_pitch

		# ------------------------------------------------------------------
		# 6. MOVEMENT EXECUTION
		# ------------------------------------------------------------------
		car.velocity = drive_dir * current_speed
		var is_colliding: bool = car.move_and_slide()
		var actual_movement: float = car.velocity.length()

		# ------------------------------------------------------------------
		# 7. BUILDING WALL DEFLECTION & COMICAL CAR-TO-CAR BOUNCE
		# ------------------------------------------------------------------
		if is_colliding:
			for collision_idx in range(car.get_slide_collision_count()):
				var slide_collision = car.get_slide_collision(collision_idx)
				var collider = slide_collision.get_collider()

				if is_instance_valid(collider) and collider is StaticBody3D and not ("PlayerCar" in collider.name):
					# Building hit — project drive direction onto wall surface plane (no more grinding!)
					var wall_normal: Vector3 = slide_collision.get_normal()
					wall_normal.y = 0.0
					wall_normal = wall_normal.normalized()

					# Remove the into-wall component; snap result to nearest cardinal axis
					var deflected_dir: Vector3 = (drive_dir - wall_normal * drive_dir.dot(wall_normal)).normalized()
					var cardinal_candidates: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]
					var best_cardinal: Vector3 = deflected_dir
					var best_dot: float = -1.0
					for candidate in cardinal_candidates:
						var d: float = deflected_dir.dot(candidate)
						if d > best_dot:
							best_dot = d
							best_cardinal = candidate

					# Nudge away from wall and re-route via AStar from new position
					car.global_position += wall_normal * 0.3
					car.set_meta("drive_direction", best_cardinal)
					car.look_at(car.global_position + best_cardinal, Vector3.UP)
					_assign_new_astar_path(car) # Get a fresh valid path away from the wall
					break

				elif is_instance_valid(collider) and (collider is CharacterBody3D or "PlayerCar" in collider.name):
					# Vehicle collision — comical elastic bounce!
					var bounce_normal: Vector3 = slide_collision.get_normal()
					var bounce_dir: Vector3 = (bounce_normal + Vector3(rng.randf_range(-0.3, 0.3), 0.2, rng.randf_range(-0.3, 0.3))).normalized()
					var bounce_recoil_speed: float = base_speed * 1.8
					car.global_position += bounce_dir * 0.45
					car.velocity = bounce_dir * bounce_recoil_speed
					var bounce_drive_dir: Vector3 = (drive_dir.bounce(bounce_normal) + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))).normalized()
					car.set_meta("drive_direction", bounce_drive_dir)
					car.look_at(car.global_position + bounce_drive_dir, Vector3.UP)
					break

		# ------------------------------------------------------------------
		# 8. BARRIER STASIS RECOVERY (Multi-stage escape for truly stuck cars)
		# ------------------------------------------------------------------
		if is_colliding and actual_movement < 2.0:
			var stuck_timer: float = car.get_meta("stuck_timer", 0.0) + delta
			car.set_meta("stuck_timer", stuck_timer)

			if stuck_timer >= 2.0:
				var recovery_stage: int = car.get_meta("stuck_recovery_stage", 0)
				if recovery_stage == 0:
					# Stage 1: Hard 90-degree left turn
					var left_turn: Vector3 = Vector3(-drive_dir.z, 0.0, drive_dir.x).normalized()
					car.set_meta("drive_direction", left_turn)
					car.set_meta("stuck_recovery_stage", 1)
					car.set_meta("stuck_timer", 0.0)
					car.look_at(car.global_position + left_turn, Vector3.UP)
				elif recovery_stage == 1:
					# Stage 2: Reassign fresh AStar path from current location
					_assign_new_astar_path(car)
					car.set_meta("stuck_recovery_stage", 2)
					car.set_meta("stuck_timer", 0.0)
				else:
					# Stage 3: Completely wedged — recycle to a fresh spawn point
					car.queue_free()
					active_traffic_cars.remove_at(i)
					_spawn_ambient_car()
		else:
			car.set_meta("stuck_timer", 0.0)
			car.set_meta("stuck_recovery_stage", 0)
