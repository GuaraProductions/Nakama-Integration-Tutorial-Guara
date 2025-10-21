extends PanelContainer

signal start_game()

@export var notification_container : NotificationContainer

@onready var matchmaking_finder: VBoxContainer = %MatchmakingFinder
@onready var match_name_field: LineEdit = %MatchNameField
@onready var matchmaking_button: Button = %MatchmakingButton
@onready var your_match_info: VBoxContainer = %YourMatchInfo
@onready var match_name_label: Label = %MatchNameLabel
@onready var match_id_label: Label = %MatchIDLabel
@onready var matchmaking_players: VBoxContainer = %MatchmakingPlayers
@onready var select_match_label: Label = %SelectMatchLabel
@onready var map_selector: ScrollContainer = %MapSelector
@onready var map_selection_vbox: VBoxContainer = %MapSelectionVbox
@onready var start_game_button: Button = %StartGameButton

@onready var how_many_players_confirmed: Label = %HowManyPlayersConfirmed
@onready var confirmation_progress_bar: ProgressBar = %ConfirmationProgressBar

var num_players : int = 0
var confirmed_players : int = 0

var players : Dictionary[int, bool] = {}

var createdMatch : NakamaRTAPI.Match
var matchmakingTicket

var match_scene_selected : String = ""

func _ready() -> void:
	your_match_info.visible = false
	matchmaking_finder.visible = true

	NakamaManager.peer_connnected_in_match.connect(_peer_connected)
	NakamaManager.peer_disconnnected_in_match.connect(_peer_connected)
	
func _update_players_confirmed() -> void:
	
	how_many_players_confirmed.text = "%d/%d" % [confirmed_players, num_players]
	confirmation_progress_bar.value = confirmed_players
	confirmation_progress_bar.max_value = num_players

func _on_join_create_match_button_down():
	
	var match_name_query : String = match_name_field.text.strip_edges()
	
	NakamaManager.multiplayerBridge.join_named_match(match_name_query)
	
	createdMatch = await NakamaManager.socket.create_match_async(match_name_query)
	
	if createdMatch.is_exception():
		notification_container.create_notification(tr("Failed to create match ") + str(createdMatch.match_id), 
							NotificationContainer.NotificationType.ERROR)
		return
	
	notification_container.create_notification(tr("Created match :") + str(createdMatch.match_id), 
						NotificationContainer.NotificationType.OK)
					
	if multiplayer.is_server():
		num_players = 1
		_update_players_confirmed()
		map_selection_vbox.visible = true
		start_game_button.disabled = true
		
	else:
		map_selection_vbox.visible = false
		start_game_button.disabled = false
	
	_show_match_found(match_name_query)

func _show_match_found(match_name_query: String) -> void:
	your_match_info.visible = true
	matchmaking_finder.visible = false
	
	match_name_field.text = ""
	
	match_name_label.text = "Match name: %s" % match_name_query
	match_id_label.text = "Match id: %s" % createdMatch.match_id
	
	if not NakamaManager.socket.received_match_presence.is_connected(_match_status_updated):
		NakamaManager.socket.received_match_presence.connect(_match_status_updated)
		
	_add_player_to_current_matchmaking(NakamaManager.current_user.display_name)
	
func _peer_connected(id: int) -> void:
	
	if not multiplayer.is_server():
		return
	
	var players_usernames : Array[String] = []
	matchmaking_players.get_children().map(func(a): players_usernames.append(a.name))
	_update_num_players.rpc(NakamaManager.Players.size() - 1)
	_update_current_players.rpc_id(id, players_usernames)
	
@rpc("any_peer", "call_local")
func _update_num_players(p_num_players: int) -> void:
	num_players = p_num_players
	_update_players_confirmed()
	
func _peer_disconnected(user, _id: int) -> void:
	if not multiplayer.is_server():
		return
		
	_remover_player_from_list.rpc(user.display_name)
	
@rpc("any_peer", "call_local")
func _remover_player_from_list(display_name: String) -> void:
	
	for player in matchmaking_players.get_children():
		if player.name == display_name:
			player.queue_free()
			player = null
	
@rpc("any_peer", "reliable", "call_local")
func _update_current_players(usernames: Array[String]) -> void:
	_update_players_confirmed()
	for username in usernames:
		_add_player_to_current_matchmaking(username)
	
