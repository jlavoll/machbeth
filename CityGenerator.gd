extends Node3D

# ==============================================================================
# CITY METRICS & GENERATION CONFIGURATION
# ==============================================================================
# @export variables allow editing parameters from the Godot Inspector.

# Total width of the city map along the X axis (600 meters)
@export var city_size_x: float = 600.0

# Total depth of the city map along the Z axis (600 meters)
@export var city_size_z: float = 600.0

# Width of the main central avenue (Broadway) in meters (30.0m = 3 full 10m grid lanes)
@export var main_broadway_width: float = 30.0

# Width of standard side streets in meters (20.0m = 2 full 10m grid lanes)
@export var secondary_street_width: float = 20.0

# Sidewalk width inset in meters (5.0m = half 10m grid tile)
@export var sidewalk_width: float = 5.0

# Narrow gap width between buildings inside a block cluster in meters (10.0m = 1 full grid lane)
@export var alley_width: float = 10.0

# Procedural generation seed number (Set to 0 for random city every launch, or enter any integer e.g. 777 for a persistent map!)
@export var city_seed: int = 0

# Random generator instance used for layout calculation
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Track special block bounding boxes for instant geometric safety checks
var active_river_boxes: Array[Rect2] = []
var active_park_boxes: Array[Rect2] = []
var active_lot_boxes: Array[Rect2] = []
var active_food_trucks: Array[Node3D] = []

# Calculated street corridor grid cuts for seed (X & Z coordinates)
var active_x_streets: Array[float] = []
var active_z_streets: Array[float] = []
var active_broadway_x: float = 0.0
var active_broadway_z: float = 0.0
var active_alley_corridors: Array[Dictionary] = []
var active_normal_buildings: Array = []

# Duncan Dynamics HQ & Special Playable Interior Building Tracking
var hq_building_pos: Vector3 = Vector3.ZERO
var hq_door_pos: Vector3 = Vector3.ZERO
var hq_door_node: Node3D = null

var banquo_safehouse_door_pos: Vector3 = Vector3.ZERO
var mack_hideout_door_pos: Vector3 = Vector3.ZERO
var mack_parked_rig_node: Node3D = null
var lady_m_lair_door_pos: Vector3 = Vector3.ZERO
var chop_shop_door_pos: Vector3 = Vector3.ZERO

# Playable Lore Locations Tracking
var porter_pit_door_pos: Vector3 = Vector3.ZERO
var norns_ai_door_pos: Vector3 = Vector3.ZERO
var fife_hq_door_pos: Vector3 = Vector3.ZERO
var bankes_logistics_door_pos: Vector3 = Vector3.ZERO
var power_substation_door_pos: Vector3 = Vector3.ZERO

# ==============================================================================
# INITIALIZATION LOOPS
# ==============================================================================

# Called when the node enters the scene tree
func _ready() -> void:
	generate_city_from_seed(city_seed)

# Listen for 9/0 keys to cycle city seeds in real-time during gameplay
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_0:
			# Key 0: Increase city seed (+1)
			regenerate_city(city_seed + 1)
		elif event.keycode == KEY_9:
			# Key 9: Decrease city seed (-1)
			regenerate_city(city_seed - 1)


# Clears existing city building and streetlight nodes, sets new seed, and rebuilds the city
func regenerate_city(new_seed: int) -> void:
	city_seed = new_seed
	print("[CITY GENERATOR] Regenerating city layout with seed: ", city_seed)
	
	# Remove all existing child nodes (buildings, streetlights, grid meshes)
	for child in get_children():
		child.queue_free()
	
	generate_city_from_seed(city_seed)

func generate_city_from_seed(target_seed: int) -> void:
	active_river_boxes.clear()
	active_park_boxes.clear()
	active_lot_boxes.clear()
	active_food_trucks.clear()
	active_x_streets.clear()
	active_z_streets.clear()
	active_alley_corridors.clear()
	active_normal_buildings.clear()
	hq_building_pos = Vector3.ZERO
	hq_door_pos = Vector3.ZERO
	hq_door_node = null
	banquo_safehouse_door_pos = Vector3.ZERO
	mack_hideout_door_pos = Vector3.ZERO
	lady_m_lair_door_pos = Vector3.ZERO
	chop_shop_door_pos = Vector3.ZERO
	porter_pit_door_pos = Vector3.ZERO
	norns_ai_door_pos = Vector3.ZERO
	fife_hq_door_pos = Vector3.ZERO
	bankes_logistics_door_pos = Vector3.ZERO
	power_substation_door_pos = Vector3.ZERO
	if target_seed != 0:
		rng.seed = target_seed
	else:
		rng.randomize()

	_build_ground_and_grid()
	_generate_city_grid()
	_spawn_exit_points()
	_spawn_food_trucks()
	_eject_entities_from_water()
	
	var ped_system = get_parent().get_node_or_null("PedestrianSystem")
	if is_instance_valid(ped_system):
		if ped_system.has_method("_spawn_park_dance_groups"):
			ped_system.call_deferred("_spawn_park_dance_groups")
		if ped_system.has_method("_spawn_parking_lot_gangs"):
			ped_system.call_deferred("_spawn_parking_lot_gangs")
		if ped_system.has_method("_spawn_narrow_street_residents"):
			ped_system.call_deferred("_spawn_narrow_street_residents")

# Spawns glowing highway exit gates at the 4 city edge boundaries (North, South, East, West)
func _spawn_exit_points() -> void:
	var half_x: float = city_size_x / 2.0
	var half_z: float = city_size_z / 2.0
	
	# Edge road locations (Broadway or central street corridor)
	var exits = [
		{"dir": "NORTH", "pos": Vector3(active_broadway_x, 0.0, -half_z + 10.0), "size": Vector3(30.0, 8.0, 4.0), "color": Color(0.0, 0.85, 1.0)}, # Cyan
		{"dir": "SOUTH", "pos": Vector3(active_broadway_x, 0.0, half_z - 10.0), "size": Vector3(30.0, 8.0, 4.0), "color": Color(1.0, 0.0, 0.8)}, # Magenta
		{"dir": "WEST", "pos": Vector3(-half_x + 10.0, 0.0, active_broadway_z), "size": Vector3(4.0, 8.0, 30.0), "color": Color(0.0, 1.0, 0.4)}, # Emerald
		{"dir": "EAST", "pos": Vector3(half_x - 10.0, 0.0, active_broadway_z), "size": Vector3(4.0, 8.0, 30.0), "color": Color(1.0, 0.8, 0.0)}  # Amber
	]

	for exit_info in exits:
		var gate = Node3D.new()
		gate.name = "ExitPoint_" + exit_info["dir"]
		gate.position = exit_info["pos"]

		# Holographic glowing arch portal mesh
		var arch_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = exit_info["size"]
		arch_mesh.mesh = box
		arch_mesh.position = Vector3(0.0, exit_info["size"].y / 2.0, 0.0)

		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(exit_info["color"].r, exit_info["color"].g, exit_info["color"].b, 0.35)
		mat.emission_enabled = true
		mat.emission = exit_info["color"]
		mat.emission_energy_multiplier = 4.0
		arch_mesh.material_override = mat
		gate.add_child(arch_mesh)

		# Light source for environmental glow
		var light = OmniLight3D.new()
		light.light_color = exit_info["color"]
		light.light_energy = 8.0
		light.omni_range = 25.0
		light.position = Vector3(0.0, exit_info["size"].y / 2.0, 0.0)
		gate.add_child(light)

		add_child(gate)

# Returns edge spawn location in local coordinates given entry direction ("NORTH", "SOUTH", "EAST", "WEST")
func get_edge_spawn_position(entry_from_direction: String) -> Vector3:
	var half_x: float = city_size_x / 2.0 - 25.0
	var half_z: float = city_size_z / 2.0 - 25.0
	
	# If entering from NORTH (exited North boundary), spawn at SOUTH edge
	match entry_from_direction:
		"NORTH":
			return Vector3(active_broadway_x, 1.0, half_z)
		"SOUTH":
			return Vector3(active_broadway_x, 1.0, -half_z)
		"WEST":
			return Vector3(half_x, 1.0, active_broadway_z)
		"EAST":
			return Vector3(-half_x, 1.0, active_broadway_z)
	return Vector3(0.0, 1.0, 0.0)

