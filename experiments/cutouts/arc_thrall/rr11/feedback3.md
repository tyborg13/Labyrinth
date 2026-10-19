# rr-15 feedback 3 — rear shoulder continuation

The three director-traced 2 px pinholes close in the CPU native estimate:
rear tether 61 and jab 26/27. Rest reconstruction remains exactly 0 px in both
views. Changes are uncommitted; fresh windowed acceptance belongs to the director.

## Source fix

The tether hole at canvas `(234,192)` / `(235,192)` samples the raised upper
arm near source `(111,66)` / `(112,66)`. Jab's `(242,190)` / `(243,190)` samples
near `(112,70)` / `(113,70)`. These lie just beyond the old shoulder cover.
The torso itself maps those holes above the approved rest silhouette, so
adding torso texels there would change rest identity.

One additional rear `upper_near` source seed, `(111,66)`, uses the existing
4 px joint-continuation domain under the torso. It adds exactly 25 texels in
source bounds x=110–115, y=63–70 to `hidden_upper_near`. The existing
`edge_texels` helper supplies exact non-outline colours from that same arm.
All original texels are preserved. The texture crop, quad, anchor, z-order,
node names and skeleton are unchanged. Every added texel is torso-covered
at rest. No exception, motion or gate code changes were made.

`rr15_shoulder_fix.py` applies the current case recipe incrementally, without
rerunning the historical whole-case builder. It updates the case paint/check
mask and digest, promotes the texture, adopts its density source, processes
the Thrall entry and refreshes integration provenance. All other production
paint remains byte-identical. Reproduction command:

```sh
python3 -B experiments/cutouts/arc_thrall/rr15_shoulder_fix.py
```

The director's `reach.py` and reach-test changes remain byte-identical to the
start of this round. Overreach is reported and inside-minimum targets fail.
The prior reach TODO is resolved by that director policy. Motion files,
approved paintings/rests, all front assets and every Seer file are unchanged.
The three affected pose records match the director's pre-fix records exactly.

## Headless proof

Commands run:

```sh
python3 -B tools/godot_task_runner.py --task-id rr-15 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case experiments/cutouts/arc_thrall/rr11 --output experiments/cutouts/arc_thrall/rr11/proof/samples.json
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
python3 -B experiments/cutouts/arc_thrall/rr15_shoulder_proof.py --output /private/tmp/labyrinth_codex/rr-15/feedback3/cpu
python3 -B -m unittest tests.test_rr11_humanoid tests.test_rr15_native_cleanup tests.test_rr15_action_direction tests.test_rr15_view_keys tests.test_rr15_reach tests.test_rr15_shoulder
python3 -B tests/test_art_identity_gate.py
python3 -B tools/process_board_density.py --check --only arc_thrall_cutout
git diff --check
```

Observed focused results:

```text
RR10 BONE SAMPLES: PASS (990 poses; headless transforms only)
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR15 FRONT ACTION DIRECTION: PASS (458 positive checks)
RR15 FRONT REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)
RR15 REAR ACTION DIRECTION: PASS (458 positive checks)
RR15 REAR REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)
RR15 CPU REAR TETHER 61: PASS (holes [2] -> []; rejected metrics 0)
RR15 CPU REAR JAB 26: PASS (holes [2] -> []; rejected metrics 0)
RR15 CPU REAR JAB 27: PASS (holes [2] -> []; rejected metrics 0)
Ran 35 tests in 12.171s
OK
Ran 111 tests in 34.371s
OK
```

The CPU proof uses the retained pre-fix texture as a mutation; restoring it
reopens each exact 2 px native-reported hole. Its before/after captures and
bound report are in `/private/tmp/labyrinth_codex/rr-15/feedback3/cpu/`, named
`rear_tether_0061_{before,after}.png`, `rear_jab_0026_{before,after}.png` and
`rear_jab_0027_{before,after}.png`. These are CPU estimates, not GPU captures.
The two new tests also check unchanged original texels, own-material donors,
torso coverage, production/density closure and exact 0 px rest identity.

Density paint is processed. The read-only density check exits 1 awaiting the
director's native rebake, reporting `rig part pixels changed since recorded
rebake` for all four registered Thrall rest paths (legacy front/rear and v2
front/rear). No native rest fingerprint was certified headlessly. Existing
rest PNG bytes remain unchanged. The density stage below performs the required
native rebake and sealing.

The machine-readable handoff is `proof/rr15_feedback3.json`; the round-only
file manifest is `proof/rr15_feedback3_changes.txt`. No TODO_DESIGN placeholder
or player-visible default was added. No new debug numeric default was chosen:
the probe uses the existing fixed CPU proof camera and the director's frames.
No full suite, windowed run, peer review or commit was performed.

## Proof for the design owner

Run at 1920×1080 and 100% UI scale. No inspection-fixture command is specified.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-15
export LABYRINTH_TASK_ID=rr-15
sh experiments/cutouts/arc_thrall/rr11_proof.sh density
sh experiments/cutouts/arc_thrall/rr11_proof.sh rest
sh experiments/cutouts/arc_thrall/rr11_proof.sh native
sh experiments/cutouts/arc_thrall/rr11_proof.sh sheets
sh experiments/cutouts/arc_thrall/rr11_proof.sh idle
sh experiments/cutouts/arc_thrall/rr11_proof.sh production
sh experiments/cutouts/arc_thrall/rr11_proof.sh review
```

Outputs remain under `proof/native_rest/`, `proof/native/`,
`proof/contact_sheets/`, `proof/idle_native/`, `proof/production_native/`,
`proof/thrall_protagonist_idle.mp4` and `proof/arc_thrall_review.mp4`.
The existing native-gate failure report predates this fix and is preserved
until the director recaptures.
