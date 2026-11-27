class_name D
extends RefCounted
## Static game data: terrain, buildings, visitors, species, research, grants.

const TILE := 32
const MAP_W := 320
const MAP_H := 240

## Large regions of the park, each with its own look, wildlife and weather.
enum BIOME { FOREST, VALLEY, WETLAND, DESERT, ALPINE }
const BIOME_NAMES := ["Montane forest", "Grassy valley", "Wetland", "Red-rock desert", "Alpine"]

enum T { DEEP, WATER, SAND, GRASS, MEADOW, FOREST, ROCK, PEAK }
enum B {
	NONE, ROAD, TRAIL, PARKING, GATE, VISITOR_CENTER, RESTROOM, BIN, OVERLOOK,
	PICNIC, CAMP, SNACK, RANGER, RESEARCH, CRAG, SIGN, HIDE, TRAILHEAD,
	CALLBOX, HUT, SAR, HELIPAD, KAYAK, MARINA, BIKES, SKI, SNOWMOBILE
}

# The park grows through four levels. Each one opens more to build, and each
# asks for a bigger, safer, better-understood park than the last.
const LEVELS := [
	{name = "Local Reserve", visitors = 0, stars = 0.0, research = 0, story = ""},
	{name = "State Park", visitors = 120, stars = 2.8, research = 0,
		story = "Word is getting round, and the state has put us on the map. With the name comes money for proper trails and a visitor center, and people who will walk further than the first overlook. Further out means further from help. Start thinking about how anyone would call for it."},
	{name = "National Park", visitors = 500, stars = 3.4, research = 60,
		story = "Congress signed it this morning: a National Park. The crowds will come for the far country now, the summit and the high lakes. A twisted ankle a mile from the road is a nuisance; ten miles out, after dark, it can kill. We can finally fund a search and rescue team and huts in the backcountry. We will need them."},
	{name = "Crown Jewel", visitors = 1600, stars = 3.8, research = 180,
		story = "They are calling it the crown jewel of the system. That buys us a helicopter, which reaches anywhere in the park in minutes. It also means that anything that goes wrong here now makes the national news."},
]


const TERRAIN_NAMES := ["Deep water", "Water", "Shore", "Grassland", "Wildflower meadow", "Forest", "Rocky foothills", "Mountain peak"]

