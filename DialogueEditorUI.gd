extends CanvasLayer

# ==============================================================================
# STORY & DIALOGUE BRANCHING EDITOR OVERLAY (DialogueEditorUI.gd)
# ==============================================================================
# Pressing F3 toggles this overlay on/off and pauses/unpauses the game engine.
# Isolated overlay for creating, editing, and mapping branching dialogues.
# Saves & loads directly from res://scripts/*.json dialogue files.

var is_editor_open: bool = false

# Data cache
var dialogue_files_list: Array[String] = []
var active_file_res_path: String = ""
var active_dialogue_data: Dictionary = {}

var active_selected_node_id: String = ""

# UI Node References
var root_overlay_panel: PanelContainer = null
var file_option_button: OptionButton = null
var node_item_list: ItemList = null
var form_fields_container: VBoxContainer = null
var choices_container: VBoxContainer = null
var status_banner_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 122 # Above F1 (120) and F2 (121)
	_build_ui_hierarchy()
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
		_update_status_banner("STORY & DIALOGUE EDITOR ACTIVE [F3 TO CLOSE]")
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
	_refresh_node_list()

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
	style_box.bg_color = Color(0.03, 0.04, 0.07, 0.96)
	style_box.border_color = Color(1.0, 0.45, 0.1, 0.9) # Orange Cyber Glow
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	root_overlay_panel.add_theme_stylebox_override("panel", style_box)
	
	# Global UI theme font sizing for compact display
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
	title_label.text = "📜 CYBERPUNK STORY & DIALOGUE TREE EDITOR [F3]"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1))
	title_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(VSeparator.new())
	
	var file_lbl = Label.new(); file_lbl.text = "File:"
	header_hbox.add_child(file_lbl)
	file_option_button = OptionButton.new()
	file_option_button.item_selected.connect(_on_dialogue_file_selected)
	header_hbox.add_child(file_option_button)
	
	var new_file_btn = Button.new(); new_file_btn.text = "➕ New Story File"
	new_file_btn.pressed.connect(_on_create_new_story_file_pressed)
	header_hbox.add_child(new_file_btn)
	
	header_hbox.add_child(VSeparator.new())
	
	status_banner_label = Label.new()
	status_banner_label.text = "READY"
	status_banner_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header_hbox.add_child(status_banner_label)
	
	var close_btn = Button.new()
	close_btn.text = "✖ CLOSE (F3)"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(_toggle_dialogue_overlay)
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# Split View Container
	var split_container = HSplitContainer.new()
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.split_offset = 260
	main_vbox.add_child(split_container)
	
	# Left: Node Tree Directory
	var left_panel = VBoxContainer.new()
	split_container.add_child(left_panel)
	
	var list_title = Label.new()
	list_title.text = "🔀 STORY BRANCH NODES"
	list_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	left_panel.add_child(list_title)
	
	node_item_list = ItemList.new()
	node_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_item_list.item_selected.connect(_on_node_selected)
	left_panel.add_child(node_item_list)
	
	var btn_hbox = HBoxContainer.new()
	left_panel.add_child(btn_hbox)
	
	var add_node_btn = Button.new()
	add_node_btn.text = "➕ Add Node"
	add_node_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_node_btn.pressed.connect(_on_add_new_node_pressed)
	btn_hbox.add_child(add_node_btn)
	
	var delete_node_btn = Button.new()
	delete_node_btn.text = "🗑️ Delete"
	delete_node_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_node_btn.pressed.connect(_on_delete_node_pressed)
	btn_hbox.add_child(delete_node_btn)
	
	# Right: Detailed Form & Branching Matrix
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_container.add_child(right_scroll)
	
	form_fields_container = VBoxContainer.new()
	form_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_fields_container.add_theme_constant_override("separation", 10)
	right_scroll.add_child(form_fields_container)

# ==============================================================================
# REFRESH & POPULATION
# ==============================================================================

func _update_status_banner(msg: String) -> void:
	if status_banner_label:
		status_banner_label.text = msg

func _refresh_node_list() -> void:
	node_item_list.clear()
	var nodes_dict = active_dialogue_data.get("nodes", {})
	
	for node_id in nodes_dict.keys():
		var node_data = nodes_dict[node_id]
		var choices = node_data.get("choices", [])
		var branch_count = choices.size()
		var display_text = node_id + " (" + str(branch_count) + " branches)"
		if node_id == "start":
			display_text = "⭐ " + display_text
		node_item_list.add_item(display_text)
		node_item_list.set_item_metadata(node_item_list.get_item_count() - 1, node_id)
		
	if nodes_dict.size() > 0:
		node_item_list.select(0)
		_on_node_selected(0)

func _on_node_selected(index: int) -> void:
	active_selected_node_id = node_item_list.get_item_metadata(index)
	_populate_node_form()

