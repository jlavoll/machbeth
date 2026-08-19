extends Node
class_name GarageManager

# ==============================================================================
# GARAGE & VEHICLE FLEET MANAGER (GarageManager.gd)
# ==============================================================================
# Manages vehicle stats, upgrades, and garage interaction at "The Pit".
# Fleet:
#   - BANQUO_CAR: "SPECTRE INTERCEPTOR" (Focus: Speed, Agility, EMP)
#   - MACK_RIG:   "WAR-RIG EXECUTOR"    (Focus: Hull Armor, Ordnance, Gatling Damage)

signal vehicle_upgraded(vehicle_id: String, upgrade_slot: String, new_level: int)
signal garage_ui_toggled(is_open: bool)

enum VehicleID { BANQUO_CAR, MACK_RIG }
var active_fleet_selection: VehicleID = VehicleID.BANQUO_CAR

# Vehicle Fleet Data Structure
var fleet: Dictionary = {
	"BANQUO_CAR": {
		"name": "BANQUO'S SPECTRE INTERCEPTOR",
		"tagline": "Agile pursuit chassis tailored for tactical intercepts & fast recovery.",
		"color_theme": Color(0.0, 0.85, 1.0), # Cyan
		"stats": {
			"top_speed": 28.0,      # meters/sec
			"acceleration": 35.0,
			"hull_integrity": 100.0,
			"atb_speed_mult": 1.0,
			"gatling_damage": 12.0
		},
		"upgrades": {
			"engine": {"level": 1, "max_level": 3, "base_cost": 250, "cost_mult": 1.8},
			"armor":  {"level": 1, "max_level": 3, "base_cost": 200, "cost_mult": 1.5},
			"ordnance": {"level": 1, "max_level": 3, "base_cost": 300, "cost_mult": 2.0},
			"telemetry": {"level": 0, "max_level": 3, "base_cost": 400, "cost_mult": 1.875} # L1: Vitals, L2: Math Matrix, L3: Drone Uplink
		}
	},
	"MACK_RIG": {
		"name": "MACK'S WAR-RIG EXECUTOR",
		"tagline": "Heavy armor corporate dreadnought built for grand highway assaults.",
		"color_theme": Color(1.0, 0.35, 0.0), # Rust Orange
		"stats": {
			"top_speed": 22.0,
			"acceleration": 24.0,
			"hull_integrity": 250.0,
			"atb_speed_mult": 0.8,
			"gatling_damage": 25.0
		},
		"upgrades": {
			"engine": {"level": 1, "max_level": 3, "base_cost": 300, "cost_mult": 1.8},
			"armor":  {"level": 1, "max_level": 3, "base_cost": 350, "cost_mult": 1.6},
			"ordnance": {"level": 1, "max_level": 3, "base_cost": 450, "cost_mult": 2.2}
		}
	}
}

# Preloaded Typography Hierarchy
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")
var sharetech_font: Font = preload("res://fonts/ShareTechMono-Regular.ttf")
var ubuntu_font: Font = preload("res://fonts/Ubuntu/Ubuntu-Regular.ttf")

# UI Nodes
var garage_hud_layer: CanvasLayer = null
var _garage_root_control: Control = null
var is_garage_open: bool = false

# Component References
@onready var quest_manager = $"../QuestManager"
@onready var player_car = $"../PlayerCar"

func _ready() -> void:
	_build_garage_ui()


func _input(event: InputEvent) -> void:
	if not is_garage_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close_garage_ui()
			get_viewport().set_input_as_handled()

# ==============================================================================
# PUBLIC API
# ==============================================================================

func open_garage_ui() -> void:
	if is_garage_open:
		return
	is_garage_open = true
	if is_instance_valid(_garage_root_control):
		_update_ui_contents()
		_garage_root_control.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	garage_ui_toggled.emit(true)

func close_garage_ui() -> void:
	if not is_garage_open:
		return
	is_garage_open = false
	if is_instance_valid(_garage_root_control):
		_garage_root_control.visible = false
	
	# Apply active vehicle stats to PlayerCar driving node if inside city
	_apply_active_vehicle_to_player()
	
	var indoor_mgr = get_parent().get_node_or_null("IndoorSystemManager")
	if not is_instance_valid(indoor_mgr) or not indoor_mgr.is_inside_building:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	garage_ui_toggled.emit(false)

