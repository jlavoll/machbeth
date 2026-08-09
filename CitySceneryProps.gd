extends Node
class_name CitySceneryProps

# ==============================================================================
# CYBERPUNK CITY SCENERY & PROPS SYSTEM (CitySceneryProps.gd)
# ==============================================================================
# Modular generator for street props, light fixtures, and parking lot floodlights.
# Keeps prop creation decoupled from CityGenerator.gd for easy customization!

# ------------------------------------------------------------------------------
# EXPORTED TWEAKING PARAMETERS (EDITABLE IN INSPECTOR OR AT TOP OF SCRIPT)
# ------------------------------------------------------------------------------
# Light Pole Dimensions
@export var pole_height: float = 7.0
@export var pole_radius_bottom: float = 0.25
@export var pole_radius_top: float = 0.18

# Lamp Housing Head (The "Car Headlight" fixture box on top of the pole)
@export var lamp_head_width: float = 0.8
@export var lamp_head_height: float = 0.4
@export var lamp_head_depth: float = 0.8
@export var lamp_lens_emission_energy: float = 8.0

# Spotlight Beam Parameters (Warm Cyber Yellow Floodlight)
@export var spotlight_color: Color = Color(1.0, 0.85, 0.2) # High-visibility Amber / Warm Cyber Yellow
@export var spotlight_energy: float = 20.0                  # Medium balanced beam energy
@export var spotlight_range_multiplier: float = 1.3         # Throws light 1.3x the lot size
@export var spotlight_cone_angle: float = 50.0              # Balanced 50-degree floodlight cone

# ==============================================================================
# PARKING LOT CORNER FLOODLIGHT FACTORY
# ==============================================================================

