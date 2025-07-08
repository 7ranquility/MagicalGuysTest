class_name Aura
extends Area2D

# -- Exported Variables --
@export var damage: int = 5
@export var damage_interval: float = 0.5  # Damage every 0.5 seconds
@export var aura_radius: float = 20.0

# -- Node References --
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

# -- Member Variables --
var enemies_in_aura: Array[Node] = []
var damage_timer: float = 0.0

# -- Constants --
const SPRITE_VISUAL_RADIUS: float = 100.0  # Adjust this value until the sprite matches the collision shape

signal enemy_damaged(enemy: Node)

func _ready() -> void:
	"""Initializes the aura, connects signals, and sets the initial radius and scale."""
	collision_shape.disabled = false
	set_aura_radius(aura_radius)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	enemies_in_aura.clear()

func _exit_tree() -> void:
	"""Resource cleanup and signal disconnection."""
	# No dynamic signals to disconnect

func _process(delta: float) -> void:
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		damage_enemies_in_aura()

func damage_enemies_in_aura() -> void:
	"""Damages all valid enemies within the aura and emits a signal for each."""
	for enemy in enemies_in_aura:
		if is_instance_valid(enemy) and enemy.is_in_group("enemies"):
			enemy.take_damage(damage)
			emit_signal("enemy_damaged", enemy)

func _on_area_entered(area: Area2D) -> void:
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
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		enemies_in_aura.erase(area.get_parent())
	elif area.is_in_group("enemies"):
		enemies_in_aura.erase(area)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemies"):
		if not enemies_in_aura.has(body):
			enemies_in_aura.append(body)

func _on_body_exited(body: Node) -> void:
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
