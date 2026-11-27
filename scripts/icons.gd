class_name Icons
extends Node
## Build-menu pictures. Each building's real 3D model is photographed once
## into a small off-screen viewport, so the button shows exactly what you get.

static var tex := {} # building kind -> Texture2D


static var pic := {} # name -> Texture2D: portraits ("face_ranger"), species ("sp_elk")
static var people := {} # model name -> standing mesh, handed over by the people renderer


func build(shared_mat: Material) -> void:
	for kind: int in D.BUILD:
		if kind == D.B.ROAD or kind == D.B.TRAIL or kind == D.B.PARKING or tex.has(kind):
			continue
		var name := str(D.B.keys()[kind]).to_lower()
		var ext := Models.external(name)
		if ext != null:
			tex[kind] = _shoot(ext, Models.fit(ext, 1.0, true), null, 0)
		elif Models.structure(kind) != null:
			tex[kind] = _shoot(Models.structure(kind), Transform3D.IDENTITY, shared_mat, 0)
	# portraits of the people in the park, from the same models that walk its trails
	for name: String in people:
		pic["face_" + name] = _shoot(people[name], Transform3D.IDENTITY, null, 1)
	if pic.has("face_person1"):
		pic["people"] = pic["face_person1"]
	if pic.has("face_ranger"):
		pic["ranger"] = pic["face_ranger"]
	# and of the wildlife
	for sp: Dictionary in D.SPECIES:
		var am := Models.external("animals/" + str(sp.id))
		if am != null:
			pic["sp_" + str(sp.id)] = _shoot(am, Transform3D.IDENTITY, null, 2)
	for pair in [["b_research", D.B.RESEARCH], ["b_gate", D.B.GATE]]:
		if tex.has(pair[1]):
			pic[pair[0]] = tex[pair[1]]


## Photographs a model into its own little viewport. Framing: 0 = building
## (three-quarter view), 1 = head and shoulders, 2 = animal seen side-on.
func _shoot(mesh: Mesh, xf: Transform3D, mat: Material, framing: int) -> Texture2D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	if mat != null:
		mi.material_override = mat
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	vp.add_child(mi)
	var box: AABB = xf * mesh.get_aabb()
	var centre := box.get_center()
	var reach := maxf(box.size.y, maxf(box.size.x, box.size.z))
	var from := Vector3(0.75, 0.6, 1.0)
	var span := reach * 1.35
	if framing == 1:
		centre.y = box.end.y - box.size.y * 0.14
		span = box.size.y * 0.4
		from = Vector3(0.35, 0.1, 1.0)
	elif framing == 2:
		# look across the shorter side, so the animal is seen in profile
		from = Vector3(0.3, 0.25, 1.0) if box.size.x >= box.size.z else Vector3(1.0, 0.25, 0.3)
		span = reach * 1.12
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = span
	cam.position = centre + from.normalized() * (reach * 4.0)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, centre, Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(35.0), 0.0)
	key.light_energy = 1.35
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-120.0), 0.0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.75, 0.85, 1.0)
	vp.add_child(fill)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	return vp.get_texture()
