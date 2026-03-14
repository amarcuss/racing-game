extends RefCounted

## Coupe mesh builder — sleeker shape with sloped rear cabin and fender flares.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> StandardMaterial3D:
	# Build base sedan shape first
	var SedanMesh: GDScript = load("res://cars/car_meshes/sedan_mesh.gd")
	var taillight_mat: StandardMaterial3D = SedanMesh.build(body_mesh, car_data, wheels)

	var mat_secondary := StandardMaterial3D.new()
	mat_secondary.albedo_color = car_data.secondary_color
	mat_secondary.metallic = 0.5
	mat_secondary.roughness = 0.3

	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height
	var ch: float = car_data.cabin_height

	# Sloped rear cabin extension — tapers the roofline down
	var rear_slope := CSGBox3D.new()
	rear_slope.size = Vector3(w * 0.83, ch * 0.4, l * 0.15)
	rear_slope.position = Vector3(0, h + ch * 0.2, car_data.cabin_offset_z + l * 0.28)
	rear_slope.material = mat_secondary
	rear_slope.use_collision = false
	body_mesh.add_child(rear_slope)

	# Fender flares near wheels
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = car_data.body_color
	mat_body.metallic = 0.6
	mat_body.roughness = 0.25
	mat_body.clearcoat_enabled = true
	mat_body.clearcoat = 0.8
	mat_body.clearcoat_roughness = 0.1

	for side in [-1.0, 1.0]:
		# Front fender flare
		var front_flare := CSGBox3D.new()
		front_flare.size = Vector3(0.06, h * 0.4, 0.5)
		front_flare.position = Vector3(side * (w * 0.5 + 0.02), h * 0.35, -l * 0.25)
		front_flare.material = mat_body
		front_flare.use_collision = false
		body_mesh.add_child(front_flare)

		# Rear fender flare
		var rear_flare := CSGBox3D.new()
		rear_flare.size = Vector3(0.06, h * 0.4, 0.5)
		rear_flare.position = Vector3(side * (w * 0.5 + 0.02), h * 0.35, l * 0.25)
		rear_flare.material = mat_body
		rear_flare.use_collision = false
		body_mesh.add_child(rear_flare)

	return taillight_mat
