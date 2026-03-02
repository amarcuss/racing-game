extends Node

## Race state machine: manages countdown, checkpoint validation, lap counting, and timing.

enum RaceState { IDLE, PRE_RACE, COUNTDOWN, RACING, FINISHED }

signal race_state_changed(new_state: int)
signal lap_completed(car: Node, lap: int)
signal race_finished(car: Node)
signal countdown_tick(number: int)

var state: RaceState = RaceState.IDLE
var total_laps: int = 3
var num_checkpoints: int = 4
var race_time: float = 0.0
var countdown_timer: float = 0.0
var countdown_current: int = 3

# Per-car tracking
var car_laps: Dictionary = {}
var car_checkpoints: Dictionary = {}
var car_started: Dictionary = {}
var car_lap_times: Dictionary = {}
var car_current_lap_start: Dictionary = {}
var registered_cars: Array = []

func setup_race(laps: int, checkpoints: int) -> void:
	total_laps = laps
	num_checkpoints = checkpoints
	race_time = 0.0
	countdown_timer = 0.0
	countdown_current = 3
	car_laps.clear()
	car_checkpoints.clear()
	car_started.clear()
	car_lap_times.clear()
	car_current_lap_start.clear()
	registered_cars.clear()
	state = RaceState.PRE_RACE
	race_state_changed.emit(RaceState.PRE_RACE)

func register_car(car: Node) -> void:
	registered_cars.append(car)
	car_laps[car] = 0
	car_started[car] = false
	car_lap_times[car] = []
	car_current_lap_start[car] = 0.0
	# Intermediate checkpoints (indices 1 through num_checkpoints-1)
	var cp_flags: Array[bool] = []
	for i in range(num_checkpoints - 1):
		cp_flags.append(false)
	car_checkpoints[car] = cp_flags

func start_countdown() -> void:
	state = RaceState.COUNTDOWN
	countdown_timer = 0.0
	countdown_current = 3
	countdown_tick.emit(3)
	race_state_changed.emit(RaceState.COUNTDOWN)

func _physics_process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.RACING:
			race_time += delta

func _process_countdown(delta: float) -> void:
	countdown_timer += delta
	if countdown_timer >= 1.0:
		countdown_timer -= 1.0
		countdown_current -= 1
		if countdown_current > 0:
			countdown_tick.emit(countdown_current)
		elif countdown_current == 0:
			countdown_tick.emit(0)
			state = RaceState.RACING
			race_time = 0.0
			for car in registered_cars:
				car_current_lap_start[car] = 0.0
			race_state_changed.emit(RaceState.RACING)

func checkpoint_hit(checkpoint_index: int, car: Node) -> void:
	if state != RaceState.RACING:
		return
	if car not in registered_cars:
		return

	if checkpoint_index == 0:
		_handle_start_finish(car)
	else:
		# Mark intermediate checkpoint as hit
		var idx: int = checkpoint_index - 1
		var flags: Array = car_checkpoints[car]
		if idx >= 0 and idx < flags.size():
			flags[idx] = true

func _handle_start_finish(car: Node) -> void:
	if not car_started.get(car, false):
		# First crossing — begin lap tracking
		car_started[car] = true
		car_current_lap_start[car] = race_time
		return

	# Check if all intermediate checkpoints were hit
	var flags: Array = car_checkpoints[car]
	for hit in flags:
		if not hit:
			return

	# Lap complete
	car_laps[car] += 1
	var lap_time: float = race_time - car_current_lap_start[car]
	car_lap_times[car].append(lap_time)
	car_current_lap_start[car] = race_time

	# Reset intermediate checkpoints
	for i in range(flags.size()):
		flags[i] = false

	lap_completed.emit(car, car_laps[car])

	if car_laps[car] >= total_laps:
		state = RaceState.FINISHED
		race_finished.emit(car)
		race_state_changed.emit(RaceState.FINISHED)

func get_car_lap(car: Node) -> int:
	return car_laps.get(car, 0)

func get_car_last_lap_time(car: Node) -> float:
	var times: Array = car_lap_times.get(car, [])
	if times.size() > 0:
		return times[-1]
	return 0.0

func get_car_best_lap_time(car: Node) -> float:
	var times: Array = car_lap_times.get(car, [])
	if times.is_empty():
		return 0.0
	var best: float = times[0]
	for t in times:
		if t < best:
			best = t
	return best

func reset() -> void:
	state = RaceState.IDLE
	car_laps.clear()
	car_checkpoints.clear()
	car_started.clear()
	car_lap_times.clear()
	car_current_lap_start.clear()
	registered_cars.clear()
	race_state_changed.emit(RaceState.IDLE)
