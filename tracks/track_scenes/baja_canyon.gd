extends Node3D

## Baja Canyon Run — 4km point-to-point desert track through narrow canyon walls.
## Winding path with sharp elevation changes, mesa walls on sides.
## All geometry built procedurally via ArrayMesh.

const ROAD_WIDTH: float = 14.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 512
const BARRIER_HEIGHT: float = 1.5
const BARRIER_WIDTH: float = 0.4

var num_checkpoints: int = 10
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var obstacle_dodges: Dictionary = {}
var race_end_index: int = 0  # Track point index where the race finish line is (before run-off)
const RUNOFF_WAYPOINTS: int = 2  # Number of extra waypoints past the finish

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_guardrails(track_points)
	_build_ground()
	_build_road_obstacles(track_points)
	_build_checkpoints()
	_build_ai_path()
	_build_scenery(track_points)
	_build_environment()

func get_spawn_transform(index: int) -> Transform3D:
	# Spawn near start of the point-to-point route
	var seg_idx: int = clampi(3 + index * 3, 0, track_points.size() - 1)
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

# --- Track layout: open path (no loop closure) ---

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# Start in a dry valley
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 0.0, "z": 100.0, "y": 2.0})
	pts.append({"x": 20.0, "z": 200.0, "y": 8.0})

	# Enter canyon — walls close in
	pts.append({"x": 50.0, "z": 300.0, "y": 15.0})
	pts.append({"x": 100.0, "z": 380.0, "y": 22.0})

	# Sharp switchback climbing
	pts.append({"x": 140.0, "z": 420.0, "y": 30.0})
	pts.append({"x": 120.0, "z": 480.0, "y": 38.0})
	pts.append({"x": 60.0, "z": 520.0, "y": 45.0})

	# Narrow canyon passage
	pts.append({"x": 0.0, "z": 580.0, "y": 50.0})
	pts.append({"x": -40.0, "z": 660.0, "y": 55.0})

	# High mesa section — winding
	pts.append({"x": -100.0, "z": 720.0, "y": 60.0})
	pts.append({"x": -160.0, "z": 760.0, "y": 58.0})
	pts.append({"x": -220.0, "z": 820.0, "y": 52.0})

	# Descent through rocky pass
	pts.append({"x": -280.0, "z": 900.0, "y": 42.0})
	pts.append({"x": -320.0, "z": 980.0, "y": 30.0})

	# Final approach — opens up
	pts.append({"x": -350.0, "z": 1060.0, "y": 20.0})
	pts.append({"x": -370.0, "z": 1140.0, "y": 12.0})
	pts.append({"x": -380.0, "z": 1220.0, "y": 5.0})

	# Finish in open desert
	pts.append({"x": -380.0, "z": 1300.0, "y": 2.0})
	pts.append({"x": -380.0, "z": 1380.0, "y": 0.0})

	# === FINISH LINE IS HERE (index 19) ===
	# Run-off area past finish (cars coast here after crossing last checkpoint)
	pts.append({"x": -380.0, "z": 1460.0, "y": 0.0})
	pts.append({"x": -380.0, "z": 1560.0, "y": 0.0})

	return pts

