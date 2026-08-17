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

# Red Alert Lockdown Mode State
var is_red_alert_lockdown_active: bool = false
var red_alert_emergency_color: Color = Color(1.0, 0.05, 0.1) # Emergency Strobe Crimson Red

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

# Listen for L key shortcut to cycle City Lighting Stages & K key for Red-Alert Lockdown toggle
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			cycle_city_light_stage()
		elif event.keycode == KEY_K:
			toggle_citywide_red_alert_lockdown()

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
	# Automatically re-acquire grid_material_ref if city was regenerated (e.g. key '0' seed change)
	if not is_instance_valid(grid_material_ref):
		_find_grid_material_reference()

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
	# 4. CONCERT STAGE SPOTLIGHT COLOR OSCILLATION & BAND BOUNCE ANIMATION
	# --------------------------------------------------------------------------
	_update_stage_lights_and_band_animation(delta)

	# --------------------------------------------------------------------------
	# 5. APPLY GLITCH & WAVE RIPPLE MATERIAL UPDATE (WITH OVERMAP OVERRIDE)
	# --------------------------------------------------------------------------
	var dark_mult: float = _get_current_light_multiplier()
	if is_overmap_active:
		# Guarantee at least 2.5x full brightness for satellite overmap view
		dark_mult = maxf(dark_mult, 2.5)

	if is_instance_valid(grid_material_ref):
		if dark_mult <= 0.0:
			grid_material_ref.emission_enabled = false
		else:
			grid_material_ref.emission_enabled = true
			if is_red_alert_lockdown_active:
				# Flashing emergency strobe red grid (10 Hz strobe frequency)
				var red_strobe_pulse: float = (sin(Time.get_ticks_msec() * 0.015) * 0.5) + 0.5
				grid_material_ref.emission = red_alert_emergency_color
				grid_material_ref.emission_energy_multiplier = (2.0 + red_strobe_pulse * 6.0) * dark_mult
			elif is_hiccup_active:
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

# Overmap override state (bypasses L key dimming/blackout for map view)
var is_overmap_active: bool = false

# Enables/disables tactical overmap visual override for ground wireframe grid & satellite view
func set_overmap_mode(active: bool) -> void:
	is_overmap_active = active
	if is_instance_valid(city_generator):
		var boost_mult: float = 2.5 if active else _get_current_light_multiplier()
		_update_node_lighting_recursively(city_generator, boost_mult)

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

# Smooth lighting transition tracking
var _light_tween: Tween = null
var _current_smooth_mult: float = 1.0

# Helper to get current energy multiplier for active city lighting stage
func _get_current_light_multiplier() -> float:
	match current_city_light_stage:
		CityLightStage.NORMAL:         return 1.0
		CityLightStage.LOW_LIGHT:      return 0.25
		CityLightStage.DIM:            return 0.05
		CityLightStage.DARK_BUILDINGS: return 0.05  # Grid stays at 5% DIM level
		CityLightStage.PITCH_BLACK:    return 0.0
		_: return 1.0

# Set a specific city lighting stage directly (with optional smooth fading)
func set_city_light_stage(target_stage: CityLightStage, smooth: bool = true, duration: float = 2.0) -> void:
	current_city_light_stage = target_stage
	var target_mult: float = _get_current_light_multiplier()
	
	var stage_name: String = ""
	match current_city_light_stage:
		CityLightStage.NORMAL:         stage_name = "NORMAL (100% - Midday)"
		CityLightStage.LOW_LIGHT:      stage_name = "LOW LIGHT (25% - Morning / Dusk)"
		CityLightStage.DIM:            stage_name = "VERY DARK / DIM (5% - Dawn / Night)"
		CityLightStage.DARK_BUILDINGS: stage_name = "DARK BUILDINGS / LIT GRID (0% Buildings, 5% Road Grid)"
		CityLightStage.PITCH_BLACK:    stage_name = "PITCH BLACK (0% - Special Blackout)"

	print("[CITY VISUALS] Transitioning to Light Stage: ", stage_name, " (Smooth: ", smooth, ")")

	if is_instance_valid(_light_tween) and _light_tween.is_running():
		_light_tween.kill()

	if smooth and is_inside_tree():
		_light_tween = create_tween()
		_light_tween.set_trans(Tween.TRANS_SINE)
		_light_tween.set_ease(Tween.EASE_IN_OUT)
		_light_tween.tween_method(_apply_custom_light_multiplier, _current_smooth_mult, target_mult, duration)
	else:
		_apply_custom_light_multiplier(target_mult)

