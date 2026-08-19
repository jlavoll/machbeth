extends CanvasLayer
class_name BanquoOperativeUI

# ==============================================================================
# BANQUO OPERATIVE EQUIPMENT TERMINAL (BanquoOperativeUI.gd)
# ==============================================================================
# Dedicated armory & tactical gear tuning interface for Banquo on-foot operative.
# Accessible in Banquo's private high-rise loft (Wardrobe & Gear Rack).

var is_open: bool = false

# References
var root_control: Control = null
var slots_container: VBoxContainer = null
var stats_summary_label: RichTextLabel = null
var item_picker_container: HBoxContainer = null
var item_picker_panel: PanelContainer = null
var item_picker_title: Label = null

var selected_slot_target: String = ""

# Fonts
var geist_font: Font = preload("res://fonts/GeistPixel-Regular-VariableFont_ELSH.ttf")
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close_banquo_ui()
			get_viewport().set_input_as_handled()

func open_banquo_ui() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	_refresh_all_slots()
	_refresh_stats()

func close_banquo_ui() -> void:
	is_open = false
	visible = false
	get_tree().paused = false

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "BanquoGearRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	root_control.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	# 1. Header Bar
	var header_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "BANQUO OPERATIVE ARMORY // PERSONAL LOADOUT & TACTICAL GEAR"
	title.add_theme_font_override("font", geist_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
	header_hbox.add_child(title)

	header_hbox.add_spacer(false)

	var btn_close = Button.new()
	btn_close.text = "CLOSE [ESC]"
	btn_close.add_theme_font_override("font", geist_font)
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.pressed.connect(close_banquo_ui)
	header_hbox.add_child(btn_close)
	main_vbox.add_child(header_hbox)

	# 2. Main 2-Column Layout (Schematic & Slots | Stats Telemetry)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content_hbox)

	# Column 1: Operative Schematic & Equipment Slots
	var gear_panel = PanelContainer.new()
	gear_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_panel.size_flags_stretch_ratio = 2.0
	var gear_style = StyleBoxFlat.new()
	gear_style.bg_color = Color(0.05, 0.02, 0.07, 0.92)
	gear_style.border_width_left = 2
	gear_style.border_color = Color(1.0, 0.0, 0.8)
	gear_style.content_margin_left = 14
	gear_style.content_margin_right = 14
	gear_style.content_margin_top = 10
	gear_style.content_margin_bottom = 10
	gear_panel.add_theme_stylebox_override("panel", gear_style)
	content_hbox.add_child(gear_panel)

	var gear_inner = VBoxContainer.new()
	gear_inner.add_theme_constant_override("separation", 10)
	gear_panel.add_child(gear_inner)

	var gear_title = Label.new()
	gear_title.name = "BanquoTitleLabel"
	gear_title.text = "OPERATIVE SILHOUETTE & HARDPOINTS [4 SLOTS]"
	gear_title.add_theme_font_override("font", geist_font)
	gear_title.add_theme_font_size_override("font_size", 13)
	gear_title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
	gear_inner.add_child(gear_title)

	# Vector Schematic Canvas for Banquo
	var blueprint_canvas = Control.new()
	blueprint_canvas.name = "BanquoBlueprintCanvas"
	blueprint_canvas.custom_minimum_size = Vector2(0, 160)
	blueprint_canvas.draw.connect(func():
		var rect = blueprint_canvas.get_rect()
		var center = Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
		var magenta_wire = Color(1.0, 0.0, 0.8, 0.85)
		var magenta_fill = Color(1.0, 0.0, 0.8, 0.08)
		var grid_col = Color(0.6, 0.0, 0.5, 0.15)
		var gold_dot = Color(1.0, 0.85, 0.0, 0.95)

		# Tech Grid Lines
		for gx in range(0, int(rect.size.x), 24):
			blueprint_canvas.draw_line(Vector2(gx, 0), Vector2(gx, rect.size.y), grid_col, 1.0)
		for gy in range(0, int(rect.size.y), 24):
			blueprint_canvas.draw_line(Vector2(0, gy), Vector2(rect.size.x, gy), grid_col, 1.0)

		# Head / Monocular
		blueprint_canvas.draw_arc(center + Vector2(0, -50), 16.0, 0, TAU, 16, magenta_wire, 2.0)
		blueprint_canvas.draw_line(center + Vector2(4, -52), center + Vector2(24, -52), Color(0.0, 1.0, 0.85, 0.9), 2.0)
		blueprint_canvas.draw_circle(center + Vector2(6, -52), 3.5, Color(0.0, 1.0, 0.85, 1.0))

		# Tactical Trenchcoat Torso
		var coat_points = PackedVector2Array([
			center + Vector2(-28, -30),
			center + Vector2(28, -30),
			center + Vector2(36, 40),
			center + Vector2(-36, 40)
		])
		blueprint_canvas.draw_colored_polygon(coat_points, magenta_fill)
		blueprint_canvas.draw_polyline(coat_points, magenta_wire, 2.0, true)

		# Vibroblade Melee Arm (Right Side)
		blueprint_canvas.draw_line(center + Vector2(28, -26), center + Vector2(56, 10), magenta_wire, 2.5)
		blueprint_canvas.draw_line(center + Vector2(56, 10), center + Vector2(66, -20), Color(1.0, 0.25, 0.4, 0.9), 3.0)

		# Cyberdeck Arm / Holster (Left Side)
		blueprint_canvas.draw_line(center + Vector2(-28, -26), center + Vector2(-54, 8), magenta_wire, 2.5)
		blueprint_canvas.draw_rect(Rect2(center.x - 66, center.y + 4, 18, 14), Color(0.0, 1.0, 0.85, 0.9), false, 1.5)

		# Socket Anchor Dots & Callout Lines
		# Monocular Optic (Head)
		blueprint_canvas.draw_circle(center + Vector2(6, -52), 3.5, gold_dot)
		# Tactical Trenchcoat (Chest)
		blueprint_canvas.draw_circle(center + Vector2(0, -6), 4.0, gold_dot)
		# Vibroblade (Right Hand)
		blueprint_canvas.draw_circle(center + Vector2(66, -20), 4.0, gold_dot)
		# Cyberdeck (Left Hip)
		blueprint_canvas.draw_circle(center + Vector2(-57, 11), 4.0, gold_dot)
	)
	gear_inner.add_child(blueprint_canvas)

	slots_container = VBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 6)
	gear_inner.add_child(slots_container)

	# Column 2: Stats Telemetry Card
	var stats_panel = PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_stretch_ratio = 1.0
	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	stats_style.border_width_left = 2
	stats_style.border_color = Color(1.0, 0.85, 0.0)
	stats_style.content_margin_left = 12
	stats_style.content_margin_right = 12
	stats_style.content_margin_top = 10
	stats_style.content_margin_bottom = 10
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	content_hbox.add_child(stats_panel)

	var stats_inner = VBoxContainer.new()
	stats_inner.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_inner)

	var stats_header = Label.new()
	stats_header.text = "OPERATIVE STATS"
	stats_header.add_theme_font_override("font", geist_font)
	stats_header.add_theme_font_size_override("font_size", 13)
	stats_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	stats_inner.add_child(stats_header)

	stats_summary_label = RichTextLabel.new()
	stats_summary_label.bbcode_enabled = true
	stats_summary_label.add_theme_font_override("normal_font", geist_font)
	stats_summary_label.add_theme_font_size_override("normal_font_size", 11)
	stats_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_inner.add_child(stats_summary_label)

	# 3. Item Swap Palette (Bottom Picker)
	item_picker_panel = PanelContainer.new()
	item_picker_panel.custom_minimum_size.y = 110
	var pick_style = StyleBoxFlat.new()
	pick_style.bg_color = Color(0.02, 0.03, 0.04, 0.95)
	pick_style.border_width_top = 1
	pick_style.border_color = Color(1.0, 0.0, 0.8)
	pick_style.content_margin_left = 12
	pick_style.content_margin_right = 12
	pick_style.content_margin_top = 8
	pick_style.content_margin_bottom = 8
	item_picker_panel.add_theme_stylebox_override("panel", pick_style)
	main_vbox.add_child(item_picker_panel)

	var pick_vbox = VBoxContainer.new()
	pick_vbox.add_theme_constant_override("separation", 6)
	item_picker_panel.add_child(pick_vbox)

	item_picker_title = Label.new()
	item_picker_title.text = "SELECT AN OPERATIVE SLOT ABOVE TO SWAP / EQUIP"
	item_picker_title.add_theme_font_override("font", geist_font)
	item_picker_title.add_theme_font_size_override("font_size", 11)
	item_picker_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.9))
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

	for child in slots_container.get_children():
		child.queue_free()

	var banquo_slots = [
		{"id": "banquo_outfit", "name": "Tactical Trenchcoat"},
		{"id": "banquo_melee", "name": "Melee Sidearm / Blade"},
		{"id": "banquo_deck", "name": "Cyberdeck Terminal"},
		{"id": "banquo_optics", "name": "Recon Monocular"}
	]

	var banquo_occupied: int = 0
	for slot_info in banquo_slots:
		var slot_card = _build_slot_card(slot_info["id"], slot_info["name"], mgr)
		slots_container.add_child(slot_card)
		if not mgr.get_equipped_item("BANQUO", slot_info["id"]).is_empty():
			banquo_occupied += 1

	var banquo_lbl = root_control.find_child("BanquoTitleLabel", true, false) as Label
	if is_instance_valid(banquo_lbl):
		banquo_lbl.text = "OPERATIVE SILHOUETTE & HARDPOINTS [%d/4 SLOTS | %d FREE]" % [banquo_occupied, 4 - banquo_occupied]

