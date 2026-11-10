class_name WeaponSystem
extends RefCounted
## Owns the equipped instruments and turns music clock steps into attacks.
## Each instrument references one attack pattern primitive; its numbers come from
## data/instruments.json.

enum Pattern { RING, BEAM, WAVE, HOMING, CONE, RAIN, ORBIT, BOUNCE, SLASH, STREAM, AURA, BOOMERANG, CHAIN, PUDDLE, LOCK, LOB }

const PATTERNS: Dictionary = {
	"ring": Pattern.RING, "beam": Pattern.BEAM, "wave": Pattern.WAVE, "homing": Pattern.HOMING,
	"cone": Pattern.CONE, "rain": Pattern.RAIN, "orbit": Pattern.ORBIT, "bounce": Pattern.BOUNCE,
	"slash": Pattern.SLASH, "stream": Pattern.STREAM, "aura": Pattern.AURA,
	"boomerang": Pattern.BOOMERANG, "chain": Pattern.CHAIN, "puddle": Pattern.PUDDLE,
	"lock": Pattern.LOCK, "lob": Pattern.LOB,
}
const PENDING_CAP: int = 160
const DIR_OFFSETS: PackedFloat32Array = [0.0, PI, PI * 0.5, -PI * 0.5, PI * 0.25, -PI * 0.75, PI * 0.75, -PI * 0.25]


class Weapon:
	var id: String
	var def: Dictionary
	var level: int = 1
	var slot: int = 0
	var pattern: int = 0
	var st: Dictionary = {}
	var rhythm: PackedByteArray
	var hits: int = 1
	var phase: int = 0
	var color: Color = Color.WHITE
	var sprite: int = -1
	var flip: int = 0
	var subs: Array = []
	var is_sub: bool = false
	var evolved: bool = false


var run: Run
var shots: ShotManager
var en: EnemyManager
var weapons: Array[Weapon] = []
var slot_damage: PackedFloat32Array = PackedFloat32Array()
var damage_by_id: Dictionary = {}
var _slot_owner: Array = []
var _visited: PackedInt32Array = PackedInt32Array()
var _visited_n: int = 0

var _p_n: int = 0
var _p_t: PackedFloat32Array = PackedFloat32Array()
var _p_i: PackedInt32Array = PackedInt32Array()
var _p_w: Array[Weapon] = []


func _init(run_: Run) -> void:
	run = run_
	shots = run.shots
	en = run.enemies
	slot_damage.resize(EnemyManager.SLOTS)
	_slot_owner.resize(EnemyManager.SLOTS)
	_visited.resize(64)
	_p_t.resize(PENDING_CAP)
	_p_i.resize(PENDING_CAP)
	_p_w.resize(PENDING_CAP)


# --- inventory -----------------------------------------------------------------------------

func find(id: String) -> Weapon:
	for w: Weapon in weapons:
		if w.id == id:
			return w
	return null


func has(id: String) -> bool:
	return find(id) != null


func add(id: String) -> Weapon:
	var w: Weapon = _make(id, _free_slot())
	weapons.append(w)
	_slot_owner[w.slot] = w
	Save.discover("instruments", id)
	_changed()
	return w


func level_up(id: String) -> void:
	var w: Weapon = find(id)
	if w == null:
		return
	w.level = mini(w.level + 1, Content.instrument_max_level(id))
	_compute(w)
	_changed()


func is_max(w: Weapon) -> bool:
	return w.level >= Content.instrument_max_level(w.id)


## Replaces the listed source instruments with the evolved/union instrument.
func transform(target_id: String) -> void:
	var def: Dictionary = Content.instruments[target_id]
	var slot: int = -1
	for src: String in def["from"]:
		var w: Weapon = find(src)
		if w == null:
			continue
		_flush_slot(w)
		_remove_slot_shots(w.slot)
		if slot < 0:
			slot = w.slot
		else:
			_slot_owner[w.slot] = null
		weapons.erase(w)
	if slot < 0:
		slot = _free_slot()
	var nw: Weapon = _make(target_id, slot)
	nw.evolved = true
	weapons.append(nw)
	_slot_owner[slot] = nw
	Save.discover("instruments", target_id)
	Save.add_stat("evolutions", 1)
	_changed()


