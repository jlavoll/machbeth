extends CanvasLayer

# ==============================================================================
# DUAL-MODE STORY & DIALOGUE BRANCHING EDITOR OVERLAY (DialogueEditorUI.gd)
# ==============================================================================
# Pressing F3 toggles this overlay on/off and pauses/unpauses the game engine.
# Supports 2 seamlessly compatible view modes:
# 1. GRAPH VIEW: Visual GraphEdit & GraphNode drag-and-drop wire canvas.
# 2. LIST VIEW: Clean linear ItemList node directory & detailed form editor.

enum EditorViewMode { GRAPH_VIEW, LIST_VIEW }
var current_view_mode: EditorViewMode = EditorViewMode.GRAPH_VIEW

var is_editor_open: bool = false

# Data cache
var dialogue_files_list: Array[String] = []
var active_file_res_path: String = ""
var active_dialogue_data: Dictionary = {}
var active_selected_node_id: String = ""

# UI Controls
var root_overlay_panel: PanelContainer = null
var file_option_button: OptionButton = null
var mode_toggle_button: Button = null
var status_banner_label: Label = null

# Containers for Dual-Mode View
var graph_editor_container: Control = null
var list_editor_container: Control = null

# Graph View Controls
var dialogue_graph_edit: GraphEdit = null

# List View Controls
var node_item_list: ItemList = null
var form_fields_container: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 122 # Above F1 (120) and F2 (121)
	_build_dual_mode_ui_hierarchy()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_toggle_dialogue_overlay()

func _toggle_dialogue_overlay() -> void:
	is_editor_open = not is_editor_open
	visible = is_editor_open
	root_overlay_panel.visible = is_editor_open
	get_tree().paused = is_editor_open
	
	if is_editor_open:
		_scan_dialogue_directory()
		_update_status_banner("ACTIVE")
	else:
		_update_status_banner("GAME RESUMED")

# ==============================================================================
# FILE SYSTEM ACCESS & SCANNING
# ==============================================================================

