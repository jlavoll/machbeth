extends Node3D
class_name TransitSystem

# ==============================================================================
# CYBER-TRANSIT BUS & LIGHTRAIL SYSTEM (TransitSystem.gd)
# ==============================================================================
# Manages heavy Cyber-Busses running along main city avenues.
# - Spawns 3-4 heavy neon transit busses with glowing route banners.
# - Busses follow Broadway/Main Avenue loops with A* navigation.
# - Busses decelerate & stop at Transit Stations for 8.0 seconds.
# - Disembarking: Pedestrians leave the bus onto the sidewalk.
# - Boarding: Waiting pedestrians on the sidewalk walk to the bus door & enter.

# Transit Bus Structure: Dictionary
# {
#   "node": Node3D, "mesh": MeshInstance3D, "label": Label3D,
#   "route_stops": Array[Vector3], "current_stop_idx": int,
#   "state": String, "stop_timer": float, "speed": float,
#   "passengers": Array[Node3D]
# }
var active_busses: Array[Dictionary] = []
var transit_stations: Array[Vector3] = []

# Mesh Assets
var bus_box_mesh: BoxMesh = null
var bus_material: StandardMaterial3D = null
var stop_shelter_mesh: BoxMesh = null

func _ready() -> void:
	_create_bus_assets()
	call_deferred("_setup_transit_network")

func _create_bus_assets() -> void:
	bus_box_mesh = BoxMesh.new()
	bus_box_mesh.size = Vector3(3.8, 3.2, 9.0)
	
	bus_material = StandardMaterial3D.new()
	bus_material.albedo_color = Color(0.04, 0.08, 0.14) # Heavy Slate Blue Steel
	bus_material.metallic = 0.8
	bus_material.roughness = 0.3
	bus_material.emission_enabled = true
	bus_material.emission = Color(0.0, 0.85, 1.0) # Glowing Cyan Trim
	bus_material.emission_energy_multiplier = 2.0
	
	stop_shelter_mesh = BoxMesh.new()
	stop_shelter_mesh.size = Vector3(4.0, 2.8, 1.2)

func _setup_transit_network() -> void:
	var city_gen = get_parent().get_node_or_null("CityGenerator")
	if not is_instance_valid(city_gen): return

	var x_cuts: Array = city_gen.active_x_streets if "active_x_streets" in city_gen and city_gen.active_x_streets.size() > 1 else [-180.0, -90.0, 0.0, 90.0, 180.0]
	var z_cuts: Array = city_gen.active_z_streets if "active_z_streets" in city_gen and city_gen.active_z_streets.size() > 1 else [-180.0, -90.0, 0.0, 90.0, 180.0]

	# Pick 2 major perpendicular street axes (Central Broadway X and Main Avenue Z)
	var main_x_street: float = city_gen.active_broadway_x if "active_broadway_x" in city_gen else x_cuts[x_cuts.size() / 2]
	var main_z_street: float = city_gen.active_broadway_z if "active_broadway_z" in city_gen else z_cuts[z_cuts.size() / 2]

	var north_z: float = z_cuts[0]
	var south_z: float = z_cuts[z_cuts.size() - 1]
	var west_x: float = x_cuts[0]
	var east_x: float = x_cuts[x_cuts.size() - 1]

	# Define 4 Major Cyber-Transit Stations strictly positioned along street curb lanes
	transit_stations = [
		Vector3(main_x_street + 4.5, 0.0, north_z), # Station 01: North Gate Station
		Vector3(main_x_street + 4.5, 0.0, 0.0),     # Station 02: Central Duncan Dynamics HQ
		Vector3(main_x_street + 4.5, 0.0, south_z), # Station 03: South Pit Garage Station
		Vector3(west_x, 0.0, main_z_street + 4.5)   # Station 04: West Park Station
	]

	# Lock route to 90-degree street corridor grid intersections (avoids clipping through building plots)
	var route_01: Array[Vector3] = [
		Vector3(main_x_street + 4.5, 0.0, north_z),     # Station 01 (North Broadway)
		Vector3(main_x_street + 4.5, 0.0, 0.0),        # Station 02 (Central HQ)
		Vector3(main_x_street + 4.5, 0.0, south_z),     # Station 03 (South Pit)
		Vector3(main_x_street + 4.5, 0.0, main_z_street + 4.5), # Broadway / Main Ave Intersection
		Vector3(west_x, 0.0, main_z_street + 4.5),       # Station 04 (West Park)
		Vector3(west_x, 0.0, north_z),                   # West-North Intersection Turn
		Vector3(main_x_street + 4.5, 0.0, north_z)      # Return to Station 01
	]

	var route_02: Array[Vector3] = route_01

	_spawn_station_shelters()
	_spawn_cyber_busses(route_01, route_02)

