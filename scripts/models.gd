class_name Models
extends RefCounted
## Procedural low-poly 3D models. One tile = 1 unit; models sit on y = 0,
## centred on their footprint. Meshes are built once and cached.

const WOOD := Color("a9743f")
const WOOD_D := Color("7d5230")
const CREAM := Color("fbf1d8")

static var _cache := {}


static func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


static func structure(kind: int) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var m := MeshBuilder.new()
	match kind:
		D.B.GATE:
			m.block(V(-0.42, 0, 0), V(0.1, 0.62, 0.1), WOOD_D)
			m.block(V(0.42, 0, 0), V(0.1, 0.62, 0.1), WOOD_D)
			m.block(V(0, 0.56, 0), V(1.0, 0.1, 0.14), WOOD)
			m.gable(V(0, 0.66, 0), V(1.06, 0.2, 0.3), Color("3f8f5a"))
			m.block(V(0, 0.4, 0.02), V(0.44, 0.15, 0.04), CREAM)
			m.block(V(-0.62, 0, 0.1), V(0.22, 0.32, 0.22), CREAM)
			m.gable(V(-0.62, 0.32, 0.1), V(0.3, 0.14, 0.3), Color("c0563f"))
		D.B.VISITOR_CENTER:
			m.block(V(0, 0, 0), V(1.7, 0.08, 1.7), Color("d8c9a3"))
			m.block(V(0, 0.08, -0.1), V(1.4, 0.62, 1.1), CREAM)
			m.gable(V(0, 0.7, -0.1), V(1.6, 0.5, 1.3), Color("c0563f"))
			m.block(V(0, 0.08, 0.47), V(0.24, 0.42, 0.04), WOOD_D)
			m.block(V(-0.42, 0.3, 0.47), V(0.3, 0.26, 0.03), Color("8fd3f4"))
			m.block(V(0.42, 0.3, 0.47), V(0.3, 0.26, 0.03), Color("8fd3f4"))
			m.block(V(0, 0.52, 0.62), V(0.8, 0.05, 0.4), Color("a94a37"))
			m.block(V(-0.36, 0.08, 0.78), V(0.06, 0.46, 0.06), WOOD_D)
			m.block(V(0.36, 0.08, 0.78), V(0.06, 0.46, 0.06), WOOD_D)
			m.cyl(V(0.72, 0.08, 0.62), 0.02, 1.1, 5, Color("777777"))
			m.block(V(-0.45, 0.7, -0.3), V(0.16, 0.6, 0.16), Color("8f887b"))
			m.block(V(0, 0.08, 0.2), V(1.44, 0.14, 0.04), Color("8f887b"))
			for bx in [-0.55, 0.55]:
				m.block(V(bx, 0.08, 0.95), V(0.3, 0.1, 0.1), WOOD_D)
			m.block(V(0.84, 1.0, 0.62), V(0.22, 0.14, 0.02), Color("3f8f5a"))
		D.B.RESTROOM:
			m.block(V(0, 0, 0), V(0.7, 0.42, 0.56), Color("e9eef2"))
			m.gable(V(0, 0.42, 0), V(0.8, 0.22, 0.66), Color("3a9aa5"))
			m.block(V(-0.17, 0, 0.28), V(0.18, 0.3, 0.03), Color("4a90d9"))
			m.block(V(0.17, 0, 0.28), V(0.18, 0.3, 0.03), Color("e77fb3"))
		D.B.BIN:
			m.block(V(-0.14, 0, 0), V(0.2, 0.26, 0.2), Color("3f8f5a"))
			m.block(V(-0.14, 0.26, 0), V(0.24, 0.05, 0.24), Color("2f6e45"))
			m.block(V(0.14, 0, 0), V(0.2, 0.26, 0.2), Color("3b7dd8"))
			m.block(V(0.14, 0.26, 0), V(0.24, 0.05, 0.24), Color("2c5fa8"))
		D.B.OVERLOOK:
			m.block(V(0, 0, 0), V(0.86, 0.1, 0.86), WOOD)
			for s in [-1.0, 1.0]:
				m.block(V(0.4 * s, 0.1, 0), V(0.05, 0.22, 0.86), Color("d9a566"))
				m.block(V(0.4 * s, 0.1, -0.4), V(0.07, 0.3, 0.07), WOOD_D)
				m.block(V(0.4 * s, 0.1, 0.4), V(0.07, 0.3, 0.07), WOOD_D)
			m.block(V(0, 0.1, -0.4), V(0.86, 0.22, 0.05), Color("d9a566"))
			m.cyl(V(0.15, 0.1, -0.22), 0.025, 0.26, 5, Color("6b6b6b"))
			m.block(V(0.15, 0.36, -0.22), V(0.1, 0.08, 0.16), Color("3b7dd8"))
		D.B.PICNIC:
			m.block(V(0, 0.2, 0), V(0.6, 0.04, 0.28), WOOD)
			m.block(V(0, 0.24, 0), V(0.26, 0.012, 0.28), Color("e8554e"))
			m.block(V(0, 0.11, -0.24), V(0.6, 0.03, 0.1), WOOD_D)
			m.block(V(0, 0.11, 0.24), V(0.6, 0.03, 0.1), WOOD_D)
			for s in [-1.0, 1.0]:
				m.block(V(0.22 * s, 0, 0), V(0.05, 0.2, 0.5), WOOD_D)
		D.B.CAMP:
			m.cone(V(-0.42, 0, -0.38), 0.42, 0.52, 4, Color("f08a3c"), PI / 4.0)
			m.cone(V(0.45, 0, 0.3), 0.4, 0.48, 4, Color("4a90d9"), PI / 4.0)
			m.cone(V(0.5, 0, -0.5), 0.3, 0.38, 4, Color("58b368"), PI / 4.0)
			m.cyl(V(-0.3, 0, 0.42), 0.16, 0.05, 7, Color("8c8c8c"))
			m.cone(V(-0.3, 0.05, 0.42), 0.09, 0.2, 5, Color("f6a13c"))
			m.block(V(-0.62, 0, 0.5), V(0.1, 0.1, 0.36), WOOD_D)
			m.block(V(-0.05, 0, 0.66), V(0.36, 0.1, 0.1), WOOD_D)
		D.B.SNACK:
			m.block(V(0, 0, -0.08), V(0.72, 0.5, 0.56), Color("fff6e0"))
			m.block(V(0, 0.22, 0.2), V(0.5, 0.2, 0.03), Color("5a3a22"))
			m.block(V(0, 0.18, 0.26), V(0.62, 0.04, 0.12), WOOD)
			for k in 6:
				m.block(V(-0.325 + k * 0.13, 0.46, 0.2), V(0.13, 0.04, 0.42), Color("e8554e") if k % 2 == 0 else Color.WHITE)
			m.block(V(0, 0.5, -0.08), V(0.78, 0.05, 0.62), Color("e8554e"))
			m.blob(V(0, 0.68, -0.08), V(0.12, 0.12, 0.12), Color("f6d44d"))
		D.B.RANGER:
			m.block(V(0, 0, 0), V(1.6, 0.06, 1.5), Color("c9b98a"))
			m.block(V(0, 0.06, -0.1), V(1.36, 0.56, 1.0), WOOD)
			for k in 3:
				m.block(V(0, 0.18 + k * 0.16, -0.1), V(1.38, 0.025, 1.02), WOOD_D)
			m.gable(V(0, 0.62, -0.1), V(1.56, 0.48, 1.2), Color("3f8f5a"))
			m.block(V(0, 0.06, 0.41), V(0.22, 0.4, 0.04), Color("5a3a22"))
			m.block(V(-0.42, 0.28, 0.41), V(0.26, 0.2, 0.03), Color("f6e7a0"))
			m.block(V(0.42, 0.28, 0.41), V(0.26, 0.2, 0.03), Color("f6e7a0"))
			m.block(V(0, 0.5, 0.56), V(1.36, 0.04, 0.34), Color("357a4c"))
			m.block(V(-0.62, 0.06, 0.7), V(0.06, 0.46, 0.06), WOOD_D)
			m.block(V(0.62, 0.06, 0.7), V(0.06, 0.46, 0.06), WOOD_D)
			m.cyl(V(-0.7, 0.06, 0.6), 0.02, 1.15, 5, Color("777777"))
			m.block(V(0.45, 0.62, -0.35), V(0.18, 0.62, 0.18), Color("8f887b"))
			m.block(V(0, 0.06, 0.56), V(1.36, 0.03, 0.34), WOOD_D)
			m.block(V(0, 0.22, 0.72), V(1.3, 0.03, 0.03), WOOD_D)
			m.block(V(-0.58, 1.08, 0.6), V(0.24, 0.15, 0.02), Color("e8554e"))
		D.B.RESEARCH:
			m.block(V(0, 0, 0), V(1.6, 0.06, 1.5), Color("cfd8dd"))
			m.block(V(-0.15, 0.06, -0.1), V(1.1, 0.5, 0.9), Color("f2f5f7"))
			m.block(V(-0.15, 0.56, -0.1), V(1.18, 0.07, 0.98), Color("3b7dd8"))
			m.block(V(0.56, 0.06, 0.1), V(0.4, 0.36, 0.6), Color("e1e8ec"))
			m.block(V(0.56, 0.42, 0.1), V(0.44, 0.03, 0.56), Color("2e4057"))
			m.block(V(-0.3, 0.24, 0.36), V(0.44, 0.2, 0.03), Color("8fd3f4"))
			m.block(V(0.15, 0.06, 0.36), V(0.18, 0.36, 0.03), Color("5d7d8c"))
			m.cyl(V(-0.5, 0.63, -0.3), 0.015, 0.5, 4, Color("777777"))
			m.blob(V(-0.5, 1.14, -0.3), V(0.04, 0.04, 0.04), Color("e8554e"))
			m.cone(V(0.1, 0.63, -0.25), 0.16, 0.12, 7, Color("dfe6ea"))
		D.B.CRAG:
			m.cone(V(0, 0, 0), 0.5, 0.2, 6, Color("9a94a0"))
			m.block(V(0.05, 0, -0.1), V(0.5, 1.0, 0.36), Color("9a94a0"))
			m.block(V(-0.18, 0, 0.05), V(0.36, 0.7, 0.3), Color("837d8a"))
			m.block(V(0.2, 0, 0.1), V(0.3, 0.45, 0.26), Color("aaa3ad"))
			m.block(V(0.02, 0.5, 0.09), V(0.025, 1.0, 0.02), Color("f08a3c"))
			var holds := [[-0.1, 0.5, "e8554e"], [0.12, 0.72, "f6d44d"], [-0.05, 0.3, "4a90d9"], [0.16, 0.38, "58b368"], [0.0, 0.88, "e77fb3"]]
			for h in holds:
				m.box(V(h[0], h[1], 0.21 if h[1] < 0.45 else 0.09), V(0.05, 0.05, 0.03), Color(h[2]))
		D.B.SIGN:
			m.block(V(0, 0, 0), V(0.05, 0.34, 0.05), WOOD_D)
			m.block(V(0, 0.3, 0.02), V(0.3, 0.24, 0.03), Color("f6d44d"))
			m.block(V(0, 0.4, 0.04), V(0.04, 0.1, 0.012), Color("2e2e2e"))
			m.block(V(0, 0.34, 0.04), V(0.04, 0.035, 0.012), Color("2e2e2e"))
		D.B.HIDE:
			m.block(V(0, 0, 0), V(0.76, 0.36, 0.6), Color("6f7f4a"))
			m.block(V(0, 0.2, 0.3), V(0.56, 0.08, 0.02), Color("23301c"))
			m.block(V(0, 0.2, -0.3), V(0.56, 0.08, 0.02), Color("23301c"))
			m.gable(V(0, 0.36, 0), V(0.9, 0.2, 0.74), Color("52653a"))
			m.blob(V(-0.2, 0.52, 0.1), V(0.14, 0.08, 0.14), Color("6fa35a"))
			m.blob(V(0.22, 0.5, -0.12), V(0.16, 0.08, 0.14), Color("7fb565"))
		D.B.TRAILHEAD:
			m.block(V(-0.26, 0, 0), V(0.06, 0.5, 0.06), WOOD_D)
			m.block(V(0.26, 0, 0), V(0.06, 0.5, 0.06), WOOD_D)
			m.block(V(0, 0.18, 0), V(0.5, 0.28, 0.03), CREAM)
			m.block(V(0, 0.3, 0.02), V(0.3, 0.025, 0.01), Color("3f8f5a"))
			m.block(V(-0.05, 0.25, 0.02), V(0.25, 0.025, 0.01), Color("e8554e"))
			m.gable(V(0, 0.5, 0), V(0.72, 0.14, 0.26), Color("8a5a35"))
	var mesh := m.commit()
	_cache[kind] = mesh
	return mesh


