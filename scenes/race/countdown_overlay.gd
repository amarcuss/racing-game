extends CanvasLayer

## Animated countdown overlay.
## Standard mode: 3-2-1-GO! with zoom-in and fade-out.
## F1 mode: 5 red lights that illuminate one by one, then all go out — "LIGHTS OUT AND AWAY WE GO!"

var number_label: Label
var flash_rect: ColorRect

# F1 lights
var lights_container: HBoxContainer
var lights_bg: ColorRect
var light_rects: Array[ColorRect] = []
var is_f1: bool = false

const TEXT_PRIMARY := Color("F0F0F0")
const SUCCESS := Color("7FFF00")
const F1_RED := Color("CC0000")
const F1_RED_DIM := Color("330000")
const F1_RED_OFF := Color("1A0000")

func _ready() -> void:
	layer = 10
	is_f1 = GameManager.racing_mode == GameManager.RacingMode.F1

	number_label = Label.new()
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.position = Vector2(0, 0)
	number_label.size = Vector2(1920, 1080)
	number_label.pivot_offset = Vector2(960, 540)
	number_label.add_theme_font_size_override("font_size", 200)
	number_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	number_label.add_theme_constant_override("outline_size", 8)
	number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	number_label.text = ""
	add_child(number_label)

	flash_rect = ColorRect.new()
	flash_rect.position = Vector2(0, 0)
	flash_rect.size = Vector2(1920, 1080)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	if is_f1:
		_build_f1_lights()

	RaceManager.countdown_tick.connect(_on_countdown_tick)

func _build_f1_lights() -> void:
	# Dark background panel behind lights
	lights_bg = ColorRect.new()
	lights_bg.color = Color(0.05, 0.05, 0.05, 0.85)
	lights_bg.position = Vector2(460, 200)
	lights_bg.size = Vector2(1000, 120)
	lights_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lights_bg)

	lights_container = HBoxContainer.new()
	lights_container.position = Vector2(510, 215)
	lights_container.size = Vector2(900, 90)
	lights_container.alignment = BoxContainer.ALIGNMENT_CENTER
	lights_container.add_theme_constant_override("separation", 40)
	lights_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lights_container)

	for i in range(5):
		var light := ColorRect.new()
		light.custom_minimum_size = Vector2(80, 80)
		light.color = F1_RED_OFF
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lights_container.add_child(light)
		light_rects.append(light)

func _on_countdown_tick(number: int) -> void:
	if is_f1:
		_on_f1_tick(number)
	else:
		_on_standard_tick(number)

func _on_standard_tick(number: int) -> void:
	if number > 0:
		_show_number(str(number), TEXT_PRIMARY, 200)
	else:
		_show_number("GO!", SUCCESS, 250)
		_flash_screen()

func _on_f1_tick(number: int) -> void:
	if number > 0:
		# Light up from left to right: tick 5 = light 0, tick 4 = light 1, etc.
		var light_index: int = 5 - number
		if light_index >= 0 and light_index < light_rects.size():
			light_rects[light_index].color = F1_RED
			# Pulse animation
			var tween := create_tween()
			tween.tween_property(light_rects[light_index], "color", F1_RED, 0.05)
	else:
		# LIGHTS OUT — all lights go dark
		for light in light_rects:
			light.color = F1_RED_OFF
		_show_number("LIGHTS OUT AND AWAY WE GO!", SUCCESS, 60)
		_flash_screen()
		# Fade out the lights panel after a moment
		var fade_tween := create_tween()
		fade_tween.tween_interval(1.5)
		fade_tween.tween_callback(func():
			if lights_container:
				var ct := create_tween()
				ct.set_parallel(true)
				ct.tween_property(lights_container, "modulate:a", 0.0, 0.5)
				if lights_bg:
					ct.tween_property(lights_bg, "modulate:a", 0.0, 0.5)
		)

func _show_number(text: String, color: Color, font_size: int) -> void:
	number_label.text = text
	number_label.add_theme_font_size_override("font_size", font_size)
	number_label.add_theme_color_override("font_color", color)
	number_label.modulate = Color(1, 1, 1, 1)
	number_label.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(number_label, "scale", Vector2(1.5, 1.5), 0.8) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(number_label, "modulate:a", 0.0, 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _flash_screen() -> void:
	flash_rect.color = Color(1, 1, 1, 0.3)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
