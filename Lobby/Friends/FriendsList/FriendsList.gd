extends PanelContainer

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
		friends_hbox.set_friend.call_deferred(i.user.display_name, 
								_on_trade.bind(i), 
								_create_chat_with_other_player.bind(i.user.display_name),
								remove_friend_by_username.bind(i.user.username),
								block_friend_by_username.bind(i.user.username),
								_invite_friend_to_party_by_username.bind(i.user))

func _on_trade(friend) -> void:
	pass

func _create_chat_with_other_player(i) -> void:
	pass
	
func _remove_friend_from_username(i) -> void:
	pass
	
func _invite_friend_to_party_by_username(friend : NakamaAPI.ApiUser) -> void:
	pass
	

func clear_box(box: BoxContainer) -> void:
	
	for child in box.get_children():
		child.queue_free()
		child = null

func remove_friend_by_username(username: String) -> void:
	
	var result = await NakamaManager.client.delete_friends_async(NakamaManager.session,[], [username])
	
	#if result.is_exception():
		#notification_container.create_notification(
			#"Error! Não foi possível remover esse usuario", 
			#NotificationContainer.NotificationType.ERROR
		#)
	#else:
		#notification_container.create_notification(
			#"Usuário deletado com sucesso!", 
		#)
		#update_friends_list()
	
func block_friend_by_username(username: String) -> void:
	var result = await NakamaManager.client.block_friends_async(NakamaManager.session,[], [username])

	#if result.is_exception():
		#notification_container.create_notification(
			#"Error! Não foi possível bloquear esse usuario", 
			#NotificationContainer.NotificationType.ERROR
		#)
	#else:
		#notification_container.create_notification(
			#"Usuário bloqueado com sucesso!" % username, 
		#)
		##update_friends_list()


func _on_add_friend_pressed() -> void:
	var id = [add_friend_text.text.strip_edges()]
	
	var result = await NakamaManager.client.add_friends_async(NakamaManager.session, null, id)
	#
	#if result.is_exception():
		#notification_container.create_notification(
			#"Error! Não foi possível adicionar esse usuário", 
			#NotificationContainer.NotificationType.ERROR
		#)
	#else:
		#notification_container.create_notification(
			#"Usuário %s adicionado com sucesso!" % id, 
		#)
		##update_friends_list()
