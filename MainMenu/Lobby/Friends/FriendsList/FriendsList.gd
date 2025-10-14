extends PanelContainer

signal trade_with(friend_id: String, friend_username: String)
signal chat_with_player(friend_id: String, friend_username: String)
signal invite_friend_to_party(friend_id: String, friend_username: String)

@export var friends_packed_scene : PackedScene

@onready var friends_container: VBoxContainer = %FriendsContainer
@onready var add_friend_text: LineEdit = %AddFriendText
@onready var add_friend: Button = %AddFriend

func _ready() -> void:
	NakamaManager.user_logged_in.connect(update_friends_list)

func update_friends_list() -> void:
	var result = await NakamaManager.client.list_friends_async(NakamaManager.session)
	
	clear_box(friends_container)
	
	for i in result.friends:
		
		var friends_hbox : FriendHBoxContainer = friends_packed_scene.instantiate()
		
		friends_container.add_child(friends_hbox)
		friends_hbox.set_friend(i.user.display_name, 
								_on_trade.bind(i.user.id, i.user.display_name), 
								_create_chat_player.bind(i.user.id),
								remove_friend_by_username.bind(i.user.id, i.user.display_name),
								block_friend_by_username.bind(i.user.id, i.user.display_name),
								_invite_friend_to_party_by_username.bind(i.user.id, i.user.display_name))

func _on_trade(id: String, username: String) -> void:
	trade_with.emit(id , username)

func _create_chat_player(id: String) -> void:
	chat_with_player.emit(id)
	
func _invite_friend_to_party_by_username(id: String, username: String) -> void:
	invite_friend_to_party.emit(id, username)

func clear_box(box: BoxContainer) -> void:
	
	for child in box.get_children():
		child.queue_free()
		child = null

func remove_friend_by_username(id: String, username: String) -> void:
	
	var result = await NakamaManager.client.delete_friends_async(NakamaManager.session,[id])
	
	if result.is_exception():
		NotificationContainer.create_notification(
			"Error! Não foi possível bloquear esse usuario", 
			NotificationContainer.NotificationType.ERROR
		)
	else:
		NotificationContainer.create_notification(
			"Usuário bloqueado com sucesso!" % username, 
		)
	update_friends_list()
	
	
func block_friend_by_username(id: String, username: String) -> void:
	var result = await NakamaManager.client.block_friends_async(NakamaManager.session,[id])

	if result.is_exception():
		NotificationContainer.create_notification(
			"Error! Não foi possível bloquear esse usuario", 
			NotificationContainer.NotificationType.ERROR
		)
	else:
		NotificationContainer.create_notification(
			"Usuário bloqueado com sucesso!" % username, 
		)
	update_friends_list()


func _on_add_friend_pressed() -> void:
	var id = [add_friend_text.text.strip_edges()]
	
	var result = await NakamaManager.client.add_friends_async(NakamaManager.session, null, id)
	
	if result.is_exception():
		NotificationContainer.create_notification(
			"Error! Não foi possível adicionar esse usuário", 
			NotificationContainer.NotificationType.ERROR
		)
	else:
		NotificationContainer.create_notification(
			"Usuário %s adicionado com sucesso!" % id, 
		)
	
	update_friends_list()
