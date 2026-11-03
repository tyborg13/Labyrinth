# rr-32 — Gale Herald, humanoid v2

## rr-34 — far thigh behind the loincloth

The front approved painting has the near thigh over the cloth. The front case
and both production layouts therefore exchange only the tabard/far-thigh depths:
`leg_far=3 < tabard=5 < leg_near=6`. Every other pair retains its prior order.
The rear painting and layout already agree (`tabard=13`, far thigh 7, near thigh
3); all rear bytes remain unchanged. No painting, piece, hidden continuation,
mesh geometry, motion key, density input, native rest or shadow is rebuilt.
The existing six-pixel connected cloth continuation and move-only air-domain
continuation remain in place; the CPU seam sweep checks their coverage.

`rr34_layering.py` applies this correction to current metadata without rebuilding
paint. `rr32_build.py` applies the same rule to future builds. The strict repair
gate now rejects a reversed front overlap or a different mesh/proof depth, and
`tests/test_rr34_layering.py` includes negative controls. The production runtime
check also samples every clip at the native proof's 60 Hz, including endpoints,
and checks the actual Polygon2D depths after every pose.

Fresh headless results and limitations are recorded in
[`mq12/proof/rr34_validation.json`](mq12/proof/rr34_validation.json). Logs and CPU
diagnostics live under `mq12/proof/logs/rr34_*` and
`mq12/proof/seam_cpu/rr34/`; these are diagnostic pixels, not native captures.
Herald checks pass. The broad suites retain failures in unchanged Thrall/Weaver
recorders and terrain/HUD/fixture checks; exact result lines are in the receipt.
No windowed run was attempted. Existing native evidence remains bound to its
original inputs and needs recapture. The design owner owns review, commits,
inspection and publication; all implementation changes remain uncommitted.

