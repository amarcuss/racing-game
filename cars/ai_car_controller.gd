extends Node

## AI car controller — follows a Path3D curve around the track with
## difficulty-based speed/steering parameters, rubber-banding, and stuck detection.

enum Difficulty { EASY, MEDIUM, HARD }

@export var difficulty: Difficulty = Difficulty.MEDIUM

var car: VehicleBody3D
var ai_path: Path3D
var curve: Curve3D
var perimeter: float = 0.0

# Path tracking
var last_offset: float = 0.0

# Difficulty parameters
var speed_factor: float = 0.88
var speed_cap_kph: float = 170.0
var brake_distance_factor: float = 1.1
var steering_noise: float = 0.02
var look_ahead_base: float = 40.0

# Rubber-banding
var rubber_band_timer: float = 0.0
var rubber_band_multiplier: float = 1.0

# Stuck detection
var stuck_timer: float = 0.0
const STUCK_SPEED_THRESHOLD: float = 2.0
const STUCK_TIMEOUT: float = 3.0

func _ready() -> void:
	car = get_parent() as VehicleBody3D
	_apply_difficulty()

func setup(path: Path3D, track_perimeter: float) -> void:
	ai_path = path
	curve = path.curve
	perimeter = track_perimeter

func _apply_difficulty() -> void:
	match difficulty:
		Difficulty.EASY:
			speed_factor = 0.75
			speed_cap_kph = 140.0
			brake_distance_factor = 1.4
			steering_noise = 0.05
			look_ahead_base = 30.0
		Difficulty.MEDIUM:
			speed_factor = 0.85
			speed_cap_kph = 160.0
			brake_distance_factor = 1.1
			steering_noise = 0.02
			look_ahead_base = 40.0
		Difficulty.HARD:
			speed_factor = 0.92
			speed_cap_kph = 178.0
			brake_distance_factor = 0.95
			steering_noise = 0.0
			look_ahead_base = 50.0

func _physics_process(delta: float) -> void:
	if not car or not curve or not car.car_data:
		return
	if RaceManager.state != RaceManager.RaceState.RACING:
		car.set_inputs(0.0, 0.0, 0.0, false)
		return

	_update_rubber_banding(delta)
	var offset: float = _find_closest_offset()
	last_offset = offset

	var speed_kph: float = car.current_speed_kph
	var max_speed: float = minf(car.car_data.max_speed_kph * speed_factor, speed_cap_kph) * rubber_band_multiplier

	# Look-ahead distance scales with speed
	var speed_ratio: float = clampf(speed_kph / max_speed, 0.0, 1.0)
	var look_ahead: float = lerpf(20.0, look_ahead_base, speed_ratio)

	# Steering
	var steer_input: float = _compute_steering(offset, look_ahead)

	# Speed control via curvature
	var target_speed: float = _compute_target_speed(offset, look_ahead, max_speed)

	var throttle: float = 0.0
	var braking: float = 0.0

	if speed_kph < target_speed - 5.0:
		throttle = clampf((target_speed - speed_kph) / 30.0, 0.3, 1.0)
	elif speed_kph > target_speed + 5.0:
		braking = clampf((speed_kph - target_speed) / 40.0, 0.2, 1.0)
	else:
		throttle = 0.3

	car.set_inputs(throttle, braking, steer_input, false)
	_check_stuck(delta)

func _find_closest_offset() -> float:
	if not curve or curve.point_count < 2:
		return 0.0

	var car_pos: Vector3 = car.global_position
	var curve_length: float = curve.get_baked_length()

	# Check if too far — fallback to global search
	var test_pos: Vector3 = curve.sample_baked(last_offset)
	if car_pos.distance_to(test_pos) > 50.0:
		return curve.get_closest_offset(car_pos)

	# Local search ±30m in 1m steps
	var best_offset: float = last_offset
	var best_dist: float = 999999.0
	var search_range: float = 30.0

	var start_s: float = last_offset - search_range
	var end_s: float = last_offset + search_range

	var s: float = start_s
	while s <= end_s:
		var wrapped: float = fposmod(s, curve_length)
		var p: Vector3 = curve.sample_baked(wrapped)
		var d: float = car_pos.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best_offset = wrapped
		s += 1.0

	# Refine to 0.25m
	start_s = best_offset - 1.0
	end_s = best_offset + 1.0
	s = start_s
	while s <= end_s:
		var wrapped: float = fposmod(s, curve_length)
		var p: Vector3 = curve.sample_baked(wrapped)
		var d: float = car_pos.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best_offset = wrapped
		s += 0.25

	return best_offset

