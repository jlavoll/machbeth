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
var banquo_slots_container: VBoxContainer = null
var stats_summary_label: RichTextLabel = null
var item_picker_container: HBoxContainer = null
var item_picker_panel: PanelContainer = null
var item_picker_title: Label = null

var selected_grid_target: String = ""
var selected_slot_target: String = ""

# Fonts
var geist_font: Font = preload("res://fonts/GeistPixel-Regular-VariableFont_ELSH.ttf")
var sharetech_font: Font = preload("res://fonts/ShareTechMono-Regular.ttf")
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
	dim.color = Color(0.01, 0.02, 0.03, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	# Main Margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	root_control.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 1. Header Bar
	var header_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "TACTICAL LOADOUT GRID // HARDPOINTS & CYBERWARE"
	title.add_theme_font_override("font", geist_font)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	header_hbox.add_child(title)

	header_hbox.add_spacer(false)

	var btn_close = Button.new()
	btn_close.text = "CLOSE [ESC]"
	btn_close.add_theme_font_override("font", geist_font)
	btn_close.add_theme_font_size_override("font_size", 10)
	btn_close.pressed.connect(close_loadout_ui)
	header_hbox.add_child(btn_close)
	main_vbox.add_child(header_hbox)

	# 2. Main Grid Columns (Mack 5 Slots | Vehicle 4 Slots | Live Telemetry & Simulation)
	var grid_columns = HBoxContainer.new()
	grid_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_columns.add_theme_constant_override("separation", 14)
	main_vbox.add_child(grid_columns)

	# COLUMN 1: Mack's Cyborg Grid
	var mack_panel = PanelContainer.new()
	mack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mack_panel.size_flags_stretch_ratio = 1.0
	var mack_style = StyleBoxFlat.new()
	mack_style.bg_color = Color(0.02, 0.05, 0.07, 0.92)
	mack_style.border_width_left = 2
	mack_style.border_color = Color(0.0, 1.0, 0.85)
	mack_style.content_margin_left = 12
	mack_style.content_margin_right = 12
	mack_style.content_margin_top = 8
	mack_style.content_margin_bottom = 8
	mack_panel.add_theme_stylebox_override("panel", mack_style)
	grid_columns.add_child(mack_panel)

	var mack_inner = VBoxContainer.new()
	mack_inner.add_theme_constant_override("separation", 8)
	mack_panel.add_child(mack_inner)

	var mack_header_hbox = HBoxContainer.new()
	var mack_title = Label.new()
	mack_title.name = "MackTitleLabel"
	mack_title.text = "MACK CYBORG [5 SLOTS]"
	mack_title.add_theme_font_override("font", geist_font)
	mack_title.add_theme_font_size_override("font_size", 13)
	mack_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	mack_header_hbox.add_child(mack_title)
	mack_inner.add_child(mack_header_hbox)

	# --- 2D Vector Cybernetic Anatomy Blueprint Canvas ---
	var mack_blueprint_canvas = Control.new()
	mack_blueprint_canvas.name = "MackCyborgBlueprintCanvas"
	mack_blueprint_canvas.custom_minimum_size = Vector2(0, 140)
	mack_blueprint_canvas.draw.connect(func():
		var rect = mack_blueprint_canvas.get_rect()
		var center = Vector2(rect.size.x * 0.5, rect.size.y * 0.52)
		var cyan_wire = Color(0.0, 1.0, 0.85, 0.85)
		var cyan_fill = Color(0.0, 1.0, 0.85, 0.08)
		var grid_col = Color(0.0, 0.4, 0.5, 0.18)
		var gold_dot = Color(1.0, 0.85, 0.0, 0.95)

		# Holographic background grid
		for gx in range(0, int(rect.size.x), 24):
			mack_blueprint_canvas.draw_line(Vector2(gx, 0), Vector2(gx, rect.size.y), grid_col, 1.0)
		for gy in range(0, int(rect.size.y), 24):
			mack_blueprint_canvas.draw_line(Vector2(0, gy), Vector2(rect.size.x, gy), grid_col, 1.0)

		# Cybernetic Head Silhouette
		mack_blueprint_canvas.draw_arc(center + Vector2(0, -42), 16.0, 0, TAU, 16, cyan_wire, 1.8)
		# Ocular Optic Target reticle
		mack_blueprint_canvas.draw_line(center + Vector2(4, -44), center + Vector2(22, -44), Color(1.0, 0.2, 0.3, 0.9), 1.8)
		mack_blueprint_canvas.draw_circle(center + Vector2(5, -44), 3.0, Color(1.0, 0.2, 0.3, 1.0))

		# Heavy Cybernetic Torso & Shoulder Rig
		var torso_points = PackedVector2Array([
			center + Vector2(-26, -22),
			center + Vector2(26, -22),
			center + Vector2(18, 24),
			center + Vector2(-18, 24)
		])
		mack_blueprint_canvas.draw_colored_polygon(torso_points, cyan_fill)
		mack_blueprint_canvas.draw_polyline(torso_points, cyan_wire, 1.8, true)

		# Neural Core chest reactor
		mack_blueprint_canvas.draw_arc(center + Vector2(0, -6), 9.0, 0, TAU, 14, Color(1.0, 0.85, 0.0, 0.95), 1.8)

		# Arm Hardpoints (Kinetic Gatling mount right, Sidearm holster left)
		mack_blueprint_canvas.draw_line(center + Vector2(-26, -18), center + Vector2(-46, 16), cyan_wire, 2.2)
		mack_blueprint_canvas.draw_line(center + Vector2(26, -18), center + Vector2(48, 20), Color(1.0, 0.3, 0.4, 0.9), 2.8)

		# Socket Anchor Dots
		mack_blueprint_canvas.draw_circle(center + Vector2(0, -6), 3.5, gold_dot)
		mack_blueprint_canvas.draw_circle(center + Vector2(0, -42), 3.5, gold_dot)
		mack_blueprint_canvas.draw_circle(center + Vector2(48, 20), 3.5, gold_dot)
		mack_blueprint_canvas.draw_circle(center + Vector2(-12, 10), 3.5, gold_dot)
	)
	mack_inner.add_child(mack_blueprint_canvas)

	mack_slots_container = VBoxContainer.new()
	mack_slots_container.add_theme_constant_override("separation", 5)
	mack_inner.add_child(mack_slots_container)

	# Mack Real-time Threat Card underneath his slots
	var mack_threat_panel = PanelContainer.new()
	mack_threat_panel.name = "MackThreatPanel"
	var t_style = StyleBoxFlat.new()
	t_style.bg_color = Color(0.01, 0.03, 0.05, 0.95)
	t_style.border_width_top = 1
	t_style.border_color = Color(0.0, 1.0, 0.85)
	t_style.content_margin_left = 8
	t_style.content_margin_right = 8
	t_style.content_margin_top = 6
	t_style.content_margin_bottom = 6
	mack_threat_panel.add_theme_stylebox_override("panel", t_style)
	mack_inner.add_child(mack_threat_panel)

	var mack_threat_lbl = RichTextLabel.new()
	mack_threat_lbl.name = "MackThreatLabel"
	mack_threat_lbl.bbcode_enabled = true
	mack_threat_lbl.fit_content = true
	mack_threat_lbl.custom_minimum_size = Vector2(0, 42)
	mack_threat_lbl.add_theme_font_override("normal_font", geist_font)
	mack_threat_lbl.add_theme_font_size_override("normal_font_size", 10)
	mack_threat_panel.add_child(mack_threat_lbl)

	# COLUMN 2: Vehicle Hardpoints & Interactive Chassis Blueprint Schematic
	var vehicle_panel = PanelContainer.new()
	vehicle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_panel.size_flags_stretch_ratio = 1.3
	var vehicle_style = StyleBoxFlat.new()
	vehicle_style.bg_color = Color(0.04, 0.02, 0.01, 0.94)
	vehicle_style.border_width_left = 2
	vehicle_style.border_color = Color(1.0, 0.45, 0.0)
	vehicle_style.content_margin_left = 12
	vehicle_style.content_margin_right = 12
	vehicle_style.content_margin_top = 8
	vehicle_style.content_margin_bottom = 8
	vehicle_panel.add_theme_stylebox_override("panel", vehicle_style)
	grid_columns.add_child(vehicle_panel)

	var vehicle_inner = VBoxContainer.new()
	vehicle_inner.add_theme_constant_override("separation", 8)
	vehicle_panel.add_child(vehicle_inner)

	var vehicle_title = Label.new()
	vehicle_title.name = "VehicleTitleLabel"
	vehicle_title.text = "WAR-RIG CHASSIS BLUEPRINT [4 SLOTS]"
	vehicle_title.add_theme_font_override("font", geist_font)
	vehicle_title.add_theme_font_size_override("font_size", 13)
	vehicle_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	vehicle_inner.add_child(vehicle_title)

	# --- 2D Vector Wireframe Blueprint Canvas ---
	var blueprint_canvas = Control.new()
	blueprint_canvas.name = "ChassisBlueprintCanvas"
	blueprint_canvas.custom_minimum_size = Vector2(0, 140)
	blueprint_canvas.draw.connect(func():
		var rect = blueprint_canvas.get_rect()
		var center = Vector2(rect.size.x * 0.5, rect.size.y * 0.52)
		var orange_wire = Color(1.0, 0.45, 0.0, 0.85)
		var orange_fill = Color(1.0, 0.35, 0.0, 0.09)
		var cyan_grid = Color(0.0, 1.0, 0.85, 0.15)
		var gold_dot = Color(1.0, 0.85, 0.0, 0.95)

		# 1. Holographic Tech Grid Lines
		for gx in range(0, int(rect.size.x), 24):
			blueprint_canvas.draw_line(Vector2(gx, 0), Vector2(gx, rect.size.y), cyan_grid, 1.0)
		for gy in range(0, int(rect.size.y), 24):
			blueprint_canvas.draw_line(Vector2(0, gy), Vector2(rect.size.x, gy), cyan_grid, 1.0)

		# 2. Heavy War-Rig Top-Down Tactical Chassis Silhouette
		var hull_points = PackedVector2Array([
			center + Vector2(-75, -28), # Front Bumper Left
			center + Vector2(75, -28),  # Front Bumper Right
			center + Vector2(92, -8),   # Front Right Fender
			center + Vector2(92, 26),   # Rear Right Tire Well
			center + Vector2(68, 42),   # Rear Right Exhaust
			center + Vector2(-68, 42),  # Rear Left Exhaust
			center + Vector2(-92, 26),  # Rear Left Tire Well
			center + Vector2(-92, -8)   # Front Left Fender
		])
		blueprint_canvas.draw_colored_polygon(hull_points, orange_fill)
		blueprint_canvas.draw_polyline(hull_points, orange_wire, 1.8, true)

		# 3. Armored Cabin & Windshield
		var cabin_points = PackedVector2Array([
			center + Vector2(-44, -12),
			center + Vector2(44, -12),
			center + Vector2(52, 20),
			center + Vector2(-52, 20)
		])
		blueprint_canvas.draw_polyline(cabin_points, Color(0.0, 1.0, 0.85, 0.7), 1.4, true)

		# 4. Roof Turret Ring Hardpoint
		blueprint_canvas.draw_arc(center + Vector2(0, 4), 12.0, 0, TAU, 16, Color(1.0, 0.2, 0.3, 0.95), 1.8)
		blueprint_canvas.draw_line(center + Vector2(-12, 4), center + Vector2(12, 4), Color(1.0, 0.2, 0.3, 0.85), 1.2)

		# 5. Dual Heavy Exhaust Nitro Stacks
		blueprint_canvas.draw_rect(Rect2(center.x - 60, center.y + 32, 15, 10), Color(0.0, 1.0, 0.85, 0.75), false, 1.2)
		blueprint_canvas.draw_rect(Rect2(center.x + 45, center.y + 32, 15, 10), Color(0.0, 1.0, 0.85, 0.75), false, 1.2)

		# 6. Spatial Hardpoint Target Anchor Dots
		# [Roof Turret] -> Center Top
		blueprint_canvas.draw_circle(center + Vector2(0, 4), 3.5, gold_dot)
		# [Armor Chassis] -> Left Fender
		blueprint_canvas.draw_circle(center + Vector2(-84, 8), 3.5, gold_dot)
		# [Nitro Boost] -> Rear Exhaust
		blueprint_canvas.draw_circle(center + Vector2(0, 38), 3.5, gold_dot)
		# [ECM Scrambler] -> Right Cabin
		blueprint_canvas.draw_circle(center + Vector2(50, -5), 3.5, gold_dot)
	)
	vehicle_inner.add_child(blueprint_canvas)

	vehicle_slots_container = VBoxContainer.new()
	vehicle_slots_container.add_theme_constant_override("separation", 5)
	vehicle_inner.add_child(vehicle_slots_container)

	# COLUMN 3: Live Combat Telemetry & Simulation
	var center_panel = PanelContainer.new()
	center_panel.custom_minimum_size.x = 240
	center_panel.size_flags_stretch_ratio = 0.9
	var center_style = StyleBoxFlat.new()
	center_style.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	center_style.border_width_left = 2
	center_style.border_color = Color(1.0, 0.85, 0.0)
	center_style.content_margin_left = 12
	center_style.content_margin_right = 12
	center_style.content_margin_top = 8
	center_style.content_margin_bottom = 8
	center_panel.add_theme_stylebox_override("panel", center_style)
	grid_columns.add_child(center_panel)

	var center_inner = VBoxContainer.new()
	center_inner.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_inner)

	var stats_header = Label.new()
	stats_header.text = "LIVE TELEMETRY"
	stats_header.add_theme_font_override("font", geist_font)
	stats_header.add_theme_font_size_override("font_size", 13)
	stats_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	center_inner.add_child(stats_header)

	stats_summary_label = RichTextLabel.new()
	stats_summary_label.bbcode_enabled = true
	stats_summary_label.add_theme_font_override("normal_font", geist_font)
	stats_summary_label.add_theme_font_size_override("normal_font_size", 11)
	stats_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_inner.add_child(stats_summary_label)

	var sim_btn = Button.new()
	sim_btn.text = "[SIMULATE BATTLE]"
	sim_btn.add_theme_font_override("font", geist_font)
	sim_btn.add_theme_font_size_override("font_size", 11)
	sim_btn.add_theme_color_override("font_color", Color(1.0, 0.25, 0.4))
	sim_btn.pressed.connect(_on_simulate_pressed)
	center_inner.add_child(sim_btn)

	# 3. Item Swap Palette (Bottom Picker)
	item_picker_panel = PanelContainer.new()
	item_picker_panel.custom_minimum_size.y = 110
	var pick_style = StyleBoxFlat.new()
	pick_style.bg_color = Color(0.02, 0.03, 0.04, 0.95)
	pick_style.border_width_top = 1
	pick_style.border_color = Color(0.0, 1.0, 0.85)
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
	item_picker_title.text = "SELECT A SLOT ABOVE TO SWAP / EQUIP"
	item_picker_title.add_theme_font_override("font", geist_font)
	item_picker_title.add_theme_font_size_override("font_size", 11)
	item_picker_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	pick_vbox.add_child(item_picker_title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pick_vbox.add_child(scroll)

	item_picker_container = HBoxContainer.new()
	item_picker_container.add_theme_constant_override("separation", 8)
	scroll.add_child(item_picker_container)

func _refresh_all_slots() -> void:
	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	# Refresh Mack Slots
	for child in mack_slots_container.get_children():
		child.queue_free()

	var mack_slots = [
		{"id": "neural_core", "name": "Neural Processor"},
		{"id": "ocular_scope", "name": "Ocular Optics"},
		{"id": "primary_weapon", "name": "Primary Cannon"},
		{"id": "secondary_weapon", "name": "Secondary Sidearm"},
		{"id": "subdermal_armor", "name": "Sub-Dermal Armor"}
	]

	var mack_occupied: int = 0
	for slot_info in mack_slots:
		var slot_card = _build_slot_card("MACK", slot_info["id"], slot_info["name"], mgr)
		mack_slots_container.add_child(slot_card)
		if not mgr.get_equipped_item("MACK", slot_info["id"]).is_empty():
			mack_occupied += 1

	var mack_lbl = root_control.find_child("MackTitleLabel", true, false) as Label
	if is_instance_valid(mack_lbl):
		mack_lbl.text = "MACK CYBORG [%d/5 SLOTS | %d FREE]" % [mack_occupied, 5 - mack_occupied]

	# Refresh Vehicle Slots
	for child in vehicle_slots_container.get_children():
		child.queue_free()

	var vehicle_slots = [
		{"id": "roof_turret", "name": "Roof Turret"},
		{"id": "armor_chassis", "name": "Chassis Armor"},
		{"id": "nitro_boost", "name": "Nitro Module"},
		{"id": "ecm_scrambler", "name": "ECM Countermeasures"}
	]

	var vehicle_occupied: int = 0
	for slot_info in vehicle_slots:
		var slot_card = _build_slot_card("VEHICLE", slot_info["id"], slot_info["name"], mgr)
		vehicle_slots_container.add_child(slot_card)
		if not mgr.get_equipped_item("VEHICLE", slot_info["id"]).is_empty():
			vehicle_occupied += 1

	var vehicle_lbl = root_control.find_child("VehicleTitleLabel", true, false) as Label
	if is_instance_valid(vehicle_lbl):
		vehicle_lbl.text = "WAR-RIG CHASSIS [%d/4 SLOTS | %d FREE]" % [vehicle_occupied, 4 - vehicle_occupied]

func _build_slot_card(grid_target: String, slot_id: String, slot_name: String, mgr: LoadoutGridManager) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.88)
	style.border_width_left = 2
	var b_col = Color(0.0, 1.0, 0.85) if grid_target == "MACK" else Color(1.0, 0.45, 0.0)
	style.border_color = b_col
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	card.add_child(hbox)

	var equipped_item = mgr.get_equipped_item(grid_target, slot_id)
	var is_empty: bool = equipped_item.is_empty()
	var item_name: String = equipped_item.get("name", "FREE / EMPTY")
	var tier: int = equipped_item.get("tier", 0)

	var lbl = Label.new()
	if is_empty:
		lbl.text = "[%s]\n// FREE SLOT //" % [slot_name]
		lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	else:
		lbl.text = "[%s]\n%s (T%d)" % [slot_name, item_name, tier]
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	lbl.add_theme_font_override("font", geist_font)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn_swap = Button.new()
	btn_swap.text = "EQUIP" if is_empty else "SWAP"
	btn_swap.add_theme_font_override("font", geist_font)
	btn_swap.add_theme_font_size_override("font_size", 9)
	btn_swap.pressed.connect(func(): _open_item_picker_for_slot(grid_target, slot_id, slot_name))
	hbox.add_child(btn_swap)

	return card

