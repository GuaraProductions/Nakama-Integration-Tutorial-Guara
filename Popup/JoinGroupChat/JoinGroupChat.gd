extends Window
class_name JoinGroupChat

@onready var groups_available: OptionButton = %GroupsAvailable

var available_groups_to_current_user

func _on_about_to_popup() -> void:
	
	groups_available.clear()
	
	var result = \
	 await NakamaManager.client.list_user_groups_async(NakamaManager.session, NakamaManager.current_user.id)
	
	available_groups_to_current_user = result.user_groups
	
	for query_result in result.user_groups:
		
		groups_available.add_item(query_result.group.name)
		
func _on_join_button_pressed() -> void:
	var query = available_groups_to_current_user[groups_available.selected]
	close_requested.emit(query.group)

func _on_close_requested(_group) -> void:
	hide()
