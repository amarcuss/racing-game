extends Node

## AI car controller — follows a Path3D curve around the track with
## difficulty-based speed/steering parameters, rubber-banding, and stuck detection.
## Adapts look-ahead, braking, and steering for high-speed F1 cars (tier 4).

enum Difficulty { EASY, MEDIUM, HARD }

@export var difficulty: Difficulty = Difficulty.MEDIUM

var car: VehicleBody3D
var ai_path: Path3D
var curve: Curve3D
var perimeter: float = 0.0

# Path tracking
var last_offset: float = 0.0
var open_path: bool = false

# Difficulty parameters
var speed_factor: float = 0.88
var brake_distance_factor: float = 1.1
var steering_noise: float = 0.02
var look_ahead_base: float = 40.0

# Steering smoothing
var prev_steer: float = 0.0

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
			speed_factor = 0.78
			brake_distance_factor = 1.4
			steering_noise = 0.05
			look_ahead_base = 30.0
		Difficulty.MEDIUM:
			speed_factor = 0.88
			brake_distance_factor = 1.1
			steering_noise = 0.02
			look_ahead_base = 40.0
		Difficulty.HARD:
			speed_factor = 0.95
			brake_distance_factor = 0.95
			steering_noise = 0.0
			look_ahead_base = 50.0

func _is_f1() -> bool:
	return car and car.car_data and car.car_data.tier == 4

func _physics_process(delta: float) -> void:
	if not car or not curve or not car.car_data:
		return
	if RaceManager.state != RaceManager.RaceState.RACING:
		car.set_inputs(0.0, 0.0, 0.0, false)
		return
	if RaceManager.car_finished.get(car, false):
		car.set_inputs(0.0, 1.0, 0.0, false)
		return

	_update_rubber_banding(delta)
	var offset: float = _find_closest_offset()
	last_offset = offset

	# Point-to-point: slow down near finish
	if open_path:
		var curve_length: float = curve.get_baked_length()
		var remaining: float = curve_length - offset
		if remaining < 10.0:
			car.set_inputs(0.0, 1.0, 0.0, false)
			return

	var speed_kph: float = car.current_speed_kph
	var max_speed: float = car.car_data.max_speed_kph * speed_factor * rubber_band_multiplier

	var speed_ratio: float = clampf(speed_kph / max_speed, 0.0, 1.0)

	# --- Steering look-ahead: scales with speed ---
	var steer_look_ahead: float
	if _is_f1():
		steer_look_ahead = lerpf(25.0, 70.0, speed_ratio)
	else:
		steer_look_ahead = lerpf(20.0, look_ahead_base, speed_ratio)

	var steer_input: float = _compute_steering(offset, steer_look_ahead)

	# Smooth steering only at high speed (>200 kph) to prevent oscillation,
	# but allow full authority at low speed for hairpins
	if _is_f1() and speed_kph > 200.0:
		var high_speed_ratio: float = clampf((speed_kph - 200.0) / 100.0, 0.0, 1.0)
		var smooth_alpha: float = lerpf(1.0, 0.15, high_speed_ratio)
		steer_input = lerpf(prev_steer, steer_input, clampf(smooth_alpha * 120.0 * delta, 0.0, 1.0))
	prev_steer = steer_input

	# --- Brake look-ahead: much further than steering, especially for F1 ---
	var brake_look_ahead: float
	if _is_f1():
		# At 300 kph (~83 m/s), need to see 250m+ ahead to brake in time
		brake_look_ahead = lerpf(40.0, 250.0, speed_ratio)
	else:
		brake_look_ahead = lerpf(20.0, look_ahead_base * brake_distance_factor, speed_ratio)

	var target_speed: float = _compute_target_speed(offset, brake_look_ahead, max_speed)

	var throttle: float = 0.0
	var braking: float = 0.0

	var speed_over: float = speed_kph - target_speed
	var speed_under: float = target_speed - speed_kph

	if _is_f1():
		if speed_over > 5.0:
			# Aggressive braking — the further over target, the harder we brake
			braking = clampf(speed_over / 50.0, 0.3, 1.0)
		elif speed_under > 10.0:
			throttle = clampf(speed_under / 50.0, 0.3, 1.0)
		else:
			throttle = 0.25
	else:
		if speed_over > 5.0:
			braking = clampf(speed_over / 40.0, 0.2, 1.0)
		elif speed_under > 5.0:
			throttle = clampf(speed_under / 30.0, 0.3, 1.0)
		else:
			throttle = 0.3

	car.set_inputs(throttle, braking, steer_input, false)

	# AI activates DRS when available and on throttle
	if car.drs_available and throttle > 0.3 and braking == 0.0:
		car.drs_active = true
	else:
		car.drs_active = false

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
		var wrapped: float
		if open_path:
			wrapped = clampf(s, 0.0, curve_length)
		else:
			wrapped = fposmod(s, curve_length)
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
		var wrapped: float
		if open_path:
			wrapped = clampf(s, 0.0, curve_length)
		else:
			wrapped = fposmod(s, curve_length)
		var p: Vector3 = curve.sample_baked(wrapped)
		var d: float = car_pos.distance_squared_to(p)
		if d < best_dist:
			best_dist = d
			best_offset = wrapped
		s += 0.25

	return best_offset

