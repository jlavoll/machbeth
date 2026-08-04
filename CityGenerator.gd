extends Node3D

# ==============================================================================
# CITY METRICS & GENERATION CONFIGURATION
# ==============================================================================
# @export variables allow editing parameters from the Godot Inspector.

# Total width of the city map along the X axis (600 meters)
@export var city_size_x: float = 600.0

# Total depth of the city map along the Z axis (600 meters)
@export var city_size_z: float = 600.0

# Width of the main central avenue (Broadway) in meters (30.0m)
@export var main_broadway_width: float = 30.0

# Width of standard side streets in meters (16.0m)
@export var secondary_street_width: float = 16.0

# Narrow gap width between buildings inside a block cluster in meters (6.0m)
@export var alley_width: float = 6.0

# Procedural generation seed number (Set to 0 for random city every launch, or enter any integer e.g. 777 for a persistent map!)
@export var city_seed: int = 0

# Random generator instance used for layout calculation
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Track special block bounding boxes for instant geometric safety checks
var active_river_boxes: Array[Rect2] = []
var active_park_boxes: Array[Rect2] = []
var active_lot_boxes: Array[Rect2] = []

# Calculated street corridor grid cuts for seed (X & Z coordinates)
var active_x_streets: Array[float] = []
var active_z_streets: Array[float] = []
var active_broadway_x: float = 0.0
var active_broadway_z: float = 0.0

# ==============================================================================
# INITIALIZATION LOOPS
# ==============================================================================

# Called when the node enters the scene tree
func _ready() -> void:
	generate_city_from_seed(city_seed)

# Listen for 1/2 keys to cycle city seeds in real-time during gameplay
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_2:
			# Key 2: Increase city seed (+1)
			regenerate_city(city_seed + 1)
		elif event.keycode == KEY_1:
			# Key 1: Decrease city seed (-1)
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
	active_x_streets.clear()
	active_z_streets.clear()
	if target_seed != 0:
		rng.seed = target_seed
	else:
		rng.randomize()

	_build_ground_and_grid()
	_generate_city_grid()
	_eject_entities_from_water()

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

	# Ground Material: Deep Dark Purple / Cyberpunk Asphalt
	var ground_mat = StandardMaterial3D.new()
	# Color(R=0.01, G=0.005, B=0.02) -> Almost pure black with a tiny tint of dark violet
	ground_mat.albedo_color = Color(0.01, 0.005, 0.02)
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
	var grid_mat = StandardMaterial3D.new()
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
	var grid_instance = MeshInstance3D.new()
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
	# 1. SEED-DRIVEN DYNAMIC AVENUE OFFSETS (MAIN BROADWAY IS NOT ALWAYS AT 0.0)
	# --------------------------------------------------------------------------
	# Pick random street cut indices for the main wide avenues (Broadway)
	var broadway_x_idx: int = rng.randi_range(1, 3) # Pick index 1, 2, or 3
	var broadway_z_idx: int = rng.randi_range(1, 3)

	var base_x_cuts: Array[float] = [-220.0, -110.0, 0.0, 110.0, 220.0]
	var base_z_cuts: Array[float] = [-220.0, -110.0, 0.0, 110.0, 220.0]

	# Add seed jitter (-25m to +25m) to secondary street cuts so city grids are irregular
	var x_streets: Array[float] = []
	var z_streets: Array[float] = []
	for i in range(base_x_cuts.size()):
		if i == 0 or i == base_x_cuts.size() - 1:
			x_streets.append(base_x_cuts[i])
			z_streets.append(base_z_cuts[i])
		else:
			x_streets.append(base_x_cuts[i] + rng.randf_range(-25.0, 25.0))
			z_streets.append(base_z_cuts[i] + rng.randf_range(-25.0, 25.0))

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

# ==============================================================================
# 4. BLOCK SUBDIVISION & ALLEY LAYOUT
# ==============================================================================

# Subdivides a city block into multiple individual building plots separated by alleys
func _create_block_cluster(center: Vector3, size: Vector2, neon_colors: Array) -> void:
	# Randomly split block into 2 to 3 building plots along X and Z axes
	var num_x: int = rng.randi_range(2, 3)
	var num_z: int = rng.randi_range(2, 3)

	# Calculate plot width and depth minus alley gaps (6 meters)
	var cell_w: float = (size.x - (num_x - 1) * alley_width) / num_x
	var cell_d: float = (size.y - (num_z - 1) * alley_width) / num_z

	var start_x: float = center.x - size.x / 2.0 + cell_w / 2.0
	var start_z: float = center.z - size.y / 2.0 + cell_d / 2.0

	for ix in range(num_x):
		for iz in range(num_z):
			# Randomize individual building footprint scale slightly (85% to 98% of plot)
			var b_width: float = cell_w * rng.randf_range(0.85, 0.98)
			var b_depth: float = cell_d * rng.randf_range(0.85, 0.98)
			# Randomize skyscraper height between 25.0 meters and 75.0 meters tall
			var b_height: float = rng.randf_range(15.0, 75.0)

			var bx: float = start_x + ix * (cell_w + alley_width)
			var bz: float = start_z + iz * (cell_d + alley_width)

			# Position Y is at b_height / 2.0 because BoxMesh origin is centered at geometric middle
			_spawn_building(Vector3(bx, b_height / 2.0, bz), Vector3(b_width, b_height, b_depth), neon_colors)

# ==============================================================================
# 5. BUILDING SPINNER & 3D MESH/PHYSICS CREATION
# ==============================================================================