static func trunk() -> ArrayMesh:
	if _cache.has("trunk"):
		return _cache["trunk"]
	var m := MeshBuilder.new()
	m.cyl(V(0, -0.1, 0), 0.035, 0.75, 6, Color("4a3a2c"))
	_cache["trunk"] = m.commit()
	return _cache["trunk"]

## White foliage: tinted per instance (so seasons can recolour it).
static func leaf() -> ArrayMesh:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var m := MeshBuilder.new()
	m.blob_smooth(V(0, 0.66, 0), V(0.3, 0.36, 0.3), Color(0.82, 0.82, 0.82))
	m.blob_smooth(V(0.13, 0.92, 0.06), V(0.22, 0.26, 0.22), Color.WHITE)
	m.blob_smooth(V(-0.15, 0.84, -0.1), V(0.2, 0.22, 0.2), Color(0.9, 0.9, 0.9))
	m.blob_smooth(V(0.02, 1.12, -0.02), V(0.16, 0.18, 0.16), Color(1.05, 1.05, 1.05))
	_cache["leaf"] = m.commit()
	return _cache["leaf"]

## Tall slender spruce, white so it can be tinted per instance.
static func conifer() -> ArrayMesh:
	if _cache.has("conifer"):
		return _cache["conifer"]
	var m := MeshBuilder.new()
	var tiers := 6
	for k in tiers:
		var f := float(k) / tiers
		var shade := 0.62 + f * 0.42
		m.cone_smooth(V(0, 0.2 + f * 1.25, 0), 0.3 * (1.0 - f * 0.78), 0.52 - f * 0.14, 8,
			Color(shade * 0.82, shade * 0.82, shade * 0.82), Color(shade, shade, shade))
	_cache["conifer"] = m.commit()
	return _cache["conifer"]

