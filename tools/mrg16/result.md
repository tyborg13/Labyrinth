# Candidate 5 integration

The six approved tips are composed in the working files of `codex/mrg-16` at `76aac505b`. The director owns the six merge commits, the gear commit, inspection and publication. [Complete working-file inventory](/private/tmp/labyrinth_codex/mrg-16/files.txt)

## 1. Merge order

| Step | Pinned tip | Requested merge subject |
| --- | --- | --- |
| 1 | `35421baad` | `Merge codex/fx-36 (owner approved chain-lightning-bolt)` |
| 2 | `3d1440d3b` | `Merge codex/fx-35 (owner approved shadow-pool-smaller)` |
| 3 | `3ec14fd87` | `Merge codex/txt-26 (owner approved relic-truth-txt26)` |
| 4 | `35b683909` | `Merge codex/txt-27 (owner approved skills-events-truth-txt27)` |
| 5 | `b966ccdeb` | `Merge codex/txt-28 (owner approved card-truth-txt28)` |
| 6 | `a3f0e70d9` | `Merge codex/txt-30 (owner approved ui-truth-txt30)` |

`MRG-16 APPROVED ANCESTRY: PASS (37 incoming commits, 0 excluded subjects)`. The range `76aac505b..HEAD` is empty in this uncommitted worktree. [Incoming ancestry](/private/tmp/labyrinth_codex/mrg-16/approved-ancestry.txt)

## 2. Conflict resolutions

| File | Resolution |
| --- | --- |
| `scripts/combat_board_view.gd` | Kept candidate 4's Blink preview and retained live transits. Took the FX removals of the procedural attack painters and kept the approved force preview wash. The FX line retired the sprite helper also called by candidate 4's reflected Root Snare. Restored that path using the existing approved raster atlas, anchors, shadow and glow. The atlas-missing diamond fallback stays removed. |
| `scripts/run_scene.gd` | Kept the FX adapter's Area contact tracing and the FX-29 Refraction sweep with its existing reservation and fallback. After publishing the board snapshot, runs the retained Blink transit and the chain callback. Collapsed the duplicate `ShotFx` import. Kept TXT-26's relic offer `fit_content = true`. |
| `scripts/shot_fx.gd` | Kept the FX flight and ground-path selectors, ranged Area centre, and chain anchors alongside candidate 4's reflected descriptor, returns, Hook guard and Refraction adapter. Kept candidate 4's direct Noctyrax breath-marker guard on generic shot selection. |
| `tests/approved_asset_pins.json` | Applied the FX-36 line's atlas pins, then FX-35's seven rebaked tile-burst pins. The candidate 4 shot atlas bytes remain in the manifest. |
| `scripts/combat_engine.gd` | TXT-26, TXT-27 and TXT-28 compose in separate hunks. Kept all three, including the resolver and shared-preview changes. |
| `data/card_faces.json`, `data/cards.json`, `data/glossary.json` and `data/grimoire.json` | Separate TXT changes in the same files touched disjoint entries. The data audit checked every approved edit against the composed data. |

Two small integration fixes are included with the responsible merge content. `scripts/section_map_panel.gd` now goes directly through Pre-Battle's objective description accessor for legacy combat rooms. This uses its existing fallback behavior for missing types and removes TXT-30's fallback placeholder. `tests/fixtures/txt20_battlefield_copy.json` now expects TXT-27's exact approved “up to 3 tiles” Noctyrax sentence. The older exact-copy expectation caused four failures in the candidate 4 effects suites on the combined tree. [Data, pins and provenance audit](/private/tmp/labyrinth_codex/mrg-16/logs/integration-audit.log)

## 3. Gear fade

The requested gear change is in `scripts/run_scene.gd` and `scripts/combat_board_view.gd`. RunScene submits only the fade progress and a snapshot of the existing pickup pose. The pickup draws at that pose at opacity `1 - progress`. The fully transparent frame draws no pickup. The original eleven 45 ms samples, resolved-state hold, salvage filtering, sound path and “Unclaimed gear crumbles into dust.” notice are preserved.

