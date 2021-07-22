extends KinematicBody2D


enum{ #STATES
	IDLE   = 0 ,
	ATTACK = 1 ,
	COVER  = 2 ,
	PEEK   = 3 ,
}


onready var eyes = $eyes
onready var body = $body
onready var main = get_parent()

onready var bullet = load("res://bullet.tscn")
# Pathfinding Vars #
var path = []
var current_path_index = 0
var dist_thresh = 3

# Meta #
var speed = 200

export var debug = false
var wanderRad = 1000

export var team = 1


var velocity = Vector2()

# Finite State Machine #
var FSMState : int = COVER

# Timers #

var coverToAttackStarted = false
var giveUpStarted = false
var peekTimerStarted = false

# Combat Vars #
var enemiesInArea = []

var accuracy = 1


var health = 3
onready var target = get_node("../player")#currently engaged enemy
var minDistToTarget = 1400
var maxDistToTarget = 300
var distDeviation = 5
var backupModifier = 2
var canShoot = true

var targetPos : Vector2

export var shootSpeed = .2

onready var t1 = get_node("../trgt")
onready var t2 = get_node("../trgt2")
onready var t3 = get_node("../trgt3")
onready var coverDetect = get_node("coverDetect")

# Combat COVER Vars #
var inCover = false
var peek = false
var desiredCover : Vector2
var currentCoverObj
var toggleGiveUpOnArrivalOfKnownPos = false #called upon move_to when ai can't see where player is. if true and path = [], IDLE.


# Cover PEEK Vars #
var peekObject
var canPeek = true
var atPeekPos = false

func _ready():
	$shootCoolDown.wait_time = shootSpeed
	pass


func _process(delta):
	if health <= 0:
		var initPop = get_parent().get("populationTeam%s" % str(team))
		get_parent().set("populationTeam%s" % str(team), initPop - 1 )
		queue_free()
	
	match FSMState:
		IDLE:
			$Label.text = "IDLE"
			idle()
		ATTACK:
			$Label.text = "ATTACK"
			attack()
		COVER:
			$Label.text = "COVER"
			cover()
		PEEK:
			$Label.text = "PEEK"
			peek()
	if !(path.empty()): #if path not empty: navigaate
		$body/AnimatedSprite.playing = true
		navigate()
	else:
		$body/AnimatedSprite.playing = false
		
	move_and_slide(velocity)


# STATES #
func idle():
#	if team == 1:
#		modulate = Color(0,0,1,1)
#	else:
#		modulate = Color(1,0,0,1)
	if path.empty():
		randomize()
		var randDest = global_position + (Vector2(rand_range(-wanderRad, wanderRad ),rand_range(-wanderRad, wanderRad )))
		
		var closestRandDest = get_node("../Navigation2D").get_closest_point(randDest)
		move_to(randDest)
	
	randomize()
	#if (randi() % 2) == 0:
	FSMState = checkPriorities([COVER])
	#else:
		#FSMState =  checkPriorities([ATTACK])

func attack():
	#FSMState = checkPriorities([COVER])
	if checkLOS(target):
		$giveUp.stop()
		giveUpStarted = false
		targetPos = target.global_position # we don't magically know where he is
#	else:
#		if !giveUpStarted:
#			print("SHLFHJAL:FAHL:FHSTARTED GIVEUP STARTD")
#			giveUpStarted = true
#			#$giveUp.start()
#			$Label.text = "TARGETPOS GIVEUP"
#			move_to(targetPos)
	
	if is_instance_valid(target):
		var distToTarget = int(self.global_position.distance_to(targetPos))
		if distToTarget >= minDistToTarget: #too far
			velocity = Vector2(0, 0)
			path = []
			$Label.text = "TARGETPOS DIST > MINIDST"
			move_to(targetPos)
			
		elif distToTarget <= maxDistToTarget: # too close
			var vectorFromTarget = global_position - targetPos
			var unitV = vectorFromTarget.normalized()
			if debug:
				get_node("../Line2D").points = [global_position, global_position+vectorFromTarget]
			velocity = Vector2(0, 0)
			path = []
			if checkLOS(target):
				$Label.text = "BACKUP"
				toggleGiveUpOnArrivalOfKnownPos = true
				move_to(unitV*backupModifier)
			else:
				$Label.text = "TOO CLOSE; NO LOS; MOVE TO TARGET ANYWAYSS"
				$coverToAttack.stop()
				if ((path == []) && (!toggleGiveUpOnArrivalOfKnownPos)) :
					print("move to")
					giveUpStarted = false
					toggleGiveUpOnArrivalOfKnownPos = true
					move_to(targetPos)
				elif ((path == []) && (toggleGiveUpOnArrivalOfKnownPos == true)):
					#print("YESSSSSSSSSSSS")
					if !giveUpStarted:
						print("start give up")
						giveUpStarted = true
						print("GIVEUP")
						$Label.text = "GIVEUP"
						$giveUp.start()
						$body/AnimationPlayer.play("lookAround")
					else:
						print("ELSE")
						if checkLOS(target):
							print("RESET")
							$giveUp.stop()
							toggleGiveUpOnArrivalOfKnownPos = false
							giveUpStarted = false
							$body/AnimationPlayer.stop()

		else: #in middle of range between max and min distances. 
			if path.size()>1:
				velocity = Vector2(0, 0)
				path = []
			if checkLOS(target):
				body.look_at(targetPos)
				if canShoot:
					canShoot = false
					$shootCoolDown.start()
					shoot()
			else: # no los
				$Label.text = "TARGETPOS ELSE BOTH DIST CHECKS"
				move_to(targetPos)
			
			
	else:
		FSMState = IDLE
		target = null