# cost: build price. upkeep: $/day. size: footprint in tiles.
# dist/str: radius and strength of the wildlife disturbance it causes.
const BUILD := {
	B.ROAD: {name = "Road", cost = 30, upkeep = 0.5, size = Vector2i(1, 1), dist = 3, str = 0.45,
		desc = "Cars drive on roads. Connect the highway to parking lots. Noisy: wildlife keeps away and scenery suffers. Drag to build."},
	B.TRAIL: {name = "Trail", cost = 12, upkeep = 0.15, size = Vector2i(1, 1), dist = 1, str = 0.12,
		desc = "A graded footpath: the everyday trail. Comfortable on gentle ground, risky on steep ground. Becomes a boardwalk over shallow water. Drag to build."},
	B.PARKING: {name = "Parking Lot", cost = 60, upkeep = 0.6, size = Vector2i(1, 1), dist = 4, str = 0.6,
		desc = "Each tile holds 2 cars. Visitors can only come if there is somewhere to park. Drag an area next to a road."},
	B.GATE: {name = "Entrance Gate", cost = 800, upkeep = 10, size = Vector2i(1, 1), dist = 2, str = 0.3,
		desc = "Place on a road. Opens the park and collects the entry fee from every car."},
	B.VISITOR_CENTER: {level = 2, name = "Visitor Center", cost = 4500, upkeep = 45, size = Vector2i(2, 2), dist = 3, str = 0.5, cap = 40,
		desc = "Exhibits, maps and a gift shop. Loved by sightseers and families. Earns gift-shop income."},
	B.RESTROOM: {name = "Restroom", cost = 700, upkeep = 12, size = Vector2i(1, 1), dist = 2, str = 0.3, cap = 12,
		desc = "Visitors on longer outings get grumpy without one nearby."},
	B.BIN: {name = "Trash & Recycling", cost = 80, upkeep = 2, size = Vector2i(1, 1), dist = 1, str = 0.1,
		desc = "Greatly cuts littering within 5 tiles. Litter attracts bears and ruins views."},
	B.OVERLOOK: {name = "Scenic Overlook", cost = 600, upkeep = 5, size = Vector2i(1, 1), dist = 1, str = 0.15, cap = 14,
		desc = "A viewing platform. Its appeal depends on the scenery around it: water, peaks, forest and landmarks help; roads, parking and litter hurt."},
	B.PICNIC: {name = "Picnic Area", cost = 350, upkeep = 4, size = Vector2i(1, 1), dist = 2, str = 0.25, cap = 16,
		desc = "Tables in the shade. Families love them. Put a bin nearby!"},
	B.CAMP: {level = 2, name = "Campground", cost = 2500, upkeep = 20, size = Vector2i(2, 2), dist = 4, str = 0.5, cap = 16,
		desc = "Campers pay a nightly fee. Best somewhere pretty and away from roads."},
	B.SNACK: {level = 2, name = "Snack Shack", cost = 1800, upkeep = 25, size = Vector2i(1, 1), dist = 2, str = 0.35, cap = 12,
		desc = "Sells food and drinks. Good income, but creates a lot of litter."},
	B.RANGER: {name = "Ranger Station", cost = 3000, upkeep = 30, size = Vector2i(2, 2), dist = 3, str = 0.4,
		desc = "Base for up to 3 rangers and 3 maintenance workers. Required to hire them."},
	B.RESEARCH: {name = "Research Station", cost = 4000, upkeep = 35, size = Vector2i(2, 2), dist = 2, str = 0.3,
		desc = "Base for up to 3 ecologists, who remove invasive species and generate research."},
	B.CRAG: {level = 3, name = "Climbing Crag", cost = 500, upkeep = 6, size = Vector2i(1, 1), dist = 2, str = 0.35, cap = 8,
		desc = "Bolted climbing routes. Must be on rocky foothills. Attracts climbers, but injuries are more likely and mountain goats dislike it."},
	B.SIGN: {name = "Safety Signage", cost = 120, upkeep = 1, size = Vector2i(1, 1), dist = 0, str = 0.0,
		desc = "Maps and hazard warnings. Without a sign nearby, steep trails hurt far more people and long trails lose them. Covers 6 tiles."},
	B.HIDE: {level = 3, name = "Wildlife Hide", cost = 700, upkeep = 5, size = Vector2i(1, 1), dist = 0, str = 0.05, cap = 8,
		desc = "A quiet blind for watching animals. Its appeal depends on how much healthy wildlife lives nearby."},
	B.CALLBOX: {name = "Call Box", cost = 250, upkeep = 2, size = Vector2i(1, 1), dist = 0, str = 0.0, level = 2,
		desc = "A solar radio post. Anyone in trouble within 9 tiles gets word out at once, so they can hold on half as long again while help comes."},
	B.HUT: {name = "Backcountry Hut", cost = 1500, upkeep = 8, size = Vector2i(1, 1), dist = 2, str = 0.25, level = 3,
		desc = "A bunkhouse far from the road. Hikers caught out after dark within 10 tiles shelter here instead of spending the night in the open."},
	B.SAR: {name = "Rescue Post", cost = 6000, upkeep = 60, size = Vector2i(2, 2), dist = 3, str = 0.4, level = 3,
		desc = "A trained team with a truck and litters. Sent to serious emergencies up to 60 tiles away, much faster than a ranger on foot. One call-out at a time."},
	B.HELIPAD: {name = "Rescue Helipad", cost = 15000, upkeep = 140, size = Vector2i(2, 2), dist = 6, str = 0.8, level = 4,
		desc = "A helicopter reaches anywhere in the park in moments and saves lives nothing else can. Each flight costs $600, and the noise empties the sky of eagles."},
	B.BIKES: {name = "Bike Rental", cost = 1600, upkeep = 14, size = Vector2i(1, 1), dist = 2, str = 0.25, cap = 12, level = 2,
		desc = "Bikes and helmets by the day. Worth as much as the riding you offer: lay Bike Path and Mountain Bike Trail for riders to use. Brings cyclists to the park."},
	B.SKI: {name = "Nordic Ski Center", cost = 2200, upkeep = 16, size = Vector2i(1, 1), dist = 2, str = 0.25, cap = 14, level = 2, season = 3,
		desc = "Winter only. Cross-country skis and groomed tracks along your trails. Quiet and light on the land, and it fills the park in the dead season. Better the more trail you have."},
	B.SNOWMOBILE: {name = "Snowmobile Rental", cost = 5500, upkeep = 45, size = Vector2i(1, 1), dist = 9, str = 0.9, cap = 12, level = 3, season = 3,
		desc = "Winter only. Nearly three times the income of skis. But winter is when animals are living on their last reserves, and engines send them running for 9 tiles around. Skiers and walkers hate the noise."},
	B.KAYAK: {name = "Kayak Rental", cost = 1800, upkeep = 15, size = Vector2i(1, 1), dist = 2, str = 0.2, cap = 10, level = 2,
		desc = "Paddles and life vests at the water's edge. Quiet: herons and beavers barely notice. Modest income, and visitors love it where the scenery is good."},
	B.MARINA: {name = "Motorboat Rental", cost = 5000, upkeep = 50, size = Vector2i(1, 1), dist = 8, str = 0.9, cap = 14, level = 3,
		desc = "Powerboats by the hour. Nearly three times the income of kayaks, but engine noise clears wildlife from 8 tiles around and fuel and wake foul the water for trout, herons and beavers."},
	B.TRAILHEAD: {level = 2, name = "Trailhead Kiosk", cost = 400, upkeep = 3, size = Vector2i(1, 1), dist = 1, str = 0.15,
		desc = "Trail maps and a register. Hikers leaving from here rarely get lost, and it doubles as safety signage."},
}

