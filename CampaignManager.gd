extends Node
class_name CampaignManager

# ==============================================================================
# CAMPAIGN MANAGER & GRAND DEPLOYMENT PIPELINE (CampaignManager.gd)
# ==============================================================================
# Manages Act progression, corporate sector control across Cyberpunk City's 9 districts,
# War-Table deployment launches, and narrative story chapter advances.

signal act_advanced(new_act_index: int, act_title: String)
signal sector_control_changed(sector_id: int, new_faction: String)
signal deployment_ui_toggled(is_open: bool)

enum CampaignAct {
	ACT_1_DUNCAN_FALL,      # Act I: Duncan's Fall & Assassination
	ACT_2_BANQUO_INTERCEPT,  # Act II: Banquo's Intercept & Highway Pursuits
	ACT_3_BIRNAM_PURGE,     # Act III: The Birnam Wood Purge (Split Convoy)
	ACT_4_DUNSINANE_SIEGE   # Act IV: Dunsinane Tower Final Assault
}

var current_act: CampaignAct = CampaignAct.ACT_2_BANQUO_INTERCEPT

# Act Metadata
var act_details: Dictionary = {
	CampaignAct.ACT_1_DUNCAN_FALL: {
		"title": "ACT I: DUNCAN'S FALL",
		"description": "Executive Duncan removed. Power vacuum created across central grid.",
		"target_convoy": "Duncan Honor Guard",
		"enemy_hp": 150.0,
		"reward_credits": 1000
	},
	CampaignAct.ACT_2_BANQUO_INTERCEPT: {
		"title": "ACT II: BANQUO'S INTERCEPT",
		"description": "Banquo's street network gathers intel & scrap. Clear corporate limos.",
		"target_convoy": "Cawdor Logistics Armored Convoy",
		"enemy_hp": 250.0,
		"reward_credits": 2500
	},
	CampaignAct.ACT_3_BIRNAM_PURGE: {
		"title": "ACT III: THE BIRNAM PURGE",
		"description": "Macduff's distributed 4-vector strike force approaches the central highway.",
		"target_convoy": "Macduff Fife Security Vanguard",
		"enemy_hp": 400.0,
		"reward_credits": 5000
	},
	CampaignAct.ACT_4_DUNSINANE_SIEGE: {
		"title": "ACT IV: DUNSINANE TOWER SIEGE",
		"description": "Final corporate siege at Duncan Dynamics HQ. Total grid supremacy.",
		"target_convoy": "Bankes Ghost Cyber-Dreadnought",
		"enemy_hp": 650.0,
		"reward_credits": 10000
	}
}

# 9 City Sector Control Map (0 to 8)
# Factions: "DUNCAN_CORP", "FIFE_SECURITY", "NEON_SYNDICATE", "MACK_LOYALISTS"
var sector_control: Array[String] = [
	"DUNCAN_CORP",    "DUNCAN_CORP",    "FIFE_SECURITY",
	"NEON_SYNDICATE", "MACK_LOYALISTS", "NEON_SYNDICATE",
	"FIFE_SECURITY",  "MACK_LOYALISTS", "DUNCAN_CORP"
]

# UI Overlay Nodes
var deployment_hud_layer: CanvasLayer = null
var _deployment_root_control: Control = null
var is_deployment_ui_open: bool = false

# Component References
@onready var quest_manager = $"../QuestManager"
@onready var battle_manager = $"../BattleSystemManager"
@onready var neural_comms = $"../NeuralNotificationSystem"

func _ready() -> void:
	_build_deployment_ui()

func _input(event: InputEvent) -> void:
	if not is_deployment_ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			close_deployment_ui()
			get_viewport().set_input_as_handled()

# ==============================================================================
# PUBLIC API
# ==============================================================================

func open_deployment_ui() -> void:
	if is_deployment_ui_open:
		return
	is_deployment_ui_open = true
	if is_instance_valid(_deployment_root_control):
		_update_ui_contents()
		_deployment_root_control.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	deployment_ui_toggled.emit(true)

