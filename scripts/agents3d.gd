class_name Agents3D
extends Node3D
## Draws everything that moves: cars, visitors, staff, wildlife, emergencies.
## People and cars are batched into MultiMeshes; animals are individual nodes.

const MAX_PEOPLE := 1600
const MAX_CARS := 500

var game: Game
var land: Terrain3D
var selected = null
var t := 0.0
var _mm := {}
var _animal_nodes := {}
var _markers: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _count := {}


func setup(g: Game, terrain: Terrain3D) -> void:
	game = g
	land = terrain
	var meshes := {"body": Models.person_body(), "head": Models.person_head(), "pack": Models.pack(), "car": Models.car(),
		"hat_ranger": Models.hat("ranger"), "hat_maint": Models.hat("maint"), "hat_eco": Models.hat("eco")}
	for key: String in meshes:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[key]
		mm.instance_count = MAX_CARS if key == "car" else (MAX_PEOPLE if not key.begins_with("hat") else 64)
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = land.mat
		mmi.custom_aabb = AABB(Vector3(-10, -5, -10), Vector3(World.W + 20, 30, World.H + 20))
		add_child(mmi)
		_mm[key] = mm
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.36
	torus.rings = 20
	torus.ring_segments = 4
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 1, 1, 0.95)
	rm.no_depth_test = true
	_ring.material_override = rm
	_ring.visible = false
	add_child(_ring)


func _put(key: String, xf: Transform3D, col: Color) -> void:
	var i: int = _count.get(key, 0)
	var mm: MultiMesh = _mm[key]
	if i >= mm.instance_count:
		return
	mm.set_instance_transform(i, xf)
	mm.set_instance_color(i, col)
	_count[key] = i + 1


func _yaw_z(d: Vector2) -> float:
	# rotation that turns a model facing +Z toward 2D direction d (x, z)
	return atan2(d.x, d.y)


func _person(p: Vector2, facing: Vector2, shirt: Color, skin: Color, s: float, bob: float, pack: bool, hat: String = "") -> void:
	var pos := land.ground(p) + Vector3(0, bob, 0)
	var xf := Transform3D(Basis(Vector3.UP, _yaw_z(facing)).scaled(Vector3(s, s, s)), pos)
	_put("body", xf, shirt)
	_put("head", xf, skin)
	if pack:
		_put("pack", xf, Color.WHITE)
	if hat != "":
		_put("hat_" + hat, xf, Color.WHITE)


func group_pos(gr) -> Vector2:
	match gr.state:
		Visitors.S.DRIVE_IN, Visitors.S.DRIVE_OUT:
			var d: Vector2 = gr.dir_at(gr.dist)
			return gr.pos_at(gr.dist) + Vector2(-d.y, d.x) * 5.0
		Visitors.S.WALK:
			return gr.pos_at(gr.dist)
	return World.center(gr.cur)


func _process(delta: float) -> void:
	if game == null:
		return
	if game.speed > 0:
		t += delta
	_count.clear()
	for gr in game.visitors.groups:
		_group(gr)
	for s in game.staffing.staff:
		var role: String = s.role
		var shirt := Color("4f7a4a")
		if role == "maint": shirt = Color("f08a3c")
		elif role == "eco": shirt = Color("3aa8b8")
		var moving: bool = s.state == Staffing.S.MOVING
		var facing := Vector2(0, 1)
		if moving and s.pts.size() >= 2:
			var k := clampi(int(s.dist / D.TILE), 0, s.pts.size() - 2)
			facing = s.pts[k + 1] - s.pts[k]
		var bob := absf(sin(t * 10.0 + s.pos.x)) * 0.04 if moving else 0.0
		if s.state == Staffing.S.WORKING:
			facing = Vector2(cos(t * 4.0), sin(t * 4.0))
		_person(s.pos, facing, shirt, Color("e9b98f"), 1.2, bob, false, role)
	for key: String in _mm:
		_mm[key].visible_instance_count = _count.get(key, 0)
	_animals(delta)
	_incidents()
	_update_ring()


