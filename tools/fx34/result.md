# fx-34 implementation and proof

Base `584a3c6d3`, risk tier low. All edits are in the prepared `codex/fx-34` worktree.

## Base inventory

A floor stroke requires `effect.kind == "chain"` and a resolver path of at least two cells. The board consumes `branches[*].path` when a grouped beat has branches and `effect.path` otherwise. Resolver paths are cardinal walks through a conductive component.

| Presentation | Existing beat | Path cells in the witnesses | Contact fraction |
| --- | --- | --- | --- |
| Player conducted attack, one target | A post-opening Lightning beat. Spark Dart supplies the witness. The same route serves damaging player Lightning attacks with a resolved conduction trace. | 4, through 6:4, 6:3, 6:2, 6:1. In play, length depends on the component and target. | 0.42 on the 12-sample, 0.22 s beat |
| Player conducted attack, grouped targets | Consecutive conducted hits form one Lightning beat and keep their separate resolver paths. The Spark Dart fork exercises both shared interiors and a contact on the trunk. | 4 to 6:1, 5 to 4:2, and 3 to 6:2 | 0.42 for every target in the group |
| Player opening projectile | The card's existing initial animation. Both Spark Dart witnesses use this beat before their conduction. | 0 | The opening attack's existing contact fraction |
| Actor-to-actor Chain, including Chain Bolt and Storm Salvo | Ordinary airborne hop. | 0 in the resolver trace | 0.42 on a later hop |
| Conductive Chain relay and ranged delivery via a relay | Empty-floor relay is a 12-sample, 0.12 s beat. Range delivery uses the opening shot or a subsequent ranged delivery. Chain Bolt and Storm Relay can also resolve a separate conducted beat when a component has a terminal victim. | 0 on the relay and delivery entries | Opening contact for the first beat, 0.42 on later beats |
| Enemy Lightning and Capacitor Discharge | Ordinary enemy attacks publish their enemy attack effect. Capacitor publishes an actor-to-actor `chain` descriptor without a floor path. | 0 in the Capacitor presentation and no published floor path for ordinary enemy Lightning | The existing enemy action or Discharge timing |
| Battlefield Lightning Storm | The primary sky strike marks the whole footprint. The authored rule disables Chain and conduction. | 0 | The existing sky-strike contact |

A two-cell conducted path can reach the old painter, with no interior tile to stamp. Reduced motion keeps the one-sample chain beat and its existing immediate contact. The dashed aiming preview is a separate painter.

## Acceptance

1. The inventory above follows the live `chain` effect producers through the resolver and board. Both path-bearing player cases are exercised.
2. The chain player schedules each unique interior tile at the first submitted sample at or beyond `k/n × contact`. It reserves beat contacts and takes the earlier threshold when two paths contain the same interior tile. It submits after the board snapshot so the existing visibility and rear/front placement apply. The shared player runs each stamp on its own clock.
3. The solid floor line, alpha helper and tile-pass submission are gone. The dashed preview and retained Electrified floor remain. The GPU pixel contract has 17 images after dropping the three floor-conduction images.
4. The first missed-gear frame submits one simultaneous Fire floor batch. The existing loot resolution filters salvage, and the shared tile player culls hidden tiles and selects the reduced still.
5. The whole pickup uses the same bobbed rectangle, minus the prescribed vertical rise. The base tint and alpha curves, draw cutoff, prop art treatment and shadow call are preserved.
6. The diamond, cinder and sliced-item painters are deleted. The comparison below audits the removed submissions.
7. Contact frames, authored and submitted samples, floating text, the fade clock, resolved loot and notice match exact base in the comparison. The edits leave the existing trap dispatch, audio calls and other surface feedback in place.

## Row starts

The sample is one-based within its beat. The frame is relative to the start of the 60 Hz take. Each entry is a rear/front pair at one size with the same start. The pair shares the target tile canvas z-index and uses sibling orders −1 and +1 relative to that canvas. On the fork, the pair at 5:2 brackets the hero at those same orders.

