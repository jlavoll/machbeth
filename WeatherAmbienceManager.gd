extends Node

# ==============================================================================
# CYBERPUNK WEATHER AMBIENCE AUDIO MANAGER (WeatherAmbienceManager.gd)
# ==============================================================================
# Manages seamless looping 24-bit 48kHz WAV weather soundscapes and smooth
# crossfading transitions between rain downpours and textural wind breezes
# when weather states change.
#
# CABIN FILTER TRANSITION
# -----------------------
# While the player is inside the car the rain is routed through the
# CarCabinAmbience bus (lowpass 1800 Hz + tight reverb).  When the player
# exits the car the filter cutoff smoothly lerps up to 20 kHz (effectively
# bypassed) and the reverb wet mix fades to 0, giving a natural "stepping
# outside" acoustic transition.  Re-entering reverses the process.
#
# OUTDOOR AMBIENT LAYERS (prepared — wire up file paths when assets exist)
# -----------------------------------------------------------------------
# • rain_on_roof_player – rain drumming on car roof, only audible near/inside car
#
# FOOTSTEP SURFACE BANKS  (one-shot, randomised, no repeat)
# ----------------------------------------------------------
# Four banks keyed by FootstepSurface enum:
#   CONCRETE      – dry asphalt / pavement (10 clips in /sfx/)
#   CONCRETE_RAIN – wet asphalt / puddles   (10 clips in /sfx/)
#   GRASS         – dry grass               (fill paths when assets arrive)
#   GRASS_RAIN    – wet grass / rain        (fill paths when assets arrive)
#
# PlayerOnFoot exposes a `current_surface` var.  Set it from a trigger area
# (Area3D) when the player enters/leaves a grass zone.  The footstep timer
# then picks the correct bank automatically.

@export var max_rain_volume_db: float = -10
@export var max_wind_volume_db: float = -17.0
@export var crossfade_duration_seconds: float = 1.5

# How long (seconds) the cabin filter fades in/out on car entry/exit
@export var cabin_filter_transition_seconds: float = 1.8

# Audio players — rain & wind (main ambience bus)
var rain_audio_player: AudioStreamPlayer
var wind_audio_player: AudioStreamPlayer

# Target volume tracking for smooth lerp crossfading (start rain volume at max_rain_volume_db)
var target_rain_volume_db: float = 0.0
var target_wind_volume_db: float = -80.0

@onready var weather_system = $"../WeatherSystem"

# Sound File Paths (.ogg Ogg Vorbis streams in /ambience/)
const RAIN_SOUND_PATH: String = "res://ambience/QP03 0303 Rain downpour fluctuates.ogg"
const WIND_SOUND_PATH: String = "res://ambience/WIND_Winds Textural Breeze Light Debris_B00M_3DS06_2.0.ogg"

# ------------------------------------------------------------------------------
# OUTDOOR AMBIENT LAYER FILE PATHS
# ------------------------------------------------------------------------------
const RAIN_ON_ROOF_PATH: String = ""   # e.g. "res://ambience/rain_on_car_roof.ogg"

# ==============================================================================
# FOOTSTEP SURFACE ENUM
# ==============================================================================

enum FootstepSurface {
	CONCRETE,       # dry asphalt / pavement
	CONCRETE_RAIN,  # wet asphalt / puddles
	GRASS,          # dry grass
	GRASS_RAIN,     # wet grass / rain
}

# ------------------------------------------------------------------------------
# FOOTSTEP CLIP BANKS  (one-shot .ogg files in /sfx/)
# Add / remove paths freely — each bank can hold any number of clips.
# ------------------------------------------------------------------------------

# Concrete — dry  (10 clips, ready)
const FOOTSTEP_CONCRETE_PATHS: Array[String] = [
	"res://sfx/footstep dry-01.ogg",
	"res://sfx/footstep dry-02.ogg",
	"res://sfx/footstep dry-03.ogg",
	"res://sfx/footstep dry-04.ogg",
	"res://sfx/footstep dry-05.ogg",
	"res://sfx/footstep dry-06.ogg",
	"res://sfx/footstep dry-07.ogg",
	"res://sfx/footstep dry-08.ogg",
	"res://sfx/footstep dry-09.ogg",
	"res://sfx/footstep dry-10.ogg",
]

