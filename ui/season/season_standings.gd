extends Node

## Season standings: team or individual championship table. Adapts to season mode.

const BG_DARK := Color("0A0E1A")
const BG_MID := Color("141B2D")
const PRIMARY_ACCENT := Color("FF6B1A")
const SURFACE := Color("1E2740")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")
const GOLD := Color("FFD700")
const SILVER := Color("C0C0C0")
const BRONZE := Color("CD7F32")

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

	var calendar: Array = GameManager.get_season_calendar()
	var just_finished: int = GameManager.season_results.size()
	var is_season_over: bool = just_finished >= calendar.size()
	var season_title: String = GameManager.get_season_title()
	var is_team: bool = GameManager.is_team_season()

	# Title
	var title := Label.new()
	if is_season_over:
		title.text = "%s - COMPLETE" % season_title
	else:
		var round_name: String = calendar[just_finished - 1].name if just_finished > 0 else ""
		title.text = "ROUND %d / %d  -  %s" % [just_finished, calendar.size(), round_name]
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1920, 50)
	bg.add_child(title)

	var accent := ColorRect.new()
	accent.color = PRIMARY_ACCENT
	accent.position = Vector2(810, 75)
	accent.size = Vector2(300, 3)
	bg.add_child(accent)

	# Subtitle
	var subtitle := Label.new()
	if is_team:
		subtitle.text = "CONSTRUCTORS' STANDINGS"
	else:
		subtitle.text = "DRIVER STANDINGS"
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", TEXT_SECONDARY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 88)
	subtitle.size = Vector2(1920, 35)
	bg.add_child(subtitle)

	# Standings table
	var table_panel := ColorRect.new()
	table_panel.color = BG_MID
	table_panel.position = Vector2(260, 135)
	table_panel.size = Vector2(1400, 640)
	bg.add_child(table_panel)

	# Header row
	var header := HBoxContainer.new()
	header.position = Vector2(30, 12)
	header.size = Vector2(1340, 30)
	header.add_theme_constant_override("separation", 0)
	table_panel.add_child(header)

	if is_team:
		_add_header_label(header, "POS", 60)
		_add_header_label(header, "TEAM", 320)
		_add_header_label(header, "TOTAL", 100)
		_add_header_label(header, "DRIVER 1", 180)
		_add_header_label(header, "DRIVER 2", 180)
		_add_header_label(header, "LAST RACE", 200)
	else:
		_add_header_label(header, "POS", 60)
		_add_header_label(header, "DRIVER", 420)
		_add_header_label(header, "POINTS", 150)
		_add_header_label(header, "LAST RACE", 150)

	var header_line := ColorRect.new()
	header_line.color = TEXT_SECONDARY
	header_line.position = Vector2(30, 45)
	header_line.size = Vector2(1340, 1)
	table_panel.add_child(header_line)

	# Get last race results
	var last_race_d1: Dictionary = {}
	var last_race_d2: Dictionary = {}
	if GameManager.season_results.size() > 0:
		var last_round: Array = GameManager.season_results[GameManager.season_results.size() - 1]
		for entry in last_round:
			if entry.driver_slot == 1:
				last_race_d1[entry.car_index] = entry.position
			else:
				last_race_d2[entry.car_index] = entry.position

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 50)
	scroll.size = Vector2(1340, 580)
	table_panel.add_child(scroll)

	var rows_container := VBoxContainer.new()
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_container.add_theme_constant_override("separation", 2)
	scroll.add_child(rows_container)

	var car_indices: Array[int] = GameManager.get_season_car_indices()

	if is_team:
		_build_team_standings(rows_container, car_indices, last_race_d1, last_race_d2)
	else:
		_build_individual_standings(rows_container, car_indices, last_race_d1)

	# Champion banner
	if is_season_over:
		var champ_label := Label.new()
		if is_team:
			var sorted_teams: Array = _get_sorted_teams(car_indices)
			if sorted_teams.size() > 0:
				var champion_idx: int = sorted_teams[0].car_index
				var champion_name: String = GameManager.get_team_name(champion_idx)
				if champion_idx == GameManager.season_player_car_index:
					champ_label.text = "YOUR TEAM WINS THE %s!" % season_title
				else:
					champ_label.text = "%s WINS THE %s" % [champion_name.to_upper(), season_title]
		else:
			var sorted_drivers: Array = _get_sorted_drivers(car_indices)
			if sorted_drivers.size() > 0:
				var winner: Dictionary = sorted_drivers[0]
				if winner.car_index == GameManager.season_player_car_index:
					champ_label.text = "YOU ARE THE %s CHAMPION!" % season_title
				else:
					var winner_name: String = GameManager.get_team_name(winner.car_index)
					champ_label.text = "%s WINS THE %s" % [winner_name.to_upper(), season_title]
		champ_label.add_theme_font_size_override("font_size", 34)
		champ_label.add_theme_color_override("font_color", GOLD)
		champ_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		champ_label.position = Vector2(0, 790)
		champ_label.size = Vector2(1920, 50)
		bg.add_child(champ_label)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.position = Vector2(0, 860)
	btn_box.size = Vector2(1920, 60)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 30)
	bg.add_child(btn_box)

	if is_season_over:
		var menu_btn := _create_button("MAIN MENU", PRIMARY_ACCENT)
		btn_box.add_child(menu_btn)
		menu_btn.pressed.connect(func():
			GameManager.end_season()
			GameManager.go_to_main_menu()
		)
	else:
		var next_round_idx: int = GameManager.season_current_round + 1
		if next_round_idx >= calendar.size():
			next_round_idx = calendar.size() - 1
		var next_round_data: Dictionary = calendar[next_round_idx]
		var next_info := Label.new()
		next_info.text = "NEXT: R%02d - %s" % [next_round_idx + 1, next_round_data.name]
		next_info.add_theme_font_size_override("font_size", 22)
		next_info.add_theme_color_override("font_color", TEXT_SECONDARY)
		next_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_info.position = Vector2(0, 830)
		next_info.size = Vector2(1920, 30)
		bg.add_child(next_info)

		var next_btn := _create_button("NEXT RACE", PRIMARY_ACCENT)
		btn_box.add_child(next_btn)
		next_btn.pressed.connect(func():
			GameManager.advance_season()
		)

		var quit_btn := _create_button("QUIT SEASON", SURFACE)
		btn_box.add_child(quit_btn)
		quit_btn.pressed.connect(func():
			GameManager.end_season()
			GameManager.go_to_main_menu()
		)

