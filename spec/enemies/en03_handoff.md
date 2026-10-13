# en-03 implementation handoff

All changes are uncommitted on `codex/en-03`. No commit, push, merge, branch change,
peer review, sign-off request, or queue update was performed. The design owner
owns those steps and fresh windowed inspection. `parallel_task.py status` reported
an empty task contract (`contract_ready: false`); its metadata was left unchanged.
The acceptance/proof contract below records what this implementation verifies.

## Acceptance criteria

| Requirement | Implementation and proof |
| --- | --- |
| 1. Paired Arc Thrall compositions | RoomGenerator `_apply_spawn_groups`; add a mate or replace the last other unit at `max_units`; summons untouched; focused parity/cap tests. An impossible all-thrall odd hard cap drops the unmatched remainder to preserve both invariants. |
| 2. Tether | Held partner/path; exact row/column/terrain/range geometry; hero-first alignment ≤3; friendly fire 4 + Shock 1; dead/out-of-line cancellation; at-rest path/tiles/damage preview; violet dashed chest line; existing Chain ribbon material, three seeded eight-segment flickers over 0.3 s plus a 0.1 s fade. Focused geometry/resolution/status/save tests and verified push-into-beam fixture. Exact director dash/flicker settings and card-aim coexistence are covered by focused/live regression tests. |
| 3. Arc Jab | Protected Move 2 + melee 3 + Shock 1 data; existing resolver and focused resolution test. |
| 4. Fade/Veil | Behind-hero Blink ≤4 using round-tagged movement direction; occupied/range/no-destination cases; 35% body + 2 px approved violet rim; visible health/intent/status badge; adjacent-only single targeting; area/surface/secondary chains/collisions preserved; real save/load and Undo compatibility tests. Three looping wisps use the director's rise, duration, stagger and alpha; exact tooltip/target-denial copy is wired to status, target feedback and the existing transient invalid-click/drag message overlay. |
| 5. Ambush | Generic forced `next_intent`; zero weight never random; re-Blink when separated; melee 7; Veil ends after the action; normal hero threat tile. Impossible forced strikes fall back to Slash under the shared AI rule. Focused preview/strike/fallback tests. |
| 6. Slash | Protected Move 2 + melee 4 data and existing movement/melee resolver. |
| Shared integration | Exact protected JSON equality, loaded sprites/portraits, explicit turn-clock identities, icon registry/policy, static fallback decisions, density adoption/process/rest record/check/shadow cache, authored cadence comparison in spec + scorer, existing enemy action analytics. |
| Encounters | enc-01 has landed on the integration branch. Director feedback 1 assigns all three biome groups to the director; no `data/encounters.json` edits. |

Risk tier: high (shared combat, targeting, saves and player-facing feedback).
Required proof: focused mechanics/schema/portrait suite, affected presentation and
density suites, full Godot suite, and the 1920×1080/100% real-renderer probe.
Inspection expectation: two verified pre-action combat fixtures, then owner
inspection of the fresh nine-image probe. Windowed proof is pending because this
worker has no macOS window-server access; no windowed command was attempted.

## Files changed

- Mechanics: `scripts/enemy_mechanics/tether.gd`, `veil.gd`, `tether_view.gd`, `veil_view.gd`.
- Integration: `data/enemies.json`; dispatch/selection/targeting hooks in `scripts/combat_engine.gd`; display hooks in `scripts/combat_board_view.gd`; composition-only `scripts/room_generator.gd`; portrait/animation dispatch in `scripts/run_scene.gd`.
- Shared identities/compatibility: `scripts/action_icon_library.gd`, `scripts/enemy_intent_compass.gd`, `scripts/enemy_strike_points.gd`, explicit static roster decisions in `scripts/cutout_context.gd`, two snapshot leaf rules in `scripts/movement_undo_rules.gd`.
- Approved derived art: both enemy PNGs, both portrait PNGs, `assets/art/icons/{tether,veil}.png`; untouched registration sources under `spec/assets/board_pixel_density/sources/assets/art/enemies/`; density `registry.json`/`outputs.json`; approved hash ledger `spec/assets/enemies/raw_sha256.txt`; refreshed `assets/generated/unit_shadow_cache.res`; repeatable `tools/process_en03_enemy_assets.py`.
- Tests: `tests/suites/en03_enemies_suite.gd`, `tests/en03_enemies_test.gd`, `tests/en03_enemies_probe.gd`, its JSON proof contract, `tests/en03_fixture_check.gd`; full-suite preload, focused and live dispatch lines in `tests/run_tests.gd`; static-only coverage in `tests/suites/contextual_cutout_suite.gd` and `tests/test_board_pixel_density.py`.
- Documentation/scorer: `spec/enemies/{arc_thrall,gloam_stalker,en03_handoff}.md`, en-03 rows in `spec/card_balance_heuristic.md` and `tools/card_heuristic.py`.

