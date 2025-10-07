extends ScrollContainer

signal map_selected(map_name: String, map_scene: String)

const CONFIG_FILE_NAME = "config.cfg"

@onready var maps: HBoxContainer = %Maps
@export var map_icon_scene : PackedScene
@export_dir var maps_directory : String

func _ready() -> void:
	
	var maps_dir = DirAccess.open(maps_directory)
	if maps_dir:
		maps_dir.list_dir_begin()
		var file_name = maps_dir.get_next()
		while file_name != "":
			if maps_dir.current_is_dir():
				
				var current_path : String = "%s/%s" % [maps_directory, file_name]
				
				var config_file = ConfigFile.new()
				var err = config_file.load("%s/%s" % [current_path, CONFIG_FILE_NAME])
				
				if err != OK:
					printerr("Nao existe config file para esse mapa!")
					file_name = maps_dir.get_next()
					continue
				
				var map_config = _get_map_config_options(config_file, current_path)
				if map_config.is_empty():
					file_name = maps_dir.get_next()
					continue

				var map_icon_instance : MapIcon = map_icon_scene.instantiate()
				
				maps.add_child(map_icon_instance)
				map_icon_instance.configure.call_deferred(map_config.map_name, map_config.map_preview_texture)
				
				map_icon_instance.map_selected.connect(_map_selected.bind(map_config.map_name, map_config.map_scene))
				
				
			file_name = maps_dir.get_next()
	else:
		print("An error occurred when trying to access the path.")


func _map_selected(map_name: String, map_scene: String) -> void:
	map_selected.emit(map_name, map_scene)
	
func _get_map_config_options(config_file: ConfigFile, current_path: String) -> Dictionary:
	
	var map_config : Dictionary
	
	var map_name : String = config_file.get_value("metadata", "name")
	var map_preview_texture : String = config_file.get_value("metadata", "preview_texture")
	var map_scene : String = config_file.get_value("metadata", "main_scene", "")
	
	if map_scene.is_empty():
		printerr("Nao existe \"main_scene\" configurado para esse mapa!")
		return {}
	
	var map_preview_texture_resource : Texture = null
	var map_preview_full_path = "%s/%s" % [current_path, map_preview_texture]
	if ResourceLoader.exists(map_preview_full_path):
		map_preview_texture_resource = load(map_preview_full_path)
	
	map_config = {
		"map_name" : map_name,
		"map_preview_texture" : map_preview_texture_resource,
		"map_scene" : "%s/%s" % [current_path, map_scene]
	}
	
	return map_config
	
