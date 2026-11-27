class_name Game
extends Node
## Simulation root: clock, money, ratings, research, and the player's actions.

signal toast(text: String, kind: String, tile: Vector2i)

const NO_TILE := Vector2i(-1, -1)

var world: World
var visitors: Visitors
var eco: Ecology
var staffing: Staffing
var grants: Grants
var rng := RandomNumberGenerator.new()

var money := 40000.0
var fee := 10
var speed := 1
var minutes := 6.0 * 60.0
var day := 1
var ledger := {}
var ledger_prev := {}
var research := 0.0
var research_total := 0.0
var techs := {}
var safety := 100.0
var ratings: Array[float] = []
var stars := 3.0
var appeal := 0.0
var demand := 0.0
var fair_fee := 8.0
var total_visitors := 0
var visitors_today := 0
var visitors_yesterday := 0
var turned_away_today := 0
var serious_incidents := 0
var deaths := 0
var level := 1
signal leveled(lv: int)
var last_serious_day := -99
var comments := {}
var sat_by_type := {} # visitor type id -> [decayed sum, decayed count]
var open := false
var map_seed := 0
var weather := "clear"
var zone_weather: Array = ["clear", "clear", "clear", "clear", "clear"]
var zone_next: Array = ["clear", "clear", "clear", "clear", "clear"]
var zone_dry: Array = [0, 0, 0, 0, 0]
var drought := false
var climate := 0.0 # degrees of warming since the park opened
var discoveries: Array = []
var _last_hour := 6
var _field_timer := 0.0
var _warned := {}


func setup(seed_val: int) -> void:
	map_seed = seed_val
	rng.seed = seed_val
	world = World.new()
	world.generate(seed_val)
	staffing = Staffing.new(self)
	eco = Ecology.new(self)
	visitors = Visitors.new(self)
	grants = Grants.new(self)
	update_appeal()


func _process(delta: float) -> void:
	if speed <= 0:
		return
	var total := minf(delta, 0.05) * speed
	var steps := int(ceil(total / 0.07))
	for s in steps:
		step(total / steps)


func step(dt: float) -> void:
	minutes += dt * (60.0 if is_night() else 10.0)
	if minutes >= 1440.0:
		minutes -= 1440.0
	var h := int(minutes / 60.0)
	if h != _last_hour:
		_last_hour = h
		_on_hour(h)
	visitors.update(dt)
	eco.update(dt)
	staffing.update(dt)
	_field_timer -= dt
	if world.fields_dirty and _field_timer <= 0.0:
		world.recompute_fields()
		_field_timer = 1.5


func is_night() -> bool:
	return minutes >= 22.0 * 60.0 or minutes < 6.0 * 60.0


func season() -> int:
	return ((day - 1) / D.DAYS_PER_SEASON) % 4


func year() -> int:
	return (day - 1) / (D.DAYS_PER_SEASON * 4) + 1


func date_text() -> String:
	var h := int(minutes / 60.0)
	var m := int(minutes) % 60
	return "%s %d, Year %d   %02d:%02d" % [D.SEASONS[season()], (day - 1) % D.DAYS_PER_SEASON + 1, year(), h, m - m % 10]


func _on_hour(h: int) -> void:
	eco.hourly()
	update_appeal()
	_check_level()
	var ecologists := staffing.count("eco")
	if ecologists > 0:
		add_research(ecologists * 0.12 * (0.5 + eco.health / 100.0))
	if h == 6:
		_new_day()
	if h == 9 and not open and day > 1 and not _warned.has("closed%d" % day):
		_warned["closed%d" % day] = true
		say("The park is closed: you need a road from the highway, an entrance gate and a parking lot.", "warn")