func close_deployment_ui() -> void:
	if not is_deployment_ui_open:
		return
	is_deployment_ui_open = false
	if is_instance_valid(_deployment_root_control):
		_deployment_root_control.visible = false
	
	var indoor_mgr = get_parent().get_node_or_null("IndoorSystemManager")
	if not is_instance_valid(indoor_mgr) or not indoor_mgr.is_inside_building:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	deployment_ui_toggled.emit(false)

# Autonomous Battle Simulation State (300 Seconds / 5 Minutes)
var is_battle_in_progress: bool = false
var battle_timer: float = 0.0
var battle_duration: float = 300.0 # 5 Minutes epic battle duration
var last_rumor_tick: float = 0.0

# Dynamic rumor feed messages sent every 45-60 seconds during battle
var rumor_dispatches: Array[String] = [
	"RUMOR // HIGHWAY FEED: Mack's War-Rig spotted breaching outer corporate barrier!",
	"RUMOR // CITIZEN DISPATCH: Heavy Ordnance Gatling fire heard roaring in Sector 4!",
	"RUMOR // NETRUNNER INTELLIGENCE: Mack's neural stack is spiking... but Fife Security is retreating!",
	"RUMOR // TRAFFIC GRID: Corporate armor units split across highway gates. Mack holding the central chokepoint!",
	"RUMOR // LADY M: Enemy vanguard hull integrity dropping below 30%! Victory is imminent!"
]
var rumor_index: int = 0

# Summary Report UI
var _summary_panel: PanelContainer
var _summary_title_label: Label
var _summary_body_label: Label

func _process(delta: float) -> void:
	if not is_battle_in_progress:
		return

	battle_timer += delta
	last_rumor_tick += delta

	# Dispatch a new rumor every 55 seconds during battle
	if last_rumor_tick >= 55.0:
		last_rumor_tick = 0.0
		_broadcast_next_rumor()

	# Complete battle after 300 seconds
	if battle_timer >= battle_duration:
		is_battle_in_progress = false
		_conclude_autonomous_battle(true)

func _broadcast_next_rumor() -> void:
	if rumor_index < rumor_dispatches.size():
		var msg: String = rumor_dispatches[rumor_index]
		rumor_index = (rumor_index + 1) % rumor_dispatches.size()
		if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
			neural_comms.send_message(msg, "TACTICAL TELEMETRY")

func launch_grand_deployment() -> void:
	if is_battle_in_progress:
		print("[CAMPAIGN MANAGER] Battle already in progress!")
		return

	close_deployment_ui()
	
	is_battle_in_progress = true
	battle_timer = 0.0
	last_rumor_tick = 0.0
	rumor_index = 0
	
	var current_data: Dictionary = act_details.get(current_act, {})
	var convoy_name: String = current_data.get("target_convoy", "Corporate Vanguard")
	
	print("[CAMPAIGN MANAGER] Launching autonomous 5-minute Grand Battle for: ", convoy_name)
	
	# Send initial Neural Comms announcement
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("WAR-RIG DISPATCHED! Mack deployed to central highway for " + convoy_name + ". Estimated engagement time: 5 MINS.", "LADY M // MISSION CONTROL")

func _conclude_autonomous_battle(success: bool) -> void:
	if not success:
		return

	var current_data: Dictionary = act_details.get(current_act, {})
	var reward_c: int = current_data.get("reward_credits", 2500)
	
	# Award credits to Banquo
	if is_instance_valid(quest_manager):
		quest_manager.player_credits += reward_c

	# Inject +20% Glitch/Paranoia into Mack's stack
	var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
	if is_instance_valid(glitch_sys):
		glitch_sys.inject_neural_instability(20.0)

	_advance_campaign_act()
	_show_after_action_summary(reward_c)

