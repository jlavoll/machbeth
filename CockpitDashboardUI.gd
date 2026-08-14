extends CanvasLayer

# ==============================================================================
# COCKPIT DASHBOARD UI & WINDSHIELD INTERFACE (CockpitDashboardUI.gd)
# ==============================================================================
# Renders the first-person combat dashboard overlay: Windshield Viewport,
# Gatling/EMP Toggle buttons, ICE-breaker Keypad, Nitrous Booster Switch,
# Overclock Lever, LED ATB Recharge Bars, and Target Status Readouts.

# Signals emitted when player interacts with tactile dashboard modules
signal gatling_attack_triggered
signal ice_breaker_hack_triggered(hack_type: String)
signal nitrous_boost_triggered
signal overclock_lever_engaged

# References to dynamically created UI components
var cockpit_overlay_panel: Control
var windshield_viewport_frame: ReferenceRect
var enemy_target_label: Label
var enemy_hull_progress_bar: ProgressBar

# System ATB LED Gauge Bars
var gatling_atb_gauge: ProgressBar
var netrunner_atb_gauge: ProgressBar
var nitrous_atb_gauge: ProgressBar
var overclock_atb_gauge: ProgressBar

# Tactical Action Buttons
var gatling_button: Button
var ice_breaker_button: Button
var nitrous_button: Button
var overclock_button: Button

# Preloaded Cyberpunk Typography Font
var orbitron_font: Font = preload("res://fonts/Orbitron/Orbitron-VariableFont_wght.ttf")

# System ATB Charge States (0.0 to 100.0)

var system_atb_charges: Dictionary = {
	"gatling": 100.0,
	"ice_breaker": 100.0,
	"nitrous": 100.0,
	"overclock": 100.0
}

# Unique Recharge Speeds (% per second)
# Light/Fast: Gatling (recharges in ~2.5s)
# Medium: ICE-Breaker Hack (recharges in ~5.0s)
# Heavy: Nitrous Evasion Boost (recharges in ~8.0s)
# Super/Limit Break: Neural Overclock (recharges in ~14.0s)
var system_recharge_rates: Dictionary = {
	"gatling": 40.0,
	"ice_breaker": 20.0,
	"nitrous": 12.5,
	"overclock": 7.14
}

# ==============================================================================
# UI INITIALIZATION & LAYOUT BUILDER
# ==============================================================================

func _ready() -> void:
	visible = false
	_construct_cockpit_dashboard_layout()

# Per-frame ATB gauge filling loop
func _process(delta: float) -> void:
	if not visible:
		return

	# Recharge Gatling ATB
	if system_atb_charges["gatling"] < 100.0:
		system_atb_charges["gatling"] = min(100.0, system_atb_charges["gatling"] + system_recharge_rates["gatling"] * delta)
		gatling_atb_gauge.value = system_atb_charges["gatling"]
		gatling_button.disabled = system_atb_charges["gatling"] < 100.0

	# Recharge Netrunner ICE-Breaker ATB
	if system_atb_charges["ice_breaker"] < 100.0:
		system_atb_charges["ice_breaker"] = min(100.0, system_atb_charges["ice_breaker"] + system_recharge_rates["ice_breaker"] * delta)
		netrunner_atb_gauge.value = system_atb_charges["ice_breaker"]
		ice_breaker_button.disabled = system_atb_charges["ice_breaker"] < 100.0

	# Recharge Engine Nitrous ATB
	if system_atb_charges["nitrous"] < 100.0:
		system_atb_charges["nitrous"] = min(100.0, system_atb_charges["nitrous"] + system_recharge_rates["nitrous"] * delta)
		nitrous_atb_gauge.value = system_atb_charges["nitrous"]
		nitrous_button.disabled = system_atb_charges["nitrous"] < 100.0

	# Recharge Neural Overclock ATB
	if system_atb_charges["overclock"] < 100.0:
		system_atb_charges["overclock"] = min(100.0, system_atb_charges["overclock"] + system_recharge_rates["overclock"] * delta)
		overclock_atb_gauge.value = system_atb_charges["overclock"]
		overclock_button.disabled = system_atb_charges["overclock"] < 100.0