# Concrete — rain / wet  (10 clips, ready)
const FOOTSTEP_CONCRETE_RAIN_PATHS: Array[String] = [
	"res://sfx/footstep wet-01.ogg",
	"res://sfx/footstep wet-02.ogg",
	"res://sfx/footstep wet-03.ogg",
	"res://sfx/footstep wet-04.ogg",
	"res://sfx/footstep wet-05.ogg",
	"res://sfx/footstep wet-06.ogg",
	"res://sfx/footstep wet-07.ogg",
	"res://sfx/footstep wet-08.ogg",
	"res://sfx/footstep wet-09.ogg",
	"res://sfx/footstep wet-10.ogg",
]

# Grass — dry  (fill in paths once you have the assets)
const FOOTSTEP_GRASS_PATHS: Array[String] = [
	# "res://sfx/footstep grass-01.ogg",
	# "res://sfx/footstep grass-02.ogg",
	# ...
]

# Grass — rain / wet  (fill in paths once you have the assets)
const FOOTSTEP_GRASS_RAIN_PATHS: Array[String] = [
	# "res://sfx/footstep grass rain-01.ogg",
	# "res://sfx/footstep grass rain-02.ogg",
	# ...
]

# ==============================================================================
# CABIN DSP BUS CONSTANTS
# ==============================================================================

const CABIN_BUS_NAME: String = "CarCabinAmbience"

# Cabin filter parameter targets
const FILTER_CUTOFF_INSIDE:  float = 1800.0   # Hz — muffled indoor rain
const FILTER_CUTOFF_OUTSIDE: float = 20000.0  # Hz — full-range outdoor rain
const REVERB_WET_INSIDE:     float = 0.25     # 25% wet — cabin resonance
const REVERB_WET_OUTSIDE:    float = 0.0      # 0% wet — no reverb when outside

# Indices of DSP effects on the CarCabinAmbience bus (set during bus creation)
var _lowpass_effect_index: int = 0
var _reverb_effect_index:  int = 1

# Live references to the effect resources so we can tween their properties
var _lowpass_effect: AudioEffectLowPassFilter = null
var _reverb_effect:  AudioEffectReverb        = null

# ==============================================================================
# CABIN / OUTDOOR STATE
# ==============================================================================

## Set this to false when the player exits the car, true when they re-enter.
## WeatherAmbienceManager will smoothly transition the DSP effects accordingly.
var is_player_in_car: bool = true

# Internal lerp targets driven by is_player_in_car
var _target_filter_cutoff: float = FILTER_CUTOFF_INSIDE
var _target_reverb_wet:    float = REVERB_WET_INSIDE

# ==============================================================================
# OUTDOOR AMBIENT LAYER PLAYERS (populated in _setup_outdoor_layers)
# ==============================================================================

var rain_on_roof_player: AudioStreamPlayer = null

# Target volume for rain-on-roof looping layer
var _target_roof_rain_db: float = -80.0

# ==============================================================================
# FOOTSTEP ONE-SHOT SYSTEM
# ==============================================================================

# Pre-loaded clip arrays — one per FootstepSurface variant
var _footstep_concrete_streams:      Array[AudioStream] = []
var _footstep_concrete_rain_streams: Array[AudioStream] = []
var _footstep_grass_streams:         Array[AudioStream] = []
var _footstep_grass_rain_streams:    Array[AudioStream] = []

# Dedicated AudioStreamPlayer for one-shot footstep playback
var _footstep_player: AudioStreamPlayer = null

# Volume for footstep playback (dB).  Tune to taste.
@export var footstep_volume_db: float = -8.0

# Last clip indices per bank — prevent the same clip playing twice in a row
var _last_concrete_index:      int = -1
var _last_concrete_rain_index: int = -1
var _last_grass_index:         int = -1
var _last_grass_rain_index:    int = -1

# ==============================================================================
# INITIALIZATION & STREAM LOADING
# ==============================================================================

