class_name EnemyManager
extends Node2D
## All enemies of a run in pooled struct-of-arrays storage, plus the uniform spatial grid
## every collision query goes through. No node per enemy; one _draw() for all of them.

enum Ai { CHASE, FLYER, CHARGER, RANGED, SINE, SWEEP, EXPLODER, TELEPORT, BUFFER, PHASE, ZIGZAG, BOSS, PROP }

const AI_NAMES: Dictionary = {
	"chase": Ai.CHASE, "flyer": Ai.FLYER, "charger": Ai.CHARGER, "ranged": Ai.RANGED,
	"sine": Ai.SINE, "sweep": Ai.SWEEP, "exploder": Ai.EXPLODER, "teleport": Ai.TELEPORT,
	"buffer": Ai.BUFFER, "phase": Ai.PHASE, "zigzag": Ai.ZIGZAG, "boss": Ai.BOSS, "prop": Ai.PROP,
}

const CAP: int = 1600
const CELL: float = 40.0
const INV_CELL: float = 1.0 / 40.0
const GW: int = 48
const GH: int = 48
const NCELL: int = GW * GH
## Per enemy hit-delay slots (one per weapon slot) for persistent area attacks.
const SLOTS: int = 12
const FAR: float = 900.0
const QCAP: int = 2048

const F_ELITE: int = 1
const F_BOSS: int = 2
const F_FLYER: int = 4
const F_PROP: int = 8
const F_INVULN: int = 16
const F_NO_RELOCATE: int = 32
const F_SILENT: int = 64

var run: Run
var hw: int = 0
var count: int = 0
var next_uid: int = 1
## Number of live non-prop enemies.
var hostile_count: int = 0

var alive: PackedByteArray = PackedByteArray()
var px: PackedFloat32Array = PackedFloat32Array()
var py: PackedFloat32Array = PackedFloat32Array()
var kx: PackedFloat32Array = PackedFloat32Array()
var ky: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var max_hp: PackedFloat32Array = PackedFloat32Array()
var spd: PackedFloat32Array = PackedFloat32Array()
var rad: PackedFloat32Array = PackedFloat32Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var armor: PackedFloat32Array = PackedFloat32Array()
var kbres: PackedFloat32Array = PackedFloat32Array()
var scl: PackedFloat32Array = PackedFloat32Array()
var flash: PackedFloat32Array = PackedFloat32Array()
var slow_t: PackedFloat32Array = PackedFloat32Array()
var slow_f: PackedFloat32Array = PackedFloat32Array()
var stun_t: PackedFloat32Array = PackedFloat32Array()
var st: PackedFloat32Array = PackedFloat32Array()
var pa: PackedFloat32Array = PackedFloat32Array()
var pb: PackedFloat32Array = PackedFloat32Array()
var pc: PackedFloat32Array = PackedFloat32Array()
var dirx: PackedFloat32Array = PackedFloat32Array()
var diry: PackedFloat32Array = PackedFloat32Array()
var hit_t: PackedFloat32Array = PackedFloat32Array()
var type_idx: PackedInt32Array = PackedInt32Array()
var ai: PackedInt32Array = PackedInt32Array()
var state: PackedInt32Array = PackedInt32Array()
var uid: PackedInt32Array = PackedInt32Array()
var flags: PackedInt32Array = PackedInt32Array()
var cell: PackedInt32Array = PackedInt32Array()
var _free: PackedInt32Array = PackedInt32Array()
var _free_n: int = 0

# Spatial grid (counting sort, rebuilt every frame).
var _cs: PackedInt32Array = PackedInt32Array()
var _sorted: PackedInt32Array = PackedInt32Array()
var _gx0: float = 0.0
var _gy0: float = 0.0
## Result buffer of the last query; valid entries are q[0 .. n-1].
var q: PackedInt32Array = PackedInt32Array()

# Per type caches (index = type_idx).
var type_ids: Array[String] = []
var type_defs: Array[Dictionary] = []
var _type_lookup: Dictionary = {}
var _reg0: Array[Rect2] = []
var _reg1: Array[Rect2] = []
var _regf0: Array[Rect2] = []
var _regf1: Array[Rect2] = []

