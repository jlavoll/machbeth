extends Node

# ==============================================================================
# BATTLE TRIGGER & ENCOUNTER MANAGER
# ==============================================================================
# Listens for the 'B' key press during city driving mode to seamlessly trigger
# or terminate first-person cockpit combat encounters without touching core driving logic.

# Signal emitted when a combat encounter is initiated
signal combat_encounter_requested

# Signal emitted when a specific targeted combat encounter is initiated (e.g. Limo Intercept)
signal combat_encounter_requested_with_target(target_profile: Dictionary)

# Signal emitted when a combat encounter is concluded
signal combat_encounter_concluded

# Boolean tracking whether Mack/Banquo is currently engaged in active cockpit combat
var is_combat_encounter_active: bool = false

func trigger_targeted_encounter(target_profile: Dictionary) -> void:
	if not is_combat_encounter_active:
		is_combat_encounter_active = true
		print("[BATTLE TRIGGER] Targeted encounter triggered: ", target_profile.get("designation", "Target"))
		combat_encounter_requested_with_target.emit(target_profile)

func conclude_encounter() -> void:
	if is_combat_encounter_active:
		is_combat_encounter_active = false
		print("[BATTLE TRIGGER] Encounter concluded.")
		combat_encounter_concluded.emit()


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
