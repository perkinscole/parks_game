class_name Terrain3D
extends Node3D
## The 3D landscape: low-poly terrain, water, roads and trails draped over it,
## forests, buildings, landmarks and all the small scenery.
## One tile = 1 world unit. Tile (x, y) spans x..x+1 on X and y..y+1 on Z.

const CH := 8
const CELLS := 8
const DECK := 0.12 # height of bridges and boardwalks above the water

var world: World
var season := 0
var font: Font
var mat: StandardMaterial3D
var hc := PackedFloat32Array() # corner heights, (W+1) x (H+1)

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
var _orchid_tiles: Array[Vector2i] = []


func setup(w: World, f: Font) -> void:
	world = w
	font = f
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_compute_heights()
	for cy in range(0, ceili(World.H / float(CH))):
		for cx in range(0, ceili(World.W / float(CH))):
			var k := Vector2i(cx, cy)
			for dict in [_tchunks, _pchunks]:
				var mi := MeshInstance3D.new()
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if dict == _pchunks else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				add_child(mi)
				dict[k] = mi
			_dirty_t[k] = true
			_dirty_p[k] = true
	_seen_build = world.build.duplicate()
	_seen_trees = world.trees.duplicate()

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(World.W, World.H)
	water.mesh = plane
	water.position = Vector3(World.W * 0.5, 0.0, World.H * 0.5)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.66, 0.9, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.25
	wm.metallic_specular = 0.6
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var meshes := {"trunk": Models.trunk(), "leaf": Models.leaf(), "conifer": Models.conifer(), "rock": Models.rock(),
		"flower": Models.flower(), "litter": Models.litter(), "thistle": Models.thistle(), "milfoil": Models.milfoil(), "orchid": Models.orchid()}
	for key: String in meshes:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[key]
		mmi.multimesh = mm
		mmi.material_override = mat
		if key == "flower" or key == "litter" or key == "milfoil":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm[key] = mm

	for i in world.rare.size():
		if world.rare[i] > 0.0:
			_orchid_tiles.append(Vector2i(i % World.W, i / World.W))
	_build_landmarks()
	world.changed.connect(_on_changed)
	_process(0.0)


# ------------------------------------------------------------------- heights

func _tile_h(x: int, y: int) -> float:
	x = clampi(x, 0, World.W - 1)
	y = clampi(y, 0, World.H - 1)
	var i := World.idx(x, y)
	var e := world.elev[i]
	match world.terrain[i]:
		D.T.DEEP: return -0.75
		D.T.WATER: return -0.3
		D.T.SAND: return 0.07
		D.T.ROCK: return 0.75 + maxf(0.0, e - 0.62) * 9.0
		D.T.PEAK: return 1.6 + maxf(0.0, e - 0.70) * 24.0 + D.hash2(x, y, 11) * 0.7
	return 0.14 + clampf(e - 0.31, 0.0, 0.4) * 1.5


func _compute_heights() -> void:
	hc.resize((World.W + 1) * (World.H + 1))
	for y in World.H + 1:
		for x in World.W + 1:
			var a := _tile_h(x - 1, y - 1)
			var b := _tile_h(x, y - 1)
			var c := _tile_h(x - 1, y)
			var d := _tile_h(x, y)
			var h := (a + b + c + d) * 0.25
			# keep shorelines crisp: a corner touching water sits just below the surface
			if minf(minf(a, b), minf(c, d)) < 0.0 and h > -0.06:
				h = -0.06
			hc[y * (World.W + 1) + x] = h


func corner(x: int, y: int) -> float:
	return hc[clampi(y, 0, World.H) * (World.W + 1) + clampi(x, 0, World.W)]


## Terrain height at a point in tile coordinates (matches the mesh exactly).
func height_at(x: float, z: float) -> float:
	x = clampf(x, 0.0, World.W - 0.001)
	z = clampf(z, 0.0, World.H - 0.001)
	var tx := int(x)
	var tz := int(z)
	var u := x - tx
	var v := z - tz
	var h00 := corner(tx, tz)
	var h10 := corner(tx + 1, tz)
	var h01 := corner(tx, tz + 1)
	var h11 := corner(tx + 1, tz + 1)
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v


## Height of whatever you would stand on: terrain, or a road/bridge deck.
func surface_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var t := Vector2i(clampi(int(x), 0, World.W - 1), clampi(int(z), 0, World.H - 1))
	var i := World.ti(t)
	if world.build[i] != D.B.NONE:
		return maxf(h, DECK if world.is_water(world.terrain[i]) else 0.03)
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
				_dirty_t[k] = true


func set_season(s: int) -> void:
	if s == season:
		return
	season = s
	for k in _tchunks:
		_dirty_t[k] = true
	_veg_dirty = true