var freeze_time: float = 0.0
var _buff_tick: float = 0.0
var _tex: Texture2D


func _ready() -> void:
	Atlas.ensure()
	_tex = Atlas.tex
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arr: PackedFloat32Array in [px, py, kx, ky, hp, max_hp, spd, rad, dmg, armor, kbres, scl, flash, slow_t, slow_f, stun_t, st, pa, pb, pc, dirx, diry]:
		arr.resize(CAP)
	hit_t.resize(CAP * SLOTS)
	for arr2: PackedInt32Array in [type_idx, ai, state, uid, flags, cell, _free, _sorted]:
		arr2.resize(CAP)
	alive.resize(CAP)
	_cs.resize(NCELL + 2)
	q.resize(QCAP)
	for id: String in Content.enemy_ids:
		var d: Dictionary = Content.enemies[id]
		_type_lookup[id] = type_ids.size()
		type_ids.append(id)
		type_defs.append(d)
		var sprite: String = d.get("sprite", "en_noteguy")
		if Atlas.has(sprite + "_0"):
			_reg0.append(Atlas.rect(sprite + "_0"))
			_reg1.append(Atlas.rect(sprite + "_1"))
			_regf0.append(Atlas.rect(sprite + "_f0"))
			_regf1.append(Atlas.rect(sprite + "_f1"))
		else:
			for regs: Array[Rect2] in [_reg0, _reg1, _regf0, _regf1]:
				regs.append(Atlas.rect(sprite))


func type_of(id: String) -> int:
	return _type_lookup.get(id, 0)


## Spawns an enemy and returns its index, or -1 when the pool is full.
func spawn(id: String, x: float, y: float, hp_mult: float = 1.0, elite: bool = false) -> int:
	var i: int
	if _free_n > 0:
		_free_n -= 1
		i = _free[_free_n]
	elif hw < CAP:
		i = hw
		hw += 1
	else:
		return -1
	var t: int = _type_lookup.get(id, 0)
	var d: Dictionary = type_defs[t]
	alive[i] = 1
	count += 1
	px[i] = x
	py[i] = y
	kx[i] = 0.0
	ky[i] = 0.0
	var h: float = float(d.get("hp", 10)) * hp_mult
	var f: int = 0
	var s: float = float(d.get("scale", 1.0))
	var a: int = AI_NAMES.get(d.get("ai", "chase"), Ai.CHASE)
	if elite:
		f |= F_ELITE
		h *= float(d.get("elite_hp", 12.0))
		s *= 1.6
	if d.get("boss", false):
		f |= F_BOSS | F_NO_RELOCATE
	if d.get("flyer", false) or a == Ai.FLYER or a == Ai.SWEEP:
		f |= F_FLYER
	if a == Ai.PROP:
		f |= F_PROP | F_NO_RELOCATE
	else:
		hostile_count += 1
	if a == Ai.SWEEP:
		f |= F_NO_RELOCATE
	hp[i] = h
	max_hp[i] = h
	spd[i] = float(d.get("speed", 40)) * run.enemy_speed_mult
	rad[i] = float(d.get("radius", 9)) * s
	dmg[i] = float(d.get("damage", 5)) * run.enemy_damage_mult * (1.5 if elite else 1.0)
	armor[i] = float(d.get("armor", 0))
	kbres[i] = 1.0 if (f & F_BOSS) != 0 else clampf(float(d.get("kb_resist", 0.0)) + (0.6 if elite else 0.0), 0.0, 1.0)
	scl[i] = s
	flash[i] = 0.0
	slow_t[i] = 0.0
	slow_f[i] = 1.0
	stun_t[i] = 0.0
	st[i] = float(d.get("start_delay", 0.0)) + randf() * 1.5
	pa[i] = float(d.get("pa", 0))
	pb[i] = float(d.get("pb", 0))
	pc[i] = float(d.get("pc", 0))
	dirx[i] = 0.0
	diry[i] = 0.0
	type_idx[i] = t
	ai[i] = a
	state[i] = 0
	uid[i] = next_uid
	next_uid += 1
	flags[i] = f
	var base: int = i * SLOTS
	for k: int in SLOTS:
		hit_t[base + k] = -100.0
	return i


