extends Node2D

var grid_scene = load("res://src/grid.tscn")

var grid : Grid

var grid_size = 64

const UPDATE_INTERVAL = 0.01

var counter = 0.0

onready var player_paddle : Paddle = $paddle
onready var ai_paddle : Paddle = $ai_paddle
onready var ball := $ball

var music_pitch_range := Vector2(0.4,1.1)
var pitch_drop_speed = 0.01
var pitch_rise_speed = 0.05

var pitch_dir := 1.0

var scores = [0,0]
var games = [0,0]
var serve = 0

var game_number = 0
var game_base_ball_speeds := [
	100.0,
	105.0,
	111.0,
	123.0,
	136.0,
	150.0,
	165.0,
]

var sprite_folder := "res://sprites/"

var score_key = [
	load(sprite_folder + "love_text.png"),
	load(sprite_folder + "15_text.png"),
	load(sprite_folder + "30_text.png"),
	load(sprite_folder + "40_text.png"),
	load(sprite_folder + "adv_text.png"),
	load(sprite_folder + "game_text.png"),
	load(sprite_folder + "match_text.png")
]

var match_key = [
	load(sprite_folder + "0_text.png"),
	load(sprite_folder + "1_text.png"),
	load(sprite_folder + "2_text.png"),
	load(sprite_folder + "3_text.png"),
]

var volume_textures = [
	load(sprite_folder + "volume_1.png"),
	load(sprite_folder + "volume_2.png"),
	load(sprite_folder + "volume_3.png"),
	load(sprite_folder + "volume_4.png")
]

var fullscreen_texture = load(sprite_folder + "fullscreen.png")

var menu_textures := {
	"play" : {
		"position" : Vector2(12,18),
		"texture" : load(sprite_folder + "play.png"),
	},
	"volume" : {
		"position" : Vector2(12,50),
		"texture" : volume_textures[2],
	},
	"fullscreen" : {
		"position" : Vector2(32, 50),
		"texture" : fullscreen_texture,
	},
	"quit" : {
		"position" : Vector2(52,50),
		"texture" : load(sprite_folder + "quit.png"),
	},
	
}

var title_texture := load(sprite_folder + "title.png")
var cursor_texture := load(sprite_folder + "cursor.png")
var hit_effect := load(sprite_folder + "hit.png")

var sound_folder = "res://sound/"
var score_sounds := {
	"game_complete" : load(sound_folder + "cheers/cheers.ogg"),
	"win" : load(sound_folder + "win.ogg"),
	"lose" : load(sound_folder + "lose.ogg"),
}

var volumes = [
	-999.0,
	-10.0,
	-3.0,
	3.0
]

var current_volume := 2

var menu_states = [
	"play", 
	"volume",
	"fullscreen",
	"quit"
]

var menu_state = 0

var menu_idxs := {
	0 : Vector2(0,0),
	1 : Vector2(0,1),
	2 : Vector2(1,1),
	3 : Vector2(2,1),
}

var menu_postions := {
	Vector2(0,0) : 0,
	Vector2(0,1) : 1,
	Vector2(1,1) : 2,
	Vector2(2,1) : 3,
}

var game_state = "menu"
var slow_mode = false


func _ready():
	randomize()
	#Engine.target_fps = 120.0
	
	grid = grid_scene.instance()
	add_child(grid)
	grid.init(Vector2(grid_size,grid_size))
	grid.connect("screen_drawn", self, "on_screen_drawn")
	
	ball.connect("bounced_paddle", self, "on_ball_bounced_on_paddle")
	ball.connect("bounced_wall", self, "on_ball_bounced_on_wall")
	ball.connect("scored", self, "on_ball_scored")
	
	ball.set_center(Vector2(grid_size*2.0,grid_size*2.0))
	ai_paddle.set_ball(ball)
	player_paddle.set_ball(ball)
	player_paddle.global_position = Vector2(grid_size*2.0, (grid_size*4) - 10.0)
	ai_paddle.global_position = Vector2(grid_size*2.0, 16.0)
	
	$AudioStreamPlayer.pitch_scale = music_pitch_range.x + music_pitch_range.y/2.0
	grid.set_update_interval_percent($AudioStreamPlayer.pitch_scale)
	
	load_settings()
	
	show_menu()
	set_menu_state(0)

