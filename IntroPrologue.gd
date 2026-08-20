extends Control
class_name IntroPrologue

# ==============================================================================
# INTRO PROLOGUE: CYBERPUNK MACBETH (IntroPrologue.gd)
# ==============================================================================
# Standalone visual novel & retro CRT narrative terminal prologue.
# Adapts the classic tragedy opening to our cyberpunk corporate war setting.
# ==============================================================================

signal prologue_completed

const MAIN_SCENE_PATH: String = "res://Main.tscn"

# Font paths
const FONT_ORBITRON_PATH: String = "res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf"
const FONT_SHARE_TECH_PATH: String = "res://fonts/ShareTechMono-Regular.ttf"
const FONT_GEIST_PATH: String = "res://fonts/GeistPixel-Regular-VariableFont_ELSH.ttf"

# Audio paths
const MUSIC_BG_PATH: String = "res://music/LANDR-sakral sang-Open-Medium.wav"
const MUSIC_FALLBACK_PATH: String = "res://music/LANDR-A Lull in the Pale-Open-Medium.ogg"
const SFX_ENGINE_PATH: String = "res://sfx/engine_hum.ogg"

# UI Colors
const COLOR_BG: Color = Color(0.02, 0.02, 0.04, 1.0)
const COLOR_MACK: Color = Color(1.0, 0.25, 0.1, 1.0)       # Crimson / Orange
const COLOR_BANQUO: Color = Color(0.0, 1.0, 0.75, 1.0)     # Neon Cyan-Teal
const COLOR_NORNS: Color = Color(0.9, 0.2, 1.0, 1.0)       # Glitch Violet / Magenta
const COLOR_DUNCAN: Color = Color(1.0, 0.85, 0.2, 1.0)     # Corporate Gold
const COLOR_LADY_M: Color = Color(0.7, 0.4, 1.0, 1.0)     # Dark Royal Indigo / Purple
const COLOR_SYS: Color = Color(0.6, 0.7, 0.8, 1.0)        # Silver Tech

