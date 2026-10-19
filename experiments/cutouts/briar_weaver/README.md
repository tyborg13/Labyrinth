# rr-21 — director feedback 2: shared walk

Work stays uncommitted on `codex/rr-21`. No full suite, windowed run, peer review,
commit or publication is performed by this implementation worker. Earlier
feedback results are historical; current results are in
`rr21_feedback2_results.json`.

## Numbered acceptance criteria

1. **Integration and shadows.** The case uses integration's gait compiler,
   projected skinned legs, lanes, pelvis fit and shared walk/support gates.
   `rr21_walk.py` imports the protected director file byte for byte and verifies
   every non-move compiled track is unchanged. It removes `leg_roles` from
   anatomy and all three layout copies, declares both support feet and carries
   the director's leg-scale maximum into production. The scoped shadow refresh
   restores the two Weaver v2 rest sources and retains all other records.
2. **New walk.** The protected gait is six steps in 0.9s, 7px lift, 2.5px settle,
   3px opposite claw sway and 2px tatter trail. Near leads in both views. No
   tuning, projection, target tolerance, joints or motion channels were chosen
   by the implementer. Source and actual-board production checks use the shared
   walk and support reports; stride/trailing aliases and old gates are retired.
3. **Seams and detached components.** `rr21_continuations.py` constructs exact
   nearest own-piece non-outline donor-coordinate recipes on existing draw
   surfaces. It closes joint pockets and bridges detached paint instead of
   deleting it. No gate exceptions are added. Gait recipes apply only to move.
   A wider CPU diagnostic found small action/death pockets too; optional
   `clip_continuations` apply the same technique only in those clips. Rest,
   idle, original textures, skeletons, weights and production density paint are
   unchanged. The head/torso and far-claw coverage gaps are repaired at their
   source surfaces, independently of animation timing. CPU coverage is a
   construction/regression aid, never native renderer acceptance.

   The additive shared extension consists of
   `scripts/maquette_cutout_runtime/humanoid_continuations.gd`, its call site in
   `humanoid_presentation.gd`, and texture/validation selection in
   `tools/humanoid_cutout/{gait_continuations,cpu_pose,gates}.py`. Cases without
   clip recipes preserve their existing gait behavior. Exact full-image tests
   cover source/production, paint/check masks, both views, repeated transitions
   and restoration. The existing gait mutation guard remains in its original
   validator function so its independent mutation program can disable it.

   `walk_gates.planted_support_report` extracts the existing non-move support
   check without changing its thresholds or default combined walk report.
   Production uses each frame's actual facing (hit can turn toward the player)
   and captures integration's uniform `walk_samples` from the live rig. This
   preserves the facing behavior while checking both feet in the correct view.
   Uniform resampling runs only after all live movement frames are recorded;
   seeking the cached production rig mid-action can contaminate those frames.

   The native probe now measures the same real board geometry as the headless
   sampler and sets continuation check-mask metadata before rendering. The
   director must rerun the native gate; the retired walk's captures are stale.
4. **Compact records.** `proof/samples.json` retains metadata and sample counts,
   pointing by SHA-256 to ignored `proof/logs/samples.json`. The additive
   `bone_evidence.load_samples` helper supports both legacy full records and
   this compact form, rejects stale/missing/outside-path diagnostics, and is
   used by native gates and review/sheet generation. `gates.json` retains
   extrema, swing summaries, failures and counts. Full direction, walk, stance
   and pixel rows go to `proof/logs/`. `native_gates.json` explicitly records
   pending fresh native proof until the director runs it; the prior full
   report is archived in ignored logs. No historical native success is claimed.
5. **Headless verification and director proof.** Current exact results, command
   inventory and capture paths are in `rr21_feedback2_results.json`. The focused
   tests cover the unit and unchanged Seer, Thrall, Mirror and Capacitor cases,
   gait mutations, sound synchronization, registration and native-probe loads.
   No full suite is run. All four reference case and asset directories and all
   approved source art stay byte-identical.

The feedback-1 residue rule remains exact: nontransparent texels satisfying
`G >= max(R,B)+12 AND 2*G >= 3*max(R,B)` are forbidden outside declared feature
masks. The front eye has its frozen 23-texel mask; rear has no eye feature.
Original pieces, rests and every continuation variant are checked, including
copies from production's density-treated donor. Native frames use the
transported feature mask and independent captured head evidence.

## Reproduce headless proof

```sh
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_walk.py
python3 tools/godot_task_runner.py --task-id rr-21 --stream -- godot --headless --path . --script tests/rr21/samples.gd -- --case experiments/cutouts/briar_weaver/mq9 --output experiments/cutouts/briar_weaver/mq9/proof/logs/samples.json
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_continuations.py
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_continuations.py --actions
LABYRINTH_TASK_ID=rr-21 python3 -B -m unittest tests.test_rr21_cutout tests.test_rr21_residue tests.test_rr21_production tests.test_rr21_walk -q
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_gates.py
PYTHONPATH=tools python3 -B experiments/cutouts/briar_weaver/rr21_seams.py
```

After rebuilding recipes, the focused tests refresh samples and the compact
index with final bindings. `rr21_build.py` preserves recipe data on a clean
case rebuild. Production integration provenance must be resealed after changes.

## Proof for the design owner

Run this exact windowed sequence from the worktree. Each stage expands to the
visual runner and proof contracts in `rr21_proof.sh`, at 1920x1080 and 100% UI
scale. The density stage also emits native 255px rest data, records rests,
refreshes only Briar shadows, checks density and seals provenance.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-21 && sh experiments/cutouts/briar_weaver/rr21_proof.sh review
```

Capture outputs stay under `mq9/proof/`: `native_rest/`, `native/`,
`contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`,
`briar_weaver_protagonist_idle.mp4`, `briar_weaver_review.mp4`. The existing
`.gitignore` protects native, rest, production, idle, sheets, CPU crops, logs
and MP4s. No inspection fixture is required by the unit brief; preparing the
fixture remains the director's workflow responsibility.

## TODO_DESIGN, chosen defaults and open issues

No active TODO_DESIGN placeholders remain. All perceived motion/paint values
come from the approved data. New non-player defaults are the 16-pass
construction convergence guard and one-pixel raster coverage margin (both
from gait-01), shortest squared-distance component bridge with row/column tie
order, the 100,000-byte compact-record regression budget, and named test/proof
fixtures (one-pixel slide, front frame 5/rear frame 2, texture-test phase .37,
two transition passes). Existing proof geometry, FPS and timeouts are reused.

Fresh native renderer, density-rest, idle comparison, production captures,
sheets and review remain director-owned windowed proof. The worker cannot run
those commands in this sandbox and does not retry them.
