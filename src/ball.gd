extends KinematicBody2D
class_name Ball

signal bounced_wall
signal bounced_paddle
signal scored(dir)

var max_speed := 9999.0
var min_speed := 50.0
var speed := 100.0
var center := Vector2(20.0*4.0,20.0*4.0)

var velocity := Vector2()

export (Texture) var texture

var attatched_to = null

var enabled := false
var just_scored = false

var time_close_to_goal = -1

func _ready():
	randomize()
	var dir = Vector2.RIGHT.rotated(rand_range(0.0,2.0*PI))
	spawn_at_center(dir)

func reverse():
	velocity = -velocity

func turn(degrees):
	velocity = velocity.rotated(deg2rad(degrees))

func set_center(pos):
	center = pos

func get_random_dir():
	var up = Vector2.UP.rotated(rand_range(-PI/8.0,PI/8.0))
	var down = Vector2.DOWN.rotated(rand_range(-PI/8.0,PI/8.0))
	return [up,down][randi()%2]

func attatch_to_paddle(paddle, dir):
	attatched_to = paddle
	position = paddle.position + dir*16

func spawn_at_center(dir):
	global_position = center
	velocity = dir*speed

func serve():
	velocity = position.direction_to(attatched_to.position) * speed + attatched_to.velocity*attatched_to.speed
	attatched_to = null
	just_scored = false

func _process(delta):
	
	if !enabled:
		return
	
	var last_pos = global_position
	
	if is_instance_valid(attatched_to):
		position.x = attatched_to.position.x
		
	elif !just_scored:
		
		velocity = velocity.normalized()*speed
		var c : KinematicCollision2D = move_and_collide(velocity*delta)
		
		var size_y = get_parent().grid_size * 4.0
		var dis = size_y - position.y
		
		if dis < 16.0 or dis > size_y-16.0:
			time_close_to_goal += delta
		else:
			time_close_to_goal = 0.0
		
		if time_close_to_goal > 0.4:
			
			var dir = Vector2.UP
			if dis > size_y/2.0:
				dir = Vector2.DOWN
			emit_signal("scored", dir)
			just_scored = true
			time_close_to_goal = 0.0
			
		elif is_instance_valid(c):
			
			if c.collider is TileMap or global_position.distance_squared_to(last_pos) == 0.0:
				
				if (c.normal == Vector2.UP or c.normal == Vector2.DOWN):
					emit_signal("scored", c.normal)
					just_scored = true
					
				else:
					emit_signal("bounced_wall")
					$AudioStreamPlayer2D2.pitch_scale = get_parent().get_pitch()
					$AudioStreamPlayer2D2.play()
					velocity = velocity.bounce(c.normal)
				
			else:
				
				$AudioStreamPlayer2D.pitch_scale = get_parent().get_pitch()
				$AudioStreamPlayer2D.play()
				velocity = c.collider.velocity*2.0 +  velocity.bounce(c.normal.rotated(rand_range(-PI/32.0,PI/32.0)))*1.05
				c.collider.hit()
				emit_signal("bounced_paddle")
