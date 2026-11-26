class_name Ecology
extends RefCounted
## The living park: a food web of species populations, animals with their own
## behaviour, invasive species, wildfire, water quality, and what your
## researchers actually know about all of it.

class Animal:
	var sp := 0
	var pos := Vector2.ZERO
	var target := Vector2.ZERO
	var timer := 0.0
	var flip := false
	var phase := 0.0
	var anchor := Vector2.ZERO
	var moving := false
	var flee := 0.0 # seconds left running from people or a predator
	var prey = null # wolves: the elk being chased
	var herd := 0
	var hidden := false # hibernating
	var graze := false
	var doing := "wandering"

var g
var w: World
var rng := RandomNumberGenerator.new()
var pops: Array[float] = []
var base: Array[float] = []
var caps: Array[float] = []
var trend: Array[float] = []
var know: Array[float] = [] # 0..1: how well each species has been studied
var animals: Array[Animal] = []
var hab_tiles: Array = []
var health := 100.0
var water_quality := 1.0
var habitat_ratio := 1.0
var runoff := 0.0 # pollution pulse washed in by rain
var surveys := 0
var _sight_timer := 0.0
var _invasive_warned := 0
var _status_warned := {}
var _ix := {}
var _confirmed := {}


func _init(game) -> void:
	g = game
	w = game.world
	rng.seed = game.rng.randi()
	for i in D.SPECIES.size():
		_ix[D.SPECIES[i].id] = i
		pops.append(0.0)
		base.append(1.0)
		caps.append(1.0)
		trend.append(0.0)
		know.append(0.0)
		hab_tiles.append([] as Array[Vector2i])
	_compute_caps()
	for i in D.SPECIES.size():
		base[i] = maxf(caps[i], 1.0)
		pops[i] = base[i]
	_sync_animals()
	_compute_health()


func sp_index(id: String) -> int:
	return _ix.get(id, -1)


func ratio(i: int) -> float:
	return pops[i] / base[i]


func r(id: String) -> float:
	return ratio(_ix[id])


func status(i: int) -> String:
	var v := ratio(i)
	if pops[i] < 0.5: return "Gone"
	if v > 1.25: return "Overabundant"
	if v >= 0.9: return "Thriving"
	if v >= 0.7: return "Stable"
	if v >= 0.45: return "Declining"
	if v >= 0.2: return "Threatened"
	return "Critical"


func zone_dry_desert() -> bool:
	return g.zone_dry[D.BIOME.DESERT] >= 7


## 0 = never studied, 1 = rough impressions, 2 = well understood.
func known(i: int) -> int:
	if know[i] >= 0.5: return 2
	if know[i] >= 0.15: return 1
	return 0


## How much of the ecosystem your researchers understand (0..1).
func understanding() -> float:
	var s := 0.0
	for k in know:
		s += minf(1.0, k * 1.6)
	return s / know.size()


# -------------------------------------------------------------- populations

