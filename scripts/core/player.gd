class_name Player
extends Node2D
## The musician. Movement only; all attacks come from WeaponSystem.

const BASE_STATS: Dictionary = {
	"max_hp": 1.0, "recovery": 0.0, "armor": 0.0, "move_speed": 1.0, "might": 1.0,
	"area": 1.0, "speed": 1.0, "duration": 1.0, "amount": 0.0, "cooldown": 1.0,
	"luck": 1.0, "growth": 1.0, "greed": 1.0, "curse": 1.0, "magnet": 1.0,
	"revival": 0.0, "reroll": 0.0, "skip": 0.0, "banish": 0.0,
}

var run: Run
var def: Dictionary = {}
var stats: Dictionary = {}
var passives: Dictionary = {}
var radius: float = 8.0
var hp: float = 100.0
var max_hp: float = 100.0
var level: int = 1
var xp: float = 0.0
var xp_next: float = 5.0
var revives_left: int = 0
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT
var side: float = 1.0
var magnet_radius: float = 42.0
var hazard_slow: float = 1.0
var invuln: float = 0.0
var god_mode: bool = false
var idle_time: float = 0.0
## Extra stat modifiers from arcana and temporary effects.
var bonus: Dictionary = {}
## Stat modifiers granted by equipped instruments (e.g. Hallelujah's healing).
var weapon_bonus: Dictionary = {}
## Movement override used by the headless bot and the touch stick.
var external_move: Vector2 = Vector2.ZERO
var use_external_move: bool = false

var _frames: Array[Rect2] = []
var _anim: float = 0.0
var _hurt_flash: float = 0.0
var _recovery_acc: float = 0.0


func setup(character_id: String) -> void:
	def = Content.characters.get(character_id, {})
	var sprite: String = def.get("sprite", "char_froguitar")
	_frames.clear()
	var k: int = 0
	while Atlas.has("%s_%d" % [sprite, k]):
		_frames.append(Atlas.rect("%s_%d" % [sprite, k]))
		k += 1
	if _frames.is_empty():
		_frames.append(Atlas.rect("ui_unknown"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	recompute_stats()
	hp = max_hp
	revives_left = int(stats["revival"])


func recompute_stats() -> void:
	var s: Dictionary = BASE_STATS.duplicate()
	for key: String in def.get("stats", {}):
		s[key] = float(s.get(key, 0.0)) + float(def["stats"][key])
	for id: String in Content.shop:
		var lvl: int = Save.powerup_level(id)
		if lvl > 0:
			var item: Dictionary = Content.shop[id]
			s[item["stat"]] = float(s.get(item["stat"], 0.0)) + float(item["per_level"]) * lvl
	for id: String in passives:
		var p: Dictionary = Content.passives[id]
		for key: String in p.get("stats", {}):
			s[key] = float(s.get(key, 0.0)) + float(p["stats"][key]) * int(passives[id])
	for key: String in bonus:
		s[key] = float(s.get(key, 0.0)) + float(bonus[key])
	for key: String in weapon_bonus:
		s[key] = float(s.get(key, 0.0)) + float(weapon_bonus[key])
	var growth: Dictionary = def.get("level_bonus", {})
	if not growth.is_empty():
		var steps: int = mini(level / int(growth.get("every", 10)), int(growth.get("max", 5)))
		s[growth["stat"]] = float(s.get(growth["stat"], 0.0)) + float(growth["amount"]) * steps
	s["cooldown"] = maxf(0.35, float(s["cooldown"]))
	s["move_speed"] = maxf(0.3, float(s["move_speed"]))
	stats = s
	var old_max: float = max_hp
	max_hp = maxf(1.0, round(float(def.get("hp", 100)) * float(s["max_hp"])))
	if max_hp > old_max and old_max > 0.0:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	magnet_radius = Game.BASE_MAGNET * float(s["magnet"])


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))


func update(dt: float) -> void:
	var move: Vector2
	if use_external_move:
		move = external_move
	else:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if external_move != Vector2.ZERO:
			move = external_move
	if move.length_squared() > 1.0:
		move = move.normalized()
	if move.length_squared() > 0.01:
		facing = move.normalized()
		if absf(move.x) > 0.15:
			side = signf(move.x)
		_anim += dt * 9.0
		idle_time = 0.0
	else:
		idle_time += dt
	velocity = move * Game.BASE_MOVE_SPEED * float(stats["move_speed"]) * hazard_slow
	var p: Vector2 = position + velocity * dt
	p = run.resolve_obstacles(p, radius)
	position = p
	if invuln > 0.0:
		invuln -= dt
	if _hurt_flash > 0.0:
		_hurt_flash -= dt
	var rec: float = float(stats["recovery"])
	if rec > 0.0 and hp < max_hp:
		_recovery_acc += rec * dt
		if _recovery_acc >= 1.0:
			_recovery_acc -= 1.0
			hp = minf(max_hp, hp + 1.0)


## Returns the damage actually taken (0 while invulnerable).
func take_hit(amount: float) -> float:
	if invuln > 0.0 or god_mode:
		return 0.0
	var taken: float = maxf(1.0, amount - float(stats["armor"]))
	hp -= taken
	invuln = 0.35
	_hurt_flash = 0.2
	return taken


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var src: Rect2 = _frames[int(_anim) % _frames.size()]
	var col: Color = Color.WHITE
	if _hurt_flash > 0.0:
		col = Color(1.0, 0.4, 0.4)
	elif invuln > 0.0 and fmod(invuln, 0.12) < 0.06:
		col = Color(1, 1, 1, 0.5)
	draw_circle(Vector2(0, 14), 7.0, Color(0, 0, 0, 0.25))
	if side < 0.0:
		draw_texture_rect_region(Atlas.tex, Rect2(-16, -18, -32, 32), src, col)
	else:
		draw_texture_rect_region(Atlas.tex, Rect2(-16, -18, 32, 32), src, col)
	draw_rect(Rect2(-13, 17, 26, 3), Color(0.1, 0.1, 0.15, 0.8))
	draw_rect(Rect2(-13, 17, 26.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color(0.9, 0.25, 0.25))
