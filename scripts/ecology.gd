class_name Ecology
extends RefCounted
## Species populations, wandering animals, invasive species, water quality
## and the overall ecosystem health score.

class Animal:
	var sp := 0
	var pos := Vector2.ZERO
	var target := Vector2.ZERO
	var timer := 0.0
	var flip := false
	var phase := 0.0
	var anchor := Vector2.ZERO
	var moving := false

var g
var w: World
var rng := RandomNumberGenerator.new()
var pops: Array[float] = []
var base: Array[float] = []
var caps: Array[float] = []
var trend: Array[float] = []
var animals: Array[Animal] = []
var hab_tiles: Array = []
var health := 100.0
var water_quality := 1.0
var habitat_ratio := 1.0
var colonies_start := 0
var _sight_timer := 0.0
var _invasive_warned := 0
var _status_warned := {}


func _init(game) -> void:
	g = game
	w = game.world
	rng.seed = game.rng.randi()
	for s in D.SPECIES:
		pops.append(0.0)
		base.append(1.0)
		caps.append(1.0)
		trend.append(0.0)
		hab_tiles.append([] as Array[Vector2i])
	for i in w.rare.size():
		if w.rare[i] > 0.0:
			colonies_start += 1
	_compute_caps()
	for i in D.SPECIES.size():
		base[i] = maxf(caps[i], 1.0)
		pops[i] = base[i]
	_sync_animals()
	_compute_health()


func sp_index(id: String) -> int:
	for i in D.SPECIES.size():
		if D.SPECIES[i].id == id:
			return i
	return -1


func ratio(i: int) -> float:
	return pops[i] / base[i]


func status(i: int) -> String:
	var r := ratio(i)
	if pops[i] < 0.5: return "Gone"
	if r >= 0.9: return "Thriving"
	if r >= 0.7: return "Stable"
	if r >= 0.45: return "Declining"
	if r >= 0.2: return "Threatened"
	return "Critical"


func _compute_caps() -> void:
	var n := World.W * World.H
	var water_n := 0
	var bad := 0.0
	for i in n:
		if w.is_water(w.terrain[i]):
			water_n += 1
			bad += minf(1.0, w.litter[i] * 0.6 + w.invasive[i] + maxf(0.0, w.disturb[i] - 0.2) * 1.6)
	water_quality = 1.0 - clampf(bad / maxf(1.0, water_n * 0.25), 0.0, 1.0)

	var by_terrain := {}
	for si in D.SPECIES.size():
		caps[si] = 0.0
		(hab_tiles[si] as Array).clear()
		for t in D.SPECIES[si].habitat:
			if not by_terrain.has(t):
				by_terrain[t] = []
			by_terrain[t].append(si)
	var total_q := 0.0
	for i in n:
		var q := w.quality[i]
		total_q += q
		var ter := w.terrain[i]
		if not by_terrain.has(ter) or q <= 0.0:
			continue
		for si: int in by_terrain[ter]:
			var sp: Dictionary = D.SPECIES[si]
			if sp.id == "oldgrowth" and w.trees[i] == 0:
				continue
			caps[si] += pow(q, 1.0 + float(sp.sens) * 0.6) * float(sp.density)
			if q > 0.3 and (i % 3 == 0 or sp.vis > 0 and i % 2 == 0):
				(hab_tiles[si] as Array).append(Vector2i(i % World.W, i / World.W))
	habitat_ratio = clampf(1.0 - (1.0 - total_q / w.pristine_total) * 3.0, 0.0, 1.0)
	var tr := sp_index("trout")
	caps[tr] *= 0.25 + 0.75 * water_quality
	caps[sp_index("salamander")] *= 0.4 + 0.6 * water_quality
	caps[sp_index("beaver")] *= 0.6 + 0.4 * water_quality
	if base[tr] > 1.0:
		caps[sp_index("eagle")] *= clampf(pops[tr] / base[tr] + 0.15, 0.2, 1.0)
	var orchid := 0.0
	for i in n:
		orchid += w.rare[i]
	caps[sp_index("orchid")] = orchid


func _compute_health() -> void:
	var s := 0.0
	for i in D.SPECIES.size():
		s += minf(1.0, ratio(i))
	s /= D.SPECIES.size()
	health = 100.0 * (0.35 * habitat_ratio + 0.5 * s + 0.15 * water_quality)


