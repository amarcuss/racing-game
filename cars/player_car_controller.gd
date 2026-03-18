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

	if RaceManager.state != RaceManager.RaceState.RACING:
		car.set_inputs(0.0, 0.0, 0.0, false)
		return

	var throttle: float = InputManager.get_acceleration(player_index)
	var braking: float = InputManager.get_brake(player_index)
	var steer: float = InputManager.get_steering(player_index)
	var handbrake: bool = InputManager.is_handbrake(player_index)

	car.set_inputs(throttle, braking, steer, handbrake)

	# DRS activation — throttle must be held and DRS must be available
	if car.drs_available and throttle > 0.5 and braking == 0.0:
		car.drs_active = true
	else:
		car.drs_active = false

	if InputManager.is_reset_pressed(player_index):
		car.reset_to_track()
