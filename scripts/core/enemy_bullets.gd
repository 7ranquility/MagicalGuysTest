class_name EnemyBullets
extends Node2D
## Pooled enemy projectiles. They only collide with the player.

const CAP: int = 400

var run: Run
var n: int = 0
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var vy: PackedFloat32Array = PackedFloat32Array()
var r: PackedFloat32Array = PackedFloat32Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var _tex: Texture2D
var _src: Rect2


func _ready() -> void:
	for arr: PackedFloat32Array in [x, y, vx, vy, r, dmg, life]:
		arr.resize(CAP)
	Atlas.ensure()
	_tex = Atlas.tex
	_src = Atlas.rect("shot_ebullet")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func spawn(px: float, py: float, vx_: float, vy_: float, radius: float, damage: float, time: float) -> void:
	if n >= CAP:
		return
	x[n] = px
	y[n] = py
	vx[n] = vx_
	vy[n] = vy_
	r[n] = radius
	dmg[n] = damage
	life[n] = time
	n += 1


## Fires `count` bullets in a ring (or an arc of `spread` radians around `angle`).
func burst(px: float, py: float, count: int, speed: float, damage: float, angle: float = 0.0, spread: float = TAU, radius: float = 5.0) -> void:
	for k: int in count:
		var a: float
		if spread >= TAU - 0.001:
			a = angle + TAU * float(k) / float(count)
		elif count > 1:
			a = angle - spread * 0.5 + spread * float(k) / float(count - 1)
		else:
			a = angle
		spawn(px, py, cos(a) * speed, sin(a) * speed, radius, damage, 6.0)


func clear_all() -> void:
	n = 0


func update(dt: float) -> void:
	var plx: float = run.player.position.x
	var ply: float = run.player.position.y
	var pr: float = run.player.radius * 0.7
	var i: int = 0
	while i < n:
		var l: float = life[i] - dt
		var bx: float = x[i] + vx[i] * dt
		var by: float = y[i] + vy[i] * dt
		var dx: float = bx - plx
		var dy: float = by - ply
		var rr: float = r[i] + pr
		var hit: bool = dx * dx + dy * dy < rr * rr
		if hit:
			run.player_hit(dmg[i], -1)
		if hit or l <= 0.0:
			n -= 1
			x[i] = x[n]
			y[i] = y[n]
			vx[i] = vx[n]
			vy[i] = vy[n]
			r[i] = r[n]
			dmg[i] = dmg[n]
			life[i] = life[n]
			continue
		life[i] = l
		x[i] = bx
		y[i] = by
		i += 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i: int in n:
		var s: float = r[i] * 2.6
		draw_texture_rect_region(_tex, Rect2(x[i] - s * 0.5, y[i] - s * 0.5, s, s), _src)
