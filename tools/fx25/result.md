# fx-25 Shadow contact playback

The comparison uses base `85d4a8f5c` and the uncommitted changes on `codex/fx-25`. The base overlay restores the original catalog and changed scripts at their original resource paths. Both revisions load the approved atlases.

## 1. Mapping

`data/tile_bursts.json` now maps Shadow to `shadow` and includes it in `replace_targeted`.

## 2. Shadow hit inventory

The inventory covers the production enemy intents and the actions and card-level elements in the card catalog, equipment, skills and upgrades. There are four melee, three ranged, two area actions and Eclipse. There is no hero Shadow damage card. Shadow Step and Shadow Gate have no qualifying hit.

| Enemy and intent | Action | Range | Authored pattern | Presentation after fx-25 |
| --- | --- | ---: | --- | --- |
| Veilbound Acolyte · Closing Shade | `melee` | 1 | One target after an approach of up to 2 tiles | FX-17 Shadow contact pair at the struck tile |
| Gloam Stalker · Ambush | `melee` | 1 | One adjacent target after the Stalker blink when needed | The nested strike feeds FX-17 at the cutout's contact pose |
| Gloam Stalker · Slash | `melee` | 1 | One target after an approach of up to 2 tiles | The cutout contact adapter feeds FX-17 on the struck tile |
| Noctyrax · Void Claw | `melee` | 1 | One target after an approach of up to 2 tiles, measured from the 2×2 footprint | Protected dragon claw presentation |
| Veilbound Acolyte · Veil Needle | `ranged` | 2 | One target | FX-14 `shade` flight and `hit_gloom`. FX-17 reserves the mapped hit. |
| Hollow Mimic · Echo | `ranged` | 4 | One target, then a separate Retaliate action | FX-14 `shade` resolves; the live cutout publishes `hit_gloom` at contact. FX-17 reserves it. |
| Hollow Mimic · Shade Bolt | `ranged` | 4 | One target | FX-14 `shade` resolves; the live cutout publishes `hit_gloom` at contact. FX-17 reserves it. |
| Noctyrax · Night Coil | `aoe` | 3 | Committed line from a 2×2 footprint, flank 1, with pull | Protected dragon Shadow source, endpoint streams and tile impacts |
| Noctyrax · Starless Breath | `aoe` | 4 | Committed fan from a 2×2 footprint, minimum flank 1 | Protected dragon Shadow source, endpoint streams and tile impacts |
| Noctyrax · Last Eclipse | `umbra_eclipse` | — | Arena tiles outside protected light, followed by a separate summon | Protected Eclipse and dragon ground presentation |

No production Shadow `terrain_burst` or non-dragon Shadow `aoe` is authored. The proof runs regular ranged, range-0 and terrain-burst area shapes through the real enemy resolver and RunScene with encounter-local descriptors. The ranged area fixture has no existing projectile. Both production ranged areas use Noctyrax's procedural Shadow stream and remain outside the replacement.

## 3. Hit rows and playback

FX-12 plays a rear/front pair on visible resolved Shadow area tiles within the shared `MAX_TILES` cap. The FX-20 reservation keeps one pair per tile per step and retains the Manhattan board-clock delay. The area witness submits all three pairs on sample 6. The hero plays the hit row. The unoccupied neighbours play the floor row with the authored 0.033-second delay. The 30-tile probe produced the same 24 tiles, order and delays for all six elements. No resolver witness exceeded the cap.

The fully blocked witness spent four Block and zero Health and selected the hit row. A surviving prop that loses Health now selects the hit row for every element. The shared hit detection also covers Stoneskin, Mantle, Defiance and defeat. The Umbra witness omitted tile `(6,4)` and kept the delays on the two visible tiles. Reduced motion submitted all three pairs on sample 0 with no stagger and displayed Shadow frame 4. Each of the three regular melee contacts submitted one hit pair at its original contact. Every authored ranged witness submitted one `hit_gloom` and zero tendril pairs.

### `hit_tiles` caller audit

