extends Control
class_name NakamaMultiplayer

@export var friends_packed_scene : PackedScene

var session : NakamaSession # this is the session
var client : NakamaClient # this is the client {session}
var socket : NakamaSocket # connection to nakama
var createdMatch
var multiplayerBridge : NakamaMultiplayerBridge

var selectedGroup
var currentChannel
var chatChannels := {}

static var Players = {}

var party

signal OnStartGame()

@onready var lobby_container : TabContainer = %LobbyContainer
@onready var authentication : CenterContainer = $Authentication

@onready var match_name : LineEdit = %MatchName
@onready var add_friend : Button = %AddFriend
@onready var friends_container : VBoxContainer = %FriendsContainer
@onready var add_friend_text : LineEdit = %AddFriendText
@onready var group_name : LineEdit = %GroupName
@onready var group_name2 : LineEdit = %GroupName2
@onready var group_desc : LineEdit = %GroupDesc
@onready var groupvbox : VBoxContainer = %GroupVBox
@onready var group_query : LineEdit = %GroupQuery
@onready var panel6vbox : VBoxContainer = %Panel6Vbox
@onready var user_to_manager : LineEdit = %UserToManage
@onready var chat_name : LineEdit = %ChatName
@onready var username_container : TabContainer = %UsernameContainer
@onready var channel_message_panel : Control = %ChannelMessagePanel
@onready var channel_message_label : Label = %ChannelMessageLabel
@onready var chat_text_line_edit : LineEdit = %ChatTextLineEdit
@onready var trade_vbox1 : VBoxContainer = %TradeVbox1
@onready var trade_vbox2 : VBoxContainer = %TradeVBox2

@onready var notificatin_container : NotificationContainer = $NotificationContainer 
@onready var user_information_display : PanelContainer = %UserInformationDisplay

# Called when the node enters the scene tree for the first time.
func _ready():

	client = Nakama.create_client("defaultkey", 
								 "127.0.0.1", 
								 7350, 
								 "http")
						
	lobby_container.visible = false
	authentication.visible = true
	user_information_display.visible = false

func updateUserInfo(username: String, 
					displayname : String, 
					avaterurl : String = "", 
					language : String = "en", 
					location : String = "us", 
					timezone : String = "est"):
	await client.update_account_async(session, 
									  username, 
									  displayname, 
									  avaterurl, 
									  language, 
									  location, 
									  timezone)

func onMatchPresence(presence : NakamaRTAPI.MatchPresenceEvent):
	print(presence)

func onMatchState(state : NakamaRTAPI.MatchData):
	print("data is : " + str(state.data))

func onSocketConnected():
	print("Socket Connected")

func onSocketClosed():
	print("Socket Closed")

func onSocketReceivedError(err):
	print("Socket Error:" + str(err))

func _on_register_account_pressed(username: String, 
								  email: String, 
								  password: String) -> void:

	session = await client.authenticate_email_async(email , password)

	if not session._created:
		client.delete_account_async(session)
		notificatin_container.create_notification("Já existe uma conta com essas credenciais!",
												  NotificationContainer.NotificationType.ERROR)
		return

	if session.is_valid():
		notificatin_container.create_notification("Registrado com sucesso!")
	elif session.is_exception():
		var exception : NakamaException = session.get_exception()
		notificatin_container.handle_exception(exception.status_code)
		return
		
	await client.update_account_async(session, null, username)
	
	var users = await client.get_users_async(session, [session.user_id])
	
	var u = NakamaAPI.ApiUser.new()
	
	if users.users and users.users.size() > 0:
		u = users.users[0] as NakamaAPI.ApiUser
	
	connect_user_to_lobby(u)

func _on_login_pressed(email: String, password: String) -> void:

	session = await client.authenticate_email_async(email , password)
	
	if session._created:
		client.delete_account_async(session)
		notificatin_container.create_notification("Não existe conta com essas credenciais!",
												  NotificationContainer.NotificationType.ERROR)
		return
	
	if session.is_valid():
		notificatin_container.create_notification("Logado com sucesso!")
	elif session.is_exception():
		var exception : NakamaException = session.get_exception()
		notificatin_container.handle_exception(exception.status_code)
		return
		
	var users = await client.get_users_async(session, [session.user_id])
	
	var u = NakamaAPI.ApiUser.new()
	
	if users.users and users.users.size() > 0:
		u = users.users[0] as NakamaAPI.ApiUser
		
	print("\n\nmy_user: ", u, "\n\n")
		
	connect_user_to_lobby(u)
	
