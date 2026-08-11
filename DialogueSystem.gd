extends CanvasLayer
class_name DialogueSystem

# ==============================================================================
# DIALOGUE SYSTEM (DialogueSystem.gd)
# ==============================================================================
# Visual-novel style dialogue overlay for Cyberpunk Macbeth.
# Renders on top of the 3D city scene via CanvasLayer (high layer index).
#
# ARCHITECTURE:
#   - Completely decoupled from all 3D physics and city generation systems.
#   - Dialogue content loaded from external JSON files (dialogue/ directory).
#   - Speaker portrait colors driven per-character via the JSON data.
#   - Typewriter text animation with skip-on-input.
#   - Emits signals so external systems (PlayerOnFoot, BattleSystem) can
#     react to dialogue start/end without tight coupling.
#
# TRIGGERING (from PlayerOnFoot or any scene node):
#   DialogueSystem.start_dialogue("res://dialogue/porter_at_the_pit.json")
#
# SIGNALS:
#   dialogue_started(json_path)
#   dialogue_ended
#   dialogue_choice_selected(choice_index, target_node_id)

# ==============================================================================
# LAYER & ANIMATION PARAMETERS  (tweak these at the top, never bury them)
# ==============================================================================

@export var dialogue_canvas_layer_index:    int   = 20     # Must be above all other CanvasLayers
@export var typewriter_chars_per_second:    float = 58.0   # Characters revealed per second
@export var panel_slide_in_duration:        float = 0.22   # Seconds for panel to slide up on open
@export var panel_slide_out_duration:       float = 0.18   # Seconds for panel to slide down on close
@export var dim_overlay_alpha:              float = 0.55   # Darkness of the background dim (0–1)
@export var portrait_glow_pulse_speed:      float = 1.8    # Speed of the portrait border pulse
@export var scanline_scroll_speed:          float = 40.0   # Pixels/sec scanline animation

# Neon color palette used for UI chrome (customise for night/weather themes)
@export var chrome_neon_color:  Color = Color(0.0, 1.0, 0.85, 1.0)   # Cyan teal
@export var choice_hover_color: Color = Color(1.0, 0.55, 0.0, 1.0)   # Hot amber
@export var speaker_name_glow_color: Color = Color(1.0, 0.45, 0.1, 1.0)  # Orange neon

# ==============================================================================
# SIGNALS
# ==============================================================================

signal dialogue_started(json_source_path: String)
signal dialogue_ended
signal dialogue_choice_selected(choice_index: int, target_node_id: String)

# ==============================================================================
# NODE REFERENCES  (built procedurally — no external .tscn file required)
# ==============================================================================

var _dialogue_root_control:     Control         # Full-screen root container
var _dim_overlay_rect:          ColorRect       # Semi-transparent background dim
var _scanline_overlay_rect:     ColorRect       # Animated scanline texture overlay

var _portrait_frame_panel:      Panel           # Left-side portrait chrome frame
var _portrait_color_accent:     ColorRect       # Speaker accent color bar (left edge)
var _portrait_label_initials:   Label           # Large character initial/sigil

var _dialogue_panel:            Panel           # Bottom dialogue box
var _speaker_name_label:        Label           # Speaker name (Orbitron, neon styled)
var _speaker_subtitle_label:    Label           # Role/neural-ID subtitle line
var _dialogue_rich_label:       RichTextLabel   # Main dialogue text (typewriter)
var _choices_v_container:       VBoxContainer   # Holds dynamically spawned choice buttons
var _continue_hint_label:       Label           # "[SPACE to skip / advance]" hint

# Panel slide animation position targets
var _panel_hidden_y_offset:     float = 340.0   # Pixels below screen when hidden
var _panel_target_y_offset:     float = 0.0

# ==============================================================================
# STATE
# ==============================================================================

var _active_dialogue_tree:      Dictionary = {}   # Full loaded JSON tree
var _current_node_id:           String     = ""   # ID of the node being displayed
var _is_dialogue_active:        bool       = false
var _typewriter_full_text:      String     = ""   # Complete text for current node
var _typewriter_char_index:     float      = 0.0  # Float so we accumulate fractional chars
var _typewriter_is_complete:    bool       = false
var _scanline_scroll_offset:    float      = 0.0  # Animated scanline Y scroll
var _portrait_pulse_phase:      float      = 0.0  # Sine phase for portrait glow pulse
var _panel_slide_progress:      float      = 0.0  # 0=hidden, 1=visible (animated)
var _is_sliding_in:             bool       = false
var _is_sliding_out:            bool       = false