func daily() -> void:
	_update_orchids()
	_compute_caps()
	var boost := 1.25 if g.has_tech("monitor") else 1.0
	if g.has_tech("restore"):
		boost *= 1.15
	for i in D.SPECIES.size():
		var sp: Dictionary = D.SPECIES[i]
		var before := pops[i]
		var k := caps[i]
		if sp.id == "orchid":
			pops[i] = k
		elif pops[i] < 0.5:
			pops[i] = 0.0
			if k > base[i] * 0.4 and rng.randf() < 0.12:
				pops[i] = maxf(2.0, base[i] * 0.05)
				g.say("%s have returned to the park!" % sp.name, "good")
		elif pops[i] > k:
			pops[i] -= (pops[i] - k) * 0.22
		else:
			pops[i] += float(sp.growth) * boost * pops[i] * (1.0 - pops[i] / maxf(k, 0.01))
		trend[i] = pops[i] - before
		var st := status(i)
		if st != _status_warned.get(i, "Thriving"):
			var worse := ["Thriving", "Stable", "Declining", "Threatened", "Critical", "Gone"]
			if worse.find(st) > worse.find(_status_warned.get(i, "Thriving")) and worse.find(st) >= 2:
				g.say("%s population is now %s." % [sp.name, st.to_lower()], "bad" if worse.find(st) >= 3 else "warn")
			_status_warned[i] = st
	_sync_animals()
	_compute_health()


func _update_orchids() -> void:
	for y in World.H:
		for x in World.W:
			var i := World.idx(x, y)
			if w.rare[i] <= 0.0:
				continue
			var harm := 0.0
			var tramp := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if World.inb(x + dx, y + dy):
						var j := World.idx(x + dx, y + dy)
						harm += w.invasive[j] * 0.12
						tramp += w.footfall[j]
			if tramp > 25.0: harm += 0.08
			if w.disturb[i] > 0.45: harm += 0.05
			if harm > 0.0:
				w.rare[i] -= harm
			else:
				w.rare[i] = minf(1.0, w.rare[i] + 0.04)
			if w.rare[i] <= 0.0:
				w.rare[i] = 0.0
				g.say("A rare orchid colony has died out.", "bad", Vector2i(x, y))
				w.changed.emit(Rect2i(x, y, 1, 1))


func hourly() -> void:
	# introduction: seeds hitchhike in on boots, tyres and boats
	var active: int = g.visitors.groups.size()
	if g.day >= 3 and active > 0:
		var p := 0.012 * (1.0 + active / 25.0)
		if g.has_tech("bootbrush"):
			p *= 0.45
		if rng.randf() < p:
			_introduce()
	# spread
	var keys := w.invasive_tiles.keys()
	for i: int in keys:
		var v := minf(1.0, w.invasive[i] + 0.035)
		w.invasive[i] = v
		if v > 0.5 and rng.randf() < 0.05 and keys.size() < 400:
			var t := Vector2i(i % World.W, i / World.W)
			var nb: Vector2i = t + World.DIRS[rng.randi() % 4]
			if _can_invade(nb, w.is_water(w.terrain[i])):
				w.set_invasive(nb, 0.2)
	if not keys.is_empty():
		w.fields_dirty = true
		if keys.size() >= _invasive_warned * 2 + 12:
			_invasive_warned = keys.size()
			g.say("Invasive species now cover %d tiles and are spreading. Send ecologists or use the Remove Invasives tool." % keys.size(), "warn",
				Vector2i(keys[0] % World.W, keys[0] / World.W))
	else:
		_invasive_warned = 0


func _can_invade(t: Vector2i, water: bool) -> bool:
	if not World.inb(t.x, t.y):
		return false
	var i := World.ti(t)
	if w.build[i] != D.B.NONE or w.invasive[i] > 0.0 or w.landmark_at.has(i):
		return false
	var ter := w.terrain[i]
	if water:
		return ter == D.T.WATER
	return ter == D.T.GRASS or ter == D.T.MEADOW or ter == D.T.FOREST or ter == D.T.SAND


func _introduce() -> void:
	var sources: Array[Vector2i] = []
	sources.append_array(w.trail_tiles)
	sources.append_array(w.lot_tiles)
	if sources.is_empty():
		return
	for attempt in 12:
		var s: Vector2i = sources[rng.randi() % sources.size()]
		var t: Vector2i = s + World.DIRS[rng.randi() % 4]
		if not World.inb(t.x, t.y):
			continue
		var water := w.is_water(w.terrain[World.ti(t)])
		if _can_invade(t, water):
			w.set_invasive(t, 0.3)
			w.fields_dirty = true
			if w.invasive_tiles.size() == 1:
				g.say("Invasive %s spotted! It will spread and choke out native species if left alone." % ("milfoil" if water else "thistle"), "warn", t)
			return


## How rewarding wildlife watching is around a tile (0..1).
func wildlife_score(t: Vector2i) -> float:
	var q := 0.0
	var n := 0
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if World.inb(t.x + dx, t.y + dy):
				q += w.quality[World.idx(t.x + dx, t.y + dy)]
				n += 1
	var near := 0
	var c := World.center(t)
	for a in animals:
		if a.pos.distance_squared_to(c) < 250.0 * 250.0:
			near += 1
	var s := 0.0
	for i in D.SPECIES.size():
		if D.SPECIES[i].kind == "animal":
			s += minf(1.0, ratio(i))
	s /= 8.0
	var score := (q / maxf(1.0, n)) * 0.5 + minf(0.5, near * 0.07) + s * 0.2
	if g.has_tech("monitor"):
		score += 0.15
	return clampf(score, 0.0, 1.2)


