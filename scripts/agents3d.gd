class_name Agents3D
extends Node3D
## Draws and animates everything that moves: cars, visitors, staff, wildlife
## and emergencies. People are batched into MultiMeshes (body, head, two legs,
## two arms); animals are small rigs with swinging legs or flapping wings.

const MAX_PEOPLE := 1600
const MAX_CARS := 500
# rough real-world proportions, nudged up a little so animals stay findable
const SIZES := {"elk": 0.85, "bear": 0.7, "wolf": 0.65, "fox": 0.6, "goat": 0.7, "bighorn": 0.7, "beaver": 0.6,
	"trout": 0.5, "salamander": 0.55, "eagle": 0.75, "heron": 0.7, "pika": 0.6}

class Rig:
	var node: Node3D
	var legs: Array[MeshInstance3D] = []
	var wings: Array[Node3D] = []
	var last := Vector2.ZERO
	var yaw := 0.0
	var tilt := 0.0
	var supplied := false

var game: Game
var land: Terrain3D
var selected = null
var t := 0.0
var _mm := {}
var _rigs := {}
var _markers: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _count := {}
var _car_keys: Array[String] = []
var _car_fit := {}
var cam_pos := Vector3.ZERO # set by the camera each frame, for level of detail
var detail := 1.0 # graphics quality multiplier for LOD distances
var _walk := {} # character name -> {frames, fit}
var _visitor_models: Array[String] = []
# real-world sizes (in tiles of about 8 m, nudged up so animals stay findable) and the turn that points each supplied model's head along +X
const ANIMAL_FIT := {"elk": [0.36, 90.0, "length"], "bear": [0.3, 123.0, "length"], "wolf": [0.24, 90.0, "length"], "fox": [0.17, 90.0, "length"],
	"goat": [0.23, 90.0, "length"], "bighorn": [0.24, 90.0, "length"], "beaver": [0.16, 90.0, "length"], "trout": [0.13, 90.0, "length"],
	"salamander": [0.11, 90.0, "length"], "pika": [0.09, 90.0, "length"], "heron": [0.2, 90.0, "height"], "eagle": [0.36, 90.0, "length"]}