## Evolutions and unions that are available right now (requirements met).
func available_transforms() -> Array[String]:
	var out: Array[String] = []
	for id: String in Content.instrument_ids:
		var def: Dictionary = Content.instruments[id]
		if not def.has("from") or has(id):
			continue
		var ok: bool = true
		for src: String in def["from"]:
			var w: Weapon = find(src)
			if w == null or not is_max(w):
				ok = false
				break
		if ok and def.has("needs_passive") and not run.player.passives.has(def["needs_passive"]):
			ok = false
		if ok:
			out.append(id)
	return out


func _free_slot() -> int:
	for s: int in EnemyManager.SLOTS - 1:
		if _slot_owner[s] == null:
			return s
	return 0


func _flush_slot(w: Weapon) -> void:
	damage_by_id[w.id] = float(damage_by_id.get(w.id, 0.0)) + slot_damage[w.slot]
	slot_damage[w.slot] = 0.0


func _remove_slot_shots(slot: int, only_kind: int = -1) -> void:
	for i: int in shots.hw:
		if shots.alive[i] == 0 or shots.slot[i] != slot:
			continue
		var k: int = shots.kind[i]
		if (only_kind < 0 and k <= ShotManager.Kind.ORBIT) or k == only_kind:
			shots.life[i] = 0.0


## Damage totals per instrument id for the results screen.
func damage_report() -> Dictionary:
	var out: Dictionary = damage_by_id.duplicate()
	for w: Weapon in weapons:
		out[w.id] = float(out.get(w.id, 0.0)) + slot_damage[w.slot]
	return out


func _make(id: String, slot: int) -> Weapon:
	var w: Weapon = Weapon.new()
	w.id = id
	w.def = Content.instruments[id]
	w.slot = slot
	w.evolved = w.def.has("from")
	_compute(w)
	return w


func _make_sub(parent: Weapon, sub_def: Dictionary) -> Weapon:
	var w: Weapon = Weapon.new()
	w.id = parent.id
	w.def = sub_def
	w.slot = parent.slot
	w.is_sub = true
	w.pattern = PATTERNS.get(sub_def.get("pattern", "ring"), 0)
	w.st = (sub_def.get("base", {}) as Dictionary).duplicate()
	w.color = Color.html(sub_def.get("color", parent.def.get("color", "#ffffff")))
	w.sprite = shots.sprite(sub_def["sprite"]) if sub_def.has("sprite") else -1
	w.phase = int(sub_def.get("phase", 0))
	return w


func _compute(w: Weapon) -> void:
	var d: Dictionary = w.def
	w.pattern = PATTERNS.get(d.get("pattern", "ring"), 0)
	var st: Dictionary = (d.get("base", {}) as Dictionary).duplicate()
	var levels: Array = d.get("levels", [])
	for k: int in mini(w.level - 1, levels.size()):
		for key: String in levels[k]:
			st[key] = float(st.get(key, 0.0)) + float(levels[k][key])
	w.st = st
	w.color = Color.html(d.get("color", "#ffffff"))
	w.sprite = shots.sprite(d["sprite"]) if d.has("sprite") else -1
	w.phase = int(d.get("phase", 0))
	w.subs.clear()
	for sub: Dictionary in d.get("sub", []):
		w.subs.append(_make_sub(w, sub))


## Recomputes rhythms and slot effects. Call after any stat, weapon or tempo change.
func refresh() -> void:
	var cd_mult: float = run.player.stat("cooldown")
	for w: Weapon in weapons:
		_set_rhythm(w, cd_mult)
		for sub: Weapon in w.subs:
			_set_rhythm(sub, cd_mult)
		var fx: Dictionary = w.def.get("on_hit", {})
		shots.slot_slow_f[w.slot] = float(fx.get("slow", 1.0))
		shots.slot_slow_t[w.slot] = float(fx.get("slow_time", 0.0))
		shots.slot_stun[w.slot] = float(fx.get("stun", 0.0))


func _set_rhythm(w: Weapon, cd_mult: float) -> void:
	var cd: float = float(w.st.get("cooldown", 1.0)) * cd_mult
	w.hits = Rhythm.hits_for_cooldown(cd, Music.step_dur)
	w.rhythm = Rhythm.euclid(w.hits)


