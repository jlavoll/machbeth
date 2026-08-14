extends CharacterBody3D
class_name PlayerCar

# ==============================================================================
# PLAYER MOVEMENT & CAR HANDLING EXPORTS
# ==============================================================================
# @export variables allow tweaking values directly inside Godot's Inspector panel.

# Maximum forward driving speed in meters per second
@export var max_speed: float = 24.0

# Maximum reverse driving speed in meters per second
@export var reverse_speed: float = 12.0

# How quickly the vehicle speeds up (meters per second squared)
@export var acceleration: float = 30.0

# Passive deceleration rate when no throttle/brake key is pressed
@export var friction: float = 15.0

# Steering rotation speed in radians per second
@export var steer_speed: float = 3.2

# Current forward/backward velocity of the vehicle
var current_speed: float = 0.0

# ==============================================================================
# ON-FOOT STATE
# ==============================================================================

## Set to true while the player is walking the streets — disables driving input
var is_on_foot: bool = false

## Reference to the active PlayerOnFoot node (null while driving)
var on_foot_node: CharacterBody3D = null

## Guard: true for one frame after re-entering so the same E press that triggered
## on_foot_reenter() doesn't also fire _exit_to_on_foot() again in this node
var _reenter_guard: bool = false

## Reference to WeatherAmbienceManager for cabin filter transition
var _weather_ambience: Node = null

# Towing cable state for Norns War-Rig recovery quest
var is_towing_war_rig: bool = false
var tow_cable_mesh: ImmediateMesh = null
var tow_cable_node: MeshInstance3D = null

# ==============================================================================
# VISUAL BODY DYNAMICS (LEANING, BANKING & PITCH)
# ==============================================================================

# Maximum body roll (lean/bank) in degrees during sharp turns
@export_range(0.0, 20.0, 0.5) var max_bank_angle_degrees: float = 8.5

# Maximum nose pitch dip/lift in degrees under heavy acceleration or braking
@export_range(0.0, 15.0, 0.5) var max_pitch_angle_degrees: float = 4.0

# How quickly body tilt responds to steering/acceleration changes (higher = snappier)
@export_range(1.0, 20.0, 0.5) var body_tilt_speed: float = 8.0

# References to visual body mesh child node
@onready var car_body_mesh: MeshInstance3D = $CarBody

# Internal smoothed tilt values (radians)
var _target_bank_roll: float = 0.0
var _target_pitch: float = 0.0

# ==============================================================================
# HEADLIGHT STAGE SYSTEM (H KEY SHORTCUT)
# ==============================================================================
# Modes: 0 = OFF, 1 = NEAR (Low Beam), 2 = LONG (High/Long Beam)
enum HeadlightMode { OFF, NEAR, LONG }
var current_headlight_mode: HeadlightMode = HeadlightMode.NEAR

# ------------------------------------------------------------------------------
# HEADLIGHT BEAM LENGTH & TUNING PARAMETERS  (Adjust values here to tune beams!)
# ------------------------------------------------------------------------------

# --- 1. NEAR BEAM (LOW BEAM) ---
# Length of Near Beam light throw in meters (Default: 35.0m)
@export_range(10.0, 100.0, 1.0) var near_beam_length: float = 35.0
# Cone spread angle in degrees (Default: 35.0°) - wider angle illuminates road right in front
@export_range(10.0, 90.0, 1.0) var near_beam_cone_angle: float = 35.0
# Brightness strength energy multiplier (Default: 5.0)
@export_range(1.0, 30.0, 0.5) var near_beam_energy: float = 5.0
# Downward tilt angle in degrees (Default: -12.0°) - points light onto nearby road surface
@export_range(-30.0, 0.0, 0.5) var near_beam_tilt_degrees: float = -12.0

