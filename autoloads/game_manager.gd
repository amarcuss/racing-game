extends Node

## Game manager — state holder, car/track registry, scene transitions.

enum GameState { MENU, RACING, PAUSED }
enum RacingMode { STREET, F1, BAJA, NASCAR }

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

# Season state (generic for all modes)
var season_active: bool = false
var season_current_round: int = 0
var season_player_car_index: int = 0
var season_driver_points: Dictionary = {}  # "car_index_slot" -> points
var season_results: Array = []
var season_mode: RacingMode = RacingMode.F1  # Which mode this season is for

# --- Season configs per mode ---

const SEASON_TITLES := {
	0: "GT CHAMPIONSHIP",      # STREET
	1: "F1 WORLD CHAMPIONSHIP", # F1
	2: "SCORE DESERT SERIES",   # BAJA
	3: "NASCAR CUP SERIES",     # NASCAR
}

const SEASON_TEAM_NAMES := {
	# STREET / GT (car indices 0-7)
	0: "Apex Autosport",
	1: "Crimson Works Racing",
	2: "Blackridge Motorsport",
	3: "Vortex Racing Co.",
	4: "Glacier Speed",
	5: "Solaris Performance",
	6: "Tempest Dynamics",
	7: "Inferno GT",
	# F1 (car indices 8-17)
	8: "Scuderia Veloce",
	9: "Alpine Zenith F1",
	10: "Quicksilver Grand Prix",
	11: "Solstice Racing F1",
	12: "Verdant Motorsport",
	13: "Sakura Grand Prix",
	14: "Polaris F1 Team",
	15: "Titan Racing Works",
	16: "Aether Dynamics F1",
	17: "Aurelius Grand Prix",
	# BAJA / Desert Rally (car indices 18-25)
	18: "Sidewinder Offroad",
	19: "Iron Canyon Racing",
	20: "Nomad Expedition Co.",
	21: "Rattlesnake Rally",
	22: "Scorpion Desert Racing",
	23: "Obsidian Offroad",
	24: "Phantom Dunes Racing",
	25: "Sandstorm Unlimited",
	# NASCAR (car indices 26-41)
	26: "Thunderhawk Racing",
	27: "Hendrick Motorsport",
	28: "Nightfall Racing",
	29: "Ember Motorsport",
	30: "Roush Fenway",
	31: "Crown Royal Racing",
	32: "Penske Racing",
	33: "Stewart-Haas Racing",
	34: "Ironclad Motorsport",
	35: "Liberty Speed Co.",
	36: "Maverick Racing",
	37: "Trackhouse Racing",
	38: "Heritage Motorsport",
	39: "Front Row Motorsport",
	40: "Vanguard Racing",
	41: "Patriot Motorsport",
}

# Points systems — modeled after real series