func _compute_caps() -> void:
	var n := World.W * World.H
	var water_n := 0
	var bad := 0.0
	for i in n:
		if w.is_water(w.terrain[i]):
			water_n += 1
			bad += minf(1.0, w.litter[i] * 0.6 + w.invasive[i] + maxf(0.0, w.disturb[i] - 0.2) * 1.6)
	water_quality = clampf(1.0 - bad / maxf(1.0, water_n * 0.25) - runoff, 0.0, 1.0)

	var by_terrain := {}
	for si in D.SPECIES.size():
		caps[si] = 0.0
		(hab_tiles[si] as Array).clear()
		for t in D.SPECIES[si].habitat:
			if not by_terrain.has(t):
				by_terrain[t] = []
			by_terrain[t].append(si)
	var total_q := 0.0
	var og: int = _ix["oldgrowth"]
	for i in n:
		var q := w.quality[i]
		if w.burned[i] > 0:
			q *= 0.4
		total_q += q
		var ter := w.terrain[i]
		if not by_terrain.has(ter) or q <= 0.0:
			continue
		for si: int in by_terrain[ter]:
			var sp: Dictionary = D.SPECIES[si]
			if si == og and w.trees[i] == 0:
				continue
			if sp.has("biomes"):
				if not (w.biome[i] in sp.biomes):
					continue
			elif w.biome[i] == D.BIOME.DESERT and (D.T.WATER in sp.habitat):
				continue # shoreline species do not live on dry desert sand
			caps[si] += pow(q, 1.0 + float(sp.sens) * 0.6) * float(sp.density)
			if q > 0.3 and (i % 3 == 0 or sp.vis > 0 and i % 2 == 0):
				(hab_tiles[si] as Array).append(Vector2i(i % World.W, i / World.W))
	habitat_ratio = clampf(1.0 - (1.0 - total_q / w.pristine_total) * 3.0, 0.0, 1.0)
	caps[_ix["trout"]] *= 0.25 + 0.75 * water_quality
	caps[_ix["salamander"]] *= 0.4 + 0.6 * water_quality
	caps[_ix["beaver"]] *= 0.6 + 0.4 * water_quality
	caps[_ix["heron"]] *= 0.4 + 0.6 * water_quality
	var orchid := 0.0
	for i in n:
		orchid += w.rare[i]
	caps[_ix["orchid"]] = orchid


## Links between species: who eats, pollinates or shelters whom.
func _apply_food_web() -> void:
	var wolf := minf(1.0, r("wolf"))
	var elk := r("elk")
	var bee := minf(1.0, r("bee"))
	var flower := r("wildflower")
	var beaver := minf(1.0, r("beaver"))
	var trout := r("trout")
	var overgraze := clampf(elk - 1.1, 0.0, 1.0)
	caps[_ix["elk"]] *= 1.0 + 0.6 * (1.0 - wolf)
	caps[_ix["wolf"]] *= clampf(elk, 0.3, 1.1)
	caps[_ix["wildflower"]] *= (1.0 - 0.6 * overgraze) * (0.55 + 0.45 * bee)
	caps[_ix["bee"]] *= clampf(flower, 0.1, 1.2)
	caps[_ix["oldgrowth"]] *= 1.0 - 0.15 * overgraze
	caps[_ix["salamander"]] *= 0.8 + 0.2 * beaver
	caps[_ix["trout"]] *= 0.85 + 0.15 * beaver
	caps[_ix["eagle"]] *= clampf(trout + 0.15, 0.2, 1.0)
	caps[_ix["fox"]] *= 0.9 + 0.1 * minf(1.0, flower)
	# weather and a slowly warming climate
	var warm: float = g.climate
	caps[_ix["trout"]] *= 1.0 - minf(0.5, 0.06 * warm)
	caps[_ix["goat"]] *= 1.0 - minf(0.4, 0.04 * warm)
	caps[_ix["pika"]] *= 1.0 - minf(0.85, 0.14 * warm)
	caps[_ix["heron"]] *= 0.7 + 0.3 * minf(1.0, trout)
	if zone_dry_desert():
		caps[_ix["bighorn"]] *= 0.8
	if g.drought:
		caps[_ix["wildflower"]] *= 0.8
		caps[_ix["trout"]] *= 0.85
		caps[_ix["salamander"]] *= 0.8
		caps[_ix["bee"]] *= 0.85
	# fire scars burst into flower for a few seasons
	var scars := 0
	for i in w.burned.size():
		if w.burned[i] > 0:
			scars += 1
	caps[_ix["wildflower"]] += scars * 0.6

	if g.staffing.count("eco") > 0:
		if overgraze > 0.08 and wolf < 0.75:
			g.discover("cascade", "Trophic cascade", "With few wolves left, elk are multiplying and grazing the meadows bare. Wildflowers, bees and young trees are all paying for it. Protect quiet backcountry so wolves can recover.")
		if bee < 0.7:
			g.discover("pollinators", "Pollinator decline", "Native bees are disappearing along with the wildflowers they feed on. Each makes the other's decline worse.")
		if water_quality < 0.8:
			g.discover("runoff", "Polluted runoff", "Oil, litter and sediment are washing off roads and parking into the water. Trout and salamanders are the first to suffer. Keep paving back from shorelines.")
		if warm >= 0.3 and r("pika") < 0.85:
			g.discover("pika", "Running out of mountain", "Pikas are vanishing from the lower talus slopes as summers warm. They can only move uphill, and the peaks are a dead end.")
		if warm >= 0.3:
			g.discover("climate", "A warming climate", "Summers are getting hotter and the snowpack thinner each year. Cold-water trout and mountain goats have less room; droughts and fires are more likely.")
		if scars > 5:
			g.discover("fire", "Fire and renewal", "Burned ground is already flushing with wildflowers. Many western forests evolved with periodic fire; it is the severe, human-started fires in drought that do lasting harm.")
		if beaver > 0.9 and know[_ix["beaver"]] > 0.5:
			g.discover("engineers", "Ecosystem engineers", "Beaver ponds are sheltering young trout and salamanders. Protecting one keystone species props up many others.")


