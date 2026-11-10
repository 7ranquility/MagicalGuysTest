extends Node
## Headless playtest: a simple bot plays one run as fast as the CPU allows.
## godot --headless --path . -- --tool=bot [minutes=5]

func _ready() -> void:
	var minutes: float = 5.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("minutes="):
			minutes = float(arg.substr(8))
	Save.set_setting("stage_minutes", minutes)
	var run: Run = Run.new()
	add_child(run)
	run.auto_pick = func(_opts: Array) -> int: return 0
	run.player.use_external_move = true
	var t0: int = Time.get_ticks_msec()
	var steps: int = 0
	var worst: int = 0
	var peak: int = 0
	while run.state != Run.State.OVER and run.time < minutes * 60.0 + 180.0:
		run.player.external_move = _steer(run)
		var u0: int = Time.get_ticks_usec()
		run.sim_step(1.0 / 60.0)
		worst = maxi(worst, Time.get_ticks_usec() - u0)
		peak = maxi(peak, run.enemies.hostile_count)
		steps += 1
	var build: PackedStringArray = []
	for w: WeaponSystem.Weapon in run.weapons.weapons:
		build.append("%s:%d" % [w.id, w.level])
	print("BOT won=%s time=%s level=%d kills=%d gold=%d peak_enemies=%d steps=%d avg_ms=%.2f worst_ms=%.1f" % [
		run.won, UiKit.format_time(run.time), run.player.level, run.kills, int(run.gold), peak, steps,
		float(Time.get_ticks_msec() - t0) / maxf(steps, 1), worst / 1000.0])
	print("BUILD ", ", ".join(build), "  passives ", run.player.passives)
	get_tree().quit()


func _steer(run: Run) -> Vector2:
	var en: EnemyManager = run.enemies
	var p: Vector2 = run.player.position
	var away: Vector2 = Vector2.ZERO
	var n: int = en.query_circle(p.x, p.y, 48.0)
	for k: int in n:
		var i: int = en.q[k]
		var d: Vector2 = p - Vector2(en.px[i], en.py[i])
		away += d / maxf(d.length_squared(), 1.0)
	if away.length() > 0.0001:
		return away.normalized()
	var pk: PickupManager = run.pickups
	var best: float = 250.0 * 250.0
	var to: Vector2 = Vector2.ZERO
	for i2: int in pk.n:
		var d2: Vector2 = Vector2(pk.x[i2], pk.y[i2]) - p
		if d2.length_squared() < best:
			best = d2.length_squared()
			to = d2
	return to.normalized()
