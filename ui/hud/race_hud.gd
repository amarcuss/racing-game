extends CanvasLayer

## Race HUD: top bar (position, lap, timer), speed display bottom-right,
## best lap label, and last-lap notification.

var player_car: VehicleBody3D

# Layout (configurable for split-screen)
var screen_offset_x: float = 0.0
var screen_width: float = 1920.0

# Colors
const BG_DARK := Color("0A0E1A")
const PRIMARY_ACCENT := Color("FF6B1A")
const SECONDARY_ACCENT := Color("00D4FF")
const SUCCESS := Color("7FFF00")
const DANGER := Color("FF2244")
const TEXT_PRIMARY := Color("F0F0F0")
const TEXT_SECONDARY := Color("8899AA")

# Top bar
const TOP_BAR_HEIGHT := 56
var position_label: Label
var lap_label: Label
var timer_label: Label

# Below top bar
var best_lap_label: Label
var last_lap_label: Label
var last_lap_tween: Tween

# Position tracking
var last_position: int = 1
var position_flash_tween: Tween

# Minimap
const MINIMAP_SIZE := 160
const MINIMAP_MARGIN := 16
var minimap_panel: Panel
var minimap_draw: Control
var minimap_track_points: PackedVector2Array
var minimap_bounds_min: Vector2
var minimap_bounds_max: Vector2
var minimap_initialized: bool = false

# Speed display
const SPEED_FONT_SIZE := 96
const BAR_WIDTH := 150
const BAR_HEIGHT := 6
var speed_label: Label
var throttle_bar: ColorRect
var brake_bar: ColorRect

# DRS indicator (F1 only)
var drs_label: Label
var is_f1_mode: bool = false

func _ready() -> void:
	is_f1_mode = GameManager.racing_mode == GameManager.RacingMode.F1
	_build_top_bar()
	_build_info_labels()
	_build_speed_display()
	_build_minimap()
	if is_f1_mode:
		_build_drs_indicator()
	RaceManager.lap_completed.connect(_on_lap_completed)

func set_player_car(car: VehicleBody3D) -> void:
	player_car = car

func configure_layout(offset_x: float, width: float) -> void:
	screen_offset_x = offset_x
	screen_width = width

# --- Build UI ---

func _build_top_bar() -> void:
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_DARK, 0.7)
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(screen_offset_x, 0)
	bar.size = Vector2(screen_width, TOP_BAR_HEIGHT)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(20, 12)
	hbox.add_theme_constant_override("separation", 20)
	bar.add_child(hbox)

	# Position
	position_label = Label.new()
	position_label.text = "1ST"
	position_label.add_theme_font_size_override("font_size", 28)
	position_label.add_theme_color_override("font_color", SECONDARY_ACCENT)
	position_label.add_theme_constant_override("outline_size", 2)
	position_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	hbox.add_child(position_label)

	var sep1 := Label.new()
	sep1.text = "\u00b7"
	sep1.add_theme_font_size_override("font_size", 28)
	sep1.add_theme_color_override("font_color", TEXT_SECONDARY)
	hbox.add_child(sep1)

	# Lap
	lap_label = Label.new()
	lap_label.text = "LAP 1/3"
	lap_label.add_theme_font_size_override("font_size", 28)
	lap_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	hbox.add_child(lap_label)

	var sep2 := Label.new()
	sep2.text = "\u00b7"
	sep2.add_theme_font_size_override("font_size", 28)
	sep2.add_theme_color_override("font_color", TEXT_SECONDARY)
	hbox.add_child(sep2)

	# Timer
	timer_label = Label.new()
	timer_label.text = "00:00.000"
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	hbox.add_child(timer_label)

	# Season GP name (right side of top bar)
	if GameManager.season_active:
		var calendar: Array = GameManager.get_season_calendar()
		if GameManager.season_current_round >= calendar.size():
			return
		var round_data: Dictionary = calendar[GameManager.season_current_round]
		var gp_label := Label.new()
		gp_label.text = "R%d  %s" % [GameManager.season_current_round + 1, round_data.name]
		gp_label.add_theme_font_size_override("font_size", 22)
		gp_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
		gp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gp_label.position = Vector2(screen_offset_x, 16)
		gp_label.size = Vector2(screen_width - 20, 30)
		bar.add_child(gp_label)

func _build_info_labels() -> void:
	best_lap_label = Label.new()
	best_lap_label.text = ""
	best_lap_label.add_theme_font_size_override("font_size", 20)
	best_lap_label.add_theme_color_override("font_color", SUCCESS)
	best_lap_label.position = Vector2(screen_offset_x + 20, TOP_BAR_HEIGHT + 10)
	add_child(best_lap_label)

	last_lap_label = Label.new()
	last_lap_label.text = ""
	last_lap_label.add_theme_font_size_override("font_size", 22)
	last_lap_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	last_lap_label.position = Vector2(screen_offset_x + 20, TOP_BAR_HEIGHT + 36)
	last_lap_label.modulate.a = 0.0
	add_child(last_lap_label)

