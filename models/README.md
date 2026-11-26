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