# Story Beats & Script Data
var script_steps: Array[Dictionary] = [
	# BEAT 1: THE RETURN FROM THE PERIMETER
	{
		"speaker": "NARRATOR / SATELLITE TELEMETRY",
		"speaker_id": "SYS_OVERWATCH",
		"speaker_sub": "SECTOR 00 // PERIMETER HIGHWAY // YEAR 2088",
		"color": COLOR_SYS,
		"text": "SECTOR WAR CONCLUDED. The Macdonwald insurgence has been liquidated along the outer boundary.\n\nTwo elite strike leads return from the scorched borderlands in convoy: GENERAL MACK-BETH of Glamis Sector, and COMMANDER BANZOU.",
		"portrait_type": "GRID_MAP"
	},
	{
		"speaker": "Mack-Beth",
		"speaker_id": "MACK_WAR_RIG",
		"speaker_sub": "FIELD GENERAL // THANOR OF GLAMIS // COCKPIT COMMS",
		"color": COLOR_MACK,
		"text": "So foul and fair a day I have not seen on these roads, Banquo. The rebel drones are smoking in the ditches, but the sky... look at the neon smog over the Dunsinane Spire. It feels like lightning waiting to strike.",
		"portrait_type": "MACK"
	},
	{
		"speaker": "Banquo",
		"speaker_id": "BANQUO_OPERATIVE",
		"speaker_sub": "INTELLIGENCE LEAD // SPECIAL OPS COMMANDER",
		"color": COLOR_BANQUO,
		"text": "Our hulls took a beating, Mack. How far is it to Duncan's high tower? If the old CEO's accounting bots are accurate, we're owed enough bounty credits to replate both our chassis in titanium.",
		"portrait_type": "BANQUO"
	},

	# BEAT 2: THE ANOMALY - THE NORNS AI TRIAD
	{
		"speaker": "TERMINAL WARNING",
		"speaker_id": "ANOMALY_OVERRIDE",
		"speaker_sub": "UNAUTHORIZED ICE INTRUSION // FREQUENCY: 666.0 MHz",
		"color": COLOR_NORNS,
		"text": "[CRITICAL ALERT]: Optical feed jammed by high-gain encrypted phantom broadcast. An anomalous neural signal has hijacked vehicle telemetry!",
		"portrait_type": "GLITCH"
	},
	{
		"speaker": "Banquo",
		"speaker_id": "BANQUO_OPERATIVE",
		"speaker_sub": "INTELLIGENCE LEAD // SCANNING FREQUENCIES",
		"color": COLOR_BANQUO,
		"text": "Mack! What are these shapes bleeding across the HUD? They look like human avatars, yet their code isn't indexed in any city database. Are you living algorithms, or phantom ghosts trapped in the fiber optic lines?",
		"portrait_type": "BANQUO"
	},
	{
		"speaker": "Norns AI Triad",
		"speaker_id": "THE_ORACLE_ALGORITHMS",
		"speaker_sub": "DEEP-NET PREDICTIVE THREAD // 3 SYNCHRONIZED CORES",
		"color": COLOR_NORNS,
		"text": "FIRST VOICE: 'All hail, Mack-Beth! Hail to thee, Thanor of Glamis!'\n\nSECOND VOICE: 'All hail, Mack-Beth! Hail to thee, Thanor of Cawdor Logistics!'\n\nTHIRD VOICE: 'All hail, Mack-Beth! Thou shalt be KING & CHIEF EXECUTIVE of Dunsinane Spire hereafter!'",
		"portrait_type": "NORNS"
	},
	{
		"speaker": "Mack-Beth",
		"speaker_id": "MACK_WAR_RIG",
		"speaker_sub": "NEURAL COCKPIT // PARANOIA SPIKE",
		"color": COLOR_MACK,
		"text": "Thanor of Cawdor? That position belongs to Bankes! And CEO Duncan still sits on the Dunsinane throne with an empire of private security! Speak, you corrupted subroutines—whence came this intelligence?!",
		"portrait_type": "MACK"
	},
	{
		"speaker": "Banquo",
		"speaker_id": "BANQUO_OPERATIVE",
		"speaker_sub": "INTELLIGENCE LEAD // PROBING DEEP-NET",
		"color": COLOR_BANQUO,
		"text": "If you can read the seeds of time and see which corporate stock will rise and which will crash—speak then to me, who neither begs nor fears your favours or your hate.",
		"portrait_type": "BANQUO"
	},
	{
		"speaker": "Norns AI Triad",
		"speaker_id": "THE_ORACLE_ALGORITHMS",
		"speaker_sub": "DEEP-NET PREDICTIVE THREAD // BANQUO CLAUSE",
		"color": COLOR_NORNS,
		"text": "LESSER THAN MACK-BETH, AND GREATER.\nNOT SO HAPPY, YET MUCH HAPPIER.\n\nThou shalt father dynasties of corporate kings and code, though thou shalt hold no crown thyself.\nSo all hail, Mack-Beth and Banquo! The threads are spun.",
		"portrait_type": "NORNS"
	},

	# BEAT 3: DUNCAN'S BROADCAST & THE CAWDOR PROMOTION
	{
		"speaker": "Duncan Dynamics HQ",
		"speaker_id": "CEO_DUNCAN_HOLOGRAM",
		"speaker_sub": "CHIEF EXECUTIVE OFFICER // DUNSINANE SPIRE CORE",
		"color": COLOR_DUNCAN,
		"text": "Generals! The whole megacity sings of your triumph over the Macdonwald faction. But grim news arrived from the West Ward: the Thanor of Cawdor was caught selling backdoor encryption keys to the enemy.\n\nHe has been terminated. And by my decree—Cawdor's sector, assets, and title are hereby transferred to MACK-BETH!",
		"portrait_type": "DUNCAN"
	},
	{
		"speaker": "Mack-Beth",
		"speaker_id": "MACK_WAR_RIG",
		"speaker_sub": "PRIVATE CHANNEL -> BANQUO",
		"color": COLOR_MACK,
		"text": "Banquo... do you hear that?! The Norns called me Thanor of Cawdor—and now Duncan hands it to me in blood! Do you not hope your children shall hold the boardroom crowns, when those who gave me Cawdor promised no less to you?",
		"portrait_type": "MACK"
	},
	{
		"speaker": "Banquo",
		"speaker_id": "BANQUO_OPERATIVE",
		"speaker_sub": "INTELLIGENCE LEAD // CAUTION PROTOCOL",
		"color": COLOR_BANQUO,
		"text": "Be careful, brother. Oftentimes, to win us to our harm, the instruments of darkness tell us truths—win us with honest trifles, to betray us in deepest consequence.",
		"portrait_type": "BANQUO"
	},

	# BEAT 4: LADY M & THE DIVISION OF ROLES
	{
		"speaker": "Lady M",
		"speaker_id": "LADY_M_EXECUTIVE",
		"speaker_sub": "CHIEF STRATEGIST // HIGH-RISE EXECUTIVE SUITE",
		"color": COLOR_LADY_M,
		"text": "Banquo. I intercepted your telemetry from the outer border. Mack is too full o' the milk of human kindness to seize the quickest way, but the Norns' algorithmic prophecy will not be denied.\n\nDuncan has arrived in our sector tonight. The crown is within our grasp.",
		"portrait_type": "LADY_M"
	},
	{
		"speaker": "Lady M",
		"speaker_id": "LADY_M_EXECUTIVE",
		"speaker_sub": "OPERATIONAL DOCTRINE // DIVISION OF LABOUR",
		"color": COLOR_LADY_M,
		"text": "Here is how we divide the board:\n\n• MACK-BETH takes the heavy War-Rig into the grand daylight battles—intercepting armed corporate convoys, crushing security battalions, and holding the highway frontlines.\n\n• YOU, BANQUO, are our scalpel in the shadows. Walk the neon alleys, infiltrate nightclubs and penthouses, tail targets, interrogate fixers, and run street-level operations while providing tactical drone support to Mack's rig.",
		"portrait_type": "LADY_M"
	},

	# BEAT 5: CONCLUSION & MISSION BRIEFING
	{
		"speaker": "Banquo",
		"speaker_id": "BANQUO_OPERATIVE",
		"speaker_sub": "STANDBY // READY FOR DEPLOYMENT",
		"color": COLOR_BANQUO,
		"text": "Understood. Mack fights the titans on the overpasses. I control the streets below.\n\nLet the neon rain fall on Dunsinane. Day 1 begins now.",
		"portrait_type": "BANQUO"
	}
]

