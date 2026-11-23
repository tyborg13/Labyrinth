# txt-30 implementation and proof

Implemented in the working tree on `codex/txt-30`, starting from the owner’s copy commit `db959f6b0`. The changes are uncommitted.

## Acceptance criteria

| # | Result | Evidence |
| --- | --- | --- |
| 1 | Scout shows “Resolve the current room first.” when mode blocks Scout. The target message appears when a permitted mode has zero eligible targets. | The Scout witness tests the three permitted modes, the open Hearth and other blocked modes, exhausted uses, section history and zero targets. Linger unlocks Scout with one target on the same Hearth tile. [Witness source](probe.gd) |
| 2 | Revealed legacy combat rooms use the existing pre-battle sentence for their objective. The shared Combat legend lists the distinct sentences for revealed combat rooms in the viewed section. Current maps retain “Defeat each enemy.” | The witness compares the map room and legend against the rendered pre-battle tooltip on a revision 4 map. It covers the opener, Defeat All, Defeat the Leader and Reach the Exit. The leader outcome is victory with a living follower. Candidate 4 stays on Defeat All. [Map code](../../scripts/section_map_panel.gd) |
| 3 | The foe hint and NEW tag are 14 px. NEW is centred in a 58×20 tag at the existing right edge. | The production controls reported their sizes and fit at 1920×1080 and 1280×800. The turn-order projection chip retains its approved 12 px. [Capture source](capture.gd) |
| 4 | The compact Lodestone stack clears the top and bottom edges by at least 8 px. | At 1280×800 it moved from `[P: (787.12, -11.0), S: (306.0, 793.0)]` to `[P: (787.12, 11.0), S: (306.0, 781.0)]`. The 1920×1080 bounds stayed `[P: (1107.12, 269.0), S: (306.0, 793.0)]`. The compact stack needed 9 more px than placement alone could provide. The existing whole-pixel gaps tightened enough to recover 12 px, preserving the panels and their text. [Stack code](../../scripts/card_focus_tooltip_stack.gd) |
| 5 | The Grimoire Ground Techniques article uses the approved Frost Circuit rider. All four production hand faces, reward cards, Scavenger detail cards and Grimoire previews were checked against the approved card data. | Serrated Slip draws one plus sign, Frost Circuit draws the new rider, Worldroot Stride uses “on your tile,” and Vortex keeps its area diagram. Rules inspections use the new sentences and rendered text contains no raw markup. The orphan audit still reports seven runtime-substituted keys. [Grimoire data](../../data/grimoire.json) |

The other two adapted truth witnesses observed 12 Health while the Deferred Choice picker was open and 15 after resolution. The new run placed the 37 lost Embers in the advertised Section I on a different map. The combat objectives suite checked the approved “Leader hidden” caption.

## Checks run

Logs are in `/private/tmp/labyrinth_codex/txt-30`.

| Check | Exact result |
| --- | --- |
| `tools/txt30/probe.gd` | `TXT30 WITNESSES: 4 true, 0 failed` |
| Native dry run, before 1920×1080 | `TXT30 DRY RUN before 1920x1080: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)` |
| Native dry run, before 1280×800 | `TXT30 DRY RUN before 1280x800: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)` |
| Native dry run, after 1920×1080 | `TXT30 DRY RUN after 1920x1080: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)` |
| Native dry run, after 1280×800 | `TXT30 DRY RUN after 1280x800: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)` |
| `tests/section_map_v2_test.gd -- --map-part-0` | `Section map v2 suite: 0 failures (seeds 0..32 x 6 sections)` |
| `tests/int11_integration_test.gd` | `INT11 INTEGRATION: PASS (407 checks; 0 failures)` |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16745 checks, 0 failures)` |
| `tests/card_summary_fit_unit_test.gd` | `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` |
| `tests/pre_battle_view_test.gd` | `PRE-BATTLE VIEW TEST: PASS`, `TEST RESULT: PASS` |
| `tests/new_descent_probe.gd -- --validate-only` | `New Descent headless probe validation: 0 failures` |
| `tests/run_end_recap_tests.gd` | `RUN END RECAP TEST RESULT: PASS` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.070s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.338s`, `OK` |
| `python3 tools/txt30/orphan_patterns.py .` | `37 keys, 7 orphaned` |
| Typed-array audit, limited to added lines in changed scripts | `TYPED ARRAY AUDIT: 12 changed scripts; 0 new review candidates` |
| Python default group, `--shards 4 --changed-since HEAD` | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 48.426s`, `OK` |

The engine checks ran through `tools/godot_task_runner.py --task-id txt-30`. No full merge suite or peer review was part of the implementation run.

## Proof for the design owner

Run the native capture script on the Mac window server from the worktree. It compares the candidate-4 production files in the sibling `txt-29` worktree with the working copy of `txt-30`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-30 && /private/tmp/labyrinth_codex/txt-30/native.sh
```

The script prints its new `native.*` output directory. Each of `before-1920x1080/` and `after-1920x1080/` contains `serrated_slip_face.png`, `frost_circuit_face.png`, `vortex_inspection.png`, `worldroot_stride_inspection.png`, `pre_battle.png` and `new_run.png`. Each of `before-1280x800/` and `after-1280x800/` contains `lodestone_reversal_inspection.png`. The visual runner validates each size and records a `manifest.json` per folder. The screenshots come from exact-size SubViewports at 100% UI scale with `LABYRINTH_CEL_LOOK=all`. [Native script](native.sh) · [1920×1080 contract](full.contract.json) · [1280×800 contract](compact.contract.json)

The headless dry run printed `/private/tmp/labyrinth_codex/txt-30/native.OKtXge`. Its four subfolders contain no PNGs. [Dry-run log](</private/tmp/labyrinth_codex/txt-30/native-dry.log>) · [Truth witness log](</private/tmp/labyrinth_codex/txt-30/witness.log>)

## TODO_DESIGN placeholders

`TODO_DESIGN_legacy_objective_<type>` is the fallback for a legacy objective whose pre-battle sentence is missing. Every exercised objective has an existing sentence.

## Chosen defaults

- Truth fixtures reuse seeds 29 and 30, a revision 4 compatibility map, 37 lost Embers, 1 surviving follower Health, and a Shatterline reward at 12/26 Health.
- Capture fixtures use seed 501, room (1,0), a 10×9 board, hero (2,4) at 24 Health and crawler (4,4) at 40 Health. The hand holds the card under inspection with Quick Stab in the draw pile.
- The New Run capture selects Depth 3. The inspection fixture places the exact-rules popover at (24,144) on layer 300. The probes settle for five frames and allow up to 600 frames for staged UI. They retain runner timeouts.

## Open issues

- Native rendering and visual inspection are pending on the design owner’s window server.
- The gap adjustment preserves the top margin when the viewport is shorter than the panels’ combined minimum height plus both margins. Fitting such a viewport on both edges would require changing the panel layout itself.
- Headless logs on both branches contain a macOS certificate diagnostic and missing cached strike and burst textures. Some existing focused probes reported resources still in use at exit. The listed checks exited successfully. The Python timing cache could not be updated in the read-only shared Git directory.
