extends Node
## Root of the game: swaps between menu screens and the run.
## Headless tools run through here too:  godot --headless --path . -- --tool=<name> [args]

const SCREENS: Dictionary = {
	"title": "res://scripts/ui/title_screen.gd",
	"settings": "res://scripts/ui/settings_screen.gd",
	"results": "res://scripts/ui/results_screen.gd",
}

var _layer: CanvasLayer
var _current: Node = null


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tool="):
			_run_tool(arg.substr(7))
			return
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var toast: Node = (load("res://scripts/ui/toast_layer.gd") as GDScript).new()
	add_child(toast)
	Game.screen_requested.connect(show_screen)
	show_screen("title")


func _run_tool(tool_name: String) -> void:
	var path: String = "res://scripts/tools/%s.gd" % tool_name
	if not ResourceLoader.exists(path):
		push_error("Unknown tool: " + tool_name)
		get_tree().quit(2)
		return
	Game.headless = true
	Save.ephemeral = true
	Save.load_game()
	add_child((load(path) as GDScript).new())


func show_screen(screen: String) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	if screen == "run":
		var run: Run = Run.new()
		run.ended.connect(func(_result: Dictionary) -> void: show_screen.call_deferred("results"))
		add_child(run)
		_current = run
		return
	var node: Node = (load(SCREENS.get(screen, SCREENS["title"])) as GDScript).new()
	_layer.add_child(node)
	_current = node


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.flush()
