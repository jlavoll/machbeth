extends Node3D
class_name TrafficSystem

# ==============================================================================
# LOOPING CITY TRAFFIC SYSTEM (TrafficSystem.gd)
# ==============================================================================
# Each car is assigned a fixed 8-waypoint clockwise loop around a city block.
# When it reaches waypoint[last], it resets to waypoint[0] and starts again.
# No continuation logic. No dead ends. No disappearing.
#
# A loop around a city block with corner (X1,Z1) and (X2,Z2):
#
#   North leg ← ← ← ← ← ←
#   ↑  [7]NorthTO  [6]NorthFROM  ↑  ← cars going North on X1 right lane
#   ↑                             ↑
#   [0]EastFROM              [3]SouthTO
#   ↓  East → → → → → →     ↑  South leg
#   [1]EastTO  [2]SouthFROM  ↑
#              [4]WestFROM → [5]WestTO
#              West leg
#
# Right-hand lane offsets by direction:
#   East  (+X): offset direction = South (+Z)
#   South (+Z): offset direction = West  (-X)
#   West  (-X): offset direction = North (-Z)
#   North (-Z): offset direction = East  (+X)
# ==============================================================================

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

@export var total_city_cars: int = 30
# Total traffic cars placed citywide at startup. Spread across city blocks.

@export var base_traffic_speed: float = 21.0
# Base speed for commuter pods in m/s.

@export var hauler_speed_multiplier: float = 0.62
# Corporate haulers are slower than commuters.

@export var lane_offset: float = 4.2
# Right-hand lane offset from road centre-line in meters.

@export var waypoint_arrival_radius: float = 3.2
# How close a car must get to a waypoint before it advances (meters).

@export var inter_car_brake_distance: float = 14.0
# Raycast distance ahead to check for a leading car (meters).

@export var inter_car_stop_distance: float = 6.0
# Full stop distance from the car ahead (meters).

# ------------------------------------------------------------------------------
# INTERNAL STATE
# ------------------------------------------------------------------------------

var _commuter_body_mesh:  BoxMesh
var _hauler_body_mesh:    BoxMesh
var _enforcer_body_mesh:  BoxMesh
var _racer_body_mesh:     BoxMesh
var _van_body_mesh:       BoxMesh
var _limo_body_mesh:      BoxMesh

var active_traffic_cars: Array[Node3D] = []

# Pre-built loop routes: each is Array[Vector3] with 8 waypoints.
# Cars pick one and loop it forever.
var _city_block_loops: Array = []   # Array of Array[Vector3]

@onready var player_car: Node3D    = $"../PlayerCar"
@onready var city_generator: Node3D = $"../CityGenerator"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_rng.randomize()
	_create_vehicle_mesh_templates()
	call_deferred("_on_city_ready")

func _on_city_ready() -> void:
	if not is_instance_valid(city_generator):
		push_warning("[TrafficSystem] CityGenerator not found.")
		return

	var x_streets: Array = city_generator.get("active_x_streets")
	var z_streets: Array = city_generator.get("active_z_streets")

	if x_streets == null or z_streets == null or x_streets.size() < 2 or z_streets.size() < 2:
		push_warning("[TrafficSystem] City street data not ready.")
		return

	_build_all_block_loops(x_streets, z_streets)
	_spawn_all_city_cars()

# ==============================================================================
# 1. BLOCK LOOP ROUTE BUILDING
# ==============================================================================
# For every valid city block (bounded by 4 intersections), build a clockwise
# 8-waypoint loop. A "valid" block has no park/river at any of its 4 corners.

func _build_all_block_loops(x_streets: Array, z_streets: Array) -> void:
	_city_block_loops.clear()

	for ix in range(x_streets.size() - 1):
		for iz in range(z_streets.size() - 1):
			var x1: float = x_streets[ix]
			var x2: float = x_streets[ix + 1]
			var z1: float = z_streets[iz]
			var z2: float = z_streets[iz + 1]

			# Skip blocks where any corner falls in a park, lot, or river
			if _is_blocked(Vector3(x1, 0.5, z1)): continue
			if _is_blocked(Vector3(x2, 0.5, z1)): continue
			if _is_blocked(Vector3(x2, 0.5, z2)): continue
			if _is_blocked(Vector3(x1, 0.5, z2)): continue

			_city_block_loops.append(_make_block_loop(x1, z1, x2, z2))

	print("[TrafficSystem] Built ", _city_block_loops.size(), " city block loops.")