func _changed() -> void:
	var bonus: Dictionary = {}
	for w: Weapon in weapons:
		for key: String in w.def.get("player_bonus", {}):
			bonus[key] = float(bonus.get(key, 0.0)) + float(w.def["player_bonus"][key])
	if bonus != run.player.weapon_bonus:
		run.player.weapon_bonus = bonus
		run.player.recompute_stats()
	refresh()
	run.on_weapons_changed()


## Music layers for the equipped instruments: [{layer, tier}].
func layers() -> Array:
	var out: Array = []
	for w: Weapon in weapons:
		var tier: int = 3 if w.evolved else (0 if w.level <= 2 else (1 if w.level <= 5 else 2))
		for layer: String in w.def.get("layers", w.def.get("from", [w.id])):
			out.append({"layer": layer, "tier": tier, "hits": w.rhythm, "phase": w.phase})
	return out


## Seconds between attacks of a weapon at the current tempo (for UI and balance tools).
func effective_period(w: Weapon) -> float:
	return Rhythm.period(w.hits, Music.step_dur)


# --- firing --------------------------------------------------------------------------------

func on_step(step: int) -> void:
	for w: Weapon in weapons:
		if w.rhythm[(step - w.phase) & 63] != 0:
			_fire(w)
			Audio.attack(w.id, w.slot, w.evolved)
		for sub: Weapon in w.subs:
			if sub.rhythm[(step - sub.phase) & 63] != 0:
				_fire(sub)


func update(dt: float) -> void:
	var i: int = 0
	while i < _p_n:
		var t: float = _p_t[i] - dt
		if t <= 0.0:
			var w: Weapon = _p_w[i]
			var idx: int = _p_i[i]
			_p_n -= 1
			_p_t[i] = _p_t[_p_n]
			_p_w[i] = _p_w[_p_n]
			_p_i[i] = _p_i[_p_n]
			_p_w[_p_n] = null
			_emit(w, idx)
			continue
		_p_t[i] = t
		i += 1


func _later(w: Weapon, idx: int, delay: float) -> void:
	if _p_n >= PENDING_CAP:
		return
	_p_t[_p_n] = delay
	_p_w[_p_n] = w
	_p_i[_p_n] = idx
	_p_n += 1


func _amount(w: Weapon) -> int:
	var extra: int = 0 if w.def.get("fixed_amount", false) else int(run.player.stat("amount"))
	return maxi(1, int(w.st.get("amount", 1)) + extra)


func _fire(w: Weapon) -> void:
	var n: int = _amount(w)
	var gap: float = Music.step_dur * float(w.def.get("stagger", 0.5))
	match w.pattern:
		Pattern.ORBIT:
			_fire_orbit(w, n)
		Pattern.AURA, Pattern.CHAIN, Pattern.LOCK:
			_emit(w, 0)
		Pattern.RING, Pattern.CONE:
			_emit(w, 0)
			for k: int in range(1, n):
				_later(w, k, Music.step_dur * 2.0 * k)
		_:
			_emit(w, 0)
			for k: int in range(1, n):
				_later(w, k, gap * k)
	w.flip += 1