Proof for the design owner (1920x1080, 100% UI scale; existing native, sheets
and review probes/contracts are reused):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-34 && sh experiments/cutouts/gale_herald/rr34_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-34 && sh experiments/cutouts/gale_herald/rr34_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-34 && sh experiments/cutouts/gale_herald/rr34_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-34 && sh experiments/cutouts/gale_herald/rr34_proof.sh review
```

Captures: `mq12/proof/native_rest/rest_pair.png`, `mq12/proof/native/`,
`mq12/proof/contact_sheets/`, and `mq12/proof/gale_herald_review.mp4`.
No inspection-fixture command is requested by this unit. TODO_DESIGN: none.
Chosen defaults are test-only: `LAYER_PROOF_FPS=60` reuses native sampling;
`MUTATION_DEPTH_DELTA=1` and `MUTATION_MESH_DEPTH=0` are rejected test depths.
The full Godot suite uses a 900-second runner budget for its documented
integrated workload. No new player-facing values are chosen.

## rr-32 implementation record

Implementation in `mq12/`; production in `assets/units/gale_herald_cutout/humanoid_v2/`.
The owner retains commits, full suites, review, inspection and publication. All
worker changes remain uncommitted. No art was generated or repainted.

1. **Cut:** rigid head/mask, shoulder wrap and belt on torso, pelvis, both hands,
   horn and boots; seven skinned surfaces (two arms, two legs, tabard, two banners).
   Source ownership uses the certified mq12 categorical maps/solos and rr07
   registration. The native torso/tunic label supplies the pelvis; the belt
   supplies the rigid torso. Native banner-root planes transfer the body-side
   shoulder yoke into that torso. Joints, arm lengths and rest bend sides come
   from the delivery; knees declare front -1 / rear +1 for both legs. Tucks use
   the existing 3 px same-surface continuation rule. Feature masks protect the
   complete original head/banner surfaces, including mask and worn insignia.
   Both visible source rests have **0 mismatched pixels**. The front painting
   contains one alpha-zero pixel with nonzero hidden RGB; `approved.png` retains
   its original bytes and the renderer reference `render_reference.png` clears only
   invisible RGB. `processed.png` and its certificate also retain the supplied
   bytes unchanged; the separate render reference records its own pixel hash. The rear needs no such normalization.
2. **Idle:** director feedback 1 is imported byte for byte into case and
   production. Only torso lift and the pre-computed upper-far-arm lag curve are
   keyed. The whole horn arm uses FK; the banners have no idle keys. The three
   rigid groups retain the shared strict bone and pixel gates.
3. **Production:** one registration enables board, pre-battle, portraits and
   removes the type from the derived static rosters. All three intent selectors
   and movement use shared playback. Contact declarations retain existing VFX,
   outcomes and cues (`push.slide`, `spell.air`, `block.gain`); the wind-call cue
   moves from action start to its protected contact. Death uses the declared
   1.5 s clip, then existing dissolve. Both production views are exercised by
   actual resolver -> RunScene callbacks, including hit and death. Paint is
   density adopted/processed. Native rest fingerprints and shadow refresh remain
   director-run steps; integration deliberately remains `ready: false`.
4. **Gates:** shared cut/source/idle/signed-motion/direction/knee/support/reach
   gates and full native piece/seam/stray gates are wired. Every action has
   direction coverage. Horn grip/world angle are checked through all clips;
   non-death offsets remain within 35 degrees. Reach overextension remains a
   diagnostic. Director feedback 1 keys the folded horn hand only for Call the
   Wind, and caps terminal banner lift at 4 px. Gust Bolt direction measures
   torso.forward_px against the same pose with that channel zeroed, using the
   strict positive-dot rule. The other actions retain shared hand direction
   checks; the combined contract requires all six action clips. Native pixel
   acceptance awaits the owner.

`mq12/proof/validation.json` records observed result lines and limitations;
`gates.json` records every unwaived gate result. Full samples, callback histories and
transcripts are under ignored `proof/logs/`; the sample index hashes its full
report. No windowed run was attempted. No inspection-fixture command was
requested for this unit; fixture creation belongs to the design owner.

## Director feedback 2: native ownership and coverage repairs

The director's 259-error native report is retained verbatim in
`mq12/proof/feedback2_director_native_gates.json`. It describes the previous cut;
fresh native acceptance is pending. No gate exception was added. All protected
motion keys remain byte-identical, including the **-30 degree death horn key**.
No new art, joints, mechanics, runtime modules or dependencies were introduced.

1. The reported front shoulder/banner gap maps to the `cape_near` root in the
   actual isolated-layer ownership. Its root now has a continuous same-material
   tuck under the tunic, including an action-only continuation where rest is air.
2. The horn pivot was already the supplied grip joint. The source categorical
   masks incorrectly divided brass shaft and glove paint between `horn`,
   `head`, `hand_far`, `arm_far` and `torso`. The repaired cut moves the original
   RGBA to the physical item/glove/sleeve owners and supplies the complete hidden
   shaft under the fist. Horn and hidden horn share one whole-source-pixel raster
   anchor at the grip; the fractional authored bone/pivot is unchanged. No death
   angle reduction was needed in the CPU diagnostic.
3. Correct hood/fist ownership and connected non-outline continuation replace
   the face-side scraps. The near sleeve's inner elbow also has continuous
   action coverage when it folds away from the body.
4. Rear hidden surfaces are rebuilt from their corrected connected physical
   surfaces with the shared rr05 nearest non-outline donor rule. This removes
   inherited outline fringe while covering the sinking torso's joints. Small
   horn-arm islands formerly attached to the rear banner now follow the arm.
5. The 13px sliver is the front `tabard` island at source `[159,161,161,168]`.
   It is the edge of the adjacent rigid near glove and now belongs to
   `hand_near`. The other detached tabard island belongs to the near trouser.
6. The 60px mouthpiece at source `[89,38,99,47]` was owned by `head`; it now
   belongs to the same rigid horn as the bell and shaft.
7. The remaining gait/cloth/cuff joins use connected own-edge continuations,
   limited to the measured inner seam domains. Action-only donors use the
   existing shared continuation path, including density-treated production
   donor texels. Rest and idle keep the approved transparent pixels.

`rr32_repairs.py` owns the deterministic source cut/coverage recipe;
`mq12/ownership_repairs/` records every original pixel's exclusive owner.
`rr32_repair_checks.py` validates the partition, unmodified RGBA, continuous
shaft and shared anchors. `rr32_coverage.py` sweeps every 60Hz pose through the
shared CPU raster, strict joint-pocket and source-component checks. It is a
CPU diagnostic, never a replacement for native renderer proof. Its conservative
rest-mask triangle filter is tested byte-for-byte against the full reference.

The final receipt is `mq12/proof/feedback2_validation.json`. Raw CPU diagnostic
captures are under `mq12/proof/seam_cpu/feedback2/`, and transcripts under
`mq12/proof/logs/feedback2/`. Source rests remain 0px; production paint is
re-adopted and processed with the existing density parameters. The two derived
native production rests and Herald shadows need the director's `density` command
before fresh production inspection. Full suites and windowed runs remain owner
steps.

## Files and shared extensions

- `rr32_case.py`, `rr32_build.py`, `rr32_surfaces.py`: anatomy, protected input
  registration, segmentation, cloth meshes, source features and promotion.
- `rr32_motion_import.py`: byte-exact director replacement import that verifies
  347 paint/anatomy files remain unchanged, then updates compilation/provenance.
- `rr32_direction.py`: strict torso-led Gust Bolt direction and complete action
  coverage, alongside the shared hand-target gate.
- `rr32_density.py`: scoped source adoption, density/identity records and pending
  native-rest integration; every unrelated identity record retains its bytes.
- `rr32_evidence.py`, `rr32_gates.py`, `rr32_production.py`, `rr32_validate.py`,
  `proof.sh`: evidence, validation, actual contact checks and owner commands.
- `mq12/**`, `assets/units/gale_herald_cutout/**`, corresponding density sources
  and three registry/output files: editable case and shipped source closure.
- `tests/rr32/**`, `tests/test_rr32_herald.py`,
  `tests/test_rr32_production.py`: probes, proof contracts, checks and mutations.
- `tools/humanoid_cutout/source_view.py`: hash-checked approved raw-step replay
  when an input has no raw-file hash; old file-based inputs keep their path.
- `tools/maquette_cutout.py`: omitted orthographic distance uses the native
  renderer's existing 30-unit distance; explicit cameras are unchanged.
- `scripts/maquette_cutout_runtime/presentation.gd`: Herald registration.
- `scripts/maquette_cutout_runtime/action.gd`, `contact_actions.gd`, and the single
  dispatch guard in `scripts/run_scene.gd`: opt-in contact cue declaration. Other
  units retain their previous cue schedules. No mechanics, saves, analytics
  emitters, event schemas, icons, balance values or authored assets changed.

Earlier humanoid assets/cases remain byte-identical to HEAD. Tests and shared
extensions are additive; rr33's figure and its registration are untouched.

## Headless reproduction

Run from this worktree. The validator's `all` means the brief's focused sets,
three SFX programs, identity checks and registration audit; it does not run full
Godot or Python suites. `mimic` redirects its missing ignored rr26 fixture folder
into a task temporary directory. `mortar` adds the test directory to Python's
module path. Neither changes source or assertions.

```sh
python3 experiments/cutouts/gale_herald/rr32_validate.py --family all
PYTHONPATH=tools python3 experiments/cutouts/gale_herald/rr32_evidence.py --refresh
python3 experiments/cutouts/gale_herald/rr32_gates.py
```

The strict gates remain unchanged in strength. Director feedback 1 resolves
all four former design placeholders. Fresh results are in
`proof/feedback1_validation.json`; initial invocation history remains in
`proof/initial_validation.json`. Re-import a future authorized director replacement with
`python3 experiments/cutouts/gale_herald/rr32_motion_import.py`; it never rebuilds
paint, anatomy or density treatment.

## Proof for the design owner

Each command starts in the task worktree; scripts use the required Godot/visual
runners. Native proof is 1920x1080 at 100% UI scale. `density` rebakes the processed
production rests, records them, refreshes only Herald shadows, checks derivation
and seals provenance. `rest` compares the unprocessed editable cut against both
approved paintings. `idle` captures both views beside the matching protagonist
view on each actor's own production period. `production` captures both views.
`sheets` and `review` create inspection material even when gates fail, then return
the gate's failure status. Captures and movies remain ignored.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-32 && sh experiments/cutouts/gale_herald/proof.sh review
```

Paths beneath `mq12/proof/`: `native_rest/`, `native/`, `contact_sheets/`,
`idle_native/{front,rear}/`, `production_native/{front,rear}/`, and
`gale_herald_review.mp4`. Existing captures describe their recorded input hashes; the repairs require fresh captures.

## TODO_DESIGN placeholders

None remain. Director feedback 1 supplies the rigid FK idle, confines horn-hand
IK to Call the Wind, and limits terminal banner tips to -4 px. The protected
replacement is `3a55e2f5fab1ca0b348624fe83611806e7c77a59aa3ef7ee73d01462431739fe`
(SHA-256). All four former placeholders are removed from case inputs, cutout
metadata and production integration. Native renderer proof remains pending.

## Chosen defaults

Only proof/test values were chosen or inherited from the reference harnesses:

- Capture: `SIZE=1920x1080`, `POSE_SIZE=512x512`, `ORIGIN=(128,128)`, `FPS=60`,
  `PROOF_LABEL_Y=60`, `PROOF_LABEL_HEIGHT=60`, `PROOF_VERTICAL_OFFSET=40`,
  `PROOF_REPRESENTATIVES=6`, `IDLE_COMPARISON_LOOPS=5`, two inspection columns at
  25%/75% width, `background.color=#1e1e24`, and 2x nearest enlargement. Actual board step/scale are measured.
- Fixtures: `SETTLE_FRAMES=8`, `HIT_PROOF_HP=30`, front/rear tiles `(2,4)/(6,4)`,
  hit tiles `(3,4)/(5,4)`, `PROOF_RUN_SEED=91210`; settings/profiles use isolated
  `user://rr32_*` names.
- `TEST_DEFAULTS`: subprocess timeout 180 s; mutation translation 2 px, angle 40
  degrees, forward displacement 100 px, over-budget cloth mutation 6 px; 8x8 RGBA fixture, paint `(80,60,40,255)`,
  stray `(255,255,255,255)`. Rejected raw replay uses a blank 1x1 fixture.
  Production mutations use phase delta .01 and pose delta 1 px.
- CPU diagnostic mask UV margin: 1 source px, a conservative transparent-triangle filter only; verified against the full reference.
- Existing serialized transform tolerance .0001; owner-windowed command budgets
  120/180/300/900/3600 s mirror the known reference capture workloads. These are
  proof timeouts, not runtime tuning.

Hero idle .84 s, Herald clip timings/keys, native camera distance 30, weight-grid
and continuation rules, knee policy, dissolve timing and density strength are
inherited approved data/rules, not newly tuned player values.