# --- 2. LONG BEAM (HIGH BEAM / FAR THROW) ---
# Length of Long Beam light throw in meters (Default: 90.0m - increase e.g. 150.0m for extreme distance)
@export_range(30.0, 300.0, 5.0) var long_beam_length: float = 250.0
# Cone spread angle in degrees (Default: 22.0°) - narrower focused spotlight beam reaches further
@export_range(5.0, 60.0, 1.0) var long_beam_cone_angle: float = 22.0
# Brightness strength energy multiplier (Default: 12.0)
@export_range(1.0, 50.0, 1.0) var long_beam_energy: float = 12.0
# Downward tilt angle in degrees (Default: -4.0°) - flatter angle lets beam illuminate down long avenues
@export_range(-20.0, 5.0, 0.5) var long_beam_tilt_degrees: float = -14.0

var spot_light_left: SpotLight3D
var spot_light_right: SpotLight3D
@onready var headlight_mesh_left:  MeshInstance3D = $HeadLightLeft
@onready var headlight_mesh_right: MeshInstance3D = $HeadLightRight
@onready var tail_light_mesh:      MeshInstance3D = $TailLight

# ==============================================================================
# BRAKE LIGHT EMISSION PARAMETERS
# ==============================================================================
# Full-bright emission when coasting/braking (feels like a brake light)
@export_range(1.0, 20.0, 0.5) var tail_emission_brake:  float = 6.0
# Dimmed emission while pressing throttle forward
@export_range(0.0, 10.0, 0.5) var tail_emission_drive:  float = 3
# How fast the emission transitions between states (units/sec)
@export_range(1.0, 50.0, 1.0) var tail_emission_speed:  float = 28.0

var _tail_mat: StandardMaterial3D = null

# ==============================================================================
# CAMERA & ZOOM CONTROL PARAMETERS
# ==============================================================================

# Reference to the child Camera3D node attached to this player vehicle
@onready var camera: Camera3D = $Camera3D

# Camera tilt angle downward in degrees (0 = looking flat forward, -90 = looking straight down)
@export var camera_pitch_angle_degrees: float = -65.0

# Camera position offset relative to the car: Vector3(X=Left/Right, Y=Height Above Car, Z=Distance Behind Car)
@export var camera_offset: Vector3 = Vector3(0.0, 22.0, 5.0)

# Minimum Field of View in degrees (base zoom-in limit before extra upward tilt kicks in)
@export var min_fov: float = 60.0

# Ultra-Zoom Field of View in degrees (maximum zoom-in limit for upward sky tilt)
@export var ultra_min_fov: float = 35.0

# Maximum Field of View in degrees (most zoomed OUT)
@export var max_fov: float = 150.0

# Amount by which the Field of View changes with each mouse wheel notch scroll
@export var zoom_step: float = 3.0

# Starting base FOV captured at launch
var base_fov: float = 85.0

# Camera position offset when fully zoomed IN: Vector3(X=0, Y=Height, Z=Distance Behind)
@export var min_zoom_camera_offset: Vector3 = Vector3(0.0, 4.0, 8.0)

# Pitch angle in degrees when zoomed in to min_fov (60° FOV) looking behind car
@export var min_zoom_pitch_angle_degrees: float = -20.0

# Pitch angle in degrees when continuing to zoom in further to ultra_min_fov (35° FOV) tilting upward to sky/skyscrapers
@export var ultra_zoom_pitch_angle_degrees: float = 10.0

# ==============================================================================
# ENGINE LOOPS & INPUT HANDLING
# ==============================================================================

func _ready() -> void:
	if camera:
		base_fov = camera.fov  # Capture scene-configured base FOV for zoom calculations
		# Start (and always return to) 5 scroll steps back from the maximum zoom-in level.
		# ultra_min_fov (35) + 5 × zoom_step (3) = 50 — close behind-the-car driving view.
		camera.fov = ultra_min_fov + 5.0 * zoom_step
	_update_camera_transform()
	_setup_3d_headlights()
	# Cache tail-light material for brake-light emission updates
	if is_instance_valid(tail_light_mesh):
		_tail_mat = tail_light_mesh.get_surface_override_material(0) as StandardMaterial3D
	# Cache WeatherAmbienceManager reference for cabin filter transitions
	_weather_ambience = get_node_or_null("../WeatherAmbienceManager")

