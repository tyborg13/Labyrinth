# mrg-13 integration result

The worktree contains the uncommitted result of integrating `bb7bf6db9`, `e0b29e0b6`, and `e5d9fc74c` in that order against `codex/release` at `f92582e85`. The worker rules prohibit Git writes. `codex/mrg-13` still points to `f92582e85`, and the index is untouched. The three requested merge commits still need to be created by the design owner.

The specified commits carry the mrg-12 candidate as ancestry, including the card, starter-deck and reward changes, and fx-13 carries the flt-01 and ico-01 dependencies used by its gain floats. The worktree includes that ancestry. The source commits stop at the three requested tips. The [file inventory](/private/tmp/labyrinth_codex/mrg-13/full/changes.txt) lists the 589 integration paths, including the export configuration. This report and `tools/mrg13/pck_check.py` are the two task-local proof files.

## Acceptance criteria

1. `scripts/combat_board_view.gd` keeps `clear_tile_bursts()` followed by shot close on teardown. `_process_board_frame` advances both burst players and the shot player. `_draw_elemental_spell_floor_overlay` keeps the area guard followed by the resolved-shot guard. `tests/approved_asset_pins.json` retains the pins for all 21 shipped sheets and the inherited icon pins. The seven conflicting area pins use fx-12’s radius-31 sheet hashes. Fx-13’s removal of the replaced defense/heal sheet also removes its obsolete pins.
2. All six `export_presets.cfg` presets keep the release include filters and add `data/tile_bursts.json`, `data/self_bursts.json`, and `data/shots.json`. `MRG-13 PRESETS: PASS (6/6, release include filters and all 3 effect catalogues)`.
3. `CombatBoardView` creates the two burst players in board setup and `ShotFx` in effects-layer setup. Map selection and combat state drive them through the normal playback paths. Default headless verification exercised all three without an effect-specific setting or environment variable.

## Other conflict resolutions

- The first merge conflicted in `tests/fixtures/rules_text_lint_baseline.json`. Kept the incoming mrg-12 baseline with 16 existing hits for the merged rules text. Both sides already contained the same lint implementation. The release terminal-wallet, settings and Ward Kite SFX changes carried through the integration.
- The preset edits from fx-13 and fx-14 were combined on top of the release filters. The three catalogues and every atlas were checked byte-for-byte against their approved commits. The area data and bake script retain the fx-12 radius-31 revision.
- No runtime fix beyond the conflict resolutions and export filters.

## Headless verification