func _scan_dialogue_directory() -> void:
	dialogue_files_list.clear()
	file_option_button.clear()
	
	var dir = DirAccess.open("res://scripts")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var full_path = "res://scripts/" + file_name
				dialogue_files_list.append(full_path)
				file_option_button.add_item(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
	if dialogue_files_list.size() > 0:
		file_option_button.select(0)
		_on_dialogue_file_selected(0)

func _on_dialogue_file_selected(index: int) -> void:
	if index < 0 or index >= dialogue_files_list.size():
		return
	active_file_res_path = dialogue_files_list[index]
	active_dialogue_data = _read_json_file(active_file_res_path)
	_refresh_active_view_mode()

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

func _save_current_dialogue_file() -> void:
	if active_file_res_path.is_empty():
		return
	var file = FileAccess.open(active_file_res_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(active_dialogue_data, "\t"))
		file.close()
		_update_status_banner("💾 SAVED DIALOGUE TO " + active_file_res_path)

# ==============================================================================
# DUAL MODE SWITCHING
# ==============================================================================

func _on_toggle_view_mode_pressed() -> void:
	if current_view_mode == EditorViewMode.GRAPH_VIEW:
		current_view_mode = EditorViewMode.LIST_VIEW
	else:
		current_view_mode = EditorViewMode.GRAPH_VIEW
	_refresh_active_view_mode()

func _refresh_active_view_mode() -> void:
	if current_view_mode == EditorViewMode.GRAPH_VIEW:
		if mode_toggle_button: mode_toggle_button.text = "🔀 SWITCH TO LIST VIEW"
		graph_editor_container.visible = true
		list_editor_container.visible = false
		_rebuild_graph_nodes()
	else:
		if mode_toggle_button: mode_toggle_button.text = "🕸️ SWITCH TO GRAPH VIEW"
		graph_editor_container.visible = false
		list_editor_container.visible = true
		_refresh_list_nodes()

# ==============================================================================
# UI HIERARCHY GENERATION
# ==============================================================================

func _build_dual_mode_ui_hierarchy() -> void:
	root_overlay_panel = PanelContainer.new()
	root_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_overlay_panel)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.03, 0.04, 0.07, 0.96)
	style_box.border_color = Color(1.0, 0.45, 0.1, 0.9) # Orange Cyber Glow
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	root_overlay_panel.add_theme_stylebox_override("panel", style_box)
	
	# Global UI theme font sizing for compact display (11px)
	var custom_theme = Theme.new()
	custom_theme.default_font_size = 11
	root_overlay_panel.theme = custom_theme

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	root_overlay_panel.add_child(main_vbox)
	
	# Header Toolbar
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "DIALOGUE EDITOR [F3]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1))
	title_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(VSeparator.new())
	
	var file_lbl = Label.new(); file_lbl.text = "File:"
	header_hbox.add_child(file_lbl)
	file_option_button = OptionButton.new()
	file_option_button.item_selected.connect(_on_dialogue_file_selected)
	header_hbox.add_child(file_option_button)
	
	var new_file_btn = Button.new(); new_file_btn.text = "➕ New File"
	new_file_btn.pressed.connect(_on_create_new_story_file_pressed)
	header_hbox.add_child(new_file_btn)
	
	header_hbox.add_child(VSeparator.new())

	# Mode Toggle Button
	mode_toggle_button = Button.new()
	mode_toggle_button.text = "🔀 SWITCH TO LIST VIEW"
	mode_toggle_button.pressed.connect(_on_toggle_view_mode_pressed)
	header_hbox.add_child(mode_toggle_button)

	var add_node_btn = Button.new(); add_node_btn.text = "➕ Add Node"
	add_node_btn.pressed.connect(_on_add_new_node_pressed)
	header_hbox.add_child(add_node_btn)

	var save_btn = Button.new(); save_btn.text = "💾 Save All"
	save_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	save_btn.pressed.connect(_save_current_dialogue_file)
	header_hbox.add_child(save_btn)
	
	header_hbox.add_child(VSeparator.new())
	
	status_banner_label = Label.new()
	status_banner_label.text = "READY"
	status_banner_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header_hbox.add_child(status_banner_label)
	
	var close_btn = Button.new()
	close_btn.text = " CLOSE "
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_toggle_dialogue_overlay)
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())

	# Content Area
	var content_container = PanelContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_container)

	# --- 1. GRAPH VIEW CONTAINER ---
	graph_editor_container = MarginContainer.new()
	graph_editor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.add_child(graph_editor_container)

	dialogue_graph_edit = GraphEdit.new()
	dialogue_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_graph_edit.snapping_enabled = true
	dialogue_graph_edit.snapping_distance = 20
	dialogue_graph_edit.connection_request.connect(_on_graph_connection_request)
	dialogue_graph_edit.disconnection_request.connect(_on_graph_disconnection_request)
	dialogue_graph_edit.delete_nodes_request.connect(_on_graph_delete_nodes_request)
	graph_editor_container.add_child(dialogue_graph_edit)

	# --- 2. LIST VIEW CONTAINER ---
	list_editor_container = HSplitContainer.new()
	list_editor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	(list_editor_container as HSplitContainer).split_offset = 260
	list_editor_container.visible = false
	content_container.add_child(list_editor_container)

	# Left: Node List Directory
	var left_panel = VBoxContainer.new()
	list_editor_container.add_child(left_panel)

	var list_title = Label.new()
	list_title.text = "🔀 STORY BRANCH NODES"
	list_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	left_panel.add_child(list_title)

	node_item_list = ItemList.new()
	node_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_item_list.item_selected.connect(_on_list_node_selected)
	left_panel.add_child(node_item_list)

	# Right: Detailed Form Panel
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_editor_container.add_child(right_scroll)

	form_fields_container = VBoxContainer.new()
	form_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_fields_container.add_theme_constant_override("separation", 10)
	right_scroll.add_child(form_fields_container)

func _update_status_banner(msg: String) -> void:
	if status_banner_label:
		status_banner_label.text = msg

# ==============================================================================
# MODE 1: GRAPH VIEW IMPLEMENTATION
# ==============================================================================

