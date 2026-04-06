extends CharacterBody2D

@export var speed      := 250
@export var gravity    := 1100
@export var jump_power := 500

#movement
var dir                 := Vector2()
var speed_mod           := 1.0
var gravity_mod         := 1.0
var velocity_last_frame := Vector2.ZERO

#stamina costs
var stamina_max            := 1000 #large stamina value for testing
var stamina                := stamina_max
var stamina_drain_climb    := 18.0
var stamina_drain_grip     := 12.0
var stamina_cost_wall_jump := 20.0

#state
var crouching           := false
var climbing            := false
var climbing_moving     := false
var allow_input         := true
var was_on_floor        := false

#transition frame timers
var land_frames   := 0
var jump_frames   := 0
var land_duration := 13
var jump_duration := 3

#heavy landing threshold
var land_velocity_threshold := 800.0

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

#wall jump cooldown
var wall_jump_cooldown := 10
var wall_jump_cooldown_ := 15 #not in use yet

#springshroom related stuff
var shroom_jump_radius := 40;
var springshrooms := []

#checkpoints and teleport points
var last_checkpoint := Vector2.ZERO

#modifier values for either jumping or running
var mod_values = {
	"crouching" : 0.6,
	"climb"     : 1.5,
	"shroom_jump": 1.5,
}

func _ready(): #runs on start
#	this allows faster distance calculations as we dont need to square root but instead we need to square the value
	shroom_jump_radius *= shroom_jump_radius
#	make a preloaded list of springshrooms so we dont have to generate a new list every single time
	for shroom in get_tree().get_nodes_in_group("springshroom"):
		springshrooms.append(shroom)
		
func cap(value, min_val, max_val): #may be broken
	value = min(value, max_val) if max_val else value
	value = max(value, min_val) if min_val else value
	return value

func animate(): #could prbly optimise
#	flip the sprite based on direction
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h
	
	var animation = "" #the animation we will play
	
	if $timers/sleep.is_stopped():
		animation = "sleeping"
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
#		we are crouching but depending on if we are moving we play a different animation
		animation = "crouching_running" if dir.x and not $body/ShapeCast2D.is_colliding() else "crouching_idle"
	elif climbing:
		animation = "climbing"
	elif land_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 6
		return
	elif jump_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 2
		return
	elif not is_on_floor():
		$AnimatedSprite2D.play("jumping")
		if velocity.y < -100:
			$AnimatedSprite2D.frame = 3
		elif velocity.y < 0:
			$AnimatedSprite2D.frame = 4
		else:
			$AnimatedSprite2D.frame = 5
		return
	else:
#		play different animation based on direction
		animation = "running" if dir.x and not $body/ShapeCast2D.is_colliding() else "idle"
		
	$AnimatedSprite2D.play(animation) #play the aniamtion

func toggle_crouch():
	$head.disabled = crouching #enable or disable head hitbox so we can become smaller to crouch
	speed_mod = mod_values["crouching"] if crouching else 1.0 #change speed to match crouching state

func update_timers():
#	these timers make us sleep or sit based on if we added input reacently
	if dir or climbing or velocity.y != 0: #condtions to reset timers so we dont sit or sleep
		$timers/sit.start()
		$timers/sleep.start()
		
	#for timer debugging
	#print(str($timers/sit.time_left) + "   " + str($timers/sleep.time_left))
	
func update_stamina(delta):
	if is_on_floor(): #reset stamina when on ground
		stamina = stamina_max
	elif climbing: #stamina for climbing
#		choose which amount of stamina do deduct, grip or climb
		stamina -= (stamina_drain_climb if climbing_moving else stamina_drain_grip) * delta
		
		#cap the stamina at min 0
		stamina = cap(stamina, 0, null) #may be broken

func force_state_update():
	if not is_on_floor(): #force crouching to be off when not on ground
		crouching = false
	if climbing and crouching: #cant have both states active at the same time
		push_error("2 states are active at the same time")

