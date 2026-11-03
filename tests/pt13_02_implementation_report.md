# pt13-02 implementation handoff

Feedback 1 updates and current focused results: [pt13_02_feedback1_report.md](pt13_02_feedback1_report.md). The report below preserves the round-0 execution history.

Work is uncommitted on `codex/pt13-02`. Commit, peer review, inspection and publication are assigned to the design owner. No production artwork, fonts, audio, design data, saves or analytics were changed.

## Requirements

1. **Home and mirror:** the original `FEET_OFFSET`, mirrored-center formula and first two candidates remain unchanged, in their original order.
2. **HUD only:** chips reserve health collision rectangles, status/defense plates and pills, pips, fixed order discs, placed intent lines, leader crests and other chips. Sprite draw bounds and foreground prop candidates are removed. Existing terrain health bars reserve only their bar rectangles; fading unit health bars reserve only their visible frames. The external boss frame remains reserved independently of actor lifetime. Umbra-clipped HUD is excluded, matching the renderer. These helpers reuse the renderer's existing geometry and visibility rules; they do not move or restyle the bars. The unchanged callout solver places callout lines after chips and avoids their full rectangles.
3. **24 px Euclidean slide:** the exact obstacle-edge/bounds grid is searched around both homes. Squared distance selects the nearest clear candidate, then home over mirror, then vertical over horizontal. Existing sign ordering is retained. Fractional edges, diagonals, inclusive 24 px, ties, viewport restrictions and a sole distant pocket are tested.
4. **Fallback:** exhausted local searches use the original home with `above_everything=true`. Every fallback is checked for that exact center. Every nonfallback is checked against all HUD pieces, the viewport and other nonfallback chips.
5. **Order and stability:** the existing turn-order sort is unchanged. Repeated identical submissions must return identical layouts. A query-counting board verifies that chip placement never asks for unit draw bounds or foreground prop candidates.

The owner regression uses an existing frozen crawler and an adjacent hero to its lower right, with a proof-only interpolated world position. Both candidate rectangles intersect the hero body. In the real RunScene setup, the frozen old implementation moves its chip 101.316 px from the nearest home; the new code keeps it exactly at home without a HUD fallback. Production HUD draws chips after unit bodies.

## Geometry and cost

`pt13_02_fixture_results.json` records every fixture's chip count, fallback count and maximum displacement. There are 150 compact/expanded fixture states plus four targeted regressions: owner sprite, terrain bar, fading bar and external boss frame. The sweep covers staged/crowded rest, E2, mixed mechanics, the 11-enemy movement stress fixture, crowded boss/dragon fixtures, all six Warband biomes at tiers 1–3 in ordinary and status-crowded forms, all six tier-2 Snare biomes in five progression states, and Air Warband mid-fight.

Maximum observed displacement is **17.953527 px** on expanded `warband_air_3_crowd`. All 48 fallbacks stay exactly at home. All zero counts are included in the JSON. Compact and expanded fallback counts match:

| Fixture | Fallbacks per state |
| --- | ---: |
| mixed_stress | 2/8 |
| movement_stress_11 | 6/11 |
| boss_crowded | 2/3 |
| dragon_crowded | 2/3 |
| snare_air_first_seal / kept_open / pressure_turn3 | 1/3 each |
| warband_fire_1_crowd | 1/4 |
| warband_fire_3_crowd | 3/6 |
| warband_ice_3_crowd | 1/6 |
| warband_lightning_1_crowd | 1/4 |
| snare_shadow_first_seal / kept_open / pressure_turn3 | 1/2 each |
| Every other state/regression | 0 |

The busiest six-visible-enemy, fully decorated Air tier-3 Warband uses expanded HUD, 12 warmups and 120 interleaved samples. Final full-run median/p95: **5.711/7.197 ms**; frozen before: **7.249/8.704 ms**. The separate focused run measured 4.391/4.782 ms versus 5.721/6.177 ms. The frozen before implementation retains its original body/prop obstacles and unbounded search. These are CPU geometry measurements, not GPU/frame or pixel proof.

## Current focused result lines

Godot commands use `python3 tools/godot_task_runner.py --task-id pt13-02 --stream -- godot --headless --path . --script <script>`.

