# area-02 feedback 1

**Implemented and verified headlessly.** The final natural truth audit has zero unexplained mismatches and zero Gusts blowing without a prior Pass snapshot. Changes remain uncommitted on `codex/area-02`; no peer review, publication, task-queue change or windowed run was performed.

## Director decisions

1. Gust retains global live occupants and freezes only direction. No tile footprint was added. The audit checks direction only.
2. A new/reaimed unannounced foes-turn Call saves `awaiting_pass` and invalidates any stale receipt. It emits no blow/event, consumes no finite blow, and waits for a hero turn and its Pass. Its existing field/red/direction presentation remains available immediately. Turn-order projection omits the deferred blow until that hero boundary. Already-announced first Calls and same-direction same-source reinstalls keep their receipt.
3. Upheaval builds its candidate set, then runs the existing route primitives as one ordered marking-time batch with cumulative accepted marks. Firing never rechecks routes. Impassable placement sites and occupants that the existing throw cannot move (including Anchored, multi-tile bodies and no landing) skip their tile. The safety solver tries the full raise first, then exact increasing-cardinality omissions to retain a hero neighbour, keeping existing mark order for ties. Every allowed skip has a categorized playback receipt; the audit saves exception reproductions.

Protected rule data, balance numbers, boss moves, art, sound and VFX timing are unchanged. The three round-0 TODO_DESIGN items have been removed. Existing unrelated prototype TODOs remain untouched. Analytics documentation and heuristic metadata describe the approved timing; no analytics event type was added.

## Focused proof

```text
ATK14 RULES RESULT: PASS (0 failures)
ATK03 FOCUSED RESULT: PASS (1792 assertions, 0 failures)
ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)
THREATS AT REST TEST RESULT: PASS (16970 assertions; includes compass suite)
ATK13 CAPTURE area02-upheaval: PASS
ATK13 CAPTURE area02-gust: PASS
AREA02 F1 SAFETY AUDIT: PASS (1 classified skip; 0 unexplained; saved reproduction)
UI identity lint: Ran 25 tests; OK
```

No full suites ran. New permanent tests are confined to battlefield-rule suites. Existing tests that asserted firing-time route rejection now assert the director-approved marking-time guard. New focused cases cover unannounced first Calls/reaims, receipt invalidation, same-source reinstalls, immediate indicators, global live occupants, all three occupied-raise causes, impassability, and a synthetic minimum one-skip safety valve.

## Truth audit

`AREA02 TRUTH: PASS (26 instances; 1885 beats; 0 unexplained mismatches; 2 Cantor/Bell Tender exclusion witnesses)`

| Instance | Fights | Beats | Impassable tiles | Occupied-raise tiles | Safety-valve tiles | Gust without snapshot | Unexplained |
|---|---:|---:|---:|---:|---:|---:|---:|
| stormcaller | 3 | 149 | 0 | 0 | 0 | 0 | 0 |
| slagmaster | 3 | 100 | 0 | 0 | 0 | 0 | 0 |
| oracle | 3 | 116 | 0 | 0 | 0 | 0 | 0 |
| dynamo | 3 | 40 | 0 | 0 | 0 | 0 | 0 |
| thornmother | 3 | 103 | 25 | 3 | 0 | 0 | 0 |
| prior | 3 | 118 | 0 | 0 | 0 | 0 | 0 |
| snare_earth | 3 | 57 | 0 | 0 | 0 | 0 | 0 |
| snare_fire | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_air | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_ice | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_lightning | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_shadow | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| last_light | 3 | 8 | 0 | 0 | 0 | 0 | 0 |
| gale_herald | 3 | 93 | 0 | 0 | 0 | 0 | 0 |
| ashen_reaver | 3 | 7 | 0 | 0 | 0 | 0 | 0 |
| rimejaw | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| storm_cantor | 3 | 73 | 0 | 0 | 0 | 0 | 0 |
| gallows_roc | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| craghide | 3 | 105 | 4 | 0 | 0 | 0 | 0 |
| last_lamplighter | 3 | 72 | 0 | 0 | 0 | 0 | 0 |
| vyraketh | 3 | 15 | 0 | 0 | 0 | 0 | 0 |
| tharokh | 3 | 36 | 0 | 21 | 0 | 0 | 0 |
| iskaldra | 3 | 63 | 0 | 0 | 0 | 0 | 0 |
| vaeloryx | 3 | 135 | 0 | 0 | 0 | 0 | 0 |
| zekarion | 3 | 43 | 0 | 0 | 0 | 0 | 0 |
| noctyrax | 3 | 48 | 0 | 0 | 0 | 0 | 0 |

