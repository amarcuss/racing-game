extends CanvasLayer

## Pause menu overlay with Resume, Restart, and Main Menu buttons.
## Processes only when tree is paused so ESC can unpause.

signal resumed
signal restarted

var overlay: ColorRect

const BG_DARK := Color("0A0E1A")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	visible = false

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(1920, 1080)
	overlay.color = Color(BG_DARK, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 300)
	title.size = Vector2(1920, 70)
	overlay.add_child(title)

	# Accent line
	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(860, 380)
	accent.size = Vector2(200, 3)
	overlay.add_child(accent)

	# Buttons
	var btn_box := VBoxContainer.new()
	btn_box.position = Vector2(760, 420)
	btn_box.size = Vector2(400, 300)
	btn_box.add_theme_constant_override("separation", 16)
	overlay.add_child(btn_box)

	var resume_btn := _create_button("RESUME", PRIMARY_ACCENT)
	btn_box.add_child(resume_btn)
	resume_btn.pressed.connect(_on_resume)

	var restart_btn := _create_button("RESTART", SURFACE)
	btn_box.add_child(restart_btn)
	restart_btn.pressed.connect(_on_restart)

	var menu_btn := _create_button("MAIN MENU", SURFACE)
	btn_box.add_child(menu_btn)
	menu_btn.pressed.connect(_on_main_menu)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("p1_pause"):
		hide_pause()
		get_viewport().set_input_as_handled()

func show_pause() -> void:
	visible = true
	get_tree().paused = true

func hide_pause() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()

func _on_resume() -> void:
	hide_pause()

func _on_restart() -> void:
	get_tree().paused = false
	RaceManager.reset()
	restarted.emit()
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	GameManager.go_to_main_menu()

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
