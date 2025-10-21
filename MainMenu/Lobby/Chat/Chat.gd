extends PanelContainer

@onready var chat_name : LineEdit = %ChatName
@onready var username_container : TabContainer = %UsernameContainer
@onready var chat_text_line_edit : LineEdit = %ChatTextLineEdit

var currentChannel
var chatChannels := {}

var group_chats = {}

var players_username_display_name = {}

#region Chat Room Code
func _on_join_chat_room_button_down():
	create_chat_channel(chat_name.text.strip_edges())

func create_chat_channel(new_chat_name: String) -> void:
	var type = NakamaSocket.ChannelType.Room
	currentChannel = await NakamaManager.socket.join_chat_async(new_chat_name, 
												  type, 
												  false, 
												  false)

## Toda vez que uma nova mensagem for mandada para o servidor
## essa função será invocada
func onChannelMessage(message : NakamaAPI.ApiChannelMessage):
	print("new message 2: ", message)
	var content = JSON.parse_string(message.content)
	if content.type == 0:
		
		var chat_id = content.id
		var display_name : String = ""
		var current_conversation : RichTextLabel = null
		
		if players_username_display_name.has(chat_id):
			
			display_name = players_username_display_name[chat_id]
			current_conversation = username_container.get_node(display_name)
		elif group_chats.has(chat_id):
			
			var sender_info_json : NakamaAPI.ApiUsers = \
			 await NakamaManager.client.get_users_async(NakamaManager.session, [message.sender_id])
			var all_user_info = sender_info_json.serialize()
			var curr_user = all_user_info.users[0]

			display_name = curr_user.display_name
			current_conversation = username_container.get_node(group_chats[chat_id])
		else:
			return
		
		var new_channel_message: String = "%s: " % [display_name]
		
		if content.has("party_id"):
			new_channel_message += "[url={%s}]%s[/url]\n" % [content.party_id, content.message]
		else:
			new_channel_message += str(content.message) + "\n"
			
		current_conversation.text += new_channel_message
		current_conversation.scroll_vertical = current_conversation.text.count("\n")
		#
	#elif content.type == 1 && party == null:
		#
		#channel_message_panel.show()
		#party = {"id" : content.partyID}
		#channel_message_label.text = str(content.message)
		
func _on_submit_chat_button_down():
	
	var text : String = chat_text_line_edit.text
	
	if text.is_empty():
		NotificationContainer.create_notification("Erro! Mensagem vazia!",
												  NotificationContainer.NotificationType.ERROR)
		return
	
	#var current_username: String = chatChannels[currentChannel.id].channel.self_presence.username
	#var current_tab : int = username_container.current_tab
	var new_message : String = chat_text_line_edit.text.strip_edges()
	
	chat_text_line_edit.text = ""
	
	print("\n\nchatChannels: ", chatChannels)
	
	var id = currentChannel.id
	
	if not currentChannel.group_id.is_empty():
		id = currentChannel.group_id
	
	await NakamaManager.socket.write_chat_message_async(currentChannel.id, {
		 "message" : new_message,
		"id" : id,
		"type" : 0
		})
	
func _on_join_group_chat_room_button_down(group_id: String, group_name : String) -> void:
	
	var type = NakamaSocket.ChannelType.Group
	currentChannel = await NakamaManager.socket.join_chat_async(group_id, type, true, false)
	
	if currentChannel.is_exception():
		get_parent().invoke_popup("Erro", "Não foi possível entrar nesse chat de grupo")
		return

	var chat_name : String = "%s's Chat" % [group_name]
	
	var currentEdit = RichTextLabel.new()
	currentEdit.scroll_active = true
	currentEdit.fit_content = true 
	currentEdit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	currentEdit.bbcode_enabled = true
	currentEdit.meta_clicked.connect(group_chat_meta_clicked)
	
	if username_container.has_node(chat_name):
		get_parent().invoke_popup("Erro", "Você já está na conversa de grupo")
		return
	
	currentEdit.name = chat_name
	username_container.add_child(currentEdit)
	currentEdit.text = await listMessages(currentChannel)
	
	if not username_container.tab_changed.is_connected(onChatTabChanged):
		username_container.tab_changed.connect(onChatTabChanged)
		
	print("channel id: " + currentChannel.id)
	#currentChannel.group_id
	chatChannels[username_container.get_child_count()-1] = {
		"channel" : currentChannel,
		"label" : chat_name
		}
	group_chats[group_id] = chat_name
	
