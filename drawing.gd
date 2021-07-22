extends Node2D


var posList = []

var lines = []

func _process(delta):
	update()


func _draw():
	for i in posList:
		draw_circle(i, 25, Color(0, 0, 1, .6))
	
	for i in lines:
		draw_line(i[0], i[1], Color(1, 0, 0, .5), 1, true)
	
	lines = []
	posList = []
