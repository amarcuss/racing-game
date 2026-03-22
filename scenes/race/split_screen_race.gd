extends Node3D

## Split-screen race orchestrator: two SubViewports sharing one World3D,
## two player cars with independent cameras and HUDs.

var track_node: Node3D
var player_cars: Array = []  # [p1_car, p2_car]
var ai_cars: Array = []
var cameras: Array = []  # [cam1, cam2]
var viewports: Array = []  # [subviewport1, subviewport2]

# UI
var player_huds: Array = []  # [hud1, hud2]
var countdown_overlay: CanvasLayer
var results_screen: CanvasLayer
var pause_menu: CanvasLayer
var is_paused: bool = false

var players_results_shown: Array[bool] = [false, false]

func _ready() -> void:
	Engine.time_scale = 1.0
	_load_track()
	_setup_viewports()
	_spawn_players()
	_spawn_ai_cars()
	_setup_cameras()
	_wire_collision_shake()
	_setup_ui()

	var track_checkpoints: int = track_node.get_num_checkpoints()
	var track_data: Resource = GameManager.get_track_data(GameManager.selected_track_index)
	var is_p2p: bool = track_data.is_point_to_point if track_data else false
	RaceManager.setup_race(GameManager.race_laps, track_checkpoints, is_p2p)

	if track_node.has_method("get_ai_path") and track_node.has_method("get_perimeter"):
		RaceManager.set_track_path(track_node.get_ai_path(), track_node.get_perimeter())

	if not is_p2p:
		var cp0: Node = track_node.find_child("Checkpoint0")
		if cp0:
			RaceManager.set_start_finish_position(cp0.global_position)

	for car in player_cars:
		RaceManager.register_car(car)
	for ai_car in ai_cars:
		RaceManager.register_car(ai_car)

	RaceManager.race_finished.connect(_on_race_finished)
	RaceManager.race_state_changed.connect(_on_race_state_changed)

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

func _setup_viewports() -> void:
	# Create an HBoxContainer with two SubViewportContainers for left/right split
	var hbox := HBoxContainer.new()
	hbox.name = "ViewportSplit"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	for i in range(2):
		var svc := SubViewportContainer.new()
		svc.name = "ViewportContainer%d" % (i + 1)
		svc.stretch = true
		svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(svc)

		var sv := SubViewport.new()
		sv.name = "SubViewport%d" % (i + 1)
		sv.handle_input_locally = false
		sv.size = Vector2i(960, 1080)
		svc.add_child(sv)

		viewports.append(sv)

	# Share the root world so both viewports see the same 3D scene
	# Defer to ensure root viewport's world is ready
	call_deferred("_share_world")

func _share_world() -> void:
	var root_world: World3D = get_viewport().world_3d
	for sv in viewports:
		sv.world_3d = root_world

func _spawn_players() -> void:
	var car_scene: PackedScene = preload("res://cars/car_base.tscn")

	# Player 1
	var p1_car: VehicleBody3D = car_scene.instantiate()
	p1_car.car_data = GameManager.get_selected_car_data()
	p1_car.car_index = GameManager.selected_car_index
	p1_car.driver_slot = 1
	if track_node.has_method("get_ai_path"):
		p1_car.track_path = track_node.get_ai_path()
	var spawn0: Transform3D = track_node.get_spawn_transform(0)
	p1_car.transform = spawn0
	add_child(p1_car)

	var ctrl1 := Node.new()
	ctrl1.name = "PlayerController"
	ctrl1.set_script(preload("res://cars/player_car_controller.gd"))
	ctrl1.player_index = 0
	p1_car.add_child(ctrl1)
	player_cars.append(p1_car)

	# Player 2
	var p2_car: VehicleBody3D = car_scene.instantiate()
	p2_car.car_data = GameManager.get_p2_car_data()
	p2_car.car_index = GameManager.p2_car_index
	p2_car.driver_slot = 1
	if track_node.has_method("get_ai_path"):
		p2_car.track_path = track_node.get_ai_path()
	var spawn1: Transform3D = track_node.get_spawn_transform(1)
	p2_car.transform = spawn1
	add_child(p2_car)

	var ctrl2 := Node.new()
	ctrl2.name = "PlayerController"
	ctrl2.set_script(preload("res://cars/player_car_controller.gd"))
	ctrl2.player_index = 1
	p2_car.add_child(ctrl2)
	player_cars.append(p2_car)