func get_upgrade_cost(veh_key: String, slot: String) -> int:
	if not fleet.has(veh_key):
		return 99999
	var upg_data: Dictionary = fleet[veh_key]["upgrades"].get(slot, {})
	var lvl: int = upg_data.get("level", 1)
	var base_cost: int = upg_data.get("base_cost", 200)
	var mult: float = upg_data.get("cost_mult", 1.5)
	return int(base_cost * pow(mult, lvl - 1))

func purchase_upgrade(veh_key: String, slot: String) -> bool:
	if not fleet.has(veh_key):
		return false
	var veh_data: Dictionary = fleet[veh_key]
	var upg_data: Dictionary = veh_data["upgrades"].get(slot, {})
	var current_lvl: int = upg_data.get("level", 1)
	var max_lvl: int = upg_data.get("max_level", 3)
	
	if current_lvl >= max_lvl:
		print("[GARAGE MANAGER] Slot %s is already max level!" % slot)
		return false
	
	var cost: int = get_upgrade_cost(veh_key, slot)
	var current_credits: int = 0
	if is_instance_valid(quest_manager):
		current_credits = quest_manager.player_credits

	# Act-based upgrade tier gating
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	var allowed_max_tier: int = 3
	if is_instance_valid(campaign_mgr):
		var act_idx = campaign_mgr.current_act
		if act_idx == campaign_mgr.CampaignAct.ACT_1_DUNCAN_FALL:
			allowed_max_tier = 1
		elif act_idx == campaign_mgr.CampaignAct.ACT_2_BANQUO_INTERCEPT:
			allowed_max_tier = 2
		else:
			allowed_max_tier = 3

	if current_lvl >= allowed_max_tier:
		print("[GARAGE MANAGER] Tier locked by current Act story progression!")
		var comms = get_parent().get_node_or_null("NeuralCommsHUD")
		if is_instance_valid(comms) and comms.has_method("send_message"):
			comms.send_message("Porter: 'Hold your horses! I need military salvage from later corporate skirmishes before I can weld Tier %d components onto the chassis.'" % (current_lvl + 1), "PORTER // THE PIT GARAGE")
		return false
	
	if current_credits < cost:
		print("[GARAGE MANAGER] Not enough credits! Needed: %d, Has: %d" % [cost, current_credits])
		return false
	
	# Deduct credits
	quest_manager.player_credits -= cost
	
	# Upgrade level & apply stat boosts
	upg_data["level"] = current_lvl + 1
	_apply_stat_boosts(veh_key, slot, upg_data["level"])
	
	print("[GARAGE MANAGER] Upgraded %s [%s] to level %d for %d credits!" % [veh_key, slot, upg_data["level"], cost])
	
	_update_ui_contents()
	vehicle_upgraded.emit(veh_key, slot, upg_data["level"])
	return true

func repair_fleet_vehicle(veh_key: String, cost: int) -> bool:
	var current_credits: int = quest_manager.player_credits if is_instance_valid(quest_manager) else 0
	if current_credits < cost:
		return false
	if is_instance_valid(quest_manager):
		quest_manager.player_credits -= cost
	
	# Reset hull to max based on armor upgrade level
	if fleet.has(veh_key):
		var armor_lvl: int = fleet[veh_key]["upgrades"]["armor"]["level"]
		var base_hp: float = 100.0 if veh_key == "BANQUO_CAR" else 250.0
		fleet[veh_key]["stats"]["hull_integrity"] = base_hp + (armor_lvl - 1) * 40.0
	
	_update_ui_contents()
	return true

# ==============================================================================
# INTERNAL STAT & PLAYER APPLIER
# ==============================================================================

func _apply_stat_boosts(veh_key: String, slot: String, new_level: int) -> void:
	var stats: Dictionary = fleet[veh_key]["stats"]
	match slot:
		"engine":
			# Increases top speed, acceleration, and ATB fill speed
			stats["top_speed"] += 3.0
			stats["acceleration"] += 4.0
			stats["atb_speed_mult"] += 0.15
		"armor":
			# Increases hull HP
			stats["hull_integrity"] += 40.0
		"ordnance":
			# Increases gatling damage
			stats["gatling_damage"] += 5.0

