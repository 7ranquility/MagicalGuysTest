extends Node2D

@onready var level_up_menu = $UILayer/LevelUpMenu
@onready var in_game_ui = $UILayer/inGameUI
@onready var enemy_spawner = $EnemySpawner
@onready var player = $Player

func _ready():
	in_game_ui.connect("start_game", Callable(self, "_on_start_game"))
	in_game_ui.connect("open_settings", Callable(self, "_on_open_settings"))
	in_game_ui.connect("quit_game", Callable(self, "_on_quit_game"))
	in_game_ui.connect("weapon_selected", Callable(self, "_on_weapon_selected"))
	# Hide gameplay nodes at start
	enemy_spawner.visible = false
	player.visible = false
	in_game_ui.visible = true

func _input(_event):
	pass

func _on_start_game():
	"""Handles the Start Game action: shows gameplay nodes and starts the game."""
	print("MainScene: Start Game action")
	# Show gameplay nodes, hide menu
	enemy_spawner.visible = true
	player.visible = true
	in_game_ui.visible = false
	enemy_spawner.start_spawning()
	player.set_game_active(true)

func _on_open_settings():
	"""Handles the Open Settings action. (TODO: Implement settings menu logic)"""
	print("MainScene: Open Settings action")
	# TODO: Implement settings menu logic

func _on_quit_game():
	"""Handles the Quit Game action and exits the game."""
	print("MainScene: Quit Game action")
	get_tree().quit()

func _on_weapon_selected(weapon_type):
	"""Handles weapon selection and sets up the player with the chosen weapon."""
	print("MainScene: Weapon selected: ", weapon_type)
	# Give player only the selected weapon
	if weapon_type == "Aura":
		player.aura_scene = preload("res://scenes/weapon/aura.tscn")
		player.projectile_scene = null
	elif weapon_type == "Projectile":
		player.projectile_scene = preload("res://scenes/weapon/projectile.tscn")
		player.aura_scene = null
	enemy_spawner.visible = true
	player.visible = true
	in_game_ui.visible = false
	enemy_spawner.start_spawning()
	player.set_game_active(true)
