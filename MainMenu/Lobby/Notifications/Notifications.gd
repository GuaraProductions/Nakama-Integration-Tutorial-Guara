extends PanelContainer

@export var notification_bubble_scene : PackedScene

@onready var notifications_v_container: VBoxContainer = %NotificationsVContainer

## The cacheable cursor for pagination
var cacheable_cursor: String = ""

## Track loaded notification IDs to avoid duplicates
var loaded_notification_ids: Array[String] = []

func _ready() -> void:	
	NakamaManager.user_logged_in.connect(_user_logged_in)

func _user_logged_in() -> void:
	# Load notifications when the panel is ready
	await load_notifications()
	
	# Listen for real-time notifications if socket is available
	if NakamaManager.socket:
		NakamaManager.socket.received_notification.connect(_on_notification_received)
## Load notifications from the server with pagination support
func load_notifications(limit: int = 100) -> void:
	var cursor_value = cacheable_cursor if cacheable_cursor != "" else ""
	var result: NakamaAPI.ApiNotificationList = await NakamaManager.list_notifications(limit, cursor_value)
	
	if result.is_exception():
		print("Failed to load notifications: %s" % result)
		return
	
	# Process the notifications
	for i in range(result.notifications.size() - 1, -1, -1):
		
		var notif = result.notifications[i]
		
		_add_notification_to_ui(notif)
	
	# Update the cursor for pagination
	if result.cacheable_cursor:
		cacheable_cursor = result.cacheable_cursor
	
	print("Loaded %d notifications" % result.notifications.size())

## Load more notifications (for infinite scroll or "Load More" button)
func load_more_notifications(limit: int = 100) -> void:
	if cacheable_cursor == "":
		print("No more notifications to load")
		return
	
	await load_notifications(limit)

## Handle real-time notification received while connected
func _on_notification_received(notif: NakamaAPI.ApiNotification) -> void:
	print("Received notification: %s - %s" % [notif.subject, notif.content])
	_add_notification_to_ui(notif)

## Add a notification to the UI
func _add_notification_to_ui(notif: NakamaAPI.ApiNotification) -> void:
	# Avoid duplicate notifications
	if notif.id in loaded_notification_ids:
		return
	
	loaded_notification_ids.append(notif.id)
	
	_create_notification_item(notif)

## Create a notification UI element
## Override this function to customize how notifications are displayed
func _create_notification_item(notif: NakamaAPI.ApiNotification) -> void:

	var notification_bubble_instance : NotificationBubble = notification_bubble_scene.instantiate()

	#delete_button.pressed.connect(_on_delete_notification.bind(notif.id, panel))
	notifications_v_container.add_child(notification_bubble_instance)
	
	notification_bubble_instance.setup(notif)
	notification_bubble_instance.delete_notification.connect(_on_delete_notification.bind(notification_bubble_instance))


## Delete a notification
func _on_delete_notification(notification_id: String, ui_element: Control) -> void:
	var delete_result: NakamaAsyncResult = await NakamaManager.delete_notifications([notification_id])
	
	if delete_result.is_exception():
		print("Failed to delete notification: %s" % delete_result)
		return
	
	notifications_v_container.remove_child(ui_element)
	ui_element.queue_free()
	
	# Remove from loaded IDs
	loaded_notification_ids.erase(notification_id)
	
	print("Notification deleted successfully")

## Clear all notifications (UI only, doesn't delete from server)
func clear_ui() -> void:
	for child in notifications_v_container.get_children():
		child.queue_free()
	loaded_notification_ids.clear()

## Delete all notifications from server and clear UI
func delete_all_notifications() -> void:
	if loaded_notification_ids.is_empty():
		return
	
	var delete_result: NakamaAsyncResult = await NakamaManager.delete_notifications(PackedStringArray(loaded_notification_ids))
	
	if delete_result.is_exception():
		print("Failed to delete all notifications: %s" % delete_result)
		return
	
	clear_ui()
	print("All notifications deleted successfully")