func _sync_animals() -> void:
	for si in D.SPECIES.size():
		var sp: Dictionary = D.SPECIES[si]
		if sp.vis <= 0:
			continue
		var want := int(round(float(sp.vis) * minf(1.3, ratio(si))))
		if pops[si] >= 1.0:
			want = maxi(want, 1)
		var have := 0
		for a in animals:
			if a.sp == si:
				have += 1
		var tiles: Array = hab_tiles[si]
		while have < want and not tiles.is_empty():
			var a := Animal.new()
			a.sp = si
			a.pos = World.center(tiles[rng.randi() % tiles.size()]) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			a.target = a.pos
			a.anchor = a.pos
			a.timer = rng.randf() * 4.0
			a.phase = rng.randf() * TAU
			animals.append(a)
			have += 1
		var k := animals.size() - 1
		while have > want and k >= 0:
			if animals[k].sp == si:
				animals.remove_at(k)
				have -= 1
			k -= 1


func update(dt: float) -> void:
	for a in animals:
		var sp: Dictionary = D.SPECIES[a.sp]
		a.phase += dt
		if sp.id == "eagle":
			a.anchor = a.anchor.move_toward(a.target, 18.0 * dt)
			var ang := a.phase * 0.7
			var np := a.anchor + Vector2(cos(ang) * 80.0, sin(ang) * 50.0)
			a.flip = np.x < a.pos.x
			a.pos = np
			if a.anchor.distance_squared_to(a.target) < 16.0:
				_pick_target(a, sp)
			continue
		if a.timer > 0.0:
			a.timer -= dt
			a.moving = false
			continue
		var before := a.pos
		a.pos = a.pos.move_toward(a.target, float(sp.speed) * dt)
		a.moving = true
		if a.pos.x != before.x:
			a.flip = a.pos.x < before.x
		if a.pos.distance_squared_to(a.target) < 4.0:
			a.timer = rng.randf_range(1.0, 6.0)
			_pick_target(a, sp)
	_sight_timer -= dt
	if _sight_timer <= 0.0:
		_sight_timer = 0.5
		_sightings()


func _pick_target(a: Animal, sp: Dictionary) -> void:
	var here := World.tile_of(a.pos if sp.id != "eagle" else a.anchor)
	if sp.id == "bear" and not w.litter_tiles.is_empty() and rng.randf() < 0.5:
		var bd := 12.0 * 12.0
		var bt := Vector2i(-1, -1)
		for i: int in w.litter_tiles.keys():
			var t := Vector2i(i % World.W, i / World.W)
			var d := float((t - here).length_squared())
			if d < bd and not w.is_water(w.terrain[i]):
				bd = d
				bt = t
		if bt.x >= 0:
			a.target = World.center(bt)
			return
	var reach := 6 if sp.id == "eagle" else (2 if sp.id == "trout" or sp.id == "salamander" else 4)
	var best := a.pos
	var best_q := -1.0
	for k in 6:
		var t := here + Vector2i(rng.randi_range(-reach, reach), rng.randi_range(-reach, reach))
		if not World.inb(t.x, t.y):
			continue
		var i := World.ti(t)
		if not (w.terrain[i] in sp.habitat) or w.build[i] != D.B.NONE:
			continue
		if sp.id == "trout":
			var mid := World.tile_of((a.pos + World.center(t)) * 0.5)
			if not w.is_water(w.terrain[World.ti(mid)]):
				continue
		var q := w.quality[i] + rng.randf() * 0.4
		if q > best_q:
			best_q = q
			best = World.center(t) + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
	if best_q < 0.0 and sp.id != "eagle":
		# stranded in ruined habitat: relocate
		var tiles: Array = hab_tiles[a.sp]
		if not tiles.is_empty() and rng.randf() < 0.3:
			a.pos = World.center(tiles[rng.randi() % tiles.size()])
			best = a.pos
	a.target = best


func _sightings() -> void:
	var r2 := 80.0 * 80.0
	for a in animals:
		var sp: Dictionary = D.SPECIES[a.sp]
		if sp.id == "trout" or sp.id == "salamander":
			continue
		for gr in g.visitors.groups:
			if gr.state != Visitors.S.WALK and gr.state != Visitors.S.DWELL:
				continue
			var p: Vector2 = gr.pos_at(gr.dist) if gr.state == Visitors.S.WALK else World.center(gr.cur)
			var rr := r2 * (2.5 if sp.id == "eagle" else 1.0)
			if p.distance_squared_to(a.pos) > rr:
				continue
			if not gr.seen.has(a.sp):
				gr.seen[a.sp] = true
				gr.sat += 7.0 if gr.vt.id == "naturalist" else 3.5
				if rng.randf() < 0.5:
					gr.last_thought = "We saw a %s!" % sp.name.to_lower()
					g.comment("We saw wildlife up close")
			if sp.id == "bear":
				g.staffing.bear_encounter(gr, World.tile_of(p))
