class_name Run
extends Node2D
## One play session on a stage: owns the managers, runs the simulation step in a fixed
## order, and handles level-ups, chests, pausing and the end of the run.

signal ended(result: Dictionary)

enum State { PLAYING, LEVEL_UP, CHEST, PAUSED, OVER }

const OBSTACLE_CELL: float = 260.0
const PROP_DROPS: Array = [
	[PickupManager.Kind.COIN, 40], [PickupManager.Kind.COINBAG, 8], [PickupManager.Kind.FOOD, 24],
	[PickupManager.Kind.MAGNET, 9], [PickupManager.Kind.BOMB, 10], [PickupManager.Kind.FREEZE, 9],
]

var stage_id: String = ""
var stage: Dictionary = {}
var modes: Dictionary = {}
var stage_len: float = 1800.0
var time: float = 0.0
var state: int = State.PLAYING
var view_rect: Rect2 = Rect2(-384, -216, 768, 432)
var bounds_y: float = 0.0

var player: Player
var enemies: EnemyManager
var shots: ShotManager
var ebullets: EnemyBullets
var pickups: PickupManager
var hazards: HazardManager
var fx: FxManager
var decor: WorldDecor
var camera: Camera2D
var floor_sprite: Sprite2D
var weapons: WeaponSystem
var waves: WaveDirector
var bosses: Array[BossController] = []
var hud: Hud = null

var enemy_speed_mult: float = 1.0
var enemy_damage_mult: float = 1.0
var enemy_hp_mult: float = 1.0
var quantity_mult: float = 1.0
var gold_mult: float = 1.0
var reduced_flashing: bool = false

var kills: int = 0
var gold: float = 0.0
var kill_slot: int = 0
var evolutions_made: int = 0
var props_broken: int = 0
var chests_opened: int = 0
var damage_taken: float = 0.0
var bosses_killed: int = 0
var kills_by_type: PackedInt32Array = PackedInt32Array()
var banished: Dictionary = {}
var rerolls: int = 0
var skips: int = 0
var banishes: int = 0
var pending_levels: int = 0
var pending_chests: Array[int] = []
var options: Array[Dictionary] = []
var chest_rewards: Array[Dictionary] = []
var won: bool = false
var relics_found: Array[String] = []
## Bot hook: receives the option list, returns the index to take.
var auto_pick: Callable = Callable()

var _last_step: int = 0
var _victory_t: float = -1.0
var _intensity_t: float = 0.0
var _obstacles: Dictionary = {}
var _has_obstacles: bool = false
var _obstacle_density: float = 0.0
var _obstacle_radius: float = 16.0
var _stage_seed: int = 0
var _kill_fx_budget: int = 0
var _idle_reported: bool = false
var _chest_count: int = 0