# Spawns between 2 and 5 cyberpunk food trucks parked along road edges next to parks & parking lots
func _spawn_food_trucks() -> void:
	var num_trucks: int = rng.randi_range(2, 5)
	var scenery_props_script = preload("res://CitySceneryProps.gd")
	var scenery_props = scenery_props_script.new()

	# Combine park and lot boxes for preferred placement
	var target_boxes: Array[Rect2] = []
	target_boxes.append_array(active_park_boxes)
	target_boxes.append_array(active_lot_boxes)

	# Shuffle target boxes to vary placement across seeds
	target_boxes.shuffle()

	var spawned_count: int = 0
	var neon_colors: Array[Color] = [
		Color(0.0, 0.85, 1.0),  # Cyan
		Color(1.0, 0.0, 0.8),   # Magenta
		Color(1.0, 0.8, 0.0),   # Amber
		Color(0.2, 1.0, 0.4)    # Emerald
	]

	# First pass: try placing along park & lot roadside edges
	for box in target_boxes:
		if spawned_count >= num_trucks:
			break

		# Pick a random roadside edge of the box (North, South, East, or West)
		var edge: int = rng.randi() % 4
		var spawn_pos: Vector3 = Vector3.ZERO
		var facing_dir: Vector3 = Vector3.FORWARD

		match edge:
			0: # North Edge (Top side along Z-min)
				spawn_pos = Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.y - 1.8)
				facing_dir = Vector3.RIGHT
			1: # South Edge (Bottom side along Z-max)
				spawn_pos = Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.y + box.size.y + 1.8)
				facing_dir = Vector3.LEFT
			2: # West Edge (Left side along X-min)
				spawn_pos = Vector3(box.position.x - 1.8, 0.0, box.position.y + box.size.y * 0.5)
				facing_dir = Vector3.FORWARD
			3: # East Edge (Right side along X-max)
				spawn_pos = Vector3(box.position.x + box.size.x + 1.8, 0.0, box.position.y + box.size.y * 0.5)
				facing_dir = Vector3.BACK

		# Ensure not placed inside water
		if not _is_position_in_water(spawn_pos):
			var truck_color: Color = neon_colors[rng.randi() % neon_colors.size()]
			var truck_node = scenery_props.create_food_truck(spawn_pos, facing_dir, truck_color)
			add_child(truck_node)
			active_food_trucks.append(truck_node)
			spawned_count += 1

	# Fallback pass: if city has fewer parks/lots than target count, place along main street curbs
	while spawned_count < num_trucks and active_x_streets.size() > 1 and active_z_streets.size() > 1:
		var rx: float = active_x_streets[rng.randi() % active_x_streets.size()] + 4.5
		var rz: float = active_z_streets[rng.randi() % active_z_streets.size()] + 4.5
		var fallback_pos: Vector3 = Vector3(rx, 0.0, rz)
		if not _is_position_in_water(fallback_pos):
			var truck_color: Color = neon_colors[rng.randi() % neon_colors.size()]
			var truck_node = scenery_props.create_food_truck(fallback_pos, Vector3.FORWARD, truck_color)
			add_child(truck_node)
			active_food_trucks.append(truck_node)
			spawned_count += 1

# Checks if PlayerCar, ambient traffic cars, or pedestrians are stuck in CyberRiver water and moves them to safe land
func _eject_entities_from_water() -> void:
	# 1. Eject PlayerCar if stuck in water
	var player_car = $"../PlayerCar"
	if is_instance_valid(player_car):
		if _is_position_in_water(player_car.global_position):
			print("[SAFETY] PlayerCar landed in water on seed change! Relocating to safe ground...")
			player_car.global_position = _find_safe_land_position(player_car.global_position)

	# 2. Eject Ambient Traffic Cars
	var traffic_system = $"../TrafficSystem"
	if is_instance_valid(traffic_system) and traffic_system.get("active_traffic_cars") != null:
		for car in traffic_system.active_traffic_cars:
			if is_instance_valid(car) and _is_position_in_water(car.global_position):
				car.global_position = _find_safe_land_position(car.global_position)

	# 3. Eject Pedestrians
	var pedestrian_system = $"../PedestrianSystem"
	if is_instance_valid(pedestrian_system) and pedestrian_system.get("active_pedestrians") != null:
		for ped in pedestrian_system.active_pedestrians:
			if is_instance_valid(ped) and _is_position_in_water(ped.global_position):
				ped.global_position = _find_safe_land_position(ped.global_position)

	# 4. Eject Food Trucks & Street Noodle Carts
	for truck in active_food_trucks:
		if is_instance_valid(truck) and _is_position_in_water(truck.global_position):
			print("[SAFETY] Relocating Food Truck / Noodle Shop from water to safe land...")
			truck.global_position = _find_safe_land_position(truck.global_position)

# Geometric AABB check against active river boxes
func _is_position_in_water(pos: Vector3) -> bool:
	var point_2d = Vector2(pos.x, pos.z)
	for river_box in active_river_boxes:
		if river_box.has_point(point_2d):
			return true
	return false

# Geometric AABB check against active park and parking lot boxes
func _is_position_in_park_or_lot(pos: Vector3) -> bool:
	var point_2d = Vector2(pos.x, pos.z)
	for park_box in active_park_boxes:
		if park_box.has_point(point_2d):
			return true
	for lot_box in active_lot_boxes:
		if lot_box.has_point(point_2d):
			return true
	return false

# Helper searching outward for a safe land location clear of water
func _find_safe_land_position(start_pos: Vector3) -> Vector3:
	for radius in range(15, 120, 15):
		for angle_deg in range(0, 360, 45):
			var rad: float = deg_to_rad(angle_deg)
			var test_pos: Vector3 = start_pos + Vector3(cos(rad) * radius, 0.0, sin(rad) * radius)
			if not _is_position_in_water(test_pos):
				return test_pos
	return Vector3.ZERO



# ==============================================================================
# Reference to wireframe grid material & instance for overmap visual boost
var grid_mat: StandardMaterial3D = null
var grid_instance: MeshInstance3D = null

# Enables/disables high-contrast glow for tactical overmap satellite view
func set_overmap_boost(active: bool) -> void:
	if is_instance_valid(grid_mat):
		if active:
			grid_mat.emission = Color(0.0, 1.0, 0.85) # High brightness cyan/turquoise
			grid_mat.emission_energy_multiplier = 12.0 # Boosted emission energy for overmap visibility
		else:
			grid_mat.emission = Color(0.0, 0.85, 1.0) # Normal neon cyan
			grid_mat.emission_energy_multiplier = 3.0

# 1. GROUND PLANE & WIREFRAME GRID SYSTEM
# ==============================================================================

# Creates the dark ground plane and draws glowing cyber wireframe grid lines
func _build_ground_and_grid() -> void:
	# --------------------------------------------------------------------------
	# GROUND PLANE MESH SETUP
	# --------------------------------------------------------------------------
	var ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	# Set flat plane size (600m x 600m)
	plane.size = Vector2(city_size_x, city_size_z)
	ground_mesh.mesh = plane
	
	# Position slightly below Y=0 (-0.05m) to avoid z-fighting visual glitches with grid lines
	# Vector3(X=0.0, Y=-0.05, Z=0.0) -> (Horizontal, Height, Depth)
	ground_mesh.position = Vector3(0, -0.05, 0)
	
		# Ground Material: Deep Cyberpunk Asphalt with Discrete Soft Reflections (~20% strength)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.01, 0.008, 0.02)
	ground_mat.roughness = 0.70     # Soft matte diffusion for subtle discrete reflections
	ground_mat.metallic = 0.17      # Toned down metallic sheen (~20% of previous 0.85)
	ground_mat.metallic_specular = 0.18
	ground_mesh.material_override = ground_mat

	# --------------------------------------------------------------------------
	# GROUND STATIC BODY 3D COLLIDER (PREVENTS CAR FROM FALLING THROUGH THE CITY)
	# --------------------------------------------------------------------------
	var ground_body = StaticBody3D.new()
	var ground_col = CollisionShape3D.new()
	var ground_box = BoxShape3D.new()
	ground_box.size = Vector3(city_size_x, 1.0, city_size_z)
	ground_col.shape = ground_box
	ground_body.position = Vector3(0.0, -0.5, 0.0) # Top surface of floor at Y=0.0
	ground_body.add_child(ground_col)
	ground_body.add_child(ground_mesh)
	add_child(ground_body)

	# --------------------------------------------------------------------------
	# WIREFRAME GRID LINES SETUP
	# --------------------------------------------------------------------------
	grid_mat = StandardMaterial3D.new()
	# Base surface color is pure black Color(R=0.0, G=0.0, B=0.0)
	grid_mat.albedo_color = Color(0, 0, 0)
	# Enable self-illumination (glowing bloom effect)
	grid_mat.emission_enabled = true
	# Emission Color(R=0.0, G=0.85, B=1.0) -> Bright Cyan / Neon Blue
	grid_mat.emission = Color(0.0, 0.85, 1.0)
	# Multiplies light intensity by 3.0 for bright glow bloom
	grid_mat.emission_energy_multiplier = 3.0

	# Dynamic line mesh drawer
	var grid_lines = ImmediateMesh.new()
	grid_instance = MeshInstance3D.new()
	grid_instance.mesh = grid_lines
	grid_instance.material_override = grid_mat
	add_child(grid_instance)

	grid_lines.clear_surfaces()
	grid_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Calculate half dimensions (-300 to +300)
	var half_x: float = city_size_x / 2.0
	var half_z: float = city_size_z / 2.0

	# Draw grid lines running along the Z axis spaced every 10 meters along X
	for x in range(int(-half_x), int(half_x) + 1, 10):
		grid_lines.surface_add_vertex(Vector3(x, 0, -half_z))
		grid_lines.surface_add_vertex(Vector3(x, 0, half_z))
	
	# Draw grid lines running along the X axis spaced every 10 meters along Z
	for z in range(int(-half_z), int(half_z) + 1, 10):
		grid_lines.surface_add_vertex(Vector3(-half_x, 0, z))
		grid_lines.surface_add_vertex(Vector3(half_x, 0, z))

	grid_lines.surface_end()

	# --------------------------------------------------------------------------
	# 4 PERIMETER LASER BARRIER COLLISION WALLS (PREVENTS CAR FROM FALLING INTO THE VOID)
	# --------------------------------------------------------------------------
	var wall_thickness: float = 4.0
	var wall_height: float = 20.0

	var wall_configs: Array[Dictionary] = [
		{"pos": Vector3(0.0, wall_height / 2.0, -half_z), "size": Vector3(city_size_x, wall_height, wall_thickness)}, # North Wall
		{"pos": Vector3(0.0, wall_height / 2.0, half_z), "size": Vector3(city_size_x, wall_height, wall_thickness)},  # South Wall
		{"pos": Vector3(-half_x, wall_height / 2.0, 0.0), "size": Vector3(wall_thickness, wall_height, city_size_z)}, # West Wall
		{"pos": Vector3(half_x, wall_height / 2.0, 0.0), "size": Vector3(wall_thickness, wall_height, city_size_z)}   # East Wall
	]

	for cfg in wall_configs:
		var wall_body = StaticBody3D.new()
		wall_body.name = "PerimeterLaserBarrierWall"
		wall_body.position = cfg["pos"]

		var wall_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = cfg["size"]
		wall_shape.shape = box_shape
		wall_body.add_child(wall_shape)

		add_child(wall_body)