func _process(_delta: float) -> void:
	if world == null:
		return
	# spread heavy rebuilds over frames
	var budget := 24
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

func tile_color(x: int, y: int) -> Color:
	x = clampi(x, 0, World.W - 1)
	y = clampi(y, 0, World.H - 1)
	match world.terrain[World.idx(x, y)]:
		D.T.DEEP: return Color("3277a8")
		D.T.WATER: return Color("6fb4c9")
		D.T.SAND: return Color("f1e0a6")
		D.T.GRASS: return [Color("93d36e"), Color("8fce6a"), Color("b7c874"), Color("e4ece8")][season]
		D.T.MEADOW: return [Color("a6d974"), Color("a2d470"), Color("cfd07c"), Color("ecf2ee")][season]
		D.T.FOREST: return [Color("6fb55b"), Color("68ad55"), Color("93aa5a"), Color("cddbd2")][season]
		D.T.ROCK: return Color("a39a86") if season != 3 else Color("cfcdc8")
		D.T.PEAK: return Color("8d8694")
	return Color.MAGENTA


func _corner_color(x: int, y: int) -> Color:
	var c := tile_color(x - 1, y - 1) + tile_color(x, y - 1) + tile_color(x - 1, y) + tile_color(x, y)
	c = c * 0.25
	var h := corner(x, y)
	var snowline := 1.5 if season == 3 else 3.3
	if h > snowline:
		c = c.lerp(Color("fbfdff"), clampf((h - snowline) * 2.5, 0.0, 1.0))
	var j := (D.hash2(x, y, 4) - 0.5) * 0.07
	return Color(c.r + j, c.g + j, c.b + j * 0.5)


func _terrain_mesh(cx: int, cy: int) -> ArrayMesh:
	var m := MeshBuilder.new()
	var earth := Color("8a6a4a")
	for y in range(cy * CH, mini(World.H, cy * CH + CH)):
		for x in range(cx * CH, mini(World.W, cx * CH + CH)):
			var p00 := Vector3(x, corner(x, y), y)
			var p10 := Vector3(x + 1, corner(x + 1, y), y)
			var p01 := Vector3(x, corner(x, y + 1), y + 1)
			var p11 := Vector3(x + 1, corner(x + 1, y + 1), y + 1)
			var c00 := _corner_color(x, y)
			var c10 := _corner_color(x + 1, y)
			var c01 := _corner_color(x, y + 1)
			var c11 := _corner_color(x + 1, y + 1)
			var n1 := (p11 - p00).cross(p10 - p00).normalized()
			if n1.y < 0.0: n1 = -n1
			var n2 := (p01 - p00).cross(p11 - p00).normalized()
			if n2.y < 0.0: n2 = -n2
			# flat shading with a blended colour per face
			var ca := (c00 + c10 + c11) * (1.0 / 3.0)
			var cb := (c00 + c11 + c01) * (1.0 / 3.0)
			m.tri(p00, p10, p11, ca, n1)
			m.tri(p00, p11, p01, cb, n2)
			var floor_y := -1.6
			if y == 0:
				m.quad(p00, p10, Vector3(x + 1, floor_y, y), Vector3(x, floor_y, y), earth, Vector3.FORWARD)
			if y == World.H - 1:
				m.quad(p01, p11, Vector3(x + 1, floor_y, y + 1), Vector3(x, floor_y, y + 1), earth, Vector3.BACK)
			if x == 0:
				m.quad(p00, p01, Vector3(x, floor_y, y + 1), Vector3(x, floor_y, y), earth.darkened(0.1), Vector3.LEFT)
			if x == World.W - 1:
				m.quad(p10, p11, Vector3(x + 1, floor_y, y + 1), Vector3(x + 1, floor_y, y), earth.darkened(0.1), Vector3.RIGHT)
	return m.commit()