func _new_day() -> void:
	day += 1
	_advance_weather()
	var wages := staffing.daily_wages()
	if wages > 0.0:
		add_money(-wages, "Wages")
	var upkeep := 0.0
	for i in World.W * World.H:
		var b := world.build[i]
		if b != D.B.NONE and world.sid[i] == 0:
			upkeep += D.BUILD[b].upkeep
	for s in world.structures.values():
		upkeep += D.BUILD[s.kind].upkeep
	add_money(-upkeep, "Upkeep")
	add_money(350.0 + stars * 40.0, "Federal funding")
	ledger_prev = ledger
	ledger = {}
	visitors_yesterday = visitors_today
	visitors_today = 0
	turned_away_today = 0
	safety = minf(100.0, safety + 4.0)
	for k in comments.keys():
		comments[k] = comments[k] * 0.6
		if comments[k] < 0.5:
			comments.erase(k)
	for i in world.footfall.size():
		world.footfall[i] *= 0.6
	world.fields_dirty = true
	eco.daily()
	staffing.daily()
	grants.daily()
	update_appeal()
	_check_level()
	if (day - 1) % D.DAYS_PER_SEASON == 0:
		say("%s has arrived." % D.SEASONS[season()], "info")
	save_game() # autosave every morning
	if money < 0.0:
		say("The park is in debt! Raise income or cut costs.", "bad")


# ------------------------------------------------------------------ economy

func add_money(amount: float, cat: String) -> void:
	money += amount
	ledger[cat] = ledger.get(cat, 0.0) + amount


func say(text: String, kind: String = "info", tile: Vector2i = NO_TILE) -> void:
	toast.emit(text, kind, tile)


func comment(text: String) -> void:
	comments[text] = comments.get(text, 0.0) + 1.0


func record_rating(sat: float) -> void:
	ratings.append(clampf(sat, 0.0, 100.0))
	if ratings.size() > 80:
		ratings.pop_front()
	var sum := 60.0 * 8.0
	for r in ratings:
		sum += r
	stars = sum / (ratings.size() + 8.0) / 20.0


## Weather differs across the park: each biome is its own weather zone.
func weather_at(t: Vector2i) -> String:
	return zone_weather[world.biome[World.ti(t)]]


func drought_at(t: Vector2i) -> bool:
	return zone_dry[world.biome[World.ti(t)]] >= 5 and season() != 3


func _roll_weather(zone: int, x: float) -> String:
	var s := season()
	var heat := 0.12 + climate * 0.12
	var wet := 1.0
	match zone:
		D.BIOME.DESERT:
			wet = 0.3
			heat += 0.3
		D.BIOME.WETLAND, D.BIOME.FOREST:
			wet = 1.25
		D.BIOME.ALPINE:
			# the high country stays wintry for longer and brews its own storms
			if s == 3: return "snow" if x < 0.65 else "clear"
			if s != 1: return "snow" if x < 0.32 else ("storm" if x < 0.42 else "clear")
			return "storm" if x < 0.2 else ("rain" if x < 0.35 else "clear")
	match s:
		0: return "rain" if x < 0.3 * wet else ("storm" if x < 0.3 * wet + 0.07 else "clear")
		1: return "heat" if x < heat else ("storm" if x < heat + 0.08 * wet else ("rain" if x < heat + 0.2 * wet else "clear"))
		2: return "rain" if x < 0.28 * wet else ("storm" if x < 0.28 * wet + 0.05 else "clear")
	if zone == D.BIOME.DESERT:
		return "rain" if x < 0.1 else "clear"
	return "snow" if x < 0.4 else "clear"


func _advance_weather() -> void:
	var front := rng.randf() # weather systems often cover several zones at once
	for z in zone_weather.size():
		zone_weather[z] = zone_next[z]
		zone_next[z] = _roll_weather(z, front if rng.randf() < 0.55 else rng.randf())
		var wz: String = zone_weather[z]
		if wz == "rain" or wz == "storm" or wz == "snow":
			zone_dry[z] = 0
		else:
			zone_dry[z] += 2 if wz == "heat" else 1
	weather = zone_weather[world.biome[World.ti(world.entry)]]
	var was := drought
	drought = (zone_dry[D.BIOME.FOREST] >= 5 or zone_dry[D.BIOME.VALLEY] >= 5) and season() != 3
	if drought and not was:
		say("Drought: it has not rained in days. Streams are low, meadows are browning and fire danger is high.", "warn")
	var storms: Array = []
	var hot: Array = []
	for z in zone_weather.size():
		if zone_weather[z] == "storm": storms.append(D.BIOME_NAMES[z].to_lower())
		elif zone_weather[z] == "heat": hot.append(D.BIOME_NAMES[z].to_lower())
	if not storms.is_empty():
		say("Thunderstorms over the %s today: more accidents there, and lightning can start fires." % " and ".join(storms), "warn")
	if not hot.is_empty():
		say("Heatwave in the %s. Fire danger is high." % " and ".join(hot), "warn")
	if (day - 1) % (D.DAYS_PER_SEASON * 4) == 0 and day > 1:
		climate += 0.15
		if world.count_kind(D.B.RESEARCH) > 0:
			say("Your weather station's yearly summary: the park is now %.2f degrees warmer than when you started." % climate, "info")