# ==============================================================================
# GODOT LIFECYCLE
# ==============================================================================

func _ready() -> void:
	layer = dialogue_canvas_layer_index
	_build_dialogue_ui()
	_dialogue_root_control.visible = false

func _process(delta: float) -> void:
	if not _is_dialogue_active and not _is_sliding_out:
		return

	_animate_panel_slide(delta)
	_animate_scanlines(delta)

	if _is_dialogue_active:
		_animate_portrait_pulse(delta)
		_animate_typewriter(delta)

func _input(event: InputEvent) -> void:
	if not _is_dialogue_active:
		return

	# Space or Enter: skips typewriter / advances dialogue / triggers choice
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_handle_advance_or_skip()
			get_viewport().set_input_as_handled()

	# LMB: only intercept during typewriter animation.
	# Once choices are visible the buttons handle their own clicks — do NOT consume
	# the event here or the buttons will never receive it.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not _typewriter_is_complete:
			_handle_advance_or_skip()
			get_viewport().set_input_as_handled()

# ==============================================================================
# PUBLIC API — called by PlayerOnFoot or any interaction trigger
# ==============================================================================

## Loads a JSON dialogue file and starts the dialogue from the "start" node.
## json_res_path example: "res://dialogue/porter_at_the_pit.json"
func start_dialogue(json_res_path: String, start_node_override: String = "start") -> void:
	if _is_dialogue_active:
		push_warning("DialogueSystem: start_dialogue called while already active — ignoring.")
		return

	var loaded_tree: Dictionary = _load_dialogue_json(json_res_path)
	if loaded_tree.is_empty():
		push_error("DialogueSystem: Failed to load or parse: " + json_res_path)
		return

	_active_dialogue_tree = loaded_tree
	_is_dialogue_active   = true

	_dialogue_root_control.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_begin_slide_in()
	_display_node(start_node_override)

	emit_signal("dialogue_started", json_res_path)

## Starts dialogue directly from a Dictionary data structure (no JSON file required!)
func start_dialogue_dict(dialogue_tree: Dictionary, start_node_override: String = "start") -> void:
	if _is_dialogue_active:
		push_warning("DialogueSystem: start_dialogue called while already active — ignoring.")
		return

	if dialogue_tree.is_empty():
		return

	_active_dialogue_tree = dialogue_tree
	_is_dialogue_active   = true

	_dialogue_root_control.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_begin_slide_in()
	_display_node(start_node_override)

	emit_signal("dialogue_started", "dynamic_dict")

## Cleanly ends dialogue and restores input state.
func end_dialogue() -> void:
	if not _is_dialogue_active:
		return
	_is_dialogue_active = false
	_begin_slide_out()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emit_signal("dialogue_ended")

# ==============================================================================
# DIALOGUE LOGIC
# ==============================================================================

func _display_node(node_id: String) -> void:
	var nodes_dict: Dictionary = _active_dialogue_tree.get("nodes", {})

	if node_id == "exit" or not nodes_dict.has(node_id):
		end_dialogue()
		return

	_current_node_id = node_id
	var node_data: Dictionary = nodes_dict[node_id]

	# --- Speaker name + subtitle ---
	_speaker_name_label.text    = _active_dialogue_tree.get("speaker_display_name", "???")
	_speaker_subtitle_label.text = _active_dialogue_tree.get("speaker_subtitle", "")

	# --- Portrait accent color from tree-level speaker_color ---
	var speaker_hex: String = _active_dialogue_tree.get("speaker_color", "#00FFD5")
	var portrait_accent_color := Color(speaker_hex)
	_portrait_color_accent.color = portrait_accent_color
	_speaker_name_label.add_theme_color_override("font_color", portrait_accent_color)

	# --- Initials sigil in portrait ---
	var display_name: String = _active_dialogue_tree.get("speaker_display_name", "?")
	_portrait_label_initials.text = display_name.left(1).to_upper()
	_portrait_label_initials.add_theme_color_override("font_color", portrait_accent_color)

	# --- Start typewriter for dialogue text ---
	_typewriter_full_text   = node_data.get("text", "")
	_typewriter_char_index  = 0.0
	_typewriter_is_complete = false
	_dialogue_rich_label.text = ""

	# --- Hide choices until typewriter completes ---
	_clear_choice_buttons()
	_continue_hint_label.text    = "[SPACE / ENTER] — Skip"
	_continue_hint_label.visible = true