func load_settings():
	OS.window_fullscreen = SaveManager.settings["fullscreen"]
	set_volume_level(SaveManager.settings["volume"])

func set_menu_state(val):
	menu_state = val
	var s = menu_states[menu_state]
	snap_and_blit_texture(menu_textures[s]["position"]*4.0- Vector2(0,0)*-4.0,cursor_texture,10)

func show_menu():
	
	ball.enabled = false
	
	games = [0,0]
	
	game_state = "menu"
	for k in menu_textures.keys():
		var tex : Texture = menu_textures[k]["texture"]
		var pos : Vector2 = menu_textures[k]["position"]
		snap_and_blit_texture(pos*4.0,tex)
	
	snap_and_blit_texture(Vector2(42,20)*4.0,title_texture)

func select_menu_option(option):
	
	match menu_states[option]:
		
		"play":
			start_match()
		
		"fullscreen" :
			OS.window_fullscreen = !OS.window_fullscreen
			SaveManager.settings["fullscreen"] = OS.window_fullscreen
			SaveManager.save_settings()
		
		"quit":
			get_tree().quit()
		
		"volume":
			set_volume_level((current_volume + 1) % 4)
			SaveManager.settings["volume"] = current_volume
			SaveManager.save_settings()
	

func set_volume_level(v : int):
	
	current_volume = v
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),volumes[current_volume])
	menu_textures["volume"]["texture"] = volume_textures[current_volume]


func toggle_slow_mode():
	
	var old = slow_mode
	slow_mode = !slow_mode
	
	if slow_mode:
		$CanvasLayer/slow_mode.visible = true
		pitch_drop_speed = .05
		pitch_rise_speed = .025
	else:
		$CanvasLayer/slow_mode.visible = false
		pitch_drop_speed = 0.01
		pitch_rise_speed = 0.05
	

func start_match():
	
	game_state = "match"
	grid.game_started = true
	grid.is_restarting = false
	$AudioStreamPlayer.play(0.0)
	yield(get_tree().create_timer(1.0),"timeout")
	
	pulse_blit(Vector2(get_map_size().x/2.0,get_map_size().y/4.0),score_key[scores[0]],2,0.33)
	
	pulse_blit(Vector2(get_map_size().x/2.0,3.0*get_map_size().y/4.0),score_key[scores[1]],2,0.33)
	
	$paddle.enabled = true
	$ai_paddle.enabled = true
	$ball.enabled = true
	
	scores = [0,0]
	games = [0,0]
	game_number = 0
	
	ball.speed = game_base_ball_speeds[game_number]
	
	ball.attatch_to_paddle($paddle,-Vector2.DOWN)


func game_over(winner):
	
	scores[0] = 0
	scores[1] = 0
	
	games[winner] += 1
	game_number += 1
	
	if game_base_ball_speeds.size() > game_number:
		ball.speed = game_base_ball_speeds[game_number]
	
	ai_paddle.speed = 100
	player_paddle.speed = 100
	
	serve = (serve + 1)%2


