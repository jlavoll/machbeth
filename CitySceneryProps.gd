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

	# Orient spotlight and lamp head box to face directly toward parking lot center
	lamp_head_instance.look_at(center_target + Vector3(0.0, 0.5, 0.0), Vector3.UP)
	spot_light.look_at(center_target + Vector3(0.0, 0.5, 0.0), Vector3.UP)

	return prop_root
