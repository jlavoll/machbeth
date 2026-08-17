extends Node
class_name ParkStageEventManager

# ==============================================================================
# PARK STAGE EVENT MANAGER (ParkStageEventManager.gd)
# ==============================================================================
# Centralized registry & engine for all Cyber Park Stage events, performers,
# and audience behaviors.
# Easily expandable: add new event definitions to EVENT_REGISTRY!

signal stage_event_changed(event_id: String, event_data: Dictionary)

const EVENT_REGISTRY: Dictionary = {
	"PARK_CONCERT": {
		"id": "PARK_CONCERT",
		"title": "🎵 NEON SYNDICATE CYBER-PUNK CONCERT",
		"spotlight_preset": "CYBER_NEON",
		"performers": [
			{"name": "Lead Singer", "pos": Vector3(1.5, 0.0, 0.0), "color": Color(1.0, 0.0, 0.8), "mic": true, "robe": false, "armor": false},
			{"name": "Cyber Guitarist", "pos": Vector3(-0.5, 0.0, -3.0), "color": Color(0.0, 0.85, 1.0), "mic": false, "robe": false, "armor": false},
			{"name": "Bassist", "pos": Vector3(-0.5, 0.0, 3.0), "color": Color(1.0, 0.85, 0.0), "mic": false, "robe": false, "armor": false},
			{"name": "Synth Drummer", "pos": Vector3(-2.2, 0.0, 0.0), "color": Color(0.2, 1.0, 0.4), "mic": false, "robe": false, "armor": false}
		],
		"audience": {
			"count_min": 28,
			"count_max": 42,
			"accessory": "VISOR",
			"behavior": "ROCK_HYPED"
		}
	},
	"RELIGIOUS_RALLY": {
		"id": "RELIGIOUS_RALLY",
		"title": "⚡ CHARISMATIC CYBER-RELIGIOUS RALLY",
		"spotlight_preset": "HOLY_GOLD",
		"performers": [
			{"name": "Cyber Preacher", "pos": Vector3(1.5, 0.0, 0.0), "color": Color(1.0, 0.85, 0.0), "mic": true, "robe": true, "armor": false},
			{"name": "Quiet Disciple North", "pos": Vector3(-0.5, 0.0, -3.0), "color": Color(0.15, 0.2, 0.3), "mic": false, "robe": false, "armor": false},
			{"name": "Quiet Disciple Center", "pos": Vector3(-2.2, 0.0, 0.0), "color": Color(0.15, 0.2, 0.3), "mic": false, "robe": false, "armor": false},
			{"name": "Quiet Disciple South", "pos": Vector3(-0.5, 0.0, 3.0), "color": Color(0.15, 0.2, 0.3), "mic": false, "robe": false, "armor": false}
		],
		"audience": {
			"count_min": 28,
			"count_max": 42,
			"accessory": "HALO",
			"behavior": "CALL_AND_RESPONSE"
		}
	},
	"SHAKESPEARE_PARK": {
		"id": "SHAKESPEARE_PARK",
		"title": "🎭 SHAKESPEARE IN THE PARK",
		"spotlight_preset": "THEATRICAL_AMBER",
		"performers": [
			{"name": "Holographic Macbeth", "pos": Vector3(1.5, 0.0, 0.0), "color": Color(1.0, 0.2, 0.2), "mic": true, "robe": false, "armor": true},
			{"name": "Witch First", "pos": Vector3(-0.8, 0.0, -2.5), "color": Color(0.7, 0.1, 1.0), "mic": false, "robe": false, "armor": false},
			{"name": "Witch Second", "pos": Vector3(-2.2, 0.0, 0.0), "color": Color(0.7, 0.1, 1.0), "mic": false, "robe": false, "armor": false},
			{"name": "Witch Third", "pos": Vector3(-0.8, 0.0, 2.5), "color": Color(0.7, 0.1, 1.0), "mic": false, "robe": false, "armor": false},
			{"name": "Lurking Banquo", "pos": Vector3(0.2, 0.0, -4.8), "color": Color(0.0, 0.85, 1.0), "mic": false, "robe": false, "armor": false}
		],
		"audience": {
			"count_min": 8,
			"count_max": 14,
			"accessory": "NONE",
			"behavior": "THEATER_PATRONS"
		}
	}
}

const STAGE_EVENT_IDS: Array[String] = [
	"PARK_CONCERT",
	"RELIGIOUS_RALLY",
	"SHAKESPEARE_PARK"
]

# Returns full event configuration dictionary for any event ID (with daily cycling fallback)
static func get_event_config(event_id: String) -> Dictionary:
	if EVENT_REGISTRY.has(event_id):
		return EVENT_REGISTRY[event_id]
	return EVENT_REGISTRY["PARK_CONCERT"]

# Returns event configuration taking into account active event or daily rotation
static func get_event_config_for_day(event_id: String, day_number: int = 1) -> Dictionary:
	if EVENT_REGISTRY.has(event_id):
		return EVENT_REGISTRY[event_id]
	# If daily event is non-stage (e.g. TRAVELING_MERCHANT, FIFE_RALLY, NORNS_RITUAL), rotate stage entertainment by day
	var fallback_id: String = STAGE_EVENT_IDS[abs(day_number - 1) % STAGE_EVENT_IDS.size()]
	return EVENT_REGISTRY[fallback_id]

# Checks if the given event ID is a valid stage event
static func is_stage_event(event_id: String) -> bool:
	return EVENT_REGISTRY.has(event_id)

