class_name Visitors
extends RefCounted
## Visitor parties: they drive in, park, walk an itinerary of attractions and
## trails, then drive home and leave a rating.

enum S { DRIVE_IN, WALK, DWELL, DRIVE_OUT, WAIT_HELP, GONE }

const CAR_SPEED := 100.0
const WALK_SPEED := 46.0
const SHIRTS := ["e8554e", "f2a541", "f4d35e", "4fa3d1", "7e6bc4", "e77fb3", "3fae7a", "f08a5d", "ffffff", "2e4057"]
const SKINS := ["f6d3b3", "e9b98f", "c98f62", "8d5a3b", "f1c9a5"]
const CARS := ["d9534f", "4a90d9", "f0c040", "f5f5f5", "6c757d", "58b368", "8e6bbf", "ef8354", "2f3e46"]
const NAMES := ["Garcia", "Chen", "Okafor", "Patel", "Novak", "Kim", "Rossi", "Haddad", "Larsen", "Tanaka", "Mbeki", "Silva", "Cohen", "Dubois", "Yilmaz", "Reyes", "Nguyen", "Kowalski", "Singh", "Murphy"]

class Group:
	var id := 0
	var name := ""
	var vt: Dictionary
	var n := 1
	var looks: Array = []
	var car_color := Color.WHITE
	var state := 0
	var pts := PackedVector2Array()
	var dist := 0.0
	var speed := 46.0
	var lot := Vector2i()
	var slot := 0
	var plan: Array = []
	var plan_i := 0
	var timer := 0.0
	var sat := 52.0
	var cur := Vector2i()
	var last_tile := Vector2i(-1, -1)
	var registered := false # signed the trailhead register
	var night_checked := false
	var scen_sum := 0.0
	var scen_n := 0
	var litter_seen := 0
	var seen := {}
	var bear_cd := 0.0
	var spent := 0.0
	var walked := 0
	var dwell_sid := 0
	var rest_ok := false
	var returning := false
	var did_hike := false
	var last_thought := ""

	func length() -> float:
		return maxf(0.0, (pts.size() - 1) * float(D.TILE))

	func pos_at(d: float) -> Vector2:
		if pts.is_empty():
			return World.center(cur)
		return Paths.pos(pts, d)

	func dir_at(d: float) -> Vector2:
		return Paths.dir(pts, d)


var g
var w: World
var rng := RandomNumberGenerator.new()
var groups: Array[Group] = []
var arrive_acc := 0.0
var next_id := 1


func _init(game) -> void:
	g = game
	w = game.world
	rng.seed = game.rng.randi()


func people_count() -> int:
	var c := 0
	for gr in groups:
		c += gr.n
	return c


func update(dt: float) -> void:
	if g.open and g.minutes >= 7.0 * 60.0 and g.minutes < 15.5 * 60.0:
		arrive_acc += g.demand / 51.0 * dt
		while arrive_acc >= 1.0:
			arrive_acc -= 1.0
			_spawn()
	var i := groups.size() - 1
	while i >= 0:
		var gr := groups[i]
		_update_group(gr, dt)
		if gr.state == S.GONE:
			groups.remove_at(i)
		i -= 1


func _pick_type() -> Dictionary:
	var total := 0.0
	var opts: Array = []
	for vt in D.VTYPES:
		if vt.has("needs") and w.count_kind(vt.needs) == 0:
			continue
		opts.append(vt)
		total += vt.weight
	var r := rng.randf() * total
	for vt in opts:
		r -= vt.weight
		if r <= 0.0:
			return vt
	return opts[0]


func _lot_score(lot: Vector2i, vt: Dictionary) -> float:
	var best := 0.0
	for s in w.structures.values():
		var pref: float = vt.prefs.get(s.kind, 0.0)
		if pref <= 0.0:
			continue
		var r := w.walk_to_structure(lot, s)
		if r[0] >= 0 and r[0] <= vt.vrange:
			best = maxf(best, pref * (0.35 + float(s.quality)))
	return best


