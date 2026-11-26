# Wildlands: A National Park Tycoon

A 3D park-management game made with Godot 4 about how ecosystems actually work. You are
handed wild land with mountains, lakes, rivers, forest and wildlife, and every choice you
make about roads, visitors and staff ripples through the food web.

## Run it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard build, not .NET).
2. From this folder:

```bash
godot --path .
```

Or open the Godot project manager, choose **Import**, pick `project.godot`, and press **Run** (F5).

The game opens on a main menu: **New Park** generates a fresh random landscape, **Load Game**
resumes your saved park. The park saves itself every in-game morning and from the Save button.

Useful extras: `godot --path . -- --seed=7` replays a specific map, and
`godot --path . -- --seed=7 --autoplay` starts with a small demo park already built.

The game uses Godot's Forward+ renderer (Vulkan / Metal / D3D12). On an old machine without
those, run `godot --path . --rendering-method gl_compatibility` (it works, with plainer lighting).

## Controls

| Action | Input |
| --- | --- |
| Move the camera | Left-drag (with no tool selected), or WASD / arrow keys |
| Orbit / tilt | Right-drag or middle-drag, or Q / E |
| Zoom | Mouse wheel |
| Build | Pick a tool at the bottom. Drag for roads, trails, parking and land tools; click for buildings |
| Cancel tool | Right-click or Esc |
| Inspect | Click any visitor, animal, staff member, building or tile |
| Speed | Space to pause, 1 / 2 / 3 for speed |

## The world

- **Scale.** The map is 160 x 120 tiles of about 8 m each, with people, cars, animals and trees in real
  proportion, peaks over 300 m, and scenery that carries on to the horizon. Zoom from treetop height to the whole park.
- **Terrain that formed like terrain.** Mountain ranges come from ridged noise; then simulated erosion routes water
  downhill and cuts branching valleys, lakes pool wherever the land forms a basin (each at its own level,
  including high tarns), and rivers appear where enough land drains through. See `scripts/terrain_gen.gd`.
- **Five biomes**, each with its own plants, animals and weather: montane forest, grassy valley with aspen groves,
  wetland, red-rock desert with mesas, and alpine.
- **Ground that blends.** Trails wear into the grass with ragged dirt edges, roads have gravel shoulders, buildings
  sit on trampled ground, rock shows through on steep slopes, and snow settles by altitude and season.

## What you are managing

- **Access.** Roads, an entrance gate and parking bring cars in; visitors then walk trails to overlooks,
  picnic areas, campgrounds, climbing crags and wildlife hides. Six visitor types want different things.
- **Development trade-offs.** An overlook is only as good as its surroundings. Pave up to a viewpoint and you get
  crowds and a spoiled view; make people hike and you get fewer, happier visitors and intact habitat.
- **A food web, not a list of animals.** Wolves hunt elk and keep herds moving. Lose the wolves (they need quiet
  country) and elk overgraze the meadows, wildflowers fade, native bees follow, and the meadows stop reseeding.
  Beaver ponds shelter trout and salamanders; eagles depend on the trout; bears follow litter into trouble.
- **Animal behaviour.** Elk travel in herds, graze, bed down at night and flee from people and wolves. Animals come
  to water at dawn and dusk, shelter in forest when it rains, and bears den up for the winter.
- **Weather and climate.** Each biome has its own weather: it can snow in the alpine while the desert bakes.
  Rain, thunderstorms, heatwaves, drought and snow change visitor numbers, accident risk, runoff and fire danger. The park warms a little every year: thinner snowpack, stressed trout and goats.
- **Wildfire.** Lightning, or campfires in a drought, can start fires that spread through forest until rain or
  rangers stop them. Burn scars flush with wildflowers and regrow.
- **Invasive species** hitchhike in on boots and boats and spread quietly.
- **Research is how you know anything.** Species data, water quality, habitat maps, invasive patches and weather
  forecasts only appear once you have a Research Station and ecologists surveying in the field. Until then the
  ecosystem readout is a question mark, and problems grow unseen. Well-studied species unlock field notes, and
  ecologists record discoveries when they see interactions play out.
- **Safety, staff, money.** Rangers respond to injuries, lost hikers, bear encounters and fires; maintenance crews
  collect litter; grants reward conservation and access goals.
- **Time.** A year is four 6-day seasons, each with its own look.

## Code map

| File | What it does |
| --- | --- |
| `scripts/defs.gd` | Game data: buildings, visitor types, species, field notes, weather, research |
| `scripts/terrain_gen.gd` | Landscape generator: ridged mountains, erosion, lakes, rivers |
| `scripts/world.gd` | Biomes and terrain types, building rules, pathfinding grids, habitat and scenery fields |
| `scripts/game.gd` | Clock, weather and climate, money, ratings, research, player actions |
| `scripts/ecology.gd` | Food web, animal behaviour, invasives, wildfire, research knowledge |
| `scripts/visitors.gd` | Visitor parties: driving, parking, itineraries, satisfaction |
| `scripts/staffing.gd` | Staff behaviour and emergencies |
| `scripts/grants.gd` | Grant offers and progress |
| `scripts/terrain3d.gd`, `shaders/terrain.gdshader` | Terrain mesh and ground shader, water, vegetation, buildings, horizon |
| `scripts/agents3d.gd`, `models.gd`, `mesh_builder.gd`, `paths.gd` | Animated people, cars and animals; all models are generated in code |
| `scripts/hud.gd`, `art.gd` | The interface and its icons |
| `scripts/main.gd` | Camera, sky and lighting, input, building tools |

## Using your own models

Every model is generated in code, but any tree, rock or building can be replaced by dropping a `.glb`
file with the right name into `models/`. See `models/README.md` for the names and sizes.

The interface font is Inter (SIL Open Font License, see `fonts/Inter-LICENSE.txt`).

Not in yet: sound. Saves do not store visitors who are mid-visit; the park reopens empty.
