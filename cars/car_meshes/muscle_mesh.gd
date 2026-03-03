extends RefCounted

## Muscle car mesh builder — aggressive stance with hood scoop, exhaust pipes, wider panels.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> void:
	# Build base sedan shape first
	var SedanMesh: GDScript = load("res://cars/car_meshes/sedan_mesh.gd")
	SedanMesh.build(body_mesh, car_data, wheels)

	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height

	var mat_secondary := StandardMaterial3D.new()
	mat_secondary.albedo_color = car_data.secondary_color
	mat_secondary.metallic = 0.5
	mat_secondary.roughness = 0.3

	var mat_chrome := StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.85, 0.85)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.05

	# Larger hood scoop overlay (on top of base scoop if present)
	var scoop := CSGBox3D.new()
	scoop.size = Vector3(w * 0.3, 0.14, 0.45)
	scoop.position = Vector3(0, h + 0.07, -l * 0.2)
	scoop.material = mat_secondary
	scoop.use_collision = false
	body_mesh.add_child(scoop)

	# Exhaust pipes at rear
	for side in [-1.0, 1.0]:
		var exhaust := CSGCylinder3D.new()
		exhaust.radius = 0.04
		exhaust.height = 0.2
		exhaust.sides = 12
		exhaust.material = mat_chrome
		exhaust.use_collision = false
		exhaust.rotation.x = PI / 2.0
		exhaust.position = Vector3(side * w * 0.25, h * 0.15, l * 0.5 + 0.1)
		body_mesh.add_child(exhaust)

	# Wider lower body panels
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = car_data.body_color
	mat_body.metallic = 0.6
	mat_body.roughness = 0.25

	for side in [-1.0, 1.0]:
		var panel := CSGBox3D.new()
		panel.size = Vector3(0.05, h * 0.3, l * 0.8)
		panel.position = Vector3(side * (w * 0.5 + 0.02), h * 0.2, 0)
		panel.material = mat_body
		panel.use_collision = false
		body_mesh.add_child(panel)
