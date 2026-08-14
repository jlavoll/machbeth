extends Node
class_name NeuralNotificationSystem

# ==============================================================================
# NEURAL NOTIFICATION SYSTEM (NeuralNotificationSystem.gd)
# ==============================================================================
# Displays incoming neural communications from "Lady M" top-left on screen.
# Styled as a futuristic cyberpunk encrypted head-up comms message.

# Preloaded Orbitron and Ubuntu fonts
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")
var ubuntu_font: Font = preload("res://fonts/Ubuntu/Ubuntu-Regular.ttf")

@export var popup_display_duration: float = 5.5
@export var random_message_interval: float = 35.0 # Seconds between ambient transmissions

# UI Nodes
var comms_canvas_layer: CanvasLayer
var comms_card_container: MarginContainer
var comms_panel: PanelContainer
var sender_avatar_box: ColorRect
var sender_name_label: Label
var status_sub_label: Label
var message_body_label: RichTextLabel

# Animation state
var fade_tween: Tween = null
var ambient_timer: float = 0.0

# Pre-scripted Lady M messages categorized by context
var weather_messages: Dictionary = {
	"NEON_RAIN": [
		"Rain's heavy tonight, Banquo. Mind the slick turns—Duncan Dynamics hitmen love bad visibility.",
		"Acid rain's eating through the optical sensors. Keep your head down.",
		"Downpour is masking our telemetry signature. Good night for clandestine moves."
	],
	"CYBER_SNOW": [
		"Sub-zero frost on the upper highways. Keep your thermal core warm, Banquo.",
		"Cyber-snow in August... the climate scrubbers must be failing in Sector 4."
	],
	"CLEAR_NEON_NIGHT": [
		"Sky's clear over the neon grid. Satellite surveillance is high—watch your tail.",
		"Quiet night. Almost makes you forget Duncan's board is watching every sector."
	]
}

var ambient_story_messages: Array[String] = [
	"Banquo, I've scrubbed our last location log from the central grid. We're clear for now.",
	"Keep an eye on Mack... he's been running his neural interface at max clock. The paranoia is leaking into his telemetry.",
	"The Syndicate's encrypted traffic is spiking. Stay sharp out there.",
	"Remember why we're doing this, Banquo. Duncan's legacy won't protect itself."
]

var mission_completion_messages: Array[String] = [
	"Data-chip received and decrypted cleanly. Great work, Banquo. 500 Credits added to your Neural Vault.",
	"Target delivery confirmed. The Syndicate won't know what hit them. Money's in your account.",
	"Clean handover, Banquo. Lady M out."
]

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_build_comms_ui()
	comms_card_container.modulate.a = 0.0
	comms_card_container.position.x = -320.0 # Hidden off-screen left
	ambient_timer = -25.0 # Grace period delay so morning briefing calls finish before ambient chatter begins!

func _process(delta: float) -> void:
	# Pause ambient random chatter during Mack's Grand Battle deployments
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_mgr) and campaign_mgr.is_battle_in_progress:
		return

	ambient_timer += delta
	if ambient_timer >= random_message_interval:
		ambient_timer = 0.0
		_trigger_random_ambient_text()

# ==============================================================================
# PUBLIC API — Trigger Lady M Messages
# ==============================================================================

## Send a custom message from Lady M to Banquo
func send_message(text_content: String, sender_name: String = "LADY M // EXEC LINK") -> void:
	sender_name_label.text = sender_name
	message_body_label.text = text_content
	_animate_slide_in()

## Trigger a context message for mission completion
func trigger_mission_complete_text() -> void:
	var msg: String = mission_completion_messages[randi() % mission_completion_messages.size()]
	send_message(msg, "LADY M // ENCRYPTED UPLINK")

## Trigger a context message based on active weather
func trigger_weather_text(weather_name: String) -> void:
	if weather_messages.has(weather_name):
		var options: Array = weather_messages[weather_name]
		var msg: String = options[randi() % options.size()]
		send_message(msg, "LADY M // WEATHER MONITOR")

# ==============================================================================
# INTERNAL LOGIC & ANIMATION
# ==============================================================================

