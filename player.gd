extends CharacterBody2D

const SPEED = 200.0
@export var ProjectileScene: PackedScene
@export var shoot_action: String = "shoot"
@export var fire_rate := 0.5
@export var detection_range: float = 300.0

var shoot_cooldown := 0.0

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()


func find_closest_enemy() -> Node2D:
	var closest_enemy = null
	var min_distance = detection_range
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy
			
	return closest_enemy

func shoot(_target: Node2D):
	var closest_enemy = find_closest_enemy()
	if closest_enemy:
		var b = ProjectileScene.instantiate()
		owner.add_child(b)
		b.global_position = $Muzzle.global_position
		var dir = ($Muzzle.global_position.direction_to(closest_enemy.global_position)).normalized()
		b.rotation = dir.angle()
		b.direction = dir  # store direction in bullet script
	
func _process(_delta):
	var closest_enemy = find_closest_enemy()
	if closest_enemy and shoot_cooldown <= 0:
		shoot(closest_enemy)
		shoot_cooldown = fire_rate
	if shoot_cooldown > 0:
		shoot_cooldown -= _delta
