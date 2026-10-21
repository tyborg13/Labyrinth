# spx-04 implementation handoff

The six orders read their ids and exact tooltip text from the protected
`data/special_encounters.json`. That file and the director's supplied assets
are unchanged. This task leaves all work uncommitted on `codex/spx-04`.
Commit, independent review, inspection and publication belong to the director.

1. Thornmother: five legal Bramble tiles, shortest-path center two steps from
   captain, nearest legal-center fallback; existing damage/Bleed/lifetime.
2. Slagmaster: seeded, saved perpendicular side; fallback to the other legal
   center; two pluses share the stored union, damage batch and existing FX.
3. Stormcaller: source-scoped persistent wind, re-aim on Call, one-tile
   hero/follower previews, anchored captain, existing collisions/source cleanup.
4. Oracle: five midpoint marks rounded toward hero; existing landing/pillars.
5. Dynamo: live Thralls determine 2/3 Charge threshold for planning, selection,
   activation and pips/tooltip; either death removes the reduction immediately.
6. Prior: distant followers use hidden visibility and existing Veil rules,
   reveal through range/Light/Truesight, and reveal through even Eclipse Umbra
   before break movement.

Shared order activation requires a matching living Warband captain. Captain
intent, leader-marker and pre-battle inspection tooltips and objective descriptions append exactly
`Order: <order.text>`. Existing Command, retreat, break, input and save paths
remain. Local append-only analytics retain their ordinary enemy-action,
surface, forced-movement, hidden-attack and death paths; there is no new event
kind or rewrite of history. Intrinsic card coefficients and protected enemy
stats remain unchanged; the six authored encounter modifiers above are the
mechanics under test, not implementation tuning.

## Feedback 2 — Stormcaller wording and independent displacement checks

The director corrected the protected catalog and staged copy to
`Its wind never drops: a gust slides everyone else 1 tile every round.` Neither
file was edited by the implementation worker. Both have SHA-256
`f7053caa0d4b399793227be07b1428e33a7d40b8bad87305b742432fb5df892c`.
Runtime wind code is unchanged: the captain remains anchored through the base
Gale Herald's `force_anchored` rule, and its preview contains no slide.

1. `_scope_and_copy` pins the director's new exact Order line and checks both
   the captain's production intent tooltip and objective tooltip against it.
   The existing live-scene probe checks the pre-battle order line as well.
2. Preview and end-of-turn resolution independently assert fixed destinations
   for every unit. The unobstructed fixture's player goes `(5,6) → (5,5)`,
   followers go `(3,5) → (3,4)` and `(7,5) → (7,4)`, and the captain stays
   `(5,2)`. Preview paths are checked against these fixed one-tile endpoints;
   forecast/resolution equality is retained as an additional check.
   A pillar at `(3,4)` stops the first follower at `(3,5)`, with the existing
   two-damage collision and collision marker/event. Every other unit's fixed
   destination is also asserted in this blocked case.
3. Focused verification only. `--wind-only` mutation mode exercises a two-tile
   push and bypassed captain anchoring, requiring the corresponding independent
   destination assertion to fail. Mutations restore exact source bytes, and
   run both order and live-scene controls before and after.

Files changed for feedback 2: `tests/suites/warband_orders_suite.gd`,
`tests/warband_orders_test.gd`, `tests/warband_order_mutations.py`,
`spec/enemies/gale_herald.md` and this handoff. The director's existing data
edits and supplied feedback file are preserved. No production script changes,
art, dependency, balance or analytics changes are needed.

Chosen defaults are test-only: `FIXTURE_WIND_EXPECTED` holds player `(5,5)` and
enemy destinations `[(5,2), (3,4), (7,4)]`; `FIXTURE_WIND_PILLAR = (3,4)`;
`FIXTURE_WIND_BLOCKED_EXPECTED` holds player `(5,5)` and enemy destinations
`[(5,2), (3,5), (7,4)]`; `MINIMUM_CHECK_COUNT = 213`. The fixture's collision
expectation `FIXTURE_WIND_COLLISION_DAMAGE = 2` records the existing rule.
No design placeholders remain.

Exact focused commands:

```bash
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/warband_orders_test.gd
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/en02_enemies_test.gd
python3 tests/warband_order_mutations.py --wind-only
```

