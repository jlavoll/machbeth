extends CanvasLayer
class_name InventoryShopUI

# ==============================================================================
# UNIFIED INVENTORY & THE PIT SHOP UI (InventoryShopUI.gd)
# ==============================================================================
# Full-screen or modal overlay for The Pit Black-Market Shop, Banquo's Stash,
# and Mack's Cyberware Locker. Press [I] to open personal inventory, or interact
# at Porter's Pit Garage Counter.

var is_open: bool = false
var active_tab_index: int = 0

# UI References
var root_control: Control = null
var currency_header_label: RichTextLabel = null
var tab_bar: TabBar = null
var items_scroll_container: VBoxContainer = null

# Preloaded Orbitron Font
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126 # Above LoadoutGridUI (125)
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			toggle_inventory_ui(1) # Open Banquo's Stash on [I]
			get_viewport().set_input_as_handled()
		elif is_open and (event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB):
			close_inventory_ui()
			get_viewport().set_input_as_handled()

func toggle_inventory_ui(default_tab: int = 0) -> void:
	if is_open:
		close_inventory_ui()
	else:
		open_inventory_ui(default_tab)

func open_inventory_ui(tab_idx: int = 0) -> void:
	is_open = true
	visible = true
	active_tab_index = tab_idx
	if is_instance_valid(tab_bar):
		tab_bar.current_tab = tab_idx
	get_tree().paused = true
	_refresh_currency_header()
	_refresh_items_view()

func close_inventory_ui() -> void:
	is_open = false
	visible = false
	get_tree().paused = false

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "InventoryShopRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	# Dark frosted glass background
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	root_control.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# 1. Header Bar
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "📦 LOGISTICS & BLACK-MARKET INVENTORY"
	title.add_theme_font_override("font", orbitron_font)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	header.add_child(title)

	header.add_spacer(false)

	currency_header_label = RichTextLabel.new()
	currency_header_label.bbcode_enabled = true
	currency_header_label.custom_minimum_size = Vector2(340, 26)
	currency_header_label.fit_content = true
	header.add_child(currency_header_label)

	var btn_close = Button.new()
	btn_close.text = "✖ CLOSE [ESC/I]"
	btn_close.pressed.connect(close_inventory_ui)
	header.add_child(btn_close)
	main_vbox.add_child(header)

	# 2. Navigation Tabs Bar
	tab_bar = TabBar.new()
	tab_bar.add_tab("🛒 THE PIT BLACK-MARKET SHOP")
	tab_bar.add_tab("🎒 BANQUO'S TRUNK & STASH")
	tab_bar.add_tab("👤 MACK'S CYBERNETIC LOCKER")
	tab_bar.tab_changed.connect(func(tab):
		active_tab_index = tab
		_refresh_items_view()
	)
	main_vbox.add_child(tab_bar)

	main_vbox.add_child(HSeparator.new())

	# 3. Main Item Scroll Container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	items_scroll_container = VBoxContainer.new()
	items_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll_container.add_theme_constant_override("separation", 8)
	scroll.add_child(items_scroll_container)

	# Quick Key Hint Footer
	var footer = Label.new()
	footer.text = "💡 QUICK-HOTKEYS: [H] Nano-Repair Injector (+50 HP) | [J] Neural Glitch Dampener Stim (-30% Paranoia) | [I] Inventory"
	footer.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(footer)

func _refresh_currency_header() -> void:
	var quest_mgr = get_parent().get_node_or_null("QuestManager")
	var inv_mgr = get_parent().get_node_or_null("UnifiedInventoryManager") as UnifiedInventoryManager
	var credits: int = quest_mgr.player_credits if is_instance_valid(quest_mgr) else 0
	var scrap: int = inv_mgr.player_scrap_salvage if is_instance_valid(inv_mgr) else 0

	currency_header_label.text = "💰 [color=#00ffcc]Credits:[/color] [b]%d CR[/b]   ⚙️ [color=#ffbb00]Scrap:[/color] [b]%d[/b]" % [credits, scrap]

func _refresh_items_view() -> void:
	for child in items_scroll_container.get_children():
		child.queue_free()

	var inv_mgr = get_parent().get_node_or_null("UnifiedInventoryManager") as UnifiedInventoryManager
	if not is_instance_valid(inv_mgr):
		return

	_refresh_currency_header()

	match active_tab_index:
		0:
			_render_pit_shop(inv_mgr)
		1:
			_render_banquo_stash(inv_mgr)
		2:
			_render_mack_locker(inv_mgr)