func _apply_active_vehicle_to_player() -> void:
	if not is_instance_valid(player_car):
		return
	
	var veh_key: String = "BANQUO_CAR" if active_fleet_selection == VehicleID.BANQUO_CAR else "MACK_RIG"
	var veh_stats: Dictionary = fleet[veh_key]["stats"]
	
	player_car.max_speed = veh_stats.get("top_speed", 24.0)
	player_car.acceleration = veh_stats.get("acceleration", 30.0)
	print("[GARAGE MANAGER] Active vehicle applied to PlayerCar: ", veh_key, " Max Speed: ", player_car.max_speed)

# ==============================================================================
# PROCEDURAL GARAGE UI CREATION & REFRESH
# ==============================================================================

var _credits_label: Label
var _veh_name_label: Label
var _veh_tagline_label: Label
var _stat_speed_val: Label
var _stat_accel_val: Label
var _stat_hull_val: Label
var _stat_atb_val: Label
var _stat_dmg_val: Label

var _btn_banquo: Button
var _btn_mack: Button

var _btn_engine_upg: Button
var _btn_armor_upg: Button
var _btn_ordnance_upg: Button
var _btn_telemetry_upg: Button

var _lbl_engine_info: Label
var _lbl_armor_info: Label
var _lbl_ordnance_info: Label
var _lbl_telemetry_info: Label

