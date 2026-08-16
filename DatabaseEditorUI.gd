extends CanvasLayer

# ==============================================================================
# STANDALONE CYBERPUNK DATABASE EDITOR OVERLAY (DatabaseEditorUI.gd)
# ==============================================================================
# Pressing F1 toggles this overlay on/off and pauses/unpauses the game engine.
# Completely isolated from garage, combat, or campaign logic.
# Allows viewing, modifying, creating, and saving entries in JSON files:
#   - res://data/weapons.json
#   - res://data/upgrades.json
#   - res://data/enemies.json

var is_editor_open: bool = false

# Internal data cache for editor
var weapons_catalog: Dictionary = {}
var upgrades_catalog: Dictionary = {}
var enemies_catalog: Dictionary = {}

enum CatalogCategory { WEAPONS, UPGRADES, ENEMIES }
var current_category: CatalogCategory = CatalogCategory.WEAPONS
var active_selected_id: String = ""

# UI Node References
var root_overlay_panel: PanelContainer = null
var category_tab_bar: TabBar = null
var catalog_item_list: ItemList = null
var form_fields_container: VBoxContainer = null
var status_banner_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Allows overlay to run while game tree is paused
	layer = 120 # High Z-index above HUD elements
	_build_ui_hierarchy()
	visible = false # Hide CanvasLayer completely so it never blocks mouse clicks when closed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_toggle_database_overlay()

func _toggle_database_overlay() -> void:
	is_editor_open = not is_editor_open
	visible = is_editor_open # Show/hide CanvasLayer
	root_overlay_panel.visible = is_editor_open
	get_tree().paused = is_editor_open # Pauses/unpauses game physics & timers cleanly
	
	if is_editor_open:
		_load_all_json_catalogs()
		_refresh_catalog_list()
		_update_status_banner("ACTIVE")
	else:
		_update_status_banner("GAME RESUMED")

# ==============================================================================
# JSON I/O
# ==============================================================================

func _load_all_json_catalogs() -> void:
	weapons_catalog = _read_json_file("res://data/weapons.json").get("weapons", {})
	upgrades_catalog = _read_json_file("res://data/upgrades.json").get("upgrades", {})
	enemies_catalog = _read_json_file("res://data/enemies.json").get("enemies", {})

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

func _save_catalogs_to_json_files() -> void:
	_write_json_file("res://data/weapons.json", {"weapons": weapons_catalog})
	_write_json_file("res://data/upgrades.json", {"upgrades": upgrades_catalog})
	_write_json_file("res://data/enemies.json", {"enemies": enemies_catalog})
	
	# Reload runtime database in Enemies.gd if loaded
	var EnemiesScript = load("res://Enemies.gd")
	if EnemiesScript:
		EnemiesScript._is_loaded = false
		EnemiesScript.load_all_json_databases()
		
	_update_status_banner("💾 SAVED TO JSON FILES SUCCESSFULLY!")