var current_step_index: int = 0
var is_typing: bool = false
var current_text_target: String = ""
var chars_revealed: float = 0.0
var type_speed: float = 45.0 # chars per second

# UI References
var font_orbitron: Font
var font_share_tech: Font
var font_geist: Font

var root_canvas: Control
var crt_overlay: Control
var portrait_canvas: Control
var speaker_name_label: Label
var speaker_sub_label: Label
var dialogue_text_label: RichTextLabel
var prompt_advance_label: Label
var progress_bar: ProgressBar
var btn_skip: Button

var audio_music_player: AudioStreamPlayer
var audio_sfx_player: AudioStreamPlayer
var audio_type_player: AudioStreamPlayer

var glitch_intensity: float = 0.0
var anim_time: float = 0.0

func _ready() -> void:
	# Ensure full screen rect
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_load_fonts()
	_setup_audio()
	_build_ui()
	_display_step(0)

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_ORBITRON_PATH):
		font_orbitron = load(FONT_ORBITRON_PATH)
	if ResourceLoader.exists(FONT_SHARE_TECH_PATH):
		font_share_tech = load(FONT_SHARE_TECH_PATH)
	if ResourceLoader.exists(FONT_GEIST_PATH):
		font_geist = load(FONT_GEIST_PATH)

func _setup_audio() -> void:
	audio_music_player = AudioStreamPlayer.new()
	audio_music_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(audio_music_player)

	var bg_music: AudioStream = null
	if ResourceLoader.exists(MUSIC_BG_PATH):
		bg_music = load(MUSIC_BG_PATH)
	elif ResourceLoader.exists(MUSIC_FALLBACK_PATH):
		bg_music = load(MUSIC_FALLBACK_PATH)

	if bg_music:
		audio_music_player.stream = bg_music
		audio_music_player.volume_db = -6.0
		audio_music_player.play()

	audio_sfx_player = AudioStreamPlayer.new()
	audio_sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(audio_sfx_player)

	audio_type_player = AudioStreamPlayer.new()
	audio_type_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(audio_type_player)

