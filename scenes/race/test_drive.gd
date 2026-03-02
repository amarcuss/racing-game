extends Node3D

## Test drive scene — flat ground with a car and chase camera for Phase 1 testing.

@onready var car: VehicleBody3D = $Car
@onready var camera: Camera3D = $RaceCamera

func _ready() -> void:
	camera.set_target(car)
