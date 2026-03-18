extends Node

## Race setup: configure laps, AI opponents, and difficulty before starting.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")

const DIFFICULTY_NAMES := ["EASY", "MEDIUM", "HARD"]

var ui_layer: CanvasLayer
var laps_value: int = 3
var ai_count_value: int = 5
var difficulty_value: int = 1

var laps_label: Label
var ai_label: Label
var difficulty_label: Label
var summary_label: Label
var laps_row: HBoxContainer

func _ready() -> void:
	# Use track default laps
	var track_data: Resource = GameManager.get_selected_track_data()
	if track_data and track_data.get("default_laps"):
		laps_value = track_data.default_laps
		GameManager.race_laps = laps_value
	else:
		laps_value = GameManager.race_laps
	difficulty_value = GameManager.ai_difficulty

	# Set sensible AI defaults per mode
	match GameManager.racing_mode:
		GameManager.RacingMode.F1:
			ai_count_value = 19
			difficulty_value = 2
		GameManager.RacingMode.BAJA:
			ai_count_value = mini(GameManager.ai_count, 5)
			if ai_count_value > 5:
				ai_count_value = 5
		_:
			ai_count_value = mini(GameManager.ai_count, 7)
	GameManager.ai_count = ai_count_value
	GameManager.ai_difficulty = difficulty_value

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_ui()
	_update_display()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	ui_layer.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "RACE SETUP"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(1920, 60)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(835, 120)
	accent.size = Vector2(250, 3)
	bg.add_child(accent)

	# Settings panel
	var panel := ColorRect.new()
	panel.color = BG_MID
	panel.position = Vector2(560, 180)
	panel.size = Vector2(800, 500)
	bg.add_child(panel)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = BG_MID
	panel_sb.set_corner_radius_all(12)

	# Laps spinner — F1 allows more laps
	var max_laps: int = 20 if GameManager.racing_mode == GameManager.RacingMode.F1 else 10
	_create_spinner(panel, "LAPS", 50, laps_value, 1, max_laps, func(v: int): laps_value = v; _update_display())
	laps_row = panel.get_child(panel.get_child_count() - 1) as HBoxContainer
	laps_label = laps_row.get_child(1) as Label

	# Hide laps for point-to-point tracks
	var track_data_check: Resource = GameManager.get_selected_track_data()
	if track_data_check and track_data_check.get("is_point_to_point") and track_data_check.is_point_to_point:
		laps_value = 1
		laps_row.visible = false

	# AI opponents spinner — capped per mode
	var max_ai: int = 7
	match GameManager.racing_mode:
		GameManager.RacingMode.F1: max_ai = 19
		GameManager.RacingMode.BAJA: max_ai = 5
	_create_spinner(panel, "AI OPPONENTS", 150, ai_count_value, 0, max_ai, func(v: int): ai_count_value = v; _update_display())
	ai_label = panel.get_child(panel.get_child_count() - 1).get_child(1) as Label

	# Difficulty spinner
	_create_spinner(panel, "DIFFICULTY", 250, difficulty_value, 0, 2, func(v: int): difficulty_value = v; _update_display(), true)
	difficulty_label = panel.get_child(panel.get_child_count() - 1).get_child(1) as Label

	# Summary
	summary_label = Label.new()
	summary_label.add_theme_font_size_override("font_size", 22)
	summary_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.position = Vector2(0, 400)
	summary_label.size = Vector2(800, 60)
	panel.add_child(summary_label)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.position = Vector2(0, 750)
	btn_box.size = Vector2(1920, 60)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 30)
	bg.add_child(btn_box)

	var back_btn := _create_button("BACK", SURFACE)
	btn_box.add_child(back_btn)
	back_btn.pressed.connect(_on_back)

	var start_btn := _create_button("START RACE", PRIMARY_ACCENT)
	btn_box.add_child(start_btn)
	start_btn.pressed.connect(_on_start)

func _create_spinner(parent: Control, label_text: String, y_pos: float, initial: int, min_val: int, max_val: int, on_change: Callable, is_difficulty: bool = false) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(100, y_pos)
	row.size = Vector2(600, 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.custom_minimum_size = Vector2(250, 60)
	row.add_child(label)

	var value_label := Label.new()
	if is_difficulty:
		value_label.text = DIFFICULTY_NAMES[initial]
	else:
		value_label.text = str(initial)
	value_label.add_theme_font_size_override("font_size", 28)
	value_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(120, 60)
	row.add_child(value_label)

	var current_val: int = initial

	var minus_btn := _create_small_button("<")
	row.add_child(minus_btn)
	minus_btn.pressed.connect(func():
		current_val = maxi(current_val - 1, min_val)
		if is_difficulty:
			value_label.text = DIFFICULTY_NAMES[current_val]
		else:
			value_label.text = str(current_val)
		on_change.call(current_val)
	)

	var plus_btn := _create_small_button(">")
	row.add_child(plus_btn)
	plus_btn.pressed.connect(func():
		current_val = mini(current_val + 1, max_val)
		if is_difficulty:
			value_label.text = DIFFICULTY_NAMES[current_val]
		else:
			value_label.text = str(current_val)
		on_change.call(current_val)
	)

func _update_display() -> void:
	var car_data: Resource = GameManager.get_selected_car_data()
	var track_data: Resource = GameManager.get_selected_track_data()
	var car_name: String = car_data.car_name if car_data else "Unknown"
	var track_name: String = track_data.track_name if track_data else "Unknown"
	var mode_str: String = "2P SPLIT" if GameManager.split_screen else "1P"
	var laps_str: String = "point-to-point" if (laps_row and not laps_row.visible) else "%d laps" % laps_value
	if summary_label:
		summary_label.text = "%s  |  %s  |  %s  |  %d AI  |  %s  |  %s" % [
			car_name, track_name, laps_str, ai_count_value, DIFFICULTY_NAMES[difficulty_value], mode_str]

func _on_back() -> void:
	GameManager.transition_to_scene("res://ui/track_select/track_select.tscn")

func _on_start() -> void:
	GameManager.race_laps = laps_value
	GameManager.ai_count = ai_count_value
	GameManager.ai_difficulty = difficulty_value
	GameManager.go_to_race()

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

	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = SURFACE.darkened(0.1)
	sb_p.set_corner_radius_all(6)
	sb_p.content_margin_left = 10
	sb_p.content_margin_right = 10
	sb_p.content_margin_top = 8
	sb_p.content_margin_bottom = 8
	btn.add_theme_stylebox_override("pressed", sb_p)

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
