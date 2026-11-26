class_name Terrain3D
extends Node3D
## The 3D landscape: a smooth, finely tessellated terrain with real relief,
## water, roads and trails draped over it, forests, buildings and landmarks,
## plus unplayable terrain that carries on to the horizon.
## One tile = 1 world unit. Tile (x, y) spans x..x+1 on X and y..y+1 on Z.

const CH := 8
const SUB := 4 # terrain vertices per tile edge
const CELLS := 8
const DECK := 0.14 # height of bridges and boardwalks above the water
const BORDER := 56 # tiles of scenery beyond the playable map
const GW := World.W * SUB + 1
const GH := World.H * SUB + 1
const LIT := [D.B.VISITOR_CENTER, D.B.RANGER, D.B.RESEARCH, D.B.SNACK, D.B.CAMP, D.B.GATE, D.B.RESTROOM]
const NO_FOUNDATION := [D.B.BIN, D.B.SIGN, D.B.PICNIC, D.B.TRAILHEAD, D.B.CRAG, D.B.GATE, D.B.CAMP]

var world: World
var season := 0
var climate := 0.0
var font: Font
var mat: StandardMaterial3D
var win_mat: StandardMaterial3D
var hf := PackedFloat32Array() # fine height field, GW x GH
var tcol := PackedColorArray() # per-tile ground colour for the current season
var detail := FastNoiseLite.new()

var _tchunks := {}
var _pchunks := {}
var _dirty_t := {}
var _dirty_p := {}
var _veg_dirty := true
var _small_dirty := true
var _struct_dirty := true
var _seen_build := PackedByteArray()
var _seen_trees := PackedByteArray()
var _mm := {}
var _struct_nodes := {}
var _lights: Array[OmniLight3D] = []
var _orchid_tiles: Array[Vector2i] = []
var _outer_trees: Array = []
var _night := 0.0
var _seen_burn := PackedByteArray()
var fire_light: OmniLight3D


func setup(w: World, f: Font) -> void:
	world = w
	font = f
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	win_mat = StandardMaterial3D.new()
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_mat.albedo_color = Color(0.45, 0.6, 0.72)
	detail.seed = int(world.rng.seed) + 5
	detail.frequency = 0.22
	detail.fractal_octaves = 3
	_compute_heights()
	_recolor_tiles()
	for cy in range(0, ceili(World.H / float(CH))):
		for cx in range(0, ceili(World.W / float(CH))):
			var k := Vector2i(cx, cy)
			for dict in [_tchunks, _pchunks]:
				var mi := MeshInstance3D.new()
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if dict == _pchunks else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				add_child(mi)
				dict[k] = mi
			_tchunks[k].mesh = _terrain_mesh(cx, cy)
			_dirty_p[k] = true
	_seen_build = world.build.duplicate()
	_seen_trees = world.trees.duplicate()
	_seen_burn = world.burned.duplicate()

	var outer := MeshInstance3D.new()
	outer.mesh = _outskirts_mesh()
	outer.material_override = mat
	add_child(outer)

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(World.W + BORDER * 2, World.H + BORDER * 2)
	water.mesh = plane
	water.position = Vector3(World.W * 0.5, 0.0, World.H * 0.5)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.13, 0.33, 0.45, 0.86)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.06
	wm.metallic = 0.25
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var meshes := {"trunk": Models.trunk(), "leaf": Models.leaf(), "conifer": Models.conifer(), "rock": Models.rock(),
		"flame": Models.flame(), "flower": Models.flower(), "litter": Models.litter(), "thistle": Models.thistle(), "milfoil": Models.milfoil(), "orchid": Models.orchid()}
	for key: String in meshes:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[key]
		mmi.multimesh = mm
		mmi.material_override = mat
		if key == "flower" or key == "litter" or key == "milfoil" or key == "flame":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if key == "flame":
			var fm := StandardMaterial3D.new()
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.vertex_color_use_as_albedo = true
			fm.albedo_color = Color(3.0, 1.3, 0.35)
			mmi.material_override = fm
		add_child(mmi)
		_mm[key] = mm

	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.5, 0.15)
	fire_light.light_energy = 6.0
	fire_light.omni_range = 14.0
	fire_light.visible = false
	add_child(fire_light)
	for i in world.rare.size():
		if world.rare[i] > 0.0:
			_orchid_tiles.append(Vector2i(i % World.W, i / World.W))
	_build_landmarks()
	world.changed.connect(_on_changed)
	_process(0.0)


# ------------------------------------------------------------------- heights

static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


