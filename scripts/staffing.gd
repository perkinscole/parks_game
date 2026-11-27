class_name Staffing
extends RefCounted
## Park staff (rangers, maintenance, ecologists) and visitor emergencies.

enum S { IDLE, MOVING, WORKING }

const FIRST := ["Ana", "Ben", "Chloe", "Dev", "Elena", "Finn", "Grace", "Hiro", "Imani", "Jonas", "Kira", "Leo", "Maya", "Noor", "Omar", "Priya", "Quinn", "Rosa", "Sam", "Tessa"]
const INCIDENT_TITLES := {
	"injury": "A hiker is injured",
	"lost": "Hikers are lost",
	"fall": "A climber has fallen",
	"bear": "Dangerous bear encounter",
	"night": "Hikers are stranded after dark",
}
const SEVERITY_NAMES := ["", "minor", "serious", "life-threatening"]

class Staff:
	var role := ""
	var name := ""
	var pos := Vector2.ZERO
	var pts := PackedVector2Array()
	var dist := 0.0
	var state := 0
	var timer := 0.0
	var job := ""
	var target := Vector2i(-1, -1)
	var claim := -1
	var home := 0
	var incident = null
	var done := 0

class Incident:
	var kind := ""
	var title := ""
	var tile := Vector2i()
	var group
	var timer := 0.0
	var ranger = null
	var treating := false
	var severity := 2 # 1 minor, 2 serious, 3 life-threatening
	var eta := -1.0 # seconds until a rescue team or helicopter arrives; -1 if none sent
	var by := ""
	var post := 0

var tally := {} # how emergencies have gone, for the record
var busy := {} # rescue post or helipad id -> seconds until its team is free again

var g
var w: World
var rng := RandomNumberGenerator.new()
var staff: Array[Staff] = []
var incidents: Array[Incident] = []
var claims := {}
var unreachable := {}


func _init(game) -> void:
	g = game
	w = game.world
	rng.seed = game.rng.randi()


func count(role: String) -> int:
	var c := 0
	for s in staff:
		if s.role == role:
			c += 1
	return c


func capacity(role: String) -> int:
	return w.count_kind(D.STAFF[role].home) * 3


func daily_wages() -> float:
	var total := 0.0
	for s in staff:
		total += D.STAFF[s.role].wage
	return total


func _home_for(role: String) -> Dictionary:
	var opts: Array = []
	for s in w.structures.values():
		if s.kind == D.STAFF[role].home:
			opts.append(s)
	if opts.is_empty():
		return {}
	return opts[rng.randi() % opts.size()]


func hire(role: String) -> String:
	if count(role) >= capacity(role):
		return "Build a %s first (3 per building)" % D.BUILD[D.STAFF[role].home].name
	var home := _home_for(role)
	var s := Staff.new()
	s.role = role
	s.name = FIRST[rng.randi() % FIRST.size()]
	s.home = home.id
	var ht: Vector2i = home.tile
	s.pos = World.center(ht) + Vector2(16, 40)
	staff.append(s)
	return ""


func fire(role: String) -> void:
	for i in range(staff.size() - 1, -1, -1):
		if staff[i].role == role:
			_release(staff[i])
			staff.remove_at(i)
			return


func _release(s: Staff) -> void:
	if s.claim >= 0:
		claims.erase(s.claim)
		s.claim = -1
	if s.incident != null:
		s.incident.ranger = null
		s.incident = null


func daily() -> void:
	unreachable.clear()
	for role in D.STAFF.keys():
		var lost := false
		while count(role) > capacity(role):
			fire(role)
			lost = true
		if lost:
			g.say("Some %s staff had to be let go: their building was demolished." % D.STAFF[role].name.to_lower(), "warn")


func ranger_near(t: Vector2i, r: float) -> bool:
	var c := World.center(t)
	var rr := r * D.TILE
	for s in staff:
		if s.role == "ranger" and s.pos.distance_squared_to(c) < rr * rr:
			return true
	return false


# ---------------------------------------------------------------- incidents

