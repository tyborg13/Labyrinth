# fx-30 · Noctyrax Shadow bursts

Base `2c3f8fb82`. Implementation and proof files are uncommitted on `codex/fx-30`.

## 1. Resolver inventory

| Availability | Intent ID | Action type | Resolved kind | Profile clip / geometry / element | Base drawing |
| --- | --- | --- | --- | --- | --- |
| Current | `starless_breath` | `aoe`, committed `fan` | `aoe` | `breath / breath / shadow` | Maw release glow, streams to fan endpoints, rear/front Shadow billows |
| Current | `night_coil` | `aoe`, committed `line` | `aoe` | `coil / breath / shadow` | Maw release glow, streams to line endpoints, rear/front Shadow billows |
| Current | `last_eclipse` | `umbra_eclipse` | `aoe` | `eclipse / ground / shadow` | Source release glow and rear/front Shadow billows across the resolved area |
| Historical compatibility | `last_eclipse`, `void_claw`, `starless_breath` | `aoe`, committed `refuge` | `aoe` | `eclipse / ground / shadow` | Source release glow and rear/front Shadow billows across the refuge |
| Historical compatibility | `starless_breath` | `ranged` | `ranged` | `breath / breath / shadow` | RunScene sets `noctyrax_breath`. The complete dragon profile uses the shared Shadow release, stream and billows. The old fallback painter had maw charge, ribbon and ring impact. |

The current Noctyrax data declares no ranged step or refuge rider. Historical ranged Starless Breath appears in `3b0b8f365`. The three historical refuge descriptors appear in the parent of `9a8855088`; migration removes the old player-anchored riders on load. The proof injects the historical Eclipse refuge descriptor into the resolver as a compatibility case.

The current Void Claw uses `move_toward / move` and `melee / melee` with `claw / physical / shadow` on the strike. Last Eclipse's separate `summon_minions / summon` has `eclipse / utility / shadow`. Neither reaches the spell painter.

## 2–5. Playback and removal

- Adding `shadow` to `BURST_ELEMENTS` routes both Breath spells through the existing Chebyshev ring schedule, tile claims, paired depth layers, visibility and row selection. No extra scheduling code was needed for Breath.
- Eclipse and refuge filter the resolved tiles via the shared loss map before building the Ground batches. Batches keep the original centre and fx-12 delays. The Eclipse area wash is suppressed through the board's existing area replacement flag. The protected darkness and Veilbound Acolyte summon still drive their existing presentation.
- The historical ranged resolver step submits a single hit pair at contact. The shot selector's existing dragon-profile guard takes care of flight.
- The board ranged painter, its maw helper, its clipped projectile colours and the range flag are gone. The shared Shadow source, stream and impact branches and the `dragon_shadow_fx.gd` script and UID are gone. There are no runtime callers. FX-18 stages the archived painter for historical comparison. The older dragon pressure probe still names the source in its provenance hash list.
- Other procedural presentation for Noctyrax includes the shared Breath footprint wash, neutral impact decals during the feedback tail and Void Claw's strike trail. The board's existing Umbra, brazier and threat presentation remains in use.

## 6–8. Timing, stills and visibility

Frames below are zero-based 60 Hz samples. The authored/rendered totals cover the whole take, including the separate summon for Eclipse and the advance for Void Claw. The base plays zero tile bursts in these cases. The verifier compared action phases, authored duration, authored/rendered frames, completion, floating text, resolved losses and contact against base. `Start` is the first visible burst frame, after any Ground delay.

| Take | Authored / rendered | Release / contact / text | Resolved tiles | Visible / total hit tiles | Shadow hit / floor pairs | Start |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| Starless Breath | 66 / 66 | 20 / 35 / 35 | 21 | 2 / 2 | 2 / 19 | 20, 25, 30, 35 |
| Night Coil | 66 / 66 | 20 / 35 / 35 | 12 | 1 / 1 | 1 / 11 | 20, 28, 35 |
| Last Eclipse and summon | 114 / 114 | 20 / 35 / 35 | 45 | 2 / 2 | 2 / 0 | 47 |
| Starless Breath, fog | 66 / 66 | 20 / 35 / 35 | 21 | 2 / 2 | 2 / 3 | 20, 25, 30 |
| Night Coil, fully blocked | 66 / 66 | 20 / 35 / 35 | 12 | 1 / 1 | 1 / 11 | 20, 28, 35 |
| Eclipse, hidden Illusion | 114 / 114 | 20 / 35 / 35 | 45 | 1 / 2 | 1 / 0 | 47 |
| Eclipse, protected hero | 114 / 114 | 20 / 35 / none | 24 | 0 / 0 | 0 / 0 | none |
| Starless Breath, reduced | 1 / 1 | 0 / 0 / 0 | 21 | 2 / 2 | 2 / 19 | 0 |
| Night Coil, reduced | 1 / 1 | 0 / 0 / 0 | 12 | 1 / 1 | 1 / 11 | 0 |
| Last Eclipse, reduced | 2 / 2 | 0 / 0 / 0 | 45 | 2 / 2 | 2 / 0 | 0 |
| Historical refuge | 66 / 66 | 20 / 35 / 35 | 25 | 2 / 2 | 2 / 0 | 46 |
| Historical ranged | 66 / 66 | 20 / 35 / 35 | 1 | 1 / 1 | 1 / 0 | 35 |
| Void Claw with advance | 136 / 136 | 94 / 102 / 102 | 1 | 1 / 1 | 0 / 0 | none |
| Reel, Starless Breath then Eclipse and summon | 180 / 180 | 20 / 35 / 35 and 94 / 109 / 109 | 21, 45 | 2 / 2, 1 / 1 | 2 / 19, 1 / 0 | 20, 25, 30, 35 and 121 |

