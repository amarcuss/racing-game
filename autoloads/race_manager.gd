extends Node

## Race state machine: manages countdown, checkpoint validation, lap counting,
## timing, position tracking, and multi-car finish handling.

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

# Position tracking
var car_positions: Dictionary = {}
var car_finished: Dictionary = {}
var finish_order: Array = []
var finish_timeout: float = 0.0
var finish_timeout_active: bool = false
const FINISH_TIMEOUT_DURATION: float = 30.0
var position_update_timer: float = 0.0

# Track path for progress calculation
var track_path: Path3D
var track_perimeter: float = 0.0
var start_finish_frac: float = 0.0

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
	car_positions.clear()
	car_finished.clear()
	finish_order.clear()
	finish_timeout = 0.0
	finish_timeout_active = false
	position_update_timer = 0.0
	track_path = null
	track_perimeter = 0.0
	start_finish_frac = 0.0
	state = RaceState.PRE_RACE
	race_state_changed.emit(RaceState.PRE_RACE)

func set_track_path(path: Path3D, perim: float) -> void:
	track_path = path
	track_perimeter = perim
	start_finish_frac = 0.0

func set_start_finish_position(pos: Vector3) -> void:
	## Compute start/finish fraction from a world position (e.g. checkpoint 0).
	if track_path and track_path.curve and track_path.curve.get_baked_length() > 0.0:
		var curve_len: float = track_path.curve.get_baked_length()
		var offset: float = track_path.curve.get_closest_offset(pos)
		start_finish_frac = offset / curve_len

func register_car(car: Node) -> void:
	registered_cars.append(car)
	car_laps[car] = 0
	car_started[car] = false
	car_lap_times[car] = []
	car_current_lap_start[car] = 0.0
	car_finished[car] = false
	car_positions[car] = registered_cars.size()
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
			position_update_timer += delta
			if position_update_timer >= 0.5:
				position_update_timer = 0.0
				_update_positions()
			if finish_timeout_active:
				finish_timeout += delta
				if finish_timeout >= FINISH_TIMEOUT_DURATION:
					_finish_race_timeout()

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
	if car_finished.get(car, false):
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
		_car_finish(car)

func _car_finish(car: Node) -> void:
	car_finished[car] = true
	finish_order.append(car)
	car_positions[car] = finish_order.size()
	race_finished.emit(car)

	# Start timeout after first finisher
	if not finish_timeout_active:
		finish_timeout_active = true
		finish_timeout = 0.0

	# Check if all cars finished
	var all_done: bool = true
	for c in registered_cars:
		if not car_finished.get(c, false):
			all_done = false
			break
	if all_done:
		state = RaceState.FINISHED
		race_state_changed.emit(RaceState.FINISHED)

func _finish_race_timeout() -> void:
	# Assign remaining positions to unfinished cars based on current progress
	_update_positions()
	state = RaceState.FINISHED
	race_state_changed.emit(RaceState.FINISHED)

func _update_positions() -> void:
	if registered_cars.is_empty():
		return

	# Build progress scores for unfinished cars
	var progress_list: Array = []
	for car in registered_cars:
		if car_finished.get(car, false):
			continue
		var laps: int = car_laps.get(car, 0)
		var cp_count: int = _count_checkpoints_hit(car)
		var track_frac: float = _get_track_fraction(car)
		var score: float = float(laps) * 1000.0 + float(cp_count) * 100.0 + track_frac * 10.0
		progress_list.append({"car": car, "score": score})

	# Sort descending by score
	progress_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score
	)

	# Assign positions: finished cars keep their finish_order positions
	var pos: int = finish_order.size() + 1
	for entry in progress_list:
		car_positions[entry.car] = pos
		pos += 1

func _count_checkpoints_hit(car: Node) -> int:
	var flags: Array = car_checkpoints.get(car, [])
	var count: int = 0
	for hit in flags:
		if hit:
			count += 1
	return count

func _get_track_fraction(car: Node) -> float:
	if not track_path or not track_path.curve or track_perimeter <= 0.0:
		return 0.0
	var curve_len: float = track_path.curve.get_baked_length()
	var offset: float = track_path.curve.get_closest_offset(car.global_position)
	# Shift so start/finish line becomes fraction 0.0
	# Prevents position jumps at the curve origin wrap point
	var shifted: float = fposmod((offset / curve_len) - start_finish_frac, 1.0)
	return shifted

func get_car_position(car: Node) -> int:
	return car_positions.get(car, 1)

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

func get_finish_position(car: Node) -> int:
	var idx: int = finish_order.find(car)
	if idx >= 0:
		return idx + 1
	return car_positions.get(car, registered_cars.size())

func reset() -> void:
	state = RaceState.IDLE
	car_laps.clear()
	car_checkpoints.clear()
	car_started.clear()
	car_lap_times.clear()
	car_current_lap_start.clear()
	registered_cars.clear()
	car_positions.clear()
	car_finished.clear()
	finish_order.clear()
	finish_timeout = 0.0
	finish_timeout_active = false
	position_update_timer = 0.0
	track_path = null
	track_perimeter = 0.0
	race_state_changed.emit(RaceState.IDLE)