func _compute_heights() -> void:
	var n := World.W * World.H
	# distance to the nearest water, so land rises away from lakes and rivers
	var wd := PackedInt32Array()
	wd.resize(n)
	wd.fill(999)
	var queue: Array[int] = []
	for i in n:
		if world.is_water(world.terrain[i]):
			wd[i] = 0
			queue.append(i)
	var qi := 0
	while qi < queue.size():
		var i := queue[qi]
		qi += 1
		var x := i % World.W
		var y := i / World.W
		for d in World.DIRS:
			var nx := x + d.x
			var ny := y + d.y
			if World.inb(nx, ny) and wd[World.idx(nx, ny)] > wd[i] + 1:
				wd[World.idx(nx, ny)] = wd[i] + 1
				queue.append(World.idx(nx, ny))
	var th := PackedFloat32Array()
	th.resize(n)
	for i in n:
		var e := world.elev[i]
		var h := 0.0
		match world.terrain[i]:
			D.T.DEEP: h = -1.4
			D.T.WATER: h = -0.3
			D.T.SAND: h = 0.25
			D.T.ROCK: h = 2.3 + maxf(0.0, e - 0.62) * 24.0
			D.T.PEAK: h = 4.2 + maxf(0.0, e - 0.70) * 50.0
			_: h = 0.32 + clampf(e - 0.31, 0.0, 0.4) * 6.5
		if h > 0.0:
			var d := float(wd[i] - 1)
			h = minf(h, 0.25 + d * 0.5 + d * d * 0.03)
			# rolling hills away from the shore
			h += detail.get_noise_2d((i % World.W) * 0.55, (i / World.W) * 0.55) * 0.9 * clampf((d - 1.0) / 4.0, 0.0, 1.0)
			h = maxf(h, 0.2)
		th[i] = h
	# tile corners
	var cw := World.W + 1
	var ch := PackedFloat32Array()
	ch.resize(cw * (World.H + 1))
	for y in World.H + 1:
		for x in cw:
			var x0 := clampi(x - 1, 0, World.W - 1)
			var x1 := clampi(x, 0, World.W - 1)
			var y0 := clampi(y - 1, 0, World.H - 1)
			var y1 := clampi(y, 0, World.H - 1)
			ch[y * cw + x] = (th[y0 * World.W + x0] + th[y0 * World.W + x1] + th[y1 * World.W + x0] + th[y1 * World.W + x1]) * 0.25
	# smooth interpolation: along X, then along Z
	var tmp := PackedFloat32Array()
	tmp.resize(GW * (World.H + 1))
	for y in World.H + 1:
		var row := y * cw
		for gx in GW:
			var i := mini(gx / SUB, World.W - 1)
			var t := float(gx - i * SUB) / SUB
			tmp[y * GW + gx] = _cr(ch[row + maxi(i - 1, 0)], ch[row + i], ch[row + i + 1], ch[row + mini(i + 2, World.W)], t)
	hf.resize(GW * GH)
	for gy in GH:
		var j := mini(gy / SUB, World.H - 1)
		var t := float(gy - j * SUB) / SUB
		var r0 := maxi(j - 1, 0) * GW
		var r1 := j * GW
		var r2 := (j + 1) * GW
		var r3 := mini(j + 2, World.H) * GW
		for gx in GW:
			var h := _cr(tmp[r0 + gx], tmp[r1 + gx], tmp[r2 + gx], tmp[r3 + gx], t)
			if h > 2.0:
				# craggy detail on high ground
				h += detail.get_noise_2d(gx * 0.25 * 4.0, gy * 0.25 * 4.0) * clampf((h - 2.0) * 0.16, 0.0, 1.1)
			hf[gy * GW + gx] = h


func _h(gx: int, gy: int) -> float:
	return hf[clampi(gy, 0, GH - 1) * GW + clampi(gx, 0, GW - 1)]


func corner(x: int, y: int) -> float:
	return _h(x * SUB, y * SUB)


## Terrain height at a point in tile coordinates (matches the mesh exactly).
func height_at(x: float, z: float) -> float:
	var fx := clampf(x, 0.0, World.W - 0.0001) * SUB
	var fz := clampf(z, 0.0, World.H - 0.0001) * SUB
	var gx := int(fx)
	var gz := int(fz)
	var u := fx - gx
	var v := fz - gz
	var i := gz * GW + gx
	var h00 := hf[i]
	var h10 := hf[i + 1]
	var h01 := hf[i + GW]
	var h11 := hf[i + GW + 1]
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v


