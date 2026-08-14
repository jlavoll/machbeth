extends Node
class_name CyborgModdingManager

# ==============================================================================
# MACK'S CYBORG MODDING & GLITCH INTEGRATION MANAGER (CyborgModdingManager.gd)
# ==============================================================================
# Handles Mack's cyberware installation (Neural Cores, Ocular Scopes, Sub-Dermal Plating).
# Integrates directly with NeuralGlitchSystem.gd:
#   - Higher tier cyberware boosts combat stats (Overclock damage, ICE hack speed, Shielding)
#   - BUT increases Mack's passive Glitch Potency / Paranoia baseline!

signal cyberware_installed(slot: String, tier_level: int)
signal cyborg_ui_toggled(is_open: bool)

# Cyberware slots and installation tiers
var cyberware_slots: Dictionary = {
	"neural_core": {
		"name": "NEURAL OVERCLOCK CORE",
		"description": "High-frequency neural processor. Dramatically boosts Overclock Limit Break damage.",
		"tier": 1,
		"max_tier": 3,
		"base_cost": 300,
		"cost_mult": 1.8,
		"glitch_per_tier": 15.0, # Adds +15% to baseline paranoia
		"stat_bonus_desc": "+25 Overclock Damage per tier"
	},
	"ocular_scope": {
		"name": "OCULAR THREAT SCOPE",
		"description": "Tactical cybernetic optics. Accelerates ICE-Breaker hack recharge speed.",
		"tier": 1,
		"max_tier": 3,
		"base_cost": 250,
		"cost_mult": 1.6,
		"glitch_per_tier": 10.0, # Adds +10% to baseline paranoia
		"stat_bonus_desc": "+20% ICE-Breaker speed per tier"
	},
	"subdermal_plating": {
		"name": "SUB-DERMAL GRAPHENE WEAVE",
		"description": "Dense sub-dermal ballistic weave. Increases Mack's personal shielding and hull absorption.",
		"tier": 1,
		"max_tier": 3,
		"base_cost": 350,
		"cost_mult": 1.7,
		"glitch_per_tier": 12.0, # Adds +12% to baseline paranoia
		"stat_bonus_desc": "+30 Hull Protection per tier"
	}
}

# UI Overlay Nodes
var cyborg_hud_layer: CanvasLayer = null
var _cyborg_root_control: Control = null
var is_cyborg_ui_open: bool = false

# Component References
@onready var quest_manager = $"../QuestManager"
@onready var glitch_system = $"../NeuralGlitchSystem"

func _ready() -> void:
	_build_cyborg_ui()

func _input(event: InputEvent) -> void:
	if not is_cyborg_ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close_cyborg_ui()
			get_viewport().set_input_as_handled()

# ==============================================================================
# PUBLIC API
# ==============================================================================

func open_cyborg_ui() -> void:
	if is_cyborg_ui_open:
		return
	is_cyborg_ui_open = true
	if is_instance_valid(_cyborg_root_control):
		_update_ui_contents()
		_cyborg_root_control.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cyborg_ui_toggled.emit(true)

func close_cyborg_ui() -> void:
	if not is_cyborg_ui_open:
		return
	is_cyborg_ui_open = false
	if is_instance_valid(_cyborg_root_control):
		_cyborg_root_control.visible = false
	
	var indoor_mgr = get_parent().get_node_or_null("IndoorSystemManager")
	if not is_instance_valid(indoor_mgr) or not indoor_mgr.is_inside_building:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	cyborg_ui_toggled.emit(false)

func get_upgrade_cost(slot_key: String) -> int:
	if not cyberware_slots.has(slot_key):
		return 99999
	var slot_data: Dictionary = cyberware_slots[slot_key]
	var tier: int = slot_data.get("tier", 1)
	var base_cost: int = slot_data.get("base_cost", 250)
	var mult: float = slot_data.get("cost_mult", 1.6)
	return int(base_cost * pow(mult, tier - 1))

func get_total_baseline_glitch() -> float:
	var total_glitch: float = 0.0
	for slot_key in cyberware_slots:
		var slot_data: Dictionary = cyberware_slots[slot_key]
		var tier: int = slot_data.get("tier", 1)
		var glitch_rate: float = slot_data.get("glitch_per_tier", 10.0)
		total_glitch += (tier - 1) * glitch_rate
	return total_glitch

