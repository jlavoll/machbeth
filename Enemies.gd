extends Node

# ==============================================================================
# CYBERPUNK ENEMY TYPES & BEHAVIOR SPECIFICATIONS (Enemies.gd)
# ==============================================================================
# Houses statistics, attack profiles, weak points, and visual metadata for 
# hostiles loaded directly from data/enemies.json, data/weapons.json, & data/upgrades.json

# ------------------------------------------------------------------------------
# ENEMY DATA STRUCTURE (RESOURCE CLASS)
# ------------------------------------------------------------------------------
class CyberpunkHostileProfile:
	var id: String = ""
	var hostile_designation: String = "Hostile Vehicle"
	var type_label: String = "🚙 HOSTILE"
	var icon: String = "🚙"
	var max_hull_integrity: float = 100.0
	var current_hull_integrity: float = 100.0
	var armor_plating_rating: float = 15.0
	var armor_class: int = 12
	var weapon_slots: int = 2
	var upgrade_slots: int = 2
	var equipped_weapons: Array = []
	var equipped_upgrades: Array = []
	var threat_level: String = "STANDARD"
	var tactical_weak_point: String = "Front Radiator"
	var atb_recharge_rate: float = 0.25
	var current_atb_charge: float = 0.0
	var primary_attack_name: String = "Plasma Cannon"
	var attack_damage_potency: float = 25.0
	var cyber_hack_vulnerability: String = "STEERING_JAM"
	var vehicle_color_tint: Color = Color(0.9, 0.1, 0.2)

# ==============================================================================
# DATA LOADER & CATALOG DATABASE
# ==============================================================================

static var enemies_db: Dictionary = {}
static var weapons_db: Dictionary = {}
static var upgrades_db: Dictionary = {}
static var _is_loaded: bool = false

static func load_all_json_databases() -> void:
	if _is_loaded:
		return
	
	weapons_db = _load_json_file("res://data/weapons.json").get("weapons", {})
	upgrades_db = _load_json_file("res://data/upgrades.json").get("upgrades", {})
	enemies_db = _load_json_file("res://data/enemies.json").get("enemies", {})
	_is_loaded = true
	print("[ENEMIES SYSTEM] Loaded %d weapons, %d upgrades, %d enemies from JSON!" % [
		weapons_db.size(), upgrades_db.size(), enemies_db.size()
	])

static func _load_json_file(res_path: String) -> Dictionary:
	if not FileAccess.file_exists(res_path):
		printerr("[ENEMIES DATA] JSON File missing at: ", res_path)
		return {}
	var file = FileAccess.open(res_path, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data
	return {}

static func get_weapon_data(weapon_id: String) -> Dictionary:
	load_all_json_databases()
	return weapons_db.get(weapon_id, {})

static func get_upgrade_data(upgrade_id: String) -> Dictionary:
	load_all_json_databases()
	return upgrades_db.get(upgrade_id, {})

static func get_enemy_data(enemy_id: String) -> Dictionary:
	load_all_json_databases()
	return enemies_db.get(enemy_id, {})

# Factory method: Create profile from JSON ID
static func create_enemy_from_json(enemy_id: String) -> CyberpunkHostileProfile:
	load_all_json_databases()
	var raw: Dictionary = enemies_db.get(enemy_id, {})
	var hostile = CyberpunkHostileProfile.new()
	
	if raw.is_empty():
		return create_corporate_enforcer()
		
	hostile.id = raw.get("id", enemy_id)
	hostile.hostile_designation = raw.get("name", "Corporate Hostile")
	hostile.type_label = raw.get("type", "🚙 ARMORED CAR")
	hostile.icon = raw.get("icon", "🚙")
	hostile.max_hull_integrity = float(raw.get("max_hp", 100))
	hostile.current_hull_integrity = hostile.max_hull_integrity
	hostile.armor_class = int(raw.get("armor_class", 12))
	hostile.weapon_slots = int(raw.get("weapon_slots", 2))
	hostile.upgrade_slots = int(raw.get("upgrade_slots", 2))
	hostile.threat_level = raw.get("threat", "STANDARD")
	hostile.tactical_weak_point = raw.get("weakness", "Front Radiator")
	hostile.equipped_weapons = raw.get("equipped_weapons", [])
	hostile.equipped_upgrades = raw.get("equipped_upgrades", [])
	
	# Resolve primary weapon attributes from weapons.json
	if not hostile.equipped_weapons.is_empty():
		var w_id = hostile.equipped_weapons[0]
		var w_data = get_weapon_data(w_id)
		if not w_data.is_empty():
			hostile.primary_attack_name = w_data.get("name", "Plasma Cannon")
			hostile.attack_damage_potency = float(w_data.get("damage_max", 25))
	
	return hostile

# Generates a Corporate Enforcer Cruiser profile
static func create_corporate_enforcer() -> CyberpunkHostileProfile:
	return create_enemy_from_json("cawdor_interceptor_alpha")

# Generates a Heavy War-Rig Truck profile
static func create_heavy_war_rig() -> CyberpunkHostileProfile:
	return create_enemy_from_json("fife_exo_trooper_a")

# Generates a Flanking Hunter Drone profile
static func create_flanking_drone() -> CyberpunkHostileProfile:
	return create_enemy_from_json("norns_hunter_drone_01")

# ==============================================================================
# ENCOUNTER RANDOMIZER
# ==============================================================================

# Selects a random hostile to spawn when battle triggers
static func spawn_random_hostile_encounter() -> CyberpunkHostileProfile:
	load_all_json_databases()
	if enemies_db.is_empty():
		return create_corporate_enforcer()
	var keys = enemies_db.keys()
	var random_key = keys.pick_random()
	return create_enemy_from_json(random_key)