func maybe_incident(gr, t: Vector2i) -> void:
	var i := World.ti(t)
	var ter := w.terrain[i]
	var p: float = 0.0004 * (0.5 + gr.n * 0.25)
	if ter == D.T.ROCK: p *= 3.0
	elif ter == D.T.PEAK: p *= 6.0
	elif w.is_water(ter): p *= 2.0
	if w.build[i] != D.B.TRAIL:
		p *= 0.3
	else:
		# the steeper the ground, the more the quality of the trail matters
		var grade: int = w.trail_grade[i]
		var steep := w.slope_at(t)
		p *= [1.5, 1.0, 0.6, 0.5, 2.2][grade] * (1.0 + steep * [6.0, 2.5, 0.4, 0.8, 5.0][grade])
		if steep > 0.6 and w.sign_cover[i] == 0:
			p *= 1.8 # nobody warned them
	if g.has_tech("trails"): p *= 0.6
	p *= float(D.WEATHER[g.weather_at(t)].risk)
	var kind := "injury"
	# a faint path is easy to wander off: people lose it sooner and far more often
	var faint: bool = w.build[i] == D.B.TRAIL and w.trail_grade[i] == 0
	if gr.walked > (10 if faint else 22) and rng.randf() < (0.6 if faint else 0.45):
		kind = "lost"
		p = 0.0011 if not gr.registered else 0.0004
		if faint: p *= 3.0
	if w.sign_cover[i] == 1: p *= 0.3
	if rng.randf() >= p:
		return
	if ranger_near(t, 7.0):
		if rng.randf() < 0.6:
			return
	create(kind, gr, t)


func crag_risk(gr) -> void:
	var p := 0.06
	if w.sign_cover[World.ti(gr.cur)] == 1: p *= 0.5
	if ranger_near(gr.cur, 7.0): p *= 0.5
	if rng.randf() < p:
		create("fall", gr, gr.cur)


func bear_encounter(gr, t: Vector2i) -> void:
	if gr.bear_cd > 0.0 or gr.state == Visitors.S.WAIT_HELP:
		return
	gr.bear_cd = 40.0
	var p := 0.1
	var litter_near := false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if World.inb(t.x + dx, t.y + dy) and w.litter[World.idx(t.x + dx, t.y + dy)] > 0:
				litter_near = true
	if litter_near: p *= 3.5
	if g.has_tech("bins") and w.bin_cover[World.ti(t)] == 1: p *= 0.15
	if ranger_near(t, 7.0): p *= 0.3
	if rng.randf() < p:
		create("bear", gr, t)


func create(kind: String, gr, t: Vector2i) -> void:
	var inc := Incident.new()
	inc.kind = kind
	inc.title = INCIDENT_TITLES[kind]
	inc.tile = t
	inc.group = gr
	# how bad is it?
	var crit := {"injury": 0.04, "lost": 0.03, "fall": 0.2, "bear": 0.07, "night": 0.08}[kind] as float
	var i := World.ti(t)
	if kind == "injury":
		crit += minf(0.3, w.slope_at(t) * 0.25)
	if kind == "night" or kind == "lost":
		if g.season() == 3 or w.biome[i] == D.BIOME.ALPINE: crit += 0.15
		var wx: String = g.weather_at(t)
		if wx == "snow" or wx == "storm": crit += 0.1
	var roll := rng.randf()
	inc.severity = 3 if roll < crit else (2 if roll < crit + 0.5 else 1)
	inc.timer = [0.0, 30.0, 40.0, 34.0][inc.severity]
	if g.has_tech("sar"): inc.timer *= 1.5
	if w.call_cover[i] == 1: inc.timer *= 1.5
	tally[kind] = tally.get(kind, 0) + 1
	tally["sev%d" % inc.severity] = tally.get("sev%d" % inc.severity, 0) + 1
	incidents.append(inc)
	gr.state = Visitors.S.WAIT_HELP
	gr.cur = t
	gr.pts = PackedVector2Array()
	var help := _dispatch(inc)
	if help == "":
		help = "A ranger is needed." if count("ranger") > 0 else "You have no rangers to help."
	g.say("%s (%s)! They can hold on about %d seconds. %s" % [inc.title, SEVERITY_NAMES[inc.severity], int(inc.timer), help], "warn" if inc.severity < 3 else "bad", t)


## Sends the best rescue the park owns. Minor trouble is left to the rangers;
## serious cases get the rescue team if one is in range; the helicopter flies
## for anything life-threatening, or serious and too far for anyone else.
func _dispatch(inc: Incident) -> String:
	if inc.severity < 2:
		return ""
	var best_id := 0
	var best_eta := 1e9
	var best_by := ""
	for s in w.structures.values():
		if busy.get(s.id, 0.0) > 0.0:
			continue
		var d := Vector2(Vector2i(s.tile) - inc.tile).length()
		var eta := 1e9
		if s.kind == D.B.SAR and d <= 60.0:
			eta = 4.0 + d * 0.38
		elif s.kind == D.B.HELIPAD and g.money >= 600.0 and (inc.severity == 3 or d > 45.0):
			eta = 7.0 + d * 0.04
		if eta < best_eta:
			best_eta = eta
			best_id = s.id
			best_by = "team" if s.kind == D.B.SAR else "heli"
	if best_id == 0:
		return ""
	inc.eta = best_eta
	inc.by = best_by
	inc.post = best_id
	busy[best_id] = best_eta * 2.0 + 6.0
	if best_by == "heli":
		g.add_money(-600.0, "Rescue flights")
		return "The helicopter is on its way: about %d seconds ($600)." % int(best_eta)
	return "The rescue team is on its way: about %d seconds." % int(best_eta)


