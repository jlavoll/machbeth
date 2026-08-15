extends CanvasLayer

# ==============================================================================
# MISSION & COMBAT ENCOUNTER EDITOR OVERLAY (MissionEditorUI.gd)
# ==============================================================================
# Pressing F2 toggles this overlay on/off and pauses/unpauses the game engine.
# Isolated overlay for creating, editing, and balancing multi-round combat missions.
# Saves & loads from res://data/missions.json.

var is_editor_open: bool = false

# Data cache
var missions_catalog: Dictionary = {}
var enemies_catalog: Dictionary = {}
var weapons_catalog: Dictionary = {}
var upgrades_catalog: Dictionary = {}

var active_selected_mission_id: String = ""
var active_selected_round_index: int = 0

# UI Node References
var root_overlay_panel: PanelContainer = null
var mission_item_list: ItemList = null
var form_fields_container: VBoxContainer = null
var round_tabs_bar: TabBar = null
var round_detail_container: VBoxContainer = null
var status_banner_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 121 # Above DatabaseEditorUI (120)
	_build_ui_hierarchy()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_toggle_mission_overlay()

func _toggle_mission_overlay() -> void:
	is_editor_open = not is_editor_open
	visible = is_editor_open
	root_overlay_panel.visible = is_editor_open
	get_tree().paused = is_editor_open
	
	if is_editor_open:
		_load_all_json_catalogs()
		_refresh_mission_list()
		_update_status_banner("MISSION & FIGHT EDITOR ACTIVE [F2 TO CLOSE]")
	else:
		_update_status_banner("GAME RESUMED")

# ==============================================================================
# JSON DATA ACCESS
# ==============================================================================

func _load_all_json_catalogs() -> void:
	missions_catalog = _read_json_file("res://data/missions.json").get("missions", {})
	enemies_catalog = _read_json_file("res://data/enemies.json").get("enemies", {})
	weapons_catalog = _read_json_file("res://data/weapons.json").get("weapons", {})
	upgrades_catalog = _read_json_file("res://data/upgrades.json").get("upgrades", {})

func _read_json_file(res_path: String) -> Dictionary:
	if not FileAccess.file_exists(res_path):
		return {}
	var file = FileAccess.open(res_path, FileAccess.READ)
	if not file:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data
	return {}

func _save_missions_to_json() -> void:
	var file = FileAccess.open("res://data/missions.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"missions": missions_catalog}, "  "))
		file.close()
		_update_status_banner("💾 MISSION CATALOG SAVED TO res://data/missions.json!")

# ==============================================================================
# UI GENERATION
# ==============================================================================

func _build_ui_hierarchy() -> void:
	root_overlay_panel = PanelContainer.new()
	root_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_overlay_panel.offset_left = 0
	root_overlay_panel.offset_top = 0
	root_overlay_panel.offset_right = 0
	root_overlay_panel.offset_bottom = 0
	add_child(root_overlay_panel)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.02, 0.05, 0.08, 0.96)
	style_box.border_color = Color(0.9, 0.1, 0.5, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	root_overlay_panel.add_theme_stylebox_override("panel", style_box)
	
	var custom_theme = Theme.new()
	custom_theme.default_font_size = 12
	root_overlay_panel.theme = custom_theme
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_overlay_panel.add_child(main_vbox)
	
	# Header
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "⚔️ CYBERPUNK MISSION & FIGHT ENCOUNTER EDITOR [F2]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.5))
	title_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(VSeparator.new())
	
	status_banner_label = Label.new()
	status_banner_label.text = "READY"
	status_banner_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header_hbox.add_child(status_banner_label)
	
	var close_btn = Button.new()
	close_btn.text = "✖ CLOSE (F2)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_toggle_mission_overlay)
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
	list_title.text = "📜 MISSIONS & ACTS"
	list_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	left_panel.add_child(list_title)
	
	mission_item_list = ItemList.new()
	mission_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_item_list.item_selected.connect(_on_mission_selected)
	left_panel.add_child(mission_item_list)
	
	var btn_hbox = HBoxContainer.new()
	left_panel.add_child(btn_hbox)
	
	var add_btn = Button.new()
	add_btn.text = "➕ NEW MISSION"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_on_add_new_mission_pressed)
	btn_hbox.add_child(add_btn)
	
	var delete_btn = Button.new()
	delete_btn.text = "🗑️ DELETE"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(_on_delete_mission_pressed)
	btn_hbox.add_child(delete_btn)
	
	# Right: Form & Round Builder Panel
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_child(right_scroll)
	
	form_fields_container = VBoxContainer.new()
	form_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_fields_container.add_theme_constant_override("separation", 10)
	right_scroll.add_child(form_fields_container)

