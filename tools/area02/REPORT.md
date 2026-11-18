**Current status:** [Feedback 1](FEEDBACK_1.md) resolves the round-0 design TODOs and supersedes the open-acceptance status below. This file retains the round-0 evidence.

# area-02 implementation handoff

Changes are uncommitted on `codex/area-02`. No commit, peer review, signoff, publication, task-queue write or windowed run was performed. The design owner retains those phases. Owner data and assets are unchanged.

**Open acceptance:** the strict truth audit reports 64 differences. The three TODO_DESIGN decisions and native inspection remain open.

## Numbered requirements

1. **Implemented, with the design exceptions below:** Pass freezes geometry before activation-end effects; player fuel changes are immediate; occupants/passability remain live. Saved snapshots survive the foes phase and turn-start effects, then release for the next hero turn. Repeated completion does not recapture.
2. **Implemented with open design exceptions:** Storm, Wildfire and Frostbite use frozen tiles; Gust uses its frozen direction; Upheaval retains marks and its existing route/occupied-raise guards; Shadowstep retains live aim. The exact-red audit exposes the guarded-raise and unannounced-new-Call cases below.
3. **Implemented:** the protected owner data is read unchanged: Cantor 4; Zekarion 6/7; all four rule storms Chain 0. Half-Health dials merge, preserving Chain 0. Rows/arcs therefore disappear through the existing shared adapters. Player Chain remains covered by the focused Chain suite. No generic Chain code was deleted because the shared primitive/playback remains used.
4. **Implemented where specified; Gust scope and native pixels pending:** rest red is live all turn, and held geometry survives foes-phase action effects. The board cache gate is updated. Forecasts, hovered boards and lightning playback read the same snapshot. Existing art, timing, sound and input paths are reused. Gust affected-tile scope remains a design TODO.
5. **Implemented:** old hero-turn saves load without a snapshot and acquire one on the next Pass. New foes-turn saves retain exact saved geometry. An old foes-turn save cannot reconstruct previous red, so it uses the live legacy fallback until its next Pass; events use the sentinel `-1`. First announced Calls and reinstalled same-source Gusts retain a Pass receipt.
6. **Implemented:** additive integer `beat_tiles_frozen_at` is recorded in the committed surface event and JSONL adapter. `spec/analytics.md` documents the clock, sentinel, save boundary and compatibility. No historical event is rewritten.

## Focused checks

```text
ATK14 RULES RESULT: PASS (0 failures)
ATK03 FOCUSED RESULT: PASS (1792 assertions, 0 failures)
ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)
THREATS AT REST TEST RESULT: PASS (16970 assertions; includes compass suite)
UI identity lint: Ran 25 tests; OK
ISOLATION AUDIT: 56 modules
AREA02 CARD SCORES: PASS (309 cards; 0 intrinsic score changes)
```

The supplied branch initially failed the atk-14 rules check with five stale assertions about the owner's new data (two sentences, the half-Health Chain row and two Cantor Damage 3 / Chain 2 assertions). Local master still had the old data. These rule assertions now verify the supplied owner data; unrelated assertions were preserved. One intermediate raw-Upheaval forecast change failed the existing BOS01 ring guard assertion; that change was reverted. No full suite was run.

## Truth audit

Natural revision-7 fights, first three samples per instance at tier 3, movement/PASS only, unchanged enemy/rule definitions. Proof Health is elevated and named below. Cantor uses a longer proof activation to include Tender placement before a later Peal in the same phase. Lightning/Ice/Fire compare complete Pass geometry with the primitive arguments at fire, with live impassability; visible red remains filtered by the existing sight policy. Gust compares the accepted direction and actual landing deltas, excluding speculative intent-preview movement. Upheaval compares marks against actual raises and therefore reports blocked-raise differences. Shadowstep is the explicit live-aim exception.

**Strict acceptance is not met:** 64 mismatches across 1986 beats. There are 2 Bell Tender post-Pass exclusion witnesses and zero Cantor mismatches.