# Creates a complete streetlight fixture (Pole + Lamp Housing + Glowing Glass Lens + High-Energy SpotLight3D)
func create_parking_lot_streetlight(center_target: Vector3, position_world: Vector3, lot_size: Vector2) -> Node3D:
	var prop_root = Node3D.new()
	prop_root.name = "ParkingLotCornerSpotlight"
	prop_root.position = position_world

	# --------------------------------------------------------------------------
	# 1. VERTICAL METALLIC LIGHT POLE
	# --------------------------------------------------------------------------
	var pole_mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = pole_radius_top
	cylinder_mesh.bottom_radius = pole_radius_bottom
	cylinder_mesh.height = pole_height
	pole_mesh_instance.mesh = cylinder_mesh
	pole_mesh_instance.position = Vector3(0.0, pole_height / 2.0, 0.0)

	# Dark Brushed Steel Material
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.08, 0.08, 0.12)
	pole_mat.metallic = 0.8
	pole_mat.roughness = 0.3
	pole_mesh_instance.material_override = pole_mat
	prop_root.add_child(pole_mesh_instance)

	# --------------------------------------------------------------------------
	# 2. LAMP HOUSING HEAD (BOX FIXTURE MOUNTED ATOP THE POLE)
	# --------------------------------------------------------------------------
	var lamp_head_instance = MeshInstance3D.new()
	lamp_head_instance.name = "StreetlampHeadBox"
	var head_box_mesh = BoxMesh.new()
	head_box_mesh.size = Vector3(lamp_head_width, lamp_head_height, lamp_head_depth)
	lamp_head_instance.mesh = head_box_mesh
	lamp_head_instance.position = Vector3(0.0, pole_height, 0.0)

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.04, 0.04, 0.06)
	lamp_head_instance.material_override = head_mat
	prop_root.add_child(lamp_head_instance)

	# --------------------------------------------------------------------------
	# 3. HIGH-GLOW EMISSION LENS MESH (GLOWING GLASS FACE LIKE A CAR HEADLIGHT)
	# --------------------------------------------------------------------------
	var lens_instance = MeshInstance3D.new()
	lens_instance.name = "StreetlampLensGlowMesh"
	var lens_box_mesh = BoxMesh.new()
	lens_box_mesh.size = Vector3(lamp_head_width * 0.85, 0.08, lamp_head_depth * 0.85)
	lens_instance.mesh = lens_box_mesh
	# Position at bottom surface of the lamp housing head box
	lens_instance.position = Vector3(0.0, pole_height - (lamp_head_height / 2.0) - 0.02, 0.0)

	var lens_mat = StandardMaterial3D.new()
	lens_mat.albedo_color = spotlight_color
	lens_mat.emission_enabled = true
	lens_mat.emission = spotlight_color
	lens_mat.emission_energy_multiplier = lamp_lens_emission_energy
	lens_instance.material_override = lens_mat
	prop_root.add_child(lens_instance)

	# --------------------------------------------------------------------------
	# 4. HIGH-INTENSITY WARM YELLOW SPOTLIGHT BEAM PROJECTOR
	# --------------------------------------------------------------------------
	var spot_light = SpotLight3D.new()
	spot_light.name = "IndependentParkingLotSpotLight"
	spot_light.position = Vector3(0.0, pole_height - 0.1, 0.0)
	
	# Light Properties
	spot_light.light_color = spotlight_color
	spot_light.light_energy = spotlight_energy
	spot_light.light_volumetric_fog_energy = 1.5 # Medium visible light beam cone in fog
	spot_light.spot_range = max(lot_size.x, lot_size.y) * spotlight_range_multiplier
	spot_light.spot_angle = spotlight_cone_angle
	spot_light.shadow_enabled = false
	prop_root.add_child(spot_light)

	# --------------------------------------------------------------------------
	# 5. SOLID POLE COLLISION (Prevents car & player from walking through)
	# --------------------------------------------------------------------------
	var pole_body = StaticBody3D.new()
	pole_body.name = "StreetlampPoleCollider"
	# Default collision_layer = 1, collision_mask = 1 — visible to player car & on-foot

	var pole_col_shape = CollisionShape3D.new()
	var pole_cylinder = CylinderShape3D.new()
	pole_cylinder.radius = pole_radius_bottom  # Slightly generous radius for reliable hits
	pole_cylinder.height = pole_height
	pole_col_shape.shape = pole_cylinder
	pole_col_shape.position = Vector3(0.0, pole_height / 2.0, 0.0)
	pole_body.add_child(pole_col_shape)
	prop_root.add_child(pole_body)

	# Orient spotlight and lamp head box to face directly toward parking lot center
	lamp_head_instance.look_at_from_position(lamp_head_instance.position, center_target + Vector3(0.0, 0.5, 0.0), Vector3.UP)
	spot_light.look_at_from_position(spot_light.position, center_target + Vector3(0.0, 0.5, 0.0), Vector3.UP)

	return prop_root

