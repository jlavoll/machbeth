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
	GLITCH_STORM,
	NEBULA_DRIFT,
	SOLAR_EMBERS,
	CYAN_DUST,
	ICE_DRIFT,
	EMP_STATIC,
	CYBER_WARP,
	CLEAR_NEON_NIGHT
}

@export var current_weather: WeatherType = WeatherType.NEON_RAIN
@export var rain_density_amount: int = 2500
@export var snow_density_amount: int = 1500
@export var ember_density_amount: int = 1200
@export var crossfade_duration_seconds: float = 2.5

# Visual particle opacity / emission ratio tracking for smooth crossfading
var target_ratios: Dictionary = {}
var current_ratios: Dictionary = {}

# Particle nodes container
var particle_nodes: Dictionary = {}

# HUD Notification UI label
var hud_container: Control = null
var hud_label: Label = null
var hud_tween: Tween = null

@onready var player_car = $"../PlayerCar"

# ==============================================================================
# INITIALIZATION & PARTICLE SYSTEM CREATION
# ==============================================================================

func _ready() -> void:
	_create_all_particle_systems()
	set_weather_state(current_weather, false)

# Listen for R key shortcut to cycle weather states silently
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			cycle_weather_state()

func _show_weather_popup(_weather_name: String) -> void:
	pass # Debug text popup removed per user request

