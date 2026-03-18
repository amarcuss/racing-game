class_name CarBase
extends VehicleBody3D

## VehicleBody3D controller that applies CarData physics: torque curve,
## aerodynamic drag/downforce, weight transfer, brake bias, and drift model.

signal collision_occurred(speed: float)

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

# Track path for reset
var track_path: Path3D

# Brake lights
var _taillight_material: StandardMaterial3D

# Particles
var _tire_smoke_l: GPUParticles3D
var _tire_smoke_r: GPUParticles3D
var _exhaust_particles: GPUParticles3D
var _spark_particles: GPUParticles3D

# Engine audio
var _audio_player: AudioStreamPlayer3D
var _audio_playback: AudioStreamGeneratorPlayback
var _engine_phase: float = 0.0
var _engine_target_freq: float = 25.0
var _engine_current_freq: float = 25.0
var _engine_volume: float = 0.3
var _engine_rpm_norm: float = 0.0
var _exhaust_phase: float = 0.0
var _prev_throttle: float = 0.0
var _lp_prev: float = 0.0   # 1st low-pass state
var _lp_prev2: float = 0.0  # 2nd low-pass state (cascaded)
# Backfire state — discrete gunshot events
var _backfire_queued: int = 0       # number of bangs left to fire
var _backfire_cooldown: float = 0.0 # time until next bang allowed
var _bang_age: int = 0              # samples since current bang started
var _bang_active: bool = false      # currently playing a bang
var _bang_sign: float = 1.0         # polarity of current bang

# Slipstream
var slipstream_active: bool = false
var slipstream_ray: RayCast3D

# DRS (F1 only)
var drs_available: bool = false
var drs_active: bool = false
var drs_gap_timer: float = 0.0

const DRIFT_SLIP_THRESHOLD: float = 0.3
const DRIFT_RECOVERY_TIME: float = 0.5
const STUCK_TIMEOUT: float = 2.0
const SLIPSTREAM_RANGE: float = 20.0
const SLIPSTREAM_DRAG_REDUCTION: float = 0.3
const SLIPSTREAM_MIN_SPEED: float = 100.0
const DRS_DRAG_REDUCTION: float = 0.50
const DRS_MIN_SPEED: float = 80.0
const REVERSE_FORCE_FACTOR: float = 0.3

func _ready() -> void:
	_find_wheels()
	_build_car_mesh()
	_setup_slipstream_ray()
	if car_data:
		_apply_car_data()
	_setup_particles()
	_setup_collision_detection()
	_setup_engine_audio()

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
	_update_drs(delta)
	_apply_anti_flip(delta)
	_check_stuck(delta)
	_update_brake_lights()
	_update_particles()

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

func _update_drs(delta: float) -> void:
	# DRS only available for F1 cars (tier 4)
	if not car_data or car_data.tier != 4:
		drs_available = false
		drs_active = false
		return

	# DRS becomes available when within slipstream range for 0.5s
	if slipstream_active and current_speed_kph > DRS_MIN_SPEED:
		drs_gap_timer += delta
		if drs_gap_timer >= 0.5:
			drs_available = true
	else:
		drs_gap_timer = 0.0
		drs_available = false
		drs_active = false

func _apply_aerodynamics() -> void:
	var speed_ms: float = linear_velocity.length()
	if speed_ms < 1.0:
		return

	var velocity_dir: Vector3 = linear_velocity.normalized()

	var drag: float = car_data.drag_coefficient
	if drs_active and car_data.tier == 4:
		# DRS gives bigger drag reduction than standard slipstream
		drag *= (1.0 - DRS_DRAG_REDUCTION)
	elif slipstream_active and current_speed_kph > SLIPSTREAM_MIN_SPEED:
		drag *= (1.0 - SLIPSTREAM_DRAG_REDUCTION)

	var drag_force: Vector3 = -velocity_dir * drag * speed_ms * speed_ms
	apply_central_force(drag_force)

	var downforce: float = car_data.downforce_coefficient * speed_ms * speed_ms
	# DRS reduces downforce too (rear wing opens)
	if drs_active and car_data.tier == 4:
		downforce *= 0.7
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

	if stuck_timer >= STUCK_TIMEOUT:
		reset_to_track()

	if global_position.y < -10.0:
		reset_to_track()

