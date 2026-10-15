# rr-03 — round 1 (director: inputs and all TODO_DESIGN decisions)

Work on top of the current uncommitted state. Do not commit.
1. **Blender outputs**: run by the director — `experiments/cutouts/gust_shrike/maquette/` (23 files: parts, clay, solos,
   joints_px.json, spec.json, view_transforms.json).
2. **Approved raws**: `experiments/cutouts/gust_shrike/inputs/front_raw.png` (sha256 a43816b7191b…) and `rear_raw.png`
   (b236be7b28e3…), byte copies of the imagegen originals matching the approved processed records.
3. **Motion tracks**: `spec/peer_benchmark/staged/rr-03/motion_tracks.json` (protected director data; copy, never edit).
   Semantic channels (see `_channels`) — you map them to per-view rigid transforms with the exported view transforms.
   Idle head intervals include their 2-frame snap. Dive: contact at the end of the 0.35 s flight, then six recovery
   frames at 1/30 s (keys at frames 1, 3, 6, smooth between). Talon rake contact phase 0.5.
4. **Masks / occlusion**: explicit no-occlusion finding for both views for now (the bird painting has no between-part
   painted shadow comparable to the gaoler's legs); bird semantic classes = body, head (incl. beak and mask), wing_near,
   wing_far, tail, legs. The motion gates (specks, magenta, hidden fill value) still apply; I will review the reel and
   add occlusion rules only if something reads wrong.
Then build the rig, run the gates headless, and list the windowed rest/render/verify/gates/proof commands plus the
production board capture (idle, move, dive, talon rake, hover, hit, death) at 1920×1080.
