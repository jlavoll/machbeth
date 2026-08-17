extends Node
class_name UnifiedInventoryManager

# ==============================================================================
# UNIFIED INVENTORY & PIT SHOP SYSTEM (UnifiedInventoryManager.gd)
# ==============================================================================
# Manages three distinct inventory pools across Cyberpunk Macbeth:
#   1. BANQUO_STASH: Carried consumables, loot, data chips, and trunk items.
#   2. MACK_LOCKER: Cybernetic weapons, implants, and vehicle hardpoints owned by Mack.
#   3. PIT_SHOP: Porter's black-market store catalog available for purchase.

signal inventory_updated(inventory_type: String)
signal consumable_used(item_id: String, effect_desc: String)
signal shop_transaction_completed(item_id: String, is_buy: bool, credits_cost: int, scrap_cost: int)

# ------------------------------------------------------------------------------
# 1. COMPREHENSIVE ITEM & CONSUMABLE CATALOG
# ------------------------------------------------------------------------------

var master_catalog: Dictionary = {
	# --- CONSUMABLES & TOOLS (Banquo's Stash) ---
	"repair_nanokit": {
		"id": "repair_nanokit", "name": "Nano-Repair Injector", "category": "CONSUMABLE",
		"icon": "🧪", "buy_credits": 250, "buy_scrap": 15, "sell_credits": 100, "scrap_yield": 8,
		"effect": "REPAIR_HULL", "potency": 50.0,
		"description": "Instantly patches hull breaches and restores +50 Vehicle Integrity."
	},
	"glitch_dampener_stim": {
		"id": "glitch_dampener_stim", "name": "Neural Glitch Dampener Stim", "category": "CONSUMABLE",
		"icon": "💉", "buy_credits": 300, "buy_scrap": 20, "sell_credits": 120, "scrap_yield": 10,
		"effect": "PURGE_GLITCH", "potency": 30.0,
		"description": "Calms Mack's neural overclock stack, reducing Glitch Paranoia by -30%."
	},
	"emp_grenade_pack": {
		"id": "emp_grenade_pack", "name": "EMP Pulse Grenade Pack", "category": "CONSUMABLE",
		"icon": "💣", "buy_credits": 400, "buy_scrap": 25, "sell_credits": 160, "scrap_yield": 12,
		"effect": "EMP_BLAST", "potency": 75.0,
		"description": "Discharges a localized EMP that disables enemy weapons for 6 seconds."
	},
	"syndicate_data_shard": {
		"id": "syndicate_data_shard", "name": "Encrypted Syndicate Data Shard", "category": "LOOT",
		"icon": "💾", "buy_credits": 0, "buy_scrap": 0, "sell_credits": 450, "scrap_yield": 15,
		"effect": "INTEL_VALUE", "potency": 0.0,
		"description": "Encrypted corporate payroll telemetry salvaged from highway transports."
	},

	# --- MACK'S CYBERWARE & WEAPONS ---
	"neural_core_l1": {
		"id": "neural_core_l1", "name": "Overclock Core Alpha", "category": "CYBERWARE",
		"icon": "🧠", "buy_credits": 600, "buy_scrap": 30, "sell_credits": 250, "scrap_yield": 20,
		"slot": "neural_core", "tier": 1, "dps_bonus": 15.0,
		"description": "+15 Overclock Limit Break DPS."
	},
	"neural_core_l2": {
		"id": "neural_core_l2", "name": "Overclock Core Mk II", "category": "CYBERWARE",
		"icon": "🧠", "buy_credits": 1400, "buy_scrap": 60, "sell_credits": 600, "scrap_yield": 40,
		"slot": "neural_core", "tier": 2, "dps_bonus": 35.0,
		"description": "+35 Overclock DPS, +20% Glitch Heat."
	},
	"cerberus_core": {
		"id": "cerberus_core", "name": "Cerberus Overclock Prototype", "category": "CYBERWARE",
		"icon": "🔥", "buy_credits": 3500, "buy_scrap": 120, "sell_credits": 1500, "scrap_yield": 80,
		"slot": "neural_core", "tier": 3, "dps_bonus": 85.0,
		"description": "Untested black-market prototype. +85 DPS, +45% Paranoia Heat!"
	},
	"ocular_scope_l1": {
		"id": "ocular_scope_l1", "name": "Tactical HUD Optics", "category": "CYBERWARE",
		"icon": "👁️", "buy_credits": 500, "buy_scrap": 25, "sell_credits": 200, "scrap_yield": 15,
		"slot": "ocular_scope", "tier": 1, "hack_speed_bonus": 20.0,
		"description": "+20% ICE-Breaker hack recharge rate."
	},
	"ocular_scope_l2": {
		"id": "ocular_scope_l2", "name": "Thermal Threat Scope", "category": "CYBERWARE",
		"icon": "👁️", "buy_credits": 1200, "buy_scrap": 50, "sell_credits": 500, "scrap_yield": 35,
		"slot": "ocular_scope", "tier": 2, "hack_speed_bonus": 45.0,
		"description": "+45% ICE-Breaker speed, +12 DPS."
	},
	"gatling_standard": {
		"id": "gatling_standard", "name": "Twin 20mm Gatling Cannon", "category": "CYBERWARE",
		"icon": "🔫", "buy_credits": 750, "buy_scrap": 35, "sell_credits": 300, "scrap_yield": 25,
		"slot": "primary_weapon", "tier": 1, "dps_bonus": 25.0,
		"description": "High cyclic rate kinetic cannon. +25 Base DPS."
	},
	"plasma_lance": {
		"id": "plasma_lance", "name": "Hyper-Thermal Plasma Lance", "category": "CYBERWARE",
		"icon": "⚡", "buy_credits": 1800, "buy_scrap": 75, "sell_credits": 750, "scrap_yield": 50,
		"slot": "primary_weapon", "tier": 2, "dps_bonus": 55.0,
		"description": "Super-heated ionized gas stream. +55 DPS."
	},
	"rail_burst": {
		"id": "rail_burst", "name": "Magnetic Rail-Burst Array", "category": "CYBERWARE",
		"icon": "💥", "buy_credits": 3200, "buy_scrap": 110, "sell_credits": 1400, "scrap_yield": 75,
		"slot": "primary_weapon", "tier": 3, "dps_bonus": 90.0,
		"description": "Electromagnetic slug driver. +90 DPS."
	},
	"smart_sidearm": {
		"id": "smart_sidearm", "name": "Auto-Tracking Smart Pistol", "category": "CYBERWARE",
		"icon": "🎯", "buy_credits": 450, "buy_scrap": 20, "sell_credits": 180, "scrap_yield": 15,
		"slot": "secondary_weapon", "tier": 1, "dps_bonus": 12.0,
		"description": "Gyrojet micro-munitions with trajectory homing. +12 DPS."
	},
	"emp_blaster": {
		"id": "emp_blaster", "name": "EMP Disruptor Sidearm", "category": "CYBERWARE",
		"icon": "⚡", "buy_credits": 1100, "buy_scrap": 45, "sell_credits": 450, "scrap_yield": 30,
		"slot": "secondary_weapon", "tier": 2, "dps_bonus": 28.0,
		"description": "Scrambles enemy electronics on sidearm impact."
	},
	"graphene_weave": {
		"id": "graphene_weave", "name": "Sub-Dermal Graphene Weave", "category": "CYBERWARE",
		"icon": "🛡️", "buy_credits": 650, "buy_scrap": 30, "sell_credits": 260, "scrap_yield": 20,
		"slot": "subdermal_armor", "tier": 1, "shield_bonus": 40.0,
		"description": "Flexible carbon-lattice mesh. +40 Hull Absorption."
	},
	"nanite_mesh": {
		"id": "nanite_mesh", "name": "Self-Healing Nanite Mesh", "category": "CYBERWARE",
		"icon": "🛡️", "buy_credits": 1900, "buy_scrap": 80, "sell_credits": 800, "scrap_yield": 55,
		"slot": "subdermal_armor", "tier": 2, "shield_bonus": 95.0,
		"description": "Bio-synthetic nanite layer. +95 Shielding."
	},

	# --- VEHICLE HARDPOINTS ---
	"autocannon_turret": {
		"id": "autocannon_turret", "name": "Roof-Mounted Twin Autocannon", "category": "VEHICLE_MOD",
		"icon": "🚀", "buy_credits": 850, "buy_scrap": 40, "sell_credits": 350, "scrap_yield": 25,
		"slot": "roof_turret", "tier": 1, "dps_bonus": 30.0,
		"description": "360-degree turret. +30 DPS."
	},
	"flak_burst_pod": {
		"id": "flak_burst_pod", "name": "Flak Cannon Shrapnel Pod", "category": "VEHICLE_MOD",
		"icon": "🚀", "buy_credits": 2100, "buy_scrap": 85, "sell_credits": 900, "scrap_yield": 60,
		"slot": "roof_turret", "tier": 2, "dps_bonus": 60.0,
		"description": "Explosive flak shells. +60 DPS."
	},
	"reinforced_plating": {
		"id": "reinforced_plating", "name": "Heavy Composite Armor Plates", "category": "VEHICLE_MOD",
		"icon": "🚗", "buy_credits": 800, "buy_scrap": 40, "sell_credits": 320, "scrap_yield": 25,
		"slot": "armor_chassis", "tier": 1, "shield_bonus": 60.0,
		"description": "+60 Vehicle Hull Integrity."
	},
	"reactive_skin": {
		"id": "reactive_skin", "name": "Explosive Reactive Armor Skin", "category": "VEHICLE_MOD",
		"icon": "🚗", "buy_credits": 2300, "buy_scrap": 95, "sell_credits": 1000, "scrap_yield": 70,
		"slot": "armor_chassis", "tier": 2, "shield_bonus": 140.0,
		"description": "Active deflection tiles. +140 Hull."
	},
	"nitro_injector_l1": {
		"id": "nitro_injector_l1", "name": "Liquid Nitrous Injector", "category": "VEHICLE_MOD",
		"icon": "⚡", "buy_credits": 700, "buy_scrap": 30, "sell_credits": 280, "scrap_yield": 20,
		"slot": "nitro_boost", "tier": 1, "speed_bonus": 8.0,
		"description": "+8 m/s Top Boost Speed."
	},
	"overdrive_turbo": {
		"id": "overdrive_turbo", "name": "Supercharged Twin-Turbo Overdrive", "category": "VEHICLE_MOD",
		"icon": "⚡", "buy_credits": 2000, "buy_scrap": 85, "sell_credits": 850, "scrap_yield": 55,
		"slot": "nitro_boost", "tier": 2, "speed_bonus": 16.0,
		"description": "+16 m/s Top Boost Speed."
	},
	"ecm_scrambler_l1": {
		"id": "ecm_scrambler_l1", "name": "Radio Frequency ECM Scrambler", "category": "VEHICLE_MOD",
		"icon": "📡", "buy_credits": 600, "buy_scrap": 25, "sell_credits": 240, "scrap_yield": 18,
		"slot": "ecm_scrambler", "tier": 1, "shield_bonus": 20.0,
		"description": "+20% Hack Speed & Defense."
	},
	"emp_disruptor_pod": {
		"id": "emp_disruptor_pod", "name": "Wide-Spectrum EMP Emitter Pod", "category": "VEHICLE_MOD",
		"icon": "📡", "buy_credits": 1900, "buy_scrap": 80, "sell_credits": 800, "scrap_yield": 50,
		"slot": "ecm_scrambler", "tier": 2, "shield_bonus": 45.0,
		"description": "+50% Hack Speed, +45 Shielding."
	}
}

