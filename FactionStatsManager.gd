extends Node
class_name FactionStatsManager

# ==============================================================================
# FACTION & REPUTATION STATS SYSTEM (FactionStatsManager.gd)
# ==============================================================================
# Modular reputation and affinity tracking system for Cyberpunk Macbeth.
# Tracks individual NPC affinity ("does this person like you") and calculates
# aggregate Faction Standing based on individual thresholds (e.g. 10 individual
# points = +1 Faction Standing point).

signal npc_affinity_changed(npc_id: String, new_affinity: int, faction_id: String)
signal faction_standing_changed(faction_id: String, new_standing: int)

# Individual NPC Affinity Dictionary: { "npc_id": affinity_score }
var npc_affinity_db: Dictionary = {}

# Individual NPC Faction Assignment: { "npc_id": "faction_id" }
var npc_faction_map: Dictionary = {}

# Aggregate Faction Standing Dictionary: { "faction_id": standing_score }
var faction_standing_db: Dictionary = {
	"NEON_SYNDICATE": 0,    # Parking Lot Syndicate
	"BANQUO_RESISTANCE": 0, # Off-grid anti-Duncan resistance
	"PARK_STREET_CREW": 0,  # Mr. Dodgy & Park regulars
	"NIGHT_VENDORS": 0     # Food truck & street cart operators
}

# Threshold: Every 10 individual affinity points earned within a faction converts to 1 Faction Standing point
@export var affinity_points_per_faction_standing: int = 10

# ==============================================================================
# PUBLIC REPUTATION API
# ==============================================================================

## Modifies an individual NPC's affinity score and recalculates Faction Standing
func modify_npc_affinity(npc_id: String, amount: int, faction_id: String = "") -> void:
	if npc_id.is_empty():
		return

	var current_affinity: int = npc_affinity_db.get(npc_id, 0)
	var new_affinity: int = current_affinity + amount
	npc_affinity_db[npc_id] = new_affinity

	if not faction_id.is_empty():
		npc_faction_map[npc_id] = faction_id
	else:
		faction_id = npc_faction_map.get(npc_id, "NEON_SYNDICATE")

	print("[STATS] NPC '%s' Affinity changed: %d -> %d (Faction: %s)" % [npc_id, current_affinity, new_affinity, faction_id])
	emit_signal("npc_affinity_changed", npc_id, new_affinity, faction_id)

	# Recalculate aggregate Faction Standing
	_recalculate_faction_standing(faction_id)

## Returns individual NPC affinity score (0 default)
func get_npc_affinity(npc_id: String) -> int:
	return npc_affinity_db.get(npc_id, 0)

## Returns aggregate Faction Standing score
func get_faction_standing(faction_id: String) -> int:
	return faction_standing_db.get(faction_id, 0)

# ==============================================================================
# INTERNAL FACTION STANDING RECALCULATION
# ==============================================================================

func _recalculate_faction_standing(faction_id: String) -> void:
	if faction_id.is_empty():
		return

	# Sum all positive individual affinity points for NPCs belonging to this faction
	var total_faction_affinity: int = 0
	for npc_id in npc_faction_map:
		if npc_faction_map[npc_id] == faction_id:
			var aff: int = npc_affinity_db.get(npc_id, 0)
			if aff > 0:
				total_faction_affinity += aff

	# 10 individual affinity points = +1 Faction Standing point
	var old_standing: int = faction_standing_db.get(faction_id, 0)
	var new_standing: int = int(total_faction_affinity / float(affinity_points_per_faction_standing))

	if old_standing != new_standing:
		faction_standing_db[faction_id] = new_standing
		print("[STATS] Faction '%s' Standing UPGRADED: %d -> %d (Total Faction Affinity: %d)" % [faction_id, old_standing, new_standing, total_faction_affinity])
		emit_signal("faction_standing_changed", faction_id, new_standing)
		_notify_lady_m_faction_upgrade(faction_id, new_standing)

func _notify_lady_m_faction_upgrade(faction_id: String, new_standing: int) -> void:
	var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
	if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
		var faction_name: String = faction_id.replace("_", " ")
		var msg: String = "Banquo, your reputation with the %s has increased (Standing Level %d). Their network is noticing your moves." % [faction_name, new_standing]
		neural_comms.send_message(msg, "LADY M // REPUTATION MONITOR")