| Caller | Effect of counting surviving terrain Health loss |
| --- | --- |
| `TileBurstFx.spawn`, normal mode | A damaged surviving prop on a planned tile now plays the hit row for any element. The fx-22 staged Cinder Bloom case changes at the outcrop on `(5,3)`. The current Cinder Bloom case and the fx-25 Shadow crate on `(3,4)` already played hit in round 0. |
| `TileBurstFx.spawn`, arrival mode | An eligible trap or arrival burst tile plays hit when a surviving prop lost Health in the same snapshot. The probe confirmed that terrain stays on its original tile and a damaged moving actor registers at arrival. The fx-20 trap fixture has no surviving prop. |
| `ResolvedContactBursts._observe_event`, trap arrival | The observed trap contact plays hit if a surviving prop on the event tile lost Health in the same snapshot. The focused probe exercised this case. |
| `ResolvedContactBursts.append_attack` | The existing terrain check already marks surviving prop loss for single-target contact. The resulting row is the same. |
| `ResolvedContactBursts._append_physical` | The hit map gains surviving props. This route emits only on occupied actor tiles, so the added prop tiles do not produce physical dragon stamps. |
| `RunScene._append_contact_burst`, Cinder Bloom | The shared map now includes the surviving outcrop before Bloom merges its explicit terrain losses. The current Bloom row remains hit. |
| `ReflectView.play_projectile` | Only a loss on the return origin can change its selected row. The Hurl Spear and Frostbolt return cases have no surviving prop loss there. |
| `ReflectView.refraction_cue` | A surviving prop loss in the cue snapshots can now mark its line tile as hit. The direct beam targets actors. The normal, fallback, cancelled and fog Refraction witnesses showed no change. |
| `VaeloryxWind.burst_cue` | The explicit target-tile terrain loss check already covers a struck surviving prop. The push, pull and Skyhook witnesses showed no change. |
| `tools/fx12/verify.gd` and `tools/fx18/verify.gd` | The direct fx-12 assertions cover actors, defeat and actor arrival. The fx-18 reference map reads the same shared rule and its Faultline fixture consumes the spires. Neither has a surviving-prop floor assertion. |

The only historical verifier assertion updated is `tools/fx22/verify.gd` in `cinder_bloom_terrain`. Its staged base row for the surviving outcrop changes from `fire_floor_front` to `fire_hit_front` because the launcher uses the current shared tile player on both sides. The current-side hit assertion already expected `fire_hit_front`. FX-12 and FX-20 required zero assertion edits in this round.

## 4. Legacy submissions

The existing FX-12 area flag suppresses the resolution wash for regular Shadow areas, including range 0 and terrain bursts. The FX-17 contact mask suppresses the old neutral impact decal on covered area, melee and mapped ranged tiles. The shared targeted replacement flag is set on those Shadow area descriptors. The headless probe checks the gates and presentation inputs used by the board painters.

Veil Needle plays its existing Shade flight and submits one `hit_gloom` at sample 44. Its neutral decal is suppressed. Closing Shade retains the posed strike trail. The protected Noctyrax controls retain their original dragon Shadow drawings, along with the generic area wash and applicable neutral decal. The remaining routes reach the generic impact or Veilbound paths being handled by fx-24. `ElementalSpellFx` has no independent Shadow impact or ground painter.

## 5. Timing against base

Contact is the zero-based 60 Hz proof sample where RunScene submits the attack's existing contact. Duration and authored frames come from RunScene's animation clock. Ambush's duration and frame count include its blink and strike. All 17 round 1 witnesses matched base `85d4a8f5c` for authored duration, rendered frame count, contact, completion and the sampled action phases.

| Resolver witness | Timed frames before / after | Authored µs before / after | Contact before / after |
| --- | ---: | ---: | ---: |
| Closing Shade | 36 / 36 | 600012 / 600012 | 19 / 19 |
| Ambush | 48 / 48 | 940014 / 940014 | 37 / 37 |
| Slash | 48 / 48 | 800016 / 800016 | 29 / 29 |
| Veil Needle | 54 / 54 | 900018 / 900018 | 44 / 44 |
| Echo | 48 / 48 | 800016 / 800016 | 28 / 28 |
| Shade Bolt | 48 / 48 | 800016 / 800016 | 28 / 28 |
| Void Claw | 66 / 66 | 1100022 / 1100022 | 34 / 34 |
| Night Coil | 66 / 66 | 1100022 / 1100022 | 43 / 43 |
| Starless Breath | 66 / 66 | 1100022 / 1100022 | 43 / 43 |
| Last Eclipse | 66 / 66 | 1100022 / 1100022 | 43 / 43 |
| Ranged area · Health loss | 6 / 6 | 240000 / 240000 | 6 / 6 |
| Range-0 area · Block absorbed | 6 / 6 | 240000 / 240000 | 6 / 6 |
| Range-0 area · Umbra | 6 / 6 | 240000 / 240000 | 6 / 6 |
| Ranged area · surviving crate | 6 / 6 | 240000 / 240000 | 6 / 6 |
| Terrain burst | 6 / 6 | 240000 / 240000 | 6 / 6 |
| Ranged area · reduced motion | 6 / 6 | 240000 / 240000 | 0 / 0 |
| Reel · area then melee | 42 / 42 | 840012 / 840012 | 6 and 80 / 6 and 80 |