The adapted FX-34 verifier keeps its archived exact-base timing, loot, notice and contact comparisons. It checks zero Fire floor stamps and replaces the old tint/rise receipt with checks on the production draw commands. These cover full opacity to no draw, neutral RGB, fixed bounds and exactly one texture at all nonzero opacities. The existing conduction, visibility, depth and reduced-motion checks run unchanged. [FX-34 log](/private/tmp/labyrinth_codex/mrg-16/logs/fx34.log) · [Gear draw receipt](/private/tmp/labyrinth_codex/mrg-16/headless.aWLaFV/gear-fade/take.json)

## 4. Export and pins

The six presets each have 45 include patterns. These are the explicit data entries in every preset.

| Scope | Data files |
| --- | --- |
| Candidate 4 effect catalogs | `data/tooltip_loops.json`, `data/tile_bursts.json`, `data/self_bursts.json`, `data/shots.json`, `data/strikes.json`, `data/acquisition_bursts.json`, `data/ground_fx_atlas.json`, `data/ground_surface_style.json` |
| New effect and text inputs | `data/chain_bolt.json`, `data/battlefield_rules.json`, `data/card_faces.json`, `data/card_panel_text.json`, `data/cards.json`, `data/events.json`, `data/glossary.json`, `data/grimoire.json`, `data/opening_boons.json`, `data/pattern_rule_text.json`, `data/relics.json`, `data/special_encounters.json` |

The 4,407-path pin union matches the installed bytes. Across the approved source trees, the seven tile-burst disagreements use FX-35's final PNGs. The seven shot-atlas disagreements with the older TXT bases use the FX-23/candidate 4 bytes shared by the FX tips. The existing density registry has the complete union, including the excluded ground-effect entries. The nine provenance files already contain the union, including candidate 4's ground and acquisition entries. [Exact hashes](/private/tmp/labyrinth_codex/mrg-16/logs/integration-audit.log)

| FX-35 sheet | Git blob hash |
| --- | --- |
| `tile_burst_44.png` | `328d7ec61b80f0b0ef498590a76d20f9ca85a736` |
| `tile_burst_52.png` | `e6b5ffdda6e93ee6c540a07defb7e6b81c6d73d9` |
| `tile_burst_60.png` | `953d17bd21f222146fd417d81f2b28ec52bbf860` |
| `tile_burst_68.png` | `db402eda12afd1453c78b86b395611c9027c572e` |
| `tile_burst_76.png` | `1883a5a5ec2cdb434e86699b16689eedd342b66b` |
| `tile_burst_84.png` | `fd1cc53ec22b89c5b72e3d4b424233b749365807` |
| `tile_burst_92.png` | `350dc11958e5740102885e176ced9ed8b82d3be4` |

## 5. Verification

Headless game verifiers used `tools/godot_task_runner.py --task-id mrg-16 --stream`. The existing FX-36 effects import helper used its hard-coded FX-36 task ID for the initial source cache bootstrap. It imported the approved PNGs in a scratch project. [Logs](/private/tmp/labyrinth_codex/mrg-16/logs)

