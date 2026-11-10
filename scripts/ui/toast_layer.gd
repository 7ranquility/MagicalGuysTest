extends CanvasLayer
## Small pop-up messages for unlocked achievements.

var _box: VBoxContainer


func _ready() -> void:
	layer = 50
	_box = UiKit.vbox(6)
	_box.theme = UiKit.theme()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_box.offset_left = -560
	_box.offset_top = -300
	_box.offset_right = -20
	_box.offset_bottom = -20
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	Game.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(id: String) -> void:
	var ach: Dictionary = Content.achievements.get(id, {})
	var card: PanelContainer = UiKit.card(Color(0, 0, 0, 0.8))
	card.add_child(UiKit.label("Unlocked: " + str(ach.get("name", id)), UiKit.SIZE_SMALL, UiKit.C_ACCENT))
	_box.add_child(card)
	get_tree().create_timer(4.0).timeout.connect(card.queue_free)