| Case | Element | Tile | Fraction | Full motion sample / frame | Reduced motion sample / frame |
| --- | --- | --- | --- | --- | --- |
| Spark Dart | Lightning | 6:3 | 1/3 | 2 / 40 | 1 / 8 |
| Spark Dart | Lightning | 6:2 | 2/3 | 4 / 42 | 1 / 8 |
| Branched | Lightning | 6:3 | 1/4 | 2 / 40 | 1 / 8 |
| Branched | Lightning | 5:2 | 3/4 | 4 / 42 | 1 / 8 |
| Fogged path | Lightning | 6:3 | 1/3 | 2 / 40 | 1 / 8 |
| One missed | Fire | 4:3 | 0/1 | 1 / 115 | 1 / 98 |
| Two missed | Fire | 4:3 | 0/1 | 1 / 115 | 1 / 98 |
| Two missed | Fire | 5:4 | 0/1 | 1 / 115 | 1 / 98 |
| One missed plus one salvaged | Fire | 4:3 | 0/1 | 1 / 130 | 1 / 113 |
| Fogged gear | Fire | 7:1 | 0/1 | Culled | Culled |

The branched beat keeps the contact at 6:2 and replaces a shared 1/3 start at 6:3 with the earlier 1/4 start. The fogged path keeps 6:2 in the resolver path and spawns no row there. The salvaged item at 5:4 gets no row. Full-motion rows showed cells 0–12, and reduced motion showed cell 3 for the shared player's 0.18 s. The full-motion Spark rows last through take frames 70 and 72, after the action finishes at frame 56.

Spark Dart's opening and conducted contacts stayed at frames 18 and 44 in full motion and 0 and 8 in reduced motion. Branched contacts on 6:1, 4:2 and 6:2 all kept frame 44 or 8. The opening used 30 × 0.0115 s and contact 0.2666667 in full motion. The conducted beat used 12 × 0.018333 s and contact 0.42. Each reduced beat used one 0.10 s sample. The item curves matched all eleven fade samples per visible item, and every case kept the 11 × 0.045 s missed beat and 0.08 s resolved-state hold. The quoted fractions for gear denote progress zero on the first frame.

## Removed-painter audit

The exact-base staging uses the original affected game scripts from Git. The same verifier observes resolved combat, retained burst stamps and floating texts for both versions. It evaluates the legacy paint paths at the recorded board samples and counts their primitive submissions with the renderer calls suppressed. The unchanged dashed preview is outside the audited effect paths.

| Representative case | Base effect submissions at the sampled draw sites | Working effect submissions |
| --- | --- | --- |
| Spark Dart | 56 floor callbacks, 504 line routes and 1,008 raw polyline fallbacks | 0 |
| Branched conduction | 84 floor callbacks, 1,512 line routes and 3,024 raw polyline fallbacks | 0 |
| One missed gear | 29 diamond calls, 26 sliced-item calls, 29 cinder callbacks and 585 cinder rectangles | 0 |
| Fogged gear | 0 visible missed-item callbacks | 0 |

All working takes recorded zero submissions from the deleted painters and their debug primitives. The brief's retained art and shadow paths still render. The whole pickup uses the shared textured alpha quad. The developer-only art-treatment toggle also retains its pre-existing polygon-based shadow fallback.

## Verification

