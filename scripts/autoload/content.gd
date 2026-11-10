extends Node
## Content database. Loads every JSON file in res://data and exposes it as dictionaries.
## All gameplay content (instruments, passives, enemies, stages, music...) lives in those
## files; code only implements the primitives they reference.

const DATA_DIR: String = "res://data/"
const FILES: PackedStringArray = [
	"instruments", "passives", "enemies", "stages", "characters",
	"shop", "achievements", "arcana", "music",
]

var instruments: Dictionary = {}
var passives: Dictionary = {}
var enemies: Dictionary = {}
var stages: Dictionary = {}
var characters: Dictionary = {}
var shop: Dictionary = {}
var achievements: Dictionary = {}
var arcana: Dictionary = {}
var music: Dictionary = {}

## Ordered id lists (JSON objects keep insertion order in Godot).
var instrument_ids: Array = []
var base_instrument_ids: Array = []
var passive_ids: Array = []
var enemy_ids: Array = []
var stage_ids: Array = []
var character_ids: Array = []

var load_errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	load_errors.clear()
	for f: String in FILES:
		set(f, _load_json(f))
	instrument_ids = instruments.keys()
	base_instrument_ids = []
	for id: String in instrument_ids:
		var d: Dictionary = instruments[id]
		d["id"] = id
		if not d.has("from"):
			base_instrument_ids.append(id)
	passive_ids = passives.keys()
	for id: String in passive_ids:
		passives[id]["id"] = id
	enemy_ids = enemies.keys()
	for id: String in enemy_ids:
		enemies[id]["id"] = id
	stage_ids = stages.keys()
	for id: String in stage_ids:
		stages[id]["id"] = id
	character_ids = characters.keys()
	for id: String in character_ids:
		characters[id]["id"] = id
	for id: String in achievements:
		achievements[id]["id"] = id
	for id: String in arcana:
		arcana[id]["id"] = id
	for id: String in shop:
		shop[id]["id"] = id
	for e: String in validate():
		push_warning("Content: " + e)


func _load_json(file: String) -> Dictionary:
	var path: String = DATA_DIR + file + ".json"
	if not FileAccess.file_exists(path):
		load_errors.append("missing " + path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		load_errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		load_errors.append(path + ": top level must be an object")
		return {}
	return json.data


## Returns the evolved/union instrument ids that list `base_id` in their "from".
func evolutions_of(base_id: String) -> Array:
	var out: Array = []
	for id: String in instrument_ids:
		var d: Dictionary = instruments[id]
		if d.has("from") and (d["from"] as Array).has(base_id):
			out.append(id)
	return out


func instrument_max_level(id: String) -> int:
	var d: Dictionary = instruments.get(id, {})
	return 1 + (d.get("levels", []) as Array).size()


func passive_max_level(id: String) -> int:
	return int(passives.get(id, {}).get("max", 5))


## Cross-reference checks. Returns human readable problems (empty when clean).
func validate() -> PackedStringArray:
	var out: PackedStringArray = load_errors.duplicate()
	for id: String in instruments:
		var d: Dictionary = instruments[id]
		for key: String in ["name", "pattern", "base"]:
			if not d.has(key):
				out.append("instrument %s lacks '%s'" % [id, key])
		if d.has("evolves_with") and not passives.has(d["evolves_with"]):
			out.append("instrument %s evolves_with unknown passive %s" % [id, d["evolves_with"]])
		if d.has("from"):
			for src: String in d["from"]:
				if not instruments.has(src):
					out.append("instrument %s built from unknown %s" % [id, src])
		elif (d.get("levels", []) as Array).size() != 7:
			out.append("instrument %s needs 7 level-up entries (8 levels)" % id)
		for layer: String in d.get("layers", []):
			if not music.is_empty() and not (music.get("instrument_layers", {}) as Dictionary).has(layer):
				out.append("instrument %s uses unknown music layer %s" % [id, layer])
	for id: String in stages:
		var st: Dictionary = stages[id]
		for wave: Dictionary in st.get("waves", []):
			for en: String in wave.get("enemies", []):
				if not enemies.has(en):
					out.append("stage %s wave uses unknown enemy %s" % [id, en])
		for ev: Dictionary in st.get("events", []):
			if ev.has("enemy") and not enemies.has(ev["enemy"]):
				out.append("stage %s event uses unknown enemy %s" % [id, ev["enemy"]])
		if not music.is_empty() and not (music.get("tracks", {}) as Dictionary).has(st.get("track", "")):
			out.append("stage %s has unknown track %s" % [id, st.get("track", "")])
	for id: String in characters:
		var ch: Dictionary = characters[id]
		if not instruments.has(ch.get("instrument", "")):
			out.append("character %s starts with unknown instrument %s" % [id, ch.get("instrument", "")])
	for id: String in enemies:
		var en: Dictionary = enemies[id]
		if en.has("split_into") and not enemies.has(en["split_into"]):
			out.append("enemy %s splits into unknown %s" % [id, en["split_into"]])
	return out