const CATEGORIES := [
	{id = "paths", name = "Roads & Trails", tools = [B.ROAD, "path", B.TRAIL, "steps", "switchback", B.PARKING, B.GATE]},
	{id = "facilities", name = "Facilities", tools = [B.VISITOR_CENTER, B.RESTROOM, B.BIN, B.SNACK, B.SIGN, B.TRAILHEAD]},
	{id = "attractions", name = "Attractions", tools = [B.OVERLOOK, B.PICNIC, B.CAMP, B.CRAG, B.HIDE]},
	{id = "ops", name = "Operations", tools = [B.RANGER, B.RESEARCH, B.CALLBOX, B.HUT, B.SAR, B.HELIPAD]},
	{id = "land", name = "Land", tools = ["bulldoze", "plant", "weed"]},
	{id = "sport", name = "Sport", tools = [B.BIKES, "bikepath", "mtb", B.SKI, B.SNOWMOBILE]},
	{id = "water", name = "Water", tools = ["dock", B.KAYAK, B.MARINA]},
	{id = "terrain", name = "Terrain", tools = ["raise", "lower", "level", "smooth"]},
]

const TOOLS := {
	"bulldoze": {name = "Demolish", cost = 10, desc = "Remove roads, trails and buildings. Drag an area. $10 per tile."},
	"plant": {name = "Plant Native Trees", cost = 25, desc = "Restore habitat by planting trees on open land. Drag an area. Requires Native Restoration research."},
	"bikepath": {name = "Bike Path", cost = 30, level = 2, desc = "A smooth paved path for bikes, wheelchairs, strollers and walkers alike. Safe, quick and fully accessible, but pavement is harder on the land than dirt."},
	"mtb": {name = "MTB Trail", cost = 14, level = 3, desc = "Narrow dirt singletrack for mountain bikes. Riders love it, especially on hills. Crashes are common, tyres erode the tread, and hikers resent sharing it."},
	"dock": {name = "Dock / Boardwalk", cost = 60, desc = "A timber walkway over shallow water. Paths cannot cross water without one. Use it for footbridges, fishing piers and lakeshore boardwalks; it is level and smooth, so anyone can use it."},
	"path": {name = "Rough Path", cost = 5, desc = "A faint beaten track, barely cleared, so it is cheap and light on the land, but it is easy to lose: hikers go astray three times as often. On a slope it is slow and where most injuries happen."},
	"steps": {name = "Built Trail", cost = 45, level = 2, desc = "Stone steps, drains and handrails. Safe and quick even on steep ground, and it upgrades any path it is laid over. Costly to build."},
	"switchback": {name = "Switchback", level = 2, cost = 12, desc = "Drag from the bottom of a slope to the top: the trail finds its own zigzag route up at a gentle grade. Hikers crawl up steep trails and avoid them."},
	"raise": {level = 2, name = "Raise Land", cost = 15, desc = "Hold to push the ground up under the brush. [ and ] change the brush size. Earthworks disturb the soil and wildlife nearby."},
	"lower": {level = 2, name = "Lower Land", cost = 15, desc = "Hold to dig the ground down under the brush. [ and ] change the brush size."},
	"level": {level = 2, name = "Level Land", cost = 15, desc = "Hold and drag to flatten ground to the height where you started. Good for building pads and road beds."},
	"smooth": {level = 2, name = "Smooth Land", cost = 10, desc = "Hold to soften bumps and blend slopes into each other."},
	"weed": {name = "Remove Invasives", cost = 40, desc = "Send a contract crew to clear invasive plants from tiles. Drag an area. Ecologists do this for free."},
}

