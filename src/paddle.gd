extends KinematicBody2D
class_name Paddle

export var speed = 100.0
export var is_player := true

var snapped_position := Vector2()
var velocity := Vector2.ZERO 

var ball_node : Ball = null

export (Texture) var texture


var map_height

var ai_min_serve_delay := 0.4
var ai_max_serve_delay := 20.0
var ai_serve_delay_counter := 0.0
var ai_serve_counter := 0.0

var enabled := false

onready var map = get_parent()

func hit():
	speed += 1.0

func _ready():
	map_height = map.get_map_size().y

func set_ball(b : Ball):
	ball_node = b

func process_input(delta):
	
	velocity = Vector2()
	if Input.is_action_pressed("ui_left"):
		velocity += Vector2.LEFT
	if Input.is_action_pressed("ui_right"):
		velocity += Vector2.RIGHT
	
	velocity.normalized()
	move_and_collide(velocity*speed*delta)
	
	if Input.is_action_just_pressed("serve") and ball_node.attatched_to == self:
		ball_node.serve()

func process_ai(delta):
	if is_instance_valid(ball_node):
		var direction = sign(ball_node.position.x - position.x)
		var ball_distance = ball_node.position.y - position.y
		
		velocity = Vector2()
		if ball_node.velocity.y > 0.0:
			direction = [-1,1][randi()%2]
		
		velocity.x = direction
		move_and_collide(velocity * speed*delta)
		
		if ball_node.attatched_to == self:
			ai_serve_delay_counter += delta 
			ai_serve_counter += delta
			
			if (ai_serve_delay_counter > ai_min_serve_delay and ai_serve_counter > 1.0):
				
				if rand_range(0.0,1.0) < 0.1 or ai_serve_counter >= ai_max_serve_delay:
				
					ball_node.serve()
					ai_serve_counter = 0.0
				
				ai_serve_delay_counter = 0.0
			
		
	

func _process(delta):
	
	if !enabled:
		return
	
	if is_player:
		process_input(delta)
	else:
		process_ai(delta)
	
