extends Area2D

@export var xp_value: int = 10
@export var pickup_range: float = 50.0
@export var move_speed: float = 200.0

var is_collected: bool = false
var player: Node2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta):
	if player and not is_collected:
		var distance = global_position.distance_to(player.global_position)
		if distance < pickup_range:
			var direction = (player.global_position - global_position).normalized()
			global_position += direction * move_speed * delta

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") and not is_collected:
		collect_xp(body)

func _on_area_entered(area: Area2D):
	if area.get_parent().is_in_group("player") and not is_collected:
		collect_xp(area.get_parent())

func collect_xp(player_node: Node2D):
	if is_collected:
		return            # already handled somewhere else

	is_collected = true   # stop magnet behaviour immediately

	if player_node.has_method("gain_xp"):
		player_node.gain_xp(xp_value)

	queue_free()