func _ready() -> void:
	stage_id = Game.run_stage
	stage = Content.stages[stage_id]
	modes = Game.run_modes.duplicate()
	stage_len = Game.stage_minutes() * 60.0
	bounds_y = float(stage.get("bounds_y", 0.0))
	reduced_flashing = bool(Save.setting("reduced_flashing"))
	_stage_seed = hash(stage_id)
	var obs: Dictionary = stage.get("obstacles", {})
	_obstacle_density = float(obs.get("density", 0.0))
	_obstacle_radius = float(obs.get("radius", 16.0))
	_has_obstacles = _obstacle_density > 0.0

	floor_sprite = Sprite2D.new()
	floor_sprite.texture = load(stage.get("floor", "res://assets/world/BG.png"))
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.region_enabled = true
	floor_sprite.scale = Vector2.ONE * float(stage.get("floor_scale", 1.0))
	floor_sprite.modulate = Color.html(stage.get("floor_tint", "#ffffff"))
	add_child(floor_sprite)

	decor = WorldDecor.new()
	hazards = HazardManager.new()
	pickups = PickupManager.new()
	enemies = EnemyManager.new()
	player = Player.new()
	shots = ShotManager.new()
	ebullets = EnemyBullets.new()
	fx = FxManager.new()
	for node: Node in [decor, hazards, pickups, enemies, player, shots, ebullets, fx]:
		node.set("run", self)
		add_child(node)
	shots.en = enemies
	kills_by_type.resize(enemies.type_ids.size())

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	_apply_modes()
	var arc: Dictionary = Content.arcana.get(Game.run_arcana, {})
	player.bonus = (arc.get("bonus", {}) as Dictionary).duplicate()
	player.setup(Game.run_character)
	rerolls = int(player.stat("reroll"))
	skips = int(player.stat("skip"))
	banishes = int(player.stat("banish"))
	_apply_curse()

	Music.start_stage(stage_id, modes.get("hyper", false))
	_last_step = Music.step
	weapons = WeaponSystem.new(self)
	waves = WaveDirector.new(self)
	hazards.setup(stage)
	weapons.add(player.def.get("instrument", "guitar"))
	for extra: String in arc.get("start_passives", []):
		player.passives[extra] = 1
	if not player.passives.is_empty():
		player.recompute_stats()
		weapons.refresh()
	for relic: Dictionary in stage.get("relics", []):
		if not Save.has_achievement(relic.get("achievement", "")):
			var rp: Array = relic.get("pos", [0, -900])
			pickups.add(PickupManager.Kind.RELIC, float(rp[0]), float(rp[1]), float(stage.get("relics", []).find(relic)))
	if not Game.headless:
		hud = Hud.new()
		hud.run = self
		add_child(hud)
	_update_view()
	Save.add_stat("runs", 1)
	Game.event("run_start", {"stage": stage_id, "character": Game.run_character})


func _apply_modes() -> void:
	if modes.get("hyper", false):
		enemy_speed_mult *= 1.3
		gold_mult *= 1.5
		quantity_mult *= 1.15
	if modes.get("hurry", false):
		gold_mult *= 0.75
	if modes.get("endless", false):
		gold_mult *= 1.1
	enemy_hp_mult *= float(stage.get("hp_mult", 1.0))
	enemy_damage_mult *= float(stage.get("damage_mult", 1.0))


func _apply_curse() -> void:
	var curse: float = maxf(player.stat("curse"), 0.5)
	quantity_mult *= curse
	enemy_hp_mult *= 1.0 + (curse - 1.0)
	enemy_speed_mult *= 1.0 + (curse - 1.0) * 0.5


# --- main loop -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Game.headless:
		return
	if state == State.PLAYING:
		sim_step(minf(delta, 0.05))
	else:
		_last_step = Music.step
		fx.update(0.0)
	_update_view()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			set_paused(true)
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			set_paused(false)
			get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	if p and state == State.PLAYING:
		state = State.PAUSED
		Music.set_paused_filter(true)
		if hud:
			hud.show_pause()
	elif not p and state == State.PAUSED:
		state = State.PLAYING
		Music.set_paused_filter(false)
		if hud:
			hud.hide_menus()


## Advances the whole simulation by dt seconds.
func sim_step(dt: float) -> void:
	time += dt
	if Music.virtual:
		Music.advance(dt)
	player.update(dt)
	view_rect.position = player.position - view_rect.size * 0.5
	var step: int = Music.step
	if step != _last_step:
		for s: int in range(maxi(_last_step + 1, step - 3), step + 1):
			weapons.on_step(s)
			hazards.on_step(s)
			for b: BossController in bosses:
				b.on_step(s)
		_last_step = step
	weapons.update(dt)
	waves.update(dt)
	_kill_fx_budget = 8
	enemies.update(dt)
	if _has_obstacles:
		_push_enemies_out_of_obstacles()
	shots.update(dt)
	ebullets.update(dt)
	hazards.update(dt)
	var bi: int = bosses.size() - 1
	while bi >= 0:
		if bosses[bi].alive():
			bosses[bi].update(dt)
		else:
			bosses.remove_at(bi)
		bi -= 1
	pickups.update(dt)
	fx.update(dt)
	_intensity_t -= dt
	if _intensity_t <= 0.0:
		_intensity_t = 0.25
		_update_intensity()
	if player.idle_time > 33.0 and not _idle_reported:
		_idle_reported = true
		Game.event("idle", {"seconds": 33})
	if _victory_t >= 0.0:
		_victory_t -= dt
		if _victory_t < 0.0:
			_finish(true)
			return
	if player.hp <= 0.0:
		_on_player_down()
		if state == State.OVER:
			return
	while state == State.PLAYING and not pending_chests.is_empty():
		_open_chest(pending_chests.pop_front())
	while state == State.PLAYING and pending_levels > 0:
		_open_level_up()