func reset_to_track() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	stuck_timer = 0.0

	if track_path and track_path.curve and track_path.curve.point_count >= 2:
		var curve: Curve3D = track_path.curve
		var curve_length: float = curve.get_baked_length()
		var offset: float = curve.get_closest_offset(global_position)
		var pos: Vector3 = curve.sample_baked(offset) + Vector3.UP * 1.5

		# Get forward direction from curve
		var ahead_offset: float = fposmod(offset + 2.0, curve_length)
		var ahead_pos: Vector3 = curve.sample_baked(ahead_offset)
		var forward: Vector3 = (ahead_pos - pos).normalized()
		forward.y = 0.0
		forward = forward.normalized()

		var z_axis: Vector3 = -forward
		var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
		var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
		var basis := Basis(x_axis, y_axis, z_axis)
		global_transform = Transform3D(basis, pos)
	else:
		global_position.y = 2.0

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
		4:
			mesh_script = load("res://cars/car_meshes/f1_mesh.gd")
		7:
			mesh_script = load("res://cars/car_meshes/buggy_mesh.gd")
		8:
			mesh_script = load("res://cars/car_meshes/trophy_truck_mesh.gd")
		_:
			mesh_script = load("res://cars/car_meshes/sedan_mesh.gd")

	var wheels_arr: Array = [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	_taillight_material = mesh_script.build(body_mesh, car_data, wheels_arr)

func _update_brake_lights() -> void:
	if not _taillight_material:
		return
	var target_energy: float = lerpf(1.5, 4.0, brake_input)
	_taillight_material.emission_energy_multiplier = target_energy

func _setup_particles() -> void:
	if not car_data:
		return

	var l: float = car_data.body_length
	var w: float = car_data.body_width

	# Tire smoke — left rear
	_tire_smoke_l = _create_tire_smoke()
	_tire_smoke_l.position = Vector3(-w * 0.4, 0.05, l * 0.3)
	add_child(_tire_smoke_l)

	# Tire smoke — right rear
	_tire_smoke_r = _create_tire_smoke()
	_tire_smoke_r.position = Vector3(w * 0.4, 0.05, l * 0.3)
	add_child(_tire_smoke_r)

	# Exhaust
	_exhaust_particles = GPUParticles3D.new()
	_exhaust_particles.amount = 10
	_exhaust_particles.lifetime = 0.8
	_exhaust_particles.emitting = false
	_exhaust_particles.position = Vector3(0, 0.15, l * 0.5 + 0.1)
	var exhaust_mat := ParticleProcessMaterial.new()
	exhaust_mat.direction = Vector3(0, 0.5, 1.0)
	exhaust_mat.spread = 15.0
	exhaust_mat.initial_velocity_min = 1.0
	exhaust_mat.initial_velocity_max = 2.0
	exhaust_mat.gravity = Vector3(0, 0.5, 0)
	exhaust_mat.scale_min = 0.1
	exhaust_mat.scale_max = 0.2
	exhaust_mat.color = Color(0.3, 0.3, 0.3, 0.4)
	_exhaust_particles.process_material = exhaust_mat
	var exhaust_mesh := QuadMesh.new()
	exhaust_mesh.size = Vector2(0.15, 0.15)
	_exhaust_particles.draw_pass_1 = exhaust_mesh
	add_child(_exhaust_particles)

	# Sparks
	_spark_particles = GPUParticles3D.new()
	_spark_particles.amount = 20
	_spark_particles.lifetime = 0.4
	_spark_particles.one_shot = true
	_spark_particles.explosiveness = 0.9
	_spark_particles.emitting = false
	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 60.0
	spark_mat.initial_velocity_min = 3.0
	spark_mat.initial_velocity_max = 8.0
	spark_mat.gravity = Vector3(0, -9.8, 0)
	spark_mat.scale_min = 0.02
	spark_mat.scale_max = 0.05
	spark_mat.color = Color(1.0, 0.6, 0.1, 1.0)
	_spark_particles.process_material = spark_mat
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.04, 0.04)
	_spark_particles.draw_pass_1 = spark_mesh
	add_child(_spark_particles)

func _create_tire_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.5
	p.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, 0.3, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	mat.color = Color(0.85, 0.85, 0.85, 0.5)
	p.process_material = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	p.draw_pass_1 = mesh
	return p

func _update_particles() -> void:
	# Tire smoke when drifting at speed
	var smoke_active: bool = is_drifting and current_speed_kph > 20.0
	if _tire_smoke_l:
		_tire_smoke_l.emitting = smoke_active
	if _tire_smoke_r:
		_tire_smoke_r.emitting = smoke_active

	# Exhaust on throttle
	if _exhaust_particles:
		_exhaust_particles.emitting = throttle_input > 0.3 and current_speed_kph > 5.0

func _setup_collision_detection() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is StaticBody3D:
		# Trigger sparks at contact point
		if _spark_particles:
			_spark_particles.emitting = false
			_spark_particles.restart()
			_spark_particles.emitting = true
		collision_occurred.emit(current_speed_kph)

func _setup_engine_audio() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.05
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = stream
	_audio_player.unit_size = 15.0
	_audio_player.max_db = 6.0
	add_child(_audio_player)
	_audio_player.play()
	_audio_playback = _audio_player.get_stream_playback()

func _process(delta: float) -> void:
	_fill_audio_buffer(delta)

