extends RefCounted

## F1 single-seater mesh builder — open-wheel, low nose, sidepods, halo, rear wing.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> StandardMaterial3D:
	for child in body_mesh.get_children():
		child.queue_free()

	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height

	# --- Materials ---
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = car_data.body_color
	mat_body.metallic = 0.4
	mat_body.roughness = 0.15
	mat_body.clearcoat_enabled = true
	mat_body.clearcoat = 0.9
	mat_body.clearcoat_roughness = 0.05

	var mat_carbon := StandardMaterial3D.new()
	mat_carbon.albedo_color = car_data.secondary_color
	mat_carbon.metallic = 0.3
	mat_carbon.roughness = 0.4

	var mat_chrome := StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.85, 0.85)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.05

	var mat_headlight := StandardMaterial3D.new()
	mat_headlight.albedo_color = Color(1.0, 0.95, 0.8)
	mat_headlight.emission_enabled = true
	mat_headlight.emission = Color(1.0, 0.95, 0.8)
	mat_headlight.emission_energy_multiplier = 1.5

	var mat_taillight := StandardMaterial3D.new()
	mat_taillight.albedo_color = Color(1.0, 0.1, 0.1)
	mat_taillight.emission_enabled = true
	mat_taillight.emission = Color(1.0, 0.0, 0.0)
	mat_taillight.emission_energy_multiplier = 1.5

	var mat_halo := StandardMaterial3D.new()
	mat_halo.albedo_color = Color(0.6, 0.6, 0.6)
	mat_halo.metallic = 0.9
	mat_halo.roughness = 0.15

	# --- Main monocoque (narrow central body) ---
	var monocoque := CSGBox3D.new()
	monocoque.size = Vector3(w * 0.45, h, l * 0.7)
	monocoque.position = Vector3(0, h * 0.5, 0)
	monocoque.material = mat_body
	monocoque.use_collision = false
	body_mesh.add_child(monocoque)

	# Nose cone (tapered front)
	var nose := CSGBox3D.new()
	nose.size = Vector3(w * 0.3, h * 0.7, l * 0.25)
	nose.position = Vector3(0, h * 0.35, -l * 0.45)
	nose.material = mat_body
	nose.use_collision = false
	body_mesh.add_child(nose)

	# Front wing endplates and main plane
	var front_wing := CSGBox3D.new()
	front_wing.size = Vector3(w * 1.0, 0.03, 0.3)
	front_wing.position = Vector3(0, h * 0.15, -l * 0.5 - 0.05)
	front_wing.material = mat_body
	front_wing.use_collision = false
	body_mesh.add_child(front_wing)

	# Front wing upper flap element
	var front_flap := CSGBox3D.new()
	front_flap.size = Vector3(w * 0.95, 0.02, 0.12)
	front_flap.position = Vector3(0, h * 0.25, -l * 0.5 + 0.02)
	front_flap.material = mat_carbon
	front_flap.use_collision = false
	body_mesh.add_child(front_flap)

	# Front wing lower flap (multi-element)
	var front_flap2 := CSGBox3D.new()
	front_flap2.size = Vector3(w * 0.9, 0.02, 0.1)
	front_flap2.position = Vector3(0, h * 0.2, -l * 0.5 + 0.15)
	front_flap2.material = mat_body
	front_flap2.use_collision = false
	body_mesh.add_child(front_flap2)

	# Front wing endplates (curved, complex shape in reality — box approximation)
	for side in [-1.0, 1.0]:
		var endplate := CSGBox3D.new()
		endplate.size = Vector3(0.03, h * 0.55, 0.4)
		endplate.position = Vector3(side * w * 0.5, h * 0.2, -l * 0.48)
		endplate.material = mat_carbon
		endplate.use_collision = false
		body_mesh.add_child(endplate)

	# Sidepods (left and right of monocoque)
	for side in [-1.0, 1.0]:
		var sidepod := CSGBox3D.new()
		sidepod.size = Vector3(w * 0.22, h * 0.8, l * 0.4)
		sidepod.position = Vector3(side * w * 0.33, h * 0.4, l * 0.05)
		sidepod.material = mat_body
		sidepod.use_collision = false
		body_mesh.add_child(sidepod)

		# Sidepod intake
		var intake := CSGBox3D.new()
		intake.size = Vector3(w * 0.18, h * 0.35, 0.04)
		intake.position = Vector3(side * w * 0.33, h * 0.6, -l * 0.14)
		intake.material = mat_carbon
		intake.use_collision = false
		body_mesh.add_child(intake)

	# Cockpit opening
	var cockpit := CSGBox3D.new()
	cockpit.size = Vector3(w * 0.3, h * 0.15, l * 0.2)
	cockpit.position = Vector3(0, h + 0.05, -l * 0.1)
	cockpit.material = mat_carbon
	cockpit.use_collision = false
	body_mesh.add_child(cockpit)

	# Halo device
	var halo_front := CSGBox3D.new()
	halo_front.size = Vector3(0.04, 0.2, 0.04)
	halo_front.position = Vector3(0, h + 0.15, -l * 0.2)
	halo_front.material = mat_halo
	halo_front.use_collision = false
	body_mesh.add_child(halo_front)

	var halo_top := CSGBox3D.new()
	halo_top.size = Vector3(w * 0.35, 0.04, l * 0.18)
	halo_top.position = Vector3(0, h + 0.27, -l * 0.12)
	halo_top.material = mat_halo
	halo_top.use_collision = false
	body_mesh.add_child(halo_top)

	# Engine cover / airbox (roll hoop + shark fin area)
	var airbox := CSGBox3D.new()
	airbox.size = Vector3(w * 0.2, h * 0.6, l * 0.15)
	airbox.position = Vector3(0, h + 0.15, l * 0.05)
	airbox.material = mat_body
	airbox.use_collision = false
	body_mesh.add_child(airbox)

	# T-cam (camera pod on top of roll hoop — iconic F1 detail)
	var tcam_base := CSGBox3D.new()
	tcam_base.size = Vector3(0.08, 0.08, 0.08)
	tcam_base.position = Vector3(0, h + 0.5, l * 0.02)
	tcam_base.material = mat_carbon
	tcam_base.use_collision = false
	body_mesh.add_child(tcam_base)

	var tcam_arm := CSGBox3D.new()
	tcam_arm.size = Vector3(0.18, 0.04, 0.04)
	tcam_arm.position = Vector3(0, h + 0.52, l * 0.02)
	tcam_arm.material = mat_body  # T-cam color matches team livery
	tcam_arm.use_collision = false
	body_mesh.add_child(tcam_arm)

	# Floor edges (ground effect tunnels visible from outside)
	for side in [-1.0, 1.0]:
		var floor_edge := CSGBox3D.new()
		floor_edge.size = Vector3(w * 0.08, h * 0.4, l * 0.55)
		floor_edge.position = Vector3(side * w * 0.46, h * 0.15, l * 0.05)
		floor_edge.material = mat_carbon
		floor_edge.use_collision = false
		body_mesh.add_child(floor_edge)

	# Rear diffuser (spans nearly full car width in modern F1)
	var diffuser := CSGBox3D.new()
	diffuser.size = Vector3(w * 0.85, h * 0.35, 0.2)
	diffuser.position = Vector3(0, h * 0.12, l * 0.48)
	diffuser.material = mat_carbon
	diffuser.use_collision = false
	body_mesh.add_child(diffuser)

	# --- Rear wing ---
	# Main wing plane
	var rear_wing := CSGBox3D.new()
	rear_wing.size = Vector3(w * 0.85, 0.04, 0.25)
	rear_wing.position = Vector3(0, h + car_data.spoiler_height + 0.02, l * 0.45)
	rear_wing.material = mat_body
	rear_wing.use_collision = false
	body_mesh.add_child(rear_wing)

	# DRS flap
	var drs_flap := CSGBox3D.new()
	drs_flap.size = Vector3(w * 0.8, 0.02, 0.12)
	drs_flap.position = Vector3(0, h + car_data.spoiler_height + 0.08, l * 0.45)
	drs_flap.material = mat_carbon
	drs_flap.use_collision = false
	body_mesh.add_child(drs_flap)

	# Rear wing endplates
	for side in [-1.0, 1.0]:
		var rw_endplate := CSGBox3D.new()
		rw_endplate.size = Vector3(0.03, car_data.spoiler_height + 0.15, 0.3)
		rw_endplate.position = Vector3(side * w * 0.42, h + car_data.spoiler_height * 0.5, l * 0.45)
		rw_endplate.material = mat_carbon
		rw_endplate.use_collision = false
		body_mesh.add_child(rw_endplate)

	# Rear wing pylons
	for side in [-1.0, 1.0]:
		var pylon := CSGBox3D.new()
		pylon.size = Vector3(0.03, car_data.spoiler_height, 0.04)
		pylon.position = Vector3(side * w * 0.15, h + car_data.spoiler_height * 0.5, l * 0.4)
		pylon.material = mat_carbon
		pylon.use_collision = false
		body_mesh.add_child(pylon)

	# Rain light (rear)
	var rain_light := CSGBox3D.new()
	rain_light.size = Vector3(w * 0.15, 0.04, 0.04)
	rain_light.position = Vector3(0, h + 0.1, l * 0.5 + 0.02)
	rain_light.material = mat_taillight
	rain_light.use_collision = false
	body_mesh.add_child(rain_light)

	# Nose light
	var nose_light := CSGBox3D.new()
	nose_light.size = Vector3(w * 0.12, 0.03, 0.04)
	nose_light.position = Vector3(0, h * 0.4, -l * 0.55)
	nose_light.material = mat_headlight
	nose_light.use_collision = false
	body_mesh.add_child(nose_light)

	# --- Wheels (open-wheel style — larger, exposed) ---
	_build_wheels(wheels, car_data)

	return mat_taillight

static func _build_wheels(wheels: Array, car_data: Resource) -> void:
	var mat_tyre := StandardMaterial3D.new()
	mat_tyre.albedo_color = Color(0.1, 0.1, 0.1)
	mat_tyre.metallic = 0.1
	mat_tyre.roughness = 0.9

	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color(0.75, 0.75, 0.75)
	mat_rim.metallic = 0.95
	mat_rim.roughness = 0.08

	for i in range(4):
		# Wider tyres for F1
		var tyre_width: float = 0.32 if i < 2 else 0.38  # Front narrower than rear

		var tyre := CSGCylinder3D.new()
		tyre.radius = car_data.wheel_radius
		tyre.height = tyre_width
		tyre.sides = 20
		tyre.material = mat_tyre
		tyre.use_collision = false
		tyre.rotation.z = PI / 2.0
		wheels[i].add_child(tyre)

		var rim := CSGCylinder3D.new()
		rim.radius = car_data.wheel_radius * 0.65
		rim.height = tyre_width + 0.02
		rim.sides = 10
		rim.material = mat_rim
		rim.use_collision = false
		rim.rotation.z = PI / 2.0
		wheels[i].add_child(rim)
