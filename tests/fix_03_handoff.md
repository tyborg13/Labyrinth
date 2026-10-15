# fix-03 implementation handoff

Implementation only, on `codex/fix-03`, based on the existing `codex/peer-benchmark` worktree. Changes remain uncommitted. No task metadata, queue, protected design data, assets, or other damage-source behavior was changed. The design owner owns commit, review, inspection and publication.

## Acceptance and proof contract

Risk: high (shared combat health-loss path plus HUD presentation); full Godot and Python suites, focused combat and UI tests, icon/UI identity gates, and a real-renderer probe. The supplied task setup says the contract/preflight were recorded, but read-only `parallel_task.py status` reported an empty contract (`contract_ready: false`, risk `standard`). This handoff records the implementation acceptance/proof without altering owner-managed Git/task metadata.

1. Fatigue must cost `fatigue_base + cycles - 1` exactly, ignoring Expose, Chilled and Frozen, and bypass Block/Stoneskin. The reshuffle call disables incoming-hit effects; the existing private flag was renamed to describe its actual scope. Regression covers each status, all three, first/later cycles, unchanged defenses/statuses, the actual-health-loss run statistic, unchanged direct attacks and Crystal Mantle. Frozen's existing normalization suppresses Chilled; the all-three input still tests the required loss amount. Existing lethal-prevention/Last Reserve/Defiance order is preserved.
2. Audit every other player health-loss source; do not change it. See the table below.
3. Sunpath/Dawnbrand show SPENT after the rules set `turn_flags["skill_turn:<id>"]`, and WAITING after the next turn resets it. Tests trigger real movement and Light-target attacks, then read the actual HUD method. The live probe also checks visible status and native focus for both abilities.
4. Nine bad `text_token` calls fixed: Burrow/Erupt/Kindle in the shared library and their enemy views, plus Capacitor Charge/Discharge and the brazier-relight row. The legacy `light` name resolves through the existing canonical Light-condition mapping to `illuminate`. `icon_text_token` preserves existing captions, tooltips and plain-text summaries while using the existing icon renderer. Each route is regression tested; the probe traces the production draw call and checks visible pixels within every icon rectangle.
5. Lightning Strikes count uses the existing dedicated `lightning_strikes` icon. No icons or data registries were added or changed. The test rejects Shock on a strike with no Shock rider.

Analytics fields are unchanged. `spec/analytics.md` does not document the old amplified Fatigue behavior, so no spec update is needed. The fix restores the existing heuristic's direct-hit-only Chill/Freeze model; no card, tuning or heuristic score was changed.

## Health-loss audit (unchanged sources)

Line references below identify runtime resolution, not preview/replay subtraction. Expose adds its amount and is consumed; Chilled adds its fixed bonus; Frozen multiplies instead of adding Chilled. “Yes” means all three use that common incoming-hit gate, before defenses. “No” means none does. Normalization still applies in both paths.