# F1: official FIA points, top 10 score (+ fastest lap bonus added in code)
const F1_POINTS := [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

# NASCAR Cup Series: 40 for win, 35 for 2nd, then -1 per position, everyone scores
const NASCAR_POINTS := [40, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

# GT/Touring Car: BTCC-style — top 15 score, tighter at the top
const GT_POINTS := [20, 17, 15, 13, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

# SCORE Desert Series: high points for finishing (just finishing Baja is an achievement)
# Based loosely on SCORE International standings
const BAJA_POINTS := [150, 120, 100, 85, 75, 65]

# Calendars per mode
const STREET_CALENDAR := [
	{"name": "Laguna Seca Grand Prix", "track_index": 0},
	{"name": "Road America Classic", "track_index": 1},
	{"name": "Brands Hatch Touring", "track_index": 2},
	{"name": "Airport Sprint", "track_index": 10},
	{"name": "Bathurst 1000", "track_index": 1},
	{"name": "Nurburgring Sprint", "track_index": 2},
	{"name": "Suzuka GT Cup", "track_index": 0},
	{"name": "Watkins Glen Finale", "track_index": 10},
]

const F1_CALENDAR := [
	{"name": "Bahrain Grand Prix", "track_index": 6},
	{"name": "Saudi Arabian Grand Prix", "track_index": 4},
	{"name": "Australian Grand Prix", "track_index": 5},
	{"name": "Japanese Grand Prix", "track_index": 3},
	{"name": "Chinese Grand Prix", "track_index": 6},
	{"name": "Miami Grand Prix", "track_index": 4},
	{"name": "Emilia Romagna Grand Prix", "track_index": 5},
	{"name": "Monaco Grand Prix", "track_index": 3},
	{"name": "Canadian Grand Prix", "track_index": 4},
	{"name": "Spanish Grand Prix", "track_index": 6},
	{"name": "Austrian Grand Prix", "track_index": 5},
	{"name": "British Grand Prix", "track_index": 6},
	{"name": "Hungarian Grand Prix", "track_index": 3},
	{"name": "Belgian Grand Prix", "track_index": 5},
	{"name": "Dutch Grand Prix", "track_index": 4},
	{"name": "Italian Grand Prix", "track_index": 4},
	{"name": "Singapore Grand Prix", "track_index": 3},
	{"name": "United States Grand Prix", "track_index": 6},
	{"name": "Mexican Grand Prix", "track_index": 5},
	{"name": "Abu Dhabi Grand Prix", "track_index": 3},
]

const BAJA_CALENDAR := [
	{"name": "San Felipe 250", "track_index": 7},
	{"name": "Baja 500", "track_index": 8},
	{"name": "Vegas to Reno", "track_index": 9},
	{"name": "Baja 1000", "track_index": 7},
	{"name": "Baja Sur 500", "track_index": 9},
]

const NASCAR_CALENDAR := [
	{"name": "Daytona 500", "track_index": 11},
	{"name": "Atlanta Motor Speedway", "track_index": 12},
	{"name": "Las Vegas Motor Speedway", "track_index": 13},
	{"name": "Phoenix Raceway", "track_index": 12},
	{"name": "Bristol Motor Speedway", "track_index": 12},
	{"name": "Talladega Superspeedway", "track_index": 11},
	{"name": "Charlotte Motor Speedway", "track_index": 13},
	{"name": "Nashville Superspeedway", "track_index": 13},
	{"name": "Michigan International", "track_index": 11},
	{"name": "Darlington Raceway", "track_index": 13},
	{"name": "Kansas Speedway", "track_index": 13},
	{"name": "Texas Motor Speedway", "track_index": 11},
	{"name": "Martinsville Speedway", "track_index": 12},
	{"name": "Homestead-Miami", "track_index": 11},
	{"name": "Championship Race", "track_index": 13},
]

# Default laps per mode in season
const SEASON_LAPS := {0: 3, 1: 3, 2: 1, 3: 5}
# Difficulty per mode
const SEASON_DIFFICULTY := {0: 1, 1: 2, 2: 1, 3: 1}

func get_season_calendar() -> Array:
	match season_mode:
		RacingMode.STREET: return STREET_CALENDAR
		RacingMode.F1: return F1_CALENDAR
		RacingMode.BAJA: return BAJA_CALENDAR
		RacingMode.NASCAR: return NASCAR_CALENDAR
		_: return F1_CALENDAR

func get_season_points() -> Array:
	match season_mode:
		RacingMode.STREET: return GT_POINTS
		RacingMode.F1: return F1_POINTS
		RacingMode.BAJA: return BAJA_POINTS
		RacingMode.NASCAR: return NASCAR_POINTS
		_: return F1_POINTS

func get_season_car_indices() -> Array[int]:
	match season_mode:
		RacingMode.STREET: return STREET_CAR_INDICES
		RacingMode.F1: return F1_CAR_INDICES
		RacingMode.BAJA: return BAJA_CAR_INDICES
		RacingMode.NASCAR: return NASCAR_CAR_INDICES
		_: return F1_CAR_INDICES

func get_season_title() -> String:
	return SEASON_TITLES.get(int(season_mode), "CHAMPIONSHIP")

func is_team_season() -> bool:
	return season_mode == RacingMode.F1

func get_team_name(car_idx: int) -> String:
	return SEASON_TEAM_NAMES.get(car_idx, "Unknown Team")

func _driver_key(car_idx: int, slot: int) -> String:
	return "%d_%d" % [car_idx, slot]

func start_season(player_car_idx: int) -> void:
	season_active = true
	season_current_round = 0
	season_mode = racing_mode
	season_player_car_index = player_car_idx
	season_driver_points = {}
	season_results = []
	var indices: Array[int] = get_season_car_indices()
	for ci in indices:
		season_driver_points[_driver_key(ci, 1)] = 0
		if is_team_season():
			season_driver_points[_driver_key(ci, 2)] = 0
	selected_car_index = player_car_idx
	_start_season_round()

func _start_season_round() -> void:
	var calendar: Array = get_season_calendar()
	var round_data: Dictionary = calendar[season_current_round]
	selected_track_index = round_data.track_index
	selected_car_index = season_player_car_index
	racing_mode = season_mode
	race_laps = SEASON_LAPS.get(int(season_mode), 3)
	var indices: Array[int] = get_season_car_indices()
	if is_team_season():
		ai_count = indices.size() * 2 - 1  # 2 per team minus player
	else:
		ai_count = indices.size() - 1  # 1 per entry minus player
	ai_difficulty = SEASON_DIFFICULTY.get(int(season_mode), 1)
	go_to_race()

func record_season_result(finish_positions: Array) -> void:
	# Prevent double recording of the same round
	if season_results.size() > season_current_round:
		return
	var round_result: Array = []
	var points: Array = get_season_points()
	for entry in finish_positions:
		var pos: int = entry.position
		var ci: int = entry.car_index
		var slot: int = entry.driver_slot
		round_result.append(entry)
		if pos >= 1 and pos <= points.size():
			var key: String = _driver_key(ci, slot)
			season_driver_points[key] = season_driver_points.get(key, 0) + points[pos - 1]

	# F1 fastest lap bonus: +1 point (passed in via fastest_lap_car_index/slot)
	if season_mode == RacingMode.F1:
		for entry in finish_positions:
			if entry.get("fastest_lap", false) and entry.position <= 10:
				var key: String = _driver_key(entry.car_index, entry.driver_slot)
				season_driver_points[key] = season_driver_points.get(key, 0) + 1

	# NASCAR race win bonus: +5 playoff points for winning
	if season_mode == RacingMode.NASCAR:
		for entry in finish_positions:
			if entry.position == 1:
				var key: String = _driver_key(entry.car_index, entry.driver_slot)
				season_driver_points[key] = season_driver_points.get(key, 0) + 5

	season_results.append(round_result)

func get_team_points(car_idx: int) -> int:
	var d1: int = season_driver_points.get(_driver_key(car_idx, 1), 0)
	var d2: int = season_driver_points.get(_driver_key(car_idx, 2), 0)
	return d1 + d2

func get_driver_points(car_idx: int, slot: int) -> int:
	return season_driver_points.get(_driver_key(car_idx, slot), 0)

func undo_current_round_result() -> void:
	## Remove the recorded result for the current round (if any) and recalculate points.
	if season_results.size() <= season_current_round:
		return
	season_results.pop_back()
	# Rebuild all driver points from remaining results
	season_driver_points = {}
	var indices: Array[int] = get_season_car_indices()
	for ci in indices:
		season_driver_points[_driver_key(ci, 1)] = 0
		if is_team_season():
			season_driver_points[_driver_key(ci, 2)] = 0
	# Re-apply points from all recorded rounds
	var saved_results: Array = season_results.duplicate()
	season_results = []
	for round_result in saved_results:
		record_season_result(round_result)

func advance_season() -> void:
	season_current_round += 1
	var calendar: Array = get_season_calendar()
	if season_current_round >= calendar.size():
		return
	_start_season_round()

func end_season() -> void:
	season_active = false
	season_current_round = 0
	season_driver_points = {}
	season_results = []

const CAR_PATHS: Array[String] = [
	"res://cars/car_definitions/starter_sedan.tres",
	"res://cars/car_definitions/sport_coupe.tres",
	"res://cars/car_definitions/muscle_car.tres",
	"res://cars/car_definitions/street_sedan_green.tres",
	"res://cars/car_definitions/street_sedan_white.tres",
	"res://cars/car_definitions/street_coupe_yellow.tres",
	"res://cars/car_definitions/street_coupe_purple.tres",
	"res://cars/car_definitions/street_muscle_red.tres",
	"res://cars/car_definitions/f1_car.tres",
	"res://cars/car_definitions/f1_car_blue.tres",
	"res://cars/car_definitions/f1_silver.tres",
	"res://cars/car_definitions/f1_orange.tres",
	"res://cars/car_definitions/f1_green.tres",
	"res://cars/car_definitions/f1_pink.tres",
	"res://cars/car_definitions/f1_white.tres",
	"res://cars/car_definitions/f1_navy.tres",
	"res://cars/car_definitions/f1_teal.tres",
	"res://cars/car_definitions/f1_yellow.tres",
	"res://cars/car_definitions/baja_buggy.tres",
	"res://cars/car_definitions/trophy_truck.tres",
	"res://cars/car_definitions/desert_runner.tres",
	"res://cars/car_definitions/baja_buggy_green.tres",
	"res://cars/car_definitions/baja_buggy_red.tres",
	"res://cars/car_definitions/trophy_truck_black.tres",
	"res://cars/car_definitions/trophy_truck_white.tres",
	"res://cars/car_definitions/desert_runner_yellow.tres",
	"res://cars/car_definitions/nascar_red.tres",
	"res://cars/car_definitions/nascar_blue.tres",
	"res://cars/car_definitions/nascar_black.tres",
	"res://cars/car_definitions/nascar_orange.tres",
	"res://cars/car_definitions/nascar_green.tres",
	"res://cars/car_definitions/nascar_purple.tres",
	"res://cars/car_definitions/nascar_yellow.tres",
	"res://cars/car_definitions/nascar_white.tres",
	"res://cars/car_definitions/nascar_silver.tres",
	"res://cars/car_definitions/nascar_teal.tres",
	"res://cars/car_definitions/nascar_maroon.tres",
	"res://cars/car_definitions/nascar_lime.tres",
	"res://cars/car_definitions/nascar_pink.tres",
	"res://cars/car_definitions/nascar_brown.tres",
	"res://cars/car_definitions/nascar_cyan.tres",
	"res://cars/car_definitions/nascar_gold.tres",
]

const TRACK_PATHS: Array[String] = [
	"res://tracks/track_definitions/oval_speedway.tres",
	"res://tracks/track_definitions/mountain_circuit.tres",
	"res://tracks/track_definitions/city_streets.tres",
	"res://tracks/track_definitions/f1_monaco.tres",
	"res://tracks/track_definitions/f1_monza.tres",
	"res://tracks/track_definitions/f1_spa.tres",
	"res://tracks/track_definitions/f1_silverstone.tres",
	"res://tracks/track_definitions/baja_canyon.tres",
	"res://tracks/track_definitions/baja_desert.tres",
	"res://tracks/track_definitions/baja_coastal.tres",
	"res://tracks/track_definitions/airport_circuit.tres",
	"res://tracks/track_definitions/nascar_superspeedway.tres",
	"res://tracks/track_definitions/nascar_short_track.tres",
	"res://tracks/track_definitions/nascar_intermediate.tres",
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
const STREET_CAR_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]  # 8 street cars
const F1_CAR_INDICES: Array[int] = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17]  # 10 F1 cars
const BAJA_CAR_INDICES: Array[int] = [18, 19, 20, 21, 22, 23, 24, 25]  # 8 desert vehicles
const STREET_TRACK_INDICES: Array[int] = [0, 1, 2, 10]  # oval, mountain, city, airport
const F1_TRACK_INDICES: Array[int] = [3, 4, 5, 6]  # monaco, monza, spa, silverstone
const BAJA_TRACK_INDICES: Array[int] = [7, 8, 9]  # canyon, desert, coastal
const NASCAR_CAR_INDICES: Array[int] = [26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41]
const NASCAR_TRACK_INDICES: Array[int] = [11, 12, 13]

func get_car_indices_for_mode() -> Array[int]:
	match racing_mode:
		RacingMode.F1:
			return F1_CAR_INDICES
		RacingMode.BAJA:
			return BAJA_CAR_INDICES
		RacingMode.NASCAR:
			return NASCAR_CAR_INDICES
		_:
			return STREET_CAR_INDICES

func get_track_indices_for_mode() -> Array[int]:
	match racing_mode:
		RacingMode.F1:
			return F1_TRACK_INDICES
		RacingMode.BAJA:
			return BAJA_TRACK_INDICES
		RacingMode.NASCAR:
			return NASCAR_TRACK_INDICES
		_:
			return STREET_TRACK_INDICES

const NUM_RACING_MODES: int = 4

func set_racing_mode(mode: RacingMode) -> void:
	racing_mode = mode
	var car_indices := get_car_indices_for_mode()
	selected_car_index = car_indices[0]
	var track_indices := get_track_indices_for_mode()
	selected_track_index = track_indices[0]
