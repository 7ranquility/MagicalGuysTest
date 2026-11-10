class_name ShotManager
extends Node2D
## Everything the player's instruments put into the world: bullets, expanding rings, damage
## zones, orbiters, delayed strikes, lobbed shots and short lived attack visuals.
## Pooled struct-of-arrays, one _draw() for all.

enum Kind { BULLET, RING, ZONE, ORBIT, STRIKE, LOB, V_BEAM, V_CONE, V_SLASH, V_LINE, V_RING }

const CAP: int = 768
const HITMEM: int = 8

const F_HOMING: int = 1
const F_BOUNCE: int = 2
const F_BOOMERANG: int = 4
const F_SPLIT: int = 8
const F_ROTATE: int = 16
const F_SPIN: int = 32
const F_FOLLOW: int = 64
const F_RETURNING: int = 128
const F_CLUSTER: int = 256

var run: Run
var en: EnemyManager
var hw: int = 0
var count: int = 0

var alive: PackedByteArray = PackedByteArray()
var kind: PackedInt32Array = PackedInt32Array()
var slot: PackedInt32Array = PackedInt32Array()
var pierce: PackedInt32Array = PackedInt32Array()
var fl: PackedInt32Array = PackedInt32Array()
var reg: PackedInt32Array = PackedInt32Array()
var tgt: PackedInt32Array = PackedInt32Array()
var tgt_uid: PackedInt32Array = PackedInt32Array()
var hit_n: PackedInt32Array = PackedInt32Array()
var hitmem: PackedInt32Array = PackedInt32Array()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var vy: PackedFloat32Array = PackedFloat32Array()
var r: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var life0: PackedFloat32Array = PackedFloat32Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var kb: PackedFloat32Array = PackedFloat32Array()
var rot: PackedFloat32Array = PackedFloat32Array()
var a: PackedFloat32Array = PackedFloat32Array()
var b: PackedFloat32Array = PackedFloat32Array()
var c: PackedFloat32Array = PackedFloat32Array()
var d: PackedFloat32Array = PackedFloat32Array()
var tick: PackedFloat32Array = PackedFloat32Array()
var col: PackedColorArray = PackedColorArray()
var _free: PackedInt32Array = PackedInt32Array()
var _free_n: int = 0

## Per weapon slot on-hit effects (set by WeaponSystem).
var slot_slow_f: PackedFloat32Array = PackedFloat32Array()
var slot_slow_t: PackedFloat32Array = PackedFloat32Array()
var slot_stun: PackedFloat32Array = PackedFloat32Array()

var _regs: Array[Rect2] = []
var _reg_lookup: Dictionary = {}
var _tex: Texture2D
var _poly: PackedVector2Array = PackedVector2Array()
var _poly_cols: PackedColorArray = PackedColorArray()


func _ready() -> void:
	Atlas.ensure()
	_tex = Atlas.tex
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arr: PackedFloat32Array in [x, y, vx, vy, r, life, life0, dmg, kb, rot, a, b, c, d, tick]:
		arr.resize(CAP)
	for arr2: PackedInt32Array in [kind, slot, pierce, fl, reg, tgt, tgt_uid, hit_n, _free]:
		arr2.resize(CAP)
	hitmem.resize(CAP * HITMEM)
	alive.resize(CAP)
	col.resize(CAP)
	slot_slow_f.resize(EnemyManager.SLOTS)
	slot_slow_t.resize(EnemyManager.SLOTS)
	slot_stun.resize(EnemyManager.SLOTS)
	_poly.resize(10)
	_poly_cols.resize(10)


func sprite(name_: String) -> int:
	if _reg_lookup.has(name_):
		return _reg_lookup[name_]
	var idx: int = _regs.size()
	_regs.append(Atlas.rect(name_))
	_reg_lookup[name_] = idx
	return idx


func clear_all() -> void:
	for i: int in hw:
		alive[i] = 0
	hw = 0
	count = 0
	_free_n = 0


