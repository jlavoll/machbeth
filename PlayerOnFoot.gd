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
const TURN_SPEED:       float   = 3.2   # rad/s — matches car steer_speed
const CAM_LERP_SPEED:   float   = 4.0   # how fast offset lerps to target
const CAM_RETURN_SPEED: float   = 3.5   # how fast orbit yaw snaps back when walking
const ZOOM_STEP:        float   = 0.08  # zoom per scroll notch (0–1 range)
const ORBIT_SENS:       float   = 0.004 # radians per pixel of mouse drag

# Camera offset extremes (zoom 0 = far/top-down, zoom 1 = near/over-shoulder)
const CAM_FAR_OFFSET:  Vector3 = Vector3(0.0,  18.0, 5.0)
const CAM_NEAR_OFFSET: Vector3 = Vector3(0.35,  2.0, 3.5)

# ==============================================================================
# STATE
# ==============================================================================

var player_car: PlayerCar
var camera:     Camera3D

var _foot_zoom:          float   = 0.0   # 0 = top-down, 1 = over-shoulder
var _cam_offset_current: Vector3          # smoothed offset (lerped each frame)
var _facing_angle:       float   = 0.0   # character Y rotation in radians
var _cam_yaw:            float   = 0.0   # orbital yaw offset in LOCAL space (0 = behind player)
var _cam_pitch:          float   = 0.0   # orbital pitch offset in radians (0 = default)
var _is_orbiting:        bool    = false  # true while LMB held

# Walk bob
var _bob_phase:     float = 0.0   # running sine phase
var _body_inst:     MeshInstance3D   # reference for bobbing
var _head_inst:     MeshInstance3D   # reference for bobbing
const BOB_BASE_Y_BODY: float = 0.6
const BOB_BASE_Y_HEAD: float = 1.35

# ==============================================================================
# SETUP  (called by PlayerCar immediately after adding this node to scene)
# ==============================================================================

func setup(car: PlayerCar, cam: Camera3D, spawn_pos: Vector3) -> void:
	player_car = car
	camera     = cam
	position   = spawn_pos

	_foot_zoom          = 0.0
	_cam_offset_current = CAM_FAR_OFFSET   # start at the far (top-down) position
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
	var neon_color := Color(0.4, 1.0, 1.0)   # Ice-cyan — subtly different from crowd

	# --- Body capsule ---
	var body_mat          := StandardMaterial3D.new()
	body_mat.albedo_color  = Color(0.05, 0.05, 0.08)
	var body_mesh         := CapsuleMesh.new()
	body_mesh.radius       = 0.15
	body_mesh.height       = 1.2
	_body_inst            = MeshInstance3D.new()
	_body_inst.name        = "PlayerBody"
	_body_inst.mesh        = body_mesh
	_body_inst.material_override = body_mat
	_body_inst.position    = Vector3(0.0, BOB_BASE_Y_BODY, 0.0)
	add_child(_body_inst)

	# --- Glowing head sphere ---
	var head_mat                        := StandardMaterial3D.new()
	head_mat.albedo_color                = neon_color
	head_mat.emission_enabled            = true
	head_mat.emission                    = neon_color
	head_mat.emission_energy_multiplier  = 4.5   # Slightly brighter than NPCs (3.5)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	_head_inst            = MeshInstance3D.new()
	_head_inst.name        = "PlayerHead"
	_head_inst.mesh        = head_mesh
	_head_inst.material_override = head_mat
	_head_inst.position    = Vector3(0.0, BOB_BASE_Y_HEAD, 0.0)
	add_child(_head_inst)

	# --- Collision capsule ---
	var col_shape    := CapsuleShape3D.new()
	col_shape.radius  = 0.2
	col_shape.height  = 1.5
	var col_inst     := CollisionShape3D.new()
	col_inst.shape    = col_shape
	col_inst.position = Vector3(0.0, 0.75, 0.0)
	add_child(col_inst)

# ==============================================================================
# PROCESS LOOP
# ==============================================================================

func _physics_process(delta: float) -> void:
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
		else:
			# Smoothly settle back to rest position when stopping
			_body_inst.position.y = lerpf(_body_inst.position.y, BOB_BASE_Y_BODY, delta * 10.0)
			_head_inst.position.y = lerpf(_head_inst.position.y, BOB_BASE_Y_HEAD, delta * 10.0)

# ------------------------------------------------------------------------------
# INPUT — mouse orbit (LMB drag), scroll zoom, E re-enter
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	# LMB hold to orbit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_orbiting = event.pressed

	# Mouse drag while orbiting: horizontal = yaw, vertical = pitch
	if event is InputEventMouseMotion and _is_orbiting:
		_cam_yaw   -= event.relative.x * ORBIT_SENS
		# Pitch: positive mouse-Y = drag down = camera goes higher (more top-down)
		# Clamp so camera can't flip below ground or fully overhead
		_cam_pitch  = clamp(_cam_pitch + event.relative.y * ORBIT_SENS, -0.8, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel zoom
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_foot_zoom = clamp(_foot_zoom + ZOOM_STEP, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_foot_zoom = clamp(_foot_zoom - ZOOM_STEP, 0.0, 1.0)

	# E key: re-enter the parked car when close enough
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and is_instance_valid(player_car):
			var dist: float = global_position.distance_to(player_car.global_position)
			if dist <= RE_ENTER_RADIUS:
				player_car.on_foot_reenter(camera)
				# Mark handled so PlayerCar's _unhandled_input doesn't see the
				# same E press and immediately re-exits the car
				get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------
# CAMERA — orbital offset with yaw+pitch, lerped each frame, always looks at head
# ------------------------------------------------------------------------------
func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return

	# Lerp the local offset toward the current zoom target
	var target_offset: Vector3 = CAM_FAR_OFFSET.lerp(CAM_NEAR_OFFSET, _foot_zoom)
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

	# Always look at the player's head — gives natural pitch at all zoom/orbit angles
	var head_world: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	if camera.global_position.distance_to(head_world) > 0.05:
		camera.look_at(head_world, Vector3.UP)