func _write_json_file(res_path: String, data: Dictionary) -> void:
	var file = FileAccess.open(res_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

# ==============================================================================
# UI GENERATION
# ==============================================================================

func _build_ui_hierarchy() -> void:
	var outer_margin = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer_margin)

	root_overlay_panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.0, 0.85, 1.0) # Cyber Cyan Border
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	root_overlay_panel.add_theme_stylebox_override("panel", p_style)
	
	# Global UI theme font sizing for compact display (11px)
	var custom_theme = Theme.new()
	custom_theme.default_font_size = 11
	root_overlay_panel.theme = custom_theme
	outer_margin.add_child(root_overlay_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_overlay_panel.add_child(main_vbox)

	# Header Bar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "DATABASE EDITOR [F1]"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var exit_btn = Button.new()
	exit_btn.text = " CLOSE "
	exit_btn.pressed.connect(_toggle_database_overlay)
	header_hbox.add_child(exit_btn)

	# Category Tab Bar
	category_tab_bar = TabBar.new()
	category_tab_bar.add_tab("⚔️ WEAPONS CATALOG")
	category_tab_bar.add_tab("🛡️ UPGRADES CATALOG")
	category_tab_bar.add_tab("🚙 ENEMIES CATALOG")
	category_tab_bar.tab_changed.connect(_on_category_tab_changed)
	main_vbox.add_child(category_tab_bar)

	# Split Body Content: Left Catalog List, Right Edit Form
	var body_hbox = HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)

	# Left Column: Item List & Controls
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(280, 0)
	left_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_vbox)

	catalog_item_list = ItemList.new()
	catalog_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_item_list.item_selected.connect(_on_item_selected_in_list)
	left_vbox.add_child(catalog_item_list)

	var btn_hbox = HBoxContainer.new()
	var new_entry_btn = Button.new()
	new_entry_btn.text = "➕ Create"
	new_entry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_entry_btn.pressed.connect(_on_create_new_entry_click)
	btn_hbox.add_child(new_entry_btn)

	var duplicate_btn = Button.new()
	duplicate_btn.text = "📋 Clone"
	duplicate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate_btn.pressed.connect(_on_duplicate_entry_click)
	btn_hbox.add_child(duplicate_btn)

	var sort_btn = Button.new()
	sort_btn.text = "🔤 Sort A-Z"
	sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_btn.pressed.connect(_on_sort_catalog_alphabetically)
	btn_hbox.add_child(sort_btn)
	left_vbox.add_child(btn_hbox)

	# Right Column: Attribute Edit Form Container
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r_style = StyleBoxFlat.new()
	r_style.bg_color = Color(0.01, 0.02, 0.05, 0.85)
	r_style.content_margin_left = 14
	r_style.content_margin_right = 14
	r_style.content_margin_top = 14
	r_style.content_margin_bottom = 14
	right_panel.add_theme_stylebox_override("panel", r_style)
	body_hbox.add_child(right_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)

	form_fields_container = VBoxContainer.new()
	form_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_fields_container.add_theme_constant_override("separation", 10)
	scroll.add_child(form_fields_container)

	# Footer Status Bar
	var footer_hbox = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)

	status_banner_label = Label.new()
	status_banner_label.text = "SYSTEM READY."
	status_banner_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	status_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(status_banner_label)

func _update_status_banner(msg: String) -> void:
	if is_instance_valid(status_banner_label):
		status_banner_label.text = msg

# ==============================================================================
# CATALOG & LIST MANAGEMENT
# ==============================================================================

func _on_category_tab_changed(tab_idx: int) -> void:
	current_category = tab_idx as CatalogCategory
	active_selected_id = ""
	_refresh_catalog_list()

func _get_current_active_catalog() -> Dictionary:
	match current_category:
		CatalogCategory.WEAPONS:
			return weapons_catalog
		CatalogCategory.UPGRADES:
			return upgrades_catalog
		CatalogCategory.ENEMIES:
			return enemies_catalog
	return {}

func _refresh_catalog_list() -> void:
	catalog_item_list.clear()
	_clear_form_fields()
	
	var active_catalog = _get_current_active_catalog()
	var selected_idx: int = 0
	var item_idx: int = 0
	
	for item_id in active_catalog.keys():
		var entry = active_catalog[item_id]
		var item_name = entry.get("name", item_id)
		var prefix = ""
		if current_category == CatalogCategory.WEAPONS:
			prefix = "⚔️ "
		elif current_category == CatalogCategory.UPGRADES:
			prefix = "🛡️ "
		elif current_category == CatalogCategory.ENEMIES:
			prefix = entry.get("icon", "🚙") + " "
			
		var list_idx = catalog_item_list.add_item(prefix + item_name)
		catalog_item_list.set_item_metadata(list_idx, item_id)
		if item_id == active_selected_id:
			selected_idx = list_idx
		item_idx += 1

	if catalog_item_list.item_count > 0:
		catalog_item_list.select(selected_idx)
		_on_item_selected_in_list(selected_idx)

