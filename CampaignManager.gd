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
signal day_advanced(new_day: int)

# Day Cycle & Daily Operational Activity Caps
var current_day: int = 1
var grand_battles_today: int = 0
var max_grand_battles_per_day: int = 1
var side_missions_today: int = 0
var max_side_missions_per_day: int = 2

# Daily Special City Events Tracking
var active_daily_event: Dictionary = {}
var special_city_events: Array[Dictionary] = [
	{
		"id": "PARK_CONCERT",
		"title": "🎵 NEON SYNDICATE CYBER-PUNK CONCERT",
		"host": "LADY M // MISSION CONTROL",
		"text": "Lady M: 'The Neon Syndicate is hosting an underground holographic synth concert in Cyber Park today! Street crowd density is high—great spot to meet informants or listen to live tracks.'",
		"location": "Cyber Park Plaza",
		"effect": "+15% Extra Loot Credits on Side Pursuits today!"
	},
	{
		"id": "TRAVELING_MERCHANT",
		"title": "🛒 BLACK-MARKET TRAVELING CYBER-MERCHANT",
		"host": "PORTER // THE PIT MECHANIC",
		"text": "Porter: 'An illegal Black-Market Smuggler Rig just parked near the South Highway Exit. He's carrying rare Military-Grade Ordnance and prototype Cyberware for today only!'",
		"location": "South Highway Exit Gate",
		"effect": "20% Discount on Pit Garage Upgrades!"
	},
	{
		"id": "FIFE_RALLY",
		"title": "🛡️ CLAN FIFE SECURITY ARMORED RALLY",
		"host": "LADY M // MISSION CONTROL",
		"text": "Lady M: 'Clan Fife Security forces are holding an armored militarized parade along Broadway. Watch out for heavy patrol drones, but their supply trucks carry double scrap salvage!'",
		"location": "Central Broadway Corridor",
		"effect": "Double Scrap Salvage on Highway Battles!"
	},
	{
		"id": "NORNS_RITUAL",
		"title": "🔮 NORNS AI PHANTOM SIGNAL BROADCAST",
		"host": "THE 3 NORNS // WEIRD SISTERS",
		"text": "The 3 Norns: 'A strange ghost frequency echoes through Sector 4... The Weird Sisters have placed an ethereal blessing on Mack's War-Rig today. Engine thermal buildup is halved!'",
		"location": "Sector 4 Data Network",
		"effect": "Mack War-Rig Thermal Engine Heating Halved!"
	},
	{
		"id": "SHAKESPEARE_PARK",
		"title": "🎭 SHAKESPEARE IN THE PARK: HOLOGRAPHIC MACBETH RE-ENACTMENT",
		"host": "LADY M // MISSION CONTROL",
		"text": "Lady M: 'The Cyber-Arts Guild is performing an ethereal holographic re-enactment of Shakespeare's Macbeth on the Cyber Park stage today! 'Is this a dagger which I see before me?' Par Cans spotlights are lit up amber-gold!'",
		"location": "Cyber Park Stage",
		"effect": "+25% Neural Glitch & Paranoia Cooldown Rate today!"
	}
]

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

var is_top_bar_user_toggled: bool = true
var is_side_terminal_user_toggled: bool = true
var is_scanner_terminal_user_toggled: bool = true

# Timed Side Mission State
var active_side_mission_name: String = ""
var side_mission_time_left: float = 0.0
var side_mission_active: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 'T' Key: Toggle Top Telemetry Bar on/off during battle
		if event.keycode == KEY_T and is_battle_in_progress:
			is_top_bar_user_toggled = not is_top_bar_user_toggled
			if is_instance_valid(telemetry_panel):
				telemetry_panel.visible = is_top_bar_user_toggled
			var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				var state_str: String = "ENABLED" if is_top_bar_user_toggled else "DISABLED"
				neural_comms.send_message("TOP TELEMETRY BAR: " + state_str + " [Press 'T' to toggle]", "HUD CONFIG")
			get_viewport().set_input_as_handled()
			return

		# 'H' Key: Toggle Right Side Telemetry Terminal on/off during battle
		if event.keycode == KEY_H and is_battle_in_progress:
			is_side_terminal_user_toggled = not is_side_terminal_user_toggled
			if is_instance_valid(side_terminal_panel):
				side_terminal_panel.visible = is_side_terminal_user_toggled
			var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				var state_str: String = "ENABLED" if is_side_terminal_user_toggled else "DISABLED"
				neural_comms.send_message("SIDE TELEMETRY TERMINAL: " + state_str + " [Press 'H' to toggle]", "HUD CONFIG")
			get_viewport().set_input_as_handled()
			return

		# 'J' Key: Toggle New Dedicated Enemy Threat Scanner Terminal on/off
		if event.keycode == KEY_J and is_battle_in_progress:
			is_scanner_terminal_user_toggled = not is_scanner_terminal_user_toggled
			if is_instance_valid(scanner_terminal_panel):
				scanner_terminal_panel.visible = is_scanner_terminal_user_toggled
			var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				var state_str: String = "ENABLED" if is_scanner_terminal_user_toggled else "DISABLED"
				neural_comms.send_message("ENEMY THREAT SCANNER TERMINAL: " + state_str + " [Press 'J' to toggle]", "HUD CONFIG")
			get_viewport().set_input_as_handled()
			return

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

# Mack's Live Telemetry State
var mack_current_hp: float = 100.0
var mack_max_hp: float = 100.0
var mack_current_action: String = "Engaging convoy vanguard..."
var mack_next_action: String = "Flanking central highway chokepoint..."

# Live Combat Statistics & Harvest Metrics (Nerd Summary Sheet Data)
var stat_highest_damage_dealt: int = 0
var stat_total_crits_landed: int = 0
var stat_enemies_destroyed: int = 0
var stat_total_rounds_fired: int = 0
var stat_tech_harvested_count: int = 0
var stat_story_clues_found: Array[String] = []

# The 3 Norns Towing & Extraction Recovery Quest State
var is_norns_recovery_active: bool = false
var norns_recovery_drop_pos: Vector3 = Vector3.ZERO
var norns_recovery_node: Node3D = null
var is_war_rig_towed: bool = false

# Event Flags
var decision_1_triggered: bool = false
var decision_2_triggered: bool = false
var decision_3_triggered: bool = false
var is_substation_side_mission_active: bool = false

# Live Telemetry HUD Bar Nodes
var telemetry_hud_layer: CanvasLayer = null
var telemetry_panel: PanelContainer = null
var mack_hp_bar: ProgressBar = null
var mack_action_label: Label = null
var mack_timer_label: Label = null

# Dynamic rumor feed messages sent every 45-60 seconds during battle
var rumor_dispatches: Array[String] = [
	"RUMOR // HIGHWAY FEED: Mack's War-Rig spotted breaching outer corporate barrier!",
	"RUMOR // CITIZEN DISPATCH: Heavy Ordnance Gatling fire heard roaring in Sector 4!",
	"RUMOR // NETRUNNER INTELLIGENCE: Mack's neural stack is spiking... but Fife Security is retreating!",
	"RUMOR // TRAFFIC GRID: Corporate armor units split across highway gates. Mack holding the central chokepoint!",
	"RUMOR // LADY M: Enemy vanguard hull integrity dropping below 30%! Victory is imminent!"
]
var rumor_index: int = 0

func _ready() -> void:
	_build_deployment_ui()
	_build_telemetry_hud()
	call_deferred("_connect_dialogue_signals")

func _connect_dialogue_signals() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if is_instance_valid(dialogue_sys):
		dialogue_sys.dialogue_choice_selected.connect(_on_decision_choice_selected)

# Multi-Stage Battle Progression State
enum BattlePhase { PHASE_1_ARRED_CARS, PHASE_2_FOOT_SOLDIERS, PHASE_3_DRONE_SWARM, PHASE_4_GUNSHIP_BOSS }
var current_battle_phase: BattlePhase = BattlePhase.PHASE_1_ARRED_CARS