func climb(im):
#	cant climb if stamina is below or equal to 0
	if stamina < 1:
		climbing = false
		return
		
	climbing = true #we are climbing
	speed_mod = mod_values["climb"] #modify speed on wall
 
	if im["jump"]: #if we jump on wall
		climbing = false #make no longer climbing as if not going off wall they can just stick back
		wall_jump_cooldown = 15 #make a jump cooldown in frames
		jump_frames = jump_duration #idk
		stamina -= stamina_cost_wall_jump #reduce stamina by correct amount
		stamina = cap(stamina, 0, null) #cap stamina at min 0

#		the less stamina the less of a jump, so ratio
		var ratio = cap(stamina / stamina_cost_wall_jump, null, 1.0) #cap ratio at max 1.0

		#velocity.x = dir.x * speed if dir.x else velocity.x #redundant but here for now
		velocity.y = -jump_power * ratio #jump with correct ratio
	elif dir.y: #going up or down with no jump
		climbing_moving = true #we are moving
		velocity.y = speed * dir.y #move correctly
	else:
		velocity.y = 0 #we aren't moving
		
func get_input():
	#for testing
	if Input.is_action_just_pressed("checkpoint"):
		last_checkpoint = position
	
	if not allow_input: #if not input dont allow
		return
		
	#default values
	gravity_mod = 1.0 #modifier for gravity
	climbing_moving = false #if we moving while climbing
	crouching = false if not is_on_floor() else crouching #not allow crouching if not on ground
	climbing = false if wall_jump_cooldown < 1 else climbing #not allow climbing if cooldown is active

	#get axis but no normalization
	dir.x = Input.get_axis("left", "right")
	dir.y = Input.get_axis("up", "down")
	#change head position based on movement
	$head.position.x = (-1.0 if dir.x < 0 else 3.0) if dir.x != 0 else $head.position.x #move head to the right position
	
#	create a movement map
	var im = {
		"up"    : Input.is_action_pressed("up"),
		"down"  : Input.is_action_pressed("down"),
		"climb" : Input.is_action_pressed("climb"),
		"jump"  : Input.is_action_just_pressed("jump")
	}

	if im["climb"] and $body/ShapeCast2D.is_colliding() and wall_jump_cooldown <= 0 and not $head/ShapeCast2D.is_colliding():
		climb(im)
	elif not $head/ShapeCast2D.is_colliding(): #dont allow certain things if head is clipped
		if im["jump"] or velocity.y > 0:
			for shroom in springshrooms: #could optimise using different nodes #springshroom jumping
				if position.distance_squared_to(shroom.position) <= shroom_jump_radius:
					velocity.y = -jump_power * mod_values["shroom_jump"]
					shroom.play("spring")
					return
		if im["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
			velocity.y = -jump_power
			jump_frames = jump_duration #may need to add to shroom bit
		else:
			crouching = im["down"] and is_on_floor() and not im["climb"]

func update_vel(delta):
	if not is_on_floor() and not climbing:
		velocity.y += gravity * delta * gravity_mod
	if land_frames > 0:
		velocity.x = 0
	else:
		velocity.x = dir.x * speed * speed_mod

#	check if touching hurtbox
	if $hitbox.is_colliding():
		position = last_checkpoint

func _physics_process(delta: float) -> void:	
	if land_frames <= 0:
		allow_input = true

	frames_since_on_floor = 0 if is_on_floor() else frames_since_on_floor + 1
	get_input()
	update_stamina(delta)
	update_timers()
	toggle_crouch()
	force_state_update()
	update_vel(delta)
	velocity_last_frame = velocity
	move_and_slide()


	# detect landing right before animate so land_frames is set before animate reads it
	if is_on_floor() and not was_on_floor:
		if velocity_last_frame.y >= land_velocity_threshold:
			land_frames = land_duration
			allow_input = false
			jump_frames = 0

	animate()
	was_on_floor = is_on_floor()

	land_frames = land_frames - 1 if land_frames > 0 else land_frames
	jump_frames = jump_frames - 1 if jump_frames > 0 else jump_frames
	wall_jump_cooldown = wall_jump_cooldown - 1 if wall_jump_cooldown > 0 else wall_jump_cooldown

#camera values:
# left: 0
# bottom: 736
