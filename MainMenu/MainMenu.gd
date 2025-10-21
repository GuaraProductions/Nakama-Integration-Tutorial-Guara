## Classe do Lobby Multiplayer que eu fiz do Nakama
extends Control
class_name NakamaMultiplayer

enum UserState {
	SuperAdmin,
	Admin,
	Member,
	JoinRequest
}
var selectedGroup
var selectedGroupState : UserState



var available_groups_to_current_user : Array
var available_users_in_current_group : Array

signal OnStartGame()

@onready var lobby_container : TabContainer = %LobbyContainer
@onready var authentication : CenterContainer = $Authentication
@onready var chat_tab: PanelContainer = %ChatTab

@onready var group_name : LineEdit = %GroupName
@onready var group_desc : LineEdit = %GroupDesc
@onready var group_query : LineEdit = %GroupQuery
@onready var groups_query_vbox : VBoxContainer = %GroupsQueryVBox
@onready var trade_vbox1 : VBoxContainer = %TradeVbox1
@onready var trade_vbox2 : VBoxContainer = %TradeVBox2
@onready var popup : Window = $Popup
@onready var join_group_popup : Window = $JoinGroupChat
@onready var party: PanelContainer = %Party

@onready var user_information_display : PanelContainer = %UserInformationDisplay
@onready var group_listing_slider: HSlider = %GroupListingSlider
@onready var group_listing_selected_label: Label = %GroupListingSelectedLabel
@onready var groups_available_to_user: OptionButton = %GroupsAvailableToUser
@onready var group_users_option_button: OptionButton = %GroupUsers
@onready var group_member_status: Label = %GroupMemberStatus
@onready var joined_member_vbox: VBoxContainer = %JoinedMemberVbox
@onready var accept_join_request: Button = %AcceptJoinRequest
@onready var pending_to_join_group_label: Label = %PendingToJoinGroupLabel
@onready var pending_to_join_section: VBoxContainer = %PendingToJoinSection
@onready var close_open_group: CheckBox = %CloseOpenGroup
@onready var delete_group: Button = %DeleteGroup

@onready var collection_line_edit: LineEdit = %CollectionLineEdit
@onready var key_line_edit: LineEdit = %KeyLineEdit
@onready var data_from_store_label: Label = %DataFromStoreLabel

@onready var match_finder: PanelContainer = %"Match Finder"

func _ready():

	popup.visible = false
	pending_to_join_section.visible = false
	
	NakamaManager.start_client()
	
	lobby_container.visible = false
	authentication.visible = true
	user_information_display.visible = false

	var args = OS.get_cmdline_args()
	print("args: ", args)
	match_finder.start_game.connect(_on_start_game)
	
	if args.size() <= 2:
		return
		
	var current_size = DisplayServer.window_get_size()
	
	# Calculate the new size by dividing the current width and height by 2
	var new_size = Vector2i(current_size.x / 2, current_size.y / 2)
	
	# Set the new window size
	DisplayServer.window_set_size(new_size)

	_on_login_pressed(args[2].strip_edges(), args[3].strip_edges())

#region Login/Register
func updateUserInfo(username: String, 
					displayname : String, 
					avaterurl : String = "", 
					language : String = "en", 
					location : String = "us", 
					timezone : String = "est"):
	await NakamaManager.update_account(username, 
									  displayname, 
									  avaterurl, 
									  language, 
									  location, 
									  timezone)


func _on_register_account_pressed(username: String, 
								  email: String, 
								  password: String) -> void:

	await NakamaManager.register(email, password, username)
	
	connect_user_to_lobby(email)

func _on_login_pressed(email: String, password: String) -> void:

	await NakamaManager.login(email, password)
		
	connect_user_to_lobby(email)
	
