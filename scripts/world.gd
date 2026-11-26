class_name World
extends RefCounted
## The land itself: terrain, everything built on it, and the derived
## ecological fields (disturbance, habitat quality, scenery).

signal changed(rect: Rect2i)

const W := D.MAP_W
const H := D.MAP_H
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var terrain := PackedByteArray()
var elev := PackedFloat32Array()
var trees := PackedByteArray() # 0 none, 1 broadleaf, 2 conifer
var build := PackedByteArray()
var sid := PackedInt32Array() # structure id per tile
var litter := PackedByteArray()
var invasive := PackedFloat32Array()
var disturb := PackedFloat32Array()
var quality := PackedFloat32Array()
var park_used := PackedByteArray()
var rare := PackedFloat32Array() # orchid colony health
var footfall := PackedFloat32Array()
var fire := PackedByteArray() # hours of burning left
var burned := PackedByteArray() # days until a burn scar recovers
var inv_seen := PackedByteArray() # invasive patches your staff have found
var fire_tiles := {}
var bin_cover := PackedByteArray()
var sign_cover := PackedByteArray()
var rest_cover := PackedByteArray()
const NO_WATER := -999.0
var biome := PackedByteArray() # D.BIOME per tile
var height := PackedFloat32Array() # ground height per tile, world units
var wlevel := PackedFloat32Array() # water surface height per tile, NO_WATER if dry
var landmark_at := {} # tile idx -> landmark dict

var pristine_total := 1.0
var lake_size := 0
var structures := {}
var next_sid := 1
var landmarks: Array = []
var entry := Vector2i()
var trail_tiles: Array[Vector2i] = []
var lot_tiles: Array[Vector2i] = []
var litter_tiles := {}
var invasive_tiles := {}
var car_nav := AStarGrid2D.new()
var walk_nav := AStarGrid2D.new()
var staff_nav := AStarGrid2D.new()
var nav_version := 0
var fields_dirty := true
var sustainable_trails := false
var defer_nav := false # set while placing many tiles at once
var _scenic_cache := {}
var _dist_cache := {}
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()


## Raw elevation noise; also defined outside the map (used for the horizon).
func raw_elev(x: float, y: float) -> float:
	var north := 1.0 - y / H
	return (noise.get_noise_2d(x, y) * 0.5 + 0.5) * 0.72 + north * 0.34 - 0.03


static func idx(x: int, y: int) -> int:
	return y * W + x

static func ti(t: Vector2i) -> int:
	return t.y * W + t.x

static func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

static func center(t: Vector2i) -> Vector2:
	return Vector2(t.x * D.TILE + D.TILE * 0.5, t.y * D.TILE + D.TILE * 0.5)

static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / D.TILE)), 0, W - 1), clampi(int(floor(p.y / D.TILE)), 0, H - 1))

func is_water(t: int) -> bool:
	return t == D.T.DEEP or t == D.T.WATER

func terrain_at(t: Vector2i) -> int:
	return terrain[ti(t)]


# ---------------------------------------------------------------- generation