func _generate_track_points() -> Array[Dictionary]:
	var waypoints: Array[Dictionary] = _get_waypoints()
	var wp_count: int = waypoints.size()
	var points: Array[Dictionary] = []

	# Open path — Catmull-Rom without wrapping
	var steps_per_seg: int = NUM_SEGMENTS / (wp_count - 1)
	if steps_per_seg < 4:
		steps_per_seg = 4

	var race_wp_count: int = wp_count - RUNOFF_WAYPOINTS

	for seg in range(wp_count - 1):
		var p0_idx: int = maxi(seg - 1, 0)
		var p1_idx: int = seg
		var p2_idx: int = seg + 1
		var p3_idx: int = mini(seg + 2, wp_count - 1)

		var p0: Vector3 = _wp_to_vec3(waypoints[p0_idx])
		var p1: Vector3 = _wp_to_vec3(waypoints[p1_idx])
		var p2: Vector3 = _wp_to_vec3(waypoints[p2_idx])
		var p3: Vector3 = _wp_to_vec3(waypoints[p3_idx])

		# Mark the race end (start of first run-off segment)
		if seg == race_wp_count - 1:
			race_end_index = points.size()

		for i in range(steps_per_seg):
			var t: float = float(i) / float(steps_per_seg)
			var pos: Vector3 = _catmull_rom(p0, p1, p2, p3, t)
			points.append({"position": pos, "forward": Vector3.ZERO, "banking": 0.0})

	# Add final waypoint
	points.append({"position": _wp_to_vec3(waypoints[wp_count - 1]), "forward": Vector3.ZERO, "banking": 0.0})

	# Compute forward directions (open path — last point uses same direction as previous)
	for i in range(points.size()):
		var next_i: int = mini(i + 1, points.size() - 1)
		if i == next_i:
			if i > 0:
				points[i].forward = points[i - 1].forward
			else:
				points[i].forward = Vector3.FORWARD
		else:
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
	for i in range(points.size() - 1):
		total += points[i].position.distance_to(points[i + 1].position)
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

# --- Road mesh (open path) ---

func _build_road_mesh(points: Array[Dictionary]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.55, 0.42, 0.3)
	road_mat.roughness = 0.95
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(road_mat)

	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(points.size() - 1):
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[i + 1]

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

# --- Road collision (open path) ---

func _build_road_collision(points: Array[Dictionary]) -> void:
	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(points.size() - 1):
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[i + 1]

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

# --- Guardrails (canyon walls — only where elevation is high) ---

func _build_guardrails(points: Array[Dictionary]) -> void:
	_build_guardrail_side(points, -1.0, "LeftWall")
	_build_guardrail_side(points, 1.0, "RightWall")

func _build_guardrail_side(points: Array[Dictionary], side: float, rail_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.roughness = 0.9
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall_mat.vertex_color_use_as_albedo = true
	st.set_material(wall_mat)

	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0
	var wall_color := Color(0.6, 0.45, 0.3)
	var wall_height: float = 4.0  # Tall canyon walls

	for i in range(points.size() - 1):
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[i + 1]

		# Only build walls where elevation > 10 (in the canyon section)
		if p.position.y < 10.0 and p_next.position.y < 10.0:
			continue

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var base: Vector3 = p.position + right * half_w * side
		var base_next: Vector3 = p_next.position + right_next * half_w * side
		var top: Vector3 = base + Vector3.UP * wall_height
		var top_next: Vector3 = base_next + Vector3.UP * wall_height

		st.set_color(wall_color)
		st.add_vertex(base)
		st.set_color(wall_color)
		st.add_vertex(base_next)
		st.set_color(wall_color)
		st.add_vertex(top)

		st.set_color(wall_color)
		st.add_vertex(top)
		st.set_color(wall_color)
		st.add_vertex(base_next)
		st.set_color(wall_color)
		st.add_vertex(top_next)

		faces.append(base)
		faces.append(base_next)
		faces.append(top)
		faces.append(top)
		faces.append(base_next)
		faces.append(top_next)

	if faces.size() == 0:
		return

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = rail_name + "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true

	var body := StaticBody3D.new()
	body.name = rail_name + "Collision"
	body.collision_layer = 1
	body.collision_mask = 0

	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	body.add_child(col_shape)
	add_child(body)

# --- Ground ---

func _build_ground() -> void:
	# Large desert ground planes
	for gz in range(-1, 5):
		var ground := CSGBox3D.new()
		ground.name = "Ground%d" % gz
		ground.size = Vector3(800, 0.05, 500)
		ground.position = Vector3(-190, -0.025, float(gz) * 400.0 + 200.0)
		ground.use_collision = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.76, 0.65, 0.45)
		mat.roughness = 0.95
		ground.material = mat
		add_child(ground)

	# Safety-net collision (at ground level so cars don't fall)
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(-190, -0.5, 700)

	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 2200)
	var col := CollisionShape3D.new()
	col.shape = box
	ground_body.add_child(col)
	add_child(ground_body)