func _update_view() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var scale_f: float = get_tree().root.content_scale_factor if is_inside_tree() else 1.0
	var zoom: float = Game.WORLD_ZOOM / maxf(scale_f, 0.1)
	var size: Vector2 = vp / zoom
	var shake_off: Vector2 = Vector2.ZERO
	if fx.shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fx.shake
	camera.zoom = Vector2(zoom, zoom)
	camera.position = (player.position + shake_off).round()
	view_rect = Rect2(player.position - size * 0.5, size)
	var fs: float = floor_sprite.scale.x
	floor_sprite.position = camera.position
	floor_sprite.region_rect = Rect2(camera.position / fs - (size / fs) * 0.5 - Vector2(8, 8), size / fs + Vector2(16, 16))


func _update_intensity() -> void:
	var density: float = clampf(float(enemies.hostile_count) / 260.0, 0.0, 1.0)
	var boss_on: bool = waves.boss_spawned and not waves.boss_defeated
	var v: float = clampf(density * 0.75 + (0.35 if boss_on else 0.0) + minf(0.15, time / stage_len * 0.15), 0.0, 1.0)
	Music.set_intensity(v, player.hp < player.max_hp * 0.3)


# --- world helpers -------------------------------------------------------------------------

## A point just outside the view where enemies may appear.
func spawn_point(margin: float = 36.0) -> Vector2:
	var half: Vector2 = view_rect.size * 0.5 + Vector2(margin, margin)
	var c: Vector2 = player.position
	var p: Vector2
	if bounds_y > 0.0:
		p = Vector2(c.x + (half.x if randf() < 0.5 else -half.x) + randf_range(-20.0, 20.0), randf_range(-bounds_y, bounds_y))
		return p
	var side: int = randi() % 4
	match side:
		0:
			p = Vector2(c.x + randf_range(-half.x, half.x), c.y - half.y)
		1:
			p = Vector2(c.x + randf_range(-half.x, half.x), c.y + half.y)
		2:
			p = Vector2(c.x - half.x, c.y + randf_range(-half.y, half.y))
		_:
			p = Vector2(c.x + half.x, c.y + randf_range(-half.y, half.y))
	return p


func clamp_to_bounds(p: Vector2) -> Vector2:
	if bounds_y > 0.0:
		p.y = clampf(p.y, -bounds_y, bounds_y)
	return p


## Obstacle in grid cell (cx, cy) as Vector3(x, y, radius); radius 0 means none.
func obstacle_at(cx: int, cy: int) -> Vector3:
	var key: Vector2i = Vector2i(cx, cy)
	if _obstacles.has(key):
		return _obstacles[key]
	var out: Vector3 = Vector3.ZERO
	if not (cx == 0 and cy == 0) and not (cx == -1 and cy == 0) and not (cx == 0 and cy == -1) and not (cx == -1 and cy == -1):
		var seed_: int = (cx * 73856093) ^ (cy * 19349663) ^ _stage_seed
		var r1: Array = rand_from_seed(seed_)
		if float(r1[0] % 10000) / 10000.0 < _obstacle_density:
			var r2: Array = rand_from_seed(r1[1])
			var r3: Array = rand_from_seed(r2[1])
			var span: float = OBSTACLE_CELL * 0.5 - _obstacle_radius - 24.0
			var ox: float = (float(r2[0] % 10000) / 5000.0 - 1.0) * span
			var oy: float = (float(r3[0] % 10000) / 5000.0 - 1.0) * span
			out = Vector3((cx + 0.5) * OBSTACLE_CELL + ox, (cy + 0.5) * OBSTACLE_CELL + oy, _obstacle_radius)
			if bounds_y > 0.0 and absf(out.y) > bounds_y - 20.0:
				out = Vector3.ZERO
	_obstacles[key] = out
	return out