# ==============================================================================
# 2. PROCEDURAL BUILDING WINDOW TEXTURE GENERATOR
# ==============================================================================

# Generates a procedural 2D window grid texture with illuminated neon windows
func _generate_window_texture(neon_color: Color) -> Texture2D:
	# Create 32x64 pixel image buffer in RGBA format (32px width, 64px height)
	var img: Image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	# Fill background with dark building wall color: Color(R=0.02, G=0.02, B=0.04) -> Dark Blueish Slate
	img.fill(Color(0.02, 0.02, 0.04))

	# Iterate rows (Y: 4 to 60, step 4) and columns (X: 2 to 30, step 4) to make window grid
	for y in range(4, 60, 4):
		for x in range(2, 30, 4):
			# 65% chance for window to be turned ON/lit up (randf() > 0.35)
			if rng.randf() > 0.35:
				# 80% chance lit window uses neon accent color, 20% chance warm yellow Color(R=1.0, G=0.9, B=0.4)
				var col: Color = neon_color if rng.randf() > 0.2 else Color(1.0, 0.9, 0.4)
				# Draw a 2x2 pixel rectangle for each illuminated window pane
				for dy in range(2):
					for dx in range(2):
						img.set_pixel(x + dx, y + dy, col)

	# Convert raw pixel image into a 3D GPU Texture object
	return ImageTexture.create_from_image(img)

# ==============================================================================
# 3. CITY GRID LAYOUT & STREET NETWORK
# ==============================================================================

# Divides the city into blocks separated by main streets, secondary avenues, parks, rivers, and parking lots
func _generate_city_grid() -> void:
	# Palette of cyberpunk neon colors for building accents & window illumination
	var neon_colors: Array[Color] = [
		Color(0.0, 0.85, 1.0),  # Cyan / Electric Blue
		Color(0.0, 0.4, 1.0),   # Deep Blue
		Color(1.0, 0.0, 0.8),   # Hot Magenta
		Color(1.0, 0.8, 0.0)    # Amber Gold
	]

	# --------------------------------------------------------------------------
	# 1. GRID-ALIGNED STREET CUTS (10m GRID UNITS, 2-LANE 20m STREETS)
	# --------------------------------------------------------------------------
	var half_x_dim: float = city_size_x / 2.0
	var half_z_dim: float = city_size_z / 2.0

	# Dynamically calculate street cuts across the full city map dimensions (90m spacing)
	var base_x_cuts: Array[float] = []
	var cur_x: float = -half_x_dim + 30.0
	while cur_x <= half_x_dim - 30.0:
		base_x_cuts.append(cur_x)
		cur_x += 90.0

	var base_z_cuts: Array[float] = []
	var cur_z: float = -half_z_dim + 30.0
	while cur_z <= half_z_dim - 30.0:
		base_z_cuts.append(cur_z)
		cur_z += 90.0

	var broadway_x_idx: int = rng.randi_range(1, base_x_cuts.size() - 2)
	var broadway_z_idx: int = rng.randi_range(1, base_z_cuts.size() - 2)

	# Strictly grid-aligned street corridors (aligned to 10m grid lines)
	var x_streets: Array[float] = base_x_cuts.duplicate()
	var z_streets: Array[float] = base_z_cuts.duplicate()

	active_x_streets = x_streets
	active_z_streets = z_streets
	active_broadway_x = x_streets[broadway_x_idx]
	active_broadway_z = z_streets[broadway_z_idx]

	# --------------------------------------------------------------------------
	# 2. SEED-DRIVEN SPECIAL DISTRICT ALLOCATION (PARKS, RIVER, PARKING LOTS)
	# --------------------------------------------------------------------------
	var total_cells: int = (x_streets.size() - 1) * (z_streets.size() - 1)
	
	# Determine if this city seed features a Cyber River / Canal running through it (50% chance)
	var has_river: bool = rng.randf() > 0.5
	var river_axis: String = "X" if rng.randf() > 0.5 else "Z" # River runs North-South or East-West
	var river_cell_index: int = rng.randi_range(1, 2) # Which cell column/row is flooded by river

	# Pick 1-2 cells for Cyber Parks with holographic foliage
	var park_count: int = rng.randi_range(1, 2)
	var park_indices: Array[int] = []
	for p in range(park_count):
		park_indices.append(rng.randi_range(0, total_cells - 1))

	# Pick up to 4 cells for Asphalt Parking Lots
	var parking_count: int = rng.randi_range(2, 4)
	var parking_indices: Array[int] = []
	for k in range(parking_count):
		var idx = rng.randi_range(0, total_cells - 1)
		if idx not in park_indices:
			parking_indices.append(idx)

	# --------------------------------------------------------------------------
	# 3. BUILD CITY BLOCKS
	# --------------------------------------------------------------------------
	var current_cell_idx: int = 0
	for ix in range(x_streets.size() - 1):
		for iz in range(z_streets.size() - 1):
			var x_start: float = x_streets[ix]
			var x_end: float = x_streets[ix + 1]
			var z_start: float = z_streets[iz]
			var z_end: float = z_streets[iz + 1]

			var w_left: float   = main_broadway_width if ix == broadway_x_idx else secondary_street_width
			var w_right: float  = main_broadway_width if (ix + 1) == broadway_x_idx else secondary_street_width
			var w_top: float    = main_broadway_width if iz == broadway_z_idx else secondary_street_width
			var w_bottom: float = main_broadway_width if (iz + 1) == broadway_z_idx else secondary_street_width

			var cell_x_min: float = x_start + w_left / 2.0
			var cell_x_max: float = x_end - w_right / 2.0
			var cell_z_min: float = z_start + w_top / 2.0
			var cell_z_max: float = z_end - w_bottom / 2.0

			var cell_width: float = cell_x_max - cell_x_min
			var cell_depth: float = cell_z_max - cell_z_min

			if cell_width > 20.0 and cell_depth > 20.0:
				var center: Vector3 = Vector3((cell_x_min + cell_x_max) / 2.0, 0, (cell_z_min + cell_z_max) / 2.0)
				var size: Vector2 = Vector2(cell_width, cell_depth)

				# Check special features for this block
				# Never place river or skyscraper cluster directly over origin (0,0) where the car spawns at game start
				var overlaps_origin: bool = (abs(center.x) < 35.0 and abs(center.z) < 35.0)
				var is_river_cell: bool = has_river and not overlaps_origin and ((river_axis == "X" and ix == river_cell_index) or (river_axis == "Z" and iz == river_cell_index))

				if is_river_cell:
					_spawn_cyber_river_canal(center, size)
				elif current_cell_idx in park_indices or overlaps_origin:
					# Force origin cell to be an open Cyber Park or Parking Lot so car is never trapped inside a building
					if overlaps_origin:
						_spawn_parking_lot(center, size, neon_colors)
					else:
						_spawn_cyber_park(center, size, neon_colors)
				elif current_cell_idx in parking_indices:
					_spawn_parking_lot(center, size, neon_colors)
				else:
					_create_block_cluster(center, size, neon_colors)

			current_cell_idx += 1

	_ensure_all_special_buildings_placed(neon_colors)

