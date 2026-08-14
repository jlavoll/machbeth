extends Node3D
class_name IndoorSystemManager

# ==============================================================================
# INDOOR TACTICAL BLUEPRINT SYSTEM (IndoorSystemManager.gd)
# ==============================================================================
# Manages Duncan Dynamics HQ Multi-Floor Interior Blueprint System:
# - Floor 01: Ground Lobby (40m x 30m) with Cyan Cyber Blueprint layout.
# - Floor 99: Executive Penthouse & Secret Server Vault (40m x 30m) with Crimson Blueprint layout.
# - Interactive Elevator Lift linking Lobby & Penthouse with interactive E key prompts.
# - Interactive Security Vault Door sliding open/closed in the Penthouse.
# - Exit portal trigger returning player to city streets outside.

enum HQFloor { LOBBY, PENTHOUSE, MACK_HIDEOUT, BANQUO_LOFT, LADY_M_LAIR, CHOP_SHOP, PORTER_PIT, NORNS_AI, FIFE_HQ, BANKES_LOGISTICS, SUBSTATION }
var current_floor: HQFloor = HQFloor.LOBBY

var is_inside_building: bool = false
var saved_player_position: Vector3 = Vector3.ZERO

# Playable Interior Floor Origins (offset far outside city grid to prevent rendering overlap)
var lobby_floor_origin: Vector3 = Vector3(1000.0, 0.0, 1000.0)
var penthouse_floor_origin: Vector3 = Vector3(2000.0, 0.0, 2000.0)
var mack_hideout_origin: Vector3 = Vector3(3000.0, 0.0, 3000.0)
var banquo_loft_origin: Vector3 = Vector3(3500.0, 0.0, 3500.0)
var lady_m_lair_origin: Vector3 = Vector3(4000.0, 0.0, 4000.0)
var chop_shop_origin: Vector3 = Vector3(5000.0, 0.0, 5000.0)
var porter_pit_origin: Vector3 = Vector3(6000.0, 0.0, 6000.0)
var norns_ai_origin: Vector3 = Vector3(7000.0, 0.0, 7000.0)
var fife_hq_origin: Vector3 = Vector3(8000.0, 0.0, 8000.0)
var bankes_logistics_origin: Vector3 = Vector3(9000.0, 0.0, 9000.0)
var substation_origin: Vector3 = Vector3(10000.0, 0.0, 10000.0)

# Elevator Lift World Locations
var lobby_elevator_pos: Vector3 = Vector3.ZERO
var penthouse_elevator_pos: Vector3 = Vector3.ZERO
var exit_door_pos: Vector3 = Vector3.ZERO

# Interior Connected Doors (Server Room Door in Penthouse)
var penthouse_server_door_pos: Vector3 = Vector3.ZERO
var is_server_door_open: bool = false
var server_door_node: Node3D = null

# Interior Camera3D & Viewport Setup
var indoor_camera: Camera3D = null
var indoor_fp_camera: Camera3D = null
var indoor_view_mode: String = "TOPDOWN" # "TOPDOWN" or "FIRST_PERSON"
var _fp_pitch: float = 0.0
var indoor_hud_layer: CanvasLayer = null
var indoor_title_label: Label = null
var indoor_view_label: Label = null
var _indoor_prompt_label: Label = null

# References
@onready var player_car: CharacterBody3D = $"../PlayerCar"
@onready var city_gen = $"../CityGenerator"

func _ready() -> void:
	_build_lobby_floor()
	_build_penthouse_floor()
	_build_hideout_floor()
	_build_banquo_loft_floor()
	_build_lady_m_lair_floor()
	_build_chop_shop_floor()
	_build_porter_pit_floor()
	_build_norns_ai_floor()
	_build_fife_hq_floor()
	_build_bankes_logistics_floor()
	_build_substation_floor()
	_setup_indoor_camera()
	_setup_indoor_hud()