# --- Checkpoints (evenly spaced along open path) ---

func _build_checkpoints() -> void:
	var end_pt: int = race_end_index if race_end_index > 0 else track_points.size()

	for i in range(num_checkpoints):
		var seg_idx: int
		# Spread checkpoints evenly but start past spawn zone (~5% in)
		var frac: float = float(i) / float(num_checkpoints - 1)
		seg_idx = int(lerpf(float(end_pt) * 0.05, float(end_pt - 1), frac))
		seg_idx = clampi(seg_idx, 0, track_points.size() - 1)
		var p: Dictionary = track_points[seg_idx]

		var cp := Area3D.new()
		cp.name = "Checkpoint%d" % i
		cp.set_script(preload("res://tracks/components/checkpoint.gd"))
		cp.checkpoint_index = i
		cp.is_start_finish = false  # No start/finish in point-to-point
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

# --- Road obstacles: fallen rocks, boulders in the canyon ---

func _build_road_obstacles(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	var total: int = points.size()
	var half_w: float = ROAD_WIDTH / 2.0

	var start_i: int = int(total * 0.10)
	var end_i: int = int(total * 0.85)

	var obstacle_interval: int = 25
	var i: int = start_i
	while i < end_i:
		i += obstacle_interval + rng.randi_range(-5, 8)
		if i >= end_i:
			break
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var lateral: float = side * half_w * rng.randf_range(0.3, 0.6)
		var pos: Vector3 = p.position + right * lateral

		# Canyon has more rocks, fewer dunes
		if rng.randf() > 0.3:
			_add_fallen_boulder(pos, rng)
		else:
			_add_dirt_ramp(pos, rng)

		for di in range(-8, 9):
			var si: int = clampi(i + di, 0, total - 1)
			obstacle_dodges[si] = -side

func _add_fallen_boulder(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var rock := CSGBox3D.new()
	var sx: float = 1.5 + rng.randf() * 1.5
	var sy: float = 0.6 + rng.randf() * 0.5
	var sz: float = 1.5 + rng.randf() * 1.5
	rock.size = Vector3(sx, sy, sz)
	rock.position = pos + Vector3.UP * sy * 0.5
	rock.rotation_degrees = Vector3(rng.randf() * 10.0, rng.randf() * 60.0, rng.randf() * 10.0)
	rock.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.35)
	mat.roughness = 0.95
	rock.material = mat
	add_child(rock)

func _add_dirt_ramp(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var ramp := CSGBox3D.new()
	ramp.size = Vector3(3.0, 0.35, 3.5)
	ramp.position = pos + Vector3.UP * 0.17
	ramp.rotation_degrees.x = -8.0 + rng.randf_range(-3.0, 3.0)
	ramp.rotation_degrees.y = rng.randf_range(-15.0, 15.0)
	ramp.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.5, 0.35)
	mat.roughness = 0.95
	ramp.material = mat
	add_child(ramp)

# --- AI Path (with obstacle dodging) ---

func _build_ai_path() -> void:
	var curve := Curve3D.new()
	var step: int = max(1, track_points.size() / 128)
	var half_w: float = ROAD_WIDTH / 2.0

	for i in range(0, track_points.size(), step):
		var p: Dictionary = track_points[i]
		var pos: Vector3 = p.position + Vector3.UP * 0.5

		if obstacle_dodges.has(i):
			var dodge_side: float = obstacle_dodges[i]
			var right: Vector3 = _get_right(p)
			pos += right * dodge_side * half_w * 0.35

		curve.add_point(pos)

	var last_p: Dictionary = track_points[track_points.size() - 1]
	curve.add_point(last_p.position + Vector3.UP * 0.5)
	ai_path = Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	add_child(ai_path)

# --- Scenery: cacti, rock formations, mesa plateaus ---

func _build_scenery(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101

	# Mesa walls alongside canyon sections
	for i in range(0, points.size(), 40):
		var p: Dictionary = points[i]
		if p.position.y < 15.0:
			continue
		var right: Vector3 = _get_right(p)
		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.6:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + 8.0 + rng.randf() * 10.0
			var mesa_pos: Vector3 = p.position + right * side_val * offset
			_add_mesa(mesa_pos, rng)

	# Cacti alongside road
	for i in range(0, points.size(), 12):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)
		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.4:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + 3.0 + rng.randf() * 15.0
			var cactus_pos: Vector3 = p.position + right * side_val * offset
			cactus_pos.y = p.position.y - 0.5
			_add_cactus(cactus_pos, rng)

	# Rock formations
	for i in range(0, points.size(), 18):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)
		if rng.randf() > 0.35:
			continue
		var side_val: float = 1.0 if rng.randf() > 0.5 else -1.0
		var offset: float = ROAD_WIDTH / 2.0 + 5.0 + rng.randf() * 20.0
		var rock_pos: Vector3 = p.position + right * side_val * offset
		rock_pos.y = p.position.y - 0.3
		_add_rock_formation(rock_pos, rng)