func connect_user_to_lobby(email: String = "") -> void:
	
	var user = NakamaManager.current_user
	
	lobby_container.visible = true
	authentication.visible = false
	
	user_information_display.update_user_info(user, email)
	user_information_display.visible = true
	
	#updateUserInfo("test", "testDisplay")
	
	#var account = await NakamaManager.client.get_account_async(NakamaManager.session)
	#
	#$Panel/UserAccountText.text = account.user.username
	#$Panel/DisplayNameText.text = account.user.display_name

	chat_tab.subToFriendChannels()
	#update_friends_list()
#endregion

#region NakamaStorage

@rpc("any_peer")
func sendData(message):
	print(message)

func _on_store_data_button_down():
	
	if collection_line_edit.text.is_empty():
		NotificationContainer.create_notification("Collection line edit vazio!", NotificationContainer.NotificationType.ERROR )
		return
		
	if key_line_edit.text.is_empty():
		NotificationContainer.create_notification("Key line edit vazio!", NotificationContainer.NotificationType.ERROR )
		return
	
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
	
	var can_read = 1
	var can_write = 1
	
	var result = await NakamaManager.client.write_storage_objects_async(NakamaManager.session, [
		NakamaWriteStorageObject.new(collection_line_edit.text.strip_edges(), key_line_edit.text.strip_edges(), can_read, can_write, data , "")
	])
	
	if result.is_exception():
		NotificationContainer.create_notification("error %s" % str(result), NotificationContainer.NotificationType.ERROR )
	else:
		NotificationContainer.create_notification("Objeto armazenado no banco de dados com sucesso!", NotificationContainer.NotificationType.OK)


func _on_get_data_button_down():
	
	if collection_line_edit.text.is_empty():
		NotificationContainer.create_notification("Collection line edit vazio!", NotificationContainer.NotificationType.ERROR )
		return
		
	if key_line_edit.text.is_empty():
		NotificationContainer.create_notification("Key line edit vazio!", NotificationContainer.NotificationType.ERROR )
		return
	
	var result = await NakamaManager.client.read_storage_objects_async(NakamaManager.session, [
		NakamaStorageObjectId.new(collection_line_edit.text.strip_edges(), key_line_edit.text.strip_edges(), NakamaManager.session.user_id)
	])
	
	if result.is_exception():
		NotificationContainer.create_notification("error %s" % str(result), NotificationContainer.NotificationType.ERROR )
		return

	data_from_store_label.text = ""

	for i in result.objects:
		data_from_store_label.text += i.value + "\n"



func _on_list_data_button_down():
	
	if collection_line_edit.text.is_empty():
		NotificationContainer.create_notification("Collection line edit vazio!", NotificationContainer.NotificationType.ERROR )
		return
	
	data_from_store_label.text = ""
	
	var dataList = await NakamaManager.client.list_storage_objects_async(NakamaManager.session, collection_line_edit.text.strip_edges() ,NakamaManager.session.user_id, 5)
	for i in dataList.objects:
		data_from_store_label.text += str(i) + "\n"

#endregion
	
#region Friends 

func _on_create_group_button_down():
	var group = await NakamaManager.client.create_group_async(NakamaManager.session, group_name.text, group_desc.text, "" , "en", true, 32)
	print(group)
	
		
		#print("users in group " + group_name2.text  + i.user.username)
		
	selectedGroup = group

func _on_start_game():
	_start_for_everyone.rpc()
	
@rpc("any_peer","call_local")
func _start_for_everyone() -> void:
	OnStartGame.emit()
	hide()
	
	
#endregion

#region Group 
func _on_add_user_to_group_button_down(group):
	var result = await NakamaManager.client.join_group_async(NakamaManager.session, group.id)
	
	if result.is_exception():
		NotificationContainer.create_notification(
			tr("Erro! Não foi possível entrar nesse grupo"),
			NotificationContainer.NotificationType.ERROR
		)
	
	else:
		NotificationContainer.create_notification(
			tr("Solicitação para entrar no grupo \"%s\" enviada!" % [group.name]),
			NotificationContainer.NotificationType.OK
		)

