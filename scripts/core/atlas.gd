class_name Atlas
extends RefCounted
## Access to the generated sprite atlas (see tools/gen_art.py).

const TEX_PATH: String = "res://assets/generated/atlas.png"
const MAP_PATH: String = "res://assets/generated/atlas.json"

static var tex: Texture2D = null
static var regions: Dictionary = {}
static var _icons: Dictionary = {}


static func ensure() -> void:
	if tex != null:
		return
	tex = load(TEX_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if parsed is Dictionary:
		for key: String in parsed:
			var a: Array = parsed[key]
			regions[key] = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func has(sprite: String) -> bool:
	ensure()
	return regions.has(sprite)


static func rect(sprite: String) -> Rect2:
	ensure()
	if regions.has(sprite):
		return regions[sprite]
	return regions.get("ui_unknown", Rect2(0, 0, 32, 32))


## An AtlasTexture for UI controls (cached).
static func icon(sprite: String) -> AtlasTexture:
	ensure()
	if _icons.has(sprite):
		return _icons[sprite]
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = tex
	at.region = rect(sprite)
	_icons[sprite] = at
	return at