func _group(gr) -> void:
	var state: int = gr.state
	if state == Visitors.S.GONE:
		return
	# the car
	if state == Visitors.S.DRIVE_IN or state == Visitors.S.DRIVE_OUT:
		var d: Vector2 = gr.dir_at(gr.dist)
		var p: Vector2 = gr.pos_at(gr.dist) + Vector2(-d.y, d.x) * 5.5
		_put("car", Transform3D(Basis(Vector3.UP, _yaw_z(d)), land.ground(p)), gr.car_color)
		return
	var cp := World.center(gr.lot) + Vector2(-8.0 + gr.slot * 16.0, 0)
	_put("car", Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(0.92, 0.92, 0.92)), land.ground(cp)), gr.car_color)
	# the people
	var walking := state == Visitors.S.WALK
	var base := World.center(gr.cur)
	var pack: bool = gr.vt.id == "hiker" or gr.vt.id == "climber" or gr.vt.id == "camper"
	for k in gr.n:
		var look: Dictionary = gr.looks[k]
		var p := base
		var facing := Vector2(0, 1)
		var bob := 0.0
		if walking:
			var d: float = maxf(0.0, gr.dist - k * 9.0)
			facing = gr.dir_at(d)
			p = gr.pos_at(d) + Vector2(-facing.y, facing.x) * ((k % 2) * 2.0 - 1.0) * 3.0
			bob = absf(sin(t * 10.0 + gr.id + k * 1.7)) * 0.04
		else:
			var a: float = gr.id * 1.3 + k * TAU / maxf(1.0, gr.n)
			p = base + Vector2(cos(a) * 8.0, sin(a) * 8.0)
			facing = Vector2(-cos(a), -sin(a))
		_person(p, facing, look.shirt, look.skin, 0.75 if look.small else 1.0, bob, pack and not look.small)


func _animals(delta: float) -> void:
	var alive := {}
	for a in game.eco.animals:
		alive[a] = true
		var id: String = D.SPECIES[a.sp].id
		var node: MeshInstance3D = _animal_nodes.get(a)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = Models.animal(id)
			node.material_override = land.mat
			if id == "trout":
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			_animal_nodes[a] = node
			node.set_meta("last", a.pos)
			node.set_meta("yaw", 0.0)
		var pos := land.ground(a.pos)
		match id:
			"eagle":
				pos.y = maxf(pos.y, 0.0) + 3.4 + sin(a.phase * 0.9) * 0.3
			"trout":
				pos.y = -0.09
			"beaver", "salamander":
				pos.y = maxf(pos.y, -0.02)
			_:
				pos.y = maxf(pos.y, 0.0)
				if a.moving:
					pos.y += absf(sin(a.phase * 9.0)) * 0.03
		var last: Vector2 = node.get_meta("last")
		var mv: Vector2 = a.pos - last
		var yaw: float = node.get_meta("yaw")
		if mv.length_squared() > 0.0004:
			yaw = lerp_angle(yaw, atan2(-mv.y, mv.x), clampf(delta * 8.0, 0.0, 1.0))
			node.set_meta("yaw", yaw)
			node.set_meta("last", a.pos)
		var basis := Basis(Vector3.UP, yaw)
		if id == "eagle":
			basis = basis * Basis(Vector3.RIGHT, 0.35) # bank into the turn
			basis = basis.scaled(Vector3(1.5, 1.5, 1.5))
		node.transform = Transform3D(basis, pos)
	for a in _animal_nodes.keys():
		if not alive.has(a):
			_animal_nodes[a].queue_free()
			_animal_nodes.erase(a)


func _incidents() -> void:
	var incs: Array = game.staffing.incidents
	while _markers.size() < incs.size():
		var mi := MeshInstance3D.new()
		mi.mesh = Models.marker()
		mi.material_override = land.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_markers.append(mi)
	for i in _markers.size():
		var mi := _markers[i]
		mi.visible = i < incs.size()
		if mi.visible:
			var c := land.tile_center(incs[i].tile)
			mi.position = c + Vector3(0, 1.0 + absf(sin(t * 5.0)) * 0.25, 0)
			mi.rotation.y = t * 2.0


func selected_pos():
	if selected is Visitors.Group:
		if selected.state == Visitors.S.GONE:
			selected = null
			return null
		return land.ground(group_pos(selected))
	if selected is Ecology.Animal:
		if not _animal_nodes.has(selected):
			selected = null
			return null
		return _animal_nodes[selected].position
	if selected is Staffing.Staff:
		if not game.staffing.staff.has(selected):
			selected = null
			return null
		return land.ground(selected.pos)
	return null


func _update_ring() -> void:
	var p = selected_pos()
	_ring.visible = p != null
	if p != null:
		_ring.position = p + Vector3(0, 0.06, 0)
		var s := 1.0 + sin(t * 5.0) * 0.08
		_ring.scale = Vector3(s, 1, s)


## Finds the agent nearest to a screen position (for the inspector).
func pick(cam: Camera3D, screen: Vector2):
	var best = null
	var bd := 26.0 * 26.0
	var cands: Array = []
	for s in game.staffing.staff:
		cands.append([s, land.ground(s.pos)])
	for gr in game.visitors.groups:
		if gr.state != Visitors.S.GONE:
			cands.append([gr, land.ground(group_pos(gr))])
	for a in _animal_nodes:
		cands.append([a, _animal_nodes[a].position])
	for c in cands:
		var wp: Vector3 = c[1] + Vector3(0, 0.15, 0)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_squared_to(screen)
		if d < bd:
			bd = d
			best = c[0]
	return best