func _b(x: int, y: int) -> int:
	if World.inb(x, y):
		return world.build[World.idx(x, y)]
	return D.B.ROAD if x == world.entry.x and y >= World.H else D.B.NONE


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
			var min_y := DECK if water else 0.03
			var n := b
			var e := b
			var s := b
			var w := b
			var half := 0.5
			var col := Color("cdb98a")
			var is_road := b == D.B.ROAD or b == D.B.GATE
			if is_road:
				half = 0.375
				col = Color("5d616b") if not water else Color("767b85")
				n = _b(x, y - 1); s = _b(x, y + 1); w = _b(x - 1, y); e = _b(x + 1, y)
			elif b == D.B.TRAIL:
				half = 0.125
				col = Color("cfa56a")
				if water: col = Color("b98a52")
				elif world.terrain[i] == D.T.ROCK or world.terrain[i] == D.T.PEAK: col = Color("d6ccb6")
				n = _b(x, y - 1); s = _b(x, y + 1); w = _b(x - 1, y); e = _b(x + 1, y)
			elif b == D.B.PARKING:
				col = Color("6f7480")
			var arm_n := true
			var arm_s := true
			var arm_w := true
			var arm_e := true
			if is_road:
				arm_n = n == D.B.ROAD or n == D.B.GATE or n == D.B.PARKING
				arm_s = s == D.B.ROAD or s == D.B.GATE or s == D.B.PARKING
				arm_w = w == D.B.ROAD or w == D.B.GATE or w == D.B.PARKING
				arm_e = e == D.B.ROAD or e == D.B.GATE or e == D.B.PARKING
			elif b == D.B.TRAIL:
				arm_n = n != D.B.NONE
				arm_s = s != D.B.NONE
				arm_w = w != D.B.NONE
				arm_e = e != D.B.NONE
			for cj in CELLS:
				for ci in CELLS:
					var u := (ci + 0.5) * step
					var v := (cj + 0.5) * step
					var au := absf(u - 0.5)
					var av := absf(v - 0.5)
					var inside := half >= 0.5
					if not inside:
						inside = (au <= half and av <= half) \
							or (au <= half and ((v < 0.5 and arm_n) or (v > 0.5 and arm_s))) \
							or (av <= half and ((u < 0.5 and arm_w) or (u > 0.5 and arm_e)))
					if not inside:
						continue
					var x0 := x + ci * step
					var z0 := y + cj * step
					var x1 := x0 + step
					var z1 := z0 + step
					var shade := col
					if b == D.B.TRAIL and (ci + cj) % 2 == 0:
						shade = col.darkened(0.05)
					m.quad(
						Vector3(x0, maxf(height_at(x0, z0), min_y) + 0.02, z0),
						Vector3(x1, maxf(height_at(x1, z0), min_y) + 0.02, z0),
						Vector3(x1, maxf(height_at(x1, z1), min_y) + 0.02, z1),
						Vector3(x0, maxf(height_at(x0, z1), min_y) + 0.02, z1), shade, Vector3.UP)
			var cy0 := maxf(height_at(x + 0.5, y + 0.5), min_y) + 0.045
			if is_road:
				var yellow := Color("f4d35e")
				for arm in [[arm_n, 0.0, -1.0], [arm_s, 0.0, 1.0], [arm_w, -1.0, 0.0], [arm_e, 1.0, 0.0]]:
					if not arm[0]:
						continue
					var dx: float = arm[1]
					var dz: float = arm[2]
					var a := Vector3(x + 0.5 + dx * 0.12, 0, y + 0.5 + dz * 0.12)
					var bb := Vector3(x + 0.5 + dx * 0.38, 0, y + 0.5 + dz * 0.38)
					a.y = maxf(height_at(a.x, a.z), min_y) + 0.04
					bb.y = maxf(height_at(bb.x, bb.z), min_y) + 0.04
					var side := Vector3(dz, 0, dx) * 0.02
					m.quad(a - side, a + side, bb + side, bb - side, yellow, Vector3.UP)
				if water:
					for sx in [-1.0, 1.0]:
						if arm_n or arm_s:
							m.box(Vector3(x + 0.5 + sx * 0.4, cy0 + 0.04, y + 0.5), Vector3(0.05, 0.14, 1.0), Color("d7dbe0"))
						else:
							m.box(Vector3(x + 0.5, cy0 + 0.04, y + 0.5 + sx * 0.4), Vector3(1.0, 0.14, 0.05), Color("d7dbe0"))
			elif b == D.B.PARKING:
				m.quad(Vector3(x + 0.485, cy0, y + 0.12), Vector3(x + 0.515, cy0, y + 0.12),
					Vector3(x + 0.515, cy0, y + 0.88), Vector3(x + 0.485, cy0, y + 0.88), Color(1, 1, 1), Vector3.UP)
				m.quad(Vector3(x + 0.0, cy0, y + 0.12), Vector3(x + 0.02, cy0, y + 0.12),
					Vector3(x + 0.02, cy0, y + 0.88), Vector3(x + 0.0, cy0, y + 0.88), Color(1, 1, 1), Vector3.UP)
			elif b == D.B.TRAIL and water:
				for sx in [-1.0, 1.0]:
					m.box(Vector3(x + 0.5 + sx * 0.3, DECK * 0.3, y + 0.5 + sx * 0.3), Vector3(0.05, DECK + 0.3, 0.05), Color("7d5230"))
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
	var bloom := [Color("fffbe6"), Color("ffd84d"), Color("f79ac0"), Color("b28be0")]
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
				var spots := [[0.3 + h * 0.4, 0.3 + h2 * 0.4, 0.95 + h2 * 0.45]]
				if t == D.T.FOREST and h2 < 0.6:
					spots = [[0.22 + h * 0.2, 0.25 + h2 * 0.25, 0.8 + h * 0.3], [0.68 + h2 * 0.2, 0.7 + h * 0.2, 0.95 + h2 * 0.4]]
				for k in spots.size():
					var sp: Array = spots[k]
					var hh := D.hash2(x, y, 8 + k)
					var xf := _xf(x + sp[0], y + sp[1], sp[2], hh * TAU, 0.02)
					trunks.append(xf)
					trunk_c.append(Color.WHITE)
					if kind == 2:
						conifers.append(xf)
						var cc := Color("2f7d57").lerp(Color("47a06f"), hh)
						if season == 3:
							cc = cc.lerp(Color("eef5f8"), 0.45)
						con_c.append(cc)
					else:
						leaves.append(xf)
						var lc: Array = Art.leaf_colors(season, hh)
						var col: Color = lc[1]
						if season == 0 and hh < 0.2:
							leaf_c.append(Color("f9a8c9"))
						else:
							leaf_c.append(col.lerp(lc[0], D.hash2(x, y, 12 + k) * 0.6))
			elif t == D.T.ROCK and h < 0.4:
				rocks.append(_xf(x + 0.2 + h2 * 0.6, y + 0.2 + h * 1.2, 0.7 + h2 * 1.1, h * TAU, 0.02))
				rock_c.append(Color.WHITE.darkened(h2 * 0.15))
			elif t == D.T.MEADOW and season != 3:
				for k in 2:
					flowers.append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.5 + h * 0.5, 0.0))
					flower_c.append(bloom[int(D.hash2(x, y, 40 + k) * 4.0) % 4])
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
			xs.append(Transform3D(Basis(Vector3.UP, k * 1.3), Vector3(px, surface_at(px, pz) + 0.02, pz)))
			cs.append(palette[(k + x) % 4])
	_fill("litter", xs, cs)
	var land: Array = []
	var land_c: Array = []
	var wet: Array = []
	var wet_c: Array = []
	for i: int in world.invasive_tiles.keys():
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