func generate(seed_val: int) -> void:
	rng.seed = seed_val
	var n := W * H
	terrain.resize(n); terrain.fill(0)
	trees.resize(n); trees.fill(0)
	build.resize(n); build.fill(0)
	litter.resize(n); litter.fill(0)
	park_used.resize(n); park_used.fill(0)
	bin_cover.resize(n); bin_cover.fill(0)
	sign_cover.resize(n); sign_cover.fill(0)
	rest_cover.resize(n); rest_cover.fill(0)
	elev.resize(n); elev.fill(0.0)
	invasive.resize(n); invasive.fill(0.0)
	disturb.resize(n); disturb.fill(0.0)
	quality.resize(n); quality.fill(0.0)
	rare.resize(n); rare.fill(0.0)
	footfall.resize(n); footfall.fill(0.0)
	fire.resize(n); fire.fill(0)
	burned.resize(n); burned.fill(0)
	inv_seen.resize(n); inv_seen.fill(0)
	sid.resize(n)
	sid.fill(0)

	var n1 := noise # only used for scenery beyond the map edge
	n1.seed = seed_val
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.0135
	n1.fractal_octaves = 4
	var n2 := FastNoiseLite.new()
	n2.seed = seed_val + 77
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.028
	n2.fractal_octaves = 3

	# shape the land first (see terrain_gen.gd), then decide what grows where
	var tg := TerrainGen.new()
	tg.generate(W, H, seed_val)
	height = tg.height
	wlevel = tg.level
	biome.resize(n)
	var moist := PackedFloat32Array()
	moist.resize(n)
	for y in H:
		for x in W:
			var i := idx(x, y)
			var hgt := height[i]
			var m := n2.get_noise_2d(x, y) * 0.5 + 0.5
			moist[i] = m
			elev[i] = clampf(0.31 + hgt / 28.0, 0.0, 1.0)
			var slope := 0.0
			for d in DIRS:
				if inb(x + d.x, y + d.y):
					slope = maxf(slope, absf(hgt - height[idx(x + d.x, y + d.y)]))
			var desert := tg.dry[i] > 0.78
			var bio := D.BIOME.FOREST if m > 0.46 else D.BIOME.VALLEY
			var t := D.T.GRASS
			if wlevel[i] != NO_WATER:
				t = D.T.DEEP if wlevel[i] - hgt > 1.7 else D.T.WATER
				if desert: bio = D.BIOME.DESERT
			elif desert:
				bio = D.BIOME.DESERT
				if tg.mesa[i] == 1 or slope > 1.3: t = D.T.ROCK
				elif m > 0.56: t = D.T.GRASS
				else: t = D.T.SAND
			elif hgt > 23.0 or (hgt > 15.0 and slope > 2.6): t = D.T.PEAK
			elif slope > 1.5 or hgt > 17.0: t = D.T.ROCK
			elif m > 0.46: t = D.T.FOREST
			elif m < 0.32: t = D.T.MEADOW
			if not desert and (hgt > 12.0 or t == D.T.PEAK or (t == D.T.ROCK and tg.mountain[i] > 0.35)):
				bio = D.BIOME.ALPINE
				if t == D.T.FOREST and m < 0.62: t = D.T.MEADOW
				elif t == D.T.GRASS: t = D.T.MEADOW
			terrain[i] = t
			biome[i] = bio
	# marshy wetlands on the flat ground beside lowland lakes
	for y in H:
		for x in W:
			var i := idx(x, y)
			if biome[i] == D.BIOME.DESERT or biome[i] == D.BIOME.ALPINE or is_water(terrain[i]) or terrain[i] == D.T.ROCK or moist[i] < 0.4:
				continue
			var lake := NO_WATER
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if inb(x + dx, y + dy):
						var j := idx(x + dx, y + dy)
						if wlevel[j] != NO_WATER and tg.river[j] == 0:
							lake = maxf(lake, wlevel[j])
			if lake == NO_WATER or height[i] - lake > 0.6 or moist[i] < 0.5:
				continue
			biome[i] = D.BIOME.WETLAND
			var hsh := D.hash2(x, y, 14)
			if hsh < 0.3:
				terrain[i] = D.T.WATER
				wlevel[i] = lake
				height[i] = lake - 0.3
			else:
				terrain[i] = D.T.GRASS if hsh < 0.85 else D.T.SAND
				height[i] = lake + 0.14
	var falls: Array[Vector2i] = tg.falls

	# sandy shores
	for y in H:
		for x in W:
			var i := idx(x, y)
			var t := terrain[i]
			if (t == D.T.GRASS or t == D.T.MEADOW or t == D.T.FOREST) and biome[i] != D.BIOME.WETLAND:
				if _near_terrain(x, y, 1, [D.T.DEEP, D.T.WATER]) and D.hash2(x, y, 3) < 0.3:
					terrain[i] = D.T.SAND

	_place_entry()

	for y in H:
		for x in W:
			var i := idx(x, y)
			var h := D.hash2(x, y, 1)
			var conifer := elev[i] > 0.45 or D.hash2(x, y, 2) < 0.6
			var bio := biome[i]
			match terrain[i]:
				D.T.FOREST: trees[i] = 2 if conifer else 1
				D.T.GRASS:
					if bio == D.BIOME.DESERT:
						if h < 0.03: trees[i] = 1 # the odd juniper
					elif bio == D.BIOME.VALLEY:
						# aspen groves in the open valley
						if n2.get_noise_2d(x * 3.0 + 90.0, y * 3.0) > 0.28 and h < 0.7: trees[i] = 1
						elif h < 0.04: trees[i] = 2
					elif bio == D.BIOME.WETLAND:
						if h < 0.06: trees[i] = 1
					elif h < 0.1: trees[i] = 2 if conifer else 1
				D.T.MEADOW:
					if h < (0.07 if bio == D.BIOME.ALPINE else 0.03): trees[i] = 2 if bio == D.BIOME.ALPINE else 1
				D.T.ROCK:
					if h < 0.1 and bio != D.BIOME.DESERT: trees[i] = 2
	for t in [entry, entry + Vector2i(0, -1), entry + Vector2i(0, -2)]:
		trees[ti(t)] = 0
		build[ti(t)] = D.B.ROAD

	_place_landmarks(falls)
	_place_orchids()
	rebuild_nav()
	recompute_fields()
	pristine_total = 0.0
	for i in n:
		pristine_total += _nature(i, true)


