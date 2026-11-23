# fx-36 implementation and proof

The existing Chain and Arc Lash contact callbacks start a retained bolt texture. Chain Bolt, Storm Relay, Storm Salvo and all three Arc Lash jumps use the scheduled damage sample. Opening Spark flights, empty relay contacts, and Electrified conduction retain their existing presentation. The final airborne leg from a Storm Relay floor contact to a unit uses that relay's floor-burst anchor.

The texture matches the Spark cell grid and uses `#5a3a9a`, `#d0c0ff` and `#ffffff` from the Spark bake. It uses mitered cell strokes, ordered dither and the seeded path from `data/chain_bolt.json`. Both ends occupy the snapped cells of their existing burst anchors. The bolt runs for two full-strength frames and three fade frames on the 30 fps game clock, with a single re-jag at the start of the fade. Reduced motion holds one still for 100 ms of game time.

## Director feedback 1

The director's first native pass reported `FX-36 NATIVE COMPARISON PASS`. In Chain Bolt's first hop, the nearer crawler covered most of the bolt at contact. The updated bolt uses the later of the two endpoint front effect layers, applying the burst's footprint depth rule. This puts the texture above both endpoint units and below the damage numbers, status chips and HUD. Empty relays still use their front floor layer. [Original contact crop](/private/tmp/labyrinth_codex/fx-36/native/now/chain_bolt/hop-1-contact-2x.png)

The first Chain Bolt hop still lands at frame 44. Its bolt draws in layer 138, after the unit layers at 125 and 137 and before the damage-number and HUD layers at 166 and 167. The same verifier retains the contact, anchor, palette, path, fade and reduced-motion checks. The dither table uses the director's `PackedInt32Array`. [Updated take](/private/tmp/labyrinth_codex/fx-36/feedback-1/headless/now/chain_bolt/take.json)

## Contact samples

Frames count 60 Hz process samples from take start. Each listed sample starts the bolt, number and target burst. Both board-space endpoint coordinates and both burst anchors are recorded in the verifier log and manifests.

| Fight | Opening Spark contact | Subsequent bolted contacts | Reduced-motion bolt contacts |
| --- | ---: | --- | --- |
| Chain Bolt | 18 | 6:4→6:5 at 44, 6:5→5:5 at 62 | 8, 16 |
| Storm Relay | 18 | 6:4→6:5 at 44, 6:2→6:1 at 78 | 8, 28 |
| Arc Lash | 64 | 4:3→4:4 at 77, 4:4→5:4 at 92, 5:4→5:5 at 104 | 21, 21, 21 |
| Storm Salvo | 18 | 6:4→6:5 at 44, 6:5→5:5 at 62 | 8, 16 |
| Spark Dart conduction | 18 | Conducted damage at 44 with zero bolts | Zero bolts |

## Verification

