extends Node

# ==============================================================================
# TACTICAL OVERMAP SYSTEM (TacticalOvermapManager.gd)
# ==============================================================================
# Listens for the 'M' key press to toggle an orthographic / high-altitude 
# bird's-eye tactical overmap camera overlooking the entire city.
# Renders a top-right PIP (Picture-In-Picture) live feed box of the most zoomed-in
# perspective, and preserves/restores the player's custom camera settings upon exit.

# Preloaded Orbitron font for HUD overlay text
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

@onready var player_car: CharacterBody3D = $"../PlayerCar"
@onready var main_camera: Camera3D = $"../PlayerCar/Camera3D"

# Dedicated Tactical Overmap Camera
var map_camera: Camera3D

# Glowing player marker on the map UI
var map_hud_layer: CanvasLayer
var map_overlay_panel: Control
var map_title_label: Label
var player_blip_marker: ColorRect

# --- PICTURE-IN-PICTURE (PIP) LIVE FEED COMPONENTS ---
var pip_viewport_container: SubViewportContainer
var pip_viewport: SubViewport
var pip_live_camera: Camera3D
var pip_border_frame: ReferenceRect
var pip_header_label: Label

# Saved player camera settings state before opening overmap
var saved_player_fov: float
var saved_player_camera_transform: Transform3D
var is_map_active: bool = false

# ==============================================================================
# INITIALIZATION & OVERMAP CAMERA CREATION
# ==============================================================================

func _ready() -> void:
	_setup_tactical_map_camera()
	_setup_pip_live_feed()
	_setup_map_hud_overlay()

func _setup_tactical_map_camera() -> void:
	map_camera = Camera3D.new()
	map_camera.name = "TacticalOvermapCamera"
	
	# Position high up centered over the 600m x 600m city looking straight down
	map_camera.position = Vector3(0.0, 450.0, 0.0)
	map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # Point straight down
	map_camera.fov = 75.0
	map_camera.current = false
	add_child(map_camera)

func _setup_pip_live_feed() -> void:
	# Picture-In-Picture 3D Camera attached directly to player car
	pip_live_camera = Camera3D.new()
	pip_live_camera.name = "PIPLiveFeedCamera"
	
	# Set to most zoomed-in perspective (close ground height Y=4, Z=8 behind car, pitch = -20 deg, FOV = 60)
	pip_live_camera.position = Vector3(0.0, 4.0, 8.0)
	pip_live_camera.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	pip_live_camera.fov = 60.0 # Most zoomed in setting
	player_car.add_child(pip_live_camera)

func _setup_map_hud_overlay() -> void:
	map_hud_layer = CanvasLayer.new()
	map_hud_layer.layer = 10
	map_hud_layer.visible = false
	add_child(map_hud_layer)

	map_overlay_panel = Control.new()
	map_overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_hud_layer.add_child(map_overlay_panel)

	# Overmap Header Title
	map_title_label = Label.new()
	map_title_label.position = Vector2(30, 30)
	map_title_label.text = "TACTICAL OVERMAP\n // SATELLITE UPLINK\n CITY SEED NUMBER"
	map_title_label.add_theme_font_override("font", orbitron_font)
	map_title_label.add_theme_font_size_override("font_size", 20)
	map_title_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	map_overlay_panel.add_child(map_title_label)

	# Glowing Cyan Blip marking player position on screen
	player_blip_marker = ColorRect.new()
	player_blip_marker.size = Vector2(16, 16)
	player_blip_marker.color = Color(1.0, 0.0, 0.8) # Neon Magenta Blip
	map_overlay_panel.add_child(player_blip_marker)

	# --------------------------------------------------------------------------
	# TOP RIGHT PIP LIVE FEED BOX (COMPACT DIMENSIONS: 220x140)
	# --------------------------------------------------------------------------
	pip_viewport_container = SubViewportContainer.new()
	pip_viewport_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pip_viewport_container.anchor_left = 1.0
	pip_viewport_container.anchor_right = 1.0
	pip_viewport_container.offset_left = -240
	pip_viewport_container.offset_top = 20
	pip_viewport_container.offset_right = -20
	pip_viewport_container.offset_bottom = 160
	map_overlay_panel.add_child(pip_viewport_container)

	pip_viewport = SubViewport.new()
	pip_viewport.size = Vector2i(220, 140)
	pip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pip_viewport_container.add_child(pip_viewport)

	# Border Frame for PIP Box
	pip_border_frame = ReferenceRect.new()
	pip_border_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pip_border_frame.border_color = Color(1.0, 0.0, 0.8, 0.9) # Neon Pink Border
	pip_border_frame.border_width = 2.0
	pip_viewport_container.add_child(pip_border_frame)

	# PIP Label Header
	pip_header_label = Label.new()
	pip_header_label.position = Vector2(10, 8)
	pip_header_label.text = "LIVE FEED // CLOSE-UP"
	pip_header_label.add_theme_font_override("font", orbitron_font)
	pip_header_label.add_theme_font_size_override("font_size", 9)
	pip_header_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
	pip_viewport_container.add_child(pip_header_label)