The legacy contextual-cutout assertion remains unchanged for every existing rig.
The two new static enemies instead assert the explicitly approved static fallback
and existing impact feedback. The strike registry explicitly retains the existing
generic target arc for these static bodies; no rig or new attack motion is invented.
Density tests now check static enemy scale against live `art_scale` as they do for
rigs, while retaining all original rig and prop checks.

## Verification

Observed result lines and logs are recorded here after the final checks. Earlier
failed runs were repaired: parser/type integration, random-selection test isolation,
Undo request bookkeeping, the blocked first fixture, and the static roster registry
expectations, plus suppression of Shock/death-cancelled beam FX. The first full run timed out with
`error: command timed out after 300 seconds.` The next full run reported
`TEST RESULT: FAIL (5 failure(s))` for the two new static identities; these findings
were addressed through explicit registry decisions and static-specific coverage.
No assertion failing on the existing master roster was rewritten.

- Focused mechanics + live feedback regression (`tests/en03_enemies_test.gd` through the Godot task runner): `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)`, runner exit 0 (`/private/tmp/en03-feedback1-focused.log`).
- Feedback 1 full regression (`tests/run_tests.gd` through the Godot task runner with `--timeout 1200`): `TEST RESULT: PASS`, runner exit 0 (`/private/tmp/en03-feedback1-full-suite.log`).
- Protected JSON: `EN03 PROTECTED DATA CHECK: PASS`.
- Feedback 1 design/proof checks: `EN03 DESIGN PLACEHOLDER CHECK: PASS (none remaining)`; `EN03 PROBE CONTRACT CHECK: PASS (9 native 1920x1080 captures)`; encounter diff exit 0 (untouched).
- Assets: `EN03 ASSET GEOMETRY AND PORTRAIT CHECK: PASS` (body ratios 0.9498/0.9247, baseline 251, portrait top 8).
- Icon identity (`python3 tests/test_icon_identity_policy.py`): `Ran 6 tests in 0.086s`, `OK`, exit 0 (`/private/tmp/en03-feedback1-icon-audit.log`).
- Heuristic Python checks (`python3 -m unittest discover -s tests -p 'test_card_heuristic*.py'`): `Ran 38 tests in 0.038s`, `OK`; JSON assumptions exported to `/private/tmp/en03-balance-assumptions.json`.
- Density tool: `CHECK-OK`; each static entry's `--record-rests` reports `RECORDED-RESTS 0 file(s)` because there is no rig to rebake.
- Shadow cache: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=44 sources=38`.
- Feedback 1 probe parse-only check: runner exit 0, no script errors (`/private/tmp/en03-feedback1-probe-parse.log`). This is not renderer proof.
- Both fixture wrappers: `Inspection fixture saved.`, `Inspection fixture verified.`, JSON `ok: true`.
- Mechanic fixture checks: `EN03 FIXTURE thralls: PASS`, `EN03 FIXTURE stalker: PASS`.
- Affected strike registry (`tests/enemy_strike_trail_test.gd` through the Godot task runner): `ENEMY STRIKE TRAIL TEST RESULT: PASS`.
- Contextual/static feedback (`tests/contextual_cutout_test.gd` through the Godot task runner): `CONTEXTUAL CUTOUT TEST: PASS`.
- Density Python suite: `Ran 41 tests in 86.326s`, `OK` (`/private/tmp/en03-board-density-tests.log`).
- Full suite before the final Shock-FX correction: `TEST RESULT: PASS`, runner exit 0 (`/private/tmp/en03-full-suite-final.log`).
- Full suite after the Shock-FX correction: `TEST RESULT: PASS`, runner exit 0 (`/private/tmp/en03-full-suite-complete.log`).
- Final `git diff --check`: exit 0; all changes remain uncommitted.

Godot also emits the environment message
`ERROR: Condition "ret != noErr" is true. Returning: ""` from
`get_system_ca_certificates (platform/macos/os_macos.mm:1014)`; passing runs returned
0 despite that certificate-store message. The full suite also ends with `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` No assertion failure accompanies it. The full suite includes an intentional
progression-outbox failure-path log; test result lines remain authoritative.

## Director feedback 1

The failed owner capture had a card aim effect active. The former early return
for any effect suppressed Tether damage forecasting; it now suppresses only
resolving animations. A live RunScene regression asserts the card effect is
present and both hero/enemy HP forecasts reach the health-bar overlay. Card aim
paths, attack tiles and existing card damage values keep their ownership.

The probe renders RunScene into a native 1920×1080 SubViewport with
`UPDATE_ALWAYS`, captures that texture after `frame_post_draw`, and asserts both
the native size and the actual 100% UI scale. No image is resized.

All six supplied design decisions are implemented: exact Tether/Veil tooltip
copy and invalid-target reason (including real invalid click feedback without
combat changes); 2 px/85%/10 px/6 px/24 px/s dashed telegraph;
three eight-segment ±3 px flickers at 100%/40% over 0.3 s followed by a 0.1 s
fade; and three 30%-to-zero curls rising 12 px over 1.6 s, staggered 0.53 s.
Reduced motion holds dashes/beam geometry static and omits wisps. No design
placeholders remain. Encounter data remains assigned to the director.

## Chosen defaults

Only test/proof values were chosen: `TEST_SEED=41027`, `TEST_HERO_HP=30`,
`TEST_GRID_SIZE=9`, `SETTLE_FRAMES=8`, `LIVE_SETTLE_FRAMES=8`, `MID_PROGRESS=0.5`, and the debug fixture
positions/hand named by the commands below. Proof-region fields are `rect=[260,110,1400,780]`, `min_luma_range=8`, `min_luma_stdev=2`. The full-suite timeout is 1200 s
after its observed 300 s timeout. Production numbers/text come from protected
data, brief constraints, or the existing fallback implementation. Sprite
registration maximizes fit within the approved band/canvas; portrait head points
are measured from the approved paintings. No new audio/art/font was generated.

## Proof for the design owner

Real renderer, exactly 1920×1080 at 100% UI scale (native SubViewport texture;
probe fixes and asserts SettingsStore/root scale 1.0 and rejects resized captures). Output is
`output/en03-enemies/<unix timestamp>/01_…png` through `09_…png`; no fresh
captures exist from this worker. The owner's failed pre-feedback captures remain
at `output/en03-enemies/1791847630/` and do not prove the fixes. The contract
enumerates every exact image name.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-03 && python3 tools/visual_probe_runner.py --task-id en-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/en03_enemies_probe_contract.json --result-manifest /private/tmp/en03-enemies-feedback1-visual-proof.json tests/en03_enemies_probe.gd
```

