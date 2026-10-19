# rr-21 — Briar Weaver humanoid v2

Implementation is uncommitted on `codex/rr-21`. The design owner retains commit,
peer review, native inspection and publication. No windowed command was run.
The protected director JSON is copied byte for byte to the editable case and
production. No maquette, source painting, sound, icon, font or gameplay value
was changed. The Glacial Mirror / rr-18 reference is absent from this checkout;
its tests and byte-preservation checks cannot be run here.

## Numbered acceptance

1. **Cut.** `mq9/anatomy.json` owns the hierarchy, knee policy, per-view long-leg
   roles and idle membership. Head (including the front-only eye), mantle/thorns
   on torso, pelvis, hands and feet are rigid. Each arm and leg is one mesh over
   its two bones; tatters are one pelvis/mid/tip cloth field. Shoulder, limb and
   body pivots come from the certified native joints. Cloth tip is the lowest
   native leaf vertex set; mid is its geometric subdivision from pelvis. Both
   source paintings reconstruct with **0 mismatching pixels**. Hidden supports
   use the existing same-surface source-texel/tuck routines, without repainting.
2. **Idle.** Both free arms belong to the upper-body group with torso/head. The
   unused weapon group has no paint and a stationary root reference. Lower body
   remains still. The unchanged shared sampler supplies the protected 0.84 s,
   2 px whole-pixel bob; slot-based actor phase seeding is declared in integration.
   Headless real Bone2D checks pass. Every-pixel idle rigidity awaits native proof.
3. **Production.** The registered renderer serves board, pre-battle LiveActor and
   both portrait consumers. The public legacy portrait identity map is retained
   for compatibility, just as for the Seer, Thrall and Capacitor; the live atlas
   replaces its still through registered dispatch. Static facing no longer owns
   registered cutouts. `move` uses the existing intent-independent movement path.
   Thornwall and mend use a declared case action adapter; lash retains the existing
   ranged pipeline. Real callbacks prove three brambles at .55, the earth lash cue
   at .45, and a 4 HP ally heal with the existing heal cue at .55. Hit recovers to
   idle; death uses the declared 1.5 s clip and existing fade. Front and rear
   production bones and painted-node transforms match independently loaded source
   rigs at every captured phase. Paint density is adopted and processed; the
   source-space rest is provisional until the director's native density rebake.
   The scoped shadow refresh adds two Briar rests and retains all 68 prior entries.
4. **Gates.** Both views pass source cuts, signed bone motion, idle transforms,
   lash/thornwall positive direction coverage, and inside-minimum reach checks.
   Dense reach samples 1000 intervals plus keys; front/rear overreach is reported
   (6/3 paths), as required. Rear move knees/supports pass at both reference and
   measured board scale. Front move acceptance fails as detailed below. Clean
   pieces, seams, stray pixels, rigid native agreement, per-pixel idle and the
   strict green presented-frame check have complete native probes/contracts but
   await the director's renderer. No seam exception was invented for this case.

## Shared extensions

- `presentation.gd`: one roster registration; optional integration `rig_directory`;
  select a family renderer by resource presence rather than adding name branches.
- `action.gd`: optional integration `action_aliases` and `action_script` declarations.
  The heal resolver calls its feedback `heal`; this case maps it to `heal_ally`.
- `run_scene.gd`: six-line generic adapter dispatch using `source_actor_key` when
  present, so an ally heal animates the source while feedback stays on the recipient.
- `static_enemy_facing.gd`: registered dynamic cutouts leave static facing dispatch.

The declarations are absent for previous families, preserving their dispatch.
The Seer, Thrall and Capacitor case/production assets remain byte-identical.
Identity and density registry edits are scoped to Briar. The identity writer
preserves every unrelated source byte, including pre-existing duplicate keys.

## TODO_DESIGN and open acceptance

- `TODO_DESIGN_green_eye_gate` (`mq9/inputs.json`): the protected front painting
  contains 23 green-dominant eye texels, owned by head. The brief simultaneously
  preserves this eye and forbids all green-dominant presented texels. The source
  is unchanged; the strict native green gate rejects them without an exception.
