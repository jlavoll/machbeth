extends Node

# ==============================================================================
# CAR ENGINE AUDIO & 3D ACOUSTIC SYSTEM (CarEngineAudio.gd)
# ==============================================================================
# 1. Plays 3D spatial engine audio attached directly to the player car (PlayerBlob).
# 2. Dynamically shifts pitch and volume according to vehicle speed.
# 3. Raycasts environment geometry in real-time to apply dynamic urban reverb & echo.
# 4. Performs camera occlusion raycasting to muffle sound behind buildings.
# ==============================================================================

# ------------------------------------------------------------------------------
# AUDIO FILE & BUS
# ------------------------------------------------------------------------------
const ENGINE_HUM_PATH: String = "res://sfx/engine_hum.ogg"

# Audio bus name (controlled by ESC menu Engine slider)
@export var audio_bus: String = "Engine"

# ------------------------------------------------------------------------------
# PITCH & VOLUME SETTINGS
# ------------------------------------------------------------------------------
@export_range(-24.0, 0.0, 0.5) var idle_semitone_shift: float = -1.0
@export_range(-6.0, 6.0, 0.5) var full_speed_semitone_shift: float = 7.0

@export_range(-80.0, 6.0, 0.5) var idle_volume_db: float = -20.0
@export_range(-40.0, 24.0, 0.5) var full_speed_volume_db: float = 1.0

@export_range(0.5, 20.0, 0.1) var response_speed: float = 4.0
@export_range(0.0, 10.0, 0.1) var speed_deadzone: float = 0.5
@export var respond_to_reverse: bool = true

# ------------------------------------------------------------------------------
# 3D ACOUSTICS & REVERB SETTINGS
# ------------------------------------------------------------------------------
# Maximum distance (meters) for acoustic raycasts to detect surrounding walls
@export_range(5.0, 50.0, 1.0) var max_acoustic_distance: float = 25.0

# Maximum reverb wetness when enclosed by high-rise buildings (0.0 = dry, 0.6 = heavy echo)
@export_range(0.0, 1.0, 0.05) var max_reverb_wetness: float = 0.45

# Low-pass filter cutoff frequency (Hz) when camera line-of-sight is occluded by a building
@export_range(400.0, 4000.0, 100.0) var occluded_lowpass_hz: float = 1200.0

@export var debug_print: bool = false

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

@onready var _player: CharacterBody3D = $"../PlayerCar"

# The 3D positional audio stream player attached to the car
var _player_node: AudioStreamPlayer3D

# Acoustic DSP Effects
var _reverb_effect: AudioEffectReverb
var _lowpass_effect: AudioEffectLowPassFilter

# Direct RayCast3D nodes for acoustic wall scanning
var _rays: Array[RayCast3D] = []
var _occlusion_ray: RayCast3D

# Smoothed acoustic state
var _current_reverb_wetness: float = 0.0
var _current_lowpass_hz: float = 20500.0

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_setup_audio_bus_and_dsp()
	_setup_3d_audio_player()
	_setup_acoustic_raycasts()

func _setup_audio_bus_and_dsp() -> void:
	# Ensure custom "Engine" audio bus exists
	var bus_idx = AudioServer.get_bus_index(audio_bus)
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, audio_bus)
		AudioServer.set_bus_send(bus_idx, "Master")
		print("[CarEngineAudio] Created '", audio_bus, "' audio bus.")

	# Attach Reverb effect if not already present
	_reverb_effect = AudioEffectReverb.new()
	_reverb_effect.room_size = 0.5
	_reverb_effect.wet = 0.0
	_reverb_effect.dry = 1.0
	AudioServer.add_bus_effect(bus_idx, _reverb_effect, 0)

	# Attach LowPass Filter effect for building occlusion
	_lowpass_effect = AudioEffectLowPassFilter.new()
	_lowpass_effect.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(bus_idx, _lowpass_effect, 1)

func _setup_3d_audio_player() -> void:
	# Create AudioStreamPlayer3D directly on the player vehicle
	_player_node = AudioStreamPlayer3D.new()
	_player_node.name = "Engine3DAudioPlayer"
	_player_node.bus = audio_bus
	_player_node.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player_node.unit_size = 10.0
	_player_node.max_distance = 150.0

	var stream = load(ENGINE_HUM_PATH)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_player_node.stream = stream

	_player_node.pitch_scale = _semitones_to_pitch_scale(idle_semitone_shift)
	_player_node.volume_db = idle_volume_db

	# Attach to the car and start playing
	_player.add_child(_player_node)
	_player_node.play()
	print("[CarEngineAudio] Custom 3D engine audio attached to car & playing.")

