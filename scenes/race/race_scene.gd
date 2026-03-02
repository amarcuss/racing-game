extends Node3D

## Single-player race orchestrator: loads track, spawns car, manages camera and HUD.

var track_node: Node3D
var player_car: VehicleBody3D
var race_camera: Camera3D

# Debug HUD
var hud_layer: CanvasLayer
var lap_label: Label
var time_label: Label
var state_label: Label
var speed_label: Label
var best_lap_label: Label

func _ready() -> void:
	_load_track()
	_spawn_player()
	_setup_camera()
	_setup_debug_hud()

	var track_checkpoints: int = track_node.get_num_checkpoints()
	RaceManager.setup_race(3, track_checkpoints)
	RaceManager.register_car(player_car)

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

	# Set transform BEFORE adding to tree — VehicleBody3D ignores transform changes after
	var spawn: Transform3D = track_node.get_spawn_transform(0)
	player_car.transform = spawn
	add_child(player_car)

	# Add player controller
	var controller := Node.new()
	controller.name = "PlayerController"
	controller.set_script(preload("res://cars/player_car_controller.gd"))
	player_car.add_child(controller)

func _setup_camera() -> void:
	race_camera = Camera3D.new()
	race_camera.name = "RaceCamera"
	race_camera.set_script(preload("res://scenes/race/race_camera.gd"))
	add_child(race_camera)
	race_camera.set_target(player_car)

func _setup_debug_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "DebugHUD"
	add_child(hud_layer)

	lap_label = Label.new()
	lap_label.position = Vector2(30, 20)
	lap_label.add_theme_font_size_override("font_size", 36)
	lap_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hud_layer.add_child(lap_label)

	time_label = Label.new()
	time_label.position = Vector2(30, 65)
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	hud_layer.add_child(time_label)

	best_lap_label = Label.new()
	best_lap_label.position = Vector2(30, 100)
	best_lap_label.add_theme_font_size_override("font_size", 22)
	best_lap_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	hud_layer.add_child(best_lap_label)

	state_label = Label.new()
	state_label.position = Vector2(860, 400)
	state_label.add_theme_font_size_override("font_size", 120)
	state_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hud_layer.add_child(state_label)

	speed_label = Label.new()
	speed_label.position = Vector2(1650, 920)
	speed_label.add_theme_font_size_override("font_size", 56)
	speed_label.add_theme_color_override("font_color", Color(1, 0.42, 0.1))
	hud_layer.add_child(speed_label)

func _process(_delta: float) -> void:
	_update_debug_hud()

func _update_debug_hud() -> void:
	if not player_car:
		return

	# Lap display
	var completed: int = RaceManager.get_car_lap(player_car)
	var current_lap: int = mini(completed + 1, RaceManager.total_laps)
	lap_label.text = "LAP %d / %d" % [current_lap, RaceManager.total_laps]

	# Race time
	var mins: int = int(RaceManager.race_time) / 60
	var secs: float = fmod(RaceManager.race_time, 60.0)
	time_label.text = "%02d:%06.3f" % [mins, secs]

	# Best lap
	var best: float = RaceManager.get_car_best_lap_time(player_car)
	if best > 0.0:
		var best_mins: int = int(best) / 60
		var best_secs: float = fmod(best, 60.0)
		best_lap_label.text = "BEST: %02d:%06.3f" % [best_mins, best_secs]
	else:
		best_lap_label.text = ""

	# Speed
	speed_label.text = "%d km/h" % int(player_car.current_speed_kph)

	# State overlay
	match RaceManager.state:
		RaceManager.RaceState.COUNTDOWN:
			if RaceManager.countdown_current > 0:
				state_label.text = str(RaceManager.countdown_current)
				state_label.add_theme_color_override("font_color", Color(1, 1, 1))
			else:
				state_label.text = "GO!"
				state_label.add_theme_color_override("font_color", Color(0.5, 1, 0))
		RaceManager.RaceState.FINISHED:
			state_label.text = "FINISHED!"
			state_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
		_:
			state_label.text = ""