func _rebuild_graph_nodes() -> void:
	if not is_instance_valid(dialogue_graph_edit): return
	dialogue_graph_edit.clear_connections()
	for child in dialogue_graph_edit.get_children():
		if child is GraphNode: child.queue_free()

	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	var layout_x: float = 80.0
	var layout_y: float = 60.0
	var column_index: int = 0

	for node_id in nodes_dict.keys():
		var node_data: Dictionary = nodes_dict[node_id]
		var graph_node = _construct_single_graph_node(node_id, node_data)
		var stored_pos = node_data.get("editor_position", Vector2(layout_x + (column_index % 3) * 360.0, layout_y + (column_index / 3) * 260.0))
		graph_node.position_offset = Vector2(stored_pos.x if typeof(stored_pos) == TYPE_VECTOR2 else stored_pos.get("x", 100), stored_pos.y if typeof(stored_pos) == TYPE_VECTOR2 else stored_pos.get("y", 100))
		dialogue_graph_edit.add_child(graph_node)
		column_index += 1

	for node_id in nodes_dict.keys():
		var choices: Array = nodes_dict[node_id].get("choices", [])
		for choice_idx in range(choices.size()):
			var target_node_id: String = choices[choice_idx].get("target", "")
			if not target_node_id.is_empty() and nodes_dict.has(target_node_id):
				dialogue_graph_edit.connect_node(node_id, choice_idx, target_node_id, 0)

func _construct_single_graph_node(node_id: String, node_data: Dictionary) -> GraphNode:
	var graph_node = GraphNode.new()
	graph_node.name = node_id
	graph_node.title = ("⭐ START: " if node_id == "start" else "NODE: ") + node_id
	graph_node.resizable = true
	graph_node.custom_minimum_size = Vector2(300, 220)
	graph_node.set_slot(0, true, 0, Color(0.0, 0.85, 1.0), false, 0, Color(1.0, 1.0, 1.0))

	var text_edit = TextEdit.new()
	text_edit.text = node_data.get("text", "")
	text_edit.custom_minimum_size.y = 70
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(func(): node_data["text"] = text_edit.text)
	graph_node.add_child(text_edit)

	var choices: Array = node_data.get("choices", [])
	for choice_idx in range(choices.size()):
		var choice_entry: Dictionary = choices[choice_idx]
		var choice_hbox = HBoxContainer.new()
		
		var choice_line = LineEdit.new()
		choice_line.text = choice_entry.get("text", "")
		choice_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_line.text_changed.connect(func(txt): choice_entry["text"] = txt)
		choice_hbox.add_child(choice_line)

		var action_opt = OptionButton.new()
		action_opt.add_item("💬 DIALOGUE ONLY", 0); action_opt.add_item("🚀 F4 QUEST", 1); action_opt.add_item("⚔️ F2 BATTLE", 2)
		var curr_action: String = choice_entry.get("action", "")
		if curr_action == "START_STREET_MISSION": action_opt.select(1)
		elif curr_action == "START_MACK_BATTLE": action_opt.select(2)
		else: action_opt.select(0)

		action_opt.item_selected.connect(func(idx):
			match idx:
				0: choice_entry.erase("action"); choice_entry.erase("quest_id")
				1: choice_entry["action"] = "START_STREET_MISSION"; choice_entry["quest_id"] = "street_01_pink_cadillac"
				2: choice_entry["action"] = "START_MACK_BATTLE"; choice_entry["quest_id"] = "mission_act1_war_rig"
		)
		choice_hbox.add_child(action_opt)
		graph_node.add_child(choice_hbox)

		var port_color = Color(1.0, 0.85, 0.0)
		if curr_action == "START_STREET_MISSION": port_color = Color(0.0, 1.0, 0.4)
		elif curr_action == "START_MACK_BATTLE": port_color = Color(1.0, 0.1, 0.2)
		graph_node.set_slot(choice_idx + 1, false, 0, Color(1.0, 1.0, 1.0), true, 0, port_color)

	var add_choice_btn = Button.new(); add_choice_btn.text = "➕ Add Choice"
	add_choice_btn.pressed.connect(func():
		choices.append({"text": "New choice option...", "target": "exit"})
		_rebuild_graph_nodes()
	)
	graph_node.add_child(add_choice_btn)
	return graph_node

func _on_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	if nodes_dict.has(from_node):
		var choices: Array = nodes_dict[from_node].get("choices", [])
		if from_port < choices.size():
			choices[from_port]["target"] = String(to_node)
			dialogue_graph_edit.connect_node(from_node, from_port, to_node, 0)
			_update_status_banner("⚡ WIRED CHOICE " + str(from_port) + " -> " + String(to_node))

func _on_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	if nodes_dict.has(from_node):
		var choices: Array = nodes_dict[from_node].get("choices", [])
		if from_port < choices.size():
			choices[from_port]["target"] = "exit"
			dialogue_graph_edit.disconnect_node(from_node, from_port, to_node, 0)
			_update_status_banner("✂️ UNWIRED CHOICE BRANCH")

