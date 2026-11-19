# QA-113 release-candidate hunt

Release under test is `2f24e9c65`. The worktree HEAD `fbafb4c6b` adds the owner-provided hunt drivers. The comparison baseline is `047c5848f`. The local `codex/release` ref advanced to `07e5c9a55` during the hunt, while all gameplay and layout receipts stayed on the pinned candidate. This report tracks campaign outcomes, focused receipts, and native checks for the design owner. Product code, scenes, data, and assets are untouched.

## Findings

| Severity | Fixture and exact repro | Root cause | Fix size | On master `047c5848f` |
| --- | --- | --- | --- | --- |
| S1 | **An existing red intent footprint is removed.** Seed 101003, section index 0, room `(2, -2)`, decision 102. Confirm Whirlwind Slash, then Walk to `(2, 5)`. The tile loses its red warning while its live intent still owns the tile. Reproduce with the default campaign command and `--seed 101003 --runs 1 --processes 1 --stop-after 103`. A second witness at seed 101014, decision 1088, selects Whirlwind Slash in room `(9, -8)` and loses the warning at `(4, 3)`. The candidate replay attributes that case to the selected-card forecast's `died_first` entry for `enemy_1`. [Aiming replay](out/red-recheck/seed-101014/trace.jsonl) · [Decision trace](out/default/seed-101003/trace.jsonl) · [Settled witness](out/default/seed-101003/102-run-red-tile_set.still.json) | The stage paint applies a future Pass result to present-board intent geometry. The adjustment omits a threat when that enemy is predicted to die before acting. [Stage apply](../../scripts/stage_hover_refresh.gd#L47) · [Threat filtering](../../scripts/pass_forecast_red_tiles.gd#L107) | Small to medium. Separate current-board tile ownership from the full-phase forecast's repeats and losses. | **Yes.** QA-110 reproduced the same seed and input at this baseline. [Matched witness](../qa110/REPORT.md#findings) |
| S1 | **An announced Tharokh footprint is replaced.** Fixture `tharokh-mouse-pass_with_loop`, seed 7262026. Open Haft Shove's tooltip and click Pass. At settled turn 2, red includes `(6, 3)`, `(6, 4)`, `(6, 5)` and `(3, 4)`. The fresh current-board calculation includes `(2, 5)`, `(5, 3)` and `(5, 4)` instead. [Path receipt](out/targeted/pass-with-loop/godot.log) | The same Pass correction replaces an announced stamp with its later sequential footprint. [Stamp replacement](../../scripts/pass_forecast_red_tiles.gd#L115) | Same small to medium change as the prior row. | **Yes.** QA-110 reproduced it at this baseline. [Matched witness](../qa110/REPORT.md#findings) |
| S2 | **The held-layout Undo reserve falls short of 8 backing pixels on Deck.** Seed 83, `reach_exit/held_undo`. Load Reach the Exit at 1280×800 and 115% UI scale, establish the existing hand-layout hold, then make a reversible Walk. Undo is visible with 8 canvas units of clearance, which scales to 6.133 px. The opening-intro route measured 45.852 px. [Held witness](out/recheck/reach-exit-held_undo/godot.log) · [Opening witness](out/recheck/reach-exit-undo/godot.log) | The dock subtracts a fixed canvas-space constant from the logical viewport bottom. [Constant](../../scripts/run_scene.gd#L1049) · [Reserve calculation](../../scripts/run_scene.gd#L12440) | Small unit conversion at the reserve clamp. | **Yes, worse.** The same held fixture put the bottom 23.522 backing pixels below the viewport on master. [Matched Deck witness](out/recheck/master-held-undo/godot.log) |
| S3 | **Mechanic names still have lowercase occurrences in the Grimoire.** Open Targeting to paragraph 2 and Chainbound Gaoler to paragraph 2. The text says “Push and pull resolve forced movement” and “intents use forced movement and immobilize.” Audit locations for all lexical candidates are in `qa113-findings.tsv`. | [Targeting](../../data/grimoire.json#L194) · [Chainbound Gaoler](../../data/grimoire.json#L749) | Local copy edits after reviewing ambiguous common-word matches. | **Yes.** Both paragraphs match in master. |
| S3 | **Relic glossary reports overflow during the treasure reveal in the headless campaign.** Seed 101009, decision 644. From the Scavenger, enter treasure at `(6, 2)`, which opens Siege Ram Totem. The block ends at y=1952 in the 1920-high study viewport. Native visibility is pending. [Stack and trace](out/default/seed-101009/godot.log#L1324) | The above-row fallback detects that the block crosses the bottom limit and still places it at that origin. [Overflow check](../../scripts/card_focus_tooltip_stack.gd#L330) | Small if confirmed with native geometry. | **Yes.** Master reproduced the identical bounds at the same choice. [Matched witness](out/master-glossary/godot.log#L1352) |
| S3 | **Campaign attached-node census grew between section entrances.** At the entrance to section index 5 in room `(-20, 0)`, seed 101013 decision 2428 measured 2,773 against 1,639 at the first entrance. Seed 101014 decision 2669 measured 2,933 against 1,643. Teardown has no ObjectDB or resource diagnostic. [Campaign log](out/no-embrace-101013/seed-101013/godot.log) | The QA log compares scene-tree totals across two different route/visual states. The total provides no production-node attribution. [Census threshold](../../tools/run_hunt.gd#L524) | Unscoped without a matched live-node ownership census. | Growth appeared in earlier QA campaigns. This deep route was measured on the candidate. |
| S3 | **Windows typed-array hazard in the supplied QA fixture.** Run `python3 tools/qa105/typed_array_scan.py --base codex/release`. The original fixture passes a bare array as `bleed_steps`. | [QA-101 Expose probe](../qa101/expose_probe.gd#L121) | One typed temporary or helper call in the fixture. | **No.** The supplied file was added at `fbafb4c6b`. |
| S3 | **macOS certificate lookup diagnostic.** Start the campaign with seed 101001. Godot emits `ERROR: Condition "ret != noErr" is true. Returning: ""` before the first scene. | Godot `platform/macos/os_macos.mm:1014`, `get_system_ca_certificates`. The hunt records the startup message before gameplay. [Raw log](out/default/seed-101001/godot.log) | Environment or engine investigation. | **Yes.** The staged master focus probe emits the same engine diagnostic at startup. [Master log](out/recheck/master-focus/godot.log) |

The legacy QA-110 hand oracle also reported `slot_offset` with the candidate. Seed 101001, decision 12, enters combat with Pale Spark in slot 0 at +8.77 px relative to that oracle. The oracle uses the pre-budget pose at [model.gd](../qa110/model.gd#L29), and production adds the approved centre and stride adjustment at [hand_fan_container.gd](../../scripts/hand_fan_container.gd#L350). Treat those flags as a measurement mismatch. The separate hand-matrix receipt tests the release fan with the adjustment applied.

## Coverage

The campaign uses the QA-101 scene route policy and QA-110 settled-state census. All 12 runs reached a terminal screen and exited 0. The raw scan found zero gameplay script errors, freed-object accesses, native crash markers, softlocks, or ObjectDB/resource shutdown warnings. The seed logs retain the startup certificate diagnostics and the growth/overflow signals. [Default campaign](out/default/report.md) · [Deep 101013](out/no-embrace-101013/report.md) · [Deep 101014](out/no-embrace-101014/report.md) · [Combined coverage](out/coverage.json)

| Lane | Outcome | Decisions | Settled samples | Room visits |
| --- | --- | ---: | ---: | ---: |
| Default seeds 101001–101010 | 10 Embrace | 3,251 | 3,261 | 112 |
| No Embrace, seed 101013 | Victory | 2,944 | 2,945 | 72 |
| No Embrace, seed 101014 | Victory | 3,083 | 3,084 | 72 |
| Total | 12 terminal | 9,278 | 9,290 | 256 |

The QA-110 checks found no alpha, lifetime, hover-ring, turn-order, tooltip ownership, targeting or displayed-vs-fresh Pass divergences at applicable boundaries. The red check flagged 58 boundaries and the legacy hand pose oracle flagged 37,633 slot offsets. Every decision settled within the watchdog. The separate hand matrix exercised the fitted production poses.

The two no-Embrace runs supplied **255/255 manual Pass receipts**. The totals matched in all **209 fully disclosed comparisons**, with 46 uncertainty receipts. The default runs supplied 109 manual Pass inputs and their decision-boundary consistency checks. The committed-phase comparison for default used the checkpoint sample below. Forecast comparisons keep independent committed-phase receipts and distinguish incomplete disclosure from a mismatch. Three terminal Pass receipts in seed 101013 lost their live combat state when the room moved to rewards. In seed 101014, decision 2305, the post-reward state showed 9,807 Health against the phase result of 9,805. The live `combat_ended` event recorded 9,805 and `reward_offered` recorded the subsequent +2 dawn heal. The three cleared states also agree with the live combat-end Health analytics. [Dawn reward call](../../scripts/run_engine.gd#L1353) · [Seed 101014 analytics](out/no-embrace-101014/seed-101014/analytics/events-2026-11-19.jsonl)

The default lane also contributed 23 combat saves from the live collector. The QA-103 committed-phase replay restored 19 and skipped four whose Continue advanced the checkpoint. It sampled 19 Pass and 12 Walk forecasts. Eleven Pass and nine Walk forecasts were fully scored. Loss totals matched in those 20 positions. Four raw intent-plate discrepancies come from two later enemy hits at the same save, seed 101009, collection decision 767 in Quiet Antechamber, turn 2, at rest and from Walk `(4, 2)`. These comparisons use full-phase contact against present-board plate color. [Audit](out/checkpoint-audit/audit.json) · [Foreground and committed receipts](out/checkpoint-audit/forecasts.json)

Headless geometry reports record actual displayed labels, line fit and HUD positions. The native capture and physical window-focus checks are listed under [Proof for the design owner](README.md#proof-for-the-design-owner). The sandbox has no window server.

### Targeted matrix

| Area | Headless verdict and coverage |
| --- | --- |
| Rule heights and exact copy | Clean for all 35 rule states per profile. Both profiles produced all-caps objective intro and docked headings, plus the real Tharokh pre-battle `LEADER` badge. Five rising-Outcrop sentences include base Tharokh and its half-Health variant. The JSONL and log retain each exact sentence, height, allocated width and visible/total line count. |
| Undo | **The held-layout fixture misses the 8 px margin.** Two actual reversible walks opened Undo on Deck. Opening-intro geometry provided 45.852 px, and the held layout provided 6.133 px. The staged history sweep verified Undo visibility throughout the rule catalog. |
| Boss hands | All 40 settled layouts passed the shape and HUD checks. The same-count fan anchor shift measured 0.000 during each select and cancel. A real Brace play and the next Pass/draw established the settled five- and seven-card layouts. Tharokh's desktop fit can move its target anchor when the hand count changes. Native motion inspection is pending. |
| Sounds | Clean for one-shot routing and source length. All eight cues started one voice per trigger in two invocations apiece. The Illusion spawn voice uses the existing contact-alignment cut, producing 0.93630–0.93646 s of PCM from its approved 0.950 s asset before pitch is applied. The dragon roar asset and cue row are byte-identical to master. [Playback receipts](out/recheck/sounds/godot.log) |
| Tooltip lifetime | Clean for 215/215 open/close cycles across 43 routes. The probe exercised all 29 registered source surfaces, seven Grimoire navigation entries and seven Grimoire card previews. Each cycle decoded a frame, held one lease for the target asset, and retired the player and lease on close. After the release grace period there were zero stream entries and zero loop owners. [Lifetime log](out/targeted/loops/godot.log) |
| Focus loss | Clean for 15 simulated interruption paths across five rooms. Five held mouse drags lost focus, another five received application pause, and five controller aims got focus loss. The matching master mouse fixture left the drag and proxy active and the source slot hidden. Native focus remains pending. [Master reproduction](out/recheck/master-focus/godot.log) |
| Text | **Residual case findings.** QA-112 reran 28 scene fixtures, the runtime formatter catalog, and every authored event at two profiles. No `HP`, `foe`, or curly quotation marks appeared in the observed and formatted text sample. The literal ` foes` is an input to the existing Chronicle migration replacement. 247 parsed spaces belong to RichText inline-icon positions in event previews and results. There are no authored or non-icon formatted double-space hits in the scan. The per-location ledger retains 1,486 lowercase glossary/resource matches across all sources and fixtures. It includes ordinary uses such as physical “fire” and status/keyword uses such as the Grimoire examples in the findings. |

Rule and hand geometry receipts are in `out/targeted/{rules,hands}-{desktop,deck}/`. Text receipts are in [the QA-112 inventory](out/targeted/text/inventory.tsv) and [the QA-113 findings ledger](out/targeted/text/qa113-findings.tsv). The first sound probe compared decoded PCM directly with the source duration. It flagged both aligned Illusion spawn voices and logged ObjectDB plus 14 resources at teardown. The recheck measured the source and alignment cut separately and drained the fixture's active audio voices before teardown. Its final log contains no ObjectDB or resource warning. The text scene probe's isolated `observations.json` path is printed in [its log](out/targeted/text-scenes/godot.log).

```text
RUN HUNT RESULT: started=10 finished=10 finding_groups=2
RUN HUNT SEED 101013: outcome=victory decisions=2944 findings=2
RUN HUNT SEED 101014: outcome=victory decisions=3083 findings=2
QA113 WHOLE RUNS: complete=12/12 decisions=9278 settled=9290
QA113 PASS: inputs=364 sampled=255 fully_disclosed=209 uncertain=46 missing_forecast=0 totals_mismatch=0 live_unavailable_terminal=3 live_health_mismatch=1
QA101 SCAN default: 10/10 terminal; outcomes={'embrace': 10}; markers={}; 0 softlocks
QA101 SCAN no-embrace-101013: 1/1 terminal; outcomes={'victory': 1}; markers={}; 0 softlocks
QA101 SCAN no-embrace-101014: 1/1 terminal; outcomes={'victory': 1}; markers={}; 0 softlocks
UI33 RESULT: profile=desktop cases=35 undo_passes=35 clipped=0 overlaps=0 offscreen=0 errors=0
UI33 RESULT: profile=deck cases=35 undo_passes=35 clipped=0 overlaps=0 offscreen=0 errors=0
QA113 LEADER: profile=desktop heading=LEADER
QA113 LEADER: profile=deck heading=LEADER
QA107 RESULT: PASS profile=desktop states=20 opened=0 candidates=0 errors=0
QA107 RESULT: PASS profile=deck states=20 opened=0 candidates=0 errors=0
QA110 INTERRUPTIONS cases=15 headless=true
QA103 RESULT interruptions.gd: PASS (0 failures)
QA113 SOUNDS: passed=16/16
QA103 RESULT sounds.gd: PASS (0 failures)
ERROR: QA107: reach_exit/held_undo: Undo margin 6.133 backing pixels, expected at least 8
QA113 LOOPS: routes=43 attempts=215 opened=215 released=215 owners=0 streams=0
TIP01 TOOLTIP QA113 LOOP LIFETIME: PASS (0 failures)
TEXT AUDIT CAPTURE HEADLESS VALIDATION RESULT: PASS (28 fixtures)
QA112 EVENT PAGES: 90 choice pages, 236 result pages
QA112 COPY EXPORT: 6141 records, 3 seeded combats, 1 Zekarion fixture
QA112 INVENTORY: 2677 data, 3138 source, 3652 formatted, 3583 observed
QA112 SCAN: 15942 matches across 432 class/check/variant rows
QA101 HUD: 31 samples from 23 entries, 4 skipped checkpoints, 0 failures
QA101 CHECKPOINT AUDIT: 20 scored, 11 uncertain, 4 raw mismatches (0 explained by rule movement), 4 skipped saves, 0 restore failures
TYPED ARRAY SCAN: 31 scripts; 1 new; 0 pre-existing
TYPED ARRAY SCAN: 23 scripts; 1 new; 0 pre-existing
QA113 WHOLE RUN PARSER EXIT: 0
```

## Defaults and scope

- QA fixtures and proof-only values include campaign seeds 101001–101010 and 101013–101014, existing QA-101 health and combat speed overrides, the fixed 120 Hz deep-run step, and the existing seed 83 layout fixtures. The hand probe uses a six-card starter hand with Brace in slot 1 and a 2 canvas-unit measurement tolerance. Proof uses the existing Desktop 100% and Deck 115% profiles.
- Tooltip lifetime uses five cycles per route and a two-second decoder witness bound. The audio fixture uses QA-111-style isolated trigger receipts, seed 410, 5-second virtual trigger spacing, and a ±2 ms length tolerance. The isolated sound fixture drains stopped voices for 0.1 seconds before teardown.
- No `TODO_DESIGN_*` placeholders or permanent tests were added. The design owner owns committing the files and running the merge suites.

## Proof for the design owner

[Exact windowed commands and output directories](README.md#proof-for-the-design-owner). Expected prefixes are `qa107-<profile>-*.png` for rules and hands, `qa113_loop_*.png` for tooltip routes, and the existing QA-110 focus and QA-112 text capture names. Native renders and physical focus changes remain pending on a window-server host.
