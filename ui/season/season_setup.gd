extends Node

## Season setup: pick your team, view calendar, start season. Works for any racing mode.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")
const GOLD := Color("FFD700")

var ui_layer: CanvasLayer
var team_name_label: Label
var team_color_rect: ColorRect
var car_preview_pivot: Node3D
var sub_viewport: SubViewport
var calendar_container: VBoxContainer
var selected_team: Array = [0]  # index into car_indices for current mode
var car_indices: Array[int] = []

func _ready() -> void:
	car_indices = GameManager.get_car_indices_for_mode()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_ui()
	_update_team_display()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	ui_layer.add_child(bg)

	var season_title: String = GameManager.SEASON_TITLES.get(int(GameManager.racing_mode), "CHAMPIONSHIP")

	# Title
	var title := Label.new()
	title.text = season_title
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(1920, 60)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(835, 95)
	accent.size = Vector2(250, 3)
	bg.add_child(accent)

	# Left panel: Team selector
	var team_panel := ColorRect.new()
	team_panel.color = BG_MID
	team_panel.position = Vector2(60, 120)
	team_panel.size = Vector2(580, 500)
	bg.add_child(team_panel)

	var team_title := Label.new()
	if GameManager.racing_mode == GameManager.RacingMode.F1:
		team_title.text = "SELECT YOUR TEAM"
	else:
		team_title.text = "SELECT YOUR CAR"
	team_title.add_theme_font_size_override("font_size", 28)
	team_title.add_theme_color_override("font_color", TEXT_PRIMARY)
	team_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_title.position = Vector2(0, 20)
	team_title.size = Vector2(580, 40)
	team_panel.add_child(team_title)

	# Team selector arrows + name
	var team_row := HBoxContainer.new()
	team_row.position = Vector2(40, 80)
	team_row.size = Vector2(500, 60)
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 20)
	team_panel.add_child(team_row)

	var left_btn := _create_small_button("<")
	team_row.add_child(left_btn)
	left_btn.pressed.connect(func():
		selected_team[0] = (selected_team[0] - 1) % car_indices.size()
		if selected_team[0] < 0:
			selected_team[0] = car_indices.size() - 1
		_update_team_display()
	)

	team_name_label = Label.new()
	team_name_label.add_theme_font_size_override("font_size", 24)
	team_name_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	team_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_name_label.custom_minimum_size = Vector2(340, 60)
	team_row.add_child(team_name_label)

	var right_btn := _create_small_button(">")
	team_row.add_child(right_btn)
	right_btn.pressed.connect(func():
		selected_team[0] = (selected_team[0] + 1) % car_indices.size()
		_update_team_display()
	)

	# Team color indicator
	team_color_rect = ColorRect.new()
	team_color_rect.position = Vector2(190, 160)
	team_color_rect.size = Vector2(200, 8)
	team_panel.add_child(team_color_rect)

	# Car preview
	var preview_container := SubViewportContainer.new()
	preview_container.position = Vector2(90, 180)
	preview_container.size = Vector2(400, 300)
	preview_container.stretch = true
	team_panel.add_child(preview_container)

	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(400, 300)
	sub_viewport.own_world_3d = true
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(sub_viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 2.0, 4.0)
	var dir: Vector3 = (Vector3.ZERO - camera.position).normalized()
	var right_vec: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right_vec.cross(dir).normalized()
	camera.transform.basis = Basis(right_vec, up, -dir)
	camera.fov = 40.0
	camera.current = true
	sub_viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	sub_viewport.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20, -60, 0)
	fill_light.light_energy = 0.4
	sub_viewport.add_child(fill_light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	sub_viewport.add_child(world_env)

	car_preview_pivot = Node3D.new()
	sub_viewport.add_child(car_preview_pivot)

	# Right panel: Calendar
	var calendar: Array = _get_calendar()
	var cal_panel := ColorRect.new()
	cal_panel.color = BG_MID
	cal_panel.position = Vector2(680, 120)
	cal_panel.size = Vector2(1180, 500)
	bg.add_child(cal_panel)

	var cal_title := Label.new()
	cal_title.text = "%d-RACE CALENDAR" % calendar.size()
	cal_title.add_theme_font_size_override("font_size", 28)
	cal_title.add_theme_color_override("font_color", TEXT_PRIMARY)
	cal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cal_title.position = Vector2(0, 20)
	cal_title.size = Vector2(1180, 40)
	cal_panel.add_child(cal_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 70)
	scroll.size = Vector2(1140, 410)
	cal_panel.add_child(scroll)

	calendar_container = VBoxContainer.new()
	calendar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_container.add_theme_constant_override("separation", 4)
	scroll.add_child(calendar_container)

	for i in range(calendar.size()):
		var round_data: Dictionary = calendar[i]
		var track_data: Resource = GameManager.get_track_data(round_data.track_index)
		var track_name: String = track_data.track_name if track_data else "Unknown"

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		calendar_container.add_child(row)

		var round_label := Label.new()
		round_label.text = "R%02d" % (i + 1)
		round_label.add_theme_font_size_override("font_size", 18)
		round_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
		round_label.custom_minimum_size = Vector2(50, 24)
		row.add_child(round_label)

		var name_label := Label.new()
		name_label.text = round_data.name
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
		name_label.custom_minimum_size = Vector2(380, 24)
		row.add_child(name_label)

		var track_label := Label.new()
		track_label.text = track_name
		track_label.add_theme_font_size_override("font_size", 18)
		track_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		track_label.custom_minimum_size = Vector2(200, 24)
		row.add_child(track_label)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.position = Vector2(0, 680)
	btn_box.size = Vector2(1920, 60)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 30)
	bg.add_child(btn_box)

	var back_btn := _create_button("BACK", SURFACE)
	btn_box.add_child(back_btn)
	back_btn.pressed.connect(func():
		GameManager.transition_to_scene("res://scenes/main.tscn")
	)

	var start_btn := _create_button("START SEASON", PRIMARY_ACCENT)
	btn_box.add_child(start_btn)
	start_btn.pressed.connect(func():
		var car_idx: int = car_indices[selected_team[0]]
		GameManager.start_season(car_idx)
	)

