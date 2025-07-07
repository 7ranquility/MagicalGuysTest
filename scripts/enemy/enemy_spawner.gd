extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_rate := 2.0  # enemies per second
@export var spawn_distance := 800.0  # distance from player to spawn
@export var max_enemies := 50  # maximum enemies on screen
@export var spawn_enabled := true

var spawn_timer := 0.0
var player: Node2D

func _ready():
	# Find the player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found for enemy spawner!")

func _process(delta):
	if not spawn_enabled or not player or not enemy_scene:
		return
	
	spawn_timer += delta
	
	# Check if it's time to spawn and we haven't hit the limit
	if spawn_timer >= (1.0 / spawn_rate) and get_enemy_count() < max_enemies:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	
	# Get spawn position around the player
	var spawn_pos = get_spawn_position()
	enemy.global_position = spawn_pos
	
	# Add to scene
	get_tree().current_scene.add_child(enemy)

func get_spawn_position() -> Vector2:
	if not player:
		return Vector2.ZERO
	
	# Generate random angle
	var angle = randf() * 2 * PI
	
	# Calculate position at spawn_distance from player
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance
	
	return spawn_pos

func get_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

# Optional: Functions to control spawning
func start_spawning():
	spawn_enabled = true

func stop_spawning():
	spawn_enabled = false

func set_spawn_rate(new_rate: float):
	spawn_rate = new_rate