func peek():
	if is_instance_valid(target):
		if checkLOS(target):
			targetPos = target.global_position # we don't magically know where he is
		if global_position.distance_to(peekObject.global_position) < dist_thresh:
			if !atPeekPos: #not atPeekPos
				velocity = Vector2(0, 0)
			
			atPeekPos = true
			
			global_position = peekObject.global_position
			
			if !peekTimerStarted:
				path = []
				peekTimerStarted = true
				$peekTime.start()
			
			body.look_at(target.global_position)
			if canShoot:
				canShoot = false
				$shootCoolDown.start()
				shoot()
		else:
			if !atPeekPos:
				move_to(peekObject.global_position)
	else:
		atPeekPos = false
		peekTimerStarted = false
		FSMState = IDLE


func cover():
	FSMState = checkPriorities([COVER])
	if is_instance_valid(target):
		if !(checkLOS(target)):
			if !coverToAttackStarted:
				$coverToAttack.start()
				print("start")
				coverToAttackStarted = true
		if !inCover:
			if path.empty():
				findCover()
			elif !inCover:
				if desiredCover.distance_to(global_position) < dist_thresh:
					inCover = true
				navigate()
		else:
			if checkIfVulnerable(false): 
				inCover = false
				if currentCoverObj != null:
					currentCoverObj.get_parent().get_parent().cover[currentCoverObj] = false
				desiredCover = Vector2(0, 0)
				
	else:
		if currentCoverObj != null:
			currentCoverObj.get_parent().get_parent().cover[currentCoverObj] = false
		inCover = false
		desiredCover = Vector2(0, 0)
	
		FSMState = ATTACK


func findCover():
	var viableCoverSpots = []
	for i in coverDetect.get_overlapping_bodies():
		var nearbyCoverSpots = []
		if i.is_in_group("cover"):
			for spot in i.get_node("coverspots").get_children():
				nearbyCoverSpots.append(spot)
			for x in nearbyCoverSpots:
				if raycastFromTo(x.global_position, target.global_position, target) == true:
					if i.cover[x] == false:
						if debug:
							get_node("../drawing").posList.append(x.global_position)
						viableCoverSpots.append(x)
	
	if viableCoverSpots.size() >= 1:
		var dists = distancesToPositions(viableCoverSpots, true)
		
		var coverSpot = viableCoverSpots[dists.find(minArray(dists))]
#		print(dists)
#		print(dists[viableCoverSpots.find(coverSpot)])
		desiredCover = coverSpot.global_position
		currentCoverObj = coverSpot
		coverSpot.get_parent().get_parent().cover[coverSpot] = true
		
		move_to(coverSpot.global_position)

func shoot():
	var bulletInstance = bullet.instance()
	bulletInstance.global_position = $body/shootSpot.global_position
	bulletInstance.rotation = $body.rotation * (rand_range(accuracy, 1))
	bulletInstance.parent = self
	main.add_child(bulletInstance)



func minArray(array):
	var minimum = array[0]
	if array.size() > 1:
		for i in range(0, array.size()-1):
			minimum = min(array[i], array[i+1])
	return minimum


func maxArray(array):
	var minimum = array[0]
	if array.size() > 1:
		for i in range(0, array.size()-1):
			minimum = max(array[i], array[i+1])
	return minimum


func distancesToPositions(positions, isObject):
	var distArr = []
	if !isObject: #If NOT isobject
		for i in positions:
			distArr.append(global_position.distance_squared_to(i))
	else:
		for i in positions:
			distArr.append(global_position.distance_squared_to(i.global_position))
	return distArr


func raycastFromTo(from, to, hideFrom):
		if debug:
			get_node("../drawing").lines.append([from, to])
		var worldSpace = get_world_2d().direct_space_state
		var result = worldSpace.intersect_ray(from, to, [self], 0x7FFFFFFF)
		
		if result:
			if result.collider != hideFrom:
				return true
			else:
				return false
		else:
			return false


