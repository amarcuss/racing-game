extends Node3D

## Airport Circuit — 2.5 km street circuit on airport runways and taxiways.
## Wide tarmac, sweeping turns around hangars, a long runway straight,
## and tight taxiway sections. All geometry built procedurally.

# --- Track geometry constants ---
const ROAD_WIDTH: float = 16.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 512
const WALL_HEIGHT: float = 1.2
const WALL_WIDTH: float = 0.3

var num_checkpoints: int = 6
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	start_segment = track_points.size() / _get_waypoints().size() * 2
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_walls(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_hangars()
	_build_control_tower()
	_build_parked_planes()
	_build_runway_markings()
	_build_runway_lights(track_points)
	_build_environment()

func get_spawn_transform(index: int) -> Transform3D:
	var stagger: int = 3 + index * 3
	var seg_idx: int = (start_segment - stagger + track_points.size()) % track_points.size()
	var p: Dictionary = track_points[seg_idx]
	var pos: Vector3 = p.position + Vector3.UP * 1.0
	var side_offset: float = 2.0 if index % 2 == 1 else -2.0
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
# Airport circuit: long runway straight, sweeping turns around hangars,
# tight taxiway connector, back via parallel taxiway.

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# === Runway straight heading east (main straight) ===
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 120.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 250.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 380.0, "z": 0.0, "y": 0.0})

	# === Turn 1 — wide right onto cross taxiway ===
	pts.append({"x": 440.0, "z": -20.0, "y": 0.0})
	pts.append({"x": 470.0, "z": -60.0, "y": 0.0})
	pts.append({"x": 480.0, "z": -110.0, "y": 0.0})

	# === Hangar complex — sweeping left through apron ===
	pts.append({"x": 470.0, "z": -170.0, "y": 0.0})
	pts.append({"x": 440.0, "z": -220.0, "y": 0.0})
	pts.append({"x": 390.0, "z": -250.0, "y": 0.0})

	# === Turn 3 — wide left back heading west ===
	pts.append({"x": 330.0, "z": -260.0, "y": 0.0})
	pts.append({"x": 270.0, "z": -250.0, "y": 0.0})

	# === Back taxiway heading west (parallel to runway) ===
	pts.append({"x": 200.0, "z": -240.0, "y": 0.0})
	pts.append({"x": 120.0, "z": -240.0, "y": 0.0})

	# === Chicane through cargo area ===
	pts.append({"x": 80.0, "z": -230.0, "y": 0.0})
	pts.append({"x": 50.0, "z": -245.0, "y": 0.0})
	pts.append({"x": 20.0, "z": -230.0, "y": 0.0})

	# === Turn 5 — right turn heading north back to runway ===
	pts.append({"x": -20.0, "z": -210.0, "y": 0.0})
	pts.append({"x": -40.0, "z": -170.0, "y": 0.0})
	pts.append({"x": -50.0, "z": -120.0, "y": 0.0})

	# === Connector taxiway heading north ===
	pts.append({"x": -45.0, "z": -70.0, "y": 0.0})
	pts.append({"x": -30.0, "z": -30.0, "y": 0.0})

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
	road_mat.albedo_color = Color(0.12, 0.12, 0.13)
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

# --- Jersey barriers (low, airport-style) ---

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
	var color_barrier := Color(0.75, 0.35, 0.05)  # Orange jersey barriers
	var color_white := Color(0.85, 0.85, 0.85)

	for i in range(points.size()):
		var next_i: int = (i + 1) % points.size()
		var p: Dictionary = points[i]
		var p_next: Dictionary = points[next_i]

		var seg_color: Color = color_barrier if (i % 8 < 4) else color_white

		var right: Vector3 = _get_right(p)
		var right_next: Vector3 = _get_right(p_next)

		var base: Vector3 = p.position + right * half_w * side
		var base_next: Vector3 = p_next.position + right_next * half_w * side
		var top: Vector3 = base + Vector3.UP * WALL_HEIGHT
		var top_next: Vector3 = base_next + Vector3.UP * WALL_HEIGHT

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

		var outward: Vector3 = right * side * WALL_WIDTH
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
	# Tarmac apron — large flat concrete area
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(800, 0.05, 600)
	ground_mesh.position = Vector3(220, -0.025, -120)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.18, 0.18, 0.17)
	ground_mat.roughness = 0.9
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	# Grass beyond the tarmac
	var grass := CSGBox3D.new()
	grass.name = "GrassMesh"
	grass.size = Vector3(1200, 0.04, 1000)
	grass.position = Vector3(220, -0.04, -120)
	grass.use_collision = false
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.2, 0.4, 0.15)
	grass_mat.roughness = 0.95
	grass.material = grass_mat
	add_child(grass)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(220, -2.0, -120)

	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 600)
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
		post.size = Vector3(0.4, 6.0, 0.4)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 3.0
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.8, 0.8, 0.8)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.2
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.4, 0.4)
	beam.position = p.position + Vector3.UP * 6.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.2, 0.2, 0.2)
	beam_mat.metallic = 0.6
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