# Active Enemy Wave Tracking
var active_enemy_units: Array[Dictionary] = []
var side_enemy_scanner_label: RichTextLabel = null

func _process(delta: float) -> void:
	if not is_battle_in_progress:
		return

	battle_timer += delta
	last_rumor_tick += delta

	# Process active side mission timer
	if side_mission_active:
		side_mission_time_left -= delta
		if side_mission_time_left <= 0.0:
			side_mission_active = false
			_on_side_mission_expired()

	# Update 4-Stage Battle Phases based on elapsed battle timer (5 minutes = 300s)
	_update_battle_phase()

	# --- REAL-TIME COMBAT MATH CALCULATIONS ---
	var incoming_dps: float = 0.40
	match current_battle_phase:
		BattlePhase.PHASE_1_ARRED_CARS: incoming_dps = 0.35
		BattlePhase.PHASE_2_FOOT_SOLDIERS: incoming_dps = 0.45
		BattlePhase.PHASE_3_DRONE_SWARM: incoming_dps = 0.55
		BattlePhase.PHASE_4_GUNSHIP_BOSS: incoming_dps = 0.70

	# Mitigation from Mack's War-Rig Graphene Armor Level
	var armor_lvl: int = 1
	var garage_mgr = get_parent().get_node_or_null("GarageManager")
	if is_instance_valid(garage_mgr) and garage_mgr.fleet.has("MACK_RIG"):
		armor_lvl = garage_mgr.fleet["MACK_RIG"]["upgrades"]["armor"].get("level", 1)
	var armor_mitigation: float = (armor_lvl - 1) * 0.10
	incoming_dps -= armor_mitigation

	# Mitigation from Mack's Sub-Dermal Plating Cyborg Mod
	var cyborg_mgr = get_parent().get_node_or_null("CyborgModdingManager")
	if is_instance_valid(cyborg_mgr) and cyborg_mgr.cyberware_slots.has("subdermal_plating"):
		var subdermal_tier: int = cyborg_mgr.cyberware_slots["subdermal_plating"].get("tier", 1)
		incoming_dps -= (subdermal_tier - 1) * 0.07

	incoming_dps = max(0.05, incoming_dps)
	mack_current_hp = max(5.0, mack_current_hp - (delta * incoming_dps))
	_update_telemetry_hud()

	# Dynamic Decision Event Triggers at random intervals (every ~60-90s)
	if battle_timer >= 60.0 and not decision_1_triggered:
		decision_1_triggered = true
		_trigger_random_decision_event()

	if battle_timer >= 150.0 and not decision_2_triggered:
		decision_2_triggered = true
		_trigger_random_decision_event()

	if battle_timer >= 230.0 and not decision_3_triggered:
		decision_3_triggered = true
		_trigger_random_decision_event()

	# Complete battle when Gunship Boss is destroyed OR engine thermal limit is reached
	var boss_destroyed: bool = (current_battle_phase == BattlePhase.PHASE_4_GUNSHIP_BOSS and active_enemy_units.is_empty())
	if boss_destroyed or battle_timer >= battle_duration:
		is_battle_in_progress = false
		_conclude_autonomous_battle(boss_destroyed)

func _on_side_mission_expired() -> void:
	mack_current_hp = max(5.0, mack_current_hp - 35.0)
	mack_current_action = "Side mission timed out! War-Rig took heavy penalty (-35 HP)."
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("MISSION FAILED: Time expired! Mack's War-Rig suffered heavy structural damage (-35 HP).", "EMERGENCY MISSION FAILURE")

func _update_battle_phase() -> void:
	var old_phase = current_battle_phase
	if battle_timer < 75.0:
		current_battle_phase = BattlePhase.PHASE_1_ARRED_CARS
		if old_phase != current_battle_phase or active_enemy_units.is_empty():
			if battle_timer < 2.0: # Initial spawn
				mack_current_action = "PHASE I: Engaging Corporate Armored Cars..."
				active_enemy_units = [
					{"name": "Cawdor Interceptor Alpha", "type": "🚙 ARMORED CAR", "hp": 100, "weapon": "Twin 20mm Cannon", "icon": "🚙"},
					{"name": "Cawdor Interceptor Beta", "type": "🚙 ARMORED CAR", "hp": 100, "weapon": "Spike Ram", "icon": "🚙"}
				]
	elif battle_timer < 160.0:
		current_battle_phase = BattlePhase.PHASE_2_FOOT_SOLDIERS
		if old_phase != current_battle_phase:
			mack_current_action = "PHASE II: Sweeping Corporate Foot-Soldier Barricade..."
			active_enemy_units = [
				{"name": "Fife Exo-Trooper Squad A", "type": "🎖️ HEAVY INFANTRY", "hp": 140, "weapon": "Plasma Rifle Array", "icon": "🎖️"},
				{"name": "Fife Exo-Trooper Squad B", "type": "🎖️ HEAVY INFANTRY", "hp": 140, "weapon": "EMP Mortar", "icon": "🎖️"}
			]
	elif battle_timer < 240.0:
		current_battle_phase = BattlePhase.PHASE_3_DRONE_SWARM
		if old_phase != current_battle_phase:
			mack_current_action = "PHASE III: Cleaving Attack Drone Swarm..."
			active_enemy_units = [
				{"name": "Norns AI Hunter Drone #01", "type": "🛸 ATTACK DRONE", "hp": 80, "weapon": "Laser Cutter", "icon": "🛸"},
				{"name": "Norns AI Hunter Drone #02", "type": "🛸 ATTACK DRONE", "hp": 80, "weapon": "Disruptor Beam", "icon": "🛸"},
				{"name": "Norns AI Hunter Drone #03", "type": "🛸 ATTACK DRONE", "hp": 80, "weapon": "Nanite Swarm", "icon": "🛸"}
			]
	else:
		current_battle_phase = BattlePhase.PHASE_4_GUNSHIP_BOSS
		if old_phase != current_battle_phase:
			mack_current_action = "FINAL PHASE: Duel against Corporate Attack Helicopter!"
			active_enemy_units = [
				{"name": "Duncan Heavy Gunship Apex", "type": "🚁 ATTACK HELICOPTER BOSS", "hp": 450, "weapon": "Hellfire Ordnance Rockets", "icon": "🚁"}
			]

	if old_phase != current_battle_phase:
		if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
			neural_comms.send_message("BATTLE PHASE TRANSITION: " + mack_current_action, "TACTICAL TELEMETRY")

# Pool of dynamic decision triggers
var decision_event_pool: Array[String] = [
	"LADY_M_HACK",
	"NORNS_PHANTOMS",
	"BANKES_SERVER_SHUTDOWN",
	"FIFE_REINFORCEMENT_INTERCEPT",
	"CHOP_SHOP_DROPSHIP",
	"POLICE_CORDON_BLOCKADE"
]

func _trigger_random_decision_event() -> void:
	if decision_event_pool.is_empty():
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var event_id: String = decision_event_pool.pick_random()
	decision_event_pool.erase(event_id)
	
	match event_id:
		"LADY_M_HACK": _trigger_decision_event_lady_m()
		"NORNS_PHANTOMS": _trigger_decision_event_norns()
		"BANKES_SERVER_SHUTDOWN": _trigger_decision_event_bankes_server()
		"FIFE_REINFORCEMENT_INTERCEPT": _trigger_decision_event_fife_intercept()
		"CHOP_SHOP_DROPSHIP": _trigger_decision_event_chop_shop()
		"POLICE_CORDON_BLOCKADE": _trigger_decision_event_police_cordon()

