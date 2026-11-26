class_name Terrain3D
extends Node3D
## The 3D landscape. A smooth terrain mesh shaded by shaders/terrain.gdshader
## (biome colours, rock, snow, and trails/roads blended into the ground from
## a painted mask), water, biome vegetation, buildings, landmarks, and
## scenery that carries on to the horizon.
## One tile = 1 world unit (about 8 m). Tile (x, y) spans x..x+1 on X, y..y+1 on Z.

const CH := 16 # tiles per terrain chunk
const SUB := 3 # terrain vertices per tile edge
const REG := 10 # tiles per vegetation region
const PX := 12 # path-mask pixels per tile
const DECK := 0.16 # height of bridges and boardwalks above the water
const BORDER := 90 # tiles of scenery beyond the playable map
const OSTEP := 1 # grid spacing of that scenery
const GW := World.W * SUB + 1
const GH := World.H * SUB + 1
const LIT := [D.B.VISITOR_CENTER, D.B.RANGER, D.B.RESEARCH, D.B.SNACK, D.B.CAMP, D.B.GATE, D.B.RESTROOM]
const NO_FOUNDATION := [D.B.CALLBOX, D.B.HELIPAD, D.B.BIN, D.B.SIGN, D.B.PICNIC, D.B.TRAILHEAD, D.B.CRAG, D.B.GATE, D.B.CAMP]
# footprint width (in tiles) that supplied building models are scaled to
const EXT_WIDTH := {D.B.PICNIC: 0.42, D.B.TRAILHEAD: 0.36, D.B.HIDE: 0.62, D.B.RESTROOM: 0.8, D.B.SNACK: 0.72, D.B.GATE: 1.35,
	D.B.OVERLOOK: 0.92, D.B.VISITOR_CENTER: 1.85, D.B.RANGER: 1.5, D.B.RESEARCH: 1.6, D.B.CAMP: 1.85, D.B.BIN: 0.3, D.B.SIGN: 0.2, D.B.CRAG: 0.9}
const VEG := ["trunk", "leaf", "conifer", "conifer2", "rock", "rock2", "rock_red", "flower", "bush", "reed", "grass"]
const HD := {"conifer": "conifer_hd", "conifer2": "conifer2_hd", "leaf": "leaf_hd"}

var world: World
var season := 0
var climate := 0.0
var font: Font
var mat: StandardMaterial3D # shared by models (vertex-coloured)
var ground: ShaderMaterial
var win_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var hf := PackedFloat32Array() # fine height field, GW x GH
var detail := FastNoiseLite.new()
var tile_img: Image
var tile_tex: ImageTexture
var path_img: Image
var path_tex: ImageTexture
var fire_light: OmniLight3D
var entrance_marker: Node3D

var _deck: MeshInstance3D
var _deck_dirty := true
var _mask_dirty := {}
var _tile_dirty := false
var _veg_dirty := {}
var _small_dirty := true
var _struct_dirty := true
var _seen_build := PackedByteArray()
var _seen_trees := PackedByteArray()
var _seen_burn := PackedByteArray()
var _regions := {} # Vector2i -> {name: MultiMesh}
var _mm := {}
var _meshes := {}
var _external := {}
var _tree_nodes: Array[MultiMeshInstance3D] = []
var _veg: Array = []
var _hd_nodes: Array[MultiMeshInstance3D] = []
var _card_nodes: Array[MultiMeshInstance3D] = []
var _shade_nodes: Array[MultiMeshInstance3D] = []
var _tree_detail := 0.0
var _grass_nodes: Array[MultiMeshInstance3D] = []
var grass_mat: ShaderMaterial
var water_mat: ShaderMaterial
var _region_nodes := {}
var _ghosted := false
var _cards := {}
var _struct_nodes := {}
var _chunks := {}
var _th := PackedFloat32Array()
var _chs := PackedFloat32Array()
var _tmp := PackedFloat32Array()
var _lakes: MeshInstance3D
var falls_mat: ShaderMaterial
var _lights: Array[OmniLight3D] = []
var _orchid_tiles: Array[Vector2i] = []
var _outer_trees: Array = []
var _ocols := 0
var _ohs := PackedFloat32Array()
var _night := 0.0
var _t := 0.0


func setup(w: World, f: Font) -> void:
	world = w
	font = f
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# trees between the camera and what you are looking at fade away
	tree_mat = mat.duplicate()
	tree_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	tree_mat.distance_fade_min_distance = 5.0
	tree_mat.distance_fade_max_distance = 9.0
	win_mat = StandardMaterial3D.new()
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_mat.albedo_color = Color(0.45, 0.6, 0.72)
	detail.seed = int(world.rng.seed) + 5
	detail.frequency = 0.16
	detail.fractal_octaves = 3
	_compute_heights()

	# ground material
	tile_img = Image.create(World.W, World.H, false, Image.FORMAT_RGBA8)
	_recolor_tiles()
	tile_tex = ImageTexture.create_from_image(tile_img)
	path_img = Image.create(World.W * PX, World.H * PX, false, Image.FORMAT_RGB8)
	path_img.fill(Color.BLACK)
	path_tex = ImageTexture.create_from_image(path_img)
	var nz := NoiseTexture2D.new()
	nz.width = 512
	nz.height = 512
	nz.seamless = true
	nz.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 5
	nz.noise = fn
	ground = ShaderMaterial.new()
	ground.shader = load("res://shaders/terrain.gdshader")
	ground.set_shader_parameter("tile_tex", tile_tex)
	ground.set_shader_parameter("path_tex", path_tex)
	ground.set_shader_parameter("noise_tex", nz)
	var bump := NoiseTexture2D.new()
	bump.width = 512
	bump.height = 512
	bump.seamless = true
	bump.generate_mipmaps = true
	bump.as_normal_map = true
	bump.bump_strength = 7.0
	var bn := FastNoiseLite.new()
	bn.seed = 9
	bn.frequency = 0.03
	bn.fractal_octaves = 5
	bump.noise = bn
	ground.set_shader_parameter("bump_tex", bump)
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass.gdshader")
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("noise_tex", nz)
	falls_mat = ShaderMaterial.new()
	falls_mat.shader = load("res://shaders/falls.gdshader")
	falls_mat.set_shader_parameter("noise_tex", nz)
	ground.set_shader_parameter("map_size", Vector2(World.W, World.H))

	for cy in range(0, ceili(World.H / float(CH))):
		for cx in range(0, ceili(World.W / float(CH))):
			var mi := MeshInstance3D.new()
			mi.mesh = _terrain_mesh(cx, cy)
			mi.material_override = ground
			add_child(mi)
			_chunks[Vector2i(cx, cy)] = mi
	var outer := MeshInstance3D.new()
	outer.mesh = _outskirts_mesh()
	outer.material_override = ground
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer)
	_build_highway()

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(World.W + BORDER * 2, World.H + BORDER * 2)
	water.mesh = plane
	water.position = Vector3(World.W * 0.5, 0.0, World.H * 0.5)
	var wm := water_mat
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = -0.05
	add_child(water)
	var lakes := MeshInstance3D.new()
	lakes.mesh = _water_mesh()
	lakes.material_override = wm
	lakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lakes)

	_deck = MeshInstance3D.new()
	_deck.material_override = mat
	add_child(_deck)

	_meshes = {"trunk": Models.trunk(), "leaf": _ext("broadleaf", Models.leaf(), 1.35), "conifer": _ext("conifer", Models.conifer(), 1.95),
		"conifer2": _ext("conifer2", Models.conifer(), 2.1), "conifer_far": Models.conifer(),
		"rock": _ext("rock", Models.rock(), 0.3), "rock2": _ext("rock2", Models.rock(), 0.3), "rock_red": _ext("rock_red", Models.rock(), 0.3), "flower": Models.flower(), "bush": _ext("bush", Models.bush(), 0.2), "reed": Models.reed(), "grass": Models.grass_tuft(),
		"flame": Models.flame(), "litter": Models.litter(), "thistle": Models.thistle(), "milfoil": Models.milfoil(), "orchid": Models.orchid()}
	# baked cut-out trees (models/impostors) take priority: they look detailed and cost almost nothing
	# one or two canopy layers are enough to close the tree from above without looking stacked
	var cone := [[0.28, 0.92], [0.58, 0.55]]
	var crown := [[0.72, 0.96]]
	for pair in [["conifer", "spruce", 2.0, cone], ["conifer2", "pine", 2.15, crown], ["leaf", "aspen", 1.5, crown], ["conifer_far", "spruce", 2.0, cone]]:
		var card := Models.card_tree(pair[1], pair[2], pair[3])
		if card != null:
			_meshes[pair[0]] = card
			_cards[card] = true
	# full 3D trees stand in for the cut-outs close to the camera
	_veg = VEG.duplicate()
	for pair in [["conifer", "trees/spruce", 2.0], ["conifer2", "trees/pine", 2.15], ["leaf", "trees/aspen", 1.5]]:
		var hd := Models.external(pair[1])
		if hd != null and _cards.has(_meshes[pair[0]]):
			_external[hd] = Models.fit(hd, pair[2])
			_meshes[HD[pair[0]]] = hd
			_veg.append(HD[pair[0]])
	for key in ["flame", "litter", "thistle", "milfoil", "orchid", "outer"]:
		_mm[key] = _new_mm("conifer_far" if key == "outer" else key, self)
	for ry in range(0, ceili(World.H / float(REG))):
		for rx in range(0, ceili(World.W / float(REG))):
			var holder := Node3D.new()
			add_child(holder)
			var mms := {}
			for key in _veg:
				mms[key] = _new_mm(key, holder)
			_regions[Vector2i(rx, ry)] = mms
			var trees_here: Array = []
			for c in holder.get_children():
				if c in _tree_nodes:
					trees_here.append(c)
			_region_nodes[Vector2i(rx, ry)] = trees_here
			_veg_dirty[Vector2i(rx, ry)] = true

	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.5, 0.15)
	fire_light.light_energy = 8.0
	fire_light.omni_range = 22.0
	fire_light.visible = false
	add_child(fire_light)
	for i in world.rare.size():
		if world.rare[i] > 0.0:
			_orchid_tiles.append(Vector2i(i % World.W, i / World.W))
	_seen_build = world.build.duplicate()
	_seen_trees = world.trees.duplicate()
	_seen_burn = world.burned.duplicate()
	for i in world.build.size():
		if world.build[i] != D.B.NONE:
			_mask_dirty[i] = true
	_build_landmarks()
	_build_entrance_marker()
	world.changed.connect(_on_changed)
	world.reshaped.connect(_on_reshaped)
	# build everything up front so the first frame is complete
	while not _veg_dirty.is_empty():
		_process(0.0)