| Check | Exact result |
| --- | --- |
| Exact-base headless proof | `FX-34 BASELINE PASS (27 checks, 0 failures)` and `FX-34 VERIFY PASS (490 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-34/dry-run-final.log) |
| Focused Godot | `FX-34 FOCUSED chain_attack PASS`, `FX-34 FOCUSED battlefield_conduction PASS`, `FX-34 FOCUSED item_pickup PASS`, `FX-34 FOCUSED skill_run PASS`, `FX-34 FOCUSED missed_equipment_resolution_and_persistence PASS`, `FX-34 FOCUSED PASS (879 checks, 0 failures)`. [Log](/private/tmp/labyrinth_codex/fx-34/focused.log) |
| Unchanged fx-32 verifier | `FX-32 VERIFY: PASS (870 checks, 0 failures)` on both exact base and the working tree. [Base](/private/tmp/labyrinth_codex/fx-34/fx32-exact-base.log), [Working](/private/tmp/labyrinth_codex/fx-34/fx32-after.log) |
| Unchanged fx-33 verifier | `FX-33 VERIFY PASS (2286 checks, 0 failures)` on exact base. The direct run reports `FX-33 VERIFY FAIL (2154 checks, 55 failures)` while calling the deleted `_surface_conduction_alpha` helper. In a temporary control with a zero-alpha response, `FX-33 VERIFY FAIL (2310 checks, 3 failures)` identifies the three old floor-line expectations. The remaining checks pass. [Base](/private/tmp/labyrinth_codex/fx-34/fx33-instrumented-exact-base.log), [Direct](/private/tmp/labyrinth_codex/fx-34/fx33-current.log), [Control](/private/tmp/labyrinth_codex/fx-34/fx33-zero-alpha-control.log) |
| Python default group | Initial run reported `FAILED (failures=1)` after the runner cancellation test's startup deadline. Retry reported `Ran 194 tests in 37.560s` and `OK`. The optional timing-cache write was denied by the read-only Git metadata. [Initial](/private/tmp/labyrinth_codex/fx-34/python-default.log), [Retry](/private/tmp/labyrinth_codex/fx-34/python-default-retry.log) |
| UI identity and rules text | `Ran 25 tests in 5.888s`, `OK`, and `PASS: Rules text lint (16 existing hits)`. [UI identity](/private/tmp/labyrinth_codex/fx-34/ui-lint.log), [Rules text](/private/tmp/labyrinth_codex/fx-34/rules-lint.log) |
| Parse and static checks | Task-runner `--check-only` exited 0 for the changed and new scripts and the existing missed-equipment probe. Shell and Python syntax, both image contracts and `git diff --check` passed. [Parse](/private/tmp/labyrinth_codex/fx-34/parse.log), [Final proof scripts](/private/tmp/labyrinth_codex/fx-34/parse-final.log) |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-34 && /private/tmp/labyrinth_codex/fx-34/native.sh
```

The desktop script uses the visual probe runner and the 60 fps MovieWriter clock with an exact 1920×1080 SubViewport, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. The four takes write `strip.png`, `native-evidence.png`, `take.json` and `manifest.json` under `/private/tmp/labyrinth_codex/fx-34/native/{before,after}/{spark,missed}/`. The full frames are at +100 ms for Spark, +233 ms for the base missed-gear effect and +133 ms for the Fire burst. The reel stitches the two after segments at 60 fps with MovieWriter audio under `/private/tmp/labyrinth_codex/fx-34/native/after/spark-then-missed-gear.mp4`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-34 && /private/tmp/labyrinth_codex/fx-34/native.sh --dry-run
```

The dry run emitted fourteen cases per revision at `/private/tmp/labyrinth_codex/fx-34/headless/{before,after}/<case>/take.json`. It selected Spark frames 38, 40, 42, 44, 48 and 56 and missed-gear frames 115, 119, 123, 129, 137 and 145 for both revisions. The after reel plan covers 180 frames per segment. The focused evidence rerun reports `FX-34 VERIFY PASS (65 checks, 0 failures)` and selected full-frame samples 129 for the base and 123 for the Fire burst. [Evidence rerun](/private/tmp/labyrinth_codex/fx-34/evidence-check.log), [Dry-run log](/private/tmp/labyrinth_codex/fx-34/dry-run-final.log)

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-34 && python3 tools/visual_probe_runner.py tests/pixel_fx_render_probe.gd --task-id fx-34 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/pixel_fx_render_probe_contract.json
```

## Chosen defaults

The proof inherits the fx-33 Spark Dart board, seed `7262026`, hero Health and normal combat speed. The fork adds the three target positions and places the hero on its 5:2 interior tile. The fog witness uses Eclipse, the proof hero at 5:4 and radius-zero lights at 6:1 and 6:3. The gear case uses Quick Stab against one 1-Health crawler. Ward Kite, Iron Cleaver and the fogged Ward Kite use 4:3, 5:4 and 7:1 respectively. Capture uses the existing game framing, a centered path or loot crop, a 64×64 MovieWriter host window, a 32-frame tail for observing rows and a 300 s native timeout.

There are no `TODO_DESIGN_*` placeholders. Native PNG and MP4 capture, GPU pixel rendering and desktop inspection require the design owner's window-server session. All changes are uncommitted.
