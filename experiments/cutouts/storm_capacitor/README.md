# rr-17 — director feedback 2

This round changes runtime clocks, cue delivery and verification. The approved
painting, cut, vent, glow textures, layouts, motion data, rest images, density,
shadow records and idle policy are unchanged. All edits remain uncommitted;
the director owns commit, inspection and publication. No full suite, peer
review or windowed run was performed.

1. **Sidecars.** Task-runner headless import generated all 52 missing/new
   deliverable sidecars, listed in `rr17_sidecars.txt`. This includes the two
   protected PNGs whose sidecars were already absent at the base: the unchanged
   repository guard requires them. The guard passes on the tracked plus
   untracked deliverable inventory, and its 18 guard tests pass. Its indexed
   repository test remains blocked: staging fails with
   `fatal: Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/rr-17/index.lock': Operation not permitted`.
   The guard is unchanged. The director must stage sources and sidecars before
   rerunning `python3 -m unittest tests.test_godot_sidecars -q`.
2. **Independent simultaneous deaths.** A generic `death_sequence.gd` opts in
   only when a dying maquette declares `death_timing`. It samples each actor's
   existing frames on that actor's own microsecond clock and holds completed
   actors until the longest sequence ends. FIFO burst deaths keep their onset
   delay. Without a declaration, the original shared timeline is retained.
   All six Capacitor pairings compare every changing frame, normalized phase
   and timestamp with the actual pre-rr17 RunScene method at `eafe1715d`.
   A legacy multi-kill, including a FIFO burst case, compares the complete
   presentation byte for byte. The Capacitor keeps all 147 frames in every pair.
3. **Crossed chain cues.** A separate cue cursor emits each crossed hop once,
   even if callbacks skip its displayed VFX. The existing four-hop resolver
   fixture emits four identical ordered cue entries normally, under reduced
   motion and when only recovery is called. Damage snapshots and popups still
   finish exactly once per hop.
4. **Production motion.** Both the case and production rigs are sampled at all
   authored keys, midpoints, contacts and sequential frames. Production
   callbacks additionally record real bone and painted sprite transforms.
   Gates check them against the protected motion oracle, require the protected
   compilation and validate production bindings. Only authored half-pixel ties
   admit their two adjacent snapped integers. A regression reverses only the
   production death lean, loads fresh rigs and a fresh real action capture,
   restores the data byte for byte, then requires signed-motion rejection.
5. **Portable shadow baseline.** `rr17_shadow_check.gd -- --baseline PATH`
   loads the requested resource and rejects missing arguments. The test
   extracts `eafe1715d:assets/generated/unit_shadow_cache.res` into an isolated
   temporary directory and verifies all 66 prior entries. The proof script
   extracts that same Git baseline locally; it has no other-checkout dependency.

## Verification

Exact observed result lines and commands are retained in
`rr17_feedback2_results.json`. Fresh headless samples, production logic frames,
unit logs and the guard-removal mutation table are under gitignored
`mq5/proof/logs/`. Windowed captures remain director-owned. The regression
fixtures and mutation runner are retained in source; `rr17_feedback2_files.json`
is the changed-file inventory.

```text
Ran 63 tests in 86.039s
OK
RR17 RUNTIME: PASS (58 checks, 0 failures; headless logic only)
RR12 RUNTIME: PASS (44988 checks, 0 failures; headless logic only)
RR17 HEADLESS GATES: PASS (0 errors)
MAQUETTE PRODUCTION LOGIC: PASS (1011 frames)
RR17 PRODUCTION GATES: PASS (0 errors)
RR17 FEEDBACK MUTATIONS: PASS (7/7 caught)
RR17 SHADOW PRESERVATION: PASS (66 existing entries unchanged)
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
```

The unchanged indexed sidecar guard reports `Ran 19 tests in 1.077s` /
`FAILED (failures=1)` because 48 required sidecars are not yet in the Git index.
Its 18 guard-only tests pass (`Ran 18 tests in 0.022s` / `OK`). All 52 generated
sidecars pass the same validator with the full deliverable working-tree inventory.

Rerun focused tests:

```sh
python3 -m unittest tests.test_rr17_cutout tests.test_rr17_production tests.test_rr17_integration tests.test_rr17_feedback tests.test_test_registration_audit -q
python3 -B experiments/cutouts/storm_capacitor/rr17_feedback_mutations.py
```

The retained Git-baseline method changes only empty typed-array declarations
to their Windows-compatible default initialization; its presentation output
remains byte-identical.

The mutation runner removes each guard in isolation, requires the corresponding
regression to fail, and restores every source byte in `finally`. Run it serially,
without another rr17 proof process. Protected director data and Git metadata
are never mutated. The separate indexed-sidecar test cannot pass in this
sandbox until the director stages the generated files.

The guard-removal mutation table (`mq5/proof/logs/mutations/table.json`):

| Removed guard | Regression result |
|---|---|
| Independent death-frame sampling | Caught: all six paired base clocks |
| Crossed-hop cue cursor | Caught: normal, reduced and skipped recovery |
| Production rig sampling | Caught: reversed production-only death lean |
| Production file bindings | Caught: missing/stale production hashes |
| Production callback signed motion | Caught: reversed production-only death lean |
| Explicit shadow baseline | Caught: supplied 66-entry baseline ignored |
| Sidecar guard | Caught: missing/stale-sidecar guard tests |

## Proof for the design owner

The complete ordered sequence (native rest, samples/motion gates, native render,
verification, real-time MP4, every-frame 3× sheets, density rest recording,
scoped shadow refresh and production capture/gates) is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && sh experiments/cutouts/storm_capacitor/rr17_proof.sh
```

Its exact three windowed invocations are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr17/rest_contract.json tests/rr17/native_capture.gd -- --output res://experiments/cutouts/storm_capacitor/mq5/proof/native_rest --rest-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/render_contract.json tests/rr17/native_capture.gd -- --output res://experiments/cutouts/storm_capacitor/mq5/proof/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/visual_probe_runner.py --task-id rr-17 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/rr17/production_contract.json tests/rr17/production_capture.gd -- --type storm_capacitor --output res://experiments/cutouts/storm_capacitor/mq5/proof/production_native
```

All proof is at 1920×1080 / 100% UI scale. Outputs remain:

- `mq5/proof/native_rest/{front_rest,rear_rest,rest}.png`
- `mq5/proof/native/verification.json`
- `mq5/proof/storm_capacitor_review.mp4`
- `mq5/proof/contact_sheets/*_all_frames_3x.png`
- `mq5/proof/production_native/{frames,verification}.json`

The MP4 centres one Capacitor at 2× nearest-neighbour on #1E1E24, with clip name
at top centre: idle ×3, charge ×2, discharge ×2, hit ×2, death once plus a
one-second terminal hold. Exact native contacts are separately captured without
changing the reel clock. Encoding checks frame count, 60 fps and dimensions.
The sheets include every presented frame at 3× with one fixed union crop.

A concrete director-owned fixture remains:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/inspection_fixture.py --task-id rr-17 --run-id rr-17-inspection --scenario combat --enemy-types storm_capacitor,crawler,crawler,crawler --enemy-positions 2:4,3:4,5:4,6:5 --enemy-charge 2 --summary 'rr-17 Storm Capacitor: Charge then Arc Burst'
```

## TODO_DESIGN, chosen defaults and open issues

No active design placeholders and no new player-facing values. New proof-only
named defaults are `PROOF_TIMEOUT_SECONDS = 90` for feedback samples,
`PROOF_CUE_DURATION_SECONDS = 0` for the silent SFX stub,
`PROOF_ENEMY_ROW = 4` for deterministic paired-death placement, and
`MUTATION_TIMEOUT_SECONDS = 180` for negative controls. Existing 180 s
production and 60 s sampler timeouts, 0.0001 bone tolerance, fixture state,
canvas, UI scale and controlled clock defaults remain in effect. Runtime
microsecond rounding is exactly the existing animation runner's rounding.

Open issues: the Git-index sidecar check awaits director staging because of
the sandbox permission failure above; fresh windowed proof awaits the director.