## Uses models/<name>.glb instead of the built-in mesh when one is provided.
func _ext(name: String, fallback: Mesh, height: float) -> Mesh:
	var m := Models.external(name)
	if m != null:
		_external[m] = Models.fit(m, height)
		return m
	return fallback


func _new_mm(key: String, parent: Node) -> MultiMesh:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _meshes[key]
	mmi.multimesh = mm
	if not _external.has(mm.mesh) and not _cards.has(mm.mesh):
		mmi.material_override = tree_mat if key in ["trunk", "leaf", "conifer", "conifer2", "conifer_far"] else mat
	if key in ["flower", "litter", "milfoil", "flame", "reed"]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if key == "flame":
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fm.albedo_color = Color(3.0, 1.3, 0.35)
		mmi.material_override = fm
	if key == "grass":
		mmi.material_override = grass_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 44.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_grass_nodes.append(mmi)
	if key in ["trunk", "leaf", "conifer", "conifer2"]:
		_tree_nodes.append(mmi)
		if _cards.has(mm.mesh) and _meshes.has(HD.get(key, "")):
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_card_nodes.append(mmi)
			# near the camera the detailed trees are drawn, but their shadows still
			# come from the cheap cut-outs: shadow passes would redraw every triangle
			var shade := MultiMeshInstance3D.new()
			shade.multimesh = mm
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shade.visible = false
			parent.add_child(shade)
			_shade_nodes.append(shade)
	elif key.ends_with("_hd"):
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.visible = false
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hd_nodes.append(mmi)
	elif key in ["flower", "bush", "reed", "rock", "rock2", "rock_red"]:
		# small ground cover is only worth drawing up close
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 55.0 if not key.begins_with("rock") else 85.0
		mmi.visibility_range_end_margin = 12.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
	return mm


## Within this distance of the camera trees are drawn as full 3D models;
## beyond it they are flat cut-outs. Zero turns the 3D trees off.
func set_tree_detail(dist: float) -> void:
	_tree_detail = dist
	for n in _hd_nodes:
		n.visible = dist > 0.0
		n.visibility_range_end = dist
		n.visibility_range_end_margin = 5.0
	for n in _shade_nodes:
		n.visible = dist > 0.0 and not _ghosted
		n.visibility_range_end = dist + 5.0
	for n in _card_nodes:
		n.visibility_range_begin = dist
		n.visibility_range_begin_margin = 5.0 if dist > 0.0 else 0.0


## Developer aid: triangles per kind of scenery over the whole map.
func print_budget() -> void:
	var tot := {}
	for key in _regions:
		for name in _regions[key]:
			var mm: MultiMesh = _regions[key][name]
			var tris := 0
			for s in mm.mesh.get_surface_count():
				var arr := mm.mesh.surface_get_arrays(s)
				tris += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
			var e: Array = tot.get(name, [0, 0, tris])
			e[0] += mm.instance_count
			e[1] += mm.instance_count * tris
			tot[name] = e
	for name in tot:
		print("budget %-12s instances %7d  tris each %5d  total %6dk" % [name, tot[name][0], tot[name][2], tot[name][1] / 1000])


## Grass blades are the first thing to drop on slower machines.
func set_grass_enabled(on: bool) -> void:
	for n in _grass_nodes:
		n.visible = on


## Makes the forest see-through (while building) so the ground is visible.
func set_trees_ghosted(on: bool) -> void:
	if on == _ghosted:
		return
	_ghosted = on
	for n in _hd_nodes:
		n.transparency = 0.82 if on else 0.0
	for n in _shade_nodes:
		n.visible = _tree_detail > 0.0 and not on
	for n in _tree_nodes:
		n.transparency = 0.82 if on else 0.0
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Level of detail: only forest near the view casts shadows.
func update_lod(focus: Vector3, shadow_range: float) -> void:
	if _ghosted:
		return
	for key: Vector2i in _region_nodes:
		var c := Vector3((key.x + 0.5) * REG, focus.y, (key.y + 0.5) * REG)
		var near: bool = c.distance_to(focus) < shadow_range + REG
		for n: MultiMeshInstance3D in _region_nodes[key]:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## True if the tile touches a road, parking lot or building (trees keep back from these).
