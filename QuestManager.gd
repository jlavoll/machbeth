extends Node
class_name QuestManager

# ==============================================================================
# QUEST MANAGER (QuestManager.gd)
# ==============================================================================
# Central data-driven quest and mission manager for Cyberpunk Macbeth.
# Decouples quest state tracking, objective triggers, reward payouts, map blips,
# and neural communications from DialogueSystem and PedestrianSystem.

# Preloaded Orbitron font
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

signal quest_started(quest_id: String)
signal quest_objective_updated(quest_id: String, objective_text: String)
signal quest_completed(quest_id: String, reward_credits: int)

# Active Quest State
var active_quest_id: String = ""
var active_quest_data: Dictionary = {}
var player_credits: int = 15000 # High starting credits for testing

# Registry of all data-driven quests in the game
var quest_registry: Dictionary = {
	"limo_intercept": {
		"title": "EXEC LIMO INTERCEPT",
		"description": "Hunt down Duncan Dynamics Exec Limo on the city grid. Side-swipe or trap to engage cockpit combat.",
		"reward_credits": 1200,
		"reward_scrap": 50,
		"map_blip_color": Color(1.0, 0.2, 0.4, 0.95),
		"completion_lady_m_text": "Target limo destroyed! Exec telemetry secured. 1,200 Cyber-Credits & 50 Scrap added to inventory."
	},
	"fetch_data_chip": {
		"title": "ENCRYPTED DATA HANDOVER",
		"description": "Deliver the encrypted Syndicate data-chip to Banquo's contact waiting on the street.",
		"reward_credits": 500,
		"giver_npc_id": "GANG_LEADER",
		"receiver_npc_id": "BANQUO_CONTACT",
		"faction_id": "NEON_SYNDICATE",
		"giver_affinity_reward": 5,
		"receiver_affinity_reward": 5,
		"start_dialogue_target": "quest_accepted",
		"complete_dialogue_target": "deliver_package",
		"map_blip_color": Color(1.0, 0.85, 0.0, 0.95),
		"completion_lady_m_text": "Data-chip received and decrypted cleanly. Great work, Banquo. 500 Credits added to your Neural Vault."
	}
}


# Quest HUD Overlay
var quest_hud_layer: CanvasLayer
var quest_panel: PanelContainer
var quest_title_label: Label
var quest_objective_label: Label

# Delayed completion queue flag for waiting until dialogue UI closes
var _pending_completion_quest_id: String = ""

# ==============================================================================
# INITIALIZATION & SIGNAL WIRING
# ==============================================================================

func _ready() -> void:
	_build_quest_hud()
	_load_street_missions_from_json()
	call_deferred("_connect_dialogue_signals")