| Check | Observed result |
| --- | --- |
| FX-34 paired verifier and focused rules | `FX-34 VERIFY PASS (514 checks, 0 failures)` and `FX-34 FOCUSED PASS (879 checks, 0 failures)` |
| FX-35 Shadow | `FX-12 VERIFY: 120 checks, 0 failures` · `TEST RESULT: PASS` · `FX-35 TENDRIL CELLS CHANGED OUTSIDE FORMER POOL: 0 (includes hit motes)` · `FX-35 BAKE IDENTITY: PASS (27398800 non-Shadow palette-index bytes, 40 rows x 13 frames x 7 sizes, zero row shifts)` · `FX-35 POOL COUNT AND RAGGEDNESS: PASS` |
| FX-36 chain bolt | `FX-36 VERIFY PASS (621 checks, 0 failures)` |
| TXT-26 relic truth and resolver suites | `TXT26 truth probe PASS: 18 rerun cases matched, 0 failed` · `TXT26 forecast comparisons: 45 resolver, 43 held-card` · `TXT26 focused suites PASS: 7579 checks, 0 failures` |
| TXT-27 rules and events | `TXT27 WITNESSES: 43 passed, 1 failed` on both the approved commit and candidate 5. `TXT27 FOCUSED SUITES: 3885 checks, 0 failures` and `TXT27 FOCUSED SUITES: 87452 checks, 0 failures`. The approved Fade wording and fallback independently pass `MRG-16 STA01 exact Fade copy and mechanics: 42 checks, 0 failures`. |
| TXT-28 card truth | `TXT28 WITNESS RESULT: PASS (54 witnesses, 0 failures)` · `TXT28 RULES SUITES: PASS (656 checks, 0 failures)` · `TXT28 COPY: PASS (15 director edits, 9 card articles, 305 cards scanned, both new panel templates)` |
| TXT-30 UI truth | `TXT30 WITNESSES: 4 true, 0 failed` · `TXT30 DRY RUN after 1280x800: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)` · `Section map v2 suite: 0 failures (seeds 0..32 x 6 sections)` · `INT11 INTEGRATION: PASS (407 checks; 0 failures)` · `CARD SUMMARY FIT UNIT RESULT: PASS (28 checks, 0 failures)` · `PRE-BATTLE VIEW TEST: PASS` · `RUN END RECAP TEST RESULT: PASS` |
| Shared rules and text | `LIGHT AND VISION RULES: 75 checks, 0 failures` · `Dragon rewards, gifts, wallet recovery and relic hooks passed.` · `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` · `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7758 panels, 15745 checks, 0 failures)` · `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` |
| Candidate 4 Mirror, hits and acquisition | `GFIX-34 VERIFY: 308 checks, 0 failures` · `MRG-15 REFLECTION VERIFY: 68 checks, 0 failures` · `FX-17 VERIFY: 132 checks, 0 failures` · `FX-20 VERIFY: PASS (172 checks, 0 failures)` · `FX-20 VERIFY: PASS (3392 checks, 0 failures)` · `FX-29 VERIFY: 4258 checks, 0 failures` · `FND-01 VERIFY: 111 checks, 0 failures` · `FND-02 VERIFY AFTER: 194 checks, 0 failures` · `FND-03 VERIFY AFTER: 352 checks, 0 failures` |
| Candidate 4 shot playback and art | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1998 checks, 0 failures)` · `MRG-16 SHOT ATLAS IDENTITY: PASS (7/7 candidate 4 PNGs, sizes, region geometry and palette)` · `FX-23 VERIFY: FAIL (258 checks, 7 failures)` |
| Pack and pins | `MRG-16 EXPORT FILTERS: PASS (6/6 presets)` · `CEL_PACK_TEST paths=3089 failures=0` · `MRG-16 PCK: PASS (20/20 data files, 48/48 sheets)` · `Ran 1 test in 14.004s` · `OK` for `tests/test_approved_content_manifest.py` |
| UI identity, rules lint and Python default | `Ran 25 tests in 6.358s` · `OK` · `PASS: Rules text lint (16 existing hits)` · `ISOLATION AUDIT: 59 modules` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 38.113s` · `OK` |
| Static | `git diff --check` exited 0. Three new GDScript proof sources have UID sidecars. No Python test modules were added. |

