# pol-83 result

Implemented in the `codex/pol-83` worktree at base `e3b27e209`. Changes are uncommitted.

The brief’s risk tier is low-medium. Inspection covers the four native hovers listed below.

## Acceptance

1. `UiTooltipPanel.make_plain_text` trims the input and sends a single line ending in `.`, `!` or `?` to the existing body renderer. It uses the shared panel factory, including its margins and width rules. The focused check verifies exact text, color, font size, title absence and inline icon rendering.
2. [CHANGED.md](CHANGED.md) lists the affected inputs by screen, including card chip hovers and every authored creature’s move rows. It identifies the one-line inputs that still read like sentences and the copy variants that interpolate live values.
3. The focused check verifies the uppercase title of a bare label, the unchanged title and body of a two-line panel, and an explicitly supplied title ending in punctuation. The tooltip consistency and loop suites pass. No passing old-cap assertion needed an update. The historical `mrk01_marked_probe.gd --cap07-only` uses `tests/helpers/txt08_combat_proof.gd::contains_tooltip_line` to look for uppercase Fade copy. The probe already fails on the base because its expected Fade and Barrage copy is stale. Its assertions were left as authored under the existing-failure rule.

## Headless results

Godot commands below ran as `python3 tools/godot_task_runner.py --task-id pol-83 --stream -- godot --headless --path . --script <script>`. The program logs also emit the sandbox’s macOS CA-certificate diagnostic.

| Check | Observed result |
| --- | --- |
| `tools/pol83/check.gd` | `POL83 PLAIN TOOLTIP: 33 checks, 0 failed` and `TOOLTIP CONSISTENCY: 69 checks, 0 failed` |
| `tests/board_tile_tooltip_test.gd` | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| `tests/board_tile_tooltip_route_test.gd` | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| `tests/board_tile_tooltip_live_test.gd` | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| `tests/petrify_tooltip_test.gd` | `STAGGER BADGE/TURN-ORDER TEST RESULT: PASS` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| `tools/tooltip_loops/tip12_checks.gd` | `TIP12 TOOLTIP SEMANTICS RESULT: PASS (0 failures)` |
| `tests/mrk01_marked_probe.gd -- --check-only --cap07-only` | `TXT08 ENEMY TOOLTIP PROBE: FAIL (2 captures or headless witnesses)` on base and patched runs, with the same six failed assertions and two fight witnesses |
| `tools/crd33/dump_cards.gd` | `CRD32 EXPORT: 309 catalog IDs; 9 source lists` |
| `tools/pol83/enemy_inventory.gd` | `POL83 ENEMY INVENTORY: 44 enemy IDs, 137 moves` |
| `tools/pol83/native.sh --dry-run` | `POL83 HEADLESS PROBE: PASS (4/4 hovers)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.839s` and `OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.040s`, `OK` and `PASS: Rules text lint (16 existing hits)` |
| `LABYRINTH_TASK_ID=pol-83 python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/pol-83/python-default` | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.367s` and `OK` |

Inventory exports, suite logs and the Python group summary are under `/private/tmp/labyrinth_codex/pol-83/`. The Python runner’s optional timing-cache write was denied by the read-only Git metadata sandbox after all tests passed. The full Godot suite was outside this round’s proof scope.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-83 && tools/pol83/native.sh
```

The command sets `LABYRINTH_CEL_LOOK=all` and runs the 1920×1080 probe at 100% UI scale. The probe uses the normal combat camera, the controls’ native hover hit regions and Godot’s embedded popups. If a popup contains a loop, capture waits for a decoded frame at full opacity.

The headless proof log is `/private/tmp/labyrinth_codex/pol-83/headless.6EzdIw/probe.log`. Native output is written to `/private/tmp/labyrinth_codex/pol-83/native.*/` with `captures.json` and these four images.

| Expected image | Observed in the headless popup |
| --- | --- |
| `craghide_groundsplit_1920x1080.png` | Body `This enemy hits each floor tile within the shown distance of a surviving Outcrop.` |
| `warden_bulwark_1920x1080.png` | Body `Grants Block to every other living enemy.` |
| `hoarder_battlefield_rule_1920x1080.png` | Body `The Hoarder slips away with its hoard after your 4th turn.` |
| `menu_title_1920x1080.png` | Title `MENU` |

The referenced txt-43 images were inspected. The current base uses its earlier Groundsplit chip and tooltip copy. The probe follows that live chip. Windowed capture and image inspection remain with the design owner because this sandbox has no window-server access.

## Chosen defaults

- The second enemy witness is Warden’s Bulwark, the HUD witness is the existing tier-2 fire Ember Hoarder fixture, and the title witness is Menu. Craghide reuses the txt-43 witness positions with one surviving 1-Health Outcrop.
- The probe uses the shared pre-battle fixture’s 0.35-second settle, a 3 px hit-test step, a 6-second popup deadline and a pointer reset at `(1, 1)`. Proof output uses per-run directories under `/private/tmp/labyrinth_codex/pol-83/`.

## Open issues

- No `TODO_DESIGN` placeholders were needed.
- The worktree helper reports an empty task contract despite the supplied owner workflow. Acceptance and proof are recorded here.
- The historical Fade and Barrage probe fails on the base as detailed above. Native captures are pending.
