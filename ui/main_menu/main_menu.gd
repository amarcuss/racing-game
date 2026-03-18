extends CanvasLayer

## Main menu: title, 3D car preview, navigation buttons, credits display.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")
const GOLD := Color("FFD700")

var credits_label: Label
var car_pivot: Node3D
var sub_viewport: SubViewport
var btn_box: VBoxContainer
var mode_label: Label

const MODE_NAMES: Array[String] = ["STREET RACING", "F1", "BAJA 1000"]

func _ready() -> void:
	layer = 10
	_build_ui()
	_build_car_preview()

func _build_ui() -> void:
	# Full-screen background
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	add_child(bg)

	# Mode selector (top bar)
	var mode_box := HBoxContainer.new()
	mode_box.position = Vector2(0, 15)
	mode_box.size = Vector2(1920, 50)
	mode_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_box.add_theme_constant_override("separation", 20)
	bg.add_child(mode_box)

	var left_arrow := Button.new()
	left_arrow.text = "<"
	left_arrow.custom_minimum_size = Vector2(48, 44)
	left_arrow.add_theme_font_size_override("font_size", 28)
	left_arrow.add_theme_color_override("font_color", PRIMARY_ACCENT)
	var sb_arrow := StyleBoxFlat.new()
	sb_arrow.bg_color = SURFACE
	sb_arrow.set_corner_radius_all(6)
	left_arrow.add_theme_stylebox_override("normal", sb_arrow)
	var sb_arrow_hover := StyleBoxFlat.new()
	sb_arrow_hover.bg_color = SURFACE.lightened(0.15)
	sb_arrow_hover.set_corner_radius_all(6)
	left_arrow.add_theme_stylebox_override("hover", sb_arrow_hover)
	left_arrow.add_theme_stylebox_override("pressed", sb_arrow)
	mode_box.add_child(left_arrow)
	left_arrow.pressed.connect(_on_mode_prev)

	mode_label = Label.new()
	mode_label.text = MODE_NAMES[GameManager.racing_mode]
	mode_label.add_theme_font_size_override("font_size", 32)
	mode_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.custom_minimum_size = Vector2(280, 44)
	mode_box.add_child(mode_label)

	var right_arrow := Button.new()
	right_arrow.text = ">"
	right_arrow.custom_minimum_size = Vector2(48, 44)
	right_arrow.add_theme_font_size_override("font_size", 28)
	right_arrow.add_theme_color_override("font_color", PRIMARY_ACCENT)
	right_arrow.add_theme_stylebox_override("normal", sb_arrow)
	right_arrow.add_theme_stylebox_override("hover", sb_arrow_hover)
	right_arrow.add_theme_stylebox_override("pressed", sb_arrow)
	mode_box.add_child(right_arrow)
	right_arrow.pressed.connect(_on_mode_next)

	# Title: V E L O C I T Y
	var title := Label.new()
	title.text = "V E L O C I T Y"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 80)
	title.size = Vector2(1920, 100)
	bg.add_child(title)

	# Orange accent line under title
	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(810, 190)
	accent.size = Vector2(300, 3)
	bg.add_child(accent)

	# Car preview container (centered)
	var preview_container := SubViewportContainer.new()
	preview_container.position = Vector2(560, 210)
	preview_container.size = Vector2(800, 480)
	preview_container.stretch = true
	bg.add_child(preview_container)

	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(800, 480)
	sub_viewport.own_world_3d = true
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(sub_viewport)

	# Menu buttons (centered below car preview)
	btn_box = VBoxContainer.new()
	btn_box.position = Vector2(760, 700)
	btn_box.size = Vector2(400, 320)
	btn_box.add_theme_constant_override("separation", 16)
	bg.add_child(btn_box)

	var quick_race_btn := _create_button("QUICK RACE", PRIMARY_ACCENT)
	btn_box.add_child(quick_race_btn)
	quick_race_btn.pressed.connect(_on_quick_race)

	var garage_btn := _create_button("GARAGE", SURFACE)
	btn_box.add_child(garage_btn)
	garage_btn.pressed.connect(_on_garage)

	var settings_btn := _create_button("SETTINGS", SURFACE)
	btn_box.add_child(settings_btn)
	settings_btn.pressed.connect(_on_settings)

	var quit_btn := _create_button("QUIT", SURFACE)
	btn_box.add_child(quit_btn)
	quit_btn.pressed.connect(_on_quit)

	# Credits display (bottom-center)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 28)
	credits_label.add_theme_color_override("font_color", GOLD)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.position = Vector2(0, 1030)
	credits_label.size = Vector2(1920, 40)
	bg.add_child(credits_label)
	_update_credits_display()

	# Version (bottom-left)
	var version := Label.new()
	version.text = "v0.5"
	version.add_theme_font_size_override("font_size", 18)
	version.add_theme_color_override("font_color", TEXT_SECONDARY)
	version.position = Vector2(30, 1045)
	version.size = Vector2(100, 30)
	bg.add_child(version)

