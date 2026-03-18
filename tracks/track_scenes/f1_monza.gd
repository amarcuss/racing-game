extends Node3D

## F1 Monza — The Temple of Speed. A ~5.8 km high-speed circuit famous for its
## long straights and tight chicanes, set in the parkland of the Royal Villa of Monza.
## All geometry built procedurally via ArrayMesh.

# --- Track geometry constants ---
const ROAD_WIDTH: float = 22.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 1024
const BARRIER_HEIGHT: float = 1.2
const BARRIER_WIDTH: float = 0.3

var num_checkpoints: int = 12
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0  # Set after generation — index on the first straight

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	# Place start/finish on the first straight (middle of waypoints 0-2)
	start_segment = track_points.size() / _get_waypoints().size() * 2
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_guardrails(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_kerbs(track_points)
	_build_gravel_traps()
	_build_scenery(track_points)
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
# Monza: The Temple of Speed. Long straights, tight chicanes, sweeping curves.
# Circuit flows clockwise. All flat (y=0).

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# === Start/finish straight heading north (z increasing) ===
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})        # wp 0 — start zone
	pts.append({"x": 0.0, "z": 150.0, "y": 0.0})       # wp 1
	pts.append({"x": 0.0, "z": 300.0, "y": 0.0})       # wp 2
	pts.append({"x": 0.0, "z": 450.0, "y": 0.0})       # wp 3
	pts.append({"x": 0.0, "z": 580.0, "y": 0.0})       # wp 4 — braking zone

	# === Variante del Rettifilo (first chicane — tight left-right) ===
	pts.append({"x": -30.0, "z": 620.0, "y": 0.0})     # wp 5 — left kink
	pts.append({"x": -10.0, "z": 660.0, "y": 0.0})     # wp 6 — right kink
	pts.append({"x": -25.0, "z": 700.0, "y": 0.0})     # wp 7 — exit

	# === Curva Grande (long sweeping right turn, radius ~200m) ===
	pts.append({"x": -40.0, "z": 780.0, "y": 0.0})     # wp 8 — entry
	pts.append({"x": -10.0, "z": 860.0, "y": 0.0})     # wp 9 — mid
	pts.append({"x": 60.0, "z": 920.0, "y": 0.0})      # wp 10
	pts.append({"x": 150.0, "z": 950.0, "y": 0.0})     # wp 11
	pts.append({"x": 250.0, "z": 940.0, "y": 0.0})     # wp 12 — apex
	pts.append({"x": 330.0, "z": 890.0, "y": 0.0})     # wp 13 — exit

	# === Variante della Roggia (second chicane — left-right-left) ===
	pts.append({"x": 370.0, "z": 840.0, "y": 0.0})     # wp 14 — braking
	pts.append({"x": 340.0, "z": 800.0, "y": 0.0})     # wp 15 — left
	pts.append({"x": 370.0, "z": 760.0, "y": 0.0})     # wp 16 — right
	pts.append({"x": 350.0, "z": 720.0, "y": 0.0})     # wp 17 — left exit

	# === Lesmo 1 (medium-speed right turn, ~100m radius) ===
	pts.append({"x": 360.0, "z": 660.0, "y": 0.0})     # wp 18 — entry
	pts.append({"x": 400.0, "z": 610.0, "y": 0.0})     # wp 19 — apex
	pts.append({"x": 420.0, "z": 550.0, "y": 0.0})     # wp 20 — exit

	# === Short connecting straight ===
	pts.append({"x": 430.0, "z": 490.0, "y": 0.0})     # wp 21

	# === Lesmo 2 (medium-speed right turn, ~80m radius) ===
	pts.append({"x": 450.0, "z": 430.0, "y": 0.0})     # wp 22 — entry
	pts.append({"x": 490.0, "z": 380.0, "y": 0.0})     # wp 23 — apex
	pts.append({"x": 510.0, "z": 320.0, "y": 0.0})     # wp 24 — exit

	# === Long back straight (~500m) ===
	pts.append({"x": 520.0, "z": 240.0, "y": 0.0})     # wp 25
	pts.append({"x": 520.0, "z": 120.0, "y": 0.0})     # wp 26
	pts.append({"x": 510.0, "z": 0.0, "y": 0.0})       # wp 27

	# === Variante Ascari (left-right-left chicane) ===
	pts.append({"x": 480.0, "z": -50.0, "y": 0.0})     # wp 28 — braking
	pts.append({"x": 450.0, "z": -90.0, "y": 0.0})     # wp 29 — left
	pts.append({"x": 480.0, "z": -130.0, "y": 0.0})    # wp 30 — right
	pts.append({"x": 450.0, "z": -170.0, "y": 0.0})    # wp 31 — left exit

	# === Short straight towards Parabolica ===
	pts.append({"x": 420.0, "z": -230.0, "y": 0.0})    # wp 32
	pts.append({"x": 380.0, "z": -290.0, "y": 0.0})    # wp 33

	# === Parabolica (long sweeping right, opens onto main straight) ===
	pts.append({"x": 320.0, "z": -340.0, "y": 0.0})    # wp 34 — entry
	pts.append({"x": 250.0, "z": -370.0, "y": 0.0})    # wp 35 — mid
	pts.append({"x": 170.0, "z": -370.0, "y": 0.0})    # wp 36 — apex
	pts.append({"x": 90.0, "z": -340.0, "y": 0.0})     # wp 37
	pts.append({"x": 30.0, "z": -280.0, "y": 0.0})     # wp 38 — exit
	pts.append({"x": 10.0, "z": -200.0, "y": 0.0})     # wp 39

	# === Approach to start/finish straight ===
	pts.append({"x": 5.0, "z": -100.0, "y": 0.0})      # wp 40

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

