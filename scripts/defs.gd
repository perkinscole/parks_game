class_name D
extends RefCounted
## Static game data: terrain, buildings, visitors, species, research, grants.

const TILE := 32
const MAP_W := 88
const MAP_H := 60

enum T { DEEP, WATER, SAND, GRASS, MEADOW, FOREST, ROCK, PEAK }
enum B {
	NONE, ROAD, TRAIL, PARKING, GATE, VISITOR_CENTER, RESTROOM, BIN, OVERLOOK,
	PICNIC, CAMP, SNACK, RANGER, RESEARCH, CRAG, SIGN, HIDE, TRAILHEAD
}

const TERRAIN_NAMES := ["Deep water", "Water", "Shore", "Grassland", "Wildflower meadow", "Forest", "Rocky foothills", "Mountain peak"]

# cost: build price. upkeep: $/day. size: footprint in tiles.
# dist/str: radius and strength of the wildlife disturbance it causes.
const BUILD := {
	B.ROAD: {name = "Road", cost = 30, upkeep = 0.5, size = Vector2i(1, 1), dist = 3, str = 0.45,
		desc = "Cars drive on roads. Connect the highway to parking lots. Noisy: wildlife keeps away and scenery suffers. Drag to build."},
	B.TRAIL: {name = "Trail", cost = 12, upkeep = 0.15, size = Vector2i(1, 1), dist = 1, str = 0.12,
		desc = "Footpath for visitors. Low impact. Becomes a boardwalk over shallow water and switchbacks on mountains. Drag to build."},
	B.PARKING: {name = "Parking Lot", cost = 60, upkeep = 0.6, size = Vector2i(1, 1), dist = 4, str = 0.6,
		desc = "Each tile holds 2 cars. Visitors can only come if there is somewhere to park. Drag an area next to a road."},
	B.GATE: {name = "Entrance Gate", cost = 800, upkeep = 10, size = Vector2i(1, 1), dist = 2, str = 0.3,
		desc = "Place on a road. Opens the park and collects the entry fee from every car."},
	B.VISITOR_CENTER: {name = "Visitor Center", cost = 4500, upkeep = 45, size = Vector2i(2, 2), dist = 3, str = 0.5, cap = 40,
		desc = "Exhibits, maps and a gift shop. Loved by sightseers and families. Earns gift-shop income."},
	B.RESTROOM: {name = "Restroom", cost = 700, upkeep = 12, size = Vector2i(1, 1), dist = 2, str = 0.3, cap = 12,
		desc = "Visitors on longer outings get grumpy without one nearby."},
	B.BIN: {name = "Trash & Recycling", cost = 80, upkeep = 2, size = Vector2i(1, 1), dist = 1, str = 0.1,
		desc = "Greatly cuts littering within 5 tiles. Litter attracts bears and ruins views."},
	B.OVERLOOK: {name = "Scenic Overlook", cost = 600, upkeep = 5, size = Vector2i(1, 1), dist = 1, str = 0.15, cap = 14,
		desc = "A viewing platform. Its appeal depends on the scenery around it: water, peaks, forest and landmarks help; roads, parking and litter hurt."},
	B.PICNIC: {name = "Picnic Area", cost = 350, upkeep = 4, size = Vector2i(1, 1), dist = 2, str = 0.25, cap = 16,
		desc = "Tables in the shade. Families love them. Put a bin nearby!"},
	B.CAMP: {name = "Campground", cost = 2500, upkeep = 20, size = Vector2i(2, 2), dist = 4, str = 0.5, cap = 16,
		desc = "Campers pay a nightly fee. Best somewhere pretty and away from roads."},
	B.SNACK: {name = "Snack Shack", cost = 1800, upkeep = 25, size = Vector2i(1, 1), dist = 2, str = 0.35, cap = 12,
		desc = "Sells food and drinks. Good income, but creates a lot of litter."},
	B.RANGER: {name = "Ranger Station", cost = 3000, upkeep = 30, size = Vector2i(2, 2), dist = 3, str = 0.4,
		desc = "Base for up to 3 rangers and 3 maintenance workers. Required to hire them."},
	B.RESEARCH: {name = "Research Station", cost = 4000, upkeep = 35, size = Vector2i(2, 2), dist = 2, str = 0.3,
		desc = "Base for up to 3 ecologists, who remove invasive species and generate research."},
	B.CRAG: {name = "Climbing Crag", cost = 500, upkeep = 6, size = Vector2i(1, 1), dist = 2, str = 0.35, cap = 8,
		desc = "Bolted climbing routes. Must be on rocky foothills. Attracts climbers, but injuries are more likely and mountain goats dislike it."},
	B.SIGN: {name = "Safety Signage", cost = 120, upkeep = 1, size = Vector2i(1, 1), dist = 0, str = 0.0,
		desc = "Maps and hazard warnings. Cuts injuries and lost hikers within 6 tiles."},
	B.HIDE: {name = "Wildlife Hide", cost = 700, upkeep = 5, size = Vector2i(1, 1), dist = 0, str = 0.05, cap = 8,
		desc = "A quiet blind for watching animals. Its appeal depends on how much healthy wildlife lives nearby."},
	B.TRAILHEAD: {name = "Trailhead Kiosk", cost = 400, upkeep = 3, size = Vector2i(1, 1), dist = 1, str = 0.15,
		desc = "Trail maps and a register. Hikers leaving from here rarely get lost, and it doubles as safety signage."},
}