# --- Individual driver standings ---

func _get_sorted_drivers(car_indices: Array[int]) -> Array:
	var drivers: Array = []
	for car_idx in car_indices:
		var pts: int = GameManager.get_driver_points(car_idx, 1)
		drivers.append({"car_index": car_idx, "points": pts})
	drivers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.points > b.points)
	return drivers

func _build_individual_standings(rows_container: VBoxContainer, car_indices: Array[int], last_race: Dictionary) -> void:
	var sorted_drivers: Array = _get_sorted_drivers(car_indices)

	for i in range(sorted_drivers.size()):
		var data: Dictionary = sorted_drivers[i]
		var car_idx: int = data.car_index
		var pts: int = data.points
		var car_data: Resource = GameManager.get_car_data(car_idx)
		var driver_name: String = GameManager.get_team_name(car_idx)
		var is_player: bool = car_idx == GameManager.season_player_car_index

		var row_panel := Panel.new()
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(PRIMARY_ACCENT, 0.12) if is_player else Color(0, 0, 0, 0)
		row_sb.set_corner_radius_all(4)
		row_panel.add_theme_stylebox_override("panel", row_sb)
		row_panel.custom_minimum_size = Vector2(1340, 52)
		rows_container.add_child(row_panel)

		var row := HBoxContainer.new()
		row.position = Vector2(0, 0)
		row.size = Vector2(1340, 52)
		row.add_theme_constant_override("separation", 0)
		row_panel.add_child(row)

		# Position
		var pos_label := Label.new()
		pos_label.text = str(i + 1)
		pos_label.add_theme_font_size_override("font_size", 22)
		var pos_color: Color = TEXT_PRIMARY
		if i == 0: pos_color = GOLD
		elif i == 1: pos_color = SILVER
		elif i == 2: pos_color = BRONZE
		pos_label.add_theme_color_override("font_color", pos_color)
		pos_label.custom_minimum_size = Vector2(60, 52)
		pos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pos_label)

		# Color bar
		var color_bar := ColorRect.new()
		color_bar.custom_minimum_size = Vector2(6, 36)
		color_bar.color = car_data.body_color if car_data else TEXT_SECONDARY
		row.add_child(color_bar)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		row.add_child(spacer)

		# Driver/entry name
		var name_label := Label.new()
		name_label.text = driver_name
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", PRIMARY_ACCENT if is_player else TEXT_PRIMARY)
		name_label.custom_minimum_size = Vector2(404, 52)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		# Points
		var pts_label := Label.new()
		pts_label.text = str(pts)
		pts_label.add_theme_font_size_override("font_size", 24)
		pts_label.add_theme_color_override("font_color", TEXT_PRIMARY)
		pts_label.custom_minimum_size = Vector2(150, 52)
		pts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pts_label)

		# Last race
		var last_pos: int = last_race.get(car_idx, -1)
		var last_label := Label.new()
		last_label.text = "P%d" % last_pos if last_pos > 0 else "-"
		last_label.add_theme_font_size_override("font_size", 20)
		last_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		last_label.custom_minimum_size = Vector2(150, 52)
		last_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(last_label)

