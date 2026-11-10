class_name PickupManager
extends Node2D
## XP gems and item pickups in pooled storage. Shapes differ per kind so they stay
## readable without relying on colour.

enum Kind { GEM, COIN, COINBAG, FOOD, MAGNET, BOMB, FREEZE, CHEST, RELIC }

const CAP: int = 2400
const SPRITES: PackedStringArray = ["pk_gem1", "pk_coin", "pk_coinbag", "pk_food", "pk_magnet", "pk_bomb", "pk_freeze", "pk_chest", "pk_relic"]

var run: Run
var n: int = 0
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var value: PackedFloat32Array = PackedFloat32Array()
var vel: PackedFloat32Array = PackedFloat32Array()
var kind: PackedInt32Array = PackedInt32Array()
var state: PackedByteArray = PackedByteArray()
var gem_count: int = 0

var _tex: Texture2D
var _src: Array[Rect2] = []
var _gem2: Rect2
var _gem3: Rect2
var _gem_cols: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE]
var _overflow: int = -1


func _ready() -> void:
	for arr: PackedFloat32Array in [x, y, value, vel]:
		arr.resize(CAP)
	kind.resize(CAP)
	state.resize(CAP)
	Atlas.ensure()
	_tex = Atlas.tex
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for s: String in SPRITES:
		_src.append(Atlas.rect(s))
	_gem2 = Atlas.rect("pk_gem2")
	_gem3 = Atlas.rect("pk_gem3")
	if bool(Save.setting("colorblind")):
		_gem_cols = [Color(0.55, 0.75, 1.0), Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 1.0)]


func add(k: int, px: float, py: float, val: float = 1.0) -> void:
	if n >= CAP:
		if k == Kind.GEM:
			if _overflow < 0 or _overflow >= n or kind[_overflow] != Kind.GEM:
				_overflow = randi() % n
				while kind[_overflow] != Kind.GEM:
					_overflow = (_overflow + 1) % n
			value[_overflow] += val
		return
	x[n] = px
	y[n] = py
	value[n] = val
	vel[n] = 0.0
	kind[n] = k
	state[n] = 0
	if k == Kind.GEM:
		gem_count += 1
	n += 1


func clear_all() -> void:
	n = 0
	gem_count = 0


## Pulls every gem on the map to the player.
func vacuum() -> void:
	for i: int in n:
		if kind[i] == Kind.GEM or kind[i] == Kind.COIN:
			state[i] = 1


func update(dt: float) -> void:
	var p: Vector2 = run.player.position
	var plx: float = p.x
	var ply: float = p.y
	var mag: float = run.player.magnet_radius
	var mag2: float = mag * mag
	var grab2: float = 14.0 * 14.0
	var i: int = 0
	while i < n:
		var dx: float = plx - x[i]
		var dy: float = ply - y[i]
		var d2: float = dx * dx + dy * dy
		var k: int = kind[i]
		if state[i] == 0:
			if d2 < mag2 and k != Kind.CHEST and k != Kind.RELIC:
				state[i] = 1
				vel[i] = -90.0
			elif d2 < grab2 * 1.6:
				state[i] = 1
		if state[i] == 1:
			var v: float = vel[i] + 900.0 * dt
			vel[i] = v
			var d: float = sqrt(d2) + 0.001
			x[i] += dx / d * v * dt
			y[i] += dy / d * v * dt
			if d2 < grab2 or (v > 0.0 and d < v * dt * 1.5):
				var val: float = value[i]
				var cx: float = x[i]
				var cy: float = y[i]
				n -= 1
				if k == Kind.GEM:
					gem_count -= 1
				x[i] = x[n]
				y[i] = y[n]
				value[i] = value[n]
				vel[i] = vel[n]
				kind[i] = kind[n]
				state[i] = state[n]
				run.on_pickup(k, val, cx, cy)
				continue
		i += 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var view: Rect2 = run.view_rect.grow(20.0)
	var x0: float = view.position.x
	var x1: float = view.end.x
	var y0: float = view.position.y
	var y1: float = view.end.y
	var bob: float = sin(run.time * 5.0) * 1.5
	for i: int in n:
		var px: float = x[i]
		var py: float = y[i]
		if px < x0 or px > x1 or py < y0 or py > y1:
			continue
		var k: int = kind[i]
		if k == Kind.GEM:
			var v: float = value[i]
			if v < 3.0:
				draw_texture_rect_region(_tex, Rect2(px - 5.0, py - 5.0, 10.0, 10.0), _src[0], _gem_cols[0])
			elif v < 10.0:
				draw_texture_rect_region(_tex, Rect2(px - 6.0, py - 6.0, 12.0, 12.0), _gem2, _gem_cols[1])
			else:
				draw_texture_rect_region(_tex, Rect2(px - 7.0, py - 7.0, 14.0, 14.0), _gem3, _gem_cols[2])
		elif k == Kind.CHEST:
			draw_texture_rect_region(_tex, Rect2(px - 14.0, py - 14.0 + bob, 28.0, 28.0), _src[k])
		else:
			draw_texture_rect_region(_tex, Rect2(px - 8.0, py - 8.0 + bob, 16.0, 16.0), _src[k])