func _close(inc: Incident, serious: bool) -> void:
	incidents.erase(inc)
	if inc.ranger != null:
		inc.ranger.incident = null
	var gr = inc.group
	if serious and inc.severity >= 3:
		g.deaths += 1
		g.safety = maxf(0.0, g.safety - 22.0)
		g.serious_incidents += 1
		g.last_serious_day = g.day
		g.add_money(-6000.0, "Fines & liability")
		for k in 6:
			g.record_rating(0.0)
		g.comment("Someone died out there and no one could reach them")
		var lesson := "Rangers on foot were too far away."
		if w.count_kind(D.B.SAR) == 0 and w.count_kind(D.B.HELIPAD) == 0:
			lesson = "The park has no rescue team that could reach them in time."
		elif inc.eta > 0.0:
			lesson = "Help was on its way but too far off. A call box, hut or rescue post nearer the far trails would have bought the time."
		g.say("A visitor has died. %s %s (-$6,000, and the news travels.)" % [inc.title, lesson], "bad", inc.tile)
		g.visitors.remove_group(gr)
		return
	if serious:
		g.safety = maxf(0.0, g.safety - 14.0)
		g.serious_incidents += 1
		g.last_serious_day = g.day
		g.add_money(-1200.0, "Fines & liability")
		gr.sat = 5.0
		g.comment("Someone got badly hurt and nobody came to help")
		g.say("%s and no help arrived in time. The park's reputation suffers (-$1,200)." % inc.title, "bad", inc.tile)
	else:
		g.safety = maxf(0.0, g.safety - 0.8)
	g.visitors.leave_dwell(gr)
	gr.plan_i = gr.plan.size()
	g.visitors.next_leg(gr)


func update(dt: float) -> void:
	var k := incidents.size() - 1
	while k >= 0:
		var inc := incidents[k]
		if inc.eta >= 0.0:
			inc.eta -= dt
			if inc.eta <= 0.0:
				inc.group.sat -= 4.0
				inc.group.last_thought = "The rescue team got us out"
				g.comment("The rescue team was there when it mattered")
				g.say("%s: %s. Everyone is safe." % ["The helicopter lifted them out" if inc.by == "heli" else "The rescue team reached them", inc.title.to_lower()], "good", inc.tile)
				_close(inc, false)
				k -= 1
				continue
		if not inc.treating:
			inc.timer -= dt
			if inc.timer <= 0.0:
				if inc.severity == 1 or (inc.severity == 2 and rng.randf() < 0.35):
					inc.group.sat -= 20.0
					_close(inc, false)
				else:
					_close(inc, true)
		k -= 1
	for id in busy.keys():
		busy[id] -= dt
		if busy[id] <= 0.0:
			busy.erase(id)
	for s in staff:
		_update_staff(s, dt)


func _update_staff(s: Staff, dt: float) -> void:
	match s.state:
		S.IDLE:
			s.timer -= dt
			if s.timer <= 0.0:
				_pick_job(s)
		S.MOVING:
			if s.role == "ranger" and s.job != "rescue" and _unassigned_incident() != null:
				_pick_job(s)
				return
			var spd := 52.0
			if s.role == "ranger":
				spd = 95.0 if g.has_tech("sar") else 68.0
				if s.job == "patrol": spd *= 0.7
			s.dist += spd * dt
			var L := (s.pts.size() - 1) * float(D.TILE)
			s.pos = Paths.pos(s.pts, s.dist)
			if s.dist >= L:
				s.state = S.WORKING
				match s.job:
					"clean": s.timer = 1.2
					"fire": s.timer = 2.5
					"weed": s.timer = 3.0
					"survey": s.timer = 4.0
					"rescue":
						s.timer = 2.5
						if s.incident != null:
							s.incident.treating = true
					_: s.timer = 2.0
		S.WORKING:
			s.timer -= dt
			if s.timer <= 0.0:
				_finish_job(s)


func _finish_job(s: Staff) -> void:
	match s.job:
		"clean":
			w.clear_litter(s.target)
			w.fields_dirty = true
			s.done += 1
		"weed":
			w.set_invasive(Vector2i(s.claim % World.W, s.claim / World.W), 0.0)
			w.fields_dirty = true
			g.add_research(0.5)
			s.done += 1
		"survey":
			g.add_research(0.4 * (0.5 + g.eco.health / 100.0))
			g.eco.survey(s.target)
			s.done += 1
		"fire":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var ft: Vector2i = s.target + Vector2i(dx, dy)
					if World.inb(ft.x, ft.y) and w.fire[World.ti(ft)] > 0:
						g.eco.put_out(ft)
			s.done += 1
		"rescue":
			if s.incident != null:
				var inc: Incident = s.incident
				inc.group.sat -= 6.0
				inc.group.last_thought = "A ranger rescued us"
				g.comment("A ranger helped us when we were in trouble")
				g.say("Ranger %s resolved an emergency." % s.name, "good", inc.tile)
				_close(inc, false)
				s.done += 1
	if s.claim >= 0:
		claims.erase(s.claim)
		s.claim = -1
	s.state = S.IDLE
	s.timer = 0.4
	s.job = ""