func _make_block_loop(x1: float, z1: float, x2: float, z2: float) -> Array[Vector3]:
	# Clockwise loop: East → South → West → North
	# Each leg has FROM and TO waypoints. Corner transitions (TO → next FROM)
	# are driven naturally as diagonal cuts through the intersection (~5.9m).
	var o: float = lane_offset  # shorthand
	var y: float = 0.5          # ride height

	var loop: Array[Vector3] = [
		Vector3(x1,     y, z1 + o),  # [0] East leg FROM  (= loop restart after North TO)
		Vector3(x2,     y, z1 + o),  # [1] East leg TO
		Vector3(x2 - o, y, z1     ),  # [2] South leg FROM (corner cut after East TO)
		Vector3(x2 - o, y, z2     ),  # [3] South leg TO
		Vector3(x2,     y, z2 - o),  # [4] West leg FROM  (corner cut after South TO)
		Vector3(x1,     y, z2 - o),  # [5] West leg TO
		Vector3(x1 + o, y, z2     ),  # [6] North leg FROM (corner cut after West TO)
		Vector3(x1 + o, y, z1     ),  # [7] North leg TO   (→ next frame: index = 0)
	]
	return loop

func _is_blocked(world_pos: Vector3) -> bool:
	if not is_instance_valid(city_generator):
		return false
	var in_park: bool  = city_generator.has_method("_is_position_in_park_or_lot") and city_generator._is_position_in_park_or_lot(world_pos)
	var in_water: bool = city_generator.has_method("_is_position_in_water")        and city_generator._is_position_in_water(world_pos)
	return in_park or in_water

# ==============================================================================
# 2. MESH TEMPLATES
# ==============================================================================

func _create_vehicle_mesh_templates() -> void:
	# 1. Commuter Pod — compact city runabout
	_commuter_body_mesh = BoxMesh.new()
	_commuter_body_mesh.size = Vector3(1.6, 0.7, 2.2)

	# 2. Corporate Hauler — heavy freight truck
	_hauler_body_mesh = BoxMesh.new()
	_hauler_body_mesh.size = Vector3(2.4, 1.8, 4.5)

	# 3. Enforcer Patrol — law enforcement cruiser, wide and aggressive
	_enforcer_body_mesh = BoxMesh.new()
	_enforcer_body_mesh.size = Vector3(2.0, 0.65, 2.8)

	# 4. Synthwave Racer — ultra-low street racer with wide stance
	_racer_body_mesh = BoxMesh.new()
	_racer_body_mesh.size = Vector3(2.1, 0.45, 2.6)

	# 5. Delivery Van — tall boxy cargo van
	_van_body_mesh = BoxMesh.new()
	_van_body_mesh.size = Vector3(1.8, 1.6, 3.2)

	# 6. Luxury Limo — long low executive transport
	_limo_body_mesh = BoxMesh.new()
	_limo_body_mesh.size = Vector3(1.9, 0.6, 4.2)

# ==============================================================================
# 3. SPAWN ALL CARS
# ==============================================================================

func _spawn_all_city_cars() -> void:
	if _city_block_loops.is_empty():
		push_warning("[TrafficSystem] No valid city block loops — no cars will spawn.")
		return

	# Shuffle loops so cars start on varied blocks
	var shuffled_loops: Array = _city_block_loops.duplicate()
	shuffled_loops.shuffle()

	var cars_placed: int = 0
	var loop_count: int  = shuffled_loops.size()

	for i in range(total_city_cars):
		# Assign loops round-robin so cars spread across the city
		var loop_route: Array[Vector3] = shuffled_loops[i % loop_count]

		# Start each car at a different waypoint in the loop so they don't
		# all clump at the same spot on the same block.
		var start_index: int = (i / loop_count) % loop_route.size()

		_spawn_car_on_loop(loop_route, start_index)
		cars_placed += 1

	print("[TrafficSystem] Spawned ", cars_placed, " looping traffic cars.")