func _setup_acoustic_raycasts() -> void:
	# Create 6 directional rays to sample surrounding building geometry
	var directions: Array[Vector3] = [
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		(Vector3.FORWARD + Vector3.LEFT).normalized(),
		(Vector3.FORWARD + Vector3.RIGHT).normalized()
	]

	for i in range(directions.size()):
		var ray = RayCast3D.new()
		ray.name = "AcousticRay_" + str(i)
		ray.target_position = directions[i] * max_acoustic_distance
		ray.enabled = true
		_player.add_child(ray)
		_rays.append(ray)

	# Create line-of-sight occlusion ray from camera to player car
	_occlusion_ray = RayCast3D.new()
	_occlusion_ray.name = "CameraOcclusionRay"
	_occlusion_ray.enabled = true
	add_child(_occlusion_ray)

# ==============================================================================
# PER-FRAME UPDATE & ACOUSTIC CALCULATIONS
# ==============================================================================

func _process(delta: float) -> void:
	if not is_instance_valid(_player_node) or not is_instance_valid(_player):
		return

	_update_speed_pitch_and_volume(delta)
	_update_urban_acoustics_and_reverb(delta)
	_update_camera_occlusion(delta)

func _update_speed_pitch_and_volume(delta: float) -> void:
	var raw_speed: float = _player.current_speed
	raw_speed = abs(raw_speed) if respond_to_reverse else max(raw_speed, 0.0)

	var effective_speed: float = max(raw_speed - speed_deadzone, 0.0)
	var effective_max: float = max(_player.max_speed - speed_deadzone, 0.001)
	var speed_ratio: float = clamp(effective_speed / effective_max, 0.0, 1.0)

	var target_semitones: float = lerp(idle_semitone_shift, full_speed_semitone_shift, speed_ratio)
	var target_pitch_scale: float = _semitones_to_pitch_scale(target_semitones)
	var target_volume_db: float = lerp(idle_volume_db, full_speed_volume_db, speed_ratio)

	var t: float = clamp(response_speed * delta, 0.0, 1.0)
	_player_node.pitch_scale = lerp(_player_node.pitch_scale, target_pitch_scale, t)
	_player_node.volume_db = lerp(_player_node.volume_db, target_volume_db, t)

	if not _player_node.playing:
		_player_node.play()

func _update_urban_acoustics_and_reverb(delta: float) -> void:
	# Calculate wall proximity score from acoustic raycasts
	var hit_count: int = 0
	var total_proximity: float = 0.0

	for ray in _rays:
		if ray.is_colliding():
			hit_count += 1
			var hit_dist: float = _player.global_position.distance_to(ray.get_collision_point())
			var proximity: float = 1.0 - clamp(hit_dist / max_acoustic_distance, 0.0, 1.0)
			total_proximity += proximity

	# Target reverb wetness scales with surrounding wall proximity and enclosure density
	var target_wetness: float = 0.0
	if hit_count > 0:
		var avg_proximity: float = total_proximity / _rays.size()
		target_wetness = avg_proximity * max_reverb_wetness

	_current_reverb_wetness = lerp(_current_reverb_wetness, target_wetness, 3.0 * delta)
	if _reverb_effect:
		_reverb_effect.wet = _current_reverb_wetness
		_reverb_effect.dry = 1.0 - (_current_reverb_wetness * 0.5)

func _update_camera_occlusion(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	# Raycast line-of-sight from camera to car
	_occlusion_ray.global_position = camera.global_position
	_occlusion_ray.target_position = _player.global_position - camera.global_position

	var target_cutoff: float = 20500.0 # Open line of sight (unfiltered)
	if _occlusion_ray.is_colliding():
		var collider = _occlusion_ray.get_collider()
		# If ray hits a building/world collision instead of the player car, it's occluded
		if collider != _player:
			target_cutoff = occluded_lowpass_hz

	_current_lowpass_hz = lerp(_current_lowpass_hz, target_cutoff, 5.0 * delta)
	if _lowpass_effect:
		_lowpass_effect.cutoff_hz = _current_lowpass_hz

# ==============================================================================
# HELPERS
# ==============================================================================
func _semitones_to_pitch_scale(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)
