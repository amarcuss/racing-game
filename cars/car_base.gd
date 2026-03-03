class_name CarBase
extends VehicleBody3D

## VehicleBody3D controller that applies CarData physics: torque curve,
## aerodynamic drag/downforce, weight transfer, brake bias, and drift model.

@export var car_data: Resource  # CarData

# --- Node references ---
var wheel_fl: VehicleWheel3D
var wheel_fr: VehicleWheel3D
var wheel_rl: VehicleWheel3D
var wheel_rr: VehicleWheel3D
var body_mesh: Node3D

# --- State ---
var current_speed_kph: float = 0.0
var is_drifting: bool = false
var drift_timer: float = 0.0
var drift_recovery_timer: float = 0.0
var stuck_timer: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var steering_input: float = 0.0
var handbrake_input: bool = false
var is_reversing: bool = false

# Slipstream
var slipstream_active: bool = false
var slipstream_ray: RayCast3D

const DRIFT_SLIP_THRESHOLD: float = 0.3
const DRIFT_RECOVERY_TIME: float = 0.5
const STUCK_TIMEOUT: float = 3.0
const SLIPSTREAM_RANGE: float = 20.0
const SLIPSTREAM_DRAG_REDUCTION: float = 0.3
const SLIPSTREAM_MIN_SPEED: float = 100.0
const REVERSE_FORCE_FACTOR: float = 0.3

func _ready() -> void:
	_find_wheels()
	_build_car_mesh()
	_setup_slipstream_ray()
	if car_data:
		_apply_car_data()

func _find_wheels() -> void:
	wheel_fl = $WheelFL as VehicleWheel3D
	wheel_fr = $WheelFR as VehicleWheel3D
	wheel_rl = $WheelRL as VehicleWheel3D
	wheel_rr = $WheelRR as VehicleWheel3D
	body_mesh = $BodyMesh as Node3D

func _apply_car_data() -> void:
	if not car_data:
		return

	mass = car_data.mass_kg
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)

	_apply_wheel_settings(wheel_fl)
	_apply_wheel_settings(wheel_fr)
	_apply_wheel_settings(wheel_rl)
	_apply_wheel_settings(wheel_rr)

	# Drive type: 0=FWD, 1=RWD, 2=AWD
	var dt: int = car_data.drive_type
	wheel_fl.use_as_traction = (dt == 0 or dt == 2)
	wheel_fr.use_as_traction = (dt == 0 or dt == 2)
	wheel_rl.use_as_traction = (dt == 1 or dt == 2)
	wheel_rr.use_as_traction = (dt == 1 or dt == 2)

	wheel_fl.use_as_steering = true
	wheel_fr.use_as_steering = true
	wheel_rl.use_as_steering = false
	wheel_rr.use_as_steering = false

func _apply_wheel_settings(w: VehicleWheel3D) -> void:
	w.wheel_radius = car_data.wheel_radius
	w.wheel_rest_length = car_data.suspension_rest_length
	w.suspension_stiffness = car_data.suspension_stiffness
	w.suspension_travel = car_data.suspension_travel
	w.damping_compression = car_data.damping_compression
	w.damping_relaxation = car_data.damping_relaxation
	w.wheel_friction_slip = car_data.normal_friction_slip

func _setup_slipstream_ray() -> void:
	slipstream_ray = RayCast3D.new()
	slipstream_ray.target_position = Vector3(0, 0, -SLIPSTREAM_RANGE)
	slipstream_ray.collision_mask = 2
	slipstream_ray.enabled = true
	add_child(slipstream_ray)

func _physics_process(delta: float) -> void:
	if not car_data:
		return

	current_speed_kph = linear_velocity.length() * 3.6
	var speed_ratio: float = current_speed_kph / car_data.max_speed_kph

	_update_reverse_state()
	_apply_engine_force(speed_ratio)
	_apply_braking()
	_apply_steering()
	_apply_aerodynamics()
	_apply_weight_transfer()
	_update_drift_state(delta)
	_check_slipstream()
	_apply_anti_flip(delta)
	_check_stuck(delta)

func _update_reverse_state() -> void:
	var local_vel: Vector3 = global_transform.basis.inverse() * linear_velocity
	var forward_speed: float = -local_vel.z * 3.6  # positive = moving forward
	if brake_input > 0.0 and throttle_input == 0.0 and forward_speed < 2.0:
		is_reversing = true
	elif throttle_input > 0.0 or brake_input == 0.0:
		is_reversing = false

func _apply_engine_force(speed_ratio: float) -> void:
	if is_reversing:
		var force: float = car_data.torque_low_rpm * brake_input * REVERSE_FORCE_FACTOR
		engine_force = force  # positive = +Z = backward
		return

	var torque: float = car_data.get_torque_at_speed_ratio(speed_ratio) * throttle_input

	if speed_ratio > 0.95:
		torque *= maxf(0.0, (1.0 - speed_ratio) / 0.05)

	engine_force = -torque

func _apply_braking() -> void:
	if is_reversing:
		brake = 0.0
		return
	if handbrake_input:
		wheel_rl.wheel_friction_slip = car_data.drift_friction_slip * 0.5
		wheel_rr.wheel_friction_slip = car_data.drift_friction_slip * 0.5
		brake = car_data.brake_force * 0.3
	elif brake_input > 0.0:
		var total_brake: float = car_data.brake_force * brake_input
		var front_brake: float = total_brake * car_data.brake_bias
		var rear_brake: float = total_brake * (1.0 - car_data.brake_bias)
		brake = (front_brake + rear_brake) * 0.5
	else:
		brake = 0.0