func checkPriorities(types : Array): #Array of values superior to current task will be passed in and called during current task function
	var stateToSwitch = FSMState 
	for i in types:
		match i: 
			ATTACK:
				if(checkForEnemies()): stateToSwitch = ATTACK
			COVER:
				var enemy = checkIfVulnerable(true) #used in below elif
			
				if inCover == true:
					if (!checkIfVulnerable(false)):
						if canPeek:
							var playerVul = checkIfPlayerVulnerable()
							if playerVul != null: 
								peekObject = playerVul
								stateToSwitch = PEEK
								#currentCoverObj.get_parent().get_parent().cover[currentCoverObj] = false
								#inCover = false
								#desiredCover = Vector2(0, 0)
				
				elif enemy != null:
					target = enemy
					stateToSwitch = COVER
				#if !peek: stateToSwitch = COVER
				if is_instance_valid(target):
					if int(self.global_position.distance_to(target.global_position)) < maxDistToTarget:
						stateToSwitch = ATTACK
				
	return stateToSwitch


# PATHFINDING #
func navigate():
	#if path isn't done
	if current_path_index <= path.size()-1:
		if self.global_position.distance_to(path[current_path_index]) > dist_thresh: #check if close to target destination
			#if not at destination
			eyes.look_at(path[current_path_index])
			#$bo.look_at(path[current_path_index])
			body.rotation_degrees = lerp(body.rotation_degrees, eyes.rotation_degrees, .1) #lerp for visuals
			#velocity = Vector2(speed, 0).rotated(eyes.rotation)
			velocity = -(global_position-path[current_path_index]).normalized() * speed
			
		else:
			#if at destination, correct position, go to next path index.
			global_position = path[current_path_index] 
			current_path_index += 1
	else:
		current_path_index = 0
		velocity = Vector2(0, 0)
		path = [] #pathfinding done


func move_to(pos):
	path = get_node("../Navigation2D").get_simple_path(global_position, pos, 1)
	if debug:
		get_node("../trgt").global_position = (pos)
		get_node("../Line2D").points = path


# CHECKS #

func checkForEnemies():
	for i in enemiesInArea:
		if checkLOS(i) == true:
			target = i
			return true


func checkLOS(entity):
	if is_instance_valid(entity):
		var globgaglobgalab = get_world_2d().direct_space_state
		var result = globgaglobgalab.intersect_ray(global_position, entity.global_position, [self], 0x7FFFFFFF)
		
		if result:
			if result.collider.is_in_group("soldier"):
				if result.collider.team != self.team:
					return true
		else:
			return false


func checkLOSFromTo(from, to, entity):
	if is_instance_valid(entity):
		var globgaglobgalab = get_world_2d().direct_space_state
		var result = globgaglobgalab.intersect_ray(from, to, [self], 0x7FFFFFFF)
		
		if result:
			if result.collider == entity:
				return true
			else:
				return false
		else:
			return false


func checkIfPlayerVulnerable(): #Returns null for false; object ID of peek pos if true
	var checkPositions = currentCoverObj.get_parent().get_parent().get_node("peek").get_children()
	
	var peekPositions = []
	for enemy in enemiesInArea:
		for i in checkPositions:
			if checkLOSFromTo(i.global_position, enemy.global_position, enemy) == true:
				target = enemy
				
				peekPositions.append(i) 
	
	if peekPositions.empty():
		return null
	else:
		var peekPositionsDistances = []
		
		for i in peekPositions:
			peekPositionsDistances.append(i.global_position.distance_squared_to(global_position))
		var minimum = minArray(peekPositionsDistances)
		var foundPosition = peekPositions[peekPositionsDistances.find(minimum, 0)]
		return foundPosition


func checkIfVulnerable(returnObj):
	for i in enemiesInArea:
		if checkLOS(i) == true:
			if !returnObj:
				return true
			else:
				return i
	if !returnObj:
		return false
	else:
		return null


func checkCover(): #Check if still in good position
	pass


func _on_enemyDetect_body_entered(body):
	if body.is_in_group("soldier"):
		if body.team != self.team:
			enemiesInArea.append(body)


func _on_enemyDetect_body_exited(body):
	if body.is_in_group("soldier"):
		if body.team != self.team:
			enemiesInArea.erase(body)


func _on_shootCoolDown_timeout():
	canShoot = true


func _on_giveUp_timeout():
	toggleGiveUpOnArrivalOfKnownPos = false
	FSMState = IDLE
	giveUpStarted = false
	$body.rotation_degrees = 0
	$body/AnimationPlayer.stop()


func hit():
	FSMState = COVER
	health -= 1


func _on_peekTime_timeout():
	move_to(currentCoverObj.global_position)
	peekTimerStarted = false
	canPeek = false
	atPeekPos = false
	$peekCoolDown.start()
	FSMState = COVER


func _on_peekCoolDown_timeout():
	canPeek = true


func _on_coverToAttack_timeout():
	print("to attack")
	coverToAttackStarted = false
	FSMState = ATTACK
	toggleGiveUpOnArrivalOfKnownPos = true
	giveUpStarted = false
	currentCoverObj.get_parent().get_parent().cover[currentCoverObj] = false
	inCover = false
	desiredCover = Vector2(0, 0)
