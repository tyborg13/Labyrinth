# rr-47 implementation evidence

Changes are uncommitted on `codex/rr-47`. No reviewer agents, peer review, commits, publication, fixture launch or windowed runs were performed. The design owner retains those phases. No art, icon, audio, font, authored motion, balance, analytics or save values changed.

## 1. Back-route disappearance

rr-46 inverted `unit_world_positions` to select a retained tile host. That position includes the cutout's nearest-facing artwork projection, which is not the diagonal board path. On `(2,1) → (1,2)`, the inversion reaches the boundary row and selects a host whose boundary wall is culled. `_units_by_draw_tile_cache` still contains the actor, but no retained layer calls `_draw_unit_body`. The actor is neither hidden nor unparented by the parity clock, and no opaque floor covers its upper body: its callback is absent.

`board_depth.gd` now samples the unchanged authored root-forward track on the actual board path, excluding visual lift. It preserves Seer's non-linear authored travel and reuses the existing fallback footprint coordinate for reduced motion and submissions without an authored move. Static occupants retain their original convention. The new regression observes actual retained layer callbacks, not just the routing dictionary; it checks all mandatory routes, all ten rigs on both boards, endpoints and the ordinary arrived state after overrides disappear.

Matched headless evidence: `a420283fa` has **0 missing callbacks in 554 back-route samples**; the exact rr-46 depth-helper mutation has **110 missing callbacks in the same 554 samples**; the fixed runtime has **0 missing callbacks in 5,540 mandatory-matrix samples**. Thus rr-46 introduced the missing-host defect. The matched native comparison uses the same probe but remains for the design owner.

The director's Seer frames 0, 36, 40 and 53, their actual/expected ownership maps and actor masks are retained verbatim: **16 files, 3,330,784 bytes**, with individual SHA-256 bindings in `fixtures/back_route.json`. The headless fixture check confirms the original recorded actor/mismatch counts. This is explicitly historical failing evidence, not a passing capture. `route_probe.gd`, its proof contract and `verify_route.py --bind` provide fresh passing, hash-bound regression fixtures on the owner's renderer.

## 2. Pillar anchor

The source investigation refined the brief's diagnosis: `paint_primitives.gd` already uses `world_position_for_tile(tile)`, the tile centre. The incorrect expected order came from the actor's artwork-axis body offset being compared with that centre. Moving the prop anchor would introduce a new error.

The independent checker now obtains authored forward travel directly from the protected track and projects it onto the route. It does not call production's depth helper or painter order. On `(3,3) → (2,4)`, its ground depth stays 6 and pillar `(2,3)` stays 5. The new test checks the pillar's tile-centre anchor and actor-in-front order for the whole route: **534 samples**. Reversed composition, actor/prop swap and reversed production canvas order remain failing mutation tests.

## 3. Death tail and verifier

All 20 supplied death failures are exactly **frame 62 / phase 1.0**, ten per board, with zero actor-mask pixels. Frame 61 is phase 0.983870967741935 and still has actor paint. The death absence boundary remains the end of the production clock, with Gaoler 0.62 retained as an early-disappearance negative control.

Godot's `Color.TRANSPARENT` is `(1,1,1,0)`. Expected maps initialized with it contained `(255,255,255,0)` where native readback and independently reconstructed primitives contained zero RGBA. Terminal inspection covers the entire crop, exposing those transparent RGB mismatches; the verifier also compared those bytes exactly. `paint_composite.gd` now initializes unowned pixels to zero RGBA. Both strict checks agree without masking or tolerance changes. The new cross-language fixture composes visible and terminal maps in Godot and verifies them through the independent Python reconstruction; deliberate transparent-RGB corruption still fails.

The new clock assertion also exposed a CPU rounding edge for Gaoler and Lancer: scaled division at progress 1 yielded 0.9999999999999999, while the shader's float uniform was already 1. `death.gd` now returns the normalized terminal value 1 exactly. No duration or earlier phase was changed. The absence rule is checked against production's dissolve clock for every rig, including the penultimate and terminal samples.

## 4. Final fight still

Escaped the literal percent in the interpolated `100%% UI scale` message at `tests/fix18/real_fight_capture_probe.gd:550`. `fight_save.gd` invokes the actual inherited save function headlessly with explicitly labelled software fixture pixels and checks saved PNG dimensions, reload and SHA-256. Native recording/final-still commands are in `proof_for_design_owner.md`.

## Validation

Logs and reports are under `/private/tmp/labyrinth_codex/rr47/`.