func onChatTabChanged(index: int):
	
	if index == 0:
		currentChannel = null
		return
	
	currentChannel = chatChannels[index].channel
	
func listMessages(currentChannel):
	
	var result = await  NakamaManager.client.list_channel_messages_async(NakamaManager.session, currentChannel.id, 100, true)
	var text = ""
	for message in result.messages:
		
		#var sender_info_json : NakamaAPI.ApiUsers = await NakamaManager.client.get_users_async(NakamaManager.session, [message.sender_id])
		#var all_user_info = sender_info_json.serialize()
		#print("user_info: ", user_info.users[0])
		
		if message.content != "{}":
			var content = JSON.parse_string(message.content)
		
			var new_channel_message: String = "%s: " % [message.username]
			
			if content.has("party_id"):
				new_channel_message += "[url={%s}]%s[/url]\n" % [content.party_id, content.message]
			else:
				new_channel_message += str(content.message) + "\n"
	
			text += new_channel_message
	return text
	
func subToFriendChannels():
	var result = await NakamaManager.client.list_friends_async(NakamaManager.session)
	
	for i in result.friends:
		
		var type = NakamaSocket.ChannelType.DirectMessage
		var channel = await NakamaManager.socket.join_chat_async(i.user.id, type, true, false)
		
		# Adicionando uma nova tab de conversa entre jogadores
		
		var currentEdit = RichTextLabel.new()
		currentEdit.fit_content = true 
		currentEdit.scroll_active = true
		currentEdit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		currentEdit.bbcode_enabled = true
		currentEdit.meta_clicked.connect(user_chat_meta_clicked)
		currentEdit.name = i.user.display_name
		
		
		username_container.add_child(currentEdit)
		players_username_display_name[i.user.username] = i.user.display_name
		currentEdit.text = await listMessages(channel)
		
		if not username_container.tab_changed.is_connected(onChatTabChanged):
			username_container.tab_changed.connect(onChatTabChanged)

		chatChannels[username_container.get_child_count()-1] = {
			"channel" : channel,
			"label" : i.user.username
		} 
		
func _on_join_direct_chat_button_down():
	var type = NakamaSocket.ChannelType.DirectMessage
	var usersResult = await  NakamaManager.client.get_users_async(NakamaManager.session, [], [chat_name.text])
	if usersResult.users.size() > 0:
		currentChannel = await NakamaManager.socket.join_chat_async(usersResult.users[0].id, type, true, false)

		var result = await  NakamaManager.client.list_channel_messages_async(NakamaManager.session, currentChannel.id, 100, true)
		
		for message in result.messages:
			if(message.content != "{}"):
				var content = JSON.parse_string(message.content)
			
				var new_channel_message: String = "%s: " % [message.username]
				
				if content.has("party_id"):
					new_channel_message += "[url={%s}]%s[/url]\n" % [content.party_id, content.message]
				else:
					new_channel_message += str(content.message) + "\n"
			
				chat_text_line_edit.text += new_channel_message

func invite_friend(id: String, username: String, party_id : String) -> void:
	var channel_type = NakamaSocket.ChannelType.DirectMessage
	var content = {
		"message": "Hey %s, wanna join the party?" % [username],
		party_id : party_id,
	}

	var user_channel = await NakamaManager.socket.join_chat_async(id, channel_type, true, false)
	await NakamaManager.socket.write_chat_message_async(user_channel.id, content)

#endregion

func group_chat_meta_clicked(meta: Variant, group_id: String) -> void:
	pass

func user_chat_meta_clicked(meta: Variant, username: String) -> void:
	print("clicked! meta: ", meta, " username: ", username)

func _on_username_meta_clicked(meta: Variant) -> void:
	pass
