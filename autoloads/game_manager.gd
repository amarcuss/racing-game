extends Node

## Game manager — state holder, car/track registry, scene transitions.

enum GameState { MENU, RACING, PAUSED }
enum RacingMode { STREET, F1, BAJA }

var state: GameState = GameState.MENU
var racing_mode: RacingMode = RacingMode.STREET
var selected_car_index: int = 0
var selected_track_index: int = 0

# Race setup (set by race_setup screen)
var race_laps: int = 3
var ai_count: int = 5
var ai_difficulty: int = 1  # 0=EASY, 1=MEDIUM, 2=HARD
var split_screen: bool = false
var p2_car_index: int = 0

const CAR_PATHS: Array[String] = [
	"res://cars/car_definitions/starter_sedan.tres",
	"res://cars/car_definitions/sport_coupe.tres",
	"res://cars/car_definitions/muscle_car.tres",
	"res://cars/car_definitions/f1_car.tres",
	"res://cars/car_definitions/f1_car_blue.tres",
	"res://cars/car_definitions/super_car.tres",
	"res://cars/car_definitions/hyper_car.tres",
	"res://cars/car_definitions/baja_buggy.tres",
	"res://cars/car_definitions/trophy_truck.tres",
	"res://cars/car_definitions/desert_runner.tres",
]

const TRACK_PATHS: Array[String] = [
	"res://tracks/track_definitions/oval_speedway.tres",
	"res://tracks/track_definitions/mountain_circuit.tres",
	"res://tracks/track_definitions/city_streets.tres",
	"res://tracks/track_definitions/f1_monaco.tres",
	"res://tracks/track_definitions/f1_monza.tres",
	"res://tracks/track_definitions/f1_spa.tres",
	"res://tracks/track_definitions/baja_canyon.tres",
	"res://tracks/track_definitions/baja_desert.tres",
	"res://tracks/track_definitions/baja_coastal.tres",
]

# Fade transition
var _transition_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning: bool = false

func _ready() -> void:
	_setup_transition_layer()
	call_deferred("_sync_from_profile")

func _setup_transition_layer() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100
	add_child(_transition_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.position = Vector2.ZERO
	_fade_rect.size = Vector2(1920, 1080)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_fade_rect)

func _sync_from_profile() -> void:
	if SaveManager and SaveManager.profile:
		selected_car_index = SaveManager.profile.selected_car_index

func transition_to_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	tween.tween_interval(0.05)
	tween.tween_callback(func():
		var fade_in := create_tween()
		fade_in.tween_property(_fade_rect, "color:a", 0.0, 0.3)
		fade_in.tween_callback(func():
			_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_transitioning = false
		)
	)

func go_to_main_menu() -> void:
	Engine.time_scale = 1.0
	RaceManager.reset()
	get_tree().paused = false
	state = GameState.MENU
	transition_to_scene("res://scenes/main.tscn")

func go_to_race() -> void:
	Engine.time_scale = 1.0
	state = GameState.RACING
	if split_screen:
		transition_to_scene("res://scenes/race/split_screen_race.tscn")
	else:
		transition_to_scene("res://scenes/race/race_scene.tscn")

func get_selected_car_data() -> Resource:
	if selected_car_index < CAR_PATHS.size():
		return load(CAR_PATHS[selected_car_index])
	return load(CAR_PATHS[0])

func get_p2_car_data() -> Resource:
	if p2_car_index < CAR_PATHS.size():
		return load(CAR_PATHS[p2_car_index])
	return load(CAR_PATHS[0])

func get_car_data(index: int) -> Resource:
	if index >= 0 and index < CAR_PATHS.size():
		if ResourceLoader.exists(CAR_PATHS[index]):
			return load(CAR_PATHS[index])
	return null

func get_track_data(index: int) -> Resource:
	if index >= 0 and index < TRACK_PATHS.size():
		if ResourceLoader.exists(TRACK_PATHS[index]):
			return load(TRACK_PATHS[index])
	return null

func get_selected_track_data() -> Resource:
	if selected_track_index < TRACK_PATHS.size():
		return load(TRACK_PATHS[selected_track_index])
	return load(TRACK_PATHS[0])

# Mode-filtered indices
const STREET_CAR_INDICES: Array[int] = [0, 1, 2]  # sedan, coupe, muscle
const F1_CAR_INDICES: Array[int] = [3, 4]  # f1_car, f1_car_blue
const BAJA_CAR_INDICES: Array[int] = [7, 8, 9]  # buggy, trophy_truck, desert_runner
const STREET_TRACK_INDICES: Array[int] = [0, 1, 2]  # oval, mountain, city
const F1_TRACK_INDICES: Array[int] = [3, 4, 5]  # monaco, monza, spa
const BAJA_TRACK_INDICES: Array[int] = [6, 7, 8]  # canyon, desert, coastal

func get_car_indices_for_mode() -> Array[int]:
	match racing_mode:
		RacingMode.F1:
			return F1_CAR_INDICES
		RacingMode.BAJA:
			return BAJA_CAR_INDICES
		_:
			return STREET_CAR_INDICES

func get_track_indices_for_mode() -> Array[int]:
	match racing_mode:
		RacingMode.F1:
			return F1_TRACK_INDICES
		RacingMode.BAJA:
			return BAJA_TRACK_INDICES
		_:
			return STREET_TRACK_INDICES

const NUM_RACING_MODES: int = 3

func set_racing_mode(mode: RacingMode) -> void:
	racing_mode = mode
	var car_indices := get_car_indices_for_mode()
	selected_car_index = car_indices[0]
	var track_indices := get_track_indices_for_mode()
	selected_track_index = track_indices[0]
