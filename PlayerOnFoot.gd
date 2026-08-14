extends CharacterBody3D
class_name PlayerOnFoot

# ==============================================================================
# PLAYER ON-FOOT SYSTEM (PlayerOnFoot.gd)
# ==============================================================================
# Car-style movement (W/S = forward/back, A/D = rotate).
# Scroll wheel zooms between top-down and over-the-shoulder.
# Hold LMB + drag mouse to freely orbit the camera around the player.
# Release LMB or start walking: camera smoothly returns behind the player.

# ==============================================================================
# PARAMETERS
# ==============================================================================

const WALK_SPEED:       float   = 3.5
const RUN_SPEED:        float   = 7.5
const RE_ENTER_RADIUS:  float   = 5.0
const TURN_SPEED:       float   = 1.8   # Slower, smoother on-foot turning speed (rad/s)
const CAM_LERP_SPEED:   float   = 4.0   # how fast offset lerps to target
const CAM_RETURN_SPEED: float   = 3.5   # how fast orbit yaw snaps back when walking
const ZOOM_STEP:        float   = 0.08  # zoom per scroll notch
const ORBIT_SENS:       float   = 0.004 # radians per pixel of mouse drag

# 3-Stage Camera Arc:
# Zoom 0.0: High-angle city overview (looking down/forward, includes character in frame)
# Zoom 1.0: Perfect Over-The-Shoulder view (swoops down right behind shoulder)
# Zoom 2.0: Skyline Look-Up (stays at over-shoulder position, tilts look target upwards to skyline)
const FOOT_ZOOM_MAX:    float   = 2.0
const CAM_FAR_OFFSET:  Vector3 = Vector3(0.0, 11.5, 7.5)  # High overview (pitched down looking at character + street ahead)
const CAM_NEAR_OFFSET: Vector3 = Vector3(0.35, 1.6, 1.8)  # Tighter, closer Over-The-Shoulder view (3.2m behind character)

# World Y height look target rises to during Stage 3 (Skyline Look-Up)
const CAM_SCENERY_LOOK_HEIGHT: float = 16.0

# ==============================================================================
# STATE
# ==============================================================================

var player_car:      PlayerCar
var camera:          Camera3D
var dialogue_system: DialogueSystem   # Set by Main scene after adding DialogueSystem node
var ambience_manager: Node            # WeatherAmbienceManager — set by Main/PlayerCar after spawn

# Surface type for footstep audio.
# Set this from an Area3D trigger when the player enters/leaves a grass zone.
# Defaults to CONCRETE (city streets).
# Use the WeatherAmbienceManager.FootstepSurface enum values:
#   0 = CONCRETE | 1 = CONCRETE_RAIN | 2 = GRASS | 3 = GRASS_RAIN
# The _fire_footstep() function automatically promotes CONCRETE → CONCRETE_RAIN
# and GRASS → GRASS_RAIN when rain weather is active, so just set the dry variant.
var current_surface: int = 0  # WeatherAmbienceManager.FootstepSurface.CONCRETE

var _foot_zoom:          float   = 0.0   # 0 = top-down, 1 = over-shoulder
var _cam_offset_current: Vector3          # smoothed offset (lerped each frame)
var _facing_angle:       float   = 0.0   # character Y rotation in radians
var _cam_yaw:            float   = 0.0   # orbital yaw offset in LOCAL space (0 = behind player)
var _cam_pitch:          float   = 0.0   # orbital pitch offset in radians (0 = default)
var _is_orbiting:        bool    = false  # true while LMB held

# Wardrobe Outfit Customization Palette (Head Glow Color)
var outfit_color_index: int = 0
var outfit_palette: Array[Dictionary] = [
	{"name": "Electric Magenta", "color": Color(1.0, 0.0, 0.8)},
	{"name": "Cyber Cyan", "color": Color(0.0, 1.0, 0.85)},
	{"name": "Gold Warlord", "color": Color(1.0, 0.85, 0.0)},
	{"name": "Neon Crimson", "color": Color(1.0, 0.1, 0.2)},
	{"name": "Emerald Matrix", "color": Color(0.2, 1.0, 0.4)},
	{"name": "Phantom Violet", "color": Color(0.6, 0.2, 1.0)}
]

# Interaction state: set by the scene when player enters an NPC/object trigger area
var _nearby_dialogue_source:  String = ""   # Path to dialogue JSON, empty = no NPC nearby
var _interaction_hint_label:  Label  = null  # "[F] Talk" HUD hint — created on demand

