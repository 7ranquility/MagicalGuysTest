class_name WorldDecor
extends Node2D
## Static world dressing: stage obstacles and the walls of bounded stages.

var run: Run
var _src: Rect2
var _has_sprite: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite: String = run.stage.get("obstacles", {}).get("sprite", "")
	_has_sprite = sprite != "" and Atlas.has(sprite)
	if _has_sprite:
		_src = Atlas.rect(sprite)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view: Rect2 = run.view_rect.grow(40.0)
	if run.bounds_y > 0.0:
		var wall: Color = Color.html(run.stage.get("wall_color", "#1c1420"))
		draw_rect(Rect2(view.position.x, -run.bounds_y - 600.0, view.size.x, 600.0), wall)
		draw_rect(Rect2(view.position.x, run.bounds_y, view.size.x, 600.0), wall)
		draw_rect(Rect2(view.position.x, -run.bounds_y - 6.0, view.size.x, 6.0), wall.lightened(0.25))
		draw_rect(Rect2(view.position.x, run.bounds_y, view.size.x, 6.0), wall.lightened(0.25))
	if not _has_sprite:
		return
	var c: float = Run.OBSTACLE_CELL
	for cy: int in range(floori(view.position.y / c), floori(view.end.y / c) + 1):
		for cx: int in range(floori(view.position.x / c), floori(view.end.x / c) + 1):
			var o: Vector3 = run.obstacle_at(cx, cy)
			if o.z > 0.0:
				draw_circle(Vector2(o.x, o.y + 14.0), o.z * 1.1, Color(0, 0, 0, 0.22))
				draw_texture_rect_region(Atlas.tex, Rect2(o.x - 24.0, o.y - 30.0, 48.0, 48.0), _src)