func on_ball_scored(dir):
	
	var i = 0
	var j = 1
	
	var show_top = true
	var show_bottom = true
	var won_game = -1
	
	if dir == Vector2.UP:
		
		if scores[i] == 4:
			won_game = i
			show_bottom = false
		
		elif scores[i] == 3:
			
			if scores[j] < 3:
				won_game = i
				scores[i] += 1
			
			show_bottom = false
		
		if scores[j] == 4:
			scores[j] -= 1
		
		scores[i] = int(clamp(scores[i] + 1,0,5))
	
	elif dir == Vector2.DOWN:
		
		i = 1
		j = 0
		
		if scores[i] == 4:
			won_game = i
			show_top = false
		
		elif scores[i] == 3:
			
			if scores[j] < 3:
				won_game = i
				scores[i] += 1
			
			show_top = false
		
		if scores[j] == 4:
			scores[j] -= 1
		
		scores[i] = int(clamp(scores[i] + 1,0,5))
	
	if show_top:
		pulse_blit(Vector2(get_map_size().x/2.0,get_map_size().y/4.0),score_key[scores[0]],3,0.33)
	
	if show_bottom:
		pulse_blit(Vector2(get_map_size().x/2.0,3.0*get_map_size().y/4.0),score_key[scores[1]],3,0.33)
	
	if won_game != -1:
		
		game_over(won_game)
		$score_audio_player.pitch_scale = $AudioStreamPlayer.pitch_scale
		
		if games[0] == 3 or games[1] == 3:
			
			if games[0] == 3:
				
				$score_audio_player.stream = score_sounds["lose"]
				$score_audio_player.play()
				yield(get_tree().create_timer(1.0), "timeout")
				pulse_blit(Vector2(get_map_size().x/2.0,get_map_size().y/4.0),score_key[6],3,0.33)
			
			elif games[1] == 3:
				
				$score_audio_player.stream = score_sounds["win"]
				$score_audio_player.play()
				yield(get_tree().create_timer(1.0), "timeout")
				pulse_blit(Vector2(get_map_size().x/2.0,3.0*get_map_size().y/4.0),score_key[6],3,0.33)
			
			yield(get_tree().create_timer(1.0),"timeout")
			
			grid.restart()
			show_menu()
			
			return
		
		else:
			
			$score_audio_player.stream = score_sounds["game_complete"]
			$score_audio_player.play()
			
			yield(get_tree().create_timer(1.0), "timeout")
			
			pulse_blit(Vector2(get_map_size().x/2.0,get_map_size().y/4.0),match_key[games[0]],3,0.33)
			pulse_blit(Vector2(get_map_size().x/2.0,3.0*get_map_size().y/4.0),match_key[games[1]],3,0.33)
			
			yield(get_tree().create_timer(0.6), "timeout")
		
	
	if scores[0] + scores[1] == 0:
		
		if serve == 0:
			ball.attatch_to_paddle($paddle, Vector2.UP)
		else:
			ball.attatch_to_paddle($ai_paddle, Vector2.DOWN)
		
	else:
		
		var p = $paddle
		if dir == Vector2.UP:
			p = $ai_paddle
		ball.attatch_to_paddle(p,-dir)
	

func on_ball_bounced_on_wall():
	
	pitch_dir = -1.0
	snap_and_blit_texture(ball.global_position + ball.velocity.normalized()*16,hit_effect)
	
	if slow_mode:
		ball.speed = clamp(ball.speed - 1.0,ball.min_speed, ball.max_speed)
	else:
		ball.speed = clamp(ball.speed + 1.0,ball.min_speed, ball.max_speed)
	

func on_ball_bounced_on_paddle():
	
	pitch_dir = 1.0
	snap_and_blit_texture(ball.global_position + ball.velocity.normalized()*16,hit_effect)
	
	if slow_mode:
		ball.speed = clamp(ball.speed - 5.0,ball.min_speed, ball.max_speed)
	else:
		ball.speed = clamp(ball.speed + 5.0,ball.min_speed, ball.max_speed)
	

func explode_ball():
	
	pitch_dir = -1.0
	snap_and_blit_texture(ball.global_position + ball.velocity.normalized()*16,hit_effect)
	
	if slow_mode:
		ball.speed = clamp(ball.speed - 10.0,ball.min_speed, ball.max_speed)
	else:
		ball.speed = clamp(ball.speed + 10.0,ball.min_speed, ball.max_speed)
	if is_instance_valid(ball.attatched_to):
		ball.serve()
	
	$ball/AudioStreamPlayer2D.play()
	$ball/AudioStreamPlayer2D2.play()