## Height of whatever you would stand on: terrain, or a road/bridge deck.
func surface_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var t := Vector2i(clampi(int(x), 0, World.W - 1), clampi(int(z), 0, World.H - 1))
	var i := World.ti(t)
	if world.build[i] != D.B.NONE:
		return maxf(h, DECK if world.is_water(world.terrain[i]) else 0.04)
	return h


## Converts a simulation position (pixels) to a 3D point on the ground.
func ground(p: Vector2) -> Vector3:
	var x := p.x / D.TILE
	var z := p.y / D.TILE
	return Vector3(x, surface_at(x, z), z)


func tile_center(t: Vector2i) -> Vector3:
	return Vector3(t.x + 0.5, surface_at(t.x + 0.5, t.y + 0.5), t.y + 0.5)


# ------------------------------------------------------------------- updates

func _on_changed(rect: Rect2i) -> void:
	_small_dirty = true
	var structural := false
	for y in range(maxi(0, rect.position.y), mini(World.H, rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(World.W, rect.end.x)):
			var i := World.idx(x, y)
			if (_seen_burn[i] > 0) != (world.burned[i] > 0):
				_seen_burn[i] = world.burned[i]
				_recolor_tiles()
				_dirty_t[Vector2i(x / CH, y / CH)] = true
			if _seen_build[i] != world.build[i] or _seen_trees[i] != world.trees[i]:
				structural = true
				_seen_build[i] = world.build[i]
				_seen_trees[i] = world.trees[i]
	if not structural:
		return
	_veg_dirty = true
	_struct_dirty = true
	var r := rect.grow(1)
	for cy in range(floori(r.position.y / float(CH)), floori((r.end.y - 1) / float(CH)) + 1):
		for cx in range(floori(r.position.x / float(CH)), floori((r.end.x - 1) / float(CH)) + 1):
			var k := Vector2i(cx, cy)
			if _tchunks.has(k):
				_dirty_p[k] = true


func set_season(s: int) -> void:
	if s == season:
		return
	season = s
	_recolor_tiles()
	for k in _tchunks:
		_dirty_t[k] = true
	_veg_dirty = true


## 0 = full daylight, 1 = night. Lights the windows and lamps.
func set_night(f: float) -> void:
	if absf(f - _night) < 0.01:
		return
	_night = f
	win_mat.albedo_color = Color(0.45, 0.6, 0.72).lerp(Color(3.2, 2.2, 1.0), f)
	for l in _lights:
		l.light_energy = f * 2.2
		l.visible = f > 0.03


func _process(_delta: float) -> void:
	if world == null:
		return
	var budget := 8 # spread seasonal recolouring over several frames
	for k in _dirty_t.keys():
		_tchunks[k].mesh = _terrain_mesh(k.x, k.y)
		_dirty_t.erase(k)
		budget -= 1
		if budget <= 0:
			break
	for k in _dirty_p.keys():
		_pchunks[k].mesh = _path_mesh(k.x, k.y)
		_dirty_p.erase(k)
	if _veg_dirty:
		_veg_dirty = false
		_rebuild_vegetation()
	if _small_dirty:
		_small_dirty = false
		_rebuild_small()
	if _struct_dirty:
		_struct_dirty = false
		_sync_structures()


# ------------------------------------------------------------------- terrain

func _recolor_tiles() -> void:
	tcol.resize(World.W * World.H)
	for i in World.W * World.H:
		var c := Color.MAGENTA
		match world.terrain[i]:
			D.T.DEEP: c = Color("2b5a73")
			D.T.WATER: c = Color("6d9597")
			D.T.SAND: c = Color("d6c598")
			D.T.GRASS: c = [Color("6f9f48"), Color("678f42"), Color("968f4c"), Color("e3e9e8")][season]
			D.T.MEADOW: c = [Color("8bb254"), Color("82a64e"), Color("ab9d55"), Color("e9eeec")][season]
			D.T.FOREST: c = [Color("40683a"), Color("3a5f34"), Color("5c5f36"), Color("cbd6d1")][season]
			D.T.ROCK: c = Color("8f887b") if season != 3 else Color("c9cbcd")
			D.T.PEAK: c = Color("807b82")
		if world.burned[i] > 0:
			c = Color("3b332c")
		tcol[i] = c


func _snowline() -> float:
	return 0.7 if season == 3 else (5.4 if season == 0 else 6.6) + climate * 1.5


## Colour for a point of ground from biome, steepness, altitude and season.
func _shade(base: Color, h: float, ny: float, jitter: float) -> Color:
	if h < 0.0:
		return base.lerp(Color("244f66"), clampf(-h * 0.9, 0.0, 1.0))
	var c := base
	if h < 0.16:
		c = c.lerp(Color("cdbb8e"), 1.0 - h / 0.16)
	var slope := 1.0 - ny
	c = c.lerp(Color("7b746a").lerp(Color("5f5a55"), jitter), smoothstep(0.09, 0.26, slope))
	var sl := _snowline()
	var snow := smoothstep(sl, sl + 1.6, h + jitter * 1.2) * (1.0 - smoothstep(0.3, 0.55, slope))
	c = c.lerp(Color("f3f6fa"), snow)
	var j := (jitter - 0.5) * 0.06
	return Color(c.r + j, c.g + j, c.b + j * 0.6)


func _terrain_mesh(cx: int, cy: int) -> ArrayMesh:
	var gx0 := cx * CH * SUB
	var gy0 := cy * CH * SUB
	var gx1 := mini(World.W, (cx + 1) * CH) * SUB
	var gy1 := mini(World.H, (cy + 1) * CH) * SUB
	var cols := gx1 - gx0 + 1
	var rows := gy1 - gy0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(cols * rows)
	norms.resize(cols * rows)
	colors.resize(cols * rows)
	var step := 1.0 / SUB
	var k := 0
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			var h := hf[gy * GW + gx]
			var nrm := Vector3(_h(gx - 1, gy) - _h(gx + 1, gy), 2.0 * step, _h(gx, gy - 1) - _h(gx, gy + 1)).normalized()
			# blend the colours of the four nearest tile centres
			var fx := clampf(gx * step - 0.5, 0.0, World.W - 1.0)
			var fy := clampf(gy * step - 0.5, 0.0, World.H - 1.0)
			var tx := mini(int(fx), World.W - 2)
			var ty := mini(int(fy), World.H - 2)
			var u := fx - tx
			var v := fy - ty
			var i := ty * World.W + tx
			var base := tcol[i].lerp(tcol[i + 1], u).lerp(tcol[i + World.W].lerp(tcol[i + World.W + 1], u), v)
			verts[k] = Vector3(gx * step, h, gy * step)
			norms[k] = nrm
			colors[k] = _shade(base, h, nrm.y, D.hash2(gx, gy, 4))
			k += 1
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			idx.append(a); idx.append(a + 1); idx.append(a + cols + 1)
			idx.append(a); idx.append(a + cols + 1); idx.append(a + cols)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Height of the scenery beyond the map edge; blends into the real terrain.
func _outer_height(x: int, y: int) -> float:
	var cxp := clampf(x, 0.0, World.W)
	var cyp := clampf(y, 0.0, World.H)
	var inner := height_at(cxp, cyp)
	var d := Vector2(x - cxp, y - cyp).length()
	if d <= 0.0:
		return inner - 0.15
	var e := world.raw_elev(x, y)
	var g := -0.6
	if e > 0.70: g = 4.2 + (e - 0.70) * 50.0
	elif e > 0.62: g = 2.3 + (e - 0.62) * 24.0
	elif e > 0.30: g = 0.3 + (e - 0.31) * 6.5
	g += maxf(0.0, d - 6.0) * 0.09 + detail.get_noise_2d(x * 2.0, y * 2.0) * clampf(g * 0.15, 0.0, 1.2)
	return lerpf(inner, g, smoothstep(0.0, 9.0, d))


func _outskirts_mesh() -> ArrayMesh:
	var x0 := -BORDER
	var y0 := -BORDER
	var cols := World.W + BORDER * 2 + 1
	var rows := World.H + BORDER * 2 + 1
	var hs := PackedFloat32Array()
	hs.resize(cols * rows)
	for r in rows:
		for c in cols:
			hs[r * cols + c] = _outer_height(x0 + c, y0 + r)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(cols * rows)
	norms.resize(cols * rows)
	colors.resize(cols * rows)
	var forest := [Color("4f7c41"), Color("47703b"), Color("6c703d"), Color("cbd6d1")]
	for r in rows:
		for c in cols:
			var k := r * cols + c
			var h := hs[k]
			var hl := hs[r * cols + maxi(c - 1, 0)]
			var hr := hs[r * cols + mini(c + 1, cols - 1)]
			var hu := hs[maxi(r - 1, 0) * cols + c]
			var hd := hs[mini(r + 1, rows - 1) * cols + c]
			var nrm := Vector3(hl - hr, 2.0, hu - hd).normalized()
			var x := x0 + c
			var y := y0 + r
			verts[k] = Vector3(x, h, y)
			norms[k] = nrm
			var jit := D.hash2(x, y, 4)
			var base: Color = forest[season].lerp(Color("76a44f"), jit * 0.5)
			if h > 2.6:
				base = base.lerp(Color("8f887b"), clampf((h - 2.6) * 0.8, 0.0, 1.0))
			colors[k] = _shade(base, h, nrm.y, jit)
			var inside := x >= 0 and y >= 0 and x < World.W and y < World.H
			if not inside and h > 0.25 and h < 3.4 and nrm.y > 0.8 and jit < 0.7:
				_outer_trees.append(Vector3(x + jit - 0.35, h, y + D.hash2(x, y, 9) - 0.5))
				if jit < 0.4:
					_outer_trees.append(Vector3(x + D.hash2(x, y, 10) * 0.9, h, y + jit))
	for r in rows - 1:
		for c in cols - 1:
			var x := x0 + c
			var y := y0 + r
			if x >= 1 and y >= 1 and x < World.W - 1 and y < World.H - 1:
				continue
			var a := r * cols + c
			idx.append(a); idx.append(a + 1); idx.append(a + cols + 1)
			idx.append(a); idx.append(a + cols + 1); idx.append(a + cols)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _b(x: int, y: int) -> int:
	if World.inb(x, y):
		return world.build[World.idx(x, y)]
	return D.B.ROAD if x == world.entry.x and y >= World.H else D.B.NONE


## A strip following the curve a -> ctrl -> b (tile coordinates), draped on the ground.
func _ribbon(m: MeshBuilder, a: Vector2, ctrl: Vector2, b: Vector2, half: float, col: Color, min_y: float, lift: float, cross: int, dashed: bool = false) -> void:
	var seg := 8
	var prev: Array[Vector3] = []
	for s in seg + 1:
		var t := float(s) / seg
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		var tan := (ctrl - a).lerp(b - ctrl, t)
		if tan.length_squared() < 0.00001:
			tan = b - a
		tan = tan.normalized()
		var perp := Vector2(-tan.y, tan.x)
		var row: Array[Vector3] = []
		for c in cross + 1:
			var q := p + perp * half * (float(c) / cross * 2.0 - 1.0)
			row.append(Vector3(q.x, maxf(height_at(q.x, q.y), min_y) + lift, q.y))
		if s > 0 and not (dashed and s % 2 == 0):
			for c in cross:
				m.quad(prev[c], prev[c + 1], row[c + 1], row[c], col, Vector3.UP)
		prev = row


func _disc(m: MeshBuilder, c: Vector2, r: float, col: Color, min_y: float, lift: float) -> void:
	var mid := Vector3(c.x, maxf(height_at(c.x, c.y), min_y) + lift, c.y)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		var p0 := c + Vector2(cos(a0), sin(a0)) * r
		var p1 := c + Vector2(cos(a1), sin(a1)) * r
		m.tri(mid, Vector3(p0.x, maxf(height_at(p0.x, p0.y), min_y) + lift, p0.y),
			Vector3(p1.x, maxf(height_at(p1.x, p1.y), min_y) + lift, p1.y), col, Vector3.UP)


func _path_mesh(cx: int, cy: int) -> ArrayMesh:
	var m := MeshBuilder.new()
	var step := 1.0 / CELLS
	for y in range(cy * CH, mini(World.H, cy * CH + CH)):
		for x in range(cx * CH, mini(World.W, cx * CH + CH)):
			var i := World.idx(x, y)
			var b := world.build[i]
			if b == D.B.NONE:
				continue
			var water := world.is_water(world.terrain[i])
			var min_y := DECK if water else 0.04
			var c := Vector2(x + 0.5, y + 0.5)
			if b == D.B.ROAD or b == D.B.GATE or b == D.B.TRAIL:
				var road := b != D.B.TRAIL
				var arms: Array[Vector2] = []
				for d in World.DIRS:
					var nb := _b(x + d.x, y + d.y)
					if (road and (nb == D.B.ROAD or nb == D.B.GATE or nb == D.B.PARKING)) or (not road and nb != D.B.NONE):
						arms.append(Vector2(d))
				var half := 0.37 if road else 0.115
				var col := Color("4b4e56") if road else Color("a98659")
				if water:
					col = Color("6b6f78") if road else Color("8a6238")
				elif not road and (world.terrain[i] == D.T.ROCK or world.terrain[i] == D.T.PEAK):
					col = Color("b3a78e")
				var lift := 0.035 if road else 0.045
				var cross := 4 if road else 2
				var edge := col.darkened(0.25) if not road else Color("8d8f95")
				if arms.size() == 2:
					_ribbon(m, c + arms[0] * 0.5, c, c + arms[1] * 0.5, half + 0.035, edge, min_y, lift - 0.012, cross)
					_ribbon(m, c + arms[0] * 0.5, c, c + arms[1] * 0.5, half, col, min_y, lift, cross)
					if road:
						_ribbon(m, c + arms[0] * 0.5, c, c + arms[1] * 0.5, 0.016, Color("d9bd55"), min_y, lift + 0.012, 1, true)
				else:
					_disc(m, c, half + 0.035, edge, min_y, lift - 0.012)
					for arm in arms:
						_ribbon(m, c + arm * 0.5, c + arm * 0.25, c, half + 0.035, edge, min_y, lift - 0.012, cross)
					_disc(m, c, half, col, min_y, lift)
					for arm in arms:
						_ribbon(m, c + arm * 0.5, c + arm * 0.25, c, half, col, min_y, lift, cross)
				if water:
					for k in 4:
						var q := c + Vector2(cos(k * PI * 0.5 + 0.78), sin(k * PI * 0.5 + 0.78)) * (half + 0.05)
						m.box(Vector3(q.x, DECK * 0.2, q.y), Vector3(0.06, DECK + 0.5, 0.06), Color("5f4428") if not road else Color("8a8d92"))
				continue
			# parking lots and building pads cover the whole tile
			var col := Color("5d616a") if b == D.B.PARKING else Color("9c8c6c")
			if b != D.B.PARKING:
				continue
			for cj in CELLS:
				for ci in CELLS:
					var x0 := x + ci * step
					var z0 := y + cj * step
					var x1 := x0 + step
					var z1 := z0 + step
					m.quad(
						Vector3(x0, maxf(height_at(x0, z0), min_y) + 0.03, z0),
						Vector3(x1, maxf(height_at(x1, z0), min_y) + 0.03, z0),
						Vector3(x1, maxf(height_at(x1, z1), min_y) + 0.03, z1),
						Vector3(x0, maxf(height_at(x0, z1), min_y) + 0.03, z1), col, Vector3.UP)
			for lx in [0.01, 0.5]:
				var a := Vector3(x + lx, maxf(height_at(x + lx, y + 0.12), min_y) + 0.05, y + 0.12)
				var bb := Vector3(x + lx, maxf(height_at(x + lx, y + 0.88), min_y) + 0.05, y + 0.88)
				m.quad(a - Vector3(0.012, 0, 0), a + Vector3(0.012, 0, 0), bb + Vector3(0.012, 0, 0), bb - Vector3(0.012, 0, 0), Color("d8d8d8"), Vector3.UP)
	return m.commit()


# ---------------------------------------------------------------- vegetation

func _fill(key: String, xforms: Array, colors: Array) -> void:
	var mm: MultiMesh = _mm[key]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])