## Records something your researchers have worked out about the ecosystem.
func discover(id: String, title: String, text: String, tile: Vector2i = NO_TILE) -> void:
	for d in discoveries:
		if d.id == id:
			return
	discoveries.append({id = id, title = title, text = text, day = day})
	say("Discovery: %s. %s" % [title, text], "good", tile)
	add_research(8.0)


func has_tech(id: String) -> bool:
	return techs.has(id)


func add_research(pts: float) -> void:
	research += pts
	research_total += pts


func unlock_tech(id: String) -> bool:
	for t in D.TECHS:
		if t.id == id and not techs.has(id) and research >= t.cost:
			research -= t.cost
			techs[id] = true
			if id == "trails":
				world.sustainable_trails = true
				world.fields_dirty = true
			say("Research complete: %s!" % t.name, "good")
			return true
	return false


func update_appeal() -> void:
	var per_kind := {}
	var a := 0.0
	for s in world.structures.values():
		var st: Vector2i = s.tile
		match s.kind:
			D.B.OVERLOOK: s.quality = world.scenic(st)
			D.B.CAMP, D.B.PICNIC: s.quality = 0.3 + world.scenic(st) * 0.6
			D.B.HIDE: s.quality = eco.wildlife_score(st)
			D.B.CRAG: s.quality = 0.7
			D.B.VISITOR_CENTER: s.quality = 0.8 if has_tech("interp") else 0.6
			_: s.quality = 0.5
		if s.kind in D.ATTRACTIONS and not s.access.is_empty():
			var base := 0.5 + float(s.quality)
			if s.kind == D.B.VISITOR_CENTER: base = 1.6
			elif s.kind == D.B.SNACK: base = 0.3
			var k: int = per_kind.get(s.kind, 0)
			a += base * pow(0.8, k)
			per_kind[s.kind] = k + 1
	a += minf(4.0, world.trail_tiles.size() / 40.0)
	appeal = a
	fair_fee = 6.0 + a * 1.6
	open = world.count_kind(D.B.GATE) > 0 and _lot_reachable()
	var fee_factor := clampf(exp(-(fee - fair_fee) / fair_fee * 1.3), 0.08, 1.35)
	var rating_factor := 0.35 + stars / 5.0 * 1.0
	var safety_factor := 0.6 + 0.4 * safety / 100.0
	demand = (5.0 + a * 11.0) * fee_factor * rating_factor * safety_factor * D.SEASON_DEMAND[season()] * float(D.WEATHER[weather].demand)
	if not open:
		demand = 0.0


func _lot_reachable() -> bool:
	for k in mini(6, world.lot_tiles.size()):
		var t: Vector2i = world.lot_tiles[rng.randi() % world.lot_tiles.size()]
		if world.car_nav.get_id_path(world.entry, t).size() > 0:
			return true
	return false


# ----------------------------------------------------------- player actions

## Tries to build. Returns "" on success or the reason for failure.
## Level a building or tool opens at.
func unlock_level(tool) -> int:
	var def: Dictionary = D.BUILD[tool] if tool is int else D.TOOLS[tool]
	return def.get("level", 1)


## How far along the park is toward its next level: [[label, have, need], ...]
func level_progress() -> Array:
	if level >= D.LEVELS.size():
		return []
	var nx: Dictionary = D.LEVELS[level]
	var out := [["Visitors welcomed", float(total_visitors), float(nx.visitors)], ["Visitor rating", stars, float(nx.stars)]]
	if nx.research > 0:
		out.append(["Research done", research_total, float(nx.research)])
	return out


