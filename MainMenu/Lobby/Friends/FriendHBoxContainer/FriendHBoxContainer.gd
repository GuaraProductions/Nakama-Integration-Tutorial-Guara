extends PanelContainer
class_name FriendHBoxContainer

var callable_arrays : Array[Callable] = []

@onready var menu_button: MenuButton = $MenuButton

func set_friend(p_text: String, 
				 trade_callable: Callable, 
				 chat_callable: Callable,
				 delete_callable: Callable,
				 block_callable: Callable,
				 party_callable) -> void:
	
	menu_button.text = p_text
	
	menu_button.get_popup().id_pressed.connect(_popup_menu_pressed)
	
	callable_arrays.append_array([
		trade_callable,
		chat_callable,
		block_callable,
		delete_callable,
		party_callable
	])

func _popup_menu_pressed(id: int) -> void:
	menu_button.get_popup().hide()
	callable_arrays[id].call()
