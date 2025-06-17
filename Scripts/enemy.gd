extends CharacterBody3D

var path: Array = []
var current_target: Vector3 = Vector3.INF
var current_velocity: Vector3 = Vector3.ZERO
var speed: float = 10.0
@onready var timer: Timer = $Timer

func _physics_process(delta: float) -> void:
	var new_velocity: Vector3 = Vector3.ZERO
	var lerp_weight: float = delta * 8.0
	if current_target != Vector3.INF:
		var dir_to_target: Vector3 = (current_target - global_transform.origin).normalized()
		new_velocity = current_velocity.lerp(speed * dir_to_target, lerp_weight)
		if global_transform.origin.distance_to(current_target) < 0.5:
			find_next_point_in_path()
	else:
		new_velocity = current_velocity.lerp(Vector3.ZERO, lerp_weight)
	
	current_velocity = new_velocity
	velocity = current_velocity
	move_and_slide()

func find_next_point_in_path() -> void:
	if path.size() > 0:
		var new_target: Vector3 = path.pop_front()
		new_target.y = global_transform.origin.y
		current_target = new_target
	else:
		current_target = Vector3.INF

func update_path() -> void:
	var player = get_node("../Player")
	if player:
		path = AStar.find_path(global_transform.origin, player.global_transform.origin, true)
		find_next_point_in_path()

func _on_timer_timeout() -> void:
	update_path()