func _near_terrain(x: int, y: int, r: int, kinds: Array) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if inb(x + dx, y + dy) and terrain[idx(x + dx, y + dy)] in kinds:
				return true
	return false


func _place_entry() -> void:
	# the highway meets the park where there is open, buildable country
	var best_x := W / 2
	var best_score := -999.0
	for x in range(14, W - 14):
		var ok := 0.0
		for y in range(H - 18, H):
			for dx in range(-8, 9):
				var i := idx(x + dx, y)
				var t := terrain[i]
				if (t == D.T.GRASS or t == D.T.MEADOW or t == D.T.FOREST or t == D.T.SAND) and biome[i] != D.BIOME.WETLAND:
					ok += 1.0
		# prefer level ground for the first road
		var lo := 1e9
		var hi := -1e9
		for y in range(H - 14, H):
			for dx in range(-4, 5):
				lo = minf(lo, height[idx(x + dx, y)])
				hi = maxf(hi, height[idx(x + dx, y)])
		ok -= (hi - lo) * 14.0
		ok -= abs(x - W / 2) * 0.4
		if ok > best_score:
			best_score = ok
			best_x = x
	entry = Vector2i(best_x, H - 1)
	for y in range(H - 5, H):
		for dx in range(-1, 2):
			var i := idx(best_x + dx, y)
			if wlevel[i] != NO_WATER:
				height[i] = wlevel[i] + 0.3
				wlevel[i] = NO_WATER
			if is_water(terrain[i]) or terrain[i] == D.T.ROCK or terrain[i] == D.T.PEAK:
				terrain[i] = D.T.GRASS


func _add_landmark(kind: String, tile: Vector2i) -> void:
	var names: Array = D.LANDMARK_NAMES[kind]
	var lm := {kind = kind, tile = tile, name = names[rng.randi() % names.size()]}
	landmarks.append(lm)
	landmark_at[ti(tile)] = lm
	trees[ti(tile)] = 0


func _far_from_landmarks(t: Vector2i, d: int) -> bool:
	for lm in landmarks:
		var lt: Vector2i = lm.tile
		if abs(lt.x - t.x) + abs(lt.y - t.y) < d:
			return false
	return true