func resolve_obstacles(p: Vector2, r: float) -> Vector2:
	if bounds_y > 0.0:
		p.y = clampf(p.y, -bounds_y + r, bounds_y - r)
	if not _has_obstacles:
		return p
	var o: Vector3 = obstacle_at(floori(p.x / OBSTACLE_CELL), floori(p.y / OBSTACLE_CELL))
	if o.z > 0.0:
		var dx: float = p.x - o.x
		var dy: float = p.y - o.y
		var rr: float = o.z + r
		var d2: float = dx * dx + dy * dy
		if d2 < rr * rr and d2 > 0.0001:
			var d: float = sqrt(d2)
			p.x = o.x + dx / d * rr
			p.y = o.y + dy / d * rr
	return p


func _push_enemies_out_of_obstacles() -> void:
	var en: EnemyManager = enemies
	var inv: float = 1.0 / OBSTACLE_CELL
	var last_cx: int = 1 << 30
	var last_cy: int = 1 << 30
	var o: Vector3 = Vector3.ZERO
	for i: int in en.hw:
		if en.alive[i] == 0 or (en.flags[i] & (EnemyManager.F_FLYER | EnemyManager.F_PROP)) != 0:
			continue
		var x: float = en.px[i]
		var y: float = en.py[i]
		var cx: int = floori(x * inv)
		var cy: int = floori(y * inv)
		if cx != last_cx or cy != last_cy:
			last_cx = cx
			last_cy = cy
			o = obstacle_at(cx, cy)
		if o.z > 0.0:
			var dx: float = x - o.x
			var dy: float = y - o.y
			var rr: float = o.z + en.rad[i] * 0.7
			var d2: float = dx * dx + dy * dy
			if d2 < rr * rr and d2 > 0.0001:
				var d: float = sqrt(d2)
				en.px[i] = o.x + dx / d * rr
				en.py[i] = o.y + dy / d * rr


func announce(text: String) -> void:
	if hud:
		hud.banner(text)


# --- combat callbacks ----------------------------------------------------------------------

func record_damage(slot: int, amount: float, x: float, y: float) -> void:
	weapons.slot_damage[slot] += amount
	fx.number(x, y, amount)


