extends Node3D

## F1 Silverstone — ~5.9 km fast flowing circuit inspired by the British Grand Prix.
## High-speed sweepers (Maggotts-Becketts-Chapel), technical infield,
## long Hangar Straight, and wide run-off areas. Flat with gentle undulations.
## All geometry built procedurally via ArrayMesh.

const ROAD_WIDTH: float = 16.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 896
const WALL_HEIGHT: float = 2.5
const WALL_WIDTH: float = 0.4

var num_checkpoints: int = 12
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	start_segment = track_points.size() / _get_waypoints().size() * 1
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_walls(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_grandstands(track_points)
	_build_trees(track_points)
	_build_kerbs(track_points)
	_build_environment()

func get_spawn_transform(index: int) -> Transform3D:
	var stagger: int = 3 + index * 3
	var seg_idx: int = (start_segment - stagger + track_points.size()) % track_points.size()
	var p: Dictionary = track_points[seg_idx]
	var pos: Vector3 = p.position + Vector3.UP * 1.0
	var side_offset: float = 1.5 if index % 2 == 1 else -1.5
	var right: Vector3 = _get_right(p)
	pos += right * side_offset
	return Transform3D(_rotation_facing(p.forward), pos)

func get_num_checkpoints() -> int:
	return num_checkpoints

func get_ai_path() -> Path3D:
	return ai_path

func get_perimeter() -> float:
	return perimeter

# --- Track layout ---
# Silverstone-inspired: long straights, high-speed sweepers, technical infield.
# Counter-clockwise flow.

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# === Start/Finish straight (Hamilton Straight) heading south ===
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 0.0, "z": 120.0, "y": 0.0})

	# === Copse — fast right-hander ===
	pts.append({"x": -40.0, "z": 230.0, "y": 0.5})
	pts.append({"x": -100.0, "z": 300.0, "y": 1.0})

	# === Maggotts-Becketts-Chapel — famous S-curves ===
	pts.append({"x": -180.0, "z": 340.0, "y": 1.5})
	pts.append({"x": -250.0, "z": 310.0, "y": 2.0})
	pts.append({"x": -310.0, "z": 350.0, "y": 1.5})
	pts.append({"x": -380.0, "z": 320.0, "y": 1.0})

	# === Hangar Straight — long blast ===
	pts.append({"x": -450.0, "z": 280.0, "y": 0.5})
	pts.append({"x": -550.0, "z": 220.0, "y": 0.0})

	# === Stowe — fast right into braking zone ===
	pts.append({"x": -600.0, "z": 140.0, "y": -0.5})
	pts.append({"x": -610.0, "z": 60.0, "y": -0.5})

	# === Vale and Club — tight complex ===
	pts.append({"x": -580.0, "z": -20.0, "y": 0.0})
	pts.append({"x": -530.0, "z": -60.0, "y": 0.5})
	pts.append({"x": -470.0, "z": -40.0, "y": 0.5})

	# === Farm Straight ===
	pts.append({"x": -400.0, "z": -60.0, "y": 0.5})
	pts.append({"x": -320.0, "z": -80.0, "y": 0.5})

	# === Village and Loop — technical section ===
	pts.append({"x": -250.0, "z": -120.0, "y": 1.0})
	pts.append({"x": -200.0, "z": -160.0, "y": 1.5})
	pts.append({"x": -140.0, "z": -150.0, "y": 1.5})

	# === Aintree and Wellington Straight ===
	pts.append({"x": -80.0, "z": -120.0, "y": 1.0})
	pts.append({"x": -30.0, "z": -80.0, "y": 0.5})

	# === Brooklands and Luffield — slow hairpin complex ===
	pts.append({"x": 10.0, "z": -50.0, "y": 0.0})

	return pts