func _on_graph_delete_nodes_request(node_names: Array[StringName]) -> void:
	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	for node_name in node_names:
		var n_str = String(node_name)
		if n_str != "start" and nodes_dict.has(n_str): nodes_dict.erase(n_str)
	_rebuild_graph_nodes()

# ==============================================================================
# MODE 2: ORIGINAL LIST VIEW IMPLEMENTATION
# ==============================================================================

func _refresh_list_nodes() -> void:
	node_item_list.clear()
	var nodes_dict = active_dialogue_data.get("nodes", {})
	var selected_idx: int = 0
	var item_idx: int = 0
	
	for node_id in nodes_dict.keys():
		var choices = nodes_dict[node_id].get("choices", [])
		var display_text = node_id + " (" + str(choices.size()) + " branches)"
		if node_id == "start": display_text = "⭐ " + display_text
		node_item_list.add_item(display_text)
		node_item_list.set_item_metadata(item_idx, node_id)
		
		if node_id == active_selected_node_id:
			selected_idx = item_idx
		item_idx += 1
		
	if nodes_dict.size() > 0:
		node_item_list.select(selected_idx)
		active_selected_node_id = node_item_list.get_item_metadata(selected_idx)
		_populate_list_form()

func _on_list_node_selected(index: int) -> void:
	active_selected_node_id = node_item_list.get_item_metadata(index)
	_populate_list_form()