The mutation command also runs `tests/warband_orders_probe.gd -- --check-only`
through the task runner for both controls. No full suite or native capture was
run for feedback 2. No new visual behavior is expected; the director can reuse
the existing seven-frame probe below to inspect the changed Order text.

Observed result lines (all commands exited 0):

```text
WARBAND ORDERS TEST RESULT: PASS (214 checks, 0 failures)
EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)
SPX04 MUTATION wind_two_tile_push: KILLED
SPX04 MUTATION wind_sliding_captain: KILLED
SPX04 MUTATION RESULT: PASS (2/2 killed; controls pass; exact sources restored)
SPX04 PROBE CONTRACT: PASS (7 states, 1920x1080, UI scale 100%)
SPX04 DIRECTOR DATA: PASS (2 protected files preserved; approved Stormcaller copy)
SPX04 RUNTIME: unchanged (all production scripts)
```

Final controls: `/private/tmp/spx04-order-mutations/control_after.log` and
`/private/tmp/spx04-order-mutations/probe_control_after.log`. EN02 engine log:
`/private/tmp/labyrinth-godot-home/spx-04-1792576566967572000-9746/godot.log`.
`git diff --check` passes. No production script diff remains after mutations;
both protected files match the hashes above.

Open issue: the final headless probe passes its assertions and exits 0 but
reports `ObjectDB instances leaked at exit` and `2 resources still in use at
exit` during shutdown. The order suite and EN02 also emit the existing macOS
certificate message. No assertion was weakened to accommodate output. Native
capture is director-owned; no feedback-2 PNGs were produced here.

## Feedback 1 — implementation and focused validation

1. The Thornmother's production board presentation now submits her exact
   Thornwall plan to the shared `ThreatTiles` marked-intent renderer. This adds
   no colour literals. The live-scene headless probe compares the renderer's
   marked-tile lookup with resolved Bramble terrain for a full wall, blocked
   and occupied tiles, and an occupied center. Frozen/dead captains clear the
   marks. Existing focus alpha and order badges are preserved.
2. The held-wind title and appended tooltip line use the director's exact copy.
   Live controls also check ordinary finite copy and source-death removal. The
   native air fixture now has called wind active so its held chip is visible.
3. Thornwall center selection ranks distance from the preferred center, then
   player, then Thornmother; complete ties retain scan order.
4. The existing dominant-cardinal axis already uses x on exact diagonals. The
   placeholder is removed and eight signed diagonal/dominant-axis cases assert
   the helper and actual Barrage centers/Oracle marks.
5. Only focused checks were run for this feedback. No full suite or windowed
   command was run. The director supplied and judged the original seven native
   frames; fresh feedback captures remain the director's next proof step.

Observed result lines:

```text
WARBAND ORDERS TEST RESULT: PASS (187 checks, 0 failures)
SPX04 THORNWALL BOARD: full wall, legal trimming, center relocation and suppression PASS
SPX04 WIND CHIP: held copy, finite countdown and source death PASS
SPX04 PROBE CONTRACT: PASS (7 states, 1920x1080, UI scale 100%)
EN04 ENEMIES TEST RESULT: PASS (454 checks, 0 failures)
EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)
Warband UI semantics: 0 failures
SPX04 MUTATION RESULT: PASS (5/5 killed; controls pass; exact sources restored)
Ran 25 tests in 2.653s
OK
```

All listed commands exited 0. The order suite still includes all seven
unchanged ordinary-mechanic goldens and six save roundtrips. Focused mutations
remove the board bridge or corrupt held copy, each center tie preference or the
diagonal axis; each fails its intended assertion without a script error. Logs:
`/private/tmp/spx04-order-mutations/`, with final controls `control_after.log`
and `probe_control_after.log`. The existing macOS headless certificate message
appears in Godot output and does not change these exit statuses.

Exact focused commands (Godot scripts are each run through the task runner):

```bash
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/warband_orders_test.gd
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/warband_orders_probe.gd -- --check-only
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/en04_enemies_test.gd
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/en02_enemies_test.gd
python3 tools/godot_task_runner.py --task-id spx-04 --stream -- godot --headless --path . --script tests/warband_ui_test.gd
python3 tests/test_ui_identity_lint.py
python3 tests/warband_order_mutations.py --feedback-only
```

