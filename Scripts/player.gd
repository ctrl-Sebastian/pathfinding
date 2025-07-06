extends CharacterBody3D
# How fast the player moves in meters per second.
@export var speed = 14
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75
const CANNON_BALL = preload("res://CannonBall.tscn")
var target_velocity = Vector3.ZERO
@onready var landing_marker: MeshInstance3D = $landing_marker
@onready var turret_018: MeshInstance3D = $Pivot/tank_1_green/Base_018/Turret_018
@onready var ground_collision_shape: CollisionShape3D = $"../Ground/CollisionShape"

func _get_mouse_ground_position() -> Vector3:
	var cam = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var dir = cam.project_ray_normal(mouse_pos)
	# Ray‑cast against your ground collision
	var space = get_world_3d().direct_space_state
	var rq = PhysicsRayQueryParameters3D.new()
	rq.from = from
	rq.to = from + dir * 1000.0
	rq.collide_with_areas = false
	rq.collide_with_bodies = true
	# Make sure ground is on a layer the ray sees
	var hit = space.intersect_ray(rq)
	if hit.is_empty():
		return Vector3.ZERO
	return hit.position

func _launch_cannonball_at(target_point: Vector3):
	# 1) Instance the ball
	var ball = CANNON_BALL.instantiate()
	var muzzle = turret_018.global_transform.origin + Vector3(0, min(5, (0.25*(global_position.distance_to(target_point)))), 0)
	ball.global_transform.origin = muzzle
	get_tree().current_scene.add_child(ball)

	# 2) Compute v0 to hit target_point (same code as before)
	var g = ProjectSettings.get_setting("physics/3d/default_gravity")
	var to = target_point - muzzle
	var h = to.y
	to.y = 0
	var d = to.length()
	var a = deg_to_rad(clamp(global_position.distance_to(target_point) / 10, 30, 60)) # Adjust angle based on distance
	var denom = 2 * cos(a)*cos(a) * (d * tan(a) - h)
	if denom <= 0:
		# fallback: just shoot straight
		ball.linear_velocity = turret_018.global_transform.basis.z * 200
		return
	var v0 = sqrt(g * d*d / denom)
	var dir = to.normalized()
	var v_xz = v0 * cos(a)
	var v_y  = v0 * sin(a)
	ball.linear_velocity = Vector3(dir.x * v_xz, v_y, dir.z * v_xz)


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if landing_marker.visible:
			_launch_cannonball_at(landing_marker.global_transform.origin)

func _physics_process(delta):
	var direction = Vector3.ZERO

	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_backwards"):
		direction.z += 1
	if Input.is_action_pressed("move_forward"):
		direction.z -= 1

	if direction != Vector3.ZERO:
		direction = direction.normalized()
		# Setting the basis property will affect the rotation of the node.
		$Pivot.basis = Basis.looking_at(direction)

	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Vertical Velocity
	if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)

	# Moving the Character
	velocity = target_velocity
	move_and_slide()
	
	var hit = _get_mouse_ground_position()
	if hit != Vector3.ZERO:
		landing_marker.visible = true
		# Snap the marker’s Y to sit flush on the ground
		hit.y = ground_collision_shape.global_transform.origin.y + 0.01
		landing_marker.global_transform.origin = hit
	else:
		landing_marker.visible = false