FX-23's seven historical failures cover procedural Ice, Air and Earth Area flights, two legacy contact-set assertions on Fire Area and Chain, and two assertions that Scatter Shot's displaced target uses a floor row even when that target lost Health. The approved FX line uses baked Area flights, contact stamps and loss-based rows. The raw historical assertions are intact. The original shot pixel utility also expects the old enemy-to-shot mapping, so the candidate 4 identity check above compares the seven PNGs, geometry and palette directly. Stage-only updates supply retired dependencies to the historical FX proof comparators. The previous standalone mrg-15 brief path is absent in this checkout. Its implementation record and checked-in proof tools supplied the comparison recipe. [FX-23 log](/private/tmp/labyrinth_codex/mrg-16/logs/fx23-replayed.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-16 && LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/mrg-16/native.sh
```

The launcher runs the visual probe runner and prints the PNG paths or their containing folders. Every full frame uses an exact 1920×1080 SubViewport at 100% UI scale. The output root is `/private/tmp/labyrinth_codex/mrg-16/native.*`.

| Output folder | Native evidence |
| --- | --- |
| `fx36/{chain_bolt,storm_relay,capacitor}` | Full contact frames, timed crop columns and 2× contact details |
| `fx35/after/{area_ranged,closing_shade}` | Contact strips, full evidence PNGs, 2× details and clips |
| `fx34/conduction` | Spark Dart floor conduction strip and full contact frame |
| `gear-fade` | `fade-{000,025,050,075,100}.png`, `strip.png`, `tile-2x.png` and draw receipt |
| `txt26/{director,edited}`, `txt27`, `txt28`, `txt30` | Existing approved text and layout probes at the brief's exact resolution |

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-16 && /private/tmp/labyrinth_codex/mrg-16/native.sh --dry-run
```

The dry run printed `MRG-16 NATIVE DRY RUN PASS`. It also printed `FX-35 NATIVE DRY RUN: PASS (2 before/after pairs)`, `MRG-16 GEAR CAPTURE PLAN PASS (5 opacity samples, 0 failures)`, `TXT26 text fit PASS: 6 offer layouts, 0 checked relic surface sets`, `TXT26 text fit PASS: 18 offer layouts, 16 checked relic surface sets`, `TXT27 HEADLESS LAYOUT 1920x1080: 20 surfaces, 0 failures.`, `TXT28 DRY RUN after 1920x1080: PASS (20 inspections, 0 PNGs, 0 failures)` and `TXT30 DRY RUN after 1920x1080: PASS (5 cards, 2 captions, 0 PNGs, 0 failures)`. [Dry-run log](/private/tmp/labyrinth_codex/mrg-16/logs/native-dry.log) · [Headless receipts](/private/tmp/labyrinth_codex/mrg-16/headless.aWLaFV)

## Chosen defaults

- The gear probe reuses the approved FX-34 Ward Kite victory and framing. Its proof strip crops a 320×240 region centred on the tile. It enlarges the 50% crop 2× with nearest-neighbour sampling. The renderer takes exact opacity fractions from the same live victory snapshot while the timing verifier separately checks each of the eleven authored samples.
- The launcher inherits the fixed 60 Hz FX clock and 64×64 MovieWriter host and uses the existing 300-second native timeout.

## TODO_DESIGN and open issues

- Candidate 5 introduces no design placeholders in production. The approved TXT-27 and TXT-28 proof tools retain `TODO_DESIGN_ashen_reaver_prebattle_rule_placement` and `TODO_DESIGN_grapple_terrain`. Those record independent director decisions on pre-battle Wildfire placement and Grapple's terrain scope.
- The approved FX-35 footprint width measurement still says `FX-35 WIDTH TARGET: 0/14 within 45–55%`. The pinned rebake, pixel identity and native take plans passed.
- The pinned TXT-27 Fade witness and the FX-23 historical assertions listed above remain open. The read-only Git metadata denied the Python timing-cache update after the default group passed. Headless Godot also emitted the existing macOS certificate and resource teardown diagnostics.
- The six merge commits and the gear commit are pending the director's Git work. Windowed PNGs, visual inspection and publication remain pending on the director's desktop.