Files changed for feedback 1: `scripts/combat_board_view.gd`,
`scripts/warband_combat_rules.gd`,
`scripts/enemy_mechanics/{bramble,bramble_view,wind_view}.gd`,
`spec/enemies/{briar_weaver,gale_herald,hoarfrost_seer,slag_mortar,spx04_orders}.md`,
`tests/suites/warband_orders_suite.gd`, `tests/warband_orders_test.gd`,
`tests/warband_orders_probe.gd` and `tests/warband_order_mutations.py`.
The supplied feedback file, protected data and approved assets are untouched.

## Proof for the design owner

The sandbox cannot access the macOS window server. No windowed run was attempted.
The native probe builds seven states through production planners/resolvers and
renders the actual RunScene to a 1920×1080 UPDATE_ALWAYS SubViewport at UI scale
1.0. It checks actor renderer readiness and actual body draw submission. The
image contract requires all seven images and a nonblank board region.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-04 && python3 tools/visual_probe_runner.py tests/warband_orders_probe.gd --task-id spx-04 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/spx04_orders.json --result-manifest /private/tmp/labyrinth-inspection-manifests/spx04-orders-feedback2-proof.json
```

Expected feedback captures (not yet produced) are under the isolated run's
`user://probes/spx04/`: `earth_telegraph.png`, `fire_telegraph.png`,
`air_telegraph.png`, `ice_telegraph.png`, `lightning_telegraph.png`,
`shadow_telegraph.png`, `shadow_reveal.png`, plus `captures.json` with semantic
facts. The runner prints their absolute paths. No screenshots are claimed as
verified until the director runs and inspects them.

The brief assigns inspection-fixture preparation to the director and requires
no new fixture CLI. The existing production Warband fixtures remain available;
for example, the exact existing interactive Prior fixture command is:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-04 && python3 tools/inspection_fixture.py --task-id spx-04 --run-id spx04-prior --scenario warband --warband-biome shadow --warband-tier 3 --warband-case encounter --seed 83 --manifest /private/tmp/labyrinth-inspection-manifests/spx04-prior.json --summary 'Hollow Prior order: hidden followers and captain break reveal' --launch
```

## Director decisions (feedback 1)

All three design placeholders are resolved. Barrage and Oracle retain the
dominant cardinal projection, with x winning exact diagonals. Equidistant legal
Thornwall centers prefer nearest player, then nearest Thornmother, then existing
scan order. The wind chip reads `Wind · held` and appends the tooltip line
`Held by the Stormcaller until it falls.` There are no remaining design TODOs.

## Chosen defaults

Only test/debug/proof values were chosen: `FIXTURE_SIZE = 11`, `FIXTURE_HP = 100`,
`FIXTURE_CAPTAIN = (5,2)`, `FIXTURE_PLAYER = (5,6)`,
`FIXTURE_FOLLOWER_A = (3,5)`, `FIXTURE_FOLLOWER_B = (7,5)`;
`MINIMUM_CHECK_COUNT = 213` guards skipped test execution. Proof reuses the
existing fixture seed `PROOF_SEED = 83`, `SETTLE_SECONDS = 0.25`,
`READY_TIMEOUT_SECONDS = 20`, and `EXPECTED_CASES = 7`.
Additional test-only fields are `FIXTURE_WALL_CENTER = (5,4)`,
`FIXTURE_BRAMBLE_PUSH_START = (5,3)`, `FIXTURE_BRAMBLE_BLOCK = (3,4)`,
`FIXTURE_BARRAGE_CENTER = (3,6)`, `FIXTURE_BARRAGE_OTHER_CENTER = (7,6)`,
`FIXTURE_BARRAGE_OUTER_ARM = (2,6)`, `FIXTURE_WIND_HAZARD = (6,6)`,
`FIXTURE_ICE_PUSH_START = (4,3)`, `FIXTURE_ODD_MIDPOINT_HERO = (5,7)`,
`FIXTURE_ODD_MIDPOINT_CENTER = (5,5)`, `FIXTURE_PRIOR_NEAR_HERO = (3,7)`,
`FIXTURE_RNG_SEED_FIRST = 1`, `FIXTURE_RNG_SEED_COUNT = 32`,
`FIXTURE_PERSISTENCE_BOUNDARIES = 5`, `FIXTURE_LIGHT_RADIUS = 1`, and
`FIXTURE_REVEAL_ACTIVATIONS = 2`. `SAVE_PATH` is the isolated
`user://spx04-mid-order.save`; mutation logs go to
`/private/tmp/spx04-order-mutations`. The native proof output directory is
`user://probes/spx04`. The probe uses the existing Clear Umbra state so the
production visibility presentation can exercise the Prior independently of
room darkness. All these choices are invisible outside tests and probes.

