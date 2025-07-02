extends CharacterBody3D

var path: Array = []
var current_target: Vector3 = Vector3.INF
var current_velocity: Vector3 = Vector3.ZERO
var speed: float = 10.0
var last_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var stuck_threshold: float = 2.0  # Time in seconds before considering stuck
var movement_threshold: float = 0.1  # Minimum movement distance to not be considered stuck
var path_recalc_cooldown: float = 0.0
var min_path_recalc_interval: float = 0.5  # Minimum time between path recalculations
@onready var timer: Timer = $Timer

func _physics_process(delta: float) -> void:
	# Update cooldown timer
	if path_recalc_cooldown > 0:
		path_recalc_cooldown -= delta
	
	# Check if enemy is stuck
	check_if_stuck(delta)
	
	var new_velocity: Vector3 = Vector3.ZERO
	var lerp_weight: float = delta * 8.0
	
	if current_target != Vector3.INF:
		var dir_to_target: Vector3 = (current_target - global_transform.origin).normalized()
		new_velocity = current_velocity.lerp(speed * dir_to_target, lerp_weight)
		
		# Check if we reached the current target
		if global_transform.origin.distance_to(current_target) < 0.5:
			find_next_point_in_path()
		
		# Check if we're moving towards an obstacle and need to recalculate
		elif is_path_blocked():
			force_path_update()
	else:
		new_velocity = current_velocity.lerp(Vector3.ZERO, lerp_weight)
	
	current_velocity = new_velocity
	velocity = current_velocity
	move_and_slide()
	
	# Update last position for stuck detection
	last_position = global_transform.origin

func find_next_point_in_path() -> void:
	if path.size() > 0:
		var new_target: Vector3 = path.pop_front()
		new_target.y = global_transform.origin.y
		current_target = new_target
		
		# Look at the target with smooth rotation
		var target_direction = (current_target - global_transform.origin).normalized()
		if target_direction != Vector3.ZERO:
			var target_basis = Basis.looking_at(target_direction, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(target_basis, 0.1)
	else:
		current_target = Vector3.INF

func update_path() -> void:
	var player = get_node("../Player")
	if player:
		var new_path = AStar.find_path(global_transform.origin, player.global_transform.origin, true)
		
		# If we got a path, use it
		if new_path.size() > 0:
			path = new_path
			find_next_point_in_path()
		else:
			# If no path found, try to get closer to player using partial path
			var close_points = AStar.get_closest_accessible_point(player.global_transform.origin)
			if close_points != Vector3.INF:
				path = AStar.find_path(global_transform.origin, close_points, true)
				find_next_point_in_path()

func _on_timer_timeout() -> void:
	update_path()

func _ready() -> void:
	# Set timer to update path more frequently
	if timer:
		timer.wait_time = 1.0  # Update path every second instead of default
		timer.start()
	
	# Initialize last position
	last_position = global_transform.origin

func check_if_stuck(delta: float) -> void:
	var movement_distance = global_transform.origin.distance_to(last_position)
	
	if movement_distance < movement_threshold and current_target != Vector3.INF:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			# We're stuck, force a path recalculation
			force_path_update()
			stuck_timer = 0.0
			print("Enemy is stuck, recalculating path.")
	else:
		stuck_timer = 0.0

func is_path_blocked() -> bool:
	# Check if there's an obstacle between current position and target
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_transform.origin + Vector3.FORWARD * 0.1,  # Start slightly above ground
		current_target + Vector3.FORWARD * 0.1,  # End slightly above ground
		1  # Collision layer for obstacles
	)
	
	var result = space_state.intersect_ray(query)
	return result != null

func force_path_update() -> void:
	if path_recalc_cooldown <= 0:
		update_path()
		path_recalc_cooldown = min_path_recalc_interval
