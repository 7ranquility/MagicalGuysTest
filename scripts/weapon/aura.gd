extends Area2D

@export var damage := 5
@export var damage_interval := 0.5  # Damage every 0.5 seconds
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var enemies_in_aura: Array[Node] = []
var damage_timer: float = 0.0


func _ready():
	collision_shape.disabled = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta):
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		damage_enemies_in_aura()


func damage_enemies_in_aura():
	for enemy in enemies_in_aura:
		if is_instance_valid(enemy) and enemy.is_in_group("enemies"):
			enemy.take_damage(damage)


func _on_area_entered(area):
	# Check if this is the player's hurtbox
	if area.name == "HurtBox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		return

	# Check if the area belongs to an enemy
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		if not enemies_in_aura.has(area.get_parent()):
			enemies_in_aura.append(area.get_parent())
	# Also check if the area itself is an enemy
	elif area.is_in_group("enemies"):
		if not enemies_in_aura.has(area):
			enemies_in_aura.append(area)


func _on_area_exited(area):
	# Remove enemy from the list when they exit
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		enemies_in_aura.erase(area.get_parent())
	elif area.is_in_group("enemies"):
		enemies_in_aura.erase(area)


func _on_body_entered(body):
	# Check if this is the player
	if body.is_in_group("player"):
		return

	# Check if the body is an enemy
	if body.is_in_group("enemies"):
		if not enemies_in_aura.has(body):
			enemies_in_aura.append(body)


func _on_body_exited(body):
	# Remove enemy from the list when they exit
	if body.is_in_group("enemies"):
		enemies_in_aura.erase(body)