## Called by EnemyManager.kill. Must not run spatial queries (callers iterate query results).
func on_enemy_killed(i: int) -> void:
	var en: EnemyManager = enemies
	var f: int = en.flags[i]
	var x: float = en.px[i]
	var y: float = en.py[i]
	var t: int = en.type_idx[i]
	var def: Dictionary = en.type_defs[t]
	if (f & EnemyManager.F_PROP) != 0:
		props_broken += 1
		_drop_from_table(x, y)
		fx.burst(x, y, Color(1.0, 0.9, 0.5), 8, 90.0)
		Audio.play("break", -4.0)
		if props_broken == 100:
			Game.event("props", {"count": 100})
		return
	kills += 1
	kills_by_type[t] += 1
	var xp: float = float(def.get("xp", 1))
	if (f & EnemyManager.F_ELITE) != 0:
		xp *= 12.0
	pickups.add(PickupManager.Kind.GEM, x, y, xp)
	var luck: float = player.stat("luck")
	var roll: float = randf()
	if roll < 0.022 * luck:
		pickups.add(PickupManager.Kind.COIN, x + 6.0, y, 1.0)
	elif roll < 0.022 * luck + 0.0035:
		pickups.add(PickupManager.Kind.FOOD, x + 6.0, y)
	if (f & EnemyManager.F_BOSS) != 0:
		_on_boss_killed(def, x, y)
	elif (f & EnemyManager.F_ELITE) != 0:
		pickups.add(PickupManager.Kind.CHEST, x, y, 0.0)
		fx.burst(x, y, Color(1.0, 0.85, 0.3), 20, 160.0)
		fx.add_shake(3.0)
	if def.has("split_into"):
		var mult: float = waves.hp_mult()
		for k: int in int(def.get("split_count", 2)):
			en.spawn(def["split_into"], x + randf_range(-10.0, 10.0), y + randf_range(-10.0, 10.0), mult)
	var owner_w: WeaponSystem.Weapon = weapons._slot_owner[kill_slot] if kill_slot < EnemyManager.SLOTS - 1 else null
	if owner_w != null:
		var wd: Dictionary = owner_w.def
		if wd.has("lifesteal") and randf() < float(wd["lifesteal"]):
			player.heal(1.0)
		if wd.has("gold_on_kill") and randf() < float(wd["gold_on_kill"]):
			pickups.add(PickupManager.Kind.COIN, x, y - 6.0, 1.0)
	if _kill_fx_budget > 0:
		_kill_fx_budget -= 1
		fx.burst(x, y, Color(0.85, 0.9, 1.0), 4, 70.0)
		Audio.play("kill", -10.0)


func _drop_from_table(x: float, y: float) -> void:
	var total: int = 0
	for e: Array in PROP_DROPS:
		total += int(e[1])
	var roll: int = randi() % total
	for e2: Array in PROP_DROPS:
		roll -= int(e2[1])
		if roll < 0:
			var val: float = 10.0 if e2[0] == PickupManager.Kind.COINBAG else 1.0
			pickups.add(e2[0], x, y, val)
			return


func player_hit(amount: float, enemy_idx: int) -> void:
	var taken: float = player.take_hit(amount)
	if taken <= 0.0:
		return
	damage_taken += taken
	fx.add_shake(3.0)
	fx.burst(player.position.x, player.position.y, Color(1.0, 0.3, 0.3), 6, 90.0)
	Audio.play("hurt")
	if hud:
		hud.flash_damage()
	if enemy_idx >= 0 and enemies.type_defs[enemies.type_idx[enemy_idx]].get("muffles", false):
		Music.muffle(2.5)


func on_pickup(kind: int, value: float, x: float, y: float) -> void:
	match kind:
		PickupManager.Kind.GEM:
			gain_xp(value * player.stat("growth"))
			Audio.play_gem()
		PickupManager.Kind.COIN, PickupManager.Kind.COINBAG:
			add_gold(value)
			Audio.play("coin", -6.0)
		PickupManager.Kind.FOOD:
			player.heal(30.0)
			fx.text(x, y, "+30", Color(0.5, 1.0, 0.5))
			Audio.play("heal")
		PickupManager.Kind.MAGNET:
			pickups.vacuum()
			Audio.play("magnet")
		PickupManager.Kind.BOMB:
			_screen_clear()
		PickupManager.Kind.FREEZE:
			enemies.freeze_time = 8.0
			fx.shockwave(x, y, 300.0, Color(0.6, 0.9, 1.0))
			Audio.play("freeze")
		PickupManager.Kind.CHEST:
			pending_chests.append(_roll_chest_count())
		PickupManager.Kind.RELIC:
			var relics: Array = stage.get("relics", [])
			var ri: int = int(value)
			if ri < relics.size():
				var relic: Dictionary = relics[ri]
				relics_found.append(relic.get("id", ""))
				announce(relic.get("text", "You found something..."))
				Game.event("relic", {"id": relic.get("id", "")})
				Audio.play("fanfare")