Totals: 29 impassable, 24 occupied-raise, 0 safety-valve skips; 0 unexplained. Counts are tiles, not beats. Natural safety skips were zero. A separate synthetic safety audit proves one classified minimum skip with zero unexplained differences and writes an exact reproduction under `/private/tmp/labyrinth_codex/area-02/f1/repro/synthetic_safety-0-0`. Every natural exception has `pass.txt`, `before.txt`, `after.txt` and `exceptions.json` under `/private/tmp/labyrinth_codex/area-02/f1/truth/repro/`. The complete receipts and per-instance commands/exits are under `/private/tmp/labyrinth_codex/area-02/f1/truth/`.

## Round 0 cause classification

The instrumented round-0 engine reproduced all 50 original mismatch records exactly, including instance, seed, clock and complete expected/actual tile sets. **49 were route-safety beat differences; 1 was occupied-raise.** These represented 52 route-blocked tiles and 1 occupied tile. No original assertion or mismatch was discarded.

| Instance | Route-safety beat differences | Occupied-raise beat differences |
|---|---:|---:|
| thornmother | 4 | 1 |
| snare_earth | 1 | 0 |
| craghide | 39 | 0 |
| tharokh | 5 | 0 |

Classifications: `/private/tmp/labyrinth_codex/area-02/f1/round0-causes.json`; instrumented receipts: `round0-classification/summary.json`; exact saved boards: `round0-repro/`. Instrumentation lives only in the temporary round-0 audit project. The before difficulty project retains the unmodified round-0 runtime.

## Difficulty: only Gust and Upheaval

Natural revision-7 tier-3 fights with unchanged committed policy v2 and decks, N=64 per instance before/after. Completed checkpoint prefixes are validated against seed, tier, section, room coordinate and entrance before resuming. Frozen runtime contracts are checked; all sample keys must match. No other rule’s difficulty fights were rerun and no numbers were tuned. A final Snare sealed-threshold correction changed only the Upheaval helper: all four after Upheaval cells restarted from zero; the unchanged Gust checkpoints were retained. The earlier Gust runtime hash is preserved in `after-gust-contract.json`, and the archived earlier helper is under `after-up-before-sealed-fix/`.

| Instance | Before wins | After wins | Change | Mean turns before → after | Mean HP lost before → after |
|---|---:|---:|---:|---:|---:|
| stormcaller | 31/64 | 30/64 | -1.56 pp | 8.88 → 8.89 | 18.52 → 18.20 |
| snare_air | 44/64 | 44/64 | +0.00 pp | 3.20 → 3.20 | 12.05 → 12.05 |
| gale_herald | 36/64 | 35/64 | -1.56 pp | 8.84 → 9.17 | 18.19 → 17.75 |
| gallows_roc | 24/64 | 24/64 | +0.00 pp | 4.48 → 4.48 | 21.33 → 21.33 |
| vaeloryx | 29/64 | 29/64 | +0.00 pp | 4.61 → 4.61 | 21.22 → 21.22 |
| thornmother | 17/64 | 21/64 | +6.25 pp | 18.34 → 17.81 | 17.58 → 17.05 |
| snare_earth | 58/64 | 58/64 | +0.00 pp | 4.34 → 4.34 | 6.84 → 6.84 |
| craghide | 39/64 | 40/64 | +1.56 pp | 6.03 → 6.12 | 17.88 → 17.86 |
| tharokh | 39/64 | 37/64 | -3.12 pp | 11.78 → 11.09 | 17.03 → 18.33 |

AREA02 F1 DIFFICULTY: PASS (1152 completed fights; 9 matched instances; N=64 before/after). All final cell processes exited 0. Raw reports, commands and costs: `/private/tmp/labyrinth_codex/area-02/f1/ladder`.

## Proof for the design owner

