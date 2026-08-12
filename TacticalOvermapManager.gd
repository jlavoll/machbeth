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
var delivery_blip_marker: ColorRect
var hq_blip_marker: ColorRect
var hideout_blip_marker: ColorRect
var lady_m_blip_marker: ColorRect
var chop_shop_blip_marker: ColorRect
var pit_blip_marker: ColorRect
var norns_blip_marker: ColorRect
var fife_blip_marker: ColorRect
var bankes_blip_marker: ColorRect
var substation_blip_marker: ColorRect
var parked_car_blip_marker: ColorRect
var poi_legend_container: Control = null
var delivery_target_pos: Vector3 = Vector3.ZERO
var has_active_delivery: bool = false

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

	# --------------------------------------------------------------------------
	# MAP BLIP MARKERS (Discrete, compact dimensions: 10-12px)
	# --------------------------------------------------------------------------
	# Player Position Blip (Magenta)
	player_blip_marker = ColorRect.new()
	player_blip_marker.size = Vector2(10, 10)
	player_blip_marker.color = Color(1.0, 0.0, 0.8) # Neon Magenta Blip
	map_overlay_panel.add_child(player_blip_marker)

	# Delivery Destination Blip (Gold / Yellow)
	delivery_blip_marker = ColorRect.new()
	delivery_blip_marker.name = "DeliveryBlipMarker"
	delivery_blip_marker.size = Vector2(12, 12)
	delivery_blip_marker.color = Color(1.0, 0.85, 0.0, 0.95) # Radiant Gold
	delivery_blip_marker.visible = false
	map_overlay_panel.add_child(delivery_blip_marker)

	# Duncan Dynamics HQ Building Blip (Cyan)
	hq_blip_marker = ColorRect.new()
	hq_blip_marker.name = "HQBlipMarker"
	hq_blip_marker.size = Vector2(12, 12)
	hq_blip_marker.color = Color(0.0, 1.0, 0.85, 0.95) # Cyan
	map_overlay_panel.add_child(hq_blip_marker)

	# Mack's Hideout Blip (Amber)
	hideout_blip_marker = ColorRect.new()
	hideout_blip_marker.size = Vector2(12, 12)
	hideout_blip_marker.color = Color(1.0, 0.5, 0.0) # Amber
	map_overlay_panel.add_child(hideout_blip_marker)

	# Lady M Lair Blip (Magenta)
	lady_m_blip_marker = ColorRect.new()
	lady_m_blip_marker.size = Vector2(12, 12)
	lady_m_blip_marker.color = Color(1.0, 0.0, 0.8) # Magenta
	map_overlay_panel.add_child(lady_m_blip_marker)

	# Chop Shop Blip (Green)
	chop_shop_blip_marker = ColorRect.new()
	chop_shop_blip_marker.size = Vector2(12, 12)
	chop_shop_blip_marker.color = Color(0.2, 1.0, 0.3) # Green
	map_overlay_panel.add_child(chop_shop_blip_marker)

	# Porter's Pit Blip (Dark Rust Orange)
	pit_blip_marker = ColorRect.new()
	pit_blip_marker.size = Vector2(12, 12)
	pit_blip_marker.color = Color(1.0, 0.3, 0.0) # Dark Rust Orange
	map_overlay_panel.add_child(pit_blip_marker)

	# Norns AI Blip (Violet)
	norns_blip_marker = ColorRect.new()
	norns_blip_marker.size = Vector2(12, 12)
	norns_blip_marker.color = Color(0.7, 0.1, 1.0) # Deep Violet
	map_overlay_panel.add_child(norns_blip_marker)

	# Fife HQ Blip (Steel Blue)
	fife_blip_marker = ColorRect.new()
	fife_blip_marker.size = Vector2(12, 12)
	fife_blip_marker.color = Color(0.1, 0.5, 1.0) # Steel Blue
	map_overlay_panel.add_child(fife_blip_marker)

	# Bankes Logistics Blip (Industrial Yellow)
	bankes_blip_marker = ColorRect.new()
	bankes_blip_marker.size = Vector2(12, 12)
	bankes_blip_marker.color = Color(0.9, 0.7, 0.1) # Industrial Yellow
	map_overlay_panel.add_child(bankes_blip_marker)

	# Substation 09 Blip (High Voltage Yellow)
	substation_blip_marker = ColorRect.new()
	substation_blip_marker.size = Vector2(12, 12)
	substation_blip_marker.color = Color(1.0, 0.9, 0.0) # High Voltage Yellow
	map_overlay_panel.add_child(substation_blip_marker)

	# Parked Car Blip Marker (Amber Orange)
	parked_car_blip_marker = ColorRect.new()
	parked_car_blip_marker.name = "ParkedCarBlipMarker"
	parked_car_blip_marker.size = Vector2(10, 10)
	parked_car_blip_marker.color = Color(1.0, 0.5, 0.0, 0.95) # Radiant Amber Orange
	parked_car_blip_marker.visible = false
	map_overlay_panel.add_child(parked_car_blip_marker)

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
	pip_border_frame.size = Vector2(220, 140)
	pip_border_frame.border_color = Color(0.0, 0.85, 1.0, 0.8) # Glowing cyan border frame
	pip_border_frame.border_width = 1.5
	pip_border_frame.editor_only = false
	pip_viewport_container.add_child(pip_border_frame)

	# Header label over PIP live feed
	pip_header_label = Label.new()
	pip_header_label.position = Vector2(8, 6)
	pip_header_label.text = "LIVE FEED // CLOSE-UP"
	pip_header_label.add_theme_font_override("font", orbitron_font)
	pip_header_label.add_theme_font_size_override("font_size", 9)
	pip_header_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
	pip_viewport_container.add_child(pip_header_label)

	# --------------------------------------------------------------------------
	# DYNAMIC POINTS OF INTEREST (POI) LEGEND PANEL (Positioned under PIP feed)
	# --------------------------------------------------------------------------
	_setup_poi_legend_panel(orbitron_font)

