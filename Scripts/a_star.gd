extends Node3D

@export var debug: bool = false
@onready var obstacles_container: Node = $"../ObstaclesContainer"
@onready var points_container: Node = $"../PointsContainer"

var grid_step := 1.35
var grid_y := 0.5
var points := {} # key: point string, value: astar id
var point_flags := {} # key: point string, value: true if inside obstacle, false otherwise
var astar = AStar3D.new()

var cube_mesh = BoxMesh.new()
var red_material = StandardMaterial3D.new()
var green_material = StandardMaterial3D.new()
var blue_material = StandardMaterial3D.new()
var black_material = StandardMaterial3D.new()

func _ready() -> void:
	cube_mesh.size = Vector3(0.25, 0.25, 0.25)
	red_material.albedo_color = Color.FIREBRICK
	green_material.albedo_color = Color.LIME_GREEN
	blue_material.albedo_color = Color.SKY_BLUE
	black_material.albedo_color = Color.BLACK
	
	var pathables = get_tree().get_nodes_in_group("pathable")
	_add_points(pathables)
	
	_connect_points()
	
func world_point_to_astar(world_point: Vector3) -> String:
	var y = snapped(world_point.y, 0.5)
	var x = snapped(world_point.x, 0.5)
	var z = snapped(world_point.z, 0.5)
	return "%d,%d,%d" % [x, y, z]

func _add_point(point: Vector3):
	point.y = grid_y
	var id = astar.get_available_point_id()
	var key = world_point_to_astar(point)
	points[key] = id
	var inside_obstacle = _is_point_inside_obstacle(point)
	point_flags[key] = inside_obstacle
	astar.add_point(id, point)
	if inside_obstacle:
		astar.set_point_disabled(id, true) # <-- Disable point in AStar3D
	_create_nav_cube(point, inside_obstacle)

func _is_point_inside_obstacle(point: Vector3) -> bool:
	if obstacles_container:
		for obstacle in obstacles_container.get_children():
			if obstacle is StaticBody3D:
				var collision_shape = obstacle.get_node("CollisionShape3D")
				if collision_shape and collision_shape.shape:
					var shape = collision_shape.shape
					var transform = obstacle.global_transform

					# Transform the point to the local space of the obstacle
					var local_point = transform.affine_inverse() * point

					# Check if the local point is inside the shape
					if shape is BoxShape3D:
						if abs(local_point.x) <= shape.size.x / 2 and abs(local_point.y) <= shape.size.y / 2 and abs(local_point.z) <= shape.size.z / 2:
							return true
					elif shape is SphereShape3D:
						if local_point.length() <= shape.radius:
							return true
					elif shape is CapsuleShape3D:
						var horizontal = Vector2(local_point.x, local_point.z).length()
						if horizontal <= shape.radius and abs(local_point.y) <= shape.height / 2:
							return true
					elif shape is CylinderShape3D:
						var horizontal = Vector2(local_point.x, local_point.z).length()
						if horizontal <= shape.radius and abs(local_point.y) <= shape.height / 2:
							return true
					# Add more shape checks as needed
	return false

func _add_points(pathables: Array):
	for pathable in pathables:
		var mesh = pathable.get_node("MeshInstance")
		var aabb: AABB = mesh.global_transform * mesh.get_aabb()
		var start_point = aabb.position

		var x_steps = int(aabb.size.x / grid_step)
		var z_steps = int(aabb.size.z / grid_step)

		for x in range(x_steps):
			for z in range(z_steps):
				var next_point = start_point + Vector3(x * grid_step, 0, z * grid_step)
				next_point.y = grid_y # Align with your grid's Y level
				_add_point(next_point)

func _get_adjacent_points(world_point: Vector3) -> Array:
	var adjacent_points = []
	var search_coords = [-grid_step, 0, grid_step]
	for x in search_coords:
		for z in search_coords:
			var search_offset = Vector3(x, 0, z)
			if search_offset == Vector3.ZERO:
				continue

			var neighbor_pos = world_point + search_offset
			var neighbor_key = world_point_to_astar(neighbor_pos)
			# Only connect to neighbors not inside obstacles
			if points.has(neighbor_key) and not point_flags.get(neighbor_key, false):
				adjacent_points.append(points[neighbor_key])
	return adjacent_points

func _connect_points():
	var space = get_world_3d().direct_space_state
	for key in points.keys():
		if point_flags[key]: continue
		var id_a = points[key]
		var pos_str = key.split(",")
		var a_pos = Vector3(pos_str[0].to_float(), pos_str[1].to_float(), pos_str[2].to_float())
		var adj = _get_adjacent_points(a_pos)

		for id_b in adj:
			# get B position
			var b_pos = astar.get_point_position(id_b)

			# build ray query
			var rq = PhysicsRayQueryParameters3D.new()
			rq.from = a_pos + Vector3.UP * 0.1
			rq.to = b_pos + Vector3.UP * 0.1
			rq.collision_mask = 1 # your Obstacles layer

			var hit = space.intersect_ray(rq)
			if hit.is_empty():
				if not astar.are_points_connected(id_a, id_b):
					astar.connect_points(id_a, id_b)
					if debug:
						points_container.get_child(id_a).material_override = green_material
						points_container.get_child(id_b).material_override = green_material

func _create_nav_cube(position: Vector3, inside_obstacle: bool):
	if debug:
		var cube = MeshInstance3D.new()
		cube.mesh = cube_mesh
		cube.material_override = black_material if inside_obstacle else red_material
		points_container.add_child(cube)
		position.y = grid_y
		cube.global_transform.origin = position

func find_path(from: Vector3, to: Vector3, allow_partial_path: bool) -> Array:
	# Find closest valid points (not inside obstacles)
	var from_id = _get_closest_valid_point(from)
	var to_id = _get_closest_valid_point(to)
	if from_id == -1 or to_id == -1:
		return []
	return astar.get_point_path(from_id, to_id, allow_partial_path)

func _get_closest_valid_point(pos: Vector3) -> int:
	var min_dist = INF
	var closest_id = -1
	for key in points.keys():
		if point_flags.get(key, false):
			continue
		var id = points[key]
		var point_pos = astar.get_point_position(id)
		var dist = pos.distance_to(point_pos)
		if dist < min_dist:
			min_dist = dist
			closest_id = id
	return closest_id

func disable_obstacle_points(obstacles: Array):
	for obstacle in obstacles:
		var obstacle_pos = obstacle.global_transform.origin
		obstacle_pos.y = grid_y # Align with your grid's Y level
		var key = world_point_to_astar(obstacle_pos)
		if points.has(key):
			var id = points[key]
			astar.set_point_disabled(id, true)
