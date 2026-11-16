# emac-02 rounds 2/3 handoff

The director's round-3 ground-line precedence resolves round 2's bounds stop.
Changes remain uncommitted. No windowed run, Git write, queue edit, full suite,
review agent or sign-off was performed. The rejected earlier cases (`emac02_round0`,
`emac02_round1`) live only on the `codex/emac-02` branch; the current case is `emac02`.

## Acceptance criteria

1. **Size / re-adoption.** Replayed the untouched approved 1254² raw's recorded
   normalization to 1024². BOX reduction is 2.783505154639175 (4 × 135/194),
   recorded as `reduction_factor` alongside generation K=4. There is no upscale
   of a 255px image, no secondary fit (`fit_scale=1.0`) and art_scale stays 1.0.
   The resulting alpha bbox is `(42,60,244,254)`, height 194 vs hero 216 (0.8981).
   Every maquette part mask, solo and joint uses the same affine transform:
   `p_new = (p_old/4 - (128,254)) × 194/135 + (128,254)` for 1024px inputs.
   The root is `(128,242.5037037)`. All coordinates fit the canvas. The raw,
   normalized raw, refs, original maquette, prompt and canon were not repainted
   or rewritten. Twenty-three initial key residues plus one remaining rounded
   mean were removed with two recorded neighbour-mean processing steps; no
   opaque green-dominant texel survives in source, parts or sampled motion.
   The registration report is in the job's `registration.json`.
2. **Nine new cuts / hidden material.** All visible pieces were re-cut directly
   at the new source size. The round-1 sack-contour ownership correction is
   transformed with the paint. Sack-label islands on the painted upper body
   were reassigned to upper-body pieces, so those pixels cannot stay behind
   during a bob. Hidden requests were rebuilt from actual translated poses:
   legs 28, torso 5, sack 8 source pixels (41 total); every other request is zero.
   This uses the existing own/same-material fill route and preserves rest RGBA.
   The far forearm's two mesh influences translate identically; neither the
   hand nor any mesh vertex is independently pinned any more. The resulting
   rig has 11 joints, nine visible parts, three hidden parts and one 3570-vertex
   mesh. Structural validation is clean.
3. **Rigid idle / glow.** The motion script now contains only bind positions
   plus group translations and the glow sampler. It has no breath scale, head
   lag, nod, look-up, rotation, forearm solve, stretch or skew. The seven upper
   pieces (and far-hand helper influence) follow the protagonist's smoothstep
   keys `(0,0),(.18,2),(.55,2),(.91,0),(1,0)`, rounded to whole source pixels.
   The existing rr-05 `phase_for` clock supplies 10fps holds. Legs and sack stay
   still. Bob period is 1.68s; loop/glow period 3.36s; sack glow lag .84s;
   reduced motion holds rest and .15 glow. The existing board elapsed clock is
   retained across syncs. The saturation cutoff stays .75. The actual overlays
   select exactly these original-paint pixels (xyxy exclusive):
   - eye 1: `(103,109,107,112)`, 12 pixels;
   - eye 2: `(117,109,121,113)`, 14 pixels;
   - sack tear: `(221,241,230,247)`, 36 pixels.
   Two other orange skin texels belong to `near_hand`, which has no overlay.
4. **Portrait / placement.** All existing painted landmarks were transformed
   with the same affine map. The new region is
   `[51.06657095,54,120.81500625,120.81500625]`: six pixels above hood top 60,
   1.9 times the new head-shell width, centred at face x=111.47407407.
   The existing optional crop helper remains in use. No other NPC data or
   accent changed; old anime sheets remain unused.

## Board and shadow input audit

- `combat_board_view.gd::_unit_center` reads tile/world-position presentation.
- `_unit_draw_rect_for_texture` fits the neutral 255×255 texture to the existing
  tile frame, applies NPC art_scale and offset. Emac has no ActorPresentation
  root/contact profile. It does not read a bone or rig root.
- `_unit_texture_draw_rect` supplies padded viewport art using that same logical
  rectangle. Root motion is inside the texture, not a placement offset.
- `_unit_shadow_foot_point` reads neutral rest silhouette bounds: bbox centre x
  and bottom y divided by texture size. Ground y remains 254/255. The shadow
  geometry must be refreshed after native rest rebake so it follows the larger
  seat/sack silhouette. No root-based compensation or placement nudge is needed.
- Waypoint fit still uses the round-1 existing room rectangle. `BoardFraming`
  uses room/floor geometry and fixed encounter envelopes, not this NPC's root.
  The real-game headless probe compares the original round-1 normal placement:
  tile width is exactly 149.413848876953 before and after; hero and NPC logical
  rectangles are byte-for-byte equal. NPC rectangle remains
  `(957.7587891,286.9480591,153.8962708,153.8962708)`; measured shadow ground y
  440.240814 matches canvas ground y 440.240816 (float tolerance).
  `proof/board_placement_comparison.json` retains both measurements.