# ==============================================================================
# 4. BLOCK SUBDIVISION & ALLEY LAYOUT
# ==============================================================================

# Subdivides a city block into multiple individual building plots sitting on discrete sidewalks
func _create_block_cluster(center: Vector3, size: Vector2, neon_colors: Array) -> void:
	# --------------------------------------------------------------------------
	# 1. DISCRETE GREY SIDEWALK SLAB WITH GLOWING CURB TRIM
	# --------------------------------------------------------------------------
	var sidewalk_mesh = MeshInstance3D.new()
	var box_slab = BoxMesh.new()
	# Sidewalk covers the entire block area (height 0.1m elevated above Y=0)
	box_slab.size = Vector3(size.x, 0.1, size.y)
	sidewalk_mesh.mesh = box_slab
	sidewalk_mesh.position = center + Vector3(0.0, 0.05, 0.0) # Y=0.05m elevation

	# Discrete Concrete Grey Slate Material
	var sw_mat = StandardMaterial3D.new()
	sw_mat.albedo_color = Color(0.12, 0.13, 0.16) # Discrete Dark Grey Concrete Slate
	sw_mat.roughness = 0.8
	sidewalk_mesh.material_override = sw_mat
	add_child(sidewalk_mesh)

	# Glowing Neon Curb Edge Trim Lines around sidewalk perimeter
	var curb_mat = StandardMaterial3D.new()
	curb_mat.emission_enabled = true
	curb_mat.emission = neon_colors[rng.randi() % neon_colors.size()]
	curb_mat.emission_energy_multiplier = 2.5

	var curb_lines = ImmediateMesh.new()
	var curb_instance = MeshInstance3D.new()
	curb_instance.mesh = curb_lines
	curb_instance.material_override = curb_mat
	curb_instance.position = center + Vector3(0.0, 0.11, 0.0)
	add_child(curb_instance)

	curb_lines.clear_surfaces()
	curb_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var hx: float = size.x / 2.0
	var hz: float = size.y / 2.0
	curb_lines.surface_add_vertex(Vector3(-hx, 0, -hz))
	curb_lines.surface_add_vertex(Vector3(hx, 0, -hz))
	curb_lines.surface_add_vertex(Vector3(hx, 0, -hz))
	curb_lines.surface_add_vertex(Vector3(hx, 0, hz))
	curb_lines.surface_add_vertex(Vector3(hx, 0, hz))
	curb_lines.surface_add_vertex(Vector3(-hx, 0, hz))
	curb_lines.surface_add_vertex(Vector3(-hx, 0, hz))
	curb_lines.surface_add_vertex(Vector3(-hx, 0, -hz))
	curb_lines.surface_end()

	# --------------------------------------------------------------------------
	# 2. GRID-SNAPPED BUILDING PLOTS (WITH ARCHITECTURAL FOOTPRINT VARIATIONS)
	# --------------------------------------------------------------------------
	# Calculate interior building footprint area after 5m (half-grid) sidewalk inset on all sides
	var inner_size_x: float = size.x - (sidewalk_width * 2.0)
	var inner_size_z: float = size.y - (sidewalk_width * 2.0)

	if inner_size_x < 10.0 or inner_size_z < 10.0:
		return

	# Split block into 2 to 3 building plots along X and Z axes
	var num_x: int = 2 if inner_size_x < 60.0 else rng.randi_range(2, 3)
	var num_z: int = 2 if inner_size_z < 60.0 else rng.randi_range(2, 3)

	# Alley gaps (10m = 1 full grid tile)
	var plot_w: float = (inner_size_x - (num_x - 1) * alley_width) / num_x
	var plot_d: float = (inner_size_z - (num_z - 1) * alley_width) / num_z

	# Snap building plot sizes to 10m grid increments
	plot_w = max(10.0, floor(plot_w / 10.0) * 10.0)
	plot_d = max(10.0, floor(plot_d / 10.0) * 10.0)

	var start_x: float = center.x - inner_size_x / 2.0 + plot_w / 2.0
	var start_z: float = center.z - inner_size_z / 2.0 + plot_d / 2.0

	# Record narrow alley corridors inside this block for narrow street resident placement
	if num_x > 1:
		for ix in range(num_x - 1):
			var alley_x: float = start_x + float(ix) * (plot_w + alley_width) + plot_w / 2.0 + alley_width / 2.0
			active_alley_corridors.append({"axis": "Z", "pos_fixed": alley_x, "min": center.z - inner_size_z / 2.0, "max": center.z + inner_size_z / 2.0})

	if num_z > 1:
		for iz in range(num_z - 1):
			var alley_z: float = start_z + float(iz) * (plot_d + alley_width) + plot_d / 2.0 + alley_width / 2.0
			active_alley_corridors.append({"axis": "X", "pos_fixed": alley_z, "min": center.x - inner_size_x / 2.0, "max": center.x + inner_size_x / 2.0})

	# Architectural variation selector per block (0: Standard Grid, 1: Corner Plaza Cutout, 2: L-Tower Split)
	var block_style_variant: int = rng.randi() % 3

	for ix in range(num_x):
		for iz in range(num_z):
			# Option 1: Corner Plaza Cutout (Leave 1 corner plot open for a small pedestrian plaza)
			if block_style_variant == 1 and ix == 0 and iz == 0 and num_x > 1 and num_z > 1:
				continue # Skip plot to create an open corner plaza!

			var b_width: float = plot_w
			var b_depth: float = plot_d
			# Skyscraper height snapped in 10m increments (20m to 90m tall)
			var b_height: float = float(rng.randi_range(2, 9) * 10)

			# Option 2: Setback / L-Shaped Tower (Offset footprint on upper floors or vary width)
			if block_style_variant == 2 and (ix + iz) % 2 == 1 and plot_w >= 20.0:
				b_width -= 10.0 # Creates an asymmetrical L-shaped building alcove!

			var bx: float = start_x + ix * (plot_w + alley_width)
			var bz: float = start_z + iz * (plot_d + alley_width)

			# Determine special interior building designation across 9 distinct map sectors (600m scale)
			var b_type: String = "NORMAL"
			
			# North-West Quadrant (Top-Left): Lady M's Lair
			if lady_m_lair_door_pos == Vector3.ZERO and bx < -50.0 and bz < -50.0:
				b_type = "LADY_M"
			# North-Center Sector (Top-Center): Duncan Dynamics HQ
			elif hq_building_pos == Vector3.ZERO and abs(bx) <= 50.0 and bz < -50.0:
				b_type = "HQ"
			# North-East Quadrant (Top-Right): Norns AI Server Core
			elif norns_ai_door_pos == Vector3.ZERO and bx > 50.0 and bz < -50.0:
				b_type = "NORNS_AI"
			# West-Center Sector (Mid-Left): Bankes Logistics Hub
			elif bankes_logistics_door_pos == Vector3.ZERO and bx < -50.0 and abs(bz) <= 50.0:
				b_type = "BANKES_LOGISTICS"
			# Central Core (Mid-Center): Mack's Hideout & War-Rig Workshop
			elif mack_hideout_door_pos == Vector3.ZERO and abs(bx) <= 50.0 and abs(bz) <= 50.0:
				b_type = "MACK_HIDEOUT"
			# South-East Corner Extreme Outer Boundary (bx > 180.0 & bz > 180.0): Banquo's Private Loft
			elif banquo_safehouse_door_pos == Vector3.ZERO and bx > 180.0 and bz > 180.0:
				b_type = "BANQUO_LOFT"
			# South-East Sector (Bottom-Right Block): Chop Shop Garage
			elif chop_shop_door_pos == Vector3.ZERO and bx > 50.0 and bz > 50.0:
				b_type = "CHOP_SHOP"
			# East-Center Sector (Mid-Right): Clan Fife HQ
			elif fife_hq_door_pos == Vector3.ZERO and bx > 50.0 and abs(bz) <= 50.0:
				b_type = "FIFE_HQ"
			# South-West Quadrant (Bottom-Left): Porter Pit Fight Club
			elif porter_pit_door_pos == Vector3.ZERO and bx < -50.0 and bz > 50.0:
				b_type = "PORTER_PIT"
			# South-Center Sector (Bottom-Center): Power Substation
			elif power_substation_door_pos == Vector3.ZERO and abs(bx) <= 50.0 and bz > 50.0:
				b_type = "SUBSTATION"

			_spawn_building(Vector3(bx, b_height / 2.0 + 0.1, bz), Vector3(b_width, b_height, b_depth), neon_colors, b_type)

