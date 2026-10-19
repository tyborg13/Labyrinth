# rr-21 — director feedback 1

Feedback changes are uncommitted on `codex/rr-21`. No full suite, windowed run,
peer review, commit or publication was performed. R0 history remains in
`rr21_results.json`; current evidence is in `rr21_feedback1_results.json`.

## Implemented direction

1. **Residue rule.** `rr21_residue.py` uses exactly
   `G >= max(R,B)+12 AND 2*G >= 3*max(R,B)` for nontransparent presented texels.
   The frozen front `green_eye` declaration in `mq9/feature_masks.json` binds its
   own 23-texel source-space mask by SHA-256; rear has no feature. The old
   zero-green rule and `TODO_DESIGN_green_eye_gate` are removed.
   Cleanup operates on derived visible paint and hidden support together for
   each logical piece. It takes RGB from the nearest non-residue source texel
   in that same piece, preserving alpha, geometry and the exempt eye. Squared
   Euclidean source distance determines nearest; ties use y, x, then layer.
   Legitimate olive/brown outside the band is untouched. All 100 case/production
   painted/support/rest surfaces have zero residue outside the declared feature.
   The actual supplied assets contain no outside-feature residue, so cleanup is
   a pixel-preserving no-op. No PNG or protected painting changed.
   Native frames use the same declared mask transported by the captured rigid
   head quad and existing native UV-tie oracle. A tie is exempt only if that
   candidate's source colour matches the actual isolated head capture. No colour
   is inferred as a new feature, no mesh is CPU-rasterized, and missing feature
   owner evidence fails closed. Review/sheet stages rerun this native gate.
2. **Revised motion.** The supplied replacement is copied byte for byte into the
   editable case and production, then recompiled with the unchanged shared
   compiler. Its SHA-256 is
   `947ed701639c51d948647225b10d46df30888a3bb3254275caab8051fc5410ca`.
   Stride lifts are 7px; pelvis is at rest height at phases .2/.65 and dips 2px
   after landings. No motion, joints, gait scale, snap policy or gate tolerance
   was tuned. Source rest reconstruction still has 0px mismatch in both views.
3. **Validation.** Source cuts, bone/idle contracts, lash/thornwall signed direction,
   inside-minimum reach, residue, registration and real production contacts/poses
   pass. Headless gates cannot all pass with this replacement: the remaining
   measured movement failures below are retained as strict acceptance failures.

## Remaining director findings

| Measurement | Front | Rear |
|---|---:|---:|
| Reference-step first apex stride / trailing knee | 54.507593 / 55.491477 degrees | passes |
| Actual-board first apex stride / trailing knee | 37.966924 / 55.491477 degrees | 83.599336 / 5.640549 degrees |
| Actual-board second apex stride / trailing knee | 61.846528 / 55.491477 degrees | 43.759601 / 5.640549 degrees |
| Maximum actual-board planted target error | 1.949545px | 1.058803px |
| Required target-error radius | 0.7072px | 0.7072px |
| Maximum consecutive stance-frame shift | 1px | 1px |
| Required stance-frame shift | 0px | 0px |

The reference sample uses the unchanged 96px step / 2x source scale. Production
measures the real board: about 138.39749 source px per step. Front target misses
occur at .388888889/.407407407; stance shifts occur at .407407407/.425925926.
Rear misses and its stance shift occur at .5. Repeated proof callbacks can sample
one presented frame several times; reports retain each observation.

`TODO_DESIGN_front_move_knee_apex`, `TODO_DESIGN_front_move_supports` and the newly
observed `TODO_DESIGN_rear_move_supports` are emitted in the owning gate reports
with the measured errors. Normative tests require zero errors and remain red;
no assertion or tolerance was weakened to accept the supplied values. The eye
finding is resolved. Native density rebakes/pixel proof remain director-owned.

## Headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && LABYRINTH_TASK_ID=rr-21 python3 -B -m unittest tests.test_rr21_cutout tests.test_rr21_residue tests.test_rr21_production -q
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input experiments/cutouts/briar_weaver/mq9/proof/logs/production/front/logic_frames.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && python3 -B experiments/cutouts/briar_weaver/rr21_production.py --input experiments/cutouts/briar_weaver/mq9/proof/logs/production/rear/logic_frames.json
```

Exact results and commands are in `rr21_feedback1_results.json`. Fresh transcripts
are under `mq9/proof/logs/feedback1_*`; both production fixtures are under
`mq9/proof/logs/production/{front,rear}/`. Focused tests retain negative controls
for band boundaries, legitimate paint, nearest same-piece donors, alpha/source
preservation, feature-mask expansion, transported frame masks, stray residue,
signed target reversal, missing/stale evidence, early healing and late contact.
Other figures' case and production assets remain byte-identical. No shared
runtime/tool module was changed in this feedback.

## Proof for the design owner

The exact sequence is below. Each stage expands to the visual runner commands
in `rr21_proof.sh`, with explicit renderer, timeout, output paths and proof
contracts. Rest/native/idle/production captures are 1920x1080 at 100% UI scale;
the density stage additionally emits native 255px derived rest data. It records
rests, refreshes only Briar's shadows, checks density and seals provenance.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh review
```

Outputs remain beneath `mq9/proof/`: `native_rest/`, `native/`,
`contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`,
`briar_weaver_protagonist_idle.mp4` and `briar_weaver_review.mp4`.
The existing proof `.gitignore` protects all captures, logs and MP4s. Movement
acceptance still causes nonzero gate exits; no native acceptance is claimed.

## Chosen defaults

No new player-facing defaults. Residue thresholds and the feature exemption are
exact director values. New deterministic nearest-donor ties use source y/x and
layer order. Synthetic tests name their 5x5 fixture, 512x512 frame, brown
(80,60,40,255), olive (70,80,40,255), residue (40,100,30,255) and threshold-edge
(70,105,50,255) colours. Existing proof tiles, clocks, sampling, tolerances and
timeouts are unchanged.
