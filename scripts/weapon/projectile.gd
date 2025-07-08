class_name Projectile
extends Area2D

# -- Exported Variables --
@export var speed: float = 300.0
@export var damage: int = 1
@export var pierce_count: int = 0  # No piercing by default

# -- Node References --
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var projectile_sprite: AnimatedSprite2D = $ProjectileSprite

# -- Member Variables --
var direction: Vector2 = Vector2.RIGHT
var hit_count: int = 0

# -- Constants --
const PROJ_SPEED: float = 750.0

# -- Upgrade Flags --
var explosive: bool = false  # If true, explodes on hit
var explosion_radius: float = 60.0
var explosion_damage: int = 3
const KNOCKBACK_FORCE: float = 50.0
var split_on_hit: bool = false  # Only enabled by upgrade
var can_split: bool = true  # Prevents infinite splitting
var lifetime: float = 0.0
var lifetime_timer: float = 0.0
var max_range: float = 1200.0
var distance_traveled: float = 0.0


func _ready() -> void:
	collision_shape.disabled = false
	area_entered.connect(_on_area_entered)
	direction = Vector2.RIGHT.rotated(rotation)
	if lifetime > 0.0:
		lifetime_timer = lifetime
	distance_traveled = 0.0


func _exit_tree() -> void:
	pass
	# No dynamic signals to disconnect


func _physics_process(delta: float) -> void:
	var move_vec = direction * speed * delta
	position += move_vec
	distance_traveled += move_vec.length()
	if distance_traveled > max_range:
		queue_free()
	if lifetime > 0.0:
		lifetime_timer -= delta
		if lifetime_timer <= 0.0:
			queue_free()
	# Remove projectile if it leaves the camera area
	var camera := get_viewport().get_camera_2d()
	if camera:
		var cam_rect := Rect2(camera.global_position - camera.zoom * camera.get_viewport_rect().size * 0.5, camera.zoom * camera.get_viewport_rect().size)
		if not cam_rect.has_point(global_position):
			queue_free()


func find_nearest_enemy() -> Node2D:
	var closest: Node2D = null
	var min_dist = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		enemy.take_damage(damage)
		# Apply knockback
		if "knockback_velocity" in enemy:
			var knockback_dir = (enemy.global_position - global_position).normalized()
			enemy.knockback_velocity += knockback_dir * KNOCKBACK_FORCE
		hit_count += 1
		if can_split and split_on_hit:
			split_projectile()
		if explosive:
			create_explosion()
		if hit_count > pierce_count:
			queue_free()
	projectile_sprite.play("default")


func create_explosion() -> void:
	"""Deals area damage to all enemies within explosion_radius."""
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage") and global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(explosion_damage)
	# Optionally, add a visual effect here


func split_projectile() -> void:
	"""Splits the projectile into two smaller, weaker projectiles with random directions."""
	var scene = preload("res://scenes/weapon/projectile.tscn")
	for i in range(2):
		var new_proj = scene.instantiate()
		# Use a random angle for each split projectile
		var random_angle = randf_range(0, 2 * PI)
		new_proj.direction = Vector2.RIGHT.rotated(random_angle)
		new_proj.rotation = new_proj.direction.angle()
		get_tree().current_scene.call_deferred("add_child", new_proj)
		new_proj.call_deferred("set_global_position", global_position + new_proj.direction * 10)
		new_proj.damage = max(1, int(damage * 0.5))
		new_proj.speed = speed * 0.7
		new_proj.pierce_count = 0
		new_proj.can_split = false
		new_proj.lifetime = 0.8
		new_proj.max_range = 400.0