| Check | Observed result | Log |
| --- | --- | --- |
| `tests/threats_at_rest_test.gd` | `THREATS AT REST TEST RESULT: PASS (15953 assertions; includes compass suite)` | `/private/tmp/pt13-02-intent-current.log` |
| `tests/board_status_plates_test.gd` | `BOARD STATUS PLATES TEST RESULT: PASS (33856 assertions; 0 failures)` | `/private/tmp/pt13-02-hud-current.log` |
| `tests/perf/hover_equivalence_test.gd` | `PERF04 EQUIVALENCE RESULT: PASS (0 failures)` | `/private/tmp/pt13-02-hover-current.log` |
| `tests/intent_chip_placement_check.gd -- --mutation-only` | `INTENT CHIP PLACEMENT RESULT: PASS (60 assertions; 0 failures)` | `/private/tmp/pt13-02-health-obstacles.log` |
| `tests/intent_chip_placement_probe.gd -- --check-only` | `INTENT CHIP PROBE RESULT: PASS (10 states; 0 failures; check_only=true)` | `/private/tmp/pt13-02-probe-frozen.log` |
| `python3 tests/intent_chip_mutations.py` | `INTENT CHIP MUTATION RESULT: PASS (2/2 killed; controls pass; exact sources restored)` | `/private/tmp/pt13-02-mutations-current.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.839s` / `OK` | `/private/tmp/pt13-02-ui-lint-current.log` |
| `python3 tools/test_registration_audit.py` | `TEST REGISTRATION AUDIT: PASS (859 scripts; full suite=502, quarantined=29, windowed probe=328)` | `/private/tmp/pt13-02-registration-frozen.log` |
| `python3 tools/test_registration_audit.py --check-quarantine --output-dir /private/tmp/pt13-02-quarantine-check` | `QUARANTINE CHECK: PASS (29 entries; 28 programs; 0 now passing)` | `/private/tmp/pt13-02-quarantine.log` |
| `python3 tools/output_gdignore.py --check` | `OUTPUT GDIGNORE: PASS (16 folders; 6 referenced roots)` | `/private/tmp/pt13-02-gdignore.log` |
| `sh -n tests/pt13_02_design_owner_proof.sh`; `git diff --check` | exit 0 | no output |

The mutations restore the complete unbounded solver and restore other units' draw rectangles as obstacles. Both expected assertion messages were observed without script errors. Mutations execute in a private source overlay under the worktree's ignored `.godot` cache; live production sources are not mutated.

## Full suites and bootstrap

The required final command is `python3 tools/godot_task_runner.py --task-id pt13-02 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd`. Its final-code log is `/private/tmp/pt13-02-full-frozen.log`; the result is recorded below.

Earlier full attempts are retained as failures, not successful proof:

- `/private/tmp/pt13-02-full.log`: `FULL SUITE RUNTIME: 901.702 seconds (budget 900 seconds)` and `TEST RESULT: FAIL (37 failure(s))`. There were two failing suites, 34 stopped/unstarted suites at the overall deadline, and the runtime assertion.
- `/private/tmp/pt13-02-full-final.log`: `MAIN BODY RUNTIME: 402.525 seconds`, `MAIN BODY ASSERTIONS: 495562`, then `error: command timed out after 900 seconds.` The child report had 209 passes, one inventory timeout, two script-error exits and 14 interrupted/unstarted suites. No final `TEST RESULT` line was emitted.
- `/private/tmp/pt13-02-full-current.log`: another pre-final run reached its budget. Its child report recorded seven timeout/interruption results. No assertion was weakened.

The unchanged shop test's separate rerun reports `PREPARED SHOP EQUIVALENCE RESULT: {"cases":3,"errors":[],"presented_frames":5}`. The inventory rerun reports `CHARACTER RETENTION RESULT: {"cases":123,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":4391}` with runner exit 0.

Two clean-worktree cache inputs were initialized without editing game/test sources:

- Eight approved emblem PNGs and their unchanged sidecars were imported in an isolated scratch project; only the generated `.ctex` files were copied into the ignored root cache. The actual special-encounter rerun then reports `SPX special encounter suite: 0 failures`.
- The missing `GameData` global-class metadata was generated by Godot in an isolated header-only project using the existing source declarations and UID, then copied into the previously absent root class cache. This is metadata bootstrap, not production parser validation. The unchanged actual no-action runtime suite then reports `ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)`. This resolves the earlier `Identifier "GameData" not declared in the current scope` parser errors in no-action/fix-11 dependencies.

Logs: `/private/tmp/pt13-02-shop-rerun.log`, `/private/tmp/pt13-02-inventory-rerun.log`, `/private/tmp/pt13-02-special-rerun.log`, `/private/tmp/pt13-02-emblem-bootstrap.log`, `/private/tmp/pt13-02-class-cache-bootstrap.log`, `/private/tmp/pt13-02-no-action-rerun.log`.

Supplemental Python discovery (`python3 -m unittest discover -s tests -p 'test_*.py' -v`) was **interrupted**, not passed. It reached 1,837 started checks and was stopped in an unrelated RR41 art coverage matrix after the required focused Python checks had passed. Exact terminal result: `KeyboardInterrupt`, exit 130. Log: `/private/tmp/pt13-02-python-full.log`.

## Proof for the design owner

No windowed run was attempted. No PNG capture or pixel inspection is claimed. The `--check-only` probe emits semantic JSON with `captured=false` for every planned image.

Run this exact command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-02 && sh tests/pt13_02_design_owner_proof.sh
```

It runs the windowed command below, with a fresh directory from `mktemp -d /private/tmp/pt13-02-native-proof.XXXXXX`:

```sh
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt13-02 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/intent_chip_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
```

Expected images: `user://probes/pt13-02/{owner,air_pre_battle,air_opening,air_midfight,shadow_warband}_{before,after}_1920x1080.png`, with `semantics.json` alongside. The script prints the absolute directory for the visual runner. Captures are native 1920×1080 at 100% UI scale and inherit production 2D MSAA. Shadow retains its visibility boundary. Pre-battle uses the production preview, and opening/mid-fight show the actual board. The matched pair freezes processing/poses and changes only the proof board's chip-placement implementation.