- `TODO_DESIGN_front_move_knee_apex` (`mq9/inputs.json`): both front stride swings
  exceed the 15-degree minimum but are less bent than the trailing knee at the
  lift apex. At the reference step their apex bends are 44.086477 / 53.697168
  degrees against 55.491477 degrees for trailing. At actual board scale they
  are 24.284211 / 51.702210 degrees against the same trailing bend.
- `TODO_DESIGN_front_move_supports` (named constant in `rr21_production.py`): at
  the measured board step (~138.397 source px), three sampled stance frames miss
  the inherited 0.7072 px target radius (maximum 0.952621 px), then one frame
  shifts the planted stride by 1 px. The rear supports pass. Do not stretch the
  native chain, edit protected keys or relax the gate to hide this.

Native density/rest, pixel gates, production captures and visual judgment remain
pending. `process_board_density.py --check --only briar_weaver_cutout` currently
reports the expected two missing native rebake records. Production readiness is
explicitly false. The design owner must resolve the three findings above.

## Headless proof

Use the task runner for every engine invocation. Focused tests include mutations
for wrong knee side, mesh weights, idle rotation/pixels, missing/stale evidence,
reversed action targets, overreach reporting, stray pixels, early healing, late
contact, missing physical poses and changed production bone transforms.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && LABYRINTH_TASK_ID=rr-21 python3 -B -m unittest tests.test_rr21_cutout tests.test_rr21_production -q
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input experiments/cutouts/briar_weaver/mq9/proof/logs/production/front/logic_frames.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input experiments/cutouts/briar_weaver/mq9/proof/logs/production/rear/logic_frames.json
```

Exact final observed result lines, commands and unresolved gates are in
`rr21_results.json`; raw transcripts and real production frame records are under
`mq9/proof/logs/`. `mq9/proof/{build,samples,gates}.json` retain source and bone
proof. Full suites are deliberately left to the director at merge, per the unit
brief. The three SFX programs and registration audit run separately. The broad
reference run's sole failure was its public portrait-map compatibility assertion;
restoring that identity fallback fixed it without changing the assertion, and
all five integration tests then passed.

## Proof for the design owner

Run these exact stages from this worktree. The shell script contains every
expanded visual-runner command, explicit renderer, proof contract, output path
and timeout. Captures are 1920x1080 at 100% UI scale; the density stage writes
native 255px source rests. It then records rests, refreshes only Briar shadows,
checks density and seals provenance. No inspection fixture is created by this
worker; the owner owns that workflow phase.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh review
```

Expected capture paths, all under `mq9/proof/` and gitignored before any run:

- `native_rest/{rest_pair,front_rest,rear_rest}.png`
- `native/{frames.json,front_rest.png,rear_rest.png,pair_*/frame_*.png}` and
  isolated piece/check/seam/rest-hole surfaces
- `contact_sheets/{front,rear}_*_3x.png`
- `idle_native/idle_comparison/frame_*.png` and
  `briar_weaver_protagonist_idle.mp4`
- `production_native/{front,rear}/{frames.json,frame_*.png,gates.json}`
- `briar_weaver_review.mp4`

The gates intentionally return nonzero for unresolved acceptance findings.
Native pixel evidence is never substituted with headless or CPU raster evidence.

## Chosen defaults

Only proof/test values were selected. Front/rear actor tiles are (2,4)/(6,4),
ally tiles (3,4)/(5,4), named `PROOF_*_TILE` in the production probe. Existing
reference defaults are retained for proof clocks, HP fixtures, camera/label
geometry, settling, 60 fps sampling, a 96px reference step at 2x scale, 1e-4
serialized-transform tolerance and timeouts (native 3600 s; production 900 s;
idle 300 s; density 180 s; rest 120 s; headless tests 180 s). They are not live
motion or balance values. New negative controls use named 1px translation,
1000px impossible target, 8x8 synthetic RGBA surface and (80,60,40,255) test paint.
A temporary maquette-solo inspection sheet used 160px cells, 8 columns and 20px
labels; it is not a game asset. No player-facing defaults were chosen.
