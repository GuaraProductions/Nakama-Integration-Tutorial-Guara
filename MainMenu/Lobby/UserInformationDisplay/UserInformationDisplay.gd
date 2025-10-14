extends PanelContainer

signal chat_with_group(id: String)
signal chat_with_friend(id: String, username: String)
signal invite_friend_to_party(id: String, username: String)
signal invite_friend_to_trade(id: String, username: String)

@onready var username = %UserAccountText
@onready var display_name = %DisplayNameText
@onready var email = %EmailText

@onready var grid = $VBox/Grid
@onready var button = $VBox/HBox/Button

func update_user_info(user: NakamaAPI.ApiUser, 
					  p_email: String = "") -> void:
	username.text = user.username
	display_name.text = user.display_name
	email.text = p_email

func _on_button_pressed() -> void:
	grid.visible = not grid.visible
	button.text = "Hide" if grid.visible else "Show"

func _on_copy_user_pressed() -> void:
	DisplayServer.clipboard_set(username.text)

func _on_copy_email_pressed() -> void:
	DisplayServer.clipboard_set(email.text)

func _on_groups_player_wants_to_chat_with_group(id: String) -> void:
	chat_with_group.emit(id)

func _on_friends_chat_with_player(friend_id: String, friend_username: String) -> void:
	chat_with_friend.emit(friend_id, friend_username)

func _on_friends_invite_friend_to_party(friend_id: String, friend_username: String) -> void:
	invite_friend_to_party.emit(friend_id, friend_username)

func _on_friends_trade_with(friend_id: String, friend_username: String) -> void:
	invite_friend_to_trade.emit(friend_id, friend_username)
