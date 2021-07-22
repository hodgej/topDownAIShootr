extends Node2D


export var team = 1

onready var soldier = load("res://soldier.tscn")

func _process(delta):
	if get_parent().get("populationTeam%s" % str(team)) < get_parent().get("desiredPopulationTeam%s" % str(team)):
		var initPop = get_parent().get("populationTeam%s" % str(team))
		get_parent().set("populationTeam%s" % str(team), initPop + 1 )
		var soldierInstance = soldier.instance()
		soldierInstance.global_position = self.global_position
		get_parent().add_child(soldierInstance)
		soldierInstance.team = team
