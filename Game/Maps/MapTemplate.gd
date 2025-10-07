extends Node2D
class_name Level

signal level_completed()

var spawnpoints : Array[Node]
@export var playerScene : PackedScene
@export var debug_mode : bool
@export var end_flag : Area2D
@export var level_void : Area2D

@onready var camera: Camera2D = %Camera

func _ready() -> void:

	end_flag.body_entered.connect(_end_level)
	level_void.body_entered.connect(_respawn_player)
	
	spawnpoints = get_tree().get_nodes_in_group("SpawnPoint")
	
	if debug_mode:
		_spawn_debug_player()
		return
		
	if multiplayer.is_server():
		print("sou o server")
		var index = 0
		var players : Array = NakamaManager.Players.values()
		print("players: ", players)
		players.sort()
		
		for player in players:
			
			var data : Dictionary = {
				"index": index,
				"id" : player.name,
			}
			_spawn_player.rpc(data)
			
			index += 1
	else:
		print("não sou o server")

func _spawn_debug_player() -> void:
	var instancedPlayer = playerScene.instantiate()
	instancedPlayer.name = "Player"
	instancedPlayer.global_position = spawnpoints[0].global_position

	add_child(instancedPlayer)
	
	instancedPlayer.setup_camera(camera)

@rpc("any_peer","call_local")
func _spawn_player(data: Dictionary) -> void:
	var instancedPlayer = playerScene.instantiate()
	instancedPlayer.name = str(data.id)
	instancedPlayer.global_position = spawnpoints[data.index].global_position

	add_child(instancedPlayer)
	
	if _is_authority(data.id):
		instancedPlayer.setup_camera(camera)
		
func _is_authority(user_id: int) -> bool:
	return user_id == multiplayer.get_unique_id()
		
func _respawn_player(player: CharacterBody2D) -> void:
	player.global_position = spawnpoints.pick_random().global_position

func _end_level(body: CharacterBody2D) -> void:
	var _player_name = body.name
	level_completed.emit()
