extends PanelContainer
class_name NotificationBubble

## Notification codes from Nakama server
enum NotificationCode {
	RESERVED = 0,
	MESSAGE_RECEIVED = -1,          ## Message received from user X while offline or not in channel
	FRIEND_REQUEST = -2,            ## User X wants to add you as a friend
	FRIEND_ACCEPTED = -3,           ## User X accepted your friend invite
	GROUP_ACCEPTED = -4,            ## You've been accepted to X group
	GROUP_JOIN_REQUEST = -5,        ## User X wants to join your group
	FRIEND_ONLINE = -6,             ## Your friend X has just joined the game
	SOCKET_CLOSED = -7,             ## Final notifications to sockets closed via the single_socket configuration
	BANNED = -8                     ## You've been banned
}

signal delete_notification(notification_id)

@onready var subject: Label = %Subject
@onready var timestamp: Label = %Timestamp
@onready var notification_type: Label = %NotificationType

var notification_id: String = ""

func setup(notif: NakamaAPI.ApiNotification) -> void:

	subject.text = notif.subject
	timestamp.text = notif.create_time
	notification_type.text = _get_notification_type_text(notif.code)
	
## Get a human-readable notification type text
func _get_notification_type_text(code: int) -> String:
	match code:
		NotificationCode.MESSAGE_RECEIVED:
			return "📨 Message Received"
		NotificationCode.FRIEND_REQUEST:
			return "👤 Friend Request"
		NotificationCode.FRIEND_ACCEPTED:
			return "✅ Friend Accepted"
		NotificationCode.GROUP_ACCEPTED:
			return "🎉 Group Accepted"
		NotificationCode.GROUP_JOIN_REQUEST:
			return "👥 Group Join Request"
		NotificationCode.FRIEND_ONLINE:
			return "🟢 Friend Online"
		NotificationCode.SOCKET_CLOSED:
			return "🔌 Socket Closed"
		NotificationCode.BANNED:
			return "🚫 Banned"
		_:
			return "📢 Notification (Code: %d)" % code

func _on_delete_pressed() -> void:
	delete_notification.emit(notification_id)