const CATEGORIES := [
	{id = "paths", name = "Roads & Trails", tools = [B.ROAD, B.TRAIL, B.PARKING, B.GATE]},
	{id = "facilities", name = "Facilities", tools = [B.VISITOR_CENTER, B.RESTROOM, B.BIN, B.SNACK, B.SIGN, B.TRAILHEAD]},
	{id = "attractions", name = "Attractions", tools = [B.OVERLOOK, B.PICNIC, B.CAMP, B.CRAG, B.HIDE]},
	{id = "ops", name = "Operations", tools = [B.RANGER, B.RESEARCH]},
	{id = "land", name = "Land", tools = ["bulldoze", "plant", "weed"]},
]

const TOOLS := {
	"bulldoze": {name = "Demolish", cost = 10, desc = "Remove roads, trails and buildings. Drag an area. $10 per tile."},
	"plant": {name = "Plant Native Trees", cost = 25, desc = "Restore habitat by planting trees on open land. Drag an area. Requires Native Restoration research."},
	"weed": {name = "Remove Invasives", cost = 40, desc = "Send a contract crew to clear invasive plants from tiles. Drag an area. Ecologists do this for free."},
}

const ATTRACTIONS := [B.OVERLOOK, B.VISITOR_CENTER, B.PICNIC, B.CAMP, B.SNACK, B.CRAG, B.HIDE]

# range: max one-way walk in tiles. hike: how much they value long, scenic walks.
const VTYPES := [
	{id = "sightseer", name = "Sightseers", weight = 30.0, vrange = 14, hike = 0.15, stops = 3,
		prefs = {B.OVERLOOK: 1.0, B.VISITOR_CENTER: 0.9, B.PICNIC: 0.5, B.SNACK: 0.6, B.HIDE: 0.3}},
	{id = "family", name = "Family", weight = 25.0, vrange = 11, hike = 0.1, stops = 3,
		prefs = {B.OVERLOOK: 0.7, B.VISITOR_CENTER: 1.0, B.PICNIC: 1.0, B.SNACK: 0.8, B.HIDE: 0.5}},
	{id = "hiker", name = "Hikers", weight = 22.0, vrange = 60, hike = 1.0, stops = 2,
		prefs = {B.OVERLOOK: 1.0, B.PICNIC: 0.3, B.HIDE: 0.5, B.VISITOR_CENTER: 0.2}},
	{id = "naturalist", name = "Naturalists", weight = 10.0, vrange = 34, hike = 0.6, stops = 2,
		prefs = {B.HIDE: 1.4, B.OVERLOOK: 0.8, B.VISITOR_CENTER: 0.5}},
	{id = "climber", name = "Climbers", weight = 8.0, vrange = 45, hike = 0.3, stops = 1, needs = B.CRAG,
		prefs = {B.CRAG: 1.6, B.SNACK: 0.3}},
	{id = "camper", name = "Campers", weight = 9.0, vrange = 30, hike = 0.5, stops = 2, needs = B.CAMP,
		prefs = {B.CAMP: 1.6, B.OVERLOOK: 0.6, B.PICNIC: 0.4}},
]