## Proof observed

See `ROUND3_RESULTS.md` for exact result lines and limitations. The CPU diagnostic
uses the binding spec's `idle_pixel_errors` and `idle_group_offset`: 337 actual
Godot poses, upper mismatches 0, lower mismatches 0, offsets {0,1,2}, green 0.
This is source/transform evidence, not native skin raster approval.

`rigid_probe.gd` captures isolated native upper/lower groups, with glow disabled
only for identity comparison. It captures rest plus every presented hold at
0,.1,…,3.3,3.36s (70 samples / 72 images). `rigid_gate.py` applies the same shared
pixel gate and checks every basis and group offset. It refuses headless manifests
and stale case hashes. Normal reels/captures retain the glow. Native mismatch
counts remain pending the owner's run.

The source/cel review sheet is the job's `sheet.png`. The painted true-scale
hero / Emaciated Man / Grave Surgeon proof is
`experiments/cutouts/emaciated_man/emac02/proof/board_comparison.png`, with native
and 2× NEAREST rows. The source portrait crop is beside it. These were inspected.
No native screenshot or native rest record is claimed for this revision.

## Chosen defaults / design placeholders

No active TODO_DESIGN field remains. New proof-only choices are 336 intervals
(337 poses), and 224 reel frames at .015s so all requested .21s keys/glow peaks
are exact while satisfying the toolkit's 240-frame limit. Existing proof defaults
remain: 2×1 mesh grid, one-pixel hidden-request raster margin, proof hero `(3,3)`,
and actor visibility thresholds 8/255 RGB difference and .10 changed box fraction.
No player-facing value was chosen beyond the director's supplied revision.

## Proof for the design owner

Run from this worktree in order. Use fresh output directories. The owner retains
native judgment, rest certification, inspection fixture and publication.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/emac-02
python3 tools/visual_probe_runner.py tools/rebake_cutout_rests.gd --task-id emac-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 -- --only emaciated_man_cutout
python3 tools/process_board_density.py --record-rests --only emaciated_man_cutout
python3 tools/godot_task_runner.py --task-id emac-02 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
python3 tools/emaciated_man_cutout/install.py --refresh-identity
python3 tools/process_board_density.py --check --only emaciated_man_cutout
python3 tools/cel_look.py build --if-stale
python3 tools/emaciated_man_cutout/comparison.py
python3 tools/art_identity_gate.py sheet --front assets/units/emaciated_man_cutout/front/rest.png --kit spec/art_identity/jobs/emaciated_man/mq_front/kit.json --landmarks spec/art_identity/jobs/emaciated_man/mq_front/landmarks_pair.json --out spec/art_identity/jobs/emaciated_man/mq_front/sheet.png
python3 tools/visual_probe_runner.py tools/emaciated_man_cutout/rigid_probe.gd --task-id emac-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --proof-contract tools/emaciated_man_cutout/rigid_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/emac-02/rigid-native-r3.json
python3 tools/emaciated_man_cutout/rigid_gate.py --runner-manifest /private/tmp/labyrinth_codex/emac-02/rigid-native-r3.json
python3 tools/cutout_workflow.py render experiments/cutouts/emaciated_man/emac02 --output /private/tmp/labyrinth_codex/emac-02/native-idle-r3 --task-id emac-02
python3 tools/cutout_workflow.py verify-render experiments/cutouts/emaciated_man/emac02 --output /private/tmp/labyrinth_codex/emac-02/native-idle-r3
python3 tools/emaciated_man_cutout/keyframes.py --render /private/tmp/labyrinth_codex/emac-02/native-idle-r3
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/emaciated_man_cutout/game_probe.gd --task-id emac-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/emaciated_man_cutout/game_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/emac-02/game-native-r3.json
```

Native keys: `native-idle-r3/keyframes/idle_00.00s_1x.png` etc., every .21s over
one 1.68s bob plus the 2.52s sack glow peak and complete 3.36s loop boundary.
Both 1× and 2× are collected. The game-speed reel is
`native-idle-r3/videos/cutout_review.mp4`. The game manifest locates normal and
adjacent-hero waypoint captures, portrait, reduced motion and body-hidden
references, all at 1920×1080 / UI scale 1. Inspect the contact shadow under the
seat and sack in `central_waypoint.png` after the refreshed shadow-cache step.

The native sequence scopes density acceptance to emac; the global check and its
unchanged Gaoler rest failures are recorded in ROUND3_RESULTS.md.
