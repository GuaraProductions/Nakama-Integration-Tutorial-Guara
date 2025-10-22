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
var formatted_time = null # TimeUtils.FormattedTime

func setup(notif: NakamaAPI.ApiNotification, users_map: Dictionary = {}) -> void:
	notification_id = notif.id
	
	# Parse and format timestamp
	formatted_time = TimeUtils.parse_nakama_timestamp(notif.create_time)
	if formatted_time:
		timestamp.text = formatted_time.get_relative_time()
		# Set tooltip to show full datetime on hover
		timestamp.tooltip_text = formatted_time.get_full_datetime()
	else:
		timestamp.text = notif.create_time
		timestamp.tooltip_text = notif.create_time
	
	notification_type.text = _get_notification_type_text(notif.code)
	
	# Get sender display name from users_map (already fetched in batch)
	if notif.sender_id and notif.sender_id != "":
		_set_sender_display_name(notif.sender_id, notif.subject, users_map)
	else:
		# Server notification (no sender)
		subject.text = notif.subject

## Set the sender's display name using pre-fetched user data
func _set_sender_display_name(sender_id: String, fallback_subject: String, users_map: Dictionary) -> void:
	if sender_id in users_map:
		var sender_user: NakamaAPI.ApiUser = users_map[sender_id]
		var display_name = sender_user.display_name if sender_user.display_name != "" else sender_user.username
		
		# Update the subject to include the display name
		subject.text = fallback_subject.replace(sender_user.username, display_name)
	else:
		# Fallback if user not found in map
		subject.text = fallback_subject
	
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

## Update the timestamp display format
## Available formats:
## - "relative": "5 minutes ago" (default)
## - "full": "Oct 20, 2025 11:59 PM"
## - "short": "Oct 20, 2025"
## - "time": "11:59 PM"
## - "iso": "2025-10-20T23:59:20Z"
## - custom: Use custom format string (e.g., "%Y-%m-%d %H:%M")
func set_timestamp_format(format: String = "relative") -> void:
	if not formatted_time:
		return
	
	match format:
		"relative":
			timestamp.text = formatted_time.get_relative_time()
		"full":
			timestamp.text = formatted_time.get_full_datetime()
		"short":
			timestamp.text = formatted_time.get_short_date()
		"time":
			timestamp.text = formatted_time.get_time_only()
		"iso":
			timestamp.text = formatted_time.get_iso_format()
		_:
			# Custom format
			timestamp.text = formatted_time.get_custom_format(format)
	
	# Always keep the tooltip showing the full datetime
	timestamp.tooltip_text = formatted_time.get_full_datetime()