func _handle_advance_or_skip() -> void:
	if not _typewriter_is_complete:
		# Skip typewriter: show full text immediately
		_typewriter_is_complete    = true
		_typewriter_char_index     = float(_typewriter_full_text.length())
		_dialogue_rich_label.text  = _typewriter_full_text
		_spawn_choice_buttons()
	else:
		# If text typing is complete:
		# If there are no choices (or only 1 automatic choice/exit node), pressing Enter/Space ends or advances dialogue
		var buttons := _choices_v_container.get_children()
		if buttons.is_empty():
			end_dialogue()
		elif buttons.size() == 1 and buttons[0] is Button:
			(buttons[0] as Button).pressed.emit()
		else:
			# If multiple choices, press the currently focused choice button if any
			var focused := _choices_v_container.get_viewport().gui_get_focus_owner()
			if focused in buttons and focused is Button:
				(focused as Button).pressed.emit()
			elif buttons[0] is Button:
				(buttons[0] as Button).pressed.emit()

func _spawn_choice_buttons() -> void:
	_clear_choice_buttons()
	_continue_hint_label.visible = false

	var nodes_dict: Dictionary = _active_dialogue_tree.get("nodes", {})
	var node_data:  Dictionary = nodes_dict.get(_current_node_id, {})
	var choices:    Array      = node_data.get("choices", [])

	for choice_index in range(choices.size()):
		var choice_data: Dictionary = choices[choice_index]
		var choice_text: String     = choice_data.get("text", "Continue")
		var target_id:   String     = choice_data.get("target", "exit")

		var cyber_button := _build_cyber_choice_button(choice_text, choice_index, target_id)
		_choices_v_container.add_child(cyber_button)

	# Focus first button so arrow keys and Enter work immediately
	if _choices_v_container.get_child_count() > 0:
		var first_btn = _choices_v_container.get_child(0) as Control
		if first_btn:
			first_btn.grab_focus()

func _clear_choice_buttons() -> void:
	for existing_child in _choices_v_container.get_children():
		existing_child.queue_free()

func _on_choice_button_pressed(choice_index: int, target_node_id: String) -> void:
	emit_signal("dialogue_choice_selected", choice_index, target_node_id)
	_display_node(target_node_id)

# ==============================================================================
# ANIMATION
# ==============================================================================

func _animate_typewriter(delta: float) -> void:
	if _typewriter_is_complete:
		return

	_typewriter_char_index += typewriter_chars_per_second * delta
	var reveal_count: int = mini(int(_typewriter_char_index), _typewriter_full_text.length())
	_dialogue_rich_label.text = _typewriter_full_text.left(reveal_count)

	if reveal_count >= _typewriter_full_text.length():
		_typewriter_is_complete = true
		_dialogue_rich_label.text = _typewriter_full_text
		_spawn_choice_buttons()

func _animate_scanlines(delta: float) -> void:
	_scanline_scroll_offset += scanline_scroll_speed * delta
	# Tile offset wrapped to texture height (assuming scanline texture height of 4px pattern)
	_scanline_overlay_rect.material.set_shader_parameter(
		"scroll_offset_y", fmod(_scanline_scroll_offset, 64.0)
	)

func _animate_portrait_pulse(delta: float) -> void:
	_portrait_pulse_phase += portrait_glow_pulse_speed * delta
	var pulse_value: float = (sin(_portrait_pulse_phase) * 0.5 + 0.5)  # 0.0 – 1.0
	var pulsed_alpha: float = lerpf(0.6, 1.0, pulse_value)
	var speaker_hex: String = _active_dialogue_tree.get("speaker_color", "#00FFD5")
	var pulsed_color := Color(speaker_hex)
	pulsed_color.a    = pulsed_alpha
	_portrait_color_accent.color = pulsed_color