No native renderer run was attempted. Headless captures validate production playback semantics only and emit JSON sidecars, not PNGs. Run the original Cantor/Wildfire proof, then the new Upheaval/Gust cases:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && sh tools/area02/native_proof.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && sh tools/area02/native_feedback1.sh upheaval
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && sh tools/area02/native_feedback1.sh gust
```

The added native commands can also be run separately:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && LABYRINTH_TASK_ID=area-02 ATK13_CAPTURE_SCRIPT=res://tools/area02/capture.gd ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/area-02/captures ATK13_PROOF_CONTRACT=tools/area02/upheaval_contract.json sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/area-02/f1/truth/fixtures/craghide area02 upheaval --case upheaval
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && LABYRINTH_TASK_ID=area-02 ATK13_CAPTURE_SCRIPT=res://tools/area02/capture.gd ATK13_CAPTURE_OUT=/private/tmp/labyrinth_codex/area-02/captures ATK13_PROOF_CONTRACT=tools/area02/gust_contract.json sh tools/atk13/native_capture.sh /private/tmp/labyrinth_codex/area-02/f1/truth/fixtures/gallows_roc area02 gust --case gust
```

These use the visual-probe runner with cel look, 1920×1080, 100% UI scale and the existing production presentation. Planned added PNGs: `/private/tmp/labyrinth_codex/area-02/captures/upheaval_pass.png`, `upheaval_rise.png`, `gust_pass.png`, `gust_blow.png`, with `upheaval.manifest.json` and `gust.manifest.json`. Headless sidecars are under `/private/tmp/labyrinth_codex/area-02/f1/headless-captures`. No inspection-fixture command was requested; the owner retains fixture packaging and visual inspection.

## Chosen defaults

The round-0 natural truth controller is unchanged: 3 fights per instance, tier 3, seed scan from 1, proof Health 9999, maximum 24 hero activations, spent Time 24 (Cantor 96), deterministic movement probability 0.75. Difficulty remains N=64 with the existing 24-Health policy-v2 presets. Collection uses 5 workers and validated checkpoints; the existing runner limits remain 14,400 seconds per ladder cell and 1,800 per truth cell. Synthetic safety/occupancy data use the existing fixed-board fixture and named test fields. Native timing/layout values are reused. No production tuning default was selected.

## Open issues

Native pixels/independent visual inspection, commit, peer review, inspection-fixture packaging and publication remain the design owner’s steps. There are no unexplained truth mismatches or unresolved round-0 TODO_DESIGN items.

## Files in the uncommitted unit

- `scripts/battlefield_rule_view.gd`
- `scripts/battlefield_rules/analytics.gd`
- `scripts/battlefield_rules/dispatcher.gd`
- `scripts/battlefield_rules/frostbite.gd`
- `scripts/battlefield_rules/fuel.gd`
- `scripts/battlefield_rules/gust.gd`
- `scripts/battlefield_rules/hit.gd`
- `scripts/battlefield_rules/lightning_storm.gd`
- `scripts/battlefield_rules/outcomes.gd`
- `scripts/battlefield_rules/playback.gd`
- `scripts/battlefield_rules/snapshot.gd`
- `scripts/battlefield_rules/upheaval.gd`
- `scripts/battlefield_rules/upheaval_rise.gd`
- `scripts/battlefield_rules/wildfire.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/snare_pressure_view.gd`
- `spec/analytics.md`
- `spec/card_balance_heuristic.md`
- `tests/suites/battlefield_conduction_suite.gd`
- `tests/suites/battlefield_fuel_suite.gd`
- `tests/suites/battlefield_rules_suite.gd`
- `tests/suites/battlefield_snapshot_feedback_suite.gd`
- `tests/suites/bos01_feedback1_suite.gd`
- `tests/suites/bos01_rules_suite.gd`
- `tools/area02/FEEDBACK_1.md`
- `tools/area02/REPORT.md`
- `tools/area02/cantor_contract.json`
- `tools/area02/capture.gd`
- `tools/area02/gust_contract.json`
- `tools/area02/native_feedback1.sh`
- `tools/area02/native_proof.sh`
- `tools/area02/report.py`
- `tools/area02/report_feedback1.py`
- `tools/area02/safety_audit.gd`
- `tools/area02/upheaval_contract.json`
- `tools/area02/wildfire_contract.json`
- `tools/atk13/rule_audit.gd`
- `tools/atk13/rule_audit.py`
- `tools/atk13/rule_cases.gd`
- `tools/atk13/rule_ladder.gd`
- `tools/atk13/rule_ladder.py`
- `tools/atk13/rule_ladder_provenance.gd`
- `tools/atk13/rule_observer.gd`
- `tools/card_heuristic.py`
