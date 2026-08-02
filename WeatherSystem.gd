extends Node

# ==============================================================================
# CYBERPUNK WEATHER SYSTEM (WeatherSystem.gd)
# ==============================================================================
# Controls ambient neon rain, cyber fog, and snow effects in their own modular script.
# Uses GPUParticles3D with 3D Collision matching (COLLISION_MODE_RIGID_BODY / HIDE_ON_CONTACT)
# so raindrops and snow particles realistically bounce off skyscraper roofs, street surfaces,
# and car hoods without clipping through building interiors!

enum WeatherType {
	NEON_RAIN,
	CYBER_SNOW,
	CLEAR_NEON_NIGHT
}

@export var current_weather: WeatherType = WeatherType.NEON_RAIN
@export var rain_density_amount: int = 2500
@export var snow_density_amount: int = 1500
@export var crossfade_duration_seconds: float = 2.5

# Visual particle opacity / emission ratio tracking for smooth crossfading
var target_rain_ratio: float = 1.0
var target_snow_ratio: float = 0.0
var current_rain_ratio: float = 1.0
var current_snow_ratio: float = 0.0

# Particle nodes
var rain_particles: GPUParticles3D
var rain_splash_particles: GPUParticles3D
var snow_particles: GPUParticles3D

@onready var player_car = $"../PlayerCar"

# ==============================================================================
# INITIALIZATION & PARTICLE SYSTEM CREATION
# ==============================================================================

func _ready() -> void:
	_create_rain_splash_subemitter_system()
	_create_rain_particle_system()
	_create_snow_particle_system()
	set_weather_state(current_weather)

# Listen for R key shortcut to cycle weather states
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			cycle_weather_state()

# ------------------------------------------------------------------------------
# 1A. SUB-EMITTER RAIN SPLASH SYSTEM (HIGH-VISIBILITY IMPACT BURSTS)
# ------------------------------------------------------------------------------
func _create_rain_splash_subemitter_system() -> void:
	rain_splash_particles = GPUParticles3D.new()
	rain_splash_particles.name = "RainSplashSubEmitter"
	rain_splash_particles.amount = 5000
	rain_splash_particles.lifetime = 0.6
	rain_splash_particles.speed_scale = 2.0
	
	# Sub-emitter process material (high velocity upward & outward splash arc)
	var splash_process_mat = ParticleProcessMaterial.new()
	splash_process_mat.direction = Vector3(0.0, 1.0, 0.0) # Splash upward
	splash_process_mat.spread = 85.0                      # Wide 85-degree arc
	splash_process_mat.initial_velocity_min = 8.0
	splash_process_mat.initial_velocity_max = 16.0        # High splash velocity
	splash_process_mat.gravity = Vector3(0.0, -25.0, 0.0)
	splash_process_mat.scale_min = 2.0
	splash_process_mat.scale_max = 4.5                     # Large prominent droplets

	rain_splash_particles.process_material = splash_process_mat

	# Larger, High-Glow Neon Cyan Droplet Ring Mesh
	var splash_quad_mesh = QuadMesh.new()
	splash_quad_mesh.size = Vector2(0.8, 0.8) # 80cm large splash size
	
	var splash_mat = StandardMaterial3D.new()
	splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_mat.albedo_color = Color(0.2, 0.95, 1.0, 0.95) # High opacity Cyan
	splash_mat.emission_enabled = true
	splash_mat.emission = Color(0.0, 1.0, 0.9)
	splash_mat.emission_energy_multiplier = 16.0          # Super 16.0x bloom glow
	splash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	splash_quad_mesh.material = splash_mat

	rain_splash_particles.draw_pass_1 = splash_quad_mesh
	add_child(rain_splash_particles)

# ------------------------------------------------------------------------------
# 1B. NEON RAIN STREAK SYSTEM (CHAOTIC ANGLES & ALL-ANGLE VISIBILITY)
# ------------------------------------------------------------------------------
func _create_rain_particle_system() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "NeonRainParticles"
	rain_particles.amount = rain_density_amount
	rain_particles.lifetime = 2.0
	rain_particles.preprocess = 1.0
	rain_particles.speed_scale = 1.5
	
	# Large 120m x 120m emitter box centered high above the player (Y=40m)
	rain_particles.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 80, 120))
	
	# Process Material (Chaotic Angles, Wind Turbulence & Collisions)
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(60.0, 1.0, 60.0) # 120m wide precipitation area
	
	# Slanted down-wind direction vector with chaotic 28.0-degree angle spread
	process_mat.direction = Vector3(-0.35, -1.0, 0.25)
	process_mat.spread = 28.0 # Wide angle variation so streaks never edge-disappear from top-down angles!
	process_mat.initial_velocity_min = 28.0
	process_mat.initial_velocity_max = 45.0
	process_mat.gravity = Vector3(-5.0, -12.0, 3.0) # Cross-wind turbulence
	
	# --------------------------------------------------------------------------
	# BUILDING & CAR COLLISION PREVENTION + SUB-EMITTER SPLASH
	# --------------------------------------------------------------------------
	process_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process_mat.collision_friction = 0.8
	process_mat.collision_bounce = 0.2
	
	# Random scale variation (random thickness from 0.02m up to 0.08m)
	process_mat.scale_min = 0.25
	process_mat.scale_max = 1.0
	
	process_mat.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_END
	process_mat.sub_emitter_amount_at_end = 8
	
	rain_particles.process_material = process_mat
	rain_particles.sub_emitter = rain_splash_particles.get_path()

	# Original Sleek Rain Streak Mesh (0.08m base width)
	var cyber_rain_streak_quad_mesh = QuadMesh.new()
	cyber_rain_streak_quad_mesh.size = Vector2(0.08, 0.9)
	
	var cyber_rain_streak_material = StandardMaterial3D.new()
	cyber_rain_streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyber_rain_streak_material.albedo_color = Color(0.0, 0.851, 1.0, 0.227) # Original transparent Cyan
	cyber_rain_streak_material.emission_enabled = true
	cyber_rain_streak_material.emission = Color(0.0, 0.85, 1.0)
	cyber_rain_streak_material.emission_energy_multiplier = 3.0 # Original 3.0x emission
	cyber_rain_streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	cyber_rain_streak_quad_mesh.material = cyber_rain_streak_material
	
	rain_particles.draw_pass_1 = cyber_rain_streak_quad_mesh
	add_child(rain_particles)




