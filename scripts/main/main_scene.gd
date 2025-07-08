extends Node2D

@onready var level_up_menu = $UILayer/LevelUpMenu

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		# Dummy upgrades for testing
		var upgrades = [
			{
				id = "aura_damage",
				name = "Aura Damage",
				description = "+5 Aura Damage",
				group = "Aura"
			},
			{
				id = "aura_radius",
				name = "Aura Radius",
				description = "+20 Aura Radius",
				group = "Aura"
			},
			{
				id = "proj_damage",
				name = "Projectile Damage",
				description = "+10 Projectile Damage",
				group = "Projectile"
			}
		]
		level_up_menu.show_menu(upgrades, ["Aura", "Projectile"])