func connect_user_to_lobby(user: NakamaAPI.ApiUser) -> void:
	lobby_container.visible = true
	authentication.visible = false
	user_information_display.update_user_info(user)
	user_information_display.visible = true
	print("\n\nSession is valid: = %s\n\n" % str(session.is_valid()))
	
	#var deviceid = OS.get_unique_id()
	#session = await client.authenticate_device_async(deviceid)
	socket = Nakama.create_socket_from(client)
	
	await socket.connect_async(session)
	
	socket.connected.connect(onSocketConnected)
	socket.closed.connect(onSocketClosed)
	socket.received_error.connect(onSocketReceivedError)
	
	socket.received_match_presence.connect(onMatchPresence)
	socket.received_match_state.connect(onMatchState)
	
	socket.received_channel_message.connect(onChannelMessage)
	
	socket.received_party_presence.connect(onPartyPresence)
	
	#updateUserInfo("test", "testDisplay")
	
	#var account = await client.get_account_async(session)
	#
	#$Panel/UserAccountText.text = account.user.username
	#$Panel/DisplayNameText.text = account.user.display_name
	
	setupMultiplayerBridge()
	subToFriendChannels()
	update_friends_list()

func setupMultiplayerBridge():
	multiplayerBridge = NakamaMultiplayerBridge.new(socket)
	multiplayerBridge.match_join_error.connect(onMatchJoinError)
	var multiplayer = get_tree().get_multiplayer()
	multiplayer.set_multiplayer_peer(multiplayerBridge.multiplayer_peer)
	multiplayer.peer_connected.connect(onPeerConnected)
	multiplayer.peer_disconnected.connect(onPeerDisconnected)
	
func onPeerConnected(id):
	print("Peer connected id is : " + str(id))
	
	if !Players.has(id):
		Players[id] = {
			"name" : id,
			"ready" : 0
		}
	if !Players.has(multiplayer.get_unique_id()):
		Players[multiplayer.get_unique_id()]= {
			"name" : multiplayer.get_unique_id(),
			"ready" : 0
		}
	print(Players)
	
func onPeerDisconnected(id):
	print("Peer disconnected id is : " + str(id))
	
func onMatchJoinError(error):
	print("Unable to join match: " + error.message)

func onMatchJoin():
	print("joined Match with id: " + multiplayerBridge.match_id)
func _on_store_data_button_down():
	var saveGame = {
		"name" : "username",
		"items" : [{
			"id" : 1,
			"name" : "gun",
			"ammo" : 10
		},
		{
			"id" : 2,
			"name" : "sword",
			"ammo" : 0
		}],
		"level" : 10
	}
	var data = JSON.stringify(saveGame)
	var result = await client.write_storage_objects_async(session, [
		NakamaWriteStorageObject.new("saves", "savegame2", 1, 1, data , "")
	])
	
	if result.is_exception():
		print("error" + str(result))
		return
	print("Stored data successfully!")
	pass # Replace with function body.


func _on_get_data_button_down():
	var result = await client.read_storage_objects_async(session, [
		NakamaStorageObjectId.new("saves", "savegame", session.user_id)
	])
	
	if result.is_exception():
		print("error" + str(result))
		return
	for i in result.objects:
		print(i.value)
	pass # Replace with function body.


func _on_list_data_button_down():
	var dataList = await client.list_storage_objects_async(session, "saves",session.user_id, 5)
	for i in dataList.objects:
		print(i)


func _on_join_create_match_button_down():
	multiplayerBridge.join_named_match(match_name.text)
	
	#createdMatch = await socket.create_match_async($Panel3/MatchName.text)
	#if createdMatch.is_exception():
		#print("Failed to create match " + str(createdMatch))
		#return
	#
	#print("Created match :" + str(createdMatch.match_id))
	pass # Replace with function body.


func _on_ping_button_down():
	#sendData.rpc("hello world")
	var data = {"hello" : "world"}
	socket.send_match_state_async(createdMatch.match_id, 1, JSON.stringify(data))
	pass # Replace with function body.

@rpc("any_peer")
func sendData(message):
	print(message)


func _on_matchmaking_button_down():
	var query = "+properties.region:US +properties.rank:>=4 +properties.rank:<=10"
	var stringP = {"region" : "US"}
	var numberP = { "rank": 6}
	
	var ticket = await socket.add_matchmaker_async(query,2, 4, stringP, numberP)
	
	if ticket.is_exception():
		print("failed to matchmake : " + str(ticket))
		return
	
	print("match ticket number : " + str(ticket))
	
	socket.received_matchmaker_matched.connect(onMatchMakerMatched)
	pass # Replace with function body.