func _setup_3d_headlights() -> void:
	# Create 3D SpotLight3D projectors for left and right headlights
	spot_light_left = SpotLight3D.new()
	spot_light_left.name = "SpotLightLeft"
	spot_light_left.position = Vector3(-0.6, 0.2, -1.2) # Front left
	spot_light_left.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	spot_light_left.light_color = Color(0.69, 1.0, 1.0, 1.0) # Neon Cyan
	spot_light_left.shadow_enabled = true
	add_child(spot_light_left)

	spot_light_right = SpotLight3D.new()
	spot_light_right.name = "SpotLightRight"
	spot_light_right.position = Vector3(0.6, 0.2, -1.2) # Front right
	spot_light_right.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	spot_light_right.light_color = Color(0.663, 0.902, 1.0, 1.0) # Neon Cyan
	spot_light_right.shadow_enabled = true
	add_child(spot_light_right)

	# Apply initial mode settings (starts on NEAR)
	_apply_headlight_mode()

func _cycle_headlight_mode() -> void:
	# Cycle OFF (0) -> NEAR (1) -> LONG (2) -> OFF (0)
	match current_headlight_mode:
		HeadlightMode.OFF:
			current_headlight_mode = HeadlightMode.NEAR
		HeadlightMode.NEAR:
			current_headlight_mode = HeadlightMode.LONG
		HeadlightMode.LONG:
			current_headlight_mode = HeadlightMode.OFF
	
	_apply_headlight_mode()

func _apply_headlight_mode() -> void:
	var mode_name: String = ""
	match current_headlight_mode:
		HeadlightMode.OFF:
			mode_name = "OFF"
			spot_light_left.visible = false
			spot_light_right.visible = false
			_set_headlight_mesh_emission(0.0)

		HeadlightMode.NEAR:
			mode_name = "NEAR (LOW BEAM)"
			spot_light_left.visible = true
			spot_light_right.visible = true
			
			# Near Beam distance, angle, energy, and tilt (configured above in NEAR BEAM parameters)
			spot_light_left.spot_range = near_beam_length
			spot_light_right.spot_range = near_beam_length
			spot_light_left.spot_angle = near_beam_cone_angle
			spot_light_right.spot_angle = near_beam_cone_angle
			spot_light_left.light_energy = near_beam_energy
			spot_light_right.light_energy = near_beam_energy
			spot_light_left.rotation_degrees = Vector3(near_beam_tilt_degrees, 0.0, 0.0)
			spot_light_right.rotation_degrees = Vector3(near_beam_tilt_degrees, 0.0, 0.0)
			_set_headlight_mesh_emission(5.0)

		HeadlightMode.LONG:
			mode_name = "LONG (HIGH BEAM)"
			spot_light_left.visible = true
			spot_light_right.visible = true
			
			# Long Beam distance, angle, energy, and tilt (configured above in LONG BEAM parameters)
			# --> TWEAK 'long_beam_length' AT TOP OF FILE OR IN INSPECTOR TO CHANGE LONG BEAM DISTANCE <--
			spot_light_left.spot_range = long_beam_length
			spot_light_right.spot_range = long_beam_length
			spot_light_left.spot_angle = long_beam_cone_angle
			spot_light_right.spot_angle = long_beam_cone_angle
			spot_light_left.light_energy = long_beam_energy
			spot_light_right.light_energy = long_beam_energy
			spot_light_left.rotation_degrees = Vector3(long_beam_tilt_degrees, 0.0, 0.0)
			spot_light_right.rotation_degrees = Vector3(long_beam_tilt_degrees, 0.0, 0.0)
			_set_headlight_mesh_emission(10.0)

	print("[HEADLIGHTS] Mode switched to: ", mode_name)

