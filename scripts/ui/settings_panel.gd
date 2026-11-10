class_name SettingsPanel
extends VBoxContainer
## Settings controls shared by the title settings screen and the pause menu.

const TOGGLES: Array = [
	["damage_numbers", "Damage numbers"], ["screen_shake", "Screen shake"],
	["reduced_flashing", "Reduced flashing"], ["colorblind", "Colorblind-safe colours"],
	["fullscreen", "Fullscreen"], ["touch_stick", "Touch stick"], ["show_fps", "Show FPS"],
]
const ACTIONS: Array = [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"],
	["move_right", "Move right"], ["pause", "Pause"],
]
const LENGTHS: PackedInt32Array = [30, 20, 10, 5, 2]

var _waiting_action: String = ""
var _key_buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiKit.label("SETTINGS", UiKit.SIZE_HEAD, UiKit.C_ACCENT, true))
	var cols: HBoxContainer = UiKit.hbox(48)
	add_child(cols)
	var left: VBoxContainer = UiKit.vbox(10)
	var right: VBoxContainer = UiKit.vbox(10)
	cols.add_child(left)
	cols.add_child(right)

	left.add_child(UiKit.label("Audio", UiKit.SIZE_BODY, UiKit.C_DIM, true))
	for pair: Array in [["vol_master", "Master"], ["vol_music", "Music"], ["vol_sfx", "Sound effects"]]:
		left.add_child(_slider_row(pair[1], pair[0], 0.0, 1.0, 0.05, true))
	left.add_child(UiKit.label("Display", UiKit.SIZE_BODY, UiKit.C_DIM, true))
	left.add_child(_slider_row("UI scale", "ui_scale", 0.8, 1.4, 0.1, false))
	for t: Array in TOGGLES:
		left.add_child(_toggle_row(t[1], t[0]))

	right.add_child(UiKit.label("Controls (keyboard)", UiKit.SIZE_BODY, UiKit.C_DIM, true))
	for a: Array in ACTIONS:
		var row: HBoxContainer = UiKit.hbox(12)
		var l: Label = UiKit.label(a[1], 22)
		l.custom_minimum_size.x = 200
		row.add_child(l)
		var action: String = a[0]
		var b: Button = UiKit.button(_key_name(action), func() -> void: _begin_rebind(action), Vector2(220, 48))
		_key_buttons[action] = b
		row.add_child(b)
		right.add_child(row)
	right.add_child(UiKit.button("Reset controls", func() -> void:
		Game.reset_bindings()
		_refresh_keys(), Vector2(432, 48)))
	right.add_child(UiKit.label("Gamepad: left stick or d-pad to move,\nStart to pause, A to confirm, B to go back.", UiKit.SIZE_SMALL, UiKit.C_DIM))
	right.add_child(UiKit.label("Stage length", UiKit.SIZE_BODY, UiKit.C_DIM, true))
	var len_row: HBoxContainer = UiKit.hbox(8)
	var current: int = int(Save.setting("stage_minutes"))
	var group: ButtonGroup = ButtonGroup.new()
	for m: int in LENGTHS:
		var lb: Button = Button.new()
		lb.text = "%d min" % m
		lb.toggle_mode = true
		lb.button_group = group
		lb.button_pressed = m == current
		lb.custom_minimum_size = Vector2(100, 48)
		lb.add_theme_font_size_override("font_size", 20)
		lb.pressed.connect(func() -> void: Save.set_setting("stage_minutes", m))
		len_row.add_child(lb)
	right.add_child(len_row)
	right.add_child(UiKit.label("30 minutes is the intended length. Shorter\nruns compress the same timeline.", UiKit.SIZE_SMALL, UiKit.C_DIM))


func _slider_row(text: String, key: String, lo: float, hi: float, step: float, audio: bool) -> Control:
	var row: HBoxContainer = UiKit.hbox(12)
	var l: Label = UiKit.label(text, 22)
	l.custom_minimum_size.x = 240
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Save.setting(key))
	s.custom_minimum_size = Vector2(300, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val: Label = UiKit.label("%d%%" % int(round(s.value * 100.0)), 20, UiKit.C_DIM)
	val.custom_minimum_size.x = 70
	s.value_changed.connect(func(v: float) -> void:
		Save.set_setting(key, v)
		val.text = "%d%%" % int(round(v * 100.0))
		if audio:
			Audio.apply_volumes()
			Audio.play("tick", -8.0)
		else:
			Game.apply_display_settings())
	row.add_child(s)
	row.add_child(val)
	return row


func _toggle_row(text: String, key: String) -> Control:
	var cb: CheckButton = CheckButton.new()
	cb.text = text
	cb.button_pressed = bool(Save.setting(key))
	cb.custom_minimum_size = Vector2(620, 44)
	cb.add_theme_font_size_override("font_size", 22)
	cb.toggled.connect(func(on: bool) -> void:
		Save.set_setting(key, on)
		Audio.play("click", -8.0)
		if key == "fullscreen":
			Game.apply_display_settings())
	return cb


func _key_name(action: String) -> String:
	return OS.get_keycode_string(Game.primary_key(action))


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = _key_name(action)


func _begin_rebind(action: String) -> void:
	_waiting_action = action
	(_key_buttons[action] as Button).text = "press a key..."


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	var key: InputEventKey = event
	get_viewport().set_input_as_handled()
	if key.physical_keycode != KEY_ESCAPE or _waiting_action == "pause":
		Game.rebind(_waiting_action, key.physical_keycode)
	_waiting_action = ""
	_refresh_keys()