# --- Hangars ---

func _build_hangars() -> void:
	var hangar_mat := StandardMaterial3D.new()
	hangar_mat.albedo_color = Color(0.55, 0.55, 0.52)
	hangar_mat.roughness = 0.8
	hangar_mat.metallic = 0.3

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.4, 0.4, 0.42)
	roof_mat.roughness = 0.6
	roof_mat.metallic = 0.5

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.3, 0.3, 0.32)
	door_mat.roughness = 0.7

	# Hangar row along the east side (near turns 1-3)
	var hangar_positions: Array[Vector3] = [
		Vector3(510.0, 0.0, -80.0),
		Vector3(510.0, 0.0, -150.0),
		Vector3(500.0, 0.0, -220.0),
	]

	for hpos in hangar_positions:
		# Main structure
		var body := CSGBox3D.new()
		body.size = Vector3(40.0, 15.0, 50.0)
		body.position = hpos + Vector3.UP * 7.5
		body.use_collision = false
		body.material = hangar_mat
		add_child(body)

		# Roof (slightly wider)
		var roof := CSGBox3D.new()
		roof.size = Vector3(42.0, 1.0, 52.0)
		roof.position = hpos + Vector3.UP * 15.5
		roof.use_collision = false
		roof.material = roof_mat
		add_child(roof)

		# Door opening (dark rectangle on track-facing side)
		var door := CSGBox3D.new()
		door.size = Vector3(0.1, 12.0, 30.0)
		door.position = hpos + Vector3(-20.0, 6.0, 0.0)
		door.use_collision = false
		door.material = door_mat
		add_child(door)

	# Cargo hangars along the back taxiway
	for ci in range(3):
		var cpos := Vector3(80.0 + float(ci) * 70.0, 0.0, -280.0)
		var cargo := CSGBox3D.new()
		cargo.size = Vector3(30.0, 10.0, 25.0)
		cargo.position = cpos + Vector3.UP * 5.0
		cargo.use_collision = false
		cargo.material = hangar_mat
		add_child(cargo)

# --- Control Tower ---

func _build_control_tower() -> void:
	var tower_pos := Vector3(250.0, 0.0, -130.0)

	# Tower shaft
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.7, 0.7, 0.68)
	shaft_mat.roughness = 0.5
	shaft_mat.metallic = 0.2

	var shaft := CSGBox3D.new()
	shaft.size = Vector3(8.0, 30.0, 8.0)
	shaft.position = tower_pos + Vector3.UP * 15.0
	shaft.use_collision = false
	shaft.material = shaft_mat
	add_child(shaft)

	# Control room (wider glass box at top)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.2, 0.4, 0.6, 0.6)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.metallic = 0.5
	glass_mat.roughness = 0.1

	var control_room := CSGBox3D.new()
	control_room.size = Vector3(14.0, 5.0, 14.0)
	control_room.position = tower_pos + Vector3.UP * 32.5
	control_room.use_collision = false
	control_room.material = glass_mat
	add_child(control_room)

	# Roof
	var roof := CSGBox3D.new()
	roof.size = Vector3(16.0, 0.5, 16.0)
	roof.position = tower_pos + Vector3.UP * 35.25
	roof.use_collision = false
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.3, 0.3)
	roof_mat.metallic = 0.6
	roof.material = roof_mat
	add_child(roof)

	# Antenna
	var antenna := CSGCylinder3D.new()
	antenna.radius = 0.2
	antenna.height = 8.0
	antenna.position = tower_pos + Vector3.UP * 39.0
	antenna.use_collision = false
	var ant_mat := StandardMaterial3D.new()
	ant_mat.albedo_color = Color(0.6, 0.6, 0.6)
	ant_mat.metallic = 0.8
	antenna.material = ant_mat
	add_child(antenna)

	# Red beacon light
	var beacon := CSGSphere3D.new()
	beacon.radius = 0.4
	beacon.position = tower_pos + Vector3.UP * 43.2
	beacon.use_collision = false
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.1, 0.1)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.0, 0.0)
	beacon_mat.emission_energy_multiplier = 3.0
	beacon.material = beacon_mat
	add_child(beacon)

# --- Parked Planes ---

