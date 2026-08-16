extends CanvasLayer

# ==============================================================================
# BANQUO STREET MISSIONS EDITOR OVERLAY (StreetMissionEditorUI.gd)
# ==============================================================================
# Pressing F4 toggles this overlay on/off and pauses/unpauses the game engine.
# Modular overlay for creating, editing, and expanding Banquo's street quests.
# Supports expandable mission types (Tail Target, Courier Run, Recon, Pursuit, Pit Brawl).
# Saves & loads from res://data/street_missions.json.

var is_editor_open: bool = false

# Data cache
var street_missions_data: Dictionary = {}
var mission_types_list: Array = []
var street_missions_catalog: Dictionary = {}

var active_selected_mission_id: String = ""

# UI Node References
var root_overlay_panel: PanelContainer = null
var mission_item_list: ItemList = null
var form_fields_container: VBoxContainer = null
var status_banner_label: Label = null
var filter_act_option: OptionButton = null
var active_act_filter: int = 0 # 0: All Acts, 1-4: Act 1-4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 123 # Above F3 Dialogue Editor (122)
	_build_ui_hierarchy()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			_toggle_street_mission_overlay()

func _toggle_street_mission_overlay() -> void:
	is_editor_open = not is_editor_open
	visible = is_editor_open
	root_overlay_panel.visible = is_editor_open
	get_tree().paused = is_editor_open
	
	if is_editor_open:
		_load_street_missions_json()
		_refresh_mission_list()
		_update_status_banner("ACTIVE")
	else:
		_update_status_banner("GAME RESUMED")

func _load_street_missions_json() -> void:
	var json_data: Dictionary = _read_json_file("res://data/street_missions.json")
	street_missions_data = json_data
	mission_types_list = json_data.get("mission_types", [])
	street_missions_catalog = json_data.get("street_missions", {})

func _read_json_file(file_path: String) -> Dictionary:
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			return json.get_data()
	return {}

func _save_street_missions_to_json() -> void:
	street_missions_data["street_missions"] = street_missions_catalog
	street_missions_data["mission_types"] = mission_types_list
	
	var file = FileAccess.open("res://data/street_missions.json", FileAccess.WRITE)
	if is_instance_valid(file):
		file.store_string(JSON.stringify(street_missions_data, "  "))
		_update_status_banner("💾 SAVED TO res://data/street_missions.json!")

func _update_status_banner(msg: String) -> void:
	if is_instance_valid(status_banner_label):
		status_banner_label.text = msg

# ==============================================================================
# UI CONSTRUCTION
# ==============================================================================

func _build_ui_hierarchy() -> void:
	root_overlay_panel = PanelContainer.new()
	root_overlay_panel.name = "StreetMissionEditorPanel"
	root_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_overlay_panel.offset_left = 0
	root_overlay_panel.offset_top = 0
	root_overlay_panel.offset_right = 0
	root_overlay_panel.offset_bottom = 0
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.03, 0.04, 0.07, 0.96)
	style_box.border_color = Color(1.0, 0.85, 0.0, 0.9) # Emerald/Gold Cyber Glow
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	root_overlay_panel.add_theme_stylebox_override("panel", style_box)
	
	var custom_theme = Theme.new()
	custom_theme.default_font_size = 11
	root_overlay_panel.theme = custom_theme
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_overlay_panel.add_child(main_vbox)
	
	# Header Bar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "BANQUO STREET MISSIONS EDITOR [F4]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(VSeparator.new())
	
	var filter_lbl = Label.new(); filter_lbl.text = "Act Filter:"
	header_hbox.add_child(filter_lbl)
	filter_act_option = OptionButton.new()
	filter_act_option.add_item("All Acts")
	filter_act_option.add_item("Act I")
	filter_act_option.add_item("Act II")
	filter_act_option.add_item("Act III")
	filter_act_option.add_item("Act IV")
	filter_act_option.item_selected.connect(_on_act_filter_selected)
	header_hbox.add_child(filter_act_option)

	header_hbox.add_child(VSeparator.new())
	
	var save_btn = Button.new(); save_btn.text = " 💾 SAVE ALL "
	save_btn.pressed.connect(_save_street_missions_to_json)
	header_hbox.add_child(save_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	status_banner_label = Label.new()
	status_banner_label.text = "READY"
	status_banner_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header_hbox.add_child(status_banner_label)
	
	var close_btn = Button.new()
	close_btn.text = " CLOSE "
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_toggle_street_mission_overlay)
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# Main Split Container
	var split_container = HSplitContainer.new()
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.split_offset = 280
	main_vbox.add_child(split_container)
	
	# Left: Mission List Panel
	var left_panel = VBoxContainer.new()
	split_container.add_child(left_panel)
	
	var list_title = Label.new()
	list_title.text = "BANQUO STREET QUESTS"
	list_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	left_panel.add_child(list_title)
	
	mission_item_list = ItemList.new()
	mission_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_item_list.item_selected.connect(_on_mission_selected)
	left_panel.add_child(mission_item_list)
	
	var btn_hbox = HBoxContainer.new()
	left_panel.add_child(btn_hbox)
	
	var add_btn = Button.new()
	add_btn.text = "➕ NEW"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_on_add_new_mission_pressed)
	btn_hbox.add_child(add_btn)

	var dup_btn = Button.new()
	dup_btn.text = "📋 CLONE"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(_on_duplicate_mission_pressed)
	btn_hbox.add_child(dup_btn)
	
	var delete_btn = Button.new()
	delete_btn.text = "🗑️ DELETE"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(_on_delete_mission_pressed)
	btn_hbox.add_child(delete_btn)
	
	# Right: Detailed Mission Properties Form
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_child(right_scroll)
	
	form_fields_container = VBoxContainer.new()
	form_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_fields_container.add_theme_constant_override("separation", 10)
	right_scroll.add_child(form_fields_container)
	
	add_child(root_overlay_panel)