| Check | Observed result |
| --- | --- |
| `tools/fx12/verify.gd` | `FX-12 VERIFY: 120 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fx13/verify.gd` | `FX-13 VERIFY: 96 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fx13/verify.gd -- --focused` | Maneuver, Illusion terrain, and combat pacing regression suites. `FX-13 FOCUSED: 3827 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fx14/verify.gd -- --affected` | Umbra action, chain attack and actor presentation suites. `FX-14 DATA: 102 ranged and distant-force action rows` · `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1809 checks, 0 failures)` |
| `tools/fx14/native.gd -- --validate-fixture` | `FX-14 NATIVE FIXTURE: PASS (25 cases, 0 failures)` |
| `tests/burst_rules_test.gd` | `BURST RULES: 130 checks, 0 failures` · `TEST RESULT: PASS` |
| `tests/en05_elemental_test.gd` | `EN05 ELEMENTAL INTEGRATION: PASS (12 checks, 0 failures; neutral, ice, air)` |
| `tests/surface_feedback_ui_test.gd` | `SURFACE FEEDBACK UI TEST RESULT: PASS` |
| `tests/test_rules_text_lint.py` | `Ran 3 tests in 0.122s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| `tests/test_ui_identity_lint.py` | `Ran 25 tests in 7.034s` · `OK` |
| Python default group | `ISOLATION AUDIT: 58 modules` · `SELECTED MODULES: 22 of 58` · `Ran 194 tests in 44.609s` · `OK` |
| Parser checks | `--check-only` exited `0` for `scripts/combat_board_view.gd`, `scripts/run_scene.gd`, and `tests/umbra_action_animation_probe.gd`. |
| Headless Lantern Rain and Brace plans | Both exited `0`. Lantern Rain reported `"bursts":true` at contact frame 177. Brace reported contact frame 22 and completion frame 72. [Lantern Rain take](/private/tmp/labyrinth_codex/mrg-13/plan/area/take.json), [Brace take](/private/tmp/labyrinth_codex/mrg-13/plan/self/take.json). |

The focused scripts ran through `tools/godot_task_runner.py` with task ID `mrg-13`. Logs are in [focused](/private/tmp/labyrinth_codex/mrg-13/focused), and the default Python results are in [summary.json](/private/tmp/labyrinth_codex/mrg-13/python-default/summary.json). No verifier pins or assertions were changed. Fx-12’s final-round list came from its result report. The fx-13 commit carries no result Markdown, so its final verification and focused logs supplied the list. Fx-14’s source report includes the default group, native fixture, Umbra probe parse and the ranged gameplay probe.

The headless import completed with exit `0`. The checked worktree matches the composed file contents on all 589 integration paths. [Import log](/private/tmp/labyrinth_codex/mrg-13/import.log).

## Export proof

`tools/export_game.py --task-id mrg-13 --preset 'Steam macOS'` exited `0` and reported `CEL_PACK_TEST paths=3089 failures=0`. The app used the unchanged production startup scene. A scratch copy used the existing release smoke staging exclusions. [Standalone app](</private/tmp/labyrinth_codex/mrg-13/Escape the Umbra.app>), [export log](/private/tmp/labyrinth_codex/mrg-13/export-release.log).

`tools/mrg13/pck_check.py` mounted the app's production pack and reported `MRG-13 PCK: PASS (3/3 catalogues, 21/21 sheets)`. The checker found `7/7 sheets` for each catalogue and matched every sheet's decoded indices against its approved SHA-256. [Pack](</private/tmp/labyrinth_codex/mrg-13/Escape the Umbra.app/Contents/Resources/Escape the Umbra.pck>), [pack log](/private/tmp/labyrinth_codex/mrg-13/pck-check.log).

The existing macOS release staging smoke loaded `combat_board_view.gd`, `run_scene.gd`, `shot_fx.gd`, and `tile_burst_fx.gd`. The board uses the latter script for both burst players. The release template reported `EXPORT_SMOKE_LOADED scripts=783 scenes=9` and `EXPORT_SMOKE RESULT: PASS (135.70 seconds)`. [Smoke output](/private/tmp/labyrinth_codex/mrg-13/export-smoke.log), [release load log](/private/tmp/labyrinth_codex/mrg-13/export-smoke/launch.log).

## Proof for the design owner

Run these commands with the window server for fresh 1920×1080, 100% UI-scale captures. The existing contracts also validate the strips. `manifest.json` records the image paths for each capture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-13 && mkdir -p /private/tmp/labyrinth_codex/mrg-13/native/area && LABYRINTH_CEL_LOOK=all FX12_CLOCK_FILE=/private/tmp/labyrinth_codex/mrg-13/native/area/clock.avi python3 tools/visual_probe_runner.py --task-id mrg-13 --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx12/movie_clock.sh --timeout 480 --expect-size 1920x1080 --expect-size 3840x480 --proof-contract tools/fx12/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/mrg-13/native/area/manifest.json tools/fx12/native_capture.gd -- --case lantern_rain --out /private/tmp/labyrinth_codex/mrg-13/native/area
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-13 && mkdir -p /private/tmp/labyrinth_codex/mrg-13/native/self && LABYRINTH_CEL_LOOK=all FX13_CLOCK_FILE=/private/tmp/labyrinth_codex/mrg-13/native/self/clock.avi python3 tools/visual_probe_runner.py --task-id mrg-13 --no-headless --display-driver macos --audio-driver Dummy --godot tools/fx13/movie_clock.sh --timeout 480 --expect-size 1920x1080 --expect-size 3840x480 --proof-contract tools/fx13/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/mrg-13/native/self/manifest.json tools/fx13/native_capture.gd -- --case brace --out /private/tmp/labyrinth_codex/mrg-13/native/self
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-13 && mkdir -p /private/tmp/labyrinth_codex/mrg-13/native/shots && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id mrg-13 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --expect-size 3840x480 --proof-contract tools/fx14/native_proof.json --result-manifest /private/tmp/labyrinth_codex/mrg-13/native/shots/manifest.json tools/fx14/native.gd
```

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The task-local pack checker uses a disposable empty Godot project so all assets resolve from the pack. It expects the seven approved sizes per effect catalogue and checks the exact metadata bytes and decoded palette indices.
- The optional renderer commands reuse the approved Lantern Rain and Brace fixtures and the existing 25-case shot fixture. Report output paths are under `/private/tmp/labyrinth_codex/mrg-13/`.

## Open issues

- The ranged gameplay probe reported `ERROR: razor_gale applies its exact damage once` and `PROTAGONIST RANGED GAMEPLAY PROBE: FAIL` on the release base and the integrated worktree. [Base log](/private/tmp/labyrinth_codex/mrg-13/ranged-release-base.log), [integrated log](/private/tmp/labyrinth_codex/mrg-13/focused/ranged-gameplay.log).
- `board_status_plates_test.gd` and `summon_card_play_test.gd` each report `The function signature doesn't match the parent.` Their test hosts have five parameters on `_animate_floating_text_presentation`, while the production method accepts six. Both mismatches already exist at `e0b29e0b6`. The status-plates runner exited `1` despite printing `BOARD STATUS PLATES TEST RESULT: PASS (29413 assertions; 0 failures)`. The summon runner exited `124` with `error: command timed out after 300 seconds.` after the compile failure. [Status plates log](/private/tmp/labyrinth_codex/mrg-13/focused/status-plates.log), [summon-card log](/private/tmp/labyrinth_codex/mrg-13/focused/summon-card.log).
- The Python sidecar test passed against the release index. Checking the intended merge inventory separately reported `Missing tracked Godot sidecars (2)`. The missing paths, `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid`, were already missing at `e0b29e0b6`. The import generated both, and the generated copies are available outside the worktree. [Inventory log](/private/tmp/labyrinth_codex/mrg-13/sidecar-inventory.log), [generated UIDs](/private/tmp/labyrinth_codex/mrg-13/generated-flt01-sidecars).
- Native framebuffer captures and Git integration remain with the design owner.