func _generate_track_points() -> Array[Dictionary]:
	var waypoints: Array[Dictionary] = _get_waypoints()
	var wp_count: int = waypoints.size()
	var points: Array[Dictionary] = []

	for seg in range(wp_count):
		var p0_idx: int = (seg - 1 + wp_count) % wp_count
		var p1_idx: int = seg
		var p2_idx: int = (seg + 1) % wp_count
		var p3_idx: int = (seg + 2) % wp_count

		var p0: Vector3 = _wp_to_vec3(waypoints[p0_idx])
		var p1: Vector3 = _wp_to_vec3(waypoints[p1_idx])
		var p2: Vector3 = _wp_to_vec3(waypoints[p2_idx])
		var p3: Vector3 = _wp_to_vec3(waypoints[p3_idx])

		var steps_per_seg: int = NUM_SEGMENTS / wp_count
		if steps_per_seg < 4:
			steps_per_seg = 4

		for i in range(steps_per_seg):
			var t: float = float(i) / float(steps_per_seg)
			var pos: Vector3 = _catmull_rom(p0, p1, p2, p3, t)
			points.append({"position": pos, "forward": Vector3.ZERO, "banking": 0.0})

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var fwd: Vector3 = (points[next_i].position - points[i].position).normalized()
		if fwd.length() < 0.001:
			fwd = Vector3.FORWARD
		points[i].forward = fwd

	return points

func _wp_to_vec3(wp: Dictionary) -> Vector3:
	return Vector3(wp.x, wp.y + ROAD_Y, wp.z)

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _compute_perimeter(points: Array[Dictionary]) -> float:
	var total: float = 0.0
	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		total += points[i].position.distance_to(points[next_i].position)
	return total

func _rotation_facing(direction: Vector3) -> Basis:
	var forward: Vector3 = direction.normalized()
	var forward_flat := Vector3(forward.x, 0.0, forward.z).normalized()
	if forward_flat.length() < 0.001:
		forward_flat = Vector3.FORWARD
	var z_axis: Vector3 = -forward_flat
	var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _basis_facing(direction: Vector3) -> Basis:
	var forward: Vector3 = direction.normalized()
	var forward_flat := Vector3(forward.x, 0.0, forward.z).normalized()
	if forward_flat.length() < 0.001:
		forward_flat = Vector3.FORWARD
	var right: Vector3 = Vector3.UP.cross(forward_flat).normalized()
	var up: Vector3 = forward_flat.cross(right).normalized()
	return Basis(right, up, -forward_flat)

func _get_right(point: Dictionary) -> Vector3:
	var fwd: Vector3 = point.forward
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	if fwd_flat.length() < 0.001:
		fwd_flat = Vector3.FORWARD
	return Vector3.UP.cross(fwd_flat).normalized()

# --- Road mesh ---

func _build_road_mesh(points: Array[Dictionary]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.10, 0.10, 0.11)
	road_mat.roughness = 0.75
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(road_mat)

	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var left_v: Vector3 = p.position - right * half_w
		var right_v: Vector3 = p.position + right * half_w
		var left_next: Vector3 = p_next.position - right_next * half_w
		var right_next_v: Vector3 = p_next.position + right_next * half_w

		st.set_normal(Vector3.UP)
		st.add_vertex(left_v)
		st.set_normal(Vector3.UP)
		st.add_vertex(left_next)
		st.set_normal(Vector3.UP)
		st.add_vertex(right_v)

		st.set_normal(Vector3.UP)
		st.add_vertex(right_v)
		st.set_normal(Vector3.UP)
		st.add_vertex(left_next)
		st.set_normal(Vector3.UP)
		st.add_vertex(right_next_v)

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, road_mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RoadMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = road_mat
	add_child(mesh_instance)

# --- Road collision ---