func _build_parked_planes() -> void:
	var fuselage_mat := StandardMaterial3D.new()
	fuselage_mat.albedo_color = Color(0.9, 0.9, 0.92)
	fuselage_mat.roughness = 0.3
	fuselage_mat.metallic = 0.4

	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.85, 0.85, 0.88)
	wing_mat.roughness = 0.3
	wing_mat.metallic = 0.5

	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.1, 0.2, 0.7)
	tail_mat.roughness = 0.4

	var engine_mat := StandardMaterial3D.new()
	engine_mat.albedo_color = Color(0.4, 0.4, 0.42)
	engine_mat.metallic = 0.7
	engine_mat.roughness = 0.2

	# Several parked planes near hangars and apron
	var plane_configs: Array[Dictionary] = [
		{"pos": Vector3(480.0, 0.0, -50.0), "rot": -0.3, "scale": 1.0},
		{"pos": Vector3(490.0, 0.0, -180.0), "rot": 0.5, "scale": 0.7},
		{"pos": Vector3(350.0, 0.0, -290.0), "rot": 1.2, "scale": 0.8},
		{"pos": Vector3(150.0, 0.0, 40.0), "rot": 0.0, "scale": 1.2},
	]

	for cfg in plane_configs:
		var pos: Vector3 = cfg.pos
		var rot_y: float = cfg.rot
		var s: float = cfg.scale

		# Fuselage
		var fuselage := CSGBox3D.new()
		fuselage.size = Vector3(3.0 * s, 3.0 * s, 25.0 * s)
		fuselage.position = pos + Vector3.UP * 2.0 * s
		fuselage.rotation.y = rot_y
		fuselage.use_collision = false
		fuselage.material = fuselage_mat
		add_child(fuselage)

		# Wings
		var wing := CSGBox3D.new()
		wing.size = Vector3(22.0 * s, 0.3 * s, 5.0 * s)
		wing.position = pos + Vector3.UP * 2.0 * s + Vector3(0, 0, -2.0 * s).rotated(Vector3.UP, rot_y)
		wing.rotation.y = rot_y
		wing.use_collision = false
		wing.material = wing_mat
		add_child(wing)

		# Tail fin
		var tail := CSGBox3D.new()
		tail.size = Vector3(0.3 * s, 5.0 * s, 4.0 * s)
		tail.position = pos + Vector3(0, 4.5 * s, 11.0 * s).rotated(Vector3.UP, rot_y)
		tail.rotation.y = rot_y
		tail.use_collision = false
		tail.material = tail_mat
		add_child(tail)

		# Engines (under wings)
		for side in [-1.0, 1.0]:
			var eng := CSGCylinder3D.new()
			eng.radius = 0.8 * s
			eng.height = 4.0 * s
			eng.sides = 12
			eng.rotation.x = PI / 2.0
			eng.position = pos + Vector3(side * 5.0 * s, 1.2 * s, -3.0 * s).rotated(Vector3.UP, rot_y)
			eng.use_collision = false
			eng.material = engine_mat
			add_child(eng)

# --- Runway center line markings ---

func _build_runway_markings() -> void:
	var marking_mat := StandardMaterial3D.new()
	marking_mat.albedo_color = Color(0.95, 0.95, 0.95)
	marking_mat.emission_enabled = true
	marking_mat.emission = Color(1.0, 1.0, 1.0)
	marking_mat.emission_energy_multiplier = 0.2

	# Dashed center line along the runway straight
	for i in range(0, 380, 20):
		var dash := CSGBox3D.new()
		dash.size = Vector3(0.3, 0.02, 8.0)
		dash.position = Vector3(float(i) + 5.0, ROAD_Y + 0.01, 0.0)
		dash.use_collision = false
		dash.material = marking_mat
		add_child(dash)

	# Runway numbers at each end
	var num_mat := StandardMaterial3D.new()
	num_mat.albedo_color = Color(0.9, 0.9, 0.9)

	# Threshold markings (wide stripes at runway ends)
	for side in range(-3, 4):
		var stripe := CSGBox3D.new()
		stripe.size = Vector3(1.5, 0.02, 15.0)
		stripe.position = Vector3(15.0, ROAD_Y + 0.01, float(side) * 2.0)
		stripe.use_collision = false
		stripe.material = marking_mat
		add_child(stripe)

	for side in range(-3, 4):
		var stripe := CSGBox3D.new()
		stripe.size = Vector3(1.5, 0.02, 15.0)
		stripe.position = Vector3(370.0, ROAD_Y + 0.01, float(side) * 2.0)
		stripe.use_collision = false
		stripe.material = marking_mat
		add_child(stripe)

# --- Runway edge lights ---

func _build_runway_lights(points: Array[Dictionary]) -> void:
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(0.2, 0.5, 1.0)
	light_mat.emission_enabled = true
	light_mat.emission = Color(0.2, 0.5, 1.0)
	light_mat.emission_energy_multiplier = 2.0

	var half_w: float = ROAD_WIDTH / 2.0

	# Place small blue edge lights every 30 segments
	for i in range(0, points.size(), 30):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			var light_pos: Vector3 = p.position + right * (half_w + 0.5) * side_val
			var bulb := CSGBox3D.new()
			bulb.size = Vector3(0.15, 0.25, 0.15)
			bulb.position = light_pos + Vector3.UP * 0.12
			bulb.use_collision = false
			bulb.material = light_mat
			add_child(bulb)

# --- Environment ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-40, 50, 0)
	light.light_energy = 1.1
	light.light_color = Color(1.0, 0.98, 0.92)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.9)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.95)
	sky_mat.ground_bottom_color = Color(0.15, 0.15, 0.1)
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
