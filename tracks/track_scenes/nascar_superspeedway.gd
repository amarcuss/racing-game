extends Node3D

## Daytona Superspeedway — 4.0 km D-shaped oval with 31° banking, 20m wide road.
## All geometry is built procedurally via ArrayMesh for clean collision.

# --- Track geometry constants ---
const TURN_RADIUS: float = 150.0
const STRAIGHT_LENGTH: float = 500.0
const HALF_STRAIGHT: float = 250.0
const ROAD_WIDTH: float = 20.0
const BANK_ANGLE: float = 0.42  # ~24 degrees (reduced for stability)
const STRAIGHT_BANK: float = 0.0
const NUM_SEGMENTS: int = 384
const BARRIER_HEIGHT: float = 2.5
const BARRIER_WIDTH: float = 0.5
const BARRIER_OFFSET: float = 0.0
const ROAD_Y: float = 0.15

var num_checkpoints: int = 4
var perimeter: float
var ai_path: Path3D

func _ready() -> void:
	perimeter = 2.0 * STRAIGHT_LENGTH + 2.0 * PI * TURN_RADIUS
	var points := _generate_track_points()
	_build_road_mesh(points)
	_build_road_collision(points)
	_build_barrier_wall(points, -1.0, "InnerBarrier")
	_build_barrier_wall(points, 1.0, "OuterBarrier")
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_environment()
	_build_pit_road_visual()
	_build_catch_fence(points)

func get_spawn_transform(index: int) -> Transform3D:
	var stagger_z: float = -15.0 - float(index) * 8.0
	var side_offset: float = 3.0 if index % 2 == 1 else -3.0
	var pos := Vector3(TURN_RADIUS + side_offset, 1.5, stagger_z)
	return Transform3D(Basis.IDENTITY.rotated(Vector3.UP, PI), pos)

func get_num_checkpoints() -> int:
	return num_checkpoints

func get_ai_path() -> Path3D:
	return ai_path

func get_perimeter() -> float:
	return perimeter

# --- Track point generation ---

func _generate_track_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	for i in range(NUM_SEGMENTS):
		var s: float = float(i) / float(NUM_SEGMENTS) * perimeter
		points.append(_compute_point(s))
	return points

func _compute_point(s: float) -> Dictionary:
	var s1: float = STRAIGHT_LENGTH
	var s2: float = STRAIGHT_LENGTH + PI * TURN_RADIUS
	var s3: float = 2.0 * STRAIGHT_LENGTH + PI * TURN_RADIUS

	var pos: Vector3
	var fwd: Vector3
	var bank: float = 0.0

	if s < s1:
		# Right straight
		pos = Vector3(TURN_RADIUS, ROAD_Y, -HALF_STRAIGHT + s)
		fwd = Vector3(0.0, 0.0, 1.0)
	elif s < s2:
		# Top turn
		var arc: float = s - s1
		var angle: float = arc / TURN_RADIUS
		var t_norm: float = angle / PI
		bank = BANK_ANGLE * _bank_factor(t_norm)
		var bank_lift: float = sin(bank) * ROAD_WIDTH / 2.0
		pos = Vector3(
			TURN_RADIUS * cos(angle),
			ROAD_Y + bank_lift,
			HALF_STRAIGHT + TURN_RADIUS * sin(angle)
		)
		fwd = Vector3(-sin(angle), 0.0, cos(angle))
	elif s < s3:
		# Left straight (tri-oval front stretch — slight kink)
		var d: float = s - s2
		var t_str: float = d / STRAIGHT_LENGTH
		# Tri-oval: slight outward bump at midpoint
		var tri_offset: float = sin(t_str * PI) * 8.0
		pos = Vector3(-TURN_RADIUS - tri_offset, ROAD_Y, HALF_STRAIGHT - d)
		fwd = Vector3(0.0, 0.0, -1.0)
	else:
		# Bottom turn
		var arc: float = s - s3
		var angle: float = PI + arc / TURN_RADIUS
		var t_norm: float = (angle - PI) / PI
		bank = BANK_ANGLE * _bank_factor(t_norm)
		var bank_lift: float = sin(bank) * ROAD_WIDTH / 2.0
		pos = Vector3(
			TURN_RADIUS * cos(angle),
			ROAD_Y + bank_lift,
			-HALF_STRAIGHT + TURN_RADIUS * sin(angle)
		)
		fwd = Vector3(-sin(angle), 0.0, cos(angle))

	return {"position": pos, "forward": fwd.normalized(), "banking": bank}