# --- Metal guardrails (both sides) ---

func _build_guardrails(points: Array[Dictionary]) -> void:
	_build_guardrail_side(points, -1.0, "InnerGuardrail")
	_build_guardrail_side(points, 1.0, "OuterGuardrail")

func _build_guardrail_side(points: Array[Dictionary], side: float, rail_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rail_mat := StandardMaterial3D.new()
	rail_mat.roughness = 0.4
	rail_mat.metallic = 0.7
	rail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rail_mat.vertex_color_use_as_albedo = true
	st.set_material(rail_mat)

	var faces := PackedVector3Array()
	var half_w: float = ROAD_WIDTH / 2.0
	var color_silver := Color(0.7, 0.72, 0.74)

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var base: Vector3 = p.position + right * half_w * side
		var base_next: Vector3 = p_next.position + right_next * half_w * side
		var top: Vector3 = base + Vector3.UP * BARRIER_HEIGHT
		var top_next: Vector3 = base_next + Vector3.UP * BARRIER_HEIGHT

		# Wall face
		st.set_color(color_silver)
		st.add_vertex(base)
		st.set_color(color_silver)
		st.add_vertex(base_next)
		st.set_color(color_silver)
		st.add_vertex(top)

		st.set_color(color_silver)
		st.add_vertex(top)
		st.set_color(color_silver)
		st.add_vertex(base_next)
		st.set_color(color_silver)
		st.add_vertex(top_next)

		# Top cap
		var outward: Vector3 = right * side * BARRIER_WIDTH
		var top_out: Vector3 = top + outward
		var top_next_out: Vector3 = top_next + outward

		st.set_color(color_silver)
		st.add_vertex(top)
		st.set_color(color_silver)
		st.add_vertex(top_next)
		st.set_color(color_silver)
		st.add_vertex(top_out)

		st.set_color(color_silver)
		st.add_vertex(top_out)
		st.set_color(color_silver)
		st.add_vertex(top_next)
		st.set_color(color_silver)
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
	# Lush green parkland ground
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(1000, 0.05, 1600)
	ground_mesh.position = Vector3(250, -0.025, 300)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.18, 0.4, 0.12)
	ground_mat.roughness = 0.95
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	# Safety-net collision
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(250, -5.0, 300)

	var box := BoxShape3D.new()
	box.size = Vector3(1000, 1, 1600)
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
	mat.emission_energy_multiplier = 0.3
	line.material = mat
	add_child(line)

	# Gantry posts — Italian racing red
	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.4, 6.0, 0.4)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 3.0
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.8, 0.1, 0.1)
		post_mat.metallic = 0.5
		post_mat.roughness = 0.3
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.5, 0.5)
	beam.position = p.position + Vector3.UP * 6.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.8, 0.1, 0.1)
	beam_mat.metallic = 0.5
	beam_mat.roughness = 0.3
	beam.material = beam_mat
	add_child(beam)

	# Chequered flag pattern — alternating black/white boxes on the beam
	for cx in range(8):
		for cy in range(2):
			var checker := CSGBox3D.new()
			checker.size = Vector3(ROAD_WIDTH / 8.0, 0.22, 0.05)
			var offset_x: float = -ROAD_WIDTH / 2.0 + (float(cx) + 0.5) * ROAD_WIDTH / 8.0
			var offset_y: float = 5.6 + float(cy) * 0.22
			checker.position = p.position + right * offset_x + Vector3.UP * offset_y + p.forward * 0.3
			checker.use_collision = false
			var ch_mat := StandardMaterial3D.new()
			if (cx + cy) % 2 == 0:
				ch_mat.albedo_color = Color(0.95, 0.95, 0.95)
			else:
				ch_mat.albedo_color = Color(0.05, 0.05, 0.05)
			checker.material = ch_mat
			add_child(checker)