# Walk bob
var _bob_phase:     float = 0.0   # running sine phase
var _body_inst:     MeshInstance3D   # reference for bobbing
var _head_inst:     MeshInstance3D   # reference for bobbing
const BOB_BASE_Y_BODY: float = 0.6
const BOB_BASE_Y_HEAD: float = 1.35

# Footstep trigger — fires once per full bob cycle
var _last_step_floor: int = 0   # tracks which half-cycle we were in last frame

# ==============================================================================
# SETUP  (called by PlayerCar immediately after adding this node to scene)
# ==============================================================================

func setup(car: PlayerCar, cam: Camera3D, spawn_pos: Vector3) -> void:
	player_car = car
	camera     = cam
	position   = spawn_pos

	_foot_zoom          = 0.0
	_cam_offset_current = CAM_FAR_OFFSET   # start at the far (top-down) position
	rotation.y          = car.rotation.y   # Align character directly with the car's forward heading
	_facing_angle       = rotation.y
	_cam_yaw            = 0.0
	_cam_pitch          = 0.0
	_bob_phase          = 0.0

	_build_figure()

	# Reparent shared camera from the car to this node, keep world transform
	var world_cam: Transform3D = camera.global_transform
	car.remove_child(camera)
	add_child(camera)
	camera.global_transform = world_cam

# ==============================================================================
# FIGURE CONSTRUCTION
# ==============================================================================

func _build_figure() -> void:
	var neon_color := Color(0.85, 0.35, 0.05)   # Mysterious Dark Ember Orange

	# --- Body capsule --- (Dark charcoal trench coat / tactical outfit)
	var body_mat          := StandardMaterial3D.new()
	body_mat.albedo_color  = Color(0.03, 0.03, 0.04)
	var body_mesh         := CapsuleMesh.new()
	body_mesh.radius       = 0.15
	body_mesh.height       = 1.2
	_body_inst            = MeshInstance3D.new()
	_body_inst.name        = "PlayerBody"
	_body_inst.mesh        = body_mesh
	_body_inst.material_override = body_mat
	_body_inst.position    = Vector3(0.0, BOB_BASE_Y_BODY, 0.0)
	add_child(_body_inst)

	# --- Mysterious dark orange head sphere ---
	var head_mat                        := StandardMaterial3D.new()
	head_mat.albedo_color                = Color(0.2, 0.08, 0.02)
	head_mat.emission_enabled            = true
	head_mat.emission                    = neon_color
	head_mat.emission_energy_multiplier  = 1.8   # Toned down subtle mysterious glow
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	_head_inst            = MeshInstance3D.new()
	_head_inst.name        = "PlayerHead"
	_head_inst.mesh        = head_mesh
	_head_inst.material_override = head_mat
	_head_inst.position    = Vector3(0.0, BOB_BASE_Y_HEAD, 0.0)
	add_child(_head_inst)

	# --- Forward Visor / Nose Direction Pointer ---
	# Attached directly to head, points along local -Z (forward direction)
	var nose_mat                        := StandardMaterial3D.new()
	nose_mat.albedo_color                = Color(1.0, 0.5, 0.0) # Bright Amber Nose/Visor Tip
	nose_mat.emission_enabled            = true
	nose_mat.emission                    = Color(1.0, 0.6, 0.0)
	nose_mat.emission_energy_multiplier  = 4.0
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(0.12, 0.12, 0.22)
	var nose_inst                       := MeshInstance3D.new()
	nose_inst.name                       = "PlayerNose"
	nose_inst.mesh                       = nose_mesh
	nose_inst.material_override          = nose_mat
	# Position on front of head facing -Z (forward)
	nose_inst.position                   = Vector3(0.0, 0.0, -0.2)
	nose_inst.rotation_degrees           = Vector3(-90.0, 0.0, 0.0)
	_head_inst.add_child(nose_inst)

	# --- Collision capsule ---
	var col_shape    := CapsuleShape3D.new()
	col_shape.radius  = 0.2
	col_shape.height  = 1.5
	var col_inst     := CollisionShape3D.new()
	col_inst.shape    = col_shape
	col_inst.position = Vector3(0.0, 0.75, 0.0)
	add_child(col_inst)

func cycle_outfit_head_color() -> String:
	outfit_color_index = (outfit_color_index + 1) % outfit_palette.size()
	var choice = outfit_palette[outfit_color_index]
	var c_color: Color = choice["color"]
	var c_name: String = choice["name"]

	if is_instance_valid(_head_inst) and _head_inst.material_override is StandardMaterial3D:
		var mat = _head_inst.material_override as StandardMaterial3D
		mat.emission = c_color
		mat.albedo_color = Color(c_color.r * 0.2, c_color.g * 0.2, c_color.b * 0.2)

	var nose = _head_inst.get_node_or_null("PlayerNose") if is_instance_valid(_head_inst) else null
	if is_instance_valid(nose) and nose.material_override is StandardMaterial3D:
		var n_mat = nose.material_override as StandardMaterial3D
		n_mat.emission = c_color
		n_mat.albedo_color = c_color

	return c_name