Thrall fixture: clear row beam between `(2,5)` and `(6,5)`; hero `(4,3)` can
Buffet the crawler from `(4,4)` into beam tile `(4,5)`. Its existing Lunge intent schedules its movement after Tether at the tied clock time. The headless semantic
verifier checks the crawler survives the push and takes the beam damage.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-03 && python3 tools/inspection_fixture.py --task-id en-03 --run-id en03-thralls --manifest /private/tmp/labyrinth-inspection-manifests/en03-thralls.json --scenario combat --enemy-types arc_thrall,arc_thrall,crawler --enemy-positions 2:5,6:5,4:4 --enemy-intents tether,arc_jab,lunge --player-position 4:3 --umbra-stage clear --seed 41027 --hand buffet,quick_stab --launch
```

Stalker fixture: Gloam Stalker at `(6,4)` about to Fade, hero `(4,4)`; headless
verification confirms it has a legal Blink destination.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-03 && python3 tools/inspection_fixture.py --task-id en-03 --run-id en03-stalker --manifest /private/tmp/labyrinth-inspection-manifests/en03-stalker.json --scenario combat --enemy-types gloam_stalker --enemy-positions 6:4 --enemy-intents fade --player-position 4:4 --umbra-stage clear --seed 41027 --hand quick_stab,pale_spark --launch
```

The fixtures were generated/verified headless; their `--launch` phases were not
run. After the design owner commits, regenerate the manifests with these same
commands before binding inspection or publication to that HEAD.