func _compute_health() -> void:
	var s := 0.0
	for i in D.SPECIES.size():
		s += clampf(ratio(i), 0.0, 1.0) - maxf(0.0, ratio(i) - 1.25) * 0.5
	s /= D.SPECIES.size()
	health = clampf(100.0 * (0.35 * habitat_ratio + 0.5 * s + 0.15 * water_quality), 0.0, 100.0)


func daily() -> void:
	_update_orchids()
	_recover_burns()
	runoff = maxf(0.0, runoff - 0.08)
	_compute_caps()
	_apply_food_web()
	var boost := 1.25 if g.has_tech("monitor") else 1.0
	if g.has_tech("restore"):
		boost *= 1.15
	var order := ["Thriving", "Stable", "Overabundant", "Declining", "Threatened", "Critical", "Gone"]
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
				if know[i] > 0.15:
					g.say("%s have returned to the park!" % sp.name, "good")
		elif pops[i] > k:
			pops[i] -= (pops[i] - k) * 0.22
		else:
			pops[i] += float(sp.growth) * boost * pops[i] * (1.0 - pops[i] / maxf(k, 0.01))
		trend[i] = pops[i] - before
		know[i] = maxf(0.0, know[i] - 0.01)
		var st := status(i)
		var was: String = _status_warned.get(i, "Thriving")
		if st != was:
			if order.find(st) > order.find(was) and order.find(st) >= 2 and know[i] >= 0.3:
				g.say("Your ecologists report: %s are now %s." % [sp.name.to_lower(), st.to_lower()], "bad" if order.find(st) >= 4 else "warn")
			_status_warned[i] = st
	_sync_animals()
	_compute_health()


## Recomputes derived values after loading a save.
func daily_refresh() -> void:
	_compute_caps()
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


# ------------------------------------------------------------------ research

## An ecologist finished a field survey at `t`: learn about whatever lives there.
func survey(t: Vector2i) -> void:
	surveys += 1
	var gain := 0.012 * (1.5 if g.has_tech("monitor") else 1.0)
	var seen_terrain := {}
	var orchid_near := false
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			if not World.inb(t.x + dx, t.y + dy):
				continue
			var i := World.idx(t.x + dx, t.y + dy)
			if absi(dx) <= 2 and absi(dy) <= 2:
				seen_terrain[w.terrain[i]] = true
			if w.rare[i] > 0.0:
				orchid_near = true
			if w.invasive[i] > 0.0 and w.inv_seen[i] == 0:
				_detect(Vector2i(t.x + dx, t.y + dy))
	for i in D.SPECIES.size():
		var sp: Dictionary = D.SPECIES[i]
		var hit: bool = sp.id == "orchid" and orchid_near
		for ter in sp.habitat:
			if seen_terrain.has(ter):
				hit = true
		if hit:
			var before := known(i)
			know[i] = minf(1.0, know[i] + gain)
			if before < 2 and known(i) == 2:
				g.say("Field notes complete: %s. %s" % [sp.name, D.NOTES[sp.id]], "good")
				g.add_research(4.0)
			elif before == 0 and known(i) == 1 and not _confirmed.has(i):
				_confirmed[i] = true
				g.say("Your ecologists have confirmed %s in the park." % sp.name.to_lower(), "info", t)