func _place_landmarks(falls: Array[Vector2i]) -> void:
	# summit: highest peak away from the map edge
	var best := Vector2i(-1, -1)
	var best_e := 0.0
	for y in range(2, H - 2):
		for x in range(3, W - 3):
			if terrain[idx(x, y)] == D.T.PEAK and height[idx(x, y)] > best_e:
				best_e = height[idx(x, y)]
				best = Vector2i(x, y)
	if best.x >= 0:
		_add_landmark("summit", best)
	for f in falls:
		if _far_from_landmarks(f, 10) and f.x > 4 and f.y > 4 and f.x < W - 5 and f.y < H - 5:
			_add_landmark("falls", f)
			break
	# lake: largest body of water
	var seen := {}
	var biggest: Array = []
	for y in H:
		for x in W:
			var s := Vector2i(x, y)
			if seen.has(s) or not is_water(terrain[ti(s)]):
				continue
			var body: Array = [s]
			seen[s] = true
			var k := 0
			while k < body.size():
				for d in DIRS:
					var nb: Vector2i = body[k] + d
					if inb(nb.x, nb.y) and not seen.has(nb) and is_water(terrain[ti(nb)]):
						seen[nb] = true
						body.append(nb)
				k += 1
			if body.size() > biggest.size():
				biggest = body
	if biggest.size() > 12:
		lake_size = biggest.size()
		var c := Vector2.ZERO
		for b in biggest:
			c += Vector2(b)
		c /= biggest.size()
		var lake_t: Vector2i = biggest[0]
		var bd := 1e9
		for b in biggest:
			var dd := Vector2(b).distance_squared_to(c)
			if dd < bd and terrain[ti(b)] == D.T.DEEP:
				bd = dd
				lake_t = b
		_add_landmark("lake", lake_t)
	# grove: densest forest
	var gbest := Vector2i(-1, -1)
	var gscore := -1.0
	for attempt in 300:
		var t := Vector2i(rng.randi_range(5, W - 6), rng.randi_range(5, H - 10))
		if terrain[ti(t)] != D.T.FOREST or not _far_from_landmarks(t, 14):
			continue
		var c := 0.0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if terrain[idx(t.x + dx, t.y + dy)] == D.T.FOREST:
					c += 1.0
		c += rng.randf()
		if c > gscore:
			gscore = c
			gbest = t
	if gbest.x >= 0:
		_add_landmark("grove", gbest)
	for attempt in 600:
		var t := Vector2i(rng.randi_range(5, W - 6), rng.randi_range(5, H - 6))
		if biome[ti(t)] == D.BIOME.DESERT and terrain[ti(t)] == D.T.SAND and _far_from_landmarks(t, 14) \
				and _near_terrain(t.x, t.y, 2, [D.T.ROCK]):
			_add_landmark("arch", t)
			break
	for attempt in 400:
		var t := Vector2i(rng.randi_range(5, W - 6), rng.randi_range(5, H - 10))
		var tt := terrain[ti(t)]
		if (tt == D.T.MEADOW or tt == D.T.GRASS) and _far_from_landmarks(t, 14):
			_add_landmark("spring", t)
			break


func _place_orchids() -> void:
	var placed := 0
	for attempt in 4000:
		if placed >= 16:
			break
		var t := Vector2i(rng.randi_range(3, W - 4), rng.randi_range(3, H - 8))
		var i := ti(t)
		if (terrain[i] == D.T.FOREST or terrain[i] == D.T.MEADOW or terrain[i] == D.T.GRASS) and rare[i] == 0.0 \
				and not landmark_at.has(i) and _near_terrain(t.x, t.y, 3, [D.T.WATER, D.T.DEEP]):
			rare[i] = 1.0
			trees[i] = 0
			placed += 1


# ------------------------------------------------------------------- fields

func _nature(i: int, pristine: bool = false) -> float:
	var base := 0.0
	match terrain[i]:
		D.T.DEEP: base = 0.8
		D.T.WATER: base = 0.9
		D.T.SAND: base = 0.55
		D.T.GRASS: base = 0.6
		D.T.MEADOW: base = 0.85
		D.T.FOREST: base = 0.7
		D.T.ROCK: base = 0.5
		D.T.PEAK: base = 0.45
	if pristine:
		if terrain[i] == D.T.FOREST: base += 0.25
		return base
	var b := build[i]
	if b == D.B.TRAIL:
		return base * 0.4
	if b != D.B.NONE:
		return 0.0
	if trees[i] > 0:
		base += 0.25
	return minf(base, 1.0)