func _advance_campaign_act() -> void:
	match current_act:
		CampaignAct.ACT_1_DUNCAN_FALL:
			current_act = CampaignAct.ACT_2_BANQUO_INTERCEPT
		CampaignAct.ACT_2_BANQUO_INTERCEPT:
			current_act = CampaignAct.ACT_3_BIRNAM_PURGE
			sector_control[1] = "MACK_LOYALISTS"
			sector_control[4] = "MACK_LOYALISTS"
		CampaignAct.ACT_3_BIRNAM_PURGE:
			current_act = CampaignAct.ACT_4_DUNSINANE_SIEGE
			sector_control[0] = "MACK_LOYALISTS"
			sector_control[8] = "MACK_LOYALISTS"
		CampaignAct.ACT_4_DUNSINANE_SIEGE:
			for i in range(sector_control.size()):
				sector_control[i] = "MACK_LOYALISTS"
	
	var act_info: Dictionary = act_details.get(current_act, {})
	var title: String = act_info.get("title", "NEW ACT")
	act_advanced.emit(int(current_act), title)

func _show_after_action_summary(reward_credits: int) -> void:
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("VICTORY! Mack's War-Rig crushed the corporate convoy! +%d Credits transferred to vault." % reward_credits, "TACTICAL REPORT")

# ==============================================================================
# PROCEDURAL DEPLOYMENT UI BUILDER
# ==============================================================================

var _act_title_label: Label
var _act_desc_label: Label
var _convoy_info_label: Label
var _sector_grid_container: GridContainer
var _launch_btn: Button

func _build_deployment_ui() -> void:
	deployment_hud_layer = CanvasLayer.new()
	deployment_hud_layer.name = "DeploymentHUDLayer"
	deployment_hud_layer.layer = 25
	add_child(deployment_hud_layer)

	_deployment_root_control = Control.new()
	_deployment_root_control.name = "DeploymentRootControl"
	_deployment_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deployment_root_control.visible = false
	deployment_hud_layer.add_child(_deployment_root_control)

	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.01, 0.03, 0.05, 0.88)
	_deployment_root_control.add_child(bg_dim)

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
	frame_style.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	frame_style.border_width_left = 3
	frame_style.border_width_right = 3
	frame_style.border_width_top = 3
	frame_style.border_width_bottom = 3
	frame_style.border_color = Color(0.0, 1.0, 0.85) # Cyan Tactical Border
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	frame_style.content_margin_left = 20
	frame_style.content_margin_right = 20
	frame_style.content_margin_top = 16
	frame_style.content_margin_bottom = 16
	main_panel.add_theme_stylebox_override("panel", frame_style)
	_deployment_root_control.add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(main_vbox)

	# Header Bar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "⚔️ WAR-TABLE // GRAND CAMPAIGN DEPLOYMENT"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	header_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = " [X] CLOSE (ESC) "
	close_btn.pressed.connect(close_deployment_ui)
	header_hbox.add_child(close_btn)

	var divider1 = ColorRect.new()
	divider1.custom_minimum_size = Vector2(0, 2)
	divider1.color = Color(0.0, 1.0, 0.85, 0.5)
	main_vbox.add_child(divider1)

	# Body Split
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(body_hbox)

	# Left Column: Act Details & Launch Button
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(360, 0)
	left_vbox.add_theme_constant_override("separation", 12)
	body_hbox.add_child(left_vbox)

	_act_title_label = Label.new()
	_act_title_label.text = "ACT TITLE"
	_act_title_label.add_theme_font_size_override("font_size", 18)
	_act_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	left_vbox.add_child(_act_title_label)

	_act_desc_label = Label.new()
	_act_desc_label.text = "Act description..."
	_act_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_act_desc_label.add_theme_font_size_override("font_size", 12)
	_act_desc_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	left_vbox.add_child(_act_desc_label)

	var convoy_card = PanelContainer.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.03, 0.06, 0.1, 0.85)
	c_style.content_margin_left = 12
	c_style.content_margin_right = 12
	c_style.content_margin_top = 10
	c_style.content_margin_bottom = 10
	convoy_card.add_theme_stylebox_override("panel", c_style)
	left_vbox.add_child(convoy_card)

	_convoy_info_label = Label.new()
	_convoy_info_label.text = "CONVOY TARGET: ..."
	_convoy_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_convoy_info_label.add_theme_font_size_override("font_size", 13)
	_convoy_info_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	convoy_card.add_child(_convoy_info_label)

	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer2)

	_launch_btn = Button.new()
	_launch_btn.text = " 🚀 DEPLOY MACK'S WAR-RIG TO GRAND HIT "
	_launch_btn.custom_minimum_size = Vector2(340, 48)
	_launch_btn.pressed.connect(launch_grand_deployment)
	left_vbox.add_child(_launch_btn)

	# Right Column: 3x3 Sector Control Hologram Grid
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(right_vbox)

	var grid_hdr = Label.new()
	grid_hdr.text = "CYBERPUNK CITY // 9-SECTOR CONTROL MAP"
	grid_hdr.add_theme_font_size_override("font_size", 14)
	grid_hdr.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	right_vbox.add_child(grid_hdr)

	_sector_grid_container = GridContainer.new()
	_sector_grid_container.columns = 3
	_sector_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sector_grid_container.add_theme_constant_override("h_separation", 10)
	_sector_grid_container.add_theme_constant_override("v_separation", 10)
	right_vbox.add_child(_sector_grid_container)

	_build_sector_grid_boxes()