| Instance | Fights | Passes | Beats | Nonempty tiles / non-tile beats | Mismatches | Seeds |
|---|---:|---:|---:|---:|---:|---|
| stormcaller | 3 | 72 | 197 | 197 | 0 | 3, 4, 8 |
| slagmaster | 3 | 72 | 100 | 17 | 0 | 1, 15, 17 |
| oracle | 3 | 72 | 116 | 113 | 0 | 2, 6, 9 |
| dynamo | 3 | 72 | 40 | 40 | 0 | 1, 2, 4 |
| thornmother | 3 | 72 | 103 | 42 | 5 | 2, 6, 8 |
| prior | 3 | 72 | 118 | 118 | 0 | 1, 2, 6 |
| snare_earth | 3 | 57 | 57 | 17 | 1 | 1, 6, 8 |
| snare_fire | 3 | 72 | 72 | 6 | 0 | 2, 3, 4 |
| snare_air | 3 | 72 | 72 | 72 | 0 | 1, 6, 10 |
| snare_ice | 3 | 72 | 72 | 26 | 0 | 3, 4, 5 |
| snare_lightning | 3 | 72 | 72 | 69 | 0 | 2, 3, 5 |
| snare_shadow | 3 | 72 | 72 | 72 | 0 | 1, 3, 5 |
| last_light | 3 | 6 | 9 | 9 | 0 | 1, 2, 2 |
| gale_herald | 3 | 72 | 164 | 164 | 14 | 2, 7, 8 |
| ashen_reaver | 3 | 16 | 7 | 3 | 0 | 1, 2, 3 |
| rimejaw | 3 | 72 | 72 | 69 | 0 | 1, 2, 3 |
| storm_cantor | 3 | 33 | 73 | 73 | 0 | 1, 2, 3 |
| gallows_roc | 3 | 72 | 72 | 72 | 0 | 1, 2, 4 |
| craghide | 3 | 60 | 86 | 30 | 39 | 2, 3, 4 |
| last_lamplighter | 3 | 72 | 72 | 72 | 0 | 1, 3, 4 |
| vyraketh | 3 | 17 | 15 | 12 | 0 | 1, 2, 3 |
| tharokh | 3 | 72 | 36 | 32 | 5 | 1, 2, 3 |
| iskaldra | 3 | 72 | 63 | 63 | 0 | 1, 2, 3 |
| vaeloryx | 3 | 50 | 135 | 135 | 0 | 1, 2, 3 |
| zekarion | 3 | 66 | 43 | 43 | 0 | 1, 2, 3 |
| noctyrax | 3 | 72 | 48 | 48 | 0 | 1, 2, 3 |

Raw counts and every mismatch: `/private/tmp/labyrinth_codex/area-02/truth/summary.json`. Per-instance commands, exits, duration and logs are beside it.

## Difficulty: matched N=64 before and after

Both snapshots include the protected owner data commit (Cantor 4, Zekarion 6/7, Chain 0), isolating the runtime snapshot change. These are natural tier-3 rooms, unchanged committed policy v2, default 24 Health, revision 7, the same decks/search limits, and exact seed/coordinate/entrance matching. Means include losses and capped runs. No tuning was performed.

| Instance | N each | Before wins | After wins | Change | Mean turns before → after | Mean HP lost before → after |
|---|---:|---:|---:|---:|---:|---:|
| storm_cantor | 64 | 17/64 (26.6%) | 17/64 (26.6%) | +0.00 pp | 7.56 → 7.56 | 22.06 → 22.06 |
| zekarion | 64 | 23/64 (35.9%) | 24/64 (37.5%) | +1.56 pp | 4.28 → 4.27 | 20.97 → 20.86 |
| dynamo | 64 | 23/64 (35.9%) | 23/64 (35.9%) | +0.00 pp | 8.62 → 8.62 | 19.58 → 19.58 |
| snare_lightning | 64 | 40/64 (62.5%) | 40/64 (62.5%) | +0.00 pp | 3.17 → 3.17 | 12.56 → 12.56 |
| ashen_reaver | 64 | 28/64 (43.8%) | 28/64 (43.8%) | +0.00 pp | 5.48 → 5.48 | 21.61 → 21.61 |
| rimejaw | 64 | 23/64 (35.9%) | 22/64 (34.4%) | -1.56 pp | 3.88 → 3.92 | 21.08 → 20.83 |
| gallows_roc | 64 | 24/64 (37.5%) | 24/64 (37.5%) | +0.00 pp | 4.48 → 4.48 | 21.33 → 21.33 |
| vyraketh | 64 | 24/64 (37.5%) | 22/64 (34.4%) | -3.12 pp | 4.75 → 4.56 | 21.47 → 21.52 |
| iskaldra | 64 | 25/64 (39.1%) | 27/64 (42.2%) | +3.12 pp | 5.77 → 5.88 | 21.14 → 20.69 |
| vaeloryx | 64 | 30/64 (46.9%) | 29/64 (45.3%) | -1.56 pp | 4.61 → 4.61 | 20.86 → 21.22 |

AREA02 DIFFICULTY: PASS (1280 completed fights; 10 matched instances; N=64 each before/after). Frozen code copies and SHA-256 contracts: `/private/tmp/labyrinth_codex/area-02/before-project`, `after-project`, `before-contract.json`, `after-contract.json`. Raw reports, commands and costs: `/private/tmp/labyrinth_codex/area-02/ladder/`.

