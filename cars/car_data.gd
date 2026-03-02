class_name CarData
extends Resource

## Full car definition resource with physics, visual, and progression data.

enum DriveType { FWD, RWD, AWD }

# --- Identity ---
@export var car_name: String = "Car"
@export var tier: int = 1
@export var price: int = 0
@export_multiline var description: String = ""

# --- Performance ---
@export var max_speed_kph: float = 180.0
@export var drive_type: DriveType = DriveType.FWD
@export var mass_kg: float = 1200.0

# --- Torque curve (3-point simplified) ---
@export var torque_low_rpm: float = 300.0
@export var torque_peak_rpm: float = 400.0
@export var torque_high_rpm: float = 200.0

# --- Aerodynamics ---
@export var drag_coefficient: float = 0.35
@export var downforce_coefficient: float = 0.1

# --- Braking ---
@export var brake_force: float = 40.0
@export var brake_bias: float = 0.65

# --- Weight transfer ---
@export var weight_transfer_factor: float = 0.15

# --- Drift ---
@export var drift_friction_slip: float = 1.5
@export var drift_steer_multiplier: float = 1.5
@export var normal_friction_slip: float = 2.5

# --- Suspension ---
@export var suspension_rest_length: float = 0.2
@export var suspension_stiffness: float = 50.0
@export var suspension_travel: float = 0.15
@export var damping_compression: float = 1.2
@export var damping_relaxation: float = 1.5

# --- Wheels ---
@export var wheel_radius: float = 0.35
@export var max_steering_angle: float = 0.35

# --- Visuals ---
@export var body_color: Color = Color(0.2, 0.4, 0.8)
@export var secondary_color: Color = Color(0.12, 0.24, 0.48)
@export var body_width: float = 1.8
@export var body_length: float = 4.2
@export var body_height: float = 0.6
@export var cabin_height: float = 0.55
@export var cabin_offset_z: float = 0.0
@export var hood_scoop: bool = false
@export var rear_spoiler: bool = false
@export var spoiler_height: float = 0.0

func get_torque_at_speed_ratio(ratio: float) -> float:
	## Returns interpolated engine force based on speed ratio (0.0 = stopped, 1.0 = top speed).
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio < 0.5:
		var t := ratio / 0.5
		return lerpf(torque_low_rpm, torque_peak_rpm, t)
	else:
		var t := (ratio - 0.5) / 0.5
		return lerpf(torque_peak_rpm, torque_high_rpm, t)
