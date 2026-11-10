class_name WaveDirector
extends RefCounted
## Spawns enemies from the stage timeline: continuous waves that scale over time plus
## scripted events (swarms, rings, walls, elites, minibosses, the final boss) and the
## destructible light sources.
##
## Timeline times in stage config are minutes on a 30 minute reference scale; they are
## stretched to the configured stage length.

var run: Run
var en: EnemyManager
var stage: Dictionary
var waves: Array = []
var events: Array = []
var _wave_i: int = -1
var _event_i: int = 0
var _spawn_t: float = 0.0
var _fill_t: float = 0.0
var _prop_t: float = 6.0
var boss_spawned: bool = false
var boss_defeated: bool = false
var loop_count: int = 0
## Offset added when the timeline wraps in endless mode (reference minutes).
var _ref_offset: float = 0.0


func _init(run_: Run) -> void:
	run = run_
	en = run.enemies
	stage = run.stage
	waves = stage.get("waves", [])
	events = (stage.get("events", []) as Array).duplicate()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## Current position on the 30 minute reference timeline.
func ref_minutes() -> float:
	return run.time / run.stage_len * 30.0 - _ref_offset


func hp_mult() -> float:
	var m: float = ref_minutes() + loop_count * 30.0
	return (1.0 + m * float(stage.get("hp_growth", 0.06))) * run.enemy_hp_mult * (1.0 + loop_count * 1.5)


func update(dt: float) -> void:
	var m: float = ref_minutes()
	while _wave_i + 1 < waves.size() and float(waves[_wave_i + 1]["t"]) <= m:
		_wave_i += 1
		_spawn_t = 0.0
	while _event_i < events.size() and float(events[_event_i]["t"]) <= m:
		_run_event(events[_event_i])
		_event_i += 1
	if _wave_i >= 0:
		var w: Dictionary = waves[_wave_i]
		var cap: int = int(float(w.get("max", 320)) * run.quantity_mult)
		var boss_alive: bool = boss_spawned and not boss_defeated
		if boss_alive:
			cap = int(cap * 0.35)
		_spawn_t -= dt
		if _spawn_t <= 0.0:
			_spawn_t = float(w.get("interval", 1.0)) / run.quantity_mult
			if en.hostile_count < cap:
				_spawn_batch(w, int(w.get("batch", 2)))
		var minimum: int = int(float(w.get("min", 10)) * run.quantity_mult * (0.4 if boss_alive else 1.0))
		_fill_t -= dt
		if en.hostile_count < minimum and _fill_t <= 0.0:
			_fill_t = 0.12
			_spawn_batch(w, mini(4, minimum - en.hostile_count))
	_prop_t -= dt
	if _prop_t <= 0.0:
		_prop_t = float(stage.get("prop_interval", 11.0))
		var prop_id: String = stage.get("prop", "")
		if prop_id != "" and Content.enemies.has(prop_id):
			var p: Vector2 = run.spawn_point(60.0)
			en.spawn(prop_id, p.x, p.y)
	if run.modes.get("endless", false) and boss_defeated and m >= 30.0:
		_ref_offset += 30.0 - float(stage.get("endless_restart", 12.0))
		loop_count += 1
		_wave_i = -1
		_event_i = 0
		boss_spawned = false
		boss_defeated = false
		run.announce("LOOP %d" % (loop_count + 1))


func _spawn_batch(w: Dictionary, n: int) -> void:
	var list: Array = w.get("enemies", [])
	if list.is_empty():
		return
	var mult: float = hp_mult()
	for k: int in n:
		var p: Vector2 = run.spawn_point()
		en.spawn(list[randi() % list.size()], p.x, p.y, mult)


func _run_event(ev: Dictionary) -> void:
	var id: String = ev.get("enemy", "")
	var count: int = int(float(ev.get("count", 1)) * run.quantity_mult)
	var mult: float = hp_mult() * float(ev.get("hp_mult", 1.0))
	var p: Vector2 = run.player.position
	match ev.get("kind", "swarm"):
		"swarm":
			var ang: float = randf() * TAU
			if run.bounds_y > 0.0:
				ang = 0.0 if randf() < 0.5 else PI
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			var side: Vector2 = Vector2(-dir.y, dir.x)
			var start: Vector2 = p - dir * 560.0
			var cols: int = maxi(1, int(sqrt(float(count)) * 1.5))
			for k: int in count:
				var off: Vector2 = side * ((k % cols) - cols * 0.5) * 22.0 - dir * float(k / cols) * 22.0
				var i: int = en.spawn(id, start.x + off.x, start.y + off.y, mult)
				if i >= 0:
					en.ai[i] = EnemyManager.Ai.SWEEP
					en.flags[i] |= EnemyManager.F_NO_RELOCATE | EnemyManager.F_FLYER
					en.dirx[i] = dir.x
					en.diry[i] = dir.y
					en.spd[i] *= 1.6
					en.st[i] = 0.0
					en.pa[i] = 1300.0 / maxf(en.spd[i], 1.0)
		"ring":
			var radius: float = float(ev.get("radius", 430))
			for k: int in count:
				var a: float = TAU * float(k) / float(count)
				var q: Vector2 = run.clamp_to_bounds(p + Vector2(cos(a), sin(a) * 0.7) * radius)
				var i2: int = en.spawn(id, q.x, q.y, mult)
				if i2 >= 0:
					en.flags[i2] |= EnemyManager.F_NO_RELOCATE
		"wall":
			var horizontal: bool = randf() < 0.5 or run.bounds_y > 0.0
			var sgn: float = 1.0 if randf() < 0.5 else -1.0
			for k: int in count:
				var u: float = (float(k) / float(maxi(count - 1, 1)) - 0.5)
				var q2: Vector2
				if horizontal:
					q2 = p + Vector2(sgn * 520.0, u * 520.0)
				else:
					q2 = p + Vector2(u * 900.0, sgn * 330.0)
				q2 = run.clamp_to_bounds(q2)
				en.spawn(id, q2.x, q2.y, mult)
		"elite":
			for k: int in count:
				var q3: Vector2 = run.spawn_point()
				en.spawn(id, q3.x, q3.y, mult, true)
			run.announce(ev.get("text", "An elite approaches"))
		"miniboss":
			var q4: Vector2 = run.spawn_point()
			var i4: int = en.spawn(id, q4.x, q4.y, mult, true)
			if i4 >= 0:
				en.flags[i4] |= EnemyManager.F_NO_RELOCATE
				run.add_boss_controller(i4)
			run.announce(ev.get("text", Content.enemies[id].get("name", "Miniboss") + " appears"))
		"boss":
			var q5: Vector2 = run.clamp_to_bounds(p + Vector2(0, -260))
			var i5: int = en.spawn(id, q5.x, q5.y, run.enemy_hp_mult * (1.0 + loop_count * 2.0) * float(ev.get("hp_mult", 1.0)))
			if i5 >= 0:
				boss_spawned = true
				run.add_boss_controller(i5)
				run.on_boss_spawned(i5)
