# int-02 implementation handoff

All changes are uncommitted on `codex/int-02`. No review, commit, publication,
branch change, queue edit or inspection-fixture preparation was performed.

## Round 1: portable Weaver fingerprints

The demo-recording fix is implemented and uncommitted. The source hashing was
extracted into `tools/demo_clips/comparison.py:_source_fingerprint`; the existing
exact-match `any(...)` guard, reviewed production policy, payload checks and
exact frame-coordinate checks remain intact. Production still reads actual
live source bytes and requires re-recording/re-review when they change.

`tests/fixtures/demo_clips/weaver_fingerprints.json` retains the reviewed source
fingerprints alongside the portable capture. The comparison tests use that
fixture only at the source-read boundary. A new test also exercises the real
hashing path against temporary source bytes: reviewed bytes allow all 96
exemptions, then an actual source change rejects `events[6]` at offset `+47`.

Round-1 changes: `tools/demo_clips/comparison.py`,
`tests/test_demo_recording.py`, `tests/fixtures/demo_clips/README.md`, the new
fingerprint JSON, and this report.

Observed verification:

- `python3 -m unittest discover -s tests -p 'test_demo_recording.py' -v`:
  `Ran 31 tests in 4.560s`; `OK`.
  Log: `/private/tmp/int-02-r1-demo-recording-guard.log`.
- A read-only check using the two glossary JSON files directly from
  `codex/peer-benchmark` passed the glossary copy/budget test:
  `Ran 1 test in 0.030s`; `OK`.
  Log: `/private/tmp/int-02-r1-integration-glossary.log`.
- `git diff --check`: exit 0. Production
  `tools/demo_clips/comparison_exemptions.json` is unchanged.

