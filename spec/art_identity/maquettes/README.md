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