func _set_headlight_mesh_emission(energy: float) -> void:
	for mesh in [headlight_mesh_left, headlight_mesh_right]:
		if is_instance_valid(mesh):
			var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
			if not mat and mesh.mesh:
				mat = mesh.mesh.surface_get_material(0)
			if mat:
				mat.emission_enabled = (energy > 0.0)
				mat.emission_energy_multiplier = energy

func _update_camera_transform() -> void:
	if camera:
		var current_pitch: float = camera_pitch_angle_degrees
		var current_offset: Vector3 = camera_offset

		if camera.fov < base_fov and camera.fov >= min_fov:
			var zoom_in_factor: float = (base_fov - camera.fov) / (base_fov - min_fov)
			current_pitch = lerp(camera_pitch_angle_degrees, min_zoom_pitch_angle_degrees, zoom_in_factor)
			current_offset = camera_offset.lerp(min_zoom_camera_offset, zoom_in_factor)
			
		elif camera.fov < min_fov:
			var ultra_zoom_factor: float = (min_fov - camera.fov) / (min_fov - ultra_min_fov)
			current_pitch = lerp(min_zoom_pitch_angle_degrees, ultra_zoom_pitch_angle_degrees, ultra_zoom_factor)
			current_offset = min_zoom_camera_offset

		camera.position = current_offset
		camera.rotation_degrees = Vector3(current_pitch, 0.0, 0.0)

