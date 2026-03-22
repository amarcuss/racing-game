extends Node3D

## F1 Monaco Grand Prix — ~3.3 km Mediterranean street circuit with tight hairpins,
## elevation changes, a tunnel section, harbor chicane, and swimming pool chicane.
## All geometry built procedurally via ArrayMesh.

# --- Track geometry constants ---
const ROAD_WIDTH: float = 14.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 768
const WALL_HEIGHT: float = 3.0
const WALL_WIDTH: float = 0.4

var num_checkpoints: int = 10
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0  # Set after generation — index on the first straight

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	# Place start/finish in middle of the first straight (waypoints 0-2 are the east straight)
	start_segment = track_points.size() / _get_waypoints().size() * 1
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_walls(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_harbor_water()
	_build_tunnel_beams(track_points)
	_build_buildings(track_points)
	_build_palm_trees(track_points)
	_build_yachts()
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
# Monaco-inspired circuit: start/finish straight, Sainte Devote, uphill to Casino,
# Casino hairpin, downhill, tunnel, harbor chicane, swimming pool chicane, Rascasse, pit straight.

func _get_waypoints() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []

	# Simple oval-ish shape that NEVER self-intersects.
	# Clockwise loop: east along bottom, north up right side,
	# west along top (with Casino hairpin), south down left side.
	# All parallel sections are 100m+ apart.

	# === Start/finish straight heading east (y=0) ===
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 150.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 300.0, "z": 0.0, "y": 0.0})

	# === Sainte Devote — wide sweeping right, uphill ===
	pts.append({"x": 400.0, "z": -50.0, "y": 2.0})
	pts.append({"x": 450.0, "z": -130.0, "y": 5.0})
	pts.append({"x": 460.0, "z": -220.0, "y": 8.0})

	# === Beau Rivage uphill heading north ===
	pts.append({"x": 450.0, "z": -320.0, "y": 11.0})
	pts.append({"x": 420.0, "z": -400.0, "y": 13.0})

	# === Massenet curve — wide left heading west ===
	pts.append({"x": 370.0, "z": -460.0, "y": 14.5})
	pts.append({"x": 300.0, "z": -500.0, "y": 15.0})

	# === Casino Square — wide U-turn at the top ===
	pts.append({"x": 220.0, "z": -520.0, "y": 15.0})
	pts.append({"x": 140.0, "z": -510.0, "y": 15.0})
	pts.append({"x": 80.0, "z": -470.0, "y": 14.5})

	# === Mirabeau — downhill heading south ===
	pts.append({"x": 50.0, "z": -410.0, "y": 13.0})
	pts.append({"x": 30.0, "z": -340.0, "y": 11.0})

	# === Grand Hotel — wide gentle curve ===
	pts.append({"x": 0.0, "z": -280.0, "y": 9.0})
	pts.append({"x": -30.0, "z": -220.0, "y": 7.5})

	# === Tunnel section ===
	pts.append({"x": -50.0, "z": -160.0, "y": 6.0})
	pts.append({"x": -60.0, "z": -100.0, "y": 4.5})

	# === Nouvelle — gentle S-curve heading south ===
	pts.append({"x": -55.0, "z": -60.0, "y": 3.0})

	# === Tabac — sweeping right back toward pit straight ===
	pts.append({"x": -40.0, "z": -40.0, "y": 2.0})
	pts.append({"x": -20.0, "z": -30.0, "y": 1.0})

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
	road_mat.albedo_color = Color(0.08, 0.08, 0.09)
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
	var color_concrete := Color(0.45, 0.43, 0.40)

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
	ground_mesh.size = Vector3(800, 0.05, 800)
	ground_mesh.position = Vector3(200, -0.025, -250)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.30, 0.22)
	ground_mat.roughness = 0.9
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(200, -2.0, -250)

	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 800)
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

	# Gantry posts and beam
	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.3, 6.0, 0.3)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 3.0
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.85, 0.85, 0.85)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.2
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.4, 0.4)
	beam.position = p.position + Vector3.UP * 6.0
	beam.use_collision = false
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.9, 0.1, 0.1)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.9, 0.1, 0.1)
	beam_mat.emission_energy_multiplier = 1.5
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

