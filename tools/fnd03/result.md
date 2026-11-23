# fnd-03 acquisition bursts

Implemented in the current `codex/fnd-03` worktree at base `c1beae85d`. Changes are uncommitted.

| Requirement | Implementation and evidence |
| --- | --- |
| 1. One burst per gain | All three Scavenger purchase kinds, every named event gain and both dragon milestone Continue paths use the approved atlas. The two-item satchel grants and displays two independent bursts. Sales, bane omens, item loss, Embers, Health and map outcomes have zero bursts. |
| 2. Launch and lifetime | Shop starts at the ware's origin, follows the displayed lift and freezes at flight. Event art stays at its origin. Dragon starts on the first beam frame or, for a nonfinal section-map milestone, at the existing transition start. Stamps own their 16-frame, 30 fps clock and survive the 0.12 s event proxy. Tests interrupt a live burst through shop dismissal, event Continue, a room change and scene teardown. |
| 3. Order | Shop and event proxy z are raised over their existing background and reward pool. Artwork stays in the reward stack. In all fixtures, the burst resolves to proxy z minus one. |
| 4. Size | Uses the displayed card's fnd-01 pop-radius rule, or displayed art's half diagonal plus 64 logical pixels. Replacement displays supply transform and reforge size. The verifier confirms the nearest prepared sheet and two framebuffer pixels per cell at 1920×1080. The shared shader snaps the centre, samples nearest and uses its existing alpha blend. |
| 5. Accent | Card element, item rarity, equipment accent, relic accent with `#d8b25a` fallback, and the event preview's blessing and Defiance accents. Replacement IDs supply both conversion accents. |
| 6. Primitive removal | Removed the merchant glow, origin and arrival stars, flight ribbon, currency stars, event radial glow and event arrival stars, and `EmberSparks`. Direct `draw_*` calls are zero across the merchant, Scavenger and event gain scripts and the former EmberSparks class. The event hurt-edge vignette remains under its existing shader. |
| 7. Pacing | All 32 case/motion traces matched the pinned base. Each proxy sample includes position, scale, rotation, tint and visibility, with crossfade modulates included where present. The shop currency flash, event arrived signal and destination pulse, ember counter roll, dragon delivery and flow all matched the base. Sound and await positions were preserved. |
| 8. Preparation | The shop prepares the shelf card and ware icon fits across the existing shelf poses. Events prepare card, item art and icon fits. The dragon reward prepares the artwork fit. Every stamp used the same atlas resource that was present before the action. |
| 9. Reduced motion | New gain bursts show approved atlas frame 4 for 0.18 s. Their hidden clocks continue until the same 533⅓ ms cleanup boundary. The existing fnd-01/fnd-02 paths retain their production behavior. |

## Gain paths

- Scavenger magic cards, equipment and consumable items use the committed Buy action and `ScavengerShopView._present_trade`. Sell uses the same ware animation with no burst. Legacy Blacksmith and Arcanist room and save IDs normalize to Scavenger, and merchant rules reject those legacy IDs as separate transaction kinds. No other live merchant kind buys or sells wares without presentation. Graftwright, the Emaciated Man's wallet services and Scavenger Purge are separate actions.
- `EventRules` commits direct card, item, equipment, relic, blessing omen, Defiance, transform and reforge outcomes. `EventResultBeats._start_beat` creates their proxies and launches the burst from the same frame. Card-choice outcomes are offers and acquire their card later through the existing fnd-01 reward-card action. Bane and loss still use the existing stamp and dissolve.
- `_on_dragon_reward_continue` starts the burst at delivery for the final/relic-beam route and at transition start for a newly committed nonfinal section-map milestone. A resumed, already claimed milestone only continues the transition. Final next-descent gifts are presented here and installed by the existing new-run flow.
- Board pickups, ordinary reward card claims, treasure relic claims, Curator's Patience and Guardian trophies retain the existing fnd-01/fnd-02 launch paths.

## Frame table

Frame offsets use a fixed 60 fps, sampled from the accepted action. A dash indicates a presentation boundary absent on that path. Shop's arrival column is the end of the existing flight, and its pulse column is the currency flash. Dragon's arrival column is beam removal. Delayed event gains start at their assigned receipt beat.

