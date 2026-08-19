extends CanvasLayer
class_name TacticalCompassHUD

# ==============================================================================
# TACTICAL COMPASS HUD (TacticalCompassHUD.gd)
# ==============================================================================
# Discrete, sleek cyberpunk horizontal compass ribbon mounted at the top of the HUD.
# Shows cardinal (N, E, S, W) & ordinal (NE, SE, SW, NW) bearings, degree ticks,
# and discrete quest / POI target indicators.

var compass_root: Control = null
var compass_tape: Control = null
var heading_label: Label = null
var frame_panel: Panel = null

# Preloaded Fonts
var geist_font: Font = preload("res://fonts/GeistPixel-Regular-VariableFont_ELSH.ttf")
var sharetech_font: Font = preload("res://fonts/ShareTechMono-Regular.ttf")

# Cardinal points definitions
const COMPASS_WIDTH: float = 380.0
const COMPASS_HEIGHT: float = 24.0
const DEG_SPAN: float = 180.0 # Visible FOV span across the tape (180 degrees)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15 # Above world, below full-screen menus
	_build_ui()

func _build_ui() -> void:
	compass_root = Control.new()
	compass_root.name = "TacticalCompassRoot"
	compass_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	compass_root.custom_minimum_size = Vector2(0, 40)
	add_child(compass_root)

	# Center Margin Container at the top
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_wrap.offset_top = 8.0
	compass_root.add_child(center_wrap)

	# Frame Container
	var compass_box = VBoxContainer.new()
	compass_box.add_theme_constant_override("separation", 2)
	compass_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_wrap.add_child(compass_box)

	# 1. Outer Chrome Border Frame Panel
	frame_panel = Panel.new()
	frame_panel.custom_minimum_size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.02, 0.04, 0.75) # Semi-transparent dark slate
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 1.0, 0.85, 0.4) # Subtle cyan border
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	frame_panel.add_theme_stylebox_override("panel", style)
	compass_box.add_child(frame_panel)

	# Clipping Control to constrain ticks within the width
	var clip_container = Control.new()
	clip_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_container.clip_contents = true
	frame_panel.add_child(clip_container)

	# 2. Custom Drawing Tape Control
	compass_tape = Control.new()
	compass_tape.set_anchors_preset(Control.PRESET_FULL_RECT)
	compass_tape.draw.connect(_on_compass_tape_draw)
	clip_container.add_child(compass_tape)

	# 3. Center Target Indicator Marker (Top Cyan Arrow / Reticle)
	var reticle = Control.new()
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.draw.connect(func():
		var cx: float = COMPASS_WIDTH * 0.5
		# Top Center Arrow
		var arrow_pts = PackedVector2Array([
			Vector2(cx - 4.0, 1.0),
			Vector2(cx + 4.0, 1.0),
			Vector2(cx, 6.0)
		])
		reticle.draw_colored_polygon(arrow_pts, Color(0.0, 1.0, 0.85, 0.95))

		# Bottom Center Pip
		var bottom_pts = PackedVector2Array([
			Vector2(cx, COMPASS_HEIGHT - 6.0),
			Vector2(cx - 4.0, COMPASS_HEIGHT - 1.0),
			Vector2(cx + 4.0, COMPASS_HEIGHT - 1.0)
		])
		reticle.draw_colored_polygon(bottom_pts, Color(0.0, 1.0, 0.85, 0.95))
	)
	frame_panel.add_child(reticle)

	# 4. Discrete Numeric Degree Readout underneath
	heading_label = Label.new()
	heading_label.name = "HeadingDegreeLabel"
	heading_label.text = "000° N"
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.add_theme_font_override("font", geist_font)
	heading_label.add_theme_font_size_override("font_size", 9)
	heading_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85, 0.8))
	compass_box.add_child(heading_label)