func kill(i: int, credited: bool = true) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	count -= 1
	if (flags[i] & F_PROP) == 0:
		hostile_count -= 1
	_free[_free_n] = i
	_free_n += 1
	if credited:
		run.on_enemy_killed(i)


func clear_all() -> void:
	for i: int in hw:
		alive[i] = 0
	hw = 0
	count = 0
	hostile_count = 0
	_free_n = 0


## Applies damage from a source position. Returns true when the enemy died.
func hurt(i: int, amount: float, slot: int, sx: float, sy: float, kb: float) -> bool:
	if alive[i] == 0:
		return false
	var f: int = flags[i]
	if (f & F_INVULN) != 0:
		return false
	amount = maxf(1.0, amount - armor[i])
	var h: float = hp[i] - amount
	hp[i] = h
	flash[i] = 0.12
	run.record_damage(slot, amount, px[i], py[i])
	if kb != 0.0:
		var res: float = 1.0 - kbres[i]
		if res > 0.0:
			var dx: float = px[i] - sx
			var dy: float = py[i] - sy
			var d2: float = dx * dx + dy * dy
			if d2 > 0.01:
				var inv: float = kb * res / sqrt(d2)
				kx[i] += dx * inv
				ky[i] += dy * inv
	if h <= 0.0:
		run.kill_slot = slot
		kill(i)
		return true
	return false


func apply_slow(i: int, factor: float, time: float) -> void:
	if (flags[i] & F_BOSS) != 0:
		factor = lerpf(1.0, factor, 0.4)
	if slow_t[i] <= 0.0 or factor < slow_f[i]:
		slow_f[i] = factor
	slow_t[i] = maxf(slow_t[i], time)


func apply_stun(i: int, time: float) -> void:
	if (flags[i] & (F_BOSS | F_PROP)) == 0:
		stun_t[i] = maxf(stun_t[i], time)


# --- simulation ----------------------------------------------------------------------------