# --- Harbor water surface ---

func _build_harbor_water() -> void:
	# Blue water plane on the harbor side of the track (positive-z side near chicane area)
	var water := CSGBox3D.new()
	water.name = "HarborWater"
	water.size = Vector3(400.0, 0.1, 150.0)
	water.position = Vector3(50.0, -0.5, 160.0)
	water.use_collision = false

	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.05, 0.20, 0.45)
	water_mat.roughness = 0.1
	water_mat.metallic = 0.3
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color.a = 0.85
	water.material = water_mat
	add_child(water)

	# Second water plane further out for depth
	var water_deep := CSGBox3D.new()
	water_deep.name = "HarborWaterDeep"
	water_deep.size = Vector3(600.0, 0.1, 300.0)
	water_deep.position = Vector3(100.0, -1.0, 200.0)
	water_deep.use_collision = false

	var deep_mat := StandardMaterial3D.new()
	deep_mat.albedo_color = Color(0.02, 0.10, 0.30)
	deep_mat.roughness = 0.2
	water_deep.material = deep_mat
	add_child(water_deep)

# --- Tunnel overhead beams ---

func _build_tunnel_beams(points: Array[Dictionary]) -> void:
	# Tunnel section: bottom-left of circuit (x~15-35, z~-85 to -45, y~5)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.3, 0.3, 0.32)
	beam_mat.roughness = 0.7
	beam_mat.metallic = 0.2

	var beam_count: int = 0
	for i in range(points.size()):
		var pos: Vector3 = points[i].position
		# Tunnel region (x=35-55, z=-170 to -100)
		if pos.x >= 30.0 and pos.x <= 60.0 and pos.z >= -170.0 and pos.z <= -100.0 and pos.y >= 4.5:
			if beam_count % 8 == 0:  # Place a beam every 8 segments in tunnel
				var right: Vector3 = _get_right(points[i])
				var half_w: float = ROAD_WIDTH / 2.0

				# Overhead beam spanning the road
				var beam := CSGBox3D.new()
				beam.name = "TunnelBeam%d" % beam_count
				beam.size = Vector3(ROAD_WIDTH + 2.0, 0.5, 1.0)
				var fwd: Vector3 = points[i].forward
				if fwd.length() > 0.001:
					beam.transform = Transform3D(_basis_facing(fwd), pos + Vector3.UP * 5.5)
				else:
					beam.position = pos + Vector3.UP * 5.5
				beam.use_collision = false
				beam.material = beam_mat
				add_child(beam)

				# Side pillars
				for side_val in [-1.0, 1.0]:
					var pillar := CSGBox3D.new()
					pillar.size = Vector3(0.5, 5.5, 1.0)
					pillar.position = pos + right * half_w * side_val + Vector3.UP * 2.75
					pillar.use_collision = false
					pillar.material = beam_mat
					add_child(pillar)

				# Ceiling panel between beams (every other beam)
				if (beam_count / 8) % 2 == 0:
					var ceiling := CSGBox3D.new()
					ceiling.name = "TunnelCeiling%d" % beam_count
					ceiling.size = Vector3(ROAD_WIDTH + 2.0, 0.15, 8.0)
					if fwd.length() > 0.001:
						ceiling.transform = Transform3D(_basis_facing(fwd), pos + Vector3.UP * 5.8)
					else:
						ceiling.position = pos + Vector3.UP * 5.8
					ceiling.use_collision = false
					var ceil_mat := StandardMaterial3D.new()
					ceil_mat.albedo_color = Color(0.2, 0.2, 0.22)
					ceil_mat.roughness = 0.8
					ceiling.material = ceil_mat
					add_child(ceiling)

			beam_count += 1

# --- Buildings alongside the track ---

