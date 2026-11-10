class_name HazardManager
extends Node2D
## Telegraphed danger zones (stage hazards, boss attacks, exploding enemies) and lingering
## fields (fog, lava, smoke). Stage hazards are scheduled on the beat from stage config.

const CAP: int = 96
const STYLE_DANGER: int = 0
const STYLE_FOG: int = 1
const STYLE_LAVA: int = 2
const STYLE_SMOKE: int = 3
const STYLES: Dictionary = {"danger": 0, "fog": 1, "lava": 2, "smoke": 3}

var run: Run
var n: int = 0
var shape: PackedInt32Array = PackedInt32Array()
var style: PackedInt32Array = PackedInt32Array()
var hits_enemies: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var x2: PackedFloat32Array = PackedFloat32Array()
var y2: PackedFloat32Array = PackedFloat32Array()
var r: PackedFloat32Array = PackedFloat32Array()
var warn: PackedFloat32Array = PackedFloat32Array()
var warn0: PackedFloat32Array = PackedFloat32Array()
var active: PackedFloat32Array = PackedFloat32Array()
var dmg: PackedFloat32Array = PackedFloat32Array()
var tick: PackedFloat32Array = PackedFloat32Array()
var tick_t: PackedFloat32Array = PackedFloat32Array()
var slow: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var vy: PackedFloat32Array = PackedFloat32Array()
var fired: PackedByteArray = PackedByteArray()
## Field left behind when a zone goes off: [radius, duration, damage, tick, slow, style] or empty.
var leave: Array[Array] = []

var _defs: Array = []
var _danger: Color = Color(1.0, 0.25, 0.2)


func _ready() -> void:
	for arr: PackedFloat32Array in [x, y, x2, y2, r, warn, warn0, active, dmg, tick, tick_t, slow, vx, vy]:
		arr.resize(CAP)
	shape.resize(CAP)
	style.resize(CAP)
	hits_enemies.resize(CAP)
	fired.resize(CAP)
	leave.resize(CAP)
	if bool(Save.setting("colorblind")):
		_danger = Color(1.0, 0.75, 0.1)


func setup(stage: Dictionary) -> void:
	_defs = stage.get("hazards", [])
	n = 0


func _add(shape_: int, px: float, py: float, radius: float, warn_: float, active_: float, damage: float, enemies_too: bool) -> int:
	if n >= CAP:
		return -1
	var i: int = n
	n += 1
	shape[i] = shape_
	style[i] = STYLE_DANGER
	x[i] = px
	y[i] = py
	x2[i] = px
	y2[i] = py
	r[i] = radius
	warn[i] = warn_
	warn0[i] = maxf(warn_, 0.001)
	active[i] = active_
	dmg[i] = damage
	tick[i] = 0.0
	tick_t[i] = 0.0
	slow[i] = 1.0
	vx[i] = 0.0
	vy[i] = 0.0
	fired[i] = 0
	hits_enemies[i] = 1 if enemies_too else 0
	leave[i] = []
	return i


## One-shot telegraphed circle: warns, then damages once.
func add_circle(px: float, py: float, radius: float, warn_: float, active_: float, damage: float, enemies_too: bool = false) -> int:
	return _add(0, px, py, radius, warn_, active_, damage, enemies_too)


## One-shot telegraphed line (capsule).
func add_line(x0: float, y0: float, x1: float, y1: float, width: float, warn_: float, active_: float, damage: float) -> int:
	var i: int = _add(1, x0, y0, width, warn_, active_, damage, false)
	if i >= 0:
		x2[i] = x1
		y2[i] = y1
	return i


## Lingering field: ticks damage and/or slows the player while inside.
func add_field(px: float, py: float, radius: float, duration: float, damage: float, tick_: float, slow_: float, style_: int, drift: Vector2 = Vector2.ZERO) -> int:
	var i: int = _add(0, px, py, radius, 0.6, duration, damage, false)
	if i >= 0:
		tick[i] = maxf(tick_, 0.1)
		slow[i] = slow_
		style[i] = style_
		vx[i] = drift.x
		vy[i] = drift.y
	return i