# --- AI Path ---

func _build_ai_path() -> void:
	var curve := Curve3D.new()
	# Sample every few points for a smooth AI racing line
	var step: int = max(1, track_points.size() / 128)
	for i in range(0, track_points.size(), step):
		var p: Dictionary = track_points[i]
		curve.add_point(p.position + Vector3.UP * 0.5)
	ai_path = Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	add_child(ai_path)

# --- Kerbs at chicanes (red and white alternating strips) ---

func _build_kerbs(points: Array[Dictionary]) -> void:
	var wp: Array[Dictionary] = _get_waypoints()
	var wp_count: int = wp.size()
	var steps_per_seg: int = NUM_SEGMENTS / wp_count
	if steps_per_seg < 4:
		steps_per_seg = 4

	# Chicane zones defined by waypoint index ranges
	# Variante del Rettifilo: wp 5-7
	# Variante della Roggia: wp 14-17
	# Variante Ascari: wp 28-31
	var chicane_ranges: Array[Array] = [
		[5, 7],   # First chicane
		[14, 17], # Second chicane
		[28, 31], # Ascari
	]

	for crange in chicane_ranges:
		var start_idx: int = crange[0] * steps_per_seg
		var end_idx: int = (crange[1] + 1) * steps_per_seg
		if end_idx > points.size():
			end_idx = points.size()

		# Place kerb strips every few segments through the chicane
		var kerb_count: int = 0
		for i in range(start_idx, end_idx, 3):
			if i >= points.size():
				break
			var p: Dictionary = points[i]
			var right: Vector3 = _get_right(p)
			var half_w: float = ROAD_WIDTH / 2.0

			# Kerbs on both sides of the road
			for side_val in [-1.0, 1.0]:
				var kerb := CSGBox3D.new()
				kerb.size = Vector3(1.5, 0.06, 1.8)
				var kerb_pos: Vector3 = p.position + right * side_val * (half_w - 0.5) + Vector3.UP * 0.03
				kerb.position = kerb_pos
				kerb.use_collision = false

				var kerb_mat := StandardMaterial3D.new()
				if kerb_count % 2 == 0:
					kerb_mat.albedo_color = Color(0.85, 0.1, 0.1)  # Red
				else:
					kerb_mat.albedo_color = Color(0.95, 0.95, 0.95)  # White
				kerb_mat.roughness = 0.7
				kerb.material = kerb_mat
				add_child(kerb)

			kerb_count += 1