func _bank_factor(t: float) -> float:
	# Very gradual ramp: 40% in, 40% out — prevents spin on entry/exit
	return smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(0.6, 1.0, t))

func _basis_facing(direction: Vector3) -> Basis:
	var forward: Vector3 = direction.normalized()
	var right: Vector3 = Vector3.UP.cross(forward)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = forward.cross(right).normalized()
	return Basis(right, up, -forward)

func _get_banked_right(point: Dictionary) -> Vector3:
	var fwd: Vector3 = point.forward
	var right_flat: Vector3 = Vector3.UP.cross(fwd).normalized()
	var banking: float = point.banking
	if banking > 0.001:
		return right_flat.rotated(fwd, banking)
	return right_flat

# --- Road mesh ---

func _build_road_mesh(points: Array[Dictionary]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.1, 0.1, 0.1)
	road_mat.roughness = 0.85
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(road_mat)

	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var right: Vector3 = _get_banked_right(p)
		var right_next: Vector3 = _get_banked_right(p_next)

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

		var right: Vector3 = _get_banked_right(p)
		var right_next: Vector3 = _get_banked_right(p_next)

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

# --- Barriers ---

func _build_barrier_wall(points: Array[Dictionary], side: float, wall_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.roughness = 0.7
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	barrier_mat.vertex_color_use_as_albedo = true
	st.set_material(barrier_mat)

	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0 + BARRIER_OFFSET
	var up := Vector3.UP
	var color_concrete := Color(0.75, 0.73, 0.7)
	var color_yellow := Color(0.95, 0.8, 0.1)
	var color_black := Color(0.05, 0.05, 0.05)

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var seg_color: Color
		var in_turn: bool = p.banking > 0.001
		if in_turn:
			seg_color = color_yellow if (i % 6 < 3) else color_black
		else:
			seg_color = color_concrete

		var right: Vector3 = _get_banked_right(p)
		var right_next: Vector3 = _get_banked_right(p_next)

		var base: Vector3 = p.position + right * half_w * side
		var base_next: Vector3 = p_next.position + right_next * half_w * side
		var top: Vector3 = base + up * BARRIER_HEIGHT
		var top_next: Vector3 = base_next + up * BARRIER_HEIGHT

		st.set_color(seg_color)
		st.add_vertex(base)
		st.set_color(seg_color)
		st.add_vertex(base_next)
		st.set_color(seg_color)
		st.add_vertex(top)

		st.set_color(seg_color)
		st.add_vertex(top)
		st.set_color(seg_color)
		st.add_vertex(base_next)
		st.set_color(seg_color)
		st.add_vertex(top_next)

		var outward: Vector3 = right * side * BARRIER_WIDTH
		var top_out: Vector3 = top + outward
		var top_next_out: Vector3 = top_next + outward

		st.set_color(seg_color)
		st.add_vertex(top)
		st.set_color(seg_color)
		st.add_vertex(top_next)
		st.set_color(seg_color)
		st.add_vertex(top_out)

		st.set_color(seg_color)
		st.add_vertex(top_out)
		st.set_color(seg_color)
		st.add_vertex(top_next)
		st.set_color(seg_color)
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

# --- Ground ---

func _build_ground() -> void:
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(800, 0.05, 1000)
	ground_mesh.position = Vector3(0, -0.025, 0)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.45, 0.2)
	ground_mat.roughness = 0.95
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(0, -2.0, 0)

	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 1000)
	var col := CollisionShape3D.new()
	col.shape = box
	ground_body.add_child(col)
	add_child(ground_body)