func _build_sector_grid_boxes() -> void:
	for i in range(9):
		var box = PanelContainer.new()
		box.name = "SectorBox_%d" % i
		box.custom_minimum_size = Vector2(100, 70)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = "SECTOR 0%d\nUNKNOWN" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		box.add_child(lbl)
		
		_sector_grid_container.add_child(box)

func _update_ui_contents() -> void:
	if not is_instance_valid(_deployment_root_control):
		return

	var act_info: Dictionary = act_details.get(current_act, {})
	_act_title_label.text = act_info.get("title", "UNKNOWN ACT")
	_act_desc_label.text = act_info.get("description", "")
	
	var target_name: String = act_info.get("target_convoy", "Enemy Squad")
	var hp: float = act_info.get("enemy_hp", 200.0)
	var reward: int = act_info.get("reward_credits", 1000)
	
	if is_battle_in_progress:
		var mins_left: float = (battle_duration - battle_timer) / 60.0
		_convoy_info_label.text = "TARGET: %s\nCONVOY HULL: %.0f HP\nSTATUS: ENGAGEMENT IN PROGRESS (%.1f MINS REMAINING)" % [target_name, hp, mins_left]
		_launch_btn.text = " ⏳ BATTLE IN PROGRESS (%.1f MINS) " % mins_left
		_launch_btn.disabled = true
	else:
		_convoy_info_label.text = "TARGET: %s\nCONVOY HULL: %.0f HP\nREWARD: %d CYBER-CREDITS" % [target_name, hp, reward]
		_launch_btn.text = " 🚀 DEPLOY MACK'S WAR-RIG TO GRAND HIT "
		_launch_btn.disabled = false

	# Update 9-Sector Grid Colors & Faction Names
	for i in range(9):
		var box = _sector_grid_container.get_node_or_null("SectorBox_%d" % i)
		if is_instance_valid(box):
			var faction: String = sector_control[i]
			var box_style = StyleBoxFlat.new()
			box_style.border_width_left = 2
			box_style.border_width_right = 2
			box_style.border_width_top = 2
			box_style.border_width_bottom = 2
			box_style.content_margin_left = 6
			box_style.content_margin_right = 6
			
			match faction:
				"MACK_LOYALISTS":
					box_style.bg_color = Color(0.0, 0.25, 0.2, 0.85)
					box_style.border_color = Color(0.0, 1.0, 0.85) # Cyan
				"DUNCAN_CORP":
					box_style.bg_color = Color(0.2, 0.05, 0.05, 0.85)
					box_style.border_color = Color(1.0, 0.2, 0.2) # Red
				"FIFE_SECURITY":
					box_style.bg_color = Color(0.05, 0.1, 0.2, 0.85)
					box_style.border_color = Color(0.1, 0.5, 1.0) # Steel Blue
				"NEON_SYNDICATE":
					box_style.bg_color = Color(0.2, 0.15, 0.02, 0.85)
					box_style.border_color = Color(1.0, 0.85, 0.0) # Gold
			
			box.add_theme_stylebox_override("panel", box_style)
			
			var lbl = box.get_node_or_null("Label")
			if is_instance_valid(lbl):
				lbl.text = "SECTOR 0%d\n%s" % [i + 1, faction.replace("_", " ")]