func _compute_steering(offset: float, look_ahead: float) -> float:
	var curve_length: float = curve.get_baked_length()
	var target_offset: float = fposmod(offset + look_ahead, curve_length)
	var target_pos: Vector3 = curve.sample_baked(target_offset)

	# Convert to car-local space
	var local: Vector3 = car.global_transform.affine_inverse() * target_pos
	var steer_angle: float = atan2(local.x, -local.z)

	# Normalize to [-1, 1]
	var max_steer: float = car.car_data.max_steering_angle
	var steer_input: float = clampf(steer_angle / max_steer, -1.0, 1.0)

	# Add difficulty noise
	if steering_noise > 0.0:
		steer_input += randf_range(-steering_noise, steering_noise)
		steer_input = clampf(steer_input, -1.0, 1.0)

	return steer_input

func _compute_target_speed(offset: float, look_ahead: float, max_speed: float) -> float:
	var curve_length: float = curve.get_baked_length()

	# Sample two points ahead to measure curvature
	var ahead1_offset: float = fposmod(offset + look_ahead * brake_distance_factor, curve_length)
	var ahead2_offset: float = fposmod(offset + look_ahead * brake_distance_factor * 1.5, curve_length)

	var p0: Vector3 = curve.sample_baked(fposmod(offset, curve_length))
	var p1: Vector3 = curve.sample_baked(ahead1_offset)
	var p2: Vector3 = curve.sample_baked(ahead2_offset)

	# Flatten to XZ plane so elevation changes don't register as curvature
	var dir1 := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()
	var dir2 := Vector3(p2.x - p1.x, 0.0, p2.z - p1.z).normalized()

	# Curvature = angle change between direction vectors
	var dot: float = clampf(dir1.dot(dir2), -1.0, 1.0)
	var curvature: float = acos(dot)

	# Map curvature to speed reduction
	var curvature_scale: float = 3.0
	var speed_mult: float = clampf(1.0 - curvature * curvature_scale, 0.4, 1.0)

	return max_speed * speed_mult

func _update_rubber_banding(delta: float) -> void:
	rubber_band_timer += delta
	if rubber_band_timer < 1.0:
		return
	rubber_band_timer = 0.0

	var pos: int = RaceManager.get_car_position(car)
	var total: int = RaceManager.registered_cars.size()

	if pos == total and total > 1:
		rubber_band_multiplier = 1.06
	elif pos == 1 and total > 1:
		rubber_band_multiplier = 0.96
	else:
		rubber_band_multiplier = 1.0

func _check_stuck(delta: float) -> void:
	if car.current_speed_kph < STUCK_SPEED_THRESHOLD:
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	if stuck_timer >= STUCK_TIMEOUT:
		_unstick()

func _unstick() -> void:
	stuck_timer = 0.0
	if not curve:
		car.reset_to_track()
		return

	# Teleport to nearest curve point facing forward
	var offset: float = _find_closest_offset()
	var curve_length: float = curve.get_baked_length()
	var pos: Vector3 = curve.sample_baked(offset) + Vector3.UP * 1.5

	# Get forward direction from curve
	var ahead_offset: float = fposmod(offset + 2.0, curve_length)
	var ahead_pos: Vector3 = curve.sample_baked(ahead_offset)
	var forward: Vector3 = (ahead_pos - pos).normalized()
	forward.y = 0.0
	forward = forward.normalized()

	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO

	# Build right-handed basis facing forward (car's -Z = forward)
	var z_axis: Vector3 = -forward
	var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)

	car.global_transform = Transform3D(basis, pos)