- Focused rr-47: `Ran 5 tests in 67.679s` / `OK`. Includes the historical regression mutation, retained callback matrix, hash-bound native failure fixture, exact Godot/Python compositor bridge and final-still save.
- Focused rr-46 first run: `Ran 23 tests in 235.449s` / `FAILED (failures=1)`. The newly added production-clock assertion caught the terminal rounding edge above; all other checks passed.
- After fixing that edge, affected painted oracle/inventory and painter mutations: `Ran 2 tests in 50.483s` / `OK`; `RR46 PAINTED ORACLE: PASS (independent primitive composition; reverse/pair mutations; authored absence; Retina crops)`; `RR46 PAINTER MUTATIONS: PASS (reversed composite; actor/prop swap; reversed production canvas order)`.
- rr-46 guards also observed: `RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 74248 old-routing failures; 30 retreat routes; native pixels=false)`; `RR46 MIXED DEATH CLOCKS: PASS (12 blocking/overlap cases; three speeds; 12 authored event crossings)`; `RR46 TIMING: PASS (39 actor/speed rows; production path schedule)`; `RR46 ROUTING MUTATIONS: PASS (death opt-in and occupant sorting rejected)`; `RR46 SCALING MUTATIONS: PASS (move and death rejected by production schedule checks)`.
- Isolation audit: `ISOLATION AUDIT: 239 modules`, exit 0. New `test_rr47_depth: []` writes only unique per-test temporary directories and isolated runner homes.
- Registration: `TEST REGISTRATION AUDIT: PASS (876 scripts; full suite=511, quarantined=29, windowed probe=336)`.
- Native inventory and route-probe parse/list: `RR46 NATIVE CASE INVENTORY: 2 boards; 20 jobs; 20 deaths; stride 2 move/retreat, stride 1 death`; exit 0. The inventory binds the new production depth helper, death clock and route-proof sources.
- First rr-47 focused attempt: `Ran 5 tests in 334.264s` / `FAILED (failures=1)` because staging the historical board alone mixed incompatible historical/current helpers. The stager now uses the matching historical runtime; the final focused run above passes.

The complete Python run encountered the stale `tests/rr46/rest_binding_changes.json` source pins before refresh. Only its two `after` source hashes were updated; all `before` hashes and the full original rest-pose byte seal remain unchanged. Follow-up proof:

- `Ran 2 tests in 0.284s` / `OK` (`rest-binding-final.log`): complete pose-byte pin and its missing/unknown/forged-binding mutations.
- `Ran 1 test in 71.464s` / `OK` (`rest-reseal-final.log`): `RR41 REST/DENSITY RESEAL: PASS (fresh poses byte-identical after pinned fix-18 source bindings; density evidence unchanged)`.
- `RR47 ROUTE BINDER SOFTWARE TEST: PASS (stable hashes; missing cadence, wrong phase, missing actor and stale source rejected; native pixels=false)` (`route-binder-software.log`).

Full Godot command was run once through the required runner with its unchanged 900-second aggregate budget. It reports `MAIN BODY RUNTIME: 801.409 seconds`, `MAIN BODY ASSERTIONS: 495687`, and `TEST RESULT: FAIL (120 failure(s))`. Of 236 standalone programs, 117 passed; three hit their normal 180-second limit; 116 were unfinished when the aggregate budget expired. Both full suites were launched concurrently, adding load. The timed-out programs are `suites/sfx_sync_0_program`, `suites/sfx_sync_1_program`, and `suites/full_scene_interaction_program`. No limits or assertions were changed. The failed invocation remains a failure; follow-up completion of only the 119 unfinished programs is recorded below.

Full Python command: `python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/rr47/full-python` (one invocation). Result, exit 1:

```text
Ran 2141 tests in 2383.833s
FAILED (failures=1, errors=1, skipped=66)
```

The error is the source-provenance pin read before its two source hashes were refreshed; the two focused provenance/mutation tests and fresh rest/density reseal above pass after refresh. The failure is unchanged `test_sb02_movement.Movement.test_incremental_submission`: `Movement plan exceeds 4000 us: 11119`. The preceding rr-46 full run already reported this same concurrency-sensitive performance assertion (`tests/rr46/implementation_report.md`); its limit/assertions were not edited here. Its idle follow-up is recorded below. All rr-46 and rr-47 test modules passed in the full Python invocation, including the depth/routing/clock/painter mutations and all ten family-preservation modules.

The Python runner also reported its existing shared-Git timing-cache permission denial: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmp80ekhi32'`. Task-local result files were saved; no escalation or alternate Git metadata was attempted.

Final source/metadata checks after the full Python run: `RR47 SIDECARS INCLUDING UNTRACKED SOURCES: PASS`; `RR47 SOURCE BINDINGS: PASS (41 source hashes)`; `RR47 DIFF WHITESPACE: PASS` (`integrity-final.log`). Git status contains only the listed unit files, all uncommitted on `codex/rr-47`.

