class_name MeshBuilder
extends RefCounted
## Tiny helper for building flat-shaded, vertex-coloured low-poly meshes.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()


func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, nrm: Vector3) -> void:
	# keep the winding consistent with the normal (Godot front faces are clockwise)
	if (d - a).cross(b - a).dot(nrm) < 0.0:
		var swap := b
		b = d
		d = swap
	v.append(a); v.append(b); v.append(d)
	n.append(nrm); n.append(nrm); n.append(nrm)
	c.append(col); c.append(col); c.append(col)


## Triangle whose normal is made to point away from `inside`.
func tri_out(a: Vector3, b: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	var nrm := (b - a).cross(d - a).normalized()
	if nrm.dot((a + b + d) / 3.0 - inside) < 0.0:
		nrm = -nrm
	tri(a, b, d, col, nrm)


func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, nrm: Vector3) -> void:
	tri(a, b, d, col, nrm)
	tri(a, d, e, col, nrm)


func quad_out(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, inside: Vector3) -> void:
	tri_out(a, b, d, col, inside)
	tri_out(a, d, e, col, inside)


## Axis-aligned box. `center` is the middle of the box.
func box(center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p := func(sx: float, sy: float, sz: float) -> Vector3:
		return center + Vector3(h.x * sx, h.y * sy, h.z * sz)
	quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), col, Vector3.UP)
	quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col, Vector3.DOWN)
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col, Vector3.BACK)
	quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), col, Vector3.FORWARD)
	quad(p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), col, Vector3.RIGHT)
	quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col, Vector3.LEFT)


## Box sitting on the plane y = base.y (base is the centre of its bottom face).
func block(base: Vector3, size: Vector3, col: Color) -> void:
	box(base + Vector3(0, size.y * 0.5, 0), size, col)


## Gable roof: a triangular prism whose rectangular base is centred on `base`.
func gable(base: Vector3, size: Vector3, col: Color, ridge_along_x: bool = true) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var inside := base + Vector3(0, size.y * 0.3, 0)
	var b := [base + Vector3(-hx, 0, -hz), base + Vector3(hx, 0, -hz), base + Vector3(hx, 0, hz), base + Vector3(-hx, 0, hz)]
	if ridge_along_x:
		var r0 := base + Vector3(-hx, size.y, 0)
		var r1 := base + Vector3(hx, size.y, 0)
		quad_out(b[0], b[1], r1, r0, col, inside)
		quad_out(b[3], b[2], r1, r0, col.darkened(0.08), inside)
		tri_out(b[0], b[3], r0, col.darkened(0.15), inside)
		tri_out(b[1], b[2], r1, col.darkened(0.15), inside)
	else:
		var r0 := base + Vector3(0, size.y, -hz)
		var r1 := base + Vector3(0, size.y, hz)
		quad_out(b[0], b[3], r1, r0, col, inside)
		quad_out(b[1], b[2], r1, r0, col.darkened(0.08), inside)
		tri_out(b[0], b[1], r0, col.darkened(0.15), inside)
		tri_out(b[3], b[2], r1, col.darkened(0.15), inside)


func cone(base: Vector3, radius: float, height: float, sides: int, col: Color, twist: float = 0.0) -> void:
	var top := base + Vector3(0, height, 0)
	var inside := base + Vector3(0, height * 0.3, 0)
	for i in sides:
		var a0 := TAU * i / sides + twist
		var a1 := TAU * (i + 1) / sides + twist
		var p0 := base + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		tri_out(p0, p1, top, col.darkened(0.1 * (i % 2)), inside)
		tri(p0, p1, base, col.darkened(0.25), Vector3.DOWN)


## Cone with smooth (per-vertex) normals, for trees.
func cone_smooth(base: Vector3, radius: float, height: float, sides: int, col: Color, tip: Color) -> void:
	var top := base + Vector3(0, height, 0)
	var ny := radius / maxf(height, 0.001)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := Vector3(d0.x, ny, d0.z).normalized()
		var n1 := Vector3(d1.x, ny, d1.z).normalized()
		# droop the skirt a little so tiers read as boughs
		var p0 := base + d0 * radius * (1.0 if i % 2 == 0 else 0.88)
		var p1 := base + d1 * radius * (1.0 if (i + 1) % 2 == 0 else 0.88)
		if (top - p0).cross(p1 - p0).dot(n0) < 0.0:
			v.append(p1); v.append(p0); v.append(top)
			n.append(n1); n.append(n0); n.append((n0 + n1).normalized())
		else:
			v.append(p0); v.append(p1); v.append(top)
			n.append(n0); n.append(n1); n.append((n0 + n1).normalized())
		c.append(col); c.append(col); c.append(tip)
		tri(p0, p1, base, col.darkened(0.45), Vector3.DOWN)


func cyl(base: Vector3, radius: float, height: float, sides: int, col: Color) -> void:
	var up := Vector3(0, height, 0)
	var inside := base + up * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		quad_out(p0, p1, p1 + up, p0 + up, col, inside)
		tri(p0 + up, p1 + up, base + up, col.lightened(0.08), Vector3.UP)


## Chunky low-poly ball (squashed by `r`).
func blob(center: Vector3, r: Vector3, col: Color, seg: int = 6) -> void:
	var rings := 3
	for j in rings:
		var t0 := PI * j / rings
		var t1 := PI * (j + 1) / rings
		for i in seg:
			var a0 := TAU * i / seg + j * 0.4
			var a1 := TAU * (i + 1) / seg + j * 0.4
			var b0 := TAU * i / seg + (j + 1) * 0.4
			var b1 := TAU * (i + 1) / seg + (j + 1) * 0.4
			var p00 := center + Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0)) * r
			var p01 := center + Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1)) * r
			var p10 := center + Vector3(sin(t1) * cos(b0), cos(t1), sin(t1) * sin(b0)) * r
			var p11 := center + Vector3(sin(t1) * cos(b1), cos(t1), sin(t1) * sin(b1)) * r
			var shade := col.lightened(0.12) if j == 0 else (col if j == 1 else col.darkened(0.12))
			if j > 0:
				tri_out(p00, p01, p10, shade, center)
			if j < rings - 1:
				tri_out(p01, p11, p10, shade, center)


func is_empty() -> bool:
	return v.is_empty()


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
