extends RefCounted

## Stock car mesh builder — boxy NASCAR silhouette with large rear spoiler and number panels.

static func build(body_mesh: Node3D, car_data: Resource, wheels: Array) -> StandardMaterial3D:
	for child in body_mesh.get_children():
		child.queue_free()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = car_data.body_color
	mat.metallic = 0.6
	mat.roughness = 0.25
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.8
	mat.clearcoat_roughness = 0.1

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

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.12, 0.12, 0.12)
	mat_dark.metallic = 0.3
	mat_dark.roughness = 0.6

	var w: float = car_data.body_width
	var l: float = car_data.body_length
	var h: float = car_data.body_height
	var ch: float = car_data.cabin_height

	# Main body — boxy stock car shape
	var body := CSGBox3D.new()
	body.size = Vector3(w, h, l)
	body.position = Vector3(0, h * 0.5, 0)
	body.material = mat
	body.use_collision = false
	body_mesh.add_child(body)

	# Lower body / rocker panels (secondary color)
	var lower := CSGBox3D.new()
	lower.size = Vector3(w + 0.02, h * 0.3, l + 0.02)
	lower.position = Vector3(0, h * 0.15, 0)
	lower.material = mat_secondary
	lower.use_collision = false
	body_mesh.add_child(lower)

	# Long hood section
	var hood := CSGBox3D.new()
	hood.size = Vector3(w * 0.95, 0.03, l * 0.35)
	hood.position = Vector3(0, h + 0.015, -l * 0.15)
	hood.material = mat
	hood.use_collision = false
	body_mesh.add_child(hood)

	# Cabin — narrower, set back (stock car greenhouse)
	var cabin := CSGBox3D.new()
	cabin.size = Vector3(w * 0.82, ch, l * 0.32)
	cabin.position = Vector3(0, h + ch * 0.5, car_data.cabin_offset_z + l * 0.05)
	cabin.material = mat
	cabin.use_collision = false
	body_mesh.add_child(cabin)

	# Windshield — raked
	var windshield := CSGBox3D.new()
	windshield.size = Vector3(w * 0.8, ch * 0.85, 0.05)
	windshield.position = Vector3(0, h + ch * 0.5, car_data.cabin_offset_z - l * 0.1)
	windshield.material = mat_glass
	windshield.use_collision = false
	body_mesh.add_child(windshield)

	# Rear window
	var rear_window := CSGBox3D.new()
	rear_window.size = Vector3(w * 0.8, ch * 0.7, 0.05)
	rear_window.position = Vector3(0, h + ch * 0.45, car_data.cabin_offset_z + l * 0.21)
	rear_window.material = mat_glass
	rear_window.use_collision = false
	body_mesh.add_child(rear_window)

	# Roll cage bars visible through windshield
	for side in [-1.0, 1.0]:
		var cage_bar := CSGBox3D.new()
		cage_bar.size = Vector3(0.03, ch * 0.9, 0.03)
		cage_bar.position = Vector3(side * w * 0.35, h + ch * 0.45, car_data.cabin_offset_z)
		cage_bar.material = mat_dark
		cage_bar.use_collision = false
		body_mesh.add_child(cage_bar)

	# Horizontal roll cage bar
	var cage_top := CSGBox3D.new()
	cage_top.size = Vector3(w * 0.7, 0.03, 0.03)
	cage_top.position = Vector3(0, h + ch * 0.85, car_data.cabin_offset_z)
	cage_top.material = mat_dark
	cage_top.use_collision = false
	body_mesh.add_child(cage_top)

	# Diagonal cage bar
	var cage_diag := CSGBox3D.new()
	cage_diag.size = Vector3(0.03, ch * 0.7, 0.03)
	cage_diag.position = Vector3(0, h + ch * 0.5, car_data.cabin_offset_z - l * 0.05)
	cage_diag.rotation.z = 0.4
	cage_diag.material = mat_dark
	cage_diag.use_collision = false
	body_mesh.add_child(cage_diag)

	# Front bumper — chrome
	var front_bumper := CSGBox3D.new()
	front_bumper.size = Vector3(w * 0.95, h * 0.25, 0.08)
	front_bumper.position = Vector3(0, h * 0.2, -l * 0.5 - 0.03)
	front_bumper.material = mat_chrome
	front_bumper.use_collision = false
	body_mesh.add_child(front_bumper)

	# Rear bumper — chrome
	var rear_bumper := CSGBox3D.new()
	rear_bumper.size = Vector3(w * 0.95, h * 0.25, 0.08)
	rear_bumper.position = Vector3(0, h * 0.2, l * 0.5 + 0.03)
	rear_bumper.material = mat_chrome
	rear_bumper.use_collision = false
	body_mesh.add_child(rear_bumper)

	# Headlight stickers (flat painted look)
	for side in [-1.0, 1.0]:
		var headlight := CSGBox3D.new()
		headlight.size = Vector3(w * 0.2, h * 0.18, 0.04)
		headlight.position = Vector3(side * w * 0.3, h * 0.55, -l * 0.5 - 0.01)
		headlight.material = mat_headlight
		headlight.use_collision = false
		body_mesh.add_child(headlight)

	# Taillight stickers
	for side in [-1.0, 1.0]:
		var taillight := CSGBox3D.new()
		taillight.size = Vector3(w * 0.25, h * 0.14, 0.04)
		taillight.position = Vector3(side * w * 0.28, h * 0.5, l * 0.5 + 0.01)
		taillight.material = mat_taillight
		taillight.use_collision = false
		body_mesh.add_child(taillight)

	# Number panels on doors (secondary color)
	for side in [-1.0, 1.0]:
		var number_panel := CSGBox3D.new()
		number_panel.size = Vector3(0.04, h * 0.5, l * 0.2)
		number_panel.position = Vector3(side * (w * 0.5 + 0.01), h * 0.55, car_data.cabin_offset_z)
		number_panel.material = mat_secondary
		number_panel.use_collision = false
		body_mesh.add_child(number_panel)

	# Short deck / trunk
	var deck := CSGBox3D.new()
	deck.size = Vector3(w * 0.92, 0.03, l * 0.2)
	deck.position = Vector3(0, h + 0.015, l * 0.3)
	deck.material = mat
	deck.use_collision = false
	body_mesh.add_child(deck)

	# Large rear spoiler (blade style) — NASCAR signature
	var spoiler_h: float = car_data.spoiler_height if car_data.spoiler_height > 0.0 else 0.2
	# Spoiler posts
	for side in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.06, spoiler_h + 0.05, 0.06)
		post.position = Vector3(side * w * 0.38, h + spoiler_h * 0.5, l * 0.42)
		post.material = mat_dark
		post.use_collision = false
		body_mesh.add_child(post)

	# Spoiler blade — wide and flat
	var blade := CSGBox3D.new()
	blade.size = Vector3(w * 0.95, 0.25, 0.06)
	blade.position = Vector3(0, h + spoiler_h, l * 0.42)
	blade.material = mat_secondary
	blade.use_collision = false
	body_mesh.add_child(blade)

	# Front splitter
	var splitter := CSGBox3D.new()
	splitter.size = Vector3(w * 1.05, 0.03, 0.15)
	splitter.position = Vector3(0, 0.05, -l * 0.5 - 0.05)
	splitter.material = mat_dark
	splitter.use_collision = false
	body_mesh.add_child(splitter)

	# Wheel visuals
	_build_wheels(wheels, car_data)

	return mat_taillight

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
		wheel_vis.height = 0.22
		wheel_vis.sides = 16
		wheel_vis.material = mat_wheel
		wheel_vis.use_collision = false
		wheel_vis.rotation.z = PI / 2.0
		wheels[i].add_child(wheel_vis)

		var rim := CSGCylinder3D.new()
		rim.radius = car_data.wheel_radius * 0.55
		rim.height = 0.24
		rim.sides = 5
		rim.material = mat_rim
		rim.use_collision = false
		rim.rotation.z = PI / 2.0
		wheels[i].add_child(rim)