# ==============================================================================
# DATA REFRESH & UI BINDING
# ==============================================================================

func _update_status_banner(msg: String) -> void:
	if status_banner_label:
		status_banner_label.text = msg

func _refresh_mission_list() -> void:
	mission_item_list.clear()
	for mission_id in missions_catalog.keys():
		var mission = missions_catalog[mission_id]
		var act_num = mission.get("act", 1)
		var display_text = "Act " + str(act_num) + ": " + mission.get("name", mission_id)
		mission_item_list.add_item(display_text)
		mission_item_list.set_item_metadata(mission_item_list.get_item_count() - 1, mission_id)
	
	if missions_catalog.size() > 0:
		mission_item_list.select(0)
		_on_mission_selected(0)

func _on_mission_selected(index: int) -> void:
	active_selected_mission_id = mission_item_list.get_item_metadata(index)
	active_selected_round_index = 0
	_populate_mission_form()

func _populate_mission_form() -> void:
	# Clear previous form children
	for child in form_fields_container.get_children():
		child.queue_free()
		
	if not missions_catalog.has(active_selected_mission_id):
		return
		
	var mission = missions_catalog[active_selected_mission_id]
	
	# --- SECTION 1: MISSION & ACT PROPERTIES ---
	var sec1_label = Label.new()
	sec1_label.text = "🎯 MISSION PARAMETERS & ACT THRESHOLD"
	sec1_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	form_fields_container.add_child(sec1_label)
	
	# Mission Name
	var name_hbox = HBoxContainer.new()
	form_fields_container.add_child(name_hbox)
	var lbl_name = Label.new(); lbl_name.text = "Mission Name:"; lbl_name.custom_minimum_size.x = 140
	name_hbox.add_child(lbl_name)
	var edit_name = LineEdit.new(); edit_name.text = mission.get("name", ""); edit_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_name.text_changed.connect(func(new_text): mission["name"] = new_text; _update_list_item_text())
	name_hbox.add_child(edit_name)
	
	# Act Selector & Difficulty Threshold
	var act_hbox = HBoxContainer.new()
	form_fields_container.add_child(act_hbox)
	
	var lbl_act = Label.new(); lbl_act.text = "Act / Chapter:"; lbl_act.custom_minimum_size.x = 140
	act_hbox.add_child(lbl_act)
	var act_opt = OptionButton.new()
	act_opt.add_item("Act I: Macbeth's Ambition (Tier 1)", 1)
	act_opt.add_item("Act II: Crown of Glamis (Tier 2)", 2)
	act_opt.add_item("Act III: Banquo's Phantom (Tier 3)", 3)
	act_opt.add_item("Act IV: Birnam Wood Advances (Tier 4)", 4)
	act_opt.add_item("Act V: Dunsinane Downfall (Tier 5)", 5)
	act_opt.select(clamp(mission.get("act", 1) - 1, 0, 4))
	act_opt.item_selected.connect(func(idx): 
		var act_val = idx + 1
		mission["act"] = act_val
		mission["difficulty_threshold"] = act_val
		_update_list_item_text()
	)
	act_hbox.add_child(act_opt)
	
	# Description
	var desc_hbox = HBoxContainer.new()
	form_fields_container.add_child(desc_hbox)
	var lbl_desc = Label.new(); lbl_desc.text = "Briefing Log:"; lbl_desc.custom_minimum_size.x = 140
	desc_hbox.add_child(lbl_desc)
	var edit_desc = LineEdit.new(); edit_desc.text = mission.get("description", ""); edit_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_desc.text_changed.connect(func(new_text): mission["description"] = new_text)
	desc_hbox.add_child(edit_desc)
	
	# --- SECTION 2: REWARDS ---
	form_fields_container.add_child(HSeparator.new())
	var sec2_label = Label.new()
	sec2_label.text = "💎 REWARDS & DEPLOYMENT SALVAGE"
	sec2_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	form_fields_container.add_child(sec2_label)
	
	var rewards_dict = mission.get("rewards", {})
	var r_hbox = HBoxContainer.new()
	form_fields_container.add_child(r_hbox)
	
	r_hbox.add_child(Label.new())
	var lbl_cred = Label.new(); lbl_cred.text = "Credits:"
	r_hbox.add_child(lbl_cred)
	var spin_cred = SpinBox.new(); spin_cred.max_value = 100000; spin_cred.value = rewards_dict.get("credits", 500)
	spin_cred.value_changed.connect(func(val): rewards_dict["credits"] = int(val))
	r_hbox.add_child(spin_cred)
	
	var lbl_scrap = Label.new(); lbl_scrap.text = " Scrap:"
	r_hbox.add_child(lbl_scrap)
	var spin_scrap = SpinBox.new(); spin_scrap.max_value = 10000; spin_scrap.value = rewards_dict.get("scrap", 25)
	spin_scrap.value_changed.connect(func(val): rewards_dict["scrap"] = int(val))
	r_hbox.add_child(spin_scrap)
	
	var lbl_rep = Label.new(); lbl_rep.text = " Faction Rep:"
	r_hbox.add_child(lbl_rep)
	var edit_rep = LineEdit.new(); edit_rep.text = rewards_dict.get("reputation", ""); edit_rep.custom_minimum_size.x = 180
	edit_rep.text_changed.connect(func(txt): rewards_dict["reputation"] = txt)
	r_hbox.add_child(edit_rep)
	mission["rewards"] = rewards_dict
	
	# --- SECTION 3: ROUNDS & ENEMY COMBAT EQUIPMENT ---
	form_fields_container.add_child(HSeparator.new())
	var sec3_label = Label.new()
	sec3_label.text = "⚔️ ROUND BUILDER & HOSTILE EQUIPMENT SETUP"
	sec3_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.5))
	form_fields_container.add_child(sec3_label)
	
	var rounds_list = mission.get("rounds", [])
	
	# Round Control HBox (Add / Remove Round buttons)
	var round_ctrl_hbox = HBoxContainer.new()
	form_fields_container.add_child(round_ctrl_hbox)
	
	round_tabs_bar = TabBar.new()
	round_tabs_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(rounds_list.size()):
		round_tabs_bar.add_tab("Round " + str(i + 1))
	if rounds_list.size() > 0:
		round_tabs_bar.current_tab = clamp(active_selected_round_index, 0, rounds_list.size() - 1)
	round_tabs_bar.tab_changed.connect(_on_round_tab_changed)
	round_ctrl_hbox.add_child(round_tabs_bar)
	
	var add_round_btn = Button.new(); add_round_btn.text = "➕ Add Round"
	add_round_btn.pressed.connect(_on_add_round_pressed)
	round_ctrl_hbox.add_child(add_round_btn)
	
	var del_round_btn = Button.new(); del_round_btn.text = "🗑️ Remove Round"
	del_round_btn.pressed.connect(_on_remove_round_pressed)
	round_ctrl_hbox.add_child(del_round_btn)
	
	# Round Detail Container
	round_detail_container = VBoxContainer.new()
	round_detail_container.add_theme_constant_override("separation", 8)
	form_fields_container.add_child(round_detail_container)
	
	_render_active_round_details()
	
	# --- SECTION 4: SAVE ACTION BUTTON ---
	form_fields_container.add_child(HSeparator.new())
	var save_btn = Button.new()
	save_btn.text = "💾 SAVE ALL MISSIONS TO JSON (res://data/missions.json)"
	save_btn.custom_minimum_size.y = 38
	save_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	save_btn.pressed.connect(_save_missions_to_json)
	form_fields_container.add_child(save_btn)

