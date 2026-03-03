extends CanvasLayer

## Race HUD: top bar (position, lap, timer), speed display bottom-right,
## best lap label, and last-lap notification.

var player_car: VehicleBody3D

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

# Speed display
const SPEED_FONT_SIZE := 96
const BAR_WIDTH := 150
const BAR_HEIGHT := 6
var speed_label: Label
var throttle_bar: ColorRect
var brake_bar: ColorRect

func _ready() -> void:
	_build_top_bar()
	_build_info_labels()
	_build_speed_display()
	RaceManager.lap_completed.connect(_on_lap_completed)

func set_player_car(car: VehicleBody3D) -> void:
	player_car = car

# --- Build UI ---

func _build_top_bar() -> void:
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_DARK, 0.7)
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, TOP_BAR_HEIGHT)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(40, 12)
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

func _build_info_labels() -> void:
	best_lap_label = Label.new()
	best_lap_label.text = ""
	best_lap_label.add_theme_font_size_override("font_size", 20)
	best_lap_label.add_theme_color_override("font_color", SUCCESS)
	best_lap_label.position = Vector2(40, TOP_BAR_HEIGHT + 10)
	add_child(best_lap_label)

	last_lap_label = Label.new()
	last_lap_label.text = ""
	last_lap_label.add_theme_font_size_override("font_size", 22)
	last_lap_label.add_theme_color_override("font_color", PRIMARY_ACCENT)
	last_lap_label.position = Vector2(40, TOP_BAR_HEIGHT + 36)
	last_lap_label.modulate.a = 0.0
	add_child(last_lap_label)

func _build_speed_display() -> void:
	# Background panel
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG_DARK, 0.5)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(1660, 860)
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

func _update_speed() -> void:
	speed_label.text = str(int(player_car.current_speed_kph))

func _update_lap() -> void:
	var completed: int = RaceManager.get_car_lap(player_car)
	var current_lap: int = mini(completed + 1, RaceManager.total_laps)
	lap_label.text = "LAP %d/%d" % [current_lap, RaceManager.total_laps]

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