func _build_road_collision(points: Array[Dictionary]) -> void:
	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var left_v: Vector3 = p.position - right * half_w
		var right_v: Vector3 = p.position + right * half_w
		var left_next: Vector3 = p_next.position - right_next * half_w
		var right_next_v: Vector3 = p_next.position + right_next * half_w

		faces.append(left_v)
		faces.append(left_next)
		faces.append(right_v)

		faces.append(right_v)
		faces.append(left_next)
		faces.append(right_next_v)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true

	var body := StaticBody3D.new()
	body.name = "RoadCollision"
	body.collision_layer = 1
	body.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	body.add_child(col_shape)
	add_child(body)

# --- Walls (tire barriers) ---

func _build_walls(points: Array[Dictionary]) -> void:
	_build_wall_side(points, -1.0, "InnerWall")
	_build_wall_side(points, 1.0, "OuterWall")

func _build_wall_side(points: Array[Dictionary], side: float, wall_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.roughness = 0.85
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_mat.vertex_color_use_as_albedo = true
	st.set_material(wall_mat)

	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0
	# Silverstone uses blue/red tire barriers
	var color_barrier := Color(0.15, 0.25, 0.55) if side > 0.0 else Color(0.55, 0.15, 0.15)

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var base: Vector3 = p.position + right * half_w * side
		var base_next: Vector3 = p_next.position + right_next * half_w * side
		var top: Vector3 = base + Vector3.UP * WALL_HEIGHT
		var top_next: Vector3 = base_next + Vector3.UP * WALL_HEIGHT

		st.set_color(color_barrier)
		st.add_vertex(base)
		st.set_color(color_barrier)
		st.add_vertex(base_next)
		st.set_color(color_barrier)
		st.add_vertex(top)

		st.set_color(color_barrier)
		st.add_vertex(top)
		st.set_color(color_barrier)
		st.add_vertex(base_next)
		st.set_color(color_barrier)
		st.add_vertex(top_next)

		var outward: Vector3 = right * side * WALL_WIDTH
		var top_out: Vector3 = top + outward
		var top_next_out: Vector3 = top_next + outward

		st.set_color(color_barrier)
		st.add_vertex(top)
		st.set_color(color_barrier)
		st.add_vertex(top_next)
		st.set_color(color_barrier)
		st.add_vertex(top_out)

		st.set_color(color_barrier)
		st.add_vertex(top_out)
		st.set_color(color_barrier)
		st.add_vertex(top_next)
		st.set_color(color_barrier)
		st.add_vertex(top_next_out)

		faces.append(base)
		faces.append(base_next)
		faces.append(top)
		faces.append(top)
		faces.append(base_next)
		faces.append(top_next)

		faces.append(top)
		faces.append(top_next)
		faces.append(top_out)
		faces.append(top_out)
		faces.append(top_next)
		faces.append(top_next_out)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = wall_name + "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true

	var body := StaticBody3D.new()
	body.name = wall_name + "Collision"
	body.collision_layer = 1
	body.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	body.add_child(col_shape)
	add_child(body)

# --- Ground (English countryside green) ---

func _build_ground() -> void:
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(1200, 0.05, 1000)
	ground_mesh.position = Vector3(-300, -0.025, 100)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.20, 0.40, 0.12)
	ground_mat.roughness = 0.95
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(-300, -2.0, 100)

	var box := BoxShape3D.new()
	box.size = Vector3(1200, 1, 1000)
	var col := CollisionShape3D.new()
	col.shape = box
	ground_body.add_child(col)
	add_child(ground_body)

# --- Checkpoints ---

