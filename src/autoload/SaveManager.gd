extends Node

var settings := {
	"volume" : 2,
	"fullscreen" : false
}
func save_settings():#_settings : Dictionary):
	#settings = _settings.duplicate(true)
	var f := File.new()
	f.open("user://settings.json",File.WRITE)
	f.store_line(JSON.print(settings))

func load_settings():
	var f := File.new()
	if f.file_exists("user://settings.json"):
		f.open("user://settings.json",File.READ)
		settings = JSON.parse(f.get_as_text()).result

func _ready():
	load_settings()