func _xf(x: float, z: float, s: float, yaw: float, sink: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x, height_at(x, z) - sink, z))


func _conifer_color(hh: float) -> Color:
	var cc := Color("1c4533").lerp(Color("316647"), hh)
	if season == 3:
		cc = cc.lerp(Color("e9f0f3"), 0.55)
	return cc


func _rebuild_vegetation() -> void:
	var trunks: Array = []
	var trunk_c: Array = []
	var leaves: Array = []
	var leaf_c: Array = []
	var conifers: Array = []
	var con_c: Array = []
	var rocks: Array = []
	var rock_c: Array = []
	var flowers: Array = []
	var flower_c: Array = []
	var bloom := [Color("fffbe6"), Color("f2cf4a"), Color("e98ab0"), Color("a887d6")]
	var leaf_pal := [
		[Color("437f3d"), Color("6a9f4c")], [Color("356b35"), Color("52883f")],
		[Color("b5622c"), Color("d9a93c")], [Color("9aa39c"), Color("e6ecee")]]
	for y in World.H:
		for x in World.W:
			var i := World.idx(x, y)
			if world.build[i] != D.B.NONE or world.landmark_at.has(i):
				continue
			var t := world.terrain[i]
			var h := D.hash2(x, y, 1)
			var h2 := D.hash2(x, y, 7)
			var kind := world.trees[i]
			if kind > 0:
				var count := 3 if t == D.T.FOREST else 1
				for k in count:
					var hh := D.hash2(x, y, 8 + k)
					var px := x + 0.12 + D.hash2(x, y, 50 + k) * 0.76
					var pz := y + 0.12 + D.hash2(x, y, 60 + k) * 0.76
					if height_at(px, pz) < 0.05:
						continue
					var xf := _xf(px, pz, 0.85 + hh * 0.75, hh * TAU, 0.05)
					trunks.append(xf)
					trunk_c.append(Color.WHITE)
					if kind == 2:
						conifers.append(xf)
						con_c.append(_conifer_color(D.hash2(x, y, 12 + k)))
					else:
						leaves.append(xf)
						var pal: Array = leaf_pal[season]
						var col: Color = pal[0].lerp(pal[1], D.hash2(x, y, 12 + k))
						if season == 0 and hh < 0.15:
							col = Color("eab4c8")
						elif season == 2 and hh < 0.35:
							col = Color("a8452c").lerp(Color("c9772e"), hh * 2.0)
						leaf_c.append(col)
			elif t == D.T.ROCK and h < 0.45:
				rocks.append(_xf(x + 0.2 + h2 * 0.6, y + 0.2 + h * 1.2, 0.8 + h2 * 1.6, h * TAU, 0.03))
				rock_c.append(Color.WHITE.darkened(h2 * 0.2))
			elif t == D.T.MEADOW and season != 3:
				for k in 3:
					flowers.append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.35 + h * 0.3, 0.0))
					flower_c.append(bloom[int(D.hash2(x, y, 40 + k) * 4.0) % 4])
	for p: Vector3 in _outer_trees:
		var hh := D.hash2(int(p.x * 7.0), int(p.z * 7.0), 3)
		var xf := Transform3D(Basis(Vector3.UP, hh * TAU).scaled(Vector3.ONE * (1.0 + hh * 0.9)), p - Vector3(0, 0.05, 0))
		conifers.append(xf)
		con_c.append(_conifer_color(hh))
	_fill("trunk", trunks, trunk_c)
	_fill("leaf", leaves, leaf_c)
	_fill("conifer", conifers, con_c)
	_fill("rock", rocks, rock_c)
	_fill("flower", flowers, flower_c)


