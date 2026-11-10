extends Control
## Title screen (playtest build): play, settings, quit.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: Control = UiKit.screen_root()
	add_child(root)
	var v: VBoxContainer = UiKit.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = UiKit.label("MUSICAL GUYS", UiKit.SIZE_TITLE, UiKit.C_ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub: Label = UiKit.label("Playtest build  ·  Froguitar in Lo-Fi Grove", UiKit.SIZE_BODY, UiKit.C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UiKit.spacer(Vector2(0, 30), false))
	var play: Button = UiKit.button("Play", func() -> void: Game.go("run"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(play)
	var settings: Button = UiKit.button("Settings", func() -> void: Game.go("settings"))
	settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(settings)
	var quit: Button = UiKit.button("Quit", func() -> void:
		Save.flush()
		get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(quit)
	v.add_child(UiKit.spacer(Vector2(0, 20), false))
	var help: Label = UiKit.label("Move: WASD / arrows / left stick     Pause: Esc     Debug: F1\nInstruments fire on their own, on the beat.", UiKit.SIZE_SMALL, UiKit.C_DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(help)
	root.add_child(UiKit.center(v))
	play.grab_focus.call_deferred()