func _on_item_selected_in_list(index: int) -> void:
	if index < 0 or index >= catalog_item_list.item_count:
		return
	active_selected_id = catalog_item_list.get_item_metadata(index)
	_build_form_for_selected_item()

func _clear_form_fields() -> void:
	for child in form_fields_container.get_children():
		child.queue_free()

# ==============================================================================
# DYNAMIC FORM EDITING
# ==============================================================================

func _build_form_for_selected_item() -> void:
	_clear_form_fields()
	var active_catalog = _get_current_active_catalog()
	if not active_catalog.has(active_selected_id):
		return
		
	var entry_data: Dictionary = active_catalog[active_selected_id]
	
	# Section Group Box
	var group_panel = PanelContainer.new()
	var g_style = StyleBoxFlat.new()
	g_style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	g_style.border_color = Color(0.0, 0.85, 1.0, 0.4) # Cyan Group Border
	g_style.set_border_width_all(1)
	g_style.set_corner_radius_all(4)
	g_style.set_content_margin_all(8)
	group_panel.add_theme_stylebox_override("panel", g_style)
	
	var group_vbox = VBoxContainer.new()
	group_vbox.add_theme_constant_override("separation", 8)

	var header_hbox = HBoxContainer.new()
	var header_title = Label.new()
	header_title.text = "✏️ EDITING ENTRY ID: " + active_selected_id
	header_title.add_theme_font_size_override("font_size", 12)
	header_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	header_hbox.add_child(header_title)

	var duplicate_top_btn = Button.new()
	duplicate_top_btn.text = "📋 Duplicate Entry"
	duplicate_top_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	duplicate_top_btn.pressed.connect(_on_duplicate_entry_click)
	header_hbox.add_child(duplicate_top_btn)
	group_vbox.add_child(header_hbox)
	
	for key in entry_data.keys():
		var val = entry_data[key]
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		group_vbox.add_child(row_hbox)
		
		var field_label = Label.new()
		field_label.text = key.capitalize() + ":"
		field_label.custom_minimum_size = Vector2(150, 0)
		row_hbox.add_child(field_label)
		
		if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
			var spin_box = SpinBox.new()
			spin_box.min_value = 0
			spin_box.max_value = 9999
			spin_box.step = 1 if typeof(val) == TYPE_INT else 0.1
			spin_box.value = float(val)
			spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin_box.value_changed.connect(func(new_val): _update_entry_attribute(key, new_val))
			row_hbox.add_child(spin_box)
		elif typeof(val) == TYPE_ARRAY:
			var array_line_edit = LineEdit.new()
			array_line_edit.text = ", ".join(val)
			array_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			array_line_edit.text_changed.connect(func(new_text): _update_array_attribute(key, new_text))
			row_hbox.add_child(array_line_edit)
		else:
			var text_line_edit = LineEdit.new()
			text_line_edit.text = str(val)
			text_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_line_edit.text_changed.connect(func(new_text): _update_entry_attribute(key, new_text))
			row_hbox.add_child(text_line_edit)

	var action_btn_hbox = HBoxContainer.new()
	action_btn_hbox.add_theme_constant_override("separation", 10)

	var save_btn = Button.new()
	save_btn.text = "💾 SAVE ALL CHANGES TO DISK"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	save_btn.pressed.connect(_save_catalogs_to_json_files)
	action_btn_hbox.add_child(save_btn)

	var delete_btn = Button.new()
	delete_btn.text = "🗑️ DELETE ENTRY"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	delete_btn.pressed.connect(_on_delete_entry_click)
	action_btn_hbox.add_child(delete_btn)

	group_vbox.add_child(action_btn_hbox)

	group_panel.add_child(group_vbox)
	form_fields_container.add_child(group_panel)

func _update_entry_attribute(key: String, new_val) -> void:
	var active_catalog = _get_current_active_catalog()
	if active_catalog.has(active_selected_id):
		active_catalog[active_selected_id][key] = new_val
		_update_status_banner("Updated " + key + " for " + active_selected_id)

