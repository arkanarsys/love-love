extends Node2D
class_name Grid

# Grid.gd
# processes and draws cellular automata
# can draw sprites onto grid using blit_texture_at_pos

signal screen_drawn

const cell_size = 4

var max_update_interval = (60.0/140.0)/8.0 # 140 BPM / 8
var update_interval = max_update_interval

var counter = 0.0
var frame = 0

var grid_size : Vector2
var grid : Array = []

var is_paused := false

#tileset index map for each cell state
var tile_key = [0,1,2,3,4,5,6,7,8,9,10]

var is_restarting = true

enum {
	CELL_EMPTY = 0,
	CELL_RED   = 1,
	CELL_BLUE  = 2,
	CELL_DYING = 3,
	CELL_KILL  = 4,
	CELL_KILLED= 5,
	CELL_K2    = 6,
	CELL_RAND  = 7,
	CELL_WALL  = 8,
	CELL_TO_DIE= 9,
	CELL_FILL  = 10
}

#currently not working properly with use_coroutine_optimization
var use_image_texture := false

#color_key is only used when use_image_texture == true
var colour_key = [
	Color(0,0,0,0),
	Color("ac3232"),
	Color.aqua,
	Color.crimson,
	Color(0,0,0,0),
	Color(0,0,0,0),
	Color.black,
	Color.antiquewhite,
	Color.cornsilk,
	Color.darkturquoise,
	Color.maroon
]

var health_grid = []
var max_health = 3

#splits update_grid_general into multiple frames
var use_coroutine_optimization := true 

var current_grid_idx := Vector2(0,0)
var rows_per_frame := 3
var continue_interval = 0.01 
var next_grid = []

onready var active_tilemap = $TileMap
onready var invisible_tilemap = $TileMap2

var process_grid := true
var game_started := false

#for changing the simulation update period at runtime
func set_update_interval_percent(p : float):
	update_interval = ((max_update_interval) * (float(rows_per_frame) / float(grid_size.x)))*p

func init(_grid_size : Vector2):
	
	grid_size = _grid_size
	
	set_update_interval_percent(1.0)
	
	for i in range(grid_size.x):
		
		var row = PoolIntArray()
		var health_row = PoolIntArray()
		
		for j in range(grid_size.y):
			
			if i == 0 or i == grid_size.x-1 or j == 0 or j == grid_size.y -1:
				row.append(CELL_WALL)
				$collisions.set_cell(i,j,0)
			else:
				row.append(10)
			
			if !use_image_texture:
				var k = row[row.size()-1]
				active_tilemap.set_cell(i,j,tile_key[k])
				invisible_tilemap.set_cell(i,j,tile_key[k])
			
			if row[row.size()-1] == 1 or row[row.size()-1] == 2:
				health_row.append(max_health/2.0 + randi()%int(ceil(max_health/2.0)))
			else:
				health_row.append(0)
				
		grid.append(row)
		health_grid.append(health_row)
	
	if use_image_texture:
		init_image_texture(grid)


#currently not set up to work with cells of more than one pixel
#colors of pixels
func init_image_texture(_grid):
	var image : Image = Image.new()
	
	image.create(_grid.size(),grid[0].size(),false,Image.FORMAT_RGB8)
	image.fill(colour_key[0])
	image.lock()
	for i in range(_grid.size()):
		for j in range(_grid[i].size()):
			image.set_pixel(i,j,colour_key[_grid[i][j]])
	
	image.unlock()
	
	$Sprite.texture.create_from_image(image,0)
	$Sprite.scale = Vector2(cell_size,cell_size)

func restart():
	for i in range(50):
		set_cell_at_pos(Vector2(rand_range(0.0,grid_size.x*4.0),rand_range(0.0,grid_size.y*4.0)),CELL_FILL)
	is_restarting = true