func _build_speed_display() -> void:
	# Background panel
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_DARK, 0.5)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(screen_offset_x + screen_width - 260, 860)
	panel.size = Vector2(220, 180)
	add_child(panel)

	# Speed number
	speed_label = Label.new()
	speed_label.text = "0"
	speed_label.add_theme_font_size_override("font_size", SPEED_FONT_SIZE)
	speed_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	speed_label.add_theme_constant_override("outline_size", 3)
	speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.position = Vector2(10, 4)
	speed_label.size = Vector2(200, 100)
	panel.add_child(speed_label)

	# km/h
	var unit_label := Label.new()
	unit_label.text = "km/h"
	unit_label.add_theme_font_size_override("font_size", 22)
	unit_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unit_label.position = Vector2(10, 106)
	unit_label.size = Vector2(200, 28)
	panel.add_child(unit_label)

	# Throttle bar background
	var throttle_bg := ColorRect.new()
	throttle_bg.color = Color(0.15, 0.15, 0.2, 0.5)
	throttle_bg.position = Vector2(35, 142)
	throttle_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	panel.add_child(throttle_bg)

	# Throttle bar fill
	throttle_bar = ColorRect.new()
	throttle_bar.color = PRIMARY_ACCENT
	throttle_bar.position = Vector2(35, 142)
	throttle_bar.size = Vector2(0, BAR_HEIGHT)
	panel.add_child(throttle_bar)

	# Brake bar background
	var brake_bg := ColorRect.new()
	brake_bg.color = Color(0.15, 0.15, 0.2, 0.5)
	brake_bg.position = Vector2(35, 156)
	brake_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	panel.add_child(brake_bg)

	# Brake bar fill
	brake_bar = ColorRect.new()
	brake_bar.color = DANGER
	brake_bar.position = Vector2(35, 156)
	brake_bar.size = Vector2(0, BAR_HEIGHT)
	panel.add_child(brake_bar)

func _build_drs_indicator() -> void:
	drs_label = Label.new()
	drs_label.text = "DRS"
	drs_label.add_theme_font_size_override("font_size", 32)
	drs_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	drs_label.add_theme_constant_override("outline_size", 3)
	drs_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	drs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drs_label.position = Vector2(screen_offset_x + screen_width - 260, 830)
	drs_label.size = Vector2(220, 40)
	drs_label.modulate.a = 0.3
	add_child(drs_label)

func _build_minimap() -> void:
	minimap_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_DARK, 0.6)
	sb.set_corner_radius_all(8)
	minimap_panel.add_theme_stylebox_override("panel", sb)
	minimap_panel.position = Vector2(screen_offset_x + screen_width - MINIMAP_SIZE - MINIMAP_MARGIN, TOP_BAR_HEIGHT + MINIMAP_MARGIN)
	minimap_panel.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	add_child(minimap_panel)

	minimap_draw = Control.new()
	minimap_draw.position = Vector2.ZERO
	minimap_draw.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	minimap_draw.draw.connect(_on_minimap_draw)
	minimap_panel.add_child(minimap_draw)

func _init_minimap_track() -> void:
	if not player_car or not player_car.track_path:
		return
	var curve: Curve3D = player_car.track_path.curve
	if not curve or curve.get_baked_length() < 1.0:
		return

	var total_len: float = curve.get_baked_length()
	var num_samples: int = 64
	var points: PackedVector2Array = PackedVector2Array()
	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)

	for i in range(num_samples):
		var offset: float = (float(i) / float(num_samples)) * total_len
		var pos3d: Vector3 = curve.sample_baked(offset)
		var pt := Vector2(pos3d.x, pos3d.z)
		points.append(pt)
		min_pt.x = minf(min_pt.x, pt.x)
		min_pt.y = minf(min_pt.y, pt.y)
		max_pt.x = maxf(max_pt.x, pt.x)
		max_pt.y = maxf(max_pt.y, pt.y)

	minimap_bounds_min = min_pt
	minimap_bounds_max = max_pt
	minimap_track_points = points
	minimap_initialized = true

func _world_to_minimap(world_pos: Vector3) -> Vector2:
	var pt := Vector2(world_pos.x, world_pos.z)
	var range_vec: Vector2 = minimap_bounds_max - minimap_bounds_min
	var padding: float = 12.0
	var draw_size: float = MINIMAP_SIZE - padding * 2.0
	var scale_val: float = draw_size / maxf(range_vec.x, range_vec.y)
	var centered: Vector2 = pt - minimap_bounds_min - range_vec * 0.5
	return Vector2(MINIMAP_SIZE * 0.5 + centered.x * scale_val, MINIMAP_SIZE * 0.5 + centered.y * scale_val)