func _update_array_attribute(key: String, text_val: String) -> void:
	var active_catalog = _get_current_active_catalog()
	if active_catalog.has(active_selected_id):
		var raw_parts = text_val.split(",")
		var clean_arr = []
		for p in raw_parts:
			var t = p.strip_edges()
			if not t.is_empty():
				clean_arr.append(t)
		active_catalog[active_selected_id][key] = clean_arr

func _on_create_new_entry_click() -> void:
	var active_catalog = _get_current_active_catalog()
	var new_id = ""
	var new_template: Dictionary = {}
	
	if current_category == CatalogCategory.WEAPONS:
		new_id = "new_weapon_" + str(randi() % 1000)
		new_template = {
			"id": new_id, "name": "New Custom Weapon", "weapon_type": "Kinetic",
			"damage_min": 20, "damage_max": 30, "rate_of_fire": 2.0,
			"required_slots": 1, "accuracy_bonus": 5, "crit_threshold": 18,
			"description": "Custom designed weapon system."
		}
	elif current_category == CatalogCategory.UPGRADES:
		new_id = "new_upgrade_" + str(randi() % 1000)
		new_template = {
			"id": new_id, "name": "New Upgrade Module", "category": "armor",
			"required_slots": 1, "cost": 300,
			"stats_modified": {"hull_hp_bonus": 50},
			"description": "Custom designed upgrade module."
		}
	elif current_category == CatalogCategory.ENEMIES:
		new_id = "new_enemy_" + str(randi() % 1000)
		new_template = {
			"id": new_id, "name": "New Hostile Unit", "type": "🚙 ARMORED CAR",
			"icon": "🚙", "hp": 120, "max_hp": 120, "armor_class": 14,
			"weapon_slots": 2, "upgrade_slots": 2,
			"equipped_weapons": ["twin_20mm_cannon"],
			"equipped_upgrades": ["graphene_armor_l1"],
			"threat": "STANDARD", "weakness": "EMP Shock",
			"description": "Custom designed enemy unit."
		}
		
	active_catalog[new_id] = new_template
	active_selected_id = new_id
	_refresh_catalog_list()
	_update_status_banner("CREATED NEW CATALOG ENTRY: " + new_id)

func _on_duplicate_entry_click() -> void:
	var active_catalog = _get_current_active_catalog()
	if not active_catalog.has(active_selected_id):
		return
		
	var source_data: Dictionary = active_catalog[active_selected_id]
	var new_cloned_data: Dictionary = source_data.duplicate(true)
	
	var cloned_id = active_selected_id + "_copy_" + str(randi() % 1000)
	new_cloned_data["id"] = cloned_id
	if new_cloned_data.has("name"):
		new_cloned_data["name"] = new_cloned_data["name"] + " (Copy)"
		
	active_catalog[cloned_id] = new_cloned_data
	active_selected_id = cloned_id
	_refresh_catalog_list()
	_update_status_banner("📋 CLONED ENTRY " + source_data.get("name", active_selected_id) + " -> " + cloned_id)

func _on_sort_catalog_alphabetically() -> void:
	var active_catalog = _get_current_active_catalog()
	if active_catalog.is_empty():
		return
		
	var sorted_entries: Array = []
	for item_id in active_catalog.keys():
		sorted_entries.append({
			"id": item_id,
			"name": active_catalog[item_id].get("name", item_id).to_lower(),
			"data": active_catalog[item_id]
		})
		
	sorted_entries.sort_custom(func(a, b): return a["name"] < b["name"])
	
	active_catalog.clear()
	for entry_item in sorted_entries:
		active_catalog[entry_item["id"]] = entry_item["data"]
		
	_refresh_catalog_list()
	_update_status_banner("🔤 SORTED CATALOG ALPHABETICALLY BY NAME")

func _on_delete_entry_click() -> void:
	var active_catalog = _get_current_active_catalog()
	if active_catalog.has(active_selected_id):
		active_catalog.erase(active_selected_id)
		active_selected_id = ""
		_refresh_catalog_list()
		_update_status_banner("DELETED CATALOG ENTRY.")