# Spawns a 3D skyscraper mesh, collision box, window materials, and rooftop neon wireframe
func _spawn_building(pos: Vector3, b_size: Vector3, neon_colors: Array) -> void:

	# Create physical rigid block for collisions so player vehicle bounces off
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.position = pos

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
	var win_tex: Texture2D = _generate_window_texture(accent_color)

	# Building Exterior Surface Material
	var b_mat: StandardMaterial3D = StandardMaterial3D.new()
	# Dark concrete building wall base color Color(R=0.02, G=0.02, B=0.05)
	b_mat.albedo_color = Color(0.02, 0.02, 0.05)
	b_mat.emission_enabled = true
	b_mat.emission_texture = win_tex
	# Boosted glow multiplier so windows punch dramatically through dense atmospheric fog
	b_mat.emission_energy_multiplier = 5.0
	# Repeat window texture vertically according to building height (Vector3(Scale X=1, Scale Y=height/8, Scale Z=1))
	b_mat.uv1_scale = Vector3(1.0, b_size.y / 8.0, 1.0)

	building_mesh.material_override = b_mat
	static_body.add_child(building_mesh)

	# --------------------------------------------------------------------------
	# BUILDING NEON OMNILIGHT (VOLUMETRIC FOG SCATTERING & ATMOSPHERIC GLOW)
	# --------------------------------------------------------------------------
	var building_light: OmniLight3D = OmniLight3D.new()
	building_light.light_color = accent_color
	building_light.light_energy = 3.0
	building_light.light_volumetric_fog_energy = 1.7 # Moderate volumetric light halo in fog
	building_light.omni_range = max(b_size.x, b_size.z) * 1.75
	building_light.omni_attenuation = 0.9
	static_body.add_child(building_light)



	# --------------------------------------------------------------------------
	# ROOFTOP NEON BORDER LIGHT LINES
	# --------------------------------------------------------------------------
	var border_mat: StandardMaterial3D = StandardMaterial3D.new()
	border_mat.emission_enabled = true
	border_mat.emission = accent_color
	# High glow brightness multiplier (4.5x) for crisp roof lines
	border_mat.emission_energy_multiplier = 4.5

	var border_mesh: ImmediateMesh = ImmediateMesh.new()
	var border_instance: MeshInstance3D = MeshInstance3D.new()
	border_instance.mesh = border_mesh
	border_instance.material_override = border_mat
	static_body.add_child(border_instance)

	border_mesh.clear_surfaces()
	border_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Half dimensions from center of building box
	var hw: float = b_size.x / 2.0  # Half width
	var hh: float = b_size.y / 2.0  # Half height
	var hd: float = b_size.z / 2.0  # Half depth

	# Define 4 top rooftop edge corners in local coordinates around building center
	# Vector3(-hw, hh, -hd) -> (-X, +Y top roof, -Z)
	# Vector3( hw, hh, -hd) -> (+X, +Y top roof, -Z)
	# Vector3( hw, hh,  hd) -> (+X, +Y top roof, +Z)
	# Vector3(-hw, hh,  hd) -> (-X, +Y top roof, +Z)
	var corners: Array[Vector3] = [
		Vector3(-hw, hh, -hd), Vector3(hw, hh, -hd),
		Vector3(hw, hh, -hd), Vector3(hw, hh, hd),
		Vector3(hw, hh, hd), Vector3(-hw, hh, hd),
		Vector3(-hw, hh, hd), Vector3(-hw, hh, -hd)
	]
	for c in corners:
		border_mesh.surface_add_vertex(c)

	# Draw vertical corner pillar accent lines connecting top roof corners down to bottom ground
	# Top corner Vector3(-hw, hh, -hd) down to bottom corner Vector3(-hw, -hh, -hd)
	border_mesh.surface_add_vertex(Vector3(-hw, hh, -hd))
	border_mesh.surface_add_vertex(Vector3(-hw, -hh, -hd))
	
	border_mesh.surface_add_vertex(Vector3(hw, hh, -hd))
	border_mesh.surface_add_vertex(Vector3(hw, -hh, -hd))
	
	border_mesh.surface_add_vertex(Vector3(hw, hh, hd))
	border_mesh.surface_add_vertex(Vector3(hw, -hh, hd))
	
	border_mesh.surface_add_vertex(Vector3(-hw, hh, hd))
	border_mesh.surface_add_vertex(Vector3(-hw, -hh, hd))

	# Add complete skyscraper object to the main city node
	add_child(static_body)

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

# Spawns a Cyber Park with green grass ground & glowing holographic trees/foliage
func _spawn_cyber_park(center: Vector3, b_size: Vector2, neon_colors: Array) -> void:
	# Track park bounding box rectangle
	var park_rect = Rect2(center.x - b_size.x / 2.0, center.z - b_size.y / 2.0, b_size.x, b_size.y)
	active_park_boxes.append(park_rect)
	# 0. Impassable StaticBody3D Wall around Park Perimeter (Collision Layer 3: Traffic Obstacles)
	var park_block_body = StaticBody3D.new()
	park_block_body.name = "CyberParkBlockBoundary"
	park_block_body.position = center
	park_block_body.collision_layer = 4 # Layer 3 (bit 3 / mask value 4)
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

# Spawns a dark asphalt Parking Lot with glowing painted parking bay lines
func _spawn_parking_lot(center: Vector3, b_size: Vector2, neon_colors: Array) -> void:
	# Track lot bounding box rectangle
	var lot_rect = Rect2(center.x - b_size.x / 2.0, center.z - b_size.y / 2.0, b_size.x, b_size.y)
	active_lot_boxes.append(lot_rect)
	# 0. Impassable StaticBody3D Wall around Parking Lot Perimeter (Collision Layer 3: Traffic Obstacles)
	var lot_block_body = StaticBody3D.new()
	lot_block_body.name = "ParkingLotBlockBoundary"
	lot_block_body.position = center
	lot_block_body.collision_layer = 4 # Layer 3 (bit 3 / mask value 4)
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