func _roll_chest_count() -> int:
	_chest_count += 1
	var luck: float = player.stat("luck")
	var roll: float = randf()
	if _chest_count == 1:
		return 1
	if roll < 0.04 * luck:
		return 5
	if roll < 0.22 * luck:
		return 3
	return 1


func _screen_clear() -> void:
	var en: EnemyManager = enemies
	var area: Rect2 = view_rect.grow(30.0)
	kill_slot = EnemyManager.SLOTS - 1
	for i: int in en.hw:
		if en.alive[i] == 0 or not area.has_point(Vector2(en.px[i], en.py[i])):
			continue
		if (en.flags[i] & (EnemyManager.F_BOSS | EnemyManager.F_ELITE)) != 0:
			en.hurt(i, en.max_hp[i] * 0.12, EnemyManager.SLOTS - 1, player.position.x, player.position.y, 0.0)
		else:
			en.kill(i)
	ebullets.clear_all()
	fx.shockwave(player.position.x, player.position.y, 420.0, Color.WHITE)
	fx.add_shake(6.0)
	Audio.play("boom")
	if hud:
		hud.flash_screen()


func add_gold(amount: float) -> void:
	gold += amount * player.stat("greed") * gold_mult


func xp_for_level(level: int) -> float:
	if level < 20:
		return 5.0 + (level - 1) * 10.0
	if level < 40:
		return 195.0 + (level - 20) * 13.0
	return 455.0 + (level - 40) * 16.0


func gain_xp(amount: float) -> void:
	player.xp += amount
	while player.xp >= player.xp_next:
		player.xp -= player.xp_next
		player.level += 1
		player.xp_next = xp_for_level(player.level)
		pending_levels += 1
		if not player.def.get("level_bonus", {}).is_empty():
			player.recompute_stats()
			weapons.refresh()


func on_weapons_changed() -> void:
	Music.set_instrument_layers(weapons.layers())
	if hud:
		hud.rebuild_inventory()


func add_boss_controller(enemy_idx: int) -> void:
	bosses.append(BossController.new(self, enemy_idx))


func on_boss_spawned(enemy_idx: int) -> void:
	var def: Dictionary = enemies.type_defs[enemies.type_idx[enemy_idx]]
	announce(def.get("name", "Boss") + " takes the stage!")
	Music.set_boss(true)
	Audio.play("boss_intro")
	fx.add_shake(6.0)


func _on_boss_killed(def: Dictionary, x: float, y: float) -> void:
	bosses_killed += 1
	Save.add_stat("bosses", 1)
	if not def.get("boss", false):
		pickups.add(PickupManager.Kind.CHEST, x, y, 0.0)
		return
	waves.boss_defeated = true
	Music.set_boss(false)
	fx.burst(x, y, Color(1.0, 0.9, 0.4), 60, 260.0)
	fx.add_shake(10.0)
	for k: int in 12:
		pickups.add(PickupManager.Kind.COINBAG, x + randf_range(-40.0, 40.0), y + randf_range(-40.0, 40.0), 10.0)
	Game.event("boss_kill", {"id": def.get("id", ""), "stage": stage_id})
	if modes.get("endless", false):
		pickups.add(PickupManager.Kind.CHEST, x, y, 0.0)
		announce("Encore! The show goes on...")
	else:
		_victory_t = 2.2
		player.god_mode = true
		announce("STAGE CLEAR!")
		Audio.play("fanfare")


# --- level up / chest ----------------------------------------------------------------------

func _open_level_up() -> void:
	options = LevelUp.roll(self)
	if auto_pick.is_valid():
		choose_option(clampi(int(auto_pick.call(options)), 0, options.size() - 1))
		return
	state = State.LEVEL_UP
	Audio.play("levelup")
	if hud:
		hud.show_level_up()
	else:
		choose_option(0)


func choose_option(index: int) -> void:
	LevelUp.apply(self, options[index])
	pending_levels = maxi(0, pending_levels - 1)
	_resume()


