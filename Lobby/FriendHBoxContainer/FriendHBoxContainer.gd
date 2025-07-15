extends MenuButton
class_name FriendHBoxContainer

var callable_arrays : Array[Callable] = []

func set_friend(p_text: String, 
				 trade_callable: Callable, 
				 chat_callable: Callable,
				 delete_callable: Callable,
				 block_callable: Callable) -> void:
	
	text = p_text
	
	get_popup().id_pressed.connect(_popup_menu_pressed)
	
	callable_arrays.append_array([
		trade_callable,
		chat_callable,
		block_callable,
		delete_callable
	])

func _popup_menu_pressed(id: int) -> void:
	get_popup().hide()
	callable_arrays[id].call()
