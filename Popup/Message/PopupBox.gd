extends Window
class_name PopupBox

@onready var description: Label = $"-/Description"
@onready var button: Button = $"-/Button"

func configure_text(new_title: String, new_message: String) -> void:
	description.text = new_message
	title = new_title

func _on_button_pressed() -> void:
	close_requested.emit()

func _on_about_to_popup() -> void:
	pass # Replace with function body.

func _on_close_requested() -> void:
	hide()
