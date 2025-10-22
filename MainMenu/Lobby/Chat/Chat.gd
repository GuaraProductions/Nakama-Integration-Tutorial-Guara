## Chat system for managing direct messages, group chats, and room chats.
## Handles message sending, receiving, and display for various chat types.
extends PanelContainer

#region Node References

@onready var chat_name: LineEdit = %ChatName
@onready var username_container: TabContainer = %UsernameContainer
@onready var chat_text_line_edit: LineEdit = %ChatTextLineEdit

#endregion

#region State Variables

## The currently active chat channel
var current_channel

## Dictionary mapping tab indices to channel data
var chat_channels := {}

## Dictionary mapping group IDs to chat names
var group_chats := {}

## Dictionary mapping usernames to display names
var players_username_display_name := {}

#endregion

#region Room Chat

func _ready() -> void:
	NakamaManager.user_logged_in.connect(_user_logged_in)
	
func _user_logged_in() -> void:
	NakamaManager.channel_message_received.connect(_on_channel_message)
	_sub_to_friends_channel()

## Button callback to join a chat room
func _on_join_chat_room_button_down() -> void:
	_create_chat_channel(chat_name.text.strip_edges())

## Create and join a new chat room channel
## [br][br]
## [param new_chat_name]: The name of the chat room to create/join
func _create_chat_channel(new_chat_name: String) -> void:
	var type = NakamaSocket.ChannelType.Room
	current_channel = await NakamaManager.socket.join_chat_async(new_chat_name, 
												  type, 
												  false, 
												  false)

## Called whenever a new message is received from the server
## Handles displaying the message in the appropriate chat tab
## [br][br]
## [param message]: The channel message received from Nakama
func _on_channel_message(message: NakamaAPI.ApiChannelMessage) -> void:
	var content = JSON.parse_string(message.content)
	if content.type == 0:
		
		var chat_id = message.username
		var display_name : String = ""
		var current_conversation : RichTextLabel = null
		
		if players_username_display_name.has(chat_id):
			
			display_name = players_username_display_name[chat_id]
			current_conversation = username_container.get_node(display_name)
		elif group_chats.has(chat_id):
			
			# Fetch sender info (single message, so single fetch is acceptable here)
			var sender_info_json : NakamaAPI.ApiUsers = \
			 await NakamaManager.get_users([message.sender_id])
			
			if not sender_info_json.is_exception() and sender_info_json.users and sender_info_json.users.size() > 0:
				var curr_user: NakamaAPI.ApiUser = sender_info_json.users[0]
				display_name = curr_user.display_name if curr_user.display_name != "" else curr_user.username
			else:
				display_name = "Unknown"
			
			current_conversation = username_container.get_node(group_chats[chat_id])
		else:
			return
		
		var new_channel_message: String = "%s: " % [display_name]
		
		if content.has("party_id"):
			new_channel_message += "[url={%s}]%s[/url]\n" % [content.party_id, content.message]
		else:
			new_channel_message += str(content.message) + "\n"
			
		current_conversation.text += new_channel_message
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
	
	print("\n\nchatChannels: ", chat_channels)
	
	var id = current_channel.id
	
	if not current_channel.group_id.is_empty():
		id = current_channel.group_id
	
	await NakamaManager.socket.write_chat_message_async(current_channel.id, {
		 "message" : new_message,
		"id" : id,
		"type" : 0
		})
		
	var new_channel_message: String = "%s: " % [NakamaManager.current_user.display_name]
	
	new_channel_message += text + "\n"

	username_container.get_child(username_container.current_tab).text += new_channel_message
	
