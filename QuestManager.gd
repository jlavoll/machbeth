extends Node
class_name QuestManager

# ==============================================================================
# QUEST MANAGER (QuestManager.gd)
# ==============================================================================
# Central data-driven quest and mission manager for Cyberpunk Macbeth.
# Decouples quest state tracking, objective triggers, reward payouts, map blips,
# and neural communications from DialogueSystem and PedestrianSystem.

# Preloaded Fonts
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")
var sharetech_font: Font = preload("res://fonts/ShareTechMono-Regular.ttf")
var geist_font: Font = preload("res://fonts/GeistPixel-Regular-VariableFont_ELSH.ttf")


signal quest_started(quest_id: String)
signal quest_objective_updated(quest_id: String, objective_text: String)
signal quest_completed(quest_id: String, reward_credits: int)

# Active Quest State & Timer Tracking
var active_quest_id: String = ""
var active_quest_data: Dictionary = {}
var active_quest_time_left: float = 0.0
var active_eavesdrop_timer: float = 0.0
var player_credits: int = 15000 # High starting credits for testing

# Act 1 Day Completion Flags
var day1_mission_complete: bool = false
var day2_mission_complete: bool = false
var day3_mission_complete: bool = false
var day4_mission_complete: bool = false
var day5_mission_complete: bool = false


# 3D Goal Line Beacon Node
var active_goal_beacon_node: Node3D = null