func get_pitch():
	return $AudioStreamPlayer.pitch_scale

func get_map_size():
	return Vector2(grid_size*4.0,grid_size*4.0)

func pulse_blit(pos, texture, pulses := 3, period := 0.5):
	
	for i in range(pulses):
		snap_and_blit_texture(pos, texture)
		yield(get_tree().create_timer(period),"timeout")
	

func snap_and_blit(ball):
	
	var pos = ball.global_position#get_global_mouse_position()
	pos.x = int(pos.x / 4.0) * 4.0
	pos.y = int(pos.y / 4.0) * 4.0
	
	grid.blit_texture_at_pos(ball.texture,pos,4)

func snap_and_blit_texture(pos, texture, state := 4):
	
	pos.x = int(pos.x / 4.0) * 4.0
	pos.y = int(pos.y / 4.0) * 4.0
	
	grid.blit_texture_at_pos(texture,pos,state)

func on_screen_drawn():
	
	if grid.process_grid and !grid.is_restarting:
		snap_and_blit(ball)
		snap_and_blit(ai_paddle)
		snap_and_blit(player_paddle)
	

func _process(delta):
	
	if Input.is_action_just_pressed("fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
	
	if (is_instance_valid(grid)):
		
		if Input.is_action_just_pressed("quit"):
			grid.restart()
			show_menu()
		
		if game_state == "menu":
			
			var menu_current_vec = menu_idxs[menu_state]
			var menu_move_dir := Vector2()
			
			if Input.is_action_just_pressed("serve"):
				select_menu_option(menu_state)
			elif Input.is_action_just_pressed("ui_left"):
				menu_move_dir = Vector2.LEFT
			elif Input.is_action_just_pressed("ui_right"):
				menu_move_dir = Vector2.RIGHT
			elif Input.is_action_just_pressed("ui_up"):
				menu_move_dir = Vector2.UP
			elif Input.is_action_just_pressed("ui_down"):
				menu_move_dir = Vector2.DOWN
			
			menu_current_vec = menu_current_vec + menu_move_dir
			if menu_postions.has(menu_current_vec) and menu_move_dir != Vector2():
				menu_state = menu_postions[menu_current_vec]
			
			if game_state == "menu":
				show_menu()
				set_menu_state(menu_state)
			
		
		if grid.process_grid and !grid.is_restarting:
			
			counter += delta
			 
			if Input.is_action_just_pressed("explode"):
				explode_ball()
			
			if Input.is_action_pressed("turn_ball_left"):
				ball.turn(-20.0*delta)
			
			if Input.is_action_pressed("turn_ball_right"):
				ball.turn(20.0*delta)
			
			if Input.is_action_just_pressed("reverse_ball"):
				ball.reverse()
			
			if Input.is_action_just_pressed("toggle_slow_mode"):
				toggle_slow_mode()
			
			var new_pitch
			
			if pitch_dir > 0:
				new_pitch = $AudioStreamPlayer.pitch_scale + (delta * pitch_rise_speed)
				if new_pitch > music_pitch_range.y:
					pitch_dir = -1
			else:
				new_pitch = $AudioStreamPlayer.pitch_scale - (delta * pitch_drop_speed)
			
			$AudioStreamPlayer.pitch_scale = clamp(music_pitch_range.x +ball.speed/300.0,music_pitch_range.x,music_pitch_range.y)
			
			grid.set_update_interval_percent(new_pitch)
			
			if counter > UPDATE_INTERVAL:
				snap_and_blit(ball)
				snap_and_blit(ai_paddle)
				snap_and_blit(player_paddle)
				counter = 0.0
			
		
	