func _detect(t: Vector2i) -> void:
	var i := World.ti(t)
	if w.inv_seen[i] == 1 or w.invasive[i] <= 0.0:
		return
	w.inv_seen[i] = 1
	w.changed.emit(Rect2i(t, Vector2i(1, 1)))
	var water := w.is_water(w.terrain[i])
	g.discover("invasive_water" if water else "invasive_land",
		"Invasive %s" % ("milfoil" if water else "thistle"),
		"An invasive plant has arrived, probably carried in on %s. With no natural enemies here it spreads fast and crowds out natives. It was only found because someone was looking." % ("boats and waders" if water else "boots and tyres"), t)


func seen_invasive_count() -> int:
	var c := 0
	for i: int in w.invasive_tiles.keys():
		if w.inv_seen[i] == 1:
			c += 1
	return c


# ------------------------------------------------------- invasives and fire

func hourly() -> void:
	var active: int = g.visitors.groups.size()
	if g.day >= 3 and active > 0:
		var p := 0.012 * (1.0 + active / 25.0)
		if g.has_tech("bootbrush"):
			p *= 0.45
		if rng.randf() < p:
			_introduce()
	var keys := w.invasive_tiles.keys()
	for i: int in keys:
		var v := minf(1.0, w.invasive[i] + 0.035)
		w.invasive[i] = v
		var t := Vector2i(i % World.W, i / World.W)
		if v >= 0.85 and w.inv_seen[i] == 0:
			_detect(t) # too big to miss: visitors report it
		if v > 0.5 and rng.randf() < (0.08 if g.weather_at(t) == "rain" else 0.05) and keys.size() < 700:
			var nb: Vector2i = t + World.DIRS[rng.randi() % 4]
			if _can_invade(nb, w.is_water(w.terrain[i])):
				w.set_invasive(nb, 0.2)
	if not keys.is_empty():
		w.fields_dirty = true
		var seen := seen_invasive_count()
		if seen >= _invasive_warned * 2 + 12:
			_invasive_warned = seen
			g.say("Known invasive patches now cover %d tiles and are spreading. Send ecologists or use the Remove Invasives tool." % seen, "warn")
	else:
		_invasive_warned = 0
	_fire_tick()
	# rain washes whatever is on paved ground toward the water
	var dirty := 0
	for t in w.lot_tiles:
		var wt: String = g.weather_at(t)
		if (wt == "rain" or wt == "storm") and w._near_terrain(t.x, t.y, 3, [D.T.WATER, D.T.DEEP]):
			dirty += 1
	if dirty > 0:
		runoff = minf(0.6, runoff + dirty * 0.0025 + w.litter_tiles.size() * 0.0006)


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
		if _can_invade(t, w.is_water(w.terrain[World.ti(t)])):
			w.set_invasive(t, 0.3) # nobody knows yet
			w.fields_dirty = true
			return


func ignite(t: Vector2i, hours: int = 6) -> void:
	var i := World.ti(t)
	if w.fire[i] > 0 or w.trees[i] == 0 or w.build[i] != D.B.NONE:
		return
	w.fire[i] = hours
	w.fire_tiles[i] = true
	w.changed.emit(Rect2i(t, Vector2i(1, 1)))


func put_out(t: Vector2i) -> void:
	var i := World.ti(t)
	w.fire[i] = 0
	w.fire_tiles.erase(i)
	w.changed.emit(Rect2i(t, Vector2i(1, 1)))


