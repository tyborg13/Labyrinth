# gfix-35 release gate

Both gates first ran on candidate 4 `3c27b676d2bdd568d41ec17e2461bbf70defba83` before any test edits. The Godot runner bootstrapped its import cache and generated the qa131 UIDs during that first launch. The Python guard inspects Git's tracked inventory, which still lacked their paths.

## Baseline failures

- Godot reported `MAIN BODY ASSERTIONS: 491395`, 144 of 149 standalone programs passed, `PROGRAM SUITE RETRIES: []`, `FULL SUITE RUNTIME: 3187.879 seconds`, `TEST RESULT: FAIL (5 failure(s))`. The five parent failures are the failed programs below. [Full log](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:42917) · [Scheduler JSON](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot-programs.json).
- Python reported `ISOLATION AUDIT: 59 modules`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 43.544s`, `FAILED (failures=1)`. [Full log](/private/tmp/labyrinth_codex/gfix-35/logs/01-python.log).
- The standalone probes reported `GRIMOIRE SEARCH PROBE RESULT: FAIL (7 failures)` and `GLACIAL MIRROR BOARD HEADLESS FIXTURE: FAIL` with two failed anchors. [Grimoire log](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log) · [Glacial Mirror log](/private/tmp/labyrinth_codex/gfix-35/logs/01-glacial.log).

| Test | Failing assertion or diagnostic | Baseline log | Branch |
| --- | --- | --- | --- |
| `threats_at_rest_test.gd` | `ERROR: boss_crowded expanded=false: preferred home and local search precede the other side, with final title clearance` | [line 37568](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37568) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: boss_crowded expanded=false: chip stays within 24px of a home: enemy_1` | [line 37573](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37573) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: boss_crowded expanded=true: preferred home and local search precede the other side, with final title clearance` | [line 37578](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37578) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: boss_crowded expanded=true: chip stays within 24px of a home: enemy_1` | [line 37583](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37583) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: dragon_crowded expanded=false: preferred home and local search precede the other side, with final title clearance` | [line 37588](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37588) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: dragon_crowded expanded=false: chip stays within 24px of a home: enemy_1` | [line 37594](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37594) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: dragon_crowded expanded=true: preferred home and local search precede the other side, with final title clearance` | [line 37599](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37599) | Stale expectation under gfix-33 hero HUD clearance |
| `threats_at_rest_test.gd` | `ERROR: dragon_crowded expanded=true: chip stays within 24px of a home: enemy_1` | [line 37604](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:37604) | Stale expectation under gfix-33 hero HUD clearance |
| `card_summary_fit_test.gd` | `SCRIPT ERROR: Invalid access to property or key 'GRIMOIRE_CARD_PREVIEW_SIZE' on a base object of type 'Dictionary'.` | [line 38451](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38451) | Stale fixture lookup under ux-18 |
| `card_summary_fit_test.gd` | `ERROR: Sweep has definitions and reading contexts` | [line 38457](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38457) | Stale fixture lookup under ux-18 |
| `card_summary_fit_test.gd` | `ERROR: Committed baseline and after coverage are identical` | [line 38463](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38463) | Stale fixture lookup under ux-18 |
| `settings_modal_input_test.gd` | `ERROR: Title confirmation: outside pointer events must preserve focus` | [line 38957](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38957) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Title confirmation: controller moves focus within Settings without activating the background` | [line 38962](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38962) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Title: B cancels confirmation and keeps Settings open` | [line 38967](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38967) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Pause confirmation: outside pointer events must preserve focus` | [line 38972](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38972) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Pause confirmation: controller moves focus within Settings without activating the background` | [line 38977](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38977) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Pause: B cancels confirmation and keeps Settings open` | [line 38982](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38982) | Stale expectation under gfix-32 |
| `settings_modal_input_test.gd` | `ERROR: Pause: Esc restores focus to the menu's Settings button` | [line 38987](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:38987) | Stale expectation under gfix-32 |
| `card_legibility_test.gd` | `SCRIPT ERROR: Invalid access to property or key 'GRIMOIRE_CARD_PREVIEW_SIZE' on a base object of type 'Dictionary'.` | [line 39188](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:39188) | Stale fixture lookup under ux-18. The nonempty-context guard exits before printing its collected assertion. |
| `board_tile_tooltip_test.gd` | `SCRIPT ERROR: Invalid access to property or key 'visible' on a base object of type 'Nil'.` | [line 41900](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:41900) | Stale retained-layer assumption under grd-11. The script error precedes the timeout. |
| `board_tile_tooltip_test.gd` | `error: command timed out after 300 seconds.` | [line 41905](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:41905) | Stale retained-layer assumption under grd-11. The script error precedes the timeout. |
| `GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` | `AssertionError: Missing tracked Godot sidecars (3):` | [line 121](/private/tmp/labyrinth_codex/gfix-35/logs/01-python.log:121) | Missing sidecar on the tracked path inventory |
| `GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` | `tools/qa131/board_effects.gd.uid` | [line 122](/private/tmp/labyrinth_codex/gfix-35/logs/01-python.log:122) | Missing sidecar on the tracked path inventory |
| `GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` | `tools/qa131/live_effects.gd.uid` | [line 123](/private/tmp/labyrinth_codex/gfix-35/logs/01-python.log:123) | Missing sidecar on the tracked path inventory |
| `GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` | `tools/qa131/relic_glossary.gd.uid` | [line 124](/private/tmp/labyrinth_codex/gfix-35/logs/01-python.log:124) | Missing sidecar on the tracked path inventory |
| `grimoire_search_probe.gd` | `ERROR: Rules-text search should select Fatigue for reshuffle` | [line 17](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:17) | Stale Fatigue search fixture after the candidate 3 rules-text integration `9d9d18349` |
| `grimoire_search_probe.gd` | `ERROR: Rules-text result should populate its detail page` | [line 22](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:22) | Stale Fatigue search fixture after the candidate 3 rules-text integration `9d9d18349` |
| `grimoire_search_probe.gd` | `ERROR: Down from search should visibly focus the first result` | [line 27](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:27) | Stale Fatigue search fixture after the candidate 3 rules-text integration `9d9d18349` |
| `grimoire_search_probe.gd` | `ERROR: Accepting a search result should keep focus on its rebuilt row` | [line 32](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:32) | Stale Fatigue search fixture after the candidate 3 rules-text integration `9d9d18349` |
| `grimoire_search_probe.gd` | `ERROR: Small transposition typo should recover Truesight` | [line 37](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:37) | Stale Truesight fixture after pla-08 `cdf21abe4` |
| `grimoire_search_probe.gd` | `ERROR: Typo-only results should be labeled as close matches` | [line 42](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:42) | Stale Truesight fixture after pla-08 `cdf21abe4` |
| `grimoire_search_probe.gd` | `ERROR: Upheaval article renders the verified sentences verbatim` | [line 47](/private/tmp/labyrinth_codex/gfix-35/logs/01-grimoire.log:47) | Stale authored text after txt-20 `2d766d929` and integration `9d9d18349` |
| `glacial_mirror_board_probe.gd, front` | `ERROR: Stage uses its exact profile` | [line 13](/private/tmp/labyrinth_codex/gfix-35/logs/01-glacial.log:13) | Stale standing anchor after pt15-01 `7bd049ec2` |
| `glacial_mirror_board_probe.gd, rear` | `ERROR: Stage uses its exact profile` | [line 19](/private/tmp/labyrinth_codex/gfix-35/logs/01-glacial.log:19) | Stale standing anchor after pt15-01 `7bd049ec2` |

