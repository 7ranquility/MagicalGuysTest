extends Area2D

@export var speed := 300.0
@export var damage := 1
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	collision_shape.disabled = false
	area_entered.connect(_on_area_entered)
	direction = Vector2.RIGHT.rotated(rotation)

func _physics_process(delta):
	position += direction * speed * delta
	
func _on_area_entered(area):
	if area.get_parent().is_in_group("enemies"):
		area.get_parent().take_damage(damage)
	$ProjectileSprite.play("default")

var direction = Vector2.RIGHT
const proj_speed = 750
