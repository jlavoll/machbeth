extends CanvasLayer

# ==============================================================================
# AUDIO SETTINGS MENU (AudioSettingsMenu.gd)
# ==============================================================================
# Press ESC to toggle this popup open/closed.
# Each slider controls the AudioServer volume for one named bus:
#
#   MUSIC     →  "Music"          bus  (used by MusicPlaylistManager)
#   AMBIENCE  →  "CarCabinAmbience" bus (used by WeatherAmbienceManager rain/wind)
#   ENGINE    →  "Engine"         bus  (used by CarEngineAudio)
#   SFX       →  "SFX"            bus  (reserved for future sound effects)
#
# Sliders go from -60 dB (near-silent) to +6 dB (slight boost).
# The centre value (0 dB) = unity gain, no change from the original audio.
# ==============================================================================

# Cyberpunk font — same as the rest of the UI
var orbitron: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

# Neon colours per channel (used for labels, slider accents, scanline tints)
const COLOR_MUSIC:    Color = Color(0.0,  0.85, 1.0,  1.0)   # Cyan
const COLOR_AMBIENCE: Color = Color(0.4,  1.0,  0.4,  1.0)   # Neon green
const COLOR_ENGINE:   Color = Color(1.0,  0.6,  0.0,  1.0)   # Amber / orange
const COLOR_SFX:      Color = Color(1.0,  0.2,  0.8,  1.0)   # Hot pink
const COLOR_TITLE:    Color = Color(0.0,  1.0,  0.85, 1.0)   # Bright teal

# dB range for every slider
const SLIDER_MIN_DB: float = -60.0
const SLIDER_MAX_DB: float =   6.0

# Default starting volumes for each bus (dB)
const DEFAULT_MUSIC_DB:    float =  0.0
const DEFAULT_AMBIENCE_DB: float =  0.0
const DEFAULT_ENGINE_DB:   float =  0.0
const DEFAULT_SFX_DB:      float =  0.0

# ---- bus name constants -------------------------------------------------------
# These must match exactly what you pass to AudioStreamPlayer.bus in each script.
const BUS_MUSIC:    String = "Music"
const BUS_AMBIENCE: String = "CarCabinAmbience"
const BUS_ENGINE:   String = "Engine"
const BUS_SFX:      String = "SFX"

# ==============================================================================
# INTERNAL REFERENCES
# ==============================================================================

var _panel:          Control       # Root panel node
var _slider_music:   HSlider
var _slider_ambience:HSlider
var _slider_engine:  HSlider
var _slider_sfx:     HSlider
var _label_music:    Label
var _label_ambience: Label
var _label_engine:   Label
var _label_sfx:      Label


# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	# Menu lives above game world but below nothing — layer 10 keeps it on top
	layer = 10

	# CRITICAL: keep this node processing even when the scene tree is paused,
	# otherwise all buttons and sliders freeze the moment we pause the game.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure all required audio buses exist before building UI
	_ensure_bus(BUS_MUSIC,    DEFAULT_MUSIC_DB)
	_ensure_bus(BUS_AMBIENCE, DEFAULT_AMBIENCE_DB)   # may already exist from WeatherAmbienceManager
	_ensure_bus(BUS_ENGINE,   DEFAULT_ENGINE_DB)
	_ensure_bus(BUS_SFX,      DEFAULT_SFX_DB)

	_build_ui()
	visible = false   # Hidden until ESC pressed


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_menu()
			get_viewport().set_input_as_handled()


# ==============================================================================
# MENU TOGGLE
# ==============================================================================

func _toggle_menu() -> void:
	visible = not visible
	# Pause the game while the menu is open so the car doesn't drift
	get_tree().paused = visible


# ==============================================================================
# UI CONSTRUCTION
# ==============================================================================

