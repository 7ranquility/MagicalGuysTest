class_name EnemySpawner
extends Node2D

# -- Exported Variables --
@export var enemy_scene: PackedScene
@export var spawn_rate: float = 2.0
@export var spawn_distance: float = 800.0
@export var max_enemies: int = 50
@export var spawn_enabled: bool = true

# -- Member Variables --
var spawn_timer: float = 0.0
@onready var player: Node2D = null

func _ready() -> void:
	"""Initializes the enemy spawner and finds the player."""
	_find_player()

func _exit_tree() -> void:
	"""Resource cleanup and signal disconnection."""
	# No dynamic signals to disconnect

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found for enemy spawner!")

func _process(delta: float) -> void:
	if not spawn_enabled or not player or not enemy_scene:
		return
	spawn_timer += delta
	if spawn_timer >= (1.0 / spawn_rate) and get_enemy_count() < max_enemies:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy() -> void:
	"""Spawns a new enemy at a random position around the player."""
	var enemy: Node2D = enemy_scene.instantiate()
	var spawn_pos: Vector2 = get_spawn_position()
	enemy.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)

func get_spawn_position() -> Vector2:
	"""Returns a random spawn position around the player at spawn_distance."""
	if not player:
		return Vector2.ZERO
	var angle: float = randf() * 2.0 * PI
	var spawn_pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance
	return spawn_pos

func get_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func start_spawning() -> void:
	spawn_enabled = true

func stop_spawning() -> void:
	spawn_enabled = false

func set_spawn_rate(new_rate: float) -> void:
	spawn_rate = new_rate