## Performs volley member `k` of a weapon.
func _emit(w: Weapon, k: int) -> void:
	var pl: Player = run.player
	var px: float = pl.position.x
	var py: float = pl.position.y
	var st: Dictionary = w.st
	var dmg: float = float(st.get("damage", 5)) * pl.stat("might")
	var area: float = float(st.get("area", 1.0)) * pl.stat("area")
	var kb: float = float(st.get("knockback", 0))
	var spd: float = float(st.get("speed", 1.0)) * pl.stat("speed")
	var dur: float = float(st.get("duration", 1.0)) * pl.stat("duration")
	var s: int = w.slot
	match w.pattern:
		Pattern.RING:
			shots.ring(s, px, py, float(st.get("radius", 70)) * area, 0.32, dmg, kb, w.color, true)
			if k == 0:
				run.fx.add_shake(0.6)
		Pattern.BEAM:
			var ang: float = pl.facing.angle() + DIR_OFFSETS[k % 8]
			if w.def.get("rotate", false):
				ang = float(w.flip) * 0.4 + TAU * float(k) / float(_amount(w))
			var length: float = float(st.get("length", 240)) * area
			var width: float = float(st.get("width", 16)) * area
			var ex: float = px + cos(ang) * length
			var ey: float = py + sin(ang) * length
			_hit_segment(s, px, py, ex, ey, width * 0.5, dmg, kb)
			shots.v_beam(px, py, ex, ey, width, 0.18, w.color)
		Pattern.WAVE:
			var ang2: float = pl.facing.angle() + DIR_OFFSETS[k % 8]
			var v: float = float(st.get("proj_speed", 120)) * spd
			shots.bullet(s, px, py, cos(ang2) * v, sin(ang2) * v, float(st.get("radius", 24)) * area, dmg, kb, -1, dur, ShotManager.F_ROTATE, w.color, w.sprite)
		Pattern.HOMING:
			var t: int = en.nearest(px, py, 320.0)
			var ang3: float = pl.facing.angle()
			if t >= 0:
				ang3 = atan2(en.py[t] - py, en.px[t] - px)
			ang3 += randf_range(-0.5, 0.5) + (float(k) - float(_amount(w) - 1) * 0.5) * 0.25
			var v2: float = float(st.get("proj_speed", 260)) * spd
			var b: int = shots.bullet(s, px, py, cos(ang3) * v2, sin(ang3) * v2, float(st.get("radius", 6)) * area, dmg, kb, int(st.get("pierce", 1)), dur, ShotManager.F_HOMING | ShotManager.F_ROTATE, w.color, w.sprite)
			if b >= 0:
				shots.c[b] = float(st.get("turn", 6.0))
		Pattern.CONE:
			var ang4: float = pl.facing.angle()
			var half: float = deg_to_rad(float(st.get("angle", 50))) * 0.5
			var reach: float = float(st.get("range", 130)) * area
			_hit_cone(s, px, py, ang4, half, reach, dmg, kb)
			shots.v_cone(px, py, ang4, half, reach, 0.22, w.color)
			if w.def.get("both_sides", false):
				_hit_cone(s, px, py, ang4 + PI, half, reach, dmg, kb)
				shots.v_cone(px, py, ang4 + PI, half, reach, 0.22, w.color)
		Pattern.RAIN:
			var t2: int = en.random_near(px, py, 300.0)
			var tx: float = px + randf_range(-200.0, 200.0)
			var ty: float = py + randf_range(-120.0, 120.0)
			if t2 >= 0:
				tx = en.px[t2]
				ty = en.py[t2]
			shots.strike(s, tx, ty, float(st.get("radius", 30)) * area, float(st.get("delay", 0.4)), dmg, kb, w.color, w.sprite)
		Pattern.BOUNCE:
			var t3: int = en.random_near(px, py, 300.0)
			var ang5: float = randf() * TAU
			if t3 >= 0:
				ang5 = atan2(en.py[t3] - py, en.px[t3] - px)
			var v3: float = float(st.get("proj_speed", 230)) * spd
			var fl: int = ShotManager.F_BOUNCE | ShotManager.F_ROTATE
			var splits: float = float(st.get("splits", 0))
			if splits > 0.0:
				fl |= ShotManager.F_SPLIT
			var b2: int = shots.bullet(s, px, py, cos(ang5) * v3, sin(ang5) * v3, float(st.get("radius", 7)) * area, dmg, kb, -1, dur, fl, w.color, w.sprite)
			if b2 >= 0:
				shots.d[b2] = splits
		Pattern.SLASH:
			var base_ang: float = 0.0 if pl.side > 0.0 else PI
			var ang6: float = base_ang + DIR_OFFSETS[k % 8]
			var reach2: float = float(st.get("range", 90)) * area
			var half2: float = deg_to_rad(float(st.get("angle", 110))) * 0.5
			_hit_cone(s, px, py, ang6, half2, reach2, dmg, kb)
			shots.v_slash(px, py, ang6, half2, reach2, 0.2, w.color)
		Pattern.STREAM:
			var ang7: float = pl.facing.angle() + randf_range(-0.09, 0.09)
			if w.def.get("random_dir", false):
				ang7 = randf() * TAU
			var v4: float = float(st.get("proj_speed", 380)) * spd
			shots.bullet(s, px, py, cos(ang7) * v4, sin(ang7) * v4, float(st.get("radius", 5)) * area, dmg, kb, int(st.get("pierce", 1)), dur, ShotManager.F_ROTATE, w.color, w.sprite)
		Pattern.AURA:
			var rad: float = float(st.get("radius", 55)) * area
			shots.blast(s, px, py, rad, dmg, kb)
			shots.v_ring(px, py, rad, minf(0.6, effective_period(w) * 1.1), w.color, true)
		Pattern.BOOMERANG:
			var t4: int = en.nearest(px, py, 300.0)
			var ang8: float = pl.facing.angle()
			if t4 >= 0:
				ang8 = atan2(en.py[t4] - py, en.px[t4] - px)
			ang8 += float((k + 1) / 2) * 0.35 * (1.0 if k % 2 == 1 else -1.0)
			var v5: float = float(st.get("proj_speed", 300)) * spd
			var b3: int = shots.bullet(s, px, py, cos(ang8) * v5, sin(ang8) * v5, float(st.get("radius", 11)) * area, dmg, kb, -1, dur, ShotManager.F_BOOMERANG | ShotManager.F_SPIN, w.color, w.sprite)
			if b3 >= 0:
				shots.a[b3] = 0.45
				shots.b[b3] = 950.0 * spd
		Pattern.CHAIN:
			_fire_chain(w, px, py, dmg, kb, area)
		Pattern.PUDDLE:
			var t5: int = en.random_near(px, py, 220.0)
			var zx: float = px + randf_range(-150.0, 150.0)
			var zy: float = py + randf_range(-100.0, 100.0)
			if t5 >= 0:
				zx = en.px[t5]
				zy = en.py[t5]
			shots.zone(s, zx, zy, float(st.get("radius", 38)) * area, dur, float(st.get("tick", 0.5)), dmg, kb, w.color, w.sprite)
			run.fx.burst(zx, zy, w.color, 6, 70.0)
		Pattern.LOCK:
			_fire_lock(w, px, py, dmg, kb, area)
		Pattern.LOB:
			var reach3: float = float(st.get("range", 150)) * area
			var t6: int = en.random_near(px, py, reach3)
			var lx: float
			var ly: float
			if t6 >= 0:
				lx = en.px[t6]
				ly = en.py[t6]
			else:
				var an: float = randf() * TAU
				var dist: float = reach3 * randf_range(0.4, 1.0)
				lx = px + cos(an) * dist
				ly = py + sin(an) * dist
			shots.lob(s, px, py, lx, ly, float(st.get("radius", 42)) * area, 0.7 / maxf(spd, 0.3), dmg, kb, w.color, w.sprite, int(st.get("cluster", 0)))


