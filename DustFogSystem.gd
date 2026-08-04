extends Node

# ==============================================================================
# CYBERPUNK DUST & NEON FOG SYSTEM (DustFogSystem.gd)
# ==============================================================================
# Controls ambient volumetric neon fog density and floating illuminated dust specks.
# Floating dust particles utilize StandardMaterial3D lit billboard shading so they
# dynamically catch and reflect the glowing neon colors of nearby skyscraper windows!

@export var dust_speck_count: int = 1800
@export var fog_density: float = 0.015
@export var fog_height_falloff: float = 0.1

# Dust Cloud Box Volume Dimensions: Vector3(X Width, Y Height, Z Depth) around player car
@export var dust_volume_extents: Vector3 = Vector3(55.0, 22.0, 55.0)

var dust_particles: GPUParticles3D
@onready var player_car = $"../PlayerCar"

# ==============================================================================
# INITIALIZATION & FOG / DUST CREATION
# ==============================================================================

func _ready() -> void:
	_setup_volumetric_neon_fog()
	_create_floating_dust_particles()

# ------------------------------------------------------------------------------
# 1. VOLUMETRIC CYBER FOG ATMOSPHERE
# ------------------------------------------------------------------------------
func _setup_volumetric_neon_fog() -> void:
	# Access or create environment node in world scene
	var world_env: WorldEnvironment = $"../WorldEnvironment"
	if is_instance_valid(world_env) and world_env.environment:
		var env: Environment = world_env.environment
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		# Dark purple/magenta ambient neon night fog
		env.fog_light_color = Color(0.04, 0.02, 0.08)
		env.fog_density = fog_density
		env.fog_height = 0.0
		env.fog_height_density = fog_height_falloff
		
		# --- VOLUMETRIC FOG & ATMOSPHERIC HAZE (Subtle & Atmospheric) ---
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.008          # Subtle fog density so visibility stays clear
		env.volumetric_fog_albedo = Color(0.1, 0.15, 0.25)   # Darker ambient tint so lights don't blow out
		env.volumetric_fog_emission = Color(0.005, 0.01, 0.02)
		env.volumetric_fog_length = 300.0
		
		# --- ENVIRONMENT GLOW & BLOOM ---
		env.glow_enabled = true
		env.glow_intensity = 1.2
		env.glow_bloom = 0.35
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

# ------------------------------------------------------------------------------
# 2. FLOATING DUST PARTICLES (DYNAMIC LIGHT REFLECTION & BUILDING COLLISIONS)
# ------------------------------------------------------------------------------
func _create_floating_dust_particles() -> void:
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "CyberDustParticles"
	dust_particles.amount = dust_speck_count
	dust_particles.lifetime = 8.0
	dust_particles.preprocess = 4.0
	dust_particles.speed_scale = 0.5
	
	# Box volume matching dust_volume_extents surrounding the car
	dust_particles.visibility_aabb = AABB(-dust_volume_extents, dust_volume_extents * 2.0)
	
	# Particle Movement & Drift (Slow ambient wind suspension)
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = dust_volume_extents
	
	# Gentle floating turbulence motion
	process_mat.direction = Vector3(0.2, 0.5, 0.1)
	process_mat.spread = 45.0
	process_mat.initial_velocity_min = 0.2
	process_mat.initial_velocity_max = 0.8
	process_mat.gravity = Vector3(0.0, 0.05, 0.0) # Slightly floating up
	
	# --------------------------------------------------------------------------
	# 3D BUILDING WALL COLLISION & BOUNCE
	# --------------------------------------------------------------------------
	# Enables 3D physics collision sensing so floating dust specks bounce off skyscraper walls & roofs!
	process_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	process_mat.collision_friction = 0.6
	process_mat.collision_bounce = 0.4
	
	# Scale variation for fine dust particles
	process_mat.scale_min = 0.4
	process_mat.scale_max = 1.2

	dust_particles.process_material = process_mat


	# Tiny Dust Particle Quad Mesh
	var dust_quad_mesh = QuadMesh.new()
	dust_quad_mesh.size = Vector2(0.12, 0.12) # Small 12cm dust specks
	
	# Light-reactive material so particles catch ambient neon building lights!
	var dust_material = StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Subtle warm silver base color
	dust_material.albedo_color = Color(0.85, 0.9, 1.0, 0.7)
	
	# Enable lit shading mode so nearby OmniLight3D/SpotLight3D and neon emissions illuminate the dust!
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dust_material.roughness = 0.2
	dust_material.metallic = 0.1
	
	# Dynamic self-illumination tint so dust specks glow softly in the dark street
	dust_material.emission_enabled = true
	dust_material.emission = Color(0.1, 0.2, 0.35)
	dust_material.emission_energy_multiplier = 1.2
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	dust_quad_mesh.material = dust_material
	dust_particles.draw_pass_1 = dust_quad_mesh
	
	add_child(dust_particles)

# ==============================================================================
# PROCESS LOOP & DUST VOLUME FOLLOW CAR
# ==============================================================================

func _process(_delta: float) -> void:
	# Keep dust particle cloud centered around the player vehicle
	if is_instance_valid(player_car) and is_instance_valid(dust_particles):
		dust_particles.global_position = player_car.global_position + Vector3(0.0, 5.0, 0.0)
