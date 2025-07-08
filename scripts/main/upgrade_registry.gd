extends Node

var upgrades: Array = []
var upgrades_by_group: Dictionary = {}


func _ready() -> void:
	register_all_upgrades()


func register_upgrade(upgrade: Dictionary) -> void:
	upgrades.append(upgrade)
	if not upgrades_by_group.has(upgrade.group):
		upgrades_by_group[upgrade.group] = []
	upgrades_by_group[upgrade.group].append(upgrade)


func get_upgrades_for_groups(groups: Array) -> Array:
	var result: Array = []
	for group in groups:
		if upgrades_by_group.has(group):
			result += upgrades_by_group[group]
	return result


func register_all_upgrades() -> void:
	# Aura upgrades
	register_upgrade({
		id = "aura_damage",
		name = "Aura Damage",
		description = "+5 Aura Damage",
		group = "Aura",
		apply = func(player):
			if player.aura:
				player.aura.damage += 5
	})
	register_upgrade({
		id = "aura_radius",
		name = "Aura Radius",
		description = "+5 Aura Radius",
		group = "Aura",
		apply = func(player):
			if player.aura:
				player.aura.set_aura_radius(player.aura.aura_radius + 5)
	})
	register_upgrade({
		id = "aura_magnet",
		name = "Aura Magnet",
		description = "XP pickups within the aura are pulled toward the player.",
		group = "Aura",
		apply = func(player):
			if player.aura:
				player.aura.has_magnet = true
	})
	# Projectile upgrades
	register_upgrade({ id = "proj_damage", name = "Projectile Damage", description = "+10 Projectile Damage", group = "Projectile", apply = func(player): player.projectile_damage += 10 })
	register_upgrade({ id = "proj_firerate", name = "Projectile Fire Rate", description = "Faster Fire Rate", group = "Projectile", apply = func(player): player.fire_rate = max(0.1, player.fire_rate * 0.8) })
	register_upgrade({ id = "proj_pierce", name = "Piercing Shot", description = "Projectiles can pierce one additional enemy.", group = "Projectile", apply = func(player): player.projectile_pierce_count += 1 })
	register_upgrade({ id = "proj_explosive", name = "Explosive Impact", description = "Projectiles explode on impact, dealing area damage.", group = "Projectile", apply = func(player): player.has_projectile_explosive = true })
	register_upgrade({ id = "proj_split", name = "Splitting Shot", description = "Projectiles split into two on hit.", group = "Projectile", apply = func(player):
		print("Splitting upgrade applied!")
		player.projectile_split_on_hit = true })
