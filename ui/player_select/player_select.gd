extends Node

## Player count selection screen: 1 PLAYER or 2 PLAYERS.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SECONDARY_ACCENT := Color("00D4FF")
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
	title.text = "SELECT MODE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 80)
	title.size = Vector2(1920, 60)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(835, 150)
	accent.size = Vector2(250, 3)
	bg.add_child(accent)

	# Cards container
	var card_box := HBoxContainer.new()
	card_box.position = Vector2(310, 250)
	card_box.size = Vector2(1300, 500)
	card_box.add_theme_constant_override("separation", 60)
	bg.add_child(card_box)

	# 1 Player card
	var p1_card := _create_mode_card(
		"1 PLAYER",
		"Solo race against AI opponents.\nWASD to drive, Space for handbrake.",
		"res://ui/track_select/track_select.tscn",
		false
	)
	card_box.add_child(p1_card)

	# 2 Players card
	var p2_card := _create_mode_card(
		"2 PLAYERS",
		"Split-screen local multiplayer.\nP1: WASD  |  P2: Arrow Keys",
		"res://ui/track_select/track_select.tscn",
		true
	)
	card_box.add_child(p2_card)

	# Back button
	var back_btn := _create_button("BACK", SURFACE)
	back_btn.position = Vector2(760, 820)
	back_btn.size = Vector2(400, 56)
	bg.add_child(back_btn)
	back_btn.pressed.connect(func():
		GameManager.transition_to_scene("res://scenes/main.tscn")
	)

func _create_mode_card(title_text: String, desc_text: String, next_scene: String, is_split: bool) -> Panel:
	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_MID
	sb.set_corner_radius_all(12)
	sb.border_width_left = 4
	sb.border_color = SURFACE
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(580, 500)

	# Icon text (large)
	var icon := Label.new()
	icon.text = "1P" if not is_split else "2P"
	icon.add_theme_font_size_override("font_size", 96)
	icon.add_theme_color_override("font_color", SECONDARY_ACCENT if not is_split else PRIMARY_ACCENT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.position = Vector2(0, 50)
	icon.size = Vector2(580, 120)
	card.add_child(icon)

	# Title
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 190)
	title.size = Vector2(580, 40)
	card.add_child(title)

	# Description
	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", TEXT_SECONDARY)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(40, 260)
	desc.size = Vector2(500, 80)
	card.add_child(desc)

	# Select button
	var btn_color: Color = SECONDARY_ACCENT if not is_split else PRIMARY_ACCENT
	var select_btn := _create_button("SELECT", btn_color)
	select_btn.position = Vector2(115, 390)
	select_btn.size = Vector2(350, 56)
	card.add_child(select_btn)
	select_btn.pressed.connect(func():
		GameManager.split_screen = is_split
		GameManager.transition_to_scene(next_scene)
	)

	return card

func _create_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(350, 56)

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