# What each purchase pushes on, from -2 (hurts a lot) to +2 (helps a lot):
# [visitors, nature, safety, income, knowledge]. Shown on the build card.
const EFFECTS := {
	B.ROAD: [1, -2, 0, 0, 0], B.TRAIL: [1, -1, 0, 0, 0], B.PARKING: [2, -2, 0, 0, 0], B.GATE: [0, -1, 0, 2, 0],
	B.VISITOR_CENTER: [2, -1, 0, 1, 0], B.RESTROOM: [1, -1, 0, 0, 0], B.BIN: [1, 1, 0, 0, 0], B.OVERLOOK: [2, -1, 0, 0, 0],
	B.PICNIC: [1, -1, 0, 0, 0], B.CAMP: [1, -2, 0, 2, 0], B.SNACK: [1, -1, 0, 2, 0], B.RANGER: [0, -1, 2, 0, 0],
	B.RESEARCH: [0, 1, 0, 0, 2], B.CRAG: [1, -1, -2, 0, 0], B.SIGN: [0, 0, 1, 0, 0], B.HIDE: [1, 0, 0, 0, 0],
	B.TRAILHEAD: [1, 0, 1, 0, 0],
	B.CALLBOX: [0, 0, 1, 0, 0], B.HUT: [1, -1, 2, 0, 0], B.SAR: [0, -1, 2, 0, 0], B.HELIPAD: [0, -2, 2, 0, 0],
	B.KAYAK: [1, 0, 0, 1, 0], B.MARINA: [1, -2, 0, 2, 0], "dock": [1, -1, 1, 0, 0],
	B.BIKES: [1, 0, 0, 1, 0], B.SKI: [2, 0, 0, 1, 0], B.SNOWMOBILE: [1, -2, -1, 2, 0], "bikepath": [1, -1, 1, 0, 0], "mtb": [1, -1, -1, 0, 0],
	"path": [1, 0, -1, 0, 0], "steps": [1, -1, 2, 0, 0],
	"switchback": [1, -1, 1, 0, 0], "bulldoze": [0, 1, 0, 0, 0], "plant": [0, 2, 0, 0, 0], "weed": [0, 2, 0, 0, 0],
	"raise": [0, -1, 0, 0, 0], "lower": [0, -1, 0, 0, 0], "level": [0, -1, 0, 0, 0], "smooth": [0, -1, 0, 0, 0],
}

const ATTRACTIONS := [B.OVERLOOK, B.VISITOR_CENTER, B.PICNIC, B.CAMP, B.SNACK, B.CRAG, B.HIDE, B.KAYAK, B.MARINA, B.BIKES, B.SKI, B.SNOWMOBILE]

# range: max one-way walk in tiles. hike: how much they value long, scenic walks.
const VTYPES := [
	{id = "sightseer", name = "Sightseers", weight = 30.0, vrange = 14, hike = 0.15, stops = 3,
		prefs = {B.OVERLOOK: 1.0, B.VISITOR_CENTER: 0.9, B.PICNIC: 0.5, B.SNACK: 0.6, B.HIDE: 0.3, B.KAYAK: 0.6, B.MARINA: 1.0, B.SNOWMOBILE: 0.9, B.SKI: 0.4}},
	{id = "family", name = "Family", weight = 25.0, vrange = 11, hike = 0.1, stops = 3,
		prefs = {B.OVERLOOK: 0.7, B.VISITOR_CENTER: 1.0, B.PICNIC: 1.0, B.SNACK: 0.8, B.HIDE: 0.5, B.KAYAK: 0.9, B.MARINA: 1.0, B.BIKES: 0.8, B.SKI: 0.9, B.SNOWMOBILE: 0.9}},
	{id = "hiker", name = "Hikers", weight = 22.0, vrange = 60, hike = 1.0, stops = 2,
		prefs = {B.OVERLOOK: 1.0, B.PICNIC: 0.3, B.HIDE: 0.5, B.VISITOR_CENTER: 0.2, B.SKI: 1.2}},
	{id = "naturalist", name = "Naturalists", weight = 10.0, vrange = 34, hike = 0.6, stops = 2,
		prefs = {B.HIDE: 1.4, B.OVERLOOK: 0.8, B.VISITOR_CENTER: 0.5, B.KAYAK: 1.1, B.MARINA: 0.0, B.SKI: 0.9}},
	{id = "cyclist", name = "Cyclists", weight = 10.0, vrange = 70, hike = 0.7, stops = 2, needs = B.BIKES,
		prefs = {B.BIKES: 1.6, B.OVERLOOK: 0.7, B.SNACK: 0.5, B.PICNIC: 0.3}},
	{id = "climber", name = "Climbers", weight = 8.0, vrange = 45, hike = 0.3, stops = 1, needs = B.CRAG,
		prefs = {B.CRAG: 1.6, B.SNACK: 0.3}},
	{id = "camper", name = "Campers", weight = 9.0, vrange = 30, hike = 0.5, stops = 2, needs = B.CAMP,
		prefs = {B.CAMP: 1.6, B.OVERLOOK: 0.6, B.PICNIC: 0.4}},
]