# ------------------------------------------------------------------------------
# CREATION OF ALL 8 SHOWCASE PARTICLE SYSTEMS
# ------------------------------------------------------------------------------
func _create_all_particle_systems() -> void:
	# 1. Rain Splash Sub-emitter
	var rain_splash = GPUParticles3D.new()
	rain_splash.name = "RainSplashSubEmitter"
	rain_splash.amount = 5000
	rain_splash.lifetime = 0.6
	rain_splash.speed_scale = 2.0
	
	var splash_mat = ParticleProcessMaterial.new()
	splash_mat.direction = Vector3(0.0, 1.0, 0.0)
	splash_mat.spread = 85.0
	splash_mat.initial_velocity_min = 8.0
	splash_mat.initial_velocity_max = 16.0
	splash_mat.gravity = Vector3(0.0, -25.0, 0.0)
	splash_mat.scale_min = 2.0
	splash_mat.scale_max = 4.5
	rain_splash.process_material = splash_mat

	var splash_quad = QuadMesh.new()
	splash_quad.size = Vector2(0.8, 0.8)
	var splash_m = StandardMaterial3D.new()
	splash_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_m.albedo_color = Color(0.2, 0.95, 1.0, 0.95)
	splash_m.emission_enabled = true
	splash_m.emission = Color(0.0, 1.0, 0.9)
	splash_m.emission_energy_multiplier = 16.0
	splash_m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	splash_quad.material = splash_m
	rain_splash.draw_pass_1 = splash_quad
	add_child(rain_splash)

	# Helper lambda for creating particle systems with rigid building collision & GPU noise turbulence
	var create_sys = func(sys_name: String, amount: int, lifetime: float, dir: Vector3, spread: float, vel_min: float, vel_max: float, grav: Vector3, scale_min: float, scale_max: float, particle_size: Vector2, alb_col: Color, emiss_col: Color, emiss_mult: float, is_streak: bool = false, sub_em: GPUParticles3D = null, enable_turbulence: bool = true, turb_noise_scale: float = 8.0, turb_vel: float = 3.5) -> GPUParticles3D:
		var p = GPUParticles3D.new()
		p.name = sys_name
		p.amount = amount * 2 # Doubled particle count for 2x larger area coverage
		p.lifetime = lifetime
		p.preprocess = 1.5
		# Doubled visibility AABB bounds (240m x 240m)
		p.visibility_aabb = AABB(Vector3(-120, -30, -120), Vector3(240, 100, 240))
		
		var pm = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		# Doubled emission box size from 60m x 60m to 120m x 120m (240m total width)
		pm.emission_box_extents = Vector3(120.0, 2.5, 120.0)
		pm.direction = dir
		pm.spread = spread
		pm.initial_velocity_min = vel_min
		pm.initial_velocity_max = vel_max
		pm.gravity = grav
		pm.scale_min = scale_min
		pm.scale_max = scale_max
		
		# RIGID BUILDING & STREET COLLISION
		pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		pm.collision_friction = 0.9
		pm.collision_bounce = 0.1
		
		# GPU NOISE TURBULENCE VECTOR FIELDS
		if enable_turbulence:
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = turb_vel
			pm.turbulence_noise_scale = turb_noise_scale
			pm.turbulence_noise_speed_random = 0.5
			pm.turbulence_influence_min = 0.15
			pm.turbulence_influence_max = 0.45
		
		if sub_em:
			pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_END
			pm.sub_emitter_amount_at_end = 8
			p.sub_emitter = sub_em.get_path()
			
		p.process_material = pm
		
		# PROCEDURAL SOFT RADIAL ALPHA GRADIENT TEXTURE
		var tex = GradientTexture2D.new()
		tex.width = 64
		tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		var grad = Gradient.new()
		grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		tex.gradient = grad
		
		var qm = QuadMesh.new()
		qm.size = particle_size
		var sm = StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = alb_col
		if not is_streak:
			sm.albedo_texture = tex
		sm.emission_enabled = true
		sm.emission = emiss_col
		sm.emission_energy_multiplier = emiss_mult
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = sm
		p.draw_pass_1 = qm
		
		add_child(p)
		return p

	# Register all 8 particle weather variations with custom GPU turbulence vectors & soft textures
	particle_nodes[WeatherType.NEON_RAIN] = create_sys.call("NeonRain", rain_density_amount, 2.0, Vector3(-0.35, -1.0, 0.25), 28.0, 28.0, 45.0, Vector3(-5.0, -12.0, 3.0), 0.25, 1.0, Vector2(0.08, 0.9), Color(0.0, 0.85, 1.0, 0.3), Color(0.0, 0.85, 1.0), 3.0, true, rain_splash, false)
	# REVERTED CYBER SNOW: Gentle straight snowfall matching original system (no turbulence)
	particle_nodes[WeatherType.CYBER_SNOW] = create_sys.call("CyberSnow", snow_density_amount, 5.0, Vector3(0.3, -1.0, 0.1), 20.0, 4.0, 8.0, Vector3(0.0, -2.0, 0.0), 0.5, 1.5, Vector2(0.2, 0.2), Color(0.8, 0.95, 1.0, 0.85), Color(0.5, 0.9, 1.0), 2.0, false, null, false)
	
	# REVERTED GLITCH STORM: Straight high-speed neon magenta rain streaks matching intro_scene showcase (no turbulence)
	particle_nodes[WeatherType.GLITCH_STORM] = create_sys.call("GlitchStorm", 1800, 2.0, Vector3(0.0, -1.0, 0.4), 25.0, 25.0, 40.0, Vector3(0.0, -14.0, 8.0), 0.3, 1.2, Vector2(0.1, 1.1), Color(1.0, 0.05, 0.85, 0.85), Color(1.0, 0.05, 0.85), 3.5, true, null, false)
	
	particle_nodes[WeatherType.NEBULA_DRIFT] = create_sys.call("NebulaDrift", 800, 5.0, Vector3(0.2, 0.05, 0.5), 45.0, 2.0, 6.0, Vector3(0.2, -0.5, 2.0), 0.8, 2.5, Vector2(0.35, 0.35), Color(0.6, 0.1, 0.8, 0.65), Color(0.6, 0.1, 0.8), 2.8, false, null, true, 4.0, 3.0)
	particle_nodes[WeatherType.SOLAR_EMBERS] = create_sys.call("SolarEmbers", 1200, 4.0, Vector3(0.0, -0.5, 0.8), 40.0, 3.0, 8.0, Vector3(0.0, -1.8, 4.0), 0.5, 2.0, Vector2(0.25, 0.25), Color(1.0, 0.75, 0.0, 0.75), Color(1.0, 0.5, 0.0), 3.5, false, null, true, 6.0, 4.0)
	particle_nodes[WeatherType.CYAN_DUST] = create_sys.call("CyanDust", 1600, 3.0, Vector3(0.8, -0.3, 0.8), 35.0, 12.0, 22.0, Vector3(6.0, -4.0, 6.0), 0.4, 1.8, Vector2(0.22, 0.22), Color(0.0, 1.0, 0.75, 0.7), Color(0.0, 1.0, 0.5), 2.5, false, null, true, 10.0, 6.0)
	particle_nodes[WeatherType.ICE_DRIFT] = create_sys.call("IceDrift", 1000, 4.5, Vector3(0.0, -0.8, 0.5), 22.0, 4.0, 10.0, Vector3(0.0, -3.5, 4.0), 0.5, 2.0, Vector2(0.2, 0.2), Color(0.5, 0.8, 1.0, 0.65), Color(0.5, 0.8, 1.0), 2.2, false, null, true, 5.0, 2.5)
	particle_nodes[WeatherType.EMP_STATIC] = create_sys.call("EMPStatic", 1500, 2.5, Vector3(0.0, -1.0, 0.5), 60.0, 8.0, 18.0, Vector3(0.0, -8.0, 6.0), 0.4, 2.2, Vector2(0.22, 0.22), Color(1.0, 0.1, 0.1, 0.8), Color(1.0, 0.1, 0.1), 4.0, false, null, true, 15.0, 8.0)
	
	# EXPANDED CYBER WARP: 2x larger area coverage (240m extents, 480m total width) with high velocity speed scale
	var warp_p = create_sys.call("CyberWarp", 2500, 2.0, Vector3(0.0, 0.0, 1.0), 15.0, 25.0, 50.0, Vector3(0.0, 0.0, 30.0), 0.4, 2.5, Vector2(0.16, 0.8), Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0), 4.0, true, null, false)
	if is_instance_valid(warp_p):
		var warp_pm = warp_p.process_material as ParticleProcessMaterial
		if warp_pm:
			warp_pm.emission_box_extents = Vector3(240.0, 40.0, 240.0) # 2x area coverage (480m total width)
		warp_p.visibility_aabb = AABB(Vector3(-240, -40, -240), Vector3(480, 120, 480))
	particle_nodes[WeatherType.CYBER_WARP] = warp_p

	for w_type in WeatherType.values():
		target_ratios[w_type] = 0.0
		current_ratios[w_type] = 0.0

