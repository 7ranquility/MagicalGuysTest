class_name LevelUp
extends RefCounted
## Level-up and chest reward logic: builds the option lists and applies a choice.

const STAT_TEXT: Dictionary = {
	"damage": "%+d damage", "amount": "%+d projectile", "radius": "%+d radius",
	"length": "%+d length", "width": "%+d width", "range": "%+d range",
	"angle": "%+d° angle", "pierce": "%+d pierce", "chains": "%+d chain",
	"knockback": "%+d knockback", "orbit_radius": "%+d orbit size", "cluster": "%+d cluster bell",
	"splits": "%+d split", "rings": "%+d ring",
}
const STAT_TEXT_F: Dictionary = {
	"cooldown": "%+.2fs cooldown", "duration": "%+.1fs duration", "area": "%+d%% area",
	"speed": "%+d%% speed", "tick": "%+.2fs hit interval",
}


static func describe_delta(delta: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in delta:
		var v: float = float(delta[key])
		if STAT_TEXT.has(key):
			parts.append(STAT_TEXT[key] % int(v))
		elif key == "area" or key == "speed":
			parts.append(STAT_TEXT_F[key] % int(round(v * 100.0)))
		elif STAT_TEXT_F.has(key):
			parts.append(STAT_TEXT_F[key] % v)
		else:
			parts.append("%+.1f %s" % [v, key])
	return ", ".join(parts)


static func instrument_option(id: String, next_level: int) -> Dictionary:
	var def: Dictionary = Content.instruments[id]
	var desc: String = def.get("desc", "")
	if next_level > 1:
		desc = describe_delta((def.get("levels", []) as Array)[next_level - 2])
	return {
		"kind": "instrument", "id": id, "level": next_level, "new": next_level == 1,
		"title": def.get("name", id), "desc": desc, "icon": def.get("icon", "ui_unknown"),
	}


static func passive_option(id: String, next_level: int) -> Dictionary:
	var def: Dictionary = Content.passives[id]
	return {
		"kind": "passive", "id": id, "level": next_level, "new": next_level == 1,
		"title": def.get("name", id), "desc": def.get("desc", ""), "icon": def.get("icon", "ui_unknown"),
	}


static func evolve_option(id: String) -> Dictionary:
	var def: Dictionary = Content.instruments[id]
	return {
		"kind": "evolve", "id": id, "level": 1, "new": true,
		"title": def.get("name", id), "desc": def.get("desc", ""), "icon": def.get("icon", "ui_unknown"),
	}


static func filler_options() -> Array[Dictionary]:
	return [
		{"kind": "gold", "id": "gold", "level": 0, "new": false, "title": "Tip Jar", "desc": "+25 gold", "icon": "pk_coinbag"},
		{"kind": "heal", "id": "heal", "level": 0, "new": false, "title": "Stage Snack", "desc": "Restore 30 HP", "icon": "pk_food"},
	]


## All upgrades the player could receive right now, as [option, weight] pairs.
static func candidates(run: Run, include_new: bool = true) -> Array:
	var out: Array = []
	var ws: WeaponSystem = run.weapons
	var consumed: Dictionary = {}
	for w: WeaponSystem.Weapon in ws.weapons:
		for src: String in w.def.get("from", []):
			consumed[src] = true
		if not ws.is_max(w):
			out.append([instrument_option(w.id, w.level + 1), 110.0])
	if include_new and ws.weapons.size() < Game.MAX_INSTRUMENTS:
		for id: String in Content.base_instrument_ids:
			if ws.has(id) or consumed.has(id) or run.banished.has(id) or not Game.is_unlocked("instrument", id):
				continue
			out.append([instrument_option(id, 1), float(Content.instruments[id].get("rarity", 100))])
	var owned: Dictionary = run.player.passives
	for id: String in owned:
		if int(owned[id]) < Content.passive_max_level(id):
			out.append([passive_option(id, int(owned[id]) + 1), 100.0])
	if include_new and owned.size() < Game.MAX_PASSIVES:
		for id: String in Content.passive_ids:
			if owned.has(id) or run.banished.has(id) or not Game.is_unlocked("passive", id):
				continue
			out.append([passive_option(id, 1), float(Content.passives[id].get("rarity", 100))])
	return out


static func _pick_weighted(pool: Array, n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	pool = pool.duplicate()
	while out.size() < n and not pool.is_empty():
		var total: float = 0.0
		for c: Array in pool:
			total += float(c[1])
		var roll_: float = randf() * total
		var chosen: int = pool.size() - 1
		for k: int in pool.size():
			roll_ -= float(pool[k][1])
			if roll_ <= 0.0:
				chosen = k
				break
		out.append(pool[chosen][0])
		pool.remove_at(chosen)
	return out


static func roll(run: Run) -> Array[Dictionary]:
	var luck: float = maxf(run.player.stat("luck"), 0.1)
	var n: int = 4 if randf() < 1.0 - 1.0 / luck else 3
	var out: Array[Dictionary] = _pick_weighted(candidates(run), n)
	if out.is_empty():
		out = filler_options()
	return out


## Chest contents: evolutions and unions first, then upgrades of owned items, then gold.
static func chest(run: Run, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in run.weapons.available_transforms():
		if out.size() < count:
			out.append(evolve_option(id))
	if out.size() < count:
		var extra: Array[Dictionary] = _pick_weighted(candidates(run, false), count - out.size())
		out.append_array(extra)
	while out.size() < count:
		out.append({"kind": "gold", "id": "gold", "level": 0, "new": false, "title": "Royalty Cheque", "desc": "+40 gold", "icon": "pk_coinbag", "amount": 40})
	return out


static func apply(run: Run, opt: Dictionary) -> void:
	match opt["kind"]:
		"instrument":
			if run.weapons.has(opt["id"]):
				run.weapons.level_up(opt["id"])
			else:
				run.weapons.add(opt["id"])
		"evolve":
			run.weapons.transform(opt["id"])
			run.evolutions_made += 1
			Game.event("evolve", {"id": opt["id"]})
		"passive":
			var p: Dictionary = run.player.passives
			p[opt["id"]] = int(p.get(opt["id"], 0)) + 1
			Save.discover("passives", opt["id"])
			run.player.recompute_stats()
			run.weapons.refresh()
			run.on_weapons_changed()
		"gold":
			run.add_gold(float(opt.get("amount", 25)))
		"heal":
			run.player.heal(30.0)
