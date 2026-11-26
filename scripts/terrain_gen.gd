class_name TerrainGen
extends RefCounted
## Landscape generator. Instead of thresholding raw noise, it builds a height
## map the way real terrain forms:
##   1. domain-warped fractal noise for rolling lowlands,
##   2. ridged multifractal noise for mountain ranges with sharp ridgelines,
##   3. stream-power erosion: water is routed downhill, and cells are cut down
##      in proportion to the flow through them and their slope, which carves
##      branching valley networks; thermal erosion then relaxes cliffs to scree,
##   4. depression filling (priority flood) to find where water pools into
##      lakes, each with its own surface level, and a drainage tree,
##   5. rivers wherever enough upstream area drains through a cell.
## Heights are in world units (1 unit is about 8 m).

const NO_WATER := -999.0
const NB := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var W := 0
var H := 0
var height := PackedFloat32Array()
var level := PackedFloat32Array() # water surface height per tile, NO_WATER if dry
var river := PackedByteArray()
var mesa := PackedByteArray()
var dry := PackedFloat32Array() # > 0.78 means desert
var mountain := PackedFloat32Array() # 0..1 mountain-range mask
var falls: Array[Vector2i] = []

# binary heap for the priority flood
var _hk := PackedFloat32Array()
var _hv := PackedInt32Array()


func _noise(seed_val: int, freq: float, octaves: int, ridged: bool = false) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_val
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	if ridged:
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	return n