func _populate_list_form() -> void:
	for child in form_fields_container.get_children(): child.queue_free()
	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	if not nodes_dict.has(active_selected_node_id): return
	var node_data: Dictionary = nodes_dict[active_selected_node_id]

	# --- GROUP 1: GLOBAL SPEAKER METADATA GROUP BOX ---
	var speaker_group_panel = PanelContainer.new()
	var group1_style = StyleBoxFlat.new()
	group1_style.bg_color = Color(0.05, 0.07, 0.12, 0.8)
	group1_style.border_color = Color(0.0, 0.85, 1.0, 0.4) # Cyan Group Border
	group1_style.set_border_width_all(1)
	group1_style.set_corner_radius_all(4)
	group1_style.set_content_margin_all(8)
	speaker_group_panel.add_theme_stylebox_override("panel", group1_style)

	var speaker_vbox = VBoxContainer.new()
	var group1_title = Label.new()
	group1_title.text = "👤 SPEAKER METADATA"
	group1_title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	group1_title.add_theme_font_size_override("font_size", 12)
	speaker_vbox.add_child(group1_title)

	var speaker_box = HBoxContainer.new()
	var name_lbl = Label.new(); name_lbl.text = "Name:"
	speaker_box.add_child(name_lbl)
	var name_edit = LineEdit.new()
	name_edit.text = active_dialogue_data.get("speaker_display_name", "NPC")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(txt): active_dialogue_data["speaker_display_name"] = txt)
	speaker_box.add_child(name_edit)

	var sub_edit = LineEdit.new()
	sub_edit.text = active_dialogue_data.get("speaker_subtitle", "")
	sub_edit.placeholder_text = "Subtitle / Neural ID..."
	sub_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_edit.text_changed.connect(func(txt): active_dialogue_data["speaker_subtitle"] = txt)
	speaker_box.add_child(sub_edit)
	speaker_vbox.add_child(speaker_box)
	speaker_group_panel.add_child(speaker_vbox)
	form_fields_container.add_child(speaker_group_panel)

	# --- GROUP 2: NODE PROMPT & EMOTION GROUP BOX ---
	var node_group_panel = PanelContainer.new()
	var group2_style = StyleBoxFlat.new()
	group2_style.bg_color = Color(0.05, 0.07, 0.12, 0.8)
	group2_style.border_color = Color(1.0, 0.85, 0.0, 0.4) # Gold Group Border
	group2_style.set_border_width_all(1)
	group2_style.set_corner_radius_all(4)
	group2_style.set_content_margin_all(8)
	node_group_panel.add_theme_stylebox_override("panel", group2_style)

	var node_vbox = VBoxContainer.new()
	node_vbox.add_theme_constant_override("separation", 6)
	
	var header_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "💬 EDITING NODE: " + active_selected_node_id
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	title_lbl.add_theme_font_size_override("font_size", 13)
	header_hbox.add_child(title_lbl)

	var delete_btn = Button.new(); delete_btn.text = "🗑️ Delete Node"
	delete_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	delete_btn.pressed.connect(func():
		if active_selected_node_id != "start":
			nodes_dict.erase(active_selected_node_id)
			_refresh_list_nodes()
			_update_status_banner("🗑️ DELETED NODE " + active_selected_node_id)
	)
	header_hbox.add_child(delete_btn)
	node_vbox.add_child(header_hbox)

	var emotion_hbox = HBoxContainer.new()
	var emo_lbl = Label.new(); emo_lbl.text = "Portrait Emotion:"
	emotion_hbox.add_child(emo_lbl)
	var emo_opt = OptionButton.new()
	var emotions = ["neutral", "smirk", "angry", "shocked", "thoughtful"]
	for emo in emotions: emo_opt.add_item(emo)
	var curr_emo = node_data.get("portrait_emotion", "neutral")
	var emo_idx = emotions.find(curr_emo)
	emo_opt.select(emo_idx if emo_idx >= 0 else 0)
	emo_opt.item_selected.connect(func(idx): node_data["portrait_emotion"] = emotions[idx])
	emotion_hbox.add_child(emo_opt)
	node_vbox.add_child(emotion_hbox)

	var text_lbl = Label.new(); text_lbl.text = "Dialogue Line Text:"
	node_vbox.add_child(text_lbl)
	var text_edit = TextEdit.new()
	text_edit.text = node_data.get("text", "")
	text_edit.custom_minimum_size.y = 70
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(func(): node_data["text"] = text_edit.text)
	node_vbox.add_child(text_edit)

	node_group_panel.add_child(node_vbox)
	form_fields_container.add_child(node_group_panel)

	# --- GROUP 3: CHOICE BRANCHES & QUEST TRIGGERS GROUP BOX ---
	var choices_group_panel = PanelContainer.new()
	var group3_style = StyleBoxFlat.new()
	group3_style.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	group3_style.border_color = Color(1.0, 0.45, 0.1, 0.4) # Orange Group Border
	group3_style.set_border_width_all(1)
	group3_style.set_corner_radius_all(4)
	group3_style.set_content_margin_all(8)
	choices_group_panel.add_theme_stylebox_override("panel", group3_style)

	var choices_vbox = VBoxContainer.new()
	choices_vbox.add_theme_constant_override("separation", 8)

	var choices_hdr = Label.new(); choices_hdr.text = "🌿 CHOICE BRANCHES & QUEST TRIGGERS"
	choices_hdr.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1))
	choices_hdr.add_theme_font_size_override("font_size", 12)
	choices_vbox.add_child(choices_hdr)

	var choices: Array = node_data.get("choices", [])
	for i in range(choices.size()):
		var choice_entry: Dictionary = choices[i]
		
		# Individual Choice Card Panel
		var choice_card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.07, 0.09, 0.14)
		card_style.border_color = Color(0.2, 0.25, 0.35)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(3)
		card_style.set_content_margin_all(6)
		choice_card.add_theme_stylebox_override("panel", card_style)

		var choice_card_vbox = VBoxContainer.new()
		
		var row1_hbox = HBoxContainer.new()
		var choice_num_lbl = Label.new()
		choice_num_lbl.text = "#" + str(i + 1) + ":" # Compact prefix
		choice_num_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row1_hbox.add_child(choice_num_lbl)

		var line = LineEdit.new()
		line.text = choice_entry.get("text", "")
		line.placeholder_text = "Choice text..."
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.text_changed.connect(func(txt): choice_entry["text"] = txt)
		row1_hbox.add_child(line)

		var target_lbl = Label.new(); target_lbl.text = "Target:"
		row1_hbox.add_child(target_lbl)

		# Dynamic OptionButton dropdown of all valid dialogue node targets in the current story file
		var target_opt = OptionButton.new()
		target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Gives generous horizontal width to Target!
		
		var valid_target_ids: Array[String] = ["exit"]
		for nid in nodes_dict.keys():
			valid_target_ids.append(nid)

		for tid in valid_target_ids:
			target_opt.add_item("🚪 exit" if tid == "exit" else ("⭐ " + tid if tid == "start" else "🔀 " + tid))

		var current_target: String = choice_entry.get("target", "exit")
		var selected_target_idx = valid_target_ids.find(current_target)
		target_opt.select(selected_target_idx if selected_target_idx >= 0 else 0)

		target_opt.item_selected.connect(func(idx):
			if idx >= 0 and idx < valid_target_ids.size():
				choice_entry["target"] = valid_target_ids[idx]
		)
		row1_hbox.add_child(target_opt)
		choice_card_vbox.add_child(row1_hbox)

		var row2_hbox = HBoxContainer.new()
		var action_opt = OptionButton.new()
		action_opt.add_item("💬 STANDARD DIALOGUE BRANCH", 0)
		action_opt.add_item("🚀 TRIGGER F4 STREET QUEST", 1)
		action_opt.add_item("⚔️ TRIGGER F2 MACK BATTLE", 2)
		var curr_action: String = choice_entry.get("action", "")
		if curr_action == "START_STREET_MISSION": action_opt.select(1)
		elif curr_action == "START_MACK_BATTLE": action_opt.select(2)
		else: action_opt.select(0)

		action_opt.item_selected.connect(func(idx):
			match idx:
				0:
					choice_entry.erase("action")
					choice_entry.erase("quest_id")
				1:
					choice_entry["action"] = "START_STREET_MISSION"
					choice_entry["quest_id"] = "street_01_pink_cadillac"
				2:
					choice_entry["action"] = "START_MACK_BATTLE"
					choice_entry["quest_id"] = "mission_act1_war_rig"
		)
		row2_hbox.add_child(action_opt)

		var jump_btn = Button.new(); jump_btn.text = "🔍 JUMP TO TARGET NODE"
		jump_btn.tooltip_text = "Selects and opens the targeted node directly in the form editor"
		jump_btn.pressed.connect(func():
			var target_id = choice_entry.get("target", "")
			if nodes_dict.has(target_id):
				active_selected_node_id = target_id
				_refresh_list_nodes()
		)
		row2_hbox.add_child(jump_btn)

		var quick_create_btn = Button.new(); quick_create_btn.text = "➕ Create & Link Node"
		quick_create_btn.pressed.connect(func():
			var new_target_id = "branch_" + str(Time.get_ticks_msec())
			nodes_dict[new_target_id] = {
				"text": "Continuation line...",
				"portrait_emotion": "neutral",
				"choices": [ { "text": "Continue...", "target": "exit" } ]
			}
			choice_entry["target"] = new_target_id
			active_selected_node_id = new_target_id
			_refresh_list_nodes()
		)
		row2_hbox.add_child(quick_create_btn)

		choice_card_vbox.add_child(row2_hbox)
		choice_card.add_child(choice_card_vbox)
		choices_vbox.add_child(choice_card)

	var add_choice_btn = Button.new(); add_choice_btn.text = "➕ Add Choice Branch Option"
	add_choice_btn.pressed.connect(func():
		choices.append({"text": "New choice option...", "target": "exit"})
		_populate_list_form()
	)
	choices_vbox.add_child(add_choice_btn)
	choices_group_panel.add_child(choices_vbox)
	form_fields_container.add_child(choices_group_panel)

