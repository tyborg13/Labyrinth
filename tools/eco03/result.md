# eco-03 Scavenger implementation and measurement

Release baseline `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a`. All changes are uncommitted in `codex/eco-03`.

## Requirements and changed lines

| Requirement | Implementation |
| --- | --- |
| 1. Price data and export | [New price data](../../data/scavenger_prices.json), [GameData loader](../../scripts/game_data.gd) at 103, [RunEngine price quotes](../../scripts/run_engine.gd) at 101, 1593, 1826 and 1837, and [all six export presets](../../export_presets.cfg) at 9, 30, 50, 70, 91 and 111. Copy the three buy tables, sell ratio, purge base, and purge step verbatim. The price witness compares public quotes at every Umbra Depth 0–20 and repeats them with Debt. |
| 2. Commons and reservation | [RunEngine](../../scripts/run_engine.gd), initial rolls at 3117, reservation at 3145, purchases at 3198, restored stock at 3257, and common selection at 3308. Use the existing category salt to replace one offer only when a Gear or Magic row has no common and an eligible one remains. Refilling the last purchased common uses its own slot. Layaway evicts a different offer when the usual eviction would remove the sole common. |
| 3. Spacing and saves | [SectionMapGraph](../../scripts/section_map_graph.gd), revision at 12, placement at 109, proposal selection at 301, and route rule at 343. Check the minimum fight prefix across all incoming edges and again after special placement. When a retry is needed, prefer a legal proposal that preserves the original shop count, using the existing attempt budget. If the budget ends, accept the highest-density legal proposal already seen. The existing revision-7 fallback is still reached if every proposal fails. Stored revision-7 maps retain their room and section data. |
| 4. Measurement and native proof | [Witnesses and scripts](.), including `route.gd`, `witness.gd`, `prices.gd`, `stock.gd`, `measure.py`, `bot.gd`, `export_check.py`, `existing_suites.gd`, and the native script, fixture and proof contract. |

The unmodified release runner wrote seeds 1–899 then reached its 300-second timeout. The retained revision-7 generator and release stock roll completed seeds 900–1000. The separate release price quotes and save fixture came from release code.

## Structural measurement

Seeds 1–1,000 at Umbra Depth 0 on each revision. Count resolved mystery Scavengers and mystery combat, using the final room type after special placement. The first-shop path minimizes fights and then arrival step, with lane order breaking ties. Room count omits the entry and includes the arrival room. Wallet projections start from the default profile and sum the base enemy drops in the qualifying encounters, excluding Guardian helpers, optional pickups and event rewards. The projection uses the generated combat roster with no skill or relic bonuses.

Affordability counts each of the nine offers independently at the phase's median wallet. The last two rows use exactly the same Revision 8 shops and wallets to isolate the common guarantee.

| Map | Section I metric | Min | P10 | Median | P90 |
| --- | --- | --- | --- | --- | --- |
| Release | Rooms through arrival | 2 | 3 | 3 | 8 |
| Release | Fights before arrival | 1 | 1 | 2 | 2 |
| Release | Base Embers on arrival | 8 | 25 | 37 | 59 |
| Revision 8 | Rooms through arrival | 3 | 3 | 3 | 8 |
| Revision 8 | Fights before arrival | 2 | 2 | 2 | 2 |
| Revision 8 | Base Embers on arrival | 16 | 35 | 53 | 60 |

| Section | Release Scavengers | Revision 8 Scavengers | Change |
| --- | --- | --- | --- |
| 1 | 2.898 | 3.119 | +7.63% |
| 2 | 3.405 | 3.671 | +7.81% |
| 3 | 2.915 | 3.125 | +7.20% |
| 4 | 2.992 | 3.153 | +5.38% |
| 5 | 2.994 | 3.152 | +5.28% |
| 6 | 3.718 | 3.959 | +6.48% |

| Map | Seeds with early shops | Sections with early shops | Fallback sections |
| --- | --- | --- | --- |
| Release | 899 | 1997 | 0 |
| Revision 8 | 0 | 0 | 0 |

| Sample | Median wallet | Median independently affordable offers out of nine |
| --- | --- | --- |
| Release routes and stock | 37 | 2 |
| Revision 8 routes before common guarantee | 53 | 3 |
| Revision 8 routes with common guarantee | 53 | 3 |

