extends Node

signal user_logged_in()
signal peer_connnected_in_match(id: int)
signal peer_disconnnected_in_match(id: int)

enum ClientScheme {
	HTTP,
	HTTPS
}

var Players = {}

@export var server_key : String = "defaultkey"
@export var server_ip : String = "127.0.0.1"
@export var server_port : int = 7350
@export var client_scheme : ClientScheme

@export var max_party_count : int

@onready var notification_container: NotificationContainer = $NotificationContainer

var session : NakamaSession # this is the session
var client : NakamaClient # this is the client {session}
var socket : NakamaSocket # connection to nakama
var multiplayerBridge : NakamaMultiplayerBridge

var party : NakamaRTAPI.Party

var current_user : NakamaAPI.ApiUser = null

func start_client() -> void:
	client = Nakama.create_client(server_key, 
								 server_ip, 
								 server_port, 
								 get_client_scheme())

func register(email: String, password: String, username: String) -> void:
	session = await client.authenticate_email_async(email , password, null, true)

	if NakamaManager.session.is_valid():
		notification_container.create_notification("Registrado com sucesso!")
	elif NakamaManager.session.is_exception():
		var exception : NakamaException = NakamaManager.session.get_exception()
		notification_container.handle_exception(exception.status_code)
		
	await client.update_account_async(session, null, username)
	
	var users = await NakamaManager.client.get_users_async(NakamaManager.session, [NakamaManager.session.user_id])
	
	current_user = NakamaAPI.ApiUser.new()
	
	if users.users and users.users.size() > 0:
		current_user = users.users[0] as NakamaAPI.ApiUser
		
	start_socket()
		
func login(email: String, password: String) -> void:
	session = await client.authenticate_email_async(email , password, null, false)
	
	if session.is_valid():
		notification_container.create_notification("Logado com sucesso!")
	elif session.is_exception():
		var exception : NakamaException = session.get_exception()
		notification_container.handle_exception(exception.status_code)
		
	var users = await client.get_users_async(session, [session.user_id])
	
	current_user = NakamaAPI.ApiUser.new()
	
	if users.users and users.users.size() > 0:
		current_user = users.users[0] as NakamaAPI.ApiUser
	
		
	await start_socket()
		
func start_socket() -> void:
	
	socket = Nakama.create_socket_from(client)
	
	await socket.connect_async(session)
	
	socket.connected.connect(onSocketConnected)
	socket.closed.connect(onSocketClosed)
	socket.received_error.connect(onSocketReceivedError)
	
	socket.received_match_presence.connect(onMatchPresence)
	socket.received_match_state.connect(onMatchState)
	
	socket.received_channel_message.connect(onChannelMessage)
	socket.received_party_presence.connect(onPartyPresence)
	
	socket.received_notification.connect(_received_notification)
	
	setup_multiplayer_bridge()
	
	user_logged_in.emit()
	
	return session.is_valid()

func is_authority() -> bool:
	return multiplayer.get_unique_id() == 1

func create_party(is_open: bool) -> void:
	party = await socket.create_party_async(is_open, max_party_count)

func invite_friend_to_party(friend: NakamaAPI.ApiUser):
	var channel = await socket.join_chat_async(friend.id, NakamaSocket.ChannelType.DirectMessage)
	var ack = await socket.write_chat_message_async(channel.id, {
			"message" : "Join Party with "  + session.username,
			"partyID" : party.party_id,
			"type" : 1
			}
		)

func setup_multiplayer_bridge():
	multiplayerBridge = NakamaMultiplayerBridge.new(NakamaManager.socket)
	multiplayerBridge.match_join_error.connect(onMatchJoinError)
	
	multiplayer.multiplayer_peer = multiplayerBridge.multiplayer_peer
	
	multiplayer.peer_connected.connect(onPeerConnected)
	multiplayer.peer_disconnected.connect(onPeerDisconnected)

func onMatchJoinError(error):
	print("Unable to join match: " + error.message)

func onMatchJoin():
	print("joined Match with id: " + NakamaManager.multiplayerBridge.match_id)

func onMatchPresence(presence : NakamaRTAPI.MatchPresenceEvent):
	pass