| Case | Proxy or delivery start | Arrival | Pulse | Proxy or delivery end | Burst start → free | Accent | Sheet radius | Burst centre | Burst z / proxy z |
| --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- |
| dragon | 1 | 29 | — | 46 | 1 → 34 | `#d9862f` | 60 | (960, 508.74) | 72 / 73 |
| dragon (reduced) | 0 | — | — | 9 | 0 → 33 | `#d9862f` | 60 | (960, 508.74) | 72 / 73 |
| dragon section | 0 | — | — | 181 | 0 → 33 | `#d9862f` | 60 | (960, 513.24) | 72 / 73 |
| dragon section (reduced) | 0 | — | — | 121 | 0 → 33 | `#d9862f` | 60 | (960, 513.24) | 72 / 73 |
| event bane | 16 | 70 | 70 | 86 | — | — | — | — | — |
| event blessing | 0 | 52 | 52 | 69 | 0 → 33 | `#f2d27a` | 72 | (697, 529) | 1201 / 1202 |
| event blessing (reduced) | 0 | 7 | 7 | 8 | 0 → 33 | `#f2d27a` | 72 | (697, 529) | 1201 / 1202 |
| event card | 16 | 67 | 67 | 84 | 16 → 48 | `#cfb347` | 148 | (697, 540.196) | 1201 / 1202 |
| event card (reduced) | 16 | 22 | 22 | 23 | 16 → 48 | `#cfb347` | 148 | (697, 540.196) | 1201 / 1202 |
| event defiance | 16 | 67 | 67 | 84 | 16 → 48 | `#c9a25e` | 72 | (697, 529) | 1201 / 1202 |
| event defiance (reduced) | 16 | 22 | 22 | 23 | 16 → 48 | `#c9a25e` | 72 | (697, 529) | 1201 / 1202 |
| event embers | — | — | 0 | 51 | — | — | — | — | — |
| event gear | 0 | 52 | 52 | 69 | 0 → 33 | `#8f9499` | 72 | (697, 529) | 1201 / 1202 |
| event gear (reduced) | 0 | 7 | 7 | 8 | 0 → 33 | `#8f9499` | 72 | (697, 529) | 1201 / 1202 |
| event health | — | — | — | 51 | — | — | — | — | — |
| event item 1 | 0 | 52 | 52 | 69 | 0 → 33 | `#8f9499` | 124 | (697, 540.196) | 1201 / 1202 |
| event item 2 | 23 | 75 | 75 | 92 | 23 → 55 | `#9b62d6` | 124 | (697, 540.196) | 1201 / 1202 |
| event item (reduced) 1 | 0 | 7 | 7 | 8 | 0 → 33 | `#8f9499` | 124 | (697, 540.196) | 1201 / 1202 |
| event item (reduced) 2 | 16 | 22 | 22 | 23 | 16 → 48 | `#9b62d6` | 124 | (697, 540.196) | 1201 / 1202 |
| event loss | 0 | — | — | 25 | — | — | — | — | — |
| event map | — | — | 0 | 51 | — | — | — | — | — |
| event reforge | 0 | 56 | 56 | 73 | 0 → 33 | `#4b84d8` | 72 | (697, 529) | 1201 / 1202 |
| event reforge (reduced) | 0 | 7 | 7 | 8 | 0 → 33 | `#4b84d8` | 72 | (697, 529) | 1201 / 1202 |
| event relic | 16 | 67 | 67 | 84 | 16 → 48 | `#4b84d8` | 72 | (697, 529) | 1201 / 1202 |
| event relic (reduced) | 16 | 22 | 22 | 23 | 16 → 48 | `#4b84d8` | 72 | (697, 529) | 1201 / 1202 |
| event transform | 0 | 56 | 56 | 73 | 0 → 33 | `#8a6d49` | 148 | (697, 540.196) | 1201 / 1202 |
| event transform (reduced) | 0 | 7 | 7 | 8 | 0 → 33 | `#8a6d49` | 148 | (697, 540.196) | 1201 / 1202 |
| shop card | 0 | 44 | 0 | 57 | 0 → 33 | `#89a15b` | 124 | (814.5, 274) | 223 / 224 |
| shop card (reduced) | 0 | — | — | 39 | 0 → 33 | `#89a15b` | 124 | (814.5, 274) | 223 / 224 |
| shop gear | 0 | 44 | 0 | 57 | 0 → 33 | `#4b84d8` | 72 | (1335, 526) | 223 / 224 |
| shop gear (reduced) | 0 | — | — | 39 | 0 → 33 | `#4b84d8` | 72 | (1335, 526) | 223 / 224 |
| shop item | 0 | 44 | 0 | 57 | 0 → 33 | `#8f9499` | 72 | (1335.04, 735) | 223 / 224 |
| shop item (reduced) | 0 | — | — | 39 | 0 → 33 | `#8f9499` | 72 | (1335, 735) | 223 / 224 |
| shop sale | 0 | 44 | 0 | 57 | — | — | — | — | — |

The chosen shop card starts at (814.5, 274) and freezes at (814.5, 287.508). The existing clearance rule pushes its displayed lift below the banner. The burst follows that pose, preserving the card animation and the visual attachment. Gear and item bursts complete the full 22 px upward lift.

The shop currency flash returns to white at frame 27. The tested ember rolls start at frame 0 and complete at frame 10. The final dragon beam starts at 1, is removed at 29, and starts settlement at 30. The nonfinal fixture uses the existing section transition, which has no beam. Both routes retain the base Continue pacing.

[Base traces](/private/tmp/labyrinth_codex/fnd-03/verify/before/pacing.json) · [After traces](/private/tmp/labyrinth_codex/fnd-03/verify/after/pacing.json) · [Logs](/private/tmp/labyrinth_codex/fnd-03/logs)

## Verification