The 180-second total allowance covers five scene setups with 20-second readiness deadlines; startup watchdog and one-attempt behavior remain intact. The brief does not request another `inspection_fixture.py` command. The design owner retains fixture preparation, renderer inspection and independent UI judging.

## TODO_DESIGN placeholders

None. Production perceivable values come from the brief or remain unchanged.

## Chosen defaults

All new choices are test/proof-only, stored in named constants or fields:

- Seed 83; frozen crawler id 1 at `(4,3)`; hero tile `(5,3)`; interpolated hero feet offset `(32,32)`; freeze count 1; one normal enemy-phase advance for mid-fight. Existing crowd decorations and the 3×4 stress roster are reused.
- Synthetic `TEST_HOME`, `TEST_MIRROR`, `TEST_BOUNDS`; tolerance 0.001 px; 12 warmups and 120 timing samples.
- Non-rendered health-bar stubs: `proof_prop_rect` at home plus `(-32,6)`, size `(64,96)`, terrain HP 5/10; `proof_health_frame` centered at home, size `(80,16)`; `proof_alpha` 0 or 0.5 and `proof_clipped` false/true. These boards never draw replacement artwork. Actual bar dimensions/offsets come from the existing renderer.
- Eight settle frames, 20-second readiness deadline, existing peak-pulse proof clock 0.55 seconds, 180-second total capture allowance and fresh temporary manifest directories. Resolution, UI scale and single-attempt behavior follow the supplied rules.

## Files changed

Production: `scripts/intent_badges.gd`, `scripts/intent_chip_placement.gd`.

Existing test integration: `tests/suites/threats_at_rest_suite.gd`, `tests/suites/board_status_feedback_suite.gd`, `tests/suites/board_hud_group_suite.gd`, `tests/threats_at_rest_test.gd`, `tests/perf/intent_badges_reference.gd`, `tests/windowed_test_allowlist.json`.

New checks/proof: `tests/suites/intent_chip_placement_suite.gd`, `tests/intent_chip_placement_check.gd`, `tests/intent_chip_mutations.py`, `tests/intent_chip_placement_probe.gd`, `tests/intent_chip_placement_proof.json`, `tests/pt13_02_design_owner_proof.sh`.

New fixtures: `tests/fixtures/intent_chip_cases.gd`, `tests/fixtures/intent_chip_proof_board.gd`, `tests/fixtures/pt13_02_before_badges.gd`, `tests/fixtures/pt13_02_before_placement.gd`. Seven new GDScript files include adjacent Godot-generated UID sidecars.

Evidence: this report and `tests/pt13_02_fixture_results.json`. Logs remain in `/private/tmp/pt13-02-*.log` and `/private/tmp/pt13-02-mutations/`.

## Final full-suite result / open issues

Final observed aggregate lines:

```text
FULL SUITE RUNTIME: 805.003 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
```

All 226 child programs completed: 225 passed; `status_plates_performance_probe` failed the unchanged 4000 µs cold-plan guard with `mixed cold/warm plan exceeds 4000 us: 4479/982/346`. That measurement is in the existing status-layout planner; its source/assertion was not changed. Its isolated rerun reports `STATUS MOVEMENT PROBE RESULT: PASS`, with mixed cold maximum 3853 µs and no recorded plan failures. Command: `python3 tools/godot_task_runner.py --task-id pt13-02 --stream -- godot --headless --path . --script tests/status_plates_performance_probe.gd`; log: `/private/tmp/pt13-02-status-performance-rerun.log`. The aggregate full run remains a failure; the isolated pass is not represented as a full-suite pass.

The full-run intent integration separately reports `THREATS AT REST TEST RESULT: PASS (15953 assertions; includes compass suite)` and the same 17.954 px maximum. Its matched cost line is `INTENT CHIP LAYOUT COST: warband_air_3_crowd (6 enemies) median=5.711 ms p95=7.197 ms; before median=7.249 ms p95=8.704 ms`.

Final child report: `/private/tmp/labyrinth-godot-home/pt13-02-1793049673595828000-74282/Library/Application Support/Escape the Umbra Parallel pt13-02-1793049673595828000-74282/program-suites.json`.

Open issues: the full-run status-plan timing guard was not green in aggregate; supplemental full Python discovery is incomplete. Native captures and independent UI judging require the design owner's window-server session. There are no TODO_DESIGN placeholders or unresolved placement-test failures.

Headless semantic output (no PNGs): `/private/tmp/labyrinth-godot-home/pt13-02-1793049674763904000-74290/Library/Application Support/Escape the Umbra Parallel pt13-02-1793049674763904000-74290/probes/pt13-02/semantics.json`. Every planned image in it has `captured=false`.