func _animate_panel_slide(delta: float) -> void:
	if _is_sliding_in:
		_panel_slide_progress += delta / panel_slide_in_duration
		_panel_slide_progress  = clamp(_panel_slide_progress, 0.0, 1.0)
		var eased: float       = _ease_out_cubic(_panel_slide_progress)
		_dialogue_panel.offset_bottom = lerpf(_panel_hidden_y_offset, 0.0, eased)
		_dim_overlay_rect.modulate.a  = lerpf(0.0, dim_overlay_alpha, eased)
		if _panel_slide_progress >= 1.0:
			_is_sliding_in = false

	elif _is_sliding_out:
		_panel_slide_progress -= delta / panel_slide_out_duration
		_panel_slide_progress  = clamp(_panel_slide_progress, 0.0, 1.0)
		var eased: float       = _ease_in_cubic(1.0 - _panel_slide_progress)
		_dialogue_panel.offset_bottom = lerpf(0.0, _panel_hidden_y_offset, eased)
		_dim_overlay_rect.modulate.a  = lerpf(dim_overlay_alpha, 0.0, eased)
		if _panel_slide_progress <= 0.0:
			_is_sliding_out = false
			_dialogue_root_control.visible = false

func _begin_slide_in() -> void:
	_panel_slide_progress          = 0.0
	_is_sliding_in                 = true
	_is_sliding_out                = false
	_dialogue_panel.offset_bottom  = _panel_hidden_y_offset
	_dim_overlay_rect.modulate.a   = 0.0

func _begin_slide_out() -> void:
	_is_sliding_out = true
	_is_sliding_in  = false

# Easing helpers
func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _ease_in_cubic(t: float) -> float:
	return t * t * t

# ==============================================================================
# JSON LOADING
# ==============================================================================

func _load_dialogue_json(json_res_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_res_path):
		push_error("DialogueSystem: File not found: " + json_res_path)
		return {}

	var file_handle := FileAccess.open(json_res_path, FileAccess.READ)
	if file_handle == null:
		push_error("DialogueSystem: Cannot open: " + json_res_path)
		return {}

	var raw_text: String = file_handle.get_as_text()
	file_handle.close()

	var json_parser := JSON.new()
	var parse_error: Error = json_parser.parse(raw_text)
	if parse_error != OK:
		push_error("DialogueSystem: JSON parse error in %s — %s" % [json_res_path, json_parser.get_error_message()])
		return {}

	var parsed_result = json_parser.get_data()
	if not parsed_result is Dictionary:
		push_error("DialogueSystem: Root JSON element must be a Dictionary in: " + json_res_path)
		return {}

	return parsed_result as Dictionary

# ==============================================================================
# UI CONSTRUCTION  (procedural — avoids .tscn dependency for this module)
# ==============================================================================

func _build_dialogue_ui() -> void:
	# --- Root full-screen control ---
	_dialogue_root_control = Control.new()
	_dialogue_root_control.name               = "DialogueRootControl"
	_dialogue_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_root_control.mouse_filter       = Control.MOUSE_FILTER_STOP
	add_child(_dialogue_root_control)

	_build_dim_overlay()
	_build_scanline_overlay()
	_build_portrait_panel()
	_build_dialogue_panel()

func _build_dim_overlay() -> void:
	_dim_overlay_rect       = ColorRect.new()
	_dim_overlay_rect.name  = "CyberpunkDimOverlay"
	_dim_overlay_rect.color = Color(0.0, 0.0, 0.04, dim_overlay_alpha)
	_dim_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_overlay_rect.modulate.a = 0.0  # starts transparent, slides in
	_dialogue_root_control.add_child(_dim_overlay_rect)

