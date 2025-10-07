extends CharacterBody2D
class_name Player

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var remote_transform_2d: RemoteTransform2D = $RemoteTransform2D
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	
	var can_control_player : bool = \
	 name == str(multiplayer.get_unique_id()) \
	 or name == "Player"
	
	set_physics_process(can_control_player)
	set_process(can_control_player)

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
	
	if not is_queued_for_deletion() and is_inside_tree():
		syncPos.rpc(global_position)
		
@rpc("any_peer")
func syncPos(p) -> void:
	global_position = p
	
func setup_camera(camera: Camera2D) -> void:
	remote_transform_2d.remote_path = camera.get_path()