# ------------------------------------------------------------------------------
# 2. ACTIVE INVENTORY STORAGE
# ------------------------------------------------------------------------------

# Banquo's Personal / Vehicle Trunk Stash: { "item_id": quantity }
var banquo_stash: Dictionary = {
	"repair_nanokit": 3,
	"glitch_dampener_stim": 2,
	"emp_grenade_pack": 1,
	"syndicate_data_shard": 2
}

# Mack's Locker (Cyberware & weapon parts owned): Array of item IDs
var mack_locker: Array[String] = [
	"neural_core_l1", "neural_core_l2",
	"ocular_scope_l1", "ocular_scope_l2",
	"gatling_standard", "plasma_lance",
	"smart_sidearm", "emp_blaster",
	"graphene_weave", "nanite_mesh",
	"autocannon_turret", "flak_burst_pod",
	"reinforced_plating", "reactive_skin",
	"nitro_injector_l1", "overdrive_turbo",
	"ecm_scrambler_l1", "emp_disruptor_pod"
]

# The Pit Shop Stock (Items Porter has for sale)
var pit_shop_stock: Array[String] = [
	"repair_nanokit", "glitch_dampener_stim", "emp_grenade_pack",
	"neural_core_l2", "cerberus_core",
	"ocular_scope_l2", "plasma_lance", "rail_burst",
	"emp_blaster", "nanite_mesh",
	"flak_burst_pod", "reactive_skin",
	"overdrive_turbo", "emp_disruptor_pod"
]

