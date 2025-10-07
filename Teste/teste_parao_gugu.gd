extends Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var player = get_tree().get_first_node_in_group("Player")
	
	print("player" , player.ola_gugu)
	player.ola_gugu = "deimox: boa noite"
	print(player.ola_gugu)
