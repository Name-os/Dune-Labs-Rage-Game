extends CharacterBody2D

@export var speed := 80.0
var gravity := 1100.0
var direction := 1.0
var move_timer := 0.0

func _ready():
	$AnimatedSprite2D.play("default")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if $"Wall Check".is_colliding() or not $"Floor Check".is_colliding():
		direction *= -1.0
		$"Wall Check".target_position.x *= -1
		$"Floor Check".position.x *= -1
		$AnimatedSprite2D.flip_h = direction < 0

	move_timer += delta
	var step_time = 4.0 / speed # how long each 4px step takes

	if move_timer >= step_time:
		move_timer -= step_time
		position.x += 4.0 * direction
		position = Vector2i(round(position / 4)) * 4

	velocity.x = 0
	move_and_slide()
