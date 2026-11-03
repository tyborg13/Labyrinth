# rr-35 — Gloam Stalker on mq-13 r3

Implementation is uncommitted on `codex/rr-35`. The rejected rr-33 case,
builders and test probes are retired. `rr35/` is the production source; its
`inputs.json`, baseline registrations and build receipt bind the approved r3
maquette and paintings. No protected input was edited. Native acceptance and
three design decisions remain outstanding. The director owns commit, review,
inspection fixtures and publication.

## Numbered requirements

1. **Re-cut / rests.** The existing rigid head/torso/pelvis/hands/feet and six
   skinned arm/leg/cape surfaces are rebuilt from mq13 paint. Carapace ownership
   combines the registered native selection with source-space painting traces;
   violet drape features retain their cloth ownership. All selected original
   RGBA texels are carried by the rigid torso, with no carapace bone or mesh.
   Vacated surfaces have same-surface hidden continuation, the binding 3 px tuck,
   and per-clip own-surface coverage recipes. Both rests have **0 visible-pixel
   mismatches**. There is one invisible exception: approved front `(173,170)`
   contains RGB `(27,15,20)` under alpha 0. Only the derived source normalizes
   it to transparent black, matching a native transparent clear. The original
   painting is untouched; `approved_painting_rgba_mismatch_pixels` honestly
   records **1 front / 0 rear**, while reconstructed derived rests record 0.
   Production parts are density processed. Native production rest rebake and
   shadow refresh remain director steps; no CPU rest is certified as native.
2. **Draw order.** Front near arm/blade and rear far arm/blade are above torso,
   pelvis and both capes; head is above both arms, and the opposite arm is behind
   torso. The sampler records actual Sprite2D/Polygon2D depths for every authored
   and presented pose. Native piece captures also record actual node depths.
   Layout, sampled and native depth gates reject lowered camera arms/blades.
3. **Clips / integration.** Protected `motion_tracks.json` is imported byte for
   byte into the case and production. Compilation keeps the rear slash override
   and all existing intent selectors, resolver/contact/SFX/movement paths,
   portraits, hit and death behavior. There are no mechanics or save changes.
4. **Knees.** Native hip/knee/ankle measurements produce the following policies;
   all four retain their bent native side, with the existing 6° near-straight
   threshold. `crouched_stance_deg` is that leg/view's measured rest bend. The
   optional walk-gate map uses the opposite leg's stance threshold at each apex.

   | View | Near bend / side | Far bend / side |
   |---|---|---|
   | Front | 32.537166° / +1 | 53.242111° / +1 |
   | Rear | 61.332177° / −1 | 40.635037° / −1 |

5. **Gates.** The rr-33 cut/source, rigid idle, signed motion, direction, dense
   reach, walk/support, blade attachment, feature, hole and clean-surface gates
   remain strict. New gates count all alpha>0 8-connected components against
   rest, check all arm/head depths, and measure the leading painted blade tip
   at exact slash contact. Mutations detach approved carapace pixels, lower each
   camera arm/blade in both views, and reset the leading blade's contact transform.
   Native component checks decode the current hash-bound frames through shared
   storage IO; they do not treat CPU diagnostics as renderer proof.

## Unresolved design inputs

These named fields live in `rr35/inputs.json` and production integration data.
The protected motion is preserved, and failing acceptance assertions are retained.

- `TODO_DESIGN_front_slash_reach`: leading `hand_far` tip travels **16.414892 px**
  at contact, below 18. Rear travels **21.503177 px** and passes. Endpoints are
  the owned painted texel centres nearest the certified native `hand_tip`.
- `TODO_DESIGN_slash_torso_lean_limit`: protected slash requests **6°**, while
  the binding spec allows at most 4° in actions. Both views fail that gate.
- `TODO_DESIGN_rear_move_foot_near_reach`: the protected gait on the r3 crouch
  reaches **22.200474 px**, below `abs(L1-L2)+4 = 25.409323 px`, at phase
  **0.047229492**. Overreach remains the inherited diagnostic policy.

## Generic changes

Only `tools/humanoid_cutout/anatomy.schema.json` and `walk_gates.py` change:
they accept the optional per-view/per-leg stance map and select the stance leg's
threshold. Omission retains the old scalar policy and arithmetic. No generic
runtime module changes. Focused reference sets exercise the legacy rigs; the
preservation receipt verifies every other rig and protected source byte.

The case-local `rr35_raster.py` culls only triangles whose guarded UV bounds
contain no opaque proof-mask texel. Runtime meshes are untouched. Two difficult
slash-pose comparisons verify exact equality with the original full-mask raster.
This avoids repeatedly rasterizing empty full-canvas seam masks during construction.

## Reproduction and headless proof

See [verification.json](rr35/proof/verification.json) for exact observed results,
[gate report](rr35/proof/gates.json), [preservation](rr35/proof/preservation.json),
and [changed-file inventory](rr35_files_changed.txt). Full logs are gitignored in
`rr35/proof/logs/`. Full project suites were deliberately not run, as requested.

```sh
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_case.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_build.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_density.py --rebuild-derived-sources
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_evidence.py --refresh
python3 -B -m unittest tests.test_rr35_cutout tests.test_rr35_production
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_gates.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_seams.py
PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr35_preservation.py
```

`rr35_continuations.py` (move) and `--actions` rebuild the recorded hidden-edge
recipes from current samples. These are construction commands, followed by a
normal rebuild/density process/sample refresh; they are not native acceptance.

## Proof for the design owner

No windowed run was attempted. Each stage below uses the required visual runner
at **1920×1080, 100% UI scale**, with no retry. Resolve the design failures before
expecting the strict `native`, `sheets` or `review` gates to accept the result.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-35 && sh experiments/cutouts/gloam_stalker/rr35_proof.sh review
```

Outputs stay gitignored under `rr35/proof/{native_rest,native,contact_sheets,
idle_native,production_native}`; idle/review MP4s are at the proof root. `density`
rebakes both native production rests, records them, refreshes only Gloam shadows
and reseals provenance. The brief does not request an `inspection_fixture.py`
command; fixture preparation remains with the director.

## Chosen defaults

No player-facing tuning was chosen. New diagnostic defaults are the sampler's
zero source origin (avoids float32 accumulation from the former proof offset),
a one-texel conservative UV-culling guard, a −100 mutation depth, a 255 px plate
mutation translation, and transparent-black normalization for the one invisible
source texel. Existing rr-33 proof cameras, scales, clocks, timeouts, seeds and
mutation fixtures are reused. [chosen_defaults.json](rr35/proof/chosen_defaults.json)
records the plain fields and their sources.