func _physics_process(delta: float) -> void:
	# While on foot, suppress all car driving — the car sits parked
	if is_on_foot:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --------------------------------------------------------------------------
	# 1. STEERING INPUT (A/D or Left/Right Arrow Keys)
	# --------------------------------------------------------------------------
	var steer_input: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer_input += 1.0  # Turn left (+1)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer_input -= 1.0  # Turn right (-1)

	# --------------------------------------------------------------------------
	# 2. THROTTLE INPUT (W/S or Up/Down Arrow Keys)
	# --------------------------------------------------------------------------
	var throttle_input: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle_input += 1.0  # Drive forward (+1)
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle_input -= 1.0  # Reverse / Brake (-1)

	# --------------------------------------------------------------------------
	# 3. STEERING ROTATION LOGIC
	# --------------------------------------------------------------------------
	if abs(current_speed) > 0.1 or throttle_input != 0.0:
		var steer_dir: float = -1.0 if current_speed < -0.1 else 1.0
		rotation.y += steer_input * steer_speed * steer_dir * delta

	# --------------------------------------------------------------------------
	# 4. SPEED ACCELERATION / BRAKING / FRICTION
	# --------------------------------------------------------------------------
	if throttle_input > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif throttle_input < 0:
		current_speed = move_toward(current_speed, -reverse_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	# --------------------------------------------------------------------------
	# 5. VISUAL BODY DYNAMICS (BANKING ROLL & NOSE PITCH)
	# --------------------------------------------------------------------------
	if is_instance_valid(car_body_mesh):
		# Roll (Z axis): Steers left (+steer_input) -> leans left (+Z roll); steers right -> leans right (-Z roll)
		var max_bank_rad: float = deg_to_rad(max_bank_angle_degrees)
		var speed_ratio: float = clamp(abs(current_speed) / max_speed, 0.2, 1.0)
		_target_bank_roll = steer_input * max_bank_rad * speed_ratio

		# Pitch (X axis): W acceleration -> nose lifts (-X pitch); S braking/reverse -> nose dips (+X pitch)
		var max_pitch_rad: float = deg_to_rad(max_pitch_angle_degrees)
		_target_pitch = -throttle_input * max_pitch_rad

		# Smoothly lerp local mesh rotation so banking feels responsive and organic
		var lerp_t: float = clamp(body_tilt_speed * delta, 0.0, 1.0)
		car_body_mesh.rotation.z = lerp(car_body_mesh.rotation.z, _target_bank_roll, lerp_t)
		car_body_mesh.rotation.x = lerp(car_body_mesh.rotation.x, _target_pitch, lerp_t)

	# --------------------------------------------------------------------------
	# 6. MOVEMENT VECTOR COMPUTATION & PHYSICS EXECUTION
	# --------------------------------------------------------------------------
	var forward_dir: Vector3 = -transform.basis.z
	velocity = forward_dir * current_speed
	move_and_slide()

	_check_city_edge_transition()
	_update_towing_physics(delta)

	# --------------------------------------------------------------------------
	# 7. BRAKE LIGHT — dim while pressing forward, full brightness otherwise
	# --------------------------------------------------------------------------
	if _tail_mat != null:
		var target_emission: float = tail_emission_drive if throttle_input > 0.0 else tail_emission_brake
		_tail_mat.emission_energy_multiplier = move_toward(
			_tail_mat.emission_energy_multiplier, target_emission, tail_emission_speed * delta)

# ==============================================================================
# MOUSE WHEEL CAMERA ZOOM HANDLER
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 'K' key toggles/cycles headlight stages: OFF -> NEAR -> LONG -> OFF
		if event.keycode == KEY_K and not is_on_foot:
			_cycle_headlight_mode()

		# 'E' key hitches tow cable to smoldering War-Rig or exits the car
		if event.keycode == KEY_E and not is_on_foot and not _reenter_guard:
			var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
			if is_instance_valid(campaign_mgr) and campaign_mgr.is_norns_recovery_active and is_instance_valid(campaign_mgr.norns_recovery_node):
				var dist_to_wreck: float = global_position.distance_to(campaign_mgr.norns_recovery_drop_pos)
				if dist_to_wreck <= 12.0 and not is_towing_war_rig:
					_attach_tow_cable()
					get_viewport().set_input_as_handled()
					return
			_exit_to_on_foot()

		# 'T' key — DEV TEST: instantly opens Porter dialogue while on foot (no Area3D needed)
		if event.keycode == KEY_T and is_on_foot and is_instance_valid(on_foot_node):
			var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
			if dialogue_sys:
				on_foot_node._nearby_dialogue_source = "res://scripts/porter_at_the_pit.json"
				dialogue_sys.start_dialogue("res://scripts/porter_at_the_pit.json")
				print("[DEV] T key: opened Porter dialogue for testing.")

	# Clear the reenter guard one frame after it was set
	if _reenter_guard:
		_reenter_guard = false

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = clamp(camera.fov - zoom_step, ultra_min_fov, max_fov)
			if not is_on_foot:
				_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = clamp(camera.fov + zoom_step, ultra_min_fov, max_fov)
			if not is_on_foot:
				_update_camera_transform()

# ==============================================================================
# ON-FOOT EXIT / REENTER
# ==============================================================================

func _exit_to_on_foot() -> void:
	is_on_foot = true
	current_speed = 0.0
	velocity = Vector3.ZERO

	# Notify ambience manager so it smoothly opens the cabin filter
	if is_instance_valid(_weather_ambience) and _weather_ambience.has_method("set_player_in_car"):
		_weather_ambience.set_player_in_car(false)

	# Spawn the player figure at ground level beside the car
	var spawn_offset: Vector3 = global_transform.basis.x * 1.5  # step out to the right
	var spawn_pos: Vector3 = global_position + spawn_offset
	spawn_pos.y = 0.0  # Force to ground — car floats at y=1 but the street is at y=0

	var foot_script = load("res://PlayerOnFoot.gd")
	on_foot_node = CharacterBody3D.new()
	on_foot_node.set_script(foot_script)
	get_parent().add_child(on_foot_node)

	# setup() reparents the camera, builds the figure, and starts lerping
	on_foot_node.setup(self, camera, spawn_pos)

	# Wire the DialogueSystem to PlayerOnFoot so it can open dialogue overlays.
	# The DialogueSystem node lives as a CanvasLayer child of Main.
	var dialogue_sys_node = get_parent().get_node_or_null("DialogueSystem")
	if dialogue_sys_node:
		on_foot_node.dialogue_system = dialogue_sys_node
		print("[DIALOGUE] DialogueSystem wired to PlayerOnFoot.")
	else:
		print("[DIALOGUE] Warning: DialogueSystem node not found in Main — add it to Main.tscn first.")

	# Wire the WeatherAmbienceManager so PlayerOnFoot can trigger footstep sounds.
	var ambience_node = get_parent().get_node_or_null("WeatherAmbienceManager")
	if ambience_node:
		on_foot_node.ambience_manager = ambience_node
		print("[AMBIENCE] WeatherAmbienceManager wired to PlayerOnFoot.")
	else:
		print("[AMBIENCE] Warning: WeatherAmbienceManager node not found in Main — footstep audio will be silent.")

	# Default walking zoom: Over-The-Shoulder sweet spot (_foot_zoom = 1.0)
	on_foot_node._foot_zoom = 1.0

	print("[ON FOOT] Player exited car at ", global_position)

## Called by PlayerOnFoot when the player walks back to the car and presses E.
func on_foot_reenter(cam: Camera3D, foot_zoom: float = 0.0) -> void:
	is_on_foot = false
	_reenter_guard = true  # Block the same E press from immediately re-exiting

	# Notify ambience manager so it smoothly closes the cabin filter
	if is_instance_valid(_weather_ambience) and _weather_ambience.has_method("set_player_in_car"):
		_weather_ambience.set_player_in_car(true)

	# Reparent camera back from the foot node to this car.
	on_foot_node.remove_child(cam)
	# Null the foot node's camera reference NOW — queue_free() is deferred to end-of-frame,
	# so _physics_process on the foot node will still run this frame. Without this,
	# _update_camera() would call look_at() and overwrite our transform reset below.
	on_foot_node.camera = null
	add_child(cam)

	# Free the on-foot figure
	if is_instance_valid(on_foot_node):
		on_foot_node.queue_free()
	on_foot_node = null

	# Hard-reset the camera transform before applying the driving position.
	# The foot camera's look_at() leaves a rotated basis that can survive reparenting;
	# wiping it first guarantees a clean, straight view with no leftover tilt.
	camera.transform = Transform3D.IDENTITY

	# Always snap back to the standard entry FOV: 5 steps back from max zoom-in.
	# Keeps re-entry feeling clean and consistent regardless of how zoomed the foot view was.
	camera.fov = ultra_min_fov + 5.0 * zoom_step

	# Place camera at the correct driving position for the new FOV
	_update_camera_transform()

# Checks if car reached edge exit boundary (600m city size = +-290m limit)
func _check_city_edge_transition() -> void:
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	if not is_instance_valid(city_gen):
		return

	var size_x: float = city_gen.city_size_x
	var size_z: float = city_gen.city_size_z
	var half_x: float = size_x / 2.0 - 5.0 # Boundary trigger edge threshold (295m for 600m map)
	var half_z: float = size_z / 2.0 - 5.0

	var pos: Vector3 = global_position
	var crossed_dir: String = ""
	var new_seed: int = city_gen.city_seed

	if pos.z < -half_z:
		crossed_dir = "NORTH"
		new_seed += 1
	elif pos.z > half_z:
		crossed_dir = "SOUTH"
		new_seed -= 1
	elif pos.x > half_x:
		crossed_dir = "EAST"
		new_seed += 10
	elif pos.x < -half_x:
		crossed_dir = "WEST"
		new_seed -= 10

	if crossed_dir != "":
		print("[CITY SEED EXIT] Player crossed ", crossed_dir, " exit! Changing city seed from ", city_gen.city_seed, " to ", new_seed)
		city_gen.regenerate_city(new_seed)
		
		var spawn_pos: Vector3 = city_gen.get_edge_spawn_position(crossed_dir)
		global_position = spawn_pos
		
		# If walking on foot during exit transition, update on-foot player position too
		if is_on_foot and is_instance_valid(on_foot_node):
			on_foot_node.global_position = spawn_pos

# ==============================================================================
# WAR-RIG TOWING RECOVERY SYSTEM
# ==============================================================================

func _attach_tow_cable() -> void:
	is_towing_war_rig = true
	print("[TOWING] Attached tow cable to smoldering War-Rig!")
	
	# Create visual tow cable line
	if not is_instance_valid(tow_cable_node):
		tow_cable_mesh = ImmediateMesh.new()
		tow_cable_node = MeshInstance3D.new()
		tow_cable_node.name = "TowCableMesh"
		tow_cable_node.mesh = tow_cable_mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5, 0.0) # Radiant Amber Steel Cable
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.0)
		mat.emission_energy_multiplier = 4.0
		tow_cable_node.material_override = mat
		get_parent().add_child(tow_cable_node)

	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("⚙️ TOW CABLE HITCHED! Tow Mack's War-Rig across the city grid to Porter's Pit Garage for emergency overhaul!", "TOWING RECOVERY")