func _spawn_ai_cars() -> void:
	var car_scene: PackedScene = preload("res://cars/car_base.tscn")
	var ai_path: Path3D = null
	var track_perim: float = 0.0

	if track_node.has_method("get_ai_path"):
		ai_path = track_node.get_ai_path()
	if track_node.has_method("get_perimeter"):
		track_perim = track_node.get_perimeter()

	var base_diff: int = GameManager.ai_difficulty
	var ai_total: int = GameManager.ai_count
	var difficulties: Array = []
	for i in range(ai_total):
		var d: int = base_diff + (randi() % 3) - 1
		difficulties.append(clampi(d, 0, 2))
	difficulties.shuffle()

	var ai_car_indices: Array[int] = GameManager.get_car_indices_for_mode()

	for i in range(ai_total):
		var ai_car: VehicleBody3D = car_scene.instantiate()
		var car_index: int = ai_car_indices[i % ai_car_indices.size()]
		ai_car.car_data = GameManager.get_car_data(car_index)
		ai_car.car_index = car_index
		ai_car.driver_slot = 1
		if ai_path:
			ai_car.track_path = ai_path

		# Spawn at positions after the two player spots
		var spawn: Transform3D = track_node.get_spawn_transform(i + 2)
		ai_car.transform = spawn
		add_child(ai_car)

		var controller := Node.new()
		controller.name = "AIController"
		controller.set_script(load("res://cars/ai_car_controller.gd"))
		controller.difficulty = difficulties[i]
		ai_car.add_child(controller)

		if ai_path:
			controller.setup(ai_path, track_perim)

		if RaceManager.is_point_to_point:
			controller.open_path = true

		ai_cars.append(ai_car)

func _setup_cameras() -> void:
	for i in range(2):
		var cam := Camera3D.new()
		cam.name = "RaceCamera%d" % (i + 1)
		cam.set_script(preload("res://scenes/race/race_camera.gd"))
		cam.player_index = i
		viewports[i].add_child(cam)
		cam.set_target(player_cars[i])
		cameras.append(cam)

func _setup_ui() -> void:
	# Per-player HUDs positioned in left/right halves of the screen
	for i in range(2):
		var hud := CanvasLayer.new()
		hud.name = "RaceHUD%d" % (i + 1)
		hud.set_script(preload("res://ui/hud/race_hud.gd"))
		hud.configure_layout(i * 960.0, 960.0)
		add_child(hud)
		hud.set_player_car(player_cars[i])
		player_huds.append(hud)

	# Shared countdown overlay
	countdown_overlay = CanvasLayer.new()
	countdown_overlay.name = "CountdownOverlay"
	countdown_overlay.set_script(preload("res://scenes/race/countdown_overlay.gd"))
	add_child(countdown_overlay)

	# Shared results screen
	results_screen = CanvasLayer.new()
	results_screen.name = "ResultsScreen"
	results_screen.set_script(preload("res://scenes/race/results_screen.gd"))
	add_child(results_screen)

	# Shared pause menu
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

func _on_race_finished(car: Node) -> void:
	# Show results when P1 finishes (P1 is the "main" player for results/saving)
	if car == player_cars[0]:
		_show_results_for_player(0)
	elif car == player_cars[1]:
		_show_results_for_player(1)

func _on_race_state_changed(new_state: int) -> void:
	if new_state == RaceManager.RaceState.FINISHED:
		# Show results for any player that hasn't been shown yet
		if not players_results_shown[0]:
			_show_results_for_player(0)

func _wire_collision_shake() -> void:
	for i in range(2):
		var car: VehicleBody3D = player_cars[i]
		var cam: Camera3D = cameras[i]
		car.collision_occurred.connect(func(speed: float):
			var intensity: float = clampf(speed / 200.0, 0.05, 0.5)
			cam.apply_shake(intensity)
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

func _show_results_for_player(player_idx: int) -> void:
	if players_results_shown[player_idx]:
		return
	players_results_shown[player_idx] = true

	# Disable controller so car coasts
	var car: VehicleBody3D = player_cars[player_idx]
	var controller: Node = car.get_node_or_null("PlayerController")
	if controller:
		controller.set_physics_process(false)
	car.set_inputs(0.0, 0.0, 0.0, false)

	# Show shared results when P1 finishes (or on timeout)
	if player_idx == 0:
		_start_slow_motion()
		var finish_pos: int = RaceManager.get_finish_position(car)
		results_screen.show_results(car, finish_pos)
