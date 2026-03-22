extends Node3D

## Race orchestrator: loads track, spawns player + AI cars, manages camera and UI.

var track_node: Node3D
var player_car: VehicleBody3D
var ai_cars: Array = []
var race_camera: Camera3D

# UI
var race_hud: CanvasLayer
var countdown_overlay: CanvasLayer
var results_screen: CanvasLayer
var pause_menu: CanvasLayer
var is_paused: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0
	_load_track()
	_spawn_player()
	_spawn_ai_cars()
	_setup_camera()
	_wire_collision_shake()
	_setup_ui()

	var track_checkpoints: int = track_node.get_num_checkpoints()
	var track_data: Resource = GameManager.get_track_data(GameManager.selected_track_index)
	var is_p2p: bool = track_data.is_point_to_point if track_data else false
	RaceManager.setup_race(GameManager.race_laps, track_checkpoints, is_p2p)

	# Wire track path for position tracking
	if track_node.has_method("get_ai_path") and track_node.has_method("get_perimeter"):
		RaceManager.set_track_path(track_node.get_ai_path(), track_node.get_perimeter())

	# Set start/finish position for accurate position tracking (circuit only)
	if not is_p2p:
		var cp0: Node = track_node.find_child("Checkpoint0")
		if cp0:
			RaceManager.set_start_finish_position(cp0.global_position)

	RaceManager.register_car(player_car)
	for ai_car in ai_cars:
		RaceManager.register_car(ai_car)

	# Connect race signals
	RaceManager.race_finished.connect(_on_race_finished)
	RaceManager.race_state_changed.connect(_on_race_state_changed)

	# Brief delay then start countdown
	await get_tree().create_timer(0.5).timeout
	RaceManager.start_countdown()

func _load_track() -> void:
	var track_data: Resource = GameManager.get_track_data(GameManager.selected_track_index)
	var scene_path: String = "res://tracks/track_scenes/oval_speedway.tscn"
	if track_data and track_data.scene_path != "":
		scene_path = track_data.scene_path
	var track_scene: PackedScene = load(scene_path)
	track_node = track_scene.instantiate()
	add_child(track_node)

func _spawn_player() -> void:
	var car_scene: PackedScene = preload("res://cars/car_base.tscn")
	player_car = car_scene.instantiate()
	player_car.car_data = GameManager.get_selected_car_data()
	player_car.car_index = GameManager.selected_car_index
	player_car.driver_slot = 1
	if track_node.has_method("get_ai_path"):
		player_car.track_path = track_node.get_ai_path()

	# Set transform BEFORE adding to tree — VehicleBody3D ignores transform changes after
	var spawn: Transform3D = track_node.get_spawn_transform(0)
	player_car.transform = spawn
	add_child(player_car)

	# Add player controller
	var controller := Node.new()
	controller.name = "PlayerController"
	controller.set_script(preload("res://cars/player_car_controller.gd"))
	player_car.add_child(controller)

func _spawn_ai_cars() -> void:
	var car_scene: PackedScene = preload("res://cars/car_base.tscn")
	var ai_path: Path3D = null
	var track_perim: float = 0.0

	if track_node.has_method("get_ai_path"):
		ai_path = track_node.get_ai_path()
	if track_node.has_method("get_perimeter"):
		track_perim = track_node.get_perimeter()

	# Build difficulty mix from GameManager.ai_difficulty with ±1 variation
	var base_diff: int = GameManager.ai_difficulty
	var ai_total: int = GameManager.ai_count
	var difficulties: Array = []
	for i in range(ai_total):
		var d: int = base_diff + (randi() % 3) - 1  # -1, 0, or +1
		difficulties.append(clampi(d, 0, 2))
	difficulties.shuffle()

	var ai_car_indices: Array[int] = GameManager.get_car_indices_for_mode()

	# Season mode AI list
	var season_ai_list: Array = []  # Array of {car_index, driver_slot}
	if GameManager.season_active:
		var season_car_indices: Array[int] = GameManager.get_season_car_indices()
		var rival_indices: Array = []
		for ci in season_car_indices:
			if ci != GameManager.season_player_car_index:
				rival_indices.append(ci)
		rival_indices.shuffle()

		if GameManager.is_team_season():
			# Team mode: 2 cars per team, interleaved so teammates aren't adjacent
			for ci in rival_indices:
				season_ai_list.append({"car_index": ci, "driver_slot": 1})
			var d2_list: Array = []
			d2_list.append({"car_index": GameManager.season_player_car_index, "driver_slot": 2})
			for ci in rival_indices:
				d2_list.append({"car_index": ci, "driver_slot": 2})
			d2_list.shuffle()
			season_ai_list.append_array(d2_list)
		else:
			# Individual mode: 1 car per entry
			for ci in rival_indices:
				season_ai_list.append({"car_index": ci, "driver_slot": 1})

	for i in range(ai_total):
		var ai_car: VehicleBody3D = car_scene.instantiate()

		var car_index: int
		var driver_slot: int = 1
		if GameManager.season_active and i < season_ai_list.size():
			car_index = season_ai_list[i].car_index
			driver_slot = season_ai_list[i].driver_slot
		else:
			# Cycle through available cars evenly (ensures ~equal distribution)
			car_index = ai_car_indices[i % ai_car_indices.size()]
		ai_car.car_data = GameManager.get_car_data(car_index)
		ai_car.car_index = car_index
		ai_car.driver_slot = driver_slot
		if ai_path:
			ai_car.track_path = ai_path

		# Set transform BEFORE add_child
		var spawn: Transform3D = track_node.get_spawn_transform(i + 1)
		ai_car.transform = spawn
		add_child(ai_car)

		# Add AI controller
		var controller := Node.new()
		controller.name = "AIController"
		controller.set_script(load("res://cars/ai_car_controller.gd"))
		controller.difficulty = difficulties[i]
		ai_car.add_child(controller)

		# Setup path after adding to tree
		if ai_path:
			controller.setup(ai_path, track_perim)

		# Set open path for point-to-point tracks
		if RaceManager.is_point_to_point:
			controller.open_path = true

		ai_cars.append(ai_car)

