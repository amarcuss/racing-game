class_name PlayerCarController
extends Node

## Reads input from InputManager and drives a CarBase.

@export var player_index: int = 0
var car: VehicleBody3D

func _ready() -> void:
	car = get_parent() as VehicleBody3D

func _physics_process(_delta: float) -> void:
	if not car or not car.has_method("set_inputs"):
		return

	var throttle: float = InputManager.get_acceleration(player_index)
	var braking: float = InputManager.get_brake(player_index)
	var steer: float = InputManager.get_steering(player_index)
	var handbrake: bool = InputManager.is_handbrake(player_index)

	car.set_inputs(throttle, braking, steer, handbrake)

	if InputManager.is_reset_pressed(player_index):
		car.reset_to_track()