func _sync_structures() -> void:
	for id in _struct_nodes.keys():
		if not world.structures.has(id):
			_struct_nodes[id].queue_free()
			_struct_nodes.erase(id)
	for id in world.structures:
		if _struct_nodes.has(id):
			continue
		var s: Dictionary = world.structures[id]
		var st: Vector2i = s.tile
		var sz: Vector2i = s.size
		var mi := MeshInstance3D.new()
		mi.mesh = Models.structure(s.kind)
		mi.material_override = mat
		var top := -9.0
		for dy in sz.y + 1:
			for dx in sz.x + 1:
				top = maxf(top, corner(st.x + dx, st.y + dy))
		var center := Vector3(st.x + sz.x * 0.5, 0, st.y + sz.y * 0.5)
		center.y = top if sz.x > 1 else maxf(height_at(center.x, center.z), 0.03) + 0.02
		if s.kind == D.B.GATE:
			center.y = surface_at(center.x, center.z) + 0.02
			var ew := _b(st.x - 1, st.y) in [D.B.ROAD, D.B.PARKING] or _b(st.x + 1, st.y) in [D.B.ROAD, D.B.PARKING]
			var ns := _b(st.x, st.y - 1) in [D.B.ROAD, D.B.PARKING] or _b(st.x, st.y + 1) in [D.B.ROAD, D.B.PARKING]
			if ew and not ns:
				mi.rotation.y = PI * 0.5
		mi.position = center
		add_child(mi)
		_struct_nodes[id] = mi


func _build_landmarks() -> void:
	for lm in world.landmarks:
		var t: Vector2i = lm.tile
		var pos := Vector3(t.x + 0.5, maxf(height_at(t.x + 0.5, t.y + 0.5), 0.0), t.y + 0.5)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.landmark(lm.kind)
		mi.material_override = mat
		mi.position = pos
		if lm.kind == "summit":
			mi.position.y = maxf(maxf(corner(t.x, t.y), corner(t.x + 1, t.y)), maxf(corner(t.x, t.y + 1), corner(t.x + 1, t.y + 1))) - 0.1
		add_child(mi)
		var label := Label3D.new()
		label.text = lm.name
		label.font = font
		label.font_size = 56
		label.outline_size = 16
		label.pixel_size = 0.011
		label.modulate = Color("fff8dc")
		label.outline_modulate = Color(0.1, 0.18, 0.13, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 5
		var lift := 1.4
		match lm.kind:
			"grove": lift = 3.2
			"summit": lift = mi.position.y - pos.y + 1.6
			"lake": lift = 0.8
		label.position = pos + Vector3(0, lift, 0)
		add_child(label)