func _on_act_filter_selected(idx: int) -> void:
	active_act_filter = idx
	_refresh_mission_list()

func _refresh_mission_list() -> void:
	mission_item_list.clear()
	for m_id in street_missions_catalog.keys():
		var mission = street_missions_catalog[m_id]
		var act_num: int = mission.get("act", 1)
		
		if active_act_filter > 0 and act_num != active_act_filter:
			continue
			
		var type_id: String = mission.get("type", "TAIL_TARGET")
		var display_text = "Act " + str(act_num) + " [" + type_id + "]: " + mission.get("name", m_id)
		mission_item_list.add_item(display_text)
		mission_item_list.set_item_metadata(mission_item_list.get_item_count() - 1, m_id)
		
	if mission_item_list.get_item_count() > 0:
		mission_item_list.select(0)
		_on_mission_selected(0)
	else:
		_clear_form_fields()

func _on_mission_selected(index: int) -> void:
	active_selected_mission_id = mission_item_list.get_item_metadata(index)
	_populate_mission_form()

func _clear_form_fields() -> void:
	for child in form_fields_container.get_children():
		child.queue_free()

func _populate_mission_form() -> void:
	_clear_form_fields()
	
	if not street_missions_catalog.has(active_selected_mission_id):
		return
		
	var mission = street_missions_catalog[active_selected_mission_id]
	
	# --- SECTION 1: GENERAL MISSION METADATA ---
	var sec1_label = Label.new()
	sec1_label.text = "🎯 MISSION PARAMETERS & ACT ASSIGNMENT"
	sec1_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	form_fields_container.add_child(sec1_label)
	
	# ID (Read-only)
	var id_row = HBoxContainer.new()
	var lbl_id = Label.new(); lbl_id.text = "Quest ID:"; lbl_id.custom_minimum_size.x = 140
	var val_id = Label.new(); val_id.text = active_selected_mission_id; val_id.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	id_row.add_child(lbl_id); id_row.add_child(val_id)
	form_fields_container.add_child(id_row)
	
	# Quest Name
	var name_row = HBoxContainer.new()
	var lbl_name = Label.new(); lbl_name.text = "Quest Name:"; lbl_name.custom_minimum_size.x = 140
	var edit_name = LineEdit.new(); edit_name.text = mission.get("name", ""); edit_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_name.text_changed.connect(func(new_text): mission["name"] = new_text; _update_list_item_text())
	name_row.add_child(lbl_name); name_row.add_child(edit_name)
	form_fields_container.add_child(name_row)
	
	# Mission Type Selector (Expandable Registry!)
	var type_row = HBoxContainer.new()
	var lbl_type = Label.new(); lbl_type.text = "Quest Type:"; lbl_type.custom_minimum_size.x = 140
	var type_opt = OptionButton.new()
	
	var current_type: String = mission.get("type", "TAIL_TARGET")
	var selected_type_idx: int = 0
	for t_idx in range(mission_types_list.size()):
		var t_info = mission_types_list[t_idx]
		type_opt.add_item(t_info.get("display_name", t_info.get("type_id", "")))
		if t_info.get("type_id", "") == current_type:
			selected_type_idx = t_idx
			
	type_opt.select(selected_type_idx)
	type_opt.item_selected.connect(func(idx):
		var picked_type: String = mission_types_list[idx].get("type_id", "TAIL_TARGET")
		mission["type"] = picked_type
		_update_list_item_text()
		_populate_mission_form() # Refresh dynamic parameters for this type!
	)
	type_row.add_child(lbl_type); type_row.add_child(type_opt)
	form_fields_container.add_child(type_row)
	
	# Act Assignment
	var act_row = HBoxContainer.new()
	var lbl_act = Label.new(); lbl_act.text = "Campaign Act:"; lbl_act.custom_minimum_size.x = 140
	var act_opt = OptionButton.new()
	act_opt.add_item("Act I: Duncan's Fall")
	act_opt.add_item("Act II: Banquo's Intercept")
	act_opt.add_item("Act III: Birnam Purge")
	act_opt.add_item("Act IV: Dunsinane Siege")
	act_opt.select(clamp(mission.get("act", 1) - 1, 0, 3))
	act_opt.item_selected.connect(func(idx): mission["act"] = idx + 1; _update_list_item_text())
	act_row.add_child(lbl_act); act_row.add_child(act_opt)
	form_fields_container.add_child(act_row)
	
	# Client / Quest Giver
	var client_row = HBoxContainer.new()
	var lbl_client = Label.new(); lbl_client.text = "Client / Contact:"; lbl_client.custom_minimum_size.x = 140
	var edit_client = LineEdit.new(); edit_client.text = mission.get("client", "MR. DODGY"); edit_client.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_client.text_changed.connect(func(new_text): mission["client"] = new_text)
	client_row.add_child(lbl_client); client_row.add_child(edit_client)
	form_fields_container.add_child(client_row)
	
	# Reward Credits
	var reward_row = HBoxContainer.new()
	var lbl_reward = Label.new(); lbl_reward.text = "Reward Credits ($):"; lbl_reward.custom_minimum_size.x = 140
	var edit_reward = SpinBox.new(); edit_reward.min_value = 0; edit_reward.max_value = 100000; edit_reward.step = 50; edit_reward.value = mission.get("reward_credits", 500)
	edit_reward.value_changed.connect(func(val): mission["reward_credits"] = int(val))
	reward_row.add_child(lbl_reward); reward_row.add_child(edit_reward)
	form_fields_container.add_child(reward_row)
	
	# Objective Text
	var obj_row = HBoxContainer.new()
	var lbl_obj = Label.new(); lbl_obj.text = "Objective Text:"; lbl_obj.custom_minimum_size.x = 140
	var edit_obj = LineEdit.new(); edit_obj.text = mission.get("objective_text", ""); edit_obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_obj.text_changed.connect(func(new_text): mission["objective_text"] = new_text)
	obj_row.add_child(lbl_obj); obj_row.add_child(edit_obj)
	form_fields_container.add_child(obj_row)

	form_fields_container.add_child(HSeparator.new())
	
	# --- SECTION 2: TYPE-SPECIFIC DYNAMIC PARAMETERS ---
	var sec2_label = Label.new()
	sec2_label.text = "⚙️ TYPE-SPECIFIC OBJECTIVE PARAMETERS (" + current_type + ")"
	sec2_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	form_fields_container.add_child(sec2_label)
	
	if current_type == "TAIL_TARGET":
		var target_row = HBoxContainer.new()
		var lbl_t = Label.new(); lbl_t.text = "Target Vehicle:"; lbl_t.custom_minimum_size.x = 140
		var edit_t = LineEdit.new(); edit_t.text = mission.get("target_vehicle", "Pink Cadillac"); edit_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_t.text_changed.connect(func(new_text): mission["target_vehicle"] = new_text)
		target_row.add_child(lbl_t); target_row.add_child(edit_t)
		form_fields_container.add_child(target_row)
		
		var dist_row = HBoxContainer.new()
		var lbl_min = Label.new(); lbl_min.text = "Min Dist (m):"; lbl_min.custom_minimum_size.x = 140
		var spin_min = SpinBox.new(); spin_min.min_value = 5; spin_min.max_value = 50; spin_min.value = mission.get("min_distance", 15.0)
		spin_min.value_changed.connect(func(val): mission["min_distance"] = float(val))
		var lbl_max = Label.new(); lbl_max.text = "  Max Dist (m):"
		var spin_max = SpinBox.new(); spin_max.min_value = 20; spin_max.max_value = 100; spin_max.value = mission.get("max_distance", 40.0)
		spin_max.value_changed.connect(func(val): mission["max_distance"] = float(val))
		dist_row.add_child(lbl_min); dist_row.add_child(spin_min); dist_row.add_child(lbl_max); dist_row.add_child(spin_max)
		form_fields_container.add_child(dist_row)

	elif current_type == "COURIER_RUN":
		var dest_row = HBoxContainer.new()
		var lbl_dest = Label.new(); lbl_dest.text = "Destination:"; lbl_dest.custom_minimum_size.x = 140
		var edit_dest = LineEdit.new(); edit_dest.text = mission.get("target_destination", "The Pit Garage"); edit_dest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_dest.text_changed.connect(func(new_text): mission["target_destination"] = new_text)
		dest_row.add_child(lbl_dest); dest_row.add_child(edit_dest)
		form_fields_container.add_child(dest_row)

		var time_row = HBoxContainer.new()
		var lbl_time = Label.new(); lbl_time.text = "Time Limit (s):"; lbl_time.custom_minimum_size.x = 140
		var spin_time = SpinBox.new(); spin_time.min_value = 10; spin_time.max_value = 600; spin_time.step = 5; spin_time.value = mission.get("time_limit", 90.0)
		spin_time.value_changed.connect(func(val): mission["time_limit"] = float(val))
		time_row.add_child(lbl_time); time_row.add_child(spin_time)
		form_fields_container.add_child(time_row)

	elif current_type == "EAVESDROP_RECON":
		var wire_row = HBoxContainer.new()
		var lbl_wire = Label.new(); lbl_wire.text = "Eavesdrop Time (s):"; lbl_wire.custom_minimum_size.x = 140
		var spin_wire = SpinBox.new(); spin_wire.min_value = 5; spin_wire.max_value = 120; spin_wire.value = mission.get("eavesdrop_duration", 15.0)
		spin_wire.value_changed.connect(func(val): mission["eavesdrop_duration"] = float(val))
		wire_row.add_child(lbl_wire); wire_row.add_child(spin_wire)
		form_fields_container.add_child(wire_row)

	elif current_type == "ALLEY_PURSUIT":
		var chase_row = HBoxContainer.new()
		var lbl_chase = Label.new(); lbl_chase.text = "Target Informant:"; lbl_chase.custom_minimum_size.x = 140
		var edit_chase = LineEdit.new(); edit_chase.text = mission.get("target_informant", "Corporate Runner"); edit_chase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_chase.text_changed.connect(func(new_text): mission["target_informant"] = new_text)
		chase_row.add_child(lbl_chase); chase_row.add_child(edit_chase)
		form_fields_container.add_child(chase_row)

