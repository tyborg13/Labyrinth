# FX-29 implementation evidence

Worktree `codex/fx-29`, pinned base `5adb3d0d1`. Changes are uncommitted.

## Requirements

1. **Shot.** Enemy Refraction uses the existing Ice-to-`lance` mapping and ShotFx sheet sizing, one heading-aligned head, and the stock lance shadow. The launch uses `Contact.chest` with the Mirror's actor key. The straight path ends at the last line tile's centre.
2. **Timing.** The protected cutout lasts 66 samples over 1.1 seconds. Refraction uses ShotFx's default release fraction, 0.18, which reaches the first sampled release at frame 13. Contact and first displayed losses stay at frame 34. The contact-minus-12 guard was exercised with a synthetic late release. Fallback still waits eight samples of 37.5 ms. It releases at the first sample and reaches the last tile after sample eight, at 300 ms, with the last burst submitted before applying the step. The pinned comparison also checks floating text and its tail timing.
3. **Tile bursts.** Each visible line tile receives one FX-12 Ice rear/front pair in its existing tile layers. The adapter's reserved area burst moves to these samples. Separate surface and trap effects retain their contact reservation. Resolved losses select hit for Health, Block, Stoneskin, Mantle, Defiance, or defeat. A surviving terrain Health loss also selects hit. Empty tiles use floor. Refraction suppresses the lance's standalone `hit_glass`. Because the chest is above the board, a straight path to the last centre cannot intersect every intermediate ground centre in screen space. Bursts use the head's progress along the tile line, the coordinate shared by its shadow and the Umbra mask.
4. **Beam removal.** `ReflectView.draw_effect` consumes Refraction with zero draw calls. The independent Ice burst clock continues if the Ice shot mapping or sheet entry is unavailable. The pinned production mapping and atlas resolve the Mirror's lance.
5. **Cancellation.** Cancelled Refraction submits zero heads and zero tile bursts. The cancelled fallback still skips its timed window.
6. **Reduced motion.** The existing one-sample cutout shows the FX-12 still on each visible line tile at contact. The fallback preserves its 300 ms clock and uses stills on the same individual tile-arrival samples as full motion.
7. **Umbra.** The projectile uses the existing FX-14 visible intervals and the original endpoints of a clipped step. Burst reservation checks board visibility at each tile arrival.

Frames are one-based. The verifier exercised hero at the end, a nearer Crawler, an empty last tile beyond the hero, a surviving crate, partial Eclipse, and cancellation. Each case ran in full and reduced motion. Cancelled steps take the fallback because the cutout adapter declines them.

| Path | Release | Contact / loss | Tile starts, nearest first |
| --- | ---: | ---: | --- |
| Cutout | 13 (200 ms) | 34 (550 ms) | 21, 26, 31, 34 |
| Fallback | 1 (0 ms) | 9 (300 ms) | 4, 6, 8, 9 |
| Reduced cutout | — | 1 | 1, 1, 1, 1 |
| Reduced fallback | — | 9 (300 ms) | 4, 6, 8, 9 |
| Cancelled | — | Immediate | — |

The Eclipse fixture reserves only `(3, 4)` and `(2, 4)`, at the same samples they use with clear sight. The surviving crate fixture inserts a one-Health loss into an otherwise resolved step because the protected direct Refraction resolver hits actors. The fixture verifies presentation of that terrain loss without changing the resolver.

## Verification

| Check | Observed result |
| --- | --- |
| `tools/fx29/verify.gd`, pinned base and current | `FX-29 VERIFY: 4258 checks, 0 failures` |
| `tools/gfix34/verify.gd` | `GFIX-34 VERIFY: 308 checks, 0 failures` |
| `tools/qa131/live_effects.gd`, fixed 60 FPS | `QA131 LIVE EFFECTS: 75 checks, 0 failures` |
| `tools/fx12/verify.gd`, restored local import cache | `FX-12 VERIFY: 120 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fx14/verify.gd -- --affected` | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1809 checks, 0 failures)` |
| `tests/en05_elemental_test.gd` | `EN05 ELEMENTAL INTEGRATION: PASS (12 checks, 0 failures; neutral, ice, air)` |
| `tests/en05_live_integration_test.gd` | `EN05 LIVE INTEGRATION: PASS (22 checks, 0 failures; headless logic only)` |
| `tests/mrg11h_review_test.gd -- --affected` | `MRG-11H Reflect EN05: 148 checks, 0 failures` · `MRG-11H REVIEW: 817 checks, 0 failures` |
| `tests/glacial_mirror_board_probe.gd -- --validate-only` | `GLACIAL MIRROR BOARD HEADLESS FIXTURE: FAIL` · two `Stage uses its exact profile` assertions |
| All seven changed or added GDScript files | `--check-only` returned exit 0 for each |
| Shell syntax, proof contract JSON, UID sidecar presence and diff whitespace | Passed |
| Python default group | `SELECTED MODULES: 22 of 58` · `Ran 194 tests in 33.533s` · `FAILED (failures=1)` · `PASS: Rules text lint (16 existing hits)` |
| Headless dry runs | Twice `FX-29 NATIVE DRY RUN strip: 17 checks, 0 failures` · `FX-29 REEL: 240 frames at 60 fps` · `FX-29 NATIVE DRY RUN reel: 6 checks, 0 failures` |

Logs are in the [FX-29 evidence directory](/private/tmp/labyrinth_codex/fx-29/logs). The live reel dry run used the ordinary Pass handler and recorded Refraction flight, contact, and the hero dropping from 30 to 26 Health.

## Proof for the design owner

The windowed command uses the visual probe runner, `LABYRINTH_CEL_LOOK=all`, a 1920×1080 production SubViewport at 100% UI scale, and the pinned base scripts for the before strip. It selects frames 13, 20, 27, 34, 40, and 48 for release, 33% and 66% of flight time, arrival, +100 ms, and +233 ms. Each strip also saves its six uncropped frames and a validation manifest. The four-second reel uses the ordinary Pass action and is encoded without audio.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-29 && /private/tmp/labyrinth_codex/fx-29/native.sh
```