# --- Team standings (F1 constructors) ---

func _get_sorted_teams(car_indices: Array[int]) -> Array:
	var teams: Array = []
	for car_idx in car_indices:
		var total: int = GameManager.get_team_points(car_idx)
		teams.append({"car_index": car_idx, "points": total})
	teams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.points > b.points)
	return teams

func _build_team_standings(rows_container: VBoxContainer, car_indices: Array[int], last_d1: Dictionary, last_d2: Dictionary) -> void:
	var sorted_teams: Array = _get_sorted_teams(car_indices)

	for i in range(sorted_teams.size()):
		var team_data: Dictionary = sorted_teams[i]
		var car_idx: int = team_data.car_index
		var total_pts: int = team_data.points
		var d1_pts: int = GameManager.get_driver_points(car_idx, 1)
		var d2_pts: int = GameManager.get_driver_points(car_idx, 2)
		var car_data: Resource = GameManager.get_car_data(car_idx)
		var team_name: String = GameManager.get_team_name(car_idx)
		var is_player_team: bool = car_idx == GameManager.season_player_car_index

		var row_panel := Panel.new()
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(PRIMARY_ACCENT, 0.12) if is_player_team else Color(0, 0, 0, 0)
		row_sb.set_corner_radius_all(4)
		row_panel.add_theme_stylebox_override("panel", row_sb)
		row_panel.custom_minimum_size = Vector2(1340, 52)
		rows_container.add_child(row_panel)

		var row := HBoxContainer.new()
		row.position = Vector2(0, 0)
		row.size = Vector2(1340, 52)
		row.add_theme_constant_override("separation", 0)
		row_panel.add_child(row)

		# Position
		var pos_label := Label.new()
		pos_label.text = str(i + 1)
		pos_label.add_theme_font_size_override("font_size", 22)
		var pos_color: Color = TEXT_PRIMARY
		if i == 0: pos_color = GOLD
		elif i == 1: pos_color = SILVER
		elif i == 2: pos_color = BRONZE
		pos_label.add_theme_color_override("font_color", pos_color)
		pos_label.custom_minimum_size = Vector2(60, 52)
		pos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pos_label)

		# Color bar
		var color_bar := ColorRect.new()
		color_bar.custom_minimum_size = Vector2(6, 36)
		color_bar.color = car_data.body_color if car_data else TEXT_SECONDARY
		row.add_child(color_bar)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		row.add_child(spacer)

		# Team name
		var name_label := Label.new()
		name_label.text = team_name
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", PRIMARY_ACCENT if is_player_team else TEXT_PRIMARY)
		name_label.custom_minimum_size = Vector2(304, 52)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		# Total
		var total_label := Label.new()
		total_label.text = str(total_pts)
		total_label.add_theme_font_size_override("font_size", 24)
		total_label.add_theme_color_override("font_color", TEXT_PRIMARY)
		total_label.custom_minimum_size = Vector2(100, 52)
		total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(total_label)

		# Driver 1
		var d1_label := Label.new()
		d1_label.text = ("YOU: %d" % d1_pts) if is_player_team else ("%d pts" % d1_pts)
		d1_label.add_theme_font_size_override("font_size", 20)
		d1_label.add_theme_color_override("font_color", PRIMARY_ACCENT if is_player_team else TEXT_SECONDARY)
		d1_label.custom_minimum_size = Vector2(180, 52)
		d1_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(d1_label)

		# Driver 2
		var d2_label := Label.new()
		d2_label.text = ("TEAMMATE: %d" % d2_pts) if is_player_team else ("%d pts" % d2_pts)
		d2_label.add_theme_font_size_override("font_size", 20)
		d2_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		d2_label.custom_minimum_size = Vector2(180, 52)
		d2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(d2_label)

		# Last race
		var d1_pos: int = last_d1.get(car_idx, -1)
		var d2_pos: int = last_d2.get(car_idx, -1)
		var last_text: String
		if d1_pos > 0 and d2_pos > 0:
			last_text = "P%d  P%d" % [d1_pos, d2_pos]
		elif d1_pos > 0:
			last_text = "P%d  -" % d1_pos
		elif d2_pos > 0:
			last_text = "-  P%d" % d2_pos
		else:
			last_text = "-"
		var last_label := Label.new()
		last_label.text = last_text
		last_label.add_theme_font_size_override("font_size", 20)
		last_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		last_label.custom_minimum_size = Vector2(200, 52)
		last_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(last_label)

# --- Helpers ---

func _add_header_label(parent: HBoxContainer, text: String, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.custom_minimum_size = Vector2(width, 30)
	parent.add_child(label)

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