func _spawn_station_shelters() -> void:
	for i in range(transit_stations.size()):
		var st_pos = transit_stations[i]
		var shelter_node = Node3D.new()
		shelter_node.name = "TransitStation_%d" % (i + 1)
		shelter_node.position = st_pos
		add_child(shelter_node)
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = stop_shelter_mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.1, 0.15, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.0, 1.0, 0.85) # Cyan Glow Glass
		mat.emission_energy_multiplier = 1.5
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0.0, 1.4, 0.0)
		shelter_node.add_child(mesh_inst)

		# Solid Physical Collider for Station Shelter
		var shelter_body = StaticBody3D.new()
		shelter_body.name = "StationShelterCollider"
		shelter_body.collision_layer = 1 | 2
		shelter_body.collision_mask = 1 | 2
		var shelter_col = CollisionShape3D.new()
		var shelter_box = BoxShape3D.new()
		shelter_box.size = Vector3(4.0, 2.8, 1.2)
		shelter_col.shape = shelter_box
		shelter_col.position = Vector3(0.0, 1.4, 0.0)
		shelter_body.add_child(shelter_col)
		shelter_node.add_child(shelter_body)
		
		# Holographic Station Label
		var label = Label3D.new()
		label.text = "🚏 CYBER-TRANSIT STATION %02d\n[LINE 01: CITY CENTRAL LOOP]" % (i + 1)
		label.position = Vector3(0.0, 3.2, 0.0)
		label.font_size = 20
		label.pixel_size = 0.004
		label.modulate = Color(0.0, 0.85, 1.0)
		shelter_node.add_child(label)

