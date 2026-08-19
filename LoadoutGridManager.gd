extends Node
class_name LoadoutGridManager

# ==============================================================================
# DUAL LOADOUT GRID SYSTEM (LoadoutGridManager.gd)
# ==============================================================================
# Central data authority managing equipment slots, inventory, and stats
# for both MACK (Cyborg Implants) and his VEHICLE (Hardpoints & Upgrades).

signal loadout_changed(target_grid: String, slot_id: String, item_id: String)
signal loadout_ui_toggled(is_open: bool)

# ------------------------------------------------------------------------------
# 1. ITEM CATALOG REGISTRY
# ------------------------------------------------------------------------------

var item_catalog: Dictionary = {
	# --- MACK CYBORG ITEMS ---
	"neural_core_l1": {
		"id": "neural_core_l1", "name": "Overclock Core Alpha", "slot": "neural_core",
		"icon": "🧠", "tier": 1, "dps_bonus": 15.0, "shield_bonus": 0.0, "glitch_heat": 10.0,
		"description": "Standard high-frequency overclock processor. +15 Overclock DPS."
	},
	"neural_core_l2": {
		"id": "neural_core_l2", "name": "Overclock Core Mk II", "slot": "neural_core",
		"icon": "🧠", "tier": 2, "dps_bonus": 35.0, "shield_bonus": 0.0, "glitch_heat": 20.0,
		"description": "Overclocked military processor. +35 Overclock DPS, +20% Glitch Heat."
	},
	"cerberus_core": {
		"id": "cerberus_core", "name": "Cerberus Overclock Prototype", "slot": "neural_core",
		"icon": "🔥", "tier": 3, "dps_bonus": 85.0, "shield_bonus": 0.0, "glitch_heat": 45.0,
		"description": "Untested black-market Cawdor prototype. +85 DPS, massive +45% Glitch buildup!"
	},
	"ocular_scope_l1": {
		"id": "ocular_scope_l1", "name": "Tactical HUD Optics", "slot": "ocular_scope",
		"icon": "👁️", "tier": 1, "dps_bonus": 5.0, "hack_speed_bonus": 20.0, "glitch_heat": 5.0,
		"description": "Heads-up tactical targeting oculars. +20% ICE-Breaker recharge speed."
	},
	"ocular_scope_l2": {
		"id": "ocular_scope_l2", "name": "Thermal Threat Scope", "slot": "ocular_scope",
		"icon": "👁️", "tier": 2, "dps_bonus": 12.0, "hack_speed_bonus": 45.0, "glitch_heat": 12.0,
		"description": "Multi-spectrum targeting optics. +45% ICE-Breaker speed, +12 DPS."
	},
	"gatling_standard": {
		"id": "gatling_standard", "name": "Twin 20mm Gatling Cannon", "slot": "primary_weapon",
		"icon": "🔫", "tier": 1, "dps_bonus": 25.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "High cyclic rate motorized kinetic cannon. +25 Base DPS."
	},
	"plasma_lance": {
		"id": "plasma_lance", "name": "Hyper-Thermal Plasma Lance", "slot": "primary_weapon",
		"icon": "⚡", "tier": 2, "dps_bonus": 55.0, "shield_bonus": 0.0, "glitch_heat": 15.0,
		"description": "Super-heated ionized gas stream. Melts heavy vehicle armor. +55 DPS."
	},
	"rail_burst": {
		"id": "rail_burst", "name": "Magnetic Rail-Burst Array", "slot": "primary_weapon",
		"icon": "💥", "tier": 3, "dps_bonus": 90.0, "shield_bonus": 0.0, "glitch_heat": 25.0,
		"description": "Electromagnetic slug driver with explosive armor penetration. +90 DPS."
	},
	"smart_sidearm": {
		"id": "smart_sidearm", "name": "Auto-Tracking Smart Pistol", "slot": "secondary_weapon",
		"icon": "🎯", "tier": 1, "dps_bonus": 12.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "Gyrojet micro-munitions with trajectory homing. +12 DPS."
	},
	"emp_blaster": {
		"id": "emp_blaster", "name": "EMP Disruptor Sidearm", "slot": "secondary_weapon",
		"icon": "⚡", "tier": 2, "dps_bonus": 28.0, "hack_speed_bonus": 25.0, "glitch_heat": 8.0,
		"description": "Short-range electromagnetic pulse charge that scrambles enemy ECM."
	},
	"graphene_weave": {
		"id": "graphene_weave", "name": "Sub-Dermal Graphene Weave", "slot": "subdermal_armor",
		"icon": "🛡️", "tier": 1, "dps_bonus": 0.0, "shield_bonus": 40.0, "glitch_heat": 5.0,
		"description": "Flexible carbon-lattice under-skin mesh. +40 Hull Shielding."
	},
	"nanite_mesh": {
		"id": "nanite_mesh", "name": "Self-Healing Nanite Mesh", "slot": "subdermal_armor",
		"icon": "🛡️", "tier": 2, "dps_bonus": 0.0, "shield_bonus": 95.0, "glitch_heat": 15.0,
		"description": "Bio-synthetic nanite layer that absorbs kinetic shock. +95 Shielding."
	},

	# --- VEHICLE HARDPOINT ITEMS ---
	"autocannon_turret": {
		"id": "autocannon_turret", "name": "Roof-Mounted Twin Autocannon", "slot": "roof_turret",
		"icon": "🚀", "tier": 1, "dps_bonus": 30.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "Pivoting 360-degree turret with armor-piercing rounds. +30 DPS."
	},
	"flak_burst_pod": {
		"id": "flak_burst_pod", "name": "Flak Cannon Shrapnel Pod", "slot": "roof_turret",
		"icon": "🚀", "tier": 2, "dps_bonus": 60.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "High-spread explosive flak shells that shred enemy drones and limos. +60 DPS."
	},
	"reinforced_plating": {
		"id": "reinforced_plating", "name": "Heavy Composite Armor Plates", "slot": "armor_chassis",
		"icon": "🚗", "tier": 1, "dps_bonus": 0.0, "shield_bonus": 60.0, "glitch_heat": 0.0,
		"description": "Bolt-on tungsten carbide side skirts. +60 Vehicle Hull Integrity."
	},
	"reactive_skin": {
		"id": "reactive_skin", "name": "Explosive Reactive Armor Skin", "slot": "armor_chassis",
		"icon": "🚗", "tier": 2, "dps_bonus": 0.0, "shield_bonus": 140.0, "glitch_heat": 0.0,
		"description": "Active deflection tiles that neutralize incoming ramming damage. +140 Hull."
	},
	"nitro_injector_l1": {
		"id": "nitro_injector_l1", "name": "Liquid Nitrous Injector", "slot": "nitro_boost",
		"icon": "⚡", "tier": 1, "speed_bonus": 8.0, "atb_speed_bonus": 15.0, "glitch_heat": 0.0,
		"description": "Direct manifold fuel injection. +8 m/s Top Speed, +15% ATB refill."
	},
	"overdrive_turbo": {
		"id": "overdrive_turbo", "name": "Supercharged Twin-Turbo Overdrive", "slot": "nitro_boost",
		"icon": "⚡", "tier": 2, "speed_bonus": 16.0, "atb_speed_bonus": 35.0, "glitch_heat": 0.0,
		"description": "Dual ceramic turbine blowers. +16 m/s Top Speed, +35% ATB refill."
	},
	"ecm_scrambler_l1": {
		"id": "ecm_scrambler_l1", "name": "Radio Frequency ECM Scrambler", "slot": "ecm_scrambler",
		"icon": "📡", "tier": 1, "hack_speed_bonus": 20.0, "shield_bonus": 20.0, "glitch_heat": 0.0,
		"description": "Disrupts hostile missile lock and slows enemy ATB attacks by 20%."
	},
	"emp_disruptor_pod": {
		"id": "emp_disruptor_pod", "name": "Wide-Spectrum EMP Emitter Pod", "slot": "ecm_scrambler",
		"icon": "📡", "tier": 2, "hack_speed_bonus": 50.0, "shield_bonus": 45.0, "glitch_heat": 0.0,
		"description": "Active localized EMP aura that neutralizes hostile electronics. +50% Hack Speed."
	},
	# --- BANQUO OPERATIVE ITEMS ---
	"tactical_trenchcoat": {
		"id": "tactical_trenchcoat", "name": "Reinforced Tactical Trenchcoat", "slot": "banquo_outfit",
		"icon": "🧥", "tier": 1, "shield_bonus": 30.0, "dps_bonus": 0.0, "glitch_heat": 0.0,
		"description": "Charcoal ballistic-weave coat. +30 Banquo on-foot armor."
	},
	"stealth_nanoshroud": {
		"id": "stealth_nanoshroud", "name": "Active Camo Nanoshroud", "slot": "banquo_outfit",
		"icon": "🧥", "tier": 2, "shield_bonus": 65.0, "hack_speed_bonus": 25.0, "glitch_heat": 0.0,
		"description": "Photonic-bending tactical shroud. +65 Armor, +25% Infiltration Speed."
	},
	"kinetic_vibroblade": {
		"id": "kinetic_vibroblade", "name": "High-Frequency Vibro-Blade", "slot": "banquo_melee",
		"icon": "🗡️", "tier": 1, "dps_bonus": 20.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "Ultrasonic carbon steel blade for swift melee takedowns. +20 Melee DPS."
	},
	"mono_molecular_katana": {
		"id": "mono_molecular_katana", "name": "Mono-Molecular Edge Katana", "slot": "banquo_melee",
		"icon": "⚔️", "tier": 2, "dps_bonus": 48.0, "shield_bonus": 0.0, "glitch_heat": 0.0,
		"description": "Atomic-scale sharp edge that severs cybernetic armor plates. +48 Melee DPS."
	},
	"street_cyberdeck": {
		"id": "street_cyberdeck", "name": "Custom Street Cyberdeck", "slot": "banquo_deck",
		"icon": "💻", "tier": 1, "hack_speed_bonus": 30.0, "dps_bonus": 5.0, "glitch_heat": 0.0,
		"description": "Portable terminal for door bypasses and security overrides. +30% Hack Speed."
	},
	"ghost_monocular": {
		"id": "ghost_monocular", "name": "Ghost-Frequency Monocular", "slot": "banquo_optics",
		"icon": "🧐", "tier": 1, "hack_speed_bonus": 20.0, "shield_bonus": 10.0, "glitch_heat": 0.0,
		"description": "Detects hidden cameras and patrolling drones through walls."
	}
}