func _spawn() -> void:
	var vt := _pick_type()
	var best_lot := Vector2i(-1, -1)
	var best_score := -1.0
	var best_path: Array[Vector2i] = []
	var tries := 0
	var free: Array[Vector2i] = []
	for t in w.lot_tiles:
		if w.park_used[World.ti(t)] != 3:
			free.append(t)
	while tries < 4 and not free.is_empty():
		tries += 1
		var t: Vector2i = free[rng.randi() % free.size()]
		var p := w.car_nav.get_id_path(w.entry, t)
		if p.is_empty():
			continue
		var sc := _lot_score(t, vt) + rng.randf() * 0.3
		if sc > best_score:
			best_score = sc
			best_lot = t
			best_path = p
	if best_lot.x < 0:
		g.turned_away_today += 1
		if rng.randf() < 0.12:
			g.record_rating(35.0)
			g.comment("The parking lots were full, so we left")
		return
	var gr := Group.new()
	gr.id = next_id
	next_id += 1
	gr.vt = vt
	gr.name = "The %s party" % NAMES[rng.randi() % NAMES.size()]
	gr.n = rng.randi_range(1, 4) if vt.id != "family" else rng.randi_range(3, 5)
	for k in gr.n:
		gr.looks.append({shirt = Color(SHIRTS[rng.randi() % SHIRTS.size()]), skin = Color(SKINS[rng.randi() % SKINS.size()]),
			small = vt.id == "family" and k >= 2, hat = rng.randf() < 0.35})
	gr.car_color = Color(CARS[rng.randi() % CARS.size()])
	gr.lot = best_lot
	var li := World.ti(best_lot)
	gr.slot = 0 if (w.park_used[li] & 1) == 0 else 1
	w.park_used[li] |= (1 << gr.slot)
	gr.pts = w.to_points(best_path)
	gr.state = S.DRIVE_IN
	gr.speed = WALK_SPEED * rng.randf_range(0.9, 1.15)
	gr.cur = best_lot
	groups.append(gr)
	g.visitors_today += gr.n
	if g.fee > 0:
		g.add_money(g.fee, "Entry fees")
	var over: float = g.fee - g.fair_fee
	if over > 0.0:
		gr.sat -= minf(25.0, over * 1.8)
		if over > 3.0:
			_think(gr, "The entry fee is too expensive")
	elif over < -4.0:
		gr.sat += 3.0


func _think(gr: Group, text: String) -> void:
	gr.last_thought = text
	g.comment(text)


func _update_group(gr: Group, dt: float) -> void:
	gr.bear_cd = maxf(0.0, gr.bear_cd - dt)
	match gr.state:
		S.DRIVE_IN:
			gr.dist += CAR_SPEED * dt
			if gr.dist >= gr.length():
				_make_plan(gr)
				gr.cur = gr.lot
				if gr.plan.is_empty():
					gr.sat = minf(gr.sat, 25.0)
					_think(gr, "There was nothing to do here")
					gr.pts = PackedVector2Array()
					gr.state = S.DWELL
					gr.dwell_sid = 0
					gr.timer = 2.5
				else:
					next_leg(gr)
		S.WALK:
			# steep ground is slow going, uphill most of all
			var here := World.tile_of(gr.pos_at(gr.dist))
			var ahead := World.tile_of(gr.pos_at(gr.dist + D.TILE))
			var climb: float = w.height[World.ti(ahead)] - w.height[World.ti(here)]
			var hi := World.ti(here)
			var grade: int = w.trail_grade[hi] if w.build[hi] == D.B.TRAIL else 1
			var pace: float = [0.85, 1.0, 1.1][grade] / (1.0 + (2.4 if climb > 0.0 else 1.0) * [1.4, 1.0, 0.45][grade] * maxf(0.0, absf(climb) - 0.15))
			gr.dist += gr.speed * dt * maxf(pace, 0.22)
			# still out on the trail when the light goes
			if not gr.night_checked and (g.minutes >= 20.5 * 60.0 or g.minutes < 5.0 * 60.0) and w.build[hi] == D.B.TRAIL:
				gr.night_checked = true
				if w.hut_cover[hi] == 1:
					_think(gr, "We made it to shelter for the night")
					gr.sat += 4.0
				elif Vector2(here - gr.lot).length() > 14.0 and rng.randf() < (0.08 if gr.registered else 0.25):
					g.staffing.create("night", gr, here)
					return
			var t := World.tile_of(gr.pos_at(gr.dist))
			if t != gr.last_tile:
				gr.last_tile = t
				_enter_tile(gr, t)
				if gr.state != S.WALK:
					return
			if gr.dist >= gr.length():
				if gr.pts.size() > 0:
					gr.cur = World.tile_of(gr.pts[gr.pts.size() - 1])
				if gr.returning:
					_drive_out(gr)
				else:
					_begin_dwell(gr)
		S.DWELL:
			gr.timer -= dt
			if gr.timer <= 0.0:
				_finish_dwell(gr)
		S.DRIVE_OUT:
			gr.dist += CAR_SPEED * dt
			if gr.dist >= gr.length():
				gr.state = S.GONE
		S.WAIT_HELP:
			pass