func _update_list_item_text() -> void:
	if not missions_catalog.has(active_selected_mission_id):
		return
	var mission = missions_catalog[active_selected_mission_id]
	for i in range(mission_item_list.get_item_count()):
		if mission_item_list.get_item_metadata(i) == active_selected_mission_id:
			mission_item_list.set_item_text(i, "Act " + str(mission.get("act", 1)) + ": " + mission.get("name", ""))
			break

func _on_round_tab_changed(tab_idx: int) -> void:
	active_selected_round_index = tab_idx
	_render_active_round_details()

func _render_active_round_details() -> void:
	for child in round_detail_container.get_children():
		child.queue_free()
		
	if not missions_catalog.has(active_selected_mission_id):
		return
	var rounds_list = missions_catalog[active_selected_mission_id].get("rounds", [])
	if rounds_list.size() == 0 or active_selected_round_index >= rounds_list.size():
		var empty_lbl = Label.new(); empty_lbl.text = "No rounds added yet. Click 'Add Round' to create Wave 1."
		round_detail_container.add_child(empty_lbl)
		return
		
	var round_data = rounds_list[active_selected_round_index]
	
	# Round Name Edit
	var rname_hbox = HBoxContainer.new()
	round_detail_container.add_child(rname_hbox)
	var lbl_rn = Label.new(); lbl_rn.text = "Wave Title:"; lbl_rn.custom_minimum_size.x = 100
	rname_hbox.add_child(lbl_rn)
	var edit_rn = LineEdit.new(); edit_rn.text = round_data.get("round_name", ""); edit_rn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_rn.text_changed.connect(func(txt): round_data["round_name"] = txt)
	rname_hbox.add_child(edit_rn)
	
	# Enemies in Round
	var enemies_array = round_data.get("enemies", [])
	var e_header_hbox = HBoxContainer.new()
	round_detail_container.add_child(e_header_hbox)
	var e_lbl = Label.new(); e_lbl.text = "Hostile Units in Wave:"; e_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	e_header_hbox.add_child(e_lbl)
	
	var add_enemy_btn = Button.new(); add_enemy_btn.text = "➕ Add Hostile Enemy Unit"
	add_enemy_btn.pressed.connect(func():
		var default_enemy_id = enemies_catalog.keys()[0] if enemies_catalog.size() > 0 else "cawdor_interceptor_alpha"
		enemies_array.append({
			"enemy_id": default_enemy_id,
			"equipped_weapons": ["twin_20mm_cannon"],
			"equipped_upgrades": ["graphene_armor_l1"]
		})
		_render_active_round_details()
	)
	e_header_hbox.add_child(add_enemy_btn)
	
	# List each enemy unit box
	for e_idx in range(enemies_array.size()):
		var enemy_entry = enemies_array[e_idx]
		var e_box = PanelContainer.new()
		var box_style = StyleBoxFlat.new()
		box_style.bg_color = Color(0.05, 0.08, 0.12, 0.8)
		box_style.set_border_width_all(1)
		box_style.border_color = Color(0.3, 0.6, 0.8, 0.5)
		e_box.add_theme_stylebox_override("panel", box_style)
		round_detail_container.add_child(e_box)
		
		var e_vbox = VBoxContainer.new()
		e_box.add_child(e_vbox)
		
		var top_e_hbox = HBoxContainer.new()
		e_vbox.add_child(top_e_hbox)
		
		var unit_lbl = Label.new(); unit_lbl.text = "Unit #" + str(e_idx + 1) + ":"
		top_e_hbox.add_child(unit_lbl)
		
		# Enemy Type OptionButton
		var enemy_opt = OptionButton.new()
		var current_enemy_id = enemy_entry.get("enemy_id", "")
		var sel_idx = 0
		var enemy_id_list = enemies_catalog.keys()
		for id_i in range(enemy_id_list.size()):
			var e_id = enemy_id_list[id_i]
			var e_prof = enemies_catalog[e_id]
			enemy_opt.add_item(e_prof.get("name", e_id) + " (" + e_prof.get("threat", "STANDARD") + ")")
			if e_id == current_enemy_id:
				sel_idx = id_i
		enemy_opt.select(sel_idx)
		enemy_opt.item_selected.connect(func(idx):
			var chosen_id = enemy_id_list[idx]
			enemy_entry["enemy_id"] = chosen_id
		)
		top_e_hbox.add_child(enemy_opt)
		
		var del_e_btn = Button.new(); del_e_btn.text = "❌ Remove Unit"
		del_e_btn.pressed.connect(func():
			enemies_array.remove_at(e_idx)
			_render_active_round_details()
		)
		top_e_hbox.add_child(del_e_btn)
		
		# Equipped Weapons Selection
		var w_hbox = HBoxContainer.new()
		e_vbox.add_child(w_hbox)
		var w_lbl = Label.new(); w_lbl.text = "  Equipped Weapon:"
		w_hbox.add_child(w_lbl)
		var w_opt = OptionButton.new()
		var weapon_keys = weapons_catalog.keys()
		var current_w = enemy_entry.get("equipped_weapons", ["twin_20mm_cannon"])
		var curr_w_id = current_w[0] if current_w.size() > 0 else ""
		var sel_w_idx = 0
		for wi in range(weapon_keys.size()):
			var w_id = weapon_keys[wi]
			w_opt.add_item(weapons_catalog[w_id].get("name", w_id))
			if w_id == curr_w_id:
				sel_w_idx = wi
		w_opt.select(sel_w_idx)
		w_opt.item_selected.connect(func(w_idx_sel):
			enemy_entry["equipped_weapons"] = [weapon_keys[w_idx_sel]]
		)
		w_hbox.add_child(w_opt)
		
		# Equipped Armor/Upgrade Selection
		var u_hbox = HBoxContainer.new()
		e_vbox.add_child(u_hbox)
		var u_lbl = Label.new(); u_lbl.text = "  Equipped Armor/Mod:"
		u_hbox.add_child(u_lbl)
		var u_opt = OptionButton.new()
		var upgrade_keys = upgrades_catalog.keys()
		var current_u = enemy_entry.get("equipped_upgrades", ["graphene_armor_l1"])
		var curr_u_id = current_u[0] if current_u.size() > 0 else ""
		var sel_u_idx = 0
		for ui in range(upgrade_keys.size()):
			var u_id = upgrade_keys[ui]
			u_opt.add_item(upgrades_catalog[u_id].get("name", u_id))
			if u_id == curr_u_id:
				sel_u_idx = ui
		u_opt.select(sel_u_idx)
		u_opt.item_selected.connect(func(u_idx_sel):
			enemy_entry["equipped_upgrades"] = [upgrade_keys[u_idx_sel]]
		)
		u_hbox.add_child(u_opt)