func _build_slot_card(slot_id: String, slot_name: String, mgr: LoadoutGridManager) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.85)
	style.border_width_left = 2
	style.border_color = Color(1.0, 0.0, 0.8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	card.add_child(hbox)

	var equipped_item = mgr.get_equipped_item("BANQUO", slot_id)
	var is_empty: bool = equipped_item.is_empty()
	var item_name: String = equipped_item.get("name", "FREE / EMPTY")
	var tier: int = equipped_item.get("tier", 0)

	var lbl = Label.new()
	if is_empty:
		lbl.text = "[%s]\n// FREE SLOT //" % [slot_name]
		lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	else:
		lbl.text = "[%s]\n%s (Tier %d)" % [slot_name, item_name, tier]
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	lbl.add_theme_font_override("font", geist_font)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn_swap = Button.new()
	btn_swap.text = "EQUIP" if is_empty else "SWAP"
	btn_swap.add_theme_font_override("font", geist_font)
	btn_swap.add_theme_font_size_override("font_size", 9)
	btn_swap.pressed.connect(func(): _open_item_picker_for_slot(slot_id, slot_name))
	hbox.add_child(btn_swap)

	return card

func _open_item_picker_for_slot(slot_id: String, slot_name: String) -> void:
	selected_slot_target = slot_id

	item_picker_title.text = "AVAILABLE OPERATIVE GEAR // %s" % [slot_name.to_upper()]

	for child in item_picker_container.get_children():
		child.queue_free()

	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	# Option to UNEQUIP / Clear Slot
	var unequip_btn = Button.new()
	unequip_btn.custom_minimum_size = Vector2(140, 52)
	unequip_btn.text = "[UNEQUIP]\nClear Slot"
	unequip_btn.add_theme_font_override("font", geist_font)
	unequip_btn.add_theme_font_size_override("font_size", 9)
	unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	unequip_btn.pressed.connect(func():
		mgr.equip_item("BANQUO", slot_id, "EMPTY")
		_refresh_all_slots()
		_refresh_stats()
	)
	item_picker_container.add_child(unequip_btn)

	var items = mgr.get_items_for_slot(slot_id)
	for item in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(210, 52)
		btn.text = "%s [T%d]\n%s" % [item.get("name", ""), item.get("tier", 1), item.get("description", "")]
		btn.add_theme_font_override("font", geist_font)
		btn.add_theme_font_size_override("font_size", 9)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func():
			mgr.equip_item("BANQUO", slot_id, item["id"])
			_refresh_all_slots()
			_refresh_stats()
		)
		item_picker_container.add_child(btn)