func _build_garage_ui() -> void:
	garage_hud_layer = CanvasLayer.new()
	garage_hud_layer.name = "GarageHUDLayer"
	garage_hud_layer.layer = 25 # Above DialogueSystem (20)
	add_child(garage_hud_layer)

	_garage_root_control = Control.new()
	_garage_root_control.name = "GarageRootControl"
	_garage_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_garage_root_control.visible = false
	garage_hud_layer.add_child(_garage_root_control)

	# Semi-transparent dark rust background overlay
	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.02, 0.01, 0.01, 0.85)
	_garage_root_control.add_child(bg_dim)

	# Main Panel Frame (Center)
	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.anchor_left = 0.1
	main_panel.anchor_right = 0.9
	main_panel.anchor_top = 0.08
	main_panel.anchor_bottom = 0.92
	main_panel.offset_left = 0
	main_panel.offset_right = 0
	main_panel.offset_top = 0
	main_panel.offset_bottom = 0

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.02, 0.01, 0.95)
	frame_style.border_width_left = 3
	frame_style.border_width_right = 3
	frame_style.border_width_top = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = Color(1.0, 0.35, 0.0) # Pit Rust Orange
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	frame_style.content_margin_left = 20
	frame_style.content_margin_right = 20
	frame_style.content_margin_top = 16
	frame_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", frame_style)
	_garage_root_control.add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(main_vbox)

	# --- Header Bar ---
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "🔧 THE PIT // VEHICLE FLEET & GARAGE HUB"
	title_lbl.add_theme_font_override("font", orbitron_font)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	header_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	_credits_label = Label.new()
	_credits_label.text = "CREDITS: 0 C"
	_credits_label.add_theme_font_override("font", sharetech_font)
	_credits_label.add_theme_font_size_override("font_size", 18)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	header_hbox.add_child(_credits_label)

	var close_btn = Button.new()
	close_btn.text = " [X] CLOSE (ESC) "
	close_btn.add_theme_font_override("font", orbitron_font)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(close_garage_ui)
	header_hbox.add_child(close_btn)

	var divider1 = ColorRect.new()
	divider1.custom_minimum_size = Vector2(0, 2)
	divider1.color = Color(1.0, 0.35, 0.0, 0.5)
	main_vbox.add_child(divider1)

	# --- Vehicle Selector Tabs ---
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(tabs_hbox)

	_btn_banquo = Button.new()
	_btn_banquo.text = " 🏎️ BANQUO'S SPECTRE INTERCEPTOR "
	_btn_banquo.add_theme_font_override("font", orbitron_font)
	_btn_banquo.add_theme_font_size_override("font_size", 12)
	_btn_banquo.custom_minimum_size = Vector2(240, 40)
	_btn_banquo.pressed.connect(func(): _select_vehicle(VehicleID.BANQUO_CAR))
	tabs_hbox.add_child(_btn_banquo)

	_btn_mack = Button.new()
	_btn_mack.text = " 🚜 MACK'S WAR-RIG EXECUTOR "
	_btn_mack.add_theme_font_override("font", orbitron_font)
	_btn_mack.add_theme_font_size_override("font_size", 12)
	_btn_mack.custom_minimum_size = Vector2(240, 40)
	_btn_mack.pressed.connect(func(): _select_vehicle(VehicleID.MACK_RIG))
	tabs_hbox.add_child(_btn_mack)

	# --- Content Body Split (Left Specs, Right Upgrade Slots) ---
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(body_hbox)

	# Left Column: Vehicle Details & Performance Stats
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(340, 0)
	left_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(left_vbox)

	_veh_name_label = Label.new()
	_veh_name_label.text = "VEHICLE NAME"
	_veh_name_label.add_theme_font_override("font", orbitron_font)
	_veh_name_label.add_theme_font_size_override("font_size", 15)
	_veh_name_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	left_vbox.add_child(_veh_name_label)

	_veh_tagline_label = Label.new()
	_veh_tagline_label.text = "Vehicle description..."
	_veh_tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_veh_tagline_label.add_theme_font_override("font", ubuntu_font)
	_veh_tagline_label.add_theme_font_size_override("font_size", 12)
	_veh_tagline_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	left_vbox.add_child(_veh_tagline_label)

	var stats_panel = PanelContainer.new()
	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.02, 0.04, 0.06, 0.8)
	stats_style.content_margin_left = 12
	stats_style.content_margin_right = 12
	stats_style.content_margin_top = 10
	stats_style.content_margin_bottom = 10
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	left_vbox.add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	var stats_hdr = Label.new()
	stats_hdr.text = "PERFORMANCE TELEMETRY"
	stats_hdr.add_theme_font_override("font", orbitron_font)
	stats_hdr.add_theme_font_size_override("font_size", 12)
	stats_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	stats_vbox.add_child(stats_hdr)

	_stat_speed_val = _add_stat_row(stats_vbox, "Top Speed:", "28.0 m/s")
	_stat_accel_val = _add_stat_row(stats_vbox, "Acceleration:", "35.0 m/s²")
	_stat_hull_val  = _add_stat_row(stats_vbox, "Hull Armor HP:", "100.0 HP")
	_stat_atb_val   = _add_stat_row(stats_vbox, "ATB Fill Rate:", "1.00x")
	_stat_dmg_val   = _add_stat_row(stats_vbox, "Gatling Ordnance:", "12.0 DMG")

	# Right Column: Interactive Upgrade Slots
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	body_hbox.add_child(right_vbox)

	var upg_hdr = Label.new()
	upg_hdr.text = "AVAILABLE PIT GARAGE UPGRADES"
	upg_hdr.add_theme_font_override("font", orbitron_font)
	upg_hdr.add_theme_font_size_override("font_size", 13)
	upg_hdr.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	right_vbox.add_child(upg_hdr)

	# Slot 1: Engine Tuning
	_lbl_engine_info = Label.new()
	_btn_engine_upg = Button.new()
	_build_upgrade_card(right_vbox, "⚡ ENGINE TUNING", "Boosts Top Speed, Acceleration, and Combat ATB Charge Rate", _lbl_engine_info, _btn_engine_upg, func(): _on_upgrade_click("engine"))

	# Slot 2: Reinforced Armor
	_lbl_armor_info = Label.new()
	_btn_armor_upg = Button.new()
	_build_upgrade_card(right_vbox, "🛡️ REINFORCED GRAPHENE ARMOR", "Increases Max Hull Integrity & Damage Absorption", _lbl_armor_info, _btn_armor_upg, func(): _on_upgrade_click("armor"))

	# Slot 3: Ordnance Mounts
	_lbl_ordnance_info = Label.new()
	_btn_ordnance_upg = Button.new()
	_build_upgrade_card(right_vbox, "💣 HEAVY ORDNANCE MOUNTS", "Increases Gatling Gun Damage output in Cockpit ATB Combat", _lbl_ordnance_info, _btn_ordnance_upg, func(): _on_upgrade_click("ordnance"))

	# Slot 4: Telemetry & Support Computer (Banquo's Rig Only)
	_lbl_telemetry_info = Label.new()
	_btn_telemetry_upg = Button.new()
	_build_upgrade_card(right_vbox, "💻 TELEMETRY & SUPPORT COMPUTER", "Unlocks Vitals Feed (L1), Combat Math Matrix (L2), & Repair Drones (L3)", _lbl_telemetry_info, _btn_telemetry_upg, func(): _on_upgrade_click("telemetry"))

func _add_stat_row(parent: Control, label_text: String, default_val: String) -> Label:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", sharetech_font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	hbox.add_child(lbl)
	var val_lbl = Label.new()
	val_lbl.text = default_val
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", sharetech_font)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	hbox.add_child(val_lbl)
	return val_lbl

