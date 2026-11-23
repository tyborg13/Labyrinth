# fx-28 Slag Mortar lob

The lob uses the baked Ember shot and the shared Fire tile-burst player. The implementation is uncommitted on `codex/fx-28`.

## Requirements

| # | Implementation and evidence |
| --- | --- |
| 1 | Ember starts at the existing kiln landmark, follows `arc_point` with the 2.2-tile lift, and faces the tangent. The existing shot player supplies the atlas, physical cell pitch, flicker frame and retained head. Each motion case checked the art cell and position throughout flight, including release, the highest sampled point and the final in-flight sample. |
| 2 | The lob submits one simultaneous Fire burst per visible tile at contact through RunScene’s shared reservation and tile player. The shared step-loss rule covers Health, Block, Stoneskin, Mantle, Defiance and defeats. The hero center used the hit row. Empty tiles and the unharmed wooden crate used the floor row. A fixture that removed 1 Health from the surviving crate used the hit row. The hidden center received no burst and its visible arm used the floor row. |
| 3 | The fallback keeps its 0.45 s arc and 0.25 s splash. The base production adapter drives presentation with the protected 0.6 s land clip and a 0.30 contact phase. Those clocks do not produce a literal 0.45 s flight in live play. The implementation preserved the live adapter’s damage, Fire surfaces, floating text and turn-order timing. In the normal hero take at 60 fps, contact and text were at frame 14 and visible Fire surfaces at frame 52 in both revisions. Tile bursts use their own presentation clock. |
| 4 | Reduced Motion omitted the flight in every case. Each eligible tile displayed the catalog’s reduced-motion still at contact. |
| 5 | The existing forecast, inspection, badge and production caption checks passed. The protected Mortar rig and clips match the base. |

The instrumented base submitted 11 procedural travel draws and 160 procedural impact draws in the normal hero take. The after take submitted zero of either. Other procedural effects remain listed in fx-26. [fx-26 procedural inventory](../fx26/result.md)

## Files

- `scripts/enemy_mechanics/lob_view.gd` owns the lob’s retained flight and its contact submission.
- `scripts/shot_fx.gd` adds one static helper for externally timed flight using the current shot sheet.
- `tools/fx28/native.gd`, `verify.gd` and their UID sidecars implement the capture and before/after proof. `stage.py` stages the baseline and instruments the procedural painters. `native.sh`, `strip_contract.json` and `reel_contract.json` launch and validate the renderer proof.
- The worktree also contains an independent `scripts/run_scene.gd` edit that resolves the base’s missing `_terrain_lost()` reference. The fx-28 diff leaves that edit intact. The proof substitutes the existing step-loss helper only when staging a source with the unresolved reference. None of the lob cases exercise that chain code.

## Verification

| Check | Observed result |
| --- | --- |
| fx-28 before/after, 10 motion and target combinations plus real-fight reel plan | `FX-28 VERIFY: PASS (410 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-28/verify-complete.log) · [Take JSON directories](/private/tmp/labyrinth_codex/fx-28/headless) |
| fx-26 dry run | `FX-26 VERIFY: PASS (315 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-28/fx26.log) |
| fx-12 verifier | `FX-12 VERIFY: 120 checks, 1 failures` · `TEST RESULT: FAIL`. The unchanged imported texture fails the `active texture preserves all bake indices` comparison. The isolated texture diagnostic reproduced the byte mismatch. [Log](/private/tmp/labyrinth_codex/fx-28/fx12-cache.log) · [Texture diagnostic](/private/tmp/labyrinth_codex/fx-28/fx12-palette.log) |
| EN04 mechanics suite | `EN04 ENEMIES SUITE: PASS (417 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-28/en04-suite.log) |
| Mortar forecast | `ENC04 FORECAST TEST: PASS (128 configurations; 1554 checks; 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-28/enc04-forecast-final.log) |
| Mortar playback and adjacent approach | `ENC03 LOB PROBE: PASS (5 states; 0 failures)`. The run includes 8 adjacent activations across normal and Reduced Motion. [Log](/private/tmp/labyrinth_codex/fx-28/enc03-lob-final.log) |
| EN04 native fixture contract, headless preparation | `EN04 ENEMIES PROBE CONTRACT: PASS (9 states, 1920x1080, UI scale 100%)`. [Log](/private/tmp/labyrinth_codex/fx-28/en04-enemies-probe-final.log) |
| Hero facing and pre-battle semantics | `HERO FACING TEST: PASS (76 checks)` · `PRE-BATTLE SEMANTICS TEST: PASS` · `TEST RESULT: PASS`. [Facing](/private/tmp/labyrinth_codex/fx-28/hero-facing.log) · [Semantics](/private/tmp/labyrinth_codex/fx-28/pre-battle-semantics.log) |
| Python default group and rules text | `Ran 194 tests in 43.077s` · `OK` · `PASS: Rules text lint (16 existing hits)`. The runner’s child startup check timed out on the first pass. It passed in isolation and in the final default group. [Final log](/private/tmp/labyrinth_codex/fx-28/python-default-final.log) · [Summary](/private/tmp/labyrinth_codex/fx-28/python-default-final/summary.json) |
| Parse and shell checks | Godot parser exit 0 for the two runtime scripts and the two fx-28 proof scripts. Both launchers passed `sh -n`. `git diff --check` exited 0. |
| UID generation | `FX-28 SIDECARS: PASS`. [Log](/private/tmp/labyrinth_codex/fx-28/sidecars.log) |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-28 && /private/tmp/labyrinth_codex/fx-28/native.sh
```

The launcher sets `LABYRINTH_CEL_LOOK=all` and uses the visual probe runner at 1920×1080 and 100% UI scale. It writes a six-column strip, full-frame contact evidence, take JSON and proof manifest under `/private/tmp/labyrinth_codex/fx-28/native/{before,after}/{hero,empty}/`. The columns use release, the first authored sample at or beyond 33% and 66%, contact, +100 ms, and +233 ms. The silent four-second reel goes to `/private/tmp/labyrinth_codex/fx-28/native/slag-mortar-lob.mp4`. Its headless plan landed at frame 53 through the normal Pass action. [Reel plan](/private/tmp/labyrinth_codex/fx-28/headless/after/recording/take.json)

## Chosen defaults

- Proof only uses the existing inspection seed `7262026` and hero tile `(4,4)`. The Mortar starts at `(4,2)`, the empty and crate centers at `(6,4)`, and the hidden center at `(7,4)` with Heart sight. The extra surviving-crate check injects a 1 Health loss into the resolved fixture.
- The 60 fps reel starts with a held mark and passes after 18 frames. The 640×480 strip crops are centered on the launch and target midpoint, raised by one tile height, and clamped to the 1920×1080 framebuffer. The windowed runner allows 300 seconds for frame capture.

## TODO_DESIGN placeholders

None.

## Open issues

- The live clip and the literal 0.45 s flight in requirement 3 specify different timing. The implementation preserves base live timing and the fallback constants.
- The fx-12 imported texture byte check remains open. Native image and video capture awaits the design owner’s window server.