func _process(_delta: float) -> void:
	# Hide compass when inside full-screen menus / tactical overmap
	var overmap = get_parent().get_node_or_null("TacticalOvermapManager")
	if is_instance_valid(overmap) and overmap.get("is_map_active") == true:
		compass_root.visible = false
		return

	var loadout_ui = get_parent().get_node_or_null("LoadoutGridUI")
	if is_instance_valid(loadout_ui) and loadout_ui.get("is_open") == true:
		compass_root.visible = false
		return

	var banquo_ui = get_parent().get_node_or_null("BanquoOperativeUI")
	if is_instance_valid(banquo_ui) and banquo_ui.get("is_open") == true:
		compass_root.visible = false
		return

	var indoor_mgr = get_parent().get_node_or_null("IndoorSystemManager")
	if is_instance_valid(indoor_mgr) and indoor_mgr.get("is_inside_building") == true:
		compass_root.visible = false
		return

	var radar_ui = get_parent().get_node_or_null("BattleTelemetryRadarUI")
	if is_instance_valid(radar_ui) and radar_ui.get("is_telemetry_open") == true:
		compass_root.visible = false
		return

	compass_root.visible = true
	if is_instance_valid(compass_tape):
		compass_tape.queue_redraw()

func _get_current_heading_degrees() -> float:
	var player_car = get_parent().get_node_or_null("PlayerCar")
	if not is_instance_valid(player_car):
		return 0.0

	var forward: Vector3 = Vector3.FORWARD
	if player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		# On-foot player heading from character orientation
		forward = -player_car.on_foot_node.global_transform.basis.z
	else:
		# Driving vehicle heading
		forward = -player_car.global_transform.basis.z

	# Standard Godot 3D coordinate system:
	# North = -Z (0 deg)
	# East  = +X (90 deg)
	# South = +Z (180 deg)
	# West  = -X (270 deg)
	var angle_rad: float = atan2(forward.x, -forward.z)
	var deg: float = wrapf(rad_to_deg(angle_rad), 0.0, 360.0)
	return deg

func _on_compass_tape_draw() -> void:
	var heading: float = _get_current_heading_degrees()
	var cx: float = COMPASS_WIDTH * 0.5
	var px_per_deg: float = COMPASS_WIDTH / DEG_SPAN

	# Update discrete degree label
	var cardinal_txt: String = "N"
	if heading >= 337.5 or heading < 22.5: cardinal_txt = "N"
	elif heading >= 22.5 and heading < 67.5: cardinal_txt = "NE"
	elif heading >= 67.5 and heading < 112.5: cardinal_txt = "E"
	elif heading >= 112.5 and heading < 157.5: cardinal_txt = "SE"
	elif heading >= 157.5 and heading < 202.5: cardinal_txt = "S"
	elif heading >= 202.5 and heading < 247.5: cardinal_txt = "SW"
	elif heading >= 247.5 and heading < 292.5: cardinal_txt = "W"
	elif heading >= 292.5 and heading < 337.5: cardinal_txt = "NW"
	
	if is_instance_valid(heading_label):
		heading_label.text = "%03d° // %s" % [int(heading), cardinal_txt]

	# Draw tick marks every 15 degrees, labels every 45 degrees
	var start_deg: float = heading - (DEG_SPAN * 0.5) - 15.0
	var end_deg: float = heading + (DEG_SPAN * 0.5) + 15.0
	
	# Round to nearest 15
	var first_tick: int = int(floor(start_deg / 15.0)) * 15
	var last_tick: int = int(ceil(end_deg / 15.0)) * 15

	var cyan_color = Color(0.0, 1.0, 0.85, 0.85)
	var major_color = Color(1.0, 0.85, 0.0, 0.95) # Gold for N/E/S/W
	var dim_tick_color = Color(0.0, 1.0, 0.85, 0.3)

	for deg_i in range(first_tick, last_tick + 1, 15):
		var deg_norm: float = wrapf(float(deg_i), 0.0, 360.0)
		var diff: float = fposmod(deg_norm - heading + 180.0, 360.0) - 180.0
		var x_pos: float = cx + (diff * px_per_deg)

		if x_pos < 0.0 or x_pos > COMPASS_WIDTH:
			continue

		var is_cardinal: bool = (int(deg_norm) % 90 == 0)
		var is_ordinal: bool = (int(deg_norm) % 45 == 0) and not is_cardinal

		var tick_h: float = 6.0
		var tick_col = dim_tick_color

		if is_cardinal:
			tick_h = 11.0
			tick_col = major_color
		elif is_ordinal:
			tick_h = 8.0
			tick_col = cyan_color

		# Draw vertical tick
		compass_tape.draw_line(
			Vector2(x_pos, COMPASS_HEIGHT - tick_h - 2.0),
			Vector2(x_pos, COMPASS_HEIGHT - 2.0),
			tick_col,
			1.5 if is_cardinal else 1.0
		)

		# Draw Text Marker (N, E, S, W, NE, NW, SE, SW)
		if is_cardinal or is_ordinal:
			var txt: String = ""
			match int(deg_norm):
				0: txt = "N"
				45: txt = "NE"
				90: txt = "E"
				135: txt = "SE"
				180: txt = "S"
				225: txt = "SW"
				270: txt = "W"
				315: txt = "NW"

			var font_sz: int = 10 if is_cardinal else 8
			var txt_col = major_color if is_cardinal else cyan_color
			var str_sz = geist_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz)
			compass_tape.draw_string(
				geist_font,
				Vector2(x_pos - str_sz.x * 0.5, 12.0),
				txt,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_sz,
				txt_col
			)

	# --- ACTIVE QUEST BEACON / BLIP MARKER ---
	_draw_quest_beacon_blip(heading, cx, px_per_deg)