func _build_ui() -> void:
	# 1. Dark Cyber Background with Subtle CRT Grid
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Tech Wireframe Backdrop
	var tech_grid = Control.new()
	tech_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_grid.draw.connect(func():
		var sz = tech_grid.size
		var grid_c = Color(0.0, 0.8, 1.0, 0.04)
		for x in range(0, int(sz.x), 40):
			tech_grid.draw_line(Vector2(x, 0), Vector2(x, sz.y), grid_c, 1.0)
		for y in range(0, int(sz.y), 40):
			tech_grid.draw_line(Vector2(0, y), Vector2(sz.x, y), grid_c, 1.0)

		# Outer decorative brackets
		var neon_cyan = Color(0.0, 1.0, 0.85, 0.4)
		tech_grid.draw_line(Vector2(20, 20), Vector2(80, 20), neon_cyan, 2.0)
		tech_grid.draw_line(Vector2(20, 20), Vector2(20, 80), neon_cyan, 2.0)

		tech_grid.draw_line(Vector2(sz.x - 20, 20), Vector2(sz.x - 80, 20), neon_cyan, 2.0)
		tech_grid.draw_line(Vector2(sz.x - 20, 20), Vector2(sz.x - 20, 80), neon_cyan, 2.0)

		tech_grid.draw_line(Vector2(20, sz.y - 20), Vector2(80, sz.y - 20), neon_cyan, 2.0)
		tech_grid.draw_line(Vector2(20, sz.y - 20), Vector2(20, sz.y - 80), neon_cyan, 2.0)

		tech_grid.draw_line(Vector2(sz.x - 20, sz.y - 20), Vector2(sz.x - 80, sz.y - 20), neon_cyan, 2.0)
		tech_grid.draw_line(Vector2(sz.x - 20, sz.y - 20), Vector2(sz.x - 20, sz.y - 80), neon_cyan, 2.0)
	)
	add_child(tech_grid)

	# 3. Main Container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("margin_left", 36)
	main_vbox.add_theme_constant_override("margin_right", 36)
	main_vbox.add_theme_constant_override("margin_top", 24)
	main_vbox.add_theme_constant_override("margin_bottom", 24)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	add_child(main_vbox)

	# --- TOP HEADER BAR ---
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 48)
	main_vbox.add_child(top_bar)

	var header_title = Label.new()
	header_title.text = "DUNSINANE SPIRE // TACTICAL ARCHIVE PROLOGUE (ACT 0)"
	if font_orbitron:
		header_title.add_theme_font_override("font", font_orbitron)
	header_title.add_theme_font_size_override("font_size", 16)
	header_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85, 0.95))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(header_title)

	btn_skip = Button.new()
	btn_skip.text = "[ ESC ] SKIP TO DAY 1"
	if font_share_tech:
		btn_skip.add_theme_font_override("font", font_share_tech)
	btn_skip.add_theme_font_size_override("font_size", 14)
	btn_skip.custom_minimum_size = Vector2(170, 32)
	btn_skip.pressed.connect(_on_skip_pressed)
	top_bar.add_child(btn_skip)

	# --- MIDDLE CONTENT AREA (PORTRAIT + NARRATIVE) ---
	var middle_hbox = HBoxContainer.new()
	middle_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(middle_hbox)

	# Left Portrait Frame Panel
	var portrait_panel = Panel.new()
	portrait_panel.custom_minimum_size = Vector2(300, 340)
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.03, 0.05, 0.08, 0.85)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.0, 1.0, 0.85, 0.5)
	p_style.corner_radius_top_left = 4
	p_style.corner_radius_bottom_right = 4
	portrait_panel.add_theme_stylebox_override("panel", p_style)
	middle_hbox.add_child(portrait_panel)

	portrait_canvas = Control.new()
	portrait_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_canvas.draw.connect(_on_draw_portrait)
	portrait_panel.add_child(portrait_canvas)

	# Right Narrative Terminal Box
	var text_panel = Panel.new()
	text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var t_style = StyleBoxFlat.new()
	t_style.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	t_style.border_width_left = 3
	t_style.border_width_top = 1
	t_style.border_width_right = 1
	t_style.border_width_bottom = 1
	t_style.border_color = Color(0.0, 0.9, 1.0, 0.7)
	t_style.corner_radius_top_left = 4
	t_style.corner_radius_bottom_right = 4
	text_panel.add_theme_stylebox_override("panel", t_style)
	middle_hbox.add_child(text_panel)

	var text_vbox = VBoxContainer.new()
	text_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	text_vbox.add_theme_constant_override("separation", 14)
	text_panel.add_child(text_vbox)

	# Speaker Name Header
	speaker_name_label = Label.new()
	speaker_name_label.text = "SPEAKER NAME"
	if font_orbitron:
		speaker_name_label.add_theme_font_override("font", font_orbitron)
	speaker_name_label.add_theme_font_size_override("font_size", 22)
	speaker_name_label.add_theme_color_override("font_color", COLOR_MACK)
	text_vbox.add_child(speaker_name_label)

	# Speaker Subtitle / Sector ID
	speaker_sub_label = Label.new()
	speaker_sub_label.text = "NEURAL-ID // SECTOR COMMS"
	if font_share_tech:
		speaker_sub_label.add_theme_font_override("font", font_share_tech)
	speaker_sub_label.add_theme_font_size_override("font_size", 13)
	speaker_sub_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85, 0.8))
	text_vbox.add_child(speaker_sub_label)

	# Divider line
	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.0, 0.8, 1.0, 0.3)
	text_vbox.add_child(divider)

	# Dialogue Text Body
	dialogue_text_label = RichTextLabel.new()
	dialogue_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text_label.bbcode_enabled = true
	if font_share_tech:
		dialogue_text_label.add_theme_font_override("normal_font", font_share_tech)
	dialogue_text_label.add_theme_font_size_override("normal_font_size", 18)
	dialogue_text_label.add_theme_constant_override("line_separation", 6)
	text_vbox.add_child(dialogue_text_label)

	# Bottom interactive prompt
	prompt_advance_label = Label.new()
	prompt_advance_label.text = "▶ [SPACE / ENTER / CLICK] TO ADVANCE"
	if font_share_tech:
		prompt_advance_label.add_theme_font_override("font", font_share_tech)
	prompt_advance_label.add_theme_font_size_override("font_size", 13)
	prompt_advance_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85, 0.85))
	prompt_advance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_vbox.add_child(prompt_advance_label)

	# --- BOTTOM PROGRESS BAR ---
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.show_percentage = false
	progress_bar.max_value = script_steps.size()
	progress_bar.value = 1
	main_vbox.add_child(progress_bar)

