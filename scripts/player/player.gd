class_name Player
extends CharacterBody2D

# -- Constants --
const DEFAULT_SPEED: float = 200.0
const DEFAULT_FIRE_RATE: float = 0.5
const DEFAULT_DETECTION_RANGE: float = 300.0
const DEFAULT_MAX_HEALTH: int = 100
const DEFAULT_INVINCIBILITY_DURATION: float = 1.0
const DEFAULT_PROJECTILE_DAMAGE: int = 10

# -- Exported Variables --
@export var speed: float = DEFAULT_SPEED
@export var projectile_scene: PackedScene
@export var aura_scene: PackedScene
@export var shoot_action: String = "shoot"
@export var fire_rate: float = DEFAULT_FIRE_RATE
@export var detection_range: float = DEFAULT_DETECTION_RANGE
@export var max_health: int = DEFAULT_MAX_HEALTH
@export var invincibility_duration: float = DEFAULT_INVINCIBILITY_DURATION
@export var current_xp: int = 0
@export var xp_to_next_level: int = 100

# -- Node References --
@onready var health_bar: ProgressBar = $HealthBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var hurtbox: Area2D = $HurtBox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Node2D = $Muzzle

# -- Member Variables --
var shoot_cooldown: float = 0.0
var current_health: int = 0
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var mouse_position: Vector2 = Vector2.ZERO
var is_manual_aiming: bool = false
var pending_level_up: bool = false
var pending_upgrades: Array = []
var projectile_damage: int = DEFAULT_PROJECTILE_DAMAGE
var game_active: bool = false
var aura: Node = null
var _last_aura_scene: PackedScene = null
# -- Projectile Upgrade Variables --
var projectile_pierce_count: int = 0
var has_projectile_explosive: bool = false
var projectile_split_on_hit: bool = false
# -- Dash Variables --
var dash_speed: float = 400.0
var dash_duration: float = 0.12
var dash_cooldown: float = 1.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	"""Initializes the player, sets up UI, connects signals, and prepares for gameplay."""
	current_health = max_health
	_setup_health_bar()
	_setup_xp_bar()
	_setup_hurtbox()
	add_to_group("player")
	if aura_scene:
		instance_aura()
	_last_aura_scene = aura_scene
	var menu: Node = get_level_up_menu()
	if menu:
		menu.connect("upgrade_chosen", Callable(self, "_on_upgrade_chosen"))


func _exit_tree() -> void:
	"""Resource cleanup and signal disconnection."""
	# No dynamic signals to disconnect


func _setup_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true


func _setup_xp_bar() -> void:
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = current_xp
		xp_bar.visible = true


func _setup_hurtbox() -> void:
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurt_box_body_entered)
		hurtbox.area_entered.connect(_on_hurt_box_area_entered)


func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventMouseMotion:
		mouse_position = get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_manual_aiming = event.pressed
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not is_dashing and dash_cooldown_timer <= 0.0:
			var move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			if move_dir.length() > 0.1:
				dash_direction = move_dir.normalized()
			else:
				dash_direction = Vector2.RIGHT.rotated(rotation)
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown


func _physics_process(delta: float) -> void:
	if not game_active:
		return
	if is_dashing:
		velocity = dash_direction * dash_speed
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		animated_sprite.play("walk")
		velocity = direction * speed
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	move_and_slide()


func _process(delta: float) -> void:
	if not game_active:
		return
	# Handle dynamic aura switching
	if aura_scene != _last_aura_scene:
		if aura:
			aura.queue_free()
			aura = null
		if aura_scene:
			instance_aura()
		_last_aura_scene = aura_scene
	if aura:
		aura.global_position = global_position
	handle_shooting(delta)
	handle_invincibility(delta)


func handle_shooting(delta: float) -> void:
	"""Handles both manual and auto-aim shooting logic."""
	if is_manual_aiming and shoot_cooldown <= 0.0:
		shoot_at_mouse()
		shoot_cooldown = fire_rate
	elif not is_manual_aiming:
		var closest_enemy: Node2D = find_closest_enemy()
		if closest_enemy and shoot_cooldown <= 0.0:
			shoot(closest_enemy)
			shoot_cooldown = fire_rate
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta


func shoot_at_mouse() -> void:
	if not projectile_scene:
		return
	var projectile: Node = projectile_scene.instantiate()
	owner.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.damage = projectile_damage
	var direction: Vector2 = (mouse_position - muzzle.global_position).normalized()
	projectile.rotation = direction.angle()
	projectile.direction = direction
	# Apply upgrades
	projectile.pierce_count = projectile_pierce_count
	projectile.split_on_hit = projectile_split_on_hit
	projectile.explosive = has_projectile_explosive


func handle_invincibility(delta: float) -> void:
	if is_invincible:
		invincibility_timer -= delta
		modulate.a = 0.5 if int(invincibility_timer * 10.0) % 2 else 1.0
		if invincibility_timer <= 0.0:
			is_invincible = false
			modulate.a = 1.0


func find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D = null
	var min_distance: float = detection_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy
	return closest_enemy


func shoot(target: Node2D) -> void:
	if not projectile_scene:
		return
	var closest_enemy: Node2D = find_closest_enemy()
	if closest_enemy:
		var b: Node = projectile_scene.instantiate()
		owner.add_child(b)
		b.global_position = muzzle.global_position
		b.damage = projectile_damage
		var dir: Vector2 = (muzzle.global_position.direction_to(closest_enemy.global_position)).normalized()
		b.rotation = dir.angle()
		b.direction = dir
		# Apply upgrades
		b.pierce_count = projectile_pierce_count
		b.split_on_hit = projectile_split_on_hit
		b.explosive = has_projectile_explosive


func _on_hurt_box_body_entered(body: Node2D) -> void:
	print("HurtBox body entered by: ", body, " at position: ", body.global_position)
	if body.is_in_group("enemies"):
		take_damage(10)


func _on_hurt_box_area_entered(area: Area2D) -> void:
	print("HurtBox area entered by: ", area, " (parent: ", area.get_parent(), ") at position: ", area.global_position)
	if area.get_parent().is_in_group("enemies"):
		take_damage(10)


func take_damage(amount: int) -> void:
	if is_invincible:
		return
	current_health -= amount
	current_health = max(current_health, 0)
	update_health_bar()
	if current_health <= 0:
		die()
	else:
		start_invincibility()


func start_invincibility() -> void:
	is_invincible = true
	invincibility_timer = invincibility_duration


func update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health


func update_xp_bar() -> void:
	if xp_bar:
		xp_bar.value = current_xp
		xp_bar.max_value = xp_to_next_level


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	update_health_bar()


func die() -> void:
	print("Player died!")
	get_tree().call_deferred("reload_current_scene")


func gain_xp(amount: int) -> void:
	current_xp += amount
	print("Gained ", amount, " XP! Total: ", current_xp)
	update_xp_bar()
	if current_xp >= xp_to_next_level:
		level_up()


func get_level_up_menu() -> Node:
	return get_tree().current_scene.get_node_or_null("UILayer/LevelUpMenu")


func level_up() -> void:
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)
	update_xp_bar()
	print("Level up!")
	pending_level_up = true
	pending_upgrades = []
	var owned_groups = []
	if aura:
		owned_groups.append("Aura")
	if projectile_scene:
		owned_groups.append("Projectile")
	pending_upgrades = UpgradeRegistry.get_upgrades_for_groups(owned_groups)
	var menu: Node = get_level_up_menu()
	if menu:
		menu.show_menu(pending_upgrades, owned_groups)


func _on_upgrade_chosen(upgrade_id: String) -> void:
	print("Upgrade chosen: ", upgrade_id)
	for upg in pending_upgrades:
		if upg.id == upgrade_id:
			upg.apply.call(self)
			break
	pending_level_up = false


func set_game_active(active: bool) -> void:
	game_active = active


func instance_aura() -> void:
	if aura_scene and not aura:
		aura = aura_scene.instantiate()
		var camera = get_node_or_null("Camera")
		if camera:
			camera.add_child(aura)
			aura.global_position = global_position