func _update_close_group_text(toggled: bool) -> void:
	
	if toggled:
		close_open_group.text = "Open Group"
	else:
		close_open_group.text = "Close Group"

func _on_delete_group_pressed() -> void:
	pass # Replace with function body.

func _on_add_user_to_group_2_button_down():
	
	if selectedGroup == null or (selectedGroup and not "id" in selectedGroup):
		NotificationContainer.create_notification("Nenhum grupo foi selecionado", NotificationContainer.NotificationType.ERROR )
		return
	
	var users = await NakamaManager.client.list_group_users_async(NakamaManager.session,selectedGroup.id, UserState.JoinRequest)
	
	for user in users.group_users:
		var u = user.user as NakamaAPI.ApiUser
		await NakamaManager.client.add_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])

#func _on_check_button_toggled(toggled_on):
#	await NakamaManager.client.update_group_async(NakamaManager.session, selectedGroup.id, "Strong Gamers", "we are the strong gamers!", null, "en", toggled_on)
#	pass # Replace with function body.

func _on_list_groups_button_down():
	var limit = group_listing_slider.value
	var result = await NakamaManager.client.list_groups_async(NakamaManager.session, group_query.text.strip_edges(), limit, null, null, null)
	
	print("\ngroups: ", result.groups,"\n")
	
	if result.groups.size() == 0:
		NotificationContainer.create_notification("O grupo \"%s\" não existe!" % group_query.text.strip_edges(), NotificationContainer.NotificationType.ERROR )
		return
	
	removeMyChildren(groups_query_vbox)
	
	for group in result.groups:
		
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		
		var namelabel = Label.new()
		
		namelabel.text = group.name
		hbox.add_child(namelabel)
		
		var button = Button.new()
		button.button_down.connect(_on_add_user_to_group_button_down.bind(group))
		button.text = tr("Join group")
		
		hbox.add_child(button)
		vbox.add_child(hbox)
		
		groups_query_vbox.add_child(vbox)

func match_ended(_match_winner_id: int) -> void:
	match_finder.reset_confirmation.rpc()

func get_selected_user():
	var selected_user_idx = group_users_option_button.selected
	var selected_user_id = available_users_in_current_group[selected_user_idx].user.id
	
	var result : NakamaAPI.ApiUsers = await  NakamaManager.client.get_users_async(NakamaManager.session, [selected_user_id],[], null)

	return result

func _on_promote_user_button_down():
	
	var result = await get_selected_user()
	var user_has_been_promoted = true

	for u in result.users:
		var promote_result = await NakamaManager.client.promote_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])
		
		if promote_result.is_exception():
			NotificationContainer.create_notification(promote_result.exception.message,
										  NotificationContainer.NotificationType.ERROR)
			user_has_been_promoted = false
	
	if user_has_been_promoted:
		NotificationContainer.create_notification("User successfully promoted",
							  NotificationContainer.NotificationType.OK)


func _on_demote_user_button_down():
	var result = await get_selected_user()

	var user_has_been_demoted = true

	for u in result.users:
		var demote_result = await NakamaManager.client.demote_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])
		
		if demote_result.is_exception():
			NotificationContainer.create_notification(demote_result.exception.message,
										  NotificationContainer.NotificationType.ERROR)
			user_has_been_demoted = false
			
	if user_has_been_demoted:
		NotificationContainer.create_notification("User successfully demoted",
							  NotificationContainer.NotificationType.OK)

func _on_kick_user_button_down():

	var result = await get_selected_user()

	var user_has_been_kicked = true

	for u in result.users:
		var kick_result = await NakamaManager.client.kick_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])
		
		if kick_result.is_exception():
			NotificationContainer.create_notification(kick_result.exception.message,
										  NotificationContainer.NotificationType.ERROR)
			user_has_been_kicked = false
			
	if user_has_been_kicked:
		NotificationContainer.create_notification("User successfully kicked",
							  NotificationContainer.NotificationType.OK)
		_on_groups_available_to_user_item_selected(0)