func _update_towing_physics(delta: float) -> void:
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if not is_instance_valid(campaign_mgr) or not campaign_mgr.is_norns_recovery_active:
		if is_towing_war_rig:
			_detach_tow_cable()
		return

	# Show HUD prompt when near wreck if not yet towed
	var wreck_pos: Vector3 = campaign_mgr.norns_recovery_drop_pos
	var dist_to_wreck: float = global_position.distance_to(wreck_pos)

	if not is_towing_war_rig:
		if dist_to_wreck <= 12.0:
			var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				neural_comms.send_message("PRESS [E] TO HITCH TOW CABLE TO WAR-RIG", "WAR-RIG RECOVERY")
		return

	# TOWING ACTIVE: Pull smoldering War-Rig mesh node behind player car at 8m distance
	var rig_node = campaign_mgr.norns_recovery_node
	if is_instance_valid(rig_node):
		var target_follow_pos: Vector3 = global_position + (global_transform.basis.z * 8.5)
		target_follow_pos.y = 0.5
		
		# Smooth physical tow pull lerp
		rig_node.global_position = rig_node.global_position.lerp(target_follow_pos, clamp(delta * 6.0, 0.0, 1.0))
		rig_node.look_at(global_position, Vector3.UP)
		campaign_mgr.norns_recovery_drop_pos = rig_node.global_position

		# Draw 3D glowing steel tow cable from rear bumper to War-Rig hitch
		if is_instance_valid(tow_cable_mesh):
			tow_cable_mesh.clear_surfaces()
			tow_cable_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			var rear_hitch_pos: Vector3 = global_position + (global_transform.basis.z * 1.5)
			var rig_hitch_pos: Vector3 = rig_node.global_position - (rig_node.global_transform.basis.z * 3.2)
			
			tow_cable_mesh.surface_add_vertex(rear_hitch_pos)
			tow_cable_mesh.surface_add_vertex(rig_hitch_pos)
			tow_cable_mesh.surface_end()

		# Check delivery drop-off at Porter's Pit Garage door
		var city_gen = get_parent().get_node_or_null("CityGenerator")
		if is_instance_valid(city_gen) and city_gen.porter_pit_door_pos != Vector3.ZERO:
			var dist_to_pit: float = global_position.distance_to(city_gen.porter_pit_door_pos)
			if dist_to_pit <= 15.0:
				_complete_towing_delivery(campaign_mgr)

func _detach_tow_cable() -> void:
	is_towing_war_rig = false
	if is_instance_valid(tow_cable_node):
		tow_cable_node.queue_free()

func _complete_towing_delivery(campaign_mgr: Node) -> void:
	print("[TOWING] Successfully delivered smoldering War-Rig to Porter's Pit Garage!")
	_detach_tow_cable()
	campaign_mgr.is_norns_recovery_active = false
	if is_instance_valid(campaign_mgr.norns_recovery_node):
		campaign_mgr.norns_recovery_node.queue_free()

	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("🔧 WAR-RIG DELIVERED TO THE PIT! Porter has begun emergency overhaul. Mack is ready for deployment!", "RECOVERY COMPLETE")
