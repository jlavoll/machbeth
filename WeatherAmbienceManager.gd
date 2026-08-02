extends Node

# ==============================================================================
# CYBERPUNK WEATHER AMBIENCE AUDIO MANAGER (WeatherAmbienceManager.gd)
# ==============================================================================
# Manages seamless looping 24-bit 48kHz WAV weather soundscapes and smooth 
# crossfading transitions between rain downpours and textural wind breezes
# when weather states change.

@export var max_rain_volume_db: float = 0.0
@export var max_wind_volume_db: float = -17.0
@export var crossfade_duration_seconds: float = 2.5

# Audio players
var rain_audio_player: AudioStreamPlayer
var wind_audio_player: AudioStreamPlayer

# Target volume tracking for smooth lerp crossfading (start rain volume at max_rain_volume_db)
var target_rain_volume_db: float = 0.0
var target_wind_volume_db: float = -80.0

@onready var weather_system = $"../WeatherSystem"

# Sound File Paths (.ogg Ogg Vorbis streams in /ambience/)
const RAIN_SOUND_PATH: String = "res://ambience/QP03 0303 Rain downpour fluctuates.ogg"
const WIND_SOUND_PATH: String = "res://ambience/WIND_Winds Textural Breeze Light Debris_B00M_3DS06_2.0.ogg"

# ==============================================================================
# INITIALIZATION & STREAM LOADING
# ==============================================================================

# Custom Audio Bus Name for Vehicle Cabin Acoustics
const CABIN_BUS_NAME: String = "CarCabinAmbience"

# ==============================================================================
# INITIALIZATION & CABIN DSP AUDIO EFFECT BUS SETUP
# ==============================================================================

func _ready() -> void:
	_create_car_cabin_audio_bus()
	target_rain_volume_db = max_rain_volume_db
	_setup_rain_audio_player()
	_setup_wind_audio_player()
	_sync_weather_state_check()

# ------------------------------------------------------------------------------
# DYNAMIC AUDIO BUS CREATION WITH LOWPASS FILTER & TIGHT CABIN REVERB
# ------------------------------------------------------------------------------
func _create_car_cabin_audio_bus() -> void:
	# Check if custom CarCabinAmbience audio bus already exists, create if not
	var bus_index: int = AudioServer.get_bus_index(CABIN_BUS_NAME)
	if bus_index == -1:
		bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, CABIN_BUS_NAME)
		AudioServer.set_bus_send(bus_index, "Master")
		
		# 1. Lowpass Filter Effect (Muffles harsh outdoor rain highs so it sounds inside car interior)
		var lowpass_filter = AudioEffectLowPassFilter.new()
		lowpass_filter.cutoff_hz = 1800.0 # Muffle high frequencies above 1.8kHz
		lowpass_filter.resonance = 0.5
		AudioServer.add_bus_effect(bus_index, lowpass_filter)
		
		# 2. Tight Enclosed Car Cabin Reverb Effect
		var cabin_reverb = AudioEffectReverb.new()
		cabin_reverb.room_size = 0.15  # Small tight room size matching car interior
		cabin_reverb.damping = 0.85    # High acoustic absorption/damping
		cabin_reverb.wet = 0.25        # 25% wet acoustic resonance
		cabin_reverb.dry = 0.85        # 85% direct muffled signal
		AudioServer.add_bus_effect(bus_index, cabin_reverb)
		
		print("[AMBIENCE DSP] Created 'CarCabinAmbience' Audio Bus with Lowpass Filter & Tight Cabin Reverb.")

# ------------------------------------------------------------------------------
# 1. RAIN AUDIO STREAM PLAYER SETUP
# ------------------------------------------------------------------------------
func _setup_rain_audio_player() -> void:
	rain_audio_player = AudioStreamPlayer.new()
	rain_audio_player.name = "RainAudioPlayer"
	rain_audio_player.bus = CABIN_BUS_NAME
	rain_audio_player.autoplay = true
	add_child(rain_audio_player)

	
	var stream = load(RAIN_SOUND_PATH)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		rain_audio_player.stream = stream
		rain_audio_player.volume_db = 1.0 # Boost initial decibel level to +6.0dB
		rain_audio_player.play()
		print("[AMBIENCE SUCCESS] Rain downpour .ogg stream loaded & playing at ", rain_audio_player.volume_db, "dB.")
	else:
		print("[AMBIENCE ERROR] Failed to load rain sound at: ", RAIN_SOUND_PATH)

# ------------------------------------------------------------------------------
# 2. WIND AUDIO STREAM PLAYER SETUP
# ------------------------------------------------------------------------------
func _setup_wind_audio_player() -> void:
	wind_audio_player = AudioStreamPlayer.new()
	wind_audio_player.name = "WindAudioPlayer"
	wind_audio_player.bus = CABIN_BUS_NAME
	wind_audio_player.autoplay = true
	add_child(wind_audio_player)

	
	var stream = load(WIND_SOUND_PATH)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		wind_audio_player.stream = stream
		wind_audio_player.volume_db = -80.0
		wind_audio_player.play()
		print("[AMBIENCE SUCCESS] Textural wind breeze .ogg stream loaded & playing.")
	else:
		print("[AMBIENCE ERROR] Failed to load wind sound at: ", WIND_SOUND_PATH)

# ==============================================================================
# PROCESS LOOP & CROSSFADE LERP
# ==============================================================================

func _process(delta: float) -> void:
	_sync_weather_state_check()
	_apply_volume_crossfade(delta)

# Checks weather state from WeatherSystem.gd if active
func _sync_weather_state_check() -> void:
	if is_instance_valid(weather_system):
		var w_state = weather_system.current_weather
		if int(w_state) == 0: # NEON_RAIN
			target_rain_volume_db = max_rain_volume_db + 6.0 # +6dB boost
			target_wind_volume_db = -80.0
		elif int(w_state) == 1: # CYBER_SNOW
			target_rain_volume_db = -80.0
			target_wind_volume_db = max_wind_volume_db + 6.0
		else:
			target_rain_volume_db = -80.0
			target_wind_volume_db = max_wind_volume_db

# Smoothly interpolates decibel levels for seamless crossfading
func _apply_volume_crossfade(delta: float) -> void:
	var lerp_speed: float = (80.0 / crossfade_duration_seconds) * delta
	
	if is_instance_valid(rain_audio_player):
		rain_audio_player.volume_db = move_toward(rain_audio_player.volume_db, target_rain_volume_db, lerp_speed)
		if not rain_audio_player.playing:
			rain_audio_player.play()
	if is_instance_valid(wind_audio_player):
		wind_audio_player.volume_db = move_toward(wind_audio_player.volume_db, target_wind_volume_db, lerp_speed)
		if not wind_audio_player.playing:
			wind_audio_player.play()
