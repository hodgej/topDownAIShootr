extends KinematicBody2D

var speed = 1000
var parent

func _process(delta):
	move_and_slide(Vector2(speed, 0).rotated(rotation))


func _on_Area2D_body_entered(body):
	if body != parent:
		if body.is_in_group("shootable"):
			body.hit()
		queue_free()
