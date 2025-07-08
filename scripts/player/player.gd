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
@onready var xp_bar: ProgressBar = $XPBar
@onready var hurtbox: Area2D = $HurtBox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aura: Node = $Camera2D/Aura

var shoot_cooldown := 0.0
var current_health: int
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var mouse_position: Vector2
var is_manual_aiming: bool = false
var pending_level_up := false
var pending_upgrades := []
var projectile_damage := 10
var game_active := false


func _ready():
	current_health = max_health
	setup_health_bar()
	setup_xp_bar()
	setup_hurtbox()
	add_to_group("player")
	# Connect to LevelUpMenu signal
	var menu = get_level_up_menu()
	if menu:
		menu.connect("upgrade_chosen", Callable(self, "_on_upgrade_chosen"))


func setup_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true


func setup_xp_bar():
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = current_xp
		xp_bar.visible = true


func setup_hurtbox():
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurt_box_body_entered)
		hurtbox.area_entered.connect(_on_hurt_box_area_entered)


func _input(event):
	if not game_active:
		return
	# Update mouse position
	if event is InputEventMouseMotion:
		mouse_position = get_global_mouse_position()

	# Check for manual shooting
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_manual_aiming = true
			else:
				is_manual_aiming = false


func _physics_process(delta):
	if not game_active:
		return
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	animated_sprite.play("walk")
	velocity = direction * SPEED
	move_and_slide()


func _process(delta):
	if not game_active:
		return
	handle_shooting(delta)
	handle_invincibility(delta)


func handle_shooting(delta):
	# Manual shooting with mouse
	if is_manual_aiming and shoot_cooldown <= 0:
		shoot_at_mouse()
		shoot_cooldown = fire_rate
	# Auto-aim shooting (fallback)
	elif not is_manual_aiming:
		var closest_enemy = find_closest_enemy()
		if closest_enemy and shoot_cooldown <= 0:
			shoot(closest_enemy)
			shoot_cooldown = fire_rate

	if shoot_cooldown > 0:
		shoot_cooldown -= delta


func shoot_at_mouse():
	var projectile = ProjectileScene.instantiate()
	owner.add_child(projectile)
	projectile.global_position = $Muzzle.global_position
	# Set projectile damage (directly, since all projectiles have 'damage')
	projectile.damage = projectile_damage
	# Calculate direction to mouse
	var direction = (mouse_position - $Muzzle.global_position).normalized()
	projectile.rotation = direction.angle()
	projectile.direction = direction


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
		# Set projectile damage (directly)
		b.damage = projectile_damage
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


func update_xp_bar():
	if xp_bar:
		xp_bar.value = current_xp
		xp_bar.max_value = xp_to_next_level


func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	update_health_bar()


func die():
	print("Player died!")
	# Add death logic here (game over screen, restart, etc.)
	# For now, just restart the scene
	get_tree().call_deferred("reload_current_scene")


func gain_xp(amount: int):
	current_xp += amount
	print("Gained ", amount, " XP! Total: ", current_xp)

	update_xp_bar()
	# Check for level up
	if current_xp >= xp_to_next_level:
		level_up()


func get_level_up_menu():
	# Now looks for LevelUpMenu under UILayer
	return get_tree().current_scene.get_node_or_null("UILayer/LevelUpMenu")


func level_up():
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)  # Increase XP requirement
	update_xp_bar()
	print("Level up!")
	# Prepare upgrades
	pending_level_up = true
	pending_upgrades = []
	if aura:
		pending_upgrades.append({
			id = "aura_damage",
			name = "Aura Damage",
			description = "+5 Aura Damage",
			group = "Aura"
		})
		pending_upgrades.append({
			id = "aura_radius",
			name = "Aura Radius",
			description = "+5 Aura Radius",
			group = "Aura"
		})
	if ProjectileScene:
		pending_upgrades.append({
			id = "proj_damage",
			name = "Projectile Damage",
			description = "+10 Projectile Damage",
			group = "Projectile"
		})
		pending_upgrades.append({
			id = "proj_firerate",
			name = "Projectile Fire Rate",
			description = "Faster Fire Rate",
			group = "Projectile"
		})
	# Show menu
	var menu = get_level_up_menu()
	if menu:
		menu.show_menu(pending_upgrades, ["Aura", "Projectile"])


func _on_upgrade_chosen(upgrade_id):
	print("Upgrade chosen: ", upgrade_id)
	if upgrade_id == "aura_damage" and aura:
		aura.damage += 5
	elif upgrade_id == "aura_radius" and aura:
		print("Before: aura.aura_radius=", aura.aura_radius)
		aura.set_aura_radius(aura.aura_radius + 5)
		print("After: aura.aura_radius=", aura.aura_radius)
	elif upgrade_id == "proj_damage":
		projectile_damage += 10
	elif upgrade_id == "proj_firerate":
		fire_rate = max(0.1, fire_rate * 0.8)
	pending_level_up = false


func set_game_active(active: bool):
	game_active = active