# Registry of all data-driven quests in the game
var quest_registry: Dictionary = {
	# -----------------------------------------------------------------------
	# ACT 1 — STORY MISSIONS
	# -----------------------------------------------------------------------
	"act1_m1_dead_end_convoy": {
		"title": "⚔️ ACT I · DEAD END CONVOY",
		"description": "Red Crows gang blockade on Industrial Corridor 7. Clear the three-vehicle formation. Protect the Bankes Logistics medical freight shipment.",
		"type": "BATTLE_INTERCEPT",
		"act": 1,
		"day": 1,
		"is_story_mission": true,
		"reward_credits": 1800,
		"reward_scrap": 60,
		"giver_npc_id": "Porter",
		"faction_id": "NEON_SYNDICATE",
		"giver_affinity_reward": 3,
		"start_dialogue_target": "act1_m1_dead_end_convoy",
		"target_destination": "Industrial Corridor 7",
		"goal_coordinates": [180.0, -60.0],
		"goal_radius": 22.0,
		"battle_mission_id": "act1_limo_intercept",
		"battle_round": 0,
		"map_blip_color": Color(1.0, 0.2, 0.1, 0.95),
		"completion_lady_m_text": "Red Crows neutralised. Freight corridor is clear. Bankes Logistics has confirmed delivery. 1,800 Credits + 60 Scrap deposited. Return to Porter at The Pit for debrief.",
		"completion_comms_sender": "MACK // OVERWATCH"
	},
	# -----------------------------------------------------------------------
	# EXISTING SIDE MISSIONS
	# -----------------------------------------------------------------------
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
var quest_timer_label: Label

# Delayed completion queue flag for waiting until dialogue UI closes
var _pending_completion_quest_id: String = ""

# ==============================================================================
# INITIALIZATION & SIGNAL WIRING
# ==============================================================================

func _ready() -> void:
	_build_quest_hud()
	_load_street_missions_from_json()
	call_deferred("_connect_dialogue_signals")

func _process(delta: float) -> void:
	if active_quest_id.is_empty():
		return

	# 1. Active Quest Live Countdown Timer
	if active_quest_time_left > 0.0:
		active_quest_time_left -= delta
		var minutes: int = int(active_quest_time_left / 60.0)
		var seconds: int = int(active_quest_time_left) % 60
		if is_instance_valid(quest_timer_label):
			quest_timer_label.text = "⏱️ TIME REMAINING: %02d:%02d" % [minutes, seconds]
			if active_quest_time_left < 20.0:
				quest_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Urgent Red Pulse
			else:
				quest_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))

		if active_quest_time_left <= 0.0:
			fail_quest(active_quest_id, "TIME LIMIT EXPIRED // CONTRACT CANCELLED")
			return

	# 2. Check Goal-Line Proximity for Eavesdrop / Destination Beacons
	if is_instance_valid(active_goal_beacon_node):
		var player_node: Node3D = null
		var root_s = get_parent()
		if is_instance_valid(root_s):
			player_node = root_s.get_node_or_null("PlayerCar")
			if is_instance_valid(player_node) and player_node.get("is_on_foot") == true:
				var on_foot = root_s.get_node_or_null("PlayerOnFoot")
				if is_instance_valid(on_foot):
					player_node = on_foot

		if is_instance_valid(player_node):
			var dist: float = player_node.global_position.distance_to(active_goal_beacon_node.global_position)
			var goal_radius: float = active_quest_data.get("goal_radius", 18.0)
			var mission_type: String = active_quest_data.get("type", "COURIER_RUN")

			if dist <= goal_radius:
				if mission_type == "EAVESDROP_RECON":
					var duration_needed: float = active_quest_data.get("eavesdrop_duration", 15.0)
					active_eavesdrop_timer += delta
					var pct: int = clampi(int((active_eavesdrop_timer / duration_needed) * 100.0), 0, 100)
					if is_instance_valid(quest_timer_label):
						quest_timer_label.text = "📡 INTERCEPTING AUDIO: %d%%" % pct
						quest_timer_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
					if active_eavesdrop_timer >= duration_needed:
						complete_quest(active_quest_id)
				elif mission_type == "BATTLE_INTERCEPT":
					# Arrived at battle zone — launch simulation, remove beacon
					_clear_goal_beacon()
					var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
					if is_instance_valid(campaign_mgr) and campaign_mgr.has_method("start_simulated_mission"):
						var b_mission: String = active_quest_data.get("battle_mission_id", "act1_limo_intercept")
						var b_round: int = active_quest_data.get("battle_round", 0)
						campaign_mgr.start_simulated_mission(b_mission, b_round)
					# Quest completes when battle simulation ends — handled by _on_battle_simulation_ended
				elif mission_type in ["COURIER_RUN", "REACH_DESTINATION", "TAIL_TARGET"]:
					complete_quest(active_quest_id)


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
					"type": quest.get("type", "COURIER_RUN"),
					"time_limit": quest.get("time_limit", 0.0),
					"target_destination": quest.get("target_destination", ""),
					"goal_coordinates": quest.get("goal_coordinates", []),
					"goal_radius": quest.get("goal_radius", 18.0),
					"eavesdrop_duration": quest.get("eavesdrop_duration", 15.0),
					"penalty_credits": quest.get("penalty_credits", 300),
					"penalty_affinity": quest.get("penalty_affinity", 5),
					"giver_npc_id": quest.get("client", ""),
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
	# Wire battle simulation completion → quest completion for BATTLE_INTERCEPT quests
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_mgr) and campaign_mgr.has_signal("battle_concluded"):
		if not campaign_mgr.battle_concluded.is_connected(_on_battle_simulation_ended):
			campaign_mgr.battle_concluded.connect(_on_battle_simulation_ended)

# ==============================================================================
# DIALOGUE & QUEST SIGNAL LISTENERS
# ==============================================================================

func _on_dialogue_choice_selected(_choice_index: int, target_node_id: String) -> void:
	# Check explicit hardcoded targets or dialogue node IDs
	if target_node_id == "accept_pink_cadillac":
		start_quest("street_01_pink_cadillac")
	elif target_node_id == "accept_data_drop":
		start_quest("street_02_data_drop")
	elif target_node_id == "accept_cyberware_heist":
		start_quest("limo_intercept")
	elif target_node_id == "accept_mission":
		start_quest("act1_m1_dead_end_convoy")
	else:
		for q_id in quest_registry:
			var q_data: Dictionary = quest_registry[q_id]
			if target_node_id == q_data.get("start_dialogue_target", "") or target_node_id == q_id:
				start_quest(q_id)
			elif target_node_id == q_data.get("complete_dialogue_target", ""):
				_pending_completion_quest_id = q_id