func _process(delta: float) -> void:
	anim_time += delta

	# Animate Typewriter Text
	if is_typing:
		chars_revealed += type_speed * delta
		var cur_count = int(chars_revealed)
		if cur_count >= current_text_target.length():
			dialogue_text_label.text = current_text_target
			is_typing = false
		else:
			dialogue_text_label.text = current_text_target.substr(0, cur_count) + " █"

	# Blink Prompt Text
	var alpha_pulse = 0.4 + 0.6 * sin(anim_time * 6.0)
	prompt_advance_label.modulate.a = alpha_pulse if not is_typing else 0.3

	# Queue Redraw for Portrait Animations
	if portrait_canvas:
		portrait_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_skip_pressed()
		return

	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept") \
		or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		_advance_or_complete()

func _advance_or_complete() -> void:
	if is_typing:
		# Complete current line instantly
		dialogue_text_label.text = current_text_target
		is_typing = false
	else:
		# Advance to next step
		if current_step_index + 1 < script_steps.size():
			_display_step(current_step_index + 1)
		else:
			_finish_prologue()

func _display_step(idx: int) -> void:
	current_step_index = idx
	var data = script_steps[idx]

	speaker_name_label.text = data["speaker"]
	speaker_name_label.add_theme_color_override("font_color", data["color"])
	speaker_sub_label.text = data["speaker_sub"]

	current_text_target = data["text"]
	chars_revealed = 0.0
	is_typing = true
	dialogue_text_label.text = ""

	if idx == script_steps.size() - 1:
		prompt_advance_label.text = "▶ [CLICK / ENTER] COMMENCE DAY 1 MISSION"
	else:
		prompt_advance_label.text = "▶ [SPACE / ENTER / CLICK] TO ADVANCE"

	progress_bar.value = idx + 1

	if portrait_canvas:
		portrait_canvas.queue_redraw()

