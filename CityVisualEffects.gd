extends Node

# ==============================================================================
# CITY VISUAL EFFECTS SYSTEM (CityVisualEffects.gd)
# ==============================================================================
# Controls aesthetic cyber glitches on the ground wireframe grid plane & city materials:
# - BPM-driven beat pulse clock (Defaults to 120.0 BPM if no active music audio stream is playing).
# - Periodic power supply hiccups & micro-flickers.
# - Dynamic color hue fluctuations along the cyber spectrum (Cyan -> Purple -> Blue -> Magenta).
# - Wave ripple pulse sweeping across the city grid coordinates.

@export var audio_stream_player_node: AudioStreamPlayer
@export var default_bpm_tempo: float = 120.0  # 120 beats per minute default

# References to targets in scene
@onready var city_generator = $"../CityGenerator"
@onready var music_manager = $"../MusicPlaylistManager"

# Global Visual Effect Potency Scaling (Default 50% strength)
@export var visual_effect_potency: float = 0.5

# Base colors for emission glitching
var base_cyan_emission: Color = Color(0.0, 0.85, 1.0) # Standard Neon Cyan
var target_emission_color: Color = Color(0.0, 0.85, 1.0)
var current_emission_color: Color = Color(0.0, 0.85, 1.0)

# Glitch state timers
var beat_accumulated_time: float = 0.0
var glitch_hiccup_timer: float = 0.0
var next_hiccup_interval: float = 4.0
var is_hiccup_active: bool = false
var hiccup_duration: float = 0.12

# --- CITY CORNER-TO-CORNER WAVE RIPPLE PARAMETERS ---
var wave_ripple_timer: float = 0.0
var next_wave_ripple_interval: float = 12.0 # Waves sweep every 12-24 seconds
var is_wave_ripple_active: bool = false
var wave_ripple_progress: float = 0.0 # Moves from 0.0 (Corner A) to 1.0 (Corner B)
var wave_ripple_speed: float = 0.5    # Completes sweep in ~2 seconds
var wave_ripple_color: Color = Color(1.0, 1.0, 1.0) # Bright pulse front

# Grid line instance reference
var grid_material_ref: StandardMaterial3D

# --- CITY LIGHTING STAGE SYSTEM (L KEY SHORTCUT) ---
# Modes: NORMAL (100%), LOW_LIGHT (25%), DIM (5%), DARK_BUILDINGS (0% buildings, 5% grid), PITCH_BLACK (0% all)
enum CityLightStage { NORMAL, LOW_LIGHT, DIM, DARK_BUILDINGS, PITCH_BLACK }
var current_city_light_stage: CityLightStage = CityLightStage.NORMAL

# ==============================================================================
# INITIALIZATION & SETUP
# ==============================================================================

func _ready() -> void:
	# Give CityGenerator time to build the grid material
	await get_tree().create_timer(0.2).timeout
	_find_grid_material_reference()

# Listen for L key shortcut to cycle City Lighting Stages
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			cycle_city_light_stage()

func _find_grid_material_reference() -> void:
	if is_instance_valid(city_generator):
		for child in city_generator.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var mat = child.material_override as StandardMaterial3D
				if mat.emission_enabled:
					grid_material_ref = mat
					break

# ==============================================================================
# PROCESS LOOP & BPM BEAT SYNCHRONIZATION
# ==============================================================================

