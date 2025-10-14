extends PanelContainer
class_name MapIcon

signal map_selected()

@onready var map_title: Label = %MapTitle
@onready var map_preview: TextureButton = %MapPreview

func configure(title: String, texture: Texture) -> void:
	
	if title and not title.is_empty():
		map_title.text = title
		
	if texture:
		map_preview.texture_normal = texture


func _on_button_pressed() -> void:
	map_selected.emit()
