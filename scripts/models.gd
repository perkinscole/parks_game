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
	m.block(V(0, 0, 0), V(0.09, 0.3, 0.09), WOOD_D)
	m.cyl(V(0.06, 0.012, 0.05), 0.3, 0.004, 8, Color("4f8f4a")) # soft contact shadow
	_cache["trunk"] = m.commit()
	return _cache["trunk"]

## White foliage: tinted per instance (so seasons can recolour it).
static func leaf() -> ArrayMesh:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var m := MeshBuilder.new()
	m.blob(V(0, 0.52, 0), V(0.34, 0.32, 0.34), Color.WHITE)
	m.blob(V(0.1, 0.72, 0.05), V(0.22, 0.2, 0.22), Color(1.08, 1.08, 1.08))
	_cache["leaf"] = m.commit()
	return _cache["leaf"]

static func conifer() -> ArrayMesh:
	if _cache.has("conifer"):
		return _cache["conifer"]
	var m := MeshBuilder.new()
	m.cone(V(0, 0.18, 0), 0.34, 0.42, 6, Color(0.85, 0.85, 0.85))
	m.cone(V(0, 0.42, 0), 0.26, 0.38, 6, Color(0.95, 0.95, 0.95), 0.5)
	m.cone(V(0, 0.66, 0), 0.17, 0.34, 6, Color(1.08, 1.08, 1.08))
	_cache["conifer"] = m.commit()
	return _cache["conifer"]

static func rock() -> ArrayMesh:
	if _cache.has("rock"):
		return _cache["rock"]
	var m := MeshBuilder.new()
	m.blob(V(0, 0.08, 0), V(0.2, 0.16, 0.17), Color("a9a299"), 5)
	_cache["rock"] = m.commit()
	return _cache["rock"]

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

## Person parts, white where tinted per instance.
static func person_body() -> ArrayMesh:
	if _cache.has("pbody"):
		return _cache["pbody"]
	var m := MeshBuilder.new()
	m.block(V(-0.035, 0, 0), V(0.05, 0.1, 0.06), Color(0.25, 0.27, 0.34))
	m.block(V(0.035, 0, 0), V(0.05, 0.1, 0.06), Color(0.25, 0.27, 0.34))
	m.block(V(0, 0.1, 0), V(0.15, 0.15, 0.1), Color.WHITE)
	_cache["pbody"] = m.commit()
	return _cache["pbody"]

static func person_head() -> ArrayMesh:
	if _cache.has("phead"):
		return _cache["phead"]
	var m := MeshBuilder.new()
	m.block(V(0, 0.26, 0), V(0.11, 0.1, 0.1), Color.WHITE)
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