func _spawn_car_on_loop(loop_route: Array[Vector3], start_waypoint_index: int) -> void:
	var car_node := CharacterBody3D.new()
	car_node.name = "TrafficCar"

	# Weighted archetype roll across 6 vehicle types:
	# 35% Commuter | 18% Hauler | 10% Enforcer | 17% Racer | 12% Van | 8% Limo
	var archetype_roll: float = _rng.randf()
	var archetype: String
	var body_mesh: BoxMesh
	var car_body_mat := StandardMaterial3D.new()
	var car_size: Vector3

	if archetype_roll < 0.35:
		archetype = "commuter"
		body_mesh = _commuter_body_mesh
		car_size  = _commuter_body_mesh.size
		car_body_mat.albedo_color               = Color(0.03, 0.03, 0.07)  # Near-black
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(0.0, 0.85, 1.0)    # Cyan strip
		car_body_mat.emission_energy_multiplier = 1.8
	elif archetype_roll < 0.53:
		archetype = "hauler"
		body_mesh = _hauler_body_mesh
		car_size  = _hauler_body_mesh.size
		car_body_mat.albedo_color               = Color(0.08, 0.06, 0.04)  # Dark rust
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(1.0, 0.75, 0.0)    # Amber banner
		car_body_mat.emission_energy_multiplier = 2.2
	elif archetype_roll < 0.63:
		archetype = "enforcer"
		body_mesh = _enforcer_body_mesh
		car_size  = _enforcer_body_mesh.size
		car_body_mat.albedo_color               = Color(0.05, 0.05, 0.06)  # Graphite
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(0.05, 0.4, 1.0)    # Corporate blue
		car_body_mat.emission_energy_multiplier = 1.4
	elif archetype_roll < 0.80:
		archetype = "racer"
		body_mesh = _racer_body_mesh
		car_size  = _racer_body_mesh.size
		car_body_mat.albedo_color               = Color(0.06, 0.02, 0.10)  # Deep purple
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(0.5, 0.0, 1.0)     # Violet underglow
		car_body_mat.emission_energy_multiplier = 2.5
		car_body_mat.metallic                   = 0.9
		car_body_mat.roughness                  = 0.15
	elif archetype_roll < 0.92:
		archetype = "van"
		body_mesh = _van_body_mesh
		car_size  = _van_body_mesh.size
		car_body_mat.albedo_color               = Color(0.06, 0.04, 0.02)  # Dark brown
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(1.0, 0.45, 0.0)    # Orange cargo stripe
		car_body_mat.emission_energy_multiplier = 1.6
	else:
		archetype = "limo"
		body_mesh = _limo_body_mesh
		car_size  = _limo_body_mesh.size
		car_body_mat.albedo_color               = Color(0.02, 0.02, 0.02)  # Jet black
		car_body_mat.emission_enabled           = true
		car_body_mat.emission                   = Color(1.0, 0.82, 0.2)    # Gold trim
		car_body_mat.emission_energy_multiplier = 1.2
		car_body_mat.metallic                   = 1.0
		car_body_mat.roughness                  = 0.05

	var wheel_radius: float  = 0.35
	var body_y_offset: float = wheel_radius * 1.5 + car_size.y * 0.5

	# ---- Body ----
	var body_instance := MeshInstance3D.new()
	body_instance.mesh              = body_mesh
	body_instance.material_override = car_body_mat
	body_instance.position          = Vector3(0.0, body_y_offset, 0.0)
	car_node.add_child(body_instance)

	# ---- Tail-light bar (colour varies by archetype) ----
	var tail_instance := MeshInstance3D.new()
	var tail_box      := BoxMesh.new()
	tail_box.size = Vector3(car_size.x * 0.82, 0.22, 0.14)
	tail_instance.mesh     = tail_box
	tail_instance.position = Vector3(0.0, body_y_offset - car_size.y * 0.25, car_size.z * 0.5 + 0.06)
	var tail_mat           := StandardMaterial3D.new()
	var tail_colour: Color = Color(1.0, 0.0, 0.12)           # Default red
	if archetype == "enforcer":  tail_colour = Color(1.0, 0.0, 0.9)   # Magenta
	elif archetype == "racer":   tail_colour = Color(0.5, 0.0, 1.0)   # Violet
	elif archetype == "van":     tail_colour = Color(1.0, 0.5, 0.0)   # Orange
	elif archetype == "limo":    tail_colour = Color(1.0, 0.75, 0.0)  # Gold
	tail_mat.albedo_color               = tail_colour
	tail_mat.emission_enabled           = true
	tail_mat.emission                   = tail_colour
	tail_mat.emission_energy_multiplier = 5.5
	tail_instance.material_override = tail_mat
	car_node.add_child(tail_instance)

	# ---- Enforcer: roof siren bar (magenta + cyan alternating visually) ----
	if archetype == "enforcer":
		var siren_instance := MeshInstance3D.new()
		var siren_box      := BoxMesh.new()
		siren_box.size = Vector3(car_size.x * 0.55, 0.18, car_size.z * 0.35)
		siren_instance.mesh     = siren_box
		siren_instance.position = Vector3(0.0, body_y_offset + car_size.y * 0.5 + 0.1, -car_size.z * 0.08)
		var siren_mat           := StandardMaterial3D.new()
		siren_mat.albedo_color               = Color(0.05, 0.05, 0.05)
		siren_mat.emission_enabled           = true
		siren_mat.emission                   = Color(1.0, 0.0, 0.85)   # Magenta siren
		siren_mat.emission_energy_multiplier = 6.0
		siren_instance.material_override = siren_mat
		car_node.add_child(siren_instance)

	# ---- Racer: low front spoiler ----
	if archetype == "racer":
		var spoiler_instance := MeshInstance3D.new()
		var spoiler_box      := BoxMesh.new()
		spoiler_box.size = Vector3(car_size.x * 1.1, 0.12, 0.22)
		spoiler_instance.mesh     = spoiler_box
		spoiler_instance.position = Vector3(0.0, wheel_radius * 0.9, -car_size.z * 0.5 - 0.10)
		var spoiler_mat           := StandardMaterial3D.new()
		spoiler_mat.albedo_color               = Color(0.04, 0.0, 0.08)
		spoiler_mat.emission_enabled           = true
		spoiler_mat.emission                   = Color(0.2, 1.0, 0.3)   # Neon green underglow
		spoiler_mat.emission_energy_multiplier = 3.5
		spoiler_instance.material_override = spoiler_mat
		car_node.add_child(spoiler_instance)

	# ---- Van: cargo box on roof ----
	if archetype == "van":
		var cargo_instance := MeshInstance3D.new()
		var cargo_box      := BoxMesh.new()
		cargo_box.size = Vector3(car_size.x * 0.9, car_size.y * 0.55, car_size.z * 0.75)
		cargo_instance.mesh     = cargo_box
		cargo_instance.position = Vector3(0.0, body_y_offset + car_size.y * 0.75, car_size.z * 0.1)
		var cargo_mat           := StandardMaterial3D.new()
		cargo_mat.albedo_color               = Color(0.05, 0.04, 0.02)
		cargo_mat.emission_enabled           = true
		cargo_mat.emission                   = Color(1.0, 0.4, 0.0)    # Orange stripe
		cargo_mat.emission_energy_multiplier = 1.2
		cargo_instance.material_override = cargo_mat
		car_node.add_child(cargo_instance)

	# ---- Limo: cabin section (raised mid-roof) ----
	if archetype == "limo":
		var cabin_instance := MeshInstance3D.new()
		var cabin_box      := BoxMesh.new()
		cabin_box.size = Vector3(car_size.x * 0.82, 0.38, car_size.z * 0.5)
		cabin_instance.mesh     = cabin_box
		cabin_instance.position = Vector3(0.0, body_y_offset + car_size.y * 0.5 + 0.19, -car_size.z * 0.05)
		var cabin_mat           := StandardMaterial3D.new()
		cabin_mat.albedo_color               = Color(0.02, 0.02, 0.02)
		cabin_mat.emission_enabled           = true
		cabin_mat.emission                   = Color(1.0, 0.82, 0.2)   # Gold window trim
		cabin_mat.emission_energy_multiplier = 0.8
		cabin_instance.material_override = cabin_mat
		car_node.add_child(cabin_instance)

	# ---- 4 Cyber Wheels ----
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius    = wheel_radius
	wheel_mesh.bottom_radius = wheel_radius
	wheel_mesh.height        = 0.25
	var wheel_mat  := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.02, 0.02, 0.04)

	var wheel_half_w: float = car_size.x * 0.5 - 0.06
	var wheel_depth:  float = car_size.z * 0.33
	var wheel_positions: Array[Vector3] = [
		Vector3(-wheel_half_w, wheel_radius, -wheel_depth),
		Vector3( wheel_half_w, wheel_radius, -wheel_depth),
		Vector3(-wheel_half_w, wheel_radius,  wheel_depth),
		Vector3( wheel_half_w, wheel_radius,  wheel_depth),
	]
	for wp in wheel_positions:
		var wi := MeshInstance3D.new()
		wi.mesh              = wheel_mesh
		wi.material_override = wheel_mat
		wi.position          = wp
		wi.rotation_degrees  = Vector3(0.0, 0.0, 90.0)
		car_node.add_child(wi)

	# ---- Headlight spot ----
	var headlight := SpotLight3D.new()
	headlight.name        = "TrafficHeadlight"
	headlight.position    = Vector3(0.0, body_y_offset, -car_size.z * 0.5 - 0.12)
	headlight.light_color  = Color(0.9, 0.95, 1.0)
	headlight.light_energy = 0.0
	headlight.spot_range   = 38.0
	headlight.spot_angle   = 34.0
	car_node.add_child(headlight)

	# ---- Collision ----
	car_node.collision_layer = 2
	car_node.collision_mask  = 1 | 2
	var col_node  := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size   = car_size
	col_node.shape   = col_shape
	col_node.position = Vector3(0.0, body_y_offset, 0.0)
	car_node.add_child(col_node)

	# ---- Place on loop ----
	var start_pos: Vector3  = loop_route[start_waypoint_index]
	var next_index: int     = (start_waypoint_index + 1) % loop_route.size()
	var next_pos: Vector3   = loop_route[next_index]

	car_node.global_position = start_pos

	var initial_dir: Vector3 = (next_pos - start_pos)
	initial_dir.y = 0.0
	if initial_dir.length_squared() > 0.001:
		initial_dir = initial_dir.normalized()

	# ---- Metadata ----
	# Speed multipliers per archetype
	var top_speed: float = base_traffic_speed
	match archetype:
		"hauler":   top_speed *= 0.62                          # Slow heavy freight
		"enforcer": top_speed *= _rng.randf_range(1.15, 1.35)  # Fast law enforcement
		"racer":    top_speed *= _rng.randf_range(1.45, 1.75)  # Aggressive street racer
		"van":      top_speed *= _rng.randf_range(0.55, 0.70)  # Slow delivery
		"limo":     top_speed *= _rng.randf_range(0.80, 0.95)  # Smooth executive pace
		_:          top_speed *= 1.0                           # Commuter baseline
	top_speed *= _rng.randf_range(0.92, 1.08)  # Small per-car variance

	car_node.set_meta("archetype",             archetype)
	car_node.set_meta("top_speed",             top_speed)
	car_node.set_meta("loop_route",            loop_route)
	car_node.set_meta("waypoint_index",        next_index)    # Next waypoint to drive toward
	car_node.set_meta("drive_direction",       initial_dir)
	car_node.set_meta("current_bank_roll",     0.0)
	car_node.set_meta("current_nose_pitch",    0.0)
	car_node.set_meta("prev_rotation_y",       0.0)
	car_node.set_meta("headlight_on",          false)
	car_node.set_meta("headlight_delay_timer", 0.0)
	car_node.set_meta("headlight_reaction_lag", _rng.randf_range(0.3, 3.2))
	car_node.set_meta("stuck_timer",           0.0)
	car_node.set_meta("last_progress_pos",     start_pos)

	add_child(car_node)

	if initial_dir.length_squared() > 0.001:
		car_node.look_at(start_pos + initial_dir, Vector3.UP)

	active_traffic_cars.append(car_node)