# ------------------------------------------------------------------------------
# 2. CURRENT EQUIPPED LOADOUT SLOTS
# ------------------------------------------------------------------------------

var mack_equipped: Dictionary = {
	"neural_core": "neural_core_l1",
	"ocular_scope": "ocular_scope_l1",
	"primary_weapon": "gatling_standard",
	"secondary_weapon": "smart_sidearm",
	"subdermal_armor": "graphene_weave"
}

var vehicle_equipped: Dictionary = {
	"roof_turret": "autocannon_turret",
	"armor_chassis": "reinforced_plating",
	"nitro_boost": "nitro_injector_l1",
	"ecm_scrambler": "ecm_scrambler_l1"
}

var banquo_equipped: Dictionary = {
	"banquo_outfit": "tactical_trenchcoat",
	"banquo_melee": "kinetic_vibroblade",
	"banquo_deck": "street_cyberdeck",
	"banquo_optics": "ghost_monocular"
}

# Unlocked inventory pool
var inventory_pool: Array[String] = [
	"neural_core_l1", "neural_core_l2", "cerberus_core",
	"ocular_scope_l1", "ocular_scope_l2",
	"gatling_standard", "plasma_lance", "rail_burst",
	"smart_sidearm", "emp_blaster",
	"graphene_weave", "nanite_mesh",
	"autocannon_turret", "flak_burst_pod",
	"reinforced_plating", "reactive_skin",
	"nitro_injector_l1", "overdrive_turbo",
	"ecm_scrambler_l1", "emp_disruptor_pod",
	"tactical_trenchcoat", "stealth_nanoshroud",
	"kinetic_vibroblade", "mono_molecular_katana",
	"street_cyberdeck", "ghost_monocular"
]

