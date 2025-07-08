class_name Enemy
extends CharacterBody2D

# -- Constants --
const SEPARATION_DISTANCE: float = 20.0
const SEPARATION_STRENGTH: float = 0.8

# -- Exported Variables --
@export var speed: float = 100.0
@export var max_health: int = 100
@export var damage: int = 10
@export var xp_drop_amount: int = 15

# -- Node References --
@onready var player: Node2D = null
@onready var hurtbox: Area2D = $Area2D
@onready var xp_pickup_scene: PackedScene = preload("res://scenes/player/xp_pickup.tscn")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var blink_timer: Timer = null

# -- Member Variables --
var current_health: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	"""Initializes the enemy, sets up hurtbox, finds player, and prepares for gameplay."""
	current_health = max_health
	_setup_hurtbox()
	_find_player()
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.12
	blink_timer.one_shot = true
	blink_timer.connect("timeout", Callable(self, "_on_blink_timeout"))
	add_child(blink_timer)

func _exit_tree() -> void:
	"""Resource cleanup and signal disconnection."""
	# No dynamic signals to disconnect

func _setup_hurtbox() -> void:
	hurtbox.body_entered.connect(_on_body_entered)
	hurtbox.area_entered.connect(_on_area_entered)

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found in group!")

func _physics_process(delta: float) -> void:
	if player:
		var direction: Vector2 = (player.global_position - global_position).normalized()
		var separation: Vector2 = get_separation_force()
		var final_direction: Vector2 = (direction + separation).normalized()
		animated_sprite.play("walk")
		velocity = final_direction * speed
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 100 * delta)
		move_and_slide()

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		print("Enemy ", name, " damaging player via area collision!")
		if area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)

func get_separation_force() -> Vector2:
	"""Calculates a separation force to avoid crowding with other enemies."""
	var separation: Vector2 = Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self:
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < SEPARATION_DISTANCE and distance > 0.0:
				var away_direction: Vector2 = (global_position - enemy.global_position).normalized()
				var force: float = (SEPARATION_DISTANCE - distance) / SEPARATION_DISTANCE
				separation += away_direction * force
	return separation * SEPARATION_STRENGTH

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("projectiles"):
		take_damage(body.damage)

func take_damage(amount: int) -> void:
	"""Reduces health, triggers blink, and handles death if health reaches zero."""
	current_health -= amount
	current_health = max(current_health, 0)
	if animated_sprite:
		animated_sprite.modulate = Color(1, 0.2, 0.2)
		if blink_timer:
			blink_timer.start()
	if current_health == 0:
		die()

func die() -> void:
	"""Handles enemy death, XP drop, and cleanup."""
	drop_xp()
	queue_free()

func drop_xp() -> void:
	if xp_pickup_scene:
		var xp_pickup: Node2D = xp_pickup_scene.instantiate()
		xp_pickup.global_position = global_position
		xp_pickup.xp_value = xp_drop_amount
		get_parent().call_deferred("add_child", xp_pickup)

func _on_blink_timeout() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1)