func _rebuild_small() -> void:
	var xs: Array = []
	var cs: Array = []
	var palette := [Color("f4f4f4"), Color("e8554e"), Color("4a90d9"), Color("f2c14e")]
	for i: int in world.litter_tiles.keys():
		var x := i % World.W
		var y := i / World.W
		for k in world.litter[i]:
			var px := x + 0.15 + D.hash2(x, y, 60 + k) * 0.7
			var pz := y + 0.15 + D.hash2(x, y, 70 + k) * 0.7
			xs.append(Transform3D(Basis(Vector3.UP, k * 1.3), Vector3(px, surface_at(px, pz) + 0.03, pz)))
			cs.append(palette[(k + x) % 4])
	_fill("litter", xs, cs)
	var land: Array = []
	var land_c: Array = []
	var wet: Array = []
	var wet_c: Array = []
	for i: int in world.invasive_tiles.keys():
		if world.inv_seen[i] == 0:
			continue # nobody has noticed this patch yet
		var x := i % World.W
		var y := i / World.W
		var v := world.invasive[i]
		var is_water := world.is_water(world.terrain[i])
		for k in int(2 + v * 5.0):
			var px := x + 0.1 + D.hash2(x, y, 40 + k) * 0.8
			var pz := y + 0.1 + D.hash2(x, y, 50 + k) * 0.8
			if is_water:
				wet.append(Transform3D(Basis(Vector3.UP, k * 0.9).scaled(Vector3.ONE * (0.7 + v)), Vector3(px, 0.005 + k * 0.002, pz)))
				wet_c.append(Color.WHITE)
			else:
				land.append(_xf(px, pz, 0.8 + v * 0.7, k * 1.1))
				land_c.append(Color.WHITE)
	_fill("thistle", land, land_c)
	_fill("milfoil", wet, wet_c)
	var ox: Array = []
	var oc: Array = []
	for t in _orchid_tiles:
		var hp := world.rare[World.ti(t)]
		if hp > 0.0:
			ox.append(_xf(t.x + 0.5, t.y + 0.5, 1.0 + hp * 0.5, 0.0))
			oc.append(Color.WHITE.lerp(Color(0.6, 0.55, 0.5), 1.0 - hp))
	_fill("orchid", ox, oc)
	var fx: Array = []
	var fc: Array = []
	for i: int in world.fire_tiles.keys():
		var x := i % World.W
		var y := i / World.W
		for k in 4:
			var px := x + 0.15 + D.hash2(x, y, 80 + k) * 0.7
			var pz := y + 0.15 + D.hash2(x, y, 90 + k) * 0.7
			fx.append(_xf(px, pz, 0.7 + D.hash2(x, y, 95 + k) * 0.9, k * 1.7))
			fc.append(Color(1.0, 0.75 + D.hash2(x, y, 99 + k) * 0.25, 0.6))
	_fill("flame", fx, fc)
	fire_light.visible = not world.fire_tiles.is_empty()
	if fire_light.visible:
		var fi: int = world.fire_tiles.keys()[0]
		fire_light.position = Vector3(fi % World.W + 0.5, height_at(fi % World.W + 0.5, fi / World.W + 0.5) + 1.5, fi / World.W + 0.5)