func _on_dialogue_ended() -> void:
	if _pending_completion_quest_id != "":
		var q_id = _pending_completion_quest_id
		_pending_completion_quest_id = ""
		complete_quest(q_id)

func _on_battle_simulation_ended(victory: bool) -> void:
	if not active_quest_id.is_empty() and active_quest_data.get("type", "") == "BATTLE_INTERCEPT":
		if victory:
			complete_quest(active_quest_id)
		else:
			fail_quest(active_quest_id, "BATTLE SIMULATION FAILED // CONVOY NOT NEUTRALISED")


# ==============================================================================
# PUBLIC QUEST CONTROL API
# ==============================================================================

func start_quest(quest_id: String) -> void:
	if not quest_registry.has(quest_id):
		push_error("QuestManager: Quest ID not found in registry: " + quest_id)
		return

	active_quest_id = quest_id
	active_quest_data = quest_registry[quest_id]
	active_quest_time_left = float(active_quest_data.get("time_limit", 0.0))
	active_eavesdrop_timer = 0.0

	print("[QUEST MANAGER] Starting quest: ", active_quest_data.get("title", quest_id))

	# 1. Trigger dynamic NPC spawn in PedestrianSystem
	var ped_system = get_parent().get_node_or_null("PedestrianSystem")
	if is_instance_valid(ped_system) and ped_system.has_method("_trigger_delivery_quest_start"):
		ped_system._trigger_delivery_quest_start()

	# 2. Check if quest requires spawning Pink Cadillac asset!
	if quest_id == "street_01_pink_cadillac":
		_spawn_pink_cadillac_mission_asset()

	# 3. Spawn 3D Goal Line Beacon on the city grid
	_spawn_goal_line_beacon(active_quest_data)

	# 4. Update HUD Banner
	_show_quest_hud(active_quest_data.get("title", ""), active_quest_data.get("description", ""))

	# 5. For story BATTLE_INTERCEPT quests — send a comms briefing from Mack
	if active_quest_data.get("type", "") == "BATTLE_INTERCEPT":
		var comms = get_parent().get_node_or_null("NeuralNotificationSystem")
		if is_instance_valid(comms) and comms.has_method("send_message"):
			comms.send_message(
				"🎯 BANQUO — drive to the marked position on the east grid. Red Crow vehicles confirmed at Industrial Corridor 7. Engage when ready. I'm on overwatch.",
				"MACK // FIELD COMMS"
			)

	emit_signal("quest_started", quest_id)