# ==============================================================================
# PROCESS LOOP & WEATHER FOLLOW CAMERA
# ==============================================================================

func _process(delta: float) -> void:
	if is_instance_valid(player_car):
		var target_pos = player_car.global_position + Vector3(0.0, 35.0, 0.0)
		for w_type in particle_nodes.keys():
			var node = particle_nodes[w_type]
			if is_instance_valid(node):
				node.global_position = target_pos

	var overmap_manager = $"../TacticalOvermapManager"
	if is_instance_valid(overmap_manager) and overmap_manager.is_map_active:
		return

	_apply_visual_weather_crossfade(delta)

# Smoothly interpolates particle amount ratios over crossfade_duration_seconds
func _apply_visual_weather_crossfade(delta: float) -> void:
	var lerp_speed: float = (1.0 / crossfade_duration_seconds) * delta

	for w_type in particle_nodes.keys():
		var node = particle_nodes[w_type]
		if is_instance_valid(node):
			var target = target_ratios.get(w_type, 0.0)
			var current = current_ratios.get(w_type, 0.0)
			var updated = move_toward(current, target, lerp_speed)
			current_ratios[w_type] = updated
			
			if updated > 0.0:
				if not node.emitting:
					node.emitting = true
				node.amount_ratio = updated
			else:
				node.emitting = false

# ==============================================================================
# WEATHER STATE SWITCHER
# ==============================================================================

func set_weather_state(type: WeatherType, show_popup: bool = true) -> void:
	current_weather = type
	for w_type in target_ratios.keys():
		target_ratios[w_type] = 1.0 if w_type == type else 0.0
		
	var display_name: String = ""
	match type:
		WeatherType.NEON_RAIN: display_name = "Neon Rain"
		WeatherType.CYBER_SNOW: display_name = "Cyber Snow"
		WeatherType.GLITCH_STORM: display_name = "Glitch Storm"
		WeatherType.NEBULA_DRIFT: display_name = "Nebula Drift"
		WeatherType.SOLAR_EMBERS: display_name = "Solar Embers"
		WeatherType.CYAN_DUST: display_name = "Cyan Dust Storm"
		WeatherType.ICE_DRIFT: display_name = "Ice Drift"
		WeatherType.EMP_STATIC: display_name = "EMP Static"
		WeatherType.CYBER_WARP: display_name = "Cyber Warp"
		WeatherType.CLEAR_NEON_NIGHT: display_name = "Clear Neon Night"

	print("[WEATHER] Atmosphere transitioning to ", display_name, "...")
	if show_popup:
		_show_weather_popup(display_name)

# Cycles through all weather types (R key shortcut)
func cycle_weather_state() -> void:
	var next_idx = (int(current_weather) + 1) % WeatherType.values().size()
	set_weather_state(next_idx as WeatherType, true)