func _ready() -> void:
	_create_car_cabin_audio_bus()
	target_rain_volume_db = max_rain_volume_db
	_setup_rain_audio_player()
	_setup_wind_audio_player()
	_setup_outdoor_layers()
	_setup_footstep_banks()
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
		lowpass_filter.cutoff_hz = FILTER_CUTOFF_INSIDE  # Muffle high frequencies above 1.8kHz
		lowpass_filter.resonance = 0.5
		AudioServer.add_bus_effect(bus_index, lowpass_filter, _lowpass_effect_index)

		# 2. Tight Enclosed Car Cabin Reverb Effect
		var cabin_reverb = AudioEffectReverb.new()
		cabin_reverb.room_size = 0.15  # Small tight room size matching car interior
		cabin_reverb.damping   = 0.85  # High acoustic absorption/damping
		cabin_reverb.wet       = REVERB_WET_INSIDE
		cabin_reverb.dry       = 0.85  # 85% direct muffled signal
		AudioServer.add_bus_effect(bus_index, cabin_reverb, _reverb_effect_index)

		print("[AMBIENCE DSP] Created 'CarCabinAmbience' Audio Bus with Lowpass Filter & Tight Cabin Reverb.")

	# Cache live references so we can tween the properties each frame
	_lowpass_effect = AudioServer.get_bus_effect(bus_index, _lowpass_effect_index) as AudioEffectLowPassFilter
	_reverb_effect  = AudioServer.get_bus_effect(bus_index, _reverb_effect_index)  as AudioEffectReverb

# ------------------------------------------------------------------------------
# 1. RAIN AUDIO STREAM PLAYER SETUP
# ------------------------------------------------------------------------------
func _setup_rain_audio_player() -> void:
	rain_audio_player = AudioStreamPlayer.new()
	rain_audio_player.name     = "RainAudioPlayer"
	rain_audio_player.bus      = CABIN_BUS_NAME
	rain_audio_player.autoplay = true
	add_child(rain_audio_player)

	var stream = load(RAIN_SOUND_PATH)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		rain_audio_player.stream    = stream
		rain_audio_player.volume_db = 1.0  # Boost initial decibel level to +1.0dB
		rain_audio_player.play()
		print("[AMBIENCE SUCCESS] Rain downpour .ogg stream loaded & playing at ", rain_audio_player.volume_db, "dB.")
	else:
		print("[AMBIENCE ERROR] Failed to load rain sound at: ", RAIN_SOUND_PATH)

# ------------------------------------------------------------------------------
# 2. WIND AUDIO STREAM PLAYER SETUP
# ------------------------------------------------------------------------------
func _setup_wind_audio_player() -> void:
	wind_audio_player = AudioStreamPlayer.new()
	wind_audio_player.name     = "WindAudioPlayer"
	wind_audio_player.bus      = CABIN_BUS_NAME
	wind_audio_player.autoplay = true
	add_child(wind_audio_player)

	var stream = load(WIND_SOUND_PATH)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		wind_audio_player.stream    = stream
		wind_audio_player.volume_db = -80.0
		wind_audio_player.play()
		print("[AMBIENCE SUCCESS] Textural wind breeze .ogg stream loaded & playing.")
	else:
		print("[AMBIENCE ERROR] Failed to load wind sound at: ", WIND_SOUND_PATH)

# ------------------------------------------------------------------------------
# 3. OUTDOOR AMBIENT LAYERS SETUP
# Layers are created now and kept silent; volumes are driven each frame.
# Swap RAIN_ON_ROOF_PATH / FOOTSTEPS_*_PATH constants above once you have assets.
# ------------------------------------------------------------------------------
func _setup_outdoor_layers() -> void:
	# Rain drumming on the car roof (audible near/inside car when it's raining)
	rain_on_roof_player = _create_ambient_player("RainOnRoofPlayer", "Master", RAIN_ON_ROOF_PATH)