func _build_checkpoints() -> void:
	var total_pts: int = track_points.size()

	for i in range(num_checkpoints):
		var seg_idx: int = (start_segment + int(float(i) / float(num_checkpoints) * float(total_pts))) % total_pts
		var p: Dictionary = track_points[seg_idx]

		var cp := Area3D.new()
		cp.name = "Checkpoint%d" % i
		cp.set_script(preload("res://tracks/components/checkpoint.gd"))
		cp.checkpoint_index = i
		cp.is_start_finish = (i == 0)
		cp.collision_layer = 0
		cp.collision_mask = 2
		cp.monitoring = true
		cp.monitorable = false

		var fwd: Vector3 = p.forward
		if fwd.length() > 0.001:
			cp.transform = Transform3D(_basis_facing(fwd), p.position + Vector3.UP * 2.0)
		else:
			cp.position = p.position + Vector3.UP * 2.0

		var shape := BoxShape3D.new()
		shape.size = Vector3(ROAD_WIDTH + 4.0, 8.0, 4.0)
		var col := CollisionShape3D.new()
		col.shape = shape
		cp.add_child(col)

		add_child(cp)

# --- Start/Finish visual ---

func _build_start_finish_visual() -> void:
	var p: Dictionary = track_points[start_segment]
	var right: Vector3 = _get_right(p)
	var half_w: float = ROAD_WIDTH / 2.0

	var line := CSGBox3D.new()
	line.name = "StartFinishLine"
	line.size = Vector3(ROAD_WIDTH, 0.02, 1.5)
	line.use_collision = false
	var fwd: Vector3 = p.forward
	if fwd.length() > 0.001:
		line.transform = Transform3D(_basis_facing(fwd), p.position + Vector3.UP * 0.01)
	else:
		line.position = p.position + Vector3.UP * 0.01

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.5
	line.material = mat
	add_child(line)

	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.3, 7.0, 0.3)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 3.5
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.85, 0.85, 0.85)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.2
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.5, 0.5)
	beam.position = p.position + Vector3.UP * 7.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.1, 0.1, 0.6)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.1, 0.1, 0.6)
	beam_mat.emission_energy_multiplier = 1.0
	beam.material = beam_mat
	add_child(beam)

# --- AI Path ---

func _build_ai_path() -> void:
	var curve := Curve3D.new()
	var step: int = max(1, track_points.size() / 128)
	for i in range(0, track_points.size(), step):
		var p: Dictionary = track_points[i]
		curve.add_point(p.position + Vector3.UP * 0.5)
	ai_path = Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	add_child(ai_path)

# --- Grandstands ---

func _build_grandstands(points: Array[Dictionary]) -> void:
	# Place grandstands at key viewing spots
	var stand_segments: Array[int] = [
		start_segment,  # Start/finish
		start_segment + track_points.size() / 6,  # Copse
		start_segment + track_points.size() / 3,  # Becketts
		start_segment + track_points.size() * 2 / 3,  # Club
	]

	for seg_idx in stand_segments:
		var idx: int = seg_idx % track_points.size()
		var p: Dictionary = track_points[idx]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			var offset: float = ROAD_WIDTH / 2.0 + WALL_WIDTH + 12.0
			var stand_pos: Vector3 = p.position + right * side_val * offset

			# Main structure
			var stand := CSGBox3D.new()
			stand.size = Vector3(30.0, 8.0, 6.0)
			stand.position = stand_pos + Vector3.UP * 4.0
			stand.use_collision = false
			var stand_mat := StandardMaterial3D.new()
			stand_mat.albedo_color = Color(0.6, 0.6, 0.65)
			stand_mat.roughness = 0.7
			stand.material = stand_mat
			add_child(stand)

			# Roof
			var roof := CSGBox3D.new()
			roof.size = Vector3(32.0, 0.3, 8.0)
			roof.position = stand_pos + Vector3.UP * 8.5
			roof.use_collision = false
			var roof_mat := StandardMaterial3D.new()
			roof_mat.albedo_color = Color(0.3, 0.3, 0.35)
			roof_mat.metallic = 0.3
			roof.material = roof_mat
			add_child(roof)

# --- Trees (English countryside) ---