func _spawn_cyber_busses(route_01: Array[Vector3], route_02: Array[Vector3]) -> void:
	var routes = [route_01, route_02]
	for b_idx in range(1): # 1 single Cyber-Transit streetcar bus running the main loop
		var bus_node = AnimatableBody3D.new()
		bus_node.name = "CyberBus_%d" % (b_idx + 1)
		bus_node.collision_layer = 1 | 2
		bus_node.collision_mask = 1 | 2
		bus_node.sync_to_physics = false

		# Solid Physical Collider for Moving Street Car
		var bus_col = CollisionShape3D.new()
		var bus_col_shape = BoxShape3D.new()
		bus_col_shape.size = Vector3(3.6, 3.0, 8.8) # Snug physical collision box
		bus_col.shape = bus_col_shape
		bus_col.position = Vector3(0.0, 0.0, 0.0)
		bus_node.add_child(bus_col)

		var bus_route: Array[Vector3] = routes[b_idx]
		bus_node.position = bus_route[0] + Vector3(0.0, 1.6, 0.0)
		add_child(bus_node)
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = bus_box_mesh
		mesh_inst.material_override = bus_material
		bus_node.add_child(mesh_inst)

		# 1. Tinted Dark Cyber Glass Windshield & Side Windows
		var glass_window_mesh_instance = MeshInstance3D.new()
		var glass_box = BoxMesh.new()
		glass_box.size = Vector3(3.85, 1.1, 8.4)
		glass_window_mesh_instance.mesh = glass_box
		glass_window_mesh_instance.position = Vector3(0.0, 0.4, 0.0)

		var streetcar_glass_material = StandardMaterial3D.new()
		streetcar_glass_material.albedo_color = Color(0.02, 0.08, 0.14)
		streetcar_glass_material.metallic = 0.95
		streetcar_glass_material.roughness = 0.1
		glass_window_mesh_instance.material_override = streetcar_glass_material
		bus_node.add_child(glass_window_mesh_instance)

		# 2. Front Headlight Light Bars (High Cyan Emission)
		var front_headlight_mesh_instance = MeshInstance3D.new()
		var headlight_box = BoxMesh.new()
		headlight_box.size = Vector3(3.2, 0.25, 0.1)
		front_headlight_mesh_instance.mesh = headlight_box
		front_headlight_mesh_instance.position = Vector3(0.0, -0.6, -4.52)

		var headlight_material = StandardMaterial3D.new()
		headlight_material.albedo_color = Color(0.0, 0.9, 1.0)
		headlight_material.emission_enabled = true
		headlight_material.emission = Color(0.0, 0.9, 1.0)
		headlight_material.emission_energy_multiplier = 6.0
		front_headlight_mesh_instance.material_override = headlight_material
		bus_node.add_child(front_headlight_mesh_instance)

		# 3. Rear Red Brake Lights
		var rear_taillight_mesh_instance = MeshInstance3D.new()
		var taillight_box = BoxMesh.new()
		taillight_box.size = Vector3(3.2, 0.25, 0.1)
		rear_taillight_mesh_instance.mesh = taillight_box
		rear_taillight_mesh_instance.position = Vector3(0.0, -0.6, 4.52)

		var taillight_material = StandardMaterial3D.new()
		taillight_material.albedo_color = Color(1.0, 0.05, 0.2)
		taillight_material.emission_enabled = true
		taillight_material.emission = Color(1.0, 0.05, 0.2)
		taillight_material.emission_energy_multiplier = 6.0
		rear_taillight_mesh_instance.material_override = taillight_material
		bus_node.add_child(rear_taillight_mesh_instance)

		# 4. Roof Overhead Pantograph Power Connector Frame
		var pantograph_frame_instance = MeshInstance3D.new()
		var pantograph_box = BoxMesh.new()
		pantograph_box.size = Vector3(1.2, 0.6, 1.6)
		pantograph_frame_instance.mesh = pantograph_box
		pantograph_frame_instance.position = Vector3(0.0, 1.9, 0.0)

		var pantograph_material = StandardMaterial3D.new()
		pantograph_material.albedo_color = Color(0.1, 0.12, 0.15)
		pantograph_material.metallic = 0.9
		pantograph_material.roughness = 0.2
		pantograph_frame_instance.material_override = pantograph_material
		bus_node.add_child(pantograph_frame_instance)

		# 5. Glowing Front Route Banner
		var banner = Label3D.new()
		banner.text = "🚌 LINE 01 // METRO TRANSIT EXPRESS"
		banner.position = Vector3(0.0, 2.0, -4.6)
		banner.font_size = 18
		banner.pixel_size = 0.004
		banner.modulate = Color(1.0, 0.85, 0.0)
		bus_node.add_child(banner)
		
		active_busses.append({
			"node": bus_node,
			"mesh": mesh_inst,
			"banner": banner,
			"route_waypoints": bus_route,
			"current_waypoint_idx": 0,
			"state": "DRIVING", # "DRIVING", "BOARDING"
			"stop_timer": 0.0,
			"speed": 14.0,
			"passengers": []
		})

# Player Passenger State
var is_player_riding_bus: bool = false
var current_riding_bus: Dictionary = {}

