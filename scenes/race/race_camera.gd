class_name RaceCamera
extends Camera3D

## Smooth chase camera that follows a CarBase with look-back support.

@export var target_path: NodePath
@export var player_index: int = 0

var target: Node3D

# Chase cam parameters
var follow_distance: float = 7.0
var follow_height: float = 3.0
var look_ahead: float = 3.0
var smoothing_speed: float = 5.0
var rotation_smoothing: float = 8.0

# Look-back
var look_back_distance: float = 5.0
var look_back_height: float = 2.5
var is_looking_back: bool = false

func _ready() -> void:
	if target_path:
		target = get_node(target_path)

func set_target(node: Node3D) -> void:
	target = node

func _physics_process(delta: float) -> void:
	if not target:
		return

	is_looking_back = InputManager.is_look_back(player_index)

	var target_basis := target.global_transform.basis
	var forward := -target_basis.z.normalized()
	var target_pos := target.global_position

	var desired_pos: Vector3
	var look_target: Vector3

	if is_looking_back:
		desired_pos = target_pos + forward * look_back_distance + Vector3.UP * look_back_height
		look_target = target_pos + forward * 10.0
	else:
		desired_pos = target_pos - forward * follow_distance + Vector3.UP * follow_height
		look_target = target_pos + forward * look_ahead

	# Smooth position
	global_position = global_position.lerp(desired_pos, smoothing_speed * delta)

	# Smooth look-at
	var current_forward := -global_transform.basis.z
	var desired_forward := (look_target - global_position).normalized()
	var smoothed_forward := current_forward.lerp(desired_forward, rotation_smoothing * delta).normalized()

	if smoothed_forward.length() > 0.001:
		look_at(global_position + smoothed_forward, Vector3.UP)