func _construct_cockpit_dashboard_layout() -> void:
	# Main Root Overlay Control
	cockpit_overlay_panel = Control.new()
	cockpit_overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cockpit_overlay_panel)

	# --------------------------------------------------------------------------
	# 1. WINDSHIELD VIEWPORT FRAME (TOP 60% OF SCREEN)
	# --------------------------------------------------------------------------
	windshield_viewport_frame = ReferenceRect.new()
	windshield_viewport_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	windshield_viewport_frame.anchor_bottom = 0.65
	windshield_viewport_frame.border_color = Color(0.0, 0.85, 1.0, 0.8) # Neon Cyan
	windshield_viewport_frame.border_width = 3.0
	cockpit_overlay_panel.add_child(windshield_viewport_frame)

	# Windshield Target Info Header
	enemy_target_label = Label.new()
	enemy_target_label.position = Vector2(20, 20)
	enemy_target_label.text = "TARGET: NO HOSTILE DETECTED"
	enemy_target_label.add_theme_font_override("font", orbitron_font)
	enemy_target_label.add_theme_font_size_override("font_size", 18)
	enemy_target_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	windshield_viewport_frame.add_child(enemy_target_label)

	# Target Hull Health Bar
	enemy_hull_progress_bar = ProgressBar.new()
	enemy_hull_progress_bar.position = Vector2(20, 50)
	enemy_hull_progress_bar.size = Vector2(300, 20)
	enemy_hull_progress_bar.max_value = 100.0
	enemy_hull_progress_bar.value = 100.0
	windshield_viewport_frame.add_child(enemy_hull_progress_bar)

	# --------------------------------------------------------------------------
	# 2. SYNTH-DECK DASHBOARD PANEL (BOTTOM 35% OF SCREEN)
	# --------------------------------------------------------------------------
	var dash_panel = ColorRect.new()
	dash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_panel.anchor_top = 0.65
	dash_panel.color = Color(0.05, 0.04, 0.08, 0.95) # Dark Synth-Deck Charcoal
	cockpit_overlay_panel.add_child(dash_panel)

	# Grid Container for Tactile Buttons & Gauges
	var grid = HBoxContainer.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 30
	grid.offset_top = 20
	grid.offset_right = -30
	grid.offset_bottom = -20
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 25)
	dash_panel.add_child(grid)

	# --- MODULE 1: ORDNANCE ARRAY (Gatling/EMP) ---
	var m1 = _create_dashboard_module("ORDNANCE ARRAY", "[1] Gatling Cannon", Color(1, 0, 0.2))
	gatling_button = m1["button"]
	gatling_atb_gauge = m1["gauge"]
	gatling_button.pressed.connect(func():
		if consume_atb_charge("gatling"):
			gatling_attack_triggered.emit()
	)
	grid.add_child(m1["container"])

	# --- MODULE 2: NETRUNNER DECK (ICE-Breaker Keypad) ---
	var m2 = _create_dashboard_module("NETRUNNER DECK", "[2] ICE-Breaker Hack", Color(0, 0.85, 1))
	ice_breaker_button = m2["button"]
	netrunner_atb_gauge = m2["gauge"]
	ice_breaker_button.pressed.connect(func():
		if consume_atb_charge("ice_breaker"):
			ice_breaker_hack_triggered.emit("EMP_OVERLOAD")
	)
	grid.add_child(m2["container"])

	# --- MODULE 3: ENGINE CORE (Nitrous Booster) ---
	var m3 = _create_dashboard_module("ENGINE CORE", "[3] Nitrous Boost", Color(1, 0.8, 0))
	nitrous_button = m3["button"]
	nitrous_atb_gauge = m3["gauge"]
	nitrous_button.pressed.connect(func():
		if consume_atb_charge("nitrous"):
			nitrous_boost_triggered.emit()
	)
	grid.add_child(m3["container"])

	# --- MODULE 4: OVERCLOCK LEVER (Limit Break) ---
	var m4 = _create_dashboard_module("OVERCLOCK LEVER", "[4] Neural Overclock", Color(1, 0, 0.8))
	overclock_button = m4["button"]
	overclock_atb_gauge = m4["gauge"]
	overclock_button.pressed.connect(func():
		if consume_atb_charge("overclock"):
			overclock_lever_engaged.emit()
	)
	grid.add_child(m4["container"])

