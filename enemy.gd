# Enemy.gd
extends CharacterBody2D

@export var speed: float = 100.0
@onready var player = null

func _ready():
	# Try to find the player automatically
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found in group!")

func _physics_process(delta):
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
