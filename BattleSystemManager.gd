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

# Signal callback for completion of targeted combat
signal targeted_combat_finished(target_profile: Dictionary, success: bool)

func _ready() -> void:
	if trigger_manager:
		trigger_manager.combat_encounter_requested.connect(_on_combat_requested)
		if trigger_manager.has_signal("combat_encounter_requested_with_target"):
			trigger_manager.combat_encounter_requested_with_target.connect(_on_targeted_combat_requested)
		trigger_manager.combat_encounter_concluded.connect(_on_combat_concluded)

	if cockpit_ui:
		cockpit_ui.gatling_attack_triggered.connect(_on_player_gatling_attack)
		cockpit_ui.ice_breaker_hack_triggered.connect(_on_player_ice_hack)
		cockpit_ui.nitrous_boost_triggered.connect(_on_player_nitrous_boost)
		cockpit_ui.overclock_lever_engaged.connect(_on_player_overclock)

func _on_targeted_combat_requested(target_profile: Dictionary) -> void:
	is_in_combat = true
	saved_topdown_camera_transform = camera.transform
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.9, -0.4))

	# Format hostile profile structure expected by combat manager
	active_hostile_profile = {
		"hostile_designation": target_profile.get("designation", "Corporate Target"),
		"current_hull_integrity": target_profile.get("hp", 100.0),
		"max_hull_integrity": target_profile.get("hp", 100.0),
		"vehicle_color_tint": target_profile.get("color", Color(1.0, 0.8, 0.1)),
		"rewards": target_profile.get("rewards", {"credits": 500, "scrap": 25})
	}

	_spawn_3d_hostile_vehicle()
	cockpit_ui.display_cockpit_hud(true)
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)


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

# Flashes 3D target mesh red/white on hit and applies camera shudder
func _flash_target_hit() -> void:
	if not is_instance_valid(enemy_3d_instance):
		return
	
	var mat = enemy_3d_instance.material_override as StandardMaterial3D
	if mat:
		var original_color = mat.albedo_color
		mat.albedo_color = Color(1.0, 1.0, 1.0) # White hit flash
		mat.emission = Color(1.0, 0.2, 0.2)
		mat.emission_energy_multiplier = 8.0
		
		# Micro camera shudder effect
		if is_instance_valid(camera):
			camera.position += Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), 0.0)
		
		# Reset color after 0.12 seconds
		var timer = get_tree().create_timer(0.12)
		timer.timeout.connect(func():
			if is_instance_valid(enemy_3d_instance) and is_instance_valid(mat):
				mat.albedo_color = original_color
				# Low HP (below 50%) adds heavy smoke/glitch glow
				if active_hostile_profile != null and active_hostile_profile.current_hull_integrity < (active_hostile_profile.max_hull_integrity * 0.5):
					mat.emission = Color(1.0, 0.1, 0.0) # Damaged orange/red smoke emission
					mat.emission_energy_multiplier = 4.0
				else:
					mat.emission = active_hostile_profile.vehicle_color_tint
					mat.emission_energy_multiplier = 2.0
			if is_instance_valid(camera):
				camera.position = Vector3(0.0, 0.9, -0.4) # Reset camera position
		)

# Spawns a high-speed 3D glowing tracer projectile that flies from player hood to target vehicle
func _spawn_projectile_effect(color: Color, speed: float, width: float) -> void:
	if not is_instance_valid(player_car) or not is_instance_valid(enemy_3d_instance):
		return

	var tracer := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, width, width * 4.0)
	tracer.mesh = box_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 10.0
	tracer.material_override = mat

	# Start position: hood level directly ahead of player
	tracer.position = Vector3(0.0, 0.4, -1.0)
	player_car.add_child(tracer)

	var target_pos := Vector3(0.0, 0.6, -12.0)
	var tween = create_tween()
	tween.tween_property(tracer, "position", target_pos, speed)
	tween.tween_callback(func():
		if is_instance_valid(tracer):
			tracer.queue_free()
	)

# ==============================================================================
# COMBAT ACTION EXECUTORS
# ==============================================================================

