# 3D maquettes for anatomy image generation cannot invent

Owner verdict 2026-10-13: image generation cannot work out bird wings from text (shrike rear; also the roc fledgling
and gallows roc rears). For such subjects the structure is decided in 3D and image generation only paints over it.

- `gust_shrike.py`: Blender (headless) proxy — body, head, beak, mask band, two feathered wing sails, tail fan, legs —
  rendered from the board camera (orthographic, azimuth 45°, elevation 30°; the bird's +X faces the board's lower-left)
  as flat part-label colours and as a grey clay pass, front (yaw 0) and rear (yaw 180).
  `FRONT_YAW=0 /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P gust_shrike.py -- OUT_DIR`
- Prompts paint over the maquette: label colours are part labels, keep silhouette/overlap/camera, identity from the
  approved painting. Front and rear come from one pose, so they agree by construction.
- The part-label renders double as ownership masks for a future cutout rig.

## Primitives: rounded by default (owner 2026-10-13)
The gaoler pilot's cube helm, slab coat panels, straight column legs and brick boots made the paint-over read "quite
boxy". Build creatures from ellipsoids and tapered capsules; use `box` only for built objects, and then with a large
bevel (`bevel` is in the unit cube's local units, before scaling: 0.3–0.5 reads as rounded) and `taper` < 1 for
buckets/helms. Give the pose life: a slight hunch or lean, bent elbows and knees, a weight shift, plates that flare.
Frame the render at the drawn size (`ortho_scale` so the figure is target_h × K pixels tall) so the painting needs no
art_scale reduction.
