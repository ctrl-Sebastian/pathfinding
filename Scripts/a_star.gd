extends Node3D

@export var debug: bool = false
@onready var obstacles_container: Node = %ObstaclesContainer

var grid_step := 1.0
var grid_y := 0.5
var points := {}
var astar = AStar3D.new()

var cube_mesh = BoxMesh.new()
var red_material = StandardMaterial3D.new()
var green_material = StandardMaterial3D.new()
var blue_material = StandardMaterial3D.new()

func _ready() -> void:
	cube_mesh.size = Vector3(0.25,0.25,0.25)
	red_material.albedo_color = Color.FIREBRICK
	green_material.albedo_color = Color.LIME_GREEN
	blue_material.albedo_color = Color.SKY_BLUE
	
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
	
	astar.add_point(id, point)
	points[world_point_to_astar(point)] = id
	_create_nav_cube(point)

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
				next_point.y = grid_y  # Align with your grid's Y level

				# Check if the point is inside any obstacle
				if not _is_point_inside_obstacle(next_point):
					_add_point(next_point)


func _get_adjacent_points(world_point: Vector3) -> Array:
	var adjacent_points = []
	var search_coords = [-grid_step, 0, grid_step]
	for x in search_coords:
		for z in search_coords:
			var search_offset = Vector3(x, 0, z)
			if search_offset == Vector3.ZERO:
				continue

			var potential_neighbor = world_point_to_astar(world_point + search_offset)
			if points.has(potential_neighbor):
				adjacent_points.append(points[potential_neighbor])
	return adjacent_points

func _connect_points():
	for point in points:
		var pos_str = point.split(",")
		var world_pos := Vector3(float(pos_str[0]), float(pos_str[1]), float(pos_str[2]))
		var adjacent_points = _get_adjacent_points(world_pos)
		var current_id = points[point]
		for neighbor_id in adjacent_points:
			if not astar.are_points_connected(current_id, neighbor_id):
				astar.connect_points(current_id, neighbor_id)
				if debug:
					get_child(current_id).material_override = green_material
					get_child(neighbor_id).material_override = green_material

func _create_nav_cube(position: Vector3):
	if debug:
		var cube = MeshInstance3D.new()
		cube.mesh = cube_mesh
		cube.material_override = red_material
		add_child(cube)
		position.y = grid_y
		cube.global_transform.origin = position

func find_path(from: Vector3, to: Vector3, allow_partial_path: bool) -> Array:
	var start_id = astar.get_closest_point(from, true)
	var end_id = astar.get_closest_point(to, true)
	return astar.get_point_path(start_id, end_id, allow_partial_path)

	
func disable_obstacle_points(obstacles: Array):
	for obstacle in obstacles:
		var obstacle_pos = obstacle.global_transform.origin
		obstacle_pos.y = grid_y  # Align with your grid's Y level
		var key = world_point_to_astar(obstacle_pos)
		if points.has(key):
			var id = points[key]
			astar.set_point_disabled(id, true)