The Starless crate lost 11 Health and survived. Night Coil pulled the hero from `(4,4)` to `(4,3)`. The blocked Coil spent 9 Block and no Health. Last Eclipse defeated the Illusion and still darkened for two activations. The verifier measured visibility at the schedule's submission frames, found one rear/front pair per stamped tile and checked Shadow cell 4 at contact in all three reduced-motion cases.

## Verification

| Check | Observed result |
| --- | --- |
| FX-30 paired headless takes and 300-frame reel plan | `FX-30 BASELINE PASS (15 checks, 0 failures)` and `FX-30 VERIFY PASS (828 checks, 0 failures)` |
| Removed painters | `FX-30 PAINTERS DragonShadowFx calls=0; Noctyrax ranged painter draws=0 (guard and source audit)` |
| FX-18 current sweeps | `FX-18 CURRENT SWEEPS PASS (0 failures)`. Starless Breath and Night Coil each recorded `26 base / 0 current primitive submissions` alongside the two other Breath controls. |
| FX-18 historical comparison | `Parse Error: Preload file "res://scripts/veilbound_acolyte_cutout/fx.gd" does not exist.` Reproduced at `2c3f8fb82`. The older overlay also references other helpers since removed. |
| FX-25 | `FX-25 BASELINE: PASS (17 checks, 0 failures)` when running the verifier's playback-only pass on the implementation. Its historical comparison stops at `Parse Error: Static function "present_arc_head()" not found in base "res://scripts/shot_fx.gd".` |
| FX-12 | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS` |
| Noctyrax and dragon focused checks | `FX-18 FOCUSED dragon_area_presentation PASS`, `FX-18 FOCUSED dragon_feedback1 PASS`, `FX-18 FOCUSED dragon_pressure_mechanics PASS`, `FX-18 FOCUSED PASS (0 failures)`, `FX-30 FOCUSED dragon_boss PASS`, `FX-30 FOCUSED dragon_element_rules PASS`, `Dragon committed patterns passed.`, `Dragon feedback mechanics passed.` |
| Python default group | `Ran 194 tests in 41.005s` and `OK`. The optional shared timing-cache write reports read-only Git metadata. |
| Rules text lint | `PASS: Rules text lint (16 existing hits)` |
| Parse and syntax checks | The eight changed or added GDScripts exit 0 with `--check-only`. The launchers, Python staging helper and both proof contracts parse. |

The per-tile burst names, rows, submission frames, visible start frames, sampled cells and timing comparisons are in `/private/tmp/labyrinth_codex/fx-30/logs/fx30.log`. Detailed takes are in `/private/tmp/labyrinth_codex/fx-30/headless/{before,after}/<case>/take.json`. Regression logs are in `/private/tmp/labyrinth_codex/fx-30/logs/`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-30 && /private/tmp/labyrinth_codex/fx-30/native.sh
```

The launcher runs the visual probe runner on an exact 1920×1080 RunScene SubViewport with the HUD, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. It writes `strip.png`, `native-evidence.png`, `take.json` and `manifest.json` under `/private/tmp/labyrinth_codex/fx-30/native/{before,after}/{starless_breath,night_coil,last_eclipse}/`. The five 960×720 strip columns sample release, contact and contact +100, +233 and +366 ms. Full-frame contact evidence for the continuous take is under `native/after/recording/`. The silent 60 fps reel is `/private/tmp/labyrinth_codex/fx-30/native/starless-breath-last-eclipse.mp4`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-30 && /private/tmp/labyrinth_codex/fx-30/native.sh --dry-run
```

## Chosen defaults

- The proof uses the inherited seed `7262026` and depth 24, hero at `(4,4)`, Noctyrax at `(4,1)` and `(4,0)` for the claw's advance. The hero starts with 30 Health and gets 20 Block for the fully blocked witness.
- The Starless Breath fixture uses crate ID 92 with 30 Health on an adjacent declared fan tile. The Eclipse fixture uses inherited Illusion ID 91 with 1 Health, at `(5,4)` for the visible case and the first eligible hidden tile for the fog case. The targeted lighting setups extinguish the proof room's braziers or light the hero's brazier for the miss. The ranged and refuge cases take their action values from the archived descriptors.
- The proof frames the projected resolved area with a 960×720 crop and records one 300-frame take. The launcher uses the inherited 300-second capture timeout. The null-canvas assertions use sampling points in the release, travel and contact phases, a 126 px tile and seed 91.

## Open issues

Windowed captures and encoding await the design owner's desktop run. The FX-18 and FX-25 historical comparisons require compatible historical overlays. The older FX-14 diagnostic still includes a synthetic assumption that the deleted flag suppresses a spear shot.

No `TODO_DESIGN_*` placeholders.