func _setup_poi_legend_panel(font: Font) -> void:
	poi_legend_container = PanelContainer.new()
	poi_legend_container.name = "POILegendPanel"
	poi_legend_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	poi_legend_container.anchor_left = 1.0
	poi_legend_container.anchor_right = 1.0
	poi_legend_container.offset_left = -240
	poi_legend_container.offset_top = 172
	poi_legend_container.offset_right = -20
	poi_legend_container.offset_bottom = 310

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.01, 0.02, 0.05, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.6)
	panel_style.set_content_margin_all(8)
	poi_legend_container.add_theme_stylebox_override("panel", panel_style)
	map_overlay_panel.add_child(poi_legend_container)

	var vbox = VBoxContainer.new()
	vbox.name = "LegendVBox"
	poi_legend_container.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "MAP LEGEND // POI"
	if font:
		title_lbl.add_theme_font_override("font", font)
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	vbox.add_child(title_lbl)

func _update_poi_legend() -> void:
	if not is_instance_valid(poi_legend_container):
		return

	var vbox = poi_legend_container.get_node_or_null("LegendVBox")
	if not is_instance_valid(vbox):
		return

	# Remove existing dynamic legend rows (keep title)
	for child in vbox.get_children():
		if child != vbox.get_child(0):
			child.queue_free()

	# Define active POI entries dynamically based on player state (On Foot vs In Car)
	var entries: Array[Dictionary] = []
	
	entries.append({"name": "PLAYER LOCATION", "color": Color(1.0, 0.0, 0.8)})
	entries.append({"name": "DUNCAN HQ", "color": Color(0.0, 1.0, 0.85)})
	entries.append({"name": "MACK'S HIDEOUT", "color": Color(1.0, 0.5, 0.0)})
	entries.append({"name": "LADY M'S LAIR", "color": Color(1.0, 0.0, 0.8)})
	entries.append({"name": "CHOP SHOP GARAGE", "color": Color(0.2, 1.0, 0.3)})
	entries.append({"name": "PORTER'S PIT", "color": Color(1.0, 0.3, 0.0)})
	entries.append({"name": "NORNS AI TERMINAL", "color": Color(0.7, 0.1, 1.0)})
	entries.append({"name": "FIFE PATROL HQ", "color": Color(0.1, 0.5, 1.0)})
	entries.append({"name": "CAWDOR LOGISTICS", "color": Color(0.9, 0.7, 0.1)})
	entries.append({"name": "SUBSTATION 09", "color": Color(1.0, 0.9, 0.0)})
	
	if has_active_delivery:
		entries.append({"name": "DELIVERY TARGET", "color": Color(1.0, 0.85, 0.0)})
		
	if is_instance_valid(player_car) and player_car.is_on_foot:
		entries.append({"name": "PARKED CAR", "color": Color(1.0, 0.5, 0.0)})

	var font = map_title_label.get_theme_font("font") if is_instance_valid(map_title_label) else null

	for item in entries:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		# Color Blip Icon Preview
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(8, 8)
		icon.color = item["color"]
		row.add_child(icon)
		
		# Label Text
		var lbl = Label.new()
		lbl.text = item["name"]
		if font:
			lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		row.add_child(lbl)
		
		vbox.add_child(row)

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

		# Use on-foot position when walking, car position when driving
		var tracked_pos: Vector3 = _get_active_player_position()

		# Project player's 3D world position to 2D screen coordinates on satellite camera
		var screen_pos: Vector2 = map_camera.unproject_position(tracked_pos)
		player_blip_marker.position = screen_pos - (player_blip_marker.size / 2.0)

		# Delivery blip update
		if is_instance_valid(delivery_blip_marker):
			if has_active_delivery:
				delivery_blip_marker.visible = true
				var deliv_screen_pos: Vector2 = map_camera.unproject_position(delivery_target_pos)
				delivery_blip_marker.position = deliv_screen_pos - (delivery_blip_marker.size / 2.0)
			else:
				delivery_blip_marker.visible = false

		# Duncan Dynamics HQ blip update
		_update_single_blip(hq_blip_marker, city_gen.hq_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(hideout_blip_marker, city_gen.mack_hideout_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(lady_m_blip_marker, city_gen.lady_m_lair_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(chop_shop_blip_marker, city_gen.chop_shop_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(pit_blip_marker, city_gen.porter_pit_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(norns_blip_marker, city_gen.norns_ai_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(fife_blip_marker, city_gen.fife_hq_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(bankes_blip_marker, city_gen.bankes_logistics_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)
		_update_single_blip(substation_blip_marker, city_gen.power_substation_door_pos if is_instance_valid(city_gen) else Vector3.ZERO)

		# Parked car blip update (visible when walking on foot)
		if is_instance_valid(parked_car_blip_marker):
			if player_car.is_on_foot:
				parked_car_blip_marker.visible = true
				var car_screen_pos: Vector2 = map_camera.unproject_position(player_car.global_position)
				parked_car_blip_marker.position = car_screen_pos - (parked_car_blip_marker.size / 2.0)
			else:
				parked_car_blip_marker.visible = false

		# Keep PIP camera synced to the active player position & orientation
		if is_instance_valid(pip_live_camera):
			var pip_yaw: float = player_car.rotation_degrees.y
			if player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
				pip_yaw = player_car.on_foot_node.rotation_degrees.y
			pip_live_camera.global_position = tracked_pos + Vector3(0.0, 4.0, 0.0) + \
				(Vector3(0.0, 0.0, 8.0).rotated(Vector3.UP, deg_to_rad(pip_yaw)))
			pip_live_camera.rotation_degrees = Vector3(-20.0, pip_yaw, 0.0)

# Returns the active player's world position — foot node when on foot, car otherwise
func _get_active_player_position() -> Vector3:
	if player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		return player_car.on_foot_node.global_position
	return player_car.global_position

func _update_single_blip(blip: ColorRect, target_pos: Vector3) -> void:
	if not is_instance_valid(blip):
		return
	if target_pos != Vector3.ZERO and is_instance_valid(map_camera):
		blip.visible = true
		var screen_pos: Vector2 = map_camera.unproject_position(target_pos)
		blip.position = screen_pos - (blip.size / 2.0)
	else:
		blip.visible = false

# Returns the active game camera — foot node's camera when on foot, main car camera otherwise
func _get_active_camera() -> Camera3D:
	if player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		# The shared camera was reparented to the foot node on exit
		var foot_cam: Camera3D = player_car.on_foot_node.get_node_or_null("Camera3D")
		if is_instance_valid(foot_cam):
			return foot_cam
	return main_camera

func _toggle_tactical_overmap() -> void:
	is_map_active = not is_map_active

	# Access environment and dust particle nodes
	var world_env: WorldEnvironment = $"../WorldEnvironment"
	var dust_system = $"../DustFogSystem"

	if is_map_active:
		print("[OVERMAP] Opening tactical overmap. Clearing high-altitude fog & dust for satellite feed...")
		_update_poi_legend()

		# SAVE player's exact camera settings before switching views
		var active_cam: Camera3D = _get_active_camera()
		if is_instance_valid(active_cam):
			saved_player_fov = active_cam.fov
			saved_player_camera_transform = active_cam.transform

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

		# Boost wireframe ground grid contrast/glow for high altitude satellite view
		var city_gen = $"../CityGenerator"
		if is_instance_valid(city_gen) and city_gen.has_method("set_overmap_boost"):
			city_gen.set_overmap_boost(true)

		# Override L key dimming for wireframe grid in overmap mode
		var city_vfx = $"../CityVisualEffects"
		if is_instance_valid(city_vfx) and city_vfx.has_method("set_overmap_mode"):
			city_vfx.set_overmap_mode(true)

		map_camera.current = true
		map_hud_layer.visible = true

	else:
		print("[OVERMAP] Closing overmap. Restoring volumetric fog and driving camera...")

		# Restore wireframe ground grid to normal intensity
		var city_gen = $"../CityGenerator"
		if is_instance_valid(city_gen) and city_gen.has_method("set_overmap_boost"):
			city_gen.set_overmap_boost(false)

		# Restore L key lighting control
		var city_vfx = $"../CityVisualEffects"
		if is_instance_valid(city_vfx) and city_vfx.has_method("set_overmap_mode"):
			city_vfx.set_overmap_mode(false)

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
		var active_cam: Camera3D = _get_active_camera()
		if is_instance_valid(active_cam):
			active_cam.transform = saved_player_camera_transform
			active_cam.fov = saved_player_fov
			active_cam.current = true
			# Only call _update_camera_transform when actually driving
			if not player_car.is_on_foot and player_car.has_method("_update_camera_transform"):
				player_car._update_camera_transform()

		map_hud_layer.visible = false
