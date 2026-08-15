extends CanvasLayer

# ==============================================================================
# UNIFIED BATTLEFIELD COMMAND CONSOLE (BattleTelemetryRadarUI.gd)
# ==============================================================================
# 'U' Key opens the single, edge-to-edge unified Battle Telemetry Screen.
# Houses all sub-systems as integrated slots:
#   [SLOT 1 - VECTOR RADAR]: 2D Vector Radar Map with floating damage popups & blip shakes
#   [SLOT 2 - MACK VITALS & REPAIR DRONE]: War-Rig HP, Engine RPM, Hull Core Temp, Repair Drone Dispatch
#   [SLOT 3 - ENEMY SCANNER]: Active Convoy Unit Roster, AC, Weaknesses, Threat Levels
#   [SLOT 4 - COMBAT MATH MATRIX]: Real-time d20 roll breakdown & armor absorption log
#
# Unpurchased Pit upgrade slots display "[ MODULE OFFLINE - PURCHASE AT THE PIT ]".

var is_telemetry_open: bool = false

# UI Root Container
var root_panel: PanelContainer = null
var title_label: Label = null
var battle_status_label: Label = null

# Sub-System Slot Panels
var radar_screen_rect: Control = null
var mack_hp_bar: ProgressBar = null
var side_vitals_label: Label = null
var drone_repair_btn: Button = null
var enemy_scanner_vbox: VBoxContainer = null
var math_log_text: RichTextLabel = null

# Upgrade Slot Lock Overlay Labels
var slot_vitals_offline_lbl: Label = null
var slot_math_offline_lbl: Label = null
var slot_drone_offline_lbl: Label = null

# Visual Animations
var active_damage_popups: Array[Dictionary] = []
var mack_shake_timer: float = 0.0
var active_enemy_shakes: Dictionary = {}

func _ready() -> void:
	layer = 120 # Standard overlay depth
	_build_unified_telemetry_console()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			_toggle_unified_console()

func _toggle_unified_console() -> void:
	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	
	var is_battle_active: bool = false
	if is_instance_valid(campaign_mgr):
		is_battle_active = campaign_mgr.is_battle_in_progress
		
	if not is_battle_active:
		if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
			neural_comms.send_message("📡 BATTLE CONSOLE STANDBY. Deploy Mack's War-Rig at The Pit War-Table to initialize live battlefield uplink.", "UPLINK STANDBY")
		return
		
	is_telemetry_open = not is_telemetry_open
	visible = is_telemetry_open
	_update_console_data()

func spawn_damage_popup(amount: int, is_mack_target: bool, target_enemy_index: int = 0) -> void:
	if is_mack_target:
		mack_shake_timer = 0.35
	else:
		active_enemy_shakes[target_enemy_index] = 0.35
		
	if not is_instance_valid(radar_screen_rect): return
	
	var r_size = radar_screen_rect.size
	if r_size.x <= 0 or r_size.y <= 0: r_size = Vector2(400, 360)
	var center = r_size / 2.0
	
	var start_pos: Vector2 = center
	var popup_color: Color = Color(1.0, 0.2, 0.3)
	
	if not is_mack_target:
		popup_color = Color(1.0, 0.85, 0.0)
		var max_r = min(r_size.x, r_size.y) * 0.42
		var angle_offset = (float(target_enemy_index) - 0.5) * 0.4 - (PI / 2.0)
		var dist = max_r * (0.45 + (target_enemy_index * 0.15))
		start_pos = center + Vector2(cos(angle_offset), sin(angle_offset)) * dist
		
	var dmg_lbl = Label.new()
	dmg_lbl.text = "-%d" % amount
	dmg_lbl.add_theme_color_override("font_color", popup_color)
	dmg_lbl.add_theme_font_size_override("font_size", 14)
	dmg_lbl.position = start_pos + Vector2(randf_range(-12, 12), randf_range(-15, -5))
	radar_screen_rect.add_child(dmg_lbl)
	
	active_damage_popups.append({
		"label": dmg_lbl,
		"pos": dmg_lbl.position,
		"vel": Vector2(randf_range(-20, 20), -45.0),
		"life": 1.4
	})