func install_cyberware(slot_key: String) -> bool:
	if not cyberware_slots.has(slot_key):
		return false
	var slot_data: Dictionary = cyberware_slots[slot_key]
	var current_tier: int = slot_data.get("tier", 1)
	var max_tier: int = slot_data.get("max_tier", 3)
	
	if current_tier >= max_tier:
		print("[CYBORG MODDING] Slot %s is already at MAX tier!" % slot_key)
		return false
	
	var cost: int = get_upgrade_cost(slot_key)
	var current_credits: int = quest_manager.player_credits if is_instance_valid(quest_manager) else 0
	
	if current_credits < cost:
		print("[CYBORG MODDING] Insufficient credits! Needed: %d, Has: %d" % [cost, current_credits])
		return false
	
	# Deduct credits & increase tier
	quest_manager.player_credits -= cost
	slot_data["tier"] = current_tier + 1
	
	# Inject paranoia / glitch baseline directly into NeuralGlitchSystem
	if is_instance_valid(glitch_system):
		var glitch_bump: float = slot_data.get("glitch_per_tier", 10.0)
		glitch_system.inject_neural_instability(glitch_bump)
		print("[CYBORG MODDING] Installed %s Tier %d! Baseline Glitch increased by +%.1f%%" % [slot_key, slot_data["tier"], glitch_bump])
	
	_update_ui_contents()
	cyberware_installed.emit(slot_key, slot_data["tier"])
	return true

# ==============================================================================
# PROCEDURAL CYBORG UI BUILDER
# ==============================================================================

var _credits_label: Label
var _glitch_meter_val: Label
var _glitch_meter_bar: ProgressBar

var _lbl_neural_info: Label
var _lbl_ocular_info: Label
var _lbl_plating_info: Label

var _btn_neural_upg: Button
var _btn_ocular_upg: Button
var _btn_plating_upg: Button

func _build_cyborg_ui() -> void:
	cyborg_hud_layer = CanvasLayer.new()
	cyborg_hud_layer.name = "CyborgHUDLayer"
	cyborg_hud_layer.layer = 25 # Above dialogue
	add_child(cyborg_hud_layer)

	_cyborg_root_control = Control.new()
	_cyborg_root_control.name = "CyborgRootControl"
	_cyborg_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cyborg_root_control.visible = false
	cyborg_hud_layer.add_child(_cyborg_root_control)

	# Dark Crimson / Violet Paranoia Dim
	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.04, 0.0, 0.02, 0.88)
	_cyborg_root_control.add_child(bg_dim)

	# Main Panel Frame (Center)
	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.anchor_left = 0.12
	main_panel.anchor_right = 0.88
	main_panel.anchor_top = 0.1
	main_panel.anchor_bottom = 0.9
	main_panel.offset_left = 0
	main_panel.offset_right = 0
	main_panel.offset_top = 0
	main_panel.offset_bottom = 0

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.01, 0.03, 0.96)
	frame_style.border_width_left = 3
	frame_style.border_width_right = 3
	frame_style.border_width_top = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = Color(1.0, 0.0, 0.6) # Hot Magenta Cyberware Border
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	frame_style.content_margin_left = 20
	frame_style.content_margin_right = 20
	frame_style.content_margin_top = 16
	frame_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", frame_style)
	_cyborg_root_control.add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(main_vbox)

	# Header Bar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "⚡ MACK'S NEURAL CYBORG MODDING SUITE"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.0, 0.6))
	header_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	_credits_label = Label.new()
	_credits_label.text = "CREDITS: 0 C"
	_credits_label.add_theme_font_size_override("font_size", 18)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	header_hbox.add_child(_credits_label)

	var close_btn = Button.new()
	close_btn.text = " [X] CLOSE (ESC) "
	close_btn.pressed.connect(close_cyborg_ui)
	header_hbox.add_child(close_btn)

	var divider1 = ColorRect.new()
	divider1.custom_minimum_size = Vector2(0, 2)
	divider1.color = Color(1.0, 0.0, 0.6, 0.5)
	main_vbox.add_child(divider1)

	# Paranoia / Glitch Warning Bar
	var warning_box = HBoxContainer.new()
	warning_box.add_theme_constant_override("separation", 12)
	main_vbox.add_child(warning_box)

	var warn_lbl = Label.new()
	warn_lbl.text = "🧠 NEURAL GLITCH BASELINE:"
	warn_lbl.add_theme_font_size_override("font_size", 13)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4))
	warning_box.add_child(warn_lbl)

	_glitch_meter_bar = ProgressBar.new()
	_glitch_meter_bar.custom_minimum_size = Vector2(240, 18)
	_glitch_meter_bar.max_value = 100.0
	_glitch_meter_bar.value = 0.0
	warning_box.add_child(_glitch_meter_bar)

	_glitch_meter_val = Label.new()
	_glitch_meter_val.text = "0.0% (STABLE)"
	_glitch_meter_val.add_theme_font_size_override("font_size", 13)
	_glitch_meter_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	warning_box.add_child(_glitch_meter_val)

	var warn_note = Label.new()
	warn_note.text = "⚠️ Higher cyberware tiers increase combat static & Bankes ghost hallucinations."
	warn_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	warn_note.add_theme_font_size_override("font_size", 11)
	warn_note.add_theme_color_override("font_color", Color(0.7, 0.6, 0.75))
	warning_box.add_child(warn_note)

	# Slots VBox
	var slots_vbox = VBoxContainer.new()
	slots_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_vbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(slots_vbox)

	# Slot 1: Neural Core
	_lbl_neural_info = Label.new()
	_btn_neural_upg = Button.new()
	_build_cyberware_card(slots_vbox, "neural_core", _lbl_neural_info, _btn_neural_upg)

	# Slot 2: Ocular Scope
	_lbl_ocular_info = Label.new()
	_btn_ocular_upg = Button.new()
	_build_cyberware_card(slots_vbox, "ocular_scope", _lbl_ocular_info, _btn_ocular_upg)

	# Slot 3: Sub-Dermal Plating
	_lbl_plating_info = Label.new()
	_btn_plating_upg = Button.new()
	_build_cyberware_card(slots_vbox, "subdermal_plating", _lbl_plating_info, _btn_plating_upg)