func clear_all() -> void:
	n = 0


## Called for every 16th-note step the music clock crosses.
func on_step(step: int) -> void:
	if (step & 3) != 0:
		return
	var beat: int = step >> 2
	var minute: float = run.time / 60.0
	for def: Dictionary in _defs:
		var every: int = int(def.get("every_beats", 16))
		if beat % every != int(def.get("offset_beats", 0)) % every:
			continue
		if minute < float(def.get("from_minute", 0.0)):
			continue
		_trigger(def, minute)


func _trigger(def: Dictionary, minute: float) -> void:
	var p: Vector2 = run.player.position
	var count: int = int(def.get("count", 1)) + int(minute / float(def.get("grow_minutes", 1000.0)))
	var warn_t: float = float(def.get("warn_beats", 4)) * Music.step_dur * 4.0
	var damage: float = float(def.get("damage", 10)) * run.enemy_damage_mult
	var st: int = STYLES.get(def.get("style", "danger"), 0)
	match def.get("kind", "falling"):
		"falling":
			var spread: float = float(def.get("spread", 240))
			for k: int in count:
				var off: Vector2 = Vector2(randf_range(-spread, spread), randf_range(-spread * 0.6, spread * 0.6))
				if k == 0:
					off = run.player.velocity * warn_t * 0.8
				var i: int = add_circle(p.x + off.x, p.y + off.y, float(def.get("radius", 36)), warn_t, 0.2, damage, true)
				if i >= 0 and def.has("leave"):
					var lv: Dictionary = def["leave"]
					leave[i] = [float(lv.get("radius", 30)), float(lv.get("duration", 6)), float(lv.get("damage", 4)) * run.enemy_damage_mult, float(lv.get("tick", 0.5)), float(lv.get("slow", 1.0)), STYLES.get(lv.get("style", "lava"), 2)]
		"sweep":
			for k: int in count:
				var ang: float = randf() * PI
				if def.get("axis", "") == "h":
					ang = 0.0
				elif def.get("axis", "") == "v":
					ang = PI * 0.5
				var dir: Vector2 = Vector2(cos(ang), sin(ang))
				var side: Vector2 = Vector2(-dir.y, dir.x) * randf_range(-140.0, 140.0)
				if k == 0:
					side = Vector2.ZERO
				var c: Vector2 = p + side
				add_line(c.x - dir.x * 700.0, c.y - dir.y * 700.0, c.x + dir.x * 700.0, c.y + dir.y * 700.0, float(def.get("width", 20)), warn_t, 0.25, damage)
		"field":
			for k: int in count:
				var ang2: float = randf() * TAU
				var dist: float = randf_range(60.0, 320.0)
				var drift: Vector2 = Vector2.from_angle(randf() * TAU) * float(def.get("drift", 0))
				add_field(p.x + cos(ang2) * dist, p.y + sin(ang2) * dist, float(def.get("radius", 60)), float(def.get("duration", 10)), damage if def.has("damage") else 0.0, float(def.get("tick", 0.5)), float(def.get("slow", 1.0)), st, drift)