# ==============================================================================
# 4. PROCESS LOOP
# ==============================================================================

func _process(delta: float) -> void:
	if not is_instance_valid(player_car):
		return

	var city_vfx: Node = get_node_or_null("../CityVisualEffects")
	var is_dark_stage: bool = false
	if is_instance_valid(city_vfx) and "current_city_light_stage" in city_vfx:
		is_dark_stage = city_vfx.current_city_light_stage >= 1

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	for car_idx in range(active_traffic_cars.size() - 1, -1, -1):
		var car: Node3D = active_traffic_cars[car_idx]
		if not is_instance_valid(car):
			active_traffic_cars.remove_at(car_idx)
			continue

		_update_headlights(car, is_dark_stage, delta)

		var move_speed: float = _drive_loop(car, space_state)

		_update_body_dynamics(car, move_speed, delta)

		var drive_dir: Vector3 = car.get_meta("drive_direction", Vector3.FORWARD)
		car.velocity = drive_dir * move_speed
		car.move_and_slide()

		_check_stuck(car, car_idx, delta)

# ==============================================================================
# 5. LOOP DRIVING
# ==============================================================================

func _drive_loop(car: Node3D, space_state: PhysicsDirectSpaceState3D) -> float:
	var loop_route: Array    = car.get_meta("loop_route",     [])
	var waypoint_index: int  = car.get_meta("waypoint_index", 0)
	var top_speed: float     = car.get_meta("top_speed",      base_traffic_speed)
	var car_pos: Vector3     = car.global_position

	if loop_route.is_empty():
		return 0.0

	# Clamp index in case of any edge case
	waypoint_index = waypoint_index % loop_route.size()

	var target_wp: Vector3 = loop_route[waypoint_index]
	target_wp.y = car_pos.y   # Horizontal movement only

	var flat_dist: float = Vector2(car_pos.x - target_wp.x, car_pos.z - target_wp.z).length()

	# Arrived at waypoint — advance to next (wraps around to 0 at end)
	if flat_dist < waypoint_arrival_radius:
		waypoint_index = (waypoint_index + 1) % loop_route.size()
		car.set_meta("waypoint_index", waypoint_index)

		target_wp   = loop_route[waypoint_index]
		target_wp.y = car_pos.y

	# Drive toward current target waypoint
	var raw_dir: Vector3 = target_wp - car_pos
	raw_dir.y = 0.0

	if raw_dir.length_squared() > 0.001:
		var drive_dir: Vector3 = raw_dir.normalized()
		car.set_meta("drive_direction", drive_dir)
		var look_target: Vector3 = car_pos + drive_dir
		look_target.y = car_pos.y
		car.look_at(look_target, Vector3.UP)

	# Braking: forward raycast for cars ahead
	return _calculate_braking_speed(car, top_speed, space_state)