func _check_level() -> void:
	if level >= D.LEVELS.size():
		return
	for row in level_progress():
		if row[1] < row[2]:
			return
	level += 1
	add_money(2500.0 * level, "Federal funding")
	say("The park is now a %s! New things to build are unlocked, with a %s grant to start on them." % [D.LEVELS[level - 1].name, D.money(2500.0 * level)], "good")
	leveled.emit(level)


## Lays or upgrades a trail of the given grade (0 rough, 1 graded, 2 built).
func build_trail(t: Vector2i, grade: int) -> String:
	var i := World.ti(t)
	var price: int = [5, 12, 45][grade]
	if world.build[i] == D.B.TRAIL:
		if world.trail_grade[i] >= grade:
			return "Already a trail"
		if money < price:
			return "Not enough money"
		world.trail_grade[i] = grade
		add_money(-price, "Construction")
		world.changed.emit(Rect2i(t.x - 1, t.y - 1, 3, 3))
		return ""
	var why := world.can_build(D.B.TRAIL, t)
	if why != "":
		return why
	var cost := world.cost_at(D.B.TRAIL, t) * price / 12
	if money < cost:
		return "Not enough money"
	var tree := world.trees[i]
	world.place(D.B.TRAIL, t)
	world.trail_grade[i] = grade
	if grade == 0 and tree > 0:
		world.trees[i] = tree # a rough path winds between the trees; nothing is felled
		world.changed.emit(Rect2i(t.x - 1, t.y - 1, 3, 3))
	add_money(-cost, "Construction")
	return ""


func try_build(kind: int, t: Vector2i, quiet: bool = false) -> String:
	if unlock_level(kind) > level:
		return "Unlocks when the park is a %s" % D.LEVELS[unlock_level(kind) - 1].name
	var why := world.can_build(kind, t)
	if why != "":
		return why
	var cost := world.cost_at(kind, t)
	if money < cost:
		return "Not enough money"
	var kills_orchid := false
	for c in world.footprint(kind, t):
		if world.rare[World.ti(c)] > 0.0:
			kills_orchid = true
	world.place(kind, t)
	add_money(-cost, "Construction")
	if kills_orchid:
		say("Construction destroyed a rare orchid colony!", "bad", t)
	if not quiet:
		update_appeal()
	return ""


func bulldoze(t: Vector2i) -> bool:
	if world.build[World.ti(t)] == D.B.NONE or money < 10:
		return false
	var kind := world.remove(t)
	if kind == D.B.NONE:
		return false
	add_money(-10.0, "Construction")
	return true


## One brush stroke of earthworks; charged per tile moved.
func terraform(c: Vector2i, mode: String, radius: float, level_h: float) -> int:
	var each: float = D.TOOLS[mode].cost
	if money < each * 4.0:
		return -1
	var n := world.terraform(c, mode, radius, 0.22, level_h)
	if n > 0:
		add_money(-each * n * 0.25, "Construction")
	return n


func plant_tree(t: Vector2i) -> bool:
	var i := World.ti(t)
	var ter := world.terrain[i]
	if not has_tech("restore") or money < 25 or world.build[i] != D.B.NONE or world.trees[i] > 0 \
			or world.landmark_at.has(i) or world.rare[i] > 0.0:
		return false
	if ter != D.T.GRASS and ter != D.T.FOREST and ter != D.T.MEADOW:
		return false
	world.trees[i] = 2 if world.height[i] > 6.0 else (3 if D.hash2(t.x, t.y, 2) < 0.5 else 1)
	if ter == D.T.GRASS:
		world.terrain[i] = D.T.FOREST
	world.fields_dirty = true
	world.changed.emit(Rect2i(t - Vector2i(1, 1), Vector2i(3, 3)))
	add_money(-25.0, "Conservation")
	return true


