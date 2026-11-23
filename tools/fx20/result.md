# fx-20 implementation handoff

The comparison starts at `f21b6ff47` on `codex/fx-20`. This is the medium-high-risk effects integration. The worktree changes are uncommitted. The local task helper reports the original fx-15 creation base and an empty stored acceptance contract. The numbered brief supplied with the task is the acceptance contract for this handoff.

## Part 1 — Burst ownership

A resolved step claims each tile in this order: falling strike impact, dragon spell burst, area or trap, mapped shot hit, contact burst. Self gains use their own player and can share the tile. Area filtering leaves each surviving tile's authored delay and position within the cap intact. An overridden shot still flies on its existing clock.

| Resolver witness | Base | fx-20 |
| --- | --- | --- |
| Hurl Spear, Frostbolt, Snake Eyes and Dust Bolt | Each already showed one mapped hit on the merged base | All four still show one hit. The reservation uses the descriptor that selects the actual shot, including its card or enemy mapping. |
| Zekarion Skybreak, battlefield lightning and Icefall | One impact per resolved tile | One impact per tile. The strike reserves the tiles before area and surface/contact playback. |
| Meteorfall landing | The Crawler's tile at (4,2) showed both a Fire hit pair and a legacy decal on frame 24 | The Fire pair stays on frame 24. The custom status playback's decal entry is marked as baked so it stops drawing while retaining its existing feedback role. |
| Cinder Breath | Fourteen Fire pairs and one aftermath decal on the hero | Fourteen Fire pairs with the original sweep. The hit pair is the only hero impact. |
| Crownfire | Nine Fire pairs and one aftermath decal on the hero | Nine Fire pairs with the original delays. The hit pair is the only hero impact. |
| Immolation Detonate with an Ice trap | Fire and Ice both submitted on the same five tiles | One Fire pair per tile. The area claims the tiles before the trap cross. |
| Refraction | The cutout adapter played the generic Ice area on all four tiles at once, in addition to the old beam painter | One Ice pair per line tile, sweeping outwards. The wind-up uses the cutout's existing action phase and the far tile starts at its authored contact. |
| Reflected shots | The legacy sprite flew both legs. A second retained shot path played an outbound hit on the Mirror. | One fx-14 design flies both legs and hits on return. The original Mirror flash plays at the same time. |

### Director merge resolutions

| Merge site | Verdict |
| --- | --- |
| `_icefall_cutout_strike`, `_timed_strike`, `_resolved_contact_bursts` and load clears | Keep all three and their independent clears. |
| `suppresses_decal` before construction of the strike decal dictionary | Keep the check before the dictionary. Covered spell and contact tiles are suppressed once. The custom Meteorfall status path also masks preconstructed decals at presentation. |
| Enemy phase area, trap/contact reservation and `DragonSpell.burst_cue` | Changed the order. Reserve the strike and dragon schedule first, then prepare area, trap, shot and contact in precedence order. |
| Icefall `present_sky_strike` and contact `present_tile_bursts` | Keep both. The strike claims its cells before observed contact events are considered. |
| Board exit, board frame and floor overlay | Keep both players' exit handling and frame advance. Keep both early returns for elemental replacement and mapped shots. |
| Export presets | All six already include `data/shots.json`, `data/tile_bursts.json`, `data/self_bursts.json` and `data/strikes.json`. |

## Part 2 — Attack effects