func _setup_camera() -> void:
	race_camera = Camera3D.new()
	race_camera.name = "RaceCamera"
	race_camera.set_script(preload("res://scenes/race/race_camera.gd"))
	add_child(race_camera)
	race_camera.set_target(player_car)

func _setup_ui() -> void:
	# Race HUD
	race_hud = CanvasLayer.new()
	race_hud.name = "RaceHUD"
	race_hud.set_script(preload("res://ui/hud/race_hud.gd"))
	add_child(race_hud)
	race_hud.set_player_car(player_car)

	# Countdown overlay
	countdown_overlay = CanvasLayer.new()
	countdown_overlay.name = "CountdownOverlay"
	countdown_overlay.set_script(preload("res://scenes/race/countdown_overlay.gd"))
	add_child(countdown_overlay)

	# Results screen
	results_screen = CanvasLayer.new()
	results_screen.name = "ResultsScreen"
	results_screen.set_script(preload("res://scenes/race/results_screen.gd"))
	add_child(results_screen)

	# Pause menu
	pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_script(preload("res://ui/pause/pause_menu.gd"))
	add_child(pause_menu)
	pause_menu.resumed.connect(func(): is_paused = false)

func _process(_delta: float) -> void:
	if InputManager.is_pause_pressed():
		_toggle_pause()

func _toggle_pause() -> void:
	if RaceManager.state == RaceManager.RaceState.FINISHED:
		return
	if RaceManager.state == RaceManager.RaceState.COUNTDOWN:
		return
	if is_paused:
		return
	pause_menu.show_pause()
	is_paused = true

var player_results_shown: bool = false

func _on_race_finished(car: Node) -> void:
	if car != player_car:
		return
	_show_player_results()

func _on_race_state_changed(new_state: int) -> void:
	if new_state == RaceManager.RaceState.FINISHED:
		# Record season positions if not already done
		if GameManager.season_active:
			_record_season_final_positions()
		# Handle timeout — show results even if player didn't finish
		if not player_results_shown:
			_show_player_results()

var season_recorded: bool = false

func _record_season_final_positions() -> void:
	if season_recorded:
		return
	season_recorded = true
	# Find fastest lap car
	var best_lap_time: float = INF
	var best_lap_car: Node = null
	for car_node in RaceManager.registered_cars:
		var lt: float = RaceManager.get_car_best_lap_time(car_node)
		if lt > 0.0 and lt < best_lap_time:
			best_lap_time = lt
			best_lap_car = car_node
	var finish_positions: Array = []
	for car_node in RaceManager.registered_cars:
		var pos: int = RaceManager.get_finish_position(car_node)
		var ci: int = car_node.car_index
		var slot: int = car_node.driver_slot
		if ci >= 0:
			var entry: Dictionary = {"car_index": ci, "driver_slot": slot, "position": pos}
			if car_node == best_lap_car:
				entry["fastest_lap"] = true
			finish_positions.append(entry)
	GameManager.record_season_result(finish_positions)

func _wire_collision_shake() -> void:
	player_car.collision_occurred.connect(func(speed: float):
		var intensity: float = clampf(speed / 200.0, 0.05, 0.5)
		race_camera.apply_shake(intensity)
	)

func _start_slow_motion() -> void:
	Engine.time_scale = 0.3
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
		timer.queue_free()
	)
	timer.start()

func _show_player_results() -> void:
	if player_results_shown:
		return
	player_results_shown = true
	_start_slow_motion()
	var finish_pos: int = RaceManager.get_finish_position(player_car)
	results_screen.show_results(player_car, finish_pos)
	# Disable player controller so car coasts to stop
	var controller: Node = player_car.get_node_or_null("PlayerController")
	if controller:
		controller.set_physics_process(false)
	player_car.set_inputs(0.0, 0.0, 0.0, false)
	# Season: wait a moment for other cars to settle, then record positions
	if GameManager.season_active and not season_recorded:
		var record_timer := Timer.new()
		record_timer.wait_time = 3.0
		record_timer.one_shot = true
		record_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(record_timer)
		record_timer.timeout.connect(func():
			RaceManager._update_positions()
			_record_season_final_positions()
			record_timer.queue_free()
		)
		record_timer.start()