func _calculate_braking_speed(car: Node3D, top_speed: float, space_state: PhysicsDirectSpaceState3D) -> float:
	var drive_dir: Vector3 = car.get_meta("drive_direction", Vector3.FORWARD)
	var ray_origin: Vector3 = car.global_position + Vector3(0.0, 0.6, 0.0)

	var fwd_ray := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + drive_dir * inter_car_brake_distance,
		2,      # Only check Layer 2 (other traffic cars)
		[car]
	)
	var hit = space_state.intersect_ray(fwd_ray)

	if hit and hit.has("collider"):
		var collider = hit["collider"]
		if collider is CharacterBody3D and collider.name == "TrafficCar":
			var gap: float = ray_origin.distance_to(hit["position"])
			if gap < inter_car_stop_distance:
				return 0.0   # Full stop
			var brake_ratio: float = (gap - inter_car_stop_distance) / (inter_car_brake_distance - inter_car_stop_distance)
			return top_speed * clamp(brake_ratio, 0.15, 0.85)

	return top_speed

# ==============================================================================
# 6. BODY DYNAMICS
# ==============================================================================

func _update_body_dynamics(car: Node3D, current_speed: float, delta: float) -> void:
	var car_body: MeshInstance3D = car.get_child(0) as MeshInstance3D
	if not is_instance_valid(car_body):
		return

	var top_speed: float    = car.get_meta("top_speed", base_traffic_speed)
	var prev_rot_y: float   = car.get_meta("prev_rotation_y", car.rotation.y)
	var yaw_delta: float    = (car.rotation.y - prev_rot_y) / max(delta, 0.001)
	car.set_meta("prev_rotation_y", car.rotation.y)

	var speed_ratio: float      = clamp(current_speed / max(top_speed, 0.1), 0.0, 1.2)
	var target_roll: float      = clamp(-yaw_delta * 0.12, -deg_to_rad(7.5), deg_to_rad(7.5)) * speed_ratio
	var target_pitch: float     = deg_to_rad(3.5) if current_speed < (top_speed * 0.35) else 0.0

	var smoothed_roll: float  = lerp(car.get_meta("current_bank_roll",  0.0), target_roll,  delta * 9.0)
	var smoothed_pitch: float = lerp(car.get_meta("current_nose_pitch", 0.0), target_pitch, delta * 9.0)
	car.set_meta("current_bank_roll",  smoothed_roll)
	car.set_meta("current_nose_pitch", smoothed_pitch)
	car_body.rotation.z = smoothed_roll
	car_body.rotation.x = smoothed_pitch