func _build_upgrade_card(parent: Control, slot_title: String, slot_desc: String, info_label: Label, upg_button: Button, on_click: Callable) -> void:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.03, 0.05, 0.08, 0.9)
	card_style.border_width_left = 2
	card_style.border_color = Color(0.0, 0.85, 1.0, 0.4)
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = slot_title
	title.add_theme_font_override("font", orbitron_font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = slot_desc
	desc.add_theme_font_override("font", ubuntu_font)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
	vbox.add_child(desc)

	info_label.text = "Level 1 / 3"
	info_label.add_theme_font_override("font", sharetech_font)
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(info_label)

	upg_button.text = " UPGRADE (250 C) "
	upg_button.add_theme_font_override("font", orbitron_font)
	upg_button.add_theme_font_size_override("font_size", 11)
	upg_button.custom_minimum_size = Vector2(170, 36)
	upg_button.pressed.connect(on_click)
	hbox.add_child(upg_button)


func _select_vehicle(veh_id: VehicleID) -> void:
	active_fleet_selection = veh_id
	_update_ui_contents()

func _on_upgrade_click(slot: String) -> void:
	var veh_key: String = "BANQUO_CAR" if active_fleet_selection == VehicleID.BANQUO_CAR else "MACK_RIG"
	purchase_upgrade(veh_key, slot)

func _update_ui_contents() -> void:
	if not is_instance_valid(_garage_root_control):
		return

	var current_credits: int = quest_manager.player_credits if is_instance_valid(quest_manager) else 0
	_credits_label.text = "CREDITS: %d C" % current_credits

	var veh_key: String = "BANQUO_CAR" if active_fleet_selection == VehicleID.BANQUO_CAR else "MACK_RIG"
	var veh_data: Dictionary = fleet[veh_key]
	var stats: Dictionary = veh_data["stats"]
	var upgs: Dictionary = veh_data["upgrades"]
	var theme_color: Color = veh_data["color_theme"]

	# Active Tab Highlight
	_btn_banquo.modulate = Color(1, 1, 1, 1) if active_fleet_selection == VehicleID.BANQUO_CAR else Color(0.6, 0.6, 0.6, 0.8)
	_btn_mack.modulate = Color(1, 1, 1, 1) if active_fleet_selection == VehicleID.MACK_RIG else Color(0.6, 0.6, 0.6, 0.8)

	_veh_name_label.text = veh_data["name"]
	_veh_name_label.add_theme_color_override("font_color", theme_color)
	_veh_tagline_label.text = veh_data["tagline"]

	_stat_speed_val.text = "%.1f m/s" % stats["top_speed"]
	_stat_accel_val.text = "%.1f m/s²" % stats["acceleration"]
	_stat_hull_val.text  = "%.1f HP" % stats["hull_integrity"]
	_stat_atb_val.text   = "%.2fx" % stats["atb_speed_mult"]
	_stat_dmg_val.text   = "%.1f DMG" % stats["gatling_damage"]

	# Update Upgrade Cards
	_update_slot_card("engine", upgs["engine"], _lbl_engine_info, _btn_engine_upg, current_credits, veh_key)
	_update_slot_card("armor", upgs["armor"], _lbl_armor_info, _btn_armor_upg, current_credits, veh_key)
	_update_slot_card("ordnance", upgs["ordnance"], _lbl_ordnance_info, _btn_ordnance_upg, current_credits, veh_key)
	if upgs.has("telemetry"):
		_lbl_telemetry_info.get_parent().get_parent().visible = true
		_update_slot_card("telemetry", upgs["telemetry"], _lbl_telemetry_info, _btn_telemetry_upg, current_credits, veh_key)
	else:
		_lbl_telemetry_info.get_parent().get_parent().visible = false

func _update_slot_card(slot_name: String, upg_dict: Dictionary, info_label: Label, button: Button, credits: int, veh_key: String) -> void:
	if not is_instance_valid(info_label) or not is_instance_valid(button):
		return

	var lvl: int = upg_dict["level"]
	var max_lvl: int = upg_dict["max_level"]
	info_label.text = "Level %d / %d" % [lvl, max_lvl]

	if lvl >= max_lvl:
		button.text = " MAX LEVEL "
		button.disabled = true
	else:
		var cost: int = get_upgrade_cost(veh_key, slot_name)
		button.text = " UPGRADE (%d C) " % cost
		button.disabled = credits < cost