func generate(w: int, h: int, seed_val: int) -> void:
	W = w
	H = h
	var n := W * H
	height.resize(n)
	level.resize(n)
	level.fill(NO_WATER)
	river.resize(n)
	river.fill(0)
	mesa.resize(n)
	mesa.fill(0)
	dry.resize(n)
	mountain.resize(n)
	var warp_a := _noise(seed_val + 11, 0.008, 2)
	var warp_b := _noise(seed_val + 12, 0.008, 2)
	var base := _noise(seed_val + 13, 0.011, 4)
	var ridge := _noise(seed_val + 14, 0.015, 5, true)
	var mask := _noise(seed_val + 15, 0.0055, 2)
	var basin := _noise(seed_val + 16, 0.012, 3)
	var dryn := _noise(seed_val + 191, 0.011, 2)

	# 1 + 2: raw relief
	for y in H:
		for x in W:
			var i := y * W + x
			var wx := x + warp_a.get_noise_2d(x, y) * 24.0
			var wy := y + warp_b.get_noise_2d(x, y) * 24.0
			var north := 1.0 - float(y) / H
			var b := base.get_noise_2d(wx, wy)
			var mk := clampf((north - 0.4) * 2.0, 0.0, 1.0) * 0.8 + (mask.get_noise_2d(wx, wy) * 0.5 + 0.5) * 0.6 - 0.28
			var m := smoothstep(0.22, 0.8, mk)
			var r := clampf(ridge.get_noise_2d(wx, wy) * 0.5 + 0.5, 0.0, 1.0)
			var v := 2.6 + b * 2.8 + north * 2.5 + m * (4.0 + pow(r, 1.7) * 36.0)
			var bs := basin.get_noise_2d(x, y)
			if bs < -0.16:
				v -= (-0.16 - bs) * 26.0 * (1.0 - m) # lowland basins that will hold lakes
			var d := dryn.get_noise_2d(x, y) * 0.5 + 0.5 + (float(x) / W - 0.5) * 0.7 + (float(y) / H - 0.5) * 0.35
			if m > 0.3:
				d = 0.0
			dry[i] = d
			if d > 0.78:
				v = lerpf(v, 1.6 + b * 0.9, 0.85) # desert basin
			mountain[i] = m
			height[i] = v

	# 3: erosion
	var order: Array = range(n)
	var recv := PackedInt32Array()
	recv.resize(n)
	var acc := PackedFloat32Array()
	acc.resize(n)
	for it in 6:
		order.sort_custom(func(a, b): return height[a] > height[b])
		for i in n:
			var x := i % W
			var y := i / W
			var best := -1
			var best_slope := 0.0
			for k in 8:
				var nx: int = x + NB[k].x
				var ny: int = y + NB[k].y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				var j := ny * W + nx
				var s := (height[i] - height[j]) / (1.0 if k < 4 else 1.414)
				if s > best_slope:
					best_slope = s
					best = j
			recv[i] = best
		acc.fill(1.0)
		for i: int in order:
			if recv[i] >= 0:
				acc[recv[i]] += acc[i]
		for i: int in order:
			var r := recv[i]
			if r < 0 or dry[i] > 0.78:
				continue
			var drop := height[i] - height[r]
			# stream power law: erosion grows with drainage area and slope
			height[i] -= minf(0.045 * sqrt(acc[i]) * drop, drop * 0.55)
		for i: int in order:
			var r := recv[i]
			if r < 0:
				continue
			var drop := height[i] - height[r]
			if drop > 2.4: # too steep to hold: slump toward the angle of repose
				var mv := (drop - 2.4) * 0.3
				height[i] -= mv
				height[r] += mv

	# flat-topped sandstone mesas, added after erosion so their rims stay sharp
	var mesan := _noise(seed_val + 191, 0.044, 2)
	for y in H:
		for x in W:
			var i := y * W + x
			if dry[i] > 0.8 and mesan.get_noise_2d(x + 500.0, y) * 0.5 + 0.5 > 0.63:
				mesa[i] = 1
				height[i] += 4.6 + floorf(mesan.get_noise_2d(x * 0.3, y * 0.3 + 90.0) * 2.5) * 0.9

	# keep all land above the surrounding sea level
	var lowest := 1e9
	for i in n:
		lowest = minf(lowest, height[i])
	if lowest < 0.8:
		for i in n:
			height[i] += 0.8 - lowest

	# 4: fill depressions and build the drainage tree
	var fill := height.duplicate()
	var seen := PackedByteArray()
	seen.resize(n)
	var drain := PackedInt32Array()
	drain.resize(n)
	drain.fill(-1)
	var seq := PackedInt32Array()
	for y in H:
		for x in W:
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				var i := y * W + x
				seen[i] = 1
				_push(fill[i], i)
	while _hv.size() > 0:
		var c := _pop()
		seq.append(c)
		var x := c % W
		var y := c / W
		for k in 8:
			var nx: int = x + NB[k].x
			var ny: int = y + NB[k].y
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var j := ny * W + nx
			if seen[j] == 1:
				continue
			seen[j] = 1
			fill[j] = maxf(height[j], fill[c] + 0.0004)
			drain[j] = c
			_push(fill[j], j)
	acc.fill(1.0)
	for k in range(seq.size() - 1, -1, -1):
		var i := seq[k]
		if drain[i] >= 0:
			acc[drain[i]] += acc[i]

	# lakes: wherever the filled surface stands well above the ground
	for i in n:
		if fill[i] - height[i] > 0.4 and dry[i] <= 0.78:
			level[i] = fill[i]
		elif fill[i] - height[i] > 0.0:
			height[i] = fill[i] # shallow puddles become level ground
	# 5: rivers
	var cands: Array = []
	for i in n:
		if level[i] != NO_WATER or dry[i] > 0.78 or drain[i] < 0:
			continue
		var x := i % W
		var y := i / W
		if acc[i] > 170.0 and x > 0 and y > 0 and x < W - 1 and y < H - 1:
			river[i] = 1
			var drop := height[i] - fill[drain[i]]
			if drop > 1.3:
				cands.append([drop * sqrt(acc[i]), Vector2i(x, y)])
	for i in n:
		if river[i] == 1:
			level[i] = height[i] - 0.04
			height[i] -= 0.4
	cands.sort_custom(func(a, b): return a[0] > b[0])
	for c in cands:
		falls.append(c[1])


func _push(key: float, value: int) -> void:
	_hk.append(key)
	_hv.append(value)
	var i := _hv.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if _hk[p] <= _hk[i]:
			break
		var tk := _hk[p]
		var tv := _hv[p]
		_hk[p] = _hk[i]
		_hv[p] = _hv[i]
		_hk[i] = tk
		_hv[i] = tv
		i = p


func _pop() -> int:
	var top := _hv[0]
	var last := _hv.size() - 1
	_hk[0] = _hk[last]
	_hv[0] = _hv[last]
	_hk.resize(last)
	_hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var s := i
		if l < last and _hk[l] < _hk[s]: s = l
		if r < last and _hk[r] < _hk[s]: s = r
		if s == i:
			break
		var tk := _hk[s]
		var tv := _hv[s]
		_hk[s] = _hk[i]
		_hv[s] = _hv[i]
		_hk[i] = tk
		_hv[i] = tv
		i = s
	return top
