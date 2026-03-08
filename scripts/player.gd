extends CharacterBody2D


const speed = 300.0
const gravity = 1000
const jump_power = 400.0

var dir_x = 0

func animate():
#	flip the sprite if going left ony if we are moving		
	$Sprite2D.flip_h = dir_x < 0 if dir_x != 0 else $Sprite2D.flip_h
	
#	change animation based on what the player is doing
	#if dir_x:
		#$AnimationPlayer
	
func get_input():
	#	jump stuff
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_power

#	update dir
	dir_x = Input.get_axis("left", "right")

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