func setup(g: Game, terrain: Terrain3D) -> void:
	game = g
	land = terrain
	var meshes := {"body": Models.person_body(), "head": Models.person_head(), "leg": Models.person_leg(), "arm": Models.person_arm(),
		"pack": Models.pack(), "car": Models.car(),
		"hat_ranger": Models.hat("ranger"), "hat_maint": Models.hat("maint"), "hat_eco": Models.hat("eco")}
	# supplied vehicle models (models/car.glb, car2.glb, car3.glb) replace the built-in car
	for name in ["car", "car2", "car3"]:
		var ext := Models.external(name)
		if ext != null:
			meshes["car_" + name] = ext
			_car_fit["car_" + name] = Models.fit_car(ext, 0.56)
			_car_keys.append("car_" + name)
	if _car_keys.is_empty():
		_car_keys.append("car")
	# supplied walking characters (models/people/*.glb), baked into walk-cycle frames
	for name in ["person1", "person2", "person3", "ranger", "maint", "eco"]:
		var frames := Models.walk_frames(self, name, 6)
		if frames.is_empty():
			continue
		var box: AABB = frames[0].get_aabb()
		var sc := 0.235 / maxf(box.size.y, 0.0001)
		var c := box.get_center()
		_walk[name] = {frames = frames.size(), fit = Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(-c.x * sc, -box.position.y * sc, -c.z * sc))}
		Icons.people[name] = frames[0]
		for f in frames.size():
			meshes["px_%s_%d" % [name, f]] = frames[f]
		if name.begins_with("person"):
			_visitor_models.append(name)
	for key: String in meshes:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[key]
		var cap := MAX_PEOPLE
		if key.begins_with("car"): cap = MAX_CARS
		elif key.begins_with("px_"): cap = 420
		elif key == "leg" or key == "arm": cap = MAX_PEOPLE * 2
		elif key.begins_with("hat"): cap = 64
		mm.instance_count = cap
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		if not _car_fit.has(key) and not key.begins_with("px_"):
			mmi.material_override = land.mat
		mmi.custom_aabb = AABB(Vector3(-10, -5, -10), Vector3(World.W + 20, 40, World.H + 20))
		add_child(mmi)
		_mm[key] = mm
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.42
	torus.rings = 20
	torus.ring_segments = 4
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 1, 1, 0.95)
	rm.no_depth_test = true
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## `stride` is the walk-cycle phase; pass a negative value to stand still.
func _person(p: Vector2, facing: Vector2, shirt: Color, skin: Color, s: float, stride: float, pack: bool, hat: String = "", model: String = "") -> void:
	var walking := stride >= 0.0
	var gp := land.ground_pos(p)
	var d2 := gp.distance_squared_to(cam_pos)
	if d2 > 130.0 * 130.0 * detail:
		return # too far away to see
	# detailed walking models up close, simple figures farther off
	if _walk.has(model) and d2 < 34.0 * 34.0 * detail:
		var w: Dictionary = _walk[model]
		var n: int = w.frames
		var frame := int(fposmod(stride * 0.5, TAU) / TAU * n) % n if walking else 0
		var sx := s / 0.7
		var at := land.ground_pos(p)
		var base := Transform3D(Basis(Vector3.UP, _yaw_z(facing)).scaled(Vector3(sx, sx, sx)), at)
		_put("px_%s_%d" % [model, frame], base * (w.fit as Transform3D), Color.WHITE.lerp(shirt, 0.15))
		return
	var swing := sin(stride) * 0.75 if walking else 0.0
	var bob := absf(cos(stride)) * 0.025 if walking else 0.0
	var pos := land.ground_pos(p) + Vector3(0, bob, 0)
	var xf := Transform3D(Basis(Vector3.UP, _yaw_z(facing)).scaled(Vector3(s, s, s)), pos)
	_put("body", xf, shirt)
	_put("head", xf, skin)
	_put("leg", xf * Transform3D(Basis(Vector3.RIGHT, swing), Vector3(-0.037, 0.1, 0)), Color.WHITE)
	_put("leg", xf * Transform3D(Basis(Vector3.RIGHT, -swing), Vector3(0.037, 0.1, 0)), Color.WHITE)
	_put("arm", xf * Transform3D(Basis(Vector3.RIGHT, -swing * 0.8), Vector3(-0.097, 0.245, 0)), shirt)
	_put("arm", xf * Transform3D(Basis(Vector3.RIGHT, swing * 0.8), Vector3(0.097, 0.245, 0)), shirt)
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
		if moving:
			facing = Paths.dir(s.pts, s.dist)
		elif s.state == Staffing.S.WORKING:
			facing = Vector2(cos(t * 3.0), sin(t * 3.0))
		_person(s.pos, facing, shirt, Color("e9b98f"), 0.78, (t * 11.0 + s.pos.x) if moving else -1.0, false, role, role)
	for key: String in _mm:
		_mm[key].visible_instance_count = _count.get(key, 0)
	_animals(delta)
	_incidents()
	_update_ring()


func _car_xf(p: Vector2, d: Vector2, s: float) -> Transform3D:
	# pitch the car to follow the slope it is driving on
	var here := land.ground_pos(p)
	var ahead := land.ground_pos(p + d * 8.0)
	var fwd := (ahead - here)
	if fwd.length_squared() < 0.00001:
		fwd = Vector3(d.x, 0, d.y)
	fwd = fwd.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var up := fwd.cross(right)
	return Transform3D(Basis(right, up, fwd).scaled(Vector3(s, s, s)), here + Vector3(0, 0.02, 0))


