extends CharacterBody2D

@export var speed: float = 100.0
@export var max_health: int = 100
@export var damage = 10
@export var xp_drop_amount: int = 15
@onready var player = null
@onready var hurtbox: Area2D = $Area2D
@onready var xp_pickup_scene = preload("res://scenes/player/xp_pickup.tscn")

var current_health: int

func _ready():
	current_health = max_health
	hurtbox.body_entered.connect(_on_body_entered)
	# Try to find the player automatically
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found in group!")
		
##	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.area_entered.connect(_on_area_entered)

func _physics_process(_delta):
	if player:
		var direction = (player.global_position - global_position).normalized()
		var separation = get_separation_force()
		var final_direction = (direction + separation).normalized()
		$AnimatedSprite2D.play("walk")
		velocity = final_direction * speed
		move_and_slide()

func _on_area_entered(area: Area2D):
	if area.get_parent().is_in_group("player"):
		print("Enemy ", name, " damaging player via area collision!")
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)

func get_separation_force() -> Vector2:
	var separation = Vector2.ZERO
	var separation_distance = 20.0  # How close is too close
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < separation_distance and distance > 0:
				var away_direction = (global_position - enemy.global_position).normalized()
				var force = (separation_distance - distance) / separation_distance
				separation += away_direction * force
	
	return separation * 0.8  # Separation strength (0.0 to 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("projectiles"):
		take_damage(body.damage)


func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(current_health, 0)
	if current_health == 0:
		die()

func die() -> void:
	drop_xp()
	queue_free()

func drop_xp() -> void:
	if xp_pickup_scene:
		var xp_pickup = xp_pickup_scene.instantiate()
		xp_pickup.global_position = global_position
		xp_pickup.xp_value = xp_drop_amount
		get_parent().add_child(xp_pickup)