func _draw_quest_beacon_blip(player_heading: float, cx: float, px_per_deg: float) -> void:
	var quest_mgr = get_parent().get_node_or_null("QuestManager")
	var player_car = get_parent().get_node_or_null("PlayerCar")
	if not is_instance_valid(quest_mgr) or not is_instance_valid(player_car):
		return

	var beacon_pos: Vector3 = Vector3.ZERO
	var has_beacon: bool = false

	if is_instance_valid(quest_mgr.get("active_goal_beacon_node")):
		beacon_pos = quest_mgr.active_goal_beacon_node.global_position
		has_beacon = true
	elif quest_mgr.active_quest_id != "" and not quest_mgr.active_quest_data.is_empty():
		var target_coords = quest_mgr.active_quest_data.get("goal_coordinates", [])
		if target_coords.size() == 3:
			beacon_pos = Vector3(target_coords[0], target_coords[1], target_coords[2])
			has_beacon = true

	if not has_beacon:
		return

	var player_pos: Vector3 = player_car.global_position
	if player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		player_pos = player_car.on_foot_node.global_position

	var dir_to_beacon: Vector3 = (beacon_pos - player_pos).normalized()
	var beacon_angle_rad: float = atan2(dir_to_beacon.x, -dir_to_beacon.z)
	var beacon_deg: float = wrapf(rad_to_deg(beacon_angle_rad), 0.0, 360.0)

	var diff: float = fposmod(beacon_deg - player_heading + 180.0, 360.0) - 180.0
	var blip_x: float = cx + (diff * px_per_deg)

	# Draw discrete diamond beacon icon on the tape if in FOV
	var gold_beacon = Color(1.0, 0.85, 0.0, 0.95)
	if blip_x >= 12.0 and blip_x <= (COMPASS_WIDTH - 12.0):
		var diamond = PackedVector2Array([
			Vector2(blip_x, COMPASS_HEIGHT * 0.5 - 3.5),
			Vector2(blip_x + 3.5, COMPASS_HEIGHT * 0.5),
			Vector2(blip_x, COMPASS_HEIGHT * 0.5 + 3.5),
			Vector2(blip_x - 3.5, COMPASS_HEIGHT * 0.5)
		])
		compass_tape.draw_colored_polygon(diamond, gold_beacon)
	elif blip_x < 12.0:
		# Pegged to left edge arrow
		var l_arrow = PackedVector2Array([
			Vector2(8.0, COMPASS_HEIGHT * 0.5),
			Vector2(14.0, COMPASS_HEIGHT * 0.5 - 3.5),
			Vector2(14.0, COMPASS_HEIGHT * 0.5 + 3.5)
		])
		compass_tape.draw_colored_polygon(l_arrow, gold_beacon)
	elif blip_x > (COMPASS_WIDTH - 12.0):
		# Pegged to right edge arrow
		var r_arrow = PackedVector2Array([
			Vector2(COMPASS_WIDTH - 8.0, COMPASS_HEIGHT * 0.5),
			Vector2(COMPASS_WIDTH - 14.0, COMPASS_HEIGHT * 0.5 - 3.5),
			Vector2(COMPASS_WIDTH - 14.0, COMPASS_HEIGHT * 0.5 + 3.5)
		])
		compass_tape.draw_colored_polygon(r_arrow, gold_beacon)