# Cycles through city ambient lighting stages (L key shortcut)
func cycle_city_light_stage() -> void:
	match current_city_light_stage:
		CityLightStage.NORMAL:         set_city_light_stage(CityLightStage.LOW_LIGHT, true, 1.2)
		CityLightStage.LOW_LIGHT:      set_city_light_stage(CityLightStage.DIM, true, 1.2)
		CityLightStage.DIM:            set_city_light_stage(CityLightStage.DARK_BUILDINGS, true, 1.2)
		CityLightStage.DARK_BUILDINGS: set_city_light_stage(CityLightStage.PITCH_BLACK, true, 1.2)
		CityLightStage.PITCH_BLACK:    set_city_light_stage(CityLightStage.NORMAL, true, 1.2)

func _apply_city_lighting_stage() -> void:
	_apply_custom_light_multiplier(_get_current_light_multiplier())

func _apply_custom_light_multiplier(dark_mult: float) -> void:
	_current_smooth_mult = dark_mult
	var building_mult: float = 0.0 if current_city_light_stage == CityLightStage.DARK_BUILDINGS else dark_mult

	# Update emission energy multipliers on all building meshes, grass, water, and street lights
	if is_instance_valid(city_generator):
		_update_node_lighting_recursively(city_generator, building_mult)

	# Ensure ground wireframe grid is set to dark_mult (5% in DARK_BUILDINGS stage, 0% in PITCH_BLACK)
	if is_instance_valid(grid_material_ref):
		if dark_mult <= 0.001:
			grid_material_ref.emission_enabled = false
		else:
			grid_material_ref.emission_enabled = true
			grid_material_ref.emission_energy_multiplier = 3.0 * dark_mult


# ==============================================================================
# CITYWIDE RED-ALERT LOCKDOWN MODE (TOGGLED VIA 'K' KEY)
# ==============================================================================
# Flashes all building window trim, rooftop neon, streetlights, and wireframe grid into red emergency strobe
func toggle_citywide_red_alert_lockdown() -> void:
	if is_red_alert_lockdown_active:
		clear_citywide_red_alert()
	else:
		trigger_citywide_red_alert()

func trigger_citywide_red_alert() -> void:
	is_red_alert_lockdown_active = true
	print("[ALERT SYSTEM] 🚨 CITYWIDE RED-ALERT LOCKDOWN ACTIVATED! 🚨")

	# Shift volumetric fog atmosphere to deep crimson emergency tint
	var world_environment_node = $"../WorldEnvironment"
	if is_instance_valid(world_environment_node) and world_environment_node.environment:
		world_environment_node.environment.volumetric_fog_albedo = Color(0.8, 0.05, 0.1)
		world_environment_node.environment.volumetric_fog_emission = Color(0.2, 0.01, 0.02)

	# Override building emission colors to red alert
	if is_instance_valid(city_generator):
		_apply_red_alert_materials_recursively(city_generator, true)

func clear_citywide_red_alert() -> void:
	is_red_alert_lockdown_active = false
	print("[ALERT SYSTEM] ✅ CITYWIDE RED-ALERT LOCKDOWN CLEARED.")

	# Restore normal volumetric fog atmosphere tint
	var world_environment_node = $"../WorldEnvironment"
	if is_instance_valid(world_environment_node) and world_environment_node.environment:
		world_environment_node.environment.volumetric_fog_albedo = Color(0.35, 0.45, 0.65)
		world_environment_node.environment.volumetric_fog_emission = Color(0.008, 0.012, 0.025)

	# Restore standard building emission colors
	if is_instance_valid(city_generator):
		_apply_red_alert_materials_recursively(city_generator, false)

func _apply_red_alert_materials_recursively(parent_node: Node, enable_red_alert: bool) -> void:
	for child_node in parent_node.get_children():
		if child_node is MeshInstance3D and is_instance_valid(child_node.material_override):
			var node_material = child_node.material_override as StandardMaterial3D
			if is_instance_valid(node_material) and node_material.emission_enabled:
				if enable_red_alert:
					node_material.set_meta("original_emission_color", node_material.emission)
					node_material.emission = red_alert_emergency_color
					node_material.emission_energy_multiplier = 6.0
				else:
					if node_material.has_meta("original_emission_color"):
						node_material.emission = node_material.get_meta("original_emission_color")
					node_material.emission_energy_multiplier = 3.0

		if child_node.get_child_count() > 0:
			_apply_red_alert_materials_recursively(child_node, enable_red_alert)