func update(dt: float) -> void:
	var player: Player = run.player
	var plx: float = player.position.x
	var ply: float = player.position.y
	var prad: float = player.radius
	var far2: float = FAR * FAR
	var kdecay: float = exp(-7.0 * dt)
	var frozen: bool = freeze_time > 0.0
	if frozen:
		freeze_time -= dt
	var tnow: float = run.time
	var phase_bit: int = (Music.step >> 3) & 1
	var hit_player: float = 0.0
	var hit_by: int = -1
	for i: int in hw:
		if alive[i] == 0:
			continue
		var x: float = px[i]
		var y: float = py[i]
		var dx: float = plx - x
		var dy: float = ply - y
		var d2: float = dx * dx + dy * dy
		var f: int = flags[i]
		if d2 > far2 and (f & F_NO_RELOCATE) == 0:
			_relocate(i, plx, ply)
			continue
		var fl: float = flash[i]
		if fl > 0.0:
			flash[i] = fl - dt
		var mvx: float = 0.0
		var mvy: float = 0.0
		var a: int = ai[i]
		var stunned: bool = frozen
		if stun_t[i] > 0.0:
			stun_t[i] -= dt
			stunned = true
		if not stunned and a != Ai.PROP:
			var s: float = spd[i]
			if slow_t[i] > 0.0:
				slow_t[i] -= dt
				s *= slow_f[i]
			var inv: float = 1.0 / sqrt(d2) if d2 > 0.0001 else 0.0
			var ux: float = dx * inv
			var uy: float = dy * inv
			match a:
				Ai.CHASE, Ai.FLYER, Ai.BOSS:
					mvx = ux * s
					mvy = uy * s
				Ai.PHASE:
					mvx = ux * s
					mvy = uy * s
					if ((phase_bit + uid[i]) & 1) == 0:
						flags[i] = f | F_INVULN
					else:
						flags[i] = f & ~F_INVULN
				Ai.SINE:
					var w: float = sin(tnow * pb[i] + float(uid[i])) * pa[i]
					mvx = (ux - uy * w) * s
					mvy = (uy + ux * w) * s
				Ai.ZIGZAG:
					var z: float = pb[i] if fmod(tnow + float(uid[i] & 7) * 0.37, pa[i] * 2.0) < pa[i] else -pb[i]
					mvx = (ux - uy * z) * s
					mvy = (uy + ux * z) * s
				Ai.SWEEP:
					mvx = dirx[i] * s
					mvy = diry[i] * s
					st[i] -= dt
					if st[i] < -pa[i]:
						kill(i, false)
						continue
				Ai.CHARGER:
					var stt: int = state[i]
					if stt == 0:
						mvx = ux * s
						mvy = uy * s
						if d2 < pb[i] * pb[i]:
							state[i] = 1
							st[i] = pc[i]
							dirx[i] = ux
							diry[i] = uy
					elif stt == 1:
						st[i] -= dt
						flash[i] = 0.05 if fmod(st[i], 0.2) < 0.1 else 0.0
						dirx[i] = ux
						diry[i] = uy
						if st[i] <= 0.0:
							state[i] = 2
							st[i] = 0.7
					elif stt == 2:
						mvx = dirx[i] * pa[i]
						mvy = diry[i] * pa[i]
						st[i] -= dt
						if st[i] <= 0.0:
							state[i] = 3
							st[i] = 0.8
					else:
						st[i] -= dt
						if st[i] <= 0.0:
							state[i] = 0
				Ai.RANGED:
					var want: float = pa[i]
					if d2 > want * want * 1.2:
						mvx = ux * s
						mvy = uy * s
					elif d2 < want * want * 0.5:
						mvx = -ux * s * 0.7
						mvy = -uy * s * 0.7
					else:
						mvx = -uy * s * 0.5
						mvy = ux * s * 0.5
					st[i] -= dt
					if st[i] <= 0.0 and d2 < 420.0 * 420.0:
						st[i] = pb[i]
						run.ebullets.spawn(x, y, ux * pc[i], uy * pc[i], 5.0, dmg[i], 5.0)
				Ai.EXPLODER:
					if state[i] == 0:
						mvx = ux * s
						mvy = uy * s
						if d2 < pa[i] * pa[i]:
							state[i] = 1
							st[i] = pc[i]
							run.hazards.add_circle(x, y, pb[i], pc[i], 0.15, dmg[i] * 2.0, true)
					else:
						st[i] -= dt
						flash[i] = 0.05
						if st[i] <= 0.0:
							kill(i, false)
							run.fx.burst(x, y, Color(1.0, 0.6, 0.2), 14, 120.0)
							continue
				Ai.TELEPORT:
					mvx = ux * s
					mvy = uy * s
					st[i] -= dt
					if st[i] <= 0.0:
						st[i] = pa[i]
						var ang: float = randf() * TAU
						run.fx.burst(x, y, Color(0.4, 0.4, 0.8), 6, 60.0)
						x = plx + cos(ang) * pb[i]
						y = ply + sin(ang) * pb[i]
						flash[i] = 0.25
				Ai.BUFFER:
					var keep: float = pa[i]
					if d2 > keep * keep:
						mvx = ux * s
						mvy = uy * s
					else:
						mvx = -uy * s * 0.6
						mvy = ux * s * 0.6
		var kxx: float = kx[i]
		var kyy: float = ky[i]
		if kxx != 0.0 or kyy != 0.0:
			mvx += kxx
			mvy += kyy
			kxx *= kdecay
			kyy *= kdecay
			if absf(kxx) + absf(kyy) < 2.0:
				kxx = 0.0
				kyy = 0.0
			kx[i] = kxx
			ky[i] = kyy
		x += mvx * dt
		y += mvy * dt
		px[i] = x
		py[i] = y
		if not frozen and (f & F_PROP) == 0:
			var rr: float = rad[i] + prad
			if d2 < rr * rr and dmg[i] > hit_player:
				hit_player = dmg[i]
				hit_by = i
	if hit_by >= 0:
		run.player_hit(hit_player, hit_by)
	_build_grid(plx, ply)
	_separate()
	_buff_tick -= dt
	if _buff_tick <= 0.0:
		_buff_tick = 0.5
		_run_buffers()