# ==============================================================================
# 5. BUILDING SPINNER & 3D MESH/PHYSICS CREATION
# ==============================================================================

# Spawns a 3D skyscraper mesh, collision box, window materials, and rooftop neon wireframe
func _spawn_building(pos: Vector3, b_size: Vector3, neon_colors: Array, b_type: String = "NORMAL") -> void:

	# Create physical rigid block for collisions so player vehicle bounces off
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.position = pos
	if b_type == "HQ":
		static_body.name = "DuncanHQBuilding"
		hq_building_pos = pos

	# 3D Collision Box matching building size (X width, Y height, Z depth)
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = b_size
	col_shape.shape = box_shape
	static_body.add_child(col_shape)

	# 3D Visible Box Mesh
	var building_mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = b_size
	building_mesh.mesh = box_mesh

	# Pick random neon color for building highlights
	var accent_color: Color = neon_colors[rng.randi() % neon_colors.size()]
	if b_type == "HQ":
		accent_color = Color(0.0, 1.0, 0.85) # Cyan HQ
	elif b_type == "HIDEOUT":
		accent_color = Color(1.0, 0.5, 0.0) # Amber Hideout
	elif b_type == "LADY_M":
		accent_color = Color(1.0, 0.0, 0.8) # Magenta Lair
	elif b_type == "CHOP_SHOP":
		accent_color = Color(0.2, 1.0, 0.3) # Green Garage
	elif b_type == "PORTER_PIT":
		accent_color = Color(1.0, 0.3, 0.0) # Dark Rust Orange
	elif b_type == "NORNS_AI":
		accent_color = Color(0.7, 0.1, 1.0) # Phosphor Deep Violet
	elif b_type == "FIFE_HQ":
		accent_color = Color(0.1, 0.5, 1.0) # Cobalt Steel Blue
	elif b_type == "BANKES_LOGISTICS":
		accent_color = Color(0.9, 0.7, 0.1) # Industrial Yellow
	elif b_type == "SUBSTATION":
		accent_color = Color(1.0, 0.9, 0.0) # High-Voltage Yellow Flag

	var win_tex: Texture2D = _generate_window_texture(accent_color)

	# Building Exterior Surface Material (Cyberpunk Metallic Glass & Reflections)
	var b_mat: StandardMaterial3D = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.015, 0.02, 0.04)
	b_mat.metallic = 0.85
	b_mat.roughness = 0.15
	b_mat.metallic_specular = 0.8
	b_mat.emission_enabled = true
	b_mat.emission_texture = win_tex
	b_mat.emission_energy_multiplier = 5.0
	b_mat.uv1_scale = Vector3(1.0, b_size.y / 8.0, 1.0)

	building_mesh.material_override = b_mat
	static_body.add_child(building_mesh)

	# --------------------------------------------------------------------------
	# BUILDING NEON OMNILIGHT (VOLUMETRIC FOG SCATTERING & ATMOSPHERIC GLOW)
	# --------------------------------------------------------------------------
	var building_light: OmniLight3D = OmniLight3D.new()
	building_light.light_color = accent_color
	building_light.light_energy = 3.0
	building_light.light_volumetric_fog_energy = 1.7
	building_light.omni_range = max(b_size.x, b_size.z) * 1.75
	building_light.omni_attenuation = 0.9
	static_body.add_child(building_light)

	# --------------------------------------------------------------------------
	# ROOFTOP NEON BORDER LIGHT LINES
	# --------------------------------------------------------------------------
	var border_mat: StandardMaterial3D = StandardMaterial3D.new()
	border_mat.emission_enabled = true
	border_mat.emission = accent_color
	border_mat.emission_energy_multiplier = 4.5

	var border_mesh: ImmediateMesh = ImmediateMesh.new()
	var border_instance: MeshInstance3D = MeshInstance3D.new()
	border_instance.mesh = border_mesh
	border_instance.material_override = border_mat
	static_body.add_child(border_instance)

	border_mesh.clear_surfaces()
	border_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var hw: float = b_size.x / 2.0
	var hh: float = b_size.y / 2.0
	var hd: float = b_size.z / 2.0

	var corners: Array[Vector3] = [
		Vector3(-hw, hh, -hd), Vector3(hw, hh, -hd),
		Vector3(hw, hh, -hd), Vector3(hw, hh, hd),
		Vector3(hw, hh, hd), Vector3(-hw, hh, hd),
		Vector3(-hw, hh, hd), Vector3(-hw, hh, -hd)
	]
	for c in corners:
		border_mesh.surface_add_vertex(c)

	border_mesh.surface_add_vertex(Vector3(-hw, hh, -hd))
	border_mesh.surface_add_vertex(Vector3(-hw, -hh, -hd))
	border_mesh.surface_add_vertex(Vector3(hw, hh, -hd))
	border_mesh.surface_add_vertex(Vector3(hw, -hh, -hd))
	border_mesh.surface_add_vertex(Vector3(hw, hh, hd))
	border_mesh.surface_add_vertex(Vector3(hw, -hh, hd))
	border_mesh.surface_add_vertex(Vector3(-hw, hh, hd))
	border_mesh.surface_add_vertex(Vector3(-hw, -hh, hd))

	border_mesh.surface_end()

	# --------------------------------------------------------------------------
	# HOLOGRAPHIC FORCEFIELD SHIELD MESH (SPECIAL CORPORATE TOWERS)
	# --------------------------------------------------------------------------
	if b_type in ["HQ", "NORNS_AI", "FIFE_HQ", "BANKES_LOGISTICS"]:
		var shield_inst = MeshInstance3D.new()
		var shield_box = BoxMesh.new()
		shield_box.size = b_size + Vector3(1.2, 1.2, 1.2)
		shield_inst.mesh = shield_box
		var shield_mat = StandardMaterial3D.new()
		shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shield_mat.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
		shield_mat.emission_enabled = true
		shield_mat.emission = accent_color
		shield_mat.emission_energy_multiplier = 2.0
		shield_inst.material_override = shield_mat
		static_body.add_child(shield_inst)

	# --------------------------------------------------------------------------
	# PLAYABLE BUILDING ENTRANCE DOOR & AREA3D TRIGGER
	# --------------------------------------------------------------------------
	if b_type != "NORMAL":
		var door_container = Node3D.new()
		door_container.name = b_type + "_EntranceDoor"
		door_container.position = Vector3(0.0, -hh + 1.8, hd + 0.1)

		# Glowing Frame
		var frame_inst = MeshInstance3D.new()
		var frame_box = BoxMesh.new()
		frame_box.size = Vector3(3.6, 3.6, 0.4)
		frame_inst.mesh = frame_box
		var frame_mat = StandardMaterial3D.new()
		frame_mat.albedo_color = Color(0.02, 0.05, 0.08)
		frame_mat.emission_enabled = true
		frame_mat.emission = accent_color
		frame_mat.emission_energy_multiplier = 6.0
		frame_inst.material_override = frame_mat
		door_container.add_child(frame_inst)

		# Inner Dark Glass Portal
		var portal_inst = MeshInstance3D.new()
		var portal_box = BoxMesh.new()
		portal_box.size = Vector3(2.8, 3.0, 0.2)
		portal_inst.mesh = portal_box
		portal_inst.position = Vector3(0.0, -0.1, 0.1)
		var portal_mat = StandardMaterial3D.new()
		portal_mat.albedo_color = Color(0.0, 0.1, 0.2)
		portal_mat.emission_enabled = true
		portal_mat.emission = accent_color
		portal_mat.emission_energy_multiplier = 2.0
		portal_inst.material_override = portal_mat
		door_container.add_child(portal_inst)

		# Door Beacon Spotlight
		var door_spot = SpotLight3D.new()
		door_spot.light_color = accent_color
		door_spot.light_energy = 8.0
		door_spot.spot_range = 10.0
		door_spot.spot_angle = 45.0
		door_spot.rotation_degrees = Vector3(30, 0, 0)
		door_spot.position = Vector3(0.0, 2.0, 0.5)
		door_container.add_child(door_spot)

		static_body.add_child(door_container)
		var door_world_pos: Vector3 = Vector3(pos.x, 0.0, pos.z + hd + 1.2)

		if b_type == "HQ":
			hq_door_pos = door_world_pos
			hq_door_node = door_container
		elif b_type == "MACK_HIDEOUT":
			mack_hideout_door_pos = door_world_pos
			# Spawn Mack's War-Rig parked outside his home
			var rig_body = StaticBody3D.new()
			rig_body.name = "MackParkedWarRig"
			rig_body.position = pos + Vector3(0.0, 1.25, hd + 5.0)
			var r_col = CollisionShape3D.new()
			var r_shape = BoxShape3D.new()
			r_shape.size = Vector3(4.2, 2.8, 8.0)
			r_col.shape = r_shape
			rig_body.add_child(r_col)

			var r_mesh = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(4.2, 2.8, 8.0)
			r_mesh.mesh = box
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.05, 0.02)
			mat.metallic = 0.8
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.35, 0.0) # Rust Orange Emissive Grille
			mat.emission_energy_multiplier = 3.5
			r_mesh.material_override = mat
			rig_body.add_child(r_mesh)

			# 3D Label
			var rig_lbl = Label3D.new()
			rig_lbl.text = "🚛 MACK'S WAR-RIG EXECUTOR\n[PARKED OUTSIDE HIDEOUT]"
			rig_lbl.position = Vector3(0.0, 3.2, 0.0)
			rig_lbl.font_size = 24
			rig_lbl.pixel_size = 0.005
			rig_lbl.modulate = Color(1.0, 0.35, 0.0)
			rig_body.add_child(rig_lbl)

			add_child(rig_body)
			mack_parked_rig_node = rig_body
		elif b_type == "BANQUO_LOFT":
			banquo_safehouse_door_pos = door_world_pos
		elif b_type == "LADY_M":
			lady_m_lair_door_pos = door_world_pos
		elif b_type == "CHOP_SHOP":
			chop_shop_door_pos = door_world_pos
		elif b_type == "PORTER_PIT":
			porter_pit_door_pos = door_world_pos
		elif b_type == "NORNS_AI":
			norns_ai_door_pos = door_world_pos
		elif b_type == "FIFE_HQ":
			fife_hq_door_pos = door_world_pos
		elif b_type == "BANKES_LOGISTICS":
			bankes_logistics_door_pos = door_world_pos
		elif b_type == "SUBSTATION":
			power_substation_door_pos = door_world_pos
	else:
		active_normal_buildings.append({"body": static_body, "pos": pos, "size": b_size})

	# Add complete skyscraper object to the main city node
	add_child(static_body)