The after ladder copy predates only the final first-Call/reinstalled-Gust receipt cache and its cleanup, plus TODO constants and provenance comments. The ten measured fight types do not use Call the Wind; these additions do not change their resolutions. Final focused tests and truth audit use the current worktree. The opt-in provenance scan checks all 640 natural rosters and their declared summons for Call the Wind; the compatibility conclusion is a control-flow inference, not a second final-code ladder.

## Proof for the design owner

Headless capture semantics passed for Cantor and Wildfire; they emitted JSON sidecars, not PNGs. Native capture paths below are planned, not observed. The native wrapper uses the visual-probe runner, cel look, Metal/mobile, 1920×1080 and 100% UI scale, with one attempt and per-case proof contracts.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && sh tools/area02/native_proof.sh
```

Expected native images: `/private/tmp/labyrinth_codex/area-02/captures/cantor_pass.png`, `cantor_tender.png`, `cantor_strike.png`, `wildfire_pass.png`, `wildfire_spread.png`; manifests `cantor.manifest.json` and `wildfire.manifest.json`. Cantor captures the later Peal after the Tender checkpoint in the long natural phase.

The brief does not request an inspection-fixture command. These capture scripts load audited `run_state.txt` witnesses under an isolated runner HOME; the design owner owns any playable inspection-fixture packaging.

Reproduce headless proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && python3 tools/atk13/rule_audit.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && python3 tools/atk13/rule_ladder.py --label before --project /private/tmp/labyrinth_codex/area-02/before-project
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-02 && python3 tools/atk13/rule_ladder.py --label after --project /private/tmp/labyrinth_codex/area-02/after-project
```

## TODO_DESIGN and open issues

- `TODO_DESIGN_GUST_FROZEN_SCOPE`: direction is frozen; global Push scope is preserved. The brief also speaks of frozen-tile occupants, which could imply a different Gust scope. No new red footprint or targeting scope was invented.
- `TODO_DESIGN_GUST_NEW_CALL`: an unannounced Call selected after Pass can install a new rule without a previous announcement. Existing live fallback is preserved in this case; the strict audit fails it. Announced first Calls and reinstallation of a held source are handled.
- `TODO_DESIGN_UPHEAVAL_BLOCKED_MARKS`: existing route-safety and occupied-raise guards can block a frozen mark on otherwise passable floor. The strict audit counts these as mismatches. The owner must decide whether these guards fall under the impassable exception or whether rule behavior should change.
- Real-renderer proof and independent visual inspection remain with the design owner. No publication readiness or peer signoff is claimed.

## Chosen defaults

- Truth proof: 3 natural fights per instance, tier 3, seed scan starts at 1, 24 hero activations maximum, proof Health 9999, spent Time 24 (Cantor 96), deterministic movement probability 0.75. These are proof-only settings, not production tuning.
- Difficulty: N=64 and tier-3 policy-v2 ladder, existing 24 Health and deck presets; 3 Python workers; runner timeout 14,400 seconds for 64 full searches. Truth cells use 1,800 seconds; the 640-roster provenance scan uses 600 seconds; default native capture limit remains 300 seconds.
- Capture: native frame ceiling 14,400; headless-only time scale 16 and frame ceiling 1,800. Existing atk-13 boot/layout constants are reused. All native settings remain at production timing.
- Rule fixtures: damage 2 or 5, save path `user://area02-snapshot.save`, tiles `(5,5)`, `(6,5)`, conductor `(3,5)/(4,5)`, proof clock 17; all are named debug fixtures. The analytics no-snapshot sentinel is `-1`.

## Files changed

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
- `scripts/battlefield_rules/wildfire.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/snare_pressure_view.gd`
- `spec/analytics.md`
- `spec/card_balance_heuristic.md`
- `tests/suites/battlefield_conduction_suite.gd`
- `tests/suites/battlefield_fuel_suite.gd`
- `tests/suites/battlefield_rules_suite.gd`
- `tools/area02/REPORT.md`
- `tools/area02/cantor_contract.json`
- `tools/area02/capture.gd`
- `tools/area02/native_proof.sh`
- `tools/area02/report.py`
- `tools/area02/wildfire_contract.json`
- `tools/atk13/rule_audit.gd`
- `tools/atk13/rule_audit.py`
- `tools/atk13/rule_cases.gd`
- `tools/atk13/rule_ladder.gd`
- `tools/atk13/rule_ladder.py`
- `tools/atk13/rule_ladder_provenance.gd`
- `tools/atk13/rule_observer.gd`
- `tools/card_heuristic.py`