func _beside_development(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var b := _b(x + dx, y + dy)
			if b != D.B.NONE and b != D.B.TRAIL:
				return true
	return false


# ------------------------------------------------------------------- heights

static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


func _compute_heights(x0: int = 0, y0: int = 0, x1: int = World.W - 1, y1: int = World.H - 1) -> void:
	var n := World.W * World.H
	var cw := World.W + 1
	if _th.size() != n:
		_th.resize(n)
		_chs.resize(cw * (World.H + 1))
		_tmp.resize(GW * (World.H + 1))
		hf.resize(GW * GH)
	x0 = clampi(x0, 0, World.W - 1)
	y0 = clampi(y0, 0, World.H - 1)
	x1 = clampi(x1, 0, World.W - 1)
	y1 = clampi(y1, 0, World.H - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * World.W + x
			var h := world.height[i]
			var wl := world.wlevel[i]
			if wl != World.NO_WATER:
				h = minf(h, wl - 0.3)
			_th[i] = h
	# tile corners
	for y in range(y0, y1 + 2):
		for x in range(x0, x1 + 2):
			var xa := clampi(x - 1, 0, World.W - 1)
			var xb := clampi(x, 0, World.W - 1)
			var ya := clampi(y - 1, 0, World.H - 1)
			var yb := clampi(y, 0, World.H - 1)
			_chs[y * cw + x] = (_th[ya * World.W + xa] + _th[ya * World.W + xb] + _th[yb * World.W + xa] + _th[yb * World.W + xb]) * 0.25
	# smooth interpolation: along X, then along Z
	var gxa := maxi(0, (x0 - 2) * SUB)
	var gxb := mini(GW - 1, (x1 + 3) * SUB)
	for y in range(y0, y1 + 2):
		var row := y * cw
		for gx in range(gxa, gxb + 1):
			var i := mini(gx / SUB, World.W - 1)
			var t := float(gx - i * SUB) / SUB
			_tmp[y * GW + gx] = _cr(_chs[row + maxi(i - 1, 0)], _chs[row + i], _chs[row + i + 1], _chs[row + mini(i + 2, World.W)], t)
	var inv := 1.0 / SUB
	for gy in range(maxi(0, (y0 - 2) * SUB), mini(GH - 1, (y1 + 3) * SUB) + 1):
		var j := mini(gy / SUB, World.H - 1)
		var t := float(gy - j * SUB) / SUB
		var r0 := maxi(j - 1, 0) * GW
		var r1 := j * GW
		var r2 := (j + 1) * GW
		var r3 := mini(j + 2, World.H) * GW
		for gx in range(gxa, gxb + 1):
			var h := _cr(_tmp[r0 + gx], _tmp[r1 + gx], _tmp[r2 + gx], _tmp[r3 + gx], t)
			if h > 9.0:
				# craggy detail on high ground
				h += detail.get_noise_2d(gx * inv * 2.2, gy * inv * 2.2) * clampf((h - 9.0) * 0.12, 0.0, 1.0)
			hf[gy * GW + gx] = h


## Earthworks: re-shape just the ground that moved and whatever stands on it.
func _on_reshaped(rect: Rect2i) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x - 1
	var y1 := rect.end.y - 1
	_compute_heights(x0, y0, x1, y1)
	for cy in range(maxi(0, y0 - 3) / CH, mini(World.H - 1, y1 + 3) / CH + 1):
		for cx in range(maxi(0, x0 - 3) / CH, mini(World.W - 1, x1 + 3) / CH + 1):
			if _chunks.has(Vector2i(cx, cy)):
				_chunks[Vector2i(cx, cy)].mesh = _terrain_mesh(cx, cy)
	for ry in range(maxi(0, y0 - 3) / REG, mini(World.H - 1, y1 + 3) / REG + 1):
		for rx in range(maxi(0, x0 - 3) / REG, mini(World.W - 1, x1 + 3) / REG + 1):
			_veg_dirty[Vector2i(rx, ry)] = true
	# buildings on the moved ground are set down again at the new height
	for id in _struct_nodes.keys():
		if world.structures.has(id):
			var s: Dictionary = world.structures[id]
			if Rect2i(x0 - 3, y0 - 3, x1 - x0 + 7, y1 - y0 + 7).has_point(s.tile):
				var old: Node3D = _struct_nodes[id]
				for c in old.get_children():
					if c is OmniLight3D:
						_lights.erase(c)
				old.queue_free()
				_struct_nodes.erase(id)
	_struct_dirty = true
	_deck_dirty = true
	_small_dirty = true
	_tile_dirty = true


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


## Water surface height at a point, or World.NO_WATER on dry land.
func water_at(x: float, z: float) -> float:
	return world.wlevel[clampi(int(z), 0, World.H - 1) * World.W + clampi(int(x), 0, World.W - 1)]


## Height of whatever you would stand on: terrain, or a bridge deck.
func surface_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var t := Vector2i(clampi(int(x), 0, World.W - 1), clampi(int(z), 0, World.H - 1))
	var i := World.ti(t)
	if world.build[i] != D.B.NONE and world.wlevel[i] != World.NO_WATER:
		return maxf(h, world.wlevel[i] + DECK)
	return h


## Terrain or water surface, whichever is on top (what the mouse lands on).
func top_at(x: float, z: float) -> float:
	return maxf(height_at(x, z), water_at(x, z))


## Lakes and rivers: each body of water sits at its own height, and rivers
## step down the valleys.
func _water_mesh() -> ArrayMesh:
	var m := MeshBuilder.new()
	var col := Color(1, 1, 1)
	for y in World.H:
		for x in World.W:
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if World.inb(x + dx, y + dy) and world.wlevel[World.idx(x + dx, y + dy)] != World.NO_WATER:
						near = true
			if not near:
				continue
			var own := world.wlevel[World.idx(x, y)]
			var lv: Array[float] = []
			var low := 1e9
			for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var sum := 0.0
				var cnt := 0
				for dy in [-1, 0]:
					for dx in [-1, 0]:
						var tx: int = x + c.x + dx
						var ty: int = y + c.y + dy
						if World.inb(tx, ty) and world.wlevel[World.idx(tx, ty)] != World.NO_WATER:
							sum += world.wlevel[World.idx(tx, ty)]
							cnt += 1
				var v := sum / cnt if cnt > 0 else NAN
				lv.append(v)
				if cnt > 0:
					low = minf(low, v)
			for k in 4:
				if is_nan(lv[k]):
					lv[k] = low
			# no water sheets hanging over a drop-off beside a lake or stream
			if own == World.NO_WATER and world.height[World.idx(x, y)] < low - 0.5:
				continue
			m.quad(Vector3(x, lv[0], y), Vector3(x + 1, lv[1], y), Vector3(x + 1, lv[2], y + 1), Vector3(x, lv[3], y + 1), col, Vector3.UP)
	return m.commit()


## Converts a simulation position (pixels) to a 3D point on the ground.
func ground_pos(p: Vector2) -> Vector3:
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
				_tile_dirty = true
			if world.build[i] == D.B.TRAIL:
				_mask_dirty[i] = true
			if _seen_build[i] != world.build[i] or _seen_trees[i] != world.trees[i]:
				structural = true
				_tile_dirty = true
				_seen_build[i] = world.build[i]
				_seen_trees[i] = world.trees[i]
				for oy in [-1, 0, 1]:
					for ox in [-1, 0, 1]:
						var rk := Vector2i(clampi(x + ox, 0, World.W - 1) / REG, clampi(y + oy, 0, World.H - 1) / REG)
						_veg_dirty[rk] = true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if World.inb(x + dx, y + dy):
							_mask_dirty[World.idx(x + dx, y + dy)] = true
	if structural:
		_struct_dirty = true
		_deck_dirty = true


func set_season(s: int) -> void:
	if s == season:
		return
	season = s
	for k in _regions:
		_veg_dirty[k] = true


## 0 = full daylight, 1 = night. Lights the windows and lamps.
func set_night(f: float) -> void:
	if absf(f - _night) < 0.01:
		return
	_night = f
	win_mat.albedo_color = Color(0.45, 0.6, 0.72).lerp(Color(3.2, 2.2, 1.0), f)
	for l in _lights:
		l.light_energy = f * 2.6
		l.visible = f > 0.03


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	ground.set_shader_parameter("snowline", (4.0 if season == 3 else (17.0 if season == 0 else 22.0)) + climate * 4.0)
	ground.set_shader_parameter("snow_all", 1.0 if season == 3 else 0.0)
	ground.set_shader_parameter("autumn", 1.0 if season == 2 else 0.0)
	grass_mat.set_shader_parameter("tint", [Vector3(1, 1, 1), Vector3(1.05, 1.0, 0.85), Vector3(1.4, 1.05, 0.5), Vector3(1.1, 1.0, 0.8)][season])
	grass_mat.set_shader_parameter("snow", 0.9 if season == 3 else 0.0)
	if entrance_marker != null and entrance_marker.visible:
		entrance_marker.get_child(0).scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.12)
		entrance_marker.visible = world.count_kind(D.B.GATE) == 0
	if not _mask_dirty.is_empty():
		for i: int in _mask_dirty.keys():
			_paint_tile(i % World.W, i / World.W)
		_mask_dirty.clear()
		path_tex.update(path_img)
	if _tile_dirty:
		_tile_dirty = false
		_recolor_tiles()
		tile_tex.update(tile_img)
	var budget := 6
	for k in _veg_dirty.keys():
		_rebuild_region(k)
		_veg_dirty.erase(k)
		budget -= 1
		if budget <= 0:
			break
	if _deck_dirty:
		_deck_dirty = false
		_deck.mesh = _deck_mesh()
	if _small_dirty:
		_small_dirty = false
		_rebuild_small()
	if _struct_dirty:
		_struct_dirty = false
		_sync_structures()


# ------------------------------------------------------------------- terrain

## Base ground colour of a tile. Alpha marks red-rock desert for the shader.
func tile_color(i: int) -> Color:
	var bio := world.biome[i]
	var t := world.terrain[i]
	var c := Color("5f8f44")
	match t:
		D.T.DEEP: c = Color("23485c")
		D.T.WATER: c = Color("5d7f7a")
		D.T.SAND: c = Color("a8966e")
		D.T.GRASS: c = Color("5a6e3a")
		D.T.MEADOW: c = Color("6f7d42")
		D.T.FOREST: c = Color("34412a")
		D.T.ROCK: c = Color("6f6a62")
		D.T.PEAK: c = Color("615e60")
	match bio:
		D.BIOME.DESERT:
			if t == D.T.SAND: c = Color("b08052")
			elif t == D.T.GRASS: c = Color("85805a")
			elif t == D.T.ROCK: c = Color("9a5436")
			c.a = 0.0 # flagged below
		D.BIOME.VALLEY:
			if t == D.T.GRASS: c = Color("71783f")
			elif t == D.T.MEADOW: c = Color("7d8245")
		D.BIOME.WETLAND:
			if t == D.T.GRASS: c = Color("46602f")
			elif t == D.T.SAND: c = Color("5f5a40")
		D.BIOME.ALPINE:
			if t == D.T.MEADOW or t == D.T.GRASS: c = Color("6b7248")
	if world.burned[i] > 0:
		c = Color("2c2622")
	c.a = 1.0 if bio == D.BIOME.DESERT else 0.0
	return c


func _recolor_tiles() -> void:
	for y in World.H:
		for x in World.W:
			tile_img.set_pixel(x, y, tile_color(y * World.W + x))


func _terrain_mesh(cx: int, cy: int) -> ArrayMesh:
	var gx0 := cx * CH * SUB
	var gy0 := cy * CH * SUB
	var gx1 := mini(World.W, (cx + 1) * CH) * SUB
	var gy1 := mini(World.H, (cy + 1) * CH) * SUB
	var cols := gx1 - gx0 + 1
	var rows := gy1 - gy0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(cols * rows)
	norms.resize(cols * rows)
	idx.resize((cols - 1) * (rows - 1) * 6)
	var step := 1.0 / SUB
	var k := 0
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			verts[k] = Vector3(gx * step, hf[gy * GW + gx], gy * step)
			norms[k] = Vector3(_h(gx - 1, gy) - _h(gx + 1, gy), 2.0 * step, _h(gx, gy - 1) - _h(gx, gy + 1)).normalized()
			k += 1
	k = 0
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + cols + 1
			idx[k + 3] = a; idx[k + 4] = a + cols + 1; idx[k + 5] = a + cols
			k += 6
	return _commit(verts, norms, idx)


func _commit(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
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
		return inner - 0.2
	# beyond the edge the land follows the same ranges and valleys as the park
	var g := world.gen.relief(x, y)
	if g > 9.0:
		g += detail.get_noise_2d(x * 2.2, y * 2.2) * clampf((g - 9.0) * 0.12, 0.0, 1.0)
	if y > World.H:
		g = lerpf(g, clampf(g, 1.0, 5.0), 0.7) # gentler country toward the highway
	return maxf(lerpf(inner, g, smoothstep(0.0, 14.0, d)), 0.3)


func _outskirts_mesh() -> ArrayMesh:
	var step := OSTEP
	var x0 := -BORDER
	var y0 := -BORDER
	var cols := (World.W + BORDER * 2) / step + 1
	var rows := (World.H + BORDER * 2) / step + 1
	_ocols = cols
	_ohs.resize(cols * rows)
	for r in rows:
		for c in cols:
			_ohs[r * cols + c] = _outer_height(x0 + c * step, y0 + r * step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(cols * rows)
	norms.resize(cols * rows)
	for r in rows:
		for c in cols:
			var k := r * cols + c
			var h := _ohs[k]
			var nrm := Vector3(_ohs[r * cols + maxi(c - 1, 0)] - _ohs[r * cols + mini(c + 1, cols - 1)], 2.0 * step,
				_ohs[maxi(r - 1, 0) * cols + c] - _ohs[mini(r + 1, rows - 1) * cols + c]).normalized()
			var x := x0 + c * step
			var y := y0 + r * step
			verts[k] = Vector3(x, h, y)
			norms[k] = nrm
			var inside := x >= 0 and y >= 0 and x <= World.W and y <= World.H
			var jit := D.hash2(x, y, 4)
			var dist := maxf(maxf(-x, x - World.W), maxf(-y, y - World.H))
			var approach: bool = y > World.H - 4 and absf(x - world.entry.x) < 16.0 # keep the entrance open
			# forest beyond the boundary, in the same patchy pattern as inside
			var patch := detail.get_noise_2d(x * 0.5 + 300.0, y * 0.5) * 0.5 + 0.5
			if not inside and not approach and dist < 70.0 and h > 0.3 and h < 10.5 and nrm.y > 0.8 and jit < patch * 1.1 - 0.15:
				_outer_trees.append(Vector3(x + D.hash2(x, y, 9) * 1.0, 0, y + D.hash2(x, y, 19) * 1.0))
	for r in rows - 1:
		for c in cols - 1:
			var x := x0 + c * step
			var y := y0 + r * step
			if x >= step and y >= step and x < World.W - step and y < World.H - step:
				continue
			var a := r * cols + c
			idx.append(a); idx.append(a + 1); idx.append(a + cols + 1)
			idx.append(a); idx.append(a + cols + 1); idx.append(a + cols)
	return _commit(verts, norms, idx)


## Height of the outskirts mesh at a point (for the highway and far trees).
func outer_at(x: float, z: float) -> float:
	var fx := clampf((x + BORDER) / float(OSTEP), 0.0, _ocols - 1.001)
	var fz := clampf((z + BORDER) / float(OSTEP), 0.0, _ohs.size() / _ocols - 1.001)
	var gx := int(fx)
	var gz := int(fz)
	var u := fx - gx
	var v := fz - gz
	var i := gz * _ocols + gx
	var h00 := _ohs[i]
	var h10 := _ohs[i + 1]
	var h01 := _ohs[i + _ocols]
	var h11 := _ohs[i + _ocols + 1]
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v


## The state highway that passes the park, and the spur visitors arrive on.
func _build_highway() -> void:
	var m := MeshBuilder.new()
	var ex := world.entry.x + 0.5
	var hz := World.H + 7.0
	var road := Color("33353a")
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := Vector3.ZERO
	var first := true
	for k in range(-BORDER, World.W + BORDER, 1):
		var x := float(k)
		var z := hz + sin(x * 0.045) * 3.0
		var y := maxf(maxf(outer_at(x, z - 0.6), outer_at(x, z + 0.6)), 0.25) + 0.18
		var l := Vector3(x, y, z - 0.6)
		var r := Vector3(x, y, z + 0.6)
		var c := Vector3(x, y + 0.02, z)
		if not first:
			m.quad(prev_l, l, r, prev_r, road, Vector3.UP)
			m.quad(prev_l, l, l + Vector3(0, -1.5, -0.5), prev_l + Vector3(0, -1.5, -0.5), Color("5a5247"), Vector3.FORWARD)
			m.quad(prev_r, r, r + Vector3(0, -1.5, 0.5), prev_r + Vector3(0, -1.5, 0.5), Color("5a5247"), Vector3.BACK)
			if k % 2 == 0:
				m.quad(prev_c + Vector3(0, 0, -0.03), c + Vector3(0, 0, -0.03), c + Vector3(0, 0, 0.03), prev_c + Vector3(0, 0, 0.03), Color("d9bd55"), Vector3.UP)
		prev_l = l
		prev_r = r
		prev_c = c
		first = false
	# spur from the highway up to the park boundary
	var zj := hz + sin(ex * 0.045) * 3.0
	first = true
	for k in 16:
		var z := lerpf(zj, World.H - 0.02, k / 15.0)
		var y := maxf(outer_at(ex, z), 0.25) + 0.16
		if k == 15:
			y = height_at(ex, World.H - 0.02) + 0.05
		var l := Vector3(ex - 0.45, y, z)
		var r := Vector3(ex + 0.45, y, z)
		if not first:
			m.quad(prev_l, l, r, prev_r, road, Vector3.UP)
			m.quad(prev_l, l, l + Vector3(-0.5, -1.5, 0), prev_l + Vector3(-0.5, -1.5, 0), Color("5a5247"), Vector3.LEFT)
			m.quad(prev_r, r, r + Vector3(0.5, -1.5, 0), prev_r + Vector3(0.5, -1.5, 0), Color("5a5247"), Vector3.RIGHT)
		prev_l = l
		prev_r = r
		first = false
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	mi.material_override = mat
	add_child(mi)


func _build_entrance_marker() -> void:
	var e := world.entry
	var base := tile_center(e + Vector2i(0, -2))
	var post := MeshInstance3D.new()
	post.mesh = Models.entrance_sign()
	post.material_override = mat
	post.position = tile_center(e) + Vector3(1.1, 0, 0.2)
	add_child(post)
	entrance_marker = Node3D.new()
	entrance_marker.position = base
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 14.0
	cyl.radial_segments = 16
	beam.mesh = cyl
	beam.position = Vector3(0, 7.0, 0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.85, 0.3, 0.22)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entrance_marker.add_child(beam)
	var label := _label("Park road starts here", 20)
	label.position = Vector3(0, 4.2, 0)
	entrance_marker.add_child(label)
	add_child(entrance_marker)


func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.outline_size = 14
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.modulate = Color("fff8dc")
	label.outline_modulate = Color(0.06, 0.1, 0.08, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 5
	return label


# ---------------------------------------------------------------- path mask

func _b(x: int, y: int) -> int:
	if World.inb(x, y):
		return world.build[World.idx(x, y)]
	return D.B.ROAD if x == world.entry.x and y >= World.H else D.B.NONE


func _arms(x: int, y: int, road: bool) -> Array[Vector2]:
	var arms: Array[Vector2] = []
	for d in World.DIRS:
		var nb := _b(x + d.x, y + d.y)
		if (road and (nb == D.B.ROAD or nb == D.B.GATE or nb == D.B.PARKING)) or (not road and nb != D.B.NONE):
			arms.append(Vector2(d))
	return arms


## Points along the curved centre line(s) of a road or trail tile, in tile-local 0..1.
func _centerline(arms: Array[Vector2]) -> Array:
	var lines: Array = []
	var c := Vector2(0.5, 0.5)
	if arms.size() == 2:
		var pts := PackedVector2Array()
		for s in 9:
			var t := s / 8.0
			var a := c + arms[0] * 0.5
			var b := c + arms[1] * 0.5
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		lines.append(pts)
	else:
		for arm in arms:
			lines.append(PackedVector2Array([c + arm * 0.5, c]))
		if arms.is_empty():
			lines.append(PackedVector2Array([c, c]))
	return lines


## Paints one tile of the path mask: R = trail, G = asphalt, B = worn ground.
func _paint_tile(x: int, y: int) -> void:
	var i := World.idx(x, y)
	var b := world.build[i]
	var px0 := x * PX
	var py0 := y * PX
	if b == D.B.NONE or world.is_water(world.terrain[i]):
		path_img.fill_rect(Rect2i(px0, py0, PX, PX), Color.BLACK)
		return
	if b == D.B.PARKING:
		path_img.fill_rect(Rect2i(px0, py0, PX, PX), Color(0, 1, 0))
		return
	var road := b == D.B.ROAD or b == D.B.GATE
	if not road and b != D.B.TRAIL:
		# worn dirt around a building
		for py in PX:
			for px in PX:
				var d := Vector2((px + 0.5) / PX - 0.5, (py + 0.5) / PX - 0.5).length()
				path_img.set_pixel(px0 + px, py0 + py, Color(0, 0, clampf(1.25 - d * 2.1, 0.0, 1.0)))
		return
	var lines := _centerline(_arms(x, y, road))
	var grade: int = world.trail_grade[i]
	var half: float = 0.36 if road else [0.05, 0.11, 0.17][grade]
	var soft: float = 0.11 if road else [0.16, 0.13, 0.07][grade]
	for py in PX:
		for px in PX:
			var p := Vector2((px + 0.5) / PX, (py + 0.5) / PX)
			var best := 9.0
			for pts: PackedVector2Array in lines:
				for k in pts.size() - 1:
					var a := pts[k]
					var ab := pts[k + 1] - a
					var t := 0.0
					var len2 := ab.length_squared()
					if len2 > 0.000001:
						t = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
					best = minf(best, p.distance_to(a + ab * t))
			var v := clampf(1.0 - (best - half) / soft, 0.0, 1.0)
			path_img.set_pixel(px0 + px, py0 + py, Color(0, v, 0) if road else Color(v * (0.7 if grade == 0 else 1.0), 0, 0))


## Mesh parts of paths: bridges and boardwalks over water, and painted lines.
func _deck_mesh() -> ArrayMesh:
	var m := MeshBuilder.new()
	for i in world.build.size():
		var b := world.build[i]
		if b != D.B.ROAD and b != D.B.GATE and b != D.B.TRAIL and b != D.B.PARKING:
			continue
		var x := i % World.W
		var y := i / World.W
		var water := world.wlevel[i] != World.NO_WATER
		var min_y := world.wlevel[i] + DECK if water else -99.0
		if b == D.B.PARKING:
			for lx in [0.02, 0.5]:
				var a := Vector3(x + lx, height_at(x + lx, y + 0.12) + 0.03, y + 0.12)
				var bb := Vector3(x + lx, height_at(x + lx, y + 0.88) + 0.03, y + 0.88)
				m.quad(a - Vector3(0.012, 0, 0), a + Vector3(0.012, 0, 0), bb + Vector3(0.012, 0, 0), bb - Vector3(0.012, 0, 0), Color("c9c9c9"), Vector3.UP)
			continue
		var road := b != D.B.TRAIL
		var half := 0.37 if road else 0.13
		for pts: PackedVector2Array in _centerline(_arms(x, y, road)):
			var prev: Array[Vector3] = []
			for k in pts.size():
				var p := pts[k] + Vector2(x, y)
				var tan := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
				if tan.length_squared() < 0.00001:
					continue
				tan = tan.normalized()
				var perp := Vector2(-tan.y, tan.x)
				var row: Array[Vector3] = []
				for s in [-1.0, -0.04, 0.04, 1.0]:
					var q: Vector2 = p + perp * half * s
					row.append(Vector3(q.x, maxf(height_at(q.x, q.y), min_y) + 0.03, q.y))
				if not prev.is_empty():
					if water:
						var col := Color("5d6068") if road else Color("7a5a36")
						m.quad(prev[0], prev[3], row[3], row[0], col, Vector3.UP)
						m.quad(prev[0], row[0], row[0] + Vector3(0, -0.12, 0), prev[0] + Vector3(0, -0.12, 0), col.darkened(0.3), Vector3(-perp.x, 0, -perp.y))
						m.quad(prev[3], row[3], row[3] + Vector3(0, -0.12, 0), prev[3] + Vector3(0, -0.12, 0), col.darkened(0.3), Vector3(perp.x, 0, perp.y))
					if road and k % 2 == 0 and pts.size() > 2:
						m.quad(prev[1] + Vector3(0, 0.012, 0), prev[2] + Vector3(0, 0.012, 0), row[2] + Vector3(0, 0.012, 0), row[1] + Vector3(0, 0.012, 0), Color("c9ad4a"), Vector3.UP)
				prev = row
		if water:
			for k in 4:
				var q := Vector2(x + 0.5, y + 0.5) + Vector2(cos(k * PI * 0.5 + 0.78), sin(k * PI * 0.5 + 0.78)) * (half + 0.02)
				m.box(Vector3(q.x, min_y - 0.7, q.y), Vector3(0.07, 1.4, 0.07), Color("4a3620") if not road else Color("777a80"))
	return m.commit()


# ---------------------------------------------------------------- vegetation

func _fill(mm: MultiMesh, xforms: Array, colors: Array) -> void:
	mm.instance_count = xforms.size()
	var supplied: bool = _external.has(mm.mesh)
	var fit_xf: Transform3D = _external[mm.mesh] if supplied else Transform3D.IDENTITY
	for i in xforms.size():
		# supplied models carry their own colours and need fitting to size
		mm.set_instance_transform(i, xforms[i] * fit_xf if supplied else xforms[i])
		var col: Color = colors[i]
		if _cards.has(mm.mesh):
			# cut-outs carry their own colours: only a gentle per-tree and seasonal tint
			var peak := maxf(maxf(col.r, col.g), maxf(col.b, 0.001))
			col = Color.WHITE.lerp(Color(col.r / peak, col.g / peak, col.b / peak), 0.3) * 0.8
			if season == 3:
				col = col.lerp(Color(1.5, 1.6, 1.75), 0.45)
		mm.set_instance_color(i, Color.WHITE if supplied else col)


func _xf(x: float, z: float, s: float, yaw: float, sink: float = 0.0, squash: float = 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * squash, s)), Vector3(x, height_at(x, z) - sink, z))


func _conifer_color(hh: float) -> Color:
	var cc := Color("15382a").lerp(Color("2a573c"), hh)
	if season == 3:
		cc = cc.lerp(Color("dfe8ec"), 0.5)
	return cc


func _rebuild_region(key: Vector2i) -> void:
	var out := {}
	for name in _veg:
		out[name] = [[], []]
	var bloom := [Color("fffbe6"), Color("f2cf4a"), Color("e98ab0"), Color("a887d6")]
	var leaf_pal := [
		[Color("3f7a3a"), Color("6a9f4c")], [Color("2f6332"), Color("4c813c")],
		[Color("c98a22"), Color("e6bf3a")], [Color("8d948d"), Color("d9e0e3")]]
	for y in range(key.y * REG, mini(World.H, key.y * REG + REG)):
		for x in range(key.x * REG, mini(World.W, key.x * REG + REG)):
			var i := World.idx(x, y)
			if world.build[i] != D.B.NONE or world.landmark_at.has(i):
				continue
			var t := world.terrain[i]
			var bio := world.biome[i]
			var h := D.hash2(x, y, 1)
			var h2 := D.hash2(x, y, 7)
			var kind := world.trees[i]
			# grass blades wherever there is living ground
			var blades := 0
			var blade_h := 1.0
			if t == D.T.MEADOW: blades = 14
			elif t == D.T.GRASS: blades = 12
			elif t == D.T.FOREST: blades = 5
			if bio == D.BIOME.WETLAND and t == D.T.GRASS:
				blades = 14
				blade_h = 1.6
			elif bio == D.BIOME.DESERT:
				blades = 3 if t == D.T.GRASS else 0
			elif bio == D.BIOME.ALPINE:
				blades = mini(blades, 8)
				blade_h = 0.6
			if blades > 0:
				var ground_col := tile_color(i)
				var straw := Color("8a7f4a") if bio != D.BIOME.DESERT else Color("a39a66")
				for k in blades:
					var gx := x + D.hash2(x, y, 100 + k)
					var gz := y + D.hash2(x, y, 120 + k)
					var gv := D.hash2(x, y, 140 + k)
					out.grass[0].append(_xf(gx, gz, (0.8 + gv * 0.9) * blade_h, gv * TAU, 0.0))
					out.grass[1].append(ground_col.lightened(0.3).lerp(straw, gv * gv * 0.6))
			if kind > 0:
				# trees keep back from roads and buildings
				if _beside_development(x, y):
					continue
				var dens: float = world.tree_density[i] if world.tree_density.size() > i else 0.6
				if dens <= 0.0:
					dens = 0.6 # planted or regrown
				var count := 1
				if dens > 0.55 and h < 0.8: count = 2
				if dens > 0.85 and h < 0.45: count = 3
				var mesh_key := "leaf" if kind == 1 else ("conifer2" if kind == 3 else "conifer")
				var heavy: bool = _external.has(_meshes[mesh_key])
				var is_card: bool = _cards.has(_meshes[mesh_key])
				if heavy:
					count = mini(count, 2)
				# trees shrink toward the treeline
				var stunt := 1.0 - 0.55 * smoothstep(8.0, 13.0, world.height[i])
				for k in count:
					var hh := D.hash2(x, y, 8 + k)
					var px := x + 0.08 + D.hash2(x, y, 50 + k) * 0.84
					var pz := y + 0.08 + D.hash2(x, y, 60 + k) * 0.84
					var s := ((1.45 if heavy else 1.1) + hh * 0.9) * stunt
					if kind == 3: s *= 1.12
					if bio == D.BIOME.DESERT: s = 0.5 + hh * 0.3
					var xf := _xf(px, pz, s, hh * TAU, 0.08, 0.9 + D.hash2(x, y, 70 + k) * 0.35)
					var own_trunk: bool = heavy or is_card
					if not own_trunk:
						out.trunk[0].append(xf)
					if kind != 1:
						if not own_trunk: out.trunk[1].append(Color.WHITE)
						out[mesh_key][0].append(xf)
						out[mesh_key][1].append(_conifer_color(D.hash2(x, y, 12 + k)))
						if out.has(HD[mesh_key]):
							out[HD[mesh_key]][0].append(xf)
							out[HD[mesh_key]][1].append(Color.WHITE)
					else:
						# aspens have pale bark
						if not own_trunk: out.trunk[1].append(Color(2.6, 2.5, 2.3) if bio != D.BIOME.DESERT else Color.WHITE)
						out.leaf[0].append(xf)
						var pal: Array = leaf_pal[season]
						var col: Color = pal[0].lerp(pal[1], D.hash2(x, y, 12 + k))
						if bio == D.BIOME.DESERT:
							col = Color("4a5a36")
						if is_card and season == 2:
							col = Color(1.0, 0.72, 0.2)
						out.leaf[1].append(col)
						if out.has("leaf_hd"):
							out.leaf_hd[0].append(xf)
							out.leaf_hd[1].append(Color.WHITE)
			elif (t == D.T.ROCK or t == D.T.PEAK) and bio != D.BIOME.DESERT and h < (0.2 if t == D.T.ROCK else 0.08):
				# boulders and scree: one big block with smaller ones fallen around it
				var rk := "rock" if h2 < 0.5 else "rock2"
				var big := 0.6 + h2 * 2.6 * (h / 0.2)
				out[rk][0].append(_xf(x + h2, y + fmod(h * 9.0, 1.0), big, h * 40.0, 0.1 * big, 0.75 + h2 * 0.5))
				out[rk][1].append(Color.WHITE)
				for k in (1 if h2 > 0.5 else 0):
					var rk2 := "rock2" if rk == "rock" else "rock"
					out[rk2][0].append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.25 + D.hash2(x, y, 40 + k) * 0.5, k * 2.3 + h * 9.0, 0.04))
					out[rk2][1].append(Color.WHITE)
			elif bio == D.BIOME.DESERT and (t == D.T.GRASS or t == D.T.SAND):
				var n := 3 if t == D.T.GRASS else (1 if h < 0.35 else 0)
				for k in n:
					out.bush[0].append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.6 + D.hash2(x, y, 40 + k) * 0.7, k * 2.0))
					out.bush[1].append(Color("7d8a6a").lerp(Color("9a9a72"), h2))
				if h < 0.1:
					out.rock_red[0].append(_xf(x + h2, y + fmod(h * 9.0, 1.0), 0.6 + h2 * 2.2, h * 40.0, 0.08, 0.8 + h2 * 0.4))
					out.rock_red[1].append(Color.WHITE)
			elif bio == D.BIOME.WETLAND and t == D.T.GRASS:
				for k in 4:
					out.reed[0].append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.7 + D.hash2(x, y, 40 + k) * 0.7, k * 1.3))
					out.reed[1].append(Color("6f8f3f").lerp(Color("a39a52"), D.hash2(x, y, 45 + k) * (1.0 if season >= 2 else 0.3)))
			elif (t == D.T.GRASS or t == D.T.MEADOW) and bio != D.BIOME.DESERT:
				if t == D.T.MEADOW and season != 3:
					for k in 3:
						out.flower[0].append(_xf(x + D.hash2(x, y, 20 + k), y + D.hash2(x, y, 30 + k), 0.14 + h * 0.16, 0.0, -0.06))
						out.flower[1].append(bloom[int(D.hash2(x, y, 40 + k) * 4.0) % 4])
				if h2 < 0.13:
					out.bush[0].append(_xf(x + h, y + h2 * 4.0, 0.5 + h * 0.6, h * 9.0))
					out.bush[1].append(Color("3f6a34").lerp(Color("5f8a3f"), h) if season != 3 else Color("9aa39c"))
				if h < (0.09 if bio == D.BIOME.ALPINE else 0.012):
					out.rock2[0].append(_xf(x + h2, y + fmod(h * 18.0, 1.0), 0.4 + h2 * 1.3, h * 40.0, 0.08))
					out.rock2[1].append(Color.WHITE)
	var mms: Dictionary = _regions[key]
	for name in _veg:
		_fill(mms[name], out[name][0], out[name][1])
	if key == Vector2i.ZERO:
		var xs: Array = []
		var cs: Array = []
		for p: Vector3 in _outer_trees:
			var hh := D.hash2(int(p.x * 7.0), int(p.z * 7.0), 3)
			var y := outer_at(p.x, p.z)
			if y < 0.2:
				continue
			xs.append(Transform3D(Basis(Vector3.UP, hh * TAU).scaled(Vector3.ONE * (1.4 + hh * 1.2)), Vector3(p.x, y - 0.1, p.z)))
			cs.append(_conifer_color(hh))
		_fill(_mm["outer"], xs, cs)


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
			xs.append(Transform3D(Basis(Vector3.UP, k * 1.3).scaled(Vector3.ONE * 0.6), Vector3(px, surface_at(px, pz) + 0.02, pz)))
			cs.append(palette[(k + x) % 4])
	_fill(_mm["litter"], xs, cs)
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
		for k in int(3 + v * 7.0):
			var px := x + 0.05 + D.hash2(x, y, 40 + k) * 0.9
			var pz := y + 0.05 + D.hash2(x, y, 50 + k) * 0.9
			if is_water:
				wet.append(Transform3D(Basis(Vector3.UP, k * 0.9).scaled(Vector3.ONE * (0.7 + v)), Vector3(px, world.wlevel[i] + 0.006 + k * 0.002, pz)))
				wet_c.append(Color.WHITE)
			else:
				land.append(_xf(px, pz, 0.6 + v * 0.6, k * 1.1))
				land_c.append(Color.WHITE)
	_fill(_mm["thistle"], land, land_c)
	_fill(_mm["milfoil"], wet, wet_c)
	var ox: Array = []
	var oc: Array = []
	for t in _orchid_tiles:
		var hp := world.rare[World.ti(t)]
		if hp > 0.0:
			ox.append(_xf(t.x + 0.5, t.y + 0.5, 0.7 + hp * 0.4, 0.0))
			oc.append(Color.WHITE.lerp(Color(0.6, 0.55, 0.5), 1.0 - hp))
	_fill(_mm["orchid"], ox, oc)
	var fx: Array = []
	var fc: Array = []
	for i: int in world.fire_tiles.keys():
		var x := i % World.W
		var y := i / World.W
		for k in 4:
			var px := x + 0.15 + D.hash2(x, y, 80 + k) * 0.7
			var pz := y + 0.15 + D.hash2(x, y, 90 + k) * 0.7
			fx.append(_xf(px, pz, 1.4 + D.hash2(x, y, 95 + k) * 1.8, k * 1.7))
			fc.append(Color(1.0, 0.75 + D.hash2(x, y, 99 + k) * 0.25, 0.6))
	_fill(_mm["flame"], fx, fc)
	fire_light.visible = not world.fire_tiles.is_empty()
	if fire_light.visible:
		var fi: int = world.fire_tiles.keys()[0]
		fire_light.position = Vector3(fi % World.W + 0.5, height_at(fi % World.W + 0.5, fi / World.W + 0.5) + 3.0, fi / World.W + 0.5)


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
		if world.wlevel[World.ti(st)] != World.NO_WATER:
			top = maxf(top, world.wlevel[World.ti(st)] + DECK)
		holder.position = Vector3(cxp, top + 0.03, czp)
		var mi := MeshInstance3D.new()
		var ext := Models.external(str(D.B.keys()[kind]).to_lower())
		mi.mesh = ext if ext != null else Models.structure(kind)
		if ext == null:
			mi.material_override = mat
		else:
			mi.transform = Models.fit(ext, EXT_WIDTH.get(kind, sz.x * 0.9), true)
		holder.add_child(mi)
		if not (kind in NO_FOUNDATION):
			var base := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(sz.x * 0.9, 4.0, sz.y * 0.9) if sz.x > 1 else Vector3(0.84, 4.0, 0.84)
			base.mesh = box
			base.position = Vector3(0, -2.0, 0)
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("5f5a52")
			bm.roughness = 1.0
			base.material_override = bm
			holder.add_child(base)
		var wins := Models.windows(kind)
		if ext == null and wins.get_surface_count() > 0:
			var wi := MeshInstance3D.new()
			wi.mesh = wins
			wi.material_override = win_mat
			wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(wi)
		if kind in LIT:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.72, 0.4) if kind != D.B.CAMP else Color(1.0, 0.55, 0.22)
			lamp.omni_range = 5.0 if sz.x > 1 else 3.2
			lamp.omni_attenuation = 1.4
			lamp.position = Vector3(-0.3, 0.3, 0.42) if kind == D.B.CAMP else Vector3(0, 0.45, sz.y * 0.5 + 0.25)
			lamp.light_energy = _night * 2.6
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