| Check | Observed result |
| --- | --- |
| Pinned base | `FND-03 VERIFY BASE: 96 checks, 0 failures` and `TEST RESULT: PASS` |
| Candidate | `FND-03 VERIFY AFTER: 352 checks, 0 failures` and `TEST RESULT: PASS` |
| fnd-01 verifier, unchanged | `FND-01 VERIFY: 111 checks, 0 failures` and `TEST RESULT: PASS` on retry. The initial parallel run reported two sheet-thread timing failures. The pinned base also reported 111 checks and 0 failures. |
| fnd-02 verifier, unchanged | `FND-02 VERIFY AFTER: 194 checks, 0 failures` and `TEST RESULT: PASS` |
| Scavenger shop probe, headless | `SCAVENGER SHOP PROBE: PASS` |
| Scavenger rules suite | `Scavenger shop rules suite: 0 failures` via a scratch entry point to the existing suite |
| Event rules | `Event rules suite: 0 failures` |
| Event view | `Event view fit: 332 pages, 45 events × fresh/rich states` and `Event view suite: 0 failures` |
| Event feedback | Pinned base `Event feedback suite: 0 failures`. Candidate `Event feedback suite: 1 failures`, with `ERROR: Event glow has the exact radial extent around the reward art` and a null material access at line 495 of the existing suite. |
| Dragon rewards | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` |
| Dragon reward feedback | `Dragon reward feedback logic: PASS` |
| Deck element rewards | `DECK ELEMENT REWARDS: 0 failures` |
| UI identity | `Ran 25 tests in 4.682s` and `OK` |
| Rules text | `Ran 3 tests in 0.054s`, `OK`, and `PASS: Rules text lint (16 existing hits)` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 33.670s`, and `FAILED (failures=1)`. The established QA-131 sidecar inventory failure lists `board_effects.gd.uid`, `live_effects.gd.uid` and `relic_glossary.gd.uid`. The runner's optional timing cache write hit read-only Git metadata. |
| Godot parser | Ten `--check-only` invocations exited 0 for all seven changed runtime scripts and three proof scripts. |
| Capture plan | Ten `TEST RESULT: PASS` receipts, five `FND-03 CAPTURE PACING PASS` comparisons and `FND-03 REEL PLAN: 480 frames at 60 fps with audio`. |

The host printed the macOS certificate-store diagnostic on headless launches. The new candidate verifier and fnd-02 verifier emitted ObjectDB/resource diagnostics at exit after their passing results.

## Proof for the design owner

Run in a WindowServer session.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fnd-03 && /private/tmp/labyrinth_codex/fnd-03/native.sh
```

The launcher uses the visual probe runner, an exact 1920×1080 SubViewport at 100% UI scale and `LABYRINTH_CEL_LOOK=all`. It captures shop card, shop gear, event relic, event card and the final dragon milestone.

- `/private/tmp/labyrinth_codex/fnd-03/native/{before,after}/{shop_card,shop_gear,event_relic,event_card,dragon}/strip.png` contains the six 640×640 origin crops at +0, +66, +133, +233, +366 and +500 ms.
- The after directories also contain `arrival.png` and `arrival-plus-100ms.png`, both 640×640. Each take writes `native-evidence.png`, `take.json` and `manifest.json`.
- `/private/tmp/labyrinth_codex/fnd-03/native/acquisition-gains.mp4` is the planned 480-frame 1080p60 reel with the game mix.
- Headless receipts are in [plan](/private/tmp/labyrinth_codex/fnd-03/plan). The [dry-run log](/private/tmp/labyrinth_codex/fnd-03/logs/native-plan.log) lists each absolute output path.

## Files changed

- `scripts/acquisition_burst.gd` adds the shared gain entry points, preparation, z and reduced-motion playback.
- `scripts/merchant_acquisition_effect.gd`, `scripts/scavenger_trade_effect.gd` and `scripts/scavenger_shop_view.gd` replace the purchase drawing with the burst and retain the trade pose.
- `scripts/event_gain_effect.gd` and `scripts/event_result_beats.gd` remove the old draw effects and launch from committed reward art.
- `scripts/run_scene.gd` wires the three surfaces and launches the dragon milestone burst.
- `tools/fnd03/` includes the fixture, verifier, native recorder, Godot UID sidecars, launcher, proof contract, encoder and this result.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The verifier reuses the Scavenger probe's seed 73491, shop stock and sale pack. Event choices use the production resolver with the event view suite's rich fixture and seed 421. The dragon factory supplies the Noctyrax depth-24 reward and Vyraketh depth-4 section transition.
- Fixtures allow 240 preparation frames, allow 24 frames for shop entry, and sample up to 228 frames. Exit checks interrupt after five frames or immediately on the room-change case. The verifier gives the audio thread 100 ms at teardown.
- The reel uses five 96-frame segments with an eight-frame lead. Capture monitoring allows 144 frames. Crops clamp to the framebuffer edges. The existing 64×64 MovieWriter sink supplies the synchronized audio, with H.264 video and AAC audio in the reel. The native runner allows 120 seconds per take.

## Open issues

- Windowed captures, sound verification and visual inspection remain for the design owner. The implementation environment has no WindowServer access.
- The event feedback suite's radial-glow assertions require a test-owner update for the intentional removal. The suite is outside this unit's file ownership.
- The Python default group retains the pinned base's three missing QA-131 UID sidecars.