static func rock() -> ArrayMesh:
	if _cache.has("rock"):
		return _cache["rock"]
	var m := MeshBuilder.new()
	m.blob_smooth(V(0, 0.06, 0), V(0.24, 0.15, 0.19), Color("7a756d"), 7, 4)
	m.blob_smooth(V(0.15, 0.03, 0.09), V(0.13, 0.09, 0.12), Color("6d6861"), 6, 4)
	_cache["rock"] = m.commit()
	return _cache["rock"]

## Window panes for a building, drawn with a glowing material at night.
## Returns an empty mesh for buildings without windows.
static func windows(kind: int) -> ArrayMesh:
	var key := "win%d" % kind
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	var w := Color.WHITE
	match kind:
		D.B.VISITOR_CENTER:
			m.block(V(-0.42, 0.3, 0.475), V(0.3, 0.26, 0.02), w)
			m.block(V(0.42, 0.3, 0.475), V(0.3, 0.26, 0.02), w)
			for sx in [-1.0, 1.0]:
				m.block(V(0.705 * sx, 0.3, -0.3), V(0.02, 0.24, 0.26), w)
				m.block(V(0.705 * sx, 0.3, 0.12), V(0.02, 0.24, 0.26), w)
			m.block(V(0, 0.82, 0.552), V(0.2, 0.16, 0.02), w)
		D.B.RANGER:
			m.block(V(-0.42, 0.28, 0.415), V(0.26, 0.2, 0.02), w)
			m.block(V(0.42, 0.28, 0.415), V(0.26, 0.2, 0.02), w)
			for sx in [-1.0, 1.0]:
				m.block(V(0.685 * sx, 0.28, -0.1), V(0.02, 0.2, 0.3), w)
		D.B.RESEARCH:
			m.block(V(-0.3, 0.24, 0.365), V(0.44, 0.2, 0.02), w)
			m.block(V(-0.705, 0.24, -0.1), V(0.02, 0.2, 0.4), w)
			m.block(V(0.765, 0.16, 0.1), V(0.02, 0.16, 0.3), w)
		D.B.SNACK:
			m.block(V(0, 0.24, 0.215), V(0.46, 0.16, 0.02), w)
		D.B.RESTROOM:
			m.block(V(0, 0.34, 0.285), V(0.5, 0.05, 0.02), w)
		D.B.GATE:
			m.block(V(-0.62, 0.14, 0.215), V(0.12, 0.12, 0.02), w)
	_cache[key] = m.commit()
	return _cache[key]

static var _ext_cache := {}

## Loads models/<name>.glb if one has been supplied (see models/README.md).
## The file is read directly, so it works without opening the Godot editor.
static func external(name: String) -> Mesh:
	if _ext_cache.has(name):
		return _ext_cache[name]
	var found: Mesh = null
	var path := "res://models/%s.glb" % name
	if FileAccess.file_exists(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			var root: Node = doc.generate_scene(state)
			if root != null:
				var stack: Array = [root]
				while not stack.is_empty() and found == null:
					var node: Node = stack.pop_back()
					if node is MeshInstance3D and node.mesh != null:
						found = node.mesh
					elif node is ImporterMeshInstance3D and node.mesh != null:
						found = node.mesh.get_mesh()
					stack.append_array(node.get_children())
				root.free()
	_ext_cache[name] = found
	return found


## Transform that stands a supplied model on the ground, centred, scaled so
## its height (or, with `by_width`, its footprint) matches `size`.
static func fit(mesh: Mesh, size: float, by_width: bool = false) -> Transform3D:
	var box := mesh.get_aabb()
	var extent := maxf(box.size.x, box.size.z) if by_width else box.size.y
	var s := size / maxf(extent, 0.0001)
	var c := box.get_center()
	return Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(-c.x * s, -box.position.y * s, -c.z * s))

## Fit for a supplied vehicle: on its wheels, centred, `length` long, nose toward +Z.
static func fit_car(mesh: Mesh, length: float) -> Transform3D:
	var box := mesh.get_aabb()
	var along_x := box.size.x > box.size.z
	var s := length / maxf(maxf(box.size.x, box.size.z), 0.0001)
	var basis := Basis(Vector3.UP, PI * 0.5 if along_x else 0.0).scaled(Vector3(s, s, s))
	var c := box.get_center()
	return Transform3D(basis, basis * Vector3(-c.x, -box.position.y, -c.z))