func _relocate(i: int, plx: float, ply: float) -> void:
	var p: Vector2 = run.spawn_point()
	px[i] = p.x
	py[i] = p.y
	kx[i] = 0.0
	ky[i] = 0.0


func _run_buffers() -> void:
	for i: int in hw:
		if alive[i] == 0 or ai[i] != Ai.BUFFER:
			continue
		var n: int = query_circle(px[i], py[i], pb[i])
		for k: int in n:
			var j: int = q[k]
			if j != i and ai[j] != Ai.BUFFER:
				slow_f[j] = 1.4
				slow_t[j] = 0.7


func _build_grid(plx: float, ply: float) -> void:
	_gx0 = plx - GW * CELL * 0.5
	_gy0 = ply - GH * CELL * 0.5
	_cs.fill(0)
	var gx0: float = _gx0
	var gy0: float = _gy0
	for i: int in hw:
		if alive[i] == 0:
			continue
		var cx: int = clampi(int((px[i] - gx0) * INV_CELL), 0, GW - 1)
		var cy: int = clampi(int((py[i] - gy0) * INV_CELL), 0, GH - 1)
		var c: int = cy * GW + cx
		cell[i] = c
		_cs[c + 2] += 1
	for k: int in range(2, NCELL + 2):
		_cs[k] += _cs[k - 1]
	for i: int in hw:
		if alive[i] == 0:
			continue
		var c: int = cell[i] + 1
		_sorted[_cs[c]] = i
		_cs[c] += 1


func _separate() -> void:
	for c: int in NCELL:
		var s: int = _cs[c]
		var e: int = _cs[c + 1] - 1
		if e <= s:
			continue
		for k: int in range(s, e):
			var a: int = _sorted[k]
			var b: int = _sorted[k + 1]
			var dx: float = px[b] - px[a]
			var dy: float = py[b] - py[a]
			var rr: float = (rad[a] + rad[b]) * 0.85
			var d2: float = dx * dx + dy * dy
			if d2 < rr * rr:
				if d2 < 0.01:
					dx = 0.5 - randf()
					dy = 0.5 - randf()
					d2 = dx * dx + dy * dy + 0.001
				var d: float = sqrt(d2)
				var push: float = (rr - d) * 0.25 / d
				var fa: int = flags[a]
				var fb: int = flags[b]
				if (fa & (F_BOSS | F_PROP)) == 0:
					px[a] -= dx * push
					py[a] -= dy * push
				if (fb & (F_BOSS | F_PROP)) == 0:
					px[b] += dx * push
					py[b] += dy * push


# --- queries -------------------------------------------------------------------------------

## Fills q with the live enemies whose body overlaps the circle. Returns the count.
func query_circle(x: float, y: float, r: float) -> int:
	var reach: float = r + 20.0
	var cx0: int = clampi(int((x - reach - _gx0) * INV_CELL), 0, GW - 1)
	var cx1: int = clampi(int((x + reach - _gx0) * INV_CELL), 0, GW - 1)
	var cy0: int = clampi(int((y - reach - _gy0) * INV_CELL), 0, GH - 1)
	var cy1: int = clampi(int((y + reach - _gy0) * INV_CELL), 0, GH - 1)
	var n: int = 0
	for cy: int in range(cy0, cy1 + 1):
		var row: int = cy * GW
		for k: int in range(_cs[row + cx0], _cs[row + cx1 + 1]):
			var i: int = _sorted[k]
			if alive[i] == 0:
				continue
			var dx: float = px[i] - x
			var dy: float = py[i] - y
			var rr: float = r + rad[i]
			if dx * dx + dy * dy <= rr * rr:
				q[n] = i
				n += 1
				if n >= QCAP:
					return n
	return n