1. Removed the hero's cast charge painter and its call. Frostbolt and Sunlance retain the existing cast motion and action lengths.
2. Removed both Vyraketh bite-stroke submissions. The non-Shadow dragon physical path claims occupied named tiles only. Health, Block, Stoneskin, Mantle, Defiance or defeat selects the hit row. The Vyraketh bite spent 8 Health in the open case and 8 Block with zero Health loss in the blocked case. Both stamped Fire hit when the number appeared. Tharokh's three-tile Worldspine Claw stamped only the hero's tile. Noctyrax keeps the existing Shadow presentation.
3. Removed the Veilbound Acolyte's contours. The shared trail samples the existing posed `strike_hand` and `strike_arm` bones. Both rigs have those bones. An unavailable rig supplies no substitute trail. Closing Shade keeps its Shadow contact.
4. Removed both Glacial Mirror beam lines and bypassed the cutout adapter's simultaneous area. On the four-tile witness, the stamps start on frames 26, 32, 37 and 42. Tile 3 uses Ice hit. A cancelled resolver descriptor starts no animation or burst. The sprite fallback also sweeps on its original eight-frame clock.
5. Reflected Hurl Spear submits Spear flight and Spark hit. Frostbolt submits Lance flight and Glass hit. Both reverse their heading and submit the return hit with the number on frame 17. The return uses the actual reflected attack's origin, including an Illusion origin for an echo.
6. The Umbra Refraction witness omits tile (4,2) and stamps the other three. Reduced-motion Vyraketh uses the existing tile player's still. All stamp submissions use the board clock without adding animation frames.

The following counts are the timed frames recorded by RunScene and the 60 Hz sample on which the fixture completes. Each value matched on both revisions.

| Case | Timed frames | Completion frame |
| --- | ---: | ---: |
| Frostbolt cast | 54 | 60 |
| Sunlance cast | 18 | 56 |
| Vyraketh bite | 51 | 80 |
| Vyraketh bite, fully blocked | 51 | 77 |
| Tharokh claw rake | 63 | 96 |
| Veilbound Acolyte melee | 36 | 71 |
| Refraction | 66 | 98 |
| Cancelled Refraction | 0 | 22 |
| Refraction in the Umbra | 66 | 98 |
| Refraction sprite fallback | 8 | 74 |
| Reflected Hurl Spear | 7 | 52 |
| Reflected Frostbolt | 7 | 52 |

Other procedural attack drawing encountered in the owned board methods includes Bile Bloomer's Shale Burst release fragments, Cinder Ooze's bloom, Vaeloryx's wind feedback and the legacy travel for Fire and Lightning shots without an fx-14 mapping. Those are outside the replacements named in the brief.

## Files

- `scripts/run_scene.gd` and `scripts/resolved_contact_bursts.gd` sequence the competing effects, reserve their tiles and mask replaced decals.
- `scripts/combat_board_view.gd` and `scripts/veilbound_acolyte_cutout/fx.gd` remove the specified primitives.
- `scripts/enemy_strike_points.gd` and `scripts/enemy_strike_trail.gd` opt Veilbound into the shared posed-hand path. The existing trail must know the two rig bones to use the authored motion.
- `scripts/enemy_mechanics/reflect_view.gd` owns the Mirror's flight and sweep integration, including the fallback beam clock.
- `scripts/shot_fx.gd` adds the reflected phase and hit-row input to the retained renderer, and an impact suppression flag so a winning area leaves the flight visible. The existing one-way interface cannot reverse flight or submit the hit at the origin.
- `scripts/tile_burst_fx.gd` accepts an excluded-tile map on the existing spec. Applying the exclusions after planning preserves authored tile limits and delays. The effect data, art, shaders and dragon profiles are protected and were left as supplied.
- `tools/fx20/` contains resolver fixtures, the verifier, the native capture script, two size-specific capture contracts and their Godot sidecars. The requested launch wrapper is at `/private/tmp/labyrinth_codex/fx-20/native.sh`.

## Verification

| Check | Result |
| --- | --- |
| fx-12 | `TEST RESULT: PASS` |
| fx-13 | `TEST RESULT: PASS` |
| fx-14 and affected suites | `FX-14 VERIFY: PASS (1809 checks, 0 failures)` · `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` |
| fx-15 | `FX-15 VERIFY PASS (0 failures)` |
| fx-17 | `TEST RESULT: PASS` |
| fx-18 | `FX-18 VERIFY PASS (0 failures)` |
| fx-20 matrix | `FX-20 VERIFY: PASS (172 checks, 0 failures)` |
| Dragon, Reflect, illusion/terrain and enemy mechanic-clock suites | `FX-20 VERIFY: PASS (3255 checks, 0 failures)` |
| EN05 live integration | `EN05 LIVE INTEGRATION: PASS (22 checks, 0 failures; headless logic only)` |
| Cel look cache | `CEL_STATUS current` |
| UI identity lint | `Ran 25 tests in 8.937s` · `OK` |
| Rules text lint in Python default | `PASS: Rules text lint (16 existing hits)` |
| Python suite audit | `ISOLATION AUDIT: 58 modules` |
| Python default | `Ran 194 tests in 38.660s` · `FAILED (failures=1)` |
| Changed script parse | All 12 scripts returned exit 0 in separate task-runner `--check-only` invocations. |

