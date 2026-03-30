extends CharacterBody2D


@export var speed       := 250
@export var gravity     := 1100
@export var jump_power  := 500
@export var frame_delay  = 1 #idk what this is

#movement
var dir           := Vector2()
var stamina       := 100 #not in use yet
var speed_mod     := 1.0
var jump_mod      := 1.0
var gravity_mod   := 1.0

#state
var crouching     := false
var climbing      := false
var allow_input   := true

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

#wall jump cooldown
var wall_jump_cooldown := 0

var mod_values = {
	"crouching" : 0.6,
	"climb"     : 1.5
}

func check_bound(lower, upper, num, equal=false):
	return lower >= num <= upper if equal else lower > num < upper

func animate():
	var animation = ""
	
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h
	
	if $timers/sleep.is_stopped():
		animation = "sleeping"
		allow_input = false
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
		animation = "crouching_running" if dir.x else "crouching_idle"
	elif climbing:
		animation = "climbing"
	elif not is_on_floor():
		animation = "in_air_up" if velocity.y < 1 else "in_air_down"
	else:	
		animation = "running" if dir.x else "idle"
		
	$AnimatedSprite2D.play(animation)

func toggle_crouch():
	if crouching:
		$head.disabled = true
		speed_mod = mod_values["crouching"]
	else:
		$head.disabled = false
		speed_mod = 1
	$head.position.x = (-1.0 if dir.x < 1 else 3.0) if dir.x != 0 else $head.position.x

func update_timers():
	if not dir and not climbing:
		$timers/sit.start()
		$timers/sleep.start()

func new_input(delta):
	jump_mod = 1
	gravity_mod = 1
	if wall_jump_cooldown <= 0:
		climbing = false

	dir = Input.get_vector("left","right","up","down")
	var input_map = {
		"up"    : Input.is_action_pressed("up"),
		"down"  : Input.is_action_pressed("down"),
		"climb" : Input.is_action_pressed("climb"),
		"jump"  : Input.is_action_just_pressed("jump")
	}
	
	if input_map["climb"] and is_on_wall() and wall_jump_cooldown <= 0:
		climbing = true
		speed_mod = mod_values["climb"]
		
		if input_map["jump"] and dir.x: # wall jump away from wall
			velocity.x = -dir.x * speed
			velocity.y = -jump_power
			climbing = false
			wall_jump_cooldown = 15
		elif input_map["jump"]: # wall jump straight up
			velocity.y = -jump_power
			wall_jump_cooldown = 15
		elif input_map["up"]: # climb up
			velocity.y = -speed * speed_mod * 0.5
		elif input_map["down"]: # climb down
			velocity.y = speed * speed_mod
		else: # stick to wall
			velocity.y = 0 #slide idk what you want it to be
			
	elif input_map["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
		velocity.y = -jump_power
	elif input_map["down"] and is_on_floor():
		crouching = true	
	elif not $head/ShapeCast2D.is_colliding():
		crouching = false

func update_vel(delta):
	if not is_on_floor():
		if not climbing:
			velocity.y += gravity * delta * gravity_mod

	velocity.x = dir.x * speed * speed_mod

func _physics_process(delta: float) -> void:
	new_input(delta)
	update_timers()
	frames_since_on_floor = 0 if is_on_floor() else frames_since_on_floor+1
	toggle_crouch()
	animate()
	update_vel(delta)
	move_and_slide()
	
	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= 1


#camera values:
# left: 0
# bottom: 736
