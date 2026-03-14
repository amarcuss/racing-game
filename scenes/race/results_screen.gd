extends CanvasLayer

## Slide-up results screen: position, stats, credits animation, and action buttons.

signal restart_pressed
signal menu_pressed

var overlay: ColorRect
var container: Control
var position_label: Label
var time_label: Label
var best_lap_label: Label
var credits_label: Label
var credits_target: int = 0
var confetti: GPUParticles2D

const BG_DARK := Color("0A0E1A")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")
const GOLD := Color("FFD700")
const SILVER := Color("C0C0C0")
const BRONZE := Color("CD7F32")

# Credits per finishing position
const CREDITS_BY_POSITION := [500, 300, 200, 150, 100, 75, 50, 25]

func _ready() -> void:
	layer = 20
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Dark overlay
	overlay = ColorRect.new()
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1920, 1080)
	overlay.color = Color(BG_DARK, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Container that slides up from bottom
	container = Control.new()
	container.position = Vector2(0, 1080)
	container.size = Vector2(1920, 1080)
	overlay.add_child(container)

	# Position label
	position_label = Label.new()
	position_label.text = "1ST"
	position_label.add_theme_font_size_override("font_size", 120)
	position_label.add_theme_color_override("font_color", GOLD)
	position_label.add_theme_constant_override("outline_size", 4)
	position_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.position = Vector2(0, 120)
	position_label.size = Vector2(1920, 150)
	container.add_child(position_label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "RACE COMPLETE"
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 280)
	subtitle.size = Vector2(1920, 40)
	container.add_child(subtitle)

	# Accent line
	var accent_line := ColorRect.new()
	accent_line.color = PRIMARY_ACCENT
	accent_line.position = Vector2(810, 330)
	accent_line.size = Vector2(300, 3)
	container.add_child(accent_line)

	# Total time
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.position = Vector2(0, 360)
	time_label.size = Vector2(1920, 50)
	container.add_child(time_label)

	# Best lap
	best_lap_label = Label.new()
	best_lap_label.add_theme_font_size_override("font_size", 28)
	best_lap_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	best_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_lap_label.position = Vector2(0, 415)
	best_lap_label.size = Vector2(1920, 40)
	container.add_child(best_lap_label)

	# Credits earned
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 36)
	credits_label.add_theme_color_override("font_color", GOLD)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.position = Vector2(0, 480)
	credits_label.size = Vector2(1920, 50)
	container.add_child(credits_label)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.position = Vector2(610, 570)
	btn_box.size = Vector2(700, 60)
	btn_box.add_theme_constant_override("separation", 30)
	container.add_child(btn_box)

	var next_btn := _create_button("NEXT RACE", PRIMARY_ACCENT)
	btn_box.add_child(next_btn)
	next_btn.pressed.connect(_on_next_race)

	var menu_btn := _create_button("MAIN MENU", SURFACE)
	btn_box.add_child(menu_btn)
	menu_btn.pressed.connect(_on_main_menu)

	# Confetti particles (hidden until 1st place)
	confetti = GPUParticles2D.new()
	confetti.amount = 100
	confetti.lifetime = 3.0
	confetti.emitting = false
	confetti.position = Vector2(960, -20)
	var conf_mat := ParticleProcessMaterial.new()
	conf_mat.direction = Vector3(0, 1, 0)
	conf_mat.spread = 45.0
	conf_mat.initial_velocity_min = 100.0
	conf_mat.initial_velocity_max = 250.0
	conf_mat.gravity = Vector3(0, 200, 0)
	conf_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	conf_mat.emission_box_extents = Vector3(450, 0, 0)
	conf_mat.scale_min = 3.0
	conf_mat.scale_max = 6.0
	conf_mat.angular_velocity_min = -180.0
	conf_mat.angular_velocity_max = 180.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color.RED)
	gradient.add_point(0.2, Color.YELLOW)
	gradient.add_point(0.4, Color.GREEN)
	gradient.add_point(0.6, Color.CYAN)
	gradient.add_point(0.8, Color.BLUE)
	gradient.set_color(1, Color.MAGENTA)
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	conf_mat.color_initial_ramp = grad_tex
	confetti.process_material = conf_mat
	# Small white rectangle texture
	var img := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	confetti.texture = tex
	overlay.add_child(confetti)

func show_results(car: Node, finish_position: int = 1) -> void:
	visible = true

	# Position text and color
	var pos_text: String = _ordinal(finish_position)
	position_label.text = pos_text
	position_label.add_theme_color_override("font_color", _position_color(finish_position))

	# Stats
	time_label.text = "TOTAL TIME   %s" % _format_time(RaceManager.race_time)
	var best: float = RaceManager.get_car_best_lap_time(car)
	best_lap_label.text = "BEST LAP   %s" % _format_time(best)

	# Credits
	var cred_index: int = clampi(finish_position - 1, 0, CREDITS_BY_POSITION.size() - 1)
	credits_target = CREDITS_BY_POSITION[cred_index]
	credits_label.text = "CREDITS   0"

	# Save credits and record result
	SaveManager.add_credits(credits_target)
	var result_dict: Dictionary = {
		"track_index": GameManager.selected_track_index,
		"car_index": GameManager.selected_car_index,
		"finish_position": finish_position,
		"total_cars": RaceManager.registered_cars.size(),
		"total_time": RaceManager.race_time,
		"best_lap_time": best,
		"credits_earned": credits_target,
		"laps": GameManager.race_laps,
	}
	SaveManager.record_race_result(result_dict)

	# Confetti for 1st place
	if finish_position == 1 and confetti:
		confetti.emitting = true

	# Slide up animation
	container.position.y = 1080
	var tween := create_tween()
	tween.tween_property(container, "position:y", 0.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_start_credits_animation)

func _start_credits_animation() -> void:
	var tween := create_tween()
	tween.tween_method(_update_credits_display, 0.0, 1.0, 1.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _update_credits_display(progress: float) -> void:
	credits_label.text = "CREDITS   %d" % int(credits_target * progress)

# --- Button actions ---

func _on_next_race() -> void:
	Engine.time_scale = 1.0
	RaceManager.reset()
	restart_pressed.emit()
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	Engine.time_scale = 1.0
	menu_pressed.emit()
	GameManager.go_to_main_menu()

# --- Helpers ---

func _ordinal(pos: int) -> String:
	match pos:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % pos

func _position_color(pos: int) -> Color:
	match pos:
		1: return GOLD
		2: return SILVER
		3: return BRONZE
		_: return TEXT_PRIMARY

func _format_time(time: float) -> String:
	var mins: int = int(time) / 60
	var secs: float = fmod(time, 60.0)
	return "%02d:%06.3f" % [mins, secs]

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