func _on_skip_pressed() -> void:
	_finish_prologue()

func _finish_prologue() -> void:
	emit_signal("prologue_completed")
	print("[INTRO PROLOGUE] Prologue completed. Transitioning to main scene: ", MAIN_SCENE_PATH)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

# ==============================================================================
# PROCEDURAL CHARACTER / SCHEMATIC WIREFRAME PORTRAITS
# ==============================================================================
func _on_draw_portrait() -> void:
	if not portrait_canvas:
		return

	var rect = portrait_canvas.get_rect()
	var center = Vector2(rect.size.x * 0.5, rect.size.y * 0.45)
	var step_data = script_steps[current_step_index]
	var p_type = step_data.get("portrait_type", "MACK")
	var col = step_data.get("color", COLOR_MACK)

	# 1. Subtle Radar Scan Circle
	var radar_r = 95.0
	portrait_canvas.draw_arc(center, radar_r, 0, TAU, 32, Color(col.r, col.g, col.b, 0.25), 1.0)
	var sweep_angle = fmod(anim_time * 2.5, TAU)
	portrait_canvas.draw_line(center, center + Vector2(cos(sweep_angle), sin(sweep_angle)) * radar_r, Color(col.r, col.g, col.b, 0.4), 1.5)

	match p_type:
		"MACK":
			_draw_mack_portrait(center, col)
		"BANQUO":
			_draw_banquo_portrait(center, col)
		"NORNS":
			_draw_norns_portrait(center, col)
		"DUNCAN":
			_draw_duncan_portrait(center, col)
		"LADY_M":
			_draw_lady_m_portrait(center, col)
		"GRID_MAP":
			_draw_map_schematic(center, col)
		"GLITCH":
			_draw_glitch_anomaly(center, col)

