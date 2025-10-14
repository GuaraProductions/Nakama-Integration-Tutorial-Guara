extends CharacterBody2D
class_name Player

const GROUP_NAME : String = "Player"

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var remote_transform_2d: RemoteTransform2D = $RemoteTransform2D
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	
	add_to_group(GROUP_NAME)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func disable_sync() -> void:
	multiplayer_synchronizer = null
	
func setup_camera(camera: Camera2D) -> void:
	remote_transform_2d.remote_path = camera.get_path()
