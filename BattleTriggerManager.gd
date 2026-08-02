extends Node

# ==============================================================================
# BATTLE TRIGGER & ENCOUNTER MANAGER
# ==============================================================================
# Listens for the 'B' key press during city driving mode to seamlessly trigger
# or terminate first-person cockpit combat encounters without touching core driving logic.

# Signal emitted when a combat encounter is initiated
signal combat_encounter_requested

# Signal emitted when a combat encounter is concluded
signal combat_encounter_concluded

# Boolean tracking whether Mack is currently engaged in active cockpit combat
var is_combat_encounter_active: bool = false

# ==============================================================================
# INPUT LISTENER LOOP
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_B:
			_toggle_combat_encounter_state()

# ==============================================================================
# STATE TOGGLE & ENCOUNTER DISPATCH
# ==============================================================================

func _toggle_combat_encounter_state() -> void:
	is_combat_encounter_active = not is_combat_encounter_active
	
	if is_combat_encounter_active:
		print("[BATTLE TRIGGER] 'B' key pressed. Transitioning to Cockpit Combat Mode...")
		combat_encounter_requested.emit()
	else:
		print("[BATTLE TRIGGER] 'B' key pressed. Exiting Cockpit Combat Mode...")
		combat_encounter_concluded.emit()