func _spawn_goal_line_beacon(q_data: Dictionary) -> void:
	_clear_goal_beacon()
	var dest_name: String = q_data.get("target_destination", "")
	var explicit_coords: Array = q_data.get("goal_coordinates", [])
	var target_pos: Vector3 = Vector3.ZERO

	if explicit_coords.size() >= 2:
		target_pos = Vector3(float(explicit_coords[0]), 0.1, float(explicit_coords[1]))
	elif dest_name == "The Pit Garage":
		target_pos = Vector3(-180.0, 0.1, 180.0)
	elif dest_name == "Chop Shop Garage":
		target_pos = Vector3(180.0, 0.1, 180.0)
	elif dest_name == "Cyber Park Plaza":
		target_pos = Vector3(0.0, 0.1, 0.0)
	elif dest_name == "West Park Plaza":
		target_pos = Vector3(-60.0, 0.1, 75.0)
	elif dest_name == "Joe's Ice Cream":
		target_pos = Vector3(65.0, 0.1, 25.0)
	elif dest_name == "Duncan Dynamics HQ":
		target_pos = Vector3(0.0, 0.1, -180.0)
	elif q_data.get("type", "") == "EAVESDROP_RECON":
		target_pos = Vector3(0.0, 0.1, 10.0) # Near park stage
	# 5. Sync Target Position to Tactical Overmap Manager (M Key Map)
	var overmap = get_parent().get_node_or_null("TacticalOvermapManager")
	if is_instance_valid(overmap):
		overmap.has_active_delivery = true
		overmap.delivery_target_pos = target_pos

	var beacon = Node3D.new()
	beacon.name = "ActiveMissionGoalBeacon"
	beacon.position = target_pos


	# Glowing Neon Ring on ground
	var ring = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 8.0
	cyl.bottom_radius = 8.0
	cyl.height = 0.2
	ring.mesh = cyl
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(1.0, 0.85, 0.0, 0.4)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.emission_enabled = true
	r_mat.emission = Color(1.0, 0.85, 0.0)
	r_mat.emission_energy_multiplier = 4.0
	ring.material_override = r_mat
	beacon.add_child(ring)

	# Vertical Sky Beam (120m towering laser beacon visible from across the whole city grid)
	var beam = MeshInstance3D.new()
	var b_cyl = CylinderMesh.new()
	b_cyl.top_radius = 1.2
	b_cyl.bottom_radius = 1.2
	b_cyl.height = 120.0
	beam.mesh = b_cyl
	beam.position = Vector3(0.0, 60.0, 0.0)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(1.0, 0.85, 0.0, 0.4)
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.emission_enabled = true
	b_mat.emission = Color(1.0, 0.85, 0.0)
	b_mat.emission_energy_multiplier = 8.0
	beam.material_override = b_mat
	beacon.add_child(beam)

	# Floating 3D Label with quest title
	var q_title: String = q_data.get("title", "MISSION OBJECTIVE")
	var lbl = Label3D.new()
	lbl.text = "🎯 " + q_title + "\n[INTERCEPT ZONE // RADIUS 22m]"
	lbl.position = Vector3(0.0, 6.0, 0.0)
	lbl.font_size = 32
	lbl.pixel_size = 0.007
	lbl.modulate = Color(1.0, 0.9, 0.1)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0)
	lbl.outline_size = 12
	beacon.add_child(lbl)


	get_parent().add_child(beacon)
	active_goal_beacon_node = beacon
	print("[QUEST MANAGER] 🏁 Spawned Mission Goal Line at: ", target_pos)

func _clear_goal_beacon() -> void:
	if is_instance_valid(active_goal_beacon_node):
		active_goal_beacon_node.queue_free()
		active_goal_beacon_node = null

func _spawn_pink_cadillac_mission_asset() -> void:
	var root_scene = get_parent()
	if is_instance_valid(root_scene):
		var old_cadillac = root_scene.get_node_or_null("PinkCadillacTarget")
		if is_instance_valid(old_cadillac):
			old_cadillac.queue_free()

		var cadillac_script = preload("res://PinkCadillacTarget.gd")
		var cadillac = CharacterBody3D.new()
		cadillac.set_script(cadillac_script)
		cadillac.name = "PinkCadillacTarget"
		
		var cadillac_route: Array[Vector3] = [
			Vector3(-60.0, 0.0, 75.0),
			Vector3(0.0, 0.0, 75.0),
			Vector3(120.0, 0.0, 75.0),
			Vector3(120.0, 0.0, -45.0),
			Vector3(0.0, 0.0, -45.0),
			Vector3(-120.0, 0.0, -45.0),
			Vector3(-120.0, 0.0, 75.0)
		]
		cadillac.setup_route(cadillac_route)
		cadillac.is_active_tail_target = true
		
		cadillac.tailing_alert_failed.connect(func(reason: String):
			fail_quest("street_01_pink_cadillac", "TAILING FAILED: " + reason)
		)
		
		cadillac.tailing_completed.connect(func():
			complete_quest("street_01_pink_cadillac")
		)
		
		root_scene.add_child(cadillac)
		print("[QUEST MANAGER] Spawned Pink Cadillac mission asset at West Park Plaza!")