# Resource currencies
var player_scrap_salvage: int = 150

# ------------------------------------------------------------------------------
# 3. TRANSACTION & INVENTORY MANAGEMENT API
# ------------------------------------------------------------------------------

func buy_item_from_pit(item_id: String) -> bool:
	if not master_catalog.has(item_id):
		return false
	var item = master_catalog[item_id]
	var cost_c: int = item.get("buy_credits", 500)
	var cost_s: int = item.get("buy_scrap", 20)

	# Check Familiarity Discount from Porter (Up to 20% discount at Level 5 Trust)
	var stats_mgr = get_parent().get_node_or_null("FactionStatsManager")
	var fam_level: int = 1
	if is_instance_valid(stats_mgr) and stats_mgr.has_method("get_npc_familiarity"):
		fam_level = stats_mgr.get_npc_familiarity("Porter")
	var discount: float = (fam_level - 1) * 0.05 # 5% per level above 1 (max 20%)
	cost_c = int(cost_c * (1.0 - discount))

	var quest_mgr = get_parent().get_node_or_null("QuestManager")
	if not is_instance_valid(quest_mgr) or quest_mgr.player_credits < cost_c:
		_notify_error("INSUFFICIENT CREDITS // NEED %d CR" % cost_c)
		return false

	if player_scrap_salvage < cost_s:
		_notify_error("INSUFFICIENT SCRAP SALVAGE // NEED %d SCRAP" % cost_s)
		return false

	# Deduct costs
	quest_mgr.player_credits -= cost_c
	player_scrap_salvage -= cost_s

	# Award Porter Affinity for doing business
	if is_instance_valid(stats_mgr) and stats_mgr.has_method("modify_npc_affinity"):
		stats_mgr.modify_npc_affinity("Porter", 2, "NEON_SYNDICATE")

	# Add to appropriate inventory
	if item.get("category", "") == "CONSUMABLE":
		banquo_stash[item_id] = banquo_stash.get(item_id, 0) + 1
		inventory_updated.emit("BANQUO_STASH")
	else:
		mack_locker.append(item_id)
		# Also ensure LoadoutGridManager has it in inventory pool
		var loadout_mgr = get_parent().get_node_or_null("LoadoutGridManager") as LoadoutGridManager
		if is_instance_valid(loadout_mgr) and not loadout_mgr.inventory_pool.has(item_id):
			loadout_mgr.inventory_pool.append(item_id)
		inventory_updated.emit("MACK_LOCKER")

	shop_transaction_completed.emit(item_id, true, cost_c, cost_s)
	_notify_success("PURCHASED %s (-%d CR, -%d SCRAP)" % [item.get("name", ""), cost_c, cost_s])
	return true