# Safety fallback pass ensuring all 9 special enterable buildings are placed across sectors
func _ensure_all_special_buildings_placed(neon_colors: Array) -> void:
	var special_specs: Array[Dictionary] = [
		{"type": "LADY_M", "placed": lady_m_lair_door_pos != Vector3.ZERO, "target": Vector3(-180.0, 0.0, -180.0)},
		{"type": "HQ", "placed": hq_building_pos != Vector3.ZERO, "target": Vector3(0.0, 0.0, -180.0)},
		{"type": "NORNS_AI", "placed": norns_ai_door_pos != Vector3.ZERO, "target": Vector3(180.0, 0.0, -180.0)},
		{"type": "BANKES_LOGISTICS", "placed": bankes_logistics_door_pos != Vector3.ZERO, "target": Vector3(-180.0, 0.0, 0.0)},
		{"type": "MACK_HIDEOUT", "placed": mack_hideout_door_pos != Vector3.ZERO, "target": Vector3(0.0, 0.0, 0.0)},
		{"type": "BANQUO_LOFT", "placed": banquo_safehouse_door_pos != Vector3.ZERO, "target": Vector3(250.0, 0.0, 250.0)}, # South-East Corner
		{"type": "FIFE_HQ", "placed": fife_hq_door_pos != Vector3.ZERO, "target": Vector3(180.0, 0.0, 0.0)},
		{"type": "PORTER_PIT", "placed": porter_pit_door_pos != Vector3.ZERO, "target": Vector3(-180.0, 0.0, 180.0)},
		{"type": "SUBSTATION", "placed": power_substation_door_pos != Vector3.ZERO, "target": Vector3(0.0, 0.0, 180.0)},
		{"type": "CHOP_SHOP", "placed": chop_shop_door_pos != Vector3.ZERO, "target": Vector3(180.0, 0.0, 180.0)}
	]

	for spec in special_specs:
		if spec["placed"]:
			continue
		if active_normal_buildings.size() == 0:
			break
		
		var best_idx: int = -1
		var min_dist: float = 999999.0
		for i in range(active_normal_buildings.size()):
			var candidate = active_normal_buildings[i]
			var d: float = candidate["pos"].distance_to(spec["target"])
			if d < min_dist:
				min_dist = d
				best_idx = i

		if best_idx >= 0:
			var chosen: Dictionary = active_normal_buildings[best_idx]
			active_normal_buildings.remove_at(best_idx)
			_attach_door_to_building(chosen["body"], chosen["pos"], chosen["size"], spec["type"], neon_colors)

func _attach_door_to_building(static_body: StaticBody3D, pos: Vector3, b_size: Vector3, b_type: String, neon_colors: Array) -> void:
	if b_type == "HQ":
		static_body.name = "DuncanHQBuilding"
		hq_building_pos = pos

	var accent_color: Color = Color(0.0, 1.0, 0.85)
	if b_type == "HQ":
		accent_color = Color(0.0, 1.0, 0.85)
	elif b_type == "HIDEOUT":
		accent_color = Color(1.0, 0.5, 0.0)
	elif b_type == "LADY_M":
		accent_color = Color(1.0, 0.0, 0.8)
	elif b_type == "CHOP_SHOP":
		accent_color = Color(0.2, 1.0, 0.3)
	elif b_type == "PORTER_PIT":
		accent_color = Color(1.0, 0.3, 0.0)
	elif b_type == "NORNS_AI":
		accent_color = Color(0.7, 0.1, 1.0)
	elif b_type == "FIFE_HQ":
		accent_color = Color(0.1, 0.5, 1.0)
	elif b_type == "BANKES_LOGISTICS":
		accent_color = Color(0.9, 0.7, 0.1)
	elif b_type == "SUBSTATION":
		accent_color = Color(1.0, 0.9, 0.0)

	var hh: float = b_size.y / 2.0
	var hd: float = b_size.z / 2.0

	var door_container = Node3D.new()
	door_container.name = b_type + "_EntranceDoor"
	door_container.position = Vector3(0.0, -hh + 1.8, hd + 0.1)

	var frame_inst = MeshInstance3D.new()
	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(3.6, 3.6, 0.4)
	frame_inst.mesh = frame_box
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.02, 0.05, 0.08)
	frame_mat.emission_enabled = true
	frame_mat.emission = accent_color
	frame_mat.emission_energy_multiplier = 6.0
	frame_inst.material_override = frame_mat
	door_container.add_child(frame_inst)

	var portal_inst = MeshInstance3D.new()
	var portal_box = BoxMesh.new()
	portal_box.size = Vector3(2.8, 3.0, 0.2)
	portal_inst.mesh = portal_box
	portal_inst.position = Vector3(0.0, -0.1, 0.1)
	var portal_mat = StandardMaterial3D.new()
	portal_mat.albedo_color = Color(0.0, 0.1, 0.2)
	portal_mat.emission_enabled = true
	portal_mat.emission = accent_color
	portal_mat.emission_energy_multiplier = 2.0
	portal_inst.material_override = portal_mat
	door_container.add_child(portal_inst)

	var door_spot = SpotLight3D.new()
	door_spot.light_color = accent_color
	door_spot.light_energy = 8.0
	door_spot.spot_range = 10.0
	door_spot.spot_angle = 45.0
	door_spot.rotation_degrees = Vector3(30, 0, 0)
	door_spot.position = Vector3(0.0, 2.0, 0.5)
	door_container.add_child(door_spot)

	static_body.add_child(door_container)
	var door_world_pos: Vector3 = Vector3(pos.x, 0.0, pos.z + hd + 1.2)

	if b_type == "HQ":
		hq_door_pos = door_world_pos
		hq_door_node = door_container
	elif b_type == "HIDEOUT":
		banquo_safehouse_door_pos = door_world_pos
	elif b_type == "LADY_M":
		lady_m_lair_door_pos = door_world_pos
	elif b_type == "CHOP_SHOP":
		chop_shop_door_pos = door_world_pos
	elif b_type == "PORTER_PIT":
		porter_pit_door_pos = door_world_pos
	elif b_type == "NORNS_AI":
		norns_ai_door_pos = door_world_pos
	elif b_type == "FIFE_HQ":
		fife_hq_door_pos = door_world_pos
	elif b_type == "BANKES_LOGISTICS":
		bankes_logistics_door_pos = door_world_pos
	elif b_type == "SUBSTATION":
		power_substation_door_pos = door_world_pos

# ==============================================================================
# 6. SPECIAL DISTRICTS (CYBER RIVER, CYBER PARKS, PARKING LOTS)
# ==============================================================================