func reroll_options() -> void:
	if rerolls > 0 and state == State.LEVEL_UP:
		rerolls -= 1
		options = LevelUp.roll(self)
		if hud:
			hud.show_level_up()


func skip_level() -> void:
	if skips > 0 and state == State.LEVEL_UP:
		skips -= 1
		pending_levels = maxi(0, pending_levels - 1)
		_resume()


func banish_option(index: int) -> void:
	if banishes > 0 and state == State.LEVEL_UP and options[index]["kind"] in ["instrument", "passive"]:
		banishes -= 1
		banished[options[index]["id"]] = true
		options = LevelUp.roll(self)
		if hud:
			hud.show_level_up()


func _open_chest(count: int) -> void:
	chests_opened += 1
	Save.add_stat("chests", 1)
	chest_rewards = LevelUp.chest(self, count)
	for opt: Dictionary in chest_rewards:
		LevelUp.apply(self, opt)
	add_gold(randf_range(20.0, 45.0) * count)
	if auto_pick.is_valid() or hud == null:
		return
	state = State.CHEST
	Audio.play("fanfare")
	hud.show_chest()


func close_chest() -> void:
	if state == State.CHEST:
		_resume()


func _resume() -> void:
	state = State.PLAYING
	_last_step = Music.step
	if hud:
		hud.hide_menus()


# --- end of run ----------------------------------------------------------------------------

func _on_player_down() -> void:
	if player.revives_left > 0:
		player.revives_left -= 1
		player.hp = player.max_hp * 0.5
		player.invuln = 2.5
		_screen_clear()
		announce("Encore! (revived)")
		Audio.play("revive")
		return
	_finish(false)


func give_up() -> void:
	if state != State.OVER:
		_finish(false)


func _finish(victory: bool) -> void:
	state = State.OVER
	won = victory
	var total_gold: int = int(round(gold)) + int(kills / 40) + (150 if victory else 0)
	var kills_map: Dictionary = {}
	for t: int in kills_by_type.size():
		if kills_by_type[t] > 0:
			kills_map[enemies.type_ids[t]] = kills_by_type[t]
			Save.add_kills(enemies.type_ids[t], kills_by_type[t])
			Save.discover("enemies", enemies.type_ids[t])
	var build: Array = []
	for w: WeaponSystem.Weapon in weapons.weapons:
		build.append({"id": w.id, "level": w.level})
	var mode_key: String = "normal"
	for m: String in Game.MODES:
		if modes.get(m, false):
			mode_key = m
	var result: Dictionary = {
		"won": victory, "stage": stage_id, "character": Game.run_character, "modes": modes,
		"mode": mode_key, "time": time, "kills": kills, "level": player.level, "gold": total_gold,
		"damage": weapons.damage_report(), "kills_by_type": kills_map, "build": build,
		"passives": player.passives.duplicate(), "evolutions": evolutions_made,
		"props": props_broken, "chests": chests_opened, "damage_taken": damage_taken,
		"minutes": time / 60.0, "ref_minutes": time / stage_len * 30.0, "bosses": bosses_killed,
		"arcana": Game.run_arcana, "new_unlocks": [],
	}
	Save.add_gold(total_gold)
	Save.add_stat("kills", kills)
	Save.add_stat("time_played", time)
	Save.add_stat("props_broken", props_broken)
	Save.add_stat("wins" if victory else "deaths", 1)
	Save.max_stat("max_level", player.level)
	if victory:
		Save.mark_clear(stage_id, mode_key)
		Save.mark_clear(stage_id, "normal")
	Save.data["last"] = {"character": Game.run_character, "stage": stage_id, "arcana": Game.run_arcana}
	var before: Dictionary = Save.data["achievements"].duplicate()
	Game.event("run_end", result)
	for id: String in Save.data["achievements"]:
		if not before.has(id):
			result["new_unlocks"].append(id)
	Save.save_game()
	Game.last_result = result
	Music.end_run(victory)
	ended.emit(result)
