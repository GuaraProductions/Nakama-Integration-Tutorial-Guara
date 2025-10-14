extends PanelContainer

@onready var map_selector_option_button: OptionButton = %MapSelectorOptionButton
@onready var user_type_option_button: OptionButton = %UserTypeOptionButton
@onready var scoring_label: Label = %ScoringLabel

func _ready() -> void:
	NakamaManager.user_logged_in.connect(_user_logged_in)
	
func _user_logged_in() -> void:

	var score = 1
	var subscore = 0
	var metadata = { "map": "space_station" }
	var record : NakamaAPI.ApiLeaderboardRecord = await NakamaManager.write_leaderboard("weekly_imposter_wins", score, subscore, metadata)

func _on_update_leaderboard_pressed() -> void:
	pass # Replace with function body.