func _fire_tick() -> void:
	# rain and snow put fires out, zone by zone
	for i: int in w.fire_tiles.keys():
		var t := Vector2i(i % World.W, i / World.W)
		var wt: String = g.weather_at(t)
		if wt == "rain" or wt == "snow":
			put_out(t)
	# ignition: lightning, or careless campfires where it is hot and dry
	if g.season() != 3 and w.fire_tiles.is_empty():
		for attempt in 3:
			var t := Vector2i(rng.randi_range(2, World.W - 3), rng.randi_range(2, World.H - 3))
			var wt: String = g.weather_at(t)
			var human := false
			var p := 0.0
			if wt == "storm":
				p = 0.02
			elif wt == "heat" or g.drought_at(t):
				var srcs: Array = []
				for s in w.structures.values():
					if s.kind == D.B.CAMP or s.kind == D.B.PICNIC:
						srcs.append(s.tile)
				if srcs.is_empty():
					continue
				var st: Vector2i = srcs[rng.randi() % srcs.size()]
				t = st + Vector2i(rng.randi_range(-2, 3), rng.randi_range(-2, 3))
				if not World.inb(t.x, t.y) or not (g.weather_at(t) == "heat" or g.drought_at(t)):
					continue
				p = 0.006 * srcs.size()
				human = true
			if p > 0.0 and rng.randf() < p and w.trees[World.ti(t)] > 0 and w.build[World.ti(t)] == D.B.NONE:
				ignite(t)
				g.say("Wildfire in the %s! %s Rangers will fight it; rain would stop it." % [D.BIOME_NAMES[w.biome[World.ti(t)]].to_lower(),
					"An escaped campfire in dry conditions." if human else "A lightning strike."], "bad", t)
				break
	for i: int in w.fire_tiles.keys():
		var t := Vector2i(i % World.W, i / World.W)
		var chance := 0.42 if (g.drought_at(t) or g.weather_at(t) == "heat") else 0.24
		if w.fire_tiles.size() < 260:
			for d in World.DIRS:
				var nb := t + d
				if World.inb(nb.x, nb.y) and rng.randf() < chance:
					var j := World.ti(nb)
					if w.burned[j] == 0:
						ignite(nb, 5)
		w.fire[i] -= 1
		if w.fire[i] <= 0:
			w.fire[i] = 0
			w.fire_tiles.erase(i)
			w.trees[i] = 0
			w.burned[i] = 10
			w.rare[i] = 0.0
			w.fields_dirty = true
			w.changed.emit(Rect2i(t, Vector2i(1, 1)))


func _recover_burns() -> void:
	for i in w.burned.size():
		if w.burned[i] == 0:
			continue
		w.burned[i] -= 1
		if w.burned[i] == 0:
			if w.build[i] == D.B.NONE and rng.randf() < 0.6:
				w.trees[i] = 2 if w.height[i] > 6.0 else 3
			w.fields_dirty = true
			w.changed.emit(Rect2i(i % World.W, i / World.W, 1, 1))


# -------------------------------------------------------------------- animals

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
		if not a.hidden and a.pos.distance_squared_to(c) < 250.0 * 250.0:
			near += 1
	var s := 0.0
	var count := 0
	for i in D.SPECIES.size():
		if D.SPECIES[i].kind == "animal":
			s += minf(1.0, ratio(i))
			count += 1
	s /= count
	var score := (q / maxf(1.0, n)) * 0.5 + minf(0.5, near * 0.07) + s * 0.2
	if g.has_tech("monitor"):
		score += 0.15
	return clampf(score, 0.0, 1.2)


