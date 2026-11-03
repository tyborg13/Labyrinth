# pt13-02 feedback 1 handoff

Changes are uncommitted on `codex/pt13-02`. This report covers the director's four feedback items. Round-0 results remain historical in `pt13_02_implementation_report.md`. The director accepted the round-0 native before/after captures. No full suite, native capture, peer review or publication was run for this feedback pass.

## Feedback requirements

1. **Live screen HUD reservations:** `IntentBadges.layouts` now includes `HudGroups.screen_reservations(board)` alongside the existing HUD obstacles. The overlap oracle and the iteration-reference implementation use those same live reservations. The bounded solver, home order and 24 px budget are unchanged. The live RunScene regression places the enemy at `(7,7)`, zoom `1.4`, zero pan, in an isolated 1920×1080 SubViewport. It observes hand `(856,761,208,319)` and home chip `(970,759.4673,99,32)`. No clear local position exists: the chip stays at home, distance `0`, with `above_everything=true`. Removing screen reservations is now a third killed mutation.
2. **Visual proof:** the director's round-0 acceptance is retained. The exact command below is re-listed for the changed source; no windowed run was attempted here.
3. **Every capture waits for readiness:** the shared readiness call runs after both setup branches, including pre-battle. Each retry reads the actual `board.combat_state` and checks prepared visible actors. Native mode additionally redraws and checks every visible actor's draw key, retrying if the board state changes. Headless mode checks preparation only. Capture metadata explicitly records `prepared`, `drawn_checked`, and the actual board enemy count; all ten headless states report `prepared=true`, `drawn_checked=false`, `captured=false`.
4. **Clean-checkout mutation driver:** the driver creates its `.godot` scratch parent. With an imported cache it links the existing cache; without one it creates a real empty private import directory and prints an explicit diagnostic. The clean-checkout integration starts without `.godot` or an imported cache and exercises controls, all three mutations and restored controls.

## Focused verification

Godot invocations use `python3 tools/godot_task_runner.py --task-id pt13-02 --stream -- godot --headless --path . --script <script>`. Only the requested focused checks and fixture diagnostics were run.

| Check / script suffix | Observed result | Log |
| --- | --- | --- |
| `tests/intent_chip_placement_check.gd` | `INTENT CHIP PLACEMENT RESULT: PASS (15121 assertions; 0 failures)` | `/private/tmp/pt13-02-fb1-intent.log` |
| `tests/enemy_intent_preview_test.gd` | `ENEMY INTENT PREVIEW TEST RESULT: PASS` | `/private/tmp/pt13-02-fb1-preview.log` |
| `tests/board_status_plates_test.gd` | `BOARD STATUS PLATES TEST RESULT: PASS (33856 assertions; 0 failures)` | `/private/tmp/pt13-02-fb1-hud.log` |
| `tests/threats_at_rest_test.gd` | `THREATS AT REST TEST RESULT: PASS (16015 assertions; includes compass suite)` | `/private/tmp/pt13-02-fb1-threats.log` |
| `tests/intent_chip_placement_check.gd -- --hand-only` | `INTENT CHIP PLACEMENT RESULT: PASS (9 assertions; 0 failures)` | `/private/tmp/pt13-02-fb1-hand.log` |
| `tests/intent_chip_placement_probe.gd -- --check-only` | `INTENT CHIP PROBE RESULT: PASS (10 states; 0 failures; check_only=true)` | `/private/tmp/pt13-02-fb1-probe.log` |
| `tests/perf/hover_equivalence_test.gd` | `PERF04 EQUIVALENCE RESULT: PASS (0 failures)` | `/private/tmp/pt13-02-fb1-hover.log` |
| `python3 tests/intent_chip_mutations.py` | `INTENT CHIP MUTATION RESULT: PASS (3/3 killed; controls pass; exact sources restored)` | `/private/tmp/pt13-02-fb1-mutations.log` |
| Driver loaded against an overlay initially lacking `.godot` | `INTENT CHIP CLEAN CHECKOUT RESULT: PASS (scratch parent created; absent imported cache handled; controls and 3 mutations pass)` | `/private/tmp/pt13-02-fb1-clean-mutations.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.910s` / `OK` | `/private/tmp/pt13-02-fb1-ui-lint.log` |
| `git diff --check` | exit 0 | no output |

