extends Area2D

@export var speed := 750.0
@export var damage := 1

func _ready():
	body_entered.connect(_on_body_entered)
	direction = Vector2.RIGHT.rotated(rotation)

func _physics_process(delta):
	position += transform.x * speed * delta
	position += direction * speed * delta
	
func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage)
	queue_free()

var direction = Vector2.RIGHT
const proj_speed = 750
