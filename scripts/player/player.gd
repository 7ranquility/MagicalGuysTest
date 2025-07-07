extends CharacterBody2D

@export var SPEED: float = 200.0
@export var ProjectileScene: PackedScene
@export var shoot_action: String = "shoot"
@export var fire_rate := 0.5
@export var detection_range: float = 300.0
@export var max_health: int = 100
@export var invincibility_duration: float = 1.0
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100

@onready var health_bar: ProgressBar = $HealthBar
@onready var hurtbox: Area2D = $HurtBox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var shoot_cooldown := 0.0
var current_health: int
var is_invincible: bool = false
var invincibility_timer: float = 0.0

func _ready():
	current_health = max_health
	setup_health_bar()
	setup_hurtbox()
	add_to_group("player")

func setup_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true

func setup_hurtbox():
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurt_box_body_entered)
		hurtbox.area_entered.connect(_on_hurt_box_area_entered)



func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	animated_sprite.play("walk")
	velocity = direction * SPEED
	move_and_slide()

func _process(delta):
	handle_shooting(delta)
	handle_invincibility(delta)

func handle_shooting(delta):
	var closest_enemy = find_closest_enemy()
	if closest_enemy and shoot_cooldown <= 0:
		shoot(closest_enemy)
		shoot_cooldown = fire_rate
	if shoot_cooldown > 0:
		shoot_cooldown -= delta

func handle_invincibility(delta):
	if is_invincible:
		invincibility_timer -= delta
		# Flash effect during invincibility
		modulate.a = 0.5 if int(invincibility_timer * 10) % 2 else 1.0
		
		if invincibility_timer <= 0:
			is_invincible = false
			modulate.a = 1.0  # Restore full opacity

func find_closest_enemy() -> Node2D:
	var closest_enemy = null
	var min_distance = detection_range
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy
			
	return closest_enemy

func shoot(target: Node2D):
	var closest_enemy = find_closest_enemy()
	if closest_enemy:
		var b = ProjectileScene.instantiate()
		owner.add_child(b)
		b.global_position = $Muzzle.global_position
		var dir = ($Muzzle.global_position.direction_to(closest_enemy.global_position)).normalized()
		b.rotation = dir.angle()
		b.direction = dir

func _on_hurt_box_body_entered(body: Node2D):
	if body.is_in_group("enemies") and not is_invincible:
		take_damage(10)  # Adjust damage amount as needed

func _on_hurt_box_area_entered(area: Area2D):
	if area.get_parent().is_in_group("enemies") and not is_invincible:
		take_damage(10)  # Adjust damage amount as needed

func take_damage(amount: int):
	if is_invincible:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	update_health_bar()
	
	if current_health <= 0:
		die()
	else:
		start_invincibility()

func start_invincibility():
	is_invincible = true
	invincibility_timer = invincibility_duration

func update_health_bar():
	if health_bar:
		health_bar.value = current_health

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	update_health_bar()

func die():
	print("Player died!")
	# Add death logic here (game over screen, restart, etc.)
	# For now, just restart the scene
	get_tree().reload_current_scene()

func gain_xp(amount: int):
	current_xp += amount
	print("Gained ", amount, " XP! Total: ", current_xp)
	
	# Check for level up
	if current_xp >= xp_to_next_level:
		level_up()

func level_up():
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)  # Increase XP requirement
	print("Level up!")