func _trigger_random_ambient_text() -> void:
	# Ambient story check-ins from Lady M
	var msg: String = ambient_story_messages[randi() % ambient_story_messages.size()]
	send_message(msg)

func _animate_slide_in() -> void:
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	comms_card_container.visible = true
	# Reset size calculation to ensure dynamic auto-resizing
	comms_card_container.reset_size()
	
	var container_width: float = maxf(comms_card_container.size.x, 320.0)
	comms_card_container.position.x = -(container_width + 40.0)

	fade_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Slide in from off-screen left to 24px and fade in alpha
	fade_tween.tween_property(comms_card_container, "position:x", 24.0, 0.45)
	fade_tween.tween_property(comms_card_container, "modulate:a", 1.0, 0.35)

	# Hold visible, then slide out cleanly
	fade_tween.chain().tween_interval(popup_display_duration)
	fade_tween.chain().tween_property(comms_card_container, "position:x", -(container_width + 40.0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(comms_card_container, "modulate:a", 0.0, 0.35)

# ==============================================================================
# UI CONSTRUCTION (Procedural Top-Left Comms Card)
# ==============================================================================

func _build_comms_ui() -> void:
	comms_canvas_layer = CanvasLayer.new()
	comms_canvas_layer.name = "NeuralNotificationLayer"
	comms_canvas_layer.layer = 15 # Below DialogueSystem (20), above overmap
	add_child(comms_canvas_layer)

	comms_card_container = MarginContainer.new()
	comms_card_container.name = "CommsCardContainer"
	comms_card_container.custom_minimum_size = Vector2(280, 0)
	comms_card_container.position = Vector2(24, 24) # Top-Left Anchor
	comms_canvas_layer.add_child(comms_card_container)

	# Outer Cyber Panel styling
	comms_panel = PanelContainer.new() # PanelContainer dynamically wraps inner content
	comms_panel.name = "CommsPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.02, 0.05, 0.92)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(1.0, 0.0, 0.55, 0.9) # Neon Hot Pink Accent
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	comms_panel.add_theme_stylebox_override("panel", panel_style)
	comms_card_container.add_child(comms_panel)

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	comms_panel.add_child(main_hbox)

	# Left Avatar / Sigil Box
	sender_avatar_box = ColorRect.new()
	sender_avatar_box.custom_minimum_size = Vector2(38, 38)
	sender_avatar_box.color = Color(1.0, 0.0, 0.45, 0.8) # Radiant Lady M Pink
	main_hbox.add_child(sender_avatar_box)

	var avatar_initial = Label.new()
	avatar_initial.text = "M"
	avatar_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_initial.add_theme_font_override("font", orbitron_font)
	avatar_initial.add_theme_font_size_override("font_size", 20)
	avatar_initial.add_theme_color_override("font_color", Color.WHITE)
	sender_avatar_box.add_child(avatar_initial)

	# Right VBox for text
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	main_hbox.add_child(text_vbox)

	# Header: Sender Name
	sender_name_label = Label.new()
	sender_name_label.text = "LADY M // EXEC LINK"
	sender_name_label.add_theme_font_override("font", orbitron_font)
	sender_name_label.add_theme_font_size_override("font_size", 11)
	sender_name_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.6))
	text_vbox.add_child(sender_name_label)

	# Sub-header: Encryption Tag
	status_sub_label = Label.new()
	status_sub_label.text = "SECURE NEURAL TEXT // BANQUO CHIP-ID: 0x99A"
	status_sub_label.add_theme_font_override("font", ubuntu_font)
	status_sub_label.add_theme_font_size_override("font_size", 9)
	status_sub_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.9, 0.6))
	text_vbox.add_child(status_sub_label)

	# Message Body
	message_body_label = RichTextLabel.new()
	message_body_label.bbcode_enabled = true
	message_body_label.fit_content = true
	message_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_body_label.custom_minimum_size = Vector2(240, 0) # Wrap text nicely when long
	message_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_body_label.add_theme_font_override("normal_font", ubuntu_font)
	message_body_label.add_theme_font_size_override("normal_font_size", 12)
	message_body_label.add_theme_color_override("default_color", Color(0.9, 0.95, 0.92))
	text_vbox.add_child(message_body_label)