func _apply_steering() -> void:
	var steer_angle: float = car_data.max_steering_angle
	if is_drifting:
		steer_angle *= car_data.drift_steer_multiplier

	var speed_factor: float = clampf(current_speed_kph / 200.0, 0.0, 1.0)
	var speed_reduction: float = lerpf(1.0, 0.5, speed_factor)
	if is_drifting:
		speed_reduction = lerpf(1.0, 0.7, speed_factor)

	steering = -steering_input * steer_angle * speed_reduction

func _apply_aerodynamics() -> void:
	var speed_ms: float = linear_velocity.length()
	if speed_ms < 1.0:
		return

	var velocity_dir: Vector3 = linear_velocity.normalized()

	var drag: float = car_data.drag_coefficient
	if slipstream_active and current_speed_kph > SLIPSTREAM_MIN_SPEED:
		drag *= (1.0 - SLIPSTREAM_DRAG_REDUCTION)

	var drag_force: Vector3 = -velocity_dir * drag * speed_ms * speed_ms
	apply_central_force(drag_force)

	var downforce: float = car_data.downforce_coefficient * speed_ms * speed_ms
	apply_central_force(Vector3(0, -downforce, 0))

func _apply_weight_transfer() -> void:
	if not car_data:
		return

	if brake_input > 0.0:
		var transfer: float = car_data.weight_transfer_factor * brake_input
		wheel_fl.wheel_friction_slip = car_data.normal_friction_slip + transfer
		wheel_fr.wheel_friction_slip = car_data.normal_friction_slip + transfer
		if not handbrake_input:
			wheel_rl.wheel_friction_slip = car_data.normal_friction_slip - transfer
			wheel_rr.wheel_friction_slip = car_data.normal_friction_slip - transfer
	elif not is_drifting and not handbrake_input:
		var all_wheels: Array = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
		for w in all_wheels:
			w.wheel_friction_slip = car_data.normal_friction_slip

func _update_drift_state(delta: float) -> void:
	var local_vel: Vector3 = global_transform.basis.inverse() * linear_velocity
	var lateral_ratio: float = 0.0
	if local_vel.length() > 2.0:
		lateral_ratio = absf(local_vel.x) / local_vel.length()

	if not is_drifting:
		if (handbrake_input or lateral_ratio > DRIFT_SLIP_THRESHOLD) and current_speed_kph > 30.0:
			is_drifting = true
			drift_timer = 0.0
			drift_recovery_timer = 0.0
	else:
		drift_timer += delta
		var drift_slip: float = car_data.drift_friction_slip
		wheel_rl.wheel_friction_slip = drift_slip
		wheel_rr.wheel_friction_slip = drift_slip

		if not handbrake_input and lateral_ratio < DRIFT_SLIP_THRESHOLD * 0.5:
			drift_recovery_timer += delta
			if drift_recovery_timer >= DRIFT_RECOVERY_TIME:
				is_drifting = false
				wheel_rl.wheel_friction_slip = car_data.normal_friction_slip
				wheel_rr.wheel_friction_slip = car_data.normal_friction_slip
		else:
			drift_recovery_timer = 0.0

func _check_slipstream() -> void:
	slipstream_active = false
	if not slipstream_ray or current_speed_kph < SLIPSTREAM_MIN_SPEED:
		return
	if slipstream_ray.is_colliding():
		var collider = slipstream_ray.get_collider()
		if collider is VehicleBody3D and collider != self:
			var dist: float = global_position.distance_to(collider.global_position)
			if dist < SLIPSTREAM_RANGE:
				slipstream_active = true

func _apply_anti_flip(delta: float) -> void:
	var any_wheel_on_ground: bool = false
	var all_wheels: Array = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	for w in all_wheels:
		if w.is_in_contact():
			any_wheel_on_ground = true
			break

	if not any_wheel_on_ground:
		var up: Vector3 = global_transform.basis.y
		var target_up: Vector3 = Vector3.UP
		var correction: Vector3 = up.cross(target_up)
		apply_torque(correction * mass * 5.0 * delta * 120.0)
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, 2.0 * delta)

func _check_stuck(delta: float) -> void:
	if current_speed_kph < 2.0 and (throttle_input > 0.2 or brake_input > 0.2):
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	if global_position.y < -10.0:
		reset_to_track()

func reset_to_track() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position.y = 2.0
	stuck_timer = 0.0

func set_inputs(throttle: float, braking: float, steer: float, handbrake: bool) -> void:
	throttle_input = throttle
	brake_input = braking
	steering_input = steer
	handbrake_input = handbrake

func _build_car_mesh() -> void:
	if not car_data or not body_mesh:
		return

	var mesh_script: GDScript
	match car_data.tier:
		2:
			mesh_script = load("res://cars/car_meshes/coupe_mesh.gd")
		3:
			mesh_script = load("res://cars/car_meshes/muscle_mesh.gd")
		_:
			mesh_script = load("res://cars/car_meshes/sedan_mesh.gd")

	var wheels_arr: Array = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	mesh_script.build(body_mesh, car_data, wheels_arr)