func _fill_audio_buffer(delta: float) -> void:
	if not _audio_playback or not car_data:
		return

	var speed_ratio: float = clampf(current_speed_kph / car_data.max_speed_kph, 0.0, 1.0)
	_engine_rpm_norm = lerpf(_engine_rpm_norm, speed_ratio, 5.0 * delta)

	# Engine frequency — F1 cars have a higher-pitched V6 turbo-hybrid
	if car_data.tier == 4:
		_engine_target_freq = lerpf(60.0, 280.0, _engine_rpm_norm)
	else:
		_engine_target_freq = lerpf(25.0, 120.0, _engine_rpm_norm)
	_engine_current_freq = lerpf(_engine_current_freq, _engine_target_freq, 0.12)

	# Volume: idle quiet, builds with RPM and throttle
	var rpm_vol: float = lerpf(0.08, 0.3, _engine_rpm_norm)
	var throttle_vol: float = lerpf(0.5, 1.0, throttle_input)
	_engine_volume = rpm_vol * throttle_vol

	# Backfire detection: queue 2-4 discrete bangs on throttle lift
	if _prev_throttle > 0.4 and throttle_input < 0.15 and _engine_rpm_norm > 0.35:
		if _backfire_queued == 0:
			_backfire_queued = randi_range(2, 4)
			_backfire_cooldown = 0.0
	_prev_throttle = throttle_input
	_backfire_cooldown = maxf(_backfire_cooldown - delta, 0.0)

	# Trigger next bang if cooldown expired
	if _backfire_queued > 0 and not _bang_active and _backfire_cooldown <= 0.0:
		_bang_active = true
		_bang_age = 0
		_bang_sign = 1.0 if randf() > 0.5 else -1.0
		_backfire_queued -= 1
		_backfire_cooldown = randf_range(0.06, 0.15)  # 60-150ms between shots

	var frames_available: int = _audio_playback.get_frames_available()
	var sample_rate: float = 44100.0
	var increment: float = _engine_current_freq / sample_rate

	# Cascaded low-pass: opens more for F1's higher-pitched whine
	var lp_alpha: float
	if car_data.tier == 4:
		lp_alpha = clampf(lerpf(0.12, 0.35, _engine_rpm_norm), 0.10, 0.40)
	else:
		lp_alpha = clampf(lerpf(0.06, 0.18, _engine_rpm_norm), 0.04, 0.25)

	# Bang duration in samples (~50ms = gunshot length)
	var bang_len: int = int(sample_rate * 0.05)

	for i in range(frames_available):
		var p: float = _engine_phase

		var pulse: float = 0.0
		var rumble: float = 0.0

		if car_data.tier == 4:
			# V6 turbo-hybrid — sharper, higher-pitched firing with turbo whine
			var p1: float = fmod(p, 1.0)
			var p2: float = fmod(p + 0.333, 1.0)
			var p3: float = fmod(p + 0.666, 1.0)
			if p1 < 0.15:
				pulse += sin(p1 / 0.15 * PI) * 0.6
			if p2 < 0.15:
				pulse += sin(p2 / 0.15 * PI) * 0.5
			if p3 < 0.15:
				pulse += sin(p3 / 0.15 * PI) * 0.4
			# Turbo whine overtone
			_exhaust_phase = fmod(_exhaust_phase + increment * 2.0, 1.0)
			rumble = sin(_exhaust_phase * TAU) * 0.2
		else:
			# V8-style firing
			var p1: float = fmod(p, 1.0)
			var p2: float = fmod(p + 0.45, 1.0)
			if p1 < 0.2:
				pulse += sin(p1 / 0.2 * PI) * 0.7
			if p2 < 0.2:
				pulse += sin(p2 / 0.2 * PI) * 0.55
			# Sub-bass rumble
			_exhaust_phase = fmod(_exhaust_phase + increment * 0.5, 1.0)
			rumble = sin(_exhaust_phase * TAU) * 0.35

		var sample: float = pulse * 0.5 + rumble

		# Two-stage low-pass filter
		_lp_prev = _lp_prev + lp_alpha * (sample - _lp_prev)
		_lp_prev2 = _lp_prev2 + lp_alpha * (_lp_prev - _lp_prev2)
		sample = _lp_prev2
		sample *= _engine_volume

		# Gunshot backfire — injected raw after filter
		if _bang_active:
			var t: float = float(_bang_age) / float(bang_len)
			if t < 1.0:
				var bang: float = 0.0
				if t < 0.02:
					# Initial transient: max amplitude spike (first ~1ms)
					bang = _bang_sign * 2.5
				elif t < 0.08:
					# Sharp crack: fast decaying noise burst
					var env: float = (0.08 - t) / 0.06
					bang = randf_range(-1.0, 1.0) * env * 1.8
				else:
					# Low-freq boom tail: damped 60Hz sine
					var tail_t: float = t - 0.08
					var env2: float = exp(-tail_t * 30.0)
					bang = sin(tail_t * TAU * 60.0) * env2 * 1.2 * _bang_sign
				sample += bang
				_bang_age += 1
			else:
				_bang_active = false

		sample = clampf(sample, -1.0, 1.0)

		_audio_playback.push_frame(Vector2(sample, sample))
		_engine_phase = fmod(_engine_phase + increment, 1.0)