func _make_plan(gr: Group) -> void:
	var vt := gr.vt
	var cands: Array = []
	for s in w.structures.values():
		var pref: float = vt.prefs.get(s.kind, 0.0)
		if pref <= 0.0:
			continue
		var r := w.walk_to_structure(gr.lot, s)
		if r[0] < 0 or r[0] > vt.vrange:
			continue
		cands.append({sid = s.id, score = pref * (0.35 + float(s.quality)) * rng.randf_range(0.7, 1.3), d = r[0]})
	cands.sort_custom(func(a, b): return a.score > b.score)
	var k := mini(cands.size(), rng.randi_range(1, int(vt.stops)))
	cands = cands.slice(0, k)
	cands.sort_custom(func(a, b): return a.d < b.d)
	for c in cands:
		gr.plan.append({sid = c.sid})
	var hike: float = vt.hike
	if not w.trail_tiles.is_empty() and (rng.randf() < hike or gr.plan.is_empty()):
		var best := Vector2i(-1, -1)
		var best_len := 5
		for j in 7:
			var t: Vector2i = w.trail_tiles[rng.randi() % w.trail_tiles.size()]
			var L := w.walk_nav.get_id_path(gr.lot, t).size()
			if L > best_len and L <= int(vt.vrange):
				best_len = L
				best = t
		if best.x >= 0:
			gr.plan.append({tile = best})
	if not gr.plan.is_empty() and rng.randf() < 0.35:
		for s in w.structures.values():
			if s.kind == D.B.RESTROOM:
				var r := w.walk_to_structure(gr.lot, s)
				if r[0] >= 0 and r[0] <= 12:
					gr.plan.insert(0, {sid = s.id})
					break


## Starts walking toward the next stop of the itinerary (or back to the car).
func next_leg(gr: Group) -> void:
	while gr.plan_i < gr.plan.size():
		var e: Dictionary = gr.plan[gr.plan_i]
		var target := Vector2i(-1, -1)
		if e.has("sid"):
			if w.structures.has(e.sid):
				var r := w.walk_to_structure(gr.cur, w.structures[e.sid])
				if r[0] >= 0:
					target = r[1]
		else:
			target = e.tile
		if target.x >= 0:
			var p := w.walk_nav.get_id_path(gr.cur, target)
			if not p.is_empty():
				gr.pts = w.to_points(p)
				gr.dist = 0.0
				gr.state = S.WALK
				return
		gr.plan_i += 1
	gr.returning = true
	var back := w.walk_nav.get_id_path(gr.cur, gr.lot)
	if back.size() <= 1:
		_drive_out(gr)
		return
	gr.pts = w.to_points(back)
	gr.dist = 0.0
	gr.state = S.WALK


func remove_group(gr: Group) -> void:
	w.park_used[World.ti(gr.lot)] &= ~(1 << gr.slot)
	gr.state = S.GONE


func _enter_tile(gr: Group, t: Vector2i) -> void:
	var i := World.ti(t)
	if w.sign_cover[i] == 1 and not gr.registered and w.build[i] == D.B.TRAIL:
		gr.registered = true # they have seen a map and know the way back
	gr.walked += 1
	w.footfall[i] += gr.n * 0.5
	if w.rest_cover[i] == 1:
		gr.rest_ok = true
	if w.build[i] == D.B.TRAIL and gr.walked % 2 == 0:
		gr.scen_sum += w.scenic(t)
		gr.scen_n += 1
	if w.litter[i] > 0:
		gr.litter_seen += 1
	var p := 0.004 * gr.n
	if w.bin_cover[i] == 1:
		p *= 0.1
	if g.has_tech("interp"):
		p *= 0.6
	if rng.randf() < p:
		w.add_litter(t)
	g.staffing.maybe_incident(gr, t)


func _begin_dwell(gr: Group) -> void:
	var e: Dictionary = gr.plan[gr.plan_i]
	gr.state = S.DWELL
	gr.dwell_sid = 0
	gr.timer = 3.0
	if e.has("sid") and w.structures.has(e.sid):
		var s: Dictionary = w.structures[e.sid]
		gr.dwell_sid = s.id
		s.visitors += gr.n
		s.visits += gr.n
		match s.kind:
			D.B.CAMP: gr.timer = 14.0
			D.B.CRAG: gr.timer = 12.0
			D.B.VISITOR_CENTER, D.B.PICNIC, D.B.HIDE: gr.timer = 7.0
			D.B.RESTROOM: gr.timer = 2.5
			_: gr.timer = 5.0
	else:
		gr.did_hike = true


func leave_dwell(gr: Group) -> void:
	if gr.dwell_sid != 0 and w.structures.has(gr.dwell_sid):
		var s: Dictionary = w.structures[gr.dwell_sid]
		s.visitors = maxi(0, s.visitors - gr.n)
	gr.dwell_sid = 0