| Check | Observed result |
| --- | --- |
| fx-36 real-fight verifier | `FX-36 VERIFY PASS (620 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-36/feedback-1/dry-run.log) |
| Palette and cell size | `FX-36 PALETTE ["5a3a9aff", "d0c0ffff", "ffffffff"], Spark cell=2 px at 1920×1080`. All runtime bolt samples used these inks or transparency. |
| fx-33 comparison | The fx-34 control and fx-36 both reported `FX-33 VERIFY FAIL (2310 checks, 1 failures)` and `FX-33 FAIL spark_conduction exercises the retained floor line`. fx-34 replaced that line with baked floor bursts. The historical assertion was left intact. [Control](/private/tmp/labyrinth_codex/fx-36/feedback-1/regressions/fx33-self.log) · [Current](/private/tmp/labyrinth_codex/fx-36/feedback-1/regressions/fx33-now.log) |
| fx-33 focused suites | `FX-33 FOCUSED chain_attack PASS`, `FX-33 FOCUSED battlefield_conduction PASS`, `FX-33 FOCUSED en01_enemies PASS`, `FX-33 FOCUSED en06_enemies PASS`, `FX-33 FOCUSED hoarder PASS` and `FX-33 VERIFY PASS (8088 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-36/feedback-1/regressions/fx33-focused.log) |
| fx-34 comparison | `FX-34 BASELINE PASS (27 checks, 0 failures)` and `FX-34 VERIFY PASS (490 checks, 0 failures)` with the same 60 Hz presentation clock in both staged copies. This keeps the existing reward roll on the frame clock during headless playback. [Log](/private/tmp/labyrinth_codex/fx-36/feedback-1/regressions.log) |
| UI identity lint | `Ran 25 tests in 4.307s` and `OK`. [Log](/private/tmp/labyrinth_codex/fx-36/feedback-1/ui-lint.log) |
| Rules text lint, round 0 | `PASS: Rules text lint (16 existing hits)`. |
| Python default, round 0 | `Ran 194 tests in 31.916s` and `OK`. The optional shared timing-cache write was denied. [Log](/private/tmp/labyrinth_codex/fx-36/python-default.log) |
| Minimal export pack, round 0 | `FX-36 PACK JSON PASS`. The runtime read the JSON from an all-resources pack with an empty extra include filter. |
| Three-revision headless proof | `FX-36 DRY RUN PASS · /private/tmp/labyrinth_codex/fx-36/feedback-1/headless`. The three revisions used identical contact columns. The fx-33 and fx-36 takes matched the resolved routes, damage, bursts, and playback duration. [Log](/private/tmp/labyrinth_codex/fx-36/feedback-1/dry-run.log) |

The original wall-clock fx-34 comparison reported `FX-34 VERIFY FAIL (490 checks, 10 failures)` in the missed-gear frame ledger. A second baseline take alone reported `FX-34 BASELINE FAIL (27 checks, 1 failures)` after its reward roll pushed the missed-gear beat outside the three-second reel. The fixed clock is applied only in the temporary regression projects. [Original comparison](/private/tmp/labyrinth_codex/fx-36/regressions/fx34-now.log) · [Baseline retry](/private/tmp/labyrinth_codex/fx-36/retry/regressions/fx34-before.log)

Godot reported `ERROR: 4 resources still in use at exit` after the feedback-1 verifier passed, a warning also recorded during the original baseline captures. The dry-run launcher exited 0. [Feedback 1 log](/private/tmp/labyrinth_codex/fx-36/feedback-1/dry-run.log) · [Original log](/private/tmp/labyrinth_codex/fx-36/dry-run-final.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-36 && FX36_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-36/feedback-1 LABYRINTH_CEL_LOOK=all /private/tmp/labyrinth_codex/fx-36/native.sh
```

The launcher uses the visual probe runner and a 1920×1080 SubViewport at 100% UI scale, with a 60 fps MovieWriter clock. It writes full contact frames, cropped panels and take manifests under `/private/tmp/labyrinth_codex/fx-36/feedback-1/native/{old,fx33,now}/<case>/`. The three-row sheets are `native/comparison/<case>/hop-<n>.png`, ordered mrg-14, fx-34 and the working fx-36 tree. Columns are contact, +33 ms, +100 ms, +166 ms, and a 2× crop at contact. The old Arc Lash row also has separate full-frame flight captures because the old line begins during flight. The game-speed reel is `native/chain-bolt-storm-relay-arc-lash.mp4`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-36 && FX36_OUTPUT_ROOT=/private/tmp/labyrinth_codex/fx-36/feedback-1 /private/tmp/labyrinth_codex/fx-36/native.sh --dry-run
```

The dry run wrote `/private/tmp/labyrinth_codex/fx-36/feedback-1/headless/{old,fx33,now}/<case>/take.json`. Windowed PNG and MP4 capture for the updated layering is pending the director's desktop session.

## Chosen defaults

The fixtures inherit fx-33's seed 7262026, normal combat speed, 30 hero Health and board positions. Arc Lash adds a fourth victim at 5:5. The isolated shape check uses seed 36 and a 120 px path. Capture centers each 640×480 crop between its two contacts and magnifies a 320×240 detail with nearest sampling. The reel allocates 180 frames per case, the headless observer keeps a 16-sample tail, and the native timeout is 300 seconds. The inherited MovieWriter host window is 64×64.

There are no design placeholders. All changes are uncommitted.