func recompute_fields() -> void:
	fields_dirty = false
	_scenic_cache.clear()
	disturb.fill(0.0)
	for y in H:
		for x in W:
			var b := build[idx(x, y)]
			if b == D.B.NONE:
				continue
			var def: Dictionary = D.BUILD[b]
			var r: int = def.dist
			var s: float = def.str
			if b == D.B.TRAIL and sustainable_trails:
				s *= 0.5
			if s <= 0.0:
				continue
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if not inb(x + dx, y + dy):
						continue
					var d := sqrt(float(dx * dx + dy * dy))
					if d > r + 0.5:
						continue
					disturb[idx(x + dx, y + dy)] += s * (1.0 - d / (r + 1.0)) * 0.5
	var n := W * H
	for i in n:
		var d := minf(1.0, disturb[i] + minf(0.35, footfall[i] * 0.01))
		disturb[i] = d
		quality[i] = _nature(i) * (1.0 - d) * (1.0 - 0.7 * invasive[i]) * (1.0 - minf(0.6, litter[i] * 0.2))


func scenic(t: Vector2i) -> float:
	var key := ti(t)
	if _scenic_cache.has(key):
		return _scenic_cache[key]
	var s := 0.0
	var seen_water := 0
	var seen_peak := 0
	var seen_forest := 0
	var seen_meadow := 0
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var d2 := dx * dx + dy * dy
			if d2 > 26 or not inb(t.x + dx, t.y + dy):
				continue
			var i := idx(t.x + dx, t.y + dy)
			var w := 1.0 / (1.0 + sqrt(float(d2)) * 0.5)
			var b := build[i]
			match b:
				D.B.NONE, D.B.TRAIL:
					match terrain[i]:
						D.T.DEEP, D.T.WATER:
							s += 1.0 * w
							seen_water += 1
						D.T.PEAK:
							s += 1.3 * w
							seen_peak += 1
						D.T.ROCK: s += 0.5 * w
						D.T.FOREST:
							s += 0.45 * w
							seen_forest += 1
						D.T.MEADOW:
							s += 0.6 * w
							seen_meadow += 1
						D.T.SAND: s += 0.3 * w
						D.T.GRASS: s += (0.45 if trees[i] > 0 else 0.3) * w
				D.B.ROAD, D.B.GATE: s -= 1.2 * w
				D.B.PARKING: s -= 2.0 * w
				D.B.OVERLOOK, D.B.HIDE, D.B.SIGN, D.B.BIN, D.B.TRAILHEAD, D.B.PICNIC: pass
				_: s -= 0.9 * w
			s -= litter[i] * 0.8 * w
			s -= invasive[i] * 0.6 * w
	var q := s / 20.0
	for c in [seen_water, seen_peak, seen_forest, seen_meadow]:
		if c >= 4:
			q += 0.07
	for lm in landmarks:
		var lt: Vector2i = lm.tile
		var d := Vector2(lt - t).length()
		if d <= 4.5:
			q += 0.5 * (1.0 - d / 6.0)
	q = clampf(q, 0.0, 1.5)
	_scenic_cache[key] = q
	return q