func _build_car_preview() -> void:
	if not sub_viewport:
		return

	# Camera
	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 2.0, 4.0)
	# Compute basis to look at origin (can't use look_at before in tree)
	var dir: Vector3 = (Vector3.ZERO - camera.position).normalized()
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	camera.transform.basis = Basis(right, up, -dir)
	camera.fov = 40.0
	camera.current = true
	sub_viewport.add_child(camera)

	# Lighting
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	sub_viewport.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20, -60, 0)
	fill_light.light_energy = 0.4
	fill_light.shadow_enabled = false
	sub_viewport.add_child(fill_light)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	sub_viewport.add_child(world_env)

	# Car pivot for rotation
	car_pivot = Node3D.new()
	sub_viewport.add_child(car_pivot)

	_create_car_visual(car_pivot, GameManager.selected_car_index)

func _create_car_visual(parent: Node3D, car_index: int) -> void:
	# Clear existing children
	for child in parent.get_children():
		child.queue_free()

	var car_data: Resource = GameManager.get_car_data(car_index)
	if not car_data:
		car_data = GameManager.get_car_data(0)

	var body_mesh := Node3D.new()
	body_mesh.name = "BodyMesh"
	parent.add_child(body_mesh)

	# Create dummy wheel Node3Ds at approximate positions
	var wheel_positions: Array[Vector3] = [
		Vector3(-0.8, 0.1, -1.3),  # FL
		Vector3(0.8, 0.1, -1.3),   # FR
		Vector3(-0.8, 0.1, 1.3),   # RL
		Vector3(0.8, 0.1, 1.3),    # RR
	]
	var wheels: Array = []
	for pos in wheel_positions:
		var w := Node3D.new()
		w.position = pos
		parent.add_child(w)
		wheels.append(w)

	# Load the appropriate mesh builder
	var mesh_script: GDScript
	match car_data.tier:
		2:
			mesh_script = load("res://cars/car_meshes/coupe_mesh.gd")
		3:
			mesh_script = load("res://cars/car_meshes/muscle_mesh.gd")
		4:
			mesh_script = load("res://cars/car_meshes/f1_mesh.gd")
		7:
			mesh_script = load("res://cars/car_meshes/buggy_mesh.gd")
		8:
			mesh_script = load("res://cars/car_meshes/trophy_truck_mesh.gd")
		_:
			mesh_script = load("res://cars/car_meshes/sedan_mesh.gd")

	mesh_script.build(body_mesh, car_data, wheels)

func _process(delta: float) -> void:
	if car_pivot:
		car_pivot.rotate_y(delta * 0.5)
	_update_credits_display()

func _update_credits_display() -> void:
	if credits_label and SaveManager and SaveManager.profile:
		credits_label.text = "$%d" % SaveManager.profile.credits

func _switch_mode(direction: int) -> void:
	var num_modes: int = GameManager.NUM_RACING_MODES
	var new_mode: int = (GameManager.racing_mode + direction) % num_modes
	if new_mode < 0:
		new_mode = num_modes - 1
	GameManager.set_racing_mode(new_mode as GameManager.RacingMode)
	mode_label.text = MODE_NAMES[GameManager.racing_mode]
	# Update car preview
	if car_pivot:
		_create_car_visual(car_pivot, GameManager.selected_car_index)

func _on_mode_prev() -> void:
	_switch_mode(-1)

func _on_mode_next() -> void:
	_switch_mode(1)

func _on_quick_race() -> void:
	GameManager.transition_to_scene("res://ui/player_select/player_select.tscn")

func _on_garage() -> void:
	GameManager.transition_to_scene("res://ui/garage/garage.tscn")

func _on_settings() -> void:
	GameManager.transition_to_scene("res://ui/settings/settings_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _create_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 56)

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
