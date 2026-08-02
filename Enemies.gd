extends Node

# ==============================================================================
# CYBERPUNK ENEMY TYPES & BEHAVIOR SPECIFICATIONS (Enemies.gd)
# ==============================================================================
# Houses statistics, attack profiles, weak points, and visual metadata for 
# hostiles encountered in the city (Corporate Enforcers, War-Rigs, Drones).

# ------------------------------------------------------------------------------
# ENEMY DATA STRUCTURE (RESOURCE CLASS)
# ------------------------------------------------------------------------------
class CyberpunkHostileProfile:
	var hostile_designation: String
	var max_hull_integrity: float
	var current_hull_integrity: float
	var armor_plating_rating: float
	var tactical_weak_point: String
	var atb_recharge_rate: float
	var current_atb_charge: float = 0.0
	var primary_attack_name: String
	var attack_damage_potency: float
	var cyber_hack_vulnerability: String  # e.g., "EMP_OVERLOAD", "STEERING_JAM"
	var vehicle_color_tint: Color

# ==============================================================================
# ENEMY FACTORY / CATALOG
# ==============================================================================

# Generates a Corporate Enforcer Cruiser profile
static func create_corporate_enforcer() -> CyberpunkHostileProfile:
	var hostile = CyberpunkHostileProfile.new()
	hostile.hostile_designation = "Arasaka Tactical Interceptor"
	hostile.max_hull_integrity = 120.0
	hostile.current_hull_integrity = 120.0
	hostile.armor_plating_rating = 15.0
	hostile.tactical_weak_point = "Front Grill Radiator"
	hostile.atb_recharge_rate = 0.25  # Recharges every ~4 seconds
	hostile.primary_attack_name = "Side-Swipe Plasma Ram"
	hostile.attack_damage_potency = 25.0
	hostile.cyber_hack_vulnerability = "STEERING_JAM"
	hostile.vehicle_color_tint = Color(0.9, 0.1, 0.2)  # Crimson Red
	return hostile

# Generates a Heavy War-Rig Truck profile
static func create_heavy_war_rig() -> CyberpunkHostileProfile:
	var hostile = CyberpunkHostileProfile.new()
	hostile.hostile_designation = "Militech Chrome Heavy War-Rig"
	hostile.max_hull_integrity = 300.0
	hostile.current_hull_integrity = 300.0
	hostile.armor_plating_rating = 45.0
	hostile.tactical_weak_point = "Exhaust Turbo Blower"
	hostile.atb_recharge_rate = 0.15  # Heavy slow attack every ~6.6 seconds
	hostile.primary_attack_name = "Heavy Mortar Cannon Barrage"
	hostile.attack_damage_potency = 55.0
	hostile.cyber_hack_vulnerability = "EMP_OVERLOAD"
	hostile.vehicle_color_tint = Color(0.2, 0.4, 0.2)  # Dark Tactical Olive
	return hostile

# Generates a Flanking Hunter Drone profile
static func create_flanking_drone() -> CyberpunkHostileProfile:
	var hostile = CyberpunkHostileProfile.new()
	hostile.hostile_designation = "Zaibatsu Hunter Drone Alpha"
	hostile.max_hull_integrity = 65.0
	hostile.current_hull_integrity = 65.0
	hostile.armor_plating_rating = 5.0
	hostile.tactical_weak_point = "Top Propulsion Rotor"
	hostile.atb_recharge_rate = 0.45  # Rapid attack every ~2.2 seconds
	hostile.primary_attack_name = "High-Frequency Laser Stinger"
	hostile.attack_damage_potency = 12.0
	hostile.cyber_hack_vulnerability = "DATA_LEAK"
	hostile.vehicle_color_tint = Color(0.0, 0.85, 1.0)  # Neon Cyan
	return hostile


# ==============================================================================
# ENCOUNTER RANDOMIZER
# ==============================================================================

# Selects a random hostile to spawn when battle triggers
static func spawn_random_hostile_encounter() -> CyberpunkHostileProfile:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var roll = rng.randi_range(1, 3)
	
	match roll:
		1:
			return create_corporate_enforcer()
		2:
			return create_heavy_war_rig()
		3:
			return create_flanking_drone()
		_:
			return create_corporate_enforcer()