func _finish_dwell(gr: Group) -> void:
	if gr.dwell_sid != 0 and w.structures.has(gr.dwell_sid):
		var s: Dictionary = w.structures[gr.dwell_sid]
		_apply_visit(gr, s)
		if gr.state == S.WAIT_HELP:
			return
	leave_dwell(gr)
	gr.plan_i += 1
	next_leg(gr)


func _apply_visit(gr: Group, s: Dictionary) -> void:
	var pref: float = gr.vt.prefs.get(s.kind, 0.5)
	var q: float = s.quality
	var def: Dictionary = D.BUILD[s.kind]
	var i := World.ti(gr.cur)
	var litter_p := 0.0
	if def.has("cap") and s.visitors > def.cap:
		gr.sat -= 4.0
		_think(gr, "%s was too crowded" % s.name)
	match s.kind:
		D.B.OVERLOOK:
			gr.sat += 20.0 * q * minf(pref, 1.2)
			if q > 0.85: _think(gr, "The view from %s was breathtaking" % s.name)
			elif q < 0.35: _think(gr, "The view from %s was disappointing" % s.name)
		D.B.VISITOR_CENTER:
			gr.sat += 8.0 * pref + (5.0 if g.has_tech("interp") else 0.0)
			var spend := gr.n * rng.randf_range(2.0, 7.0)
			g.add_money(spend, "Gift shop")
			if g.has_tech("interp") and rng.randf() < 0.3: _think(gr, "The ranger talk was fascinating")
		D.B.PICNIC:
			gr.sat += 4.0 + 8.0 * q * pref
			litter_p = 0.3
		D.B.SNACK:
			gr.sat += 5.0 * pref
			g.add_money(gr.n * rng.randf_range(5.0, 9.0), "Food & drink")
			litter_p = 0.45
		D.B.CAMP:
			gr.sat += 8.0 + 14.0 * q
			g.add_money(28.0, "Camping fees")
			litter_p = 0.3
			if q > 0.8: _think(gr, "Camping under the stars was magical")
		D.B.CRAG:
			gr.sat += 22.0
			_think(gr, "Great climbing routes")
			g.staffing.crag_risk(gr)
		D.B.HIDE:
			gr.sat += 4.0 + 18.0 * q * minf(pref, 1.3)
			if q > 0.7: _think(gr, "We watched so much wildlife from the hide")
			elif q < 0.3: _think(gr, "We sat in the hide and saw nothing")
		D.B.RESTROOM:
			gr.rest_ok = true
	if litter_p > 0.0:
		if w.bin_cover[i] == 1: litter_p *= 0.08
		if g.has_tech("interp"): litter_p *= 0.6
		if rng.randf() < litter_p:
			w.add_litter(gr.cur)


func _drive_out(gr: Group) -> void:
	_finalize(gr)
	w.park_used[World.ti(gr.lot)] &= ~(1 << gr.slot)
	var p := w.car_nav.get_id_path(gr.lot, w.entry)
	if p.is_empty():
		gr.state = S.GONE
		return
	gr.pts = w.to_points(p)
	gr.dist = 0.0
	gr.state = S.DRIVE_OUT


func _finalize(gr: Group) -> void:
	var hike: float = gr.vt.hike
	if gr.scen_n > 0:
		var avg := gr.scen_sum / gr.scen_n
		gr.sat += (avg - 0.4) * 30.0 * (0.3 + hike * 0.8)
		if avg > 0.75 and hike >= 0.5: _think(gr, "The trails here are gorgeous")
		elif avg < 0.12: _think(gr, "The walk was dull, all roads and parking lots")
	if gr.litter_seen > 0:
		gr.sat -= minf(16.0, gr.litter_seen * 2.0)
		if gr.litter_seen >= 3: _think(gr, "There was litter everywhere")
	if gr.walked > 24 and not gr.rest_ok:
		gr.sat -= 9.0
		_think(gr, "We couldn't find a restroom")
	if hike >= 0.5:
		if gr.did_hike and gr.walked >= 30:
			gr.sat += 5.0
		elif gr.walked < 18:
			gr.sat -= 10.0
			_think(gr, "There aren't enough trails to hike")
	gr.sat = clampf(gr.sat, 0.0, 100.0)
	g.record_rating(gr.sat)
	var acc: Array = g.sat_by_type.get(gr.vt.id, [0.0, 0])
	g.sat_by_type[gr.vt.id] = [acc[0] * 0.95 + gr.sat, acc[1] * 0.95 + 1.0]
	g.total_visitors += gr.n
	if gr.sat > 85.0 and rng.randf() < 0.25:
		var gift := rng.randf_range(5.0, 40.0) * (1.6 if g.has_tech("interp") else 1.0)
		g.add_money(gift, "Donations")
	if gr.sat > 88.0 and rng.randf() < 0.3:
		_think(gr, "What a wonderful park")