| Source | Expose / Chilled / Frozen amplified? | Resolution / notes |
| --- | --- | --- |
| Bleed on qualifying player actions | No / No / No | `scripts/combat_engine.gd:7482`; explicit `false`, Block/Stoneskin absorb. |
| Forced-movement collision, including being the blocking unit | No / No / No | `scripts/combat_engine.gd:7006`; explicit `false`; Block/Stoneskin absorb. |
| Bramble contact damage and Ice Pillar movement-break damage | No / No / No | `scripts/enemy_mechanics/bramble.gd:92`, `scripts/enemy_mechanics/icefall.gd:100`; both call the collision helper. Bramble's later Bleed follows the Bleed row. |
| Trap trigger impact (all elements) | No / No / No | `scripts/combat_engine.gd:7358` → `:11405`; `direct=false`. Trap wakes may separately cause surface contact or collision. |
| Fire ground entry and activation-start damage | No / No / No | `scripts/combat_engine.gd:11459` → `:11405`; default `direct=false`. Rites/relics may alter the base Fire amount/immunity independently of these statuses. |
| Powder Keg explosion | No / No / No | `scripts/terrain_card_rules.gd:106` → `scripts/combat_engine.gd:11405`; explicit `direct=false`. |
| Printed card health costs (including repeated Flurry payment) | No / No / No | `scripts/combat_engine.gd:2005` → `scripts/defense_relic_rules.gd:81`; `true,false` bypasses defenses. Cards: Reprise, Glassbone Guard, Phoenix Cleave, Borrowed Spark, Thorn Crown Pact, Gate Gambit. Iron Lung's Stoneskin payment conversion happens first. |
| Empower health costs | No / No / No | `scripts/combat_engine.gd:2008` → `scripts/defense_relic_rules.gd:81`. Bloody Lunge, Blood Price, Royal Bramble, Overclock, Immolation; same payment/conversion path. |
| Relic surface-pulse/cross-damage reward, if authored for all actors | No / No / No | `scripts/combat_engine.gd:11601`; explicit `false`. Current relic rewards do not author `affects: all_actors`, so this is a supported potential source, not a shipped self-hit. |
| Glacial Mirror Reflect rebound | Yes / Yes / Yes | `scripts/enemy_mechanics/reflect.gd:35` → `scripts/combat_engine.gd:4332`; returning damage is a normal hit. The mirror's own Chill/Freeze can also modify the returned base at `reflect.gd:23`. |
| Ember Tick death burst (including Kindle bonus) | Yes / Yes / Yes | `scripts/enemy_mechanics/death_burst.gd:11` → `scripts/combat_engine.gd:4332`; on-death AoE enters the direct-hit path. Subsequent Fire follows the Fire row. |
| Player Meteorfall delayed self-hit | Yes / Yes / Yes | `scripts/surface_card_rules.gd:564` → `scripts/combat_engine.gd:11405`; explicit `direct=true`. |
| Detonate self-hit / friendly-fire explosion, unless it spares the player | Yes / Yes / Yes | `scripts/combat_engine.gd:12090` → `:11405`; explicit `direct=true`, with authored Pierce honored. |
| Delayed/line enemy threats: Icefall, Lob Slag and Arc Thrall Tether | Yes / Yes / Yes | `scripts/enemy_mechanics/icefall.gd:66`, `lob.gd:77`, `tether.gd:132`; direct hit paths. These are enemy attacks mechanically, included to distinguish their marked-ground/line appearance from passive ground damage. |
| Event HP sacrifices and hazards | No / No / No | `scripts/event_rules.gd:206`; direct out-of-combat HP adjustment clamped to at least 1, with depth event tuning applied separately. Authored sources: Bloodletter's Basin, Ossuary Gamblers, Abandoned Forge, Shrine of the Last Door, Sealed Sarcophagus, Petrified Pilgrims, Root-Choked Vault, Cinder Supplicant, Ember Font, Windcut Bridge, Frozen Champion, Storm Obelisk, Tempest Choir, Your Own Body. |
| Event maximum-HP sacrifices that clamp current HP | No / No / No | `scripts/event_rules.gd:210-212`; Name Collector, Petrified Pilgrims, Umbral Bargain. |
| Other relic/skill self-damage | No additional independent source found | Inspected all `_damage_player`, `_lose_player_health`, `_surface_damage_actor`, `_damage_actor_target` callers and all runtime HP writes. Skill draws still use Fatigue; skill movement uses ordinary Bleed/trap/ground routes. Ice/Rubble/Electrified do not independently subtract HP; conducted attacks do use normal attack amplification. |

Conventional enemy attacks (including Charge/Discharge, Erupt, Refraction, Mirror, Lightning Strikes and dragon/guardian attacks) use the existing amplified attack path and are outside the non-attack change. Player ordinary area/chain plans target opponents; exceptional self-hit routes are listed above. UI animation/replay writes mirror resolved damage and are not new damage sources.

## Proof for the design owner

No windowed command was attempted: this worker has no macOS window-server access. Headless contract validation is not screenshot proof.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-03 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/fix_03.json --result-manifest /private/tmp/labyrinth-inspection-manifests/fix-03-visual.json tests/fix_03_probe.gd --task-id fix-03
```

Expected images in the runner's isolated `user://fix_03_probe/` (absolute paths are printed as `FIX-03 CAPTURE` and recorded in the result manifest):

- `01_waiting.png`
- `02_spent_sunpath_focus.png`
- `03_spent_dawnbrand_focus.png`
- `04_next_turn_waiting.png`
- `05_all_fixed_tokens.png`

The unit brief does not request an `inspection_fixture.py` command. Fixture preparation remains with the design owner. The probe already supplies the exact HUD states and all nine token call sites plus the Lightning Strikes chip at 1920×1080, UI scale 100%.

## TODO_DESIGN

None. All perceivable changes follow the brief and use existing approved assets and captions.

## Chosen defaults

Debug/test-only: reuse the existing skill suite's deterministic seed 501, 8×8 room, 30 visible HP and target coordinates; Expose fixture 3, defense fixture 100, attack fixture 2, later cycle 2. Token sample fields are Burrow, Erupt damage 6, Kindle amount 2, Charge amount 1, Discharge damage 4, and Lightning Strikes damage 3/count 4. Probe seed 20261015, legal level-4 progression with Long Dawn/Sunpath/Dawnbrand, three settle frames, reduced motion on, and isolated test save paths. Debug token sheet uses row origin (520,120), row step 88 and label x=80; actual token font/icon sizes come from production constants. Pixel validation uses luminance range >0.1 per icon; the sheet proof region uses range 25/stdev 2. No shipped visual, tuning, text, motion or timing defaults were invented.

## Files changed

