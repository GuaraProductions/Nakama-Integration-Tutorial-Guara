extends PanelContainer

signal player_wants_to_chat_with_group(id: String)

@export var groups_packed_scene : PackedScene

@onready var search_group: LineEdit = %SearchGroup
@onready var add_group_line_edit: LineEdit = %AddGroupLineEdit
@onready var add_group: Button = %AddGroup
@onready var groups_container: VBoxContainer = %GroupsContainer

func _ready() -> void:
	NakamaManager.user_logged_in.connect(update_friends_list)

func update_friends_list() -> void:
	clear_box(groups_container)
	var result_group_information = await NakamaManager.client.list_groups_async(NakamaManager.session, search_group.text, 1)
	
	if result_group_information.groups.size() == 0:
		return

	#selected_group_name.text = "Group name: %s" % group.name
	#selected_group_description.text = "Group description: %s" % group.description
	#selected_group_id.text = "Group ID: %s" % group.id
	#selected_group_is_open.text = "Is open: %s" %  str(group.open)
	
	for i in result_group_information.groups:
		
		var group_button_instance = groups_packed_scene.instantiate()
		
		groups_container.add_child(group_button_instance)
		group_button_instance.set_group(i.id, i.name, chat_with_group, leave_group)
		
func clear_box(box: BoxContainer) -> void:
	
	for child in box.get_children():
		child.queue_free()
		child = null

func leave_group(id: String) -> void:
	NakamaManager.leave_group(id)
	update_friends_list()

func chat_with_group(id: String) -> void:
	player_wants_to_chat_with_group.emit(id)