func _process(delta: float) -> void:
	if is_telemetry_open:
		var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
		if not is_instance_valid(campaign_mgr) or not campaign_mgr.is_battle_in_progress:
			is_telemetry_open = false
			visible = false
			return
		_update_console_data()
		
		# Animate shakes & damage popups
		if mack_shake_timer > 0.0:
			mack_shake_timer = max(0.0, mack_shake_timer - delta)
		for k in active_enemy_shakes.keys():
			active_enemy_shakes[k] = max(0.0, active_enemy_shakes[k] - delta)

		var i = active_damage_popups.size() - 1
		while i >= 0:
			var item = active_damage_popups[i]
			item["life"] -= delta
			item["pos"] += item["vel"] * delta
			var lbl = item["label"]
			if is_instance_valid(lbl):
				lbl.position = item["pos"]
				lbl.modulate.a = clamp(item["life"] / 1.2, 0.0, 1.0)
			if item["life"] <= 0.0:
				if is_instance_valid(lbl):
					lbl.queue_free()
				active_damage_popups.remove_at(i)
			i -= 1

# ==============================================================================
# UNIFIED FULLSCREEN LAYOUT BUILDER
# ==============================================================================

func _build_unified_telemetry_console() -> void:
	root_panel = PanelContainer.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.offset_left = 10
	root_panel.offset_top = 10
	root_panel.offset_right = -10
	root_panel.offset_bottom = -10
	add_child(root_panel)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.02, 0.04, 0.07, 0.96)
	style_box.border_color = Color(1.0, 0.35, 0.0, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(8)
	root_panel.add_theme_stylebox_override("panel", style_box)
	
	var compact_theme = Theme.new()
	compact_theme.default_font_size = 11
	root_panel.theme = compact_theme
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_panel.add_child(main_vbox)
	
	# Console Top Header
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	title_label = Label.new()
	title_label.text = "🖥️ UNIFIED BATTLEFIELD COMMAND CONSOLE [U]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	title_label.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(VSeparator.new())
	
	battle_status_label = Label.new()
	battle_status_label.text = "LIVE SATELLITE UPLINK ACTIVE"
	battle_status_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header_hbox.add_child(battle_status_label)
	
	var close_btn = Button.new()
	close_btn.text = "✖ CLOSE (U)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(func(): is_telemetry_open = false; visible = false)
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# 3-Column Master Layout Grid
	var grid_split = HBoxContainer.new()
	grid_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_split.add_theme_constant_override("separation", 8)
	main_vbox.add_child(grid_split)
	
	# --- COLUMN 1 (LEFT): SLOT 4 - COMBAT MATH MATRIX ---
	var col1_vbox = VBoxContainer.new()
	col1_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1_vbox.size_flags_stretch_ratio = 1.0
	grid_split.add_child(col1_vbox)
	
	var math_hdr = Label.new()
	math_hdr.text = "🎲 SLOT 4: COMBAT MATH MATRIX [TELEMETRY L2]"
	math_hdr.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	col1_vbox.add_child(math_hdr)
	
	var math_panel = PanelContainer.new()
	math_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(0.01, 0.03, 0.05, 0.95)
	m_style.border_color = Color(0.0, 1.0, 0.85, 0.4)
	m_style.set_border_width_all(1)
	m_style.set_content_margin_all(6)
	math_panel.add_theme_stylebox_override("panel", m_style)
	col1_vbox.add_child(math_panel)
	
	math_log_text = RichTextLabel.new()
	math_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	math_log_text.bbcode_enabled = true
	math_log_text.scroll_following = false # Top is always newest
	math_log_text.add_theme_font_size_override("normal_font_size", 9)
	math_panel.add_child(math_log_text)
	
	# --- COLUMN 2 (CENTER): SLOT 1 - VECTOR BATTLE RADAR ---
	var col2_vbox = VBoxContainer.new()
	col2_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_vbox.size_flags_stretch_ratio = 1.2
	grid_split.add_child(col2_vbox)
	
	var radar_hdr = Label.new()
	radar_hdr.text = "📡 SLOT 1: VECTOR BATTLE RADAR"
	radar_hdr.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	col2_vbox.add_child(radar_hdr)
	
	var radar_panel = PanelContainer.new()
	radar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0.01, 0.02, 0.04, 0.95)
	r_style.border_color = Color(0.0, 0.85, 1.0, 0.5)
	r_style.set_border_width_all(1)
	radar_panel.add_theme_stylebox_override("panel", r_style)
	col2_vbox.add_child(radar_panel)
	
	radar_screen_rect = Control.new()
	radar_screen_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_screen_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	radar_panel.add_child(radar_screen_rect)
	
	# --- COLUMN 3 (RIGHT): SLOT 2 (THREAT SCANNER) & SLOT 3 (MACK VITALS) SHARED COLUMN ---
	var col3_vbox = VBoxContainer.new()
	col3_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3_vbox.size_flags_stretch_ratio = 1.0
	col3_vbox.add_theme_constant_override("separation", 6)
	grid_split.add_child(col3_vbox)
	
	# Sub-Slot 3A: War-Rig Hull & Core Temp (Telemetry Upgrade L1)
	var vitals_hdr = Label.new()
	vitals_hdr.text = "🚜 SLOT 3: MACK WAR-RIG VITALS [TELEMETRY L1]"
	vitals_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	col3_vbox.add_child(vitals_hdr)
	
	var vitals_card = PanelContainer.new()
	var v_style = StyleBoxFlat.new()
	v_style.bg_color = Color(0.03, 0.05, 0.08, 0.9)
	v_style.border_color = Color(1.0, 0.85, 0.0, 0.5)
	v_style.set_border_width_all(1)
	v_style.set_content_margin_all(6)
	vitals_card.add_theme_stylebox_override("panel", v_style)
	col3_vbox.add_child(vitals_card)
	
	var vitals_vbox = VBoxContainer.new()
	vitals_card.add_child(vitals_vbox)
	
	mack_hp_bar = ProgressBar.new()
	mack_hp_bar.custom_minimum_size.y = 14
	vitals_vbox.add_child(mack_hp_bar)
	
	side_vitals_label = Label.new()
	side_vitals_label.text = "CORE TEMP: 75.0°C | ENGINE RPM: 4200"
	side_vitals_label.add_theme_font_size_override("font_size", 9)
	side_vitals_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vitals_vbox.add_child(side_vitals_label)
	
	# Drone Button (Telemetry L3)
	drone_repair_btn = Button.new()
	drone_repair_btn.text = "🛸 LAUNCH REPAIR DRONE (150 C) [L3]"
	drone_repair_btn.custom_minimum_size.y = 24
	drone_repair_btn.pressed.connect(_on_repair_drone_pressed)
	vitals_vbox.add_child(drone_repair_btn)
	
	col3_vbox.add_child(HSeparator.new())
	
	# Sub-Slot 2: Hostile Threat Scanner
	var enemy_hdr = Label.new()
	enemy_hdr.text = "🎯 SLOT 2: HOSTILE THREAT SCANNER"
	enemy_hdr.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))
	col3_vbox.add_child(enemy_hdr)
	
	var enemy_scroll = ScrollContainer.new()
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col3_vbox.add_child(enemy_scroll)
	
	enemy_scanner_vbox = VBoxContainer.new()
	enemy_scanner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_scroll.add_child(enemy_scanner_vbox)