## Evidence and diff

| Changed file | Replacement and evidence |
| --- | --- |
| `tests/settings_modal_input_test.gd` | gfix-32 `8b5494403` gives the confirmation first claim on B, Esc and the primary backdrop click. The updated title and pause routes navigate within the confirmation before clicking the backdrop, then reopen it for each Back input. Each input closes only the confirmation and returns focus to Restore Defaults. Existing background, cue, and parent Settings close assertions still run. The approved verifier on candidate 4 printed `GFIX-32 AFTER HEADLESS: 0 failures`. [Verifier](/private/tmp/labyrinth_codex/gfix-35/logs/01-gfix32.log:39). |
| `tests/grimoire_search_probe.gd` | The four Fatigue selection, detail and focus failures came from one empty search for “reshuffle”. The integrated copy uses “shuffles”. The probe now uses “drawing from an empty”, the query already used by the candidate 4 ux-18 verifier. The two fuzzy-search assertions now recover Vision from a transposition and still require the close-match label. The Upheaval check still pins both rendered paragraphs verbatim. The seven failure messages also appeared on candidate 3, before ux-18’s shared panel reached this line. ux-18 added the title entry and preserved these search interactions. The candidate 4 ux-18 verifier printed `UX18 HEADLESS RESULT: PASS`. [Candidate 3 search log](/private/tmp/labyrinth_codex/mrg-14/focused/grimoire_search_candidate3.log:17) · [Verifier](/private/tmp/labyrinth_codex/gfix-35/logs/01-ux18.log:30). |
| `tests/glacial_mirror_board_probe.gd` | The complete actor profile file has the same blob `36781ffd7250f7adbe22da1a73a4e914fbf094e5` on candidate 4, candidate 3 and `master`. Replaced the two current pin values with front `(122.57, 224.82)` and rear `(125.81, 226.23)`. The legacy-stage values and the registration and facing assertions still run as before. [Profile](../../scripts/actor_presentation.gd#L20). |
| `tests/helpers/card_legibility_audit.gd` | ux-18 `35a145277` moved both Grimoire preview size constants to `GrimoirePanel` with their values. The shared fixture now reads them there. The card-summary and card-legibility programs retain their sample, fit and coverage checks. [Panel](../../scripts/grimoire_panel.gd#L26). |
| `tests/pt15_01_sole_layout_assertions.gd`, `tests/suites/intent_chip_placement_suite.gd` | gfix-33 r1 `2a35d7220` allows a final, capped clearance move. For all four crowded fixtures the frozen layout exactly matched the production layout after applying only the reported `(-45.00024, 0)` offset. The four natural centers had zero distance from their homes and initially overlapped the hero HUD. The final rectangles cleared it, within the 92 px horizontal cap. The tests still compare the full layout with the frozen placement reference, apply the 24 px limit to the natural stage, and check that the affected fixtures move within the approved final clearance caps. [Matched geometry](/private/tmp/labyrinth_codex/gfix-35/logs/01-threat-clearance-always.log:13) · [gfix-33 approval evidence](../gfix33/result.md). |
| `tests/board_tile_tooltip_test.gd` | Candidate 4 ships grd-11’s approved pixel default. That mode omits the legacy ground nodes. Tooltips now run against the default board, with an assertion for the missing legacy canvases in pixel mode. A separate board mounted under the supported `LABYRINTH_GROUND_FX=off` override still runs all original retained order and Rubble-retirement assertions. [Approval verifier](../grd03/verify_geometry.gd#L88) · [Integration evidence](../mrg14/result.md). |
| `tools/qa131/*.gd.uid` | Kept the three files produced by the baseline Godot import. A read-only projected Git inventory passed the unchanged sidecar validator with these exact files. Both named flt-01 sidecars were already tracked in `2c6aff3f7`. [UIDs and validator result](/private/tmp/labyrinth_codex/gfix-35/logs/02-sidecar-inventory.log). |
| `tools/gfix35/result.md` | Baseline failure catalog, evidence and rerun results. |

## Focused checks after edits

| Check | Observed result |
| --- | --- |
| Settings modal | [`TEST RESULT: PASS — Settings modal input`](/private/tmp/labyrinth_codex/gfix-35/logs/02-settings.log) |
| Grimoire search | [`GRIMOIRE STEAM KEYBOARD: PASS` and `GRIMOIRE SEARCH PROBE RESULT: PASS`](/private/tmp/labyrinth_codex/gfix-35/logs/02-grimoire.log) |
| Glacial Mirror | [`GLACIAL MIRROR BOARD HEADLESS FIXTURE: PASS`](/private/tmp/labyrinth_codex/gfix-35/logs/02-glacial.log) |
| Card summary | [`CARD SUMMARY FIT RESULT: PASS (5447 checks, 0 failures, 650 samples)`](/private/tmp/labyrinth_codex/gfix-35/logs/02-card-summary.log:91) |
| Card legibility | [`CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)`](/private/tmp/labyrinth_codex/gfix-35/logs/02-card-legibility.log:63) |
| Threats at rest | [`THREATS AT REST TEST RESULT: PASS (15645 assertions; includes compass suite)`](/private/tmp/labyrinth_codex/gfix-35/logs/02-threats.log) |
| Board tooltips | [`BOARD TILE TOOLTIPS: PASS checks=233 failures=0`](/private/tmp/labyrinth_codex/gfix-35/logs/02-board-tooltip.log) |
| Rules text | [`PASS: Rules text lint (16 existing hits)`](/private/tmp/labyrinth_codex/gfix-35/logs/02-rules-text.log) |

## Authored Fatigue wording

The candidate 3 comparison flagged the current `combat:fatigue` body. Both paragraphs below are from [data/grimoire.json](../../data/grimoire.json#L183). The data stayed byte-identical in this work.

> Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health.
>
> Fatigue costs 2 Health the first time and +1 Health each time after. Fatigue bypasses Block. Draw and Pass previews show the Health that Fatigue costs.

## Full rerun

Both reruns used candidate 4 HEAD `3c27b676d2bdd568d41ec17e2461bbf70defba83` with the uncommitted test patch and three generated UIDs. The saved test patch has SHA-256 `8fe44f8a5eccab0b001b17213a3aa1d3af8ed21bd59a579f912c2df00f029aff`. [Test patch](/private/tmp/labyrinth_codex/gfix-35/logs/02-test-changes.patch).

| Gate | Result |
| --- | --- |
| Godot | `MAIN BODY ASSERTIONS: 491395`, 148 of 149 standalone programs passed, `PROGRAM SUITE RETRIES: []`, `FULL SUITE RUNTIME: 2850.226 seconds`, `TEST RESULT: FAIL (1 failure(s))`. All five previously failing programs passed. The remaining failure was Original Music. [Full log](/private/tmp/labyrinth_codex/gfix-35/logs/02-godot.log:6745) · [Scheduler JSON](/private/tmp/labyrinth_codex/gfix-35/logs/02-godot-programs.json). |
| Python | `ISOLATION AUDIT: 59 modules`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 30.680s`, `FAILED (failures=1)`. The tracked-sidecar guard is the sole failure. It will see the three generated qa131 files once they are staged. The same validator passed a read-only projected inventory containing those files. [Full log](/private/tmp/labyrinth_codex/gfix-35/logs/02-python.log:114) · [Projected inventory](/private/tmp/labyrinth_codex/gfix-35/logs/02-sidecar-inventory.log). |

## Anything else

The full rerun reported `ERROR: Planning stream should replace combat after its outgoing fade` from `tests/original_music_test.gd:30`. The assertion opens the planning surfaces one by one during combat, waits 0.3 seconds, and expects a 48-second Ogg stream. The error message does not identify which surface was active. The first full run passed this program in 11.998 seconds. The second full run failed it in 32.711 seconds. The differing outcomes show an intermittent failure under the full runner. Its cause remains unconfirmed. The test and production audio code were left intact. [First full pass](/private/tmp/labyrinth_codex/gfix-35/logs/01-godot.log:41223) · [Second full failure](/private/tmp/labyrinth_codex/gfix-35/logs/02-godot.log:5027).

The smallest existing headless check is the standalone script. It passed once on each revision, so the failure did not reproduce in isolation.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-35 && python3 tools/godot_task_runner.py --task-id gfix-35 --stream -- godot --headless --path . --script res://tests/original_music_test.gd
```

| Revision | Standalone result |
| --- | --- |
| Candidate 4 `3c27b676d` plus test changes | [`ORIGINAL MUSIC ROUTING/PLAYBACK TEST: PASS`](/private/tmp/labyrinth_codex/gfix-35/logs/02-music-candidate4.log:13) |
| Candidate 3 `90d5574ff` | [`ORIGINAL MUSIC ROUTING/PLAYBACK TEST: PASS`](/private/tmp/labyrinth_codex/gfix-35/logs/02-music-candidate3.log:13) |
| Local `master` `4c1547f1` | [`ORIGINAL MUSIC ROUTING/PLAYBACK TEST: PASS`](/private/tmp/labyrinth_codex/gfix-35/logs/02-music-master.log:13) |

The Python runner’s optional learned timing-cache write was denied by the read-only Git sandbox on both runs. The suite reports and logs were written.

## Chosen defaults

- The proof-only transposition is `visoin`. The Fatigue query reuses the ux-18 verifier’s fixture.
- The Godot gate used `LABYRINTH_TEST_POOL=1`, allowing one child beside the parent. The four-shard Python gate ran separately and used a scratch two-slot native launch limit with 0.05-second polling. Both Python runs selected changes from pre-merge local `master` `4c1547f199272976d217d3ed910f0a8014160c81`.
- The tooltip test mounts its legacy fixture under the existing `off` setting and restores the environment immediately after mounting.
- No `TODO_DESIGN_*` placeholders or permanent test programs were added.

## Proof for the design owner

The requested gate and focused proof ran headless. These existing capture probes can be run from a desktop session at 1920×1080 and 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-35 && python3 tools/visual_probe_runner.py --task-id gfix-35 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 10 tests/grimoire_search_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-35 && python3 tools/visual_probe_runner.py --task-id gfix-35 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 5 tests/glacial_mirror_board_probe.gd -- --stage after
```

The runner prints the resolved directories for `user://grimoire_search_probe/` and `user://probes/glacial_mirror_board/`. No captures were produced by the headless runs.
