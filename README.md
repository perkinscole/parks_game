# Wildlands: A National Park Tycoon

A cute low-poly 3D park-management game made with Godot 4. You are handed a piece of
wild land with mountains, lakes, rivers, forest and wildlife, and you decide how to
open it to the public without wrecking what makes it special.

## Run it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard build, not .NET).
2. Open the Godot project manager, choose **Import**, pick this folder's `project.godot`, then press **Run** (F5).

Or from a terminal, in this folder:

```bash
godot --path .
```

Every new game generates a different map. To replay a map, pass a seed: `godot --path . -- --seed=7`.

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

## How it plays

- **Getting visitors in.** Extend the road from the highway, place an Entrance Gate, add parking.
  Every car needs a parking space, pays the entry fee, and the people in it walk the trails to whatever is in range.
- **Development choices.** A Scenic Overlook is only as good as its surroundings: water, peaks, forest and the five
  named landmarks raise its appeal; roads, parking and litter lower it. Put a parking lot right at a viewpoint and you
  get crowds of sightseers and a mediocre view. Make people hike there and you get fewer, happier hikers and intact habitat.
- **Visitors.** Sightseers, families, hikers, naturalists, climbers and campers all want different things and walk
  different distances. Click one to see their mood; the Park panel lists what they are saying.
- **Conservation.** Eleven species (elk, bears, foxes, mountain goats, eagles, beavers, trout, salamanders, wildflowers,
  old-growth pine, rare orchids) each need their own habitat. Development and crowds disturb it, runoff and litter foul
  the water, and invasive thistle and milfoil creep in on visitors' boots. Use the Habitat view to see the damage.
- **Safety.** Hikers get injured or lost, climbers fall, and bears drawn to litter cause dangerous encounters.
  Rangers patrol and respond; signs and trailhead kiosks cut the risk. Ignored emergencies cost money and reputation.
- **Staff.** Rangers and maintenance workers work out of Ranger Stations, ecologists out of Research Stations.
- **Research and grants.** Ecologists generate research points for seven upgrades (bear-proof bins, boot-brush stations,
  native restoration and more). Grants pay out for hitting conservation, safety and access goals by a deadline.
- **Time.** A year is four 6-day seasons. Summer is busy, winter is quiet, and the trees change with the seasons.

## Code map

| File | What it does |
| --- | --- |
| `scripts/defs.gd` | All game data: buildings, visitor types, species, research, staff |
| `scripts/world.gd` | Map generation, building rules, pathfinding grids, habitat and scenery fields |
| `scripts/game.gd` | Clock, money, ratings, research, player actions |
| `scripts/visitors.gd` | Visitor parties: driving, parking, itineraries, satisfaction |
| `scripts/ecology.gd` | Species populations, wandering animals, invasives, ecosystem health |
| `scripts/staffing.gd` | Staff behaviour and emergencies |
| `scripts/grants.gd` | Grant offers and progress |
| `scripts/terrain3d.gd`, `agents3d.gd`, `models.gd`, `mesh_builder.gd` | 3D rendering; every model is generated in code |
| `scripts/hud.gd`, `art.gd` | The interface and its icons |
| `scripts/main.gd` | Camera, input, building tools |

All artwork is procedural, so there are no image or model assets. The interface font is Fredoka (SIL Open Font License, see `fonts/OFL.txt`).

Not in yet: saving and loading, sound.
