extends Node2D

@onready var level_up_menu = $UILayer/LevelUpMenu
@onready var in_game_ui = $UILayer/inGameUI
@onready var enemy_spawner = $EnemySpawner
@onready var player = $Player

func _ready():
	in_game_ui.connect("start_game", Callable(self, "_on_start_game"))
	in_game_ui.connect("open_settings", Callable(self, "_on_open_settings"))
	in_game_ui.connect("quit_game", Callable(self, "_on_quit_game"))
	# Hide gameplay nodes at start
	enemy_spawner.visible = false
	player.visible = false
	in_game_ui.visible = true

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

func _on_start_game():
	print("MainScene: Start Game action")
	# Show gameplay nodes, hide menu
	enemy_spawner.visible = true
	player.visible = true
	in_game_ui.visible = false
	enemy_spawner.start_spawning()
	player.set_game_active(true)

func _on_open_settings():
	print("MainScene: Open Settings action")
	# TODO: Implement settings menu logic

func _on_quit_game():
	print("MainScene: Quit Game action")
	get_tree().quit()
