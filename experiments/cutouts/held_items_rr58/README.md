# rr-58 held-item ownership

Implementation in the prepared `codex/rr-58` worktree. The director owns paint,
native inspection, commit, review and publication. No motion, timing, contact,
landing, gameplay or shared runtime scripts change.

The original composites are byte-identical in-hand caches, as in rr-57 r2.
At the Seer's existing death release, 90 rear staff-owned palm texels return to
the hand. That reconnects the original 43px outer-finger component; moving those
fingers onto the staff would transfer more hand paint in the wrong direction.
The two release sprites keep their original crops, nodes and transforms.
Source variants retain the raw case paint; production variants partition the
existing density-treated paint, with exact density provenance. There is no new
paint, recolouring, resampling or hand donor fill.

Feedback 1 copies each item's own paint into release variants, with no resampling
or new colours. `fills.py` selects the nearest equally oriented Gaoler link arc
and exact same-side Seer shaft cross-sections; `ownership.json` records every
source/destination UV, RGBA, source region and source hash. Check/outline texels
travel with their paint. The larger chain crop uses `Sprite2D.offset`; no bone
or snapped node transform changes, and held frames restore offset zero.

All three requests are `filled`. Feedback 2 approves the corrected rear Gaoler
mask bounds [158,160,181,166] and its prepared 44px own-chain copy from source
region [161,177,178,181], translated by (0,-17). The request index records the
prior bounds/hash and the director-approved corrected bounds/proposal hash.
Every fill remains inside its request mask, and all design placeholders are
removed. Native renderer and density rest certification remain director steps.

## Headless proof

Run from the task worktree. `build.py` installs partitions/requests; `density.py`
registers and seals their exact provenance. `checks.py` runs eight focused tests
and writes no shared test resources. `samples.gd` loads the production adapters,
samples every frame on the live production clock, and checks release/reset.
`build.py --prepare RIG --output FRESH_DIRECTORY [--before]` creates a runtime
proof closure; the before case omits release variants. Both copy live compiled
motion, since historical cases retain obsolete walk durations.

`proof.py --sweep --rig RIG --output OUTPUT` uses those prepared before/after
cases and samples under `/private/tmp/labyrinth_codex/rr-58/RIG/`. It compares all
bone/node transforms, every in-hand CPU pixel, joint holes, outline exposure,
dark slabs and components for every frame. The existing rr-44 release policy retires only the chain/hand anatomical grip pair at release; all body-joint checks remain active. Baseline findings are retained.
`--proof-root` selects isolated feedback outputs. `--collect` rebuilds only the aggregate report from completed frame reports;
it exits nonzero for new gate findings. CPU proof never certifies native pixels.
The output contains paired front/rear 3x drop strips with a shared crop. Feedback 1 clears all 77 Seer missing-shaft component findings.

## Proof for the design owner

Use `RR58_PROOF_ROOT=/private/tmp/labyrinth_codex/rr-58/feedback1` for a fresh feedback-1 native capture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/chainbound_gaoler/rr58_proof.sh prepare
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/chainbound_gaoler/rr58_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/chainbound_gaoler/rr58_proof.sh compare
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/chainbound_gaoler/rr58_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/hoarfrost_seer/rr58_proof.sh prepare
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/hoarfrost_seer/rr58_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/hoarfrost_seer/rr58_proof.sh compare
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-58 && sh experiments/cutouts/hoarfrost_seer/rr58_proof.sh density
```

`native` calls the visual runner at 1920x1080/100%, captures every frame, and
prints only its two 1920x1080 overviews for screenshot validation. Native source
grids live separately in the external capture directory. `compare` lists every
differing in-hand RGBA pixel and makes before/after front/rear native 3x strips.
`density` performs the director's windowed rest rebake and records/checks it.
The original rest PNGs and shadow-source hashes are unchanged by release-only
variants; no new shadow silhouette is introduced. No playable inspection
fixture is requested for this art-ownership unit.

`config.DEFAULTS` and the named constants in the probes are proof-only defaults:
60fps sampling, 1024px source canvas, source origin 384, 3x strips, 24px labels,
3px conservative request padding, triangle batches of 128, four CPU workers,
180s sample/validation limit, 900s all-frame native limit. Native overviews use
1920x1080 and a fixed (448,28) proof placement. No player-visible tuning is chosen.
