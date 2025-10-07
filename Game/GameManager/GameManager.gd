extends Node2D

@export var multiplayerScene : PackedScene
@onready var main_menu: NakamaMultiplayer = %MainMenu
@onready var multiplayer_scene: Node2D = $MultiplayerScene

var multiplayer_scene_instance : Level

var match_ended : bool = false

func _ready():
	main_menu.OnStartGame.connect(on_start_game)

func on_start_game():
	main_menu.visible = false
	multiplayer_scene_instance = multiplayerScene.instantiate()
	multiplayer_scene_instance.debug_mode = false
	
	multiplayer_scene.add_child(multiplayer_scene_instance)
	multiplayer_scene_instance.level_completed.connect(player_finished)
	
func player_finished() -> void:
	_player_finished.rpc()

@rpc("any_peer", "call_local")
func _player_finished() -> void:
	
	var winner_id : int = multiplayer.get_remote_sender_id()
	match_ended = true
	
	main_menu.visible = true
	multiplayer_scene_instance.queue_free()
	multiplayer_scene_instance = null
	
	if multiplayer.is_server():
		main_menu.match_ended(winner_id)
	
@rpc("authority", "call_remote")
func _end_match() -> void:
	pass
	
