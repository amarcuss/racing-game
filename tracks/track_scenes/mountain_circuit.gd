extends Node3D

## Mountain Circuit — 2.5 km technical winding road with elevation changes,
## hairpin switchbacks, esses through forest, and a fast ridgeline sweeper.
## All geometry built procedurally via ArrayMesh.

# --- Track geometry constants ---
const ROAD_WIDTH: float = 10.0
const ROAD_Y: float = 0.15
const NUM_SEGMENTS: int = 512
const BARRIER_HEIGHT: float = 1.2
const BARRIER_WIDTH: float = 0.3

var num_checkpoints: int = 8
var perimeter: float
var ai_path: Path3D
var track_points: Array[Dictionary] = []
var start_segment: int = 0  # Set after generation — index on the first straight

func _ready() -> void:
	track_points = _generate_track_points()
	perimeter = _compute_perimeter(track_points)
	# Place start/finish on the first straight (middle of waypoints 0-1)
	start_segment = track_points.size() / _get_waypoints().size()
	_build_road_mesh(track_points)
	_build_road_collision(track_points)
	_build_guardrails(track_points)
	_build_ground()
	_build_checkpoints()
	_build_start_finish_visual()
	_build_ai_path()
	_build_scenery(track_points)
	_build_environment()

func get_spawn_transform(index: int) -> Transform3D:
	# Spawn cars BEHIND start/finish on the straight, staggered grid
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
# The mountain circuit is defined as a series of waypoints forming a closed loop.
# Each waypoint has (x, z, y_elevation). The road interpolates smoothly between them.

func _get_waypoints() -> Array[Dictionary]:
	# A technical circuit with hairpins, esses, a ridgeline sweeper, and elevation.
	# Layout roughly forms a distorted loop going clockwise.
	# Total ~2500m. Positions in meters.
	var pts: Array[Dictionary] = []

	# Start straight heading north (x=0)
	pts.append({"x": 0.0, "z": 0.0, "y": 0.0})
	pts.append({"x": 0.0, "z": 80.0, "y": 2.0})
	pts.append({"x": 0.0, "z": 160.0, "y": 6.0})

	# Gentle right curve climbing
	pts.append({"x": 30.0, "z": 160.0, "y": 8.0})
	pts.append({"x": 80.0, "z": 220.0, "y": 15.0})

	# First hairpin right (switchback climbing)
	pts.append({"x": 120.0, "z": 250.0, "y": 20.0})
	pts.append({"x": 130.0, "z": 220.0, "y": 23.0})
	pts.append({"x": 100.0, "z": 180.0, "y": 26.0})

	# Esses through forest
	pts.append({"x": 60.0, "z": 160.0, "y": 28.0})
	pts.append({"x": 30.0, "z": 190.0, "y": 30.0})
	pts.append({"x": -10.0, "z": 220.0, "y": 33.0})
	pts.append({"x": -50.0, "z": 250.0, "y": 36.0})

	# Ridgeline sweeper — fast long left curve at peak elevation
	pts.append({"x": -100.0, "z": 290.0, "y": 40.0})
	pts.append({"x": -160.0, "z": 300.0, "y": 40.0})
	pts.append({"x": -220.0, "z": 280.0, "y": 38.0})

	# Descent — sweeping right downhill
	pts.append({"x": -250.0, "z": 240.0, "y": 32.0})
	pts.append({"x": -260.0, "z": 190.0, "y": 25.0})
	pts.append({"x": -240.0, "z": 140.0, "y": 18.0})

	# Wide sweeping left turn downhill (replaces tight hairpin)
	pts.append({"x": -210.0, "z": 90.0, "y": 12.0})
	pts.append({"x": -220.0, "z": 40.0, "y": 7.0})

	# Long downhill sweeping south then east, approaching start from below
	pts.append({"x": -200.0, "z": -10.0, "y": 4.0})
	pts.append({"x": -140.0, "z": -50.0, "y": 2.0})
	pts.append({"x": -70.0, "z": -75.0, "y": 1.0})
	pts.append({"x": 0.0, "z": -80.0, "y": 0.5})
	pts.append({"x": 0.0, "z": -40.0, "y": 0.2})

	return pts

func _generate_track_points() -> Array[Dictionary]:
	var waypoints: Array[Dictionary] = _get_waypoints()
	var wp_count: int = waypoints.size()

	# Build Catmull-Rom spline through waypoints for smooth interpolation
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
	road_mat.albedo_color = Color(0.08, 0.08, 0.08)
	road_mat.roughness = 0.9
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