func _sync_structures() -> void:
	for id in _struct_nodes.keys():
		if not world.structures.has(id):
			var old: Node3D = _struct_nodes[id]
			for c in old.get_children():
				if c is OmniLight3D:
					_lights.erase(c)
			old.queue_free()
			_struct_nodes.erase(id)
	for id in world.structures:
		if _struct_nodes.has(id):
			continue
		var s: Dictionary = world.structures[id]
		var st: Vector2i = s.tile
		var sz: Vector2i = s.size
		var kind: int = s.kind
		var holder := Node3D.new()
		var cxp := st.x + sz.x * 0.5
		var czp := st.y + sz.y * 0.5
		var top := maxf(height_at(cxp, czp), 0.04)
		if sz.x > 1:
			for dy in [0.15, 1.0, 1.85]:
				for dx in [0.15, 1.0, 1.85]:
					top = maxf(top, height_at(st.x + dx, st.y + dy))
		holder.position = Vector3(cxp, top + 0.03, czp)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.structure(kind)
		mi.material_override = mat
		holder.add_child(mi)
		if not (kind in NO_FOUNDATION):
			var base := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(sz.x * 0.9, 2.5, sz.y * 0.9) if sz.x > 1 else Vector3(0.84, 2.5, 0.84)
			base.mesh = box
			base.position = Vector3(0, -1.25, 0)
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("7c766c")
			bm.roughness = 1.0
			base.material_override = bm
			holder.add_child(base)
		var wins := Models.windows(kind)
		if wins.get_surface_count() > 0:
			var wi := MeshInstance3D.new()
			wi.mesh = wins
			wi.material_override = win_mat
			wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(wi)
		if kind in LIT:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.72, 0.4) if kind != D.B.CAMP else Color(1.0, 0.55, 0.22)
			lamp.omni_range = 4.5 if sz.x > 1 else 3.0
			lamp.omni_attenuation = 1.4
			lamp.position = Vector3(-0.3, 0.3, 0.42) if kind == D.B.CAMP else Vector3(0, 0.45, sz.y * 0.5 + 0.25)
			lamp.light_energy = _night * 2.2
			lamp.visible = _night > 0.03
			holder.add_child(lamp)
			_lights.append(lamp)
		if kind == D.B.GATE:
			var ew := _b(st.x - 1, st.y) in [D.B.ROAD, D.B.PARKING] or _b(st.x + 1, st.y) in [D.B.ROAD, D.B.PARKING]
			var ns := _b(st.x, st.y - 1) in [D.B.ROAD, D.B.PARKING] or _b(st.x, st.y + 1) in [D.B.ROAD, D.B.PARKING]
			if ew and not ns:
				holder.rotation.y = PI * 0.5
		add_child(holder)
		_struct_nodes[id] = holder


func _build_landmarks() -> void:
	for lm in world.landmarks:
		var t: Vector2i = lm.tile
		var pos := Vector3(t.x + 0.5, maxf(height_at(t.x + 0.5, t.y + 0.5), 0.0), t.y + 0.5)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.landmark(lm.kind)
		mi.material_override = mat
		mi.position = pos
		if lm.kind == "grove":
			mi.scale = Vector3(1.6, 1.6, 1.6)
		add_child(mi)
		var label := Label3D.new()
		label.text = lm.name
		label.font = font
		label.font_size = 56
		label.outline_size = 16
		label.pixel_size = 0.013
		label.modulate = Color("fff8dc")
		label.outline_modulate = Color(0.08, 0.12, 0.1, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 5
		var lift := 1.6
		match lm.kind:
			"grove": lift = 5.2
			"summit": lift = 1.9
			"lake": lift = 0.9
		label.position = pos + Vector3(0, lift, 0)
		add_child(label)