func onMatchMakerMatched(matched : NakamaRTAPI.MatchmakerMatched):
	var joinedMatch = await socket.join_matched_async(matched)
	createdMatch = joinedMatch

######### Friends 
func _on_add_friend_button_down():

	var id = [add_friend_text.text]
	
	var result = await client.add_friends_async(session, null, id)
	update_friends_list()


func _on_get_friends_button_down():
	update_friends_list()
	
func update_friends_list() -> void:
	var result = await client.list_friends_async(session)
	
	clear_box(friends_container)
	
	for i in result.friends:
		
		var friends_hbox : FriendHBoxContainer = friends_packed_scene.instantiate()
		
		friends_container.add_child(friends_hbox)
		friends_hbox.set_friend.call_deferred(i.user.display_name, 
								onTrade.bind(i), 
								remove_friend_from_username.bind(i.user.username),
								block_friend_by_username.bind(i.user.username))
		"""
		var container = HBoxContainer.new()
		var currentlabel = Label.new()
		currentlabel.text = i.user.display_name
		container.add_child(currentlabel)
		var currentButton = Button.new()
		container.add_child(currentButton)
		currentButton.text = "Trade"
		#currentButton.text = "Invite"
		currentButton.button_down.connect(onTrade.bind(i))
		#currentButton.button_down.connect(onInviteToParty.bind(i))
		"""

func clear_box(box: BoxContainer) -> void:
	
	for child in box.get_children():
		child.queue_free()
		child = null

func _on_remove_friend_button_down():
	remove_friend_from_username(add_friend_text.text)

func remove_friend_from_username(username: String) -> void:
	var result = await client.delete_friends_async(session,[], [username])
	update_friends_list()

func _on_block_friends_button_down():
	var result = await client.block_friends_async(session,[], [add_friend_text.text])
	block_friend_by_username(add_friend_text.text)
	
func block_friend_by_username(username: String) -> void:
	var result = await client.block_friends_async(session,[], [username])

func _on_create_group_button_down():
	var group = await client.create_group_async(session, group_name.text, group_desc.text, "" , "en", true, 32)
	print(group)
	pass # Replace with function body.


func _on_get_group_memebers_button_down():
	var result = await client.list_group_users_async(session, group_name2.text)
	
	for i in result.group_users:
		var currentlabel = Label.new()
		currentlabel.text = i.user.display_name
		groupvbox.add_child(i.user.username)
		print("users in group " + group_name2.text  + i.user.username)
	pass # Replace with function body.


func _on_button_button_down():
	Ready.rpc(multiplayer.get_unique_id())
	pass # Replace with function body.
	
@rpc("any_peer", "call_local")
func Ready(id):
	Players[id].ready = 1
	if multiplayer.is_server():
		var readyPlayers = 0
		for i in Players:
			if Players[i].ready == 1:
				readyPlayers += 1
		if readyPlayers == Players.size():
			StartGame.rpc()

@rpc("any_peer", "call_local")
func StartGame():
	OnStartGame.emit()
	hide()

####### Group 
func _on_add_user_to_group_button_down():
	await  client.join_group_async(session, selectedGroup.id)

func _on_add_user_to_group_2_button_down():
	var users = await client.list_group_users_async(session,selectedGroup.id, 3)
	
	for user in users.group_users:
		var u = user.user as NakamaAPI.ApiUser
		await client.add_group_users_async(session, selectedGroup.id, [u.id])


func _on_check_button_toggled(toggled_on):
	await client.update_group_async(session, selectedGroup.id, "Strong Gamers", "we are the strong gamers!", null, "en", toggled_on)
	pass # Replace with function body.


func _on_list_groups_button_down():
	var limit = 10
	var result = await client.list_groups_async(session, group_query.text, limit, null, null, null)
	
	for group in result.groups:
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		
		var namelabel = Label.new()
		namelabel.text = group.name
		hbox.add_child(namelabel)
		var button = Button.new()
		button.button_down.connect(onGroupSelectButton.bind(group))
		button.text = "Select Group"
		hbox.add_child(button)
		vbox.add_child(hbox)
		panel6vbox.add_child(vbox)
	pass # Replace with function body.

func onGroupSelectButton(group):
	selectedGroup = group

func _on_promote_user_button_down():
	var result : NakamaAPI.ApiUsers = await  client.get_users_async(session, [],[user_to_manager.text], null)
	for u in result.users:
		await client.promote_group_users_async(session, selectedGroup.id, [u.id])
	pass # Replace with function body.


func _on_demote_user_button_down():
	var result : NakamaAPI.ApiUsers = await  client.get_users_async(session, [],[user_to_manager.text], null)
	for u in result.users:
		await client.demote_group_users_async(session, selectedGroup.id, [u.id])
	pass # Replace with function body.