## A tree drawn as a few textured cut-outs baked from a detailed model by
## tools/bake_impostor.gd: three upright cards plus two flat canopy layers,
## about ten triangles in all. Returns null if the images are not there.
static func card_tree(name: String, height: float, layers: Array) -> ArrayMesh:
	var key := "card_" + name
	if _cache.has(key):
		return _cache[key]
	var side_path := "res://models/impostors/%s_side.png" % name
	var top_path := "res://models/impostors/%s_top.png" % name
	var mesh: ArrayMesh = null
	if FileAccess.file_exists(side_path) and FileAccess.file_exists(top_path):
		var side := Image.load_from_file(ProjectSettings.globalize_path(side_path))
		var top := Image.load_from_file(ProjectSettings.globalize_path(top_path))
		if side != null and top != null:
			mesh = ArrayMesh.new()
			var half := height * float(side.get_width()) / side.get_height() * 0.5
			for pass_i in 2:
				var v := PackedVector3Array()
				var n := PackedVector3Array()
				var uv := PackedVector2Array()
				var idx := PackedInt32Array()
				if pass_i == 0:
					for k in 4:
						var a := k * PI / 4.0
						var dir := Vector3(cos(a), 0, sin(a))
						var nrm := Vector3.UP # lit like the canopy as a whole, from either side
						var b := v.size()
						v.append(-dir * half); v.append(dir * half)
						v.append(dir * half + Vector3(0, height, 0)); v.append(-dir * half + Vector3(0, height, 0))
						uv.append(Vector2(0, 1)); uv.append(Vector2(1, 1)); uv.append(Vector2(1, 0)); uv.append(Vector2(0, 0))
						for q in 4: n.append(nrm)
						for q in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: idx.append(b + q)
				else:
					for layer in layers:
						var y: float = height * layer[0]
						var r: float = half * layer[1]
						var b := v.size()
						v.append(Vector3(-r, y, -r)); v.append(Vector3(r, y, -r)); v.append(Vector3(r, y, r)); v.append(Vector3(-r, y, r))
						uv.append(Vector2(0, 0)); uv.append(Vector2(1, 0)); uv.append(Vector2(1, 1)); uv.append(Vector2(0, 1))
						for q in 4: n.append(Vector3.UP)
						for q in [0, 1, 2, 0, 2, 3]: idx.append(b + q)
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = v
				arrays[Mesh.ARRAY_NORMAL] = n
				arrays[Mesh.ARRAY_TEX_UV] = uv
				arrays[Mesh.ARRAY_INDEX] = idx
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var img: Image = side if pass_i == 0 else top
				img.generate_mipmaps()
				var m := StandardMaterial3D.new()
				m.albedo_texture = ImageTexture.create_from_image(img)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
				m.cull_mode = BaseMaterial3D.CULL_BACK
				m.vertex_color_use_as_albedo = true
				m.roughness = 1.0
				m.metallic_specular = 0.0
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				# trees between the camera and what you are looking at fade away
				m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				m.distance_fade_min_distance = 5.0
				m.distance_fade_max_distance = 9.0
				mesh.surface_set_material(pass_i, m)
	_cache[key] = mesh
	return mesh

