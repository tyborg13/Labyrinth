# en-02 implementation handoff

Uncommitted on `codex/en-02`, starting HEAD
`8290eb1833e24fc7c025e4ef54005c28c454ea52`. No commit, push, branch change,
peer review, signoff request, queue edit or windowed run was performed.

## Acceptance

| Brief requirement | Implementation and proof |
| --- | --- |
| 1 — Icefall mark | Range-5 perpendicular three-tile line; diagonals use the row; fixed saved marks, impassable/off-board filtering; all eight directions tested. Real compass, intent-row and threat values. |
| 2 — Icefall landing and pillars | Forced zero-random-weight next intent; 5 ice damage to actors on held tiles; surviving units prevent pillars; 3 enemy-turn boundaries including landing's own, LOS/path blocking, 2-damage collision shatter. Existing Iskaldra pillar art, exact 0.18-second fall, 0.30-second frost puff/feedback. Unique saved terrain-generation counter. Untargetable/undamageable terrain without HP. Wind precedes terrain lifetime countdown; last-round pillars still collide. |
| 3 — Rime Bolt / Withdraw | Staged values copied verbatim; existing ranged/Chilled and move-away/Block verbs. Illegal ranged intents excluded. |
| 4 — Wind rules | Closest hazard in four cardinal rays within 3; ties toward Herald; 2 boundaries, Push 1, downwind-first order, existing collision/surface/trap/death paths. Herald Anchored for all pushes/pulls; boss/guardian/construct wind exceptions; helpers remain pushable. Refresh, direct/source/follower death cancellation, frozen/other-enemy turns and save/load tested. Construct immunity reads only the enemy definition's `construct: true`. |
| 5 — Wind presentation | Approved icon, active chevrons and dashed Call layers, 22% white-blue, 2 per tile, 40 px/s, static reduced motion. Real-resolver arrows/contact markers, including focused Call; card previews are not duplicated. HUD under clock with exact Wind · rounds text, a 12 px TEXT-colour screen-direction arrow, and quadrant direction words. Chevrons: 14 px width, 2 px stroke, half-tile spacing. All tooltip/icon copy matches director feedback 1. Written windowed probe and proof contract; renderer inspection pending owner. |
| 6 — Gust Bolt / Still Air | Existing ranged 3 + Push 1 at range 4 and Block 5 from protected staged data. |

Generic `next_intent` forcing and zero random weights are implemented in the
shared engine. Enemy action events keep the existing schema and report action
types, directions, resolved tiles and losses. Old saves require no migration.
Player/card kill credit and existing Ember behavior are preserved.

`data/encounters.json` is untouched. Per director feedback 1, enc-01 has landed
and the director adds the four specified ice/air groups after merge.

## Enemy and asset integration

- Hoarfrost Seer: controller, Rime Hall, 12 HP / initiative 12 / 11 Embers;
  initial authored mean cycle 17, repeat 16.667 including landing. Closest:
  Frostglass Lancer and Acolyte. Counterplay: leave the line or put foes on it.
- Gale Herald: controller, Hollow Gale, 14 HP / initiative 13 / 11 Embers;
  authored weighted cycle 18.167. Closest: Chainbound Gaoler. Counterplay:
  stand upwind or kill the Herald.
- Both use approved 255x255 static paintings, no rig/idle sheet, existing
  art-scale/offset defaults; Gaoler baseline 251 and standard-band height 227
  relative to Lancer 239. Dedicated native 128x128 head/shoulder crops have
  8 px transparent top margins and explicit turn-clock registrations.
- Icefall/Wind icons are keyed/trimmed onto 64x64 canvases with the existing
  4 px Blink fit padding. All four source hashes match the protected record.
- Density sources/manifests are registered/adopted/processed, rest recording
  reports zero new rig rests, and the shadow cache was refreshed. The existing
  Iskaldra pillar painting is used. No art/audio/font was generated or downloaded.