func _on_kick_user_button_down():
	var result : NakamaAPI.ApiUsers = await  client.get_users_async(session, [],[user_to_manager.text], null)
	for u in result.users:
		await client.kick_group_users_async(session, selectedGroup.id, [u.id])
	pass # Replace with function body.



func _on_leave_group_button_down():
	await client.leave_group_async(session, selectedGroup.id)
	pass # Replace with function body.


func _on_delete_group_button_down():
	await  client.delete_group_async(session, selectedGroup.id)
	pass # Replace with function body.

########## Chat Room Code
func _on_join_chat_room_button_down():
	var type = NakamaSocket.ChannelType.Room
	currentChannel = await socket.join_chat_async(chat_name.text, type, false, false)
	
	print("channel id: " + currentChannel.id)

func onChannelMessage(message : NakamaAPI.ApiChannelMessage):
	var content = JSON.parse_string(message.content)
	if content.type == 0:
		username_container.get_node(content.id).text += message.username + ": " + str(content.message) + "\n"
	elif content.type == 1 && party == null:
		channel_message_panel.show()
		party = {"id" : content.partyID}
		channel_message_label.text = str(content.message)

func _on_submit_chat_button_down():
	await socket.write_chat_message_async(currentChannel.id, {
		 "message" : chat_text_line_edit.text,
		"id" : chatChannels[currentChannel.id].label,
		"type" : 0
		})


func _on_join_group_chat_room_button_down():
	var type = NakamaSocket.ChannelType.Group
	currentChannel = await socket.join_chat_async(selectedGroup.id, type, true, false)
	
	print("channel id: " + currentChannel.id)
	chatChannels[selectedGroup.id] = {
		"channel" : currentChannel,
		"label" : "Group Chat"
		}
	var currentEdit = TextEdit.new()
	currentEdit.name = "currentGroup"
	username_container.add_child(currentEdit)
	currentEdit.text = await listMessages(currentChannel)
	username_container.tab_changed.connect(onChatTabChanged.bind(selectedGroup.id))
	
	pass # Replace with function body.

func onChatTabChanged(index, channelID):
	currentChannel = chatChannels[channelID].channel
	pass
	
func listMessages(currentChannel):
	
	var result = await  client.list_channel_messages_async(session, currentChannel.id, 100, true)
	var text = ""
	for message in result.messages:
		if(message.content != "{}"):
			var content = JSON.parse_string(message.content)
		
			text += message.username + ": " + str(content.message) + "\n"
	return text
	
func subToFriendChannels():
	var result = await client.list_friends_async(session)
	for i in result.friends:
		var type = NakamaSocket.ChannelType.DirectMessage
		var channel = await socket.join_chat_async(i.user.id, type, true, false)
		chatChannels[channel.id] = {
		"channel" : channel,
		"label" : i.user.username
		} 
		var currentEdit = TextEdit.new()
		currentEdit.name = i.user.username
		username_container.add_child(currentEdit)
		currentEdit.text = await listMessages(channel)
		username_container.tab_changed.connect(onChatTabChanged.bind(channel.id))

func _on_join_direct_chat_button_down():
	var type = NakamaSocket.ChannelType.DirectMessage
	var usersResult = await  client.get_users_async(session, [], [chat_name.text])
	if usersResult.users.size() > 0:
		currentChannel = await socket.join_chat_async(usersResult.users[0].id, type, true, false)
		
		print("channel id: " + currentChannel.id)
		
		var result = await  client.list_channel_messages_async(session, currentChannel.id, 100, true)
		
		for message in result.messages:
			if(message.content != "{}"):
				var content = JSON.parse_string(message.content)
			
				chat_text_line_edit.text += message.username + ": " + str(content.message) + "\n"

###### Party System

func _on_create_party_button_down():
	party = await  socket.create_party_async(false, 2)

func onInviteToParty(friend):
	var channel = await socket.join_chat_async(friend.user.id, NakamaSocket.ChannelType.DirectMessage)
	var ack = await socket.write_chat_message_async(channel.id, {
			"message" : "Join Party with "  + session.username,
			"partyID" : party.party_id,
			"type" : 1
			}
		)
	pass


func _on_join_party_yes_button_down():
	var result = await  socket.join_party_async(party.id)
	if result.is_exception():
		print("failed to join party")
	channel_message_panel.hide()
	pass # Replace with function body.
	

func _on_join_party_no_button_down():
	channel_message_panel.hide()
	pass # Replace with function body.