func _on_leave_group_button_down():
	var result : NakamaAsyncResult = await NakamaManager.client.leave_group_async(NakamaManager.session, selectedGroup.id)
	
	if result.is_exception():
		NotificationContainer.create_notification("Cannot leave group",
							  NotificationContainer.NotificationType.ERROR)
	else:
		NotificationContainer.create_notification("Successfully left group",
							  NotificationContainer.NotificationType.OK)

func _on_delete_group_button_down():
	var result : NakamaAsyncResult = await NakamaManager.client.delete_group_async(NakamaManager.session, selectedGroup.id)
	
	if result.is_exception():
		NotificationContainer.create_notification("Cannot delete group",
							  NotificationContainer.NotificationType.ERROR)
	else:
		NotificationContainer.create_notification("Successfully deleted group",
							  NotificationContainer.NotificationType.OK)

func _on_group_listing_slider_value_changed(value: int) -> void:
	group_listing_selected_label.text = "%d" % value

func _on_update_available_groups_pressed() -> void:
	
	var result = await NakamaManager.client.list_user_groups_async(NakamaManager.session, NakamaManager.current_user.id)
	
	groups_available_to_user.clear()
	
	available_groups_to_current_user = result.user_groups
	
	for query_result in result.user_groups:
		if query_result.state != UserState.JoinRequest:
			groups_available_to_user.add_item(query_result.group.name)

	_on_groups_available_to_user_item_selected(0)

func _is_state_admin(state: UserState) -> bool:
	return state == UserState.Admin or state == UserState.SuperAdmin

func _on_groups_available_to_user_item_selected(index: int) -> void:
	var selected_id = available_groups_to_current_user[index].group.id
	
	selectedGroup = available_groups_to_current_user[index].group
	
	print("\n\nselectedGroup.open = ", selectedGroup.open, "\n\n")
	
	close_open_group.button_pressed = not selectedGroup.open
	_update_close_group_text(selectedGroup.open)
	
	var result = await NakamaManager.client.list_group_users_async(NakamaManager.session, selected_id)
	
	group_users_option_button.clear()
	
	available_users_in_current_group = result.group_users
	
	for query_results in result.group_users:
		
		var user = query_results.user
		
		group_users_option_button.add_item(user.display_name)
		
		if user.id == NakamaManager.current_user.id:
			selectedGroupState = query_results.state
		
	var is_admin : bool = _is_state_admin(selectedGroupState)

	close_open_group.visible = is_admin
	delete_group.visible = is_admin
	
	close_open_group.button_pressed = selectedGroup.open
		
	_update_close_group_text(close_open_group.button_pressed)
		
	_on_group_users_item_selected(0)
	_update_pending_members_to_join_group()
	
func _update_pending_members_to_join_group() -> void:
	
	var users = await NakamaManager.client.list_group_users_async(NakamaManager.session, selectedGroup.id, 3)
	
	pending_to_join_group_label.text = ""
	
	for user in users.group_users:
		var u = user.user as NakamaAPI.ApiUser
		pending_to_join_group_label.text += "%s\n" % u.display_name

	pending_to_join_section.visible = not pending_to_join_group_label.text.is_empty()

func _on_group_users_item_selected(index: int) -> void:
	var user = available_users_in_current_group[index]
	
	group_member_status.text = "Status: %s" % user_status_to_string(user.state)
	
	if user.state >= UserState.SuperAdmin and user.state < UserState.JoinRequest:
		
		joined_member_vbox.visible = _can_manage_other_user(user.state, selectedGroupState)
		accept_join_request.visible = false
	elif user.state == UserState.JoinRequest:
		joined_member_vbox.visible = false
		accept_join_request.visible = true

