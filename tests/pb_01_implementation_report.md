# pb-01 implementation handoff

Changes are uncommitted on `codex/pb-01`. No commit, branch operation, peer review, publication, queue edit, art generation, or windowed run was performed.

## Requirements

1. **Objective copy:** the prominent 19 px line is `OBJECTIVE · <TITLE>`. The four shared descriptions match the brief verbatim. The secondary line uses the existing 14 px caption role and cannot wrap. `time` uses its gold word-only glossary token. Dragon and Guardian objectives omit the secondary line. Current identity rules resolve old saved descriptions as before.
2. **Living foes:** the new reusable wrapper selects the production board renderer for all 32 rigged identities, including promoted Gust Shrike and the shared Guardian renderer. Renderer selection precedes legacy sheet loading; the board's loader/order/timing supply that fallback. The 11 unrigged identities stay static. Existing source TextureRects and node names remain the layout/scale/floor/pool/badge authority; only the live padded canvas replaces their visible art. Slot index divided by displayed slot count seeds the authored idle cycle. Hidden actors pause; reduced motion selects the authored rest pose. Inspection stills and input paths remain intact.
3. **Performance:** the six-rigged-foe before/after benchmark is implemented and passes headless workload validation. It removes the live nodes for the static baseline, uses the same production scene, kit, roster, layout and renderer configuration, then compares ABBA trials with 45 warmup and 180 measured frames per trial. It records frame intervals, process time and viewport CPU/GPU time. Median and p95 must both avoid regression. **Actual renderer timing remains unmeasured; the director must run the command below.**

## Files changed

- `scripts/combat_objective_rules.gd`: exact shared descriptions only.
- `scripts/pre_battle_view.gd`: objective hierarchy, glossary word token, per-slot live actors.
- `scripts/pre_battle_foe_layout.gd`: apply existing source registration to the live wrapper.
- `scripts/live_actor_presentation.gd` (new): reusable renderer/sheet/still presentation wrapper.
- `tests/suites/pre_battle_ui_suite.gd`: include the new suite in existing semantic/full-suite coverage.
- `tests/suites/combat_objective_suite.gd`: replace its old `Hold out` / `Label` expectation with the exact authored survival line in the new secondary `RichTextLabel`. This failure was introduced by the intentional pb-01 copy change; existing unrelated failure assertions remain intact.
- `tests/suites/pre_battle_living_foes_suite.gd` and `tests/pre_battle_living_foes_test.gd` (new): exact copy, all 43 identities, scale/floor inheritance, front idle, advancing/hidden/rest clocks, deterministic phases and still inspection checks.
- `tests/fixtures/pre_battle_view_reference.gd`: update only the two intentionally changed presentation surfaces in the frozen synchronous reference; preparation/retention comparison remains independent.
- `tests/pre_battle_living_foes_fixture.gd`, `tests/pre_battle_living_foes_probe.gd`, `tests/pre_battle_living_foes_benchmark.gd` (new): shared scene fixture, 13-state visual proof and matched performance proof.
- `tests/proof_contracts/pb_01_living_foes.json`, `tests/proof_contracts/pb_01_performance.json` (new): acceptance/inspection contract and exact-size semantic image requirements.
- `tests/pb_01_implementation_report.md` (new): this handoff.

## Tests and probes run

Every Godot command used `python3 tools/godot_task_runner.py --task-id pb-01 --stream -- godot --headless --path . --script <script>`; the full suite used the documented `--timeout 900`. Probe/benchmark setup checks appended `-- --logic-only` and made no renderer captures or performance claims.

Observed final result lines:

- `PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)` / `TEST RESULT: PASS`
- `PRE-BATTLE SEMANTICS TEST: PASS` / `TEST RESULT: PASS`
- `PRE-BATTLE VIEW TEST: PASS` / `TEST RESULT: PASS`
- `PRE-BATTLE TRUE SCALE TEST: PASS` / `TEST RESULT: PASS`
- `PRE-BATTLE REVIEW FIXES TEST: PASS` / `TEST RESULT: PASS`
- `PREPARED PRE-BATTLE VIEW EQUIVALENCE RESULT: {"cases":18,"errors":[],"presented":12}`
- `PB-01 LIVING FOES PROBE LOGIC ONLY: PASS`
- `PB-01 SIX-FOE BENCHMARK LOGIC ONLY (NO PERFORMANCE MEASUREMENT): PASS`
- UI identity lint after the final spacing-constant edit: `Ran 25 tests in 2.879s` / `OK`.
- Python full discovery: `Ran 545 tests in 377.736s` / `OK (skipped=61)`.
- Output import hygiene: `OUTPUT GDIGNORE: PASS (12 folders; 2 referenced roots)`.

Full Godot suite after the copy-expectation fix: **PASS**, exit 0. Exact result lines: `FULL SUITE RUNTIME: 792.316 seconds (budget 900 seconds)` / `TEST RESULT: PASS`. All program sub-suites passed.

Verification iterations retained for transparency: the first attempt reached the 900-second limit (exit 124) after run-end recap passed, before the final main-menu check completed; it overlapped Python discovery and focused checks. The second attempt completed all program sub-suites and emitted `FULL SUITE RUNTIME: 860.000 seconds (budget 900 seconds)` / `TEST RESULT: FAIL (1 failure(s))`: the objective suite still expected the deliberately replaced words `Hold out` in a `Label`. That expectation now requires the exact new survival line in its secondary `RichTextLabel`. The focused runner executes the full combat-objective suite and passes, as does the final full run.

