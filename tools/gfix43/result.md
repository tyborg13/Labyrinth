# gfix-43 release proof repair

## Acceptance and findings

1. Reproduced the listed failures in separate headless commands at `e2cca11a1` on `codex/gfix-43`. The base already contains gfix-42 (`ebc635e11`).
2. Traced each failure to a stale fixture, an outdated exact-copy expectation, or an outdated test double. The release-gate commands all pass after the targeted updates.
3. Changed six existing proof and test files. The worktree is uncommitted. The risk tier is low because the changes are confined to tests and proof tooling.

### Split forecast

The original `death_spawn` fixture expected the Ooze’s own melee activation to kill it through Bleed. `pla-07` (`4aa73ad65`) removed the resolver that charged Bleed before the action. The Ooze therefore survived, so the fixture made no split enemies available to forecast. This commit removed the old death trigger. The split scheduling code still queues the Droplets during the enemy turn.

The updated fixture places Fire beneath an Ooze at 1 Health. Fire kills it at the start of its activation and the resulting Droplets can act within the already booked Pass interval. The same three ATK04 assertions now pass, including the turn-clock `?` row, the absence of an Umbra row and the line “A new enemy acts before you.” Before the repair, both broader forecast checks reported `CASE death_spawn: forecast_hp=11 actual_hp=11 loss=13 uncertain=false`. Afterward, both reported `CASE death_spawn: forecast_hp=24 actual_hp=15 loss=0 uncertain=true`. Their known-loss path executes two fewer checks because the fixture now exercises the existing uncertainty path.

### Exact pins and analytics

- `txt-20` (`2d766d929`) supplied both Splits sentences in `scripts/enemy_mechanics/split_trait_text.gd:17` and `data/glossary.json:63`.
- `txt-27` (`4bbaa6790`) supplied the five battlefield sentences in `data/battlefield_rules.json`. Both Warband commands call `tests/suites/element_retrofit_suite.gd:47` at each of three tiers. The Guardian suite reads the same exact-copy fixture. In BOS01, the Continue path refreshes the Roc’s saved sentence from authored data, as added by `35b683909` (`scripts/battlefield_rules/dispatcher.gd:71`). Updating the synthetic starting sentence makes the existing HUD equality check meaningful again.
- `pol-63` (`8203c39bd`, `scripts/combat_objective_rules.gd:274`) standardized the HUD and Pre-Battle title to the dragon’s short name or the Guardian’s full name with “the”. The test still compares the entire rendered heading.
- `fnd-02` (`c1beae85d`, `scripts/run_scene.gd:28680`) added the optional `launch_burst: Callable` argument. The analytics override matches the parent and the suite finishes with zero failures.

## Assertion ledger