# --- Gravel traps at chicane exits ---

func _build_gravel_traps() -> void:
	# Place tan gravel trap areas at the exits of each chicane
	var gravel_positions: Array[Dictionary] = [
		# Variante del Rettifilo exit — outside of the left kink
		{"x": 20.0, "z": 630.0, "sx": 20.0, "sz": 30.0},
		{"x": -55.0, "z": 660.0, "sx": 20.0, "sz": 30.0},
		# Variante della Roggia exit
		{"x": 400.0, "z": 800.0, "sx": 20.0, "sz": 25.0},
		{"x": 320.0, "z": 760.0, "sx": 20.0, "sz": 25.0},
		# Ascari chicane exit
		{"x": 510.0, "z": -90.0, "sx": 20.0, "sz": 25.0},
		{"x": 420.0, "z": -130.0, "sx": 20.0, "sz": 25.0},
		# Parabolica exit
		{"x": 60.0, "z": -390.0, "sx": 30.0, "sz": 20.0},
	]

	var gravel_mat := StandardMaterial3D.new()
	gravel_mat.albedo_color = Color(0.72, 0.62, 0.42)
	gravel_mat.roughness = 0.95

	for gp in gravel_positions:
		var trap := CSGBox3D.new()
		trap.size = Vector3(gp.sx, 0.08, gp.sz)
		trap.position = Vector3(gp.x, 0.04, gp.z)
		trap.use_collision = false
		trap.material = gravel_mat
		add_child(trap)

# --- Scenery: parkland trees ---

func _build_scenery(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77  # Deterministic placement

	# Place trees alongside the road — Monza is set in a park
	for i in range(0, points.size(), 14):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.55:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + 5.0 + rng.randf() * 20.0
			var tree_pos: Vector3 = p.position + right * side_val * offset
			tree_pos.y = -0.3
			_add_park_tree(tree_pos, rng)

	# Additional scattered trees further from the track for depth
	for i in range(0, points.size(), 30):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.4:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + 30.0 + rng.randf() * 40.0
			var tree_pos: Vector3 = p.position + right * side_val * offset
			tree_pos.y = -0.3
			_add_park_tree(tree_pos, rng)

func _add_park_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	# Deciduous tree — trunk + sphere crown (Italian parkland style)
	var trunk := CSGCylinder3D.new()
	trunk.radius = 0.2 + rng.randf() * 0.15
	var tree_height: float = 5.0 + rng.randf() * 4.0
	trunk.height = tree_height * 0.45
	trunk.position = pos + Vector3.UP * trunk.height / 2.0
	trunk.use_collision = false
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.3, 0.2, 0.1)
	trunk_mat.roughness = 0.9
	trunk.material = trunk_mat
	add_child(trunk)

	# Crown — sphere for deciduous look
	var crown := CSGSphere3D.new()
	crown.radius = 1.5 + rng.randf() * 1.5
	crown.position = pos + Vector3.UP * (trunk.height + crown.radius * 0.6)
	crown.use_collision = false
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.15 + rng.randf() * 0.1, 0.35 + rng.randf() * 0.15, 0.1)
	crown_mat.roughness = 0.85
	crown.material = crown_mat
	add_child(crown)

# --- Environment: sunny Italian day ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.95, 0.85)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.65, 0.75, 0.9)
	sky_mat.ground_bottom_color = Color(0.15, 0.25, 0.1)
	sky_mat.ground_horizon_color = Color(0.4, 0.5, 0.35)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2  # BG_SKY
	env.sky = sky
	env.ambient_light_source = 2  # AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = 2  # Filmic
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
