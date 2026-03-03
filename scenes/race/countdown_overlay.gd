extends CanvasLayer

## Animated countdown overlay: 3-2-1-GO! with zoom-in, fade-out, and screen flash.

var number_label: Label
var flash_rect: ColorRect

const TEXT_PRIMARY := Color("F0F0F0")
const SUCCESS := Color("7FFF00")

func _ready() -> void:
	layer = 10

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

	RaceManager.countdown_tick.connect(_on_countdown_tick)

func _on_countdown_tick(number: int) -> void:
	if number > 0:
		_show_number(str(number), TEXT_PRIMARY, 200)
	else:
		_show_number("GO!", SUCCESS, 250)
		_flash_screen()

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
