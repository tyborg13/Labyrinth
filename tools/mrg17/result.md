# Candidate 6 and playtest 25

Candidate 6 is composed in the uncommitted working files of `codex/mrg-17`. Playtest 25 is composed in `.godot/mrg17-playtest`, a private project within the worktree. The [checked playtest patch](/private/tmp/labyrinth_codex/mrg-17/playtest-overlay.patch) applies to the candidate working files. The candidate excludes the playtest economy.

| Branch | Actual Git head | Intended integration |
| --- | --- | --- |
| `codex/mrg-17` | `86d9f6ad1411e99c1336c78b8f585b018c7d70fc` | Four approved merges and the Light intent test adjustment |
| `codex/pt-25` | Ref absent | Candidate 6 plus ECO-02 |

The worktree stayed on `codex/mrg-17`. The implementation instructions leave branch operations and merge commits with the director. The read-only audit reported `MRG-17 APPROVED ANCESTRY: PASS (4 candidate tips, 1 playtest-only tip, 0 other commits)`. [Composition log](/private/tmp/labyrinth_codex/mrg-17/patch-final.log)

## Merge order and changed files

| Edition | Approved tip | Requested merge subject |
| --- | --- | --- |
| Candidate 6 | `9c3652e1a` | `Merge codex/fx-38 (owner approved kindle-cracks)` |
| Candidate 6 | `a753ba8a5` | `Merge codex/pol-70 (owner approved polish-batch-1123d)` |
| Candidate 6 | `2b2656f17` | `Merge codex/pol-71 (owner approved polish-batch-1123d)` |
| Candidate 6 | `253d5122f` | `Merge codex/pol-73 (owner approved intent-text-no-burst)` |
| Playtest 25 | `844bd3936` | `Merge codex/eco-02 (playtest only: turn-economy-2)` |

The [57-path candidate inventory](/private/tmp/labyrinth_codex/mrg-17/candidate-files.txt) covers the approved changes and `export_presets.cfg`. The integration test adjustment is in [light_vision_rules_test.gd](../../tests/light_vision_rules_test.gd). The unit adds `native.sh`, `native.py`, `check_exports.py`, `stage_legacy.py` and this report under `tools/mrg17/`. The external launcher is `/private/tmp/labyrinth_codex/mrg-17/native.sh`. The [65-path playtest inventory](/private/tmp/labyrinth_codex/mrg-17/playtest-files.txt) covers the ECO-02 delta and its export additions. No new Python test modules were introduced.

## Conflict rules

1. **RunScene.** POL-70’s title and proxy methods and POL-71’s playback methods coexist. The candidate’s chain-contact hunk forwards POL-71’s `split_push_contact` to `ChainAttackFeedback.play` and keeps candidate 5’s following `_chain_contact_before` reset. The playtest keeps the shared Empower-aware preview helper. Its hidden enemy action hunk preserves candidate 5’s deferred Burst callback and removes the retired summon bonus presentation. POL-71’s labels still appear at the attack and surface contact beats. ECO-02’s `DeathCardPlayFeedback.append_frame` remains in the subsequent death sequence. [Candidate resolution](/private/tmp/labyrinth_codex/mrg-17/resolutions/2b2656f17/scripts/run_scene.gd) · [Playtest patch](/private/tmp/labyrinth_codex/mrg-17/playtest-overlay.patch)
2. **Combat board.** FX-38’s Kindle shader wiring and POL-73’s next-move text compose without a textual conflict. The inspection rows and lethal Burst glow remain reachable. ECO-02’s rail and popup additions compose separately.
3. **Combat engine.** ECO-02 supplies the playtest scheduler, death accounting and Borrowed Time base cost. The payment hunk combines that base cost with candidate 5’s Empower surcharge in pending payment, preview and final payment. [Playtest resolution](/private/tmp/labyrinth_codex/mrg-17/resolutions/844bd3936/scripts/combat_engine.gd)
4. **Export.** All six presets preserve the 45 candidate 5 include patterns. They now have 52 patterns in the candidate and 55 in the playtest. The MRG-16 export filter check and the MRG-17 source-union check passed for both. [Candidate export check](/private/tmp/labyrinth_codex/mrg-17/logs-a/export-union-final.log) · [Playtest export check](/private/tmp/labyrinth_codex/mrg-17/logs-b/export-union-final.log)
5. **Pins, density and provenance.** Both editions reported `MRG-17 PIN UNION: PASS (4407 pins, 14 hash clashes)` and `MRG-17 PROVENANCE AND DENSITY: PASS (9 provenance files and 1 registry)`. Seven tile sheets keep the FX-35 Shadow hashes and seven shot sheets keep candidate 5’s shot hashes. The winning hashes match the installed files and appear in the export logs. The inventories required no edits.