# --- Guardrails (metal railings on both sides) ---

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
	var ground_mesh := CSGBox3D.new()
	ground_mesh.name = "GroundMesh"
	ground_mesh.size = Vector3(600, 0.05, 600)
	ground_mesh.position = Vector3(-60, -0.025, 140)
	ground_mesh.use_collision = false
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.38, 0.15)
	ground_mat.roughness = 0.95
	ground_mesh.material = ground_mat
	add_child(ground_mesh)

	# Safety-net collision
	var ground_body := StaticBody3D.new()
	ground_body.name = "Ground"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	ground_body.position = Vector3(-60, -5.0, 140)

	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
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

	# Gantry posts
	for side_val in [-1.0, 1.0]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.3, 5.0, 0.3)
		post.position = p.position + right * half_w * side_val + Vector3.UP * 2.5
		post.use_collision = false
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.7, 0.7, 0.7)
		post_mat.metallic = 0.7
		post_mat.roughness = 0.25
		post.material = post_mat
		add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(ROAD_WIDTH + 1.0, 0.4, 0.4)
	beam.position = p.position + Vector3.UP * 5.0
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
	# Sample every few points for a smooth AI racing line
	var step: int = max(1, track_points.size() / 128)
	for i in range(0, track_points.size(), step):
		var p: Dictionary = track_points[i]
		curve.add_point(p.position + Vector3.UP * 0.5)
	ai_path = Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	add_child(ai_path)

# --- Scenery: pine trees and rocky outcrops ---

func _build_scenery(points: Array[Dictionary]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic placement

	# Place trees alongside the road (every 16th point to limit CSG node count)
	for i in range(0, points.size(), 16):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)

		for side_val in [-1.0, 1.0]:
			if rng.randf() > 0.5:
				continue
			var offset: float = ROAD_WIDTH / 2.0 + 4.0 + rng.randf() * 15.0
			var tree_pos: Vector3 = p.position + right * side_val * offset
			tree_pos.y = p.position.y - 0.5  # Slightly below road
			_add_pine_tree(tree_pos, rng)

	# Scattered rocks
	for i in range(0, points.size(), 20):
		var p: Dictionary = points[i]
		var right: Vector3 = _get_right(p)
		if rng.randf() > 0.35:
			continue
		var side_val: float = 1.0 if rng.randf() > 0.5 else -1.0
		var offset: float = ROAD_WIDTH / 2.0 + 6.0 + rng.randf() * 20.0
		var rock_pos: Vector3 = p.position + right * side_val * offset
		rock_pos.y = p.position.y - 0.3
		_add_rock(rock_pos, rng)

func _add_pine_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := CSGCylinder3D.new()
	trunk.radius = 0.2 + rng.randf() * 0.1
	var tree_height: float = 4.0 + rng.randf() * 3.0
	trunk.height = tree_height * 0.4
	trunk.position = pos + Vector3.UP * trunk.height / 2.0
	trunk.use_collision = false
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.1)
	trunk_mat.roughness = 0.9
	trunk.material = trunk_mat
	add_child(trunk)

	# Canopy — stacked cones
	var canopy_base: float = pos.y + trunk.height
	for layer in range(2):
		var cone := CSGCylinder3D.new()
		cone.radius = (2.0 - float(layer) * 0.7) * (0.8 + rng.randf() * 0.4)
		cone.height = tree_height * 0.35
		cone.position = Vector3(pos.x, canopy_base + float(layer) * tree_height * 0.22, pos.z)
		cone.use_collision = false
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = Color(0.1, 0.3 + rng.randf() * 0.1, 0.08)
		canopy_mat.roughness = 0.85
		cone.material = canopy_mat
		add_child(cone)

func _add_rock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var rock := CSGBox3D.new()
	var sx: float = 1.0 + rng.randf() * 2.0
	var sy: float = 0.5 + rng.randf() * 1.5
	var sz: float = 1.0 + rng.randf() * 2.0
	rock.size = Vector3(sx, sy, sz)
	rock.position = pos + Vector3.UP * sy / 2.0
	rock.rotation_degrees = Vector3(rng.randf() * 10.0, rng.randf() * 360.0, rng.randf() * 10.0)
	rock.use_collision = false
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.42, 0.4)
	rock_mat.roughness = 0.95
	rock.material = rock_mat
	add_child(rock)

# --- Environment: overcast, cool tones ---

func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-50, 45, 0)
	light.light_energy = 0.8
	light.light_color = Color(0.85, 0.88, 0.92)
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.5, 0.6)
	sky_mat.sky_horizon_color = Color(0.6, 0.62, 0.65)
	sky_mat.ground_bottom_color = Color(0.15, 0.18, 0.12)
	sky_mat.ground_horizon_color = Color(0.45, 0.48, 0.42)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = 2  # BG_SKY
	env.sky = sky
	env.ambient_light_source = 2  # AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = 2  # Filmic
	env.ssao_enabled = true
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.65, 0.68)
	env.fog_density = 0.003

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