func _car(gr, xf: Transform3D) -> void:
	var key: String = _car_keys[gr.id % _car_keys.size()]
	var d2 := xf.origin.distance_squared_to(cam_pos)
	if d2 > 260.0 * 260.0 * detail:
		return
	if _car_fit.has(key) and d2 > 75.0 * 75.0 * detail:
		_put("car", xf, gr.car_color)
	elif _car_fit.has(key):
		_put(key, xf * _car_fit[key], Color.WHITE)
	else:
		_put(key, xf, gr.car_color)


func _group(gr) -> void:
	var state: int = gr.state
	if state == Visitors.S.GONE:
		return
	if state == Visitors.S.DRIVE_IN or state == Visitors.S.DRIVE_OUT:
		var d: Vector2 = gr.dir_at(gr.dist)
		var p: Vector2 = gr.pos_at(gr.dist) + Vector2(-d.y, d.x) * 5.5
		_car(gr, _car_xf(p, d, 1.0))
		return
	var cp := World.center(gr.lot) + Vector2(-8.0 + gr.slot * 16.0, 0)
	_car(gr, _car_xf(cp, Vector2(0, -1), 1.0))
	var walking := state == Visitors.S.WALK
	var base := World.center(gr.cur)
	var pack: bool = gr.vt.id == "hiker" or gr.vt.id == "climber" or gr.vt.id == "camper"
	for k in gr.n:
		var look: Dictionary = gr.looks[k]
		var p := base
		var facing := Vector2(0, 1)
		var stride := -1.0
		if walking:
			var d: float = maxf(0.0, gr.dist - k * 6.0)
			facing = gr.dir_at(d)
			p = gr.pos_at(d) + Vector2(-facing.y, facing.x) * ((k % 2) * 2.0 - 1.0) * 1.6
			stride = t * 11.0 + gr.id + k * 1.7
		else:
			var a: float = gr.id * 1.3 + k * TAU / maxf(1.0, gr.n)
			p = base + Vector2(cos(a) * 6.0, sin(a) * 6.0)
			facing = Vector2(-cos(a), -sin(a))
		var who := "" if _visitor_models.is_empty() else _visitor_models[(gr.id + k) % _visitor_models.size()]
		_person(p, facing, look.shirt, look.skin, 0.5 if look.small else 0.7, stride, pack and not look.small, "", who)


func _make_rig(id: String) -> Rig:
	var rig := Rig.new()
	rig.node = Node3D.new()
	var ext := Models.external("animals/" + id)
	if ext != null:
		var spec: Array = ANIMAL_FIT.get(id, [0.2, 0.0, "length"])
		var shell := MeshInstance3D.new()
		shell.mesh = ext
		shell.transform = Models.fit_animal(ext, spec[0], spec[1], spec[2])
		if id == "trout":
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.node.add_child(shell)
		rig.supplied = true
		add_child(rig.node)
		return rig
	var body := MeshInstance3D.new()
	body.mesh = Models.animal(id)
	body.material_override = land.mat
	if id == "trout":
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.node.add_child(body)
	for hip: Vector3 in Models.hips(id):
		var leg := MeshInstance3D.new()
		leg.mesh = Models.leg(id)
		leg.material_override = land.mat
		leg.position = hip
		rig.node.add_child(leg)
		rig.legs.append(leg)
	if id == "eagle":
		for side in [1.0, -1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 0.03, 0.05 * side)
			pivot.scale = Vector3(1, 1, side)
			var wing := MeshInstance3D.new()
			wing.mesh = Models.wing()
			wing.material_override = land.mat
			pivot.add_child(wing)
			rig.node.add_child(pivot)
			rig.wings.append(pivot)
	add_child(rig.node)
	return rig