func _build_trees(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	for i in range(0, points.size(), 18):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		var side_val: float = 1.0 if (i / 18) % 2 == 0 else -1.0
		if rng.randf() > 0.55:
			continue

		var offset: float = ROAD_WIDTH / 2.0 + WALL_WIDTH + 15.0 + rng.randf() * 20.0
		var tree_pos: Vector3 = p.position + right * side_val * offset

		var trunk_height: float = 5.0 + rng.randf() * 5.0
		var trunk := CSGCylinder3D.new()
		trunk.radius = 0.25
		trunk.height = trunk_height
		trunk.position = Vector3(tree_pos.x, tree_pos.y + trunk_height / 2.0, tree_pos.z)
		trunk.use_collision = false
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.35, 0.25, 0.12)
		trunk_mat.roughness = 0.9
		trunk.material = trunk_mat
		add_child(trunk)

		# Rounded canopy — English oak style
		var crown := CSGSphere3D.new()
		crown.radius = 2.5 + rng.randf() * 2.0
		crown.position = Vector3(tree_pos.x, tree_pos.y + trunk_height + 1.5, tree_pos.z)
		crown.use_collision = false
		var crown_mat := StandardMaterial3D.new()
		# Varied greens
		var green_shade: float = 0.25 + rng.randf() * 0.2
		crown_mat.albedo_color = Color(0.10, green_shade, 0.08)
		crown_mat.roughness = 0.85
		crown.material = crown_mat
		add_child(crown)

# --- Kerbs (red/white at corner apexes) ---

func _build_kerbs(points: Array[Dictionary]) -> void:
	# Detect corners by measuring direction change and place kerbs
	var total_pts: int = points.size()
	var kerb_mat_red := StandardMaterial3D.new()
	kerb_mat_red.albedo_color = Color(0.8, 0.15, 0.1)
	kerb_mat_red.roughness = 0.7
	var kerb_mat_white := StandardMaterial3D.new()
	kerb_mat_white.albedo_color = Color(0.95, 0.95, 0.95)
	kerb_mat_white.roughness = 0.7

	var last_kerb_i: int = -30
	for i in range(total_pts):
		if i - last_kerb_i < 25:
			continue
		var prev_i: int = (i - 5 + total_pts) % total_pts
		var next_i: int = (i + 5) % total_pts
		var angle: float = points[prev_i].forward.angle_to(points[next_i].forward)
		if angle > 0.08:  # Significant turn
			last_kerb_i = i
			var p: Dictionary = points[i]
			var right: Vector3 = _get_right(p)
			# Determine which side the inside of the corner is
			var cross_y: float = points[prev_i].forward.cross(points[next_i].forward).y
			var inner_side: float = -1.0 if cross_y > 0 else 1.0

			for k in range(4):
				var ki: int = (i + k * 3) % total_pts
				var kp: Dictionary = points[ki]
				var kr: Vector3 = _get_right(kp)
				var kerb := CSGBox3D.new()
				kerb.size = Vector3(1.5, 0.06, 2.0)
				var kerb_pos: Vector3 = kp.position + kr * inner_side * (ROAD_WIDTH / 2.0 - 0.5)
				kerb_pos.y += 0.03
				var fwd: Vector3 = kp.forward
				if fwd.length() > 0.001:
					kerb.transform = Transform3D(_basis_facing(fwd), kerb_pos)
				else:
					kerb.position = kerb_pos
				kerb.use_collision = false
				kerb.material = kerb_mat_red if k % 2 == 0 else kerb_mat_white
				add_child(kerb)

# --- Environment: overcast English sky ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.1
	light.light_color = Color(0.90, 0.90, 0.92)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.55, 0.70)
	sky_mat.sky_horizon_color = Color(0.70, 0.75, 0.80)
	sky_mat.ground_bottom_color = Color(0.20, 0.30, 0.15)
	sky_mat.ground_horizon_color = Color(0.50, 0.55, 0.45)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2  # BG_SKY
	env.sky = sky
	env.ambient_light_source = 1  # AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.50, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = 2  # Filmic
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.65, 0.68, 0.72)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.4

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