func _on_player_gatling_attack() -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	_spawn_projectile_effect(Color(1.0, 0.8, 0.1), 0.1, 0.15) # Fast amber Gatling bullet tracer

	var base_damage = 25.0
	var garage_mgr = get_parent().get_node_or_null("GarageManager")
	if is_instance_valid(garage_mgr):
		var veh_key: String = "BANQUO_CAR" if garage_mgr.active_fleet_selection == garage_mgr.VehicleID.BANQUO_CAR else "MACK_RIG"
		base_damage = garage_mgr.fleet[veh_key]["stats"].get("gatling_damage", 25.0)

	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - base_damage)
	print("[COMBAT] Gatling Gun fired! Dealt ", base_damage, " damage!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	_flash_target_hit()
	_check_hostile_destroyed()

func _on_player_ice_hack(hack_type: String) -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	_spawn_projectile_effect(Color(0.0, 0.85, 1.0), 0.15, 0.25) # Cyan ICE hack pulse wave

	var damage = 40.0
	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - damage)
	print("[COMBAT] ICE-Breaker Hack (", hack_type, ") inflicted ", damage, " tech damage!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	_flash_target_hit()
	_check_hostile_destroyed()

func _on_player_nitrous_boost() -> void:
	print("[COMBAT] Nitrous Evasion Boost activated!")
	if is_instance_valid(player_car):
		# Create glowing forward speed surge burst effect
		_spawn_projectile_effect(Color(1.0, 0.8, 0.0), 0.05, 0.5)
		# Forward camera surge & recoil
		if is_instance_valid(camera):
			var tween = create_tween()
			tween.tween_property(camera, "position", Vector3(0.0, 0.8, -0.7), 0.1)
			tween.tween_property(camera, "position", Vector3(0.0, 0.9, -0.4), 0.25)


func _on_player_overclock() -> void:
	if not is_in_combat or active_hostile_profile == null:
		return

	_spawn_projectile_effect(Color(1.0, 0.0, 0.8), 0.08, 0.35) # Massive Magenta Overclock beam

	var damage = 70.0
	active_hostile_profile.current_hull_integrity = max(0.0, active_hostile_profile.current_hull_integrity - damage)
	print("[COMBAT] NEURAL OVERCLOCK LIMIT BREAK! Dealt ", damage, " critical damage!")
	
	cockpit_ui.set_target_hostile_info(
		active_hostile_profile.hostile_designation,
		active_hostile_profile.current_hull_integrity,
		active_hostile_profile.max_hull_integrity
	)

	_flash_target_hit()
	_check_hostile_destroyed()


func _check_hostile_destroyed() -> void:
	if active_hostile_profile != null and active_hostile_profile.current_hull_integrity <= 0.0:
		var rewards_dict: Dictionary = {}
		if active_hostile_profile is Dictionary:
			rewards_dict = active_hostile_profile.get("rewards", {"credits": 500, "scrap": 25})
		elif "rewards" in active_hostile_profile:
			rewards_dict = active_hostile_profile.rewards
		else:
			rewards_dict = {"credits": 500, "scrap": 25}

		print("[COMBAT] Hostile destroyed! Awarding rewards: ", rewards_dict)
		_convert_target_limo_to_wreckage()
		targeted_combat_finished.emit(active_hostile_profile, true)
		trigger_manager.conclude_encounter()


# Despawns active Limo traffic car and leaves a burning, charred wreck on the city road
func _convert_target_limo_to_wreckage() -> void:
	var traffic_sys = get_parent().get_node_or_null("TrafficSystem")
	if is_instance_valid(traffic_sys):
		for car in traffic_sys.active_traffic_cars:
			if is_instance_valid(car) and car.get_meta("archetype", "") == "limo":
				# Flag car as destroyed to halt traffic processing
				car.set_meta("is_destroyed", true)
				car.set_meta("speed", 0.0)
				if car is CharacterBody3D:
					car.velocity = Vector3.ZERO
				
				# Turn the limo mesh black/charred with smoking crimson emission
				for child in car.get_children():
					if child is MeshInstance3D:
						var wreck_mat = StandardMaterial3D.new()
						wreck_mat.albedo_color = Color(0.02, 0.02, 0.02) # Charred black
						wreck_mat.emission_enabled = true
						wreck_mat.emission = Color(1.0, 0.1, 0.0) # Burning crimson data-fluid
						wreck_mat.emission_energy_multiplier = 3.0
						child.material_override = wreck_mat
					elif child is SpotLight3D:
						child.light_energy = 0.0 # Turn off headlights
				
				print("[TrafficSystem] Executive Limo halted and reduced to a burning wreck on the city grid.")
				break