Feedback 1 adds test-only `FIXTURE_CENTER_TIES` (all prefer center `(5,4)`):

| Tie rank | Player | Captain | Legal candidates | Expected |
| --- | --- | --- | --- | --- |
| player | (5,6) | (5,2) | (5,3), (5,5) | (5,5) |
| captain | (7,6) | (3,5) | (5,3), (4,4) | (4,4) |
| scan | (5,6) | (5,2) | (4,4), (6,4) | (4,4) |

`FIXTURE_AXIS_CAPTAIN = (5,5)`. `FIXTURE_AXIS_BEARINGS` pairs delta and
perpendicular axis: `(2,2) → down`, `(2,-2) → down`, `(-2,2) → up`,
`(-2,-2) → up`, `(1,3) → left`, `(-1,-3) → right`, `(3,-1) → down`,
`(-3,1) → up`. No player-facing values were chosen.

The full Godot runner uses 960 seconds to cover the existing 900-second suite
budget plus shutdown/report overhead. These values never affect gameplay.

## Validation

Results are recorded after execution below. The focused suite contains one
function per order, pre-resolution preview/telegraph assertions, scope/copy,
mutation guards, saves and seven full-state ordinary-mechanic goldens recorded
against the unmodified spx-03 runtime. Mutants restore exact source bytes in
`finally` and require a failing intended assertion, not a parser error.


## Task contract coverage

- All six captain-only orders: `_thornmother`, `_slagmaster`, `_stormcaller`,
  `_oracle`, `_dynamo`, `_prior` and `_scope_and_copy` cover the authored behavior,
  levers, scope and live-source boundaries. Feedback 1 resolves the three
  original design placeholders as recorded above.
- Preview before harm and exact order copy: each order asserts its pre-resolution
  plan, stored marks, hidden presentation or threshold before resolution;
  `_scope_and_copy` compares both tooltip paths to the protected JSON text.
- Ordinary mechanics and mid-combat saves: seven full Variant goldens recorded
  against the unmodified integration runtime, all six real save roundtrips and
  deterministic continuation. The unchanged spx-03 Warband suite covers
  placement, Command, retreat and break.
- Director inspection: the seven-state native probe and image contract are
  written; its live-scene headless contract passes. Fresh PNG inspection is
  pending the listed windowed command.

The initial complete Godot run ended `TEST RESULT: FAIL (2 failure(s))` and
`FULL SUITE RUNTIME: 459.604 seconds (budget 900 seconds)`. All 183 other child
programs, including the new order suite/probe, passed. The two failing programs
were `encounter_measurement_test` and `special_encounter_test` (missing cached
emblem imports). The required headless import bootstrap subsequently exited 0.
The initial full log is
`/private/tmp/labyrinth-godot-home/spx-04-1792567294423583000-76987/godot.log`.

The measurement failure was reproduced with every modified runtime script
restored temporarily to the unmodified integration HEAD, then restored to the
exact implementation bytes. No existing assertion was changed:

```text
SPX03 UNMODIFIED RUNTIME BASELINE: exit 1
FAIL: pre-change golden maps, rooms, combat transitions and save roundtrips match
ENCOUNTER GOLDEN: FAIL (3 seeds; maps, rooms, combat, saves)
FAIL: small sweep includes every current objective
ENCOUNTER SMALL SWEEP: FAIL (36 rooms)
ENCOUNTER MEASUREMENT: FAIL (132 checks; 2 failures)
```

Baseline log: `/private/tmp/spx04-base-measurement.log`.


Post-bootstrap full Godot result:

```text
MAIN BODY RUNTIME: 213.688 seconds
MAIN BODY ASSERTIONS: 378992
SPX special encounter suite: 0 failures
WARBAND ORDERS TEST RESULT: PASS (156 checks, 0 failures)
SPX04 PROBE CONTRACT: PASS (7 states, 1920x1080, UI scale 100%)
FULL SUITE RUNTIME: 459.638 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
```

