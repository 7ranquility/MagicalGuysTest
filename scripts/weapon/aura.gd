class_name Aura
extends Area2D

# -- Exported Variables --
@export var damage: float = 1.0
@export var damage_interval: float = 0.1  # Damage every 0.1 seconds
@export var aura_radius: float = 20.0

# -- Node References --
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

# -- Member Variables --
var enemies_in_aura: Array[Node] = [] # Nodes currently inside the aura
var damage_timer: float = 0.0
var slowed_enemies: Array[Node] = [] # Enemies currently slowed by the aura

# -- Constants --
const SPRITE_VISUAL_RADIUS: float = 100.0  # Adjust to match your sprite's true radius in pixels
const SLOW_FACTOR: float = 0.75  # Enemies move at 75% speed in aura

# -- Upgrade Flags --
var has_magnet: bool = false # If true, aura pulls XP pickups
var has_slow: bool = false   # If true, aura slows enemies

# -- Signals --
signal enemy_damaged(enemy: Node) # Emitted when an enemy is damaged by the aura

func _ready() -> void:
	"""Initializes the aura, connects signals, and sets the initial radius and scale."""
	collision_shape.disabled = false
	set_aura_radius(aura_radius)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	enemies_in_aura.clear()
	slowed_enemies.clear()

func _exit_tree() -> void:
	"""Resource cleanup and signal disconnection."""
	# No dynamic signals to disconnect

func _process(delta: float) -> void:
	"""Handles damage, magnet, and slow effects each frame."""
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		damage_enemies_in_aura()
	# Magnet effect
	if has_magnet:
		pull_xp_pickups()
	# Slow effect (upgrade only)
	if has_slow:
		# Remove all nulls and invalids from slowed_enemies first
		slowed_enemies = slowed_enemies.filter(func(e: Node): return is_instance_valid(e))
		# Apply slow to new enemies
		for enemy in enemies_in_aura:
			if is_instance_valid(enemy) and enemy.is_in_group("enemies"):
				if not slowed_enemies.has(enemy):
					enemy.speed *= SLOW_FACTOR
					slowed_enemies.append(enemy)
		# Remove slow from enemies who left aura
		for enemy in slowed_enemies.duplicate():
			if not enemies_in_aura.has(enemy):
				if is_instance_valid(enemy):
					enemy.speed /= SLOW_FACTOR
				slowed_enemies.erase(enemy)

func damage_enemies_in_aura() -> void:
	"""Damages all valid enemies within the aura and emits a signal for each."""
	for enemy in enemies_in_aura:
		if is_instance_valid(enemy) and enemy.is_in_group("enemies"):
			enemy.take_damage(damage)
			emit_signal("enemy_damaged", enemy)

func _on_area_entered(area: Area2D) -> void:
	"""Tracks enemies entering the aura area."""
	# Ignore player hurtbox
	if area.name == "HurtBox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		return
	# Add enemy if not already tracked
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		if not enemies_in_aura.has(area.get_parent()):
			enemies_in_aura.append(area.get_parent())
	elif area.is_in_group("enemies"):
		if not enemies_in_aura.has(area):
			enemies_in_aura.append(area)

func _on_area_exited(area: Area2D) -> void:
	"""Removes enemies leaving the aura area."""
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		enemies_in_aura.erase(area.get_parent())
	elif area.is_in_group("enemies"):
		enemies_in_aura.erase(area)

func _on_body_entered(body: Node) -> void:
	"""Tracks enemies entering the aura by body collision."""
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemies"):
		if not enemies_in_aura.has(body):
			enemies_in_aura.append(body)

func _on_body_exited(body: Node) -> void:
	"""Removes enemies leaving the aura by body collision."""
	if body.is_in_group("enemies"):
		enemies_in_aura.erase(body)

func set_aura_radius(new_radius: float) -> void:
	"""Sets the aura's radius and updates the collision shape and sprite scale."""
	aura_radius = new_radius
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = aura_radius
	if sprite.texture:
		var scale_factor: float = aura_radius / SPRITE_VISUAL_RADIUS
		sprite.scale = Vector2.ONE * scale_factor

func pull_xp_pickups() -> void:
	"""Pulls XP pickups within aura radius toward the player."""
	for xp in get_tree().get_nodes_in_group("xp_pickup"):
		if is_instance_valid(xp) and global_position.distance_to(xp.global_position) <= aura_radius:
			var dir: Vector2 = (global_position - xp.global_position).normalized()
			xp.global_position += dir * 300 * get_process_delta_time()