Release median-wallet example, seed 8. Start → combat (1,-1) → event (0,1) → guardian (2,-2) → campfire (1,2) → treasure (-2,1) → scavenger (3,-3).
Release seeds with zero affordable offers at their own projected wallet, 108/1000.

Revision 8 median-wallet example, seed 9. Start → combat (1,-1) → combat (0,1) → scavenger (2,-2).
Revision 8 seeds with zero affordable offers at their own projected wallet, 27/1000.

## Price identity

| Category | Rarity | Buy depth 0–15 before → after | Buy depth 16–20 before → after | Sell both | Debt buy depth 1 both | Debt buy depth 16 both |
| --- | --- | --- | --- | --- | --- | --- |
| gear | common | 150 → 150 | 165 → 165 | 53 | 225 | 248 |
| gear | rare | 240 → 240 | 265 → 265 | 84 | 360 | 398 |
| gear | epic | 360 → 360 | 400 → 400 | 126 | 540 | 600 |
| gear | legendary | 540 → 540 | 595 → 595 | 189 | 810 | 893 |
| magic | common | 110 → 110 | 125 → 125 | 39 | 165 | 188 |
| magic | rare | 175 → 175 | 195 → 195 | 61 | 263 | 293 |
| magic | epic | 265 → 265 | 295 → 295 | 93 | 398 | 443 |
| magic | legendary | 400 → 400 | 440 → 440 | 140 | 600 | 660 |
| item | common | 25 → 25 | 30 → 30 | 9 | 38 | 45 |
| item | rare | 40 → 40 | 45 → 45 | 14 | 60 | 68 |
| item | epic | 60 → 60 | 70 → 70 | 21 | 90 | 105 |
| item | legendary | 90 → 90 | 100 → 100 | 31 | 135 | 150 |

| Prior priced purges | Purge price both | Debt purge price both |
| --- | --- | --- |
| 0 | 50 | 75 |
| 1 | 75 | 113 |
| 2 | 100 | 150 |

The measured density stayed above the release mean in each section without changing the map's room-type or mystery weights. The remaining unaffordable arrivals are the cases the director's price pass can address.

## Bot arrival wallet

The existing curve-ladder bot played the selected Section I route for each of the 100 paired seeds. Wallets were recorded before trading. The ladder resets Health at fight entry and can advance a lost fight, so these figures describe that bot policy.

| Ladder | Shop arrivals / 100 | Forced victories | Min | P10 | Median | P90 |
| --- | --- | --- | --- | --- | --- | --- |
| before | 100/100 | 11 | 8 | 25 | 52 | 102 |
| after | 100/100 | 16 | 17 | 35 | 53 | 80 |

Each shard printed `ECO03 BOT RESULT first_seed=<1, 26, 51, or 76> seeds=25 before_reached=25 after_reached=25` in `bot-complete-*.log`. The combined report printed `ECO03 MEASUREMENT: PASS`.

## Receipts and diagnostics

Raw receipts are under `.godot/eco03/` in this worktree. Rebuild the tables with `python3 tools/eco03/measure.py .godot/eco03`. The price quote program inserts a disposable Legendary Item in its process because the release catalog has no Legendary Item. Every remaining quote uses the catalog as shipped.