func _alloc(k: int, s: int) -> int:
	var i: int
	if _free_n > 0:
		_free_n -= 1
		i = _free[_free_n]
	elif hw < CAP:
		i = hw
		hw += 1
	else:
		return -1
	alive[i] = 1
	count += 1
	kind[i] = k
	slot[i] = s
	fl[i] = 0
	reg[i] = -1
	tgt[i] = -1
	hit_n[i] = 0
	rot[i] = 0.0
	tick[i] = 0.0
	vx[i] = 0.0
	vy[i] = 0.0
	a[i] = 0.0
	b[i] = 0.0
	c[i] = 0.0
	d[i] = 0.0
	return i


func _release(i: int) -> void:
	alive[i] = 0
	count -= 1
	_free[_free_n] = i
	_free_n += 1


## Central damage entry for weapon hits: applies damage, knockback and slot effects.
func hit(e: int, s: int, amount: float, sx: float, sy: float, knock: float) -> bool:
	var killed: bool = en.hurt(e, amount, s, sx, sy, knock)
	if not killed:
		if slot_slow_t[s] > 0.0:
			en.apply_slow(e, slot_slow_f[s], slot_slow_t[s])
		if slot_stun[s] > 0.0:
			en.apply_stun(e, slot_stun[s])
	return killed


## Instant area damage. Returns the number of enemies hit.
func blast(s: int, cx: float, cy: float, radius: float, amount: float, knock: float) -> int:
	var n: int = en.query_circle(cx, cy, radius)
	for k: int in n:
		hit(en.q[k], s, amount, cx, cy, knock)
	return n


# --- spawners ------------------------------------------------------------------------------

func bullet(s: int, px_: float, py_: float, vx_: float, vy_: float, radius: float, amount: float, knock: float, pierce_: int, time: float, flags_: int, color: Color, sprite_: int) -> int:
	var i: int = _alloc(Kind.BULLET, s)
	if i < 0:
		return -1
	x[i] = px_
	y[i] = py_
	vx[i] = vx_
	vy[i] = vy_
	r[i] = radius
	dmg[i] = amount
	kb[i] = knock
	pierce[i] = pierce_
	life[i] = time
	life0[i] = time
	fl[i] = flags_
	col[i] = color
	reg[i] = sprite_
	rot[i] = atan2(vy_, vx_)
	return i


func ring(s: int, px_: float, py_: float, r_max: float, time: float, amount: float, knock: float, color: Color, follow: bool = false) -> int:
	var i: int = _alloc(Kind.RING, s)
	if i < 0:
		return -1
	x[i] = px_
	y[i] = py_
	r[i] = r_max
	a[i] = 0.0
	dmg[i] = amount
	kb[i] = knock
	life[i] = time
	life0[i] = time
	col[i] = color
	if follow:
		fl[i] = F_FOLLOW
	return i


func zone(s: int, px_: float, py_: float, radius: float, time: float, tick_: float, amount: float, knock: float, color: Color, sprite_: int = -1) -> int:
	var i: int = _alloc(Kind.ZONE, s)
	if i < 0:
		return -1
	x[i] = px_
	y[i] = py_
	r[i] = radius
	dmg[i] = amount
	kb[i] = knock
	life[i] = time
	life0[i] = time
	a[i] = tick_
	tick[i] = 0.05
	col[i] = color
	reg[i] = sprite_
	return i


func orbit(s: int, angle: float, orbit_r: float, radius: float, time: float, spin: float, amount: float, knock: float, hit_delay: float, color: Color, sprite_: int) -> int:
	var i: int = _alloc(Kind.ORBIT, s)
	if i < 0:
		return -1
	a[i] = angle
	b[i] = orbit_r
	c[i] = spin
	d[i] = hit_delay
	r[i] = radius
	dmg[i] = amount
	kb[i] = knock
	life[i] = time
	life0[i] = time
	col[i] = color
	reg[i] = sprite_
	x[i] = run.player.position.x + cos(angle) * orbit_r
	y[i] = run.player.position.y + sin(angle) * orbit_r
	return i