Window-server access is required to produce these paths.

- `/private/tmp/labyrinth_codex/fx-29/native/before/strip.png`
- `/private/tmp/labyrinth_codex/fx-29/native/after/strip.png`
- `/private/tmp/labyrinth_codex/fx-29/native/after/reel/reel_preview.png`
- `/private/tmp/labyrinth_codex/fx-29/native/refraction.mp4`

Headless replay uses the same launcher with `--verify` or `--dry-run`.

## Chosen defaults

- The fixture uses seed 131011, the existing 9×9 board, 30 hero Health, Quick Stab and Brace, Mirror at `(6, 4)`, hero at `(2, 4)` or `(3, 4)`, a line Crawler at `(5, 4)` or a survivor at `(7, 7)`, and crate Health 10 with a one-point result. Eclipse uses zero stage reduction and an empty light-source list.
- The fixture uses eight settle samples and a 12-second ready or turn-completion guard. The late-release guard case uses 135 samples and contact at 25. The reel places the Mirror one initiative unit ahead of the opening clock and presses Pass after 30 frames.
- Each strip panel is a 640×480 crop centred on the midpoint of the Mirror and hero. The fixed capture clock follows the gfix-34 harness with a 64×64 host window and a 300-second capture timeout.

No `TODO_DESIGN_*` placeholders were needed.

## Open issues and procedural effects

- Native framebuffer inspection and video encoding await the owner run. Headless dry runs produced timing and path receipts.
- Python's tracked-sidecar assertion reports `tools/qa131/board_effects.gd.uid`, `tools/qa131/live_effects.gd.uid`, and `tools/qa131/relic_glossary.gd.uid`. All three are absent from the pinned base's tracked inventory. The timing-cache write to shared Git metadata also hit the expected permissions boundary. [Python default log](/private/tmp/labyrinth_codex/fx-29/logs/python-default.log)
- The existing Mirror standing probe expects anchors `(113.64, 221.74)` and `(109.90, 221.71)`. Base and local master both define `(122.57, 224.82)` and `(125.81, 226.23)`. [Standing probe log](/private/tmp/labyrinth_codex/fx-29/logs/glacial_mirror_board_probe.log)
- The initial FX-12 run reported `active texture preserves all bake indices`. Refreshing the seven generated texture caches from gfix-34 with byte-matched source PNGs and import sidecars cleared it. Headless runs also reported the known macOS certificate lookup error and some ObjectDB exit warnings. [FX-12 rerun](/private/tmp/labyrinth_codex/fx-29/logs/fx12-cache-restored.log)
- Reflected lone shots still use `_draw_projectile_sprite` when `_reflected_shot_descriptor` returns empty because ShotFx has no matching baked shot or the action is excluded by its resolver. The gfix-34 replay confirms Root Snare takes that path. Its inventory lists Arc Flash, Cinder Fusillade, Cinderline Tempo, Ember Tithe, Firebrand Volley, Guiding Flare, Jolt, Lodestone Reversal, Pyroclasm, Root Snare, Scorch, Skybolt, Spark Dart, Static Lash, and Thunderstone. [Reflection regression log](/private/tmp/labyrinth_codex/fx-29/logs/gfix34.log)
- Other procedural combat drawing still includes Capacitor links and pips, Briar flecks, burrow rims and dust, lob and Icefall collision markers, Call Wind chevrons, Chain hop marks, and legacy elemental effects such as Starless Breath and Blink or shadow-rift effects.
