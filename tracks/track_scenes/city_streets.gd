extends Node3D

## City Streets — 1.8 km night circuit through city blocks with tight 90-degree
## corners, a chicane through a plaza, and narrow 8m road lined with concrete walls.
## All geometry built procedurally via ArrayMesh.

# --- Track geometry constants ---
const ROAD_WIDTH: float = 8.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 512
const WALL_HEIGHT: float = 3.0
const WALL_WIDTH: float = 0.4

var num_checkpoints: int = 6
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0  # Set after generation — index on the first straight

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	# Place start/finish in middle of the first straight (waypoints 0-3 are the east straight)
	start_segment = track_points.size() / _get_waypoints().size() * 2
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_walls(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_buildings(track_points)
	_build_street_lights(track_points)
	_build_environment()

func get_spawn_transform(index: int) -> Transform3D:
	# Spawn cars BEHIND start/finish on the straight, staggered grid
	var stagger: int = 3 + index * 3
	var seg_idx: int = (start_segment - stagger + track_points.size()) % track_points.size()
	var p: Dictionary = track_points[seg_idx]
	var pos: Vector3 = p.position + Vector3.UP * 1.0
	var side_offset: float = 1.2 if index % 2 == 1 else -1.2
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
# City circuit: rectangular blocks with tight 90° turns and a chicane.

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# Start/finish on south straight heading east
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 60.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 120.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 180.0, "z": 0.0, "y": 0.0})

	# 90° right turn heading north
	pts.append({"x": 210.0, "z": 5.0, "y": 0.0})
	pts.append({"x": 220.0, "z": 20.0, "y": 0.0})
	pts.append({"x": 220.0, "z": 50.0, "y": 0.0})

	# North straight
	pts.append({"x": 220.0, "z": 100.0, "y": 0.0})
	pts.append({"x": 220.0, "z": 160.0, "y": 0.0})

	# 90° right turn heading west
	pts.append({"x": 215.0, "z": 190.0, "y": 0.0})
	pts.append({"x": 200.0, "z": 200.0, "y": 0.0})
	pts.append({"x": 170.0, "z": 200.0, "y": 0.0})

	# Chicane through plaza — quick left-right
	pts.append({"x": 140.0, "z": 200.0, "y": 0.0})
	pts.append({"x": 120.0, "z": 210.0, "y": 0.0})
	pts.append({"x": 100.0, "z": 200.0, "y": 0.0})
	pts.append({"x": 80.0, "z": 210.0, "y": 0.0})
	pts.append({"x": 60.0, "z": 200.0, "y": 0.0})

	# Continue west
	pts.append({"x": 30.0, "z": 200.0, "y": 0.0})

	# 90° right turn heading south
	pts.append({"x": 5.0, "z": 195.0, "y": 0.0})
	pts.append({"x": -5.0, "z": 180.0, "y": 0.0})
	pts.append({"x": -5.0, "z": 150.0, "y": 0.0})

	# South section sweeping west then east back to start
	pts.append({"x": -5.0, "z": 100.0, "y": 0.0})
	pts.append({"x": -20.0, "z": 60.0, "y": 0.0})
	pts.append({"x": -50.0, "z": 30.0, "y": 0.0})
	pts.append({"x": -80.0, "z": 10.0, "y": 0.0})
	pts.append({"x": -90.0, "z": -15.0, "y": 0.0})
	pts.append({"x": -70.0, "z": -20.0, "y": 0.0})

	# Straight approach heading east at z=0 (collinear with start)
	pts.append({"x": -40.0, "z": -10.0, "y": 0.0})
	pts.append({"x": -20.0, "z": -3.0, "y": 0.0})

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

	# Compute forward directions
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
	## Returns a proper right-handed rotation basis where -Z faces along direction.
	## Use this for VehicleBody3D spawn transforms.
	var forward: Vector3 = direction.normalized()
	var forward_flat := Vector3(forward.x, 0.0, forward.z).normalized()
	if forward_flat.length() < 0.001:
		forward_flat = Vector3.FORWARD
	var z_axis: Vector3 = -forward_flat
	var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _basis_facing(direction: Vector3) -> Basis:
	## Returns a basis facing along direction. Used for visual elements and checkpoints.
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
	road_mat.albedo_color = Color(0.06, 0.06, 0.07)
	road_mat.roughness = 0.8
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

# --- Concrete walls (both sides) ---

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
	var color_concrete := Color(0.4, 0.4, 0.42)

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

		# Wall face
		st.set_color(color_concrete)
		st.add_vertex(base)
		st.set_color(color_concrete)
		st.add_vertex(base_next)
		st.set_color(color_concrete)
		st.add_vertex(top)

		st.set_color(color_concrete)
		st.add_vertex(top)
		st.set_color(color_concrete)
		st.add_vertex(base_next)
		st.set_color(color_concrete)
		st.add_vertex(top_next)

		# Top cap
		var outward: Vector3 = right * side * WALL_WIDTH
		var top_out: Vector3 = top + outward
		var top_next_out: Vector3 = top_next + outward

		st.set_color(color_concrete)
		st.add_vertex(top)
		st.set_color(color_concrete)
		st.add_vertex(top_next)
		st.set_color(color_concrete)
		st.add_vertex(top_out)

		st.set_color(color_concrete)
		st.add_vertex(top_out)
		st.set_color(color_concrete)
		st.add_vertex(top_next)
		st.set_color(color_concrete)
		st.add_vertex(top_next_out)

		# Collision
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

