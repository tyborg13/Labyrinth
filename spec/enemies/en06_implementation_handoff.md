# EN06 implementation handoff

Branch `codex/en-06`, base `f56687907fddb312ef4f888694c11e07f7512163`
(`codex/peer-benchmark`). All changes are **uncommitted**. No branch changes,
stash, commit, push, merge, peer review or publication were performed.

## Brief acceptance

| Requirement | Implementation and observed proof |
| --- | --- |
| 1. Charge | Persistent capped +1; three 8px diamond pips; authored colours/40% glow; exact badge tooltip. Focused accumulation, caps, freeze persistence, save and live badge checks pass. Director feedback 1 sets 4px edge gaps and row centre 10px above the health-frame top; Charge pill is `+1`. |
| 2. Discharge | Automatic threshold intent; nearest Manhattan-range-4 first hit with hero tie precedence; eight-neighbour jumps, 6/5/4/3, reset. Telegraph uses the resolver's snapshots, responds to pushes/deaths, and shares existing violet Chain FX at 0.12s/hop. Friendly-fire rewards, full path parity and actual animation-state application pass. Every tied choice uses hero, lowest current HP, tile y, tile x; Discharge pill is `6`. |
| 3. Grounded / anchored | Shock transition loses one Charge and refreshes intent; exact Grounded float works for cards and enemy actions. Walk/force/wind anchoring pass. |
| 4. Mirror | Actual damaging card history, native base values, immutable selected copy, direct/area/facing geometry, range approach up to 2, disclosed Shade Bolt fallback, no riders, seeded legal selection, live tooltip/compass/pills/previews and save round-trip pass. Director feedback 1 selects the first damaging action; special shapes keep copied damage/name/element with single ranged range-4 geometry. |
| 5. Shade Bolt / Recede | Protected staged values are wired to existing ranged 4/range 4 and move-away 2/Block 4 verbs. No tuning or redesign. |
| Integration | Two protected entries match staged data; two approved static sprites/portraits/icons load; turn clock and static fallback registry cover both; density sources/output/shadow cache registered. Encounter additions remain director-owned after merge. Analytics keeps existing events and classifies Charge as an enemy action. |

## Director feedback 1 acceptance

| Feedback | Concrete implementation |
| --- | --- |
| 1. Integer numbers | Shared pill primary/rider values and numeric icon tokens cast to integers; Charge keeps `+1`. Computed-float capacitor and mimic regressions pass. The native probe asserts `+1` / `6` for 01/02 and `8` for the mimic. |
| 2. Pip geometry | Three 8px diamonds use 4px edge gaps; row centre is horizontally centred and 10px above the health-frame top. Geometry checks pass. |
| 3. Discharge ties | Every nearest-target selection, including jumps, uses hero, lowest current HP, lowest tile y, lowest tile x. Resolution and preview use the same function; first-hit/jump/forecast regressions pass. |
| 4. Special Mirror targeting | Special shapes retain the card name, first base damage and element as one ranged hit at range 4. Direct single/line/pattern shapes retain their native geometry. Real Discharge and synthetic self/chain/summon/blink/force/surface copies pass without riders. |
| 5. Multiple damaging actions | Copy only the first damaging action's damage and shape; retain `Mirror: <card>`. Direct and special first-action regressions pass. |

Feedback edits are in `scripts/intent_badges.gd`, `action_icon_library.gd`,
`enemy_mechanics/{capacitor,capacitor_view,mimic}.gd`,
`tests/suites/en06_enemies_suite.gd`, `tests/en06_enemies_probe.gd`,
`tools/card_heuristic.py`, the EN06 heuristic rows, and these owning specs.
No protected staged values or art were changed for the feedback.

## Files changed

- `assets/generated/unit_shadow_cache.res`
- `data/enemies.json`
- `scripts/action_icon_library.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/cutout_context.gd`
- `scripts/enemy_intent_compass.gd`
- `scripts/intent_badges.gd`
- `scripts/run_scene.gd`
- `spec/analytics.md`
- `spec/assets/board_pixel_density/outputs.json`
- `spec/assets/board_pixel_density/registry.json`
- `spec/assets/enemies/raw_sha256.txt`
- `spec/card_balance_heuristic.md`
- `spec/icon_identity_policy.md`
- `tests/run_tests.gd`
- `tests/test_board_pixel_density.py`
- `tests/test_icon_identity_policy.py`
- `tools/card_heuristic.py`
- `tools/inspection_fixture.gd`
- `assets/art/enemies/hollow_mimic.png`
- `assets/art/enemies/storm_capacitor.png`
- `assets/art/icons/charge.png`
- `assets/art/icons/mirror.png`
- `assets/art/portraits/hollow_mimic.png`
- `assets/art/portraits/storm_capacitor.png`
- `scripts/enemy_mechanics/capacitor.gd`
- `scripts/enemy_mechanics/capacitor_view.gd`
- `scripts/enemy_mechanics/mimic.gd`
- `scripts/enemy_mechanics/mimic_view.gd`
- `spec/assets/board_pixel_density/sources/assets/art/enemies/hollow_mimic.png`
- `spec/assets/board_pixel_density/sources/assets/art/enemies/storm_capacitor.png`
- `spec/enemies/en06_implementation_handoff.md`
- `spec/enemies/hollow_mimic.md`
- `spec/enemies/storm_capacitor.md`
- `tests/en06_enemies_probe.gd`
- `tests/en06_enemies_probe_contract.json`
- `tests/en06_enemies_test.gd`
- `tests/en06_fixture_check.gd`
- `tests/en06_shadow_cache_check.gd`
- `tests/suites/en06_enemies_suite.gd`
- `tools/en06_inspection_rules.gd`
- `tools/process_en06_enemy_assets.py`