func _build_scanline_overlay() -> void:
	_scanline_overlay_rect      = ColorRect.new()
	_scanline_overlay_rect.name = "ScanlineOverlay"
	_scanline_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanline_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Inline shader: renders dark horizontal scanlines across the full screen
	var scanline_shader_code: String = """
shader_type canvas_item;
uniform float scroll_offset_y : hint_range(0, 64) = 0.0;
void fragment() {
    float screen_y  = (UV.y * 1080.0 + scroll_offset_y);
    float line_val  = mod(screen_y, 4.0);
    float darkness  = (line_val < 1.5) ? 0.12 : 0.0;
    COLOR = vec4(0.0, 0.0, 0.0, darkness);
}
"""
	var scanline_shader := Shader.new()
	scanline_shader.code = scanline_shader_code
	var scanline_mat     := ShaderMaterial.new()
	scanline_mat.shader  = scanline_shader
	_scanline_overlay_rect.material = scanline_mat
	_dialogue_root_control.add_child(_scanline_overlay_rect)

func _build_portrait_panel() -> void:
	# Portrait frame: left side, roughly bottom-third height
	_portrait_frame_panel      = Panel.new()
	_portrait_frame_panel.name = "CharacterPortraitFrame"

	# Position left side, vertically centred in the lower 40% of screen
	_portrait_frame_panel.set_anchor_and_offset(SIDE_LEFT,   0.0,   24.0)
	_portrait_frame_panel.set_anchor_and_offset(SIDE_RIGHT,  0.0,  184.0)
	_portrait_frame_panel.set_anchor_and_offset(SIDE_TOP,    0.62,   0.0)
	_portrait_frame_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.94,   0.0)

	var portrait_panel_style := StyleBoxFlat.new()
	portrait_panel_style.bg_color                = Color(0.02, 0.02, 0.05, 0.92)
	portrait_panel_style.border_width_left        = 3
	portrait_panel_style.border_width_right       = 3
	portrait_panel_style.border_width_top         = 3
	portrait_panel_style.border_width_bottom      = 3
	portrait_panel_style.border_color             = chrome_neon_color
	portrait_panel_style.corner_radius_top_left   = 4
	portrait_panel_style.corner_radius_top_right  = 4
	portrait_panel_style.corner_radius_bottom_left  = 4
	portrait_panel_style.corner_radius_bottom_right = 4
	_portrait_frame_panel.add_theme_stylebox_override("panel", portrait_panel_style)
	_dialogue_root_control.add_child(_portrait_frame_panel)

	# Accent color bar — 6px wide strip on the left edge of portrait
	_portrait_color_accent       = ColorRect.new()
	_portrait_color_accent.name  = "SpeakerAccentBar"
	_portrait_color_accent.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	_portrait_color_accent.set_anchor_and_offset(SIDE_RIGHT,  0.0,  6.0)
	_portrait_color_accent.set_anchor_and_offset(SIDE_TOP,    0.0,  0.0)
	_portrait_color_accent.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	_portrait_frame_panel.add_child(_portrait_color_accent)

	# Large character initial / sigil centered in portrait box
	_portrait_label_initials      = Label.new()
	_portrait_label_initials.name = "SpeakerInitialSigil"
	_portrait_label_initials.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_portrait_label_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label_initials.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_portrait_label_initials.text                 = "P"

	var sigil_font: FontFile = _load_orbitron_font()
	if sigil_font:
		_portrait_label_initials.add_theme_font_override("font", sigil_font)
	_portrait_label_initials.add_theme_font_size_override("font_size", 58)
	_portrait_frame_panel.add_child(_portrait_label_initials)

