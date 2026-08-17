extends CanvasLayer
class_name LoadoutGridUI

# ==============================================================================
# DUAL LOADOUT GRID UI (LoadoutGridUI.gd)
# ==============================================================================
# Visual interface for tuning and equipping Mack's cybernetic implants and
# vehicle hardpoints. Accessible from The Pit workshop and Battle Editor (F2).

signal simulation_requested(target_mission_id: String)

var is_open: bool = false
var active_mission_to_simulate: String = "act1_limo_intercept"

# References
var root_control: Control = null
var mack_slots_container: VBoxContainer = null
var vehicle_slots_container: VBoxContainer = null
var stats_summary_label: RichTextLabel = null
var item_picker_container: HBoxContainer = null
var item_picker_panel: PanelContainer = null
var item_picker_title: Label = null

var selected_grid_target: String = ""
var selected_slot_target: String = ""

# Font
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125 # Above Battle Editor (121)
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close_loadout_ui()
			get_viewport().set_input_as_handled()

func open_loadout_ui(mission_id_for_sim: String = "") -> void:
	is_open = true
	visible = true
	active_mission_to_simulate = mission_id_for_sim
	get_tree().paused = true
	_refresh_all_slots()
	_refresh_stats()

func close_loadout_ui() -> void:
	is_open = false
	visible = false
	get_tree().paused = false

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "LoadoutGridRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	# Dim background
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	# Main Margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	root_control.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# 1. Header Bar
	var header_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "⚡ TACTICAL LOADOUT GRID // MACK & WAR-RIG HARDPOINTS"
	title.add_theme_font_override("font", orbitron_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	header_hbox.add_child(title)

	header_hbox.add_spacer(false)

	var btn_close = Button.new()
	btn_close.text = "✖ CLOSE [ESC]"
	btn_close.pressed.connect(close_loadout_ui)
	header_hbox.add_child(btn_close)
	main_vbox.add_child(header_hbox)

	# 2. Main Grid Columns (Mack 5 Slots | Center Stats | Vehicle 4 Slots)
	var grid_columns = HBoxContainer.new()
	grid_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_columns.add_theme_constant_override("separation", 20)
	main_vbox.add_child(grid_columns)

	# LEFT: Mack's Cyborg Grid
	var mack_panel = PanelContainer.new()
	mack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mack_style = StyleBoxFlat.new()
	mack_style.bg_color = Color(0.02, 0.06, 0.09, 0.85)
	mack_style.border_width_left = 3
	mack_style.border_color = Color(0.0, 1.0, 0.85)
	mack_style.content_margin_left = 12
	mack_style.content_margin_right = 12
	mack_style.content_margin_top = 10
	mack_style.content_margin_bottom = 10
	mack_panel.add_theme_stylebox_override("panel", mack_style)
	grid_columns.add_child(mack_panel)

	var mack_inner = VBoxContainer.new()
	mack_inner.add_theme_constant_override("separation", 8)
	mack_panel.add_child(mack_inner)

	var mack_title = Label.new()
	mack_title.text = "👤 MACK'S CYBORG SLOTS (5)"
	mack_title.add_theme_font_override("font", orbitron_font)
	mack_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	mack_inner.add_child(mack_title)

	mack_slots_container = VBoxContainer.new()
	mack_slots_container.add_theme_constant_override("separation", 6)
	mack_inner.add_child(mack_slots_container)

	# CENTER: Telemetry & Stats Summary
	var center_panel = PanelContainer.new()
	center_panel.custom_minimum_size.x = 240
	var center_style = StyleBoxFlat.new()
	center_style.bg_color = Color(0.03, 0.04, 0.07, 0.9)
	center_style.border_width_top = 2
	center_style.border_width_bottom = 2
	center_style.border_color = Color(1.0, 0.85, 0.0)
	center_style.content_margin_left = 12
	center_style.content_margin_right = 12
	center_style.content_margin_top = 10
	center_style.content_margin_bottom = 10
	center_panel.add_theme_stylebox_override("panel", center_style)
	grid_columns.add_child(center_panel)

	var center_inner = VBoxContainer.new()
	center_inner.add_theme_constant_override("separation", 10)
	center_panel.add_child(center_inner)

	var stats_header = Label.new()
	stats_header.text = "📊 COMBAT TELEMETRY"
	stats_header.add_theme_font_override("font", orbitron_font)
	stats_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	center_inner.add_child(stats_header)

	stats_summary_label = RichTextLabel.new()
	stats_summary_label.bbcode_enabled = true
	stats_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_inner.add_child(stats_summary_label)

	# Instant Simulation Button in Center Column
	var sim_btn = Button.new()
	sim_btn.text = "⚔️ [SIMULATE BATTLE NOW]"
	sim_btn.add_theme_font_override("font", orbitron_font)
	sim_btn.add_theme_font_size_override("font_size", 12)
	sim_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4))
	sim_btn.pressed.connect(_on_simulate_pressed)
	center_inner.add_child(sim_btn)

	# RIGHT: Vehicle Hardpoint Grid
	var vehicle_panel = PanelContainer.new()
	vehicle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vehicle_style = StyleBoxFlat.new()
	vehicle_style.bg_color = Color(0.07, 0.03, 0.02, 0.85)
	vehicle_style.border_width_left = 3
	vehicle_style.border_color = Color(1.0, 0.4, 0.0)
	vehicle_style.content_margin_left = 12
	vehicle_style.content_margin_right = 12
	vehicle_style.content_margin_top = 10
	vehicle_style.content_margin_bottom = 10
	vehicle_panel.add_theme_stylebox_override("panel", vehicle_style)
	grid_columns.add_child(vehicle_panel)

	var vehicle_inner = VBoxContainer.new()
	vehicle_inner.add_theme_constant_override("separation", 8)
	vehicle_panel.add_child(vehicle_inner)

	var vehicle_title = Label.new()
	vehicle_title.text = "🚗 WAR-RIG HARDPOINTS (4)"
	vehicle_title.add_theme_font_override("font", orbitron_font)
	vehicle_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
	vehicle_inner.add_child(vehicle_title)

	vehicle_slots_container = VBoxContainer.new()
	vehicle_slots_container.add_theme_constant_override("separation", 6)
	vehicle_inner.add_child(vehicle_slots_container)

	# 3. Item Swap Palette (Bottom Picker)
	item_picker_panel = PanelContainer.new()
	item_picker_panel.custom_minimum_size.y = 120
	var pick_style = StyleBoxFlat.new()
	pick_style.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	pick_style.border_width_top = 2
	pick_style.border_color = Color(0.0, 1.0, 0.85)
	pick_style.content_margin_left = 12
	pick_style.content_margin_right = 12
	pick_style.content_margin_top = 8
	pick_style.content_margin_bottom = 8
	item_picker_panel.add_theme_stylebox_override("panel", pick_style)
	main_vbox.add_child(item_picker_panel)

	var pick_vbox = VBoxContainer.new()
	item_picker_panel.add_child(pick_vbox)

	item_picker_title = Label.new()
	item_picker_title.text = "📦 SELECT A SLOT ABOVE TO SWAP / EQUIP FROM INVENTORY"
	item_picker_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	pick_vbox.add_child(item_picker_title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pick_vbox.add_child(scroll)

	item_picker_container = HBoxContainer.new()
	item_picker_container.add_theme_constant_override("separation", 10)
	scroll.add_child(item_picker_container)

func _refresh_all_slots() -> void:
	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	# Refresh Mack Slots
	for child in mack_slots_container.get_children():
		child.queue_free()

	var mack_slots = [
		{"id": "neural_core", "name": "Neural Processor", "icon": "🧠"},
		{"id": "ocular_scope", "name": "Ocular Optics", "icon": "👁️"},
		{"id": "primary_weapon", "name": "Primary Arm Cannon", "icon": "🔫"},
		{"id": "secondary_weapon", "name": "Secondary Sidearm", "icon": "🎯"},
		{"id": "subdermal_armor", "name": "Sub-Dermal Plating", "icon": "🛡️"}
	]

	for slot_info in mack_slots:
		var slot_card = _build_slot_card("MACK", slot_info["id"], slot_info["name"], slot_info["icon"], mgr)
		mack_slots_container.add_child(slot_card)

	# Refresh Vehicle Slots
	for child in vehicle_slots_container.get_children():
		child.queue_free()

	var vehicle_slots = [
		{"id": "roof_turret", "name": "Roof Turret Hardpoint", "icon": "🚀"},
		{"id": "armor_chassis", "name": "Chassis Plating", "icon": "🚗"},
		{"id": "nitro_boost", "name": "Nitro Booster Module", "icon": "⚡"},
		{"id": "ecm_scrambler", "name": "ECM Countermeasures", "icon": "📡"}
	]

	for slot_info in vehicle_slots:
		var slot_card = _build_slot_card("VEHICLE", slot_info["id"], slot_info["name"], slot_info["icon"], mgr)
		vehicle_slots_container.add_child(slot_card)

func _build_slot_card(grid_target: String, slot_id: String, slot_name: String, fallback_icon: String, mgr: LoadoutGridManager) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.12, 0.8)
	style.border_width_left = 2
	style.border_color = Color(0.0, 1.0, 0.85) if grid_target == "MACK" else Color(1.0, 0.4, 0.0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	card.add_child(hbox)

	var equipped_item = mgr.get_equipped_item(grid_target, slot_id)
	var item_name: String = equipped_item.get("name", "EMPTY SLOT")
	var item_icon: String = equipped_item.get("icon", fallback_icon)
	var tier: int = equipped_item.get("tier", 1)

	var lbl = Label.new()
	lbl.text = "%s [%s]\n%s (T%d)" % [item_icon, slot_name, item_name, tier]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn_swap = Button.new()
	btn_swap.text = "⚙️ SWAP"
	btn_swap.pressed.connect(func(): _open_item_picker_for_slot(grid_target, slot_id, slot_name))
	hbox.add_child(btn_swap)

	return card

func _open_item_picker_for_slot(grid_target: String, slot_id: String, slot_name: String) -> void:
	selected_grid_target = grid_target
	selected_slot_target = slot_id

	item_picker_title.text = "📦 AVAILABLE ITEMS FOR: %s (%s)" % [slot_name.to_upper(), grid_target]

	for child in item_picker_container.get_children():
		child.queue_free()

	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	var items = mgr.get_items_for_slot(slot_id)
	for item in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(210, 60)
		btn.text = "%s %s\nTier %d | %s" % [item.get("icon", "🔹"), item.get("name", ""), item.get("tier", 1), item.get("description", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func():
			mgr.equip_item(grid_target, slot_id, item["id"])
			_refresh_all_slots()
			_refresh_stats()
		)
		item_picker_container.add_child(btn)

func _refresh_stats() -> void:
	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	var dps = mgr.calculate_total_dps()
	var shield = mgr.calculate_total_shielding()
	var heat = mgr.calculate_total_glitch_heat()

	stats_summary_label.text = "[b]COMBAT STATS[/b]\n\n"
	stats_summary_label.text += "⚔️ [color=#00ffcc]Total DPS:[/color] [b]%.1f[/b]\n" % dps
	stats_summary_label.text += "🛡️ [color=#ffbb00]Hull Shielding:[/color] [b]%.1f[/b]\n" % shield
	stats_summary_label.text += "🧠 [color=#ff0055]Glitch Baseline:[/color] [b]+%.1f%%[/b]\n\n" % heat
	stats_summary_label.text += "[color=#aaaaaa]Tuned at The Pit Garage[/color]"

func _on_simulate_pressed() -> void:
	close_loadout_ui()
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_mgr) and campaign_mgr.has_method("start_simulated_mission"):
		campaign_mgr.start_simulated_mission(active_mission_to_simulate, 0)