# ==============================================================================
# 7. HEADLIGHTS
# ==============================================================================

func _update_headlights(car: Node3D, is_dark_stage: bool, delta: float) -> void:
	var headlight: SpotLight3D = car.get_node_or_null("TrafficHeadlight") as SpotLight3D
	if not is_instance_valid(headlight):
		return

	var headlight_on: bool   = car.get_meta("headlight_on",          false)
	var delay_timer: float   = car.get_meta("headlight_delay_timer",  0.0)
	var reaction_lag: float  = car.get_meta("headlight_reaction_lag", 1.0)

	if is_dark_stage != headlight_on:
		delay_timer += delta
		car.set_meta("headlight_delay_timer", delay_timer)
		if delay_timer >= reaction_lag:
			car.set_meta("headlight_on",          is_dark_stage)
			car.set_meta("headlight_delay_timer", 0.0)
			headlight.light_energy = 9.0 if is_dark_stage else 0.0
	else:
		car.set_meta("headlight_delay_timer", 0.0)

# ==============================================================================
# 8. STUCK DETECTION
# ==============================================================================
# Sample position every 20 seconds. If the car moved less than 2m in that
# window it is genuinely wedged — teleport it back to its loop start.

const STUCK_SAMPLE_INTERVAL: float = 20.0
const STUCK_MIN_TRAVEL:       float = 2.0

func _check_stuck(car: Node3D, array_idx: int, delta: float) -> void:
	var stuck_timer: float         = car.get_meta("stuck_timer",       0.0) + delta
	var stuck_sample_pos: Vector3  = car.get_meta("last_progress_pos", car.global_position)
	car.set_meta("stuck_timer", stuck_timer)

	if stuck_timer >= STUCK_SAMPLE_INTERVAL:
		var distance_travelled: float = car.global_position.distance_to(stuck_sample_pos)
		if distance_travelled < STUCK_MIN_TRAVEL:
			# Genuinely wedged — teleport back to loop waypoint 0
			var loop_route: Array = car.get_meta("loop_route", [])
			if not loop_route.is_empty():
				car.global_position = loop_route[0]
				car.set_meta("waypoint_index", 1)
			car.set_meta("stuck_timer",       0.0)
			car.set_meta("last_progress_pos", car.global_position)
		else:
			# Moving fine — reset sample window
			car.set_meta("stuck_timer",       0.0)
			car.set_meta("last_progress_pos", car.global_position)