func _animals(delta: float) -> void:
	var alive := {}
	for a in game.eco.animals:
		alive[a] = true
		var id: String = D.SPECIES[a.sp].id
		var rig: Rig = _rigs.get(a)
		if rig == null:
			rig = _make_rig(id)
			rig.last = a.pos
			_rigs[a] = rig
		rig.node.visible = not a.hidden and land.ground_pos(a.pos).distance_squared_to(cam_pos) < 190.0 * 190.0 * detail
		if a.hidden:
			continue
		var pos := land.ground_pos(a.pos)
		var scale_f: float = SIZES.get(id, 0.7)
		var wl := land.water_at(pos.x, pos.z)
		match id:
			"eagle":
				pos.y = maxf(pos.y, wl) + 5.0 + sin(a.phase * 0.9) * 0.4
			"trout":
				pos.y = wl - 0.09 + sin(a.phase * 2.0) * 0.01
			"beaver", "salamander", "heron":
				pos.y = maxf(pos.y, wl - 0.02)
			_:
				pos.y = maxf(pos.y, wl)
		var mv := a.pos - rig.last
		if mv.length_squared() > 0.0004:
			rig.yaw = lerp_angle(rig.yaw, atan2(-mv.y, mv.x), clampf(delta * 8.0, 0.0, 1.0))
			rig.last = a.pos
		# grazing animals lower their heads; fish wiggle; eagles bank
		var want_tilt := -0.24 if a.graze else 0.0
		rig.tilt = lerpf(rig.tilt, want_tilt, clampf(delta * 3.0, 0.0, 1.0))
		var basis := Basis(Vector3.UP, rig.yaw) * Basis(Vector3.BACK, rig.tilt)
		if id == "eagle":
			basis = basis * Basis(Vector3.RIGHT, 0.3)
			var flap := sin(a.phase * 2.2)
			var beat := maxf(0.0, flap) * sin(a.phase * 14.0) * 0.5 # a few beats, then glide
			for k in rig.wings.size():
				rig.wings[k].rotation.x = (-0.12 - beat) * (1.0 if k == 0 else -1.0)
		elif id == "trout":
			basis = basis * Basis(Vector3.UP, sin(a.phase * 9.0) * 0.18)
		var gait := 0.0
		if a.moving:
			var fast := a.flee > 0.0 or a.prey != null
			gait = a.phase * (18.0 if fast else 10.0)
			if not rig.legs.is_empty():
				pos.y += absf(sin(gait)) * (0.05 if fast else 0.015)
		for k in rig.legs.size():
			# diagonal pairs move together, like a trot
			var ph := gait + (PI if (k == 1 or k == 2) else 0.0)
			rig.legs[k].rotation.z = sin(ph) * 0.6 if a.moving else 0.0
		if rig.supplied:
			# realistic models have no joints: give them a walking rock and bob instead
			scale_f = 1.0
			if a.moving and id != "eagle" and id != "trout":
				pos.y += absf(sin(gait)) * 0.006
				basis = basis * Basis(Vector3.BACK, sin(gait) * 0.05)
		rig.node.transform = Transform3D(basis.scaled(Vector3(scale_f, scale_f, scale_f)), pos)
	for a in _rigs.keys():
		if not alive.has(a):
			_rigs[a].node.queue_free()
			_rigs.erase(a)


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
		return land.ground_pos(group_pos(selected))
	if selected is Ecology.Animal:
		if not _rigs.has(selected) or selected.hidden:
			selected = null
			return null
		return _rigs[selected].node.position
	if selected is Staffing.Staff:
		if not game.staffing.staff.has(selected):
			selected = null
			return null
		return land.ground_pos(selected.pos)
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
		cands.append([s, land.ground_pos(s.pos)])
	for gr in game.visitors.groups:
		if gr.state != Visitors.S.GONE:
			cands.append([gr, land.ground_pos(group_pos(gr))])
	for a in _rigs:
		if not a.hidden:
			cands.append([a, _rigs[a].node.position])
	for c in cands:
		var wp: Vector3 = c[1] + Vector3(0, 0.1, 0)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_squared_to(screen)
		if d < bd:
			bd = d
			best = c[0]
	return best
