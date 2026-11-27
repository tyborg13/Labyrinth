# tut-02 round 1 implementation and proof

## Requirements

1. The pointer is evaluated at the first settled player-turn presentation for each combat and turn. It requires an effective non-clear Umbra, a living enemy concealed by it, and a completed profile without `umbra_read`. Active, dismissed, and legacy-exempt profiles, debug and inspection runs, enemy turns, and the animation lock all suppress it. Ordinary refreshes preserve the turn-start decision.
2. The existing card spotlights the printed text of the HUD label. Its title comes from the label and both input modes use the approved sentences shared with the label's tooltip. The definition includes an empty icon, `UMBRA`, and the floor-loot Continue configuration. It omits `lesson` and `lesson_total`, which hides the whole progress row. `hide_skip` hides Skip. The HUD's embedded popup opened through real hover input while the card stayed visible. The previous and current floor-loot node trees matched across all 34 controls.
3. The accepted truth witness remains in [witness.gd](witness.gd). It passed again in the first Fringe fight generated for seed `90211`, after a legal walk from `(1, 4)` to `(1, 3)`.
4. Continue uses the floor-loot milestone commit path to write `umbra_read` into both the profile tutorial state and the run save. Completion normalization supplies the original guided milestones and preserves the Umbra receipt only when present. A pre-Continue checkpoint reopened the pointer. A later fight, a new run, and guide replay preserved the acknowledgement after Continue. The existing `_test_save_and_load_round_trip()` covers the tutorial state format. [Save test](../../tests/contextual_combat_tutorial_test.gd#L217)
5. Continue writes one `guided_tutorial_step_completed` receipt with `phase_id` `umbra` and `milestone_id` `umbra_read`. The existing event fields and guided milestone counts for the original lessons are preserved. [Analytics specification](../../spec/analytics.md#L431)

## Changed files and functions

| File | Functions and lines |
| --- | --- |
| [contextual_combat_prompt.gd](../../scripts/contextual_combat_prompt.gd#L50) | `_progress_row` (50), `configure()` (83–130), `_build()` progress row (393–409) |
| [contextual_combat_tutorial.gd](../../scripts/contextual_combat_tutorial.gd#L423) | Authored definition (423–429), `normalized_state()` (435–460), `guided_milestone_count()`, `complete_milestone()` and `complete_tutorial()` (480–517), replay and merge helpers (531–579), `phase_definition()` (581–605), milestone and compatibility lookups (610–638, 653–659) |
| [run_scene.gd](../../scripts/run_scene.gd#L10026) | Prompt refresh and reconciliation (7791–7893), phase and spotlight (7966–7999, 8067–8133), action gate and Continue (8303–8308, 8374–8409), milestone persistence and dismissal analytics (8421–8453, 8476–8500), load reset (9574–9577), turn-start hook and `_maybe_queue_umbra_tutorial()` (10026, 10034–10069), tooltip copy sharing (13764–13791) |
| [contextual_combat_tutorial_test.gd](../../tests/contextual_combat_tutorial_test.gd#L39) and [analytics.md](../../spec/analytics.md#L443) | Four milestone-list expectations and the new analytics IDs |
| [floor_loot_tree.gd](floor_loot_tree.gd) | `_compare()` (12–39) and `_snapshot()` (41–59) |
| [run_fixture.gd](run_fixture.gd) | `first_umbra()` (12–25), `later_umbra()` and generated route helpers (27–71) |
| [proof.gd](proof.gd) | Setup and checkpoint mounting (17–75), layout and copy assertions (77–102), trigger, controls and analytics (104–194), native sequence (196–226) |
| [native.sh](native.sh) and [proof_contract.json](proof_contract.json) | Native runner and three required 1920×1080 images |
| [witness.gd](witness.gd), `.gd.uid` sidecars, and [result.md](result.md) | Accepted truth witness, four Godot resource IDs, and this report |

## Truth witness

```text
TUT-02 COUNTER WITNESS: omitted lesson fields, visible=false, text=GUIDED RUN • 1/1
TUT-02 TRUTH 1: "Tiles outside your sight or a Light source are obscured." tile=(5, 6) distance=7 personal_radius=6 light_sources=1 obscured=true
TUT-02 TRUTH 2: "Hidden enemies cannot be targeted and show no intents." enemy=roc_fledgling hidden=true card=Skybolt targetable=false intent=circle displayed=false
TUT-02 TRUTH 3: "Vision shows hidden enemies." card=Prism Sight visible=true targetable=true tile_still_dark=true
TUT-02 UMBRA TRUTH WITNESS: PASS
```

## Trigger and controls

```text
TUT-02 POINTER: title=Fringe Umbra spotlight=[[P: (10.0, 74.0), S: (121.0, 21.0)]] card=[P: (24.0, 431.0), S: (430.0, 218.0)]
TUT-02 FIRST UMBRA: seed=90212 room=(2, 1) turn=1 first=visible animation_locked=hidden
TUT-02 SAVE/RELOAD: before=unread restored=visible
TUT-02 CONTINUE: controller=accepted profile=stored run=stored card=closed
TUT-02 REPLAY: guided_steps=0 umbra_read=true
TUT-02 LATER FIGHT: room=(-1, -2) visible=false
TUT-02 NEW RUN: index=2 visible=false
TUT-02 CONTROL: dismissed visible=false
TUT-02 CONTROL: legacy_exempt visible=false
TUT-02 CONTROL: active visible=false
TUT-02 CONTROL: debug_boss_run visible=false
TUT-02 CONTROL: inspection_fixture visible=false
TUT-02 CONTROL: enemy_turn visible=false
TUT-02 CONTROL: no_hidden_enemies visible=false
TUT-02 TURN BOUNDARY: mid_turn=hidden next_turn=visible
TUT-02 ANALYTICS: guided_tutorial_step_completed {"completed_step_count":16.0,"milestone_id":"umbra_read","phase_id":"umbra","tutorial_version":2.0}
TUT-02 TRIGGER WITNESS: PASS
```

## Test and probe receipts

| Check | Result |
| --- | --- |
| Floor-loot nodes | `TUT-02 FLOOR LOOT TREE: MATCH (34 controls, SHA-256 e2595d53fe2a04bc54e9bebd8978b6b1dff3abe10d152c984f4ff4724af4efe5)` |
| `tests/contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| `tests/guided_combat_tutorial_integration_test.gd` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` |
| Python default group | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 29.696s` · `OK` |
| `tests/test_rules_text_lint.py` in the default group | `PASS: Rules text lint (16 existing hits)` |
| `tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.302s` · `OK` |
| `tools/tut02/native.sh --dry-run` | `TUT-02 CAPTURE STATES: pointer=visible hover=visible after_continue=hidden same_turn=true` · `TUT-02 NATIVE DRY RUN: PASS` |

The two floor-loot snapshots are `.godot/tut02/floor_loot/before.json` and `.godot/tut02/floor_loot/after.json`. They are byte-identical and include node order, classes, visibility, geometry, spacing, text, fonts, and colors. The `before.json` snapshot was taken before the card edits using `floor_loot_tree.gd -- --record-before`.

Godot receipts are `godot.log` in these directories under `/private/tmp/labyrinth-godot-home/`.

- Truth witness `tut-02-1795785280444847000-7706`
- Floor-loot before `tut-02-1795784896621621000-5534` and after `tut-02-1795785097681781000-7320`
- Trigger `tut-02-1795785445371853000-8033` and native dry run `tut-02-1795785445389645000-8034`
- Catalog and save `tut-02-1795785445371860000-8032` and integration `tut-02-1795785445379528000-8035`

The successful Godot processes also logged a macOS system CA certificate diagnostic. Python receipts are in `/private/tmp/labyrinth_codex/tut02-round1-python.Su6Xzz/`. The untracked timing-cache write under the read-only Git metadata was denied after the Python checks passed.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-02 && tools/tut02/native.sh
```

The wrapper selects `LABYRINTH_CEL_LOOK=all` and the windowed visual probe runner. It prints each PNG path on its own line. Planned output is at `.godot/tut02/native/` with a manifest beside the captures.

- `01_umbra_pointer.png` shows the first qualifying turn with the card spotlighting the Umbra text.
- `02_after_continue.png` shows the same turn after clicking Continue.
- `03_umbra_hover.png` shows the real HUD popup open alongside the card.

Reproduce the independent headless checks with these commands.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-02 && python3 tools/godot_task_runner.py --task-id tut-02 --stream -- godot --headless --path . --script tools/tut02/witness.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-02 && python3 tools/godot_task_runner.py --task-id tut-02 --stream -- godot --headless --path . --script tools/tut02/proof.gd -- --trigger
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-02 && tools/tut02/native.sh --dry-run
```

## Chosen defaults and open issues

- Trigger and native proof use the named seed `90212`, route `(1, 0) → (-1, 0) → (2, 1)`, and a five-room bound for finding a later concealed fight. Preceding fights use a fixture victory followed by normal reward and traversal methods. The captured fight is generated by the ordinary room and pre-battle engines with its original enemies, positions, and opening hand.
- The no-concealment control uses one Vision activation. The floor-loot tree lets five frames settle. The native wrapper uses a 60-second runner timeout and the shared embedded-popup witness.
- Truth proof retains seed `90211`, the eight-room bound, and the card choices Glowstone Ward, Skybolt, and Prism Sight.
- No `TODO_DESIGN_` placeholders. The issued native command and visual judgment remain for the design owner because the worker has no window-server access. All changes are uncommitted.
