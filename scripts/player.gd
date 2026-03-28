extends CharacterBody2D


@export var speed       := 250
@export var gravity     := 1100
@export var jump_power  := 410
@export var frame_delay  = 1 #idk what this is

#movement
var dir_x     := 0.0
var stamina   := 100 #not in use yet
var speed_mod := 1.0
var jump_mod  := 1.0

#acelleration
var acel_amount := 50
var max_speed  := 250


#state
#var current_state
#enum states {idle, running, jumping, crouching, climbing}
var crouching   := false
var climbing    := false
var allow_input := true

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

var mod_values = {
	"crouching" : 0.6,
	"climb"     : 0.4,
}

func check_bound(lower, upper, num, equal=false):
	return lower >= num <= upper if equal else lower > num < upper

func animate():
	var animation = ""
	
#	flip the sprite if going left ony if we are moving		
	$AnimatedSprite2D.flip_h = dir_x < 0 if dir_x != 0 else $AnimatedSprite2D.flip_h
	
	if $timers/sleep.is_stopped():
		animation = "sleeping"
		allow_input = false
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
		animation = "crouching_running" if dir_x else "crouching_idle"
	elif climbing:
		animation = "climbing"
	elif not is_on_floor():
		animation = "in_air_up" if velocity.y < 1 else "in_air_down"
	else:	
		animation = "running" if dir_x else "idle"
		
	$AnimatedSprite2D.play(animation)

func toggle_crouch(): #could make more clean
	if crouching:
		$head.disabled = true
		speed_mod = mod_values["crouching"]
	else:
		$head.disabled = false
		speed_mod = 1
#	change head hit box dir based on dir
	$head.position.x = (-1.0 if dir_x < 1 else 3.0) if dir_x != 0 else $head.position.x

func update_timers():
	if dir_x or crouching or climbing or velocity.y == -jump_power:
		$timers/sit.start()
		$timers/sleep.start()

func get_input():
	jump_mod = 1
	climbing = false
	
	if allow_input:
		dir_x = Input.get_axis("left", "right")
		var input_map = {
			"jump"   : Input.is_action_pressed("jump"),
			"climb"  : Input.is_action_pressed("climb"),
			"crouch" : Input.is_action_pressed("crouch"),
		}
		if input_map["climb"]:
			if is_on_wall() and dir_x != 0:
				climbing = true
				speed_mod = 0.5
				velocity.y = Input.get_axis("jump", "crouch") * speed * speed_mod #overide the y vel
		elif input_map["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
			velocity.y = -jump_power
		elif input_map["crouch"] and is_on_floor():
			crouching = true
		elif not $head/ShapeCast2D.is_colliding(): #not allow uncrouch if head is clipped
			crouching = false

func update_vel(delta):
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# X axis acceleration
	if dir_x != 0:
		# Increment speed if it hasn't reached the limit
		if speed < max_speed:
			speed += acel_amount
		
		# Clamp speed so it doesn't exceed terminal velocity
		if speed > max_speed:
			speed = max_speed
	else:
		# Reset current speed when there is no input
		speed = 0
		
	# Apply final horizontal velocity
	velocity.x = dir_x * speed * speed_mod

func _physics_process(delta: float) -> void:
	get_input()
	update_timers()
	frames_since_on_floor = 0 if is_on_floor() or climbing else frames_since_on_floor+1 #update frames since on floor
	toggle_crouch()
	animate() #animate based on state
	update_vel(delta) #update the player vel
	move_and_slide() #update position and adds delta
	position = Vector2i(round(position/4))*4 #make movement pixel perfect