# density: animals per unit of habitat quality. sens: sensitivity to disturbance.
# vis: how many walk around the map at a healthy population.
const SPECIES := [
	{id = "elk", name = "Elk", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST], density = 0.05, sens = 0.5, growth = 0.12, vis = 34, speed = 22.0,
		desc = "Grazes meadows and forest edges. Fairly tolerant of people."},
	{id = "bear", name = "Black Bear", kind = "animal", habitat = [T.FOREST], density = 0.012, sens = 1.2, growth = 0.06, vis = 11, speed = 20.0,
		desc = "Needs big, quiet forest. Drawn to litter, which leads to dangerous encounters."},
	{id = "fox", name = "Red Fox", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST, T.SAND], density = 0.015, sens = 0.3, growth = 0.15, vis = 15, speed = 34.0,
		desc = "Adaptable hunter of meadows and edges."},
	{id = "goat", name = "Mountain Goat", kind = "animal", habitat = [T.ROCK, T.PEAK], biomes = [BIOME.ALPINE, BIOME.FOREST, BIOME.VALLEY], density = 0.03, sens = 1.0, growth = 0.08, vis = 12, speed = 16.0,
		desc = "Lives on crags and peaks. Disturbed by climbing areas and summit crowds."},
	{id = "eagle", name = "Bald Eagle", kind = "animal", habitat = [T.WATER, T.DEEP, T.SAND], density = 0.01, sens = 1.0, growth = 0.07, vis = 8, speed = 60.0,
		desc = "Nests near clean water and depends on healthy trout."},
	{id = "beaver", name = "Beaver", kind = "animal", habitat = [T.WATER, T.SAND], density = 0.012, sens = 0.7, growth = 0.1, vis = 9, speed = 10.0,
		desc = "Ecosystem engineer of rivers and lake shores."},
	{id = "trout", name = "Cutthroat Trout", kind = "animal", habitat = [T.WATER, T.DEEP], density = 0.12, sens = 0.8, growth = 0.2, vis = 34, speed = 14.0,
		desc = "Needs cold, clean water. Hurt by runoff, litter and invasive milfoil."},
	{id = "salamander", name = "Tiger Salamander", kind = "animal", habitat = [T.SAND, T.WATER], density = 0.08, sens = 1.6, growth = 0.18, vis = 12, speed = 6.0,
		desc = "Indicator species: the first to vanish when shorelines are polluted or developed."},
	{id = "wolf", name = "Gray Wolf", kind = "animal", habitat = [T.GRASS, T.MEADOW, T.FOREST, T.ROCK], density = 0.006, sens = 1.5, growth = 0.07, vis = 10, speed = 30.0,
		desc = "Apex predator that needs large, undisturbed country. Keeps elk numbers and behaviour in check."},
	{id = "bighorn", name = "Desert Bighorn", kind = "animal", habitat = [T.ROCK, T.SAND, T.GRASS], biomes = [BIOME.DESERT], density = 0.012, sens = 1.1, growth = 0.08, vis = 10, speed = 18.0,
		desc = "Sure-footed sheep of the mesas and canyons. Needs scarce desert water and room away from people."},
	{id = "heron", name = "Great Blue Heron", kind = "animal", habitat = [T.WATER, T.GRASS, T.SAND], biomes = [BIOME.WETLAND], density = 0.03, sens = 1.2, growth = 0.1, vis = 9, speed = 8.0,
		desc = "Patient wading hunter of the marshes. Abandons nesting colonies that are disturbed."},
	{id = "pika", name = "American Pika", kind = "animal", habitat = [T.ROCK, T.MEADOW, T.GRASS], biomes = [BIOME.ALPINE], density = 0.08, sens = 0.8, growth = 0.2, vis = 10, speed = 9.0,
		desc = "Tiny relative of rabbits living among alpine boulders. Cannot survive heat."},
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
	"bighorn": "Bighorn pick up fatal pneumonia from domestic sheep and avoid water holes that people crowd. In a desert, water decides everything.",
	"heron": "Wetlands filter water, soak up floods and feed more species per acre than any other habitat here. Herons are the visible tip of that food chain.",
	"pika": "Pikas overheat within hours above about 25 degrees C. As the climate warms they retreat upslope until there is no mountain left.",
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
	"arch": ["Windgate Arch", "Coyote Arch", "Sunrise Arch", "The Needle's Eye"],
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