## Boulders and rubble heaped around a landmark's foot so it grows out of the
## ground instead of sitting on it.
func _landmark_rocks(kind: String, pos: Vector3, width: float) -> void:
	var names := ["rock_red"] if kind == "arch" else ["rock", "rock2"]
	var n := 16 if kind != "spring" else 9
	for k in n:
		var key: String = names[k % names.size()]
		var mesh: Mesh = _meshes[key]
		var a := k * 2.399 + pos.x
		var r := width * (0.38 + 0.3 * D.hash2(int(pos.x), int(pos.z), 300 + k))
		var p := Vector3(pos.x + cos(a) * r, 0, pos.z + sin(a) * r)
		var s := (0.35 + 1.1 * D.hash2(int(pos.x), int(pos.z), 330 + k)) * (0.6 if kind == "spring" else 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var xf := _xf(p.x, p.z, s, a * 3.0, 0.1 * s, 0.8)
		if _external.has(mesh):
			xf = xf * _external[mesh]
		else:
			mi.material_override = mat
		mi.transform = xf
		add_child(mi)


## Height of the water sheet at a point, as the water mesh draws it (levels
## averaged at tile corners), or far below ground where there is no water.
func _river_surface(x: float, z: float) -> float:
	var tx := clampi(int(floor(x)), 0, World.W - 1)
	var tz := clampi(int(floor(z)), 0, World.H - 1)
	var lv: Array[float] = []
	var low := 1e9
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var sum := 0.0
		var cnt := 0
		for dy in [-1, 0]:
			for dx in [-1, 0]:
				var ax: int = tx + c.x + dx
				var ay: int = tz + c.y + dy
				if World.inb(ax, ay) and world.wlevel[World.idx(ax, ay)] != World.NO_WATER:
					sum += world.wlevel[World.idx(ax, ay)]
					cnt += 1
		lv.append(sum / cnt if cnt > 0 else NAN)
		if cnt > 0:
			low = minf(low, sum / cnt)
	if low > 1e8:
		return -1e6
	for k in 4:
		if is_nan(lv[k]):
			lv[k] = low
	var u := x - tx
	var v := z - tz
	return lerpf(lerpf(lv[0], lv[1], u), lerpf(lv[2], lv[3], u), v)


## A waterfall is part of the land: the river pours over the rock step that
## the world generator raised, as a sheet of moving water laid on the cliff.
func _build_falls(lm: Dictionary, pos: Vector3) -> void:
	var up: Vector2 = lm.get("dir", Vector2(0, -1))
	var side := Vector2(-up.y, up.x)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var steps := 44
	var prev_y := 1e9
	for k in steps + 1:
		var f := float(k) / steps
		var along := lerpf(0.7, -1.7, f) # from the lip to the pool
		var c := Vector2(pos.x, pos.z) + up * along
		var wide := lerpf(0.5, 0.62, f)
		# ride on the river's own surface, so the sheet joins the water above and below
		var cy := maxf(height_at(c.x, c.y) + 0.06, _river_surface(c.x, c.y) + 0.04)
		cy = minf(cy, prev_y) # water never runs uphill
		var steep := clampf((prev_y - cy) * 4.0, 0.0, 1.0) if k > 0 else 0.0
		prev_y = cy
		for sgn in [-1.0, 1.0]:
			var p: Vector2 = c + side * wide * float(sgn)
			# the sheet stands a little proud of the rock where it falls free
			verts.append(Vector3(p.x - up.x * 0.12 * steep, cy, p.y - up.y * 0.12 * steep))
			norms.append(Vector3(-up.x * steep, 1.0 - steep * 0.6, -up.y * steep).normalized())
			uvs.append(Vector2(0.0 if float(sgn) < 0.0 else 1.0, f * 6.0 if f < 0.999 else 6.0))
			uv2.append(Vector2(steep, 0.0))
		if k > 0:
			var a := (k - 1) * 2
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	for k in uvs.size():
		uvs[k].y /= 6.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = falls_mat
	add_child(mi)
	# spray hanging over the plunge pool
	var foot := Vector2(pos.x, pos.z) - up * 1.2
	var mist := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(-up.x, 1.2, -up.y)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, -0.15, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	mist.process_material = pm
	mist.amount = 26
	mist.lifetime = 2.6
	var puff := QuadMesh.new()
	puff.size = Vector2(0.7, 0.7)
	var pmat := StandardMaterial3D.new()
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(1, 1, 1, 0.13)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = pmat
	mist.draw_pass_1 = puff
	mist.position = Vector3(foot.x, height_at(foot.x, foot.y) + 0.4, foot.y)
	mist.visibility_range_end = 120.0
	add_child(mist)
	_landmark_rocks("falls", Vector3(foot.x, pos.y, foot.y), 2.6)


func _build_landmarks() -> void:
	# target width (in tiles) for each landmark model, and how high its name floats
	var spec := {"falls": [4.2, 6.0], "spring": [2.6, 2.2], "arch": [3.6, 5.0], "summit": [0.9, 2.4], "grove": [0.0, 9.5], "lake": [0.0, 1.5]}
	for lm in world.landmarks:
		var t: Vector2i = lm.tile
		var pos := Vector3(t.x + 0.5, top_at(t.x + 0.5, t.y + 0.5), t.y + 0.5)
		var info: Array = spec.get(lm.kind, [1.0, 3.0])
		if lm.kind == "grove":
			# a stand of giant old trees
			for k in 7:
				var a := k * 0.9
				var r := 0.0 if k == 0 else 0.9 + (k % 3) * 0.5
				var tp := Vector3(pos.x + cos(a) * r, 0, pos.z + sin(a) * r)
				tp.y = height_at(tp.x, tp.z) - 0.1
				var tree := MeshInstance3D.new()
				tree.mesh = _meshes["conifer2" if k % 2 == 1 else "conifer"]
				if not _cards.has(tree.mesh) and not _external.has(tree.mesh):
					tree.material_override = mat
				tree.position = tp
				tree.rotation.y = k * 1.7
				tree.scale = Vector3.ONE * (3.6 - (k % 3) * 0.5)
				add_child(tree)
		elif lm.kind == "falls":
			_build_falls(lm, pos)
		elif lm.kind != "lake":
			var mi := MeshInstance3D.new()
			var ext := Models.external("lm_" + str(lm.kind))
			if ext != null:
				mi.mesh = ext
				# set into the ground and turned to face down the slope it stands on
				var gx := height_at(pos.x + 1.5, pos.z) - height_at(pos.x - 1.5, pos.z)
				var gz := height_at(pos.x, pos.z + 1.5) - height_at(pos.x, pos.z - 1.5)
				var yaw := atan2(-gx, -gz) if absf(gx) + absf(gz) > 0.25 else 0.0
				var low := pos.y
				for k in 8:
					low = minf(low, top_at(pos.x + cos(k * TAU / 8.0) * info[0] * 0.4, pos.z + sin(k * TAU / 8.0) * info[0] * 0.4))
				var sink: float = {"falls": 0.7, "arch": 0.3, "spring": 0.14, "summit": 0.1}.get(lm.kind, 0.12)
				mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, lerpf(pos.y, low, 0.7) - sink, pos.z)) * Models.fit(ext, info[0], true)
				_landmark_rocks(lm.kind, pos, info[0])
			else:
				mi.mesh = Models.landmark(lm.kind)
				mi.material_override = mat
				mi.position = pos
				mi.scale = Vector3.ONE * 2.0
			add_child(mi)
		var label := _label(lm.name, 19)
		label.position = pos + Vector3(0, info[1], 0)
		add_child(label)