# ------------------------------------------------------------------------------
# 2. CYBER SNOW SYSTEM (WITH 3D BUILDING COLLISION DETECTORS)
# ------------------------------------------------------------------------------
func _create_snow_particle_system() -> void:
	snow_particles = GPUParticles3D.new()
	snow_particles.name = "CyberSnowParticles"
	snow_particles.amount = snow_density_amount
	snow_particles.lifetime = 5.0
	snow_particles.preprocess = 2.0
	
	snow_particles.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 80, 120))
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(60.0, 1.0, 60.0)
	
	# Gentle fluttering snowfall velocity
	process_mat.direction = Vector3(0.3, -1.0, 0.1)
	process_mat.spread = 20.0
	process_mat.initial_velocity_min = 4.0
	process_mat.initial_velocity_max = 8.0
	process_mat.gravity = Vector3(0.0, -2.0, 0.0)
	
	# 3D COLLISION PREVENTION FOR SNOW
	process_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process_mat.collision_friction = 1.0
	process_mat.collision_bounce = 0.0

	
	snow_particles.process_material = process_mat

	# Flake Mesh (Glowing Soft White / Cyan Flakes)
	var flake_mesh = QuadMesh.new()
	flake_mesh.size = Vector2(0.15, 0.15)
	
	var flake_mat = StandardMaterial3D.new()
	flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.85)
	flake_mat.emission_enabled = true
	flake_mat.emission = Color(0.5, 0.9, 1.0)
	flake_mat.emission_energy_multiplier = 2.0
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake_mesh.material = flake_mat

	flake_mesh.material = flake_mat
	
	snow_particles.draw_pass_1 = flake_mesh
	add_child(snow_particles)

# ==============================================================================
# PROCESS LOOP & WEATHER FOLLOW CAMERA
# ==============================================================================

func _process(delta: float) -> void:
	# Keep weather particle emitters centered high above player car position (Y=35m)
	if is_instance_valid(player_car):
		var target_pos = player_car.global_position + Vector3(0.0, 35.0, 0.0)
		if is_instance_valid(rain_particles):
			rain_particles.global_position = target_pos
		if is_instance_valid(snow_particles):
			snow_particles.global_position = target_pos

	# Check if Tactical Overmap is currently active
	var overmap_manager = $"../TacticalOvermapManager"
	if is_instance_valid(overmap_manager) and overmap_manager.is_map_active:
		return

	_apply_visual_weather_crossfade(delta)

# Smoothly interpolates particle amount ratios over crossfade_duration_seconds
func _apply_visual_weather_crossfade(delta: float) -> void:
	var lerp_speed: float = (1.0 / crossfade_duration_seconds) * delta

	# Smoothly interpolate rain emission ratio
	current_rain_ratio = move_toward(current_rain_ratio, target_rain_ratio, lerp_speed)
	if is_instance_valid(rain_particles):
		if current_rain_ratio > 0.0:
			if not rain_particles.emitting:
				rain_particles.emitting = true
			rain_particles.amount_ratio = current_rain_ratio
		else:
			rain_particles.emitting = false

	# Smoothly interpolate snow emission ratio
	current_snow_ratio = move_toward(current_snow_ratio, target_snow_ratio, lerp_speed)
	if is_instance_valid(snow_particles):
		if current_snow_ratio > 0.0:
			if not snow_particles.emitting:
				snow_particles.emitting = true
			snow_particles.amount_ratio = current_snow_ratio
		else:
			snow_particles.emitting = false

# ==============================================================================
# WEATHER STATE SWITCHER
# ==============================================================================

func set_weather_state(type: WeatherType) -> void:
	current_weather = type
	match type:
		WeatherType.NEON_RAIN:
			target_rain_ratio = 1.0
			target_snow_ratio = 0.0
			print("[WEATHER] Atmosphere transitioning to NEON RAIN...")
		WeatherType.CYBER_SNOW:
			target_rain_ratio = 0.0
			target_snow_ratio = 1.0
			print("[WEATHER] Atmosphere transitioning to CYBER SNOW...")
		WeatherType.CLEAR_NEON_NIGHT:
			target_rain_ratio = 0.0
			target_snow_ratio = 0.0
			print("[WEATHER] Atmosphere transitioning to CLEAR NEON NIGHT...")

# Cycles through all weather types (R key shortcut)
func cycle_weather_state() -> void:
	match current_weather:
		WeatherType.NEON_RAIN:
			set_weather_state(WeatherType.CYBER_SNOW)
		WeatherType.CYBER_SNOW:
			set_weather_state(WeatherType.CLEAR_NEON_NIGHT)
		WeatherType.CLEAR_NEON_NIGHT:
			set_weather_state(WeatherType.NEON_RAIN)