# ==============================================================================
# PROCESS LOOP
# ==============================================================================

func _physics_process(delta: float) -> void:
	# Freeze all movement while dialogue is active so Mack stands still during conversations
	if is_instance_valid(dialogue_system) and dialogue_system._is_dialogue_active:
		return
	_handle_movement(delta)
	_update_camera(delta)

# ------------------------------------------------------------------------------
# MOVEMENT — car-style: W/S = forward/back along own axis, A/D = rotate
#            Shift = run. Walking bob animates body/head nodes, NOT the camera.
# ------------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	# Rotation
	var turn_input: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn_input -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn_input += 1.0

	if turn_input != 0.0:
		_facing_angle -= turn_input * TURN_SPEED * delta
		rotation.y     = _facing_angle

	# Forward / back + run
	var throttle: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0

	var is_running: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float     = RUN_SPEED if is_running else WALK_SPEED

	# While moving, smoothly return camera behind player
	var is_moving: bool = throttle != 0.0 or turn_input != 0.0
	if is_moving and not _is_orbiting:
		_cam_yaw = lerpf(_cam_yaw, 0.0, delta * CAM_RETURN_SPEED)

	var forward_dir: Vector3 = -transform.basis.z
	velocity = forward_dir * throttle * speed
	move_and_slide()

	# --------------------------------------------------------------------------
	# WALKING BOB — animates _body_inst and _head_inst Y position only
	# The camera parent (this node) stays perfectly still vertically
	# --------------------------------------------------------------------------
	if is_instance_valid(_body_inst) and is_instance_valid(_head_inst):
		if abs(throttle) > 0.01:
			# Phase advances faster when running
			var bob_freq: float = 14.0 if is_running else 8.0
			_bob_phase += delta * bob_freq
			var bob_y: float = abs(sin(_bob_phase)) * 0.1
			_body_inst.position.y = BOB_BASE_Y_BODY + bob_y
			_head_inst.position.y = BOB_BASE_Y_HEAD + bob_y

			# ----------------------------------------------------------------
			# FOOTSTEP TRIGGER
			# Fire once per full stride: detect when bob_phase crosses an
			# integer multiple of PI (bottom of each step).
			# ----------------------------------------------------------------
			var step_floor: int = int(_bob_phase / PI)
			if step_floor != _last_step_floor:
				_last_step_floor = step_floor
				_fire_footstep()
		else:
			# Smoothly settle back to rest position when stopping
			_body_inst.position.y = lerpf(_body_inst.position.y, BOB_BASE_Y_BODY, delta * 10.0)
			_head_inst.position.y = lerpf(_head_inst.position.y, BOB_BASE_Y_HEAD, delta * 10.0)

	# --------------------------------------------------------------------------
	# DUNCAN DYNAMICS HQ ENTRANCE PROMPT HUD LABEL
	# --------------------------------------------------------------------------
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	if is_instance_valid(city_gen) and city_gen.hq_door_pos != Vector3.ZERO:
		if global_position.distance_to(city_gen.hq_door_pos) <= 5.0:
			_show_hq_door_hint("[E] ENTER DUNCAN DYNAMICS HQ")
		else:
			_hide_hq_door_hint()
	else:
		_hide_hq_door_hint()

var _hq_door_hint_label: Label = null

func _show_hq_door_hint(text_msg: String) -> void:
	if not is_instance_valid(_hq_door_hint_label):
		_hq_door_hint_label = Label.new()
		_hq_door_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_hq_door_hint_label.anchor_top = 0.82
		_hq_door_hint_label.anchor_bottom = 0.82
		_hq_door_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var font_res = load("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")
		if font_res:
			_hq_door_hint_label.add_theme_font_override("font", font_res)
		_hq_door_hint_label.add_theme_font_size_override("font_size", 22)
		_hq_door_hint_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
		
		# CanvasLayer overlay
		var hud_canvas = CanvasLayer.new()
		hud_canvas.name = "HQDoorHUDCanvas"
		hud_canvas.add_child(_hq_door_hint_label)
		add_child(hud_canvas)

	_hq_door_hint_label.text = text_msg
	_hq_door_hint_label.visible = true

