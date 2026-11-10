extends Node
## Persistent progress and settings. One versioned JSON file in user://, with
## migrations from older versions, text export/import and reset.

signal changed

const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.bak.json"
const EXPORT_PATH: String = "user://musicalguys_export.txt"
const SAVE_VERSION: int = 3
const EXPORT_PREFIX: String = "MGSAVE1:"

var data: Dictionary = {}
## When true nothing is written to disk (headless tools and tests).
var ephemeral: bool = false
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_write()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"gold": 0,
		"powerups": {},
		"achievements": {},
		"discovered": {"instruments": {}, "passives": {}, "enemies": {}},
		"kills": {},
		"clears": {},
		"best": {},
		"stats": {
			"runs": 0, "wins": 0, "deaths": 0, "kills": 0, "gold_earned": 0,
			"time_played": 0.0, "max_level": 0, "props_broken": 0, "chests": 0,
			"evolutions": 0, "bosses": 0,
		},
		"arcana_enabled": true,
		"last": {"character": "froguitar", "stage": "forest", "arcana": ""},
		"settings": default_settings(),
	}


func default_settings() -> Dictionary:
	return {
		"vol_master": 0.8, "vol_music": 0.8, "vol_sfx": 0.7,
		"damage_numbers": true, "screen_shake": true, "reduced_flashing": false,
		"colorblind": false, "ui_scale": 1.0, "fullscreen": false,
		"touch_stick": false, "show_fps": false, "stage_minutes": 30,
		"keys": {},
	}


func load_game() -> void:
	data = default_data()
	if ephemeral or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		data = _merge_defaults(migrate(parsed))
	else:
		push_warning("Save: file unreadable, starting fresh (old file kept as backup)")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))


func save_game() -> void:
	_dirty = true
	changed.emit()


## Writes immediately (used before quitting).
func flush() -> void:
	_dirty = false
	_write()


func _write() -> void:
	if ephemeral:
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Upgrades a save dictionary of any older version to SAVE_VERSION.
func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 1))
	if v < 2:
		d = _migrate_1_to_2(d)
	if v < 3:
		d = _migrate_2_to_3(d)
	d["version"] = SAVE_VERSION
	return d


## v1 stored unlocks as a flat list of "kind:id" strings and kills as one number.
## v2 keys everything by achievement id and tracks kills per enemy.
func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var ach: Dictionary = d.get("achievements", {})
	for entry: Variant in d.get("unlocked", []):
		var key: String = str(entry)
		for id: String in Content.achievements:
			var reward: Dictionary = Content.achievements[id].get("reward", {})
			if "%s:%s" % [reward.get("kind", ""), reward.get("id", "")] == key:
				ach[id] = true
	d.erase("unlocked")
	d["achievements"] = ach
	if d.get("kills") is float or d.get("kills") is int:
		var stats: Dictionary = d.get("stats", {})
		stats["kills"] = int(d["kills"])
		d["stats"] = stats
		d["kills"] = {}
	d["version"] = 2
	return d


## v2 had volume settings named "music"/"sfx" and no accessibility options.
func _migrate_2_to_3(d: Dictionary) -> Dictionary:
	var s: Dictionary = d.get("settings", {})
	for pair: Array in [["music", "vol_music"], ["sfx", "vol_sfx"], ["master", "vol_master"]]:
		if s.has(pair[0]):
			s[pair[1]] = s[pair[0]]
			s.erase(pair[0])
	d["settings"] = s
	d["version"] = 3
	return d


func _merge_defaults(d: Dictionary) -> Dictionary:
	var out: Dictionary = default_data()
	_deep_merge(out, d)
	return out


func _deep_merge(base: Dictionary, over: Dictionary) -> void:
	for k: Variant in over:
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary:
			_deep_merge(base[k], over[k])
		else:
			base[k] = over[k]


# --- export / import / reset ---------------------------------------------------------------

func export_string() -> String:
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(data))


func export_to_file() -> String:
	var f: FileAccess = FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(export_string())
		f.close()
	return ProjectSettings.globalize_path(EXPORT_PATH)


## Accepts an exported string or raw save JSON. Returns false and leaves the save untouched
## when the text is not a valid save.
func import_string(text: String) -> bool:
	text = text.strip_edges()
	if text.begins_with(EXPORT_PREFIX):
		text = Marshalls.base64_to_utf8(text.substr(EXPORT_PREFIX.length()))
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("version"):
		return false
	data = _merge_defaults(migrate(parsed))
	save_game()
	return true


func import_from_file() -> bool:
	if not FileAccess.file_exists(EXPORT_PATH):
		return false
	return import_string(FileAccess.get_file_as_string(EXPORT_PATH))


func reset_progress(keep_settings: bool = true) -> void:
	var settings: Dictionary = data.get("settings", default_settings())
	data = default_data()
	if keep_settings:
		data["settings"] = settings
	save_game()


# --- accessors -----------------------------------------------------------------------------

func setting(key: String) -> Variant:
	return data["settings"].get(key, default_settings().get(key))


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_game()


func gold() -> int:
	return int(data["gold"])


func add_gold(amount: int) -> void:
	data["gold"] = int(data["gold"]) + amount
	if amount > 0:
		data["stats"]["gold_earned"] = int(data["stats"]["gold_earned"]) + amount
	save_game()


func powerup_level(id: String) -> int:
	return int(data["powerups"].get(id, 0))


func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)


func grant_achievement(id: String) -> bool:
	if data["achievements"].has(id):
		return false
	data["achievements"][id] = true
	save_game()
	return true


func add_stat(key: String, amount: float) -> void:
	data["stats"][key] = float(data["stats"].get(key, 0)) + amount


func max_stat(key: String, value: float) -> void:
	data["stats"][key] = maxf(float(data["stats"].get(key, 0)), value)


func stat(key: String) -> float:
	return float(data["stats"].get(key, 0))


func discover(kind: String, id: String) -> void:
	if not data["discovered"].has(kind):
		data["discovered"][kind] = {}
	if not data["discovered"][kind].has(id):
		data["discovered"][kind][id] = true
		_dirty = true


func is_discovered(kind: String, id: String) -> bool:
	return data["discovered"].get(kind, {}).has(id)


func add_kills(enemy_id: String, n: int) -> void:
	data["kills"][enemy_id] = int(data["kills"].get(enemy_id, 0)) + n


func kills_of(enemy_id: String) -> int:
	return int(data["kills"].get(enemy_id, 0))


func mark_clear(stage_id: String, mode: String) -> void:
	if not data["clears"].has(stage_id):
		data["clears"][stage_id] = {}
	data["clears"][stage_id][mode] = true


func has_clear(stage_id: String, mode: String = "normal") -> bool:
	return data["clears"].get(stage_id, {}).has(mode)


func clear_count() -> int:
	return (data["clears"] as Dictionary).size()
