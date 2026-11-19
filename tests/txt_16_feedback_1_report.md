# txt-16 feedback 1

The combat objective HUD and intro title are all caps again. Glyph preparation uses the same uppercased strings for the live and intro titles. The hover still uses the authored title and appends a description only when the objective provides one.

## Other caps restored

| Surface | Restored copy |
| --- | --- |
| Enemy inspection section | KNOWN MOVES |
| Pre-battle sections | ENEMIES and YOUR KIT |
| Reward and treasure banners | GROW YOUR POWER and CLAIM YOUR TREASURE |
| Reward controls | REROLL, SKIP · HEALTH FULL, and SKIP & RECOVER · +3 HEALTH · 14 → 17 in the proof fixture |
| Skill status pager | ← PREV and NEXT → |
| Skill details section | SKILL DETAILS |
| Settings heading | SETTINGS |
| Run-end Chronicle link | VIEW IN THE CHRONICLE › |

The release comparison found four removed uppercase transforms, all in the objective HUD. All four are restored. The skill detail timing label kept its uppercase transform. The audit found no additional removed uppercase properties or transforms.

## Text pins

Updated the Hoarder HUD’s Health pin in BRS01 while preserving both title assertions. Updated other live expectations for Health, enemy wording, Slag Mortar’s US spelling, compact fractions, the Unicode minus, and separators. Historical audit rows and the Chronicle fixture used to exercise legacy wording remain available for comparison. The changed files and exact replacements are in the uncommitted diff.

## Results

| Check | Observed result |
| --- | --- |
| BRS01 | BRS01 FOCUSED RESULT: PASS (4384 checks; 0 failures) |
| Combat objective probe | COMBAT OBJECTIVE PROBE HEADLESS RESULT: FAIL |
| Text-audit scenes | TEXT AUDIT CAPTURE HEADLESS VALIDATION RESULT: PASS (28 fixtures) |
| Card panel | CARD PANEL TEXT TEST RESULT: PASS (2181 definitions, 7537 panels, 7770 checks, 0 failures) |
| Short card tooltips | SHORT CARD TOOLTIPS TEST RESULT: PASS (768 checks, 0 failures) |
| Glossary | GLOSSARY TEST RESULT: PASS (6530 checks, 0 failures) |
| Grimoire | GRIMOIRE PERFORMANCE RESULT: PASS |
| Pre-battle semantics | PRE-BATTLE SEMANTICS TEST: PASS |
| Guided tutorial | CONTEXTUAL COMBAT TUTORIAL TEST: PASS |
| Run score | RUN SCORE TEST RESULT: PASS |
| Event rules | Event rules suite: 0 failures |
| Event view | Event view suite: 0 failures |
| Dragon rewards | Dragon rewards, gifts, wallet recovery and relic hooks passed. |
| Affected suites, including Briar Weaver and Slag Mortar | TXT16 AFFECTED SUITES: PASS (9651 checks, 0 failures) |
| Empower copy | TXT16 EMPOWER COPY: PASS (10 checks, 0 failures) |
| Main menu resume | TEST RESULT: PASS — main menu resume safety |
| Terrain tooltips | BOARD TILE TOOLTIPS: PASS checks=227 failures=0 |
| Forecast wording | ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures) |
| Number audit | CHK01 AUDIT: 123 displayed numbers checked, 0 mismatches, 0 setup failures |
| Text budget, short-card and card-panel Python suites | Ran 6 tests, Ran 5 tests, Ran 4 tests, all OK |
| UI identity lint | Ran 25 tests, OK |
| Zekarion native probe parser check | Exit 0 from Godot check-only mode |
| qa-112 collector | QA112 COPY EXPORT: 6141 records, 3 seeded combats, 1 Zekarion fixture |
| qa-112 audit | QA112 SCAN: 15929 matches across 432 class/check/variant rows |

The combat objective probe ran its assertions headless with image capture disabled. All six remaining failures also occurred on the release production files at a869b8ba3. They cover the pre-battle leader chip, three side-lane overlap checks, the Reach Exit encounter setup, and its reward overlay. Release also failed its stale KILL THE LEADER title pin. The current probe’s objective title and Health assertions passed. Logs and audit exports are in /tmp/txt-16-feedback-1/.

No new design placeholders or fixture defaults. Native proof remains pending. The Zekarion and reward commands are in the [round 0 report](txt_16_report.md). The objective probe can also be run at 1920×1080 with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-16 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 6 tests/combat_objective_probe.gd --task-id txt-16
```

Its capture directory is `user://combat_objective_probe_v1`.