func _draw_mack_portrait(c: Vector2, col: Color) -> void:
	# Heavy War-Rig Commander Silhouette (Armored Helmet & Glowing Ocular Targeter)
	var wire = Color(col.r, col.g, col.b, 0.95)
	var fill = Color(col.r, col.g, col.b, 0.15)

	# Heavy Jaw & Helmet
	var helmet = PackedVector2Array([
		c + Vector2(-35, -45),
		c + Vector2(35, -45),
		c + Vector2(45, 10),
		c + Vector2(25, 45),
		c + Vector2(-25, 45),
		c + Vector2(-45, 10)
	])
	portrait_canvas.draw_colored_polygon(helmet, fill)
	portrait_canvas.draw_polyline(helmet, wire, 2.5, true)

	# Heavy Shoulders
	var shoulders = PackedVector2Array([
		c + Vector2(-70, 85),
		c + Vector2(-45, 45),
		c + Vector2(45, 45),
		c + Vector2(70, 85)
	])
	portrait_canvas.draw_polyline(shoulders, wire, 3.0)

	# Red Ocular Cyber-Optic (Right Eye)
	var eye_c = c + Vector2(15, -15)
	portrait_canvas.draw_circle(eye_c, 8.0, Color(1.0, 0.1, 0.1, 1.0))
	portrait_canvas.draw_arc(eye_c, 16.0, 0, TAU, 16, Color(1.0, 0.3, 0.2, 0.8), 1.5)
	portrait_canvas.draw_line(eye_c + Vector2(-22, 0), eye_c + Vector2(22, 0), Color(1.0, 0.2, 0.1, 0.9), 1.0)
	portrait_canvas.draw_line(eye_c + Vector2(0, -22), eye_c + Vector2(0, 22), Color(1.0, 0.2, 0.1, 0.9), 1.0)

func _draw_banquo_portrait(c: Vector2, col: Color) -> void:
	# Stealth Special Ops Monocular Silhouette (Trenchcoat & Cyber Visor)
	var wire = Color(col.r, col.g, col.b, 0.95)
	var fill = Color(col.r, col.g, col.b, 0.12)

	# Sleek Head / Cap
	var head = PackedVector2Array([
		c + Vector2(-28, -50),
		c + Vector2(28, -50),
		c + Vector2(35, -10),
		c + Vector2(18, 38),
		c + Vector2(-18, 38),
		c + Vector2(-35, -10)
	])
	portrait_canvas.draw_colored_polygon(head, fill)
	portrait_canvas.draw_polyline(head, wire, 2.0, true)

	# High Collar Coat
	var coat = PackedVector2Array([
		c + Vector2(-60, 85),
		c + Vector2(-30, 30),
		c + Vector2(0, 48),
		c + Vector2(30, 30),
		c + Vector2(60, 85)
	])
	portrait_canvas.draw_polyline(coat, wire, 2.5)

	# Cyan Cyber-Visor Strip
	var visor = PackedVector2Array([
		c + Vector2(-24, -20),
		c + Vector2(24, -20),
		c + Vector2(22, -10),
		c + Vector2(-22, -10)
	])
	portrait_canvas.draw_colored_polygon(visor, Color(0.0, 1.0, 0.85, 0.9))

func _draw_norns_portrait(c: Vector2, col: Color) -> void:
	# 3 Intersecting Glitching AI Cores / Triangle of Fate
	var wire = Color(col.r, col.g, col.b, 0.9)
	var fill = Color(col.r, col.g, col.b, 0.15)

	var p1 = c + Vector2(0, -55)
	var p2 = c + Vector2(50, 35)
	var p3 = c + Vector2(-50, 35)

	portrait_canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), fill)
	portrait_canvas.draw_polyline(PackedVector2Array([p1, p2, p3]), wire, 2.5, true)

	# 3 Glowing AI Cores at Vertices
	portrait_canvas.draw_circle(p1, 10.0 + sin(anim_time * 8.0) * 3.0, Color(1.0, 0.1, 0.8, 1.0))
	portrait_canvas.draw_circle(p2, 10.0 + sin(anim_time * 8.0 + 2.0) * 3.0, Color(0.2, 0.9, 1.0, 1.0))
	portrait_canvas.draw_circle(p3, 10.0 + sin(anim_time * 8.0 + 4.0) * 3.0, Color(1.0, 0.85, 0.0, 1.0))

	# Data Streams
	portrait_canvas.draw_line(p1, c, Color(1.0, 0.2, 0.9, 0.6), 1.5)
	portrait_canvas.draw_line(p2, c, Color(0.2, 0.9, 1.0, 0.6), 1.5)
	portrait_canvas.draw_line(p3, c, Color(1.0, 0.85, 0.0, 0.6), 1.5)