func _refresh_stats() -> void:
	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	var b_outfit = mgr.get_equipped_item("BANQUO", "banquo_outfit")
	var b_melee = mgr.get_equipped_item("BANQUO", "banquo_melee")
	var b_deck = mgr.get_equipped_item("BANQUO", "banquo_deck")
	var b_optics = mgr.get_equipped_item("BANQUO", "banquo_optics")

	var banquo_armor = b_outfit.get("shield_bonus", 0.0) + b_optics.get("shield_bonus", 0.0)
	var banquo_dps = b_melee.get("dps_bonus", 0.0) + b_deck.get("dps_bonus", 0.0)
	var banquo_hack = b_deck.get("hack_speed_bonus", 0.0) + b_optics.get("hack_speed_bonus", 0.0) + b_outfit.get("hack_speed_bonus", 0.0)

	stats_summary_label.text = "[b]BANQUO OPERATIVE TELEMETRY[/b]\n\n"
	stats_summary_label.text += "⚔️ [color=#ff00cc]Melee DPS Bonus:[/color] [b]+%.1f[/b]\n" % banquo_dps
	stats_summary_label.text += "🛡️ [color=#00ccff]Armor / Shielding:[/color] [b]+%.1f[/b]\n" % banquo_armor
	stats_summary_label.text += "⚡ [color=#aaff00]Infiltration / Hack Speed:[/color] [b]+%.1f%%[/b]\n\n" % banquo_hack
	stats_summary_label.text += "[color=#aaaaaa]// TUNED IN BANQUO'S HIGH-RISE LOFT ARMORY[/color]"