func _process(delta: float) -> void:
	var ped_sys = get_parent().get_node_or_null("PedestrianSystem")
	
	for bus in active_busses:
		var node: Node3D = bus["node"]
		if not is_instance_valid(node): continue
		
		var target_waypoint: Vector3 = bus["route_waypoints"][bus["current_waypoint_idx"]] + Vector3(0.0, 1.6, 0.0)
		
		if bus["state"] == "DRIVING":
			# Move toward target street waypoint
			var dir: Vector3 = (target_waypoint - node.position).normalized()
			var dist: float = node.position.distance_to(target_waypoint)
			
			if dist > 2.5:
				node.position += dir * bus["speed"] * delta
				if dir.length_squared() > 0.001:
					var target_look = node.position + dir
					if not target_look.is_equal_approx(node.position):
						node.look_at(target_look, Vector3.UP)
			else:
				# Reached waypoint! Check if this waypoint is a Transit Station
				var is_station_stop: bool = false
				for st in transit_stations:
					if (st + Vector3(0.0, 1.6, 0.0)).distance_to(target_waypoint) <= 3.0:
						is_station_stop = true
						break

				# Advance to next waypoint
				bus["current_waypoint_idx"] = (bus["current_waypoint_idx"] + 1) % bus["route_waypoints"].size()

				if is_station_stop:
					# Switch to BOARDING State at Station for 8 Seconds
					bus["state"] = "BOARDING"
					bus["stop_timer"] = 8.0
					_handle_bus_passenger_exchange(bus, ped_sys)
				
		elif bus["state"] == "BOARDING":
			bus["stop_timer"] -= delta
			if bus["stop_timer"] <= 0.0:
				# Finished boarding -> Resume driving
				bus["state"] = "DRIVING"

	# Synchronize player's position with bus if riding inside
	if is_player_riding_bus and current_riding_bus.has("node") and is_instance_valid(current_riding_bus["node"]):
		var player_car = get_parent().get_node_or_null("PlayerCar")
		if is_instance_valid(player_car) and player_car.is_on_foot and is_instance_valid(player_car.on_foot_node):
			var foot_node = player_car.on_foot_node
			foot_node.global_position = current_riding_bus["node"].global_position + Vector3(0.0, 1.2, 0.0)

func try_toggle_player_bus_passenger(foot_pos: Vector3, foot_node: Node3D) -> bool:
	if is_player_riding_bus:
		# Disembark from bus!
		is_player_riding_bus = false
		if current_riding_bus.has("node") and is_instance_valid(current_riding_bus["node"]):
			foot_node.global_position = current_riding_bus["node"].global_position + Vector3(3.5, -0.8, 0.0)
		foot_node.visible = true
		current_riding_bus = {}
		
		var comms = get_parent().get_node_or_null("NeuralNotificationSystem")
		if is_instance_valid(comms) and comms.has_method("send_message"):
			comms.send_message("🚏 DISEMBARKED CYBER-TRANSIT METRO EXPRESS. Enjoy your stay in the district!", "CYBER-TRANSIT METRO")
		return true
	else:
		# Board nearby stopping bus!
		for bus in active_busses:
			if bus.has("node") and is_instance_valid(bus["node"]):
				var bus_pos: Vector3 = bus["node"].global_position
				if foot_pos.distance_to(bus_pos) <= 8.0:
					is_player_riding_bus = true
					current_riding_bus = bus
					foot_node.visible = false
					
					var comms = get_parent().get_node_or_null("NeuralNotificationSystem")
					if is_instance_valid(comms) and comms.has_method("send_message"):
						comms.send_message("🚌 BOARDED CYBER-TRANSIT METRO EXPRESS! Sit back and enjoy the scenic loop through the city. Press 'E' anytime to step off.", "CYBER-TRANSIT METRO")
					return true
	return false

func _handle_bus_passenger_exchange(bus: Dictionary, ped_sys: Node) -> void:
	var bus_pos: Vector3 = bus["node"].global_position
	
	# 1. Disembarking: Passengers exit the bus onto the sidewalk
	if not bus["passengers"].is_empty():
		var exiting_ped = bus["passengers"].pop_back()
		if is_instance_valid(exiting_ped):
			exiting_ped.visible = true
			exiting_ped.global_position = bus_pos + Vector3(randf_range(3.0, 5.0), -1.6, randf_range(-2.0, 2.0))
			print("[TRANSIT BUS] Pedestrian disembarked at station!")
			
	# 2. Boarding: Nearby pedestrians walk up and enter the bus
	if is_instance_valid(ped_sys) and "active_pedestrians" in ped_sys:
		for ped in ped_sys.active_pedestrians:
			if is_instance_valid(ped) and ped.visible:
				var dist: float = ped.global_position.distance_to(bus_pos)
				if dist <= 12.0 and bus["passengers"].size() < 6:
					# Pedestrian boards the bus!
					ped.visible = false
					bus["passengers"].append(ped)
					print("[TRANSIT BUS] Pedestrian boarded the bus! Passengers inside: %d" % bus["passengers"].size())
					break