# ------------------------------------------------------------------------------
# 3. PUBLIC API METHODS
# ------------------------------------------------------------------------------

func equip_item(target_grid: String, slot_id: String, item_id: String) -> bool:
	if item_id == "" or item_id == "EMPTY":
		# Unequip / clear slot
		if target_grid == "MACK":
			mack_equipped.erase(slot_id)
			loadout_changed.emit("MACK", slot_id, "")
			_sync_mack_stats()
			return true
		elif target_grid == "VEHICLE":
			vehicle_equipped.erase(slot_id)
			loadout_changed.emit("VEHICLE", slot_id, "")
			_sync_vehicle_stats()
			return true
		elif target_grid == "BANQUO":
			banquo_equipped.erase(slot_id)
			loadout_changed.emit("BANQUO", slot_id, "")
			return true
		return false

	if not item_catalog.has(item_id):
		return false
	var item_data: Dictionary = item_catalog[item_id]
	if item_data.get("slot", "") != slot_id:
		return false

	if target_grid == "MACK":
		mack_equipped[slot_id] = item_id
		loadout_changed.emit("MACK", slot_id, item_id)
		_sync_mack_stats()
		return true
	elif target_grid == "VEHICLE":
		vehicle_equipped[slot_id] = item_id
		loadout_changed.emit("VEHICLE", slot_id, item_id)
		_sync_vehicle_stats()
		return true
	elif target_grid == "BANQUO":
		banquo_equipped[slot_id] = item_id
		loadout_changed.emit("BANQUO", slot_id, item_id)
		return true
	return false