# Spawns a glowing Cyber River / Water Canal with cyan water emission and solid water collision
func _spawn_cyber_river_canal(center: Vector3, b_size: Vector2) -> void:
	# Track river bounding box rectangle for geometric water safety check
	var river_rect = Rect2(center.x - b_size.x / 2.0, center.z - b_size.y / 2.0, b_size.x, b_size.y)
	active_river_boxes.append(river_rect)
	# StaticBody3D river obstacle (prevents car from driving into water)
	var river_body = StaticBody3D.new()
	river_body.name = "CyberRiver"
	river_body.position = center

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(b_size.x, 4.0, b_size.y) # 4m deep collision wall
	col_shape.shape = box_shape
	river_body.add_child(col_shape)

	var river_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = b_size
	river_mesh.mesh = plane
	river_mesh.position = Vector3(0.0, 0.02, 0.0)

	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.0, 0.15, 0.3, 0.8) # Deep Cyan Water
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.0, 0.7, 0.9)
	r_mat.emission_energy_multiplier = 1.8
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	river_mesh.material_override = r_mat
	river_body.add_child(river_mesh)

	add_child(river_body)

	# --- NEON SAFETY GUARDRAIL PERIMETER ---
	_build_river_guardrails(center, b_size)

# Constructs 1.1m tall metallic guardrails with glowing cyan neon top-bars along canal perimeters
func _build_river_guardrails(center: Vector3, b_size: Vector2) -> void:
	var half_w: float = b_size.x / 2.0
	var half_h: float = b_size.y / 2.0

	var railing_node = Node3D.new()
	railing_node.name = "RiverGuardrails"
	railing_node.position = center
	add_child(railing_node)

	# Metallic Post & Rail Materials
	var metal_mat = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.1, 0.12, 0.15)
	metal_mat.metallic = 0.8
	metal_mat.roughness = 0.3

	var neon_rail_mat = StandardMaterial3D.new()
	var cyan_neon = Color(0.0, 0.85, 1.0)
	neon_rail_mat.albedo_color = cyan_neon
	neon_rail_mat.emission_enabled = true
	neon_rail_mat.emission = cyan_neon
	neon_rail_mat.emission_energy_multiplier = 3.5

	# Construct 4 perimeter sides: North, South, East, West
	var sides: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.55, -half_h), "size": Vector3(b_size.x, 0.1, 0.15)}, # North
		{"pos": Vector3(0.0, 0.55, half_h),  "size": Vector3(b_size.x, 0.1, 0.15)}, # South
		{"pos": Vector3(-half_w, 0.55, 0.0), "size": Vector3(0.15, 0.1, b_size.y)}, # West
		{"pos": Vector3(half_w, 0.55, 0.0),  "size": Vector3(0.15, 0.1, b_size.y)}  # East
	]

	for side in sides:
		# Glowing Top Handrail
		var top_rail = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = side["size"]
		top_rail.mesh = r_box
		top_rail.position = side["pos"] + Vector3(0.0, 0.5, 0.0) # 1.05m elevation
		top_rail.material_override = neon_rail_mat
		railing_node.add_child(top_rail)

		# Lower Support Rail
		var bot_rail = MeshInstance3D.new()
		bot_rail.mesh = r_box
		bot_rail.position = side["pos"] + Vector3(0.0, 0.1, 0.0) # 0.65m elevation
		bot_rail.material_override = metal_mat
		railing_node.add_child(bot_rail)

	# Vertical Guard Posts spaced every 12 meters
	var post_spacing: float = 12.0
	var post_mesh = BoxMesh.new()
	post_mesh.size = Vector3(0.18, 1.1, 0.18)

	# North & South post runs
	var num_x_posts: int = int(b_size.x / post_spacing)
	for i in range(num_x_posts + 1):
		var px: float = -half_w + (float(i) * post_spacing)
		for pz in [-half_h, half_h]:
			var post = MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(px, 0.55, pz)
			post.material_override = metal_mat
			railing_node.add_child(post)

	# East & West post runs
	var num_z_posts: int = int(b_size.y / post_spacing)
	for j in range(num_z_posts + 1):
		var pz: float = -half_h + (float(j) * post_spacing)
		for px in [-half_w, half_w]:
			var post = MeshInstance3D.new()
			post.mesh = post_mesh
			post.position = Vector3(px, 0.55, pz)
			post.material_override = metal_mat
			railing_node.add_child(post)

# Spawns a Cyber Park with green grass ground & glowing holographic trees/foliage
func _spawn_cyber_park(center: Vector3, b_size: Vector2, neon_colors: Array) -> void:
	# Track park bounding box rectangle
	var park_rect = Rect2(center.x - b_size.x / 2.0, center.z - b_size.y / 2.0, b_size.x, b_size.y)
	active_park_boxes.append(park_rect)
	# 0. Impassable StaticBody3D Wall around Park Perimeter (AI Traffic Obstacle only)
	# collision_layer = 4, collision_mask = 0: blocks AI traffic (which checks layer 4)
	# but is invisible to the player car and on-foot character (which use default mask 1)
	var park_block_body = StaticBody3D.new()
	park_block_body.name = "CyberParkBlockBoundary"
	park_block_body.position = center
	park_block_body.collision_layer = 4
	park_block_body.collision_mask = 0

	var park_block_collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(b_size.x, 3.0, b_size.y)
	park_block_collision_shape.shape = box_shape
	park_block_body.add_child(park_block_collision_shape)
	add_child(park_block_body)
	# 1. Dark Green Synthetic Grass Ground Plane
	var park_ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = b_size
	park_ground.mesh = plane
	park_ground.position = center + Vector3(0.0, 0.01, 0.0)

	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.02, 0.12, 0.05) # Dark Emerald synth grass
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.0, 0.6, 0.2)
	p_mat.emission_energy_multiplier = 0.8
	park_ground.material_override = p_mat
	add_child(park_ground)

	# 2. Spawn 3 to 6 Holographic Neon Trees (With solid tree trunk colliders)
	var tree_count: int = rng.randi_range(3, 6)
	for i in range(tree_count):
		var tx: float = center.x + rng.randf_range(-b_size.x * 0.35, b_size.x * 0.35)
		var tz: float = center.z + rng.randf_range(-b_size.y * 0.35, b_size.y * 0.35)

		var tree_body = StaticBody3D.new()
		tree_body.name = "ParkTree"
		tree_body.position = Vector3(tx, 0.0, tz)

		var radius: float = rng.randf_range(2.0, 4.0)
		var height: float = rng.randf_range(5.0, 9.0)

		# Solid Tree Trunk Collision Shape
		var tree_trunk_collision_shape = CollisionShape3D.new()
		var cylinder = CylinderShape3D.new()
		cylinder.radius = radius * 0.6
		cylinder.height = height
		tree_trunk_collision_shape.shape = cylinder
		tree_trunk_collision_shape.position = Vector3(0.0, height / 2.0, 0.0)
		tree_body.add_child(tree_trunk_collision_shape)

		# Tree Canopy Cone Mesh
		var canopy = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = radius
		cone.height = height
		canopy.mesh = cone
		canopy.position = Vector3(0.0, height / 2.0 + 1.5, 0.0)

		var tree_color: Color = neon_colors[rng.randi() % neon_colors.size()]
		var c_mat = StandardMaterial3D.new()
		c_mat.albedo_color = tree_color
		c_mat.emission_enabled = true
		c_mat.emission = tree_color
		c_mat.emission_energy_multiplier = 2.5
		canopy.material_override = c_mat
		tree_body.add_child(canopy)

		add_child(tree_body)

	# 3. Corner Streetlights (Independent lights aimed towards park center using CitySceneryProps)
	var scenery_props_script = preload("res://CitySceneryProps.gd")
	var scenery_props = scenery_props_script.new()
	var park_offset_half_width: float = b_size.x / 2.0 - 1.5
	var park_offset_half_depth: float = b_size.y / 2.0 - 1.5
	var park_corner_positions: Array[Vector3] = [
		center + Vector3(-park_offset_half_width, 0.0, -park_offset_half_depth),
		center + Vector3(park_offset_half_width, 0.0, -park_offset_half_depth),
		center + Vector3(park_offset_half_width, 0.0, park_offset_half_depth),
		center + Vector3(-park_offset_half_width, 0.0, park_offset_half_depth)
	]

	for pos in park_corner_positions:
		var park_streetlight_node = scenery_props.create_parking_lot_streetlight(center, pos, b_size)
		add_child(park_streetlight_node)

	# --------------------------------------------------------------------------
	# 4. CONCERT STAGE & PAR CANS SPOTLIGHTS RIG (WEST SIDE OF PARK)
	# --------------------------------------------------------------------------
	var stage_node = Node3D.new()
	stage_node.name = "CyberParkConcertStage"
	# Position along the West side of the park facing East towards audience
	var stage_pos = center + Vector3(-b_size.x * 0.35, 0.0, 0.0)
	stage_node.position = stage_pos
	add_child(stage_node)

	# Raised Platform Solid Slab (8m wide, 1.2m tall, 12m long)
	var stage_body = StaticBody3D.new()
	stage_body.name = "StagePlatformCollider"
	var stage_col = CollisionShape3D.new()
	var stage_box = BoxShape3D.new()
	stage_box.size = Vector3(8.0, 1.2, 12.0)
	stage_col.shape = stage_box
	stage_col.position = Vector3(0.0, 0.6, 0.0)
	stage_body.add_child(stage_col)

	var stage_mesh = MeshInstance3D.new()
	var s_mesh = BoxMesh.new()
	s_mesh.size = Vector3(8.0, 1.2, 12.0)
	stage_mesh.mesh = s_mesh
	stage_mesh.position = Vector3(0.0, 0.6, 0.0)
	var stage_mat = StandardMaterial3D.new()
	stage_mat.albedo_color = Color(0.05, 0.06, 0.08) # Metallic stage floor
	stage_mat.metallic = 0.8
	stage_mat.roughness = 0.3
	stage_mesh.material_override = stage_mat
	stage_body.add_child(stage_mesh)

	# Glowing Neon Front Stage Edge Trim
	var edge_mesh = MeshInstance3D.new()
	var e_box = BoxMesh.new()
	e_box.size = Vector3(0.2, 0.15, 12.0)
	edge_mesh.mesh = e_box
	edge_mesh.position = Vector3(4.0, 1.25, 0.0)
	var edge_mat = StandardMaterial3D.new()
	edge_mat.albedo_color = Color(1.0, 0.0, 0.8) # Hot Magenta Edge
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(1.0, 0.0, 0.8)
	edge_mat.emission_energy_multiplier = 4.0
	edge_mesh.material_override = edge_mat
	stage_body.add_child(edge_mesh)

	stage_node.add_child(stage_body)

	# Check if PARK_CONCERT or SHAKESPEARE_PARK event is currently active today
	var active_event_id: String = ""
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_mgr):
		active_event_id = campaign_mgr.active_daily_event.get("id", "")

	var is_stage_event_today: bool = (active_event_id == "PARK_CONCERT" or active_event_id == "SHAKESPEARE_PARK")
	var is_shakespeare_today: bool = (active_event_id == "SHAKESPEARE_PARK")

	# Par Can Lighting Truss Towers (North and South ends of stage)
	for z_side in [-5.5, 5.5]:
		var truss = MeshInstance3D.new()
		var t_mesh = BoxMesh.new()
		t_mesh.size = Vector3(0.3, 5.0, 0.3)
		truss.mesh = t_mesh
		truss.position = Vector3(3.5, 3.7, z_side)
		var t_mat = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.2, 0.22, 0.25)
		t_mat.metallic = 0.9
		truss.material_override = t_mat
		stage_node.add_child(truss)

		# Par Can Spotlight Fixture
		var spot = SpotLight3D.new()
		spot.name = "ParCanSpotlight"
		spot.position = Vector3(3.5, 6.0, z_side)
		spot.rotation_degrees = Vector3(-35.0, 45.0 if z_side < 0 else -45.0, 0.0)
		
		# Gold/Amber spotlights for Shakespeare, Magenta/Cyan for Concert!
		if is_shakespeare_today:
			spot.light_color = Color(1.0, 0.75, 0.2) # Golden Dramatic Theater Spotlight
		else:
			spot.light_color = Color(1.0, 0.0, 0.8) if z_side < 0 else Color(0.0, 0.85, 1.0) # Magenta & Cyan Synth

		spot.light_energy = 9.0 if is_stage_event_today else 0.0 # ON during events, OFF when no event!
		spot.spot_range = 25.0
		spot.spot_angle = 35.0
		spot.spot_attenuation = 0.8
		stage_node.add_child(spot)