The Python failure is the tracked-sidecar check. The unchanged index from `f21b6ff47` lacks `tools/flt01/fight_probe.gd.uid` and `tools/flt01/renderer_check.gd.uid`. The Python runner also reports that the read-only Git directory prevents it from updating its timing cache. The named development-workflow path `tests/en05_integration_sync_test.gd` is absent from this merged checkout. The EN05 suite and its existing live integration entry point ran.

The original fx-18 launcher stages its historical board while leaving its dependencies at the current revision. That board still references the removed Bramble and Veilbound painters. The fx-20 `--verify-fx18` command stages those original dependencies too. It runs the unmodified fx-18 verifier and its original assertions. The fx-12, fx-13 and fx-15 result documents are absent from this merge. Their verify scripts and original change commits are present.

- [FX-20 matrix log](/private/tmp/labyrinth_codex/fx-20/matrix-complete.log)
- [Before and after take data](/private/tmp/labyrinth_codex/fx-20/headless/)
- [Integrated fx-18 verifier log](/private/tmp/labyrinth_codex/fx-20/fx18-integrated.log)
- [Focused suite log](/private/tmp/labyrinth_codex/fx-20/focused-final.log)
- [Script parse logs](/private/tmp/labyrinth_codex/fx-20/parse/)
- [Python default summary](/private/tmp/labyrinth_codex/fx-20/python-default-final/summary.json)

## Proof for the design owner

The capture script uses the fx-15 MovieWriter clock and a 1920×1080 SubViewport at 100% UI scale with the combat HUD and `LABYRINTH_CEL_LOOK=all`. Each of the eight cases outputs a before and after strip with release, contact, and contact +100, +233 and +366 ms. The witness crops are 640×480, or 960×720 for dragons and Refraction. A separate 300-frame take records Frostbolt reflected by the Mirror and the subsequent Refraction.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-20 && /private/tmp/labyrinth_codex/fx-20/native.sh
```

For each case, the launcher prints `/private/tmp/labyrinth_codex/fx-20/native/{before,after}/<case>/{strip.png,native-evidence.png,take.json,manifest.json}`. The five-second MP4 is `/private/tmp/labyrinth_codex/fx-20/native/frostbolt-reflect-refraction.mp4`. The headless dry run produced its before and after `take.json` files and planned the native samples. Image and video output awaits a window-server run.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-20 && /private/tmp/labyrinth_codex/fx-20/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-20 && /private/tmp/labyrinth_codex/fx-20/native.sh --verify-fx18
```

## TODO_DESIGN placeholders

- `TODO_DESIGN_REFLECTED_SHOT_FLOOR_ROW` is empty. The fx-14 atlas has hit rows only. A return without pool loss uses the existing fx-17 floor pair.
- `TODO_DESIGN_REFLECTED_UNMAPPED_FLIGHT` is empty. Fire and Lightning can resolve with no fx-14 flight design. Those returns still take the existing time and use the fx-17 contact at arrival.

## Chosen defaults

The proof inherits fx-15's seed, isolated 60 Hz clock and 900-frame take budget and 420-frame teardown allowance. The hero starts at (4,4), the Mirror at (4,1), and the dragon, melee and ranged witnesses use the named positions and held footprints in `cases.gd`. Fixture Health is 30, the blocked bite starts with 20 Block and the trap has 4 damage. Crops centre on the projected bounds of the hero, source and named targets. The sample offsets are 6, 14 and 22 capture frames. The native runner has 300 seconds per take.

## Open issues

Native captures, the recording and their visual inspection await the design owner's window-server access. The Python default group has the existing two missing tracked sidecars.