## Helper: create a silent, looping AudioStreamPlayer child.  Returns null-safe node.
func _create_ambient_player(player_name: String, bus_name: String, file_path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name      = player_name
	player.bus       = bus_name
	player.volume_db = -80.0
	add_child(player)

	if file_path != "":
		var stream = load(file_path)
		if stream:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			player.stream = stream
			player.play()
			print("[AMBIENCE] Loaded outdoor layer: ", player_name)
		else:
			print("[AMBIENCE WARN] Could not load: ", file_path, " (", player_name, ")")
	else:
		print("[AMBIENCE] Outdoor layer '", player_name, "' ready — no asset path set yet.")

	return player

# ------------------------------------------------------------------------------
# FOOTSTEP BANK SETUP
# Pre-loads all footstep clips for every surface type into memory.
# Banks with empty path arrays are silently skipped — add paths to activate.
# ------------------------------------------------------------------------------
func _setup_footstep_banks() -> void:
	# Dedicated one-shot player (no loop, no autoplay)
	_footstep_player           = AudioStreamPlayer.new()
	_footstep_player.name      = "FootstepPlayer"
	_footstep_player.bus       = "Master"
	_footstep_player.volume_db = footstep_volume_db
	add_child(_footstep_player)

	_load_bank(FOOTSTEP_CONCRETE_PATHS,      _footstep_concrete_streams,      "concrete")
	_load_bank(FOOTSTEP_CONCRETE_RAIN_PATHS, _footstep_concrete_rain_streams, "concrete_rain")
	_load_bank(FOOTSTEP_GRASS_PATHS,         _footstep_grass_streams,         "grass")
	_load_bank(FOOTSTEP_GRASS_RAIN_PATHS,    _footstep_grass_rain_streams,    "grass_rain")

	print("[AMBIENCE] Footstep banks — concrete: ", _footstep_concrete_streams.size(),
		" | concrete_rain: ",  _footstep_concrete_rain_streams.size(),
		" | grass: ",          _footstep_grass_streams.size(),
		" | grass_rain: ",     _footstep_grass_rain_streams.size())

## Internal helper — loads a list of paths into a stream array, prints warnings on failure.
func _load_bank(paths: Array[String], bank: Array[AudioStream], label: String) -> void:
	for path in paths:
		var s = load(path)
		if s:
			bank.append(s)
		else:
			print("[AMBIENCE WARN] Could not load footstep clip (", label, "): ", path)

# ==============================================================================
# PUBLIC API — called by PlayerCar on exit / reenter
# ==============================================================================

## Call with false when the player steps out of the car, true when they get back in.
func set_player_in_car(in_car: bool) -> void:
	is_player_in_car      = in_car
	_target_filter_cutoff = FILTER_CUTOFF_INSIDE  if in_car else FILTER_CUTOFF_OUTSIDE
	_target_reverb_wet    = REVERB_WET_INSIDE     if in_car else REVERB_WET_OUTSIDE
	print("[AMBIENCE] Cabin filter transition → ", "INSIDE" if in_car else "OUTSIDE")

# ------------------------------------------------------------------------------
# PUBLIC API — called by PlayerOnFoot on each footfall
# ------------------------------------------------------------------------------

## Call this every time the player's foot hits the ground.
## Pass the appropriate FootstepSurface variant for the terrain under the player.
## The manager picks a random non-repeating clip from the matching bank.
## If the bank for that surface is empty (assets not yet added), the call is a no-op.
func trigger_footstep(surface: FootstepSurface) -> void:
	if not is_instance_valid(_footstep_player):
		return

	var bank: Array[AudioStream]
	var last_idx: int

	match surface:
		FootstepSurface.CONCRETE:
			bank     = _footstep_concrete_streams
			last_idx = _last_concrete_index
		FootstepSurface.CONCRETE_RAIN:
			bank     = _footstep_concrete_rain_streams
			last_idx = _last_concrete_rain_index
		FootstepSurface.GRASS:
			bank     = _footstep_grass_streams
			last_idx = _last_grass_index
		FootstepSurface.GRASS_RAIN:
			bank     = _footstep_grass_rain_streams
			last_idx = _last_grass_rain_index
		_:
			return

	if bank.is_empty():
		return  # Assets not loaded yet — no-op until files are added

	# Pick a random index that differs from the last one played
	var idx: int = randi() % bank.size()
	if bank.size() > 1:
		while idx == last_idx:
			idx = randi() % bank.size()

	# Store last index back into the correct tracker
	match surface:
		FootstepSurface.CONCRETE:      _last_concrete_index      = idx
		FootstepSurface.CONCRETE_RAIN: _last_concrete_rain_index = idx
		FootstepSurface.GRASS:         _last_grass_index         = idx
		FootstepSurface.GRASS_RAIN:    _last_grass_rain_index    = idx

	_footstep_player.stream    = bank[idx]
	_footstep_player.volume_db = footstep_volume_db
	_footstep_player.play()

# ==============================================================================
# PROCESS LOOP & CROSSFADE LERP
# ==============================================================================

func _process(delta: float) -> void:
	_sync_weather_state_check()
	_apply_volume_crossfade(delta)
	_apply_cabin_filter_transition(delta)
	_apply_outdoor_layer_volumes(delta)

# Checks weather state from WeatherSystem.gd if active
func _sync_weather_state_check() -> void:
	if is_instance_valid(weather_system):
		var w_state = int(weather_system.current_weather)
		if w_state == 0 or w_state == 2: # NEON_RAIN or GLITCH_STORM
			target_rain_volume_db = max_rain_volume_db + 6.0
			target_wind_volume_db = -80.0
		elif w_state == 1 or w_state == 6: # CYBER_SNOW or ICE_DRIFT
			target_rain_volume_db = -80.0
			target_wind_volume_db = max_wind_volume_db + 6.0
		elif w_state == 5: # CYAN_DUST
			target_rain_volume_db = -80.0
			target_wind_volume_db = max_wind_volume_db + 10.0
		else: # NEBULA_DRIFT, SOLAR_EMBERS, EMP_STATIC, CYBER_WARP, CLEAR_NEON_NIGHT
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

# ------------------------------------------------------------------------------
# CABIN FILTER TRANSITION
# Smoothly tweens the lowpass cutoff frequency and reverb wet mix on the
# CarCabinAmbience bus so the acoustic character changes gradually rather than
# snapping when the car door opens or closes.
# ------------------------------------------------------------------------------
func _apply_cabin_filter_transition(delta: float) -> void:
	if _lowpass_effect == null or _reverb_effect == null:
		return

	# Lerp speed for cutoff: covers the full 1800 → 20000 Hz range in transition_seconds
	var cutoff_speed: float = ((FILTER_CUTOFF_OUTSIDE - FILTER_CUTOFF_INSIDE) / cabin_filter_transition_seconds) * delta
	_lowpass_effect.cutoff_hz = move_toward(
		_lowpass_effect.cutoff_hz,
		_target_filter_cutoff,
		cutoff_speed
	)

	# Lerp speed for reverb wet: covers 0 → 0.25 range in transition_seconds
	var wet_speed: float = (REVERB_WET_INSIDE / cabin_filter_transition_seconds) * delta
	_reverb_effect.wet = move_toward(
		_reverb_effect.wet,
		_target_reverb_wet,
		wet_speed
	)

# ------------------------------------------------------------------------------
# OUTDOOR AMBIENT LAYER VOLUMES
# Determines target volume for each outdoor layer based on weather + foot state,
# then smoothly lerps toward those targets.
# Extend this function as new layers are added.
# ------------------------------------------------------------------------------
func _apply_outdoor_layer_volumes(delta: float) -> void:
	var lerp_speed: float = (80.0 / crossfade_duration_seconds) * delta

	# Determine whether rain weather is currently active
	var rain_active: bool = false
	if is_instance_valid(weather_system):
		var w = int(weather_system.current_weather)
		rain_active = (w == 0 or w == 2) # NEON_RAIN or GLITCH_STORM

	# --- Rain on car roof ---
	# Audible only when inside the car and it's raining.
	# TODO: tune max volume once asset exists
	_target_roof_rain_db = (max_rain_volume_db - 6.0) if (is_player_in_car and rain_active) else -80.0

	if is_instance_valid(rain_on_roof_player):
		rain_on_roof_player.volume_db = move_toward(
			rain_on_roof_player.volume_db, _target_roof_rain_db, lerp_speed)
		if not rain_on_roof_player.playing and rain_on_roof_player.stream != null:
			rain_on_roof_player.play()

	# Note: footstep playback is triggered externally via trigger_footstep().
	# PlayerOnFoot calls it on each footfall; no per-frame volume lerp needed here.