| Failing check location | Exact failure output | Class | Commit and unit | Change | Before → after result |
| --- | --- | --- | --- | --- | --- |
| `tools/atk04/focused_tests.gd:61` | `FAIL: death_spawn: a visible new foe is flagged as new and still unknown` | Stale fixture | `4aa73ad65` (pla-07) | `tools/ptf07/forecast_cases.gd:177` uses lethal turn-start Fire to trigger the split. | `ATK04 FOCUSED RESULT: FAIL (982 assertions, 3 failures)` → `ATK04 FOCUSED RESULT: PASS (982 assertions, 0 failures)` |
| `tools/atk04/focused_tests.gd:62` | `FAIL: death_spawn: the turn-clock '?' row, not the Umbra row: time:+10`<br>`health:−13` | Stale fixture | `4aa73ad65` (pla-07) | `tools/ptf07/forecast_cases.gd:177` uses lethal turn-start Fire to trigger the split. | `ATK04 FOCUSED RESULT: FAIL (982 assertions, 3 failures)` → `ATK04 FOCUSED RESULT: PASS (982 assertions, 0 failures)` |
| `tools/atk04/focused_tests.gd:63` | `FAIL: death_spawn: new-foe line only: Ending now leaves 2 card plays unused: +10 Time.`<br>`Before your next turn: −13 Health` | Stale fixture | `4aa73ad65` (pla-07) | `tools/ptf07/forecast_cases.gd:177` uses lethal turn-start Fire to trigger the split. | `ATK04 FOCUSED RESULT: FAIL (982 assertions, 3 failures)` → `ATK04 FOCUSED RESULT: PASS (982 assertions, 0 failures)` |
| `tools/spl01/capture.gd:55` | `ERROR: Exact contextual rules and pluralised data name` | Stale pin | `2d766d929` (txt-20) | `tools/spl01/capture.gd:55` pins the approved contextual sentence with the plural child name. | `SPL01 SEMANTICS: FAIL (17 checks, 2 failures)` → `SPL01 SEMANTICS: PASS (17 checks, 0 failures)` |
| `tools/spl01/capture.gd:57` | `ERROR: Exact glossary definition` | Stale pin | `2d766d929` (txt-20) | `tools/spl01/capture.gd:57` pins the approved static adjacent-tile definition. | `SPL01 SEMANTICS: FAIL (17 checks, 2 failures)` → `SPL01 SEMANTICS: PASS (17 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_orders_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` → `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: fire` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:6` pins the Slagmaster-to-player direction. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: lightning` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:12` pins Arc Lash. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 1)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 2)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/element_retrofit_test.gd (tier 3)` | `ERROR: Warband exact panel sentence: shadow` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:18` pins the maximum Blink distance. | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` → `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: tharokh` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: vyraketh` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: vaeloryx` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: iskaldra` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: noctyrax` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: zekarion` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the dragon’s short name. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: ashen_reaver` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: rimejaw` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: storm_cantor` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: gallows_roc` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: craghide` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/suites/pre_battle_living_foes_suite.gd:90` | `ERROR: Named objective keeps its authored title: last_lamplighter` | Stale pin | `8203c39bd` (pol-63) | `tests/suites/pre_battle_living_foes_suite.gd:88` pins the exact heading with the Guardian’s name and article. | `PRE-BATTLE SEMANTICS TEST: FAIL` → `PRE-BATTLE SEMANTICS TEST: PASS` |
| `tests/bos01_rule_scene_test.gd:25` | `ERROR: BOS01 real HUD uses instance sentence` | Stale fixture | `4bbaa6790` and `35b683909` (txt-27) | `tests/fixtures/bos01_rule_fights.gd:13` uses the approved Roc sentence before the Continue load. | `BOS01 RULE SCENE RESULT: FAIL (170 checks, 1 failures)` → `BOS01 RULE SCENE RESULT: PASS (170 checks, 0 failures)` |
| `tests/suites/guardian_rules_suite.gd:42` | `ERROR: ashen_reaver pinned acceptance sentence` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:45` pins the Reaver-to-player direction. | `GUARDIAN RULES TEST RESULT: FAIL (693 checks, 2 failures)` → `GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)` |
| `tests/suites/guardian_rules_suite.gd:42` | `ERROR: gallows_roc pinned acceptance sentence` | Stale pin | `4bbaa6790` (txt-27) | `tests/fixtures/txt20_battlefield_copy.json:54` pins the player-to-Roc direction. | `GUARDIAN RULES TEST RESULT: FAIL (693 checks, 2 failures)` → `GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)` |
| `tests/suites/analytics_contract_suite.gd:46` | `SCRIPT ERROR: Parse Error: The function signature doesn't match the parent. Parent signature is "_animate_relic_acquisition_flourish(String, Rect2, Color, Control = <default>, Callable = <default>) -> void".` | Stale test double | `c1beae85d` (fnd-02) | `tests/suites/analytics_contract_suite.gd:46` matches the parent’s optional Callable. | `SCRIPT ERROR: Parse Error: The function signature doesn't match the parent. Parent signature is "_animate_relic_acquisition_flourish(String, Rect2, Color, Control = <default>, Callable = <default>) -> void".` → `ENCOUNTER ANALYTICS: PASS (0 failures)` |
| `tests/encounter_analytics_test.gd:170` | `SCRIPT ERROR: Invalid call. Nonexistent function 'run' in base 'GDScript'.` | Consequence of stale test double | `c1beae85d` (fnd-02) | `tests/suites/analytics_contract_suite.gd:46` matches the parent’s optional Callable. | `SCRIPT ERROR: Invalid call. Nonexistent function 'run' in base 'GDScript'.` → `ENCOUNTER ANALYTICS: PASS (0 failures)` |
| `tools/ptf07/forecast_cases.gd:73` | `FAIL: death_spawn: unavailable intent flagged` | Stale fixture | `4aa73ad65` (pla-07) | `tools/ptf07/forecast_cases.gd:177` uses lethal turn-start Fire to trigger the split. | `PTF07 RESULT: FAIL (341 checks, 6 failures)` → `PTF07 RESULT: FAIL (339 checks, 5 failures)` |
| `tools/ptf08/forecast_cases.gd:73` | `FAIL: death_spawn: unavailable intent flagged` | Stale fixture | `4aa73ad65` (pla-07) | `tools/ptf07/forecast_cases.gd:177` uses lethal turn-start Fire to trigger the split. | `PTF08 CASES RESULT: FAIL (364 checks, 5 failures)` → `PTF08 CASES RESULT: FAIL (362 checks, 4 failures)` |

## Headless command results

Run commands from `/Users/borgerding/workspace/Labyrinth.worktrees/gfix-43`. All Godot commands use the task runner.