func _process(delta: float) -> void:
	var active_bpm: float = default_bpm_tempo
	
	# Fetch live BPM from MusicPlaylistManager if available
	if is_instance_valid(music_manager) and music_manager.has_method("get_current_bpm"):
		active_bpm = music_manager.get_current_bpm()
	elif is_instance_valid(audio_stream_player_node) and audio_stream_player_node.playing:
		active_bpm = default_bpm_tempo

	# Calculate seconds per beat (120 BPM = 0.5s per beat)
	var seconds_per_beat: float = 60.0 / active_bpm
	beat_accumulated_time += delta

	# --------------------------------------------------------------------------
	# 1. BPM BEAT PULSE & HUE FLUCTUATION (EXPLICIT ON-BEAT COLOR DRIFT)
	# --------------------------------------------------------------------------
	if beat_accumulated_time >= seconds_per_beat:
		beat_accumulated_time -= seconds_per_beat
		_on_bpm_beat_trigger()

	# Smoothly interpolate current emission color towards target hue
	current_emission_color = current_emission_color.lerp(target_emission_color, delta * 2.0)

	# --------------------------------------------------------------------------
	# 2. POWER SUPPLY HICCUP & FLICKER EVENT
	# --------------------------------------------------------------------------
	glitch_hiccup_timer += delta
	if glitch_hiccup_timer >= next_hiccup_interval:
		_trigger_power_hiccup_glitch()

	# --------------------------------------------------------------------------
	# 3. CORNER-TO-CORNER CITY WAVE RIPPLE SWEEP
	# --------------------------------------------------------------------------
	wave_ripple_timer += delta
	if wave_ripple_timer >= next_wave_ripple_interval and not is_wave_ripple_active:
		_trigger_city_wave_ripple()

	if is_wave_ripple_active:
		wave_ripple_progress += delta * wave_ripple_speed
		if wave_ripple_progress >= 1.0:
			is_wave_ripple_active = false
			wave_ripple_progress = 0.0

	# --------------------------------------------------------------------------
	# 4. APPLY GLITCH & WAVE RIPPLE MATERIAL UPDATE (WITH CITY LIGHT STAGE MULTIPLIER)
	# --------------------------------------------------------------------------
	var dark_mult: float = _get_current_light_multiplier()

	if is_instance_valid(grid_material_ref):
		if dark_mult <= 0.0:
			grid_material_ref.emission_enabled = false
		else:
			grid_material_ref.emission_enabled = true
			if is_hiccup_active:
				var rng = RandomNumberGenerator.new()
				grid_material_ref.emission_energy_multiplier = (0.6 if rng.randf() > 0.5 else (3.0 + 3.0 * visual_effect_potency)) * dark_mult
				grid_material_ref.emission = Color(1.0, 1.0, 1.0)
			elif is_wave_ripple_active:
				var wave_intensity: float = sin(wave_ripple_progress * PI) * (3.0 * visual_effect_potency)
				grid_material_ref.emission = current_emission_color.lerp(wave_ripple_color, (wave_intensity / 3.0) * visual_effect_potency)
				grid_material_ref.emission_energy_multiplier = (3.0 + wave_intensity) * dark_mult
			else:
				grid_material_ref.emission = current_emission_color
				grid_material_ref.emission_energy_multiplier = (3.0 + sin(Time.get_ticks_msec() * 0.005) * (0.4 * visual_effect_potency)) * dark_mult

# ==============================================================================
# GLITCH EVENT TRIGGERS
# ==============================================================================

# Fired on every music BPM beat
func _on_bpm_beat_trigger() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Reduced to 12.5% chance per beat (50% of previous 25% frequency)
	if rng.randf() < (0.25 * visual_effect_potency):
		var hue_pick = rng.randi_range(1, 4)
		match hue_pick:
			1: target_emission_color = Color(0.0, 0.85, 1.0) # Cyan
			2: target_emission_color = Color(0.0, 0.4, 1.0)  # Electric Blue
			3: target_emission_color = Color(0.6, 0.0, 1.0)  # Deep Violet
			4: target_emission_color = Color(1.0, 0.0, 0.8)  # Hot Magenta

# Triggers a rare power supply glitch / ripple blackout
func _trigger_power_hiccup_glitch() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	is_hiccup_active = true
	glitch_hiccup_timer = 0.0
	# Schedule next hiccup less frequently (12 to 24 seconds)
	next_hiccup_interval = rng.randf_range(12.0, 24.0)

	# Reset hiccup active state after 0.08 seconds (shorter flicker)
	get_tree().create_timer(hiccup_duration * visual_effect_potency).timeout.connect(func():
		is_hiccup_active = false
	)