func _build_ui() -> void:
	# ------------------------------------------------------------------
	# BACKDROP — semi-transparent full-screen dimmer
	# MOUSE_FILTER_PASS lets clicks reach the panel behind it.
	# The panel itself stops clicks from reaching the game world.
	# ------------------------------------------------------------------
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.06, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(backdrop)

	# ------------------------------------------------------------------
	# CENTRE PANEL
	# ------------------------------------------------------------------
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(480, 400)
	# Anchor to screen centre
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left   = -240
	_panel.offset_top    = -210
	_panel.offset_right  =  240
	_panel.offset_bottom =  210
	_panel.mouse_filter  = Control.MOUSE_FILTER_STOP   # panel blocks game clicks
	_panel.process_mode  = Node.PROCESS_MODE_ALWAYS

	# Panel background: dark charcoal with slight blue tint
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color            = Color(0.04, 0.03, 0.09, 0.97)
	panel_style.border_color        = Color(0.0, 0.85, 1.0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color        = Color(0.0, 0.7, 1.0, 0.35)
	panel_style.shadow_size         = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# ------------------------------------------------------------------
	# TITLE BAR
	# ------------------------------------------------------------------
	var title_bar = ColorRect.new()
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom = 48
	title_bar.color = Color(0.0, 0.55, 0.8, 0.25)
	_panel.add_child(title_bar)

	# Scanline decoration strip below title
	var scan_line = ColorRect.new()
	scan_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scan_line.offset_top    = 48
	scan_line.offset_bottom = 50
	scan_line.color = Color(0.0, 0.85, 1.0, 0.6)
	_panel.add_child(scan_line)

	var title = Label.new()
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 8
	title.offset_bottom = 48
	title.text = "//  AUDIO  SYSTEMS  //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", orbitron)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	_panel.add_child(title)

	# ------------------------------------------------------------------
	# CLOSE BUTTON  [X]
	# ------------------------------------------------------------------
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left   = -44
	close_btn.offset_top    =   6
	close_btn.offset_right  =  -6
	close_btn.offset_bottom =  42
	close_btn.add_theme_font_override("font", orbitron)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", COLOR_TITLE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(_toggle_menu)
	_panel.add_child(close_btn)

	# ------------------------------------------------------------------
	# SLIDER ROWS  (built via helper, stacked vertically)
	# ------------------------------------------------------------------
	var rows_container = VBoxContainer.new()
	rows_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows_container.offset_top    =  64    # below title bar
	rows_container.offset_left   =  28
	rows_container.offset_right  = -28
	rows_container.offset_bottom = -60
	rows_container.add_theme_constant_override("separation", 18)
	_panel.add_child(rows_container)

	var r_music    = _build_slider_row("MUSIC",         COLOR_MUSIC,    DEFAULT_MUSIC_DB)
	var r_ambience = _build_slider_row("AMBIENCE",      COLOR_AMBIENCE, DEFAULT_AMBIENCE_DB)
	var r_engine   = _build_slider_row("ENGINE HUM",    COLOR_ENGINE,   DEFAULT_ENGINE_DB)
	var r_sfx      = _build_slider_row("SFX",           COLOR_SFX,      DEFAULT_SFX_DB)

	rows_container.add_child(r_music["row"])
	rows_container.add_child(r_ambience["row"])
	rows_container.add_child(r_engine["row"])
	rows_container.add_child(r_sfx["row"])

	_slider_music    = r_music["slider"]
	_slider_ambience = r_ambience["slider"]
	_slider_engine   = r_engine["slider"]
	_slider_sfx      = r_sfx["slider"]

	_label_music    = r_music["db_label"]
	_label_ambience = r_ambience["db_label"]
	_label_engine   = r_engine["db_label"]
	_label_sfx      = r_sfx["db_label"]

	# Connect slider signals to bus update functions
	_slider_music.value_changed.connect(   func(v): _on_slider_changed(BUS_MUSIC,    v, _label_music))
	_slider_ambience.value_changed.connect(func(v): _on_slider_changed(BUS_AMBIENCE, v, _label_ambience))
	_slider_engine.value_changed.connect(  func(v): _on_slider_changed(BUS_ENGINE,   v, _label_engine))
	_slider_sfx.value_changed.connect(     func(v): _on_slider_changed(BUS_SFX,      v, _label_sfx))

	# ------------------------------------------------------------------
	# FOOTER HINT
	# ------------------------------------------------------------------
	var footer = Label.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top    = -46
	footer.offset_bottom =  -8
	footer.text = "[ ESC ] CLOSE  ·  DRAG SLIDERS TO ADJUST"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", orbitron)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.4, 0.6, 0.7, 0.8))
	_panel.add_child(footer)