func _update_list_item_text() -> void:
	if not street_missions_catalog.has(active_selected_mission_id): return
	var mission = street_missions_catalog[active_selected_mission_id]
	var act_num: int = mission.get("act", 1)
	var type_id: String = mission.get("type", "TAIL_TARGET")
	var display_text = "Act " + str(act_num) + " [" + type_id + "]: " + mission.get("name", active_selected_mission_id)
	
	for i in range(mission_item_list.get_item_count()):
		if mission_item_list.get_item_metadata(i) == active_selected_mission_id:
			mission_item_list.set_item_text(i, display_text)
			break

func _on_add_new_mission_pressed() -> void:
	var new_id = "street_%02d_quest" % (street_missions_catalog.size() + 1)
	street_missions_catalog[new_id] = {
		"id": new_id,
		"name": "New Banquo Street Quest",
		"type": "TAIL_TARGET",
		"act": 1,
		"client": "MR. DODGY",
		"reward_credits": 500,
		"objective_text": "Complete street quest objective."
	}
	_refresh_mission_list()
	_update_status_banner("✨ CREATED NEW STREET QUEST " + new_id)

func _on_duplicate_mission_pressed() -> void:
	if active_selected_mission_id.is_empty() or not street_missions_catalog.has(active_selected_mission_id):
		return
	var source_mission: Dictionary = street_missions_catalog[active_selected_mission_id]
	var cloned_mission: Dictionary = source_mission.duplicate(true)
	var new_id = active_selected_mission_id + "_copy_" + str(randi() % 1000)
	cloned_mission["id"] = new_id
	cloned_mission["name"] = cloned_mission.get("name", "Street Quest") + " (Copy)"
	street_missions_catalog[new_id] = cloned_mission
	active_selected_mission_id = new_id
	_refresh_mission_list()
	_update_status_banner("📋 CLONED STREET QUEST " + new_id)

func _on_delete_mission_pressed() -> void:
	if active_selected_mission_id != "" and street_missions_catalog.has(active_selected_mission_id):
		street_missions_catalog.erase(active_selected_mission_id)
		active_selected_mission_id = ""
		_refresh_mission_list()
		_update_status_banner("🗑️ DELETED STREET QUEST")