func _build_buildings(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Place buildings well behind the walls — every N segments, skip tight sections
	for i in range(0, points.size(), 20):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)
		var pos: Vector3 = p.position

		# Skip buildings in harbor/south area (z > 20) to keep waterfront clear
		if pos.z > 20.0:
			continue

		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.6:
				continue
			var bldg_width: float = 5.0 + rng.randf() * 6.0
			var bldg_depth: float = 5.0 + rng.randf() * 6.0
			# Large fixed offset + half diagonal to guarantee clearance on curves
			var half_diag: float = sqrt(bldg_width * bldg_width + bldg_depth * bldg_depth) / 2.0
			var offset: float = ROAD_WIDTH / 2.0 + WALL_WIDTH + 8.0 + half_diag + rng.randf() * 8.0
			var bldg_pos: Vector3 = pos + right * side_val * offset
			_add_building(bldg_pos, rng, bldg_width, bldg_depth)

func _add_building(pos: Vector3, rng: RandomNumberGenerator, preset_width: float = -1.0, preset_depth: float = -1.0) -> void:
	var width: float = preset_width if preset_width > 0.0 else 5.0 + rng.randf() * 8.0
	var depth: float = preset_depth if preset_depth > 0.0 else 5.0 + rng.randf() * 8.0
	var height: float = 8.0 + rng.randf() * 20.0

	var bldg := CSGBox3D.new()
	bldg.size = Vector3(width, height, depth)
	bldg.position = Vector3(pos.x, pos.y + height / 2.0, pos.z)
	bldg.use_collision = false

	var bldg_mat := StandardMaterial3D.new()
	# Mediterranean warm tones — cream, terracotta, sandy
	var palette: Array[Color] = [
		Color(0.85, 0.80, 0.65),   # Cream
		Color(0.80, 0.55, 0.35),   # Terracotta
		Color(0.90, 0.85, 0.70),   # Sandy
		Color(0.75, 0.70, 0.60),   # Stone
		Color(0.95, 0.90, 0.80),   # White-wash
	]
	var color_idx: int = rng.randi() % palette.size()
	bldg_mat.albedo_color = palette[color_idx]
	bldg_mat.roughness = 0.85
	bldg.material = bldg_mat
	add_child(bldg)

	# Windows
	var window_rows: int = int(height / 3.5)
	var window_cols: int = int(width / 3.0)
	for row in range(window_rows):
		for col in range(window_cols):
			if rng.randf() > 0.5:
				continue
			var win := CSGBox3D.new()
			win.size = Vector3(1.0, 1.2, 0.05)
			var wx: float = pos.x - width / 2.0 + 1.5 + float(col) * 3.0
			var wy: float = pos.y + 2.5 + float(row) * 3.5
			var wz: float = pos.z + depth / 2.0 + 0.03
			win.position = Vector3(wx, wy, wz)
			win.use_collision = false

			var win_mat := StandardMaterial3D.new()
			win_mat.albedo_color = Color(0.3, 0.5, 0.7)
			win_mat.roughness = 0.1
			win_mat.metallic = 0.5
			win.material = win_mat
			add_child(win)

# --- Palm trees ---

func _build_palm_trees(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	for i in range(0, points.size(), 25):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)
		var pos: Vector3 = p.position

		# Skip tunnel section
		if pos.x >= 30.0 and pos.x <= 60.0 and pos.z >= -170.0 and pos.z <= -100.0:
			continue

		# Alternate sides
		var side_val: float = 1.0 if (i / 25) % 2 == 0 else -1.0
		if rng.randf() > 0.7:
			continue

		var offset: float = ROAD_WIDTH / 2.0 + WALL_WIDTH + 2.0 + rng.randf() * 3.0
		var tree_pos: Vector3 = pos + right * side_val * offset

		# Trunk — brown cylinder
		var trunk_height: float = 6.0 + rng.randf() * 4.0
		var trunk := CSGCylinder3D.new()
		trunk.radius = 0.2
		trunk.height = trunk_height
		trunk.position = Vector3(tree_pos.x, tree_pos.y + trunk_height / 2.0, tree_pos.z)
		trunk.use_collision = false
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.45, 0.30, 0.15)
		trunk_mat.roughness = 0.9
		trunk.material = trunk_mat
		add_child(trunk)

		# Crown — green sphere
		var crown := CSGSphere3D.new()
		crown.radius = 2.0 + rng.randf() * 1.0
		crown.position = Vector3(tree_pos.x, tree_pos.y + trunk_height + 1.0, tree_pos.z)
		crown.use_collision = false
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = Color(0.15, 0.45, 0.10)
		crown_mat.roughness = 0.8
		crown.material = crown_mat
		add_child(crown)

		# Second smaller crown for fullness
		var crown2 := CSGSphere3D.new()
		crown2.radius = 1.5 + rng.randf() * 0.8
		crown2.position = Vector3(tree_pos.x + 0.5, tree_pos.y + trunk_height + 2.0, tree_pos.z - 0.3)
		crown2.use_collision = false
		crown2.material = crown_mat
		add_child(crown2)