# ==============================================================================
# KEYBOARD SHORTCUT LISTENER (HOTKEYS 1, 2, 3, 4)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				if consume_atb_charge("gatling"):
					print("[HOTKEY 1] Fired Gatling Cannon via key 1!")
					gatling_attack_triggered.emit()
			KEY_2:
				if consume_atb_charge("ice_breaker"):
					print("[HOTKEY 2] Fired ICE-Breaker Hack via key 2!")
					ice_breaker_hack_triggered.emit("EMP_OVERLOAD")
			KEY_3:
				if consume_atb_charge("nitrous"):
					print("[HOTKEY 3] Engaged Nitrous Boost via key 3!")
					nitrous_boost_triggered.emit()
			KEY_4:
				if consume_atb_charge("overclock"):
					print("[HOTKEY 4] Engaged Neural Overclock via key 4!")
					overclock_lever_engaged.emit()


# Helper to manufacture tactile UI module boxes with LED gauges
func _create_dashboard_module(header: String, btn_title: String, led_color: Color) -> Dictionary:
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 140)

	var label = Label.new()
	label.text = header
	label.add_theme_font_override("font", orbitron_font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", led_color)
	box.add_child(label)

	var gauge = ProgressBar.new()
	gauge.custom_minimum_size = Vector2(200, 15)
	gauge.value = 100.0
	box.add_child(gauge)

	var btn = Button.new()
	btn.text = btn_title
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_override("font", orbitron_font)
	btn.add_theme_font_size_override("font_size", 13)
	box.add_child(btn)

	return {"container": box, "button": btn, "gauge": gauge}

# Depletes a system's ATB gauge to 0 upon firing
func consume_atb_charge(system_key: String) -> bool:
	if system_atb_charges.has(system_key) and system_atb_charges[system_key] >= 100.0:
		system_atb_charges[system_key] = 0.0
		match system_key:
			"gatling":
				gatling_atb_gauge.value = 0.0
				gatling_button.disabled = true
			"ice_breaker":
				netrunner_atb_gauge.value = 0.0
				ice_breaker_button.disabled = true
			"nitrous":
				nitrous_atb_gauge.value = 0.0
				nitrous_button.disabled = true
			"overclock":
				overclock_atb_gauge.value = 0.0
				overclock_button.disabled = true
		return true
	return false

# Reset all ATB gauges to full when initiating a new battle
func reset_all_atb_gauges() -> void:
	for key in system_atb_charges.keys():
		system_atb_charges[key] = 100.0
	if gatling_atb_gauge: gatling_atb_gauge.value = 100.0
	if netrunner_atb_gauge: netrunner_atb_gauge.value = 100.0
	if nitrous_atb_gauge: nitrous_atb_gauge.value = 100.0
	if overclock_atb_gauge: overclock_atb_gauge.value = 100.0
	if gatling_button: gatling_button.disabled = false
	if ice_breaker_button: ice_breaker_button.disabled = false
	if nitrous_button: nitrous_button.disabled = false
	if overclock_button: overclock_button.disabled = false

# ==============================================================================
# EXTERNAL UPDATE FUNCTIONS
# ==============================================================================

func set_target_hostile_info(hostile_name: String, current_hp: float, max_hp: float) -> void:
	enemy_target_label.text = "TARGET: " + hostile_name.to_upper()
	enemy_hull_progress_bar.max_value = max_hp
	enemy_hull_progress_bar.value = current_hp

func display_cockpit_hud(show_hud: bool) -> void:
	visible = show_hud
	if show_hud:
		reset_all_atb_gauges()