func _fire_orbit(w: Weapon, n: int) -> void:
	var pl: Player = run.player
	var st: Dictionary = w.st
	_remove_slot_shots(w.slot, ShotManager.Kind.ORBIT)
	var area: float = float(st.get("area", 1.0)) * pl.stat("area")
	var dmg: float = float(st.get("damage", 5)) * pl.stat("might")
	var dur: float = float(st.get("duration", 2.5)) * pl.stat("duration")
	if w.def.get("permanent", false):
		dur = effective_period(w) + 0.3
	var spin: float = float(st.get("spin", 3.2)) * float(st.get("speed", 1.0)) * pl.stat("speed")
	var rings: int = int(st.get("rings", 1))
	for ring_i: int in rings:
		var count: int = n if ring_i == 0 else maxi(2, n - 1)
		var orbit_r: float = float(st.get("orbit_radius", 60)) * area * (1.0 + 0.6 * ring_i)
		var dir: float = 1.0 if ring_i % 2 == 0 else -1.0
		for k: int in count:
			shots.orbit(w.slot, TAU * float(k) / float(count), orbit_r, float(st.get("radius", 10)) * area, dur, spin * dir, dmg, float(st.get("knockback", 0)), float(st.get("tick", 0.45)), w.color, w.sprite)


func _fire_chain(w: Weapon, px: float, py: float, dmg: float, kb: float, area: float) -> void:
	var st: Dictionary = w.st
	var starts: int = _amount(w)
	var chains: int = int(st.get("chains", 3))
	var jump: float = float(st.get("jump", 90)) * area
	var reach: float = float(st.get("range", 150)) * area
	_visited_n = 0
	for a: int in starts:
		var cx: float = px
		var cy: float = py
		var search: float = reach
		for hop: int in chains + 1:
			var t: int = _nearest_unvisited(cx, cy, search)
			if t < 0:
				break
			var tx: float = en.px[t]
			var ty: float = en.py[t]
			if _visited_n < 64:
				_visited[_visited_n] = en.uid[t]
				_visited_n += 1
			shots.v_line(cx, cy, tx, ty, 2.5, 0.22, w.color)
			shots.hit(t, w.slot, dmg, cx, cy, kb)
			if w.def.get("vacuum_on_hit", false):
				run.fx.burst(tx, ty, w.color, 2, 40.0)
			cx = tx
			cy = ty
			search = jump


