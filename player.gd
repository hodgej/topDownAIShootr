extends KinematicBody2D


onready var bullet = load("res://bullet.tscn")
var team = 1

var health = 10000
var velocity : Vector2
var speed = 300

var canShoot = true


var accuracy = .99

onready var eyes = get_node("eyes")
onready var body = get_node("body")


func _process(delta):
	if health < 0:
		queue_free()
	
	body.rotation = lerp(body.rotation, eyes.rotation, .1)
	
	
	eyes.look_at(get_global_mouse_position())
	
	if Input.is_action_pressed("forward"):
		velocity = Vector2(speed, 0)
	else:
		velocity = Vector2(0, 0)
	
	if Input.is_action_pressed("shoot"):
		shoot()
	
	
	move_and_slide(velocity.rotated(body.rotation))


func hit():
	health -= 1


func shoot():
	if canShoot:
		$Timer.start()
		canShoot = false
		var bulletInstance = bullet.instance()
		bulletInstance.global_position = $body/shootspot.global_position
		bulletInstance.rotation = body.rotation * (rand_range(accuracy, 1))
		bulletInstance.parent = self
		get_parent().add_child(bulletInstance)


func _on_Timer_timeout():
	canShoot = true
