extends RefCounted

## Baja buggy mesh builder — open-frame buggy with roll cage, exposed wheels, roof light bar.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> StandardMaterial3D:
	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height

	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = car_data.body_color
	mat_body.metallic = 0.4
	mat_body.roughness = 0.5

	var mat_cage := StandardMaterial3D.new()
	mat_cage.albedo_color = car_data.secondary_color
	mat_cage.metallic = 0.8
	mat_cage.roughness = 0.2

	var mat_chrome := StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.85, 0.85)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.05

	# Minimal body panels — flat low platform
	var floor_panel := CSGBox3D.new()
	floor_panel.size = Vector3(w * 0.8, h * 0.3, l * 0.7)
	floor_panel.position = Vector3(0, h * 0.15, 0)
	floor_panel.material = mat_body
	floor_panel.use_collision = false
	body_mesh.add_child(floor_panel)

	# Front nose
	var nose := CSGBox3D.new()
	nose.size = Vector3(w * 0.6, h * 0.4, l * 0.2)
	nose.position = Vector3(0, h * 0.2, -l * 0.35)
	nose.material = mat_body
	nose.use_collision = false
	body_mesh.add_child(nose)

	# Rear engine cover
	var rear := CSGBox3D.new()
	rear.size = Vector3(w * 0.5, h * 0.5, l * 0.15)
	rear.position = Vector3(0, h * 0.25, l * 0.3)
	rear.material = mat_body
	rear.use_collision = false
	body_mesh.add_child(rear)

	# Roll cage — vertical pillars
	var cage_radius: float = 0.04
	var cage_height: float = h + 0.8
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var pillar := CSGCylinder3D.new()
			pillar.radius = cage_radius
			pillar.height = cage_height
			pillar.sides = 8
			pillar.position = Vector3(x_sign * w * 0.35, cage_height * 0.5, z_sign * l * 0.2)
			pillar.material = mat_cage
			pillar.use_collision = false
			body_mesh.add_child(pillar)

	# Roll cage — top cross bars (front and rear)
	for z_sign in [-1.0, 1.0]:
		var cross := CSGCylinder3D.new()
		cross.radius = cage_radius
		cross.height = w * 0.7
		cross.sides = 8
		cross.rotation.z = PI / 2.0
		cross.position = Vector3(0, cage_height, z_sign * l * 0.2)
		cross.material = mat_cage
		cross.use_collision = false
		body_mesh.add_child(cross)

	# Roll cage — top longitudinal bars
	for x_sign in [-1.0, 1.0]:
		var long_bar := CSGCylinder3D.new()
		long_bar.radius = cage_radius
		long_bar.height = l * 0.4
		long_bar.sides = 8
		long_bar.rotation.x = PI / 2.0
		long_bar.position = Vector3(x_sign * w * 0.35, cage_height, 0)
		long_bar.material = mat_cage
		long_bar.use_collision = false
		body_mesh.add_child(long_bar)

	# Roof light bar
	var light_bar := CSGBox3D.new()
	light_bar.size = Vector3(w * 0.6, 0.08, 0.12)
	light_bar.position = Vector3(0, cage_height + 0.04, -l * 0.2)
	light_bar.use_collision = false
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(1.0, 0.95, 0.7)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1.0, 0.95, 0.7)
	light_mat.emission_energy_multiplier = 2.0
	light_bar.material = light_mat
	body_mesh.add_child(light_bar)

	# Headlights
	for side in [-1.0, 1.0]:
		var headlight := CSGBox3D.new()
		headlight.size = Vector3(0.15, 0.1, 0.05)
		headlight.position = Vector3(side * w * 0.25, h * 0.4, -l * 0.45)
		headlight.use_collision = false
		var hl_mat := StandardMaterial3D.new()
		hl_mat.albedo_color = Color(1.0, 0.95, 0.8)
		hl_mat.emission_enabled = true
		hl_mat.emission = Color(1.0, 0.95, 0.8)
		hl_mat.emission_energy_multiplier = 1.5
		headlight.material = hl_mat
		body_mesh.add_child(headlight)

	# Taillights
	var taillight_mat := StandardMaterial3D.new()
	taillight_mat.albedo_color = Color(0.8, 0.05, 0.05)
	taillight_mat.emission_enabled = true
	taillight_mat.emission = Color(1.0, 0.1, 0.1)
	taillight_mat.emission_energy_multiplier = 1.5

	for side in [-1.0, 1.0]:
		var tail := CSGBox3D.new()
		tail.size = Vector3(0.12, 0.08, 0.05)
		tail.position = Vector3(side * w * 0.2, h * 0.35, l * 0.38)
		tail.material = taillight_mat
		tail.use_collision = false
		body_mesh.add_child(tail)

	# Wheels
	for i in range(wheels.size()):
		var wheel_node: Node3D = wheels[i]
		var tire := CSGCylinder3D.new()
		tire.radius = car_data.wheel_radius
		tire.height = 0.25
		tire.sides = 16
		tire.rotation.z = PI / 2.0
		tire.position = Vector3.ZERO
		var tire_mat := StandardMaterial3D.new()
		tire_mat.albedo_color = Color(0.12, 0.12, 0.12)
		tire_mat.roughness = 0.95
		tire.material = tire_mat
		tire.use_collision = false
		wheel_node.add_child(tire)

		var hub := CSGCylinder3D.new()
		hub.radius = car_data.wheel_radius * 0.45
		hub.height = 0.26
		hub.sides = 8
		hub.rotation.z = PI / 2.0
		hub.material = mat_chrome
		hub.use_collision = false
		wheel_node.add_child(hub)

	return taillight_mat