184/185 child programs pass. The sole failing program is the independently
reproduced pre-existing `encounter_measurement_test`; no assertion was rewritten.
Final full stdout: `/private/tmp/spx04-full-final.log`; engine log:
`/private/tmp/labyrinth-godot-home/spx-04-1792568117528599000-80837/godot.log`.
The final order suite includes the Eclipse reveal boundary, unchanged ordinary
board projection and actual saved Dynamo Charge. The probe also checks the
pre-battle captain's exact line and preservation of both authored Dynamo moves.


## Final focused validation and Python sweep

```text
WARBAND ORDERS TEST RESULT: PASS (157 checks, 0 failures)
SPX04 MUTATION RESULT: PASS (10/10 killed; controls pass; exact sources restored)
SPX04 PROBE CONTRACT: PASS (7 states, 1920x1080, UI scale 100%)
Warband suite: 0 failures
Warband UI semantics: 0 failures
EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)
TEST REGISTRATION AUDIT: PASS (776 scripts; full suite=426, quarantined=29, windowed probe=321)
```

UI identity lint: `Ran 25 tests in 3.453s` / `OK`.
The scheduler regression suite: `Ran 28 tests in 19.368s` / `OK`, including
all 133 supplemental mode mutations rejected. The legacy 129-program set and
spx-03 suffix assertions remain intact; the two new programs have their own
explicit registration contract immediately ahead of that suffix. The original
Warband tooltip assertion was updated only to include the newly required exact
protected Order line; no pre-existing failing assertion was weakened.

The full Python command was:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/spx-04 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Observed complete-sweep result (before the registration fix):

```text
Ran 1563 tests in 1641.851s
FAILED (failures=1, skipped=66)
```

Its only failure was `test_manifest_preserves_all_existing_children_and_order`.
That task-introduced registration issue is fixed and the affected 28-test
scheduler suite now passes as recorded above. The entire Python sweep was not
repeated after that manifest/contract-only fix. Full Python log:
`/private/tmp/spx04-python-full.log`. The sweep's generated Briar proof sample
was restored to its original bytes; no unrelated production/art diff remains.

The last tooltip refinement keeps the existing Charge wording while replacing
its `At 3` number with the live threshold in the Dynamo's badge and intent row;
ordinary tooltip copy remains byte-identical. The focused suite checks both.
Latest focused log:
`/private/tmp/spx04-order-mutations/control_after.log`.
Latest probe log:
`/private/tmp/labyrinth-godot-home/spx-04-1792569897152952000-89727/godot.log`.
Existing macOS headless certificate warnings appear in the engine logs. EN06
also reports retained-resource warnings at shutdown while returning 0; its
assertions pass. No native capture was attempted or produced.


## Files changed

- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/combat_objective_rules.gd`
- `scripts/enemy_mechanics/bramble.gd`
- `scripts/enemy_mechanics/capacitor.gd`
- `scripts/enemy_mechanics/capacitor_view.gd`
- `scripts/enemy_mechanics/icefall.gd`
- `scripts/enemy_mechanics/lob.gd`
- `scripts/enemy_mechanics/veil.gd`
- `scripts/enemy_mechanics/wind.gd`
- `scripts/enemy_mechanics/wind_view.gd`
- `scripts/pre_battle_inspection_view.gd`
- `scripts/warband_combat_rules.gd`
- `spec/enemies/briar_weaver.md`
- `spec/enemies/gale_herald.md`
- `spec/enemies/hoarfrost_seer.md`
- `spec/enemies/hollow_mimic.md`
- `spec/enemies/slag_mortar.md`
- `spec/enemies/storm_capacitor.md`
- `tests/headless_test_programs.json`
- `tests/suites/warband_suite.gd`
- `tests/test_program_suite_runner.py`
- `spec/enemies/spx04_orders.md`
- `tests/fixtures/spx04_legacy_golden.json`
- `tests/proof_contracts/spx04_orders.json`
- `tests/suites/warband_orders_suite.gd`
- `tests/suites/warband_orders_suite.gd.uid`
- `tests/warband_order_mutations.py`
- `tests/warband_orders_probe.gd`
- `tests/warband_orders_probe.gd.uid`
- `tests/warband_orders_test.gd`
- `tests/warband_orders_test.gd.uid`