func _get_calendar() -> Array:
	match GameManager.racing_mode:
		GameManager.RacingMode.STREET: return GameManager.STREET_CALENDAR
		GameManager.RacingMode.F1: return GameManager.F1_CALENDAR
		GameManager.RacingMode.BAJA: return GameManager.BAJA_CALENDAR
		GameManager.RacingMode.NASCAR: return GameManager.NASCAR_CALENDAR
		_: return GameManager.F1_CALENDAR

func _update_team_display() -> void:
	var car_idx: int = car_indices[selected_team[0]]
	var car_data: Resource = GameManager.get_car_data(car_idx)
	var team_name: String = GameManager.get_team_name(car_idx)
	team_name_label.text = team_name
	if car_data:
		team_color_rect.color = car_data.body_color
	_build_car_preview(car_idx)

func _build_car_preview(car_index: int) -> void:
	for child in car_preview_pivot.get_children():
		child.queue_free()

	var car_data: Resource = GameManager.get_car_data(car_index)
	if not car_data:
		return

	var body_mesh := Node3D.new()
	body_mesh.name = "BodyMesh"
	car_preview_pivot.add_child(body_mesh)

	var wheel_positions: Array[Vector3] = [
		Vector3(-0.8, 0.1, -1.3),
		Vector3(0.8, 0.1, -1.3),
		Vector3(-0.8, 0.1, 1.3),
		Vector3(0.8, 0.1, 1.3),
	]
	var wheels: Array = []
	for pos in wheel_positions:
		var w := Node3D.new()
		w.position = pos
		car_preview_pivot.add_child(w)
		wheels.append(w)

	# Load correct mesh script for car tier
	var mesh_script: GDScript
	match car_data.tier:
		2: mesh_script = load("res://cars/car_meshes/coupe_mesh.gd")
		3: mesh_script = load("res://cars/car_meshes/muscle_mesh.gd")
		4: mesh_script = load("res://cars/car_meshes/f1_mesh.gd")
		7: mesh_script = load("res://cars/car_meshes/buggy_mesh.gd")
		8: mesh_script = load("res://cars/car_meshes/trophy_truck_mesh.gd")
		9: mesh_script = load("res://cars/car_meshes/stock_car_mesh.gd")
		_: mesh_script = load("res://cars/car_meshes/sedan_mesh.gd")
	mesh_script.build(body_mesh, car_data, wheels)

func _process(delta: float) -> void:
	if car_preview_pivot:
		car_preview_pivot.rotate_y(delta * 0.5)

func _create_small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(50, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = SURFACE.lightened(0.2)
	sb_h.set_corner_radius_all(6)
	sb_h.content_margin_left = 10
	sb_h.content_margin_right = 10
	sb_h.content_margin_top = 8
	sb_h.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	return btn

func _create_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 56)
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = bg_color
	sb_normal.set_corner_radius_all(8)
	sb_normal.content_margin_left = 24
	sb_normal.content_margin_right = 24
	sb_normal.content_margin_top = 14
	sb_normal.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", sb_normal)
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = bg_color.lightened(0.15)
	sb_hover.set_corner_radius_all(8)
	sb_hover.content_margin_left = 24
	sb_hover.content_margin_right = 24
	sb_hover.content_margin_top = 14
	sb_hover.content_margin_bottom = 14
	sb_hover.border_width_left = 4
	sb_hover.border_color = PRIMARY_ACCENT
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = bg_color.darkened(0.1)
	sb_pressed.set_corner_radius_all(8)
	sb_pressed.content_margin_left = 24
	sb_pressed.content_margin_right = 24
	sb_pressed.content_margin_top = 14
	sb_pressed.content_margin_bottom = 14
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	return btn
