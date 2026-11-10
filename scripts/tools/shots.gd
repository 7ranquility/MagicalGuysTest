extends Node
## Dev tool: plays a short bot run with rendering on and saves screenshots to user://shots.
## xvfb-run godot --path . --rendering-driver opengl3 -- --tool=shots

var _run: Run
var _t: float = 0.0
var _shot: int = 0
var _marks: PackedFloat32Array = [3.0, 25.0, 60.0]


func _ready() -> void:
	Game.headless = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_run = Run.new()
	add_child(_run)
	_run.player.use_external_move = true
	_run.gain_xp(400.0)


func _process(delta: float) -> void:
	_t += delta
	if _run.state == Run.State.PLAYING:
		var a: float = _t * 0.7
		_run.player.external_move = Vector2(cos(a), sin(a))
	if _shot < _marks.size() and _t >= _marks[_shot]:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/shot%d.png" % _shot)
		_shot += 1
		if _run.state == Run.State.LEVEL_UP:
			_run.auto_pick = func(_o: Array) -> int: return 0
			while _run.state == Run.State.LEVEL_UP:
				_run.choose_option(0)
				if _run.pending_levels > 0:
					_run._open_level_up()
		if _shot >= _marks.size():
			print("SHOTS ", ProjectSettings.globalize_path("user://shots"))
			get_tree().quit()
