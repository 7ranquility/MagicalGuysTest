class_name BossController
extends RefCounted
## Drives one boss or miniboss: phases by remaining HP and telegraphed attacks on the beat.
## Attack lists come from the enemy's "phases" config.

var run: Run
var en: EnemyManager
var idx: int
var uid: int
var def: Dictionary
var phases: Array = []
var phase: int = -1
var is_final: bool = false
var base_speed: float = 0.0
var _spiral_left: int = 0
var _spiral_def: Dictionary = {}
var _spiral_ang: float = 0.0
var _dash_t: float = 0.0
var _dash_warn: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_speed: float = 0.0


func _init(run_: Run, enemy_idx: int) -> void:
	run = run_
	en = run.enemies
	idx = enemy_idx
	uid = en.uid[idx]
	def = en.type_defs[en.type_idx[idx]]
	phases = def.get("phases", [])
	is_final = def.get("boss", false)
	base_speed = en.spd[idx]


func alive() -> bool:
	return en.alive[idx] != 0 and en.uid[idx] == uid


func hp_fraction() -> float:
	return clampf(en.hp[idx] / en.max_hp[idx], 0.0, 1.0) if alive() else 0.0


func display_name() -> String:
	return def.get("name", "Boss")


func update(dt: float) -> void:
	if not alive():
		return
	var frac: float = hp_fraction()
	var want: int = phase
	for k: int in phases.size():
		if frac <= float(phases[k].get("hp", 1.0)):
			want = k
	if want != phase:
		phase = want
		en.spd[idx] = base_speed * float(phases[phase].get("speed", 1.0))
		if phase > 0:
			run.fx.burst(en.px[idx], en.py[idx], Color(1, 0.3, 0.3), 30, 200.0)
			run.fx.add_shake(5.0)
			run.ebullets.clear_all()
			Audio.play("phase")
			if is_final:
				run.announce("%s: phase %d" % [display_name(), phase + 1])
				Music.set_boss_phase(phase)
	if _dash_warn > 0.0:
		_dash_warn -= dt
		if _dash_warn <= 0.0:
			_dash_t = 0.45
	elif _dash_t > 0.0:
		_dash_t -= dt
		en.px[idx] += _dash_dir.x * _dash_speed * dt
		en.py[idx] += _dash_dir.y * _dash_speed * dt


func on_step(step: int) -> void:
	if not alive() or phase < 0 or en.freeze_time > 0.0:
		return
	if _spiral_left > 0 and (step & 1) == 0:
		_spiral_left -= 1
		var arms: int = int(_spiral_def.get("arms", 2))
		run.ebullets.burst(en.px[idx], en.py[idx], arms, float(_spiral_def.get("speed", 90)), _damage(_spiral_def), _spiral_ang)
		_spiral_ang += float(_spiral_def.get("turn", 0.35))
	if (step & 3) != 0:
		return
	var beat: int = step >> 2
	for atk: Dictionary in phases[phase].get("attacks", []):
		var every: int = int(atk.get("every_beats", 8))
		if beat % every == int(atk.get("offset_beats", 0)) % every:
			_attack(atk)


func _damage(atk: Dictionary) -> float:
	return float(atk.get("damage", 10)) * run.enemy_damage_mult


func _attack(atk: Dictionary) -> void:
	var bx: float = en.px[idx]
	var by: float = en.py[idx]
	var p: Vector2 = run.player.position
	var beat_len: float = Music.step_dur * 4.0
	var warn: float = float(atk.get("warn_beats", 4)) * beat_len
	var count: int = int(atk.get("count", 1))
	match atk.get("kind", "radial"):
		"radial":
			run.ebullets.burst(bx, by, count, float(atk.get("speed", 90)), _damage(atk), randf() * TAU)
			Audio.play("boss_shot", -4.0)
		"aimed":
			var ang: float = atan2(p.y - by, p.x - bx)
			run.ebullets.burst(bx, by, count, float(atk.get("speed", 130)), _damage(atk), ang, deg_to_rad(float(atk.get("spread", 40))))
			Audio.play("boss_shot", -4.0)
		"spiral":
			_spiral_left = int(atk.get("beats", 4)) * 2
			_spiral_def = atk
		"slam":
			for k: int in count:
				var off: Vector2 = Vector2.ZERO
				if k > 0:
					off = Vector2.from_angle(randf() * TAU) * randf_range(50.0, float(atk.get("spread", 160)))
				run.hazards.add_circle(p.x + off.x, p.y + off.y, float(atk.get("radius", 60)), warn, 0.25, _damage(atk))
		"lines":
			for k: int in count:
				var a: float = randf() * PI
				var d: Vector2 = Vector2(cos(a), sin(a)) * 700.0
				var c: Vector2 = p + Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0)) * (0.0 if k == 0 else 1.0)
				run.hazards.add_line(c.x - d.x, c.y - d.y, c.x + d.x, c.y + d.y, float(atk.get("width", 22)), warn, 0.25, _damage(atk))
		"cross":
			var base: float = randf() * TAU
			for k: int in count:
				var a2: float = base + PI * float(k) / float(count)
				var d2: Vector2 = Vector2(cos(a2), sin(a2)) * 700.0
				run.hazards.add_line(bx - d2.x, by - d2.y, bx + d2.x, by + d2.y, float(atk.get("width", 24)), warn, 0.3, _damage(atk))
		"charge":
			_dash_dir = (p - Vector2(bx, by)).normalized()
			_dash_speed = float(atk.get("speed", 420))
			_dash_warn = warn
			var end: Vector2 = Vector2(bx, by) + _dash_dir * _dash_speed * 0.45
			run.hazards.add_line(bx, by, end.x, end.y, en.rad[idx] * 2.0, warn, 0.45, _damage(atk))
		"summon":
			var id: String = atk.get("enemy", "sour_note")
			var mult: float = run.waves.hp_mult()
			for k: int in count:
				var a3: float = TAU * float(k) / float(count)
				en.spawn(id, bx + cos(a3) * 50.0, by + sin(a3) * 50.0, mult)
			run.fx.burst(bx, by, Color(0.7, 0.4, 1.0), 12, 120.0)
		"field":
			for k: int in count:
				var off2: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(0.0, 180.0)
				run.hazards.add_field(p.x + off2.x, p.y + off2.y, float(atk.get("radius", 55)), float(atk.get("duration", 8)), _damage(atk), 0.5, float(atk.get("slow", 1.0)), HazardManager.STYLES.get(atk.get("style", "lava"), 2))