## Nearest hostile (non-prop) enemy within max_r, or -1.
func nearest(x: float, y: float, max_r: float, skip_uid: int = -1) -> int:
	var n: int = query_circle(x, y, max_r)
	var best: int = -1
	var best_d: float = INF
	for k: int in n:
		var i: int = q[k]
		if (flags[i] & (F_PROP | F_INVULN)) != 0 or uid[i] == skip_uid:
			continue
		var dx: float = px[i] - x
		var dy: float = py[i] - y
		var d2: float = dx * dx + dy * dy
		if d2 < best_d:
			best_d = d2
			best = i
	return best


## A random hostile enemy within r, or -1.
func random_near(x: float, y: float, r: float) -> int:
	var n: int = query_circle(x, y, r)
	if n == 0:
		return -1
	var start: int = randi() % n
	for k: int in n:
		var i: int = q[(start + k) % n]
		if (flags[i] & (F_PROP | F_INVULN)) == 0:
			return i
	return -1


func first_boss() -> int:
	for i: int in hw:
		if alive[i] != 0 and (flags[i] & F_BOSS) != 0:
			return i
	return -1


# --- drawing -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null or count == 0:
		return
	var view: Rect2 = run.view_rect
	var cx0: int = clampi(int((view.position.x - 40.0 - _gx0) * INV_CELL), 0, GW - 1)
	var cx1: int = clampi(int((view.end.x + 40.0 - _gx0) * INV_CELL), 0, GW - 1)
	var cy0: int = clampi(int((view.position.y - 40.0 - _gy0) * INV_CELL), 0, GH - 1)
	var cy1: int = clampi(int((view.end.y + 70.0 - _gy0) * INV_CELL), 0, GH - 1)
	var frame1: bool = Music.beat_phase >= 0.5
	var plx: float = run.player.position.x
	var frozen: bool = freeze_time > 0.0
	var reduced: bool = run.reduced_flashing
	var white: Color = Color.WHITE
	var ice: Color = Color(0.6, 0.85, 1.0)
	var ghost: Color = Color(1, 1, 1, 0.35)
	var slowc: Color = Color(0.75, 0.8, 1.0)
	for cy: int in range(cy0, cy1 + 1):
		var row: int = cy * GW
		for k: int in range(_cs[row + cx0], _cs[row + cx1 + 1]):
			var i: int = _sorted[k]
			if alive[i] == 0:
				continue
			var t: int = type_idx[i]
			var f: int = flags[i]
			var src: Rect2
			if flash[i] > 0.0 and not reduced:
				src = _regf1[t] if frame1 else _regf0[t]
			else:
				src = _reg1[t] if frame1 else _reg0[t]
			var s: float = scl[i]
			var w: float = src.size.x * s
			var h: float = src.size.y * s
			var x: float = px[i]
			var y: float = py[i]
			var col: Color = white
			if (f & F_INVULN) != 0:
				col = ghost
			elif frozen or stun_t[i] > 0.0:
				col = ice
			elif slow_t[i] > 0.0 and slow_f[i] < 1.0:
				col = slowc
			if (f & F_ELITE) != 0:
				draw_arc(Vector2(x, y + h * 0.3), rad[i] * 1.3, 0.0, TAU, 20, Color(1.0, 0.85, 0.2, 0.8), 2.0)
			if x > plx and (f & F_PROP) == 0:
				draw_texture_rect_region(_tex, Rect2(x - w * 0.5, y - h * 0.5, -w, h), src, col)
			else:
				draw_texture_rect_region(_tex, Rect2(x - w * 0.5, y - h * 0.5, w, h), src, col)
			if (f & F_ELITE) != 0 and hp[i] < max_hp[i]:
				draw_rect(Rect2(x - 14.0, y - h * 0.5 - 6.0, 28.0, 3.0), Color(0, 0, 0, 0.6))
				draw_rect(Rect2(x - 14.0, y - h * 0.5 - 6.0, 28.0 * hp[i] / max_hp[i], 3.0), Color(1.0, 0.3, 0.3))