## Animals face +X.
static func animal(id: String) -> ArrayMesh:
	if _cache.has("animal_" + id):
		return _cache["animal_" + id]
	var m := MeshBuilder.new()
	match id:
		"elk":
			var fur := Color("a87445")
			for lx in [-0.13, 0.13]:
				for lz in [-0.06, 0.06]:
					m.block(V(lx, 0, lz), V(0.04, 0.2, 0.04), Color("5c3d25"))
			m.block(V(0, 0.2, 0), V(0.4, 0.18, 0.18), fur)
			m.block(V(-0.2, 0.26, 0), V(0.03, 0.1, 0.14), Color("ead9b8"))
			m.block(V(0.2, 0.3, 0), V(0.09, 0.2, 0.1), Color("8a5c36"))
			m.block(V(0.27, 0.44, 0), V(0.16, 0.09, 0.1), Color("8a5c36"))
			for s in [-1.0, 1.0]:
				m.block(V(0.22, 0.53, 0.05 * s), V(0.02, 0.16, 0.02), Color("e8dcc0"))
				m.block(V(0.22, 0.63, 0.09 * s), V(0.02, 0.02, 0.1), Color("e8dcc0"))
				m.block(V(0.27, 0.6, 0.05 * s), V(0.08, 0.02, 0.02), Color("e8dcc0"))
		"bear":
			var fur := Color("3d2d22")
			for lx in [-0.14, 0.14]:
				for lz in [-0.08, 0.08]:
					m.block(V(lx, 0, lz), V(0.08, 0.13, 0.08), Color("2f221a"))
			m.block(V(0, 0.12, 0), V(0.46, 0.24, 0.26), fur)
			m.block(V(0.28, 0.2, 0), V(0.18, 0.18, 0.2), fur)
			m.block(V(0.39, 0.22, 0), V(0.07, 0.08, 0.1), Color("a8855f"))
			m.block(V(0.27, 0.38, 0.07), V(0.05, 0.05, 0.05), fur)
			m.block(V(0.27, 0.38, -0.07), V(0.05, 0.05, 0.05), fur)
		"fox":
			var fur := Color("ef7f2e")
			for lx in [-0.08, 0.08]:
				m.block(V(lx, 0, 0), V(0.035, 0.09, 0.08), Color("5a3320"))
			m.block(V(0, 0.09, 0), V(0.26, 0.1, 0.1), fur)
			m.block(V(0.17, 0.14, 0), V(0.1, 0.1, 0.1), fur)
			m.block(V(0.24, 0.15, 0), V(0.06, 0.04, 0.05), Color.WHITE)
			m.block(V(0.15, 0.24, 0.035), V(0.03, 0.05, 0.03), Color("5a3320"))
			m.block(V(0.15, 0.24, -0.035), V(0.03, 0.05, 0.03), Color("5a3320"))
			m.block(V(-0.2, 0.11, 0), V(0.16, 0.08, 0.08), fur)
			m.block(V(-0.3, 0.11, 0), V(0.06, 0.07, 0.07), Color.WHITE)
		"goat":
			var fur := Color("fbfaf4")
			for lx in [-0.09, 0.09]:
				for lz in [-0.05, 0.05]:
					m.block(V(lx, 0, lz), V(0.035, 0.13, 0.035), Color("d8d2c6"))
			m.block(V(0, 0.13, 0), V(0.3, 0.17, 0.16), fur)
			m.block(V(0.17, 0.26, 0), V(0.11, 0.12, 0.1), fur)
			m.block(V(0.2, 0.2, 0), V(0.03, 0.07, 0.03), Color("e6e0d2"))
			m.block(V(0.15, 0.38, 0.03), V(0.02, 0.08, 0.02), Color("3a3a3a"))
			m.block(V(0.15, 0.38, -0.03), V(0.02, 0.08, 0.02), Color("3a3a3a"))
		"beaver":
			m.block(V(0, 0, 0), V(0.24, 0.11, 0.14), Color("8a5c36"))
			m.block(V(0.14, 0.03, 0), V(0.1, 0.1, 0.11), Color("8a5c36"))
			m.block(V(-0.19, 0.01, 0), V(0.16, 0.03, 0.1), Color("4a3524"))
		"trout":
			m.box(V(0, 0, 0), V(0.26, 0.05, 0.08), Color("3d5f78"))
			m.box(V(-0.17, 0, 0), V(0.08, 0.05, 0.14), Color("3d5f78"))
		"salamander":
			m.box(V(0, 0.02, 0), V(0.16, 0.035, 0.05), Color("e9a23b"))
			m.box(V(0.1, 0.022, 0), V(0.06, 0.04, 0.06), Color("e9a23b"))
			m.box(V(-0.14, 0.015, 0), V(0.14, 0.025, 0.025), Color("d98a1f"))
			m.box(V(0, 0.04, 0), V(0.04, 0.01, 0.03), Color("3a2a14"))
		"eagle":
			m.box(V(0, 0, 0), V(0.3, 0.07, 0.1), Color("3d2b1f"))
			m.box(V(0.19, 0.01, 0), V(0.1, 0.08, 0.09), Color.WHITE)
			m.box(V(0.26, 0.0, 0), V(0.05, 0.03, 0.04), Color("f2c14e"))
			m.box(V(-0.2, 0, 0), V(0.1, 0.02, 0.14), Color.WHITE)
			m.quad(V(-0.08, 0.02, 0.05), V(0.1, 0.02, 0.05), V(0.04, 0.1, 0.55), V(-0.1, 0.1, 0.55), Color("4a3524"), Vector3.UP)
			m.quad(V(-0.08, 0.02, -0.05), V(0.1, 0.02, -0.05), V(0.04, 0.1, -0.55), V(-0.1, 0.1, -0.55), Color("4a3524"), Vector3.UP)
	_cache["animal_" + id] = m.commit()
	return _cache["animal_" + id]


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