Production: `scripts/combat_engine.gd`, `scripts/run_scene.gd`, `scripts/action_icon_library.gd`, `scripts/combat_board_view.gd`, `scripts/enemy_mechanics/burrow_view.gd`, `scripts/enemy_mechanics/kindle_view.gd`, `scripts/enemy_mechanics/capacitor_view.gd`.

Verification: `tests/suites/fix_03_suite.gd`, `tests/fix_03_test.gd`, `tests/run_tests.gd` (one suite registration), `tests/fix_03_probe.gd`, `tests/helpers/fix_03_token_canvas.gd`, `tests/proof_contracts/fix_03.json`, and this handoff.

## Test results

Final focused regression: `/tmp/fix-03-final-focused.log`:

```text
FIX-03 TEST RESULT: PASS (0 failures)
```

Pre-fix reproduction: `/tmp/fix-03-before.log` reported `FIX-03 TEST RESULT: FAIL (34 failures)`. This included the Fatigue amount/analytics/Expose failures, both HUD failures, all eight original icon-call failures and the Shock count chip. Two assertions about simultaneous Frozen/Chilled normalization were corrected in the new test; shipped normalization was not changed. The later brazier alias case was added to final focused coverage.

Final headless live-scene/probe validation: `/tmp/fix-03-probe-final.log`:

```text
FIX-03 PROBE CONTRACT: PASS (5 states, 1920x1080, UI scale 100%)
```

Icon and UI identity, after all production changes:

```text
Ran 7 tests in 0.076s
OK
Ran 25 tests in 2.424s
OK
```

Logs: `/tmp/fix-03-icon_identity_policy-final.log`, `/tmp/fix-03-ui_identity_lint-final.log`.

Python discovery (`python3 -m unittest discover -s tests -p 'test_*.py' -v`), `/tmp/fix-03-full-python.log`:

```text
Ran 397 tests in 284.308s
OK (skipped=61)
```

Focused integration (each executed with the required Godot task runner):

```text
SKILL COMBAT TEST RESULT: PASS
RADIANCE PACKAGE TEST RESULT: PASS
EN01 ENEMIES TEST RESULT: PASS
EN06 ENEMIES TEST RESULT: PASS (176 checks, 0 failures)
INLINE ICON DESCRIPTION TEST RESULT: PASS
```

Logs: `/tmp/fix-03-skill_combat_test.log`, `/tmp/fix-03-radiance_package_test.log`, `/tmp/fix-03-final-en01_enemies_test.log`, `/tmp/fix-03-final-en06_enemies_test.log`, `/tmp/fix-03-final-inline_icon_description_test.log`.

First full Godot run, `/tmp/fix-03-full-godot.log`:

```text
FULL SUITE RUNTIME: 790.114 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Repeat full Godot run, `/tmp/fix-03-final-full-godot.log`, exited 0:

```text
FULL SUITE RUNTIME: 692.790 seconds (budget 900 seconds)
TEST RESULT: PASS
```

Its initial preloads preceded the final one-line brazier Light alias correction; final focused regression/probe/icon/UI/threats/HUD-buttons checks cover that addition. An attempt to cancel/restart the repeat was denied by the sandbox (`PermissionError: [Errno 1] Operation not permitted`), so it was left to finish. Do not interpret the headless probe as renderer proof.

Full Godot logs include non-fatal macOS certificate, deliberately rejected persistence, tree-access and resource-leak messages. The runner exits successfully on the first full run; no existing assertions were edited or suppressed.

Focused commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-03 && python3 tools/godot_task_runner.py --task-id fix-03 --stream -- godot --headless --path . --script tests/fix_03_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-03 && python3 tools/godot_task_runner.py --task-id fix-03 --stream -- godot --headless --path . --script tests/fix_03_probe.gd -- --check-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-03 && python3 tools/godot_task_runner.py --task-id fix-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

Final threats-at-rest recheck: `/tmp/fix-03-final-threats_at_rest_test.log`:

```text
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
```

Additional HUD integration test: `/tmp/fix-03-final-combat_hud_badges_test.log`:

```text
ERROR: Intents starts off with its semantic label intact
ERROR: ON retains semantic text and brightens the plate
COMBAT HUD BADGES TEST: FAIL
```

The two failures are stale expectations in unchanged `tests/combat_hud_badges_test.gd:60` and `:65`: they expect `INTENTS [I]` / `INTENTS ON [I]`. Both the task's starting HEAD (`codex/peer-benchmark`) and the current `scripts/run_scene.gd` set `DETAILS [I]` in `_refresh_enemy_intent_toggle` (current line 22060). This is a mismatch already present in the supplied base, not an observed failure on local master, which still has the older labels. No assertion or button wording was rewritten. All other assertions in this additional HUD test passed, including existing ready/spent ability badges and input paths. The current button-specific suite also passed: `COMBAT HUD BUTTONS TEST: PASS` (`/tmp/fix-03-final-combat_hud_buttons_test.log`).

`git diff --check` passed. No windowed captures exist yet.
