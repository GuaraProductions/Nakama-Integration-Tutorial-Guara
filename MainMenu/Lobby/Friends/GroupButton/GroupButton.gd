extends PanelContainer
class_name GroupButton

var callable_arrays : Array[Callable] = []
var group_id: String = ""

@onready var menu_button: MenuButton = $MenuButton

func set_group(
			 p_group_id : String,
			 p_text: String, 
			 chat_callable: Callable,
			 leave_callable: Callable) -> void:
	
	group_id = p_group_id
	menu_button.text = p_text
	
	menu_button.get_popup().id_pressed.connect(_popup_menu_pressed)
	
	callable_arrays.append_array([
		chat_callable,
		leave_callable
	])

func _popup_menu_pressed(id: int) -> void:
	menu_button.get_popup().hide()
	callable_arrays[id].call(id)