func _populate_node_form() -> void:
	for child in form_fields_container.get_children():
		child.queue_free()
		
	var nodes_dict = active_dialogue_data.get("nodes", {})
	if not nodes_dict.has(active_selected_node_id):
		return
		
	var node_data = nodes_dict[active_selected_node_id]
	
	# --- SECTION 1: SPEAKER & FILE METADATA ---
	var sec1_label = Label.new()
	sec1_label.text = "🗣️ SPEAKER IDENTITY & OVERLAY PROFILE"
	sec1_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	form_fields_container.add_child(sec1_label)
	
	var s_hbox = HBoxContainer.new()
	form_fields_container.add_child(s_hbox)
	
	var lbl_spk = Label.new(); lbl_spk.text = "Speaker Name:"; lbl_spk.custom_minimum_size.x = 110
	s_hbox.add_child(lbl_spk)
	var edit_spk = LineEdit.new(); edit_spk.text = active_dialogue_data.get("speaker_display_name", ""); edit_spk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_spk.text_changed.connect(func(txt): active_dialogue_data["speaker_display_name"] = txt)
	s_hbox.add_child(edit_spk)
	
	var lbl_sub = Label.new(); lbl_sub.text = " Subtitle / Neural ID:"
	s_hbox.add_child(lbl_sub)
	var edit_sub = LineEdit.new(); edit_sub.text = active_dialogue_data.get("speaker_subtitle", ""); edit_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_sub.text_changed.connect(func(txt): active_dialogue_data["speaker_subtitle"] = txt)
	s_hbox.add_child(edit_sub)
	
	# Accent Color
	var c_hbox = HBoxContainer.new()
	form_fields_container.add_child(c_hbox)
	var lbl_clr = Label.new(); lbl_clr.text = "Accent Color (Hex):"; lbl_clr.custom_minimum_size.x = 140
	c_hbox.add_child(lbl_clr)
	var edit_clr = LineEdit.new(); edit_clr.text = active_dialogue_data.get("speaker_color", "#FF6B35"); edit_clr.custom_minimum_size.x = 120
	edit_clr.text_changed.connect(func(txt): active_dialogue_data["speaker_color"] = txt)
	c_hbox.add_child(edit_clr)
	
	form_fields_container.add_child(HSeparator.new())
	
	# --- SECTION 2: NODE DETAILS & DIALOGUE BODY ---
	var sec2_label = Label.new()
	sec2_label.text = "📝 NODE CONTENT [" + active_selected_node_id + "]"
	sec2_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	form_fields_container.add_child(sec2_label)
	
	var id_hbox = HBoxContainer.new()
	form_fields_container.add_child(id_hbox)
	var lbl_nid = Label.new(); lbl_nid.text = "Node ID:"; lbl_nid.custom_minimum_size.x = 110
	id_hbox.add_child(lbl_nid)
	var edit_nid = LineEdit.new(); edit_nid.text = active_selected_node_id; edit_nid.custom_minimum_size.x = 200
	edit_nid.text_submitted.connect(func(new_id):
		if new_id != active_selected_node_id and not new_id.is_empty():
			nodes_dict[new_id] = nodes_dict[active_selected_node_id]
			nodes_dict.erase(active_selected_node_id)
			active_selected_node_id = new_id
			_refresh_node_list()
	)
	id_hbox.add_child(edit_nid)
	
	var emo_hbox = HBoxContainer.new()
	form_fields_container.add_child(emo_hbox)
	var lbl_emo = Label.new(); lbl_emo.text = "Emotion State:"; lbl_emo.custom_minimum_size.x = 110
	emo_hbox.add_child(lbl_emo)
	var edit_emo = LineEdit.new()
	edit_emo.text = node_data.get("portrait_emotion", "neutral")
	edit_emo.custom_minimum_size.x = 200
	edit_emo.text_changed.connect(func(txt): node_data["portrait_emotion"] = txt)
	emo_hbox.add_child(edit_emo)
	
	# Dialogue Rich Text Box
	var txt_lbl = Label.new(); txt_lbl.text = "Dialogue Body Text:"
	form_fields_container.add_child(txt_lbl)
	var text_edit = TextEdit.new()
	text_edit.custom_minimum_size.y = 100
	text_edit.text = node_data.get("text", "")
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(func(): node_data["text"] = text_edit.text)
	form_fields_container.add_child(text_edit)
	
	form_fields_container.add_child(HSeparator.new())
	
	# --- SECTION 3: BRANCHING CHOICE MATRIX ---
	var sec3_label = Label.new()
	sec3_label.text = "🔀 BRANCHING CHOICES MATRIX"
	sec3_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1))
	form_fields_container.add_child(sec3_label)
	
	var choices_array = node_data.get("choices", [])
	
	var ch_top_hbox = HBoxContainer.new()
	form_fields_container.add_child(ch_top_hbox)
	var add_choice_btn = Button.new(); add_choice_btn.text = "➕ Add Choice Option"
	add_choice_btn.pressed.connect(func():
		choices_array.append({ "text": "New dialogue response...", "target": "exit" })
		node_data["choices"] = choices_array
		_populate_node_form()
	)
	ch_top_hbox.add_child(add_choice_btn)
	
	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 8)
	form_fields_container.add_child(choices_container)
	
	# Render each choice row
	for c_idx in range(choices_array.size()):
		var choice_entry = choices_array[c_idx]
		var c_box = PanelContainer.new()
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
		c_style.set_border_width_all(1)
		c_style.border_color = Color(1.0, 0.45, 0.1, 0.5)
		c_box.add_theme_stylebox_override("panel", c_style)
		choices_container.add_child(c_box)
		
		var c_vbox = VBoxContainer.new()
		c_box.add_child(c_vbox)
		
		var row1_hbox = HBoxContainer.new()
		c_vbox.add_child(row1_hbox)
		
		var c_lbl = Label.new(); c_lbl.text = "Option #" + str(c_idx + 1) + ":"
		row1_hbox.add_child(c_lbl)
		
		var edit_ctxt = LineEdit.new(); edit_ctxt.text = choice_entry.get("text", ""); edit_ctxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_ctxt.text_changed.connect(func(txt): choice_entry["text"] = txt)
		row1_hbox.add_child(edit_ctxt)
		
		var del_c_btn = Button.new(); del_c_btn.text = "❌"
		del_c_btn.pressed.connect(func():
			choices_array.remove_at(c_idx)
			node_data["choices"] = choices_array
			_populate_node_form()
		)
		row1_hbox.add_child(del_c_btn)
		
		var row2_hbox = HBoxContainer.new()
		c_vbox.add_child(row2_hbox)
		
		var tgt_lbl = Label.new(); tgt_lbl.text = "  ➡ Target Branch Node:"
		row2_hbox.add_child(tgt_lbl)
		
		# Target Node Dropdown
		var target_opt = OptionButton.new()
		var all_node_ids = nodes_dict.keys()
		if not all_node_ids.has("exit"):
			all_node_ids.append("exit")
			
		var curr_tgt = choice_entry.get("target", "exit")
		var sel_tgt_idx = 0
		for tid_i in range(all_node_ids.size()):
			var tid = all_node_ids[tid_i]
			target_opt.add_item(tid)
			if tid == curr_tgt:
				sel_tgt_idx = tid_i
		target_opt.select(sel_tgt_idx)
		target_opt.item_selected.connect(func(t_idx):
			choice_entry["target"] = all_node_ids[t_idx]
		)
		row2_hbox.add_child(target_opt)
		
		# Quick Jump to Target Node Button
		var jump_btn = Button.new(); jump_btn.text = "🔍 Jump To Node"
		jump_btn.pressed.connect(func():
			var target_id = choice_entry.get("target", "")
			if nodes_dict.has(target_id):
				active_selected_node_id = target_id
				_refresh_node_list()
				# Find index in ItemList
				for i in range(node_item_list.get_item_count()):
					if node_item_list.get_item_metadata(i) == target_id:
						node_item_list.select(i)
						break
		)
		row2_hbox.add_child(jump_btn)
		
		# Quick Create & Link Target Node Button
		var quick_create_btn = Button.new(); quick_create_btn.text = "➕ Create & Link New Node"
		quick_create_btn.pressed.connect(func():
			var new_target_id = "branch_" + str(Time.get_ticks_msec())
			nodes_dict[new_target_id] = {
				"text": "Continuation line for " + choice_entry.get("text", "") + "...",
				"portrait_emotion": "neutral",
				"choices": [
					{ "text": "Continue... [Leave]", "target": "exit" }
				]
			}
			choice_entry["target"] = new_target_id
			active_selected_node_id = new_target_id
			_refresh_node_list()
		)
		row2_hbox.add_child(quick_create_btn)
	
	# --- SECTION 4: SAVE FILE ---
	form_fields_container.add_child(HSeparator.new())
	var save_btn = Button.new()
	save_btn.text = "💾 SAVE STORY FILE TO DISK (" + active_file_res_path + ")"
	save_btn.custom_minimum_size.y = 38
	save_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	save_btn.pressed.connect(_save_current_dialogue_file)
	form_fields_container.add_child(save_btn)