# density: animals per unit of habitat quality. sens: sensitivity to disturbance.
# vis: how many walk around the map at a healthy population.
const SPECIES := [
	{id = "elk", name = "Elk", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST], density = 0.05, sens = 0.5, growth = 0.12, vis = 14, speed = 22.0,
		desc = "Grazes meadows and forest edges. Fairly tolerant of people."},
	{id = "bear", name = "Black Bear", kind = "animal", habitat = [T.FOREST], density = 0.012, sens = 1.2, growth = 0.06, vis = 5, speed = 20.0,
		desc = "Needs big, quiet forest. Drawn to litter, which leads to dangerous encounters."},
	{id = "fox", name = "Red Fox", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST, T.SAND], density = 0.015, sens = 0.3, growth = 0.15, vis = 7, speed = 34.0,
		desc = "Adaptable hunter of meadows and edges."},
	{id = "goat", name = "Mountain Goat", kind = "animal", habitat = [T.ROCK, T.PEAK], density = 0.03, sens = 1.0, growth = 0.08, vis = 7, speed = 16.0,
		desc = "Lives on crags and peaks. Disturbed by climbing areas and summit crowds."},
	{id = "eagle", name = "Bald Eagle", kind = "animal", habitat = [T.WATER, T.DEEP, T.SAND], density = 0.01, sens = 1.0, growth = 0.07, vis = 4, speed = 60.0,
		desc = "Nests near clean water and depends on healthy trout."},
	{id = "beaver", name = "Beaver", kind = "animal", habitat = [T.WATER, T.SAND], density = 0.012, sens = 0.7, growth = 0.1, vis = 4, speed = 10.0,
		desc = "Ecosystem engineer of rivers and lake shores."},
	{id = "trout", name = "Cutthroat Trout", kind = "animal", habitat = [T.WATER, T.DEEP], density = 0.12, sens = 0.8, growth = 0.2, vis = 16, speed = 14.0,
		desc = "Needs cold, clean water. Hurt by runoff, litter and invasive milfoil."},
	{id = "salamander", name = "Tiger Salamander", kind = "animal", habitat = [T.SAND, T.WATER], density = 0.08, sens = 1.6, growth = 0.18, vis = 7, speed = 6.0,
		desc = "Indicator species: the first to vanish when shorelines are polluted or developed."},
	{id = "wolf", name = "Gray Wolf", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST, T.ROCK], density = 0.006, sens = 1.5, growth = 0.07, vis = 5, speed = 30.0,
		desc = "Apex predator that needs large, undisturbed country. Keeps elk numbers and behaviour in check."},
	{id = "bee", name = "Native Bees", kind = "insect", habitat = [T.MEADOW, T.GRASS], density = 2.0, sens = 0.5, growth = 0.3, vis = 0, speed = 0.0,
		desc = "Pollinators. They need wildflowers, and wildflowers need them."},
	{id = "wildflower", name = "Wildflowers", kind = "plant", habitat = [T.MEADOW], density = 1.0, sens = 0.6, growth = 0.25, vis = 0, speed = 0.0,
		desc = "Meadow blooms. Crowded out by invasive thistle."},
	{id = "oldgrowth", name = "Old-Growth Pine", kind = "plant", habitat = [T.FOREST], density = 1.0, sens = 0.3, growth = 0.04, vis = 0, speed = 0.0,
		desc = "Ancient forest. Lost when cleared; slowly recovers when replanted."},
	{id = "orchid", name = "Lady's Slipper Orchid", kind = "plant", habitat = [], density = 1.0, sens = 2.0, growth = 0.05, vis = 0, speed = 0.0,
		desc = "Rare orchid found in only a few colonies (pink flowers on the map). Dies if built over, trampled or overrun by invasives."},
]

