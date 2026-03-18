extends RefCounted

## Trophy truck mesh builder — raised truck body, wide fenders, roll cage, front bumper guard.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> StandardMaterial3D:
	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height

	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = car_data.body_color
	mat_body.metallic = 0.5
	mat_body.roughness = 0.35
	mat_body.clearcoat_enabled = true
	mat_body.clearcoat = 0.6
	mat_body.clearcoat_roughness = 0.15

	var mat_secondary := StandardMaterial3D.new()
	mat_secondary.albedo_color = car_data.secondary_color
	mat_secondary.metallic = 0.4
	mat_secondary.roughness = 0.5

	var mat_cage := StandardMaterial3D.new()
	mat_cage.albedo_color = Color(0.2, 0.2, 0.2)
	mat_cage.metallic = 0.8
	mat_cage.roughness = 0.2

	var mat_chrome := StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.85, 0.85)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.05

	# Main cab body — raised higher than normal
	var cab := CSGBox3D.new()
	cab.size = Vector3(w * 0.85, h, l * 0.35)
	cab.position = Vector3(0, h * 0.5 + 0.15, -l * 0.05)
	cab.material = mat_body
	cab.use_collision = false
	body_mesh.add_child(cab)

	# Cabin roof
	var cabin := CSGBox3D.new()
	cabin.size = Vector3(w * 0.75, car_data.cabin_height, l * 0.25)
	cabin.position = Vector3(0, h + car_data.cabin_height * 0.5 + 0.15, car_data.cabin_offset_z)
	cabin.material = mat_secondary
	cabin.use_collision = false
	body_mesh.add_child(cabin)

	# Hood — long front section
	var hood := CSGBox3D.new()
	hood.size = Vector3(w * 0.8, h * 0.6, l * 0.25)
	hood.position = Vector3(0, h * 0.3 + 0.15, -l * 0.3)
	hood.material = mat_body
	hood.use_collision = false
	body_mesh.add_child(hood)

	# Hood scoop
	var scoop := CSGBox3D.new()
	scoop.size = Vector3(w * 0.25, 0.12, 0.35)
	scoop.position = Vector3(0, h * 0.6 + 0.15 + 0.06, -l * 0.28)
	scoop.material = mat_secondary
	scoop.use_collision = false
	body_mesh.add_child(scoop)

	# Truck bed (rear open area)
	var bed_floor := CSGBox3D.new()
	bed_floor.size = Vector3(w * 0.85, h * 0.2, l * 0.3)
	bed_floor.position = Vector3(0, h * 0.1 + 0.15, l * 0.25)
	bed_floor.material = mat_body
	bed_floor.use_collision = false
	body_mesh.add_child(bed_floor)

	# Bed side walls
	for side in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.size = Vector3(0.06, h * 0.5, l * 0.3)
		wall.position = Vector3(side * w * 0.42, h * 0.25 + 0.15, l * 0.25)
		wall.material = mat_body
		wall.use_collision = false
		body_mesh.add_child(wall)

	# Wide fenders
	for side in [-1.0, 1.0]:
		# Front fender
		var ff := CSGBox3D.new()
		ff.size = Vector3(0.15, h * 0.5, l * 0.2)
		ff.position = Vector3(side * (w * 0.5 + 0.05), h * 0.25 + 0.15, -l * 0.25)
		ff.material = mat_secondary
		ff.use_collision = false
		body_mesh.add_child(ff)

		# Rear fender
		var rf := CSGBox3D.new()
		rf.size = Vector3(0.15, h * 0.5, l * 0.2)
		rf.position = Vector3(side * (w * 0.5 + 0.05), h * 0.25 + 0.15, l * 0.2)
		rf.material = mat_secondary
		rf.use_collision = false
		body_mesh.add_child(rf)

	# Front bumper guard (bull bar)
	var bumper := CSGBox3D.new()
	bumper.size = Vector3(w * 0.7, 0.08, 0.08)
	bumper.position = Vector3(0, h * 0.35 + 0.15, -l * 0.48)
	bumper.material = mat_cage
	bumper.use_collision = false
	body_mesh.add_child(bumper)

	# Bumper verticals
	for side in [-1.0, 1.0]:
		var vert := CSGCylinder3D.new()
		vert.radius = 0.03
		vert.height = h * 0.4
		vert.sides = 8
		vert.position = Vector3(side * w * 0.3, h * 0.35 + 0.15, -l * 0.47)
		vert.material = mat_cage
		vert.use_collision = false
		body_mesh.add_child(vert)

	# Roll cage on cabin
	var cage_top_y: float = h + car_data.cabin_height + 0.15
	for x_sign in [-1.0, 1.0]:
		var pillar := CSGCylinder3D.new()
		pillar.radius = 0.035
		pillar.height = car_data.cabin_height + 0.1
		pillar.sides = 8
		pillar.position = Vector3(x_sign * w * 0.37, h + car_data.cabin_height * 0.5 + 0.15, -l * 0.05 + l * 0.12)
		pillar.material = mat_cage
		pillar.use_collision = false
		body_mesh.add_child(pillar)

	# Roof light bar
	var light_bar := CSGBox3D.new()
	light_bar.size = Vector3(w * 0.65, 0.08, 0.1)
	light_bar.position = Vector3(0, cage_top_y + 0.04, -l * 0.05)
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
		headlight.size = Vector3(0.2, 0.12, 0.05)
		headlight.position = Vector3(side * w * 0.3, h * 0.45 + 0.15, -l * 0.44)
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
		tail.size = Vector3(0.15, 0.1, 0.05)
		tail.position = Vector3(side * w * 0.35, h * 0.3 + 0.15, l * 0.42)
		tail.material = taillight_mat
		tail.use_collision = false
		body_mesh.add_child(tail)

	# Wheels
	for i in range(wheels.size()):
		var wheel_node: Node3D = wheels[i]
		var tire := CSGCylinder3D.new()
		tire.radius = car_data.wheel_radius
		tire.height = 0.3
		tire.sides = 16
		tire.rotation.z = PI / 2.0
		var tire_mat := StandardMaterial3D.new()
		tire_mat.albedo_color = Color(0.12, 0.12, 0.12)
		tire_mat.roughness = 0.95
		tire.material = tire_mat
		tire.use_collision = false
		wheel_node.add_child(tire)

		var hub := CSGCylinder3D.new()
		hub.radius = car_data.wheel_radius * 0.4
		hub.height = 0.31
		hub.sides = 8
		hub.rotation.z = PI / 2.0
		hub.material = mat_chrome
		hub.use_collision = false
		wheel_node.add_child(hub)

	return taillight_mat