| Scope | Explicit additions in every preset |
| --- | --- |
| Candidate 6 | `assets/shaders/kindle_cracks.gdshaderinc`, `scripts/chain_attack_feedback.gd`, `scripts/displacement_throw.gd`, `scripts/enemy_mechanics/kindle.gd`, `scripts/floating_combat_text.gd`, `scripts/presentation_clock.gd`, `scripts/push_contact_feedback.gd` |
| Playtest additions | `scripts/death_card_play_feedback.gd`, `scripts/enemy_mechanics/reflect_view.gd`, `scripts/turn_order_slots.gd` |

The smallest integration fix updates the older Light Expose witness. It checks that the expanded overlay stays on the next move while inspection retains the Light row. Candidate 5 passed the original assertion, which directly expected the floating row POL-73 removes.

## Candidate 6 proof

| Check | Observed result |
| --- | --- |
| FX-38 | `FX-38 ROUND 1 LOADING_COVER prewarm before board=yes sample_frame=3 board_frame=1491 shared_shader=yes board shader contains kindle_crack=yes` · `FX-38 PROFILES PASS (three actors, death, bonus reset)` · `FX-38 BASE SOURCE PASS (profiles 0-11: same sampling, grading and output, zero Kindle gain)` · `FX-38 AFTER PLAN PASS (18 captures)` |
| FX-38 focused | `EN01 ENEMIES TEST RESULT: PASS` · `Hoarder suite: 0 failures` · `BOARD STATUS PLATES TEST RESULT: PASS (28640 assertions; 0 failures)` · `STATIC FACING TEST RESULT: PASS (149 checks, 0 failures)` · `DEATH TRANSITION TEST: PASS (6 cases)` · `PERF165 LIFECYCLE: PASS (0 failures; 34 warmed recipes)` |
| POL-70 | `RECT COMPARISON: PASS; 0 mismatches` · `CARD TITLE CHECKS: PASS; 0 mismatches` · `NAME FIT: 0 unresolved context/name pairs` · `ROUND 1 NON-SHELF TITLE DIFF: 0 mismatches across 2135 rows` · `ROUND 1 SHELF TITLE DIFF: 13 expected changes; 0 other mismatches` · `TITLE MOTION: PASS; 12 sequences; 0 mismatches` · `CENSUS RESULT: PASS; 14/14 shots succeeded; 0 capped` |
| POL-70 focused | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` · `CARD SUMMARY FIT RESULT: PASS (5447 checks, 0 failures, 650 samples)` · `FACE FIT CHECKS: 18944 checks, 0 failures` |
| POL-71, both editions | `POL71 gameplay proof: 0 failures` · `RULE VALUE GUARD: PASS (8 scenarios, Health, Block, statuses and surface events identical)` · `PREVIEW HANDOFF: PASS (contradicted Expose pruned at commit, matching previews held without a second pop or extra refresh)` · `RECT COMPARISON: PASS (443 matched paths, maximum edge delta 0.0000 px)` |
| POL-71 focused | `CARD BUFF PLAYBACK TEST RESULT: PASS (525 checks, 0 failures)` · `BOSS HEALTH PREVIEW TEST: PASS (0 failures)` · `SURFACE FEEDBACK UI TEST RESULT: PASS` · `TEST RESULT: PASS board surface presentation` |
| POL-73 | `POL73 HEADLESS LAYOUT after 1920x1080: 5 surfaces, 0 failures.` · `POL73 ROSTER after: 44 enemies, 6 Guardians, 137 intents, 422 checks, 0 failures.` · `MIM01 TEST RESULT: PASS (40 checks, 0 failures)` · `THREATS AT REST TEST RESULT: PASS (15645 assertions; includes compass suite)` · `LIGHT AND VISION RULES: 75 checks, 0 failures` |
| Candidate 5 effects | `FX-34 VERIFY PASS (514 checks, 0 failures)` · `FX-34 FOCUSED PASS (879 checks, 0 failures)` · `MRG-16 GEAR CAPTURE PLAN PASS (5 opacity samples, 0 failures)` · `FX-12 VERIFY: 120 checks, 0 failures` · `FX-35 BAKE IDENTITY: PASS (27398800 non-Shadow palette-index bytes, 40 rows x 13 frames x 7 sizes, zero row shifts)` · `FX-35 POOL COUNT AND RAGGEDNESS: PASS` · `FX-36 VERIFY PASS (620 checks, 0 failures)` |
| Candidate 5 copy and rules | `TXT26 truth probe PASS: 18 rerun cases matched, 0 failed` · `TXT26 focused suites PASS: 7579 checks, 0 failures` · `TXT27 FOCUSED SUITES: 91337 checks, 0 failures` · `MRG-16 STA01 exact Fade copy and mechanics: 42 checks, 0 failures` · `TXT28 WITNESS RESULT: PASS (54 witnesses, 0 failures)` · `TXT28 RULES SUITES: PASS (656 checks, 0 failures)` · `TXT28 COPY: PASS (15 director edits, 9 card articles, 305 cards scanned, both new panel templates)` · `TXT30 WITNESSES: 4 true, 0 failed` · `MRG-16 NATIVE DRY RUN PASS` |
| Candidate 5 additional suites | `Section map v2 suite: 0 failures (seeds 0..32 x 6 sections)` · `INT11 INTEGRATION: PASS (407 checks; 0 failures)` · `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` · `PRE-BATTLE VIEW TEST: PASS` · `RUN END RECAP TEST RESULT: PASS` · `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` · `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` |
| Earlier effects | `GFIX-34 VERIFY: 308 checks, 0 failures` · `MRG-15 REFLECTION VERIFY: 68 checks, 0 failures` · `FX-17 VERIFY: 132 checks, 0 failures` · `FX-20 VERIFY: PASS (172 checks, 0 failures)` · `FX-20 VERIFY: PASS (3423 checks, 0 failures)` · `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1998 checks, 0 failures)` · `FX-29 VERIFY: 4258 checks, 0 failures` · `FND-01 VERIFY: 111 checks, 0 failures` · `FND-02 VERIFY AFTER: 194 checks, 0 failures` · `FND-03 VERIFY AFTER: 352 checks, 0 failures` |
| Static and Python | `MRG-16 EXPORT FILTERS: PASS (6/6 presets)` · Pin test `Ran 1 test in 13.053s`, `OK` · UI lint `Ran 25 tests in 5.541s`, `OK` · `PASS: Rules text lint (16 existing hits)` · Default group `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 39.795s`, `OK` |

The initial Scavenger geometry mismatch came from a stale ranged icon import. Its cached source hash differed from the pinned PNG. After restoring the import whose recorded source hash matches the PNG, the two rectangles matched. Cache repairs restored 48 missing effects and 14 stale icon imports from identical approved sources. Historical comparison stages use pinned copies of retired Kindle, pacing and forecast dependencies. Their assertions stay intact.

[Candidate logs](/private/tmp/labyrinth_codex/mrg-17/logs-a) · [Focused logs](/private/tmp/labyrinth_codex/mrg-17/logs-extra) · [Headless receipts](/private/tmp/labyrinth_codex/mrg-17/a-headless.buywtbhd) · [Final title comparison](/private/tmp/labyrinth_codex/mrg-17/logs-a/title-comparison-refreshed.log)

## Playtest 25 proof

| Check | Observed result |
| --- | --- |
| Economy | `ECO-02 KILL TIME: PASS (146 checks, 0 failures)` · `ECO-02 TURN CLOCK: PASS (261 checks, 0 failures)` · `ECO-02 KILL GRANTS: PASS (1796 checks, 0 failures)` · `ECO-02 PROBE: 82 passed, 0 failed` |
| Rail, Pass and popups | `ECO-02 FIRE AND DEATH LABELS: PASS (damage frame=692, rewards frame=726)` · `ECO-02 DUAL FLOAT CROP PLAN: [P: (982, 367), S: (234, 127)]` · `ECO-02 NATIVE after DRY RUN: PASS (0 failures)` · `MRG-17 B DRY RUN PASS`. In the dual-kill fixture, the visible rail went from 19 to 9 at aim and showed 9 on the death beat and at settlement. Gross Wait was 5 and effective Wait was 0. |
| Saves and combat | `SUMMON CARD PLAY TEST RESULT: PASS (159 checks, 0 failures)` · `Surface migration checks: PASS` · `TEST RESULT: PASS — committed save/resume boundary matrix` · `PTF02 SAVED MAP RESULT: PASS (7 checks, 0 failures)` · `TURN CLOCK HUD PROBE RESULT: PASS` · `TURN CLOCK COPY FIT RESULT: PASS` · `EN01 ENEMIES TEST RESULT: PASS` · Burst `TEST RESULT: PASS` · Dragon reward and relic hooks passed |
| Copy and score | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` · `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` · Python tooltips `Ran 5 tests in 0.015s`, `OK` · `PASS: Rules text lint (16 existing hits)` · `MRG-17 HEURISTIC: PASS (309 rows, candidate and playtest scores byte-identical)` |
| Static and Python | `MRG-16 EXPORT FILTERS: PASS (6/6 presets)` · Pin test `Ran 1 test in 13.302s`, `OK` · UI lint `Ran 25 tests in 5.867s`, `OK` · Default group `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 38.382s`, `OK` |

