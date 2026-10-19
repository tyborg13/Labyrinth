# rr-18 — Glacial Mirror humanoid v2

Current handoff: [director feedback 1](rr18/feedback1.md). The four original design questions are resolved. Both views pass knees, supports, direction/coverage, reach, source cuts and density-derived production rest. **Acceptance is incomplete:** the strict headless seam scan rejects 20 front and 122 rear posed frames. `TODO_DESIGN_source_gap_calibration` remains explicit; no exemption or motion/art tuning was applied.

## Implementation and numbered unit requirements

1. Fifteen rigid boulders per view use the specified labels/bones. Fists map to `hand_*`; hands/feet retain two-bone targets. Each boulder keeps its existing painted continuation and 3 px adjacent tuck. Source composites match both approved paintings at **0 px**. The front ice mirror is owned by torso. All visible parts are connected. Director feedback sets the near-straight threshold to **10°** for both legs/views and facing bend sides to +1 front / −1 rear; stride is near/front and far/rear. Visible and hidden partitions now share one registered presentation anchor and identical texture bounds, preventing independent raster snapping from tearing a single rigid boulder.
2. Torso, head and both free arms use the existing upper-body idle. Pelvis, legs and feet stay still. The existing empty weapon group uses root only as a stationary diagnostic anchor. Headless idle rigidity passes; native isolated-pixel proof is pending.
3. The existing rr-18 production registration covers board, pre-battle, portraits, per-tile advance, Refraction, guard, hit, death and fade. Existing VFX/SFX remain attached to contact. Both real resolver/callback probes pass **940 frames** in front and rear, including guard's source actor and reduced-motion runtime checks. This feedback pass changes only the Mirror's closure, density/rest and shadow records, case tools and tests.
4. No generic humanoid tools/runtime changes. The protected maquette, paintings and staged director data are untouched. Preservation checks pass for **3,616 tracked files**; unrelated identity/density JSON values and shadow entries remain equal. The focused regressions retain **990 exact Thrall** and **1,258 exact Seer** pose rows.
5. Source/cut, idle/signed motion, action direction and coverage for `refraction`/`guard`, every stride swing, facing knees, supports and dense reach with interval minimum pass. Overreach remains diagnostic. Production rest compares against independently density-processed adopted parts, at **0 px** in both views; saved snapshots also match at 0 px. The new headless rigid raster scan runs **341 frames per view**, uses the shared calibrated joint-hole/clean-piece gates, and reports every remaining pocket without waivers. No stray/outline/outside/slab defects are found. Native sprite/idle/seam proof remains wired and pending the director's renderer.

## Reproduce headless proof

Use this worktree. Source readoption must follow a build restoring source pixels; do not adopt already processed production pieces.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_case.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_build.py --import-director
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_density.py --refresh-sources
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 tools/godot_task_runner.py --task-id rr-18 --stream -- godot --headless --path . --script tests/rr18/action_direction.gd -- --case experiments/cutouts/glacial_mirror/rr18 --output experiments/cutouts/glacial_mirror/rr18/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_mutations.py
```

The strict gate currently exits **1 (142 unique errors)**. The focused runner passes **188 tests** and runs only rr-10/11/14/15/16, rr-07 production, registration regressions and rr-18. Final Mirror-only checks pass **18 tests**; all **6** guard mutations are caught. The three SFX harnesses pass **4075 / 3348 / 1604 observations**, with zero failures. Registration passes **750 scripts**; art identity passes **111 tests** and icon identity **7**. Full suites are not run, per the brief/director. Exact observed lines, log hashes and proof paths are in [verification.json](rr18/proof/verification.json).

## Proof for the design owner

No windowed command was attempted. Run in this exact order at 1920×1080, 100% UI scale; the wrapper invokes `tools/visual_probe_runner.py` with proof contracts. `rest` independently compares the authoring rig to raw paint and the production rig to the density-derived rest. Native rest sealing remains pending. `native` retains the strict seam gate and currently cannot certify acceptance.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Captures remain gitignored under `rr18/proof/{native_rest,native,contact_sheets,idle_native,production_native}` and `*.mp4`. Ignored CPU diagnostics are under `rr18/proof/seam_cpu`; they are not renderer proof. No inspection-fixture command is requested; the design owner prepares the fixture.

## Chosen defaults and open issues

No new player-facing values were chosen. New proof-only choices are `PROGRESS_INTERVAL_FRAMES=50` (the existing Thrall diagnostic cadence) and the production-rest diagnostic caption. Existing named fixtures, source origin `(128,128)`, 512 px pose canvas, 96 px proof step, 2× scale, cameras, 60 fps sampler, five idle loops and timeouts remain unchanged. Texture bounds and anchors are derived from existing alpha; knee policy and motion values are director decisions.

`TODO_DESIGN_source_gap_calibration` records the remaining design ambiguity. For example, front guard frame 20 has a 19 px torso/upper-near pocket and rear Refraction frame 32 has a 9 px upper-far/fore-far pocket whose inverse samples lie in transparent source paint for both owners. The scan records all 210 pockets, including cases with mixed provenance; it does not assert that all are exemptible. No paint, protected key, calibration threshold or shared gate was changed to hide them.

The headless macOS logs contain CA-certificate warnings and some production shutdown resource warnings; observed assertion reports and exit results are recorded separately. No existing master assertion was weakened. No commit, stage, peer review, branch change or publication was performed.