func _on_join_group_chat_room_button_down(group_id: String, group_name : String) -> void:
	
	var type = NakamaSocket.ChannelType.Group
	current_channel = await NakamaManager.socket.join_chat_async(group_id, type, true, false)
	
	if current_channel.is_exception():
		get_parent().invoke_popup("Erro", "Não foi possível entrar nesse chat de grupo")
		return

	var group_chat_name : String = "%s's Chat" % [group_name]
	
	var currentEdit = RichTextLabel.new()
	currentEdit.scroll_active = true
	currentEdit.fit_content = true 
	currentEdit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	currentEdit.bbcode_enabled = true
	currentEdit.meta_clicked.connect(group_chat_meta_clicked)
	
	if username_container.has_node(group_chat_name):
		get_parent().invoke_popup("Erro", "Você já está na conversa de grupo")
		return
	
	currentEdit.name = group_chat_name
	username_container.add_child(currentEdit)
	currentEdit.text = await list_messages(current_channel)
	
	if not username_container.tab_changed.is_connected(_on_chat_tab_changed):
		username_container.tab_changed.connect(_on_chat_tab_changed)
		
	print("channel id: " + current_channel.id)
	#current_channel.group_id
	chat_channels[username_container.get_child_count()-1] = {
		"channel" : current_channel,
		"label" : group_chat_name
		}
	group_chats[group_id] = group_chat_name

## Called when user switches between chat tabs
## Updates the current channel reference
## [br][br]
## [param index]: The tab index that was selected
func _on_chat_tab_changed(index: int) -> void:
	
	if index == 0:
		current_channel = null
		return
	
	current_channel = chat_channels[index].channel

## Load and format chat messages from a channel
## Uses batch fetching to optimize performance
## [br][br]
## [param channel]: The channel to load messages from
## [br]Returns: Formatted BBCode string with all messages
func list_messages(channel):
	
	var result = \
	 await  NakamaManager.client.list_channel_messages_async(NakamaManager.session, channel.id, 100, true)
	
	# Collect all unique sender IDs first
	var sender_ids: Array[String] = []
	for message in result.messages:
		if message.sender_id and message.sender_id != "" and message.sender_id not in sender_ids:
			sender_ids.append(message.sender_id)
	
	# Fetch all users in ONE batch request
	var users_map: Dictionary = {}
	if sender_ids.size() > 0:
		var sender_info_json: NakamaAPI.ApiUsers = \
		 await NakamaManager.client.get_users_async(NakamaManager.session, PackedStringArray(sender_ids))
		
		if not sender_info_json.is_exception() and sender_info_json.users:
			for user in sender_info_json.users:
				var api_user: NakamaAPI.ApiUser = user
				users_map[api_user.id] = api_user
	
	# Build the text with pre-fetched user data
	var text = ""
	for message in result.messages:
		if message.content != "{}":
			var content = JSON.parse_string(message.content)
			
			# Get user info from the map
			var display_name = "Unknown"
			if message.sender_id in users_map:
				var user_info: NakamaAPI.ApiUser = users_map[message.sender_id]
				display_name = user_info.display_name if user_info.display_name != "" else user_info.username
			
			var new_channel_message: String = "%s: " % [display_name]
			
			if content.has("party_id"):
				new_channel_message += "[url={%s}]%s[/url]\n" % [content.party_id, content.message]
			else:
				new_channel_message += str(content.message) + "\n"
	
			text += new_channel_message
	return text
	
func _sub_to_friends_channel():
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
		currentEdit.text = await list_messages(channel)
		
		if not username_container.tab_changed.is_connected(_on_chat_tab_changed):
			username_container.tab_changed.connect(_on_chat_tab_changed)

		chat_channels[username_container.get_child_count()-1] = {
			"channel" : channel,
			"label" : i.user.username
		} 

## Button callback to join a direct message chat with a user
func _on_join_direct_chat_button_down():
	var type = NakamaSocket.ChannelType.DirectMessage
	var usersResult = await  NakamaManager.client.get_users_async(NakamaManager.session, [], [chat_name.text])
	if usersResult.users.size() > 0:
		current_channel = await NakamaManager.socket.join_chat_async(usersResult.users[0].id, type, true, false)

		var result = await  NakamaManager.client.list_channel_messages_async(NakamaManager.session, current_channel.id, 100, true)
		
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

#region Event Handlers

## Called when a clickable link in a group chat message is clicked
func group_chat_meta_clicked(_meta: Variant, _group_id: String) -> void:
	pass

## Called when a clickable link in a user chat message is clicked
func user_chat_meta_clicked(meta: Variant, username: String) -> void:
	print("clicked! meta: ", meta, " username: ", username)

## Called when a clickable username is clicked
func _on_username_meta_clicked(_meta: Variant) -> void:
	pass

#endregion