func _hide_hq_door_hint() -> void:
	if is_instance_valid(_hq_door_hint_label):
		_hq_door_hint_label.visible = false

# ------------------------------------------------------------------------------
# FOOTSTEP AUDIO
# Resolves wet/dry variant from weather, then delegates to WeatherAmbienceManager.
# ------------------------------------------------------------------------------
func _fire_footstep() -> void:
	if not is_instance_valid(ambience_manager):
		return
	if not ambience_manager.has_method("trigger_footstep"):
		return

	# Check whether rain is currently active
	var rain_active: bool = false
	var ws = ambience_manager.get("weather_system")
	if is_instance_valid(ws):
		var w = int(ws.current_weather)
		rain_active = (w == 0 or w == 2)  # NEON_RAIN or GLITCH_STORM

	# Resolve surface enum: promote dry → wet variant automatically when raining.
	# current_surface should always be the DRY base (CONCRETE=0, GRASS=2);
	# we add 1 to get the rain variant (CONCRETE_RAIN=1, GRASS_RAIN=3).
	var surface: int = current_surface
	if rain_active:
		# CONCRETE(0)->CONCRETE_RAIN(1), GRASS(2)->GRASS_RAIN(3)
		# Already-wet variants are left unchanged.
		if surface == 0:  # CONCRETE
			surface = 1   # CONCRETE_RAIN
		elif surface == 2:  # GRASS
			surface = 3   # GRASS_RAIN

	ambience_manager.trigger_footstep(surface)

# ------------------------------------------------------------------------------
# INPUT — mouse orbit (LMB drag), scroll zoom, E re-enter
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	# Block all camera orbit input while dialogue is active so LMB clicks
	# pass through to the choice buttons unobstructed.
	var dialogue_active: bool = is_instance_valid(dialogue_system) and dialogue_system._is_dialogue_active

	# LMB hold to orbit — skip entirely during dialogue
	if event is InputEventMouseButton and not dialogue_active:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_orbiting = event.pressed

	# If dialogue just opened while orbiting, release the orbit lock immediately
	if dialogue_active:
		_is_orbiting = false

	# Mouse drag while orbiting: horizontal = yaw, vertical = pitch
	if event is InputEventMouseMotion and _is_orbiting:
		_cam_yaw   -= event.relative.x * ORBIT_SENS
		# Pitch: positive mouse-Y = drag down = camera goes higher (more top-down)
		# Clamp so camera can't flip below ground or fully overhead
		_cam_pitch  = clamp(_cam_pitch + event.relative.y * ORBIT_SENS, -0.8, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel zoom — range 0 (top-down) → 1 (shoulder) → 2 (scenery tilt)
	# Block zoom input while dialogue is active
	var dialogue_blocking_input: bool = is_instance_valid(dialogue_system) and dialogue_system._is_dialogue_active

	if not dialogue_blocking_input and event is InputEventMouseButton and event.is_pressed():
		# Dynamic step size: finer steps (0.035) during Stage 3 skyline look-up for ultra-smooth precision
		var step: float = 0.035 if _foot_zoom >= 0.95 else 0.08
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_foot_zoom = clamp(_foot_zoom + step, 0.0, FOOT_ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_foot_zoom = clamp(_foot_zoom - step, 0.0, FOOT_ZOOM_MAX)

	if event is InputEventKey and event.pressed and not event.echo:
		# E key: Talk to nearby character, enter HQ building, or re-enter parked car when close enough
		if event.keycode == KEY_E and not dialogue_blocking_input:
			# 1. Check if standing near any playable interior entrance door!
			var city_gen = get_parent().get_node_or_null("CityGenerator")
			var indoor_mgr = get_parent().get_node_or_null("IndoorSystemManager")

			if is_instance_valid(city_gen) and is_instance_valid(indoor_mgr):
				if city_gen.hq_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.hq_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.LOBBY)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.banquo_safehouse_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.banquo_safehouse_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.BANQUO_LOFT)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.mack_hideout_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.mack_hideout_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.MACK_HIDEOUT)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.lady_m_lair_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.lady_m_lair_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.LADY_M_LAIR)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.chop_shop_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.chop_shop_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.CHOP_SHOP)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.porter_pit_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.porter_pit_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.PORTER_PIT)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.norns_ai_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.norns_ai_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.NORNS_AI)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.fife_hq_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.fife_hq_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.FIFE_HQ)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.bankes_logistics_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.bankes_logistics_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.BANKES_LOGISTICS)
					get_viewport().set_input_as_handled()
					return
				elif city_gen.power_substation_door_pos != Vector3.ZERO and global_position.distance_to(city_gen.power_substation_door_pos) <= 7.0:
					indoor_mgr.enter_location(indoor_mgr.HQFloor.SUBSTATION)
					get_viewport().set_input_as_handled()
					return

			# 1B. Check if standing near Banquo's Wardrobe Cupboard inside his loft!
			if is_instance_valid(indoor_mgr) and indoor_mgr.is_inside_building and indoor_mgr.current_floor == indoor_mgr.HQFloor.BANQUO_LOFT:
				var cupboard = get_parent().get_node_or_null("IndoorSystemManager/BanquoLoftRoot/WardrobeCupboard")
				if is_instance_valid(cupboard) and global_position.distance_to(cupboard.global_position) <= 3.5:
					var new_style: String = cycle_outfit_head_color()
					var comms = get_parent().get_node_or_null("NeuralCommsManager")
					if is_instance_valid(comms) and comms.has_method("send_message"):
						comms.send_message("👔 BANQUO'S WARDROBE: Changed head color outfit to [color=#FF00CC]%s[/color]!" % new_style, "OUTFIT CUSTOMIZER")
					get_viewport().set_input_as_handled()
					return

			# 2. Check if standing near an NPC / character to talk!
			var ped_system = get_parent().get_node_or_null("PedestrianSystem")
			var talk_triggered: bool = false
			if is_instance_valid(ped_system) and ped_system.has_method("_try_trigger_character_dialogue"):
				talk_triggered = ped_system._try_trigger_character_dialogue(global_position, dialogue_system)

			if talk_triggered:
				get_viewport().set_input_as_handled()
			elif is_instance_valid(player_car):
				var dist: float = global_position.distance_to(player_car.global_position)
				if dist <= RE_ENTER_RADIUS:
					player_car.on_foot_reenter(camera, _foot_zoom)
					get_viewport().set_input_as_handled()

		# F key: interact with nearby NPC / object (opens dialogue overlay)
		elif event.keycode == KEY_F and not dialogue_blocking_input:
			if _nearby_dialogue_source != "" and is_instance_valid(dialogue_system):
				dialogue_system.start_dialogue(_nearby_dialogue_source)
				get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# CAMERA — orbital offset with yaw+pitch, lerped each frame, always looks at head
