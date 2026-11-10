extends Node
## Run configuration, screen flow and unlock queries shared by all screens.

signal screen_requested(screen: String)
signal achievement_unlocked(id: String)

const BASE_MOVE_SPEED: float = 105.0
const BASE_MAGNET: float = 42.0
const MAX_INSTRUMENTS: int = 6
const MAX_PASSIVES: int = 6
const WORLD_ZOOM: float = 2.5
const MODES: PackedStringArray = ["hyper", "hurry", "endless"]

## Parameters of the next / current run.
var run_character: String = "froguitar"
var run_stage: String = "forest"
var run_modes: Dictionary = {}
var run_arcana: String = ""
## Result of the last finished run (filled by Run, shown by the results screen).
var last_result: Dictionary = {}
## Set by headless tools: no audio, no UI, virtual music clock.
var headless: bool = false
var debug_enabled: bool = OS.is_debug_build()
## achievement id by "kind:id" for everything that is locked behind an achievement.
var _locked_by: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	rebuild_lock_table()
	var last: Dictionary = Save.data.get("last", {})
	if Content.characters.has(last.get("character", "")):
		run_character = last["character"]
	if Content.stages.has(last.get("stage", "")):
		run_stage = last["stage"]
	apply_display_settings()


func rebuild_lock_table() -> void:
	_locked_by.clear()
	for id: String in Content.achievements:
		var reward: Dictionary = Content.achievements[id].get("reward", {})
		if reward.has("kind"):
			_locked_by["%s:%s" % [reward["kind"], reward["id"]]] = id


func go(screen: String) -> void:
	screen_requested.emit(screen)


## kind: character, instrument, passive, stage, mode, arcana
func is_unlocked(kind: String, id: String) -> bool:
	var key: String = "%s:%s" % [kind, id]
	if not _locked_by.has(key):
		return true
	return Save.has_achievement(_locked_by[key])


func lock_reason(kind: String, id: String) -> String:
	var key: String = "%s:%s" % [kind, id]
	if not _locked_by.has(key):
		return ""
	var ach: Dictionary = Content.achievements[_locked_by[key]]
	if ach.get("secret", false) and not Save.has_achievement(ach["id"]):
		return ach.get("hint", "???")
	return ach.get("desc", "")


func grant(achievement_id: String) -> void:
	if not Content.achievements.has(achievement_id):
		return
	if Save.grant_achievement(achievement_id):
		achievement_unlocked.emit(achievement_id)


func stage_minutes() -> float:
	var minutes: float = float(Save.setting("stage_minutes"))
	if run_modes.get("hurry", false):
		minutes *= 0.5
	return maxf(minutes, 0.5)


func apply_display_settings() -> void:
	if headless or DisplayServer.get_name() == "headless":
		return
	var want_full: bool = bool(Save.setting("fullscreen"))
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not OS.has_feature("web"):
		DisplayServer.window_set_mode(mode)
	get_tree().root.content_scale_factor = clampf(float(Save.setting("ui_scale")), 0.75, 1.5)


# --- input ---------------------------------------------------------------------------------

const DEFAULT_KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"pause": [KEY_ESCAPE, KEY_P],
}
const PAD_BUTTONS: Dictionary = {
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	"pause": JOY_BUTTON_START,
}
const PAD_AXES: Dictionary = {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _setup_input_map() -> void:
	var custom: Dictionary = Save.setting("keys")
	for action: String in DEFAULT_KEYS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.35)
		var keys: Array = DEFAULT_KEYS[action]
		if custom.has(action):
			keys = [int(custom[action])] + keys.slice(1)
		for k: int in keys:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(action, ev)
		var jb: InputEventJoypadButton = InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)
	if not InputMap.has_action("debug_menu"):
		InputMap.add_action("debug_menu")
		var f1: InputEventKey = InputEventKey.new()
		f1.physical_keycode = KEY_F1
		InputMap.action_add_event("debug_menu", f1)


func primary_key(action: String) -> int:
	var custom: Dictionary = Save.setting("keys")
	if custom.has(action):
		return int(custom[action])
	return int(DEFAULT_KEYS[action][0])


func rebind(action: String, keycode: int) -> void:
	var custom: Dictionary = Save.setting("keys")
	custom[action] = keycode
	Save.set_setting("keys", custom)
	_setup_input_map()


func reset_bindings() -> void:
	Save.set_setting("keys", {})
	_setup_input_map()


# --- achievements --------------------------------------------------------------------------

## Reports a gameplay event. Achievements whose condition matches are granted.
func event(type: String, params: Dictionary) -> void:
	for id: String in Content.achievements:
		if Save.has_achievement(id):
			continue
		var cond: Dictionary = Content.achievements[id].get("cond", {})
		if cond.get("on", "") != type:
			continue
		if _cond_met(cond, params):
			grant(id)


func _cond_met(cond: Dictionary, params: Dictionary) -> bool:
	for key: String in cond:
		if key == "on":
			continue
		var want: Variant = cond[key]
		if key.begins_with("min_"):
			if float(params.get(key.substr(4), 0)) < float(want):
				return false
		elif key.begins_with("stat_"):
			if Save.stat(key.substr(5)) < float(want):
				return false
		elif key == "has_instrument":
			var found: bool = false
			for entry: Dictionary in params.get("build", []):
				if entry.get("id", "") == want:
					found = true
			if not found:
				return false
		elif key == "clears":
			if Save.clear_count() < int(want):
				return false
		elif key == "save_gold":
			if Save.gold() < int(want):
				return false
		else:
			var have: Variant = params.get(key)
			if have is float or have is int:
				if not is_equal_approx(float(have), float(want)):
					return false
			elif have != want:
				return false
	return true
