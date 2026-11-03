# mq-27 — Burrow Grub on the floor

Feedback 1 changes only the legs. Current numbers, the native pixel definition
and the retained front-far visibility TODO are in [feedback_1.md](feedback_1.md).

Structure for the director's repaint; no paint, runtime rig, motion, game data,
shadow, source painting or mq-05 delivery is changed. Everything is uncommitted.
Only this directory is owned. There are no shared builder changes or new global
test guards.

`recipe.py` projects the inherited mq-05 sculpture onto the brief's constraints.
It retains its folds, asymmetry, fleshy lip, teeth and hooked limb contours. It
does not fit a silhouette or landmarks to the old painting. The old evaluated
sculpture supplies the lower capture margin; one common support-plane Z offset
preserves the unchanged camera and framing. This offset does not affect gaps,
dimensions, pose or the front/rear relationship.

The camera remains orthographic 45°/30°, scale 2.4 m, target `[0,0,1.12]`, native
1024. A native square draws at 0.85 tile widths. A board diamond is sqrt(2) tile
metres wide, hence `L = 1.25 * 2.4 / (0.85 * sqrt(2)) = 2.4956709924 m`.

## Acceptance and measured proof

1. Every ring from `seg_1` through `tail` has a flattened support cap. Its local
   evaluated height/width is 0.8; every ring's gap is **4.572524512e-9 L**.
2. The inherited entire maw is rounded and grounded. The head gap is also
   **4.572524512e-9 L**. Lip height is **0.5490476305 m / 0.2200000049 L**;
   evaluated maw-plane upward tilt is effectively **0°** (floating point noise).
3. L is **1.25 tiles / 2.4956709924 m**. The least-squares line through the actual
   projected lower contact extrema is **26.84797980°**, inside 26.6° ±4°.
4. The inherited sideways curl is detrended into the board axis and bounded to
   **5.99862739°** maximum neighbouring plan turn. The inherited mass progression
   supplies the slight middle swell; its axial taper also reduces the blunt
   tail's width. Surface forms and creases remain sculpted geometry.
5. Six thick hooked stubs attach to `seg_1`, `seg_3`, `seg_5`, with the original
   labels. Feedback 1 limits axes to **0.075 L**, hip width to at least **0.05 L**,
   hip height to at most **0.09 L**, and native foot/body clearance to **34 px**.
   Actual front near clearances are **31/30/30 px**, rear visible far clearances
   **21/30/31 px**. Every foot gap remains **4.572524512e-9 L**. Front far stubs
   are occluded; the prior two-far-leg condition remains a named design TODO.
6. All **14 part/bone names and 33 joint names** match mq-05. Leg parents follow
   their newly required segment numbers. Rest joints match the transformed
   support roots and the inherited claw-bend landmarks.
7. Rear is the same immutable geometry and pose turned **180° about Z**, with
   up preserved. No reflected, independently fitted or reposed rear is used.
8. `delivery/floor_contact_report.json` measures final evaluated geometry, per
   ring and foot. The source-fit gate is replaced, not loosened.

`delivery/` contains 34 native-size front/rear clay, part, silhouette and solo
PNGs, `joints_px.json`, input/provenance, build/capture/contact/packing/coverage
reports and native/portable proof. `source_spec.json` retains inherited sculpt
inputs for provenance and the final joints/camera; the executable geometry
authority is `recipe.py` + `build.py`, not the old piece coordinates alone.
Native clay bytes are copied untouched. Semantic masks use mq-05's lossless
packing, preserving every alpha and every RGBA pixel with nonzero alpha.
Original native hashes remain in `capture_report.json` and `capture_packing.json`.

`delivery/review/hero_beside.png` shows both clays at art_scale 0.85 beside the
approved current hero rest at 1.03, using one 248-pixel tile width. The flat ground
and projected support axes are proof guides. No per-figure crop-to-fit scale is
used. Its JSON binds the hero and clay sources, common scale and placement.

## Reproduce / proof for the design owner

Run from this task worktree. Each bridge request has a hard 120 s deadline,
including queue time; an unanswered request stops the workflow without retry.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/burrow_grub/v2/workflow.py all
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/burrow_grub/v2/probe.py -- /private/tmp/labyrinth_codex/mq-27/build /Users/borgerding/workspace/Labyrinth.worktrees/mq-27/spec/art_identity/maquettes/burrow_grub/v2/delivery/focused_native_proof.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-27 && python3 -B spec/art_identity/maquettes/burrow_grub/v2/verify.py
```

The editable bone-bound maquette is retained locally at
`/private/tmp/labyrinth_codex/mq-27/build/maquette.blend`. It is regenerated rather
than delivered as a binary input, matching mq-05. The native probe independently
reopens this file, checks hashes, bindings, world poses and contacts, then rejects
all 13 deliberately lifted ring/foot fixtures.

Original delivery results (feedback 1 results are in `feedback_1.md`):

- `MQ27_BUILD: PASS`
- `MQ27_CAPTURE: PASS; front preview` / `front solos` / `rear preview` / `rear solos`
- `MQ27_DELIVERY: PASS`
- `MQ27_FOCUSED: PASS; 82/82 checks; 13/13 lift mutations rejected`
- `MQ27_PORTABLE: PASS; 83/83 checks`
- `python3 -B -m unittest spec.art_identity.maquettes.blender.test_sculpt_forms`:
  `Ran 7 tests in 0.153s` / `OK`.
- `python3 tests/test_art_identity_gate.py`: `Ran 111 tests in 65.486s` / `OK`.
  Existing NumPy runtime and Pillow deprecation warnings were emitted.
- Python suite audit only: `ISOLATION AUDIT: 53 modules`; exit 0. No new
  `tests/test*.py` module or resource registry entry is required.

Full suites, peer review, commits and publication were not run, per assignment.
Godot/windowed probes and `inspection_fixture.py` are not applicable: this unit
only produces offline maquette inputs and proof, with no game integration.

## Chosen defaults and unresolved design

The original delivery had no design placeholders; feedback 1 records
`TODO_DESIGN_FRONT_FAR_LEG_VISIBILITY` in `solo_coverage.json`. Non-player defaults are named in
`PROOF_DEFAULTS`: numerical epsilon 1e-6 m; 4096-step bound search; proof tile
width 248 px; sheet 960×360, floor y=270 and centres x=160/480/800; background RGB
69/65/58 and guide RGB 132/126/113; label offset -100/32, caption 24/336, axis
half-extent 1.5 m; mask alpha threshold 128 and RGB tolerance 2; joint projection
tolerance 0.011 px; mutation lift twice the limit. The 120 s bridge cap is mandated by the brief.
Shared sculpt sampling, part palette and rendering defaults are inherited
unchanged. No new player-visible colours, text, assets or tuning are selected.

## Director decision, 2026-11-01
Owner on `grub-paint-v2`: it runs too far into the neighboring tiles, scale it down. `art_scale` becomes **0.64** (the same painting; was 0.86), the Crawler's scale. This sits below the identity gate's new-creature bands (art_scale 0.75, drawn height 120), on the owner's word. The rig unit sets it in data and regrids at the hero's density.