func sell_item_to_pit(item_id: String, source_inv: String = "BANQUO_STASH") -> bool:
	if not master_catalog.has(item_id):
		return false
	var item = master_catalog[item_id]
	var sell_val: int = item.get("sell_credits", 50)

	if source_inv == "BANQUO_STASH":
		if not banquo_stash.has(item_id) or banquo_stash[item_id] <= 0:
			return false
		banquo_stash[item_id] -= 1
		if banquo_stash[item_id] <= 0:
			banquo_stash.erase(item_id)
		inventory_updated.emit("BANQUO_STASH")
	elif source_inv == "MACK_LOCKER":
		if not mack_locker.has(item_id):
			return false
		mack_locker.erase(item_id)
		inventory_updated.emit("MACK_LOCKER")

	var quest_mgr = get_parent().get_node_or_null("QuestManager")
	if is_instance_valid(quest_mgr):
		quest_mgr.player_credits += sell_val

	shop_transaction_completed.emit(item_id, false, sell_val, 0)
	_notify_success("SOLD %s (+%d CR)" % [item.get("name", ""), sell_val])
	return true

func dismantle_for_scrap(item_id: String, source_inv: String = "BANQUO_STASH") -> bool:
	if not master_catalog.has(item_id):
		return false
	var item = master_catalog[item_id]
	var yield_scrap: int = item.get("scrap_yield", 10)

	if source_inv == "BANQUO_STASH":
		if not banquo_stash.has(item_id) or banquo_stash[item_id] <= 0:
			return false
		banquo_stash[item_id] -= 1
		if banquo_stash[item_id] <= 0:
			banquo_stash.erase(item_id)
		inventory_updated.emit("BANQUO_STASH")
	elif source_inv == "MACK_LOCKER":
		if not mack_locker.has(item_id):
			return false
		mack_locker.erase(item_id)
		inventory_updated.emit("MACK_LOCKER")

	player_scrap_salvage += yield_scrap
	_notify_success("DISMANTLED %s (+%d SCRAP SALVAGE)" % [item.get("name", ""), yield_scrap])
	return true