### Completion of the Godot graph and idle timing check

After Python exited, only the 119 unfinished Godot programs were run via `tools/program_suite_runner.py --jobs 3`, using unchanged 180-second child and 900-second aggregate limits. The exact command array is `/private/tmp/labyrinth_codex/rr47/unfinished-command.json`; report: `unfinished-programs.json` (681.909 seconds). It completed **115/119 passing**, with four environment-cache failures: `special_encounter_test`, `enemy_no_action_test`, `fix_11_test`, `fix_11_probe`.

The worktree lacked eight emblem `.ctex` caches and `.godot/global_script_class_cache.cfg`. A temporary sparse import project copied the existing eight approved PNGs and their existing `.import` settings, plus the 18 actual source files reachable from `scripts/game_data.gd`. Both cache builds ran through `tools/godot_task_runner.py --task-id rr-47 --stream -- godot --headless --path /private/tmp/labyrinth_codex/rr47/emblem-import-project --import`, exit 0 (`emblem-import.log`, `class-cache-import.log`). Only generated ignored cache files were copied back. No source image, sidecar, game script, assertion or registry source changed. This was actual cache bootstrap, not a parser-check editor scan.

The four affected checks then passed through the same program runner with one worker and normal limits:

```text
RR47 CACHE FOLLOWUP: PASS (4/4 programs; 87.141 seconds)
RR47 COMPLETE GODOT PROGRAM GRAPH: PASS (236/236 standalone programs observed passing; original aggregate invocation remains failed)
```

Reports: `cache-followup.json`, `godot-coverage-final.json`. Thus every standalone program and the 495,687-assertion main body were exercised successfully across the recorded invocations. **The original timed full invocation remains failed**; this does not claim the 900-second complete-suite budget passed.

Once all other test processes stopped, the unchanged movement payload was run with `python3 tools/godot_task_runner.py --task-id rr-47 --stream -- godot --headless --path . --script tests/status_plates_performance_probe.gd -- --movement-only`:

```text
STATUS MOVEMENT PROBE RESULT: PASS
```

Exit 0 (`sb02-idle.log`); `plan_max_us=1350` versus the unchanged 4000 µs cap; mixed cold best / warm median were 1949 / 256 µs. The original full Python timing failure remains recorded.

## Files changed

- Runtime: `scripts/maquette_cutout_runtime/board_depth.gd`, `death.gd`.
- Fight probe: `tests/fix18/real_fight_capture_probe.gd`.
- rr-46 checker/integration: `tests/rr46/native_cases.gd`, `native_inventory.json`, `paint_checks_test.gd`, `paint_composite.gd`, `paint_primitives.gd`, `rest_binding_changes.json`.
- rr-47 tests, immutable failing evidence, route probe/contract/verifier, temporary-project stager, implementation/proof documents and script UIDs: `tests/rr47/**`; Python driver: `tests/test_rr47_depth.py`.
- Required registrations: `tests/windowed_test_allowlist.json`, `tools/python_suite_resources.json`.

## TODO_DESIGN placeholders

None introduced. The brief supplies the required visible behavior; no new visible values were selected.

## Chosen defaults

- `tests/test_rr47_depth.py::DEFAULTS.suite_timeout_seconds = 360`: subprocess supervision for headless regression fixtures.
- `tests/rr47/routing.gd::PROOF_ACTOR_HP = 10`: inherited isolated actor survival fixture; no production tuning.
- Software compositor fixtures use the named `SIZE = Vector2i(4,4)` canvas; unfinished-program completion uses three child workers with unchanged time limits. The temporary sparse cache-import project uses `config/name="rr47 Import Cache Fixture"` and `renderer/rendering_method="gl_compatibility"`; these fields affect only headless cache bootstrap.
- Proof-only route names, software image filenames and temporary output locations name fixtures; no player-facing defaults were added. Native job budgets, sample cadence, resolution, UI scale and fight fixture values reuse rr-46's existing named constants/contracts.

One early provenance command also named a nonexistent Python module (`tests.test_rr41_registration_halo`); the corrected two-test command is the passing result listed above.

## Open proof

The complete-suite aggregate timing budget was not observed passing. All program/assertion coverage was completed as described above; the design owner retains the final merge-wide full run.

Fresh native base/fixed comparison, all 20 native jobs with zero verifier errors, native fight recording/final still and the playable inspection fixture require the design owner's window server. Exact commands and capture paths are in `proof_for_design_owner.md`. No native success is claimed from software or callback checks.