func _can_manage_other_user(user_state: UserState, current_user_state: UserState) -> bool:
	
	var result : bool = true
	
	if current_user_state == UserState.Admin:
		result = user_state == UserState.Member
	elif current_user_state == UserState.Member or current_user_state == UserState.JoinRequest:
		result = false
		
	return result
		

func user_status_to_string(state: int) -> String:
	
	var state_string := ""
	
	match state:
		UserState.SuperAdmin:
			state_string = "Superadmin"
		UserState.Admin:
			state_string = "Admin"
		UserState.Member:
			state_string = "Member"
		UserState.JoinRequest:
			state_string = "Join Request"
		_:
			state_string = "Undefined"
			
	return state_string

func _on_accept_join_request_pressed() -> void:
	var users = await NakamaManager.client.list_group_users_async(NakamaManager.session,selectedGroup.id, UserState.JoinRequest)
	
	for query_result in users.group_users:
		var u = query_result.user as NakamaAPI.ApiUser
	
		await NakamaManager.client.add_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])
		
	_on_groups_available_to_user_item_selected(groups_available_to_user.selected)

func _on_accept_all_pending_requests_pressed() -> void:
	var users = await NakamaManager.client.list_group_users_async(NakamaManager.session,selectedGroup.id, UserState.JoinRequest)
	
	for user in users.group_users:
		var u = user.user as NakamaAPI.ApiUser
		await NakamaManager.client.add_group_users_async(NakamaManager.session, selectedGroup.id, [u.id])

#endregion

#region RPC TRADE SYSTEM
func _on_ping_rpc_button_down():
	var item = {
		"name" = "sword",
		"type" = "Weapon",
		"rarity" = "common"
	}
	var rpcReturn = await  NakamaManager.client.rpc_async(NakamaManager.session, "addItemToInventory", JSON.stringify(item))
	print(rpcReturn)


func _on_get_inventory_button_down():
	var inventory = await getInventory(NakamaManager.session.user_id)
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
	 await NakamaManager.client.rpc_async(NakamaManager.session, "getInventory", JSON.stringify({"id" : id}))
	
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

	var result = await  NakamaManager.client.rpc_async(NakamaManager.session, "createTradeOffer", JSON.stringify(payload))
	print(result)
	pass # Replace with function body.


func _on_accept_trade_offer_button_down():
	var payload = {"offerID" : currentTradeOffer.offerid}
	var result = await  NakamaManager.client.rpc_async(NakamaManager.session, "acceptTradeOffer", JSON.stringify(payload))
	
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
		var id = await NakamaManager.client.get_users_async(NakamaManager.session, [i.senderid], null)
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
	var result = await NakamaManager.client.rpc_async(NakamaManager.session, "getTradeOffers", "{}")
	
	var tradeOffers = JSON.parse_string(result.payload)
	
	return tradeOffers


func _on_cancel_trade_offer_button_down():
	var payload = {"offerID" : currentTradeOffer.offerid}
	var result = await  NakamaManager.client.rpc_async(NakamaManager.session, "cancelTradeOffer", JSON.stringify(payload))
	
	var response = JSON.parse_string(result.payload)
	print("Canceled trade offer " + response.result)
	pass # Replace with function body.
	
#endregion

#region Popup

func invoke_popup(title: String, message: String) -> void:
	popup.configure_text(title, message)
	popup.popup_centered()

#endregion


func _on_close_open_group_pressed() -> void:
	print("\n\nfechar grupo?: ", close_open_group.button_pressed, "\n\n")
	
	await NakamaManager.client.update_group_async(NakamaManager.session, selectedGroup.id, null, null, null, null, close_open_group.button_pressed)
	
	_update_close_group_text(close_open_group.button_pressed)

func _on_user_information_display_invite_friend_to_party(id: String, username: String) -> void:
	
	var party_id : String = NakamaManager.get_party_id()

	if NakamaManager.is_in_party():
		party.create_party()
		party_id = NakamaManager.get_party_id()
	
	chat_tab.invite_friend(id, username, party_id)