# ==============================================================================
# CYBERPUNK FOOD TRUCK FACTORY
# ==============================================================================
# Creates a detailed cyberpunk street food truck (Noodle / Cyber-Taco / Synth-Bento Bar)
# with glowing neon menu signs, serving counter window, roof AC vents, and ambient lights!
func create_food_truck(spawn_pos: Vector3, facing_dir: Vector3, neon_color: Color) -> Node3D:
	var truck_root = Node3D.new()
	truck_root.name = "CyberFoodTruck"
	truck_root.position = spawn_pos

	# Orient truck along roadside (use look_at_from_position — node not in tree yet)
	if facing_dir.length_squared() > 0.01:
		truck_root.look_at_from_position(spawn_pos, spawn_pos + facing_dir, Vector3.UP)

	# 1. Main Truck Body Box (4.2m long, 2.2m wide, 2.4m tall)
	var body_inst = MeshInstance3D.new()
	body_inst.name = "FoodTruckBody"
	var body_box = BoxMesh.new()
	body_box.size = Vector3(2.2, 2.2, 4.2)
	body_inst.mesh = body_box
	body_inst.position = Vector3(0.0, 1.4, 0.0)

	var truck_mat = StandardMaterial3D.new()
	truck_mat.albedo_color = Color(0.06, 0.07, 0.1) # Dark Synth-Matte Steel
	truck_mat.metallic = 0.7
	truck_mat.roughness = 0.4
	body_inst.material_override = truck_mat
	truck_root.add_child(body_inst)

	# 2. Driver Cabin Windshield (Front)
	var cab_inst = MeshInstance3D.new()
	var cab_box = BoxMesh.new()
	cab_box.size = Vector3(2.0, 0.9, 0.8)
	cab_inst.mesh = cab_box
	cab_inst.position = Vector3(0.0, 1.5, -1.8)

	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.02, 0.08, 0.12)
	glass_mat.metallic = 0.9
	glass_mat.roughness = 0.1
	cab_inst.material_override = glass_mat
	truck_root.add_child(cab_inst)

	# 3. Wheels (4 Heavy Cyber Tires)
	var wheel_positions = [
		Vector3(-1.05, 0.45, 1.2),
		Vector3(1.05, 0.45, 1.2),
		Vector3(-1.05, 0.45, -1.2),
		Vector3(1.05, 0.45, -1.2)
	]
	for w_pos in wheel_positions:
		var w_inst = MeshInstance3D.new()
		var w_mesh = CylinderMesh.new()
		w_mesh.top_radius = 0.45
		w_mesh.bottom_radius = 0.45
		w_mesh.height = 0.35
		w_inst.mesh = w_mesh
		w_inst.rotation_degrees = Vector3(0, 0, 90)
		w_inst.position = w_pos

		var w_mat = StandardMaterial3D.new()
		w_mat.albedo_color = Color(0.03, 0.03, 0.04)
		w_mat.roughness = 0.9
		w_inst.material_override = w_mat
		truck_root.add_child(w_inst)

	# 4. Glowing Neon Roof Menu Sign ("NOODLES / SYNTH-BAR")
	var sign_inst = MeshInstance3D.new()
	sign_inst.name = "FoodTruckNeonSign"
	var sign_box = BoxMesh.new()
	sign_box.size = Vector3(1.8, 0.6, 0.1)
	sign_inst.mesh = sign_box
	sign_inst.position = Vector3(0.0, 2.8, 0.0)

	var sign_mat = StandardMaterial3D.new()
	sign_mat.albedo_color = neon_color
	sign_mat.emission_enabled = true
	sign_mat.emission = neon_color
	sign_mat.emission_energy_multiplier = 6.0
	sign_inst.material_override = sign_mat
	truck_root.add_child(sign_inst)

	# 5. Serving Window Opening Cutout & Counter Hatch
	var counter_inst = MeshInstance3D.new()
	counter_inst.name = "FoodTruckCounter"
	var counter_box = BoxMesh.new()
	counter_box.size = Vector3(0.3, 0.1, 2.0)
	counter_inst.mesh = counter_box
	counter_inst.position = Vector3(1.15, 1.2, 0.0)

	var counter_mat = StandardMaterial3D.new()
	counter_mat.albedo_color = Color(0.8, 0.8, 0.85)
	counter_mat.metallic = 0.9
	counter_inst.material_override = counter_mat
	truck_root.add_child(counter_inst)

	# 6. Warm Serving Counter Light (OmniLight3D illuminating customer area)
	var counter_light = OmniLight3D.new()
	counter_light.name = "FoodTruckCounterLight"
	counter_light.position = Vector3(1.6, 1.8, 0.0)
	counter_light.light_color = neon_color.lerp(Color(1.0, 0.9, 0.5), 0.5)
	counter_light.light_energy = 4.0
	counter_light.omni_range = 6.0
	counter_light.omni_attenuation = 0.8
	truck_root.add_child(counter_light)

	# 7. Impassable Solid Collision Box for Player Car, Traffic & On-Foot Player
	# collision_layer = 1 (default) — matches player car and on-foot CharacterBody3D mask
	var static_body = StaticBody3D.new()
	static_body.name = "FoodTruckCollision"

	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2.4, 2.5, 4.4)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 1.4, 0.0)
	static_body.add_child(col_shape)
	truck_root.add_child(static_body)

	return truck_root