# Spawns a dark asphalt Parking Lot with glowing painted parking bay lines
func _spawn_parking_lot(center: Vector3, b_size: Vector2, neon_colors: Array) -> void:
	# Track lot bounding box rectangle
	var lot_rect = Rect2(center.x - b_size.x / 2.0, center.z - b_size.y / 2.0, b_size.x, b_size.y)
	active_lot_boxes.append(lot_rect)
	# 0. Impassable StaticBody3D Wall around Parking Lot Perimeter (AI Traffic Obstacle only)
	# collision_layer = 4, collision_mask = 0: blocks AI traffic (which checks layer 4)
	# but is invisible to the player car and on-foot character (which use default mask 1)
	var lot_block_body = StaticBody3D.new()
	lot_block_body.name = "ParkingLotBlockBoundary"
	lot_block_body.position = center
	lot_block_body.collision_layer = 4
	lot_block_body.collision_mask = 0

	var lot_block_collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(b_size.x, 3.0, b_size.y)
	lot_block_collision_shape.shape = box_shape
	lot_block_body.add_child(lot_block_collision_shape)
	add_child(lot_block_body)
	# 1. Dark Asphalt Plane
	var lot_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = b_size
	lot_mesh.mesh = plane
	lot_mesh.position = center + Vector3(0.0, 0.01, 0.0)

	var l_mat = StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.04, 0.04, 0.06) # Dark Asphalt Slate
	lot_mesh.material_override = l_mat
	add_child(lot_mesh)

	# 2. Glowing Neon Parking Bay Lines (ImmediateMesh lines)
	var line_mat = StandardMaterial3D.new()
	line_mat.emission_enabled = true
	line_mat.emission = Color(1.0, 0.8, 0.0) # Glowing Yellow Parking Lines
	line_mat.emission_energy_multiplier = 3.0

	var line_mesh = ImmediateMesh.new()
	var line_inst = MeshInstance3D.new()
	line_inst.mesh = line_mesh
	line_inst.material_override = line_mat
	line_inst.position = center + Vector3(0.0, 0.02, 0.0)
	add_child(line_inst)

	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Draw parking stall lines
	var stall_boundary_half_width: float = b_size.x / 2.0 - 2.0
	var stall_boundary_half_depth: float = b_size.y / 2.0 - 2.0
	for px in range(int(-stall_boundary_half_width), int(stall_boundary_half_width), 6):
		line_mesh.surface_add_vertex(Vector3(px, 0.0, -stall_boundary_half_depth))
		line_mesh.surface_add_vertex(Vector3(px, 0.0, -stall_boundary_half_depth + 8.0))
		line_mesh.surface_add_vertex(Vector3(px, 0.0, stall_boundary_half_depth - 8.0))
		line_mesh.surface_add_vertex(Vector3(px, 0.0, stall_boundary_half_depth))

	line_mesh.surface_end()

	# 3. Corner Streetlights (Independent lights aimed towards parking lot center using CitySceneryProps)
	var scenery_props_script = preload("res://CitySceneryProps.gd")
	var scenery_props = scenery_props_script.new()
	var streetlight_offset_half_width: float = b_size.x / 2.0 - 1.5
	var streetlight_offset_half_depth: float = b_size.y / 2.0 - 1.5
	var corner_positions: Array[Vector3] = [
		center + Vector3(-streetlight_offset_half_width, 0.0, -streetlight_offset_half_depth),
		center + Vector3(streetlight_offset_half_width, 0.0, -streetlight_offset_half_depth),
		center + Vector3(streetlight_offset_half_width, 0.0, streetlight_offset_half_depth),
		center + Vector3(-streetlight_offset_half_width, 0.0, streetlight_offset_half_depth)
	]

	for pos in corner_positions:
		var streetlight_node = scenery_props.create_parking_lot_streetlight(center, pos, b_size)
		add_child(streetlight_node)

	# 4. Spawn 1 to 2 Parked Vehicles cleanly aligned within stall lines
	var num_parked_cars: int = rng.randi_range(1, 2)
	var available_stalls: Array[float] = []
	for px in range(int(-stall_boundary_half_width), int(stall_boundary_half_width), 6):
		available_stalls.append(float(px) + 3.0) # Stall center X

	available_stalls.shuffle()
	var vehicle_colors: Array[Color] = [
		Color(0.85, 0.1, 0.1),  # Crimson Red
		Color(0.1, 0.45, 0.9),  # Cobalt Blue
		Color(0.1, 0.12, 0.15), # Obsidian Black
		Color(0.85, 0.85, 0.9), # Silver Metal
		Color(0.9, 0.7, 0.0)    # Amber Gold
	]

	for i in range(min(num_parked_cars, available_stalls.size())):
		var stall_x: float = available_stalls[i]
		# Pick north row (Z min) or south row (Z max)
		var is_north_row: bool = (i % 2 == 0)
		var stall_z: float = (-stall_boundary_half_depth + 4.0) if is_north_row else (stall_boundary_half_depth - 4.0)
		var car_pos: Vector3 = center + Vector3(stall_x, 0.0, stall_z)
		var facing: Vector3 = Vector3.BACK if is_north_row else Vector3.FORWARD
		var car_color: Color = vehicle_colors[rng.randi() % vehicle_colors.size()]

		var parked_car_node = scenery_props.create_parked_vehicle(car_pos, facing, car_color)
		add_child(parked_car_node)
