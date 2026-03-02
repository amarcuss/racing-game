extends Node

## Minimal game manager — state holder and car/track registry.

enum GameState { MENU, RACING, PAUSED }

var state: GameState = GameState.MENU
var selected_car_index: int = 0
var selected_track_index: int = 0

const CAR_PATHS: Array[String] = [
	"res://cars/car_definitions/starter_sedan.tres",
	"res://cars/car_definitions/sport_coupe.tres",
	"res://cars/car_definitions/muscle_car.tres",
	"res://cars/car_definitions/super_car.tres",
	"res://cars/car_definitions/hyper_car.tres",
]

const TRACK_PATHS: Array[String] = [
	"res://tracks/track_definitions/oval_speedway.tres",
	"res://tracks/track_definitions/mountain_circuit.tres",
	"res://tracks/track_definitions/city_streets.tres",
]

func get_selected_car_data() -> Resource:
	if selected_car_index < CAR_PATHS.size():
		return load(CAR_PATHS[selected_car_index])
	return load(CAR_PATHS[0])

func get_car_data(index: int) -> Resource:
	if index >= 0 and index < CAR_PATHS.size():
		return load(CAR_PATHS[index])
	return null

func get_track_data(index: int) -> Resource:
	if index >= 0 and index < TRACK_PATHS.size():
		return load(TRACK_PATHS[index])
	return null

func get_selected_track_data() -> Resource:
	if selected_track_index < TRACK_PATHS.size():
		return load(TRACK_PATHS[selected_track_index])
	return load(TRACK_PATHS[0])