# Builds one labelled slider row.  Returns a dict with {"row", "slider", "db_label"}.
func _build_slider_row(channel_name: String, accent: Color, default_db: float) -> Dictionary:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# ---- channel label + dB readout on one line ----
	var header = HBoxContainer.new()

	var name_lbl = Label.new()
	name_lbl.text = channel_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", orbitron)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", accent)
	header.add_child(name_lbl)

	var db_lbl = Label.new()
	db_lbl.text  = _format_db(default_db)
	db_lbl.custom_minimum_size = Vector2(72, 0)
	db_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	db_lbl.add_theme_font_override("font", orbitron)
	db_lbl.add_theme_font_size_override("font_size", 13)
	db_lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.75))
	header.add_child(db_lbl)

	row.add_child(header)

	# ---- the actual slider ----
	var slider = HSlider.new()
	slider.min_value = SLIDER_MIN_DB
	slider.max_value = SLIDER_MAX_DB
	slider.step      = 0.5
	slider.value     = default_db
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the slider track and grabber with the accent colour
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 1.0)
	track_style.set_corner_radius_all(3)
	track_style.content_margin_top    = 8
	track_style.content_margin_bottom = 8
	slider.add_theme_stylebox_override("slider", track_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.9)
	fill_style.set_corner_radius_all(3)
	fill_style.content_margin_top    = 8
	fill_style.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber_area", fill_style)

	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = accent
	grabber_style.set_corner_radius_all(4)
	grabber_style.content_margin_left   = 5
	grabber_style.content_margin_right  = 5
	grabber_style.content_margin_top    = 5
	grabber_style.content_margin_bottom = 5
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)

	# Thin accent line under slider as decoration
	var underline = ColorRect.new()
	underline.custom_minimum_size = Vector2(0, 1)
	underline.color = Color(accent.r, accent.g, accent.b, 0.18)

	row.add_child(slider)
	row.add_child(underline)

	return {"row": row, "slider": slider, "db_label": db_lbl}


# ==============================================================================
# SLIDER CALLBACK
# ==============================================================================

func _on_slider_changed(bus_name: String, value_db: float, db_label: Label) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("[AudioSettingsMenu] Bus not found: " + bus_name)
		return

	# Convert the slider's dB value to linear volume and apply
	AudioServer.set_bus_volume_db(bus_idx, value_db)

	# Mute the bus entirely at the bottom of the range to avoid -60 dB hiss
	AudioServer.set_bus_mute(bus_idx, value_db <= SLIDER_MIN_DB)

	# Update the readout label
	db_label.text = _format_db(value_db)


# ==============================================================================
# HELPERS
# ==============================================================================

# Formats a dB value as a tidy string, e.g. "-12.0 dB" or "MUTE"
func _format_db(db: float) -> String:
	if db <= SLIDER_MIN_DB:
		return "MUTE"
	var sign_str = "+" if db > 0.0 else ""
	return sign_str + ("%.1f" % db) + " dB"


# Creates an audio bus if it doesn't already exist, sets initial volume.
# Sends to Master so you can still add per-bus effects later.
func _ensure_bus(bus_name: String, initial_db: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		print("[AudioSettingsMenu] Created audio bus: ", bus_name)
	AudioServer.set_bus_volume_db(idx, initial_db)
