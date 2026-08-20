extends CharacterBody3D
class_name PinkCadillacTarget

# ==============================================================================
# PINK CADILLAC TARGET VEHICLE (PinkCadillacTarget.gd)
# ==============================================================================
# Custom mission asset for Banquo's "The Mysterious Pink Cadillac" tailing quest.
# Features a 5.4m luxury convertible mesh with hot pink metallic paint & violet LED glow.
# Handles autonomous street navigation and player stealth distance tracking (15m - 40m).

signal tailing_alert_failed(reason: String)
signal tailing_completed

@export var min_safe_distance: float = 15.0
@export var max_safe_distance: float = 40.0
@export var target_cruise_speed: float = 18.0

var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var suspicion_level: float = 0.0 # 0.0 to 100.0%
var is_active_tail_target: bool = false

# Visual References
var cadillac_body_mesh: MeshInstance3D
var underglow_light: OmniLight3D
var status_hud_label: Label = null

func _ready() -> void:
	name = "PinkCadillacTarget"
	_build_pink_cadillac_mesh()

func setup_route(route_points: Array[Vector3]) -> void:
	waypoints = route_points
	current_waypoint_index = 0
	if waypoints.size() > 0:
		global_position = waypoints[0]

func _build_pink_cadillac_mesh() -> void:
	# Main Car Body Mesh (5.4m long, 2.1m wide, 0.75m high classic convertible stance)
	cadillac_body_mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.1, 0.75, 5.4)
	cadillac_body_mesh.mesh = box_mesh
	cadillac_body_mesh.position = Vector3(0.0, 0.5, 0.0)
	
	# Hot Pink Metallic Paint with Violet Emission Accent
	var cadillac_material = StandardMaterial3D.new()
	cadillac_material.albedo_color = Color(1.0, 0.05, 0.75) # Hot Neon Pink
	cadillac_material.metallic = 0.95
	cadillac_material.roughness = 0.1
	cadillac_material.emission_enabled = true
	cadillac_material.emission = Color(0.9, 0.0, 0.8)
	cadillac_material.emission_energy_multiplier = 2.5
	cadillac_body_mesh.material_override = cadillac_material
	add_child(cadillac_body_mesh)
	
	# White Convertible Interior Cockpit Deck
	var cockpit_mesh = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(1.7, 0.2, 2.2)
	cockpit_mesh.mesh = c_box
	cockpit_mesh.position = Vector3(0.0, 0.85, 0.2)
	var white_leather = StandardMaterial3D.new()
	white_leather.albedo_color = Color(0.95, 0.95, 1.0)
	cockpit_mesh.material_override = white_leather
	add_child(cockpit_mesh)

	# Hot Pink Underglow LED OmniLight3D
	underglow_light = OmniLight3D.new()
	underglow_light.position = Vector3(0.0, 0.1, 0.0)
	underglow_light.light_color = Color(1.0, 0.0, 0.85) # Violet/Magenta underglow
	underglow_light.light_energy = 4.5
	underglow_light.omni_range = 7.0
	add_child(underglow_light)
	
	# Collision Box
	collision_layer = 1 | 2
	collision_mask  = 1 | 2
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2.0, 0.85, 5.2) # Snug collision envelope
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 0.55, 0.0)
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return

	_navigate_waypoints(delta)
	
	if is_active_tail_target:
		_process_stealth_distance_tracking(delta)

func _navigate_waypoints(delta: float) -> void:
	var target_wp: Vector3 = waypoints[current_waypoint_index]
	var dir_to_wp: Vector3 = (target_wp - global_position)
	dir_to_wp.y = 0.0
	
	if dir_to_wp.length() < 3.5:
		current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
		if current_waypoint_index == 0:
			emit_signal("tailing_completed")
		return

	var move_dir: Vector3 = dir_to_wp.normalized()
	velocity = move_dir * target_cruise_speed
	look_at(global_position + move_dir, Vector3.UP)
	move_and_slide()

func _process_stealth_distance_tracking(delta: float) -> void:
	var player_car = get_parent().get_node_or_null("PlayerCar")
	if not is_instance_valid(player_car):
		return

	var player_pos: Vector3 = player_car.global_position
	var dist: float = global_position.distance_to(player_pos)

	# Stealth Radar Meter Mechanics:
	# Safe Range: [15m - 40m] -> Suspicion decays
	# Too Close: [< 15m]     -> Suspicion rises rapidly (Spotted!)
	# Too Far:   [> 40m]     -> Suspicion rises slowly (Losing target!)
	if dist < min_safe_distance:
		suspicion_level = move_toward(suspicion_level, 100.0, delta * 35.0)
	elif dist > max_safe_distance:
		suspicion_level = move_toward(suspicion_level, 100.0, delta * 18.0)
	else:
		suspicion_level = move_toward(suspicion_level, 0.0, delta * 20.0)

	if suspicion_level >= 100.0:
		is_active_tail_target = false
		var reason: String = "TOO CLOSE! Target spotted you!" if dist < min_safe_distance else "TOO FAR! Lost target out of sight!"
		emit_signal("tailing_alert_failed", reason)