func nearest_landmark(t: Vector2i, maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for lm in landmarks:
		var lt: Vector2i = lm.tile
		var d := Vector2(lt - t).length()
		if d <= bd:
			bd = d
			best = lm
	return best


# ------------------------------------------------------------------ building

func footprint(kind: int, t: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = D.BUILD[kind].size
	var out: Array[Vector2i] = []
	for dy in size.y:
		for dx in size.x:
			out.append(t + Vector2i(dx, dy))
	return out


## Returns "" if `kind` can be placed at `t`, otherwise the reason it can't.
func can_build(kind: int, t: Vector2i) -> String:
	for c in footprint(kind, t):
		if not inb(c.x, c.y):
			return "Off the map"
		var i := ti(c)
		var ter := terrain[i]
		var b := build[i]
		if landmark_at.has(i):
			return "Landmarks are protected"
		match kind:
			D.B.ROAD:
				if b == D.B.ROAD or b == D.B.GATE: return "Already a road"
				if b != D.B.NONE and b != D.B.TRAIL: return "Occupied"
				if ter == D.T.DEEP: return "Water is too deep"
				if ter == D.T.ROCK or ter == D.T.PEAK: return "Too steep for a road"
			D.B.TRAIL:
				if b != D.B.NONE: return "Occupied"
				if ter == D.T.DEEP: return "Water is too deep"
			D.B.GATE:
				if b != D.B.ROAD: return "Place on a road"
				if c == entry: return "Too close to the highway"
			D.B.CRAG:
				if b != D.B.NONE: return "Occupied"
				if ter != D.T.ROCK: return "Needs rocky foothills"
			D.B.OVERLOOK, D.B.SIGN, D.B.HIDE:
				if b != D.B.NONE: return "Occupied"
				if is_water(ter): return "Can't build on water"
			_:
				if b != D.B.NONE: return "Occupied"
				if is_water(ter): return "Can't build on water"
				if ter == D.T.ROCK or ter == D.T.PEAK: return "Too steep"
	return ""


func cost_at(kind: int, t: Vector2i) -> int:
	var base: int = D.BUILD[kind].cost
	var total := 0.0
	var cells := footprint(kind, t)
	for c in cells:
		if not inb(c.x, c.y):
			continue
		var i := ti(c)
		var mult := 1.0
		var ter := terrain[i]
		if kind == D.B.ROAD and ter == D.T.WATER: mult = 6.0
		elif kind == D.B.TRAIL and ter == D.T.WATER: mult = 4.0
		elif kind == D.B.TRAIL and ter == D.T.PEAK: mult = 3.0
		elif kind == D.B.TRAIL and ter == D.T.ROCK: mult = 1.5
		total += float(base) / cells.size() * mult
		if trees[i] > 0 and kind != D.B.TRAIL:
			total += 15.0
	return int(round(total))


func place(kind: int, t: Vector2i) -> int:
	var cells := footprint(kind, t)
	var new_id := 0
	var linear := kind == D.B.ROAD or kind == D.B.TRAIL or kind == D.B.PARKING
	if not linear:
		new_id = next_sid
		next_sid += 1
		var def: Dictionary = D.BUILD[kind]
		var s := {id = new_id, kind = kind, tile = t, size = def.size, name = def.name, quality = 0.5,
			visitors = 0, access = [] as Array[Vector2i], visits = 0}
		if kind == D.B.OVERLOOK:
			var lm := nearest_landmark(t, 4.5)
			if not lm.is_empty():
				s.name = "%s Overlook" % lm.name
		structures[new_id] = s
	for c in cells:
		var i := ti(c)
		build[i] = kind
		sid[i] = new_id
		trees[i] = 0
		if invasive[i] > 0.0:
			invasive[i] = 0.0
			invasive_tiles.erase(i)
		rare[i] = 0.0
	if not defer_nav:
		rebuild_nav()
	fields_dirty = true
	_scenic_cache.clear()
	changed.emit(Rect2i(t - Vector2i(1, 1), Vector2i(D.BUILD[kind].size) + Vector2i(2, 2)))
	return new_id


## Removes whatever is built at `t`. Returns the kind removed (NONE if nothing).
func remove(t: Vector2i) -> int:
	var i := ti(t)
	var kind := build[i]
	if kind == D.B.NONE or t == entry:
		return D.B.NONE
	if kind == D.B.PARKING and park_used[i] > 0:
		return D.B.NONE
	var rect := Rect2i(t - Vector2i(1, 1), Vector2i(3, 3))
	if sid[i] != 0:
		var s: Dictionary = structures[sid[i]]
		var st: Vector2i = s.tile
		var sz: Vector2i = s.size
		for c in footprint(kind, st):
			build[ti(c)] = D.B.ROAD if kind == D.B.GATE else D.B.NONE
			sid[ti(c)] = 0
		structures.erase(s.id)
		rect = Rect2i(st - Vector2i(1, 1), sz + Vector2i(2, 2))
	else:
		build[i] = D.B.NONE
	if not defer_nav:
		rebuild_nav()
	fields_dirty = true
	_scenic_cache.clear()
	changed.emit(rect)
	return kind


func count_kind(kind: int) -> int:
	var c := 0
	for s in structures.values():
		if s.kind == kind:
			c += 1
	return c


func rebuild_nav() -> void:
	nav_version += 1
	_dist_cache.clear()
	var region := Rect2i(0, 0, W, H)
	for nav in [car_nav, walk_nav, staff_nav]:
		if nav.region != region:
			nav.region = region
			nav.cell_size = Vector2(1, 1)
			nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			nav.update()
	trail_tiles.clear()
	lot_tiles.clear()
	bin_cover.fill(0)
	sign_cover.fill(0)
	rest_cover.fill(0)
	for y in H:
		for x in W:
			var i := idx(x, y)
			var b := build[i]
			var t := Vector2i(x, y)
			var ter := terrain[i]
			var is_car := b == D.B.ROAD or b == D.B.GATE or b == D.B.PARKING
			car_nav.set_point_solid(t, not is_car)
			if is_car:
				car_nav.set_point_weight_scale(t, 3.0 if b == D.B.PARKING else 1.0)
			var is_walk := is_car or b == D.B.TRAIL
			walk_nav.set_point_solid(t, not is_walk)
			if is_walk:
				walk_nav.set_point_weight_scale(t, 1.0 if b == D.B.TRAIL else (1.4 if b == D.B.PARKING else 2.2))
			var staff_ok := is_walk or not is_water(ter)
			staff_nav.set_point_solid(t, not staff_ok)
			if staff_ok:
				staff_nav.set_point_weight_scale(t, 1.0 if is_walk else (5.0 if ter == D.T.PEAK else 2.0))
			if b == D.B.TRAIL:
				trail_tiles.append(t)
			elif b == D.B.PARKING:
				lot_tiles.append(t)
	for s in structures.values():
		var acc: Array[Vector2i] = []
		var st: Vector2i = s.tile
		var sz: Vector2i = s.size
		for c in footprint(s.kind, st):
			for d in DIRS:
				var nb := c + d
				if inb(nb.x, nb.y) and not walk_nav.is_point_solid(nb) and not acc.has(nb):
					acc.append(nb)
		s.access = acc
		match s.kind:
			D.B.BIN: _stamp(bin_cover, st, 5)
			D.B.SIGN, D.B.TRAILHEAD: _stamp(sign_cover, st, 6)
			D.B.RESTROOM, D.B.VISITOR_CENTER: _stamp(rest_cover, st, 9)


func _stamp(arr: PackedByteArray, t: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if inb(t.x + dx, t.y + dy) and dx * dx + dy * dy <= r * r + 1:
				arr[idx(t.x + dx, t.y + dy)] = 1


## Walking distance (in tiles) from `from` to the nearest access tile of a
## structure, and that tile. Returns [-1, ZERO] when unreachable. Cached.
func walk_to_structure(from: Vector2i, s: Dictionary) -> Array:
	var key := ti(from) * 4096 + int(s.id)
	if _dist_cache.has(key):
		return _dist_cache[key]
	var best := [-1, Vector2i.ZERO]
	if not walk_nav.is_point_solid(from):
		for a: Vector2i in s.access:
			var p := walk_nav.get_id_path(from, a)
			if p.size() > 0 and (best[0] < 0 or p.size() < best[0]):
				best = [p.size(), a]
	_dist_cache[key] = best
	return best


func add_litter(t: Vector2i) -> void:
	var i := ti(t)
	if litter[i] < 5:
		litter[i] += 1
		litter_tiles[i] = true
		_scenic_cache.clear()
		changed.emit(Rect2i(t, Vector2i(1, 1)))


func clear_litter(t: Vector2i) -> void:
	var i := ti(t)
	litter[i] = 0
	litter_tiles.erase(i)
	changed.emit(Rect2i(t, Vector2i(1, 1)))


func set_invasive(t: Vector2i, v: float) -> void:
	var i := ti(t)
	invasive[i] = v
	if v > 0.0:
		invasive_tiles[i] = true
	else:
		invasive_tiles.erase(i)
		inv_seen[i] = 0
	changed.emit(Rect2i(t, Vector2i(1, 1)))


func to_points(path: Array[Vector2i]) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in path:
		pts.append(center(p))
	return pts
