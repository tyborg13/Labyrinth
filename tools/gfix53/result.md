# gfix-53 results

## Release and branch receipts

The adapted txt-39 Shadowstep and txt-40 skill witnesses run on either revision. The release run used `codex/release` at `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a`, the prepared worktree HEAD, before any production or test edits.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-53 && python3 tools/godot_task_runner.py --task-id gfix-53 --stream -- godot --headless --path . --script tools/gfix53/witnesses.gd
```

| Requirement | Root cause | Release → working tree |
| --- | --- | --- |
| 2. Shadowstep | The landing search started with an unbounded best distance, so it accepted any visible, legal destination when the nearer tile was occupied. Seeding the comparison with the Shade's starting Manhattan distance requires a strict improvement. | `shadowstep_direction` failed with a hidden Shade at distance 2 Blinking to distance 3. It now stays at (5, 4), distance 2, on beat 1. The eligibility control passed on both revisions. |
| 3. Ghost Stride | Both readiness and the armed action capped the authored Blink range by remaining Movement. They now share the authored Blink action and the Movement pool pays up to its remaining balance. | `ghost_stride` failed with 1 Movement, range 1, and no Blink. It now has range 2 and resolves to (4, 6). Shadow Step leaves the charge armed on both revisions. The permanent test also verifies readiness when only distance-two landings are open and a spend of exactly 1 Movement. |
| 4. Sunpath | The skill reused the endpoint-only Blink placement shared by authored movement riders and relic effects. The skill now uses the same line trace as combat sight and places Light on each passable tile of that trace. | `sunpath` failed on a four-tile Blink with two sources and a dark midpoint. It now places sources at (3, 4), (4, 4), (5, 4), (6, 4) and (7, 4). Three-step walking still places three radius-1 sources, with first and next-turn activation counts of 1 and 2. The permanent test covers a diagonal Blink across a wall. |
| 5. Dawnbrand | All enemy hits passed through the skill modifier. Electrified-only victims have a conduction trace and Chain victims share the actor trace with a positive enemy-hop index. Both paths now skip the modifier in resolution and during Chain displacement forecasting. | `dawnbrand_conduction` and `dawnbrand_chain` each failed with Expose 1 and a spent trigger. Both secondary hits now deal damage with Expose 0 and no activation. The follow-up direct hit applies Expose 1. |

```text
Release       GFIX-53 WITNESSES: 8 checks, 5 failures
Working tree  GFIX-53 WITNESSES: 8 checks, 0 failures
```

[Release Godot log](/private/tmp/labyrinth-godot-home/gfix-53-1795538527514805000-67362/godot.log) · [Working-tree Godot log](/private/tmp/labyrinth-godot-home/gfix-53-1795538706345470000-69902/godot.log)

Cinderburst from an empty center hit a previously lit enemy on both revisions. The hit applied Expose 0 and generated zero Dawnbrand events, and the same-turn Arc Flash follow-up applied Expose 1. Dawnbrand's authored action types are melee, ranged, push and pull.

Neutral card scores use the no-skill reference profile and the card definitions are identical. The existing Light and battlefield event paths record the revised sources and destinations. The Movement event reports 1 Movement paid and retains the two-tile travel in its origin and destination.

## Changed rules copy

- `data/glossary.json` (`shadowstep`) — `On each Shadowstep beat, each hidden enemy Blinks toward you if there is room.`
- `data/battlefield_rules.json` (`last_lamplighter`) — `On each Shadowstep beat, after your turn, each hidden Wick Shade Blinks 1 tile toward you if there is room.`
- `data/skills.json` (`ghost_stride`) and `data/glossary.json` (`skill_ghost_stride`) — `Once per combat, activate to turn your next free Movement into @icon(blink) 2.`

The current Grimoire catalog has no Ghost Stride entry. The active copy fixtures are `tests/fixtures/txt20_battlefield_copy.json` and `tests/fixtures/txt20_rules_copy.json`. Ghost Stride is pinned by `skill_tree_suite.gd` and the glossary checks. Last Lamplighter is pinned by `battlefield_rules_suite.gd` and `guardian_rules_suite.gd`. The Python default group's copy checks include `test_short_card_tooltips` and `test_text_budget`.

## Headless verification

```text
GFIX-53 battlefield_rules_suite.gd: 635 checks, 0 failures
GFIX-53 guardian_rules_suite.gd: 543 checks, 0 failures
GFIX-53 last_light_suite.gd: 238 checks, 0 failures
GFIX-53 player_movement_suite.gd: 37 checks, 0 failures
GFIX-53 movement_undo_suite.gd: 51 checks, 0 failures
GFIX-53 skill_combat_suite.gd: 126 checks, 0 failures
GFIX-53 skill_tree_suite.gd: 387 checks, 0 failures
GFIX-53 radiance_package_suite.gd: 51 checks, 0 failures
GFIX-53 fix_03_suite.gd: 106 checks, 0 failures
GFIX-53 FOCUSED: 2174 checks, 0 failures
SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)
```

`tools/gfix53/focused.gd` and `tests/short_card_tooltips_test.gd` were run through the task-local Godot runner with `--headless`. [Focused suites log](/private/tmp/labyrinth-godot-home/gfix-53-1795538696636843000-69866/godot.log) · [Tooltip test log](/private/tmp/labyrinth-godot-home/gfix-53-1795538706353042000-69904/godot.log)

`python3 tests/test_rules_text_lint.py` reported `Ran 3 tests`, `FAILED (failures=1)`, and `FAIL: Rules text lint (2 new hits)`. The linter flags standalone `it` without checking for a noun earlier in that sentence. Both hits come from the exact director-approved Shadowstep sentences above.

`python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/gfix-53-python-default` selected the 23 default modules and reported `Ran 196 tests in 48.500s` and `FAILED (failures=2)`. The failures were the lint case above and `GodotTaskRunnerTests.test_killing_runner_mid_godot_test_leaves_no_godot_child` (`AssertionError: False is not true : Child did not start`). The run also reported that updating the shared timing cache was denied by the sandbox. [Python suite summary](/private/tmp/labyrinth_codex/gfix-53-python-default/summary.json)

An isolated retry of the runner test via `python3 -m unittest discover -s tests -p test_godot_task_runner.py -k test_killing_runner_mid_godot_test_leaves_no_godot_child` reported `Ran 1 test in 2.845s` and `OK`.

## Native proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-53 && tools/gfix53/native.sh
```

