extends CharacterBody2D

const SPEED = 200.0
@export var ProjectileScene: PackedScene
@export var shoot_action: String = "shoot"


func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()


func _input(event):
	if Input.is_action_just_pressed(shoot_action):
		shoot()

func shoot():
	if not ProjectileScene:
		return
	var bullet = ProjectileScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = $Muzzle.global_transform
	var b = ProjectileScene.instantiate()
	owner.add_child(b)
	b.global_position = $GunPivot.global_position
	var dir = ($GunPivot.global_position.direction_to(get_global_mouse_position())).normalized()
	b.rotation = dir.angle()
	b.direction = dir  # store direction in bullet script

func _process(_delta):
	$GunPivot.look_at(get_global_mouse_position())
