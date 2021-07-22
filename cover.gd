extends StaticBody2D

var cover = {} #ex: c1 (object) : false; not taken

func _ready():
	for i in get_node("coverspots").get_children():
		cover[i] = false