func strike(s: int, px_: float, py_: float, radius: float, delay: float, amount: float, knock: float, color: Color, sprite_: int) -> int:
	var i: int = _alloc(Kind.STRIKE, s)
	if i < 0:
		return -1
	x[i] = px_
	y[i] = py_
	r[i] = radius
	dmg[i] = amount
	kb[i] = knock
	life[i] = delay
	life0[i] = delay
	col[i] = color
	reg[i] = sprite_
	return i


func lob(s: int, x0: float, y0: float, x1: float, y1: float, radius: float, time: float, amount: float, knock: float, color: Color, sprite_: int, cluster: int = 0) -> int:
	var i: int = _alloc(Kind.LOB, s)
	if i < 0:
		return -1
	x[i] = x0
	y[i] = y0
	a[i] = x0
	b[i] = y0
	c[i] = x1
	d[i] = y1
	r[i] = radius
	dmg[i] = amount
	kb[i] = knock
	life[i] = time
	life0[i] = time
	col[i] = color
	reg[i] = sprite_
	pierce[i] = cluster
	return i


func _visual(k: int, px_: float, py_: float, time: float, color: Color) -> int:
	var i: int = _alloc(k, 0)
	if i < 0:
		return -1
	x[i] = px_
	y[i] = py_
	life[i] = time
	life0[i] = time
	col[i] = color
	return i


func v_beam(x0: float, y0: float, x1: float, y1: float, width: float, time: float, color: Color) -> void:
	var i: int = _visual(Kind.V_BEAM, x0, y0, time, color)
	if i >= 0:
		a[i] = x1
		b[i] = y1
		r[i] = width


func v_line(x0: float, y0: float, x1: float, y1: float, width: float, time: float, color: Color) -> void:
	var i: int = _visual(Kind.V_LINE, x0, y0, time, color)
	if i >= 0:
		a[i] = x1
		b[i] = y1
		r[i] = width


func v_cone(px_: float, py_: float, angle: float, half: float, reach: float, time: float, color: Color) -> void:
	var i: int = _visual(Kind.V_CONE, px_, py_, time, color)
	if i >= 0:
		a[i] = angle
		b[i] = half
		r[i] = reach


func v_slash(px_: float, py_: float, angle: float, half: float, reach: float, time: float, color: Color) -> void:
	var i: int = _visual(Kind.V_SLASH, px_, py_, time, color)
	if i >= 0:
		a[i] = angle
		b[i] = half
		r[i] = reach


func v_ring(px_: float, py_: float, radius: float, time: float, color: Color, follow: bool = false) -> void:
	var i: int = _visual(Kind.V_RING, px_, py_, time, color)
	if i >= 0:
		r[i] = radius
		if follow:
			fl[i] = F_FOLLOW


# --- simulation ----------------------------------------------------------------------------