## Bakes a rigged, animated character (models/people/<name>.glb, e.g. Meshy's
## walking clip) into `count` static meshes, one per step of the walk cycle,
## so hundreds of walkers can be drawn in batches. `host` must be in the tree.
## Returns [] when the file is missing or has no usable animation.
static func walk_frames(host: Node, name: String, count: int) -> Array:
	var out: Array = []
	var path := "res://models/people/%s.glb" % name
	if not FileAccess.file_exists(path):
		return out
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return out
	var scene: Node = doc.generate_scene(state)
	if scene == null:
		return out
	host.add_child(scene)
	var player: AnimationPlayer = null
	var skel: Skeleton3D = null
	var skinned: MeshInstance3D = null
	var stack: Array = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer: player = node
		elif node is Skeleton3D: skel = node
		elif node is MeshInstance3D and node.mesh != null and skinned == null: skinned = node
		stack.append_array(node.get_children())
	if player != null and skel != null and skinned != null and not player.get_animation_list().is_empty():
		var clip: String = player.get_animation_list()[0]
		var length := player.get_animation(clip).length
		var skin := skinned.skin
		var to_root: Transform3D = (scene as Node3D).global_transform.affine_inverse() * skel.global_transform
		player.play(clip)
		for f in count:
			player.seek(length * f / count, true)
			player.advance(0.0)
			var mats: Array[Transform3D] = []
			if skin != null:
				for b in skin.get_bind_count():
					var bone := skin.get_bind_bone(b)
					if bone < 0:
						bone = skel.find_bone(skin.get_bind_name(b))
					mats.append(to_root * skel.get_bone_global_pose(maxi(bone, 0)) * skin.get_bind_pose(b))
			else:
				for b in skel.get_bone_count():
					mats.append(to_root * skel.get_bone_global_pose(b) * skel.get_bone_global_rest(b).affine_inverse())
			var mesh := ArrayMesh.new()
			for si in skinned.mesh.get_surface_count():
				var src := skinned.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
				var norms = src[Mesh.ARRAY_NORMAL]
				var bones = src[Mesh.ARRAY_BONES]
				var weights = src[Mesh.ARRAY_WEIGHTS]
				if bones == null or weights == null:
					continue
				var per: int = bones.size() / verts.size()
				var nv := PackedVector3Array()
				var nn := PackedVector3Array()
				nv.resize(verts.size())
				nn.resize(verts.size())
				for vi in verts.size():
					var p := Vector3.ZERO
					var q := Vector3.ZERO
					for k in per:
						var wgt: float = weights[vi * per + k]
						if wgt <= 0.0:
							continue
						var m: Transform3D = mats[bones[vi * per + k]]
						p += (m * verts[vi]) * wgt
						if norms != null:
							q += (m.basis * norms[vi]) * wgt
					nv[vi] = p
					nn[vi] = q.normalized() if norms != null else Vector3.UP
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = nv
				arrays[Mesh.ARRAY_NORMAL] = nn
				arrays[Mesh.ARRAY_TEX_UV] = src[Mesh.ARRAY_TEX_UV]
				arrays[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var mat := skinned.get_active_material(si)
				if mat != null:
					mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
			if mesh.get_surface_count() > 0:
				out.append(mesh)
	host.remove_child(scene)
	scene.free()
	return out


## Fit for a supplied animal: standing on the ground, centred, turned by
## `yaw_deg` so its head points along +X, and scaled so `axis` ("length",
## "height" or "span") measures `size`.
static func fit_animal(mesh: Mesh, size: float, yaw_deg: float, axis: String = "length") -> Transform3D:
	var box := mesh.get_aabb()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var extent := maxf(box.size.x, box.size.z)
	if axis == "height":
		extent = box.size.y
	var s := size / maxf(extent, 0.0001)
	basis = basis.scaled(Vector3(s, s, s))
	var c := box.get_center()
	return Transform3D(basis, basis * Vector3(-c.x, -box.position.y, -c.z))

## A tuft of grass blades with UVs running root (0) to tip (1), for the grass shader.
static func grass_tuft() -> ArrayMesh:
	if _cache.has("grass"):
		return _cache["grass"]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	for k in 14:
		var a := k * 2.4 + 0.3
		var out_dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out_dir.z, 0, out_dir.x) * 0.016
		var root := out_dir * (0.02 + 0.022 * (k % 4))
		var h := 0.09 + 0.036 * (k % 5)
		var tip := root + out_dir * (0.025 + 0.015 * (k % 3)) + Vector3(0, h, 0)
		var mid := root.lerp(tip, 0.55) + Vector3(0, 0.008, 0)
		for p in [[root - side, 0.0], [root + side, 0.0], [mid + side * 0.6, 0.55], [root - side, 0.0], [mid + side * 0.6, 0.55], [mid - side * 0.6, 0.55],
				[mid - side * 0.6, 0.55], [mid + side * 0.6, 0.55], [tip, 1.0]]:
			v.append(p[0])
			n.append(Vector3.UP)
			uv.append(Vector2(0.5, p[1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["grass"] = mesh
	return mesh

static func bush() -> ArrayMesh:
	if _cache.has("bush"):
		return _cache["bush"]
	var m := MeshBuilder.new()
	m.blob_smooth(V(0, 0.07, 0), V(0.16, 0.11, 0.15), Color.WHITE)
	m.blob_smooth(V(0.11, 0.05, 0.06), V(0.1, 0.08, 0.1), Color(0.85, 0.85, 0.85))
	m.blob_smooth(V(-0.09, 0.05, -0.07), V(0.1, 0.07, 0.09), Color(0.92, 0.92, 0.92))
	_cache["bush"] = m.commit()
	return _cache["bush"]

static func reed() -> ArrayMesh:
	if _cache.has("reed"):
		return _cache["reed"]
	var m := MeshBuilder.new()
	for k in 6:
		var a := k * 1.05
		var o := V(cos(a) * 0.07, 0, sin(a) * 0.07)
		m.cone(o, 0.018, 0.28 + (k % 3) * 0.07, 3, Color.WHITE)
		if k % 2 == 0:
			m.box(o + V(0, 0.27 + (k % 3) * 0.07, 0), V(0.025, 0.07, 0.025), Color(0.5, 0.36, 0.22))
	_cache["reed"] = m.commit()
	return _cache["reed"]

static func entrance_sign() -> ArrayMesh:
	if _cache.has("esign"):
		return _cache["esign"]
	var m := MeshBuilder.new()
	m.block(V(-0.55, 0, 0), V(0.14, 0.9, 0.14), Color("6b5a4a"))
	m.block(V(0.55, 0, 0), V(0.14, 0.9, 0.14), Color("6b5a4a"))
	m.block(V(-0.55, 0, 0), V(0.3, 0.3, 0.3), Color("8f887b"))
	m.block(V(0.55, 0, 0), V(0.3, 0.3, 0.3), Color("8f887b"))
	m.block(V(0, 0.42, 0), V(1.2, 0.46, 0.08), Color("5a3a22"))
	m.block(V(0, 0.47, 0.045), V(1.05, 0.34, 0.01), Color("7a4f2c"))
	m.block(V(0, 0.66, 0.05), V(0.8, 0.06, 0.012), Color("f3e2a8"))
	m.block(V(0, 0.56, 0.05), V(0.6, 0.04, 0.012), Color("f3e2a8"))
	m.cone(V(-0.4, 0.5, 0.05), 0.08, 0.2, 5, Color("3f8f5a"))
	_cache["esign"] = m.commit()
	return _cache["esign"]

static func flame() -> ArrayMesh:
	if _cache.has("flame"):
		return _cache["flame"]
	var m := MeshBuilder.new()
	m.cone(V(0, 0, 0), 0.22, 0.9, 5, Color.WHITE)
	m.cone(V(0.12, 0, 0.08), 0.13, 0.55, 4, Color(1.0, 0.8, 0.5))
	_cache["flame"] = m.commit()
	return _cache["flame"]

static func flower() -> ArrayMesh:
	if _cache.has("flower"):
		return _cache["flower"]
	var m := MeshBuilder.new()
	m.box(V(0, 0.035, 0), V(0.07, 0.07, 0.07), Color.WHITE)
	_cache["flower"] = m.commit()
	return _cache["flower"]

static func litter() -> ArrayMesh:
	if _cache.has("litter"):
		return _cache["litter"]
	var m := MeshBuilder.new()
	m.box(V(0, 0.03, 0), V(0.1, 0.06, 0.07), Color.WHITE)
	m.box(V(0.08, 0.02, 0.06), V(0.06, 0.04, 0.06), Color(0.8, 0.8, 0.8))
	_cache["litter"] = m.commit()
	return _cache["litter"]

static func thistle() -> ArrayMesh:
	if _cache.has("thistle"):
		return _cache["thistle"]
	var m := MeshBuilder.new()
	m.block(V(0, 0, 0), V(0.03, 0.26, 0.03), Color("4d6b2f"))
	m.cone(V(0, 0.08, 0), 0.12, 0.1, 4, Color("5f7f38"))
	m.blob(V(0, 0.3, 0), V(0.08, 0.08, 0.08), Color("9a45b8"), 5)
	_cache["thistle"] = m.commit()
	return _cache["thistle"]

static func milfoil() -> ArrayMesh:
	if _cache.has("milfoil"):
		return _cache["milfoil"]
	var m := MeshBuilder.new()
	m.cyl(V(0, 0, 0), 0.2, 0.02, 6, Color("8fae35"))
	_cache["milfoil"] = m.commit()
	return _cache["milfoil"]

static func orchid() -> ArrayMesh:
	if _cache.has("orchid"):
		return _cache["orchid"]
	var m := MeshBuilder.new()
	for k in 3:
		var o := V((k - 1) * 0.2, 0, absf(k - 1.0) * 0.12)
		m.block(o, V(0.025, 0.22, 0.025), Color("4f9a4a"))
		m.cone(o, 0.09, 0.08, 4, Color("6dbb5e"))
		m.blob(o + V(0, 0.26, 0), V(0.075, 0.075, 0.075), Color("f48fb8"), 5)
		m.box(o + V(0, 0.24, 0.05), V(0.04, 0.04, 0.04), Color("fff2a8"))
	_cache["orchid"] = m.commit()
	return _cache["orchid"]

## Person parts, white where tinted per instance. Legs and arms are separate
## so they can swing; their origin is the hip / shoulder joint.
static func person_body() -> ArrayMesh:
	if _cache.has("pbody"):
		return _cache["pbody"]
	var m := MeshBuilder.new()
	m.block(V(0, 0.1, 0), V(0.15, 0.15, 0.1), Color.WHITE)
	m.block(V(0, 0.1, 0), V(0.152, 0.03, 0.102), Color(0.3, 0.3, 0.34))
	_cache["pbody"] = m.commit()
	return _cache["pbody"]

static func person_leg() -> ArrayMesh:
	if _cache.has("pleg"):
		return _cache["pleg"]
	var m := MeshBuilder.new()
	m.box(V(0, -0.045, 0), V(0.055, 0.09, 0.06), Color(0.24, 0.27, 0.36))
	m.box(V(0, -0.092, 0.012), V(0.058, 0.02, 0.085), Color(0.16, 0.13, 0.11))
	_cache["pleg"] = m.commit()
	return _cache["pleg"]

static func person_arm() -> ArrayMesh:
	if _cache.has("parm"):
		return _cache["parm"]
	var m := MeshBuilder.new()
	m.box(V(0, -0.05, 0), V(0.04, 0.1, 0.05), Color(0.92, 0.92, 0.92))
	m.box(V(0, -0.115, 0), V(0.04, 0.03, 0.045), Color(1.6, 1.25, 1.0))
	_cache["parm"] = m.commit()
	return _cache["parm"]

static func person_head() -> ArrayMesh:
	if _cache.has("phead"):
		return _cache["phead"]
	var m := MeshBuilder.new()
	m.block(V(0, 0.26, 0), V(0.11, 0.1, 0.1), Color.WHITE)
	m.block(V(0, 0.335, -0.01), V(0.115, 0.035, 0.11), Color(0.3, 0.2, 0.14))
	_cache["phead"] = m.commit()
	return _cache["phead"]

static func pack() -> ArrayMesh:
	if _cache.has("pack"):
		return _cache["pack"]
	var m := MeshBuilder.new()
	m.block(V(0, 0.12, -0.08), V(0.11, 0.13, 0.06), Color("7a4e2d"))
	_cache["pack"] = m.commit()
	return _cache["pack"]

static func hat(kind: String) -> ArrayMesh:
	if _cache.has("hat" + kind):
		return _cache["hat" + kind]
	var m := MeshBuilder.new()
	match kind:
		"ranger":
			m.cyl(V(0, 0.355, 0), 0.11, 0.015, 8, Color("b08d57"))
			m.cyl(V(0, 0.36, 0), 0.06, 0.06, 6, Color("b08d57"))
		"maint":
			m.blob(V(0, 0.37, 0), V(0.075, 0.05, 0.075), Color("f6d44d"), 6)
		"eco":
			m.cyl(V(0, 0.355, 0), 0.12, 0.012, 8, Color("f3ead0"))
			m.blob(V(0, 0.375, 0), V(0.06, 0.04, 0.06), Color("f3ead0"), 6)
	_cache["hat" + kind] = m.commit()
	return _cache["hat" + kind]

static func car() -> ArrayMesh:
	if _cache.has("car"):
		return _cache["car"]
	var m := MeshBuilder.new()
	# faces +Z; white body is tinted per instance
	m.box(V(0, 0.11, 0), V(0.26, 0.11, 0.5), Color.WHITE)
	m.box(V(0, 0.21, -0.03), V(0.22, 0.1, 0.26), Color(0.55, 0.62, 0.7))
	m.box(V(0, 0.265, -0.03), V(0.23, 0.02, 0.27), Color.WHITE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(V(0.125 * sx, 0.05, 0.15 * sz), V(0.04, 0.1, 0.1), Color(0.12, 0.12, 0.14))
	m.box(V(-0.08, 0.12, 0.251), V(0.05, 0.035, 0.01), Color(2.0, 1.9, 1.3))
	m.box(V(0.08, 0.12, 0.251), V(0.05, 0.035, 0.01), Color(2.0, 1.9, 1.3))
	_cache["car"] = m.commit()
	return _cache["car"]

static func marker() -> ArrayMesh:
	if _cache.has("marker"):
		return _cache["marker"]
	var m := MeshBuilder.new()
	m.blob(V(0, 0, 0), V(0.22, 0.22, 0.22), Color("e8443a"), 8)
	m.box(V(0, 0.04, 0.2), V(0.06, 0.16, 0.04), Color.WHITE)
	m.box(V(0, -0.1, 0.2), V(0.06, 0.06, 0.04), Color.WHITE)
	m.box(V(0, 0.04, -0.2), V(0.06, 0.16, 0.04), Color.WHITE)
	m.box(V(0, -0.1, -0.2), V(0.06, 0.06, 0.04), Color.WHITE)
	_cache["marker"] = m.commit()
	return _cache["marker"]


## Leg joints for four-legged animals: [hip positions, leg length, thickness, colour].
const LEGS := {
	"elk": [[-0.13, 0.13], 0.06, 0.2, 0.04, "5c3d25"],
	"bear": [[-0.14, 0.14], 0.08, 0.13, 0.08, "2f221a"],
	"fox": [[-0.08, 0.08], 0.03, 0.09, 0.03, "5a3320"],
	"goat": [[-0.09, 0.09], 0.05, 0.13, 0.035, "d8d2c6"],
	"wolf": [[-0.12, 0.12], 0.045, 0.15, 0.04, "6f7378"],
	"bighorn": [[-0.1, 0.1], 0.05, 0.15, 0.04, "8a6f52"],
	"heron": [[0.0], 0.03, 0.2, 0.015, "5a5a4a"],
}

static func leg(id: String) -> ArrayMesh:
	var key := "leg_" + id
	if _cache.has(key):
		return _cache[key]
	var spec: Array = LEGS[id]
	var m := MeshBuilder.new()
	var L: float = spec[2]
	var th: float = spec[3]
	m.box(V(0, -L * 0.5, 0), V(th, L, th), Color(spec[4]))
	_cache[key] = m.commit()
	return _cache[key]

static func hips(id: String) -> Array:
	var out: Array = []
	if LEGS.has(id):
		var spec: Array = LEGS[id]
		for lx in spec[0]:
			for sz in [-1.0, 1.0]:
				out.append(V(lx, spec[2], spec[1] * sz))
	return out

## One eagle wing; its origin is the shoulder and it extends along +Z.
static func wing() -> ArrayMesh:
	if _cache.has("wing"):
		return _cache["wing"]
	var m := MeshBuilder.new()
	m.quad(V(-0.1, 0, 0), V(0.1, 0, 0), V(0.05, 0, 0.3), V(-0.12, 0, 0.3), Color("4a3524"), Vector3.UP)
	m.quad(V(-0.12, 0, 0.3), V(0.05, 0, 0.3), V(-0.02, 0, 0.58), V(-0.14, 0, 0.55), Color("3d2b1f"), Vector3.UP)
	_cache["wing"] = m.commit()
	return _cache["wing"]

## Animal bodies (legs and wings are separate, see above). They face +X.
static func animal(id: String) -> ArrayMesh:
	var key := "animal_" + id
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	match id:
		"elk":
			var fur := Color("a87445")
			m.block(V(0, 0.2, 0), V(0.4, 0.18, 0.18), fur)
			m.block(V(0.02, 0.36, 0), V(0.3, 0.03, 0.15), Color("8f5f37"))
			m.block(V(-0.2, 0.26, 0), V(0.03, 0.1, 0.14), Color("ead9b8"))
			m.block(V(0.2, 0.3, 0), V(0.09, 0.2, 0.1), Color("8a5c36"))
			m.block(V(0.27, 0.44, 0), V(0.16, 0.09, 0.1), Color("8a5c36"))
			m.block(V(0.35, 0.445, 0), V(0.03, 0.05, 0.07), Color("3a2a1c"))
			for s in [-1.0, 1.0]:
				m.block(V(0.21, 0.5, 0.06 * s), V(0.03, 0.05, 0.02), Color("8a5c36"))
				m.block(V(0.22, 0.53, 0.05 * s), V(0.02, 0.16, 0.02), Color("e8dcc0"))
				m.block(V(0.22, 0.63, 0.09 * s), V(0.02, 0.02, 0.1), Color("e8dcc0"))
				m.block(V(0.27, 0.6, 0.05 * s), V(0.08, 0.02, 0.02), Color("e8dcc0"))
				m.block(V(0.18, 0.66, 0.12 * s), V(0.02, 0.07, 0.02), Color("e8dcc0"))
		"bear":
			var fur := Color("3d2d22")
			m.block(V(0, 0.12, 0), V(0.46, 0.24, 0.26), fur)
			m.block(V(-0.05, 0.36, 0), V(0.26, 0.05, 0.22), Color("463428"))
			m.block(V(0.28, 0.2, 0), V(0.18, 0.18, 0.2), fur)
			m.block(V(0.39, 0.22, 0), V(0.07, 0.08, 0.1), Color("a8855f"))
			m.block(V(0.425, 0.27, 0), V(0.02, 0.03, 0.04), Color("1a1512"))
			m.block(V(0.27, 0.38, 0.07), V(0.05, 0.05, 0.05), fur)
			m.block(V(0.27, 0.38, -0.07), V(0.05, 0.05, 0.05), fur)
			m.block(V(-0.24, 0.2, 0), V(0.04, 0.06, 0.06), fur)
		"fox":
			var fur := Color("ef7f2e")
			m.block(V(0, 0.09, 0), V(0.26, 0.1, 0.1), fur)
			m.block(V(0, 0.09, 0), V(0.2, 0.03, 0.102), Color("f5e6d0"))
			m.block(V(0.17, 0.14, 0), V(0.1, 0.1, 0.1), fur)
			m.block(V(0.24, 0.15, 0), V(0.06, 0.04, 0.05), Color.WHITE)
			m.block(V(0.275, 0.17, 0), V(0.015, 0.02, 0.025), Color("1a1512"))
			m.block(V(0.15, 0.24, 0.035), V(0.03, 0.05, 0.03), Color("5a3320"))
			m.block(V(0.15, 0.24, -0.035), V(0.03, 0.05, 0.03), Color("5a3320"))
			m.block(V(-0.2, 0.11, 0), V(0.16, 0.08, 0.08), fur)
			m.block(V(-0.3, 0.11, 0), V(0.06, 0.07, 0.07), Color.WHITE)
		"wolf":
			var fur := Color("8a8f94")
			m.block(V(0, 0.15, 0), V(0.38, 0.14, 0.13), fur)
			m.block(V(0, 0.27, 0), V(0.3, 0.025, 0.11), Color("5f6368"))
			m.block(V(0, 0.15, 0), V(0.3, 0.035, 0.132), Color("c9cdd1"))
			m.block(V(0.2, 0.22, 0), V(0.1, 0.14, 0.1), fur)
			m.block(V(0.26, 0.3, 0), V(0.14, 0.1, 0.11), fur)
			m.block(V(0.35, 0.3, 0), V(0.08, 0.05, 0.06), Color("c9cdd1"))
			m.block(V(0.39, 0.33, 0), V(0.015, 0.02, 0.03), Color("1a1512"))
			m.block(V(0.23, 0.4, 0.04), V(0.03, 0.05, 0.03), Color("5f6368"))
			m.block(V(0.23, 0.4, -0.04), V(0.03, 0.05, 0.03), Color("5f6368"))
			m.block(V(-0.25, 0.17, 0), V(0.16, 0.06, 0.06), Color("6f7378"))
		"goat":
			var fur := Color("fbfaf4")
			m.block(V(0, 0.13, 0), V(0.3, 0.17, 0.16), fur)
			m.block(V(0.17, 0.26, 0), V(0.11, 0.12, 0.1), fur)
			m.block(V(0.2, 0.2, 0), V(0.03, 0.07, 0.03), Color("e6e0d2"))
			m.block(V(0.225, 0.32, 0), V(0.015, 0.02, 0.03), Color("1a1512"))
			m.block(V(0.15, 0.38, 0.03), V(0.02, 0.08, 0.02), Color("3a3a3a"))
			m.block(V(0.15, 0.38, -0.03), V(0.02, 0.08, 0.02), Color("3a3a3a"))
			m.block(V(-0.16, 0.24, 0), V(0.03, 0.04, 0.04), fur)
		"bighorn":
			var fur := Color("b08a62")
			m.block(V(0, 0.15, 0), V(0.34, 0.18, 0.17), fur)
			m.block(V(-0.16, 0.2, 0), V(0.03, 0.1, 0.13), Color("efe6d6"))
			m.block(V(0.18, 0.28, 0), V(0.12, 0.13, 0.11), fur)
			m.block(V(0.25, 0.28, 0), V(0.04, 0.06, 0.07), Color("efe6d6"))
			for s in [-1.0, 1.0]:
				m.block(V(0.14, 0.4, 0.07 * s), V(0.1, 0.04, 0.04), Color("6b5a44"))
				m.block(V(0.09, 0.34, 0.09 * s), V(0.04, 0.09, 0.04), Color("6b5a44"))
				m.block(V(0.14, 0.31, 0.1 * s), V(0.07, 0.035, 0.035), Color("6b5a44"))
		"heron":
			m.block(V(0, 0.2, 0), V(0.2, 0.09, 0.09), Color("7f93a6"))
			m.block(V(-0.12, 0.2, 0), V(0.1, 0.05, 0.07), Color("5f7286"))
			m.block(V(0.1, 0.27, 0), V(0.03, 0.17, 0.03), Color("c9d3dc"))
			m.block(V(0.12, 0.43, 0), V(0.07, 0.045, 0.045), Color("e9eef2"))
			m.block(V(0.2, 0.44, 0), V(0.11, 0.018, 0.018), Color("e0a82e"))
			m.block(V(0.09, 0.47, 0), V(0.06, 0.012, 0.02), Color("2a3340"))
		"pika":
			m.blob(V(0, 0.045, 0), V(0.085, 0.055, 0.06), Color("9a7f5f"), 6)
			m.blob(V(0.075, 0.06, 0), V(0.045, 0.04, 0.045), Color("9a7f5f"), 6)
			m.block(V(0.07, 0.09, 0.03), V(0.02, 0.03, 0.025), Color("7a6248"))
			m.block(V(0.07, 0.09, -0.03), V(0.02, 0.03, 0.025), Color("7a6248"))
		"beaver":
			m.block(V(0, 0, 0), V(0.24, 0.11, 0.14), Color("8a5c36"))
			m.block(V(0.14, 0.03, 0), V(0.1, 0.1, 0.11), Color("8a5c36"))
			m.block(V(0.195, 0.06, 0), V(0.015, 0.025, 0.04), Color("1a1512"))
			m.block(V(-0.19, 0.01, 0), V(0.16, 0.03, 0.1), Color("4a3524"))
		"trout":
			m.box(V(0, 0, 0), V(0.26, 0.05, 0.08), Color("3d5f78"))
			m.box(V(-0.17, 0, 0), V(0.08, 0.05, 0.14), Color("3d5f78"))
			m.box(V(0.02, 0.03, 0), V(0.08, 0.03, 0.02), Color("4d7391"))
		"salamander":
			m.box(V(0, 0.02, 0), V(0.16, 0.035, 0.05), Color("e9a23b"))
			m.box(V(0.1, 0.022, 0), V(0.06, 0.04, 0.06), Color("e9a23b"))
			m.box(V(-0.14, 0.015, 0), V(0.14, 0.025, 0.025), Color("d98a1f"))
			m.box(V(0, 0.04, 0), V(0.04, 0.01, 0.03), Color("3a2a14"))
			for sx in [-0.05, 0.06]:
				m.box(V(sx, 0.012, 0), V(0.02, 0.015, 0.11), Color("d98a1f"))
		"eagle":
			m.box(V(0, 0, 0), V(0.3, 0.07, 0.1), Color("3d2b1f"))
			m.box(V(0.19, 0.01, 0), V(0.1, 0.08, 0.09), Color.WHITE)
			m.box(V(0.26, 0.0, 0), V(0.05, 0.03, 0.04), Color("f2c14e"))
			m.box(V(-0.2, 0, 0), V(0.1, 0.02, 0.14), Color.WHITE)
	_cache[key] = m.commit()
	return _cache[key]


static func landmark(kind: String) -> ArrayMesh:
	if _cache.has("lm_" + kind):
		return _cache["lm_" + kind]
	var m := MeshBuilder.new()
	match kind:
		"summit":
			m.cyl(V(0, 0, 0), 0.025, 0.9, 5, Color("6b4a2f"))
			m.box(V(0.2, 0.78, 0), V(0.38, 0.22, 0.02), Color("e8554e"))
		"falls":
			m.block(V(0, -0.3, 0), V(0.7, 1.5, 0.3), Color("eaf7fd"))
			m.block(V(-0.2, -0.3, 0.02), V(0.12, 1.55, 0.3), Color.WHITE)
			m.block(V(0.18, -0.3, 0.02), V(0.1, 1.5, 0.3), Color.WHITE)
			m.block(V(-0.5, -0.3, 0), V(0.34, 1.7, 0.5), Color("8f8a94"))
			m.block(V(0.5, -0.3, 0), V(0.34, 1.6, 0.5), Color("7c7783"))
			m.blob(V(-0.15, 0.05, 0.4), V(0.3, 0.14, 0.26), Color.WHITE)
			m.blob(V(0.25, 0.05, 0.5), V(0.26, 0.12, 0.24), Color.WHITE)
		"grove":
			m.cyl(V(0, 0, 0), 0.2, 1.3, 7, Color("6b4226"))
			m.blob(V(0, 1.7, 0), V(0.95, 0.75, 0.95), Color("256b48"), 8)
			m.blob(V(0.3, 2.2, 0.15), V(0.6, 0.5, 0.6), Color("2f8257"), 7)
			m.blob(V(-0.45, 1.5, -0.3), V(0.5, 0.4, 0.5), Color("2f8257"), 7)
		"spring":
			m.cyl(V(0, 0.0, 0), 0.9, 0.03, 12, Color("f1d9a0"))
			m.cyl(V(0, 0.01, 0), 0.72, 0.03, 12, Color("f08a3c"))
			m.cyl(V(0, 0.02, 0), 0.56, 0.03, 12, Color("f6d44d"))
			m.cyl(V(0, 0.03, 0), 0.42, 0.03, 12, Color("3fd0c9"))
			m.cyl(V(0, 0.04, 0), 0.22, 0.03, 10, Color("2a8fd6"))
			m.blob(V(0.05, 0.5, 0), V(0.16, 0.16, 0.16), Color(1, 1, 1, 0.5), 6)
			m.blob(V(-0.1, 0.9, 0.08), V(0.22, 0.2, 0.22), Color(1, 1, 1, 0.4), 6)
		"lake":
			pass
	_cache["lm_" + kind] = m.commit()
	return _cache["lm_" + kind]