# ==============================================================================
# INPUT LISTENER & MAP TOGGLE LOOP
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_M:
			_toggle_tactical_overmap()

func _process(_delta: float) -> void:
	if is_map_active and is_instance_valid(player_car) and is_instance_valid(map_camera):
		# Keep active city seed number updated dynamically in the HUD title label
		var city_gen = $"../CityGenerator"
		var active_seed_str: String = str(city_gen.city_seed) if is_instance_valid(city_gen) else "N/A"
		if is_instance_valid(map_title_label):
			map_title_label.text = "TACTICAL OVERMAP\n // SATELLITE UPLINK\n CITY SEED: " + active_seed_str

		# Project player's 3D world position to 2D screen coordinates on satellite camera
		var screen_pos: Vector2 = map_camera.unproject_position(player_car.global_position)
		player_blip_marker.position = screen_pos - (player_blip_marker.size / 2.0)
		
		# Keep PIP camera synced to player car global position & orientation
		if is_instance_valid(pip_live_camera):
			var local_offset = Vector3(0.0, 4.0, 8.0) # Close ground height & Z distance behind car
			pip_live_camera.global_position = player_car.global_transform * local_offset
			pip_live_camera.rotation_degrees = Vector3(-20.0, player_car.rotation_degrees.y, 0.0)

func _toggle_tactical_overmap() -> void:
	is_map_active = not is_map_active

	# Access environment and dust particle nodes
	var world_env: WorldEnvironment = $"../WorldEnvironment"
	var dust_system = $"../DustFogSystem"

	if is_map_active:
		print("[OVERMAP] Opening tactical overmap. Clearing high-altitude fog & dust for satellite feed...")
		
		# SAVE player's exact camera settings before switching views
		if is_instance_valid(main_camera):
			saved_player_fov = main_camera.fov
			saved_player_camera_transform = main_camera.transform

		# Temporarily disable volumetric fog so 450m high camera view isn't darkened
		if is_instance_valid(world_env) and world_env.environment:
			world_env.environment.fog_enabled = false

		# Access weather system node
		var weather_system = $"../WeatherSystem"

		# Temporarily hide heavy dust speck particle rendering for clean satellite view
		if is_instance_valid(dust_system) and is_instance_valid(dust_system.dust_particles):
			dust_system.dust_particles.emitting = false
			dust_system.dust_particles.visible = false

		# Temporarily hide weather particle rendering during satellite view
		if is_instance_valid(weather_system):
			if "particle_nodes" in weather_system and weather_system.particle_nodes is Dictionary:
				for p_key in weather_system.particle_nodes:
					var p_node = weather_system.particle_nodes[p_key]
					if is_instance_valid(p_node):
						p_node.visible = false
			elif "rain_particles" in weather_system and is_instance_valid(weather_system.rain_particles):
				weather_system.rain_particles.visible = false

		# Assign PIP camera to PIP SubViewport world
		if is_instance_valid(pip_live_camera) and is_instance_valid(pip_viewport):
			pip_viewport.world_3d = get_viewport().world_3d
			if pip_live_camera.get_parent() != pip_viewport:
				if pip_live_camera.get_parent():
					pip_live_camera.get_parent().remove_child(pip_live_camera)
				pip_viewport.add_child(pip_live_camera)
			pip_live_camera.current = true

		map_camera.current = true
		map_hud_layer.visible = true

	else:
		print("[OVERMAP] Closing overmap. Restoring volumetric fog and driving camera...")

		# Restore volumetric fog for gameplay
		if is_instance_valid(world_env) and world_env.environment:
			world_env.environment.fog_enabled = true

		var weather_system = $"../WeatherSystem"

		# Re-enable floating dust specks around player vehicle
		if is_instance_valid(dust_system) and is_instance_valid(dust_system.dust_particles):
			dust_system.dust_particles.visible = true
			dust_system.dust_particles.emitting = true

		# Restore weather particles matching active weather state
		if is_instance_valid(weather_system):
			if "particle_nodes" in weather_system and weather_system.particle_nodes is Dictionary:
				for p_key in weather_system.particle_nodes:
					var p_node = weather_system.particle_nodes[p_key]
					if is_instance_valid(p_node):
						p_node.visible = true
			if weather_system.has_method("set_weather_state"):
				weather_system.set_weather_state(weather_system.current_weather)
		
		# RESTORE PIP camera back under TacticalOvermapManager
		if is_instance_valid(pip_live_camera):
			if pip_live_camera.get_parent() != self:
				if pip_live_camera.get_parent():
					pip_live_camera.get_parent().remove_child(pip_live_camera)
				add_child(pip_live_camera)
			pip_live_camera.current = false

		# RESTORE player's exact FOV and camera transform
		if is_instance_valid(main_camera):
			main_camera.transform = saved_player_camera_transform
			main_camera.fov = saved_player_fov
			main_camera.current = true
			if player_car.has_method("_update_camera_transform"):
				player_car._update_camera_transform()

		map_hud_layer.visible = false