Logs: `/private/tmp/pb-01-full-godot-attempt-1.log` (timeout), `/private/tmp/pb-01-full-godot-attempt-2.log` (one stale-copy assertion), `/private/tmp/pb-01-full-godot.log` (final standalone run), `/private/tmp/pb-01-python-suite.log`, `/private/tmp/pb-01-living.log`, `/private/tmp/pb-01-semantics.log`, `/private/tmp/pb-01-view.log`, `/private/tmp/pb-01-true-scale.log`, `/private/tmp/pb-01-review-fixes.log`, `/private/tmp/pb-01-equivalence.log`, `/private/tmp/pb-01-probe-logic.log`, `/private/tmp/pb-01-benchmark-logic.log`, `/private/tmp/pb-01-ui-lint.log`.

The first benchmark logic run exposed retained-section reuse in the proof fixture; explicit proof-only invalidation fixes it. The initial equivalence run reported the intended copy/hierarchy/live-node differences against its old reference; the narrowly updated reference now passes all 18 cases. The survival-copy expectation was updated only for the intentional pb-01 copy/type change; unrelated assertions remain intact. Godot macOS certificate diagnostics, ObjectDB cleanup warnings and scene-tree cleanup diagnostics from unchanged scripts appeared in logs.

## Proof for the design owner

No windowed command was attempted: this worker has no window-server access. Run these exact commands from this worktree. The runner prints the isolated absolute capture folder and records it in the result manifest. The 120-second benchmark budget covers four known 225-frame warmup/sample trials plus scene setup and captures; its startup watchdog stays at the normal default.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pb-01 && python3 tools/visual_probe_runner.py --task-id pb-01 --no-headless --display-driver macos --audio-driver Dummy --min-images 13 --expect-size 1920x1080 --proof-contract tests/proof_contracts/pb_01_living_foes.json --result-manifest /private/tmp/pb-01-living-foes-renderer.json tests/pre_battle_living_foes_probe.gd
```

Captures: `user://probes/pb_01_living_foes/mixed_idle_00.png` through `mixed_idle_03.png`; `objective_kill_leader.png`, `objective_survive.png`, `objective_reach_exit.png`, `objective_dragon.png`, `objective_guardian.png`; `controller_focus.png`, `inspection_still.png`; `reduced_motion_00.png`, `reduced_motion_01.png`. `witnesses.json` records per-slot renderer snapshots. The probe checks actual pixel changes across the idle strip and unchanged pixels in the reduced-motion foe stage. Inspect the original 1920×1080 images at 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pb-01 && python3 tools/visual_probe_runner.py --task-id pb-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 4 --expect-size 1920x1080 --proof-contract tests/proof_contracts/pb_01_performance.json --result-manifest /private/tmp/pb-01-performance-renderer.json tests/pre_battle_living_foes_benchmark.gd
```

Captures: `user://probes/pb_01_performance/00_before_1920x1080_ui100.png`, `01_after_1920x1080_ui100.png`, `02_after_1920x1080_ui100.png`, `03_before_1920x1080_ui100.png`; raw measurements and verdict: `measurement.json` in that folder. No inspection-fixture command was required by this unit brief; fixture preparation remains assigned to the design owner.

## TODO_DESIGN placeholders

`OBJECTIVE_LINE_SPACING` in the production view and its reference fixture: the brief does not supply a vertical gap between the restored heading and secondary copy. The provisional field references the existing `Typography.SPACE_TIGHT` token (4 px). The design owner must confirm or replace it during inspection.

## Chosen defaults (test/debug only)

- Test fixture rosters: mixed `crawler, burrow_grub, crawler, ash_hound, gust_shrike, hoarfrost_seer`; performance `crawler, acolyte, harrier, warden, ash_hound, gust_shrike`; named objective proofs use Vyraketh and Last Lamplighter.
- Unit stage size: 206×365; explicit clock step: 0.23 seconds; phase fixture: slot 2 of 6. These do not set production layout or timing.
- Frame strip: four frames, 0.2 seconds apart. Benchmark: ABBA, 45 warmup / 180 measured frames per trial; VSync disabled and FPS uncapped only in the windowed benchmark; headless validation uses two process frames and emits no timing verdict.
- Proof regions `[390, 320, 650, 530]` (foes) and `[600, 245, 720, 100]` (header), with luma thresholds of range 8 and standard deviation 2, are named debug-only image-validation fields; no production camera or layout changes.
- Existing base-fixture seed selection, settling delays and 1920×1080/UI100 settings are reused. Production phase spacing is derived from actual slot count; production cycle durations come exclusively from existing board renderer/data.

## Open issues / owner actions

- Real-renderer captures, visual identity judging and the six-foe no-regression measurement are pending owner execution.
- Confirm `OBJECTIVE_LINE_SPACING`.
- Read-only `parallel_task.py status` reported an empty acceptance/proof contract (`contract_ready: false`) despite the launch brief stating it was recorded. Acceptance and proof expectations are also recorded in the owned proof JSON. The owner must reconcile helper metadata before their commit/review/inspection workflow.
- The existing `tests/pre_battle_preview_probe.gd` still contains its explicitly retained `KILL THE LEADER` boss-title assertion, although current identity rules use named bosses. It was left unchanged; this worker only parsed that legacy probe. The new probe checks the current exact named title.
- Peer review, inspection fixture, commit and publication remain with the owner, as requested.