# Triggers a wave ripple sweeping across the city from one corner to the other
func _trigger_city_wave_ripple() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	is_wave_ripple_active = true
	wave_ripple_progress = 0.0
	wave_ripple_timer = 0.0
	# Schedule next wave sweep less frequently (14 to 28 seconds)
	next_wave_ripple_interval = rng.randf_range(14.0, 28.0)

	# Pick a subtle energy color for the ripple wave front
	wave_ripple_color = Color(1.0, 0.0, 0.8) if rng.randf() > 0.5 else Color(0.0, 1.0, 0.9)

# Helper to get current energy multiplier for active city lighting stage
func _get_current_light_multiplier() -> float:
	match current_city_light_stage:
		CityLightStage.NORMAL:         return 1.0
		CityLightStage.LOW_LIGHT:      return 0.25
		CityLightStage.DIM:            return 0.05
		CityLightStage.DARK_BUILDINGS: return 0.05  # Grid stays at 5% DIM level
		CityLightStage.PITCH_BLACK:    return 0.0
		_: return 1.0

# Cycles through city ambient lighting stages (L key shortcut)
func cycle_city_light_stage() -> void:
	match current_city_light_stage:
		CityLightStage.NORMAL:         current_city_light_stage = CityLightStage.LOW_LIGHT
		CityLightStage.LOW_LIGHT:      current_city_light_stage = CityLightStage.DIM
		CityLightStage.DIM:            current_city_light_stage = CityLightStage.DARK_BUILDINGS
		CityLightStage.DARK_BUILDINGS: current_city_light_stage = CityLightStage.PITCH_BLACK
		CityLightStage.PITCH_BLACK:    current_city_light_stage = CityLightStage.NORMAL

	_apply_city_lighting_stage()

func _apply_city_lighting_stage() -> void:
	var dark_mult: float = _get_current_light_multiplier()
	var building_mult: float = 0.0 if current_city_light_stage == CityLightStage.DARK_BUILDINGS else dark_mult
	var stage_name: String = ""

	match current_city_light_stage:
		CityLightStage.NORMAL:         stage_name = "NORMAL (100%)"
		CityLightStage.LOW_LIGHT:      stage_name = "LOW LIGHT (25%)"
		CityLightStage.DIM:            stage_name = "VERY DARK / DIM (5%)"
		CityLightStage.DARK_BUILDINGS: stage_name = "DARK BUILDINGS / LIT GRID (0% Buildings, 5% Road Grid)"
		CityLightStage.PITCH_BLACK:    stage_name = "PITCH BLACK (0% - ONLY CAR LIGHTS)"

	# Update emission energy multipliers on all building meshes, grass, water, and street lights
	if is_instance_valid(city_generator):
		_update_node_lighting_recursively(city_generator, building_mult)

	# Ensure ground wireframe grid is set to dark_mult (5% in DARK_BUILDINGS stage, 0% in PITCH_BLACK)
	if is_instance_valid(grid_material_ref):
		if dark_mult <= 0.0:
			grid_material_ref.emission_enabled = false
		else:
			grid_material_ref.emission_enabled = true
			grid_material_ref.emission_energy_multiplier = 3.0 * dark_mult

	print("[CITY VISUALS] City Lighting Stage: ", stage_name)

# Helper function to recursively update material emission across all city elements (buildings, grass, water, trees)
func _update_node_lighting_recursively(target_node: Node, mult: float) -> void:
	# Skip corner streetlights so independent floodlights stay on
	if "ParkingLotCornerSpotlight" in target_node.name:
		return

	if target_node is MeshInstance3D and target_node.material_override is StandardMaterial3D:
		var mat = target_node.material_override as StandardMaterial3D
		if mat.emission_enabled:
			# Skip the floor grid mesh — its emission is controlled separately so
			# DARK_BUILDINGS keeps the grid at 5% while buildings go to 0%
			if is_instance_valid(grid_material_ref) and mat == grid_material_ref:
				return
			mat.emission_energy_multiplier = 2.5 * mult
	elif target_node is OmniLight3D:
		target_node.light_energy = 2.0 * mult

	for child in target_node.get_children():
		_update_node_lighting_recursively(child, mult)


