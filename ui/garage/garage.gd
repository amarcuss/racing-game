extends Node

## Garage: browse, buy, and select cars with 3D turntable preview.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")
const GOLD := Color("FFD700")
const CYAN := Color("00D4FF")

var ui_layer: CanvasLayer
var car_cards: Array = []
var selected_index: int = 0

# Right panel elements
var car_name_label: Label
var car_desc_label: Label
var tier_label: Label
var action_btn: Button
var stat_bars: Dictionary = {}  # stat_name -> ColorRect (fill)
var credits_label: Label

# 3D preview
var sub_viewport: SubViewport
var car_pivot: Node3D

const STAT_NAMES := ["SPEED", "HANDLING", "BRAKING", "DRIFT"]

func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_ui()
	_select_car(GameManager.selected_car_index)

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	ui_layer.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "GARAGE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.position = Vector2(60, 30)
	title.size = Vector2(300, 60)
	bg.add_child(title)

	# Accent
	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(60, 90)
	accent.size = Vector2(160, 3)
	bg.add_child(accent)

	# Credits (top-right)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 28)
	credits_label.add_theme_color_override("font_color", GOLD)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.position = Vector2(1500, 35)
	credits_label.size = Vector2(380, 40)
	bg.add_child(credits_label)

	# Left panel: car cards in scroll
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 130)
	scroll.size = Vector2(440, 860)
	bg.add_child(scroll)

	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 12)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list)

	# Build car cards for all registered cars
	for i in range(GameManager.CAR_PATHS.size()):
		var card := _create_car_card(i)
		card_list.add_child(card)
		car_cards.append(card)

	# Right panel: 3D preview + stats
	_build_right_panel(bg)

	# Back button
	var back_btn := _create_button("BACK", SURFACE)
	back_btn.position = Vector2(60, 1000)
	bg.add_child(back_btn)
	back_btn.pressed.connect(_on_back)

func _build_right_panel(parent: Control) -> void:
	# 3D preview
	var preview_container := SubViewportContainer.new()
	preview_container.position = Vector2(520, 130)
	preview_container.size = Vector2(700, 450)
	preview_container.stretch = true
	parent.add_child(preview_container)

	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(700, 450)
	sub_viewport.own_world_3d = true
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(sub_viewport)

	_setup_3d_scene()

	# Car name
	car_name_label = Label.new()
	car_name_label.add_theme_font_size_override("font_size", 36)
	car_name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	car_name_label.position = Vector2(520, 600)
	car_name_label.size = Vector2(700, 50)
	parent.add_child(car_name_label)

	# Tier label
	tier_label = Label.new()
	tier_label.add_theme_font_size_override("font_size", 20)
	tier_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	tier_label.position = Vector2(520, 645)
	tier_label.size = Vector2(700, 30)
	parent.add_child(tier_label)

	# Description
	car_desc_label = Label.new()
	car_desc_label.add_theme_font_size_override("font_size", 18)
	car_desc_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	car_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	car_desc_label.position = Vector2(520, 680)
	car_desc_label.size = Vector2(700, 60)
	parent.add_child(car_desc_label)

	# Stat bars
	var stat_y: float = 760.0
	for stat_name in STAT_NAMES:
		var label := Label.new()
		label.text = stat_name
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", TEXT_SECONDARY)
		label.position = Vector2(520, stat_y)
		label.size = Vector2(120, 25)
		parent.add_child(label)

		# Bar background
		var bar_bg := ColorRect.new()
		bar_bg.color = SURFACE
		bar_bg.position = Vector2(660, stat_y + 3)
		bar_bg.size = Vector2(300, 18)
		parent.add_child(bar_bg)

		# Bar fill
		var bar_fill := ColorRect.new()
		bar_fill.color = CYAN
		bar_fill.position = Vector2(660, stat_y + 3)
		bar_fill.size = Vector2(0, 18)
		parent.add_child(bar_fill)
		stat_bars[stat_name] = bar_fill

		stat_y += 35.0

	# Action button
	action_btn = _create_button("SELECT", PRIMARY_ACCENT)
	action_btn.position = Vector2(520, 920)
	parent.add_child(action_btn)
	action_btn.pressed.connect(_on_action)

func _setup_3d_scene() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(3.0, 2.0, 4.0)
	var dir: Vector3 = (Vector3.ZERO - camera.position).normalized()
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	camera.transform.basis = Basis(right, up, -dir)
	camera.fov = 40.0
	camera.current = true
	sub_viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	sub_viewport.add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.4
	sub_viewport.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	sub_viewport.add_child(world_env)

	car_pivot = Node3D.new()
	sub_viewport.add_child(car_pivot)