## Fails an active quest, applying penalties (credits fine, affinity loss) and notifying user
func fail_quest(quest_id: String, reason: String = "MISSION FAILED") -> void:
	var q_data: Dictionary = quest_registry.get(quest_id, active_quest_data)
	var fine: int = q_data.get("penalty_credits", 300)
	var aff_loss: int = q_data.get("penalty_affinity", 5)
	var giver_id: String = q_data.get("giver_npc_id", "")

	player_credits = maxi(0, player_credits - fine)

	var stats_mgr = get_parent().get_node_or_null("FactionStatsManager")
	if is_instance_valid(stats_mgr) and not giver_id.is_empty():
		stats_mgr.modify_npc_affinity(giver_id, -aff_loss)

	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		var fail_msg: String = "⚠️ CONTRACT FAILED: %s\nPenalty Applied: -%d Cyber-Credits & Client Familiarity Lost." % [reason, fine]
		neural_comms.send_message(fail_msg, "MISSION FAILED // REPUTATION PENALTY")

	_clear_goal_beacon()
	_hide_quest_hud()

	active_quest_id = ""
	active_quest_data.clear()
	active_quest_time_left = 0.0

## Completes an active quest, rewarding credits, updating map, and triggering Lady M comms
func complete_quest(quest_id: String) -> void:
	if active_quest_id != quest_id and active_quest_id != "":
		push_warning("QuestManager: Completing quest that is not active: " + quest_id)

	var q_data: Dictionary = quest_registry.get(quest_id, active_quest_data)
	var reward: int = q_data.get("reward_credits", 500)
	player_credits += reward

	print("[QUEST MANAGER] Quest completed! Reward: %d Credits. Total Credits: %d" % [reward, player_credits])

	_clear_goal_beacon()

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
	active_quest_time_left = 0.0

	emit_signal("quest_completed", quest_id, reward)

	# 6. Notify CampaignManager of completed side mission & check daily quota
	var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_mgr):
		if q_data.get("is_story_mission", false):
			# Set per-day completion flag based on which day's story mission this is
			match q_data.get("day", 0):
				1: day1_mission_complete = true
				2: day2_mission_complete = true
				3: day3_mission_complete = true
				4: day4_mission_complete = true
				5: day5_mission_complete = true
		else:
			campaign_mgr.side_missions_today += 1
			if campaign_mgr.side_missions_today >= campaign_mgr.max_side_missions_per_day:
				campaign_mgr.notify_daily_quests_exhausted()



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
	vbox.add_theme_constant_override("separation", 3)
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
	quest_objective_label.add_theme_font_override("font", sharetech_font)
	quest_objective_label.add_theme_font_size_override("font_size", 11)
	quest_objective_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(quest_objective_label)

	quest_timer_label = Label.new()
	quest_timer_label.text = ""
	quest_timer_label.add_theme_font_override("font", sharetech_font)
	quest_timer_label.add_theme_font_size_override("font_size", 11)
	quest_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	quest_timer_label.visible = false
	vbox.add_child(quest_timer_label)


func _show_quest_hud(title: String, desc: String) -> void:
	quest_title_label.text = "MISSION // " + title
	quest_objective_label.text = desc
	if active_quest_time_left > 0.0 or active_quest_data.get("type", "") == "EAVESDROP_RECON":
		quest_timer_label.visible = true
		quest_timer_label.text = "⏱️ INITIALIZING OBJECTIVE TRACKER..."
	else:
		quest_timer_label.visible = false
	quest_panel.visible = true

func _hide_quest_hud() -> void:
	quest_panel.visible = false
	if is_instance_valid(quest_timer_label):
		quest_timer_label.visible = false
