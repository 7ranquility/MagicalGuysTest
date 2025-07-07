extends Area2D

@export var damage := 5
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	collision_shape.disabled = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _on_area_entered(area):
	print("Aura: Area entered - ", area.name, " Parent: ", area.get_parent().name if area.get_parent() else "None")
	
	# Check if this is the player's hurtbox
	if area.name == "HurtBox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		print("Aura: WARNING - Player hurtbox detected! This should not happen.")
		return
	
	# Check if the area belongs to an enemy
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		print("Aura: Damaging enemy via area - ", area.get_parent().name)
		area.get_parent().take_damage(damage)
	# Also check if the area itself is an enemy
	elif area.is_in_group("enemies"):
		print("Aura: Damaging enemy directly - ", area.name)
		area.take_damage(damage)

func _on_body_entered(body):
	print("Aura: Body entered - ", body.name)
	
	# Check if this is the player
	if body.is_in_group("player"):
		print("Aura: WARNING - Player body detected! This should not happen.")
		return
	
	# Check if the body is an enemy
	if body.is_in_group("enemies"):
		print("Aura: Damaging enemy via body - ", body.name)
		body.take_damage(damage)