# --- Yachts in harbor ---

func _build_yachts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55

	# Place several yacht shapes in the harbor water area
	# Yachts in harbor south of the track (z > 70)
	var yacht_positions: Array[Vector3] = [
		Vector3(20.0, 0.0, 90.0),
		Vector3(80.0, 0.0, 110.0),
		Vector3(140.0, 0.0, 95.0),
		Vector3(200.0, 0.0, 105.0),
		Vector3(50.0, 0.0, 130.0),
		Vector3(120.0, 0.0, 140.0),
		Vector3(170.0, 0.0, 125.0),
	]

	for yacht_pos in yacht_positions:
		var length: float = 8.0 + rng.randf() * 12.0
		var width_y: float = 3.0 + rng.randf() * 3.0
		var height_y: float = 2.0 + rng.randf() * 2.0

		# Hull
		var hull := CSGBox3D.new()
		hull.size = Vector3(length, height_y, width_y)
		hull.position = yacht_pos + Vector3.UP * (height_y / 2.0 - 0.5)
		hull.use_collision = false
		var hull_mat := StandardMaterial3D.new()
		hull_mat.albedo_color = Color(0.95, 0.95, 0.98)
		hull_mat.roughness = 0.3
		hull_mat.metallic = 0.1
		hull.material = hull_mat
		add_child(hull)

		# Cabin / superstructure
		var cabin := CSGBox3D.new()
		cabin.size = Vector3(length * 0.5, height_y * 0.6, width_y * 0.6)
		cabin.position = yacht_pos + Vector3(length * 0.1, height_y + 0.1, 0.0)
		cabin.use_collision = false
		var cabin_mat := StandardMaterial3D.new()
		cabin_mat.albedo_color = Color(0.85, 0.85, 0.90)
		cabin_mat.roughness = 0.2
		cabin_mat.metallic = 0.3
		cabin.material = cabin_mat
		add_child(cabin)

		# Mast / antenna
		var mast := CSGCylinder3D.new()
		mast.radius = 0.05
		mast.height = 3.0
		mast.position = yacht_pos + Vector3(length * 0.1, height_y + height_y * 0.6 + 1.5, 0.0)
		mast.use_collision = false
		var mast_mat := StandardMaterial3D.new()
		mast_mat.albedo_color = Color(0.7, 0.7, 0.7)
		mast_mat.metallic = 0.8
		mast.material = mast_mat
		add_child(mast)

# --- Environment: sunny Mediterranean day ---

func _build_environment() -> void:
	# Bright warm sun
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-55, 40, 0)
	light.light_energy = 1.3
	light.light_color = Color(1.0, 0.95, 0.85)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.50, 0.90)
	sky_mat.sky_horizon_color = Color(0.60, 0.75, 0.95)
	sky_mat.ground_bottom_color = Color(0.20, 0.25, 0.15)
	sky_mat.ground_horizon_color = Color(0.55, 0.65, 0.50)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2  # BG_SKY
	env.sky = sky
	env.ambient_light_source = 1  # AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.60)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = 2  # Filmic
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	# Fog for Mediterranean haze
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.75, 0.85)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.3

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
