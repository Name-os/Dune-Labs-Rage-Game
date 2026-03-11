extends CharacterBody2D


@export var speed = 200
@export var gravity = 1000
@export var jump_power = 700.0
@export var frame_delay = 0.15
#var on_floor_last_frame = false
var dir_x = 0

#func loop_check(num_checks, condition):
	#for i in range(num_checks):
		#if condition:
			#

func check_bound(lower, upper, num, equal=false):
	return lower >= num <= upper if equal else lower > num < upper

func animate():
#	flip the sprite if going left ony if we are moving		
	$AnimatedSprite2D.flip_h = dir_x < 0 if dir_x != 0 else $AnimatedSprite2D.flip_h
	$AnimatedSprite2D.play("running" if dir_x else "idle")	
	if not is_on_floor():
		$AnimatedSprite2D.play("in_air_up" if velocity.y < 1 else "in_air_down")
	
func get_input():
#	update dir
	dir_x = Input.get_axis("left", "right")
	
	#	jump stuff
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_power
		
func apply_gravity(delta):
	#	gravity
	if not is_on_floor():
		velocity.y += gravity * delta

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	get_input()
	velocity.x = dir_x * speed #update x vel
	animate() #animate based on state
	move_and_slide() #update position and adds delta