func onPeerConnected(id: int):
	print("Peer connected id is : " + str(id))
	if id == 0:
		printerr("Nao foi adicionado id 0")
		return
	
	if !Players.has(id):
		Players[id] = {
			"name" : id,
		}
	if !Players.has(multiplayer.get_unique_id()):
		Players[multiplayer.get_unique_id()]= {
			"name" : multiplayer.get_unique_id(),
		}
		
	peer_connnected_in_match.emit(id)
	#update_peer_in_network.rpc_id(id)
	
@rpc("any_peer")
func update_peer_in_network() -> void:

	var multiplayer_id = multiplayer.get_unique_id()
	_update_peer_in_network.rpc(multiplayer_id, current_user.id)
	
@rpc("any_peer","call_local")
func _update_peer_in_network(multiplayer_id, nakama_id) -> void:
	
	var query = await client.get_users_async(session, [nakama_id])
	
	var user = query.users[0]
	
	Players[multiplayer_id] = user
	
func onPeerDisconnected(id):
	print("Peer disconnected id is : " + str(id))
	var user = Players[id]
	peer_disconnnected_in_match.emit(user, id)

func onMatchState(state : NakamaRTAPI.MatchData):
	pass

func onSocketConnected():
	print("Socket Connected")

func onSocketClosed():
	print("Socket Closed")

func onSocketReceivedError(err):
	print("Socket Error:" + str(err))

func onPartyPresence(presence : NakamaRTAPI.PartyPresenceEvent):
	print("JOINED PARTY " + presence.party_id)

func _received_notification(p_notification: NakamaAPI.ApiNotification) -> void:
	
	var notification_type = \
	 NotificationContainer.nakama_notification_code_to_notification(p_notification.code)
	
	notification_container.create_notification(
		p_notification.subject,
		notification_type
	)

## Toda vez que uma nova mensagem for mandada para o servidor
## essa função será invocada
func onChannelMessage(message : NakamaAPI.ApiChannelMessage) -> void:
	pass
	#var content = JSON.parse_string(message.content)
	#if content.type == 0:
		#
		#var chat_id = content.id
		#var display_name : String = ""
		#var current_conversation : TextEdit = null
		#
		#if players_username_display_name.has(chat_id):
			#
			#display_name = players_username_display_name[chat_id]
			#current_conversation = username_container.get_node(display_name)
		#elif group_chats.has(chat_id):
			#
			#var sender_info_json : NakamaAPI.ApiUsers = \
			 #await NakamaManager.client.get_users_async(NakamaManager.session, [message.sender_id])
			#var all_user_info = sender_info_json.serialize()
			#var curr_user = all_user_info.users[0]
#
			#display_name = curr_user.display_name
			#current_conversation = username_container.get_node(group_chats[chat_id])
		#else:
			#return
		#
		#current_conversation.text += display_name + ": " + str(content.message) + "\n"
		#current_conversation.scroll_vertical = current_conversation.text.count("\n")
		#
	#elif content.type == 1 && party == null:
		#
		#channel_message_panel.show()
		#party = {"id" : content.partyID}
		#channel_message_label.text = str(content.message)

func get_client_scheme() -> String:
	
	match client_scheme:
		ClientScheme.HTTP:
			return "http"
		ClientScheme.HTTPS:
			return "https"
	
	return "http"

# Update the current user's account on the server.
# @param p_username - The new username for the user.
# @param p_display_name - A new display name for the user.
# @param p_avatar_url - A new avatar url for the user.
# @param p_lang_tag - A new language tag in BCP-47 format for the user.
# @param p_location - A new location for the user.
# @param p_timezone - New timezone information for the user.
# Returns a task which represents the asynchronous operation.
func update_account(username = null, 
					display_name = null,
					avatar_url = null, 
					lang_tag = null, 
					location = null, 
					timezone = null) -> NakamaAsyncResult:
	return await client.update_account_async(session, 
									  username, 
									  display_name, 
									  avatar_url, 
									  lang_tag, 
									  location, 
									  timezone)

func write_leaderboard(leaderboard_name: String,
					   score: float,
					   subscore: float,
					   metadata: Dictionary) -> NakamaAPI.ApiLeaderboardRecord:
	return await client.write_leaderboard_record_async(session, 
													  leaderboard_name, 
													   score, 
													   subscore, 
													   JSON.stringify(metadata))
	
func is_match_created_by_user(created_match : NakamaRTAPI.Match) -> bool:
	return created_match.presences[0].user_id == current_user.id