## Hollow Mimic

Echo and Shade Bolt publish at contact. Flight is a follow-up unit.

## Chosen defaults

- Proof fixtures inherit fx-20's seed `7262026` and 30 Health and use 20 Block or 20 crate Health for the relevant contacts. The area controls use Shade Bolt's existing damage, with a three-cell proof pattern and range 0 where required. The terrain burst uses a declared strip. The dragon area controls use the same declared proof strip while retaining their authored action settings.
- The proof uses the generated room's camera and clears the local lanes around the witnesses. Crops center on the projected affected tiles. The reel uses one fight with a Hollow Mimic and a Veilbound Acolyte and captures 240 frames. The native launcher uses the fx-22 300-second capture timeout.
- The representative ranged strip uses Veil Needle because its production route submits flight before contact.

## Proof for the design owner

Run the windowed strips and four-second silent reel with the prepared launcher.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-25 && /private/tmp/labyrinth_codex/fx-25/native.sh
```

The strips use the 1920×1080 RunScene SubViewport with cel look and HUD at 100% UI scale. Their four 640×480 crops sample contact and +100, +233 and +366 ms. The native launcher writes strips and full-size contact evidence in `/private/tmp/labyrinth_codex/fx-25/native/{before,after}/{area_ranged,closing_shade,veil_needle}/`. The after-only reel is `/private/tmp/labyrinth_codex/fx-25/native/shadow-tendrils.mp4`. Its full-size contact evidence and manifest are under `native/after/recording/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-25 && /private/tmp/labyrinth_codex/fx-25/native.sh --dry-run
```

The two headless runs write per-take JSON under `/private/tmp/labyrinth_codex/fx-25/headless/{before,after}/<case>/take.json`. Round 1 used `FX25_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-25/round-1`. Windowed captures await the owner's renderer run.

## Files

- `data/tile_bursts.json` wires the two Shadow mapping fields.
- `scripts/tile_burst_fx.gd` accepts Shadow areas at either range, counts surviving terrain Health loss for every element, and reads the catalog's per-burst still.
- `scripts/resolved_contact_bursts.gd` routes Ambush's nested contact, marks Shadow area replacement, and uses the shared mapped ranged contact path.
- `tools/fx22/verify.gd` expects the shared hit row on Cinder Bloom's surviving outcrop.
- `tools/fx25/` contains the resolver fixtures, comparison overlay, headless verifier, native capture and encoding launcher, proof contracts and GDScript sidecars. The director's executable wrapper is `/private/tmp/labyrinth_codex/fx-25/native.sh`.

## Round 1 verification

| Check | Observed result |
| --- | --- |
| fx-25 dry-run base | `FX-25 BASELINE: PASS (17 checks, 0 failures)` |
| fx-25 dry-run implementation | `FX-25 VERIFY: PASS (554 checks, 0 failures)` |
| fx-12 | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS` |
| fx-17 | `FX-17 VERIFY: 132 checks, 0 failures` and `TEST RESULT: PASS` |
| fx-20 | `FX-20 VERIFY: PASS (172 checks, 0 failures)` |
| fx-22 | `FX-22 VERIFY: PASS (266 checks, 0 failures)` |
| Shared rows and cap | `FX-25 SHARED ROWS AND CAP: PASS (15 checks, 0 failures)` |
| GDScript parse checks | The five scripts changed in round 1 each returned exit 0 via the task runner's `--check-only`. |

FX-20 ran through `--verify-fx20`. The existing fx-22 launcher dispatches its verifier through `--dry-run`. Both used fx-25 task isolation. The director's fx-17 and fx-20 expectations from `9184f1c4b` were used as committed.

- [fx-25 dry run](/private/tmp/labyrinth_codex/fx-25/round-1/dry-run.log) and [Veil Needle after take](/private/tmp/labyrinth_codex/fx-25/round-1/headless/after/veil_needle/take.json)
- [fx-12](/private/tmp/labyrinth_codex/fx-25/round-1/fx12.log), [fx-17](/private/tmp/labyrinth_codex/fx-25/round-1/fx17.log), [fx-20](/private/tmp/labyrinth_codex/fx-25/round-1/fx20.log) and [fx-22](/private/tmp/labyrinth_codex/fx-25/round-1/fx22.log)
- [Shared rows and cap](/private/tmp/labyrinth_codex/fx-25/round-1/shared-rows.log) and [GDScript parse results](/private/tmp/labyrinth_codex/fx-25/round-1/parse/results.txt)

## Open issues

Native strips and the reel await a renderer run. Hollow Mimic flight is a follow-up unit.