func _render_pit_shop(inv_mgr: UnifiedInventoryManager) -> void:
	for item_id in inv_mgr.pit_shop_stock:
		var item = inv_mgr.master_catalog.get(item_id, {})
		var card = _build_item_card(item, "SHOP", inv_mgr)
		items_scroll_container.add_child(card)

func _render_banquo_stash(inv_mgr: UnifiedInventoryManager) -> void:
	if inv_mgr.banquo_stash.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Trunk is empty! Salvage loot from highway convoys or buy items at The Pit."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		items_scroll_container.add_child(empty_lbl)
		return

	for item_id in inv_mgr.banquo_stash:
		var item = inv_mgr.master_catalog.get(item_id, {})
		var qty: int = inv_mgr.banquo_stash[item_id]
		var card = _build_item_card(item, "STASH", inv_mgr, qty)
		items_scroll_container.add_child(card)

func _render_mack_locker(inv_mgr: UnifiedInventoryManager) -> void:
	# Add direct button to open Loadout Grid
	var grid_btn = Button.new()
	grid_btn.text = "⚡ [OPEN MACK & VEHICLE LOADOUT GRID]"
	grid_btn.add_theme_font_override("font", orbitron_font)
	grid_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	grid_btn.pressed.connect(func():
		close_inventory_ui()
		var l_ui = get_parent().get_node_or_null("LoadoutGridUI") as LoadoutGridUI
		if is_instance_valid(l_ui):
			l_ui.open_loadout_ui()
	)
	items_scroll_container.add_child(grid_btn)

	for item_id in inv_mgr.mack_locker:
		var item = inv_mgr.master_catalog.get(item_id, {})
		var card = _build_item_card(item, "LOCKER", inv_mgr)
		items_scroll_container.add_child(card)

func _build_item_card(item: Dictionary, context: String, inv_mgr: UnifiedInventoryManager, qty: int = 1) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.85)
	style.border_width_left = 3
	style.border_color = Color(0.0, 1.0, 0.85) if context != "SHOP" else Color(1.0, 0.8, 0.0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	card.add_child(hbox)

	var icon_lbl = Label.new()
	icon_lbl.text = item.get("icon", "🔹")
	icon_lbl.add_theme_font_size_override("font_size", 24)
	hbox.add_child(icon_lbl)

	var desc_vbox = VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_vbox)

	var name_lbl = Label.new()
	var qty_str = " (x%d)" % qty if (context == "STASH" and qty > 1) else ""
	name_lbl.text = "%s%s // %s" % [item.get("name", ""), qty_str, item.get("category", "")]
	name_lbl.add_theme_font_override("font", orbitron_font)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	desc_vbox.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = item.get("description", "")
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	desc_vbox.add_child(sub_lbl)

	# Action Buttons depending on Context
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	hbox.add_child(action_hbox)

	if context == "SHOP":
		var cost_c = item.get("buy_credits", 0)
		var cost_s = item.get("buy_scrap", 0)
		var btn_buy = Button.new()
		btn_buy.text = "🛒 BUY (%d CR + %d SCRAP)" % [cost_c, cost_s]
		btn_buy.pressed.connect(func():
			if inv_mgr.buy_item_from_pit(item["id"]):
				_refresh_items_view()
		)
		action_hbox.add_child(btn_buy)

	elif context == "STASH":
		if item.get("category", "") == "CONSUMABLE":
			var btn_use = Button.new()
			btn_use.text = "🧪 USE"
			btn_use.pressed.connect(func():
				if inv_mgr.use_consumable(item["id"]):
					_refresh_items_view()
			)
			action_hbox.add_child(btn_use)

		var btn_sell = Button.new()
		btn_sell.text = "💰 SELL (+%d CR)" % item.get("sell_credits", 50)
		btn_sell.pressed.connect(func():
			if inv_mgr.sell_item_to_pit(item["id"], "BANQUO_STASH"):
				_refresh_items_view()
		)
		action_hbox.add_child(btn_sell)

		var btn_dismantle = Button.new()
		btn_dismantle.text = "⚙️ SCRAP (+%d)" % item.get("scrap_yield", 10)
		btn_dismantle.pressed.connect(func():
			if inv_mgr.dismantle_for_scrap(item["id"], "BANQUO_STASH"):
				_refresh_items_view()
		)
		action_hbox.add_child(btn_dismantle)

	elif context == "LOCKER":
		var btn_dismantle = Button.new()
		btn_dismantle.text = "⚙️ SCRAP (+%d)" % item.get("scrap_yield", 20)
		btn_dismantle.pressed.connect(func():
			if inv_mgr.dismantle_for_scrap(item["id"], "MACK_LOCKER"):
				_refresh_items_view()
		)
		action_hbox.add_child(btn_dismantle)

	return card