# ==============================================================================
# 1. FLOOR 1: GROUND LOBBY (40m x 30m)
# ==============================================================================
func _build_lobby_floor() -> void:
	var root_lobby = Node3D.new()
	root_lobby.name = "HQLobbyRoot"
	root_lobby.position = lobby_floor_origin
	add_child(root_lobby)

	# Floor plane & static collider
	_build_floor_plane(root_lobby, Vector2(40.0, 30.0), Color(0.01, 0.03, 0.08))
	_build_blueprint_grid(root_lobby, 40, 30, Color(0.0, 0.85, 1.0))

	# Boundary Walls
	_build_interior_wall(root_lobby, Vector3(0.0, 2.5, -15.0), Vector3(40.0, 5.0, 0.8), Color(0.0, 0.85, 1.0)) # North
	_build_interior_wall(root_lobby, Vector3(0.0, 2.5, 15.0), Vector3(40.0, 5.0, 0.8), Color(0.0, 0.85, 1.0))  # South
	_build_interior_wall(root_lobby, Vector3(-20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(0.0, 0.85, 1.0)) # West
	_build_interior_wall(root_lobby, Vector3(20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(0.0, 0.85, 1.0))  # East

	# Pillars & Desks
	for px in [-10.0, 10.0]:
		for pz in [-6.0, 6.0]:
			_build_interior_pillar(root_lobby, Vector3(px, 2.5, pz), Vector3(1.8, 5.0, 1.8), Color(0.0, 1.0, 0.85))
	for dx in [-12.0, -4.0, 4.0, 12.0]:
		_build_interior_desk(root_lobby, Vector3(dx, 0.6, -8.0), Vector3(2.5, 1.2, 1.2), Color(1.0, 0.85, 0.0))
		_build_interior_desk(root_lobby, Vector3(dx, 0.6, 8.0), Vector3(2.5, 1.2, 1.2), Color(1.0, 0.85, 0.0))

	# Reception Desk & Secretary NPC
	_build_interior_desk(root_lobby, Vector3(0.0, 0.6, 2.0), Vector3(5.0, 1.2, 1.8), Color(0.0, 1.0, 0.85))
	_spawn_npc_character(root_lobby, Vector3(0.0, 0.0, 0.5), Color(0.0, 0.85, 1.0), "HQ Reception Secretary", Vector3(0.0, 0.0, 1.0))

	# Exit Door (South Wall)
	exit_door_pos = lobby_floor_origin + Vector3(0.0, 0.0, 13.5)
	_build_exit_door(root_lobby, Vector3(0.0, 1.8, 14.2))

	# Elevator Shaft (North Wall Center)
	lobby_elevator_pos = lobby_floor_origin + Vector3(0.0, 0.0, -13.2)
	_build_elevator_shaft(root_lobby, Vector3(0.0, 2.5, -14.0))

# ==============================================================================
# 2. FLOOR 2: EXECUTIVE PENTHOUSE & SERVER VAULT (40m x 30m)
# ==============================================================================
func _build_penthouse_floor() -> void:
	var root_penthouse = Node3D.new()
	root_penthouse.name = "HQPenthouseRoot"
	root_penthouse.position = penthouse_floor_origin
	add_child(root_penthouse)

	# Crimson / Violet Executive Cyber Blueprint Floor
	_build_floor_plane(root_penthouse, Vector2(40.0, 30.0), Color(0.06, 0.01, 0.04))
	_build_blueprint_grid(root_penthouse, 40, 30, Color(1.0, 0.0, 0.6)) # Hot Magenta Grid

	# Outer Boundary Walls (Hot Pink Accent)
	_build_interior_wall(root_penthouse, Vector3(0.0, 2.5, -15.0), Vector3(40.0, 5.0, 0.8), Color(1.0, 0.0, 0.6))
	_build_interior_wall(root_penthouse, Vector3(0.0, 2.5, 15.0), Vector3(40.0, 5.0, 0.8), Color(1.0, 0.0, 0.6))
	_build_interior_wall(root_penthouse, Vector3(-20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(1.0, 0.0, 0.6))
	_build_interior_wall(root_penthouse, Vector3(20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(1.0, 0.0, 0.6))

	# Interior Dividing Wall (Separates Executive Suite from Secret Server Room on West side)
	_build_interior_wall(root_penthouse, Vector3(-8.0, 2.5, -7.0), Vector3(0.8, 5.0, 16.0), Color(1.0, 0.0, 0.6))
	_build_interior_wall(root_penthouse, Vector3(-8.0, 2.5, 7.0), Vector3(0.8, 5.0, 16.0), Color(1.0, 0.0, 0.6))

	# Interactive Security Door connecting Penthouse Suite to Server Room (Center of partition wall)
	penthouse_server_door_pos = penthouse_floor_origin + Vector3(-8.0, 0.0, 0.0)
	server_door_node = _build_interactive_door(root_penthouse, Vector3(-8.0, 2.0, 0.0), Vector3(0.8, 4.0, 3.6), Color(1.0, 0.85, 0.0))

	# Elevator Shaft (South Wall Center in Penthouse)
	penthouse_elevator_pos = penthouse_floor_origin + Vector3(0.0, 0.0, 13.2)
	_build_elevator_shaft(root_penthouse, Vector3(0.0, 2.5, 14.0))

	# CEO Executive Desk & CEO Duncan NPC
	_build_interior_desk(root_penthouse, Vector3(8.0, 0.6, 0.0), Vector3(4.0, 1.2, 2.0), Color(1.0, 0.1, 0.1))
	_spawn_npc_character(root_penthouse, Vector3(8.0, 0.0, -1.5), Color(1.0, 0.1, 0.1), "CEO Duncan", Vector3(8.0, 0.0, 0.0))

	# Glowing Server Racks in Vault
	for sz in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		_build_interior_desk(root_penthouse, Vector3(-14.0, 1.2, sz), Vector3(2.0, 2.4, 2.0), Color(0.0, 1.0, 0.85))

# ==============================================================================
# 3. MACK'S HIDEOUT (APARTMENT & TACTICAL WORKSHOP - 24m x 18m)
# ==============================================================================
func _build_hideout_floor() -> void:
	var root_hideout = Node3D.new()
	root_hideout.name = "MackHideoutRoot"
	root_hideout.position = mack_hideout_origin
	add_child(root_hideout)

	_build_floor_plane(root_hideout, Vector2(24.0, 18.0), Color(0.04, 0.03, 0.01))
	_build_blueprint_grid(root_hideout, 24, 18, Color(1.0, 0.5, 0.0)) # Ember Orange Grid

	_build_interior_wall(root_hideout, Vector3(0.0, 2.5, -9.0), Vector3(24.0, 5.0, 0.8), Color(1.0, 0.5, 0.0))
	_build_interior_wall(root_hideout, Vector3(0.0, 2.5, 9.0), Vector3(24.0, 5.0, 0.8), Color(1.0, 0.5, 0.0))
	_build_interior_wall(root_hideout, Vector3(-12.0, 2.5, 0.0), Vector3(0.8, 5.0, 18.0), Color(1.0, 0.5, 0.0))
	_build_interior_wall(root_hideout, Vector3(12.0, 2.5, 0.0), Vector3(0.8, 5.0, 18.0), Color(1.0, 0.5, 0.0))

	# Mack's Workbench & Weapon Rack
	_build_interior_desk(root_hideout, Vector3(0.0, 0.6, -4.0), Vector3(4.0, 1.2, 1.6), Color(1.0, 0.5, 0.0))
	_build_interior_pillar(root_hideout, Vector3(-6.0, 1.5, -5.0), Vector3(1.2, 3.0, 1.2), Color(1.0, 0.5, 0.0))

	# Spawn Mack NPC Warlord (Only present at home when not out on battle missions!)
	_spawn_npc_character(root_hideout, Vector3(0.0, 0.0, -5.5), Color(1.0, 0.3, 0.0), "Mack", Vector3(0.0, 0.0, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_hideout, Vector3(0.0, 1.8, 8.2))

# ==============================================================================
# 3B. BANQUO'S PRIVATE LOFT (CYBER-PUNK HIGH-RISE APARTMENT - 24m x 18m)
# ==============================================================================
func _build_banquo_loft_floor() -> void:
	var root_loft = Node3D.new()
	root_loft.name = "BanquoLoftRoot"
	root_loft.position = banquo_loft_origin
	add_child(root_loft)

	# Deep Violet / Magenta Cyber Blueprint Floor
	_build_floor_plane(root_loft, Vector2(24.0, 18.0), Color(0.04, 0.01, 0.05))
	_build_blueprint_grid(root_loft, 24, 18, Color(1.0, 0.0, 0.8)) # Electric Purple Grid

	_build_interior_wall(root_loft, Vector3(0.0, 2.5, -9.0), Vector3(24.0, 5.0, 0.8), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_loft, Vector3(0.0, 2.5, 9.0), Vector3(24.0, 5.0, 0.8), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_loft, Vector3(-12.0, 2.5, 0.0), Vector3(0.8, 5.0, 18.0), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_loft, Vector3(12.0, 2.5, 0.0), Vector3(0.8, 5.0, 18.0), Color(1.0, 0.0, 0.8))

	# Banquo's Personal Rest Bed & Telemetry Terminal
	_build_interior_desk(root_loft, Vector3(6.0, 0.4, -4.0), Vector3(3.2, 0.8, 4.5), Color(1.0, 0.0, 0.8))
	_build_interior_desk(root_loft, Vector3(-5.0, 0.6, -4.0), Vector3(4.0, 1.2, 1.6), Color(1.0, 0.0, 0.8))

	# --- INTERACTIVE OUTFIT WARDROBE CUPBOARD (West Wall - North Side) ---
	var cupboard_body = StaticBody3D.new()
	cupboard_body.name = "WardrobeCupboard"
	cupboard_body.position = Vector3(-9.5, 1.5, -4.0)

	var cupboard_col = CollisionShape3D.new()
	var cupboard_shape = BoxShape3D.new()
	cupboard_shape.size = Vector3(1.4, 3.0, 2.2)
	cupboard_col.shape = cupboard_shape
	cupboard_body.add_child(cupboard_col)

	var cupboard_mesh = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(1.4, 3.0, 2.2)
	cupboard_mesh.mesh = c_box
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.08, 0.02, 0.1)
	c_mat.emission_enabled = true
	c_mat.emission = Color(1.0, 0.0, 0.8) # Neon Magenta Outline
	c_mat.emission_energy_multiplier = 4.0
	cupboard_mesh.material_override = c_mat
	cupboard_body.add_child(cupboard_mesh)

	# Wardrobe 3D Label
	var c_lbl = Label3D.new()
	c_lbl.text = "👔 BANQUO'S OUTFIT WARDROBE\n[PRESS 'E' TO CHANGE HEAD COLOR!]"
	c_lbl.position = Vector3(0.0, 2.0, 0.0)
	c_lbl.font_size = 20
	c_lbl.pixel_size = 0.004
	c_lbl.modulate = Color(1.0, 0.0, 0.8)
	cupboard_body.add_child(c_lbl)

	root_loft.add_child(cupboard_body)

	# Exit Door (South Wall Center)
	_build_exit_door(root_loft, Vector3(0.0, 1.8, 8.2))

# ==============================================================================
# 4. LADY M'S HACKER LAIR (UNDERGROUND NETRUNNER VAULT - 30m x 20m)
# ==============================================================================
func _build_lady_m_lair_floor() -> void:
	var root_lair = Node3D.new()
	root_lair.name = "LadyMLairRoot"
	root_lair.position = lady_m_lair_origin
	add_child(root_lair)

	_build_floor_plane(root_lair, Vector2(30.0, 20.0), Color(0.05, 0.0, 0.06))
	_build_blueprint_grid(root_lair, 30, 20, Color(1.0, 0.0, 0.8)) # Electric Magenta Grid

	_build_interior_wall(root_lair, Vector3(0.0, 2.5, -10.0), Vector3(30.0, 5.0, 0.8), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_lair, Vector3(0.0, 2.5, 10.0), Vector3(30.0, 5.0, 0.8), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_lair, Vector3(-15.0, 2.5, 0.0), Vector3(0.8, 5.0, 20.0), Color(1.0, 0.0, 0.8))
	_build_interior_wall(root_lair, Vector3(15.0, 2.5, 0.0), Vector3(0.8, 5.0, 20.0), Color(1.0, 0.0, 0.8))

	# Central Hacker Rig Terminal & Lady M NPC
	_build_interior_desk(root_lair, Vector3(0.0, 0.8, -2.0), Vector3(6.0, 1.6, 2.4), Color(1.0, 0.0, 0.8))
	_spawn_npc_character(root_lair, Vector3(0.0, 0.0, -3.5), Color(1.0, 0.0, 0.8), "Lady M", Vector3(0.0, 0.0, 0.0))

	# Surrounding Mainframe Servers
	for sx in [-10.0, 10.0]:
		for sz in [-5.0, 5.0]:
			_build_interior_pillar(root_lair, Vector3(sx, 2.0, sz), Vector3(1.6, 4.0, 1.6), Color(1.0, 0.0, 0.8))

	# Exit Door (South Wall Center)
	_build_exit_door(root_lair, Vector3(0.0, 1.8, 9.2))

# ==============================================================================
# 5. CAR CUSTOMIZATION CHOP SHOP GARAGE (36m x 24m)
# ==============================================================================
func _build_chop_shop_floor() -> void:
	var root_shop = Node3D.new()
	root_shop.name = "ChopShopRoot"
	root_shop.position = chop_shop_origin
	add_child(root_shop)

	_build_floor_plane(root_shop, Vector2(36.0, 24.0), Color(0.01, 0.05, 0.02))
	_build_blueprint_grid(root_shop, 36, 24, Color(0.2, 1.0, 0.3)) # Cyber Green Grid

	_build_interior_wall(root_shop, Vector3(0.0, 2.5, -12.0), Vector3(36.0, 5.0, 0.8), Color(0.2, 1.0, 0.3))
	_build_interior_wall(root_shop, Vector3(0.0, 2.5, 12.0), Vector3(36.0, 5.0, 0.8), Color(0.2, 1.0, 0.3))
	_build_interior_wall(root_shop, Vector3(-18.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.2, 1.0, 0.3))
	_build_interior_wall(root_shop, Vector3(18.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.2, 1.0, 0.3))

	# Hydraulic Lift Platform & Garage Master Mechanic NPC
	_build_interior_desk(root_shop, Vector3(0.0, 0.3, 0.0), Vector3(6.0, 0.6, 10.0), Color(0.2, 1.0, 0.3))
	_spawn_npc_character(root_shop, Vector3(4.5, 0.0, 0.0), Color(0.2, 1.0, 0.3), "Chop Shop Mechanic", Vector3(0.0, 0.0, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_shop, Vector3(0.0, 1.8, 11.2))

# ==============================================================================
# 6. "THE PIT" SUBTERRANEAN GARAGE (PORTER's HUB - 36m x 24m)
# ==============================================================================
func _build_porter_pit_floor() -> void:
	var root_pit = Node3D.new()
	root_pit.name = "PorterPitRoot"
	root_pit.position = porter_pit_origin
	add_child(root_pit)

	_build_floor_plane(root_pit, Vector2(36.0, 24.0), Color(0.05, 0.02, 0.01))
	_build_blueprint_grid(root_pit, 36, 24, Color(1.0, 0.3, 0.0)) # Dark Rust Orange Grid

	_build_interior_wall(root_pit, Vector3(0.0, 2.5, -12.0), Vector3(36.0, 5.0, 0.8), Color(1.0, 0.3, 0.0))
	_build_interior_wall(root_pit, Vector3(0.0, 2.5, 12.0), Vector3(36.0, 5.0, 0.8), Color(1.0, 0.3, 0.0))
	_build_interior_wall(root_pit, Vector3(-18.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(1.0, 0.3, 0.0))
	_build_interior_wall(root_pit, Vector3(18.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(1.0, 0.3, 0.0))

	# Subterranean Pit Diagnostic Terminal & Porter NPC
	_build_interior_desk(root_pit, Vector3(0.0, 0.5, -4.0), Vector3(5.0, 1.0, 2.0), Color(1.0, 0.3, 0.0))
	_spawn_npc_character(root_pit, Vector3(0.0, 0.0, -5.5), Color(1.0, 0.3, 0.0), "Porter", Vector3(0.0, 0.0, 0.0))

	# --- 3D TELEMETRY MONITOR MATRIX (Back Wall - North Side) ---
	# Screen 1 (Left): Battle Vitals & HP Meter Monitor
	_build_interior_pillar(root_pit, Vector3(-9.0, 3.2, -11.5), Vector3(8.0, 3.0, 0.2), Color(0.0, 0.85, 1.0))
	var scr1_label = Label3D.new()
	scr1_label.name = "PitMonitorVitalsLabel"
	scr1_label.position = Vector3(-9.0, 3.2, -11.35)
	scr1_label.text = "💻 TELEMETRY VITALS\nMACK HP: 100 / 100\nCORE TEMP: 75.0°C\nENGINE RPM: 4200"
	scr1_label.font_size = 22
	scr1_label.pixel_size = 0.004
	scr1_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scr1_label.width = 1750.0
	scr1_label.modulate = Color(0.0, 1.0, 1.0)
	scr1_label.outline_render_priority = 1
	root_pit.add_child(scr1_label)

	# Screen 2 (Center): Main Telemetry Video / Tactical Feed Monitor
	_build_interior_pillar(root_pit, Vector3(0.0, 3.4, -11.5), Vector3(10.0, 3.4, 0.2), Color(1.0, 0.35, 0.0))
	var scr2_label = Label3D.new()
	scr2_label.name = "PitMonitorTacticalLabel"
	scr2_label.position = Vector3(0.0, 3.4, -11.35)
	scr2_label.text = "🎥 LIVE TACTICAL VIDEO FEED\nPHASE I: HIGHWAY ENGAGEMENT\n[CAM UPLINK ACTIVE]"
	scr2_label.font_size = 24
	scr2_label.pixel_size = 0.004
	scr2_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scr2_label.width = 2200.0
	scr2_label.modulate = Color(1.0, 0.5, 0.0)
	scr2_label.outline_render_priority = 1
	root_pit.add_child(scr2_label)

	# Screen 3 (Right): Enemy Threat & Combat Math Monitor
	_build_interior_pillar(root_pit, Vector3(9.0, 3.2, -11.5), Vector3(8.0, 3.0, 0.2), Color(1.0, 0.85, 0.0))
	var scr3_label = Label3D.new()
	scr3_label.name = "PitMonitorMathLabel"
	scr3_label.position = Vector3(9.0, 3.2, -11.35)
	scr3_label.text = "🎲 COMBAT MATH MATRIX\n[MACK ATK] d20(16)+8=24 -> 38 DMG\n[ENEMY ATK] d20(12) -> 24 DMG\nArmor Absorbed: -8 HP"
	scr3_label.font_size = 20
	scr3_label.pixel_size = 0.004
	scr3_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scr3_label.width = 1750.0
	scr3_label.modulate = Color(1.0, 0.85, 0.0)
	scr3_label.outline_render_priority = 1
	root_pit.add_child(scr3_label)

	# Interactive Pit Garage Fleet Terminal Console (West Bay)
	_build_interior_desk(root_pit, Vector3(-10.0, 0.6, 0.0), Vector3(3.0, 1.2, 4.0), Color(1.0, 0.5, 0.0))

	# Interactive Cyborg Surgery Chair & Neural Modding Terminal (East Bay)
	_build_interior_desk(root_pit, Vector3(10.0, 0.6, 0.0), Vector3(3.0, 1.2, 4.0), Color(1.0, 0.0, 0.6))

	# Interactive Tactical War-Table Hologram Terminal (Center Bay)
	_build_interior_desk(root_pit, Vector3(0.0, 0.6, 4.0), Vector3(4.0, 1.2, 4.0), Color(0.0, 1.0, 0.85))

	# Exit Door (South Wall Center)
	_build_exit_door(root_pit, Vector3(0.0, 1.8, 11.2))

# ==============================================================================
# 7. THE 3 NORNS' DEEP-WEB TERMINAL (#03-NORNS - 24m x 24m)
# ==============================================================================
func _build_norns_ai_floor() -> void:
	var root_norns = Node3D.new()
	root_norns.name = "NornsAIRoot"
	root_norns.position = norns_ai_origin
	add_child(root_norns)

	_build_floor_plane(root_norns, Vector2(24.0, 24.0), Color(0.04, 0.0, 0.06))
	_build_blueprint_grid(root_norns, 24, 24, Color(0.7, 0.1, 1.0)) # Deep Violet Grid

	_build_interior_wall(root_norns, Vector3(0.0, 2.5, -12.0), Vector3(24.0, 5.0, 0.8), Color(0.7, 0.1, 1.0))
	_build_interior_wall(root_norns, Vector3(0.0, 2.5, 12.0), Vector3(24.0, 5.0, 0.8), Color(0.7, 0.1, 1.0))
	_build_interior_wall(root_norns, Vector3(-12.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.7, 0.1, 1.0))
	_build_interior_wall(root_norns, Vector3(12.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.7, 0.1, 1.0))

	# Central AI Prophecy Pillar & 3 Norns NPCs
	_build_interior_pillar(root_norns, Vector3(0.0, 2.0, 0.0), Vector3(3.0, 4.0, 3.0), Color(0.7, 0.1, 1.0))
	_spawn_npc_character(root_norns, Vector3(-3.0, 0.0, 0.0), Color(0.7, 0.1, 1.0), "Norn-01", Vector3(0.0, 0.0, 0.0))
	_spawn_npc_character(root_norns, Vector3(0.0, 0.0, -3.0), Color(0.7, 0.1, 1.0), "Norn-02", Vector3(0.0, 0.0, 0.0))
	_spawn_npc_character(root_norns, Vector3(3.0, 0.0, 0.0), Color(0.7, 0.1, 1.0), "Norn-03", Vector3(0.0, 0.0, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_norns, Vector3(0.0, 1.8, 11.2))

# ==============================================================================
# 8. FIFE SECURITY PATROL HEADQUARTERS (MACDUFF's CITADEL - 40m x 30m)
# ==============================================================================
func _build_fife_hq_floor() -> void:
	var root_fife = Node3D.new()
	root_fife.name = "FifeHQRoot"
	root_fife.position = fife_hq_origin
	add_child(root_fife)

	_build_floor_plane(root_fife, Vector2(40.0, 30.0), Color(0.01, 0.03, 0.06))
	_build_blueprint_grid(root_fife, 40, 30, Color(0.1, 0.5, 1.0)) # Steel Blue Grid

	_build_interior_wall(root_fife, Vector3(0.0, 2.5, -15.0), Vector3(40.0, 5.0, 0.8), Color(0.1, 0.5, 1.0))
	_build_interior_wall(root_fife, Vector3(0.0, 2.5, 15.0), Vector3(40.0, 5.0, 0.8), Color(0.1, 0.5, 1.0))
	_build_interior_wall(root_fife, Vector3(-20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(0.1, 0.5, 1.0))
	_build_interior_wall(root_fife, Vector3(20.0, 2.5, 0.0), Vector3(0.8, 5.0, 30.0), Color(0.1, 0.5, 1.0))

	# Tactical Holotable & Macduff NPC
	_build_interior_desk(root_fife, Vector3(0.0, 0.6, 0.0), Vector3(6.0, 1.2, 4.0), Color(0.1, 0.5, 1.0))
	_spawn_npc_character(root_fife, Vector3(0.0, 0.0, -3.0), Color(0.1, 0.5, 1.0), "Macduff", Vector3(0.0, 0.0, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_fife, Vector3(0.0, 1.8, 14.2))

# ==============================================================================
# 9. CAWDOR LOGISTICS DEPOT (BANKES' PATROL HUB - 32m x 24m)
# ==============================================================================
func _build_bankes_logistics_floor() -> void:
	var root_bankes = Node3D.new()
	root_bankes.name = "BankesLogisticsRoot"
	root_bankes.position = bankes_logistics_origin
	add_child(root_bankes)

	_build_floor_plane(root_bankes, Vector2(32.0, 24.0), Color(0.05, 0.04, 0.01))
	_build_blueprint_grid(root_bankes, 32, 24, Color(0.9, 0.7, 0.1)) # Industrial Yellow Grid

	_build_interior_wall(root_bankes, Vector3(0.0, 2.5, -12.0), Vector3(32.0, 5.0, 0.8), Color(0.9, 0.7, 0.1))
	_build_interior_wall(root_bankes, Vector3(0.0, 2.5, 12.0), Vector3(32.0, 5.0, 0.8), Color(0.9, 0.7, 0.1))
	_build_interior_wall(root_bankes, Vector3(-16.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.9, 0.7, 0.1))
	_build_interior_wall(root_bankes, Vector3(16.0, 2.5, 0.0), Vector3(0.8, 5.0, 24.0), Color(0.9, 0.7, 0.1))

	# Telemetry Terminal & Bankes NPC
	_build_interior_desk(root_bankes, Vector3(0.0, 0.6, -2.0), Vector3(5.0, 1.2, 2.0), Color(0.9, 0.7, 0.1))
	_spawn_npc_character(root_bankes, Vector3(0.0, 0.0, -3.5), Color(0.9, 0.7, 0.1), "Bankes", Vector3(0.0, 0.0, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_bankes, Vector3(0.0, 1.8, 11.2))

# ==============================================================================
# 10. SUB-GRID POWER SUBSTATION 09 (BLACKOUT HUB - 28m x 20m)
# ==============================================================================
func _build_substation_floor() -> void:
	var root_sub = Node3D.new()
	root_sub.name = "SubstationRoot"
	root_sub.position = substation_origin
	add_child(root_sub)

	_build_floor_plane(root_sub, Vector2(28.0, 20.0), Color(0.05, 0.05, 0.0))
	_build_blueprint_grid(root_sub, 28, 20, Color(1.0, 0.9, 0.0)) # High-Voltage Yellow Grid

	_build_interior_wall(root_sub, Vector3(0.0, 2.5, -10.0), Vector3(28.0, 5.0, 0.8), Color(1.0, 0.9, 0.0))
	_build_interior_wall(root_sub, Vector3(0.0, 2.5, 10.0), Vector3(28.0, 5.0, 0.8), Color(1.0, 0.9, 0.0))
	_build_interior_wall(root_sub, Vector3(-14.0, 2.5, 0.0), Vector3(0.8, 5.0, 20.0), Color(1.0, 0.9, 0.0))
	_build_interior_wall(root_sub, Vector3(14.0, 2.5, 0.0), Vector3(0.8, 5.0, 20.0), Color(1.0, 0.9, 0.0))

	# High-Voltage Transformers
	for tx in [-6.0, 6.0]:
		_build_interior_pillar(root_sub, Vector3(tx, 2.0, -2.0), Vector3(3.0, 4.0, 3.0), Color(1.0, 0.9, 0.0))

	# Interactive Substation 09 Power Grid Breaker Terminal
	_build_interior_desk(root_sub, Vector3(0.0, 0.6, -6.0), Vector3(4.0, 1.2, 2.0), Color(1.0, 0.9, 0.0))

	# Exit Door (South Wall Center)
	_build_exit_door(root_sub, Vector3(0.0, 1.8, 9.2))

# ==============================================================================
# HELPER BUILDERS: PLANES, GRIDS, WALLS, ELEVATORS, DOORS
# ==============================================================================
func _build_floor_plane(parent: Node3D, size: Vector2, color: Color) -> void:
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = size
	floor_mesh.mesh = plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = color
	floor_mat.roughness = 0.5
	floor_mesh.material_override = floor_mat
	parent.add_child(floor_mesh)

	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(size.x, 1.0, size.y)
	floor_col.shape = floor_box
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	parent.add_child(floor_body)

func _build_blueprint_grid(parent: Node3D, size_x: int, size_z: int, grid_color: Color) -> void:
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0, 0, 0)
	grid_mat.emission_enabled = true
	grid_mat.emission = grid_color
	grid_mat.emission_energy_multiplier = 4.0

	var grid_mesh = ImmediateMesh.new()
	var grid_inst = MeshInstance3D.new()
	grid_inst.mesh = grid_mesh
	grid_inst.material_override = grid_mat
	parent.add_child(grid_inst)

	var hx: int = size_x / 2
	var hz: int = size_z / 2
	grid_mesh.clear_surfaces()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(-hx, hx + 1, 2):
		grid_mesh.surface_add_vertex(Vector3(x, 0.01, -hz))
		grid_mesh.surface_add_vertex(Vector3(x, 0.01, hz))
		grid_mesh.surface_add_vertex(Vector3(x, 4.0, -hz))
		grid_mesh.surface_add_vertex(Vector3(x, 4.0, hz))
	for z in range(-hz, hz + 1, 2):
		grid_mesh.surface_add_vertex(Vector3(-hx, 0.01, z))
		grid_mesh.surface_add_vertex(Vector3(hx, 0.01, z))
		grid_mesh.surface_add_vertex(Vector3(-hx, 4.0, z))
		grid_mesh.surface_add_vertex(Vector3(hx, 4.0, z))
	grid_mesh.surface_end()

func _build_interior_wall(parent: Node3D, pos: Vector3, size: Vector3, accent_color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.04, 0.09)
	mat.emission_enabled = true
	mat.emission = accent_color
	mat.emission_energy_multiplier = 3.0
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	parent.add_child(body)

func _build_interior_pillar(parent: Node3D, pos: Vector3, size: Vector3, glow_color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.06, 0.12)
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 2.5
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	parent.add_child(body)

func _build_interior_desk(parent: Node3D, pos: Vector3, size: Vector3, glow_color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.08, 0.15)
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 3.5
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	parent.add_child(body)

func _build_exit_door(parent: Node3D, pos: Vector3) -> void:
	var door_node = Node3D.new()
	door_node.name = "IndoorExitDoor"
	door_node.position = pos

	var frame_inst = MeshInstance3D.new()
	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(3.2, 3.2, 0.4)
	frame_inst.mesh = frame_box
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.05, 0.1, 0.15)
	frame_mat.emission_enabled = true
	frame_mat.emission = Color(1.0, 0.0, 0.8) # Radiant Magenta Exit Door
	frame_mat.emission_energy_multiplier = 6.0
	frame_inst.material_override = frame_mat
	door_node.add_child(frame_inst)

	parent.add_child(door_node)

func _build_elevator_shaft(parent: Node3D, pos: Vector3) -> void:
	var elev_node = Node3D.new()
	elev_node.name = "ElevatorShaft"
	elev_node.position = pos

	# Elevator Door Frame (Gold/Yellow Emission)
	var frame_inst = MeshInstance3D.new()
	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(3.6, 3.8, 0.6)
	frame_inst.mesh = frame_box
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.1, 0.08, 0.02)
	frame_mat.emission_enabled = true
	frame_mat.emission = Color(1.0, 0.85, 0.0) # High-energy Gold Elevator Frame
	frame_mat.emission_energy_multiplier = 5.0
	frame_inst.material_override = frame_mat
	elev_node.add_child(frame_inst)

	# Inner Lift Chamber
	var cab_inst = MeshInstance3D.new()
	var cab_box = BoxMesh.new()
	cab_box.size = Vector3(2.8, 3.2, 0.2)
	cab_inst.mesh = cab_box
	cab_inst.position = Vector3(0.0, 0.0, -0.2)
	var cab_mat = StandardMaterial3D.new()
	cab_mat.albedo_color = Color(0.02, 0.02, 0.03)
	cab_inst.material_override = cab_mat
	elev_node.add_child(cab_inst)

	# Spotlight
	var spot = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.85, 0.0)
	spot.light_energy = 6.0
	spot.spot_range = 8.0
	spot.spot_angle = 35.0
	spot.position = Vector3(0.0, 2.0, 0.5)
	spot.rotation_degrees = Vector3(25, 0, 0)
	elev_node.add_child(spot)

	parent.add_child(elev_node)

func _build_interactive_door(parent: Node3D, pos: Vector3, size: Vector3, door_color: Color) -> Node3D:
	var door_body = StaticBody3D.new()
	door_body.name = "InteractiveServerDoor"
	door_body.position = pos

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	door_body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.05, 0.02)
	mat.emission_enabled = true
	mat.emission = door_color
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat
	door_body.add_child(mesh_inst)

	parent.add_child(door_body)
	return door_body

func _spawn_npc_character(parent: Node3D, pos: Vector3, glow_color: Color, npc_name: String, look_target: Vector3) -> Node3D:
	var npc_node = CharacterBody3D.new()
	npc_node.name = npc_name
	npc_node.position = pos

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.04, 0.04, 0.07)

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = glow_color
	head_mat.emission_enabled = true
	head_mat.emission = glow_color
	head_mat.emission_energy_multiplier = 4.0

	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.15
	body_mesh.height = 1.2
	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0.0, 0.6, 0.0)
	npc_node.add_child(body_inst)

	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	var head_inst = MeshInstance3D.new()
	head_inst.mesh = head_mesh
	head_inst.material_override = head_mat
	head_inst.position = Vector3(0.0, 1.35, 0.0)
	npc_node.add_child(head_inst)

	# Visor pointer
	var nose_mat = StandardMaterial3D.new()
	nose_mat.albedo_color = glow_color
	nose_mat.emission_enabled = true
	nose_mat.emission = glow_color
	nose_mat.emission_energy_multiplier = 4.0
	var nose_mesh = PrismMesh.new()
	nose_mesh.size = Vector3(0.12, 0.12, 0.22)
	var nose_inst = MeshInstance3D.new()
	nose_inst.mesh = nose_mesh
	nose_inst.material_override = nose_mat
	nose_inst.position = Vector3(0.0, 0.0, -0.2)
	nose_inst.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	head_inst.add_child(nose_inst)

	parent.add_child(npc_node)
	if look_target != pos:
		npc_node.look_at(look_target, Vector3.UP)
	return npc_node

# ==============================================================================
# CAMERA & HUD OVERLAY
# ==============================================================================
func _setup_indoor_camera() -> void:
	indoor_camera = Camera3D.new()
	indoor_camera.name = "IndoorTacticalCamera"
	indoor_camera.position = lobby_floor_origin + Vector3(0.0, 24.0, 0.0)
	indoor_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # South door at bottom, North interior at top
	indoor_camera.fov = 65.0
	indoor_camera.current = false
	add_child(indoor_camera)

	indoor_fp_camera = Camera3D.new()
	indoor_fp_camera.name = "IndoorFirstPersonCamera"
	indoor_fp_camera.fov = 85.0
	indoor_fp_camera.current = false
	add_child(indoor_fp_camera)

func _setup_indoor_hud() -> void:
	indoor_hud_layer = CanvasLayer.new()
	indoor_hud_layer.name = "IndoorHUDLayer"
	indoor_hud_layer.layer = 12
	indoor_hud_layer.visible = false
	add_child(indoor_hud_layer)

	var font_res = load("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")
	indoor_title_label = Label.new()
	indoor_title_label.position = Vector2(30, 30)
	indoor_title_label.text = "DUNCAN DYNAMICS HQ\n // FLOOR 01: GROUND LOBBY\n TACTICAL TOP-DOWN MODE [V]"
	if font_res:
		indoor_title_label.add_theme_font_override("font", font_res)
	indoor_title_label.add_theme_font_size_override("font_size", 18)
	indoor_title_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	indoor_hud_layer.add_child(indoor_title_label)

	# Camera View Mode Key Hint
	indoor_view_label = Label.new()
	indoor_view_label.position = Vector2(30, 105)
	indoor_view_label.text = "[V] TOGGLE VIEW: PRESS 'V' FOR FIRST-PERSON VIEW"
	if font_res:
		indoor_view_label.add_theme_font_override("font", font_res)
	indoor_view_label.add_theme_font_size_override("font_size", 13)
	indoor_view_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	indoor_hud_layer.add_child(indoor_view_label)

	# Interaction Prompt Label
	_indoor_prompt_label = Label.new()
	_indoor_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_indoor_prompt_label.anchor_top = 0.85
	_indoor_prompt_label.anchor_bottom = 0.85
	_indoor_prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if font_res:
		_indoor_prompt_label.add_theme_font_override("font", font_res)
	_indoor_prompt_label.add_theme_font_size_override("font_size", 22)
	_indoor_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_indoor_prompt_label.visible = false
	indoor_hud_layer.add_child(_indoor_prompt_label)

# ==============================================================================
# ENTER / EXIT & LOCATION TRANSITIONS
# ==============================================================================
func enter_location(target_floor: HQFloor) -> void:
	if is_inside_building:
		return

	is_inside_building = true
	current_floor = target_floor
	print("[INDOOR SYSTEM] Entering interior location: ", target_floor)

	var origin: Vector3 = _get_origin_for_floor(current_floor)
	var spawn_z: float = 6.0
	if current_floor == HQFloor.LOBBY:
		spawn_z = 12.0
	elif current_floor == HQFloor.MACK_HIDEOUT:
		spawn_z = 6.5
	elif current_floor == HQFloor.LADY_M_LAIR:
		spawn_z = 7.5
	elif current_floor == HQFloor.CHOP_SHOP:
		spawn_z = 9.5

	if is_instance_valid(player_car) and player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		saved_player_position = player_car.on_foot_node.global_position
		player_car.on_foot_node.global_position = origin + Vector3(0.0, 0.0, spawn_z)
		# South entrance door is at +Z (bottom of top-down view).
		# Facing 0° (North / up screen) puts player's back to entrance door stepping into the room.
		player_car.on_foot_node.rotation_degrees.y = 0.0
		if player_car.on_foot_node.get("_facing_angle") != null:
			player_car.on_foot_node.set("_facing_angle", 0.0)

	if indoor_view_mode == "FIRST_PERSON" and is_instance_valid(indoor_fp_camera):
		indoor_fp_camera.current = true
	else:
		indoor_camera.current = true
	indoor_hud_layer.visible = true
	_update_hud_floor_label()

func toggle_indoor_view_mode() -> void:
	if not is_inside_building:
		return

	if indoor_view_mode == "TOPDOWN":
		indoor_view_mode = "FIRST_PERSON"
		_fp_pitch = 0.0
		if is_instance_valid(indoor_fp_camera):
			indoor_fp_camera.current = true
	else:
		indoor_view_mode = "TOPDOWN"
		if is_instance_valid(indoor_camera):
			indoor_camera.current = true
	_update_hud_floor_label()

func exit_building_interior() -> void:
	if not is_inside_building:
		return

	is_inside_building = false
	indoor_view_mode = "TOPDOWN"
	_fp_pitch = 0.0
	print("[INDOOR SYSTEM] Exiting interior, returning to city street...")

	if is_instance_valid(player_car) and player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		var target_exit: Vector3 = saved_player_position
		if current_floor == HQFloor.LOBBY or current_floor == HQFloor.PENTHOUSE:
			target_exit = city_gen.hq_door_pos if is_instance_valid(city_gen) and city_gen.hq_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.MACK_HIDEOUT:
			target_exit = city_gen.banquo_safehouse_door_pos if is_instance_valid(city_gen) and city_gen.banquo_safehouse_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.LADY_M_LAIR:
			target_exit = city_gen.lady_m_lair_door_pos if is_instance_valid(city_gen) and city_gen.lady_m_lair_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.CHOP_SHOP:
			target_exit = city_gen.chop_shop_door_pos if is_instance_valid(city_gen) and city_gen.chop_shop_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.PORTER_PIT:
			target_exit = city_gen.porter_pit_door_pos if is_instance_valid(city_gen) and city_gen.porter_pit_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.NORNS_AI:
			target_exit = city_gen.norns_ai_door_pos if is_instance_valid(city_gen) and city_gen.norns_ai_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.FIFE_HQ:
			target_exit = city_gen.fife_hq_door_pos if is_instance_valid(city_gen) and city_gen.fife_hq_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.BANKES_LOGISTICS:
			target_exit = city_gen.bankes_logistics_door_pos if is_instance_valid(city_gen) and city_gen.bankes_logistics_door_pos != Vector3.ZERO else saved_player_position
		elif current_floor == HQFloor.SUBSTATION:
			target_exit = city_gen.power_substation_door_pos if is_instance_valid(city_gen) and city_gen.power_substation_door_pos != Vector3.ZERO else saved_player_position

		target_exit += Vector3(0.0, 0.0, 3.0)
		target_exit.y = 0.0
		var foot_node = player_car.on_foot_node
		foot_node.global_position = target_exit
		foot_node.scale = Vector3.ONE

		foot_node.set("_foot_zoom", 1.0)
		foot_node.set("_cam_yaw", 0.0)
		foot_node.set("_cam_pitch", 0.0)
		if "CAM_NEAR_OFFSET" in foot_node:
			foot_node.set("_cam_offset_current", foot_node.CAM_NEAR_OFFSET)

		if is_instance_valid(foot_node.camera):
			foot_node.camera.current = true
			foot_node.camera.fov = 95.0
			foot_node._update_camera(0.01)

	indoor_hud_layer.visible = false
	if is_instance_valid(_indoor_prompt_label):
		_indoor_prompt_label.visible = false

func switch_to_floor(target_floor: HQFloor) -> void:
	current_floor = target_floor
	var target_origin: Vector3 = _get_origin_for_floor(current_floor)
	var spawn_offset: Vector3 = Vector3(0.0, 0.0, -11.0) if current_floor == HQFloor.LOBBY else Vector3(0.0, 0.0, 11.0)
	var facing_deg: float = 180.0 if current_floor == HQFloor.LOBBY else 0.0

	print("[ELEVATOR LIFT] Transporting Mack to ", ("LOBBY" if current_floor == HQFloor.LOBBY else "PENTHOUSE"))

	if is_instance_valid(player_car) and player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
		player_car.on_foot_node.global_position = target_origin + spawn_offset
		player_car.on_foot_node.rotation_degrees.y = facing_deg
		if player_car.on_foot_node.get("_facing_angle") != null:
			player_car.on_foot_node.set("_facing_angle", deg_to_rad(facing_deg))

	_update_hud_floor_label()

func _get_origin_for_floor(fl: HQFloor) -> Vector3:
	match fl:
		HQFloor.LOBBY:
			return lobby_floor_origin
		HQFloor.PENTHOUSE:
			return penthouse_floor_origin
		HQFloor.MACK_HIDEOUT:
			return mack_hideout_origin
		HQFloor.BANQUO_LOFT:
			return banquo_loft_origin
		HQFloor.LADY_M_LAIR:
			return lady_m_lair_origin
		HQFloor.CHOP_SHOP:
			return chop_shop_origin
		HQFloor.PORTER_PIT:
			return porter_pit_origin
		HQFloor.NORNS_AI:
			return norns_ai_origin
		HQFloor.FIFE_HQ:
			return fife_hq_origin
		HQFloor.BANKES_LOGISTICS:
			return bankes_logistics_origin
		HQFloor.SUBSTATION:
			return substation_origin
	return lobby_floor_origin

func _update_hud_floor_label() -> void:
	if is_instance_valid(indoor_view_label):
		if indoor_view_mode == "FIRST_PERSON":
			indoor_view_label.text = "[V] TOGGLE VIEW: PRESS 'V' FOR TOP-DOWN VIEW"
		else:
			indoor_view_label.text = "[V] TOGGLE VIEW: PRESS 'V' FOR FIRST-PERSON VIEW"

	if is_instance_valid(indoor_title_label):
		var mode_suffix: String = "FIRST-PERSON MODE [V]" if indoor_view_mode == "FIRST_PERSON" else "TACTICAL TOP-DOWN MODE [V]"
		match current_floor:
			HQFloor.LOBBY:
				indoor_title_label.text = "DUNCAN DYNAMICS HQ\n // FLOOR 01: GROUND LOBBY\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
			HQFloor.PENTHOUSE:
				indoor_title_label.text = "DUNCAN DYNAMICS HQ\n // FLOOR 99: EXECUTIVE PENTHOUSE & SERVER VAULT\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.6))
			HQFloor.MACK_HIDEOUT:
				indoor_title_label.text = "MACK'S SAFEHOUSE\n // APARTMENT & WORKSHOP\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
			HQFloor.BANQUO_LOFT:
				indoor_title_label.text = "BANQUO'S PRIVATE LOFT\n // RESIDENTIAL HIGH-RISE APARTMENT\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
			HQFloor.LADY_M_LAIR:
				indoor_title_label.text = "LADY M'S NETRUNNER VAULT\n // UNDERGROUND LAIR\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.8))
			HQFloor.CHOP_SHOP:
				indoor_title_label.text = "REDLINE CHOP SHOP\n // CUSTOM GARAGE & TUNE-UP BAY\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			HQFloor.PORTER_PIT:
				indoor_title_label.text = "THE PIT SUBTERRANEAN GARAGE\n // PORTER'S BLACK-MARKET HUB\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
			HQFloor.NORNS_AI:
				indoor_title_label.text = "DEEP-WEB SUBSTATION #03-NORNS\n // THE 3 AI NORNS TERMINAL\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(0.7, 0.1, 1.0))
			HQFloor.FIFE_HQ:
				indoor_title_label.text = "FIFE PATROL HEADQUARTERS\n // MACDUFF'S CITADEL\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(0.1, 0.5, 1.0))
			HQFloor.BANKES_LOGISTICS:
				indoor_title_label.text = "CAWDOR LOGISTICS DEPOT\n // BANKES' PATROL HUB\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1))
			HQFloor.SUBSTATION:
				indoor_title_label.text = "SUB-GRID POWER SUBSTATION 09\n // GRID BLACKOUT TARGET\n " + mode_suffix
				indoor_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))

# ==============================================================================
# PROCESS LOOP & INTERACTION PROMPTS
# ==============================================================================
func _process(_delta: float) -> void:
	if not is_inside_building or not is_instance_valid(player_car):
		return

	var player_node: Node3D = player_car.on_foot_node if (player_car.is_on_foot and is_instance_valid(player_car.on_foot_node)) else null
	if not is_instance_valid(player_node):
		return

	var current_origin: Vector3 = _get_origin_for_floor(current_floor)
	if indoor_view_mode == "TOPDOWN":
		if is_instance_valid(indoor_camera):
			indoor_camera.global_position = Vector3(player_node.global_position.x, current_origin.y + 24.0, player_node.global_position.z + 0.1)
			indoor_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			indoor_camera.current = true
	else:
		if is_instance_valid(indoor_fp_camera):
			indoor_fp_camera.global_position = player_node.global_position + Vector3(0.0, 1.65, 0.0)
			indoor_fp_camera.rotation = Vector3(_fp_pitch, player_node.rotation.y, 0.0)
			indoor_fp_camera.current = true

	# --- INTERACTION PROMPT DETECTION ---
	var pos: Vector3 = player_node.global_position
	var prompt_text: String = ""
	var exit_target_z: float = 13.5

	if current_floor == HQFloor.MACK_HIDEOUT:
		exit_target_z = 8.2
	elif current_floor == HQFloor.LADY_M_LAIR:
		exit_target_z = 9.2
	elif current_floor == HQFloor.CHOP_SHOP or current_floor == HQFloor.PORTER_PIT or current_floor == HQFloor.NORNS_AI or current_floor == HQFloor.BANKES_LOGISTICS:
		exit_target_z = 11.2
	elif current_floor == HQFloor.FIFE_HQ:
		exit_target_z = 14.2
	elif current_floor == HQFloor.SUBSTATION:
		exit_target_z = 9.2

	var floor_exit_pos: Vector3 = current_origin + Vector3(0.0, 0.0, exit_target_z)

	if current_floor == HQFloor.LOBBY:
		if pos.distance_to(exit_door_pos) <= 4.5:
			prompt_text = "[E] EXIT TO CITY STREETS"
		elif pos.distance_to(lobby_elevator_pos) <= 4.5:
			prompt_text = "[E] TAKE ELEVATOR UP TO PENTHOUSE (CEO SUITE)"
	elif current_floor == HQFloor.PENTHOUSE:
		if pos.distance_to(penthouse_elevator_pos) <= 4.5:
			prompt_text = "[E] TAKE ELEVATOR DOWN TO GROUND LOBBY"
		elif pos.distance_to(penthouse_server_door_pos) <= 4.5:
			if not is_server_door_open:
				prompt_text = "[E] OPEN SECURITY DOOR // SERVER VAULT"
			else:
				prompt_text = "[E] CLOSE SECURITY DOOR"
	else:
		if current_floor == HQFloor.MACK_HIDEOUT:
			var mack_pos: Vector3 = mack_hideout_origin + Vector3(0.0, 0.0, -5.5)
			if pos.distance_to(mack_pos) <= 4.0:
				prompt_text = "[E] TALK TO COMMANDER MACK"
			elif pos.distance_to(floor_exit_pos) <= 4.5:
				prompt_text = "[E] EXIT TO CITY STREETS"
		elif current_floor == HQFloor.PORTER_PIT:
			var terminal_pos: Vector3 = porter_pit_origin + Vector3(-10.0, 0.0, 0.0)
			var cyborg_terminal_pos: Vector3 = porter_pit_origin + Vector3(10.0, 0.0, 0.0)
			var wartable_pos: Vector3 = porter_pit_origin + Vector3(0.0, 0.0, 4.0)
			if pos.distance_to(terminal_pos) <= 4.0:
				prompt_text = "[E] ACCESS PIT GARAGE & FLEET MANAGER"
			elif pos.distance_to(cyborg_terminal_pos) <= 4.0:
				prompt_text = "[E] ACCESS MACK'S NEURAL CYBORG MODDING SUITE"
			elif pos.distance_to(wartable_pos) <= 4.0:
				prompt_text = "[E] ACCESS WAR-TABLE // DEPLOY MACK TO GRAND HIT"
			elif pos.distance_to(floor_exit_pos) <= 4.5:
				prompt_text = "[E] EXIT TO CITY STREETS"
		elif current_floor == HQFloor.BANKES_LOGISTICS:
			var bankes_server_pos: Vector3 = bankes_logistics_origin + Vector3(0.0, 0.0, -2.0)
			if pos.distance_to(bankes_server_pos) <= 4.0:
				prompt_text = "[E] SEVER BANKES LOGISTICS SHIELD UPLINK"
			elif pos.distance_to(floor_exit_pos) <= 4.5:
				prompt_text = "[E] EXIT TO CITY STREETS"
		elif current_floor == HQFloor.SUBSTATION:
			var sub_breaker_pos: Vector3 = substation_origin + Vector3(0.0, 0.0, -6.0)
			if pos.distance_to(sub_breaker_pos) <= 4.0:
				prompt_text = "[E] CUT SUBSTATION 09 POWER GRID // SEVER NORNS FEED"
			elif pos.distance_to(floor_exit_pos) <= 4.5:
				prompt_text = "[E] EXIT TO CITY STREETS"
		elif pos.distance_to(floor_exit_pos) <= 4.5:
			prompt_text = "[E] EXIT TO CITY STREETS"

	if is_instance_valid(_indoor_prompt_label):
		if prompt_text != "":
			_indoor_prompt_label.text = prompt_text
			_indoor_prompt_label.visible = true
		else:
			_indoor_prompt_label.visible = false

func _input(event: InputEvent) -> void:
	if not is_inside_building:
		return

	if indoor_view_mode == "FIRST_PERSON" and event is InputEventMouseMotion:
		_fp_pitch = clamp(_fp_pitch - event.relative.y * 0.004, -1.2, 1.2)
		if is_instance_valid(player_car) and is_instance_valid(player_car.on_foot_node):
			var foot_node = player_car.on_foot_node
			foot_node.rotation.y -= event.relative.x * 0.004
			if foot_node.get("_facing_angle") != null:
				foot_node.set("_facing_angle", foot_node.rotation.y)

# Listen for key presses while inside interior
func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_building or not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_V:
		toggle_indoor_view_mode()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_E:
		var player_node: Node3D = player_car.on_foot_node if (player_car.is_on_foot and is_instance_valid(player_car.on_foot_node)) else null
		if not is_instance_valid(player_node):
			return

		var pos: Vector3 = player_node.global_position

		if current_floor == HQFloor.LOBBY:
			if pos.distance_to(exit_door_pos) <= 4.5:
				exit_building_interior()
				get_viewport().set_input_as_handled()
			elif pos.distance_to(lobby_elevator_pos) <= 4.5:
				switch_to_floor(HQFloor.PENTHOUSE)
				get_viewport().set_input_as_handled()

		elif current_floor == HQFloor.PENTHOUSE:
			if pos.distance_to(penthouse_elevator_pos) <= 4.5:
				switch_to_floor(HQFloor.LOBBY)
				get_viewport().set_input_as_handled()
			elif pos.distance_to(penthouse_server_door_pos) <= 4.5:
				_toggle_server_vault_door()
				get_viewport().set_input_as_handled()
		else:
			var current_origin: Vector3 = _get_origin_for_floor(current_floor)
			var exit_target_z: float = 8.2 if current_floor == HQFloor.MACK_HIDEOUT else (9.2 if current_floor == HQFloor.LADY_M_LAIR else 11.2)
			var floor_exit_pos: Vector3 = current_origin + Vector3(0.0, 0.0, exit_target_z)
			
			if current_floor == HQFloor.MACK_HIDEOUT:
				var mack_pos: Vector3 = mack_hideout_origin + Vector3(0.0, 0.0, -5.5)
				var bed_pos: Vector3 = mack_hideout_origin + Vector3(8.0, 0.0, -2.0)
				if pos.distance_to(mack_pos) <= 4.0:
					var dialogue_sys = get_parent().get_node_or_null("DialogueSystem")
					if is_instance_valid(dialogue_sys):
						dialogue_sys.start_dialogue("res://scripts/mack_dialogue.json")
						get_viewport().set_input_as_handled()
						return
				elif pos.distance_to(bed_pos) <= 4.5 or pos.distance_to(mack_pos) <= 7.0:
					var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
					if is_instance_valid(campaign_mgr):
						campaign_mgr.advance_to_next_day()
						get_viewport().set_input_as_handled()
						return
			
			if current_floor == HQFloor.PORTER_PIT:
				var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
				if is_instance_valid(campaign_mgr) and campaign_mgr.is_norns_recovery_active:
					campaign_mgr.is_norns_recovery_active = false
					if is_instance_valid(campaign_mgr.norns_recovery_node):
						campaign_mgr.norns_recovery_node.queue_free()
					var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
					if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
						neural_comms.send_message("RECOVERY QUEST COMPLETE! Mack's War-Rig delivered to The Pit Garage! Full thermal overhaul complete (+400 C fee refunded).", "NORNS RECOVERY SUCCESS")
					var quest_mgr = get_parent().get_node_or_null("QuestManager")
					if is_instance_valid(quest_mgr):
						quest_mgr.player_credits += 400

				var terminal_pos: Vector3 = porter_pit_origin + Vector3(-10.0, 0.0, 0.0)
				var cyborg_terminal_pos: Vector3 = porter_pit_origin + Vector3(10.0, 0.0, 0.0)
				var wartable_pos: Vector3 = porter_pit_origin + Vector3(0.0, 0.0, 4.0)
				if pos.distance_to(terminal_pos) <= 4.0:
					var garage_mgr = get_parent().get_node_or_null("GarageManager")
					if is_instance_valid(garage_mgr):
						garage_mgr.open_garage_ui()
						get_viewport().set_input_as_handled()
						return
				elif pos.distance_to(cyborg_terminal_pos) <= 4.0:
					var cyborg_mgr = get_parent().get_node_or_null("CyborgModdingManager")
					if is_instance_valid(cyborg_mgr):
						cyborg_mgr.open_cyborg_ui()
						get_viewport().set_input_as_handled()
						return
				elif pos.distance_to(wartable_pos) <= 4.0:
					if is_instance_valid(campaign_mgr):
						campaign_mgr.open_deployment_ui()
						get_viewport().set_input_as_handled()
						return
			
			if current_floor == HQFloor.BANKES_LOGISTICS:
				var bankes_server_pos: Vector3 = bankes_logistics_origin + Vector3(0.0, 0.0, -2.0)
				if pos.distance_to(bankes_server_pos) <= 4.0:
					var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
					if is_instance_valid(campaign_mgr):
						if campaign_mgr.is_bankes_server_mission_active:
							campaign_mgr.is_bankes_server_mission_active = false
							campaign_mgr.side_mission_active = false
							campaign_mgr.mack_current_hp = min(campaign_mgr.mack_max_hp, campaign_mgr.mack_current_hp + 45.0)
							campaign_mgr.mack_current_action = "Bankes Shield Uplink severed! Gatling output restored (+45 HP)."
							
							var quest_mgr = get_parent().get_node_or_null("QuestManager")
							if is_instance_valid(quest_mgr):
								quest_mgr.player_credits += 800
							
							var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
							if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
								neural_comms.send_message("BANKES SHIELD UPLINK SEVERED! Convoy shielding offline! +800 Credits awarded.", "EMERGENCY MISSION COMPLETE")
							
							get_viewport().set_input_as_handled()
							return

			if current_floor == HQFloor.SUBSTATION:
				var sub_breaker_pos: Vector3 = substation_origin + Vector3(0.0, 0.0, -6.0)
				if pos.distance_to(sub_breaker_pos) <= 4.0:
					var campaign_mgr = get_parent().get_node_or_null("CampaignManager")
					if is_instance_valid(campaign_mgr):
						if campaign_mgr.is_substation_side_mission_active:
							campaign_mgr.is_substation_side_mission_active = false
							campaign_mgr.side_mission_active = false
							campaign_mgr.mack_current_hp = min(campaign_mgr.mack_max_hp, campaign_mgr.mack_current_hp + 40.0)
							campaign_mgr.mack_current_action = "Substation 09 severed! Norns phantoms purged (+40 HP)."
							
							var quest_mgr = get_parent().get_node_or_null("QuestManager")
							if is_instance_valid(quest_mgr):
								quest_mgr.player_credits += 750
							
							var neural_comms = get_parent().get_node_or_null("NeuralNotificationSystem")
							if is_instance_valid(neural_comms) and neural_comms.has_method("send_message"):
								neural_comms.send_message("SUBSTATION 09 POWER CUT! Norns AI ocular interference purged from Mack's War-Rig! +750 Credits awarded.", "EMERGENCY MISSION COMPLETE")
							
							get_viewport().set_input_as_handled()
							return

			if pos.distance_to(floor_exit_pos) <= 4.5:
				exit_building_interior()
				get_viewport().set_input_as_handled()

func _toggle_server_vault_door() -> void:
	is_server_door_open = not is_server_door_open
	if is_instance_valid(server_door_node):
		if is_server_door_open:
			server_door_node.position.x = penthouse_floor_origin.x - 8.0 + 3.2
			print("[SECURITY DOOR] Server Vault Door Unlocked & Opened!")
		else:
			server_door_node.position.x = penthouse_floor_origin.x - 8.0
			print("[SECURITY DOOR] Server Vault Door Closed & Locked.")