func weed(t: Vector2i) -> bool:
	if world.invasive[World.ti(t)] <= 0.0 or world.inv_seen[World.ti(t)] == 0 or money < 40:
		return false
	world.set_invasive(t, 0.0)
	world.fields_dirty = true
	add_money(-40.0, "Conservation")
	return true


func set_fee(v: int) -> void:
	fee = clampi(v, 0, 60)
	update_appeal()


# ------------------------------------------------------------- save and load
const SAVE_PATH := "user://wildlands_save.dat"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func read_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	return d if d is Dictionary and d.get("version", 0) == 3 else {}


## Everything that differs from a freshly generated map with this seed.
## Visitors are not saved: the park reopens empty.
func save_game() -> bool:
	var structs: Array = []
	for s in world.structures.values():
		structs.append({id = s.id, kind = s.kind, tile = s.tile, size = s.size, name = s.name, visits = s.visits})
	var roles: Array = []
	for s in staffing.staff:
		roles.append(s.role)
	var d := {
		version = 3, level = level, deaths = deaths, trail_grade = world.trail_grade, seed = map_seed, day = day, minutes = minutes, money = money, fee = fee, research = research,
		research_total = research_total, techs = techs, safety = safety, ratings = ratings, total_visitors = total_visitors,
		serious = serious_incidents, last_serious = last_serious_day, climate = climate, zone_weather = zone_weather,
		zone_next = zone_next, zone_dry = zone_dry, discoveries = discoveries, comments = comments,
		terrain = world.terrain, height = world.height, trees = world.trees, build = world.build, sid = world.sid, litter = world.litter,
		invasive = world.invasive, inv_seen = world.inv_seen, rare = world.rare, burned = world.burned,
		footfall = world.footfall, structures = structs, next_sid = world.next_sid,
		pops = eco.pops, know = eco.know, surveys = eco.surveys, staff = roles,
		offers = grants.offers, active = grants.active, grants_done = grants.completed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	return true


## Call right after setup() with the same seed the save was made from.
func load_game(d: Dictionary) -> void:
	day = d.day
	minutes = d.minutes
	_last_hour = int(minutes / 60.0)
	money = d.money
	fee = d.fee
	research = d.research
	research_total = d.research_total
	techs = d.techs
	safety = d.safety
	ratings.assign(d.ratings)
	total_visitors = d.total_visitors
	serious_incidents = d.serious
	level = d.get("level", 1)
	deaths = d.get("deaths", 0)
	if d.has("trail_grade"):
		world.trail_grade = d.trail_grade
	last_serious_day = d.last_serious
	climate = d.climate
	zone_weather = d.zone_weather
	zone_next = d.zone_next
	zone_dry = d.zone_dry
	discoveries = d.discoveries
	comments = d.comments
	world.terrain = d.terrain
	if d.has("height"):
		world.height = d.height
	world.trees = d.trees
	world.build = d.build
	world.sid = d.sid
	world.litter = d.litter
	world.invasive = d.invasive
	world.inv_seen = d.inv_seen
	world.rare = d.rare
	world.burned = d.burned
	world.footfall = d.footfall
	world.next_sid = d.next_sid
	world.structures.clear()
	for s in d.structures:
		world.structures[s.id] = {id = s.id, kind = s.kind, tile = s.tile, size = s.size, name = s.name, quality = 0.5,
			visitors = 0, access = [] as Array[Vector2i], visits = s.visits}
	world.litter_tiles.clear()
	world.invasive_tiles.clear()
	for i in world.litter.size():
		if world.litter[i] > 0: world.litter_tiles[i] = true
		if world.invasive[i] > 0.0: world.invasive_tiles[i] = true
	world.sustainable_trails = techs.has("trails")
	world.rebuild_nav()
	world.recompute_fields()
	eco.pops.assign(d.pops)
	eco.know.assign(d.know)
	eco.surveys = d.surveys
	for role in d.staff:
		staffing.hire(role)
	grants.offers = d.offers
	grants.active = d.active
	grants.completed = d.grants_done
	weather = zone_weather[world.biome[World.ti(world.entry)]]
	record_rating(60.0)
	ratings.pop_back()
	eco.daily_refresh()
	update_appeal()