func update(dt: float) -> void:
	var plx: float = run.player.position.x
	var ply: float = run.player.position.y
	var view: Rect2 = run.view_rect
	var vx0: float = view.position.x
	var vy0: float = view.position.y
	var vx1: float = view.end.x
	var vy1: float = view.end.y
	var tnow: float = run.time
	for i: int in hw:
		if alive[i] == 0:
			continue
		var t: float = life[i] - dt
		life[i] = t
		match kind[i]:
			Kind.BULLET:
				if t <= 0.0:
					_release(i)
					continue
				var f: int = fl[i]
				var bx: float = x[i]
				var by: float = y[i]
				var bvx: float = vx[i]
				var bvy: float = vy[i]
				if (f & F_HOMING) != 0:
					var ti: int = tgt[i]
					if ti < 0 or en.alive[ti] == 0 or en.uid[ti] != tgt_uid[i]:
						tick[i] -= dt
						if tick[i] <= 0.0:
							tick[i] = 0.15
							ti = en.nearest(bx, by, 260.0)
							tgt[i] = ti
							if ti >= 0:
								tgt_uid[i] = en.uid[ti]
					if ti >= 0 and en.alive[ti] != 0:
						var sp: float = sqrt(bvx * bvx + bvy * bvy)
						var dx: float = en.px[ti] - bx
						var dy: float = en.py[ti] - by
						var dl: float = sqrt(dx * dx + dy * dy) + 0.001
						var turn: float = minf(1.0, c[i] * dt)
						bvx = lerpf(bvx, dx / dl * sp, turn)
						bvy = lerpf(bvy, dy / dl * sp, turn)
						var nl: float = sqrt(bvx * bvx + bvy * bvy) + 0.001
						bvx *= sp / nl
						bvy *= sp / nl
				if (f & F_BOOMERANG) != 0:
					var age: float = life0[i] - t
					if age > a[i]:
						var dx2: float = plx - bx
						var dy2: float = ply - by
						var dl2: float = sqrt(dx2 * dx2 + dy2 * dy2) + 0.001
						var acc: float = b[i] * dt
						bvx += dx2 / dl2 * acc
						bvy += dy2 / dl2 * acc
						if (f & F_RETURNING) == 0:
							fl[i] = f | F_RETURNING
							hit_n[i] = 0
						if dl2 < 14.0 and age > a[i] + 0.25:
							_release(i)
							continue
					else:
						var damp: float = 1.0 - minf(1.0, 1.6 * dt)
						bvx *= damp
						bvy *= damp
				bx += bvx * dt
				by += bvy * dt
				if (f & F_BOUNCE) != 0:
					var bounced: bool = false
					if bx < vx0 and bvx < 0.0:
						bvx = -bvx
						bounced = true
					elif bx > vx1 and bvx > 0.0:
						bvx = -bvx
						bounced = true
					if by < vy0 and bvy < 0.0:
						bvy = -bvy
						bounced = true
					elif by > vy1 and bvy > 0.0:
						bvy = -bvy
						bounced = true
					if bounced:
						hit_n[i] = 0
						if (f & F_SPLIT) != 0 and d[i] > 0.0:
							d[i] -= 1.0
							var j: int = bullet(slot[i], bx, by, bvy, -bvx, r[i], dmg[i], kb[i], pierce[i], t, f, col[i], reg[i])
							if j >= 0:
								d[j] = d[i]
				x[i] = bx
				y[i] = by
				vx[i] = bvx
				vy[i] = bvy
				if (f & F_ROTATE) != 0:
					rot[i] = atan2(bvy, bvx)
				elif (f & F_SPIN) != 0:
					rot[i] += 14.0 * dt
				var n: int = en.query_circle(bx, by, r[i])
				if n > 0:
					var base: int = i * HITMEM
					var hn: int = hit_n[i]
					var s: int = slot[i]
					for k: int in n:
						var e: int = en.q[k]
						var eu: int = en.uid[e]
						var seen: bool = false
						for m: int in mini(hn, HITMEM):
							if hitmem[base + m] == eu:
								seen = true
								break
						if seen:
							continue
						hitmem[base + (hn % HITMEM)] = eu
						hn += 1
						hit(e, s, dmg[i], bx - bvx * 0.05, by - bvy * 0.05, kb[i])
						var p: int = pierce[i]
						if p > 0:
							p -= 1
							pierce[i] = p
							if p == 0:
								_release(i)
								break
					hit_n[i] = hn
			Kind.RING:
				if t <= 0.0:
					_release(i)
					continue
				if (fl[i] & F_FOLLOW) != 0:
					x[i] = plx
					y[i] = ply
				var prev: float = a[i]
				var cur: float = r[i] * (1.0 - t / life0[i])
				a[i] = cur
				var n2: int = en.query_circle(x[i], y[i], cur)
				var cx: float = x[i]
				var cy: float = y[i]
				for k: int in n2:
					var e2: int = en.q[k]
					var dx3: float = en.px[e2] - cx
					var dy3: float = en.py[e2] - cy
					var inner: float = prev + en.rad[e2]
					if dx3 * dx3 + dy3 * dy3 >= inner * inner or prev <= 0.0:
						hit(e2, slot[i], dmg[i], cx, cy, kb[i])
			Kind.ZONE:
				if t <= 0.0:
					_release(i)
					continue
				tick[i] -= dt
				if tick[i] <= 0.0:
					tick[i] += a[i]
					blast(slot[i], x[i], y[i], r[i], dmg[i], kb[i])
			Kind.ORBIT:
				if t <= 0.0:
					_release(i)
					continue
				var ang: float = a[i] + c[i] * dt
				a[i] = ang
				var grow: float = minf(1.0, (life0[i] - t) * 5.0) * minf(1.0, t * 5.0)
				var ox: float = plx + cos(ang) * b[i] * grow
				var oy: float = ply + sin(ang) * b[i] * grow
				x[i] = ox
				y[i] = oy
				rot[i] = ang + PI * 0.5
				var n3: int = en.query_circle(ox, oy, r[i])
				if n3 > 0:
					var s3: int = slot[i]
					var delay: float = d[i]
					for k: int in n3:
						var e3: int = en.q[k]
						var hi: int = e3 * EnemyManager.SLOTS + s3
						if tnow - en.hit_t[hi] >= delay:
							en.hit_t[hi] = tnow
							hit(e3, s3, dmg[i], plx, ply, kb[i])
			Kind.STRIKE:
				if t <= 0.0:
					blast(slot[i], x[i], y[i], r[i], dmg[i], kb[i])
					run.fx.shockwave(x[i], y[i], r[i], col[i])
					run.fx.burst(x[i], y[i], col[i], 6, 90.0)
					_release(i)
			Kind.LOB:
				var u: float = 1.0 - maxf(t, 0.0) / life0[i]
				x[i] = lerpf(a[i], c[i], u)
				y[i] = lerpf(b[i], d[i], u)
				rot[i] += 9.0 * dt
				if t <= 0.0:
					blast(slot[i], x[i], y[i], r[i], dmg[i], kb[i])
					run.fx.shockwave(x[i], y[i], r[i], col[i])
					run.fx.burst(x[i], y[i], col[i], 8, 110.0)
					run.fx.add_shake(1.5)
					var minis: int = pierce[i]
					var lx: float = x[i]
					var ly: float = y[i]
					var mr: float = r[i]
					var md: float = dmg[i]
					var mk: float = kb[i]
					var ms: int = slot[i]
					var mc: Color = col[i]
					var mreg: int = reg[i]
					_release(i)
					for m2: int in minis:
						var an: float = randf() * TAU
						var dist: float = mr * randf_range(0.9, 1.6)
						lob(ms, lx, ly, lx + cos(an) * dist, ly + sin(an) * dist, mr * 0.6, 0.45, md * 0.5, mk, mc, mreg, 0)
			_:
				if t <= 0.0:
					_release(i)
				elif (fl[i] & F_FOLLOW) != 0:
					x[i] = plx
					y[i] = ply