func _on_repair_drone_pressed() -> void:
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	var quest_mgr = get_parent().get_node_or_null("QuestManager")
	if is_instance_valid(campaign_mgr) and is_instance_valid(quest_mgr):
		if quest_mgr.player_credits >= 150:
			quest_mgr.player_credits -= 150
			campaign_mgr.mack_current_hp = min(campaign_mgr.mack_max_hp, campaign_mgr.mack_current_hp + 40.0)
			campaign_mgr._log_combat_math("[color=#00FF88][DRONE REPAIR] Banquo launched nanite drone -> +40 HP Restored![/color]")
		else:
			campaign_mgr._log_combat_math("[color=#FF3333][DRONE ERROR] Insufficient Cyber-Credits! Need 150 C.[/color]")

# ==============================================================================
# REALTIME CONSOLE DATA & UPGRADE SLOT STATUS SYNC
# ==============================================================================

func _update_console_data() -> void:
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	var garage_mgr = get_parent().get_node_or_null("GarageManager")
	if not is_instance_valid(campaign_mgr): return
	
	# Fetch Telemetry Upgrade Purchase Level from Pit Garage
	var telemetry_lvl: int = 0
	if is_instance_valid(garage_mgr) and garage_mgr.fleet.has("BANQUO_CAR"):
		telemetry_lvl = garage_mgr.fleet["BANQUO_CAR"]["upgrades"]["telemetry"].get("level", 0)
		
	# Update Header Battle Action
	if is_instance_valid(battle_status_label):
		battle_status_label.text = campaign_mgr.mack_current_action
		
	# 1. Always Render Vector Radar (Slot 1)
	_draw_radar_screen(campaign_mgr)
	
	# 2. Render Hostile Enemy Scanner (Slot 2)
	for child in enemy_scanner_vbox.get_children():
		child.queue_free()
		
	for enemy in campaign_mgr.active_enemy_units:
		var e_card = PanelContainer.new()
		var e_style = StyleBoxFlat.new()
		e_style.bg_color = Color(0.08, 0.03, 0.04, 0.85)
		e_style.border_color = Color(1.0, 0.2, 0.3, 0.6)
		e_style.set_border_width_all(1)
		e_style.set_content_margin_all(5)
		e_card.add_theme_stylebox_override("panel", e_style)
		enemy_scanner_vbox.add_child(e_card)
		
		var eVbox = VBoxContainer.new()
		e_card.add_child(eVbox)
		
		var e_lbl = Label.new()
		var e_name = enemy.get("name", "Hostile Target")
		var e_icon = enemy.get("icon", "🚘")
		var e_ac = enemy.get("ac", 12)
		e_lbl.text = "%s %s [AC: %d]" % [e_icon, e_name, e_ac]
		e_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		eVbox.add_child(e_lbl)
		
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size.y = 10
		hp_bar.max_value = enemy.get("max_hp", 100)
		hp_bar.value = enemy.get("hp", 100)
		eVbox.add_child(hp_bar)
		
	# 3. Render Vitals (Slot 3 - Telemetry Level 1 Required)
	mack_hp_bar.max_value = campaign_mgr.mack_max_hp
	mack_hp_bar.value = campaign_mgr.mack_current_hp
	
	if telemetry_lvl >= 1:
		var core_temp: float = 75.0 + ((1.0 - (campaign_mgr.mack_current_hp / campaign_mgr.mack_max_hp)) * 35.0)
		var rpm: int = 4000 + randi() % 800
		side_vitals_label.text = "CORE TEMP: %.1f°C | ENGINE RPM: %d" % [core_temp, rpm]
		side_vitals_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	else:
		side_vitals_label.text = "[ 🔒 VITALS OFFLINE - BUY TELEMETRY L1 AT THE PIT ]"
		side_vitals_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		
	# Drone Repair Button (Telemetry Level 3 Required)
	if telemetry_lvl >= 3:
		drone_repair_btn.disabled = false
		drone_repair_btn.text = "🛸 LAUNCH REPAIR DRONE (150 C)"
	else:
		drone_repair_btn.disabled = true
		drone_repair_btn.text = "🔒 REPAIR DRONE OFFLINE [BUY TELEMETRY L3]"

	# 4. Render Combat Math Log (Slot 4 - Telemetry Level 2 Required)
	if telemetry_lvl >= 2:
		var formatted_lines: Array[String] = []
		var lines = campaign_mgr.math_log_lines
		for idx in range(lines.size()):
			var line_str: String = lines[idx]
			if idx == 0:
				# Clean high-contrast indicator: bright gold pulse arrow & bold white text
				formatted_lines.append("[color=#FFCC00]▶ [b]" + line_str + "[/b][/color]")
			else:
				formatted_lines.append("  " + line_str)
		math_log_text.text = "\n".join(formatted_lines)
	else:
		math_log_text.text = "[color=#FF5555]🔒 COMBAT MATH MATRIX OFFLINE\n\nPurchase Telemetry Upgrade Level 2 at Porter's Pit Garage to unlock real-time D20 dice rolls & armor absorption telemetry![/color]"