func _on_add_new_node_pressed() -> void:
	var nodes_dict: Dictionary = active_dialogue_data.get("nodes", {})
	var new_id = "node_" + str(Time.get_ticks_msec())
	nodes_dict[new_id] = {
		"text": "Enter dialogue line...",
		"portrait_emotion": "neutral",
		"choices": [ { "text": "Continue...", "target": "exit" } ]
	}
	active_dialogue_data["nodes"] = nodes_dict
	_refresh_active_view_mode()
	_update_status_banner("✨ CREATED NODE " + new_id)

func _on_create_new_story_file_pressed() -> void:
	var file_name = "new_story_" + str(Time.get_ticks_msec()) + ".json"
	var full_res_path = "res://scripts/" + file_name
	var new_data = {
		"speaker_display_name": "Unknown Contact",
		"speaker_subtitle": "NEURAL-ID: UNKNOWN_001",
		"speaker_color": "#00E5FF",
		"nodes": {
			"start": {
				"text": "Start conversation line...",
				"portrait_emotion": "neutral",
				"choices": [ { "text": "Goodbye. [Leave]", "target": "exit" } ]
			}
		}
	}
	var file = FileAccess.open(full_res_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(new_data, "\t"))
		file.close()
		_scan_dialogue_directory()
		_update_status_banner("✨ CREATED NEW STORY FILE " + full_res_path)
