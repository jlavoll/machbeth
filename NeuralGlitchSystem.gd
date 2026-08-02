extends Node

# ==============================================================================
# MACK'S NEURAL GLITCH & PARANOIA SYSTEM (NeuralGlitchSystem.gd)
# ==============================================================================
# Tracks Mack's mental unraveling, Glitch Gauge accumulation from overclocks
# and enemy hacks, visual dashboard scramble effects, and Banquo ghost prompts.

signal glitch_potency_changed(new_potency: float)
signal banquo_ghost_hallucination_triggered

# Glitch severity gauge (0.0 = completely sane, 100.0 = total cyber-psychosis)
var neural_glitch_potency: float = 0.0

# Rate at which glitch potency decays naturally over time
@export var passive_cooldown_rate: float = 2.0

func _process(delta: float) -> void:
	if neural_glitch_potency > 0.0:
		neural_glitch_potency = max(0.0, neural_glitch_potency - passive_cooldown_rate * delta)
		glitch_potency_changed.emit(neural_glitch_potency)

# Accumulates mental instability from heavy hacks, overclocks, or taking damage
func inject_neural_instability(amount: float) -> void:
	neural_glitch_potency = min(100.0, neural_glitch_potency + amount)
	glitch_potency_changed.emit(neural_glitch_potency)
	
	# High chance to trigger Banquo ghost visual hallucination if glitch level > 60%
	if neural_glitch_potency > 60.0:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() > 0.4:
			banquo_ghost_hallucination_triggered.emit()

func reset_neural_state() -> void:
	neural_glitch_potency = 0.0
	glitch_potency_changed.emit(0.0)
