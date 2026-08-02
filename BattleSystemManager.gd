extends Node

# ==============================================================================
# BATTLE SYSTEM MANAGER (BattleSystemManager.gd)
# ==============================================================================
# Orchestrates ATB combat loop, connects BattleTriggerManager signals,
# manages 3D enemy spawning in front of the vehicle, and switches camera views.

const EnemiesScript = preload("res://Enemies.gd")

@onready var trigger_manager = $"../BattleTriggerManager"
@onready var cockpit_ui = $"../CockpitDashboardUI"
@onready var player_car = $"../PlayerCar"
@onready var camera = $"../PlayerCar/Camera3D"

# Node container for spawning active 3D enemy vehicles in front of player
var enemy_3d_instance: MeshInstance3D

# Active hostile profile
var active_hostile_profile = null

# Saved top-down camera transform for restoring driving mode
var saved_topdown_camera_transform: Transform3D
var is_in_combat: bool = false

# ==============================================================================
# INITIALIZATION & SIGNAL WIRING
# ==============================================================================

func _ready() -> void:
	if trigger_manager:
		trigger_manager.combat_encounter_requested.connect(_on_combat_requested)
		trigger_manager.combat_encounter_concluded.connect(_on_combat_concluded)

	if cockpit_ui:
		cockpit_ui.gatling_attack_triggered.connect(_on_player_gatling_attack)
		cockpit_ui.ice_breaker_hack_triggered.connect(_on_player_ice_hack)
		cockpit_ui.nitrous_boost_triggered.connect(_on_player_nitrous_boost)
		cockpit_ui.overclock_lever_engaged.connect(_on_player_overclock)

# ==============================================================================
# COMBAT ENCOUNTER TRANSITION HANDLERS
# ==============================================================================

func _on_combat_requested() -> void:
	is_in_combat = true
	print("[BATTLE SYSTEM] Initiating combat encounter!")

	# Save camera transform for restoration later
	saved_topdown_camera_transform = camera.transform

	# Transition camera into cockpit view (positioned at front windshield looking forward)
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, -0.4))

	# Spawn a random hostile encounter profile
	active_hostile_profile = EnemiesScript.spawn_random_hostile_encounter()
	print("[BATTLE SYSTEM] Spawned Hostile: ", active_hostile_profile.hostile_designation)

	# Build 3D representation of hostile vehicle positioned ahead on the road
	_spawn_3d_hostile_vehicle()

	# Display first-person dashboard UI and update target readouts
	cockpit_ui.display_cockpit_hud(true)
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

func _on_combat_concluded() -> void:
	is_in_combat = false
	print("[BATTLE SYSTEM] Concluding combat encounter. Returning to city driving...")

	# Restore top-down camera transform
	camera.transform = saved_topdown_camera_transform

	# Hide dashboard HUD
	cockpit_ui.display_cockpit_hud(false)

	# Despawn 3D hostile vehicle
	if is_instance_valid(enemy_3d_instance):
		enemy_3d_instance.queue_free()

# ==============================================================================
# 3D HOSTILE VEHICLE VISUALIZER
# ==============================================================================

func _spawn_3d_hostile_vehicle() -> void:
	if is_instance_valid(enemy_3d_instance):
		enemy_3d_instance.queue_free()

	enemy_3d_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.2, 1.2, 3.5) # Enemy vehicle size
	enemy_3d_instance.mesh = box_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = active_hostile_profile.vehicle_color_tint
	mat.emission_enabled = true
	mat.emission = active_hostile_profile.vehicle_color_tint
	mat.emission_energy_multiplier = 2.0
	enemy_3d_instance.material_override = mat

	# Position enemy 12 meters directly ahead of the player car (-Z axis)
	enemy_3d_instance.position = Vector3(0.0, 0.6, -12.0)
	player_car.add_child(enemy_3d_instance)

# ==============================================================================
# COMBAT ACTION EXECUTORS
# ==============================================================================

func _on_player_gatling_attack() -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	var damage = 25.0
	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - damage)
	print("[COMBAT] Gatling Cannon struck ", active_hostile_profile.hostile_designation, " for ", damage, " HP!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	if active_hostile_profile.current_hull_integrity <= 0.0:
		print("[COMBAT] Hostile destroyed!")
		trigger_manager._toggle_combat_encounter_state()

func _on_player_ice_hack(hack_type: String) -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	var damage = 40.0
	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - damage)
	print("[COMBAT] ICE-Breaker Hack (", hack_type, ") inflicted ", damage, " tech damage!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	if active_hostile_profile.current_hull_integrity <= 0.0:
		print("[COMBAT] Hostile destroyed!")
		trigger_manager._toggle_combat_encounter_state()

func _on_player_nitrous_boost() -> void:
	print("[COMBAT] Nitrous Evasion Boost activated!")

func _on_player_overclock() -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	var damage = 70.0
	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - damage)
	print("[COMBAT] NEURAL OVERCLOCK LIMIT BREAK! Dealt ", damage, " critical damage!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	if active_hostile_profile.current_hull_integrity <= 0.0:
		print("[COMBAT] Hostile destroyed!")
		trigger_manager._toggle_combat_encounter_state()
