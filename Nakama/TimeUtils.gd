extends RefCounted
class_name TimeUtils

## A utility class for parsing and formatting timestamps from Nakama.
## [br][br]
## Nakama uses ISO 8601 format (e.g., "2025-10-20T23:59:20Z")
## [br][br]
## [b]Usage Examples:[/b]
## [codeblock]
## # Parse a timestamp
## var formatted = TimeUtils.parse_nakama_timestamp("2025-10-20T23:59:20Z")
## 
## # Get relative time: "5 minutes ago"
## var relative = formatted.get_relative_time()
## 
## # Get full datetime: "Oct 20, 2025 11:59 PM"
## var full = formatted.get_full_datetime()
## 
## # Get custom format
## var custom = formatted.get_custom_format("%Y-%m-%d at %I:%M %p")
## # Result: "2025-10-20 at 11:59 PM"
## 
## # Quick helpers
## var relative_quick = TimeUtils.get_relative_time("2025-10-20T23:59:20Z")
## var full_quick = TimeUtils.get_full_datetime("2025-10-20T23:59:20Z")
## [/codeblock]

## Represents a parsed timestamp with various formatting options
class FormattedTime:
	var unix_time: int
	var datetime_dict: Dictionary
	
	func _init(p_unix_time: int, p_datetime_dict: Dictionary):
		unix_time = p_unix_time
		datetime_dict = p_datetime_dict
	
	## Get time in "X minutes/hours/days ago" format
	func get_relative_time() -> String:
		var current_time = Time.get_unix_time_from_system()
		var diff = current_time - unix_time
		
		if diff < 60:
			return "Just now"
		elif diff < 3600: # Less than 1 hour
			var minutes = int(diff / 60)
			return "%d minute%s ago" % [minutes, "s" if minutes != 1 else ""]
		elif diff < 86400: # Less than 1 day
			var hours = int(diff / 3600)
			return "%d hour%s ago" % [hours, "s" if hours != 1 else ""]
		elif diff < 604800: # Less than 1 week
			var days = int(diff / 86400)
			return "%d day%s ago" % [days, "s" if days != 1 else ""]
		elif diff < 2592000: # Less than 30 days
			var weeks = int(diff / 604800)
			return "%d week%s ago" % [weeks, "s" if weeks != 1 else ""]
		elif diff < 31536000: # Less than 1 year
			var months = int(diff / 2592000)
			return "%d month%s ago" % [months, "s" if months != 1 else ""]
		else:
			var years = int(diff / 31536000)
			return "%d year%s ago" % [years, "s" if years != 1 else ""]
	
	## Get formatted date and time: "Oct 20, 2025 11:59 PM"
	func get_full_datetime() -> String:
		var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", 
						   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var month = month_names[datetime_dict.month - 1]
		var hour = datetime_dict.hour
		var period = "AM"
		
		if hour >= 12:
			period = "PM"
			if hour > 12:
				hour -= 12
		elif hour == 0:
			hour = 12
		
		return "%s %d, %d %d:%02d %s" % [
			month, 
			datetime_dict.day, 
			datetime_dict.year, 
			hour, 
			datetime_dict.minute, 
			period
		]
	
	## Get short date format: "Oct 20, 2025"
	func get_short_date() -> String:
		var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", 
						   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var month = month_names[datetime_dict.month - 1]
		return "%s %d, %d" % [month, datetime_dict.day, datetime_dict.year]
	
	## Get time only: "11:59 PM"
	func get_time_only() -> String:
		var hour = datetime_dict.hour
		var period = "AM"
		
		if hour >= 12:
			period = "PM"
			if hour > 12:
				hour -= 12
		elif hour == 0:
			hour = 12
		
		return "%d:%02d %s" % [hour, datetime_dict.minute, period]
	
	## Get ISO format: "2025-10-20T23:59:20Z"
	func get_iso_format() -> String:
		return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			datetime_dict.year,
			datetime_dict.month,
			datetime_dict.day,
			datetime_dict.hour,
			datetime_dict.minute,
			datetime_dict.second
		]
	
	## Get custom format using strftime-style format codes
	## Available codes:
	## %Y - Year (4 digits), %y - Year (2 digits)
	## %m - Month (01-12), %d - Day (01-31)
	## %H - Hour 24h (00-23), %I - Hour 12h (01-12)
	## %M - Minute (00-59), %S - Second (00-59)
	## %p - AM/PM
	func get_custom_format(format_string: String) -> String:
		var result = format_string
		var hour_12 = datetime_dict.hour
		var period = "AM"
		
		if hour_12 >= 12:
			period = "PM"
			if hour_12 > 12:
				hour_12 -= 12
		elif hour_12 == 0:
			hour_12 = 12
		
		result = result.replace("%Y", "%04d" % datetime_dict.year)
		result = result.replace("%y", "%02d" % (datetime_dict.year % 100))
		result = result.replace("%m", "%02d" % datetime_dict.month)
		result = result.replace("%d", "%02d" % datetime_dict.day)
		result = result.replace("%H", "%02d" % datetime_dict.hour)
		result = result.replace("%I", "%02d" % hour_12)
		result = result.replace("%M", "%02d" % datetime_dict.minute)
		result = result.replace("%S", "%02d" % datetime_dict.second)
		result = result.replace("%p", period)
		
		return result

## Parse an ISO 8601 timestamp string from Nakama into a FormattedTime object
## Example input: "2025-10-20T23:59:20Z"
static func parse_nakama_timestamp(timestamp: String) -> FormattedTime:
	# Remove the 'Z' suffix if present
	var clean_timestamp = timestamp.replace("Z", "")
	
	# Split date and time
	var parts = clean_timestamp.split("T")
	if parts.size() != 2:
		push_error("Invalid timestamp format: " + timestamp)
		return null
	
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	if date_parts.size() != 3 or time_parts.size() != 3:
		push_error("Invalid timestamp format: " + timestamp)
		return null
	
	var datetime_dict = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2])
	}
	
	# Convert to Unix timestamp
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	
	return FormattedTime.new(unix_time, datetime_dict)

## Quick helper to get relative time from a Nakama timestamp string
static func get_relative_time(timestamp: String) -> String:
	var formatted = parse_nakama_timestamp(timestamp)
	return formatted.get_relative_time() if formatted else "Unknown"

## Quick helper to get full datetime from a Nakama timestamp string
static func get_full_datetime(timestamp: String) -> String:
	var formatted = parse_nakama_timestamp(timestamp)
	return formatted.get_full_datetime() if formatted else "Unknown"