# --- drawing -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var white: Color = Color.WHITE
	for i: int in hw:
		if alive[i] == 0:
			continue
		var cl: Color = col[i]
		var px_: float = x[i]
		var py_: float = y[i]
		var u: float = clampf(life[i] / life0[i], 0.0, 1.0)
		match kind[i]:
			Kind.BULLET, Kind.ORBIT:
				var ri: int = reg[i]
				if ri >= 0:
					var src: Rect2 = _regs[ri]
					var sz: float = maxf(r[i] * 2.4, 10.0)
					draw_set_transform(Vector2(px_, py_), rot[i], Vector2.ONE)
					draw_texture_rect_region(_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), src, cl)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_circle(Vector2(px_, py_), r[i], cl)
					draw_circle(Vector2(px_, py_), r[i] * 0.5, white)
			Kind.RING:
				var rr: float = a[i]
				cl.a = 0.25 + 0.6 * u
				draw_arc(Vector2(px_, py_), rr, 0.0, TAU, 40, cl, 2.0 + 3.0 * u)
				cl.a *= 0.4
				draw_arc(Vector2(px_, py_), rr * 0.82, 0.0, TAU, 32, cl, 1.5)
			Kind.ZONE:
				var fade: float = minf(1.0, life[i] * 3.0)
				cl.a = 0.22 * fade
				draw_circle(Vector2(px_, py_), r[i], cl)
				cl.a = 0.7 * fade
				draw_arc(Vector2(px_, py_), r[i], 0.0, TAU, 32, cl, 1.5)
				var ri2: int = reg[i]
				if ri2 >= 0:
					var bob: float = sin(run.time * 6.0 + float(i)) * 2.0
					draw_texture_rect_region(_tex, Rect2(px_ - 10.0, py_ - 16.0 + bob, 20.0, 20.0), _regs[ri2], Color(1, 1, 1, fade))
			Kind.STRIKE:
				cl.a = 0.25
				draw_circle(Vector2(px_, py_), r[i] * (1.0 - u * 0.6), cl)
				cl.a = 0.8
				draw_arc(Vector2(px_, py_), r[i], 0.0, TAU, 24, cl, 1.0)
				var ri3: int = reg[i]
				if ri3 >= 0:
					var drop: float = u * 140.0
					draw_texture_rect_region(_tex, Rect2(px_ - 9.0, py_ - 18.0 - drop, 18.0, 18.0), _regs[ri3], col[i])
			Kind.LOB:
				var hgt: float = 4.0 * u * (1.0 - u) * 60.0
				draw_circle(Vector2(px_, py_), 5.0, Color(0, 0, 0, 0.25))
				var ri4: int = reg[i]
				if ri4 >= 0:
					draw_set_transform(Vector2(px_, py_ - hgt), rot[i], Vector2.ONE)
					draw_texture_rect_region(_tex, Rect2(-9.0, -9.0, 18.0, 18.0), _regs[ri4], white)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.V_BEAM:
				cl.a = u
				var to: Vector2 = Vector2(a[i], b[i])
				draw_line(Vector2(px_, py_), to, cl, r[i] * (0.4 + 0.6 * u))
				draw_line(Vector2(px_, py_), to, Color(1, 1, 1, u), r[i] * 0.3 * u)
			Kind.V_LINE:
				cl.a = u
				draw_line(Vector2(px_, py_), Vector2(a[i], b[i]), cl, r[i])
			Kind.V_CONE:
				var ang: float = a[i]
				var half: float = b[i]
				var reach: float = r[i] * (1.0 - u * 0.35)
				_poly[0] = Vector2(px_, py_)
				for k: int in 9:
					var an: float = ang - half + half * 2.0 * float(k) / 8.0
					_poly[k + 1] = Vector2(px_ + cos(an) * reach, py_ + sin(an) * reach)
				cl.a = 0.55 * u
				draw_colored_polygon(_poly, cl)
				cl.a = u
				draw_arc(Vector2(px_, py_), reach, ang - half, ang + half, 12, cl, 2.0)
			Kind.V_SLASH:
				var reach2: float = r[i]
				var sweep: float = b[i] * 2.0 * (1.0 - u)
				var a0: float = a[i] - b[i]
				cl.a = u
				draw_arc(Vector2(px_, py_), reach2 * 0.8, a0, a0 + sweep + 0.3, 14, cl, reach2 * 0.3)
				draw_arc(Vector2(px_, py_), reach2, a0, a0 + sweep + 0.3, 14, Color(1, 1, 1, u), 2.0)
			Kind.V_RING:
				cl.a = 0.5 * u
				draw_arc(Vector2(px_, py_), r[i] * (1.0 - 0.15 * u), 0.0, TAU, 40, cl, 2.0)
				cl.a = 0.12 * u
				draw_circle(Vector2(px_, py_), r[i], cl)