The script sets `LABYRINTH_CEL_LOOK=all`, drives the production combat scene and validates each 1920×1080 capture at 100% UI scale. It prints one absolute PNG path per line. The expected paths relative to the runner's isolated `user://` are:

- `gfix53/01_shadowstep_stayed.png` — Last Lamplighter's beat resolved with the hidden Wick Shade at (5, 4). The fixture casts Light after the beat so the screenshot shows the Shade still at that tile.
- `gfix53/02_ghost_stride_blink_2.png` — armed Ghost Stride, 1/2 Movement, and marked distance-two landing.
- `gfix53/03_sunpath_lit_line.png` — the three-tile Blink landed at (6, 4), with sources on all four tiles from origin to landing.

The headless dry run `tools/gfix53/native.sh --dry-run` reported `GFIX-53 NATIVE DRY RUN: 3 combat cases, 1920x1080, UI scale 100%, 0 failures` and exited 0. Godot logged a RunScene resource still in use at shutdown. Windowed captures remain pending. [Native dry-run log](/private/tmp/labyrinth-godot-home/gfix-53-1795539006214753000-73551/godot.log)

## Chosen defaults

The witnesses use fixed seed 73021, a 9×9 test grid, fixture actor positions, test Health and a test illusion to block the closer Shade landing. The native probe uses a level-3 test profile with tutorial dismissed, three settling frames, the Deep Umbra stage to show the Sunpath trail, isolated proof saves and the existing board framing. All apply only to verification.

## Open items

The approved Shadowstep copy requires the text-lint owner to reconcile the pronoun check with the same-sentence antecedent rule. No `TODO_DESIGN_*` placeholders. Changes are uncommitted for the design owner.