All three mutations fail the intended assertions without script errors: `unbounded_search`, `unit_rect_obstacles`, and `screen_reservations`. The source overlay is restored byte-for-byte; the working production source is never mutated.

The 150-state sweep still reports `INTENT CHIP SWEEP: 150 fixtures; maximum distance 17.954 px`. All previous 154 fixture records are unchanged; the live-hand regression adds one chip and one fallback. `pt13_02_fixture_results.json` includes all 155 records and per-fixture zero/nonzero fallback counts: 49 fallbacks total, all at home. Maximum displacement remains `17.9535274505615` px. No nonfallback chip violates the HUD overlap oracle, now including live screen HUD.

The final isolated threats-at-rest run measured the busiest decorated six-visible-enemy Air tier-3 Warband: `INTENT CHIP LAYOUT COST: warband_air_3_crowd (6 enemies) median=4.320 ms p95=4.567 ms; before median=5.602 ms p95=5.910 ms`. Timing uses the existing 12 warmups and 120 matched samples. This measures CPU geometry, not renderer/frame cost. The final fixture cleanup resumes startup callbacks for one second after freezing and checking geometry, then stops audio before freeing the scene; the final hand and threats checks have no resource-leak warning.

Headless readiness metadata (no PNGs): `/private/tmp/labyrinth-godot-home/pt13-02-1793059659175446000-42376/Library/Application Support/Escape the Umbra Parallel pt13-02-1793059659175446000-42376/probes/pt13-02/semantics.json`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-02 && sh tests/pt13_02_design_owner_proof.sh
```

The wrapper creates a fresh `manifest_dir` using `mktemp -d /private/tmp/pt13-02-native-proof.XXXXXX` and runs:

```sh
python3 tools/visual_probe_runner.py tests/intent_chip_placement_probe.gd \
  --task-id pt13-02 --no-headless --display-driver macos --audio-driver Dummy \
  --timeout 180 --attempts 1 --min-images 10 --expect-size 1920x1080 \
  --proof-contract tests/intent_chip_placement_proof.json \
  --result-manifest "$manifest_dir/manifest.json"
```

Expected native images: `user://probes/pt13-02/{owner,air_pre_battle,air_opening,air_midfight,shadow_warband}_{before,after}_1920x1080.png`, plus `semantics.json`. The wrapper prints the resolved capture directory. Resolution remains 1920×1080 at 100% UI scale. No additional `inspection_fixture.py` command was requested by this brief or feedback.

## Files changed

- Runtime: `scripts/intent_badges.gd`.
- Regression/oracle integration: `tests/suites/intent_chip_placement_suite.gd`, `tests/intent_chip_placement_check.gd`, `tests/threats_at_rest_test.gd`, `tests/perf/intent_badges_reference.gd`.
- Probe readiness: `tests/intent_chip_placement_probe.gd`.
- Mutation driver: `tests/intent_chip_mutations.py`.
- Evidence: `tests/pt13_02_fixture_results.json`, this report, and the feedback-report link in `tests/pt13_02_implementation_report.md`.

## TODO_DESIGN placeholders

None. No new perceivable values or assets were introduced.

## Chosen defaults

Test-only constants: `HAND_SETTLE_FRAMES=8`, `HAND_ZOOM_SETTLE_FRAMES=2`, `HAND_CLEANUP_SECONDS=1.0`. The SubViewport copies the existing 1920×1080 fixture size and root MSAA; it updates every frame. The enemy tile `(7,7)`, zoom `1.4` and zero pan come directly from the director's reproduction. Scratch/cache directory names are internal to the driver.

## Open issues

No feedback acceptance check remains failing. Native proof was not rerun because this sandbox has no window server; the requested command is above. The historical full-suite timing failure and incomplete supplemental Python discovery are preserved in the round-0 report and were not rerun under the director's focused-only instruction. Godot still emits the sandbox macOS system-certificate diagnostic at startup; the listed checks complete successfully.
