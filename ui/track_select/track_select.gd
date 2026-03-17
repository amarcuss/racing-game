extends Node

## Track selection screen with track cards and coming-soon placeholders.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")

const TRACK_COLORS := [Color("2ECC71"), Color("3498DB"), Color("9B59B6"), Color("E74C3C"), Color("F39C12"), Color("1ABC9C")]

var ui_layer: CanvasLayer
var selected_index: int = 0
var track_cards: Array = []
var mode_track_indices: Array[int] = []
var track_name_label: Label
var track_desc_label: Label
var difficulty_label: Label
var length_label: Label
var continue_btn: Button

func _ready() -> void:
	mode_track_indices = GameManager.get_track_indices_for_mode()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_ui()
	_select_track(mode_track_indices[0])

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920, 1080)
	bg.color = BG_DARK
	ui_layer.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "SELECT TRACK"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1920, 60)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(835, 110)
	accent.size = Vector2(250, 3)
	bg.add_child(accent)

	# Track cards centered
	var card_box := HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 20)
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.position = Vector2(0, 160)
	card_box.size = Vector2(1920, 420)
	bg.add_child(card_box)

	for ci in range(mode_track_indices.size()):
		var track_idx: int = mode_track_indices[ci]
		var card := _create_track_card(track_idx, ci)
		card_box.add_child(card)
		track_cards.append(card)

	# Detail panel below cards
	track_name_label = Label.new()
	track_name_label.add_theme_font_size_override("font_size", 36)
	track_name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	track_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_name_label.position = Vector2(0, 600)
	track_name_label.size = Vector2(1920, 50)
	bg.add_child(track_name_label)

	track_desc_label = Label.new()
	track_desc_label.add_theme_font_size_override("font_size", 20)
	track_desc_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	track_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_desc_label.position = Vector2(360, 660)
	track_desc_label.size = Vector2(1200, 80)
	bg.add_child(track_desc_label)

	difficulty_label = Label.new()
	difficulty_label.add_theme_font_size_override("font_size", 22)
	difficulty_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.position = Vector2(0, 760)
	difficulty_label.size = Vector2(1920, 30)
	bg.add_child(difficulty_label)

	length_label = Label.new()
	length_label.add_theme_font_size_override("font_size", 20)
	length_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	length_label.position = Vector2(0, 795)
	length_label.size = Vector2(1920, 30)
	bg.add_child(length_label)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.position = Vector2(0, 880)
	btn_box.size = Vector2(1920, 60)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 30)
	bg.add_child(btn_box)

	var back_btn := _create_button("BACK", SURFACE)
	btn_box.add_child(back_btn)
	back_btn.pressed.connect(_on_back)

	continue_btn = _create_button("CONTINUE", PRIMARY_ACCENT)
	btn_box.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue)

func _create_track_card(index: int, color_index: int = 0) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(280, 380)

	var track_data: Resource = GameManager.get_track_data(index)
	var is_available: bool = track_data != null

	var color: Color = TRACK_COLORS[color_index] if color_index < TRACK_COLORS.size() else TRACK_COLORS[0]

	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_MID
	sb.set_corner_radius_all(12)
	sb.border_width_top = 6
	sb.border_color = color
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("normal", sb)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = BG_MID.lightened(0.08)
	sb_hover.set_corner_radius_all(12)
	sb_hover.border_width_top = 6
	sb_hover.border_color = color
	sb_hover.content_margin_left = 20
	sb_hover.content_margin_right = 20
	sb_hover.content_margin_top = 20
	sb_hover.content_margin_bottom = 20
	card.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = BG_MID.darkened(0.05)
	sb_pressed.set_corner_radius_all(12)
	sb_pressed.border_width_top = 6
	sb_pressed.border_color = color
	sb_pressed.content_margin_left = 20
	sb_pressed.content_margin_right = 20
	sb_pressed.content_margin_top = 20
	sb_pressed.content_margin_bottom = 20
	card.add_theme_stylebox_override("pressed", sb_pressed)

	if is_available:
		card.text = track_data.track_name
		card.add_theme_font_size_override("font_size", 24)
		card.add_theme_color_override("font_color", TEXT_PRIMARY)
		card.pressed.connect(_select_track.bind(index))
	else:
		card.text = "COMING SOON"
		card.add_theme_font_size_override("font_size", 22)
		card.add_theme_color_override("font_color", TEXT_SECONDARY)
		card.disabled = true

	return card

func _select_track(index: int) -> void:
	selected_index = index
	var track_data: Resource = GameManager.get_track_data(index)
	if not track_data:
		return

	GameManager.selected_track_index = index
	track_name_label.text = track_data.track_name
	track_desc_label.text = track_data.description

	var stars: String = ""
	for i in range(track_data.difficulty):
		stars += "★"
	for i in range(3 - track_data.difficulty):
		stars += "☆"
	difficulty_label.text = "DIFFICULTY  %s" % stars
	length_label.text = "LENGTH  %.1f km" % track_data.length_km

func _on_back() -> void:
	GameManager.transition_to_scene("res://scenes/main.tscn")

func _on_continue() -> void:
	GameManager.transition_to_scene("res://ui/race_setup/race_setup.tscn")

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
