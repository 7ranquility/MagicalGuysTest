class_name TouchStick
extends Control
## Floating virtual stick for touch screens. Touch anywhere, drag to move.

const RADIUS: float = 110.0

var player: Player
var _finger: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _finger < 0:
			_finger = touch.index
			_origin = touch.position
			_knob = Vector2.ZERO
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			_knob = Vector2.ZERO
			if is_instance_valid(player):
				player.external_move = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
		_knob = ((event as InputEventScreenDrag).position - _origin).limit_length(RADIUS)
		if is_instance_valid(player):
			var v: Vector2 = _knob / RADIUS
			player.external_move = v if v.length() > 0.15 else Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	if _finger < 0:
		return
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var o: Vector2 = inv * _origin
	draw_circle(o, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(o, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(o + _knob, 42.0, Color(1, 1, 1, 0.45))
