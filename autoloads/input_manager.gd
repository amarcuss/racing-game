extends Node

## Registers all player input actions via InputMap API and provides
## per-player input accessors.

func _ready() -> void:
	_register_p1_actions()
	_register_p2_actions()

func _register_p1_actions() -> void:
	_add_key_action("p1_accelerate", KEY_W)
	_add_key_action("p1_brake", KEY_S)
	_add_key_action("p1_steer_left", KEY_A)
	_add_key_action("p1_steer_right", KEY_D)
	_add_key_action("p1_handbrake", KEY_SPACE)
	_add_key_action("p1_look_back", KEY_Q)
	_add_key_action("p1_reset", KEY_R)
	_add_key_action("p1_pause", KEY_ESCAPE)

	# Gamepad for player 1 (device 0)
	_add_joy_axis_action("p1_accelerate", JOY_AXIS_TRIGGER_RIGHT, 0.1, 0)
	_add_joy_axis_action("p1_brake", JOY_AXIS_TRIGGER_LEFT, 0.1, 0)
	_add_joy_axis_action("p1_steer_left", JOY_AXIS_LEFT_X, -0.2, 0)
	_add_joy_axis_action("p1_steer_right", JOY_AXIS_LEFT_X, 0.2, 0)
	_add_joy_button_action("p1_handbrake", JOY_BUTTON_A, 0)
	_add_joy_button_action("p1_look_back", JOY_BUTTON_LEFT_SHOULDER, 0)
	_add_joy_button_action("p1_reset", JOY_BUTTON_Y, 0)
	_add_joy_button_action("p1_pause", JOY_BUTTON_START, 0)

func _register_p2_actions() -> void:
	_add_key_action("p2_accelerate", KEY_UP)
	_add_key_action("p2_brake", KEY_DOWN)
	_add_key_action("p2_steer_left", KEY_LEFT)
	_add_key_action("p2_steer_right", KEY_RIGHT)
	_add_key_action("p2_handbrake", KEY_KP_0)
	_add_key_action("p2_look_back", KEY_KP_1)
	_add_key_action("p2_reset", KEY_KP_2)

	# Gamepad for player 2 (device 1)
	_add_joy_axis_action("p2_accelerate", JOY_AXIS_TRIGGER_RIGHT, 0.1, 1)
	_add_joy_axis_action("p2_brake", JOY_AXIS_TRIGGER_LEFT, 0.1, 1)
	_add_joy_axis_action("p2_steer_left", JOY_AXIS_LEFT_X, -0.2, 1)
	_add_joy_axis_action("p2_steer_right", JOY_AXIS_LEFT_X, 0.2, 1)
	_add_joy_button_action("p2_handbrake", JOY_BUTTON_A, 1)
	_add_joy_button_action("p2_look_back", JOY_BUTTON_LEFT_SHOULDER, 1)
	_add_joy_button_action("p2_reset", JOY_BUTTON_Y, 1)

# --- Input accessors ---

func get_acceleration(player: int) -> float:
	var prefix := _prefix(player)
	return Input.get_action_strength(prefix + "accelerate")

func get_brake(player: int) -> float:
	var prefix := _prefix(player)
	return Input.get_action_strength(prefix + "brake")

func get_steering(player: int) -> float:
	var prefix := _prefix(player)
	var left := Input.get_action_strength(prefix + "steer_left")
	var right := Input.get_action_strength(prefix + "steer_right")
	return right - left

func is_handbrake(player: int) -> bool:
	return Input.is_action_pressed(_prefix(player) + "handbrake")

func is_look_back(player: int) -> bool:
	return Input.is_action_pressed(_prefix(player) + "look_back")

func is_reset_pressed(player: int) -> bool:
	return Input.is_action_just_pressed(_prefix(player) + "reset")

func is_pause_pressed() -> bool:
	return Input.is_action_just_pressed("p1_pause")

# --- Helpers ---

func _prefix(player: int) -> String:
	return "p" + str(player + 1) + "_"

func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)

func _add_joy_button_action(action_name: String, button: JoyButton, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	InputMap.action_add_event(action_name, event)

func _add_joy_axis_action(action_name: String, axis: JoyAxis, deadzone_threshold: float, device: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, abs(deadzone_threshold))
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = sign(deadzone_threshold)
	event.device = device
	InputMap.action_add_event(action_name, event)