func _build_dialogue_panel() -> void:
	_dialogue_panel      = Panel.new()
	_dialogue_panel.name = "CyberpunkDialoguePanel"

	_dialogue_panel.set_anchor_and_offset(SIDE_LEFT,   0.0,  200.0)
	_dialogue_panel.set_anchor_and_offset(SIDE_RIGHT,  0.65,   0.0)
	_dialogue_panel.set_anchor_and_offset(SIDE_TOP,    0.62,   0.0)
	_dialogue_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.94,   0.0)  # Height matches left portrait panel (0.62 to 0.94 Y)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color                  = Color(0.01, 0.01, 0.04, 0.94)
	panel_style.border_width_left          = 2
	panel_style.border_width_right         = 2
	panel_style.border_width_top           = 2
	panel_style.border_width_bottom        = 2
	panel_style.border_color               = chrome_neon_color
	panel_style.corner_radius_top_left     = 4
	panel_style.corner_radius_top_right    = 4
	panel_style.corner_radius_bottom_left  = 4
	panel_style.corner_radius_bottom_right = 4
	_dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	_dialogue_root_control.add_child(_dialogue_panel)

	# Top neon chrome line accent
	var neon_top_line      := ColorRect.new()
	neon_top_line.name      = "NeonTopAccentLine"
	neon_top_line.color     = chrome_neon_color
	neon_top_line.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	neon_top_line.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	neon_top_line.set_anchor_and_offset(SIDE_TOP,    0.0,  0.0)
	neon_top_line.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  2.0)
	_dialogue_panel.add_child(neon_top_line)

	var margin_wrap       := MarginContainer.new()
	margin_wrap.name       = "DialoguePanelMargin"
	margin_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_wrap.add_theme_constant_override("margin_left",   18)
	margin_wrap.add_theme_constant_override("margin_right",  18)
	margin_wrap.add_theme_constant_override("margin_top",    14)
	margin_wrap.add_theme_constant_override("margin_bottom", 12)
	_dialogue_panel.add_child(margin_wrap)

	var panel_v_box       := VBoxContainer.new()
	panel_v_box.name       = "DialoguePanelVBox"
	panel_v_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_v_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel_v_box.add_theme_constant_override("separation", 6)
	margin_wrap.add_child(panel_v_box)

	var orbitron_font: FontFile = _load_orbitron_font()
	var ubuntu_font:   FontFile = _load_ubuntu_font()

	# Speaker name label
	_speaker_name_label      = Label.new()
	_speaker_name_label.name = "SpeakerNameLabel"
	if orbitron_font:
		_speaker_name_label.add_theme_font_override("font", orbitron_font)
	_speaker_name_label.add_theme_font_size_override("font_size", 16)
	_speaker_name_label.add_theme_color_override("font_color", speaker_name_glow_color)
	panel_v_box.add_child(_speaker_name_label)

	# Speaker subtitle / neural-ID
	_speaker_subtitle_label      = Label.new()
	_speaker_subtitle_label.name = "SpeakerSubtitleLabel"
	if ubuntu_font:
		_speaker_subtitle_label.add_theme_font_override("font", ubuntu_font)
	_speaker_subtitle_label.add_theme_font_size_override("font_size", 10)
	_speaker_subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.9, 0.7))
	_speaker_subtitle_label.modulate.a = 0.75
	panel_v_box.add_child(_speaker_subtitle_label)

	# Thin divider line
	var divider_line      := ColorRect.new()
	divider_line.name      = "SpeakerDividerLine"
	divider_line.color     = Color(chrome_neon_color.r, chrome_neon_color.g, chrome_neon_color.b, 0.3)
	divider_line.custom_minimum_size = Vector2(0.0, 1.0)
	panel_v_box.add_child(divider_line)

	# Main dialogue RichTextLabel
	_dialogue_rich_label        = RichTextLabel.new()
	_dialogue_rich_label.name   = "DialogueRichTextBody"
	_dialogue_rich_label.bbcode_enabled = true
	_dialogue_rich_label.fit_content    = false
	_dialogue_rich_label.scroll_active  = false
	_dialogue_rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ubuntu_font:
		_dialogue_rich_label.add_theme_font_override("normal_font", ubuntu_font)
	_dialogue_rich_label.add_theme_font_size_override("normal_font_size", 14)
	_dialogue_rich_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.90, 1.0))
	panel_v_box.add_child(_dialogue_rich_label)

	# Choices container
	_choices_v_container      = VBoxContainer.new()
	_choices_v_container.name = "DialogueChoicesContainer"
	_choices_v_container.add_theme_constant_override("separation", 5)
	panel_v_box.add_child(_choices_v_container)

	# Continue hint
	_continue_hint_label      = Label.new()
	_continue_hint_label.name = "ContinueHintLabel"
	_continue_hint_label.text = "[SPACE] — Skip"
	_continue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if ubuntu_font:
		_continue_hint_label.add_theme_font_override("font", ubuntu_font)
	_continue_hint_label.add_theme_font_size_override("font_size", 10)
	_continue_hint_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.8, 0.5))
	panel_v_box.add_child(_continue_hint_label)

# ==============================================================================
# CHOICE BUTTON FACTORY
# ==============================================================================