The requested merge is blocked by the sandbox, before any merge state was
created. Attempted command:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-02 && git merge --no-commit --no-ff codex/peer-benchmark
```

Exact failure:

```text
fatal: update_ref failed for ref 'ORIG_HEAD': cannot lock ref 'ORIG_HEAD': Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/int-02/ORIG_HEAD.lock': Operation not permitted
```

The branch remains at `05e8d872b`, with no `MERGE_HEAD`. An outside-sandbox
merge was requested. Full Python discovery and Godot verification of the
integrated tree must follow that merge; they have not been claimed as passing
for round 1. The full-suite results below are from the original implementation.

## Numbered requirements

1. `maquette_cutout_runtime/presentation.gd` resolves renderer Scripts from its
   existing `CREATURES` registration. `ActorPresentation.travel_renderer`, board
   sync and portrait binding use that resolver. This covers LiveActor,
   pre-battle, turn order, landing strip and inspection. Pre-battle's retained
   source canvas now shares its LiveActor renderer's atlas, approved rest-path
   metadata and opaque bounds; no second renderer is created for that canvas.
2. The shared maquette renderer accepts a normalized idle seed before tree
   entry and derives seconds from the protected compiled motion. Snapshots
   expose the displayed clip/phase, including reduced-motion rest. Existing
   travel query APIs delegate to the old helpers; gameplay continues to use
   the approved compiled maquette action duration. No tuning values changed.
3. Removed nothing. Both legacy renderer files still have references, listed
   below. They remain available to gameplay helpers and legacy/export fixtures.
4. The pb-01 independent Script oracle now names both concrete maquette
   Scripts. Its actual SceneTree motion, hidden/reduced-motion pause and
   six-slot/two-rebuild phase tests exercise both. A separate small suite
   instantiates board, rail, landing-strip and portrait consumers; inspection
   and source-canvas checks run in the roster suite. The new checks were run
   before the routing fix and failed. The full Godot suite passes. Python
   discovery still has three failures in unchanged files, detailed below.

## Files changed

- `scripts/actor_presentation.gd`: central travel routing.
- `scripts/live_actor_presentation.gd`: maquette seed and shared source atlas.
- `scripts/maquette_cutout_runtime/presentation.gd`: shared renderer resolver.
- `scripts/maquette_cutout_runtime/portrait.gd`: resolver and reusable atlas adapter.
- `scripts/maquette_cutout_runtime/renderer.gd`: seed and displayed-pose snapshot.
- `scripts/maquette_cutout_runtime/shale_bloomer_renderer.gd` and
  `lightning_wisp_renderer.gd`: compatibility with existing travel queries.
- `tests/suites/pre_battle_living_foes_suite.gd` and new
  `maquette_presentation_surfaces_suite.gd`: regression coverage.
- `tests/pre_battle_living_foes_probe.gd`: optional `--maquette-pack` proof case.
- `tests/proof_contracts/int_02_maquette_surfaces.json`: 13-capture UI100 contract.
- `tests/pb_01_mutation_check.py`: adapt seed mutation; task-local runner/output options.
- This report. No scenes, assets, protected data, saves or analytics changed.

## Verification

Commands were run from this worktree. Godot always used
`python3 tools/godot_task_runner.py --task-id int-02 --stream -- godot --headless --path .`.

| Check | Observed result | Log |
| --- | --- | --- |
| `--script tests/pre_battle_living_foes_test.gd` | `PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)`; `TEST RESULT: PASS` | `/private/tmp/int-02-living-foes-final.log` |
| `--script tests/maquette_cutout_test.gd` | `MAQUETTE CUTOUT: PASS (1710 checks, 0 failures; headless logic only)` | `/private/tmp/int-02-maquette.log` |
| `--script tests/maquette_cutout/integration_test.gd` | `MAQUETTE INTEGRATION: PASS (0 failures)` | `/private/tmp/int-02-integration-fixed.log` |
| `--script tests/pre_battle_living_foes_probe.gd -- --logic-only --maquette-pack` | `PB-01 LIVING FOES PROBE LOGIC ONLY: PASS` | `/private/tmp/int-02-probe-logic-final.log` |
| `python3 tests/pb_01_mutation_check.py --task-id int-02 --output /private/tmp/int-02-mutations.json` | `PB-01 MUTATION CHECK: PASS (5/5 caught)` | `/private/tmp/int-02-mutations.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 2.634s`; `OK` | `/private/tmp/int-02-ui-identity.log` |
| `python3 tests/test_icon_identity_policy.py` | `Ran 7 tests in 0.064s`; `OK` | `/private/tmp/int-02-icon-identity.log` |
| Full Godot, with `--timeout 900 --script tests/run_tests.gd` | `FULL SUITE RUNTIME: 807.952 seconds (budget 900 seconds)`; `TEST RESULT: PASS` | `/private/tmp/int-02-full-godot.log` |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | `Ran 616 tests in 490.517s`; `FAILED (failures=2, errors=1, skipped=61)` | `/private/tmp/int-02-python.log` |
| `python3 tools/output_gdignore.py --check` | `OUTPUT GDIGNORE: PASS (13 folders; 3 referenced roots)` | `/private/tmp/int-02-output-gdignore-final.log` |
| `git diff --check` | Exit 0, no output | — |

The pre-fix integration run failed 14 assertions about stale source art, source
canvas and pool bounds. Those assertions were preserved and pass after wiring
the source atlas. The baseline full-suite run loaded the original scripts before
editing and finished `TEST RESULT: FAIL (14 failure(s))`;
`/private/tmp/int-02-baseline-godot.log` also includes the old Wisp's `crown`
motion errors. No failure assertion was weakened.

The ordinary Python compile-cache path is outside this sandbox. The syntax
check passed with
`PYTHONPYCACHEPREFIX=/private/tmp/labyrinth_codex/int-02-pycache python3 -m py_compile tests/pb_01_mutation_check.py`.

## Proof for the design owner

Windowed proof was not attempted: this worker has no window-server access.
Run exactly:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-02 && python3 tools/visual_probe_runner.py --task-id int-02 --no-headless --display-driver macos --audio-driver Dummy --min-images 13 --expect-size 1920x1080 --proof-contract tests/proof_contracts/int_02_maquette_surfaces.json --result-manifest /private/tmp/int-02-maquette-surfaces-renderer.json tests/pre_battle_living_foes_probe.gd -- --maquette-pack
```

