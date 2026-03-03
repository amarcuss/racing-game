extends Node

## Settings screen: volume sliders, fullscreen/vsync toggles.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")

var ui_layer: CanvasLayer

func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	ui_layer.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(1920, 60)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(845, 120)
	accent.size = Vector2(230, 3)
	bg.add_child(accent)

	# Settings panel
	var panel := ColorRect.new()
	panel.color = BG_MID
	panel.position = Vector2(560, 180)
	panel.size = Vector2(800, 600)
	bg.add_child(panel)

	var y: float = 40.0

	# Master volume
	_create_slider(panel, "MASTER VOLUME", y, SaveManager.master_volume, func(v: float):
		SaveManager.master_volume = v
		SaveManager.save_settings()
	)
	y += 90.0

	# SFX volume
	_create_slider(panel, "SFX VOLUME", y, SaveManager.sfx_volume, func(v: float):
		SaveManager.sfx_volume = v
		SaveManager.save_settings()
	)
	y += 90.0

	# Music volume
	_create_slider(panel, "MUSIC VOLUME", y, SaveManager.music_volume, func(v: float):
		SaveManager.music_volume = v
		SaveManager.save_settings()
	)
	y += 110.0

	# Fullscreen checkbox
	_create_checkbox(panel, "FULLSCREEN", y, SaveManager.fullscreen, func(v: bool):
		SaveManager.fullscreen = v
		SaveManager.save_settings()
	)
	y += 70.0

	# VSync checkbox
	_create_checkbox(panel, "VSYNC", y, SaveManager.vsync, func(v: bool):
		SaveManager.vsync = v
		SaveManager.save_settings()
	)

	# Back button
	var back_btn := _create_button("BACK", SURFACE)
	back_btn.position = Vector2(800, 840)
	bg.add_child(back_btn)
	back_btn.pressed.connect(_on_back)

func _create_slider(parent: Control, label_text: String, y_pos: float, initial: float, on_change: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.position = Vector2(50, y_pos)
	label.size = Vector2(250, 40)
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.position = Vector2(320, y_pos + 5)
	slider.size = Vector2(350, 30)
	parent.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(initial * 100)
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	value_label.position = Vector2(690, y_pos)
	value_label.size = Vector2(80, 40)
	parent.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%d%%" % int(v * 100)
		on_change.call(v)
	)

func _create_checkbox(parent: Control, label_text: String, y_pos: float, initial: bool, on_change: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.position = Vector2(50, y_pos)
	cb.size = Vector2(400, 40)
	cb.add_theme_font_size_override("font_size", 22)
	cb.add_theme_color_override("font_color", TEXT_PRIMARY)
	parent.add_child(cb)

	cb.toggled.connect(func(pressed: bool):
		on_change.call(pressed)
	)

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