- The two new static enemies have explicit fallback checks in the existing
  contextual-cutout suite; all existing rig assertions remain unchanged.
  Density tests add their required live-code scale assertions.
- Balance assumptions/comparisons are mirrored in the spec and scorer; no
  card coefficients or director-authored enemy values changed.

## Observed checks

- `tests/en02_enemies_test.gd`: `EN02 ENEMIES TEST RESULT: PASS (212 checks, 0 failures)`.
- `tests/en02_enemies_probe.gd -- --check-only`:
  `EN02 ENEMIES PROBE CONTRACT: PASS (8 states, 1920x1080, UI scale 100%)`.
- `tests/test_icon_identity_policy.py`: `Ran 6 tests in 0.074s` / `OK`.
- Card heuristic suites: `Ran 38 tests in 0.047s` / `OK`.
- `tests/test_board_pixel_density.py`: `Ran 41 tests in 90.826s` / `OK`.
- Density CLI: `CHECK-OK`; rest records: `RECORDED-RESTS 0 file(s)` for each static enemy.
- Shadow CLI: `UNIT SHADOW CACHE GENERATED: res://assets/generated/unit_shadow_cache.res entries=44 sources=38`.
- Asset checks: `EN02 DATA/ASSET CHECK: PASS`, four `APPROVED RAW HASH: PASS` lines.
- Pure Python parsing: `EN02 PYTHON PARSE: PASS`; `git diff --check` clean.
- Both inspection fixtures: `Inspection fixture verified.` and
  `INSPECTION_FIXTURE_VERIFIED` with `ok:true`.
- Full suite after director feedback 1: `TEST RESULT: PASS` (runner exit 0); final runtime run is logged
  at `/private/tmp/en02-feedback-full-suite.log`.

Earlier checks exposed the new static-roster assumption and missing static
scale assertion, both fixed. The first full run timed out at 300 seconds while
still progressing; subsequent full runs use 900 seconds. A Python bytecode
check could not write the macOS cache outside the sandbox, so syntax was checked
with `compile()` without filesystem writes instead. The first feedback-focused check found a new assertion referencing the wrong
icon registry constant (`ICONS`); it was corrected to `KEYWORDS`, then all 212
checks passed. No existing master failure assertion was rewritten.

## Director feedback 1

1. Native capture uses a 1920×1080 UPDATE_ALWAYS SubViewport texture, following
   movement_undo_probe; 100% UI scale is asserted at every capture.
2. Frost puff is 0.30 seconds after the 0.18-second fall.
3. Ice Pillars have no HP, cannot be targeted/damaged by attacks, and leave
   terrain only through expiry or a push collision.
4. Wind pushes resolve before terrain countdown; last-round collision is tested.
5. Pillar tooltip matches approved copy with the current remaining rounds.
6. Wind words and the 12 px TEXT-colour HUD arrow follow screen quadrants.
7. Chevrons use 14 px width, 2 px stroke, two per tile at half-tile spacing,
   #cfe3f2 at 22%, 40 px/s drift, static under reduced motion.
8. Constructs use only the enemy definition's construct flag; bosses, guardian
   leaders and Anchored units retain wind immunity.
9. Icefall and Wind icon descriptions match the supplied text.
10. Herald Anchored tooltip matches the supplied text.
11. Encounter data is untouched; the director adds groups after merge.
12. Focused suite, full suite and icon audit rerun; exact result lines above.

Design placeholders: none remain in en-02 implementation, tests or documents.

## Chosen defaults

Only debug/internal fields: seed 20261012, 11x11 fixture grid, hero (5,5), caster
(5,2), fixture hero HP 50, helper enemy HP 20, mid-fall elapsed 0.09 seconds,
mid-push progress 0.5, proof-region luma range 70/stdev 12, isolated save/probe
paths, serial counter initial 0, focused-suite minimum 212 checks, debug construct fixture id
`en02_construct_fixture`, full-suite runner timeout 900 seconds after the
observed 300-second timeout. No new production tuning was chosen for this feedback.