# --- Ground ---

func _build_ground() -> void:
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(500, 0.05, 450)
	ground_mesh.position = Vector3(70, -0.025, 95)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.05, 0.05, 0.06)
	ground_mat.roughness = 0.9
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(70, -2.0, 95)

	var box := BoxShape3D.new()
	box.size = Vector3(500, 1, 450)
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

	# Neon gantry for night visibility
	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.3, 5.0, 0.3)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 2.5
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.2, 0.2, 0.2)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.2
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.3, 0.3)
	beam.position = p.position + Vector3.UP * 5.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.0, 0.8, 1.0)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.0, 0.8, 1.0)
	beam_mat.emission_energy_multiplier = 2.0
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

# --- Buildings alongside the track ---

func _build_buildings(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# Place buildings behind the walls every N segments
	for i in range(0, points.size(), 12):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.7:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + WALL_WIDTH + 10.0 + rng.randf() * 8.0
			var bldg_pos: Vector3 = p.position + right * side_val * offset
			_add_building(bldg_pos, rng)

func _add_building(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var width: float = 6.0 + rng.randf() * 10.0
	var depth: float = 6.0 + rng.randf() * 10.0
	var height: float = 8.0 + rng.randf() * 25.0

	var bldg := CSGBox3D.new()
	bldg.size = Vector3(width, height, depth)
	bldg.position = Vector3(pos.x, height / 2.0, pos.z)
	bldg.use_collision = false

	var bldg_mat := StandardMaterial3D.new()
	var shade: float = 0.08 + rng.randf() * 0.1
	bldg_mat.albedo_color = Color(shade, shade, shade + 0.02)
	bldg_mat.roughness = 0.9
	bldg.material = bldg_mat
	add_child(bldg)

	# Emissive windows — small boxes on the face
	var window_rows: int = int(height / 3.0)
	var window_cols: int = int(width / 2.5)
	for row in range(window_rows):
		for col in range(window_cols):
			if rng.randf() > 0.6:
				continue
			var win := CSGBox3D.new()
			win.size = Vector3(1.2, 1.0, 0.05)
			var wx: float = pos.x - width / 2.0 + 1.5 + float(col) * 2.5
			var wy: float = 2.0 + float(row) * 3.0
			var wz: float = pos.z + depth / 2.0 + 0.03
			win.position = Vector3(wx, wy, wz)
			win.use_collision = false

			var win_mat := StandardMaterial3D.new()
			var warm: float = 0.7 + rng.randf() * 0.3
			win_mat.albedo_color = Color(warm, warm * 0.85, warm * 0.5)
			win_mat.emission_enabled = true
			win_mat.emission = Color(warm, warm * 0.85, warm * 0.5)
			win_mat.emission_energy_multiplier = 1.5 + rng.randf() * 1.0
			win.material = win_mat
			add_child(win)

# --- Street lights ---

func _build_street_lights(points: Array[Dictionary]) -> void:
	for i in range(0, points.size(), 20):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		# Alternate sides
		var side_val: float = 1.0 if (i / 20) % 2 == 0 else -1.0
		var light_pos: Vector3 = p.position + right * side_val * (ROAD_WIDTH / 2.0 - 0.5)

		# Post
		var post := CSGCylinder3D.new()
		post.radius = 0.08
		post.height = 5.0
		post.position = light_pos + Vector3.UP * 2.5
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.25, 0.25, 0.25)
		post_mat.metallic = 0.6
		post_mat.roughness = 0.3
		post.material = post_mat
		add_child(post)

		# Light fixture
		var fixture := CSGBox3D.new()
		fixture.size = Vector3(0.4, 0.15, 0.4)
		fixture.position = light_pos + Vector3.UP * 5.0
		fixture.use_collision = false
		var fix_mat := StandardMaterial3D.new()
		fix_mat.albedo_color = Color(1.0, 0.95, 0.8)
		fix_mat.emission_enabled = true
		fix_mat.emission = Color(1.0, 0.95, 0.8)
		fix_mat.emission_energy_multiplier = 3.0
		fixture.material = fix_mat
		add_child(fixture)

		# OmniLight3D for actual illumination
		var omni := OmniLight3D.new()
		omni.position = light_pos + Vector3.UP * 4.8
		omni.light_energy = 1.5
		omni.light_color = Color(1.0, 0.92, 0.75)
		omni.omni_range = 15.0
		omni.omni_attenuation = 1.5
		omni.shadow_enabled = false  # Performance — many lights
		add_child(omni)

# --- Environment: night, neon-lit ---

func _build_environment() -> void:
	# No sun — night scene. Use a dim directional for minimal fill
	var light := DirectionalLight3D.new()
	light.name = "MoonLight"
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 0.15
	light.light_color = Color(0.6, 0.65, 0.8)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.02, 0.06)
	sky_mat.sky_horizon_color = Color(0.05, 0.05, 0.1)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_mat.ground_horizon_color = Color(0.03, 0.03, 0.06)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2  # BG_SKY
	env.sky = sky
	env.ambient_light_source = 1  # AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.08, 0.12)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = 2  # Filmic
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_bloom = 0.3

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
