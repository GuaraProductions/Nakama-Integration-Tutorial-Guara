extends PanelContainer

var party : NakamaRTAPI.Party = null

@onready var party_creator: PanelContainer = %PartyCreator
@onready var party_is_open_check_box: CheckBox = %PartyIsOpenCheckBox
@onready var party_information: PanelContainer = %PartyInformation
@onready var party_id_line_edit: LineEdit = %PartyIDLineEdit

func _ready() -> void:
	toggle_party_sections_visibility()

func _on_create_party_button_pressed() -> void:
	party = await NakamaManager.create_party(party_is_open_check_box.button_pressed)
	toggle_party_sections_visibility()

func create_party() -> void:
	party = await NakamaManager.create_party(party_is_open_check_box.button_pressed)
	toggle_party_sections_visibility()

func toggle_party_sections_visibility() -> void:
	party_creator.visible = party == null
	party_information.visible = party != null
	
	if party_information.visible:
		update_party_information()
		
func update_party_information() -> void:
	party_id_line_edit.text = party.party_id