# Helper function to recursively update material emission across all city elements (buildings, grass, water, trees)
func _update_node_lighting_recursively(target_node: Node, mult: float) -> void:
	# Skip streetlights & parking lot corner lights so independent floodlights and lamp bulb lenses stay lit
	var n_name: String = target_node.name
	var p_name: String = target_node.get_parent().name if target_node.get_parent() != null else ""
	if "Spotlight" in n_name or "Streetlight" in n_name or "ParkingLot" in n_name or "Streetlamp" in n_name or "Spotlight" in p_name or "Streetlight" in p_name or "ParkingLot" in p_name or "Streetlamp" in p_name:
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

var _stage_anim_time: float = 0.0

func _update_stage_lights_and_band_animation(delta: float) -> void:
	_stage_anim_time += delta
	var stage_node = get_parent().get_node_or_null("CityGenerator/CyberParkConcertStage")
	if not is_instance_valid(stage_node) and is_instance_valid(city_generator):
		stage_node = city_generator.find_child("CyberParkConcertStage", true, false)
	if not is_instance_valid(stage_node):
		return

	# Oscillate spotlight colors along the cyber spectrum (Magenta <-> Cyan <-> Gold)
	var hue1: Color = Color(1.0, 0.0, 0.8).lerp(Color(0.0, 0.85, 1.0), (sin(_stage_anim_time * 2.5) + 1.0) * 0.5)
	var hue2: Color = Color(0.0, 0.85, 1.0).lerp(Color(1.0, 0.85, 0.0), (cos(_stage_anim_time * 2.5) + 1.0) * 0.5)

	# Update cross-beam spotlights
	for i in range(4):
		var beam_spot = stage_node.get_node_or_null("CrossBeamSpotlight_%d" % i)
		if is_instance_valid(beam_spot):
			beam_spot.light_color = hue1 if (i % 2 == 0) else hue2
			beam_spot.rotation_degrees.z = sin(_stage_anim_time * 3.0 + i) * 12.0 # Sweeping beam oscillation!

	# Update side Par Can spotlights
	for child in stage_node.get_children():
		if child.name == "ParCanSpotlight":
			child.light_color = hue2

	# Animate Stage Performers (Cyber Band vs Charismatic Preacher + Quiet Disciples vs Shakespeare in the Park)
	var performers_node: Node3D = null
	for child in stage_node.get_children():
		if child is Node3D and (child.name.begins_with("StagePerformers") or child.name.begins_with("StageCyberBand")):
			performers_node = child
			break

	# Check active event ID directly from StagePerformers metadata or CampaignManager
	var active_event_id: String = "PARK_CONCERT"
	if is_instance_valid(performers_node) and performers_node.has_meta("event_id"):
		active_event_id = performers_node.get_meta("event_id", "PARK_CONCERT")
	else:
		var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
		if is_instance_valid(campaign_mgr) and "active_daily_event" in campaign_mgr and campaign_mgr.active_daily_event is Dictionary and campaign_mgr.active_daily_event.has("id"):
			active_event_id = campaign_mgr.active_daily_event.get("id", "PARK_CONCERT")

	if is_instance_valid(performers_node):

		if active_event_id == "SHAKESPEARE_PARK":
			# SHAKESPEARE IN THE PARK ANIMATION ENGINE:
			# - Holographic Macbeth in Dron armor declaims dramatically at stage front
			# - 3 Ethereal Witches dance eerily in a floating circle behind Macbeth
			# - Banquo lurks stealthily on the North stage wing
			var macbeth_node = performers_node.get_node_or_null("Holographic Macbeth")
			var banquo_node = performers_node.get_node_or_null("Lurking Banquo")
			
			if is_instance_valid(macbeth_node):
				var m_base: Vector3 = macbeth_node.get_meta("base_pos", macbeth_node.position)
				# Macbeth dramatic gestures & pacing
				var gesture_y: float = abs(sin(_stage_anim_time * 2.5)) * 0.15
				var gesture_tilt_x: float = sin(_stage_anim_time * 1.8) * 12.0
				macbeth_node.position = m_base + Vector3(0.0, gesture_y, 0.0)
				macbeth_node.rotation_degrees = Vector3(gesture_tilt_x, 0.0, 0.0)

			if is_instance_valid(banquo_node):
				var b_base: Vector3 = banquo_node.get_meta("base_pos", banquo_node.position)
				# Banquo lurks in shadow on stage wing, leaning forward subtly
				banquo_node.position = b_base + Vector3(0.0, sin(_stage_anim_time * 1.2) * 0.03, 0.0)
				banquo_node.rotation_degrees = Vector3(0.0, 25.0, sin(_stage_anim_time * 1.5) * 4.0)

			# Eerie floating ritual dance for the 3 Witches
			var witch_idx: int = 0
			for member in performers_node.get_children():
				if "Witch" in member.name and member is Node3D:
					var w_base: Vector3 = member.get_meta("base_pos", member.position)
					var float_y: float = sin(_stage_anim_time * 4.0 + witch_idx * 2.0) * 0.35 # Eerie floating levitation
					var spin_z: float = sin(_stage_anim_time * 6.0 + witch_idx * 1.5) * 18.0 # Eerie ritual sway
					member.position = Vector3(w_base.x, w_base.y + float_y, w_base.z)
					member.rotation_degrees = Vector3(0.0, sin(_stage_anim_time * 3.0 + witch_idx) * 20.0, spin_z)
					witch_idx += 1

		elif active_event_id == "RELIGIOUS_RALLY":
			# CALL-AND-RESPONSE RITUAL CYCLE (5.0s Total Cycle):
			# [0.0s - 1.8s] PREACHER ACTS (2 double jumps / prostration bow / color flare)
			# [1.8s - 2.5s] PREACHER & CROWD PAUSE IN STILL REVERENCE
			# [2.5s - 4.5s] CROWD MIMICKS PREACHER'S ACTION IN UNISON
			# [4.5s - 5.0s] RESET PAUSE
			var cycle_time: float = fmod(_stage_anim_time, 5.0)
			var preacher_node = performers_node.get_node_or_null("Cyber Preacher")
			
			var routine_type: int = int(_stage_anim_time / 5.0) % 3 # 0: Double Jump, 1: Color Flare & Bow, 2: Swaying Blessing
			var preacher_head_color: Color = Color(1.0, 0.85, 0.0) # Default Gold
			var preacher_jump_offset: float = 0.0
			var preacher_sway_z: float = 0.0
			var preacher_tilt_x: float = 0.0

			var active_action_jump: float = 0.0
			var active_action_sway: float = 0.0
			var active_action_tilt: float = 0.0

			# Calculate active move based on current routine type
			match routine_type:
				0: # Move A: 2 High Jumps
					active_action_jump = abs(sin(cycle_time * 6.0)) * 0.65
					preacher_head_color = Color(1.0, 0.85, 0.0) # Gold
				1: # Move B: Deep Prostration Bow & Magenta Glow
					active_action_tilt = sin(cycle_time * 4.0) * 30.0
					preacher_head_color = Color(1.0, 0.0, 0.8) # Hot Magenta
				2: # Move C: Swaying Blessing & Cyan Glow
					active_action_sway = sin(cycle_time * 5.0) * 0.4
					preacher_head_color = Color(0.0, 0.85, 1.0) # Cyan

			if cycle_time < 1.8:
				# --- PHASE 1: PREACHER ACTS FIRST ---
				preacher_jump_offset = active_action_jump
				preacher_sway_z = active_action_sway
				preacher_tilt_x = active_action_tilt
			else:
				# Preacher pauses after doing the move!
				preacher_jump_offset = 0.0
				preacher_sway_z = 0.0
				preacher_tilt_x = 0.0

			# Apply position, rotation & head color to Preacher
			if is_instance_valid(preacher_node):
				var p_base: Vector3 = preacher_node.get_meta("base_pos", preacher_node.position)
				preacher_node.position = Vector3(p_base.x, p_base.y + preacher_jump_offset, p_base.z + preacher_sway_z)
				preacher_node.rotation_degrees = Vector3(preacher_tilt_x, 0.0, 0.0)
				
				var p_head = preacher_node.get_node_or_null("HeadMesh")
				if is_instance_valid(p_head) and is_instance_valid(p_head.material_override):
					var h_mat = p_head.material_override as StandardMaterial3D
					if is_instance_valid(h_mat):
						h_mat.albedo_color = preacher_head_color
						h_mat.emission = preacher_head_color

			# Pass state to metadata for crowd copying
			performers_node.set_meta("cycle_time", cycle_time)
			performers_node.set_meta("routine_type", routine_type)
			performers_node.set_meta("action_color", preacher_head_color)
			performers_node.set_meta("active_action_jump", active_action_jump)
			performers_node.set_meta("active_action_sway", active_action_sway)
			performers_node.set_meta("active_action_tilt", active_action_tilt)

			# Quiet Disciples stay still/quiet behind preacher
			for member in performers_node.get_children():
				if member != preacher_node and member is Node3D:
					var base_p: Vector3 = member.get_meta("base_pos", member.position)
					member.position = base_p + Vector3(0.0, sin(_stage_anim_time * 1.5) * 0.04, 0.0)
					member.rotation_degrees = Vector3(sin(_stage_anim_time * 2.0) * 4.0, 0.0, 0.0)

		else:
			# Standard Cyber-Punk Rock Band Bounce
			var member_idx: int = 0
			for member in performers_node.get_children():
				if member is Node3D:
					var base_p: Vector3 = member.get_meta("base_pos", member.position)
					var bounce_y: float = abs(sin(_stage_anim_time * 12.0 + member_idx * 0.9)) * 0.45
					var sway_z: float = sin(_stage_anim_time * 6.0 + member_idx * 1.3) * 0.25
					member.position = Vector3(base_p.x, base_p.y + bounce_y, base_p.z + sway_z)
					member.rotation_degrees.z = sin(_stage_anim_time * 12.0 + member_idx) * 15.0
					member_idx += 1

	# ==========================================================================
	# DYNAMIC STAGE DECOR & PROPS ANIMATIONS (Par Cans, Equalizer, Halo, Cauldron)
	# ==========================================================================
	var decor_node = stage_node.get_node_or_null("StageDecor")
	if is_instance_valid(decor_node):
		# 1. Animate Visible Par Can Lenses in tempo with music BPM
		var beat_pulse: float = (sin(_stage_anim_time * 12.0) + 1.0) * 0.5
		for child in decor_node.get_children():
			if child.name.begins_with("ParCanFixture"):
				var lens = child.get_node_or_null("ParCanLens")
				if is_instance_valid(lens) and is_instance_valid(lens.material_override):
					var l_mat = lens.material_override as StandardMaterial3D
					l_mat.emission_energy_multiplier = lerp(2.0, 7.5, beat_pulse)

		# 2. Animate Graphic Equalizer Columns on Concert Backdrop
		var eq_board = decor_node.get_node_or_null("ConcertEqualizerBoard")
		if is_instance_valid(eq_board):
			for c_idx in range(10):
				var col = eq_board.get_node_or_null("EQCol_%d" % c_idx)
				if is_instance_valid(col):
					var eq_h: float = 0.5 + abs(sin(_stage_anim_time * 8.0 + float(c_idx) * 1.4)) * 2.2
					col.scale.y = eq_h
					col.position.y = -1.5 + (eq_h * 0.9)

		# 3. Rotate Giant Floating Golden Halo above Preacher
		var halo_node = decor_node.get_node_or_null("GiantFloatingHalo")
		if is_instance_valid(halo_node):
			halo_node.rotation_degrees.z += delta * 25.0
			halo_node.position.y = 8.2 + sin(_stage_anim_time * 2.0) * 0.25 # Gentle holy hover

		# 4. Animate Bubbling Witch Cauldron Plasma
		var cauldron = decor_node.get_node_or_null("WitchCauldronNode")
		if is_instance_valid(cauldron):
			var soup = cauldron.get_node_or_null("CauldronPlasmaSoup")
			if is_instance_valid(soup) and is_instance_valid(soup.material_override):
				var s_mat = soup.material_override as StandardMaterial3D
				var boil_pulse: float = abs(sin(_stage_anim_time * 6.0))
				s_mat.emission_energy_multiplier = lerp(3.5, 7.5, boil_pulse)

	# 5. Animate Joe's Neon Ice Cream Cone Sign
	var joe_building = get_parent().get_node_or_null("CityGenerator/JoeIceCreamStoreBuilding")
	if is_instance_valid(joe_building):
		var cone_sign = joe_building.find_child("NeonIceCreamConeSign", true, false)
		if is_instance_valid(cone_sign):
			cone_sign.rotation_degrees.y = sin(_stage_anim_time * 1.5) * 12.0
			cone_sign.position.y = 5.2 + sin(_stage_anim_time * 2.5) * 0.15