Shared runtime growth stays within the brief: CombatEngine +26 net lines,
CombatBoardView +8, RunScene +12 (all below 120/120/20).

## Headless verification

All Godot execution used `tools/godot_task_runner.py --task-id en-06`.

- `tests/en06_enemies_test.gd`: `EN06 ENEMIES TEST RESULT: PASS (176 checks, 0 failures)`; mechanics, schema, portraits, save/load, live preview data and actual animation application.
- `tests/en03_enemies_test.gd`: `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)`.
- `tests/contextual_cutout_test.gd`: `CONTEXTUAL CUTOUT TEST: PASS`.
- `tests/threats_at_rest_test.gd`: `THREATS AT REST TEST RESULT: PASS (451 assertions; includes compass suite)`.
- `tests/inline_icon_description_test.gd`: `INLINE ICON DESCRIPTION TEST RESULT: PASS`.
- `tests/test_icon_identity_policy.py`: `Ran 7 tests in 0.083s` / `OK`.
- `tests/test_board_pixel_density.py`: `Ran 41 tests in 100.191s` / `OK`.
- `tools/process_board_density.py --check`: `CHECK-OK`; both individual new entries also return `CHECK-OK`.
- `tools/process_board_density.py --record-rests --only <enemy>`: `RECORDED-RESTS 0 file(s)` for each; static enemies have no cutout rests to rebake.
- Shadow-cache baseline comparison: `EN06 SHADOW CACHE ADDITIVE CHECK: PASS (48 existing entries; 2 additions)`; all existing silhouettes/source hashes are unchanged.
- Shadow regeneration: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=50 sources=44`.
- Probe parser (`godot --headless --path . --check-only --script tests/en06_enemies_probe.gd`): runner exit 0; no editor scan.
- Protected data comparison: `EN06 PROTECTED DATA: PASS (2 verbatim staged entries)`.
- Heuristic assumptions: `EN06 HEURISTIC ASSUMPTIONS: PASS (Capacitor 20.25; Mimic 17; feedback 1 rules)`; intrinsic card coefficients are unchanged.
- Python compilation passes with task-local `PYTHONPYCACHEPREFIX`; `git diff --check` is clean.
- Both `tools/inspection_fixture.py` generation/reload checks: `Inspection fixture verified.` / `INSPECTION_FIXTURE_VERIFIED` with `ok:true`.
- Additional saved-state checks: `EN06 CAPACITOR FIXTURE CHECK: PASS` and `EN06 MIMIC FIXTURE CHECK: PASS`.
- Feedback 1 full suite: `TEST RESULT: FAIL (4 failure(s))`, runner exit 1, at `/private/tmp/en06-feedback1-full.log`. Exactly the known depth-zero pinned integration hashes fail: run seeds 307, 8821, 90429; combat seed 8821. No new assertion, parse or script failures. Assertions were not changed. The suite's card-targeting audit covered `309 cards, 699 upgrades`.
- Earlier implementation full suite: the same `TEST RESULT: FAIL (4 failure(s))` at `/private/tmp/en06-full-final-head.log`. A 300s attempt had timed out during known long gear checks; the established 1200s command completed both later runs. The two earlier static-registry omissions were fixed before the final implementation run.

Feedback 1 logs: `/private/tmp/en06-feedback1-{focused,threats,inline,icons,density,probe-parse,capacitor-fixture,mimic-fixture,full}.log`.

Earlier implementation logs:
`/private/tmp/en06-focused-final.log`, `/private/tmp/en06-full-final-head.log`,
`/private/tmp/en06-icon-audit.log`, `/private/tmp/en06-density-tests-final.log`,
`/private/tmp/en06-probe-parse-final.log`, `/private/tmp/en06-shadow.log`,
`/private/tmp/en06-{capacitor,mimic}-fixture.log`,
`/private/tmp/en06-{capacitor,mimic}-check.log`.

## Proof for the design owner

No windowed run was attempted: this worker has no macOS window-server access.
The probe writes seven fresh native 1920×1080 captures at 100% UI scale from an
`UPDATE_ALWAYS` SubViewport, never `root.get_texture()`:

1. `01_capacitor_two_pips.png`
2. `02_capacitor_discharge_telegraph.png` (two enemies and hero)
3. `03_capacitor_mid_chain.png`
4. `04_capacitor_after_discharge.png`
5. `05_mimic_area_copy_intent.png` (a real Whirlwind Slash was played)
6. `06_mimic_mid_area_copy.png`
7. `07_mimic_after_copy.png`

Expected capture directory: `output/en06-enemies/<fresh-unix-timestamp>/`.
The director reviewed the initial native captures at
`/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/en-06/`.
This worker inspected those images. Feedback 1 requires fresh 01/02; none were
recaptured here because windowed execution is unavailable. The probe now asserts
integer `+1` / `6` on those live pills and `8` on the mimic pill. Run this exact
command in a window-server-capable session; it captures all seven, including 01/02:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-06 && python3 tools/visual_probe_runner.py --task-id en-06 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --startup-timeout 30 --expect-size 1920x1080 --proof-contract tests/en06_enemies_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/en06-feedback1-renderer-proof.json tests/en06_enemies_probe.gd
```