func _sync_animals() -> void:
	for si in D.SPECIES.size():
		var sp: Dictionary = D.SPECIES[si]
		if sp.vis <= 0:
			continue
		var want := int(round(float(sp.vis) * minf(1.6, ratio(si))))
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
			a.herd = have / 5
			a.pos = World.center(tiles[rng.randi() % tiles.size()]) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			if sp.id == "elk" and have % 5 != 0:
				# join the herd leader
				for o in animals:
					if o.sp == si and o.herd == a.herd:
						a.pos = o.pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
						break
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
	var night: bool = g.is_night()
	var winter: bool = g.season() == 3
	for a in animals:
		var sp: Dictionary = D.SPECIES[a.sp]
		var id: String = sp.id
		a.phase += dt
		a.hidden = id == "bear" and winter # bears den up for the winter
		if a.hidden:
			a.moving = false
			a.doing = "hibernating"
			continue
		if id == "eagle":
			a.anchor = a.anchor.move_toward(a.target, 18.0 * dt)
			var ang := a.phase * 0.7
			a.pos = a.anchor + Vector2(cos(ang) * 80.0, sin(ang) * 50.0)
			a.moving = true
			a.doing = "soaring, watching for fish"
			if a.anchor.distance_squared_to(a.target) < 16.0:
				_pick_target(a, sp)
			continue
		var speed := float(sp.speed)
		if a.flee > 0.0:
			a.flee -= dt
			speed *= 2.4
			a.timer = 0.0
			a.doing = "fleeing"
		elif a.prey != null:
			var prey: Animal = a.prey
			if not animals.has(prey):
				a.prey = null
			else:
				a.target = prey.pos
				speed *= 1.7
				a.timer = 0.0
				a.doing = "hunting elk"
				var d2 := a.pos.distance_squared_to(prey.pos)
				if d2 < 110.0 * 110.0 and prey.flee <= 0.0:
					_scare(prey, a.pos, 3.5)
				if d2 < 12.0 * 12.0:
					_predation(a, prey)
		elif night and (id == "bear" or id == "fox" or id == "wolf"):
			speed *= 1.3
		if a.timer > 0.0:
			a.timer -= dt
			a.moving = false
			a.graze = id == "elk" or id == "goat" or id == "bighorn"
			if a.graze: a.doing = "grazing" if not night else "bedded down"
			elif id == "beaver": a.doing = "gnawing and building"
			elif id == "heron": a.doing = "standing motionless, fishing"
			elif id == "pika": a.doing = "gathering hay for winter"
			elif id == "trout": a.doing = "holding in the current"
			else: a.doing = "resting"
			continue
		a.graze = false
		var before := a.pos
		a.pos = a.pos.move_toward(a.target, speed * dt)
		a.moving = true
		if a.flee <= 0.0 and a.prey == null:
			a.doing = "on the move"
		if a.pos.x != before.x:
			a.flip = a.pos.x < before.x
		if a.pos.distance_squared_to(a.target) < 4.0:
			var rest := rng.randf_range(1.0, 6.0)
			if night and (id == "elk" or id == "goat"):
				rest *= 3.0
			a.timer = rest if a.flee <= 0.0 else 0.3
			_pick_target(a, sp)
	_sight_timer -= dt
	if _sight_timer <= 0.0:
		_sight_timer = 0.5
		_sightings()


func _scare(a: Animal, from: Vector2, secs: float) -> void:
	var away := a.pos - from
	if away.length_squared() < 1.0:
		away = Vector2(1, 0)
	var dest := a.pos + away.normalized() * 150.0
	var t := World.tile_of(dest)
	if w.is_water(w.terrain[World.ti(t)]):
		dest = a.pos + away.normalized().rotated(1.2) * 120.0
	a.target = dest.clamp(Vector2(8, 8), Vector2(World.W, World.H) * D.TILE - Vector2(8, 8))
	a.flee = secs
	a.timer = 0.0


func _predation(wolf: Animal, elk: Animal) -> void:
	wolf.prey = null
	wolf.timer = 14.0
	wolf.doing = "feeding"
	var ei: int = _ix["elk"]
	pops[ei] = maxf(0.0, pops[ei] - 0.3)
	var tiles: Array = hab_tiles[ei]
	if not tiles.is_empty():
		elk.pos = World.center(tiles[rng.randi() % tiles.size()])
		elk.target = elk.pos
		elk.flee = 0.0
	if g.staffing.count("eco") > 0:
		g.discover("predation", "Predator and prey", "Your ecologists watched wolves bring down an elk. Predators take the weak and keep herds moving, which gives overgrazed meadows time to recover.", World.tile_of(wolf.pos))


