# rr-20 — Hollow Mimic humanoid v2

Implementation is uncommitted on `codex/rr-20`. The design owner owns commit,
peer review, the inspection fixture and publication. No windowed command was
attempted. No art was generated or repainted.

## Numbered requirements and task contract

1. `rr20/` owns both mq-09 source registrations, certified maquette input
   hashes, exact visible ownership, covered continuations, anatomy, source
   masks and the compiled rig. Each view has four two-bone skinned limbs;
   head/hair/mask, torso, pelvis, gloves and boots are rigid. The violet crack
   is a front-only head feature. Both source rests reconstruct with **0 px**
   mismatch. Front stride is near, rear stride is far; every leg/view declares
   its facing bend policy. Production paint is adopted and density processed.
   Its native rest rebake, rest records and shadow refresh await the director.
2. The protected `motion_tracks.json` is copied byte for byte to
   `rr20/director_motion.json` and production. The shared compiler interprets
   every supplied channel without a new channel semantic or modified key.
   Upper body and both free arms bob as one rigid group; lower body is still.
   The empty weapon group retains the root as its proof anchor.
3. The production registry routes board, pre-battle actors and live portraits
   to the new two-view adapter. Every movement tile uses `move`; Shade Bolt
   uses `bolt`, the existing en06 marker selects `mirror` for every copied
   action, and Recede's guard uses `block`. Contact playback submits the
   existing effect and outcome at the protected contact and uses existing
   pacing cues. Existing melee preparation swings and approach footsteps stay
   on their established clocks. Hit and terminal death use the shared runtime;
   the data-owned death declaration runs collapse before the existing fade.
   Static facing/reaction lists no longer claim this identity. The existing
   portrait path dictionary remains unchanged; the live binding replaces its
   displayed texture by the same established registration path as the Seer.
4. Headless gates use actual Bone2D samples: all authored keys/midpoints plus
   all presented frames, strict positive direction coverage for `bolt` and
   `mirror`, every stride swing, supports and 1000-interval dense reach. Native
   proof scripts check exact idle pixels, clean isolated GPU pieces, seams,
   stray pixels and the green rule without exemptions. These GPU checks are
   prepared and load headlessly; they have **not** run. The aggregate source
   gate deliberately remains failed for the protected source conflict below.

The three recorded task acceptance criteria are covered by requirements 1–4.
Source identity, motion import and headless integration are verified. Native
appearance, density rests and final gate acceptance remain director work.

## Small generic extensions

- `scripts/maquette_cutout_runtime/contact_actions.gd`: opt-in, data-declared
  contact playback; `run_scene.gd` adds only the dispatch hook.
- `action.gd`: integration `step_selectors` map existing resolver flags to a
  clip, preserving the copied action type and all gameplay/analytics payloads.
- `humanoid_motion.gd`: optional `planted_during_death` support. Undeclared
  figures retain the previous path. Both boots plant during the actual sink.
- `presentation.gd` registers the identity and discovers concrete adapters;
  `static_enemy_facing.gd` consults that registry. `cutout_context.gd` removes
  only this identity from its static list. No new creature-name branches were
  added to shared code.

The untouched source and prior Seer/Thrall/Capacitor closures are bound in
`rr20/protected_inputs.json` (3,528 files). The rr-18 Mirror case/production
assets are absent from this checkout, so its cutout regression cannot be run.
Its maquette tests are not a substitute for that missing rig set.

## Tests and headless proof

Exact observed result lines and commands are retained in
`rr20/proof/verification.json`; detailed logs stay gitignored under
`rr20/proof/logs/`. The focused suites are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && python3 -B -m unittest tests.test_rr20_cutout tests.test_rr20_production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && python3 tools/godot_task_runner.py --task-id rr-20 --stream -- godot --headless --path . --script tests/rr20/samples.gd -- --case res://experiments/cutouts/hollow_mimic/rr20 --output res://experiments/cutouts/hollow_mimic/rr20/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && python3 -B experiments/cutouts/hollow_mimic/gates.py
```

The last command is expected to fail while the protected rear green texel
remains. The focused tests verify that this failure stays visible; their PASS
is not a visual acceptance or a green-gate exemption. No full suite was run,
as directed by the unit brief.

## Proof for the design owner

Run these exact stages in order. Each stage expands to the required repo
runner(s) and explicit proof contracts in `proof.sh`. Every visual stage uses
1920×1080 and 100% UI scale. Resolve the protected-source green conflict before
expecting `native`, `sheets` or `review` gates to accept.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-20 && sh experiments/cutouts/hollow_mimic/proof.sh review
```

Expected capture paths under `rr20/proof/`:

- `native_rest/rest_pair.png`, `native_rest/{front,rear}_rest.png`;
- `native/{frames.json,pair_<clip>/frame_*.png,pieces/,holes/,seams/}`;
- `contact_sheets/{front,rear}_<clip>_3x.png`;
- `idle_native/idle_comparison/frame_*.png` and
  `hollow_mimic_protagonist_idle.mp4` (five cycles beside the protagonist);
- `production_native/{front,rear}/{whirlwind_slash,quick_stab,hurl_spear}/`
  with full-frame captures and `frames.json` / `verification.json`;
- `hollow_mimic_review.mp4`.

The production stage covers real area, melee and ranged copies in both views,
including the embedded approach movement. The density stage rebakes only this
unit, records its two native rests and refreshes only its two shadow records.
No inspection fixture was created here; the brief assigns it to the director.

## TODO_DESIGN and open issues

`TODO_DESIGN_rear_green_texel` is recorded in `inputs.json`, `cutout.json` and
production `integration.json`. The protected rear painting contains opaque
RGBA `(0,26,7,255)` at source `(125,54)`. It exceeds the inherited Mirror rule
`G > R + 12 && G > B + 12`. Changing it would violate protected art and exact
source rest. No exception, recolour or relaxed threshold was introduced.

The protected death preload raises the pelvis 1 px at .15 while the near leg
is nearly straight. Exact floor support is geometrically unreachable there.
The runtime retains the supplied keys and existing length clamp; the support
report records maximum unclamped excess **0.856754 px front / 0.689794 px rear**.
Presentation can move the boot by one pixel during that preload. The subsequent
sink plants both boots. Dense reach also reports six overreach paths without
failing them, as the brief requires. No timing or tuning value was changed.

Fresh GPU seam/clean-piece acceptance, final density rest equivalence and
visual identity remain unproved until the director runs the windowed stages.
The import command reports the existing duplicate player placeholder UID; it
completed successfully. Other figures and their source files remain unchanged.

## Chosen defaults

Only proof controls were chosen: `PROOF_WORKERS=2`,
`PROOF_TIMEOUT_SECONDS=180`, `MUTATION_OFFSET_PX=4`, `FIXTURE_SIZE_PX=8`,
`PROOF_FEATURE_CHROMA_MARGIN=20` (feature proof mask only),
`PROOF_IDLE_SEED=.37`, `PROOF_TERMINAL_PHASE=.9`,
`PROOF_ENEMY_TILE=(4,4)`, `PROOF_HERO_TILES={front:(4,6),rear:(4,2)}` and
`PROOF_HIT_TILES={front:(4,5),rear:(4,3)}`. Copy fixtures use `whirlwind_slash`, `quick_stab` and
`hurl_spear` to exercise the existing three copied attack kinds. The source
pixel/bone epsilon is the existing 0.0001; contact epsilon is 0.000001. Native
canvas, scale measurement, stepped clock, proof layout and timeouts are reused
from the supplied reference probes. No player-facing default was invented.