| Check | Receipt |
| --- | --- |
| Release and candidate quote snapshots | `ECO03 PRICE QUOTES BEFORE: PASS (383 checks, 0 failures)` and `ECO03 PRICE QUOTES AFTER: PASS (383 checks, 0 failures)`. `cmp prices-before.json prices-after.json` exited 0. |
| Export staging | `ECO03 STAGED PRICE DATA: PASS presets=6 sha256=6fe47c52d994cdc4f2c11c7ef9552cca3df8d571be5e0c74917bec949912bfa2`. Staged Steam macOS pack printed `CEL_PACK_TEST paths=3089 failures=0` and `ECO03 PACK PRICE DATA: PASS` with the same hash. See `export.log` and `export/scavenger.pck`. |
| Stock at all 500 seeds × 15 depths | `ECO03 STOCK COVERAGE seeds=500 depths=1-15 stocks=7500 changed_gear=1453 changed_magic=890 protected_reservations=15000` and `ECO03 STOCK: PASS (97500 checks, 0 failures)`. See `stock.log`. |
| 1,000 final maps | Each of `final-{1,251,501,751}.log` printed `ECO03 MAP RESULT phase=after seeds=250 early_seeds=0 early_sections=0 fallback_sections=0` and `ECO03 AFTER: PASS (1949 checks, 0 failures)`. |
| Release save and regeneration | `ECO03 RELEASE SAVE seed=83 rooms=263 sections=6`. The witness compared the stored room and section dictionaries and the regenerated revision-7 room types and doors. Fixture `release.save`, SHA-256 `106e6d24417b77e9478df3a686e21d1f34033d7733acdc7f4b38c79294814b84`. |
| Existing merchant and v7 map checks | `ECO03 SCAVENGER AND MAP POLICIES: PASS (121354 checks, 0 failures)`. The wrapper calls `scavenger_shop_suite.gd` and `section_map_v7_suite.gd` generation, door, layout, fallback and saved-revision checks. |
| Existing merchant and depth price check | `Depth shop price regression: 216 buyable items x depths 0, 13, 16` and `ECO03 MERCHANT AND DEPTH PRICES: PASS (8870 checks, 0 failures)`, from `scavenger_shop_suite.gd` and `depth_rules_suite.gd`. See `depth-prices.log`. |
| Existing v5 map check | `Section map v5 suite: 0 failures`. See `map-v5.log`. |
| Existing saved map check | `PTF02 SAVED MAP RESULT: PASS (7 checks, 0 failures)`. See `ptf02-save.log`. |
| Existing save/resume boundaries | `TEST RESULT: FAIL — 6 committed save/resume failure(s)` on release and candidate with the same six assertions. See `save-boundary-release.log` and `save-boundary.log`. |
| Rules text lint | `Ran 3 tests in 0.061s`, `OK`, and `PASS: Rules text lint (16 existing hits)`. |
| Real RunScene dry run | `ECO03 REAL SCAVENGER: PASS seed=9 section=1 fights=2 embers=53 size=1920x1080 scale=1.0 stock=storm_beacon,frostbolt,searing_light,stormglass_orb,war_maul,monks_wraps,crimson_draught,smoke_bomb,pitch_firebomb`. `ECO03 NATIVE DRY RUN: PASS` in `native-dry-final.log`. The engine reported one resource at exit. |

The Python default group finished with `Ran 196 tests in 40.229s` and `OK` in `python-handoff.log`. One run under parallel load failed the runner cancellation test with `Child did not start`. The retry passed all 23 modules. The runner printed a permission error when saving learned timings to read-only Git metadata.

The check-only command against the main test entry triggered the runner's automatic cache import and was stopped. A standalone headless load printed `ECO03 GODOT MAIN ENTRY LOAD: PASS` in `main-entry-load-final.log`. Git status showed only the listed unit files.

The existing revision-7 suite also contains a check that hard-codes revision 7 for new runs. The focused wrapper runs its generation and compatibility checks. The design owner can update the version-specific expectation in `tests/suites/section_map_v7_suite.gd` at integration.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/eco-03 && tools/eco03/native.sh
```

This opens the real RunScene Scavenger at 1920 × 1080, 100% UI scale, with `LABYRINTH_CEL_LOOK=all`. The visual runner validates the PNG named `section_1_scavenger.png` under its isolated `user://eco03/` and prints its absolute path. Its result manifest is `.godot/eco03/native_manifest.json`.

## Chosen defaults

- Measurement seeds 1–1,000 and bot seeds 1–100. Release save seed 83. Stock sweeps use seeds 1–500 and fixture room coordinates `(depth, seed % depth)` for depths 1–15.
- Percentiles use nearest rank. Path ties use the earliest room and then map lane order. The native fixture uses the lowest seed at the measured median wallet whose stock changed. The capture waits 0.65 seconds for the scene to settle.
- Godot budgets were 600 seconds for the stock sweep and 900 seconds per final map and bot shard. The bot uses the existing ladder best-draft, combat, and forced-victory policy on the measured Section I route, with Reach Exit directed to the exit on that route.

No `TODO_DESIGN_*` placeholders.