func _unassigned_incident() -> Incident:
	for inc in incidents:
		if inc.ranger == null:
			return inc
	return null


func _go(s: Staff, target: Vector2i, job: String) -> bool:
	var from := World.tile_of(s.pos)
	if w.staff_nav.is_point_solid(from):
		# standing somewhere odd (e.g. station was moved): hop to nearest walkable
		for d in World.DIRS:
			if World.inb(from.x + d.x, from.y + d.y) and not w.staff_nav.is_point_solid(from + d):
				from = from + d
				break
	var p := w.staff_nav.get_id_path(from, target)
	if p.is_empty():
		return false
	s.pts = w.to_points(p)
	s.pts[0] = s.pos
	s.dist = 0.0
	s.target = target
	s.job = job
	s.state = S.MOVING
	return true


func _nearest(keys: Array, from: Vector2i, land_adjacent: bool) -> Array:
	# returns [key, walk_target] of the closest unclaimed, reachable tile
	var best := -1
	var bd := 1e9
	for i: int in keys:
		if claims.has(i) or unreachable.has(i):
			continue
		var t := Vector2i(i % World.W, i / World.W)
		var d := float((t - from).length_squared())
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return []
	var t := Vector2i(best % World.W, best / World.W)
	if w.staff_nav.is_point_solid(t):
		if land_adjacent:
			for d in World.DIRS:
				var nb := t + d
				if World.inb(nb.x, nb.y) and not w.staff_nav.is_point_solid(nb):
					return [best, nb]
		unreachable[best] = true
		return []
	return [best, t]


func _pick_job(s: Staff) -> void:
	_release(s)
	s.state = S.IDLE
	s.timer = 1.0
	var here := World.tile_of(s.pos)
	match s.role:
		"ranger":
			var inc := _unassigned_incident()
			if inc != null:
				if _go(s, inc.tile, "rescue"):
					inc.ranger = s
					s.incident = inc
					return
			if not w.fire_tiles.is_empty():
				var fr := _nearest(w.fire_tiles.keys(), here, true)
				if not fr.is_empty() and _go(s, fr[1], "fire"):
					s.claim = fr[0]
					claims[fr[0]] = true
					return
			var target := Vector2i(-1, -1)
			if not w.trail_tiles.is_empty():
				target = w.trail_tiles[rng.randi() % w.trail_tiles.size()]
			elif not w.lot_tiles.is_empty():
				target = w.lot_tiles[rng.randi() % w.lot_tiles.size()]
			if target.x >= 0:
				_go(s, target, "patrol")
		"maint":
			var r := _nearest(w.litter_tiles.keys(), here, true)
			if not r.is_empty():
				if _go(s, r[1], "clean"):
					s.claim = r[0]
					s.target = Vector2i(int(r[0]) % World.W, int(r[0]) / World.W)
					claims[r[0]] = true
				else:
					unreachable[r[0]] = true
			else:
				_go_home(s)
		"eco":
			var known: Array = []
			for ik: int in w.invasive_tiles.keys():
				if w.inv_seen[ik] == 1:
					known.append(ik)
			var r := _nearest(known, here, true)
			if not r.is_empty():
				if _go(s, r[1], "weed"):
					s.claim = r[0]
					claims[r[0]] = true
				else:
					unreachable[r[0]] = true
				return
			if not w.structures.has(s.home):
				return
			var ht: Vector2i = w.structures[s.home].tile
			for attempt in 8:
				var t := ht + Vector2i(rng.randi_range(-14, 14), rng.randi_range(-14, 14))
				if World.inb(t.x, t.y) and w.build[World.ti(t)] == D.B.NONE and not w.staff_nav.is_point_solid(t) \
						and w.terrain[World.ti(t)] != D.T.PEAK:
					if _go(s, t, "survey"):
						return


func _go_home(s: Staff) -> void:
	s.timer = 3.0
	if not w.structures.has(s.home):
		return
	var home: Dictionary = w.structures[s.home]
	var ht: Vector2i = home.tile
	var t := ht + Vector2i(0, 2)
	if World.inb(t.x, t.y) and World.tile_of(s.pos) != t and not w.staff_nav.is_point_solid(t):
		if _go(s, t, "rest"):
			return