#processes cellular automata,
#can be processed over multiple frames
#using use_coroutine_optimization = true
func update_grid_general() -> void:
	var new_grid
	
	var i_range = [0,grid_size.x]
	var j_range = [0,grid_size.y]
	
	if use_coroutine_optimization:
		if next_grid == []:
			next_grid = grid.duplicate(true)
		new_grid = next_grid
		i_range[0] = int(current_grid_idx.x)
		j_range[0] = int(current_grid_idx.y)
	else:
		new_grid = grid.duplicate(true)
	
	
	var updated_count = 0
	var image : Image
	
	if use_image_texture:
		image = $Sprite.texture.get_data()
		image.lock()
	
	for i in range(i_range[0],i_range[1]):
		for j in range(j_range[0],j_range[1]):
			
			var reds = 0
			var blues = 0
			
			var kill_neighbors = false
			
			var fill = false
			
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					
					if x == 0 and y == 0:
						continue
					
					var ni : int = i + x
					var nj : int = j + y
					
					if ni < 0 or ni >= grid_size.x or nj < 0 or nj >= grid_size.y:
						continue
					
					if grid[ni][nj] == CELL_FILL:
						fill = true
					if grid[ni][nj] == CELL_KILL:
						kill_neighbors = true
					elif grid[ni][nj] == CELL_RED:
						reds += 1
					elif grid[ni][nj] == CELL_BLUE:
						blues += 1
			
			var neighbors = reds + blues

			
			match(grid[i][j]):
				
				CELL_EMPTY:
					if kill_neighbors:
						new_grid[i][j] = CELL_KILLED
					elif neighbors > 2:
						if reds > blues:
							health_grid[i][j] = max_health
							new_grid[i][j] = CELL_RED
						elif blues > reds:
							health_grid[i][j] = max_health
							new_grid[i][j] = CELL_BLUE
						else:
							new_grid[i][j] = 1+randi()%2
							health_grid[i][j] = max_health
					else:
						new_grid[i][j] = CELL_EMPTY
				
				CELL_RED:
					
					var new_state = CELL_RED
					if kill_neighbors:
						health_grid[i][j] = 0
						new_state = CELL_EMPTY
						
					elif neighbors < 1 or reds > 3:
						health_grid[i][j] -= 1
						new_state = CELL_DYING
						
					else:
						if blues > reds:
							health_grid[i][j] -= CELL_BLUE
							new_state = CELL_EMPTY
						elif blues == reds:
							health_grid[i][j] -= 1
							new_state = 1+randi()%2
						else:
							health_grid[i][j] -= 1
							new_state = CELL_EMPTY
					
					if new_state != CELL_RED and health_grid[i][j] <= 0:
						new_grid[i][j] =new_state
						health_grid[i][j] = max_health
					else:
						health_grid[i][j] = int(clamp(health_grid[i][j],0,max_health))
						new_grid[i][j] = CELL_RED
				
				CELL_BLUE:
					
					var new_state = CELL_BLUE
					if kill_neighbors:
						health_grid[i][j] = 0
						new_state = CELL_EMPTY
					elif neighbors < 1 or blues > 3:
						health_grid[i][j] -= 1
						new_state = CELL_DYING
					else:
						if reds > blues:
							health_grid[i][j] -= 2
							new_state = CELL_EMPTY
						elif blues == reds:
							health_grid[i][j] -= 1
							new_state =  1+randi()%2
						else:
							health_grid[i][j] -= 1
							new_state = CELL_EMPTY
					
					if new_state != CELL_BLUE and health_grid[i][j] <= 0:
						new_grid[i][j] =new_state
						health_grid[i][j] = max_health
					else:
						health_grid[i][j] = int(clamp(health_grid[i][j],0,max_health))
						new_grid[i][j] = CELL_BLUE
				
				CELL_DYING:
					if kill_neighbors:
						new_grid[i][j] = CELL_KILLED
					elif neighbors > 5:
						if reds > blues:
							new_grid[i][j] = CELL_RED
						elif blues > reds:
							new_grid[i][j] = CELL_BLUE
						else:
							new_grid[i][j] =[CELL_K2,CELL_RED,CELL_BLUE][randi()%3]
						
					else:
						new_grid[i][j] =[CELL_EMPTY,CELL_DYING,CELL_DYING,CELL_DYING,CELL_RAND][randi()%5]
				
				CELL_KILL:
					if neighbors <3:
						health_grid[i][j] = max_health*10
						new_grid[i][j] = CELL_KILLED
					else:
						new_grid[i][j] =CELL_KILL
				
				CELL_KILLED:
					if neighbors < 2:
						new_grid[i][j] =9
					else:
						if reds > blues or blues > reds:
							health_grid[i][j] -= 1
							if health_grid[i][j] <= 0:
								new_grid[i][j] = CELL_K2
							else:
								new_grid[i][j] = CELL_KILLED
						else:
							new_grid[i][j] = CELL_KILLED
				
				CELL_K2:
					if neighbors < 3:
						new_grid[i][j] = CELL_DYING
					else:
						new_grid[i][j] = CELL_TO_DIE
				
				CELL_RAND:
					new_grid[i][j] =randi()%6
				
				CELL_WALL:
					new_grid[i][j] =CELL_WALL
				
				CELL_TO_DIE:
					if kill_neighbors:
						new_grid[i][j] = CELL_DYING
					elif neighbors > 1:
						if reds > blues:
							new_grid[i][j] = CELL_RED
						elif blues > reds:
							new_grid[i][j] = CELL_BLUE
						elif !is_restarting:
							new_grid[i][j] =randi()%3
						
					else:
						new_grid[i][j] = CELL_EMPTY
				
				CELL_FILL:
					if kill_neighbors:
						new_grid[i][j] = CELL_KILLED
					if !is_restarting:
						new_grid[i][j] = 1+randi()%3
			
			if fill and is_restarting and grid[i][j] != CELL_WALL and !kill_neighbors:
				new_grid[i][j] = CELL_FILL
			
			if !use_image_texture:
				
				if use_coroutine_optimization:
					invisible_tilemap.set_cell(i,j,tile_key[new_grid[i][j]])
				else:
					active_tilemap.set_cell(i,j,tile_key[new_grid[i][j]])
				
			else:
				image.set_pixel(i,j,colour_key[new_grid[i][j]])
			
		updated_count += 1
		
		if use_coroutine_optimization and updated_count > rows_per_frame:
			current_grid_idx = Vector2(i+1,0)
			next_grid = new_grid
			return
		
	
	grid = new_grid
	next_grid = []
	current_grid_idx = Vector2(0,0)
	
	
	
	if use_image_texture:
		
		#update_image_texture(grid)
		image.unlock()
		VisualServer.texture_set_data($Sprite.texture,image)
		#$Sprite.texture.set_data(image)
		
	else:
		
		if use_coroutine_optimization:
			var temp = active_tilemap
			active_tilemap = invisible_tilemap
			invisible_tilemap = temp
			invisible_tilemap.visible = false
			active_tilemap.visible = true
	
	emit_signal("screen_drawn")
	frame += 1