func _add_mesa(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var mesa := CSGBox3D.new()
	var sx: float = 8.0 + rng.randf() * 12.0
	var sy: float = 6.0 + rng.randf() * 10.0
	var sz: float = 6.0 + rng.randf() * 8.0
	mesa.size = Vector3(sx, sy, sz)
	mesa.position = Vector3(pos.x, pos.y + sy * 0.3, pos.z)
	mesa.rotation_degrees.y = rng.randf() * 30.0
	mesa.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65 + rng.randf() * 0.1, 0.45 + rng.randf() * 0.1, 0.3)
	mat.roughness = 0.95
	mesa.material = mat
	add_child(mesa)

func _add_cactus(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := CSGCylinder3D.new()
	var h: float = 2.0 + rng.randf() * 3.0
	trunk.radius = 0.15 + rng.randf() * 0.1
	trunk.height = h
	trunk.sides = 8
	trunk.position = pos + Vector3.UP * h * 0.5
	trunk.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.15)
	mat.roughness = 0.9
	trunk.material = mat
	add_child(trunk)

	# Arms
	if rng.randf() > 0.4:
		for arm_i in range(rng.randi_range(1, 2)):
			var arm := CSGCylinder3D.new()
			arm.radius = trunk.radius * 0.7
			arm.height = h * 0.4
			arm.sides = 8
			arm.rotation.z = (PI / 3.0) * (1.0 if arm_i == 0 else -1.0)
			var arm_y: float = h * (0.4 + rng.randf() * 0.3)
			arm.position = pos + Vector3.UP * arm_y + Vector3(0.3 * (1.0 if arm_i == 0 else -1.0), 0, 0)
			arm.use_collision = false
			arm.material = mat
			add_child(arm)

func _add_rock_formation(pos: Vector3, rng: RandomNumberGenerator) -> void:
	for _j in range(rng.randi_range(2, 4)):
		var rock := CSGBox3D.new()
		var sx: float = 1.0 + rng.randf() * 3.0
		var sy: float = 0.8 + rng.randf() * 2.0
		var sz: float = 1.0 + rng.randf() * 3.0
		rock.size = Vector3(sx, sy, sz)
		var offset := Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
		rock.position = pos + offset + Vector3.UP * sy * 0.5
		rock.rotation_degrees = Vector3(rng.randf() * 15.0, rng.randf() * 360.0, rng.randf() * 15.0)
		rock.use_collision = false
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55 + rng.randf() * 0.1, 0.45 + rng.randf() * 0.05, 0.35)
		mat.roughness = 0.95
		rock.material = mat
		add_child(rock)

# --- Environment: warm desert ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.light_energy = 1.1
	light.light_color = Color(1.0, 0.92, 0.8)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.8, 0.7, 0.55)
	sky_mat.ground_bottom_color = Color(0.55, 0.42, 0.3)
	sky_mat.ground_horizon_color = Color(0.75, 0.6, 0.45)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2
	env.sky = sky
	env.ambient_light_source = 2
	env.ambient_light_color = Color(0.7, 0.6, 0.5)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = 2
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.7, 0.55)
	env.fog_density = 0.001

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
