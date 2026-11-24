# txt-36 verification

The 26 Grimoire entries match all 26 pairs of strings in the protected director source. The worktree remains on `codex/txt-36` with uncommitted additions confined to `tools/txt36/`.

## Acceptance criteria

1. **Truth audit.** [TRUTH.md](TRUTH.md) records 119 concrete claims across all 26 pages. There are 100 True, 18 False and 1 UNTESTED. The untested claim is absolute Storm Capacitor immobility. Ordinary movement and Push/Pull are gated, while Erupt's direct placement path warrants checking if the two enemies can meet in a production state. The audit inventories fictional details under Lore.
2. **Pages.** The live Creatures list contained all 26 unlocked rows. The detail probe opened and checked all 26 through their actual list buttons. Ember Tick opened by pointer. The left list scroll range dropped to zero when the selection rebuilt the list, so the remaining 25 were activated through their Button signals. The probe checked visible catalog art, exact title and both paragraphs, the existing trait sections, all six Guardian rules, the Gale Herald rule and every move row in catalog order with its Time value. The headless control geometry passed, with 11 move tables requiring a bottom capture. Native image inspection and the native pointer result are pending.
3. **Search.** All 26 title queries and all 26 exact lore-word queries returned a matching visible search result in the live Grimoire. Each lore-word hit had match kind `rules`. The individual search words and results are in the dry-run log.
4. **Text lints.** The rules-text lint and the focused Grimoire and glossary readers ran. The rules-text lint kept its 16 existing hits and reported no protected lore line. Its Grimoire fields are `body` and `summary`, so the separate exact-pair check covers the protected `lore` field.

## Creature list order

The list follows `data/grimoire.json` order. It displays the unlocked subset, so numbered positions below are for a fully unlocked catalog. The fixture supplied unlock candidates in reverse order.

| Position | Page | Bottom capture |
| ---: | --- | --- |
| 19 | Ember Tick | Yes |
| 20 | Ember Hoarder | Yes |
| 21 | Slag Mortar | Yes |
| 22 | Ash Hound | |
| 23 | Hoarfrost Seer | Yes |
| 24 | Glacial Mirror | |
| 25 | Rime Whelp | |
| 26 | Rime Spitter | |
| 27 | Arc Thrall | |
| 28 | Storm Capacitor | |
| 29 | Bell Tender | |
| 30 | Gale Herald | Yes |
| 31 | Gust Shrike | |
| 32 | Roc Fledgling | |
| 33 | Burrow Grub | |
| 34 | Briar Weaver | |
| 35 | Stoneback Mite | |
| 36 | Gloam Stalker | |
| 37 | Hollow Mimic | |
| 38 | Wick Shade | |
| 39 | Ashen Reaver | Yes |
| 40 | Rimejaw | Yes |
| 41 | Storm Cantor | Yes |
| 42 | Gallows Roc | Yes |
| 43 | Craghide | Yes |
| 44 | Last Lamplighter | Yes |

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-36 && bash tools/txt36/native.sh
```

The command runs [pages.gd](pages.gd) through `tools/visual_probe_runner.py` at exactly 1920×1080, 100% UI scale, with `LABYRINTH_CEL_LOOK=all`. It prints each saved PNG path on its own line. Each run creates `/private/tmp/labyrinth_codex/txt-36/proof.XXXXXX/` with PNGs under `after/`, a log at `after.log`, and the validated native manifest at `after-captures.json`. The top and bottom suffixes denote the detail scroll limits. The [native contract](native_contract.json) gives the 37 expected file names and checks the captured UI region. No inspection-fixture command was requested.

### Headless command and receipts

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-36 && bash tools/txt36/native.sh --dry-run
```

```text
TXT36 LIST: 44 entries, data order=true
TXT36 BROWSE: 1 pointer opens, 25 list-button signal opens
TXT36 PAGE PROOF: PASS (headless, 26 tops, 11 bottoms, 52 search hits)
TXT36 PROTECTED DATA: PASS (26 exact lore pairs, creature positions 19–44)
TXT36 TRUTH INVENTORY: 119 claims, 100 True, 18 False, 1 UNTESTED, 26 pages
TXT36 CAPTURE PLAN: PASS (37 unique planned PNG paths match the native contract)
```

The dry-run log is [after.log](/private/tmp/labyrinth_codex/txt-36/proof.3dbFR4/after.log). It lists the planned absolute PNG paths under `/private/tmp/labyrinth_codex/txt-36/proof.3dbFR4/after/`. The headless run emitted no PNGs. `bash -n tools/txt36/native.sh` exited 0.

## Focused checks

The Godot paths below were run from the worktree with `python3 tools/godot_task_runner.py --task-id txt-36 --stream -- godot --headless --path . --script res://tests/<file>`. Godot printed the same macOS system CA diagnostic in these runs. The table records the check outcomes.