func update_image_texture(_grid):
	var image : Image = $Sprite.texture.get_data()
	image.lock()
	for i in range(_grid.size()):
		for j in range(_grid[i].size()):
			image.set_pixel(i,j,colour_key[_grid[i][j]])
	image.unlock()
	VisualServer.texture_set_data($Sprite.texture,image)


func update_tilemap():
	for i in range(grid_size.x):
		for j in range(grid_size.y):
			$TileMap.set_cell(i,j,tile_key[grid[i][j]])

func set_cell_at_pos(pos, i = 1) -> Vector2:
	
	var cell_i = floor(pos.x / cell_size)
	var cell_j = floor(pos.y / cell_size)
	
	if cell_i >= 0 and cell_i < grid_size.x and cell_j >= 0 and cell_j < grid_size.y:
		if grid[cell_i][cell_j] == CELL_WALL:
			return Vector2(cell_i,cell_j)
		
		grid[cell_i][cell_j] = i
		if next_grid != []:
			next_grid[cell_i][cell_j] = i
		
		if !use_image_texture:
			active_tilemap.set_cell(cell_i,cell_j,tile_key[grid[cell_i][cell_j]])
	
	return Vector2(cell_i,cell_j)

func blit_texture_at_pos(t : Texture,pos,state):
	var image : Image = t.get_data()
	var offset = Vector2(-floor(image.get_width()/2)*$TileMap.cell_size.x,-floor(image.get_height()/2)*$TileMap.cell_size.x)
	
	var grid_image : Image
	if use_image_texture:
		grid_image = $Sprite.texture.get_data()
		grid_image.lock()
	
	image.lock()
	for i in range(image.get_width()):
		for j in range(image.get_height()):
			
			var p_c = image.get_pixel(i,j)
			var c = Color(0,0,0,0)
			
			if image.get_pixel(i,j).a == 0:
				pass
			else:
				var grid_pos = set_cell_at_pos(to_local(pos + offset + Vector2(i*$TileMap.cell_size.x,j*$TileMap.cell_size.x)),CELL_KILL)
				if use_image_texture:
					grid_image.set_pixel(int(grid_pos.x), int(grid_pos.y), colour_key[CELL_KILL])
				
	image.unlock()
	
	if use_image_texture:
		grid_image.unlock()
		$Sprite.texture.set_data(grid_image)

#called every frame
func _process(delta: float) -> void:
	
	if Input.is_action_just_pressed("pause"):
		is_paused = !is_paused
	
	if !is_paused and process_grid:
		counter += delta
		
		if counter >= update_interval:
			
			update_grid_general()
			counter = 0.0