func get_equipped_item(target_grid: String, slot_id: String) -> Dictionary:
	var item_id: String = ""
	if target_grid == "MACK":
		item_id = mack_equipped.get(slot_id, "")
	elif target_grid == "VEHICLE":
		item_id = vehicle_equipped.get(slot_id, "")
	elif target_grid == "BANQUO":
		item_id = banquo_equipped.get(slot_id, "")
	return item_catalog.get(item_id, {})

func get_items_for_slot(slot_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in inventory_pool:
		if item_catalog.has(item_id):
			var item = item_catalog[item_id]
			if item.get("slot", "") == slot_id:
				result.append(item)
	return result

func calculate_total_dps() -> float:
	var dps: float = 25.0 # Base DPS
	for slot in mack_equipped:
		var item = item_catalog.get(mack_equipped[slot], {})
		dps += item.get("dps_bonus", 0.0)
	for slot in vehicle_equipped:
		var item = item_catalog.get(vehicle_equipped[slot], {})
		dps += item.get("dps_bonus", 0.0)
	return dps

func calculate_total_shielding() -> float:
	var shield: float = 100.0 # Base Shield
	for slot in mack_equipped:
		var item = item_catalog.get(mack_equipped[slot], {})
		shield += item.get("shield_bonus", 0.0)
	for slot in vehicle_equipped:
		var item = item_catalog.get(vehicle_equipped[slot], {})
		shield += item.get("shield_bonus", 0.0)
	return shield

func calculate_total_glitch_heat() -> float:
	var heat: float = 0.0
	for slot in mack_equipped:
		var item = item_catalog.get(mack_equipped[slot], {})
		heat += item.get("glitch_heat", 0.0)
	return heat

func calculate_mack_power_threat() -> Dictionary:
	# Real-time power rating based on current cyborg implants and war-rig chassis
	var dps: float = calculate_total_dps()
	var shield: float = calculate_total_shielding()
	var glitch: float = calculate_total_glitch_heat()
	
	var equipped_count: int = mack_equipped.size() + vehicle_equipped.size()
	var total_slots: int = 9
	var free_slots: int = total_slots - equipped_count
	
	# Threat index formula
	var raw_power: float = (dps * 1.8) + (shield * 0.9) - (glitch * 0.5)
	var threat_rating: int = int(round(raw_power))
	
	var threat_class: String = "NOMAD RECON"
	var threat_color: String = "#00ffcc"
	if threat_rating >= 450:
		threat_class = "WAR-RIG TITAN // S-RANK"
		threat_color = "#ff0055"
	elif threat_rating >= 320:
		threat_class = "ASSAULT JUGGERNAUT // A-RANK"
		threat_color = "#ff7700"
	elif threat_rating >= 220:
		threat_class = "CYBERNETIC ENFORCER // B-RANK"
		threat_color = "#ffcc00"
	elif threat_rating >= 140:
		threat_class = "COMBAT OPERATIVE // C-RANK"
		threat_color = "#00ffcc"
	
	return {
		"rating": threat_rating,
		"class": threat_class,
		"color": threat_color,
		"dps": dps,
		"shield": shield,
		"glitch": glitch,
		"equipped_count": equipped_count,
		"free_slots": free_slots,
		"total_slots": total_slots
	}

func _sync_mack_stats() -> void:
	var glitch_sys = get_parent().get_node_or_null("NeuralGlitchSystem")
	if is_instance_valid(glitch_sys):
		glitch_sys.glitch_potency_baseline = calculate_total_glitch_heat()

func _sync_vehicle_stats() -> void:
	var player_car = get_parent().get_node_or_null("PlayerCar")
	if is_instance_valid(player_car):
		var boost_item = item_catalog.get(vehicle_equipped.get("nitro_boost", ""), {})
		var extra_speed: float = boost_item.get("speed_bonus", 0.0)
		player_car.boost_max_speed = 38.0 + extra_speed