func _compute_steering(offset: float, look_ahead: float) -> float:
	var curve_length: float = curve.get_baked_length()
	var target_offset: float
	if open_path:
		target_offset = clampf(offset + look_ahead, 0.0, curve_length)
	else:
		target_offset = fposmod(offset + look_ahead, curve_length)
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
	var is_f1: bool = _is_f1()

	# Sample multiple points along the upcoming path to find the tightest corner
	var num_samples: int = 8 if is_f1 else 3
	var worst_speed_mult: float = 1.0
	var sample_spacing: float = look_ahead / float(num_samples)

	for i in range(num_samples):
		var dist: float = sample_spacing * float(i + 1)
		var s0: float
		var s1: float
		var s2: float

		# Sample three points around each check position
		var step: float = 8.0 if is_f1 else 5.0
		if open_path:
			s0 = clampf(offset + dist - step, 0.0, curve_length)
			s1 = clampf(offset + dist, 0.0, curve_length)
			s2 = clampf(offset + dist + step, 0.0, curve_length)
		else:
			s0 = fposmod(offset + dist - step, curve_length)
			s1 = fposmod(offset + dist, curve_length)
			s2 = fposmod(offset + dist + step, curve_length)

		var p0: Vector3 = curve.sample_baked(s0)
		var p1: Vector3 = curve.sample_baked(s1)
		var p2: Vector3 = curve.sample_baked(s2)

		# Flatten to XZ
		var dir1 := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z).normalized()
		var dir2 := Vector3(p2.x - p1.x, 0.0, p2.z - p1.z).normalized()

		var dot: float = clampf(dir1.dot(dir2), -1.0, 1.0)
		var curvature: float = acos(dot)

		# Convert curvature to speed multiplier
		var curvature_scale: float = 3.5 if is_f1 else 3.0
		var speed_mult: float = clampf(1.0 - curvature * curvature_scale, 0.2, 1.0)

		# Nearer corners are more urgent — weight by proximity
		# But even far corners must cause early braking
		var proximity_weight: float = 1.0 - float(i) / float(num_samples) * 0.3
		speed_mult = 1.0 - (1.0 - speed_mult) * proximity_weight

		worst_speed_mult = minf(worst_speed_mult, speed_mult)

	return max_speed * worst_speed_mult

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
	var ahead_offset: float
	if open_path:
		ahead_offset = clampf(offset + 2.0, 0.0, curve_length)
	else:
		ahead_offset = fposmod(offset + 2.0, curve_length)
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