func _pick_target(a: Animal, sp: Dictionary) -> void:
	var id: String = sp.id
	var here := World.tile_of(a.pos if id != "eagle" else a.anchor)
	if id == "bear" and not w.litter_tiles.is_empty() and rng.randf() < 0.5:
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
			a.doing = "following the smell of litter"
			return
	if id == "wolf" and a.prey == null and rng.randf() < 0.3:
		var ei: int = _ix["elk"]
		var best = null
		var bd := 14.0 * D.TILE
		bd *= bd
		for o in animals:
			if o.sp == ei:
				var d := o.pos.distance_squared_to(a.pos)
				if d < bd:
					bd = d
					best = o
		if best != null:
			a.prey = best
			return
	var center := here
	if id == "elk":
		# stay with the herd: follow the first elk of the group
		for o in animals:
			if o.sp == a.sp and o.herd == a.herd:
				if o != a:
					center = World.tile_of(o.target)
				break
	var hour: float = g.minutes / 60.0
	var thirsty := (hour > 6.0 and hour < 8.0) or (hour > 18.0 and hour < 20.0)
	var reach := 6 if id == "eagle" else (2 if id == "trout" or id == "salamander" else 4)
	var best := a.pos
	var best_q := -1.0
	for k in 7:
		var t := center + Vector2i(rng.randi_range(-reach, reach), rng.randi_range(-reach, reach))
		if thirsty and k < 3 and id != "trout" and id != "eagle":
			t = here + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		if not World.inb(t.x, t.y):
			continue
		var i := World.ti(t)
		if not (w.terrain[i] in sp.habitat) or w.build[i] != D.B.NONE or w.fire[i] > 0:
			continue
		if sp.has("biomes") and not (w.biome[i] in sp.biomes):
			continue
		if id == "trout":
			var mid := World.tile_of((a.pos + World.center(t)) * 0.5)
			if not w.is_water(w.terrain[World.ti(mid)]):
				continue
		var q := w.quality[i] + rng.randf() * 0.4
		if thirsty and w._near_terrain(t.x, t.y, 1, [D.T.WATER]):
			q += 1.0
		if g.weather_at(t) == "rain" and w.terrain[i] == D.T.FOREST:
			q += 0.4 # shelter under the trees
		if q > best_q:
			best_q = q
			best = World.center(t) + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
	if best_q < 0.0 and id != "eagle":
		var tiles: Array = hab_tiles[a.sp]
		if not tiles.is_empty() and rng.randf() < 0.3:
			a.pos = World.center(tiles[rng.randi() % tiles.size()])
			best = a.pos
	a.target = best


func _sightings() -> void:
	var r2 := 80.0 * 80.0
	for a in animals:
		if a.hidden:
			continue
		var sp: Dictionary = D.SPECIES[a.sp]
		var id: String = sp.id
		if id == "trout" or id == "salamander":
			continue
		for gr in g.visitors.groups:
			if gr.state != Visitors.S.WALK and gr.state != Visitors.S.DWELL:
				continue
			var p: Vector2 = gr.pos_at(gr.dist) if gr.state == Visitors.S.WALK else World.center(gr.cur)
			var rr := r2 * (2.5 if id == "eagle" else 1.0)
			var d2 := p.distance_squared_to(a.pos)
			if d2 > rr:
				continue
			if not gr.seen.has(a.sp):
				gr.seen[a.sp] = true
				gr.sat += 7.0 if gr.vt.id == "naturalist" else 3.5
				if rng.randf() < 0.5:
					gr.last_thought = "We saw a %s!" % sp.name.to_lower()
					g.comment("We saw wildlife up close")
			if id == "bear":
				g.staffing.bear_encounter(gr, World.tile_of(p))
			elif (id == "elk" or id == "fox" or id == "goat" or id == "wolf" or id == "bighorn" or id == "heron" or id == "pika") and d2 < 62.0 * 62.0 and a.flee <= 0.0:
				a.prey = null
				_scare(a, p, 2.0) # people push wary animals off their feeding grounds