func _create_car_card(index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(400, 90)

	var car_data: Resource = GameManager.get_car_data(index)
	var is_coming_soon: bool = car_data == null

	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_MID
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("normal", sb)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = BG_MID.lightened(0.1)
	sb_hover.set_corner_radius_all(8)
	sb_hover.content_margin_left = 16
	sb_hover.content_margin_right = 16
	sb_hover.content_margin_top = 12
	sb_hover.content_margin_bottom = 12
	card.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = BG_MID.darkened(0.1)
	sb_pressed.set_corner_radius_all(8)
	sb_pressed.content_margin_left = 16
	sb_pressed.content_margin_right = 16
	sb_pressed.content_margin_top = 12
	sb_pressed.content_margin_bottom = 12
	card.add_theme_stylebox_override("pressed", sb_pressed)

	if is_coming_soon:
		card.text = "COMING SOON"
		card.add_theme_font_size_override("font_size", 20)
		card.add_theme_color_override("font_color", TEXT_SECONDARY)
		card.disabled = true
	else:
		var owned: bool = SaveManager.is_car_owned(index)
		var selected: bool = (index == GameManager.selected_car_index)
		var status_text: String = ""
		if selected:
			status_text = "  [SELECTED]"
		elif owned:
			status_text = "  [OWNED]"
		else:
			status_text = "  $%d" % car_data.price

		card.text = "%s   T%d%s" % [car_data.car_name, car_data.tier, status_text]
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_color_override("font_color", TEXT_PRIMARY)
		card.pressed.connect(_select_car.bind(index))

	return card

func _select_car(index: int) -> void:
	selected_index = index
	var car_data: Resource = GameManager.get_car_data(index)
	if not car_data:
		return

	car_name_label.text = car_data.car_name
	tier_label.text = "TIER %d" % car_data.tier
	car_desc_label.text = car_data.description

	# Update stat bars (normalized 0-1)
	var speed_norm: float = clampf(car_data.max_speed_kph / 300.0, 0.0, 1.0)
	var handling_norm: float = clampf(car_data.max_steering_angle / 0.5, 0.0, 1.0)
	var braking_norm: float = clampf(car_data.brake_force / 50.0, 0.0, 1.0)
	var drift_norm: float = clampf(car_data.drift_steer_multiplier / 2.0, 0.0, 1.0)

	_set_stat_bar("SPEED", speed_norm)
	_set_stat_bar("HANDLING", handling_norm)
	_set_stat_bar("BRAKING", braking_norm)
	_set_stat_bar("DRIFT", drift_norm)

	# Update action button
	var owned: bool = SaveManager.is_car_owned(index)
	var selected: bool = (index == GameManager.selected_car_index)
	if selected:
		action_btn.text = "SELECTED"
		action_btn.disabled = true
	elif owned:
		action_btn.text = "SELECT"
		action_btn.disabled = false
	elif SaveManager.profile.credits >= car_data.price:
		action_btn.text = "BUY  $%d" % car_data.price
		action_btn.disabled = false
	else:
		action_btn.text = "LOCKED  $%d" % car_data.price
		action_btn.disabled = true

	# Update 3D preview
	_update_car_preview(index)

func _set_stat_bar(stat_name: String, value: float) -> void:
	if stat_name in stat_bars:
		var fill: ColorRect = stat_bars[stat_name]
		var t: float = clampf(value, 0.0, 1.0)
		fill.size.x = 300.0 * t
		fill.color = CYAN.lerp(PRIMARY_ACCENT, t)

func _update_car_preview(car_index: int) -> void:
	if not car_pivot:
		return
	for child in car_pivot.get_children():
		child.queue_free()

	var car_data: Resource = GameManager.get_car_data(car_index)
	if not car_data:
		return

	var body_mesh := Node3D.new()
	body_mesh.name = "BodyMesh"
	car_pivot.add_child(body_mesh)

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
		car_pivot.add_child(w)
		wheels.append(w)

	var mesh_script: GDScript
	match car_data.tier:
		2: mesh_script = load("res://cars/car_meshes/coupe_mesh.gd")
		3: mesh_script = load("res://cars/car_meshes/muscle_mesh.gd")
		4: mesh_script = load("res://cars/car_meshes/f1_mesh.gd")
		_: mesh_script = load("res://cars/car_meshes/sedan_mesh.gd")

	mesh_script.build(body_mesh, car_data, wheels)

func _on_action() -> void:
	var car_data: Resource = GameManager.get_car_data(selected_index)
	if not car_data:
		return

	var owned: bool = SaveManager.is_car_owned(selected_index)
	if owned:
		# Select this car
		SaveManager.select_car(selected_index)
		_refresh_cards()
		_select_car(selected_index)
	else:
		# Buy
		if SaveManager.spend_credits(car_data.price):
			SaveManager.own_car(selected_index)
			SaveManager.select_car(selected_index)
			_refresh_cards()
			_select_car(selected_index)

func _refresh_cards() -> void:
	# Rebuild card text to reflect ownership changes
	for i in range(car_cards.size()):
		var card: Button = car_cards[i]
		var car_data: Resource = GameManager.get_car_data(i)
		if not car_data:
			continue
		var owned: bool = SaveManager.is_car_owned(i)
		var selected: bool = (i == GameManager.selected_car_index)
		var status_text: String = ""
		if selected:
			status_text = "  [SELECTED]"
		elif owned:
			status_text = "  [OWNED]"
		else:
			status_text = "  $%d" % car_data.price
		card.text = "%s   T%d%s" % [car_data.car_name, car_data.tier, status_text]

func _process(delta: float) -> void:
	if car_pivot:
		car_pivot.rotate_y(delta * 0.5)
	if credits_label and SaveManager and SaveManager.profile:
		credits_label.text = "$%d" % SaveManager.profile.credits

func _on_back() -> void:
	GameManager.transition_to_scene("res://scenes/main.tscn")

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