| Command | Before | After | Logs |
| --- | --- | --- | --- |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tools/atk04/focused_tests.gd` | `ATK04 FOCUSED RESULT: FAIL (982 assertions, 3 failures)` | `ATK04 FOCUSED RESULT: PASS (982 assertions, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-0.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-0.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tools/spl01/capture.gd` | `SPL01 SEMANTICS: FAIL (17 checks, 2 failures)` | `SPL01 SEMANTICS: PASS (17 checks, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-1.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-1.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/warband_orders_test.gd` | `WARBAND ORDERS TEST RESULT: FAIL (287 checks, 9 failures)` | `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-2.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-2.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/element_retrofit_test.gd` | `ELEMENT RETROFIT TEST RESULT: FAIL (930 checks, 9 failures)` | `ELEMENT RETROFIT TEST RESULT: PASS (930 checks, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-3.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-3.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/pre_battle_semantics_test.gd` | `PRE-BATTLE SEMANTICS TEST: FAIL` | `PRE-BATTLE SEMANTICS TEST: PASS` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-4.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-4.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/bos01_rule_scene_test.gd` | `BOS01 RULE SCENE RESULT: FAIL (170 checks, 1 failures)` | `BOS01 RULE SCENE RESULT: PASS (170 checks, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-5.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-5.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/guardian_rules_test.gd` | `GUARDIAN RULES TEST RESULT: FAIL (693 checks, 2 failures)` | `GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-6.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-6.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/encounter_analytics_test.gd` | `error: command timed out after 300 seconds.` | `ENCOUNTER ANALYTICS: PASS (0 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-7.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-7.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tools/ptf07/forecast_cases.gd` | `PTF07 RESULT: FAIL (341 checks, 6 failures)` | `PTF07 RESULT: FAIL (339 checks, 5 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-ptf07.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-8.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tools/ptf08/forecast_cases.gd` | `PTF08 CASES RESULT: FAIL (364 checks, 5 failures)` | `PTF08 CASES RESULT: FAIL (362 checks, 4 failures)` | [Before](/private/tmp/labyrinth_codex/gfix-43/before-ptf08.log), [after](/private/tmp/labyrinth_codex/gfix-43/after-9.log) |

The Analytics baseline also printed `SCRIPT ERROR: Compile Error: Failed to compile depended scripts.` and `ERROR: Failed to load script "res://tests/encounter_analytics_test.gd" with error "Compilation failed".` The before-run diagnostics match the supplied release gate log.

Additional checks

| Command | Observed result | Log |
| --- | --- | --- |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tests/bos01_rules_test.gd` | `BOS01 RULES TEST RESULT: PASS (421 checks, 0 failures)` | [Log](/private/tmp/labyrinth_codex/gfix-43/after-10.log) |
| `cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && python3 tools/godot_task_runner.py --task-id gfix-43 --stream -- godot --headless --path . --script tools/txt27/focused.gd -- 'battlefield rules'` | `TXT27 SUITE battlefield rules: 629 checks, 0 failures` | [Log](/private/tmp/labyrinth_codex/gfix-43/after-txt27-battlefield.log) |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/gfix-43/python-default` | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 30.800s`, `OK` | [Log](/private/tmp/labyrinth_codex/gfix-43/after-python-default.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.957s`, `OK` | [Log](/private/tmp/labyrinth_codex/gfix-43/after-ui-identity.log) |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.042s`, `OK`, `PASS: Rules text lint (16 existing hits)` | [Log](/private/tmp/labyrinth_codex/gfix-43/after-rules-text.log) |
| `git diff --check` on changed tracked files | Exit 0 | |

## Open issues outside this unit

| Proof | Exact failure output present before and after |
| --- | --- |
| PTF07 | `FAIL: Hidden ending Health stays unknown after the visible Defiance save` |
| PTF07 | `FAIL: All repeating foes counted twice, none unknown` |
| PTF07 | `FAIL: Frostbite leaves the hero alive on the first, Frozen turn` |
| PTF07 | `FAIL: The committed Frozen span ends in defeat` |
| PTF07 | `FAIL: Exact tooltip order, cap and wording` |
| PTF08 | `FAIL: All repeating foes counted twice, none unknown` |
| PTF08 | `FAIL: Frostbite leaves the hero alive on the first, Frozen turn` |
| PTF08 | `FAIL: The committed Frozen span ends in defeat` |
| PTF08 | `FAIL: activation_end: panel shows the full lethal Health loss` |

Godot emitted the macOS `get_system_ca_certificates` startup diagnostic. ATK04 also emitted `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` before and after the patch. The Python runner passed and reported that its optional timing cache under shared Git metadata was read-only. All suite logs are under `/private/tmp/labyrinth_codex/gfix-43`.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- `DEATH_SPAWN_FIXTURE_HP = 1` gives the synthetic Ooze a reliably lethal Fire contact. Fire damage, split count and initiative come from the existing gameplay rules.

## Proof for the design owner

The low-risk patch changes tests and fixtures only. The existing SPL01 capture command is available for native inspection of the board status plate, the hover over the pre-battle Splits tag and the glossary tooltip, at 1920×1080 and 100% UI scale. No windowed run took place in this sandbox.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-43 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tools/spl01/capture.gd --task-id gfix-43 --expect-size 1920x1080 --proof-contract tools/spl01/proof_contract.json --result-manifest /private/tmp/labyrinth_codex/gfix-43/spl01-windowed.json
```

Expected capture paths

- `/private/tmp/labyrinth_codex/spl-01/captures/board_status_plate.png`
- `/private/tmp/labyrinth_codex/spl-01/captures/pre_battle_splits_hover.png`
- `/private/tmp/labyrinth_codex/spl-01/captures/splits_keyword_tooltip.png`