func onPartyPresence(presence : NakamaRTAPI.PartyPresenceEvent):
	print("JOINED PARTY " + presence.party_id)

############### RPC TRADE SYSTEM
func _on_ping_rpc_button_down():
	var item = {
		"name" = "sword",
		"type" = "Weapon",
		"rarity" = "common"
	}
	var rpcReturn = await  client.rpc_async(session, "addItemToInventory", JSON.stringify(item))
	print(rpcReturn)


func _on_get_inventory_button_down():
	var inventory = await getInventory(session.user_id)
	removeMyChildren(trade_vbox1)
	
	if not inventory:
		return
	
	for i in inventory:
		var button = Button.new()
		button.name = i.name
		button.text = i.name
		trade_vbox1.add_child(button)
		button.button_down.connect(setItemForTrade.bind(i, button, true))
		var stylebox = StyleBoxFlat.new()
		button.add_theme_stylebox_override("normal", stylebox)

func getInventory(id):
	var result = \
	 await client.rpc_async(session, "getInventory", JSON.stringify({"id" : id}))
	
	if result is NakamaException:
		return null
	
	var inventory = JSON.parse_string(result.payload)
	return inventory

func onTrade(friend):
	var inventory = await getInventory(friend.user.id)
	PlayerToTradeWith = friend
	removeMyChildren(trade_vbox2)
	
	for i in inventory:
		var button = Button.new()
		button.name = i.name
		button.text = i.name
		button.button_down.connect(setItemForTrade.bind(i, button, false))
		trade_vbox2.add_child(button)
		var stylebox = StyleBoxFlat.new()
		button.add_theme_stylebox_override("normal", stylebox)
	pass

var TradeItems = []
var ItemsToTradeFor = []
var PlayerToTradeWith 
var currentTradeOffer

func setItemForTrade(item, button : Button, player: bool):
	var items
	if player:
		items = TradeItems
	else:
		items = ItemsToTradeFor
		
	if(!items.has(item)):
		items.append(item)
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.GREEN
		button.add_theme_stylebox_override("normal", stylebox)
	else:
		items.erase(item)
		var stylebox = StyleBoxFlat.new()
		button.add_theme_stylebox_override("normal", stylebox)
	
	if player:
		TradeItems = items
	else:
		ItemsToTradeFor = items


func _on_send_trade_offer_button_down():
	var receiverID = PlayerToTradeWith.user.id
	var offerItems = TradeItems
	var requestedItems = ItemsToTradeFor
	
	var payload = {
		"recieverid" : receiverID,
		"offerItems" : offerItems, 
		"requestedItems" : requestedItems
	}
	if offerItems == [] || requestedItems == []:
		print("cannot send empty offer")
		return

	var result = await  client.rpc_async(session, "createTradeOffer", JSON.stringify(payload))
	print(result)
	pass # Replace with function body.


func _on_accept_trade_offer_button_down():
	var payload = {"offerID" : currentTradeOffer.offerid}
	var result = await  client.rpc_async(session, "acceptTradeOffer", JSON.stringify(payload))
	
	var response = JSON.parse_string(result.payload)
	if result.exception != null:
		print(result.exception.message)
	else:
		print("accepted trade offer " + response.result)
	pass # Replace with function body.


func _on_get_trade_offers_button_down():
	var tradeOffers = await getTradeOffers()
	
	for i in tradeOffers:
		var button = Button.new()
		var id = await client.get_users_async(session, [i.senderid], null)
		button.text = id.users[0].display_name
		button.button_down.connect(setTradeOffers.bind(i))
		trade_vbox1.add_child(button)
	pass # Replace with function body.

func setTradeOffers(offer):
	removeMyChildren(trade_vbox1)
	removeMyChildren(trade_vbox2)
	
	for i in offer.requestedItems:
		var button = Button.new()
		button.text = i.name
		trade_vbox1.add_child(button)
	for i in offer.offerItems:
		var button = Button.new()
		button.text = i.name
		trade_vbox2.add_child(button)
	
	currentTradeOffer = offer

func removeMyChildren(node):
	for i in node.get_children():
		i.queue_free()

func getTradeOffers():
	var result = await client.rpc_async(session, "getTradeOffers", "{}")
	
	var tradeOffers = JSON.parse_string(result.payload)
	
	return tradeOffers


func _on_cancel_trade_offer_button_down():
	var payload = {"offerID" : currentTradeOffer.offerid}
	var result = await  client.rpc_async(session, "cancelTradeOffer", JSON.stringify(payload))
	
	var response = JSON.parse_string(result.payload)
	print("Canceled trade offer " + response.result)
	pass # Replace with function body.