# Field notes: what your ecologists learn once a species is well studied.
const NOTES := {
	"elk": "Without wolves, elk multiply and linger in meadows, grazing wildflowers and young trees down to stubble. This knock-on effect is called a trophic cascade.",
	"bear": "Bears are omnivores with superb noses. One taste of human food teaches a bear to seek people out, which usually ends badly for the bear.",
	"fox": "Foxes thrive along edges where forest meets meadow. Generalists like these often cope with change better than specialists.",
	"goat": "Mountain goats rely on steep ground to escape predators. Repeated disturbance pushes them off the best feeding ledges.",
	"eagle": "Eagles sit at the top of the aquatic food chain, so anything that harms fish (warm water, pollution, invasives) reaches them too.",
	"beaver": "Beaver dams slow water and create wetlands that shelter amphibians and young trout. One species can engineer habitat for many.",
	"trout": "Cutthroat trout need cold, clear, oxygen-rich water. Runoff from parking lots, drought and a warming climate all squeeze them.",
	"salamander": "Amphibians breathe partly through their skin, so they absorb pollutants readily. Their decline is an early warning.",
	"wolf": "Wolves change where elk feed as well as how many there are. Their return lets streamside plants recover.",
	"bee": "Most wildflowers cannot set seed without pollinators. Lose the bees and the meadows fade a few seasons later.",
	"wildflower": "Meadows depend on pollinators, on not being overgrazed, and on occasional fire to hold back the forest.",
	"oldgrowth": "Old forest takes centuries to form. Low-intensity fire clears the understory and can actually help it; clearing does not.",
	"orchid": "Lady's slipper orchids need a specific soil fungus to germinate and take years to flower, so lost colonies rarely return.",
}

const WEATHER := {
	"clear": {name = "Clear", demand = 1.0, risk = 1.0},
	"rain": {name = "Rain", demand = 0.55, risk = 1.4},
	"storm": {name = "Thunderstorm", demand = 0.25, risk = 2.5},
	"heat": {name = "Heatwave", demand = 0.85, risk = 1.3},
	"snow": {name = "Snow", demand = 0.7, risk = 1.5},
}

const TECHS := [
	{id = "bins", name = "Bear-Proof Bins", cost = 60, desc = "Bins lock out wildlife. Dangerous bear encounters drop sharply near bins."},
	{id = "bootbrush", name = "Boot-Brush Stations", cost = 80, desc = "Visitors clean seeds off boots and boats. Invasive species arrive half as often."},
	{id = "restore", name = "Native Restoration", cost = 100, desc = "Unlocks the Plant Native Trees tool and speeds habitat recovery."},
	{id = "trails", name = "Sustainable Trails", cost = 120, desc = "Better drainage and tread. Trails disturb wildlife less and cause fewer injuries."},
	{id = "interp", name = "Interpretive Programs", cost = 140, desc = "Ranger talks and exhibits. Happier visitors, less littering, more donations."},
	{id = "sar", name = "Search & Rescue Training", cost = 160, desc = "Rangers move faster and visitors in trouble can wait longer for help."},
	{id = "monitor", name = "Wildlife Monitoring", cost = 200, desc = "Collars and camera traps. All animal populations grow faster and hides are more rewarding."},
]

const STAFF := {
	"ranger": {name = "Ranger", wage = 90, home = B.RANGER, desc = "Patrols trails, prevents accidents and responds to emergencies."},
	"maint": {name = "Maintenance", wage = 60, home = B.RANGER, desc = "Picks up litter across the park."},
	"eco": {name = "Ecologist", wage = 110, home = B.RESEARCH, desc = "Removes invasive species, surveys wildlife and produces research."},
}

const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_DEMAND := [0.9, 1.3, 1.0, 0.55]
const DAYS_PER_SEASON := 6

const LANDMARK_NAMES := {
	"summit": ["Mt. Solitude", "Thunder Peak", "Mt. Larkspur", "Raven's Crown"],
	"falls": ["Eagle Falls", "Bridal Veil Falls", "Whisper Falls", "Rainbow Cascade"],
	"lake": ["Mirror Lake", "Lake Serenity", "Heron Lake", "Sapphire Tarn"],
	"grove": ["Elder Grove", "Cathedral Grove", "Grandfather Pines", "Mossy Hollow"],
	"spring": ["Opal Springs", "Painted Pools", "Steamboat Spring", "Emerald Basin"],
}

static func money(v: float) -> String:
	var n := int(round(abs(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < -0.5 else "$") + s + out

static func hash2(x: int, y: int, k: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h % 10007) / 10007.0