func _build_cyberware_card(parent: Control, slot_key: String, info_label: Label, upg_button: Button) -> void:
	var slot_data: Dictionary = cyberware_slots[slot_key]
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.02, 0.05, 0.9)
	card_style.border_width_left = 2
	card_style.border_color = Color(1.0, 0.0, 0.6, 0.4)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = slot_data["name"]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.6))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = slot_data["description"]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(desc)

	var bonus = Label.new()
	bonus.text = "STATS: " + slot_data["stat_bonus_desc"] + " | Glitch Risk: +" + str(slot_data["glitch_per_tier"]) + "%"
	bonus.add_theme_font_size_override("font_size", 11)
	bonus.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	vbox.add_child(bonus)

	info_label.text = "Tier 1 / 3"
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(info_label)

	upg_button.text = " INSTALL CYBERWARE "
	upg_button.custom_minimum_size = Vector2(180, 38)
	upg_button.pressed.connect(func(): install_cyberware(slot_key))
	hbox.add_child(upg_button)

func _update_ui_contents() -> void:
	if not is_instance_valid(_cyborg_root_control):
		return

	var current_credits: int = quest_manager.player_credits if is_instance_valid(quest_manager) else 0
	_credits_label.text = "CREDITS: %d C" % current_credits

	# Update Paranoia Baseline
	var baseline_glitch: float = get_total_baseline_glitch()
	var current_glitch: float = glitch_system.neural_glitch_potency if is_instance_valid(glitch_system) else baseline_glitch
	
	_glitch_meter_bar.value = current_glitch
	if current_glitch > 60.0:
		_glitch_meter_val.text = "%.1f%% (CYBER-PSYCHOSIS CRITICAL)" % current_glitch
		_glitch_meter_val.add_theme_color_override("font_color", Color(1.0, 0.0, 0.2))
	elif current_glitch > 30.0:
		_glitch_meter_val.text = "%.1f%% (ELEVATED PARANOIA)" % current_glitch
		_glitch_meter_val.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	else:
		_glitch_meter_val.text = "%.1f%% (STABLE)" % current_glitch
		_glitch_meter_val.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))

	_update_slot_card("neural_core", _lbl_neural_info, _btn_neural_upg, current_credits)
	_update_slot_card("ocular_scope", _lbl_ocular_info, _btn_ocular_upg, current_credits)
	_update_slot_card("subdermal_plating", _lbl_plating_info, _btn_plating_upg, current_credits)

func _update_slot_card(slot_key: String, info_label: Label, button: Button, credits: int) -> void:
	var slot_data: Dictionary = cyberware_slots[slot_key]
	var tier: int = slot_data["tier"]
	var max_tier: int = slot_data["max_tier"]
	info_label.text = "Tier %d / %d" % [tier, max_tier]

	if tier >= max_tier:
		button.text = " MAX TIER "
		button.disabled = true
	else:
		var cost: int = get_upgrade_cost(slot_key)
		button.text = " INSTALL TIER %d (%d C) " % [tier + 1, cost]
		button.disabled = credits < cost
