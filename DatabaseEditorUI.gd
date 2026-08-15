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
		_update_status_banner("DATABASE EDITOR ACTIVE [F1 TO CLOSE]")
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
	outer_margin.add_theme_constant_override("margin_left", 0)
	outer_margin.add_theme_constant_override("margin_right", 0)
	outer_margin.add_theme_constant_override("margin_top", 0)
	outer_margin.add_theme_constant_override("margin_bottom", 0)
	add_child(outer_margin)

	root_overlay_panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	p_style.border_width_left = 3
	p_style.border_width_top = 3
	p_style.border_width_right = 3
	p_style.border_width_bottom = 3
	p_style.border_color = Color(0.0, 0.85, 1.0) # Cyber Cyan Border
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	root_overlay_panel.add_theme_stylebox_override("panel", p_style)
	
	var custom_theme = Theme.new()
	custom_theme.default_font_size = 12
	root_overlay_panel.theme = custom_theme
	outer_margin.add_child(root_overlay_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_overlay_panel.add_child(main_vbox)

	# Header Bar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "🖥️ STANDALONE CYBERPUNK DATABASE EDITOR [F1 PAUSE MODE]"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	header_hbox.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var exit_btn = Button.new()
	exit_btn.text = " ✖ CLOSE EDITOR (F1) "
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

	# Left Column: Item List & Add Button
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(280, 0)
	left_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_vbox)

	catalog_item_list = ItemList.new()
	catalog_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_item_list.item_selected.connect(_on_item_selected_in_list)
	left_vbox.add_child(catalog_item_list)

	var new_entry_btn = Button.new()
	new_entry_btn.text = "➕ CREATE NEW CATALOG ENTRY"
	new_entry_btn.pressed.connect(_on_create_new_entry_click)
	left_vbox.add_child(new_entry_btn)

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

	var save_json_btn = Button.new()
	save_json_btn.text = "💾 SAVE ALL CHANGES TO JSON FILES"
	save_json_btn.pressed.connect(_save_catalogs_to_json_files)
	footer_hbox.add_child(save_json_btn)

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

	if catalog_item_list.item_count > 0:
		catalog_item_list.select(0)
		_on_item_selected_in_list(0)

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
	
	var header_title = Label.new()
	header_title.text = "EDITING ENTRY ID: " + active_selected_id
	header_title.add_theme_font_size_override("font_size", 12)
	header_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	form_fields_container.add_child(header_title)
	
	for key in entry_data.keys():
		var val = entry_data[key]
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		form_fields_container.add_child(row_hbox)
		
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

	var delete_btn = Button.new()
	delete_btn.text = "🗑️ DELETE THIS ENTRY FROM CATALOG"
	delete_btn.pressed.connect(_on_delete_entry_click)
	form_fields_container.add_child(delete_btn)

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
	_refresh_catalog_list()
	_update_status_banner("CREATED NEW CATALOG ENTRY: " + new_id)

func _on_delete_entry_click() -> void:
	var active_catalog = _get_current_active_catalog()
	if active_catalog.has(active_selected_id):
		active_catalog.erase(active_selected_id)
		active_selected_id = ""
		_refresh_catalog_list()
		_update_status_banner("DELETED CATALOG ENTRY.")