# --- Dynamic Event 1: Lady M ICE-Hack Override ---
func _trigger_decision_event_lady_m() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "Lady M",
		"speaker_subtitle": "MISSION CONTROL // OVERRIDE PROTOCOL",
		"speaker_color": "#FF00CC",
		"nodes": {
			"start": {
				"text": "Banquo! Mack's War-Rig is trapped under intense corporate EMP suppressive fire at Sector 4! His hull is taking heavy damage. I can execute an unauthorized ICE override on their grid to shut down their turret array — but it will inject severe neural static into Mack's stack. What should I do?",
				"portrait_emotion": "urgent",
				"choices": [
					{ "text": "Execute the override! Protect Mack's chassis. [HP +35%, Paranoia +15%]", "target": "lady_m_override" },
					{ "text": "No, stay off the grid. Let Mack fight through it. [Take Damage]", "target": "lady_m_hold" }
				]
			},
			"lady_m_override": {
				"text": "Executing ICE override... Turret array offline! Mack's hull is stabilized, but his neural stack is spiking wildly. Keep an eye on him.",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			},
			"lady_m_hold": {
				"text": "Understood. Holding offline protocol. Mack's taking heavy structural hits, but his mind remains intact. Re-routing telemetry.",
				"portrait_emotion": "grave",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

# --- Dynamic Event 2: The 3 Norns Ocular Interference ---
func _trigger_decision_event_norns() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "The 3 Norns",
		"speaker_subtitle": "#03-NORNS // DEEP-WEB PREDICTIVE AI",
		"speaker_color": "#B01BFF",
		"nodes": {
			"start": {
				"text": "Banquo... the threads of thread-code tremble. We are broadcasting phantom target vectors directly into Mack's ocular scope! He is firing at shadows while the enemy convoy reloads! Drive to Substation 09 immediately and sever the grid power, or watch the War-Rig crumble!",
				"portrait_emotion": "cryptic",
				"choices": [
					{ "text": "I'm heading to Substation 09 now! [Emergency Mission]", "target": "norns_accept" },
					{ "text": "Ignore the phantoms. Mack will push through.", "target": "norns_ignore" }
				]
			},
			"norns_accept": {
				"text": "Hurry, Banquo... the clock ticks at Substation 09. Cut the power link before Mack's core burns.",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Drive to Substation 09]", "target": "exit" } ]
			},
			"norns_ignore": {
				"text": "A foolish choice... the shadows strike hard.",
				"portrait_emotion": "grave",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

# --- Dynamic Event 6: Fife Security Police Barricade Blockade ---
func _trigger_decision_event_police_cordon() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "Fife Security Checkpoint",
		"speaker_subtitle": "POLICE CORDON // SECTOR 3 BARRICADE",
		"speaker_color": "#1B82FF",
		"nodes": {
			"start": {
				"text": "ALERT: Fife Security Patrol has locked down Sector 3 with heavy police barricades and laser scanner cones! Mack's War-Rig cannot advance without taking heavy fire from their automated barrier turrets. How should we bypass the blockade?",
				"portrait_emotion": "warning",
				"choices": [
					{ "text": "Bribe checkpoint officer. [Pay 300 C, Bypass Barricade]", "target": "police_bribe_officer" },
					{ "text": "Lady M: Hack barricade laser grid remotely. [Paranoia +12%]", "target": "police_lady_m_hack" },
					{ "text": "Tell Mack to ram straight through the barricade! [Take -35 Damage]", "target": "police_ram_through" }
				]
			},
			"police_bribe_officer": {
				"text": "Cyber-credits transferred. Checkpoint officer disabled security barrier! Mack's route is clear.",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			},
			"police_lady_m_hack": {
				"text": "Laser grid offline! Barrier lowered, but remote frequency injected static into Mack's neural feed.",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			},
			"police_ram_through": {
				"text": "War-Rig smashed through concrete barricades! Route cleared, but Mack's front hull took heavy damage.",
				"portrait_emotion": "grave",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

# --- Dynamic Event 3: Bankes Logistics Server Shutdown ---
func _trigger_decision_event_bankes_server() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "Lady M",
		"speaker_subtitle": "MISSION CONTROL // TELEMETRY ALERT",
		"speaker_color": "#FF00CC",
		"nodes": {
			"start": {
				"text": "Banquo! The enemy convoy is receiving real-time tactical shielding updates from Bankes Logistics Server Vault! Mack's Gatling output is being completely absorbed. Drive to Bankes Logistics HQ immediately to sever their server link!",
				"portrait_emotion": "urgent",
				"choices": [
					{ "text": "I'm on it! Heading to Bankes Logistics. [Server Mission]", "target": "bankes_server_accept" },
					{ "text": "Can't make it. Tell Mack to focus fire.", "target": "bankes_server_ignore" }
				]
			},
			"bankes_server_accept": {
				"text": "Go! Interact with the server terminal inside Bankes Logistics to shut down their shield uplink!",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Drive to Bankes HQ]", "target": "exit" } ]
			},
			"bankes_server_ignore": {
				"text": "Their shielding is holding... Mack's ammo reserves are depleting rapidly.",
				"portrait_emotion": "grave",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

# --- Dynamic Event 4: Fife Security Reinforcement Intercept ---
func _trigger_decision_event_fife_intercept() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "Porter",
		"speaker_subtitle": "THE PIT // RADAR SCANNER",
		"speaker_color": "#FF6B35",
		"nodes": {
			"start": {
				"text": "Mack's in trouble! Fife Security just dispatched a heavy armor reinforcement squad from Fife HQ! If they link up with the main convoy, Mack's War-Rig is toast. Should I pay off a local gang to ambush them, or will you intercept?",
				"portrait_emotion": "warning",
				"choices": [
					{ "text": "Pay Neon Syndicate 400 Credits to ambush them. [Pay 400 C]", "target": "fife_pay_gang" },
					{ "text": "I'll drive and intercept the reinforcement limo myself!", "target": "fife_intercept_self" },
					{ "text": "Let them link up. Mack can take them.", "target": "fife_ignore" }
				]
			},
			"fife_pay_gang": {
				"text": "Credits sent! Neon Syndicate hit-squad is setting up spikes at Sector 3. Fife reinforcements delayed!",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			},
			"fife_intercept_self": {
				"text": "Good! Look for the red target blip on your overmap and side-swipe that reinforcement car!",
				"portrait_emotion": "intense",
				"choices": [ { "text": "[Hunter Mode Engaged]", "target": "exit" } ]
			},
			"fife_ignore": {
				"text": "Reinforcements connected... Mack's taking double fire on the central highway!",
				"portrait_emotion": "grave",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

# --- Dynamic Event 5: Chop Shop Emergency Repair Drop ---
func _trigger_decision_event_chop_shop() -> void:
	var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
	if not is_instance_valid(dialogue_sys): return
	var event_tree = {
		"speaker_display_name": "Chop Shop Mechanic",
		"speaker_subtitle": "GARAGE RECOVERY UNIT",
		"speaker_color": "#33FF57",
		"nodes": {
			"start": {
				"text": "Hey Banquo! I've got an automated drone dropship packed with repair nanites ready at the Chop Shop Garage. We can launch it to repair Mack mid-battle, but it requires 300 Credits for fuel & nanite canister prep. Launch it?",
				"portrait_emotion": "excited",
				"choices": [
					{ "text": "Launch nanite dropship! [Pay 300 C, Mack HP +50]", "target": "chop_drop_accept" },
					{ "text": "Save the credits. Mack's armor will hold.", "target": "chop_drop_decline" }
				]
			},
			"chop_drop_accept": {
				"text": "Nanite dropship launched! Re-supplying Mack's War-Rig on the central highway now!",
				"portrait_emotion": "satisfied",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			},
			"chop_drop_decline": {
				"text": "Roger that. Holding nanite drone in bay.",
				"portrait_emotion": "neutral",
				"choices": [ { "text": "[Return to Streets]", "target": "exit" } ]
			}
		}
	}
	dialogue_sys.start_dialogue_dict(event_tree)

var is_bankes_server_mission_active: bool = false

func _on_decision_choice_selected(_choice_index: int, target_node_id: String) -> void:
	match target_node_id:
		"lady_m_override":
			mack_current_hp = min(mack_max_hp, mack_current_hp + 35.0)
			mack_current_action = "ICE Override active! Hull repaired (+35 HP)."
			var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
			if is_instance_valid(glitch_sys):
				glitch_sys.inject_neural_instability(15.0)
		"lady_m_hold":
			mack_current_hp = max(10.0, mack_current_hp - 20.0)
			mack_current_action = "Holding ground. Hull damaged (-20 HP)."
		"norns_accept":
			is_substation_side_mission_active = true
			side_mission_active = true
			active_side_mission_name = "CUT SUBSTATION 09 POWER GRID"
			side_mission_time_left = 60.0 # 60 Seconds timer
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				neural_comms.send_message("EMERGENCY OBJECTIVE: Drive to Substation 09 in 60s to save Mack!", "TACTICAL ALERT")
		"norns_ignore":
			mack_current_hp = max(10.0, mack_current_hp - 25.0)
			mack_current_action = "Ocular phantoms active. Heavy damage (-25 HP)."
		"bankes_server_accept":
			is_bankes_server_mission_active = true
			side_mission_active = true
			active_side_mission_name = "SEVER BANKES LOGISTICS SHIELD UPLINK"
			side_mission_time_left = 60.0 # 60 Seconds timer
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				neural_comms.send_message("EMERGENCY OBJECTIVE: Enter Bankes HQ in 60s & shut down server vault!", "TACTICAL ALERT")
		"bankes_server_ignore":
			mack_current_hp = max(10.0, mack_current_hp - 30.0)
			mack_current_action = "Shielding link active. Heavy damage (-30 HP)."
		"fife_pay_gang":
			if is_instance_valid(quest_manager) and quest_manager.player_credits >= 400:
				quest_manager.player_credits -= 400
				mack_current_hp = min(mack_max_hp, mack_current_hp + 20.0)
				mack_current_action = "Syndicate gang ambushed reinforcements! (+20 HP)"
			else:
				mack_current_hp = max(10.0, mack_current_hp - 25.0)
		"fife_intercept_self":
			if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
				neural_comms.send_message("INTERCEPT OBJECTIVE: Hunt down the Fife Reinforcement limo on the city grid!", "TACTICAL ALERT")
		"fife_ignore":
			mack_current_hp = max(10.0, mack_current_hp - 30.0)
			mack_current_action = "Fife reinforcements connected! (-30 HP)"
		"chop_drop_accept":
			if is_instance_valid(quest_manager) and quest_manager.player_credits >= 300:
				quest_manager.player_credits -= 300
				mack_current_hp = min(mack_max_hp, mack_current_hp + 50.0)
				mack_current_action = "Nanite dropship deployed! War-Rig repaired (+50 HP)."
		"police_bribe_officer":
			if is_instance_valid(quest_manager) and quest_manager.player_credits >= 300:
				quest_manager.player_credits -= 300
				mack_current_hp = min(mack_max_hp, mack_current_hp + 30.0)
				mack_current_action = "Police checkpoint officer bribed! Blockade lifted (+30 HP)."
			else:
				mack_current_hp = max(10.0, mack_current_hp - 25.0)
		"police_lady_m_hack":
			mack_current_hp = min(mack_max_hp, mack_current_hp + 30.0)
			mack_current_action = "Police barrier laser grid hacked! Route cleared."
			var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
			if is_instance_valid(glitch_sys):
				glitch_sys.inject_neural_instability(12.0)
		"police_ram_through":
			mack_current_hp = max(10.0, mack_current_hp - 35.0)
			mack_current_action = "War-Rig rammed through police barricade! Heavy hull damage (-35 HP)."

	# Dispatch rumor every 55s
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

# ==============================================================================
# LIVE TELEMETRY HUD BAR UI (TOP CENTER OF SCREEN)
# ==============================================================================

# Advanced Side Terminal UI Nodes
var side_terminal_panel: PanelContainer = null
var scanner_terminal_panel: PanelContainer = null
var side_vitals_label: Label = null
var side_math_text: RichTextLabel = null
var side_cam_rect: TextureRect = null
var side_drone_btn: Button = null

var math_log_lines: Array[String] = []

func _build_telemetry_hud() -> void:
	telemetry_hud_layer = CanvasLayer.new()
	telemetry_hud_layer.name = "TelemetryHUDLayer"
	telemetry_hud_layer.layer = 15 # Below Dialogue (20), above Overmap
	add_child(telemetry_hud_layer)

	# --- 0. CRT SCANLINE & CYBERWARE HUD VIGNETTE OVERLAY ---
	var crt_overlay = ColorRect.new()
	crt_overlay.name = "CRTScanlineOverlay"
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.color = Color(0.0, 0.05, 0.08, 0.06)
	telemetry_hud_layer.add_child(crt_overlay)

	# --- 1. Top Screen Compact Telemetry Bar ---
	var top_margin = MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_top = 10
	top_margin.offset_left = 220
	top_margin.offset_right = -380
	top_margin.offset_bottom = 54
	telemetry_hud_layer.add_child(top_margin)

	telemetry_panel = PanelContainer.new()
	telemetry_panel.visible = false
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.07, 0.92)
	p_style.border_width_bottom = 2
	p_style.border_color = Color(1.0, 0.35, 0.0) # Rust Orange
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	telemetry_panel.add_theme_stylebox_override("panel", p_style)
	top_margin.add_child(telemetry_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	telemetry_panel.add_child(hbox)

	var mack_lbl = Label.new()
	mack_lbl.text = "🚜 MACK'S WAR-RIG:"
	mack_lbl.add_theme_font_size_override("font_size", 11)
	mack_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	hbox.add_child(mack_lbl)

	mack_hp_bar = ProgressBar.new()
	mack_hp_bar.custom_minimum_size = Vector2(120, 14)
	mack_hp_bar.max_value = 100.0
	mack_hp_bar.value = 100.0
	hbox.add_child(mack_hp_bar)

	mack_action_label = Label.new()
	mack_action_label.text = "Engaging convoy..."
	mack_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mack_action_label.add_theme_font_size_override("font_size", 10)
	mack_action_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	hbox.add_child(mack_action_label)

	mack_timer_label = Label.new()
	mack_timer_label.text = "05:00"
	mack_timer_label.add_theme_font_size_override("font_size", 11)
	mack_timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	hbox.add_child(mack_timer_label)

	# --- 2. Right-Hand Side Advanced Telemetry Terminal ---
	var side_margin = MarginContainer.new()
	side_margin.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_margin.offset_top = 135 # Shifted down so it never covers Overmap PiP camera feed!
	side_margin.offset_bottom = -20
	side_margin.offset_left = -360
	side_margin.offset_right = -10
	telemetry_hud_layer.add_child(side_margin)

	side_terminal_panel = PanelContainer.new()
	side_terminal_panel.visible = false
	var side_style = StyleBoxFlat.new()
	side_style.bg_color = Color(0.01, 0.03, 0.06, 0.94)
	side_style.border_width_left = 2
	side_style.border_width_top = 2
	side_style.border_width_right = 2
	side_style.border_width_bottom = 2
	side_style.border_color = Color(0.0, 0.85, 1.0) # Cyan Telemetry Border
	side_style.content_margin_left = 10
	side_style.content_margin_right = 10
	side_style.content_margin_top = 10
	side_style.content_margin_bottom = 10
	side_terminal_panel.add_theme_stylebox_override("panel", side_style)
	side_margin.add_child(side_terminal_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	side_terminal_panel.add_child(vbox)

	var term_hdr = Label.new()
	term_hdr.text = "💻 BATTLE TELEMETRY TERMINAL"
	term_hdr.add_theme_font_size_override("font_size", 12)
	term_hdr.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(term_hdr)

	# Level 1: Live Vitals Feed & Active Enemy Unit Scanner
	side_vitals_label = Label.new()
	side_vitals_label.text = "CORE TEMP: 82°C | SHIELD: 100%\nRPM: 4200 | GATLING AMMO: 88%"
	side_vitals_label.add_theme_font_size_override("font_size", 10)
	side_vitals_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(side_vitals_label)

	# --- 3. Left-Hand Side Dedicated Enemy Threat Scanner Terminal ('J' Key) ---
	var scanner_margin = MarginContainer.new()
	scanner_margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scanner_margin.offset_top = 135
	scanner_margin.offset_bottom = -140
	scanner_margin.offset_left = 10
	scanner_margin.offset_right = 310
	telemetry_hud_layer.add_child(scanner_margin)

	scanner_terminal_panel = PanelContainer.new()
	scanner_terminal_panel.visible = false
	var scan_p_style = StyleBoxFlat.new()
	scan_p_style.bg_color = Color(0.02, 0.05, 0.08, 0.94)
	scan_p_style.border_width_left = 2
	scan_p_style.border_width_top = 2
	scan_p_style.border_width_right = 2
	scan_p_style.border_width_bottom = 2
	scan_p_style.border_color = Color(1.0, 0.35, 0.0) # Rust Orange Border
	scan_p_style.content_margin_left = 10
	scan_p_style.content_margin_right = 10
	scan_p_style.content_margin_top = 10
	scan_p_style.content_margin_bottom = 10
	scanner_terminal_panel.add_theme_stylebox_override("panel", scan_p_style)
	scanner_margin.add_child(scanner_terminal_panel)

	var scan_vbox = VBoxContainer.new()
	scan_vbox.add_theme_constant_override("separation", 6)
	scanner_terminal_panel.add_child(scan_vbox)

	var scanner_hdr = Label.new()
	scanner_hdr.text = "📡 ACTIVE ENEMY THREAT SCANNER [J]"
	scanner_hdr.add_theme_font_size_override("font_size", 11)
	scanner_hdr.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	scan_vbox.add_child(scanner_hdr)

	side_enemy_scanner_label = RichTextLabel.new()
	side_enemy_scanner_label.custom_minimum_size = Vector2(0, 180)
	side_enemy_scanner_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_enemy_scanner_label.bbcode_enabled = true
	side_enemy_scanner_label.add_theme_font_size_override("normal_font_size", 10)
	scan_vbox.add_child(side_enemy_scanner_label)

	# Level 2: Detailed Math Combat Calculations Log
	side_math_text = RichTextLabel.new()
	side_math_text.custom_minimum_size = Vector2(0, 110)
	side_math_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_math_text.bbcode_enabled = true
	side_math_text.scroll_following = true
	side_math_text.add_theme_font_size_override("normal_font_size", 9)
	vbox.add_child(side_math_text)

	# Level 3: Drone Dispatch Button
	side_drone_btn = Button.new()
	side_drone_btn.text = " 🛸 LAUNCH REPAIR DRONE (150 C) "
	side_drone_btn.custom_minimum_size = Vector2(0, 32)
	side_drone_btn.pressed.connect(_on_launch_repair_drone_pressed)
	vbox.add_child(side_drone_btn)

func _on_launch_repair_drone_pressed() -> void:
	if is_instance_valid(quest_manager) and quest_manager.player_credits >= 150:
		quest_manager.player_credits -= 150
		mack_current_hp = min(mack_max_hp, mack_current_hp + 40.0)
		mack_current_action = "Repair drone deployed! (+40 HP)"
		_log_combat_math("[color=#00FF88][DRONE REPAIR] Banquo launched nanite drone -> +40 HP Restored![/color]")
		if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
			neural_comms.send_message("REPAIR DRONE DISPATCHED! War-Rig hull integrity stabilized.", "GARAGE TELEMETRY")
	else:
		_log_combat_math("[color=#FF3333][DRONE ERROR] Insufficient Cyber-Credits! Need 150 C.[/color]")

func _log_combat_math(text: String) -> void:
	math_log_lines.append(text)
	if math_log_lines.size() > 20:
		math_log_lines.remove_at(0)
	if is_instance_valid(side_math_text):
		side_math_text.text = "\n".join(math_log_lines)

var math_tick: float = 0.0

func _update_telemetry_hud() -> void:
	if not is_instance_valid(telemetry_panel):
		return
	
	if not is_battle_in_progress:
		telemetry_panel.visible = false
		if is_instance_valid(side_terminal_panel):
			side_terminal_panel.visible = false
		return
		
	telemetry_panel.visible = is_top_bar_user_toggled
	
	if is_instance_valid(mack_hp_bar):
		mack_hp_bar.max_value = mack_max_hp
		mack_hp_bar.value = mack_current_hp
	if side_mission_active:
		if is_instance_valid(mack_action_label):
			mack_action_label.text = "⚠️ MISSION: " + active_side_mission_name
		if is_instance_valid(mack_timer_label):
			var m_secs: int = max(0, int(side_mission_time_left))
			mack_timer_label.text = "⏱️ %02ds" % m_secs
	else:
		if is_instance_valid(mack_action_label):
			mack_action_label.text = mack_current_action
		var secs_left: int = max(0, int(battle_duration - battle_timer))
		var mins: int = secs_left / 60
		var secs: int = secs_left % 60
		if is_instance_valid(mack_timer_label):
			mack_timer_label.text = "%02d:%02d" % [mins, secs]

	# Check Telemetry Upgrade level from GarageManager
	var telemetry_lvl: int = 0
	var garage_mgr = get_parent().get_node_or_null("GarageManager")
	if is_instance_valid(garage_mgr) and garage_mgr.fleet.has("BANQUO_CAR"):
		telemetry_lvl = garage_mgr.fleet["BANQUO_CAR"]["upgrades"]["telemetry"].get("level", 0)

	if telemetry_lvl >= 1:
		if is_instance_valid(side_terminal_panel):
			side_terminal_panel.visible = is_side_terminal_user_toggled
		
		# Live Vitals
		var core_temp: float = 75.0 + ((1.0 - (mack_current_hp / mack_max_hp)) * 35.0)
		var rpm: int = 4000 + randi() % 800
		if is_instance_valid(side_vitals_label):
			side_vitals_label.text = "CORE TEMP: %.1f°C | HULL: %.0f/%.0f\nENGINE RPM: %d | GATLING AMMO: %.0f%%" % [
				core_temp, mack_current_hp, mack_max_hp, rpm, (mack_current_hp / mack_max_hp) * 100.0
			]

		# Synchronize 3D Screen Matrix inside The Pit Garage
		var pit_root = get_parent().get_node_or_null("IndoorSystemManager/PorterPitRoot")
		if is_instance_valid(pit_root):
			var scr1 = pit_root.get_node_or_null("PitMonitorVitalsLabel")
			if is_instance_valid(scr1):
				scr1.text = "💻 TELEMETRY VITALS\nMACK HP: %.0f / %.0f\nCORE TEMP: %.1f°C\nENGINE RPM: %d" % [mack_current_hp, mack_max_hp, core_temp, rpm]
			var scr2 = pit_root.get_node_or_null("PitMonitorTacticalLabel")
			if is_instance_valid(scr2):
				scr2.text = "🎥 LIVE TACTICAL VIDEO FEED\n" + mack_current_action + "\n[CAM UPLINK ACTIVE]"
			var scr3 = pit_root.get_node_or_null("PitMonitorMathLabel")
			if is_instance_valid(scr3):
				scr3.text = "🎲 COMBAT MATH MATRIX\n" + ("\n".join(math_log_lines.slice(-3)))

		# Live Enemy Threat Scanner
		if is_instance_valid(side_enemy_scanner_label):
			var scan_text: String = ""
			for enemy in active_enemy_units:
				scan_text += "[color=#FFCC00]%s %s[/color]\n[color=#88CCFF]   Weapon: %s | Hull: %d HP[/color]\n" % [
					enemy["icon"], enemy["name"], enemy["weapon"], enemy["hp"]
				]
			side_enemy_scanner_label.text = scan_text

		# Level 2: Detailed Dual-Roll Combat Math Feed (Mack Attacks vs Enemy Offense & Graphene Absorption)
		if telemetry_lvl >= 2:
			side_math_text.visible = true
			math_tick += 0.016
			if math_tick >= 2.2: # Faster pulse (every 2.2s) alternating Mack attacks and Enemy rolls
				math_tick = 0.0
				var is_player_turn: bool = (randi() % 2 == 0)

				var ord_lvl: int = 1
				var armor_lvl: int = 1
				if is_instance_valid(garage_mgr) and garage_mgr.fleet.has("MACK_RIG"):
					ord_lvl = garage_mgr.fleet["MACK_RIG"]["upgrades"]["ordnance"].get("level", 1)
					armor_lvl = garage_mgr.fleet["MACK_RIG"]["upgrades"]["armor"].get("level", 1)
				
				var ocular_tier: int = 1
				var cyborg_mgr = get_parent().get_node_or_null("CyborgModdingManager")
				if is_instance_valid(cyborg_mgr) and cyborg_mgr.cyberware_slots.has("ocular_scope"):
					ocular_tier = cyborg_mgr.cyberware_slots["ocular_scope"].get("tier", 1)

				if is_player_turn:
					# --- MACK REAL ATTACK ROLL & ENEMY HP DEDUCTION ---
					stat_total_rounds_fired += 1
					var atk_bonus: int = (ord_lvl - 1) * 6 + (ocular_tier - 1) * 4
					var crit_threshold: int = 15 - (ocular_tier - 1) * 2 # Crit range expands with ocular scope
					var roll_d20: int = (randi() % 20) + 1
					var total_val: int = roll_d20 + 8 + atk_bonus
					var damage_dealt: int = int((18 + atk_bonus * 2.8) + (randi() % 6))

					if roll_d20 >= crit_threshold:
						damage_dealt = int(damage_dealt * 1.85)
						stat_total_crits_landed += 1

					stat_highest_damage_dealt = max(stat_highest_damage_dealt, damage_dealt)

					if not active_enemy_units.is_empty():
						var target_enemy = active_enemy_units[0]
						target_enemy["hp"] = max(0, target_enemy["hp"] - damage_dealt)
						if roll_d20 >= crit_threshold:
							_log_combat_math("[color=#FFCC00][MACK ATK ⚔️] d20(%d)+%d=%d [CRIT!] -> %d DMG to %s! (HP: %d)[/color]" % [roll_d20, 8 + atk_bonus, total_val, damage_dealt, target_enemy["name"], target_enemy["hp"]])
						else:
							_log_combat_math("[color=#00E5FF][MACK ATK ⚔️] d20(%d)+%d=%d Hit -> %d DMG to %s! (HP: %d)[/color]" % [roll_d20, 8 + atk_bonus, total_val, damage_dealt, target_enemy["name"], target_enemy["hp"]])
						
						if target_enemy["hp"] <= 0:
							stat_enemies_destroyed += 1
							stat_tech_harvested_count += (1 + randi() % 2)
							_log_combat_math("[color=#33FF57]💥 DESTROYED! %s neutralized by Mack's Gatling Fire![/color]" % target_enemy["name"])
							active_enemy_units.remove_at(0)
					else:
						# Downtime: All wave enemies destroyed early! Mack slowly recovers hull integrity!
						mack_current_hp = min(mack_max_hp, mack_current_hp + 3.5)
						mack_current_action = "WAVE CLEARED! Mack's nanite systems repairing hull (+3.5 HP)..."
						_log_combat_math("[color=#00FF88]🌿 DOWNTIME RECOVERY: Wave cleared early! Nanites restoring War-Rig hull (+3.5 HP)[/color]")
				else:
					# --- ENEMY ATTACK ROLL & ARMOR ABSORPTION ---
					if not active_enemy_units.is_empty():
						var active_enemy = active_enemy_units.pick_random()
						var enemy_roll: int = (randi() % 20) + 1
						var enemy_raw_dmg: int = 24 + (randi() % 10)
						var armor_absorbed: int = int(enemy_raw_dmg * ((armor_lvl - 1) * 0.15 + 0.10))
						var net_dmg: int = max(4, enemy_raw_dmg - armor_absorbed)

						_log_combat_math("[color=#FF5555][ENEMY ATK 💥] %s d20(%d) -> %d DMG [/color][color=#00FF88](Armor L%d Absorbed -%d HP! Net: %d)[/color]" % [
							active_enemy["name"], enemy_roll, enemy_raw_dmg, armor_lvl, armor_absorbed, net_dmg
						])
		else:
			side_math_text.visible = false

		# Level 3: Repair Drone Dispatch Uplink
		if telemetry_lvl >= 3:
			side_drone_btn.visible = true
		else:
			side_drone_btn.visible = false
	else:
		side_terminal_panel.visible = false

func launch_grand_deployment() -> void:
	if is_battle_in_progress:
		print("[CAMPAIGN MANAGER] Battle already in progress!")
		return

	if grand_battles_today >= max_grand_battles_per_day:
		print("[CAMPAIGN MANAGER] Daily Grand Battle limit reached for Day ", current_day)
		if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
			neural_comms.send_message("DAILY LIMIT REACHED! Mack's War-Rig requires overnight engine maintenance. Drive to your Safehouse to rest and advance to Day %d." % (current_day + 1), "TACTICAL DEPLOYMENT CAP")
		close_deployment_ui()
		return

	grand_battles_today += 1
	close_deployment_ui()
	
	is_battle_in_progress = true
	battle_timer = 0.0
	last_rumor_tick = 0.0
	rumor_index = 0
	decision_1_triggered = false
	decision_2_triggered = false
	decision_3_triggered = false
	is_substation_side_mission_active = false
	
	# Reset Combat Stats & Story Clues for new engagement
	stat_highest_damage_dealt = 0
	stat_total_crits_landed = 0
	stat_enemies_destroyed = 0
	stat_total_rounds_fired = 0
	stat_tech_harvested_count = 0
	stat_story_clues_found = [
		"Cawdor Executive Encrypted Data Drive #0" + str(int(current_act) + 1),
		"Fife Logistics Manifest Fragment (Sector " + str(randi() % 9 + 1) + ")"
	]
	
	# Fetch Mack stats and Engine Cooling Level from GarageManager
	var mack_engine_lvl: int = 1
	var garage_mgr = get_parent().get_node_or_null("GarageManager")
	if is_instance_valid(garage_mgr) and garage_mgr.fleet.has("MACK_RIG"):
		mack_max_hp = garage_mgr.fleet["MACK_RIG"]["stats"].get("hull_integrity", 250.0)
		mack_engine_lvl = garage_mgr.fleet["MACK_RIG"]["upgrades"]["engine"].get("level", 1)
	else:
		mack_max_hp = 250.0

	# Story Point: Engine Thermal Limit (L1 = 300s / 5 MINS, L2 = 420s / 7 MINS, L3 = 540s / 9 MINS)
	battle_duration = 300.0 + float((mack_engine_lvl - 1) * 120)

	mack_current_hp = mack_max_hp
	mack_current_action = "Breaching highway entry vector..."
	
	var current_data: Dictionary = act_details.get(current_act, {})
	var convoy_name: String = current_data.get("target_convoy", "Corporate Vanguard")
	var mins_limit: int = int(battle_duration / 60.0)
	
	print("[CAMPAIGN MANAGER] Launching autonomous Grand Battle for: ", convoy_name, " (Max Thermal Limit: ", mins_limit, " mins)")
	_update_telemetry_hud()
	
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("WAR-RIG DISPATCHED! Mack deployed to central highway for %s. [ENGINE COOLER L%d: %d MIN MAX THERMAL LIMIT]" % [convoy_name, mack_engine_lvl, mins_limit], "LADY M // MISSION CONTROL")

func _conclude_autonomous_battle(success: bool) -> void:
	var current_data: Dictionary = act_details.get(current_act, {})
	var base_reward_c: int = current_data.get("reward_credits", 2500)
	var hp_ratio: float = clamp(mack_current_hp / mack_max_hp, 0.05, 1.0)
	
	if success:
		# --- SUCCESSFUL CONVOY PURGE (Boss Neutralized Before Engine Overheat) ---
		var salvage_mult: float = lerp(2.2, 0.8, hp_ratio)
		var final_payout: int = int(base_reward_c * salvage_mult)
		var bonus_scrap: int = int(lerp(350, 40, hp_ratio))
		
		if is_instance_valid(quest_manager):
			quest_manager.player_credits += final_payout

		var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
		if is_instance_valid(glitch_sys):
			glitch_sys.inject_neural_instability(20.0)

		_advance_campaign_act()
		_show_after_action_summary(final_payout, bonus_scrap, hp_ratio, true)
	else:
		# --- ENGINE OVERHEAT FAILURE & RETREAT PENALTY ---
		# Engine cooling limit reached before boss was destroyed -> Forced Emergency Abort!
		var penalty_repair_cost: int = 400
		var scrap_salvaged: int = 25 # Minimal emergency scrap
		
		if is_instance_valid(quest_manager):
			quest_manager.player_credits = max(0, quest_manager.player_credits - penalty_repair_cost)

		# Overheating inflicts severe neural paranoia on Mack (+35%)
		var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
		if is_instance_valid(glitch_sys):
			glitch_sys.inject_neural_instability(35.0)

		# Launch The 3 Norns Towing Recovery Quest
		_spawn_norns_recovery_quest()

		_show_after_action_summary(-penalty_repair_cost, scrap_salvaged, hp_ratio, false)

func _spawn_norns_recovery_quest() -> void:
	is_norns_recovery_active = true
	# Select North City Gate Edge (Vector3(0.0, 0.0, -280.0))
	norns_recovery_drop_pos = Vector3(0.0, 0.5, -280.0)

	# Clean existing recovery mesh
	if is_instance_valid(norns_recovery_node):
		norns_recovery_node.queue_free()

	norns_recovery_node = Node3D.new()
	norns_recovery_node.name = "NornsSmolderingWarRigDrop"
	norns_recovery_node.position = norns_recovery_drop_pos
	get_parent().add_child(norns_recovery_node)

	# Smoldering War-Rig Mesh
	var rig_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4.0, 2.5, 7.0)
	rig_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.04, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 1.0) # Deep Norns Violet Runes
	mat.emission_energy_multiplier = 4.0
	rig_inst.material_override = mat
	norns_recovery_node.add_child(rig_inst)

	# 3D Label Rune Marker
	var label = Label3D.new()
	label.text = "🔮 NORNS RECOVERY DROP-OFF\n[MACK'S SMOLDERING WAR-RIG]\nTOW TO THE PIT GARAGE FOR REPAIR"
	label.position = Vector3(0.0, 3.5, 0.0)
	label.font_size = 28
	label.pixel_size = 0.005
	label.modulate = Color(0.7, 0.1, 1.0)
	norns_recovery_node.add_child(label)

	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("🔮 THE 3 NORNS // WEIRD SISTERS DISPATCH: 'None of woman born shall harm Macbeth!' We extracted Mack from the highway. Drive to the North Gate drop-off and tow his War-Rig to The Pit Garage for emergency overhaul!", "NORNS RECOVERY QUEST")

func advance_to_next_day() -> void:
	current_day += 1
	grand_battles_today = 0
	side_missions_today = 0
	
	# Roll a new Daily Special City Event
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	active_daily_event = special_city_events[rng.randi() % special_city_events.size()]
	
	print("[CAMPAIGN MANAGER] Rested at Safehouse. Advanced to Day ", current_day, " | Today's Special Event: ", active_daily_event.get("title", ""))
	day_advanced.emit(current_day)
	
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		neural_comms.send_message("SPECIAL CITY EVENT TODAY: %s! Check your debriefing logs." % active_daily_event.get("title", ""), "CITY DISPATCH")

	_build_end_of_day_comms_hub()

# ------------------------------------------------------------------------------
# SAFEHOUSE END-OF-DAY CINEMATIC COMMS HUB MODAL
# ------------------------------------------------------------------------------
func _build_end_of_day_comms_hub() -> void:
	var comms_layer = CanvasLayer.new()
	comms_layer.name = "EndOfDayCommsHubLayer"
	comms_layer.layer = 36
	add_child(comms_layer)

	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.01, 0.02, 0.05, 0.96)
	comms_layer.add_child(bg_dim)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 160
	margin.offset_top = 70
	margin.offset_right = -160
	margin.offset_bottom = -70
	comms_layer.add_child(margin)

	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.08, 0.98)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.0, 0.85, 1.0) # Cyan Border
	p_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", p_style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var hdr = Label.new()
	hdr.text = "🌃 SAFEHOUSE DEBRIEFING // END OF DAY %d" % (current_day - 1)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(hdr)

	var sub_hdr = Label.new()
	sub_hdr.text = "INCOMING ENCRYPTED SECURE COMMS DISPATCHES"
	sub_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hdr.add_theme_font_size_override("font_size", 11)
	sub_hdr.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
	vbox.add_child(sub_hdr)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var txt = RichTextLabel.new()
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.bbcode_enabled = true
	vbox.add_child(txt)

	# Dynamic Story Debrief Text per Act & Day
	var lady_m_text: String = "Lady M: 'The corporate grid is shifting in our favor, Banquo. Tomorrow we strike another Cawdor supply convoy.'"
	var mack_text: String = "Mack: 'My neural stack is static... Banquo, did you see those shadows by Duncan Tower? They're watching us.'"
	var norns_text: String = "The 3 Norns: 'Beware the Thane of Fife! Macduff's security legions mobilize at sunrise...'"

	var event_title: String = active_daily_event.get("title", "NORMAL CITY GRID PATROL")
	var event_text: String = active_daily_event.get("text", "Lady M: 'Standard patrol routines across central grid today.'")
	var event_location: String = active_daily_event.get("location", "City Wide")
	var event_effect: String = active_daily_event.get("effect", "Standard combat rewards.")

	txt.text = """[color=#00FF88]📞 LADY M // MISSION CONTROL:[/color]
"%s"

[color=#FF5555]🧠 MACK // WAR-RIG EXECUTOR:[/color]
"%s"

[color=#AA00FF]🔮 THE 3 NORNS // WEIRD SISTERS PROPHECY:[/color]
"%s"

[color=#FFCC00]🌟 SPECIAL CITY EVENT ANNOUNCEMENT FOR DAY %d:[/color]
 [color=#00FFFF]%s[/color]
 • Intel Dispatch: [i]"%s"[/i]
 • Target Location: [color=#FF8800]%s[/color]
 • Active Modifier: [color=#00FF88]%s[/color]

[color=#FFCC00]🌅 MORNING OPERATIONAL PREP FOR DAY %d:[/color]
 • Grand Highway Battle Allowance: [color=#00FF88]1/1 Ready[/color]
 • Gang & Street Mission Allowance: [color=#00FF88]2/2 Ready[/color]
 • Mack War-Rig Thermal Engine: [color=#00FF88]100%% Cooled & Primed[/color]""" % [
		lady_m_text, mack_text, norns_text, current_day,
		event_title, event_text, event_location, event_effect, current_day
	]

	var wake_btn = Button.new()
	wake_btn.text = " 🌅 WAKE UP & BEGIN DAY %d " % current_day
	wake_btn.custom_minimum_size = Vector2(0, 44)
	wake_btn.pressed.connect(func(): comms_layer.queue_free())
	vbox.add_child(wake_btn)

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

func _show_after_action_summary(reward_credits: int, bonus_scrap: int = 100, hp_ratio: float = 0.5, is_victory: bool = true) -> void:
	var quality_desc: String = "OVERKILL VAPORIZATION (Minimal Salvage 0.8x)"
	if not is_victory:
		quality_desc = "ENGINE OVERHEAT CRITICAL FAILURE (Forced Abort & Overhaul Penalty)"
	elif hp_ratio <= 0.35:
		quality_desc = "DESPERATE NARROW VICTORY! (PRISTINE SALVAGE RETRIEVED 2.2x 🌟)"
	elif hp_ratio <= 0.70:
		quality_desc = "HARD-FOUGHT VICTORY (High-Grade Salvage 1.5x)"

	# Hide all active in-battle HUD terminals so player can focus 100% on summary sheet
	if is_instance_valid(telemetry_panel): telemetry_panel.visible = false
	if is_instance_valid(side_terminal_panel): side_terminal_panel.visible = false
	if is_instance_valid(scanner_terminal_panel): scanner_terminal_panel.visible = false

	# Lady M Comms Dispatch
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		if is_victory:
			neural_comms.send_message("LADY M // MISSION CONTROL: 'Mack's assault is complete! Convoy neutralized. Payout & salvage transferred to your account.'", "LADY M // MISSION COMPLETE")
		else:
			neural_comms.send_message("LADY M // MISSION CONTROL: 'Mack's engine reached thermal limit! The Weird Sisters extracted him to the North Gate. Check your summary report.'", "LADY M // EMERGENCY ABORT")

	_build_after_action_modal(reward_credits, bonus_scrap, quality_desc, hp_ratio, is_victory)

func _build_after_action_modal(credits_earned: int, scrap_earned: int, quality_str: String, final_hp_ratio: float, is_victory: bool = true) -> void:
	var summary_layer = CanvasLayer.new()
	summary_layer.name = "AfterActionSummaryLayer"
	summary_layer.layer = 35 # Top layer above all HUDs
	add_child(summary_layer)

	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.01, 0.03, 0.06, 0.94)
	summary_layer.add_child(bg_dim)

	# Fullscreen Centered Margin Container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 180
	margin.offset_top = 80
	margin.offset_right = -180
	margin.offset_bottom = -80
	summary_layer.add_child(margin)

	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.05, 0.09, 0.96)
	p_style.border_width_left = 3
	p_style.border_width_top = 3
	p_style.border_width_right = 3
	p_style.border_width_bottom = 3
	p_style.border_color = Color(1.0, 0.35, 0.0) # Rust Orange Border
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 20
	p_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", p_style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var hdr = Label.new()
	hdr.text = "📊 MACK'S AFTER-ACTION TACTICAL SUMMARY SHEET"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
	vbox.add_child(hdr)

	var sub_hdr = Label.new()
	sub_hdr.text = "OPERATIONAL OUTCOME: " + quality_str
	sub_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hdr.add_theme_font_size_override("font_size", 12)
	sub_hdr.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(sub_hdr)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var txt = RichTextLabel.new()
	txt.custom_minimum_size = Vector2(0, 320)
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.bbcode_enabled = true
	vbox.add_child(txt)

	var clues_str: String = "• [color=#FFCC00]Cawdor Executive Encrypted Memory Key #01[/color]"
	if stat_story_clues_found.size() > 0:
		clues_str = "• " + "\n• ".join(stat_story_clues_found)

	if is_victory:
		txt.text = """[color=#00FF88]💰 SALVAGE & FINANCIAL RETURNS:[/color]
 • Total Cyber-Credits Earned: [color=#FFCC00]+%d C[/color] (Base Payout + Inverse Salvage Multiplier)
 • Cyber-Scrap Material Salvaged: [color=#FFCC00]+%d Scrap[/color]
 • Harvested Tech Components: [color=#88CCFF]%d Advanced Modules[/color]

[color=#FF5555]⚔️ COMBAT ENGAGEMENT STATS:[/color]
 • Enemy Units Neutralized: [color=#FF9900]%d Hostiles[/color]
 • Total Gatling Rounds Fired: [color=#88CCFF]%d Rounds[/color]
 • Critical Hits Landed: [color=#FFCC00]%d Crits[/color]
 • Highest Single-Round Damage: [color=#FF3333]%d DMG[/color]
 • Final War-Rig Hull Integrity: [color=#00FF88]%.0f / 100 HP (%.0f%%)[/color]

[color=#AA00FF]🔍 RECOVERED STORY INTEL & CLUES:[/color]
 %s""" % [
			credits_earned, scrap_earned, stat_tech_harvested_count,
			stat_enemies_destroyed, stat_total_rounds_fired, stat_total_crits_landed,
			stat_highest_damage_dealt, mack_current_hp, final_hp_ratio * 100.0,
			clues_str
		]
	else:
		txt.text = """[color=#FF3333]⚠️ CRITICAL FAILURE & RETREAT PENALTY:[/color]
 • Emergency Overhaul Repair Fee: [color=#FF3333]%d C[/color] (Deducted for thermal engine recovery)
 • Emergency Scrap Salvaged: [color=#FFCC00]+%d Scrap[/color]
 • Story Note: [color=#FF9900]Mack's War-Rig Engine overheated! Upgrade Engine Cooling in The Pit to extend battle duration limit![/color]

[color=#FF5555]⚔️ COMBAT ENGAGEMENT STATS:[/color]
 • Enemy Units Neutralized: [color=#FF9900]%d Hostiles[/color] (Target Boss Survived)
 • Total Gatling Rounds Fired: [color=#88CCFF]%d Rounds[/color]
 • Critical Hits Landed: [color=#FFCC00]%d Crits[/color]
 • Highest Single-Round Damage: [color=#FF3333]%d DMG[/color]
 • Neural Instability Penalty: [color=#AA00FF]+35%% Paranoia Spike[/color]

[color=#AA00FF]🔍 RECOVERED STORY INTEL & CLUES:[/color]
 %s""" % [
			credits_earned, scrap_earned,
			stat_enemies_destroyed, stat_total_rounds_fired, stat_total_crits_landed,
			stat_highest_damage_dealt,
			clues_str
		]

	var close_btn = Button.new()
	close_btn.text = " 💾 CLOSE SUMMARY SHEET & RETURN TO GARAGE "
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.pressed.connect(func(): summary_layer.queue_free())
	vbox.add_child(close_btn)

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
	if is_instance_valid(_act_title_label):
		_act_title_label.text = act_info.get("title", "UNKNOWN ACT")
	if is_instance_valid(_act_desc_label):
		_act_desc_label.text = act_info.get("description", "")
	
	var target_name: String = act_info.get("target_convoy", "Enemy Squad")
	var hp: float = act_info.get("enemy_hp", 200.0)
	var reward: int = act_info.get("reward_credits", 1000)
	
	if is_battle_in_progress:
		var mins_left: float = (battle_duration - battle_timer) / 60.0
		if is_instance_valid(_convoy_info_label):
			_convoy_info_label.text = "TARGET: %s\nCONVOY HULL: %.0f HP\nSTATUS: ENGAGEMENT IN PROGRESS (%.1f MINS REMAINING)" % [target_name, hp, mins_left]
		if is_instance_valid(_launch_btn):
			_launch_btn.text = " ⏳ BATTLE IN PROGRESS (%.1f MINS) " % mins_left
			_launch_btn.disabled = true
	else:
		if is_instance_valid(_convoy_info_label):
			_convoy_info_label.text = "TARGET: %s\nCONVOY HULL: %.0f HP\nREWARD: %d CYBER-CREDITS" % [target_name, hp, reward]
		if is_instance_valid(_launch_btn):
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
