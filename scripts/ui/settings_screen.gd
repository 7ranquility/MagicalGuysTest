extends Control
## Settings reached from the title screen.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: Control = UiKit.screen_root()
	add_child(root)
	var panel: PanelContainer = UiKit.panel()
	var v: VBoxContainer = UiKit.vbox(12)
	panel.add_child(v)
	v.add_child(SettingsPanel.new())
	var back: Button = UiKit.button("Back", func() -> void: Game.go("title"))
	v.add_child(back)
	root.add_child(UiKit.center(panel))
	back.grab_focus.call_deferred()
