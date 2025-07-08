class_name Projectile
extends Area2D

# -- Exported Variables --
@export var speed: float = 300.0
@export var damage: int = 1

# -- Node References --
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var projectile_sprite: AnimatedSprite2D = $ProjectileSprite

# -- Member Variables --
var direction: Vector2 = Vector2.RIGHT

# -- Constants --
const PROJ_SPEED: float = 750.0


func _ready() -> void:
	collision_shape.disabled = false
	area_entered.connect(_on_area_entered)
	direction = Vector2.RIGHT.rotated(rotation)


func _exit_tree() -> void:
	pass
	# No dynamic signals to disconnect


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("enemies"):
		area.get_parent().take_damage(damage)
	projectile_sprite.play("default")