Both fixtures have already generated/reloaded/verified headlessly. Their
manifests are `/private/tmp/labyrinth-inspection-manifests/en06-capacitor.json`
and `en06-mimic.json`. Exact interactive launch commands (regenerate and verify
before opening) are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-06 && python3 tools/inspection_fixture.py --project /Users/borgerding/workspace/Labyrinth.worktrees/en-06 --task-id en-06 --run-id en06-capacitor --godot godot --godot-home-root /private/tmp/labyrinth-godot-home --manifest /private/tmp/labyrinth-inspection-manifests/en06-capacitor.json --launch --scenario combat --seed 61027 --enemy-types storm_capacitor,crawler,crawler,crawler --enemy-positions 4:3,3:3,5:3,4:2 --enemy-intents charge,coil,coil,coil --enemy-charge 2 --hand quick_stab,whirlwind_slash,pale_spark --umbra-stage clear --summary 'en06 capacitor at two Charge beside three crawlers'

cd /Users/borgerding/workspace/Labyrinth.worktrees/en-06 && python3 tools/inspection_fixture.py --project /Users/borgerding/workspace/Labyrinth.worktrees/en-06 --task-id en-06 --run-id en06-mimic --godot godot --godot-home-root /private/tmp/labyrinth-godot-home --manifest /private/tmp/labyrinth-inspection-manifests/en06-mimic.json --launch --scenario combat --seed 61027 --enemy-types hollow_mimic,crawler --enemy-positions 5:3,3:3 --enemy-intents shade_bolt,coil --hand whirlwind_slash,quick_stab,pale_spark --umbra-stage clear --summary 'en06 mimic with an area attack in hand'
```

## TODO_DESIGN placeholders

None. Director feedback 1 supplied all outstanding decisions; corresponding
constants, intent fields, tests and documentation now use those decisions.

## Chosen defaults

Only proof/test values were chosen: test/run seed 61027 (shared engine fixture
builder retains EN03 seed 41027), hero HP 30, shared 9×9 debug grid, fixture
positions/hand listed in the commands, eight settle frames, midpoint progress
0.5, mid-chain hop index 1, timestamped output directory, proof region
`[260,110,1400,780]` with minimum luma range 8/stdev 2, and the previously
established 1200s full-suite / 120s probe / 30s startup timeouts. Source feature
coordinates (coil x627/y600, head x630) are measurements of approved paint;
asset sizes, baseline, ratios, icon padding, renderer styles and timings are
brief-defined or inherited from existing production helpers. Feedback-only
regression fixtures use computed values 1.0/2.0/6.0/8.0, a health frame
`Rect2(100,200,80,12)`, synthetic card damage 0/5/7/99 and ranges 3/9,
explicit self/player targets, line patterns and rider fields; these exist only
in the test suite. Feedback 1 introduced no production defaults.

## Open issues and ownership

- Feedback 1 native recapture of 01/02 remains with the design owner because this worker has no window-server access.
- Known whole-state hash failures remain with qa-01; no assertions were rewritten.
- The local task helper reports `contract_ready:false`, empty acceptance/proof arrays and empty inspection expectation at standard risk, despite the supplied brief saying the owner recorded the contract and passed preflight. This worker did not alter owner metadata. Acceptance above follows the numbered brief; the owner should reconcile its task contract before its commit/review/publication phase.
- No encounter pool edits: the brief explicitly assigns the two data additions to the director after merge.
- Routine macOS certificate-store and existing ObjectDB leak warnings were observed. The suite's save-failure/analytics-failure messages include intentional failure fixtures; final assertions are reported separately.