func _draw_radar_screen(campaign_mgr: Node) -> void:
	for child in radar_screen_rect.get_children():
		child.queue_free()
		
	var r_size = radar_screen_rect.size
	if r_size.x <= 0 or r_size.y <= 0:
		r_size = Vector2(400, 360)
		
	var center = r_size / 2.0
	
	var grid_draw = RadarGridControl.new()
	grid_draw.center = center
	grid_draw.max_r = min(r_size.x, r_size.y) * 0.42
	grid_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	radar_screen_rect.add_child(grid_draw)
	
	# Mack's War-Rig Marker
	var mack_shake_offset = Vector2.ZERO
	if mack_shake_timer > 0.0:
		mack_shake_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		
	var mack_marker = PanelContainer.new()
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(1.0, 0.4, 0.4) if mack_shake_timer > 0.0 else Color(0.0, 1.0, 0.85)
	m_style.set_corner_radius_all(4)
	mack_marker.add_theme_stylebox_override("panel", m_style)
	mack_marker.custom_minimum_size = Vector2(14, 14)
	mack_marker.position = center - Vector2(7, 7) + mack_shake_offset
	radar_screen_rect.add_child(mack_marker)
	
	var m_label = Label.new()
	m_label.text = " 🚜 MACK"
	m_label.position = mack_marker.position + Vector2(18, -4)
	m_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	m_label.add_theme_font_size_override("font_size", 9)
	radar_screen_rect.add_child(m_label)
	
	# Enemy Blip Markers (Dynamic orbital movement ahead of Mack)
	var active_enemies = campaign_mgr.active_enemy_units
	var count = active_enemies.size()
	var max_r = min(r_size.x, r_size.y) * 0.42
	var time_sec = Time.get_ticks_msec() / 1000.0
	
	for i in range(count):
		var enemy = active_enemies[i]
		
		# Organic dynamic orbital sway movement
		var base_angle = (float(i) - (float(count - 1) / 2.0)) * 0.4 - (PI / 2.0)
		var dynamic_angle_sway = sin(time_sec * 1.8 + i * 1.5) * 0.12
		var dynamic_dist_sway = cos(time_sec * 2.2 + i * 2.1) * (max_r * 0.05)
		
		var angle_offset = base_angle + dynamic_angle_sway
		var dist = max_r * (0.45 + (i * 0.15)) + dynamic_dist_sway
		
		var e_shake_offset = Vector2.ZERO
		var e_shake_time = active_enemy_shakes.get(i, 0.0)
		if e_shake_time > 0.0:
			e_shake_offset = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			
		var e_pos = center + Vector2(cos(angle_offset), sin(angle_offset)) * dist + e_shake_offset
		
		var e_marker = PanelContainer.new()
		var e_style = StyleBoxFlat.new()
		e_style.bg_color = Color(1.0, 0.9, 0.2) if e_shake_time > 0.0 else Color(1.0, 0.2, 0.3)
		e_style.set_corner_radius_all(3)
		e_marker.add_theme_stylebox_override("panel", e_style)
		e_marker.custom_minimum_size = Vector2(12, 12)
		e_marker.position = e_pos - Vector2(6, 6)
		radar_screen_rect.add_child(e_marker)
		
		# Clean Target Name Tag (No health bar, HP is cleanly shown in Slot 2)
		var e_name_lbl = Label.new()
		e_name_lbl.text = enemy.get("name", "Hostile")
		e_name_lbl.position = e_pos + Vector2(10, -8)
		e_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		e_name_lbl.add_theme_font_size_override("font_size", 9)
		radar_screen_rect.add_child(e_name_lbl)

class RadarGridControl extends Control:
	var center: Vector2 = Vector2.ZERO
	var max_r: float = 100.0

	func _draw() -> void:
		draw_arc(center, max_r, 0, TAU, 64, Color(0.0, 0.85, 1.0, 0.4), 1.5)
		draw_arc(center, max_r * 0.66, 0, TAU, 48, Color(0.0, 0.85, 1.0, 0.25), 1.0)
		draw_arc(center, max_r * 0.33, 0, TAU, 32, Color(0.0, 0.85, 1.0, 0.15), 1.0)
		
		draw_line(Vector2(center.x - max_r, center.y), Vector2(center.x + max_r, center.y), Color(0.0, 0.85, 1.0, 0.3), 1.0)
		draw_line(Vector2(center.x, center.y - max_r), Vector2(center.x, center.y + max_r), Color(0.0, 0.85, 1.0, 0.3), 1.0)
		
		var time_sec = Time.get_ticks_msec() / 1000.0
		var sweep_angle = fmod(time_sec * 2.5, TAU)
		var sweep_end = center + Vector2(cos(sweep_angle), sin(sweep_angle)) * max_r
		draw_line(center, sweep_end, Color(0.0, 1.0, 0.85, 0.7), 2.0)