func _match_status_updated(param) -> void:
	
	if not param.joins.is_empty():
		var user_ids : Array = []
		param.joins.map(func(a): user_ids.append(a.user_id))
		var query = await NakamaManager.client.get_users_async(NakamaManager.session, user_ids)

		for user in query.users:
			
			_add_player_to_current_matchmaking(user.display_name)
			
	if not param.leaves.is_empty():
		for user_presence in param.leaves:
			
			var player_label_node = matchmaking_players.get_node_or_null(user_presence.username)
			if not player_label_node:
				continue
				
			player_label_node.queue_free()
			player_label_node = null
			
			#print("username %s has left" % user_presence.username)

func _add_player_to_current_matchmaking(display_name: String) -> void:
	
	if matchmaking_players.has_node(display_name):
		return
	
	var label : Label = Label.new()
	label.name = display_name
	label.text = display_name
	
	matchmaking_players.add_child(label)

func _on_matchmaking_button_down():
	
	if matchmakingTicket:
		
		var removed : NakamaAsyncResult = await NakamaManager.socket.remove_matchmaker_async(matchmakingTicket.ticket)
	
		if removed.is_exception():
			notification_container.create_notification(tr("Falha ao deletar ticket de matchmaking") + str(matchmakingTicket.ticket), 
						NotificationContainer.NotificationType.ERROR)
			return
		
		notification_container.create_notification(tr("Ticket removido!"), 
							NotificationContainer.NotificationType.OK)
							
		matchmaking_button.text = tr("Start Matchmaking")
		matchmakingTicket = null
	else:
		
		#var query = "+properties.region:US +properties.rank:>=4 +properties.rank:<=10"
		#var stringP = {"region" : "US"}
		#var numberP = { "rank": 6}
		var query = "*"
		var min_count = 2
		var max_count = 4
		
		matchmakingTicket = await NakamaManager.socket.add_matchmaker_async(query,min_count, max_count)
		
		if matchmakingTicket.is_exception():
			notification_container.create_notification(tr("failed to matchmake : ") + str(matchmakingTicket.ticket), 
								NotificationContainer.NotificationType.ERROR)
			return
		
		notification_container.create_notification(tr("match ticket number : ") + str(matchmakingTicket.ticket), 
							NotificationContainer.NotificationType.WARNING)
		
		if not NakamaManager.socket.received_matchmaker_matched.is_connected(onMatchMakerMatched):
			NakamaManager.socket.received_matchmaker_matched.connect(onMatchMakerMatched)
			
		matchmaking_button.text = tr("Stop Matchmaking")
	
func onMatchMakerMatched(matched : NakamaRTAPI.MatchmakerMatched):
	var joinedMatch = await NakamaManager.socket.join_matched_async(matched)
	createdMatch = joinedMatch
	
	notification_container.create_notification(tr("Partida encontrada!"), 
						NotificationContainer.NotificationType.OK)
	_show_match_found("nome da partida")

func _on_close_quit_match_pressed() -> void:
	if not createdMatch:
		return
		
	var result = await NakamaManager.socket.leave_match_async(createdMatch.match_id)
	
	if result.is_exception():
		notification_container.create_notification("Não foi possível sair da partida", 
												NotificationContainer.NotificationType.ERROR )
		
	notification_container.create_notification("Você saiu da partida com sucesso",
										 NotificationContainer.NotificationType.OK )

	your_match_info.visible = false
	matchmaking_finder.visible = true
	
	if start_game_button.pressed.is_connected(_on_start_game):
		start_game_button.pressed.disconnect(_on_start_game)

func _on_start_game() -> void:
	
	if multiplayer.is_server():
		start_game.emit()
	else:
		Ready.rpc()
	

@rpc("any_peer", "call_local")
func Ready():
	
	var id = multiplayer.get_remote_sender_id()
	
	if players.has(id):
		var player_confirmed = players[id]
		players[id] = not player_confirmed
	else:
		players[id] = true
		
	confirmed_players = 0
	for i in players:
		if players[i]:
			confirmed_players += 1
				
	if multiplayer.is_server():
		start_game_button.disabled = confirmed_players != num_players

	_update_players_confirmed()
		
func _on_map_selector_map_selected(map_name: String, map_scene: String) -> void:
	select_match_label.text = "Selected map: %s" % [map_name]
	match_scene_selected = map_scene

@rpc("any_peer","call_local")
func reset_confirmation() -> void:
	confirmed_players = 0
	_update_players_confirmed()
	start_game_button.button_pressed = false