func _on_minimap_draw() -> void:
	if not minimap_initialized:
		_init_minimap_track()
	if not minimap_initialized:
		return

	# Draw track outline
	var scaled_points: PackedVector2Array = PackedVector2Array()
	for pt in minimap_track_points:
		var range_vec: Vector2 = minimap_bounds_max - minimap_bounds_min
		var padding: float = 12.0
		var draw_size: float = MINIMAP_SIZE - padding * 2.0
		var scale_val: float = draw_size / maxf(range_vec.x, range_vec.y)
		var centered: Vector2 = pt - minimap_bounds_min - range_vec * 0.5
		scaled_points.append(Vector2(MINIMAP_SIZE * 0.5 + centered.x * scale_val, MINIMAP_SIZE * 0.5 + centered.y * scale_val))
	# Close the loop (only for circuit tracks)
	if scaled_points.size() > 1 and not RaceManager.is_point_to_point:
		scaled_points.append(scaled_points[0])
	minimap_draw.draw_polyline(scaled_points, Color(0.5, 0.5, 0.6, 0.6), 2.0, true)

	# Draw car dots
	for car in RaceManager.registered_cars:
		if not is_instance_valid(car):
			continue
		var map_pos: Vector2 = _world_to_minimap(car.global_position)
		var dot_color: Color = SECONDARY_ACCENT if car == player_car else DANGER
		minimap_draw.draw_circle(map_pos, 4.0, dot_color)

# --- Update loop ---

func _process(_delta: float) -> void:
	if not player_car:
		return
	_update_speed()
	_update_lap()
	_update_timer()
	_update_best_lap()
	_update_input_bars()
	_update_position()
	if is_f1_mode:
		_update_drs()
	if minimap_draw:
		minimap_draw.queue_redraw()

func _update_speed() -> void:
	speed_label.text = str(int(player_car.current_speed_kph))

func _update_lap() -> void:
	if RaceManager.is_point_to_point:
		# Show checkpoint progress instead of laps
		var cp_hit: int = _count_player_checkpoints()
		var cp_total: int = RaceManager.num_checkpoints
		lap_label.text = "CP %d/%d" % [cp_hit, cp_total]
	else:
		var completed: int = RaceManager.get_car_lap(player_car)
		var current_lap: int = mini(completed + 1, RaceManager.total_laps)
		lap_label.text = "LAP %d/%d" % [current_lap, RaceManager.total_laps]

func _count_player_checkpoints() -> int:
	var flags: Array = RaceManager.car_checkpoints.get(player_car, [])
	var count: int = 0
	for hit in flags:
		if hit:
			count += 1
	return count

func _update_timer() -> void:
	timer_label.text = _format_time(RaceManager.race_time)

func _update_best_lap() -> void:
	var best: float = RaceManager.get_car_best_lap_time(player_car)
	if best > 0.0:
		best_lap_label.text = "BEST  %s" % _format_time(best)
	else:
		best_lap_label.text = ""

func _update_position() -> void:
	var pos: int = RaceManager.get_car_position(player_car)
	var total: int = RaceManager.registered_cars.size()
	position_label.text = "%s / %d" % [_ordinal(pos), total]
	if pos != last_position:
		last_position = pos
		# Flash color on position change
		position_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
		if position_flash_tween and position_flash_tween.is_valid():
			position_flash_tween.kill()
		position_flash_tween = create_tween()
		position_flash_tween.tween_callback(func():
			position_label.add_theme_color_override("font_color", SECONDARY_ACCENT)
		).set_delay(0.5)

func _update_input_bars() -> void:
	throttle_bar.size.x = BAR_WIDTH * player_car.throttle_input
	brake_bar.size.x = BAR_WIDTH * player_car.brake_input

func _update_drs() -> void:
	if not drs_label or not player_car:
		return
	if player_car.drs_active:
		drs_label.add_theme_color_override("font_color", SUCCESS)
		drs_label.modulate.a = 1.0
	elif player_car.drs_available:
		drs_label.add_theme_color_override("font_color", SECONDARY_ACCENT)
		drs_label.modulate.a = 1.0
	else:
		drs_label.add_theme_color_override("font_color", TEXT_SECONDARY)
		drs_label.modulate.a = 0.3

# --- Signals ---

func _on_lap_completed(car: Node, lap: int) -> void:
	if car != player_car:
		return
	var last_time: float = RaceManager.get_car_last_lap_time(car)
	last_lap_label.text = "LAP %d  \u2014  %s" % [lap, _format_time(last_time)]
	last_lap_label.modulate.a = 1.0
	if last_lap_tween and last_lap_tween.is_valid():
		last_lap_tween.kill()
	last_lap_tween = create_tween()
	last_lap_tween.tween_property(last_lap_label, "modulate:a", 0.0, 2.0).set_delay(1.5)

# --- Helpers ---

func _ordinal(pos: int) -> String:
	match pos:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % pos

func _format_time(time: float) -> String:
	var mins: int = int(time) / 60
	var secs: float = fmod(time, 60.0)
	return "%02d:%06.3f" % [mins, secs]
