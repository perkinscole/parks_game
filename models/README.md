# Bring your own models

Every model in the game is generated in code, but any of them can be replaced:
drop a glTF binary (`.glb`) with one of the names below into this folder and
the game uses it instead on the next launch. No code changes needed.

One world unit is one map tile, roughly 8 metres. Models should sit on `y = 0`
with their origin at the centre of their footprint.

| File | Replaces | Suggested size (units) |
| --- | --- | --- |
| `conifer.glb` | Spruce / pine trees | about 2.5 tall (scaled 0.7x to 2.3x per tree) |
| `broadleaf.glb` | Aspen and other leafy trees | about 1.4 tall |
| `rock.glb` | Boulders | about 0.4 across |
| `bush.glb` | Sagebrush and shrubs | about 0.3 across |
| `visitor_center.glb`, `ranger.glb`, `research.glb`, `camp.glb` | 2x2 buildings | fit inside 2 x 2 |
| `restroom.glb`, `snack.glb`, `overlook.glb`, `picnic.glb`, `hide.glb`, `bin.glb`, `sign.glb`, `trailhead.glb`, `crag.glb`, `gate.glb` | 1x1 buildings | fit inside 1 x 1 |

Only the first mesh found in the file is used, with the materials it came with.
Trees are drawn thousands at a time, so keep them low-poly (a few hundred triangles).

## What is here now

- The **building** and **car** models in this folder (`car.glb`, `car2.glb`, `car3.glb`) were generated with
  Meshy and are used automatically. Delete any `.glb` to go back to the built-in model.
- **Trees** work differently, because the park draws tens of thousands of them. `impostors/` holds
  cut-out images baked from three detailed Meshy trees (spruce, pine, aspen); each tree in the game is
  about ten triangles textured with those images. To bake your own tree model into cut-outs:

  ```bash
  godot --path . -s tools/bake_impostor.gd -- /path/to/tree.glb spruce
  ```

  (use `spruce`, `pine` or `aspen` as the name to replace that tree). Delete the images to return to
  the built-in trees.
- `optional/` holds earlier, lighter Meshy trees and a boulder that are not used.

## People and animals

- `people/` holds six Meshy characters with Meshy's walking animation (`person1`-`person3` are visitors;
  `ranger`, `maint` and `eco` are staff). At startup the game bakes each walk cycle into a handful of
  poses so hundreds of walkers can be drawn at once. Any rigged `.glb` with one animation clip works.
- `animals/` holds one model per species, named by species id (`elk.glb`, `bear.glb`, ...). They are
  static models, so animals move, turn and bob but do not swing their legs. Their size and facing are
  set in `ANIMAL_FIT` in `scripts/agents3d.gd`.

Delete a file to return to the built-in version of that model.