func _build_cyber_choice_button(button_text: String, choice_index: int, target_id: String) -> Button:
	var cyber_btn      := Button.new()
	cyber_btn.name      = "ChoiceButton_%d" % choice_index
	cyber_btn.text      = "▸  " + button_text
	cyber_btn.flat      = false
	cyber_btn.focus_mode = Control.FOCUS_ALL  # Allow keyboard navigation via Up/Down arrow keys

	var ubuntu_font: FontFile = _load_ubuntu_font()
	if ubuntu_font:
		cyber_btn.add_theme_font_override("font", ubuntu_font)
	cyber_btn.add_theme_font_size_override("font_size", 13)

	# --- Normal state style ---
	var normal_style             := StyleBoxFlat.new()
	normal_style.bg_color         = Color(0.02, 0.08, 0.08, 0.85)
	normal_style.border_width_left = 2
	normal_style.border_color      = Color(chrome_neon_color.r, chrome_neon_color.g, chrome_neon_color.b, 0.4)
	normal_style.corner_radius_top_left     = 2
	normal_style.corner_radius_top_right    = 2
	normal_style.corner_radius_bottom_left  = 2
	normal_style.corner_radius_bottom_right = 2
	normal_style.content_margin_left   = 12.0
	normal_style.content_margin_top    = 5.0
	normal_style.content_margin_bottom = 5.0
	cyber_btn.add_theme_stylebox_override("normal", normal_style)
	cyber_btn.add_theme_color_override("font_color", Color(0.78, 0.95, 0.92, 1.0))

	# --- Hover / Focus state style ---
	var hover_style             := StyleBoxFlat.new()
	hover_style.bg_color         = Color(0.0, 0.18, 0.16, 0.95)
	hover_style.border_width_left = 3
	hover_style.border_color      = choice_hover_color
	hover_style.corner_radius_top_left     = 2
	hover_style.corner_radius_top_right    = 2
	hover_style.corner_radius_bottom_left  = 2
	hover_style.corner_radius_bottom_right = 2
	hover_style.content_margin_left   = 12.0
	hover_style.content_margin_top    = 5.0
	hover_style.content_margin_bottom = 5.0
	cyber_btn.add_theme_stylebox_override("hover", hover_style)
	cyber_btn.add_theme_stylebox_override("focus", hover_style)
	cyber_btn.add_theme_color_override("font_hover_color", choice_hover_color)
	cyber_btn.add_theme_color_override("font_focus_color", choice_hover_color)

	# --- Pressed state style ---
	var pressed_style             := StyleBoxFlat.new()
	pressed_style.bg_color         = Color(0.06, 0.25, 0.18, 0.95)
	pressed_style.border_width_left = 3
	pressed_style.border_color      = Color(0.0, 1.0, 0.5, 1.0)
	pressed_style.corner_radius_top_left     = 2
	pressed_style.corner_radius_top_right    = 2
	pressed_style.corner_radius_bottom_left  = 2
	pressed_style.corner_radius_bottom_right = 2
	pressed_style.content_margin_left   = 12.0
	pressed_style.content_margin_top    = 5.0
	pressed_style.content_margin_bottom = 5.0
	cyber_btn.add_theme_stylebox_override("pressed", pressed_style)

	cyber_btn.pressed.connect(func(): _on_choice_button_pressed(choice_index, target_id))
	return cyber_btn

# ==============================================================================
# FONT LOADING HELPERS
# ==============================================================================

func _load_orbitron_font() -> FontFile:
	var orbitron_path: String = "res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf"
	if ResourceLoader.exists(orbitron_path):
		return load(orbitron_path) as FontFile
	return null

func _load_ubuntu_font() -> FontFile:
	# Locate any Ubuntu .ttf in the fonts/Ubuntu/ directory
	var ubuntu_regular_path: String = "res://fonts/Ubuntu/Ubuntu-Regular.ttf"
	if ResourceLoader.exists(ubuntu_regular_path):
		return load(ubuntu_regular_path) as FontFile
	# Fallback: any .ttf in the Ubuntu folder (Godot will find it)
	var ubuntu_bold_path: String = "res://fonts/Ubuntu/Ubuntu-Bold.ttf"
	if ResourceLoader.exists(ubuntu_bold_path):
		return load(ubuntu_bold_path) as FontFile
	return null