# ==============================================================================
# MISSION CREATION & DELETION HANDLERS
# ==============================================================================

func _on_add_new_mission_pressed() -> void:
	var new_id = "act1_custom_mission_" + str(Time.get_ticks_msec())
	missions_catalog[new_id] = {
		"id": new_id,
		"name": "Custom Operation Strike",
		"act": 1,
		"act_title": "Act I: Macbeth's Ambition",
		"difficulty_threshold": 1,
		"description": "Custom mission created in Mission Editor overlay.",
		"rounds": [
			{
				"round_number": 1,
				"round_name": "Wave 1 - Initial Patrol",
				"enemies": [
					{
						"enemy_id": "cawdor_interceptor_alpha",
						"equipped_weapons": ["twin_20mm_cannon"],
						"equipped_upgrades": ["graphene_armor_l1"]
					}
				]
			}
		],
		"rewards": {
			"credits": 750,
			"scrap": 50,
			"reputation": "Street Operative (+15)"
		}
	}
	_refresh_mission_list()
	active_selected_mission_id = new_id
	_populate_mission_form()
	_update_status_banner("✨ CREATED NEW MISSION " + new_id)

func _on_delete_mission_pressed() -> void:
	if missions_catalog.has(active_selected_mission_id):
		missions_catalog.erase(active_selected_mission_id)
		_refresh_mission_list()
		_update_status_banner("🗑️ DELETED MISSION")

func _on_add_round_pressed() -> void:
	if not missions_catalog.has(active_selected_mission_id):
		return
	var rounds_list = missions_catalog[active_selected_mission_id].get("rounds", [])
	var new_round_num = rounds_list.size() + 1
	rounds_list.append({
		"round_number": new_round_num,
		"round_name": "Wave " + str(new_round_num) + " Reinforcements",
		"enemies": [
			{
				"enemy_id": "cawdor_interceptor_alpha",
				"equipped_weapons": ["twin_20mm_cannon"],
				"equipped_upgrades": ["graphene_armor_l1"]
			}
		]
	})
	active_selected_round_index = rounds_list.size() - 1
	_populate_mission_form()

func _on_remove_round_pressed() -> void:
	if not missions_catalog.has(active_selected_mission_id):
		return
	var rounds_list = missions_catalog[active_selected_mission_id].get("rounds", [])
	if rounds_list.size() > 0:
		rounds_list.remove_at(active_selected_round_index)
		active_selected_round_index = max(0, active_selected_round_index - 1)
		_populate_mission_form()