[Playtest logs](/private/tmp/labyrinth_codex/mrg-17/logs-b) · [Headless receipts](/private/tmp/labyrinth_codex/mrg-17/b-headless.hqsj1guw) · [Heuristic scores](/private/tmp/labyrinth_codex/mrg-17/scores-b.json)

## Proof for the design owner

Both launchers use the caller’s files with Cel Look `all` and a 1920×1080 SubViewport at 100% UI scale. They print absolute PNG paths or output directories. No renderer PNGs were produced in the sandbox.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-17 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/mrg-17/native.sh a
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-17/.godot/mrg17-playtest && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/mrg-17/native.sh b
```

Mode `b` also runs from the worktree root after the director switches to the merged playtest branch. Candidate output covers Kindle, the long hand and Scavenger shelf, the POL-71 playback strips and both floating intent and inspection. Playtest output covers rail, Pass, death popups and Grimoire plus the POL-71 Block confirmation sample. The ECO-02 launcher computes the dual-popup crop from the current board layout in both modes. The earlier ECO-02 desktop receipt missed this crop and reached its 30-second cap. The combined headless probe verified the crop bounds and the native driver uses the same layout. The headless launchers printed `MRG-17 A DRY RUN PASS` and `MRG-17 B DRY RUN PASS`.

## Chosen defaults

- The launcher uses the approved fixtures, crop sizes, long-hand order and Kindle’s 60 Hz clock. The single playtest POL-71 sample is `block_confirm_36.png` with its 2× crop.
- The launcher uses fresh proof directories, serialized windowed captures and a 180-second native runner timeout. The Kindle probe observes the normal Continue handoff before moving the initialized fight into the exact-size capture viewport.

## Open issues and design placeholders

- Branch commits and native proof remain with the director. The requested proof excludes the full Godot suite.
- Candidate 5 carried `TXT27 WITNESSES: 43 passed, 1 failed`, `FX-23 VERIFY: FAIL (258 checks, 7 failures)` and `FX-35 WIDTH TARGET: 0/14 within 45–55%`. The original assertions remain. The independent Fade check passed all 42 assertions.
- The standalone BRS-01 check cannot compile on candidate 5 or candidate 6 because `CombatBoardView.FORCE_TILE_GLOW_ALPHA` was retired. The POL-73 live roster, lethal glow and intent-focused checks passed.
- The playtest reproduces candidate 5’s `GLOSSARY TEST RESULT: FAIL (6218 checks, 4 failures)` for the Meteorfall panels and relic hover, and `GUARDIAN RULES TEST RESULT: FAIL (693 checks, 2 failures)` for Ashen Reaver and Gallows Roc copy. Encounter analytics retains the inherited `_animate_relic_acquisition_flourish` override-signature parse error. The ECO-02-focused analytics payload checks passed.
- No new `TODO_DESIGN_*` placeholders. The default Python groups passed. Their timing-cache updates were denied by read-only Git metadata.