func _open_item_picker_for_slot(grid_target: String, slot_id: String, slot_name: String) -> void:
	selected_grid_target = grid_target
	selected_slot_target = slot_id

	item_picker_title.text = "AVAILABLE ITEMS // %s [%s]" % [slot_name.to_upper(), grid_target]

	for child in item_picker_container.get_children():
		child.queue_free()

	var mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
	if not is_instance_valid(mgr):
		return

	# Option to UNEQUIP / Clear Slot
	var unequip_btn = Button.new()
	unequip_btn.custom_minimum_size = Vector2(120, 48)
	unequip_btn.text = "[UNEQUIP]\nClear Slot"
	unequip_btn.add_theme_font_override("font", geist_font)
	unequip_btn.add_theme_font_size_override("font_size", 8)
	unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	unequip_btn.pressed.connect(func():
		mgr.equip_item(grid_target, slot_id, "EMPTY")
		_refresh_all_slots()
		_refresh_stats()
	)
	item_picker_container.add_child(unequip_btn)

	var items = mgr.get_items_for_slot(slot_id)
	for item in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 48)
		btn.text = "%s [T%d]\n%s" % [item.get("name", ""), item.get("tier", 1), item.get("description", "")]
		btn.add_theme_font_override("font", geist_font)
		btn.add_theme_font_size_override("font_size", 8)
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
	var threat_data = mgr.calculate_mack_power_threat()

	# Update Realtime Power Threat Panel underneath Mack
	var threat_lbl = root_control.find_child("MackThreatLabel", true, false) as RichTextLabel
	if is_instance_valid(threat_lbl):
		threat_lbl.text = "[color=#aaaaaa]POWER THREAT:[/color] [color=%s][b]%d[/b][/color]  [color=#ffffff][%s][/color]\n[color=#888888]Allocated: %d/9 Slots  |  Free: %d[/color]" % [
			threat_data["color"],
			threat_data["rating"],
			threat_data["class"],
			threat_data["equipped_count"],
			threat_data["free_slots"]
		]

	stats_summary_label.text = "[color=#ffffff][b]WAR-RIG TELEMETRY[/b][/color]\n\n"
	stats_summary_label.text += "⚔️ [color=#00ffcc]Total DPS Output:[/color] [b]%.1f[/b]\n" % dps
	stats_summary_label.text += "🛡️ [color=#ffbb00]Hull Shielding:[/color] [b]%.1f[/b]\n" % shield
	stats_summary_label.text += "🧠 [color=#ff0055]Glitch Heat Baseline:[/color] [b]+%.1f%%[/b]\n" % heat
	stats_summary_label.text += "⚡ [color=#ffffff]Power Threat Index:[/color] [color=%s][b]%d[/b][/color] [%s]\n\n" % [threat_data["color"], threat_data["rating"], threat_data["class"]]
	stats_summary_label.text += "[color=#888888]Tuned in Porter's Pit subterranean garage hub for highway grand battles.[/color]"

func _on_simulate_pressed() -> void:
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	# Start the simulation FIRST (CampaignManager is PROCESS_MODE_ALWAYS so it runs even while paused)
	if is_instance_valid(campaign_mgr) and campaign_mgr.has_method("start_simulated_mission"):
		campaign_mgr.start_simulated_mission(active_mission_to_simulate, 0)
	# Then close the UI (unpauses the tree)
	close_loadout_ui()