# --- Checkpoints ---

func _build_checkpoints() -> void:
	var start_finish_s: float = HALF_STRAIGHT

	for i in range(num_checkpoints):
		var s: float = fmod(start_finish_s + float(i) / float(num_checkpoints) * perimeter, perimeter)
		var p: Dictionary = _compute_point(s)

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
		shape.size = Vector3(ROAD_WIDTH + 4.0, 6.0, 3.0)
		var col := CollisionShape3D.new()
		col.shape = shape
		cp.add_child(col)
		add_child(cp)

# --- Start/Finish visual ---

func _build_start_finish_visual() -> void:
	var s: float = HALF_STRAIGHT
	var p: Dictionary = _compute_point(s)
	var right: Vector3 = _get_banked_right(p)
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
	mat.emission_energy_multiplier = 0.3
	line.material = mat
	add_child(line)

	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.5, 8.0, 0.5)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 4.0
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.8, 0.8, 0.8)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.2
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 2.0, 0.6, 0.6)
	beam.position = p.position + Vector3.UP * 8.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.3, 0.3, 0.3)
	beam_mat.metallic = 0.6
	beam_mat.roughness = 0.3
	beam.material = beam_mat
	add_child(beam)

# --- AI Path ---

func _build_ai_path() -> void:
	var curve := Curve3D.new()
	var num_samples: int = 96
	for i in range(num_samples):
		var s: float = float(i) / float(num_samples) * perimeter
		var p: Dictionary = _compute_point(s)
		curve.add_point(p.position + Vector3.UP * 0.5)
	ai_path = Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	add_child(ai_path)

# --- Pit road (visual only) ---

func _build_pit_road_visual() -> void:
	var pit := CSGBox3D.new()
	pit.name = "PitRoad"
	pit.size = Vector3(8.0, 0.02, 300.0)
	pit.position = Vector3(TURN_RADIUS + ROAD_WIDTH * 0.5 + 6.0, ROAD_Y + 0.01, 0)
	pit.use_collision = false
	var pit_mat := StandardMaterial3D.new()
	pit_mat.albedo_color = Color(0.15, 0.15, 0.15)
	pit_mat.roughness = 0.8
	pit.material = pit_mat
	add_child(pit)

	# Pit wall
	var pit_wall := CSGBox3D.new()
	pit_wall.size = Vector3(0.3, 1.2, 300.0)
	pit_wall.position = Vector3(TURN_RADIUS + ROAD_WIDTH * 0.5 + 2.0, ROAD_Y + 0.6, 0)
	pit_wall.use_collision = false
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.7, 0.7, 0.7)
	pit_wall.material = wall_mat
	add_child(pit_wall)

# --- Catch fence above outer wall ---

func _build_catch_fence(points: Array[Dictionary]) -> void:
	# Simplified catch fence — tall posts along outer wall in turns
	var half_w: float = ROAD_WIDTH / 2.0
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.6, 0.6, 0.6, 0.4)
	fence_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fence_mat.metallic = 0.8

	var post_spacing: int = points.size() / 32
	for i in range(0, points.size(), post_spacing):
		var p: Dictionary = points[i]
		if p.banking < 0.01:
			continue
		var right: Vector3 = _get_banked_right(p)
		var post_pos: Vector3 = p.position + right * (half_w + 0.3) + Vector3.UP * (BARRIER_HEIGHT + 2.0)
		var post := CSGBox3D.new()
		post.size = Vector3(0.1, 4.0, 0.1)
		post.position = post_pos
		post.use_collision = false
		post.material = fence_mat
		add_child(post)

# --- Environment ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.9)
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.1)
	sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.45)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2
	env.sky = sky
	env.ambient_light_source = 2
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = 2
	env.ssao_enabled = true
	env.glow_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