func _load_street_missions_from_json() -> void:
	if FileAccess.file_exists("res://data/street_missions.json"):
		var file = FileAccess.open("res://data/street_missions.json", FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var s_data = json.get_data().get("street_missions", {})
			for s_id in s_data:
				var quest = s_data[s_id]
				quest_registry[s_id] = {
					"title": quest.get("name", s_id).to_upper(),
					"description": quest.get("objective_text", ""),
					"reward_credits": quest.get("reward_credits", 500),
					"start_dialogue_target": "accept_" + s_id.replace("street_01_", "").replace("street_02_", "").replace("street_03_", ""),
					"map_blip_color": Color(1.0, 0.85, 0.0, 0.95),
					"completion_lady_m_text": "Street quest '" + quest.get("name", s_id) + "' objective complete. Reward added to inventory."
				}

func _connect_dialogue_signals() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if is_instance_valid(dialogue_sys):
		dialogue_sys.dialogue_choice_selected.connect(_on_dialogue_choice_selected)
		dialogue_sys.dialogue_ended.connect(_on_dialogue_ended)

# ==============================================================================
# DIALOGUE & QUEST SIGNAL LISTENERS
# ==============================================================================

func _on_dialogue_choice_selected(_choice_index: int, target_node_id: String) -> void:
	# Check explicit hardcoded targets or dialogue node IDs
	if target_node_id == "accept_pink_cadillac":
		start_quest("street_01_pink_cadillac")
	elif target_node_id == "accept_data_drop":
		start_quest("street_02_data_drop")
	else:
		for q_id in quest_registry:
			var q_data: Dictionary = quest_registry[q_id]
			if target_node_id == q_data.get("start_dialogue_target", ""):
				start_quest(q_id)
			elif target_node_id == q_data.get("complete_dialogue_target", ""):
				_pending_completion_quest_id = q_id

func _on_dialogue_ended() -> void:
	if _pending_completion_quest_id != "":
		var q_id: String = _pending_completion_quest_id
		_pending_completion_quest_id = ""
		complete_quest(q_id)

# ==============================================================================
# PUBLIC QUEST MANAGEMENT API
# ==============================================================================

## Starts a quest by ID, updating map blips, spawning NPCs, and displaying HUD notification
func start_quest(quest_id: String) -> void:
	if not quest_registry.has(quest_id):
		push_error("QuestManager: Quest ID not found in registry: " + quest_id)
		return

	active_quest_id = quest_id
	active_quest_data = quest_registry[quest_id]

	print("[QUEST MANAGER] Starting quest: ", active_quest_data.get("title", quest_id))

	# 1. Trigger dynamic NPC spawn in PedestrianSystem
	var ped_system = get_parent().get_node_or_null("PedestrianSystem")
	if is_instance_valid(ped_system) and ped_system.has_method("_trigger_delivery_quest_start"):
		ped_system._trigger_delivery_quest_start()

	# 2. Check if quest requires spawning Pink Cadillac asset!
	if quest_id == "street_01_pink_cadillac":
		_spawn_pink_cadillac_mission_asset()

	# 3. Update HUD Banner
	_show_quest_hud(active_quest_data.get("title", ""), active_quest_data.get("description", ""))

	emit_signal("quest_started", quest_id)

func _spawn_pink_cadillac_mission_asset() -> void:
	var traffic_sys = get_parent().get_node_or_null("TrafficSystem")
	var root_scene = get_parent()
	
	if is_instance_valid(root_scene):
		# Remove existing Cadillac if present
		var old_cadillac = root_scene.get_node_or_null("PinkCadillacTarget")
		if is_instance_valid(old_cadillac):
			old_cadillac.queue_free()

		var cadillac_script = preload("res://PinkCadillacTarget.gd")
		var cadillac = CharacterBody3D.new()
		cadillac.set_script(cadillac_script)
		cadillac.name = "PinkCadillacTarget"
		
		# Persistent fixed street route for Seed 1042 (Right-hand traffic lanes along main avenues)
		# Start: Cyber Park West Gate -> Central Broadway -> North Substation Avenue -> Chop Shop Alley Drop-off
		var cadillac_route: Array[Vector3] = [
			Vector3(-60.0, 0.0, 75.0),   # 1. Cyber Park West Gate Departure
			Vector3(0.0, 0.0, 75.0),     # 2. Main Broadway & 1st Avenue Intersection
			Vector3(120.0, 0.0, 75.0),   # 3. East Commercial Sector Turn
			Vector3(120.0, 0.0, -45.0),  # 4. North Industrial Corridor
			Vector3(0.0, 0.0, -45.0),    # 5. Substation Avenue Crossing
			Vector3(-120.0, 0.0, -45.0), # 6. West Warehouse District
			Vector3(-120.0, 0.0, 75.0)   # 7. Return to Chop Shop Alley Destination
		]
		cadillac.setup_route(cadillac_route)
		cadillac.is_active_tail_target = true
		
		# Connect failure & completion signals
		cadillac.tailing_alert_failed.connect(func(reason: String):
			var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
			if is_instance_valid(neural_comms):
				neural_comms.send_message("TAILING FAILED: " + reason, "MR. DODGY // PARK CONTACT")
			_hide_quest_hud()
			active_quest_id = ""
		)
		
		cadillac.tailing_completed.connect(func():
			complete_quest("street_01_pink_cadillac")
		)
		
		root_scene.add_child(cadillac)
		print("[QUEST MANAGER] Spawned Pink Cadillac mission asset at West Park Plaza!")

## Completes an active quest, rewarding credits, updating map, and triggering Lady M comms
func complete_quest(quest_id: String) -> void:
	if active_quest_id != quest_id and active_quest_id != "":
		push_warning("QuestManager: Completing quest that is not active: " + quest_id)

	var q_data: Dictionary = quest_registry.get(quest_id, active_quest_data)
	var reward: int = q_data.get("reward_credits", 500)
	player_credits += reward

	print("[QUEST MANAGER] Quest completed! Reward: %d Credits. Total Credits: %d" % [reward, player_credits])

	# 1. Clear Overmap blip
	var overmap = get_parent().get_node_or_null("TacticalOvermapManager")
	if is_instance_valid(overmap):
		overmap.has_active_delivery = false

	# 2. Trigger recipient vehicle exit in PedestrianSystem
	var ped_system = get_parent().get_node_or_null("PedestrianSystem")
	if is_instance_valid(ped_system) and ped_system.has_method("_trigger_delivery_quest_complete"):
		ped_system._trigger_delivery_quest_complete()

	# 3. Award NPC Affinity and Faction Standing Points!
	var stats_mgr = get_parent().get_node_or_null("FactionStatsManager")
	if is_instance_valid(stats_mgr) and stats_mgr.has_method("modify_npc_affinity"):
		var faction_id: String = q_data.get("faction_id", "NEON_SYNDICATE")
		var giver_id: String = q_data.get("giver_npc_id", "")
		var receiver_id: String = q_data.get("receiver_npc_id", "")
		var giver_reward: int = q_data.get("giver_affinity_reward", 5)
		var receiver_reward: int = q_data.get("receiver_affinity_reward", 5)

		if not giver_id.is_empty():
			stats_mgr.modify_npc_affinity(giver_id, giver_reward, faction_id)
		if not receiver_id.is_empty():
			stats_mgr.modify_npc_affinity(receiver_id, receiver_reward, faction_id)

	# 4. Trigger Lady M Comms text
	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		var lady_m_msg: String = q_data.get("completion_lady_m_text", "Objective complete, Banquo. Good work.")
		neural_comms.send_message(lady_m_msg, "LADY M // MISSION CONTROL")

	# 5. Hide HUD Banner
	_hide_quest_hud()

	active_quest_id = ""
	active_quest_data.clear()

	emit_signal("quest_completed", quest_id, reward)

# ==============================================================================
# QUEST HUD BANNER UI (Top Right Compact HUD)
# ==============================================================================

func _build_quest_hud() -> void:
	quest_hud_layer = CanvasLayer.new()
	quest_hud_layer.name = "QuestHUDLayer"
	quest_hud_layer.layer = 12 # Above Overmap, below dialogue
	add_child(quest_hud_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.anchor_left = 1.0
	margin.anchor_right = 1.0
	margin.offset_left = -310
	margin.offset_top = 175 # Sits cleanly below PIP overmap camera box
	margin.offset_right = -20
	margin.offset_bottom = 245
	quest_hud_layer.add_child(margin)

	quest_panel = PanelContainer.new()
	quest_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.03, 0.06, 0.88)
	panel_style.border_width_left = 3
	panel_style.border_color = Color(1.0, 0.85, 0.0, 0.95) # Gold Quest Border
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	quest_panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(quest_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	quest_panel.add_child(vbox)

	quest_title_label = Label.new()
	quest_title_label.text = "ACTIVE OBJECTIVE"
	quest_title_label.add_theme_font_override("font", orbitron_font)
	quest_title_label.add_theme_font_size_override("font_size", 11)
	quest_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	vbox.add_child(quest_title_label)

	quest_objective_label = Label.new()
	quest_objective_label.text = ""
	quest_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_objective_label.add_theme_font_size_override("font_size", 10)
	quest_objective_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(quest_objective_label)

func _show_quest_hud(title: String, desc: String) -> void:
	quest_title_label.text = "MISSION // " + title
	quest_objective_label.text = desc
	quest_panel.visible = true

func _hide_quest_hud() -> void:
	quest_panel.visible = false