func _draw_duncan_portrait(c: Vector2, col: Color) -> void:
	# Gold Corporate Crown / Spire Monolith Insignia
	var wire = Color(col.r, col.g, col.b, 0.95)
	var fill = Color(col.r, col.g, col.b, 0.18)

	var crown = PackedVector2Array([
		c + Vector2(-45, 30),
		c + Vector2(-55, -30),
		c + Vector2(-25, -10),
		c + Vector2(0, -60),
		c + Vector2(25, -10),
		c + Vector2(55, -30),
		c + Vector2(45, 30)
	])
	portrait_canvas.draw_colored_polygon(crown, fill)
	portrait_canvas.draw_polyline(crown, wire, 3.0, true)

	# Central Corporate Eye
	portrait_canvas.draw_circle(c + Vector2(0, 0), 12.0, Color(1.0, 0.9, 0.2, 0.9))

func _draw_lady_m_portrait(c: Vector2, col: Color) -> void:
	# Sharp Executive Royal Crown Silhouette (Geometric & Cold)
	var wire = Color(col.r, col.g, col.b, 0.95)
	var fill = Color(col.r, col.g, col.b, 0.15)

	# High Cheekbones / Face
	var face = PackedVector2Array([
		c + Vector2(-25, -40),
		c + Vector2(25, -40),
		c + Vector2(30, -5),
		c + Vector2(15, 35),
		c + Vector2(-15, 35),
		c + Vector2(-30, -5)
	])
	portrait_canvas.draw_colored_polygon(face, fill)
	portrait_canvas.draw_polyline(face, wire, 2.0, true)

	# Sharp High Collar & Shoulders
	var collar = PackedVector2Array([
		c + Vector2(-55, 80),
		c + Vector2(-35, 10),
		c + Vector2(0, 45),
		c + Vector2(35, 10),
		c + Vector2(55, 80)
	])
	portrait_canvas.draw_polyline(collar, wire, 2.5)

	# Cold Violet Eyes
	portrait_canvas.draw_line(c + Vector2(-18, -15), c + Vector2(-6, -15), Color(0.9, 0.3, 1.0, 1.0), 3.0)
	portrait_canvas.draw_line(c + Vector2(6, -15), c + Vector2(18, -15), Color(0.9, 0.3, 1.0, 1.0), 3.0)

func _draw_map_schematic(c: Vector2, col: Color) -> void:
	# Satellite Tactical Vector Map
	var wire = Color(col.r, col.g, col.b, 0.8)
	for i in range(4):
		var rad = 25.0 + float(i) * 22.0
		portrait_canvas.draw_arc(c, rad, 0, TAU, 24, Color(col.r, col.g, col.b, 0.2), 1.0)

	portrait_canvas.draw_line(c + Vector2(-80, 0), c + Vector2(80, 0), wire, 1.0)
	portrait_canvas.draw_line(c + Vector2(0, -80), c + Vector2(0, 80), wire, 1.0)
	portrait_canvas.draw_rect(Rect2(c.x - 40, c.y - 40, 80, 80), Color(col.r, col.g, col.b, 0.1), true)
	portrait_canvas.draw_rect(Rect2(c.x - 40, c.y - 40, 80, 80), wire, false, 1.5)

func _draw_glitch_anomaly(c: Vector2, col: Color) -> void:
	# Static / Signal Glitch Anomaly
	for i in range(16):
		var y_off = randf_range(-70, 70)
		var x_len = randf_range(30, 140)
		var x_off = randf_range(-70, 0)
		portrait_canvas.draw_line(
			c + Vector2(x_off, y_off),
			c + Vector2(x_off + x_len, y_off),
			Color(randf(), randf(), 1.0, randf_range(0.3, 0.9)),
			randf_range(1.5, 4.0)
		)
