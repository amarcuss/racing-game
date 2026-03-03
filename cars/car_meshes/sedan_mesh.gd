extends RefCounted

## Sedan mesh builder — standard car shape extracted from car_base.gd.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> void:
	for child in body_mesh.get_children():
		child.queue_free()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = car_data.body_color
	mat.metallic = 0.6
	mat.roughness = 0.25

	var mat_secondary := StandardMaterial3D.new()
	mat_secondary.albedo_color = car_data.secondary_color
	mat_secondary.metallic = 0.5
	mat_secondary.roughness = 0.3

	var mat_chrome := StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.85, 0.85)
	mat_chrome.metallic = 1.0
	mat_chrome.roughness = 0.05

	var mat_headlight := StandardMaterial3D.new()
	mat_headlight.albedo_color = Color(1.0, 0.95, 0.8)
	mat_headlight.emission_enabled = true
	mat_headlight.emission = Color(1.0, 0.95, 0.8)
	mat_headlight.emission_energy_multiplier = 2.0

	var mat_taillight := StandardMaterial3D.new()
	mat_taillight.albedo_color = Color(1.0, 0.1, 0.1)
	mat_taillight.emission_enabled = true
	mat_taillight.emission = Color(1.0, 0.0, 0.0)
	mat_taillight.emission_energy_multiplier = 1.5

	var mat_glass := StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.1, 0.12, 0.18, 0.7)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height
	var ch: float = car_data.cabin_height

	# Main body
	var body := CSGBox3D.new()
	body.size = Vector3(w, h, l)
	body.position = Vector3(0, h * 0.5, 0)
	body.material = mat
	body.use_collision = false
	body_mesh.add_child(body)

	# Lower body (secondary color)
	var lower := CSGBox3D.new()
	lower.size = Vector3(w + 0.02, h * 0.35, l + 0.02)
	lower.position = Vector3(0, h * 0.175, 0)
	lower.material = mat_secondary
	lower.use_collision = false
	body_mesh.add_child(lower)

	# Cabin
	var cabin := CSGBox3D.new()
	cabin.size = Vector3(w * 0.85, ch, l * 0.4)
	cabin.position = Vector3(0, h + ch * 0.5, car_data.cabin_offset_z)
	cabin.material = mat_secondary
	cabin.use_collision = false
	body_mesh.add_child(cabin)

	# Windshield
	var windshield := CSGBox3D.new()
	windshield.size = Vector3(w * 0.83, ch * 0.8, 0.05)
	windshield.position = Vector3(0, h + ch * 0.55, car_data.cabin_offset_z - l * 0.2 + 0.02)
	windshield.material = mat_glass
	windshield.use_collision = false
	body_mesh.add_child(windshield)

	# Rear window
	var rear_window := CSGBox3D.new()
	rear_window.size = Vector3(w * 0.83, ch * 0.7, 0.05)
	rear_window.position = Vector3(0, h + ch * 0.5, car_data.cabin_offset_z + l * 0.2 - 0.02)
	rear_window.material = mat_glass
	rear_window.use_collision = false
	body_mesh.add_child(rear_window)

	# Chrome grille (front)
	var grille := CSGBox3D.new()
	grille.size = Vector3(w * 0.6, h * 0.3, 0.05)
	grille.position = Vector3(0, h * 0.35, -l * 0.5 - 0.02)
	grille.material = mat_chrome
	grille.use_collision = false
	body_mesh.add_child(grille)

	# Headlights
	for side in [-1.0, 1.0]:
		var headlight := CSGBox3D.new()
		headlight.size = Vector3(w * 0.15, h * 0.15, 0.06)
		headlight.position = Vector3(side * w * 0.35, h * 0.55, -l * 0.5 - 0.02)
		headlight.material = mat_headlight
		headlight.use_collision = false
		body_mesh.add_child(headlight)

	# Taillights
	for side in [-1.0, 1.0]:
		var taillight := CSGBox3D.new()
		taillight.size = Vector3(w * 0.2, h * 0.12, 0.06)
		taillight.position = Vector3(side * w * 0.3, h * 0.5, l * 0.5 + 0.02)
		taillight.material = mat_taillight
		taillight.use_collision = false
		body_mesh.add_child(taillight)

	# Hood scoop
	if car_data.hood_scoop:
		var scoop := CSGBox3D.new()
		scoop.size = Vector3(w * 0.2, 0.1, 0.3)
		scoop.position = Vector3(0, h + 0.05, -l * 0.2)
		scoop.material = mat_secondary
		scoop.use_collision = false
		body_mesh.add_child(scoop)

	# Rear spoiler
	if car_data.rear_spoiler:
		var spoiler_h: float = car_data.spoiler_height if car_data.spoiler_height > 0.0 else 0.15
		for side in [-1.0, 1.0]:
			var post := CSGBox3D.new()
			post.size = Vector3(0.05, spoiler_h, 0.05)
			post.position = Vector3(side * w * 0.35, h + ch + spoiler_h * 0.5, l * 0.35)
			post.material = mat_secondary
			post.use_collision = false
			body_mesh.add_child(post)
		var wing := CSGBox3D.new()
		wing.size = Vector3(w * 0.9, 0.04, 0.2)
		wing.position = Vector3(0, h + ch + spoiler_h, l * 0.35)
		wing.material = mat_secondary
		wing.use_collision = false
		body_mesh.add_child(wing)

	# Wheel visuals
	_build_wheels(wheels, car_data)

static func _build_wheels(wheels: Array, car_data: Resource) -> void:
	var mat_wheel := StandardMaterial3D.new()
	mat_wheel.albedo_color = Color(0.15, 0.15, 0.15)
	mat_wheel.metallic = 0.3
	mat_wheel.roughness = 0.8

	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color(0.7, 0.7, 0.7)
	mat_rim.metallic = 0.9
	mat_rim.roughness = 0.1

	for i in range(4):
		var wheel_vis := CSGCylinder3D.new()
		wheel_vis.radius = car_data.wheel_radius
		wheel_vis.height = 0.2
		wheel_vis.sides = 16
		wheel_vis.material = mat_wheel
		wheel_vis.use_collision = false
		wheel_vis.rotation.z = PI / 2.0
		wheels[i].add_child(wheel_vis)

		var rim := CSGCylinder3D.new()
		rim.radius = car_data.wheel_radius * 0.6
		rim.height = 0.22
		rim.sides = 8
		rim.material = mat_rim
		rim.use_collision = false
		rim.rotation.z = PI / 2.0
		wheels[i].add_child(rim)