# ------------------------------------------------------------------------------
func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return

	# Lerp the local offset toward the current zoom target.
	# The offset only interpolates over the 0–1 range; beyond 1.0 it stays at
	# CAM_NEAR_OFFSET and the camera instead tilts upward (scenery mode).
	var offset_zoom: float = clamp(_foot_zoom, 0.0, 1.0)
	var target_offset: Vector3 = CAM_FAR_OFFSET.lerp(CAM_NEAR_OFFSET, offset_zoom)
	_cam_offset_current = _cam_offset_current.lerp(target_offset, delta * CAM_LERP_SPEED)

	# --- Apply orbital yaw (rotate offset around local Y) ---
	var yc: float   = cos(_cam_yaw)
	var ys: float   = sin(_cam_yaw)
	var b:  Vector3 = _cam_offset_current
	var rotated: Vector3 = Vector3(
		b.x * yc + b.z * ys,
		b.y,
		-b.x * ys + b.z * yc
	)

	# --- Apply orbital pitch (raise/lower the camera around local X) ---
	# Pitch moves the camera along the arc: positive pitch = camera pulls upward/back
	var pitch_offset: float = rotated.length() * sin(_cam_pitch)
	rotated.y += pitch_offset
	# Keep a minimum height so camera never goes below ground
	rotated.y = max(rotated.y, 0.5)

	camera.position = rotated

	# --- 3-STAGE CAMERA LOOK-AT ARC ---
	# Zoom 0.0 -> 1.0: Swoops from high overview down to head/shoulder level (y = 1.35)
	# Zoom 1.0 -> 2.0: Camera stays at shoulder position while look target smoothly tilts UPWARDS to skyline
	var look_base_y: float = lerpf(0.6, 1.35, offset_zoom)
	var scenery_factor: float = clamp(_foot_zoom - 1.0, 0.0, 1.0)
	var look_y: float = lerpf(look_base_y, CAM_SCENERY_LOOK_HEIGHT, scenery_factor)
	var look_world: Vector3 = global_position + Vector3(0.0, look_y, 0.0)
	if camera.global_position.distance_to(look_world) > 0.05:
		camera.look_at(look_world, Vector3.UP)

	# --- 95° WIDE-ANGLE ON-FOOT FOV ---
	camera.fov = 95.0