func update(dt: float) -> void:
	var player: Player = run.player
	var plx: float = player.position.x
	var ply: float = player.position.y
	var slow_now: float = 1.0
	var i: int = 0
	while i < n:
		var inside: bool = false
		if warn[i] > 0.0:
			warn[i] -= dt
		else:
			x[i] += vx[i] * dt
			y[i] += vy[i] * dt
			if shape[i] == 0:
				var dx: float = plx - x[i]
				var dy: float = ply - y[i]
				inside = dx * dx + dy * dy < r[i] * r[i]
			else:
				inside = _dist_to_segment(plx, ply, x[i], y[i], x2[i], y2[i]) < r[i] * 0.5 + 4.0
			if tick[i] > 0.0:
				if inside:
					slow_now = minf(slow_now, slow[i])
					tick_t[i] -= dt
					if tick_t[i] <= 0.0 and dmg[i] > 0.0:
						tick_t[i] = tick[i]
						run.player_hit(dmg[i], -1)
			elif fired[i] == 0:
				fired[i] = 1
				if inside:
					run.player_hit(dmg[i], -1)
				if shape[i] == 0:
					run.fx.shockwave(x[i], y[i], r[i], _danger)
					if run.view_rect.has_point(Vector2(x[i], y[i])):
						run.fx.add_shake(2.0)
						Audio.play("boom", -6.0)
					if hits_enemies[i] != 0:
						run.shots.blast(EnemyManager.SLOTS - 1, x[i], y[i], r[i], dmg[i] * 3.0, 80.0)
				if not leave[i].is_empty():
					var lv: Array = leave[i]
					add_field(x[i], y[i], lv[0], lv[1], lv[2], lv[3], lv[4], lv[5])
			active[i] -= dt
			if active[i] <= 0.0:
				n -= 1
				if i != n:
					shape[i] = shape[n]
					style[i] = style[n]
					hits_enemies[i] = hits_enemies[n]
					x[i] = x[n]
					y[i] = y[n]
					x2[i] = x2[n]
					y2[i] = y2[n]
					r[i] = r[n]
					warn[i] = warn[n]
					warn0[i] = warn0[n]
					active[i] = active[n]
					dmg[i] = dmg[n]
					tick[i] = tick[n]
					tick_t[i] = tick_t[n]
					slow[i] = slow[n]
					vx[i] = vx[n]
					vy[i] = vy[n]
					fired[i] = fired[n]
					leave[i] = leave[n]
				continue
		i += 1
	player.hazard_slow = slow_now


static func _dist_to_segment(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var abx: float = bx - ax
	var aby: float = by - ay
	var l2: float = abx * abx + aby * aby
	var t: float = 0.0
	if l2 > 0.0001:
		t = clampf(((px - ax) * abx + (py - ay) * aby) / l2, 0.0, 1.0)
	var cx: float = ax + abx * t - px
	var cy: float = ay + aby * t - py
	return sqrt(cx * cx + cy * cy)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i: int in n:
		var c: Color
		match style[i]:
			STYLE_FOG:
				c = Color(0.8, 0.85, 0.95)
			STYLE_LAVA:
				c = Color(1.0, 0.45, 0.1)
			STYLE_SMOKE:
				c = Color(0.55, 0.5, 0.6)
			_:
				c = _danger
		var pos: Vector2 = Vector2(x[i], y[i])
		if tick[i] > 0.0:
			var fade: float = minf(1.0, active[i]) * (1.0 - clampf(warn[i] / warn0[i], 0.0, 1.0))
			c.a = 0.28 * fade
			draw_circle(pos, r[i], c)
			c.a = 0.2 * fade
			draw_circle(pos + Vector2(r[i] * 0.3, -r[i] * 0.2), r[i] * 0.6, c)
			c.a = 0.6 * fade
			draw_arc(pos, r[i], 0.0, TAU, 28, c, 1.5)
		elif warn[i] > 0.0:
			var u: float = 1.0 - warn[i] / warn0[i]
			if shape[i] == 0:
				c.a = 0.18
				draw_circle(pos, r[i], c)
				c.a = 0.4
				draw_circle(pos, r[i] * u, c)
				draw_arc(pos, r[i], 0.0, TAU, 28, Color(1, 1, 1, 0.75), 1.5)
			else:
				var to: Vector2 = Vector2(x2[i], y2[i])
				c.a = 0.18
				draw_line(pos, to, c, r[i])
				c.a = 0.45
				draw_line(pos, to, c, r[i] * u)
				draw_line(pos, to, Color(1, 1, 1, 0.6), 1.0)
		else:
			c.a = 0.85
			if shape[i] == 0:
				draw_circle(pos, r[i], c)
			else:
				draw_line(pos, Vector2(x2[i], y2[i]), c, r[i])
				draw_line(pos, Vector2(x2[i], y2[i]), Color(1, 1, 1, 0.9), r[i] * 0.35)