func _fire_lock(w: Weapon, px: float, py: float, dmg: float, kb: float, area: float) -> void:
	var st: Dictionary = w.st
	var targets: int = _amount(w)
	var reach: float = float(st.get("range", 170)) * area
	var chains: int = int(st.get("chains", 0))
	_visited_n = 0
	for a: int in targets:
		var t: int = _nearest_unvisited(px, py, reach)
		if t < 0:
			break
		var cx: float = px
		var cy: float = py
		for hop: int in chains + 1:
			if t < 0:
				break
			var tx: float = en.px[t]
			var ty: float = en.py[t]
			if _visited_n < 64:
				_visited[_visited_n] = en.uid[t]
				_visited_n += 1
			var mx: float = (cx + tx) * 0.5 + randf_range(-8.0, 8.0)
			var my: float = (cy + ty) * 0.5 + randf_range(-8.0, 8.0)
			shots.v_line(cx, cy, mx, my, 2.0, 0.14, w.color)
			shots.v_line(mx, my, tx, ty, 2.0, 0.14, w.color)
			shots.hit(t, w.slot, dmg, cx, cy, kb)
			cx = tx
			cy = ty
			if hop < chains:
				t = _nearest_unvisited(cx, cy, 80.0 * area)


func _nearest_unvisited(x: float, y: float, r: float) -> int:
	var n: int = en.query_circle(x, y, r)
	var best: int = -1
	var best_d: float = INF
	for k: int in n:
		var i: int = en.q[k]
		if (en.flags[i] & (EnemyManager.F_PROP | EnemyManager.F_INVULN)) != 0:
			continue
		var u: int = en.uid[i]
		var seen: bool = false
		for m: int in _visited_n:
			if _visited[m] == u:
				seen = true
				break
		if seen:
			continue
		var dx: float = en.px[i] - x
		var dy: float = en.py[i] - y
		var d2: float = dx * dx + dy * dy
		if d2 < best_d:
			best_d = d2
			best = i
	return best


func _hit_segment(s: int, ax: float, ay: float, bx: float, by: float, half_w: float, dmg: float, kb: float) -> void:
	var mx: float = (ax + bx) * 0.5
	var my: float = (ay + by) * 0.5
	var abx: float = bx - ax
	var aby: float = by - ay
	var l2: float = abx * abx + aby * aby
	var n: int = en.query_circle(mx, my, sqrt(l2) * 0.5 + half_w)
	for k: int in n:
		var i: int = en.q[k]
		var t: float = clampf(((en.px[i] - ax) * abx + (en.py[i] - ay) * aby) / maxf(l2, 0.001), 0.0, 1.0)
		var cx: float = ax + abx * t - en.px[i]
		var cy: float = ay + aby * t - en.py[i]
		var rr: float = half_w + en.rad[i]
		if cx * cx + cy * cy <= rr * rr:
			shots.hit(i, s, dmg, ax, ay, kb)


func _hit_cone(s: int, px: float, py: float, ang: float, half: float, reach: float, dmg: float, kb: float) -> void:
	var dx0: float = cos(ang)
	var dy0: float = sin(ang)
	var cos_half: float = cos(half)
	var n: int = en.query_circle(px, py, reach)
	for k: int in n:
		var i: int = en.q[k]
		var dx: float = en.px[i] - px
		var dy: float = en.py[i] - py
		var d: float = sqrt(dx * dx + dy * dy)
		if d < en.rad[i] + 10.0 or (dx * dx0 + dy * dy0) >= cos_half * d:
			shots.hit(i, s, dmg, px, py, kb)