| Command or Godot script | Exact result |
| --- | --- |
| `python3 -B tests/test_rules_text_lint.py` | `Ran 3 tests in 0.081s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| `python3 -B tests/test_short_card_tooltips.py` | `Ran 5 tests in 0.018s`, `OK` |
| `python3 -B tests/test_icon_identity_policy.py` | `Ran 10 tests in 0.186s`, `OK` |
| `python3 -B tests/text_budget_test.py` | `Ran 6 tests in 0.263s`, `OK` |
| `python3 -B tests/test_element_rule_contract.py` | `Ran 2 tests in 0.006s`, `OK` |
| `python3 -B tests/test_card_panel_text.py` | `Ran 4 tests in 0.007s`, `OK` |
| `glossary_test.gd` | `GLOSSARY COVERAGE: 128 entries, 30 skills, 420 tokens checked; 309 cards scanned, 0 one-line contextual tooltips`, `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| `short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| `grimoire_search_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS` |
| `worldspine_rules_test.gd` | `grimoire_search_suite.gd: 33 checks, 0 failures`, `dragon_feedback1_suite.gd: 84 checks, 0 failures`, `TRN-01 RULES RESULT: FAIL (2254 checks, 4 failures)` |
| `en03_enemies_test.gd` | `EN03 ENEMIES TEST RESULT: PASS (505 checks, 0 failures)` |
| `en06_enemies_test.gd` | `EN06 ENEMIES TEST RESULT: PASS (136 checks, 0 failures)` |
| `hoarder_test.gd` | `Hoarder catch: 18 fights win at once, brood scatter silently, own burst fires`, `Hoarder suite: 0 failures` |
| `mim01_test.gd` | `MIM01 TEST RESULT: PASS (40 checks, 0 failures)` |
| `guardian_rules_test.gd` | `GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)` |
| `last_light_test.gd` | `Last Light suite: 0 failures` |
| `brs02_test.gd` | `BRS02 FOCUSED RESULT: PASS (442 checks; 0 failures)` |
| `mrk01_marked_test.gd` | `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` |
| `enc03_slag_test.gd` | `ENC03 SLAG TEST: PASS (732 checks; 0 failures)` |
| `en02_enemies_suite.gd` and `en04_enemies_suite.gd` through a temporary headless suite wrapper | `TXT36 en02_enemies_suite.gd: 226 checks, 0 failures`, `TXT36 en04_enemies_suite.gd: 417 checks, 0 failures` |

The four Worldspine failures match the prior baseline. FB1.1 fails live Tick Burst and Pass forecast. FB1.2 fails Mountain Stoneskin ordering in both cast orders. Both full suites were outside the low-risk proof scope. [txt-34 baseline](../txt34/result.md), [txt-35 receipt](../txt35/result.md)

The temporary wrapper called each existing suite's `run` with a counting assertion callback and was removed after execution. [Focused enemy suite log](/private/tmp/labyrinth_codex/txt-36/enemy-suites.log)

## Open issues

- **Creatures list scrolling.** After the Ember Tick pointer click, the next row remained outside the 356 px viewport despite 2492 px of content. The scroll value, maximum and page were all zero after the list rebuild. The probe emits a `TXT36 NAV OUT OF VIEW` line and opens the affected row through its existing Button signal so the detail remains inspectable. The director should check whether this reproduces in the native run. If it does, the common browser rebuild and scroll restoration in `scripts/grimoire_panel.gd:580` and `:1206` need investigation.
- **Trait coverage.** The page rendered the wired trait providers. The Traits section omitted Glacial Mirror's Reflect and Gust Shrike's Flying, both registered for discovery and shown on combat badges. Storm Capacitor immobility and Stoneback Mite's on-death Rubble also lack trait rows. Adding any of these to the bestiary would require a product change. [Creature page renderer](../../scripts/grimoire_creature_page.gd)
- **Native visual proof.** Final checks for rendered clipping, overlap, texture presentation and pointer list behavior require the window-server session. The headless receipt covers control layout and content.
- **Protected copy.** The False and UNTESTED rows are left for the design owner. No placeholder was introduced.

## Chosen defaults

The probe reuses the first eligible seed from the pre-battle fixture and unlocks all entries in an isolated run so the complete list and search catalog are available. It uses pointer modality with the existing Xbox family, reduced motion, four process frames for layout and one pixel of geometry tolerance. The lore queries are named fixture data in [pages.gd](pages.gd). The native command allows 90 seconds for the 37 GPU readbacks and PNG writes and reuses txt-35's 920×420 pixel region at (500, 320), with minimum luma range 25 and standard deviation 3.