# ------------------------------------------------------------------------------
# 4. QUICK-USE CONSUMABLES (HUD HOTKEYS H & J)
# ------------------------------------------------------------------------------

func use_consumable(item_id: String) -> bool:
	if not banquo_stash.has(item_id) or banquo_stash[item_id] <= 0:
		_notify_error("OUT OF STOCK: %s" % item_id.replace("_", " ").to_upper())
		return false

	var item = master_catalog.get(item_id, {})
	var effect = item.get("effect", "")
	var potency = item.get("potency", 0.0)

	match effect:
		"REPAIR_HULL":
			var player_car = get_parent().get_node_or_null("PlayerCar")
			if is_instance_valid(player_car):
				# Repair hull
				pass
			_notify_success("🧪 INJECTED NANO-REPAIR: +%.0f Hull Integrity Restored!" % potency)
		"PURGE_GLITCH":
			var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
			if is_instance_valid(glitch_sys):
				glitch_sys.neural_glitch_potency = maxf(0.0, glitch_sys.neural_glitch_potency - potency)
			_notify_success("💉 NEURAL STIM ADMINISTERED: Glitch Paranoia dropped by -%.0f%%!" % potency)

		"EMP_BLAST":
			_notify_success("💣 EMP PULSE DETONATED: Hostile Electronics Jammed!")

	banquo_stash[item_id] -= 1
	if banquo_stash[item_id] <= 0:
		banquo_stash.erase(item_id)

	consumable_used.emit(item_id, effect)
	inventory_updated.emit("BANQUO_STASH")
	return true

func _notify_success(msg: String) -> void:
	var comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(comms):
		comms.send_message(msg, "INVENTORY // THE PIT LOGISTICS")

func _notify_error(msg: String) -> void:
	var comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(comms):
		comms.send_message("⚠️ " + msg, "TRANSACTION REJECTED")