## Proof for the design owner

No rendered PNGs were captured in the sandbox, which has no window-server
access. The director reported failed root-window captures; the probe now uses
the same native SubViewport capture pattern as movement_undo_probe. The eight planned images are under the runner's isolated
`user://en02_enemies_probe/`: `01_icefall_marks.png`,
`02_icicles_mid_fall.png`, `03_ice_pillars.png`,
`04_call_wind_dashed_preview.png`, `05_wind_at_rest_hud.png`,
`06_wind_mid_push.png`, `07_wind_after_push_hud.png`,
`08_wind_reduced_motion.png`. The result manifest will record their exact paths.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/visual_probe_runner.py tests/en02_enemies_probe.gd --task-id en-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/en02_enemies.json --result-manifest /private/tmp/labyrinth-inspection-manifests/en02-visual-proof.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/inspection_fixture.py --task-id en-02 --run-id en02-hoarfrost-seer --scenario combat --enemy-types hoarfrost_seer --enemy-positions 5:2 --enemy-intents icefall --player-position 5:5 --umbra-stage clear --biome iskaldra --manifest /private/tmp/labyrinth-inspection-manifests/en02-hoarfrost-seer.json --summary 'Hoarfrost Seer before Icefall marks and landing' --launch
cd /Users/borgerding/workspace/Labyrinth.worktrees/en-02 && python3 tools/inspection_fixture.py --task-id en-02 --run-id en02-gale-herald --scenario combat --enemy-types gale_herald --enemy-positions 5:2 --enemy-intents call_the_wind --player-position 5:5 --surfaces fire@6:5 --umbra-stage clear --biome vaeloryx --manifest /private/tmp/labyrinth-inspection-manifests/en02-gale-herald.json --summary 'Gale Herald before Call the Wind beside Fire' --launch
```

## Open owner work

Capture/inspect the fixed windowed proof, add the pools after merge, and
complete the owner workflow. The task helper's recorded contract
has empty acceptance/proof arrays (`contract_ready:false`), despite the task
brief assigning that phase to the owner. No task metadata was changed.

## Files changed

- `assets/generated/unit_shadow_cache.res`
- `data/enemies.json`
- `scripts/action_icon_library.gd`
- `scripts/board_surface_rules.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/enemy_intent_compass.gd`
- `scripts/guardian_relic_rules.gd`
- `scripts/run_scene.gd`
- `spec/assets/board_pixel_density/outputs.json`
- `spec/assets/board_pixel_density/registry.json`
- `spec/card_balance_heuristic.md`
- `spec/icon_identity_policy.md`
- `tests/suites/contextual_cutout_suite.gd`
- `tests/test_board_pixel_density.py`
- `tests/test_icon_identity_policy.py`
- `tools/card_heuristic.py`
- `assets/art/enemies/gale_herald.png`
- `assets/art/enemies/hoarfrost_seer.png`
- `assets/art/icons/icefall.png`
- `assets/art/icons/wind.png`
- `assets/art/portraits/gale_herald.png`
- `assets/art/portraits/hoarfrost_seer.png`
- `scripts/enemy_mechanics/icefall.gd`
- `scripts/enemy_mechanics/icefall_view.gd`
- `scripts/enemy_mechanics/wind.gd`
- `scripts/enemy_mechanics/wind_view.gd`
- `spec/assets/board_pixel_density/sources/assets/art/enemies/gale_herald.png`
- `spec/assets/board_pixel_density/sources/assets/art/enemies/hoarfrost_seer.png`
- `spec/assets/enemies/raw_sha256.txt`
- `spec/enemies/gale_herald.md`
- `spec/enemies/hoarfrost_seer.md`
- `tests/en02_enemies_probe.gd`
- `tests/en02_enemies_test.gd`
- `tests/proof_contracts/en02_enemies.json`
- `tests/suites/en02_enemies_suite.gd`
- `tools/process_en02_assets.py`
- `spec/enemies/en02_implementation_handoff.md`