# ==============================================================================
# NODE CREATION & DELETION
# ==============================================================================

func _on_add_new_node_pressed() -> void:
	var nodes_dict = active_dialogue_data.get("nodes", {})
	var new_id = "node_" + str(Time.get_ticks_msec())
	nodes_dict[new_id] = {
		"text": "Enter new dialogue text here...",
		"portrait_emotion": "neutral",
		"choices": [
			{ "text": "End conversation [Leave]", "target": "exit" }
		]
	}
	active_dialogue_data["nodes"] = nodes_dict
	_refresh_node_list()
	active_selected_node_id = new_id
	_populate_node_form()
	_update_status_banner("✨ CREATED NEW DIALOGUE NODE " + new_id)

func _on_delete_node_pressed() -> void:
	var nodes_dict = active_dialogue_data.get("nodes", {})
	if nodes_dict.has(active_selected_node_id) and active_selected_node_id != "start":
		nodes_dict.erase(active_selected_node_id)
		_refresh_node_list()
		_update_status_banner("🗑️ DELETED NODE")

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
				"choices": [
					{ "text": "Goodbye. [Leave]", "target": "exit" }
				]
			}
		}
	}
	var file = FileAccess.open(full_res_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(new_data, "\t"))
		file.close()
		_scan_dialogue_directory()
		_update_status_banner("✨ CREATED NEW STORY FILE " + full_res_path)
