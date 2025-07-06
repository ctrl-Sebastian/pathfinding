extends RigidBody3D

func _ready() -> void:
	await get_tree().create_timer(4).timeout
	queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(25)  # Reduce health
		queue_free()  # Destroy the cannonball