The runner prints its isolated capture directory under
`user://probes/pb_01_living_foes/`. Expected images: `mixed_idle_00.png` through
`mixed_idle_03.png`, `objective_kill_leader.png`, `objective_survive.png`,
`objective_reach_exit.png`, `objective_dragon.png`, `objective_guardian.png`,
`controller_focus.png`, `inspection_still.png`, `reduced_motion_00.png` and
`reduced_motion_01.png`, plus `witnesses.json`.

The headless probe wrote witnesses, not captures, to:
`/private/tmp/labyrinth-godot-home/int-02-1792174256412885000-19701/Library/Application Support/Escape the Umbra Parallel int-02-1792174256412885000-19701/probes/pb_01_living_foes/witnesses.json`.

No `inspection_fixture.py` command was requested by this brief. Fixture
preparation, visual inspection, review and publication belong to the owner.

## Legacy renderer references retained

Production references (some are timing/constants only):

- `scripts/combat_board_view.gd`
- `scripts/run_scene.gd`
- `scripts/bile_bloomer_cutout/pool.gd`
- `scripts/maquette_cutout_runtime/shale_bloomer_renderer.gd`
- `scripts/maquette_cutout_runtime/lightning_wisp_renderer.gd`

Test references:

- `tests/lightning_wisp_cutout_asset_probe.gd`
- `tests/lightning_wisp_cutout_gameplay_probe.gd`
- `tests/bile_bloomer_cutout_gameplay_probe.gd`
- `tests/lightning_wisp_cutout_pack_test.gd`
- `tests/bile_bloomer_cutout_pack_test.gd`
- `tests/fixtures/lightning_wisp_cutout_export_smoke.gd`
- `tests/fixtures/bile_bloomer_cutout_export_smoke.gd`
- `tests/fixtures/static_floor_cache_reference.gd`
- `tests/run_tests.gd`

Text/provenance references also remain in the unit brief,
`spec/peer_benchmark/staged/text/{coverage,inventory_icons}.json`, and 52
historical files under `spec/proofs/`. None were rewritten.

## TODO_DESIGN placeholders

None added. No perceivable design decisions were missing.

## Chosen defaults

- Debug proof roster: crawler, bile_bloomer, lightning_wisp, noctyrax,
  gust_shrike, hoarfrost_seer, selected only with `--maquette-pack`.
- New surface tests settle for `PROCESS_FRAMES = 3`, matching pb-01. Their
  synthetic rail entry uses id/HP/max HP `1`, time `0`, first rail slot and
  landing-strip x `0`; production data is untouched.
- Mutation logs use `/private/tmp/int-02-mutations.json` and adjacent per-case
  logs via the new optional CLI argument; prior defaults remain available.
- The new source-guard test uses the existing committed reference gzip as its
  source-byte fixture; its expected digest is stored in `guard_fixture`.

## Open issues

- Real-renderer images and design-owner inspection remain outstanding.
- `parallel_task.py status` reported an empty acceptance/proof contract and
  `contract_ready: false`, despite the brief's stated owner preparation. Task
  metadata was left untouched; the owner must reconcile it before handoff.
- The original Python discovery had three failures. The demo
  tests `test_reviewed_weaver_pairs_report_presentation_exemptions` and
  `test_weaver_exemptions_survive_record_compare_and_encode_reports` reject
  stale fingerprint-bound timing exemptions (first rejected offset is
  `events[6] +47`). Their fingerprint inputs are unchanged
  `scripts/combat_pacing.gd`, `scripts/run_scene.gd` and
  `scripts/enemy_mechanics/bramble_view.gd`. The glossary budget test finds
  different `loadout` definitions in unchanged `data/glossary.json` and
  `spec/peer_benchmark/staged/text/glossary_rewrite.json`. No assertions or
  protected wording were changed in the original implementation. The verbose
  log records all 61 skips. Round 1 fixes the two portable demo tests; the
  integration branch supplies the approved glossary fix, pending the blocked
  merge and full-suite reruns described above.
