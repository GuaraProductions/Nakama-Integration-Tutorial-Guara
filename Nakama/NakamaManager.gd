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
		NotificationContainer.create_notification("Registrado com sucesso!")
	elif NakamaManager.session.is_exception():
		var exception : NakamaException = NakamaManager.session.get_exception()
		NotificationContainer.handle_exception(exception.status_code)
		
	await client.update_account_async(session, null, username)
	
	var users = await NakamaManager.client.get_users_async(NakamaManager.session, [NakamaManager.session.user_id])
	
	current_user = NakamaAPI.ApiUser.new()
	
	if users.users and users.users.size() > 0:
		current_user = users.users[0] as NakamaAPI.ApiUser
		
	start_socket()
		
func login(email: String, password: String) -> void:
	session = await client.authenticate_email_async(email , password, null, false)
	
	if session.is_valid():
		NotificationContainer.create_notification("Logado com sucesso!")
	elif session.is_exception():
		var exception : NakamaException = session.get_exception()
		NotificationContainer.handle_exception(exception.status_code)
		
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

func is_in_party() -> bool:
	return party != null

func create_party(is_open: bool) -> NakamaRTAPI.Party:
	party = await socket.create_party_async(is_open, max_party_count)
	
	return party

func get_party_id() -> String:
	return party.party_id if party else ""

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
	
	NotificationContainer.create_notification(
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

func leave_group(id: String) -> NakamaAsyncResult:
	return await client.leave_group(session, id)
	

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

#region Friend Management

## Add one or more friends by id or username.
## [br][br]
## [param ids]: The ids of the users to add or invite as friends.
## [param usernames]: The usernames of the users to add as friends.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func add_friends(ids: PackedStringArray = [], usernames: PackedStringArray = []) -> NakamaAsyncResult:
	return await client.add_friends_async(session, ids, usernames)

## Delete one or more friends by id or username.
## [br][br]
## [param ids]: The ids of the users to delete as friends.
## [param usernames]: The usernames of the users to delete as friends.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_friends(ids: PackedStringArray, usernames: PackedStringArray = []) -> NakamaAsyncResult:
	return await client.delete_friends_async(session, ids, usernames)

## Block one or more friends by id or username.
## [br][br]
## [param ids]: The ids of the users to block.
## [param usernames]: The usernames of the users to block.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func block_friends(ids: PackedStringArray, usernames: PackedStringArray = []) -> NakamaAsyncResult:
	return await client.block_friends_async(session, ids, usernames)

## List all friends for the current user.
## [br][br]
## [param state]: Filter by friend state (optional).
## [param limit]: Maximum number of records to return (optional).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiFriendList containing the user's friends.
func list_friends(state = null, limit = null, cursor = null):
	return await client.list_friends_async(session, state, limit, cursor)

## Import Facebook friends and add them to the user's account.
## [br][br]
## [param token]: The Facebook access token.
## [param reset]: Whether to reset the friend list (optional).
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func import_facebook_friends(token: String, reset = null) -> NakamaAsyncResult:
	return await client.import_facebook_friends_async(session, token, reset)

## Import Steam friends and add them to the user's account.
## [br][br]
## [param token]: The Steam access token.
## [param reset]: Whether to reset the friend list (optional).
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func import_steam_friends(token: String, reset = null):
	return await client.import_steam_friends_async(session, token, reset)

#endregion

#region Group Management

## Create a new group with the specified parameters.
## [br][br]
## [param group_name]: The name of the group.
## [param description]: A description for the group (default: empty).
## [param avatar_url]: An avatar URL for the group (optional).
## [param lang_tag]: A language tag for the group (optional).
## [param open]: Whether the group is open for anyone to join (default: true).
## [param max_count]: Maximum number of members allowed (default: 100).
## [br][br]
## Returns a NakamaAPI.ApiGroup representing the created group.
func create_group(group_name: String, description: String = "", avatar_url = null, lang_tag = null, open: bool = true, max_count: int = 100):
	return await client.create_group_async(session, group_name, description, avatar_url, lang_tag, open, max_count)

## Delete a group by ID. Only group owners can delete groups.
## [br][br]
## [param group_id]: The ID of the group to delete.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_group(group_id: String) -> NakamaAsyncResult:
	return await client.delete_group_async(session, group_id)

## Join an existing group by ID.
## [br][br]
## [param group_id]: The ID of the group to join.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func join_group(group_id: String) -> NakamaAsyncResult:
	return await client.join_group_async(session, group_id)

## List and filter groups based on various criteria.
## [br][br]
## [param group_name]: Filter by group name (optional).
## [param limit]: Maximum number of groups to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [param lang_tag]: Filter by language tag (optional).
## [param members]: Filter by member count (optional).
## [param open]: Filter by open status (optional).
## [br][br]
## Returns a NakamaAPI.ApiGroupList containing matching groups.
func list_groups(group_name = null, limit: int = 10, cursor = null, lang_tag = null, members = null, open = null):
	return await client.list_groups_async(session, group_name, limit, cursor, lang_tag, members, open)

## List all groups a specific user is a member of.
## [br][br]
## [param user_id]: The ID of the user.
## [param state]: Filter by membership state (optional).
## [param limit]: Maximum number of groups to return (optional).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiUserGroupList containing the user's groups.
func list_user_groups(user_id: String, state = null, limit = null, cursor = null):
	return await client.list_user_groups_async(session, user_id, state, limit, cursor)

## List all users that are members of a specific group.
## [br][br]
## [param group_id]: The ID of the group.
## [param state]: Filter by user state in the group (optional).
## [param limit]: Maximum number of users to return (optional).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiGroupUserList containing the group's members.
func list_group_users(group_id: String, state = null, limit = null, cursor = null):
	return await client.list_group_users_async(session, group_id, state, limit, cursor)

## Update properties of an existing group.
## [br][br]
## [param group_id]: The ID of the group to update.
## [param group_name]: New name for the group (optional).
## [param description]: New description for the group (optional).
## [param avatar_url]: New avatar URL for the group (optional).
## [param lang_tag]: New language tag for the group (optional).
## [param open]: New open status for the group (optional).
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func update_group(group_id: String, group_name = null, description = null, avatar_url = null, lang_tag = null, open = null) -> NakamaAsyncResult:
	return await client.update_group_async(session, group_id, group_name, description, avatar_url, lang_tag, open)

## Add one or more users to a group.
## [br][br]
## [param group_id]: The ID of the group.
## [param ids]: Array of user IDs to add to the group.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func add_group_users(group_id: String, ids: PackedStringArray) -> NakamaAsyncResult:
	return await client.add_group_users_async(session, group_id, ids)

## Kick one or more users from a group.
## [br][br]
## [param group_id]: The ID of the group.
## [param ids]: Array of user IDs to kick from the group.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func kick_group_users(group_id: String, ids: PackedStringArray) -> NakamaAsyncResult:
	return await client.kick_group_users_async(session, group_id, ids)

## Promote one or more users to administrators in a group.
## [br][br]
## [param group_id]: The ID of the group.
## [param ids]: Array of user IDs to promote.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func promote_group_users(group_id: String, ids: PackedStringArray) -> NakamaAsyncResult:
	return await client.promote_group_users_async(session, group_id, ids)

## Demote one or more administrators to regular members in a group.
## [br][br]
## [param group_id]: The ID of the group.
## [param user_ids]: Array of user IDs to demote.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func demote_group_users(group_id: String, user_ids: Array):
	return await client.demote_group_users_async(session, group_id, user_ids)

#endregion

#region Leaderboard Management

## List records from a leaderboard with optional filtering.
## [br][br]
## [param leaderboard_id]: The ID of the leaderboard.
## [param owner_ids]: Filter by owner IDs (optional).
## [param expiry]: Filter by expiry time (optional).
## [param limit]: Maximum number of records to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiLeaderboardRecordList containing the leaderboard records.
func list_leaderboard_records(leaderboard_id: String, owner_ids = null, expiry = null, limit: int = 10, cursor = null):
	return await client.list_leaderboard_records_async(session, leaderboard_id, owner_ids, expiry, limit, cursor)

## List leaderboard records around a specific owner.
## [br][br]
## [param leaderboard_id]: The ID of the leaderboard.
## [param owner_id]: The ID of the owner to center the results around.
## [param expiry]: Filter by expiry time (optional).
## [param limit]: Maximum number of records to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiLeaderboardRecordList centered around the owner.
func list_leaderboard_records_around_owner(leaderboard_id: String, owner_id: String, expiry = null, limit: int = 10, cursor = null):
	return await client.list_leaderboard_records_around_owner_async(session, leaderboard_id, owner_id, expiry, limit, cursor)

## Delete the current user's record from a leaderboard.
## [br][br]
## [param leaderboard_id]: The ID of the leaderboard.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_leaderboard_record(leaderboard_id: String) -> NakamaAsyncResult:
	return await client.delete_leaderboard_record_async(session, leaderboard_id)

#endregion

#region Tournament Management

## Join a tournament by ID.
## [br][br]
## [param tournament_id]: The ID of the tournament to join.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func join_tournament(tournament_id: String) -> NakamaAsyncResult:
	return await client.join_tournament_async(session, tournament_id)

## List available tournaments with filtering options.
## [br][br]
## [param category_start]: Filter by category start range.
## [param category_end]: Filter by category end range.
## [param start_time]: Filter by start time.
## [param end_time]: Filter by end time.
## [param limit]: Maximum number of tournaments to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiTournamentList containing available tournaments.
func list_tournaments(category_start: int, category_end: int, start_time: int, end_time: int, limit: int = 10, cursor = null):
	return await client.list_tournaments_async(session, category_start, category_end, start_time, end_time, limit, cursor)

## List records from a tournament with optional filtering.
## [br][br]
## [param tournament_id]: The ID of the tournament.
## [param owner_ids]: Filter by owner IDs (optional).
## [param limit]: Maximum number of records to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [param expiry]: Filter by expiry time (optional).
## [br][br]
## Returns a NakamaAPI.ApiTournamentRecordList containing tournament records.
func list_tournament_records(tournament_id: String, owner_ids = null, limit: int = 10, cursor = null, expiry = null):
	return await client.list_tournament_records_async(session, tournament_id, owner_ids, limit, cursor, expiry)

## List tournament records around a specific owner.
## [br][br]
## [param tournament_id]: The ID of the tournament.
## [param owner_id]: The ID of the owner to center the results around.
## [param limit]: Maximum number of records to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [param expiry]: Filter by expiry time (optional).
## [br][br]
## Returns a NakamaAPI.ApiTournamentRecordList centered around the owner.
func list_tournament_records_around_owner(tournament_id: String, owner_id: String, limit: int = 10, cursor = null, expiry = null):
	return await client.list_tournament_records_around_owner_async(session, tournament_id, owner_id, limit, cursor, expiry)

## Submit a score record to a tournament.
## [br][br]
## [param tournament_id]: The ID of the tournament.
## [param score]: The score value to submit.
## [param subscore]: An optional secondary score for tie-breaking (default: 0).
## [param metadata]: Optional metadata to attach to the record.
## [br][br]
## Returns a NakamaAPI.ApiLeaderboardRecord representing the submitted record.
func write_tournament_record(tournament_id: String, score: int, subscore: int = 0, metadata = null):
	return await client.write_tournament_record_async(session, tournament_id, score, subscore, metadata)

#endregion

#region Storage Management

## Read one or more storage objects by their IDs.
## [br][br]
## [param ids]: Array of storage object IDs to read. Each ID should contain collection, key, and user_id.
## [br][br]
## Returns a NakamaAPI.ApiStorageObjects containing the requested objects.
func read_storage_objects(ids: Array):
	return await client.read_storage_objects_async(session, ids)

## Write one or more storage objects.
## [br][br]
## [param objects]: Array of storage objects to write. Each object should specify collection, key, value, etc.
## [br][br]
## Returns a NakamaAPI.ApiStorageObjectAcks containing acknowledgments of the written objects.
func write_storage_objects(objects: Array):
	return await client.write_storage_objects_async(session, objects)

## Delete one or more storage objects by their IDs.
## [br][br]
## [param ids]: Array of storage object IDs to delete. Each ID should contain collection, key, and user_id.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_storage_objects(ids: Array) -> NakamaAsyncResult:
	return await client.delete_storage_objects_async(session, ids)

## List storage objects in a collection with optional filtering.
## [br][br]
## [param collection]: The collection to list objects from.
## [param user_id]: Filter by user ID (default: empty for current user).
## [param limit]: Maximum number of objects to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiStorageObjectList containing the objects.
func list_storage_objects(collection: String, user_id: String = "", limit: int = 10, cursor = null):
	return await client.list_storage_objects_async(session, collection, user_id, limit, cursor)

## List storage objects for a specific user in a collection.
## [br][br]
## [param collection]: The collection to list objects from.
## [param user_id]: The ID of the user whose objects to list.
## [param limit]: Maximum number of objects to return.
## [param cursor]: Pagination cursor from previous request.
## [br][br]
## Returns a NakamaAPI.ApiStorageObjectList containing the user's objects.
func list_users_storage_objects(collection: String, user_id: String, limit: int, cursor: String):
	return await client.list_users_storage_objects_async(session, collection, user_id, limit, cursor)

#endregion

#region Match Management

## List available matches based on filtering criteria.
## [br][br]
## [param min_size]: Minimum number of match participants.
## [param max_size]: Maximum number of match participants.
## [param limit]: Maximum number of matches to return.
## [param authoritative]: Filter for authoritative matches.
## [param label]: Filter by match label.
## [param query]: Additional query string for filtering.
## [br][br]
## Returns a NakamaAPI.ApiMatchList containing available matches.
func list_matches(min_size: int, max_size: int, limit: int, authoritative: bool, label: String, query: String):
	return await client.list_matches_async(session, min_size, max_size, limit, authoritative, label, query)

#endregion

#region Notification Management

## List notifications for the current user.
## [br][br]
## [param limit]: Maximum number of notifications to return (default: 10).
## [param cacheable_cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiNotificationList containing the user's notifications.
func list_notifications(limit: int = 10, cacheable_cursor = null):
	return await client.list_notifications_async(session, limit, cacheable_cursor)

## Delete one or more notifications by their IDs.
## [br][br]
## [param ids]: Array of notification IDs to delete.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_notifications(ids: PackedStringArray) -> NakamaAsyncResult:
	return await client.delete_notifications_async(session, ids)

#endregion

#region Account Management

## Get the current user's account information.
## [br][br]
## Returns a NakamaAPI.ApiAccount containing the account details.
func get_account():
	return await client.get_account_async(session)

## Get information about one or more users.
## [br][br]
## [param ids]: Array of user IDs to fetch.
## [param usernames]: Array of usernames to fetch (optional).
## [param facebook_ids]: Array of Facebook IDs to fetch (optional).
## [br][br]
## Returns a NakamaAPI.ApiUsers containing the user information.
func get_users(ids: PackedStringArray, usernames = null, facebook_ids = null):
	return await client.get_users_async(session, ids, usernames, facebook_ids)

## Delete the current user's account permanently.
## [br][br]
## [b]Warning:[/b] This action is irreversible!
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func delete_account() -> NakamaAsyncResult:
	return await client.delete_account_async(session)

#endregion

#region Social Authentication Links

## Link a custom ID to the current user's account.
## [br][br]
## [param id]: The custom ID to link.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_custom(id: String) -> NakamaAsyncResult:
	return await client.link_custom_async(session, id)

## Link a device ID to the current user's account.
## [br][br]
## [param id]: The device ID to link.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_device(id: String) -> NakamaAsyncResult:
	return await client.link_device_async(session, id)

## Link an email and password to the current user's account.
## [br][br]
## [param email]: The email address to link.
## [param password]: The password to associate with the email.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_email(email: String, password: String) -> NakamaAsyncResult:
	return await client.link_email_async(session, email, password)

## Link a Facebook account to the current user's account.
## [br][br]
## [param token]: The Facebook access token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_facebook(token: String) -> NakamaAsyncResult:
	return await client.link_facebook_async(session, token)

## Link a Google account to the current user's account.
## [br][br]
## [param token]: The Google access token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_google(token: String) -> NakamaAsyncResult:
	return await client.link_google_async(session, token)

## Link a Steam account to the current user's account.
## [br][br]
## [param token]: The Steam access token.
## [param sync]: Whether to sync Steam profile data (default: false).
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_steam(token: String, sync: bool = false) -> NakamaAsyncResult:
	return await client.link_steam_async(session, token, sync)

## Link an Apple account to the current user's account.
## [br][br]
## [param token]: The Apple ID token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func link_apple(token: String) -> NakamaAsyncResult:
	return await client.link_apple_async(session, token)

## Unlink a custom ID from the current user's account.
## [br][br]
## [param id]: The custom ID to unlink.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_custom(id: String) -> NakamaAsyncResult:
	return await client.unlink_custom_async(session, id)

## Unlink a device ID from the current user's account.
## [br][br]
## [param id]: The device ID to unlink.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_device(id: String) -> NakamaAsyncResult:
	return await client.unlink_device_async(session, id)

## Unlink an email from the current user's account.
## [br][br]
## [param email]: The email address to unlink.
## [param password]: The password associated with the email.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_email(email: String, password: String) -> NakamaAsyncResult:
	return await client.unlink_email_async(session, email, password)

## Unlink a Facebook account from the current user's account.
## [br][br]
## [param token]: The Facebook access token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_facebook(token: String) -> NakamaAsyncResult:
	return await client.unlink_facebook_async(session, token)

## Unlink a Google account from the current user's account.
## [br][br]
## [param token]: The Google access token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_google(token: String) -> NakamaAsyncResult:
	return await client.unlink_google_async(session, token)

## Unlink a Steam account from the current user's account.
## [br][br]
## [param token]: The Steam access token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_steam(token: String) -> NakamaAsyncResult:
	return await client.unlink_steam_async(session, token)

## Unlink an Apple account from the current user's account.
## [br][br]
## [param token]: The Apple ID token.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func unlink_apple(token: String) -> NakamaAsyncResult:
	return await client.unlink_apple_async(session, token)

#endregion

#region RPC and Session Management

## Execute a remote procedure call (RPC) on the server.
## [br][br]
## [param id]: The ID/name of the RPC function to call.
## [param payload]: Optional payload data to send with the RPC call.
## [br][br]
## Returns a NakamaAPI.ApiRpc containing the RPC response.
func rpc_func(id: String, payload = null):
	return await client.rpc_async(session, id, payload)

## Logout and invalidate the current session.
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func session_logout() -> NakamaAsyncResult:
	return await client.session_logout_async(session)

## Refresh the current session to extend its validity.
## [br][br]
## [param vars]: Optional variables to include in the refreshed session.
## [br][br]
## Returns a new NakamaSession with updated expiration time.
func session_refresh(vars = null) -> NakamaSession:
	return await client.session_refresh_async(session, vars)

#endregion

#region In-App Purchases and Subscriptions

## Validate an Apple in-app purchase receipt.
## [br][br]
## [param receipt]: The Apple receipt data to validate.
## [br][br]
## Returns a NakamaAPI.ApiValidatePurchaseResponse containing the validation result.
func validate_purchase_apple(receipt: String):
	return await client.validate_purchase_apple_async(session, receipt)

## Validate a Google Play in-app purchase receipt.
## [br][br]
## [param receipt]: The Google Play receipt data to validate.
## [br][br]
## Returns a NakamaAPI.ApiValidatePurchaseResponse containing the validation result.
func validate_purchase_google(receipt: String):
	return await client.validate_purchase_google_async(session, receipt)

## Validate a Huawei in-app purchase receipt.
## [br][br]
## [param receipt]: The Huawei receipt data to validate.
## [param signature]: The purchase signature from Huawei.
## [br][br]
## Returns a NakamaAPI.ApiValidatePurchaseResponse containing the validation result.
func validate_purchase_huawei(receipt: String, signature: String):
	return await client.validate_purchase_huawei_async(session, receipt, signature)

## Get information about a subscription by product ID.
## [br][br]
## [param product_id]: The product ID of the subscription.
## [br][br]
## Returns a NakamaAPI.ApiValidatedSubscription containing subscription details.
func get_subscription(product_id: String):
	return await client.get_subscription_async(session, product_id)

## List all active subscriptions for the current user.
## [br][br]
## [param limit]: Maximum number of subscriptions to return (default: 10).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiSubscriptionList containing the user's subscriptions.
func list_subscriptions(limit: int = 10, cursor = null):
	return await client.list_subscriptions_async(session, limit, cursor)

## Validate an Apple subscription receipt.
## [br][br]
## [param receipt]: The Apple subscription receipt data.
## [param persist]: Whether to persist the subscription (default: true).
## [br][br]
## Returns a NakamaAPI.ApiValidateSubscriptionResponse containing the validation result.
func validate_subscription_apple(receipt: String, persist: bool = true):
	return await client.validate_subscription_apple_async(session, receipt, persist)

## Validate a Google Play subscription receipt.
## [br][br]
## [param receipt]: The Google Play subscription receipt data.
## [param persist]: Whether to persist the subscription (default: true).
## [br][br]
## Returns a NakamaAPI.ApiValidateSubscriptionResponse containing the validation result.
func validate_subscription_google(receipt: String, persist: bool = true):
	return await client.validate_subscription_google_async(session, receipt, persist)

#endregion

#region Events and Channel Messages

## Send a custom analytics event to the server.
## [br][br]
## [param event_name]: The name of the event to send.
## [param properties]: Dictionary of properties/metadata to attach to the event (default: empty).
## [br][br]
## Returns a NakamaAsyncResult which represents the asynchronous operation.
func send_event(event_name: String, properties: Dictionary = {}) -> NakamaAsyncResult:
	return await client.event_async(session, event_name, properties)

## List messages from a specific channel.
## [br][br]
## [param channel_id]: The ID of the channel to list messages from.
## [param limit]: Maximum number of messages to return (default: 1).
## [param forward]: Whether to list messages in chronological order (default: true).
## [param cursor]: Pagination cursor from previous request (optional).
## [br][br]
## Returns a NakamaAPI.ApiChannelMessageList containing the channel messages.
func list_channel_messages(channel_id: String, limit: int = 1, forward: bool = true, cursor = null):
	return await client.list_channel_messages_async(session, channel_id, limit, forward, cursor)

#endregion
	
