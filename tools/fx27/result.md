# fx-27 Hollow Mimic Shade flight

The implementation is uncommitted on `codex/fx-27`, based on `7179c630c`.

## United line

All eight verifiers ran before the first source edit. The merge left a call to `ResolvedContactBursts._terrain_lost` in the Lightning hop path. FX-25 had removed that helper after adding surviving terrain losses to `TileBurstFx.hit_tiles`. RunScene now uses the shared hit map. The worktree also lacked the 28 imported textures for the four effects atlases across their seven sizes. I refreshed only the task-local import cache from the existing PNGs and sidecars.

- The fx-22 dry-run launcher now stages its historical board-surface and Veilbound painter dependencies, matching the fx-24 launcher. No fx-22 assertions changed.
- The fx-24 Veilbound melee and Shadow trap assertions now require the baked rows that fx-25 authorized. The trap requires one hit at the centre and one floor row on each cardinal neighbour, all on the original contact sample.
- The fx-25 comparison now uses the fx-26 parent `3e946d932` for the pre-tendril data and effect scripts. The former overlay lacked the `include_outcome` API required by the merged RunScene. The verifier observes retained windup submissions from the cutout adapter and requires the two new Mimic flights. Its ranged-area witnesses require the fx-26 flight, one Gloom hit at the aim and the original fx-25 tendril rows.
- The fx-26 verifier continues to compare complete arrival rows and birth samples. Its Shadow cases require the same tendrils plus one Gloom hit at the aimed centre on contact. In the shared renderer the shot resolves during board submission, followed by RunScene's existing tile burst callback in that sample.

## Acceptance criteria

1. Shade Bolt starts from the posed `hand_far` bone named in the approved bolt clip. The board uses `_cutout_launch_point` and the same retained Shade shot and target anchor as Veil Needle. Exactly one `hit_gloom` starts at contact. The proof observed zero legacy decals and zero tendril stamps for the single-target attack.
2. Echo's first, ranged action uses the same clip and shot path. A dedicated take ran both resolver steps and measured the separate Retaliate granting 3 on sample 77 before and after.
3. Both Mimic attacks retain 48 authored frames, 800016 µs, and zero-based contact sample 28. Both release on authored frame 9 (one-based), observed on zero-based sample 11. Their style uses the standard `release_for(style)` threshold of 0.18. The director's frame-16 fallback was unused.
4. Reduced motion submits no flight and preserves the original contact sample. The Mimic, Veil Needle and Shadow-area witnesses each submit exactly one Gloom still. The area also submits the six tendril layers on contact.
5. The shared visibility clipping produced `[0.234375, 1.0]` when the source was hidden and `[0.0, 0.46875]` when the target was hidden. The visible hero received one hit. The hidden target received no hit sprite.
6. The Mimic rig, clips, integration, shot and tile-burst catalogs, and atlases are byte-identical to the base.

The before takes use the scripts from `7179c630c` with the redundant terrain-loss call removed so Godot can parse them. Both sides use the same resolver and approved data. “Sample” is the zero-based 60 Hz take index and includes existing combat pacing. Authored release is the one-based animation frame.

| Headless take | Frames before → after | Release sample before → after (authored release) | Contact sample before → after | Gloom count before → after | Tendril layers before → after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Shade Bolt | 48 → 48 | — → 11 (9) | 28 → 28 | 1 → 1 | 0 → 0 |
| Echo first strike | 48 → 48 | — → 11 (9) | 28 → 28 | 1 → 1 | 0 → 0 |
| Veil Needle | 54 → 54 | 12 → 12 (10) | 44 → 44 | 1 → 1 | 0 → 0 |
| Ranged Shadow area | 6 → 6 | 3 → 3 (2) | 6 → 6 | 0 → 1 | 6 → 6 |
| Shade Bolt, Echo and Veil Needle, reduced | 1 → 1 each | — | 0 → 0 | 1 → 1 each | 0 → 0 |
| Ranged Shadow area, reduced | 6 → 6 | — | 0 → 0 | 0 → 1 | 6 → 6 |

All four normal and reduced comparison cases had zero legacy decals on both sides. The area is fx-25's proof-only three-tile adaptation of Shade Bolt. Gloom is centred at the aim, and each tendril pair retains the board's existing per-tile stagger.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-27 && /private/tmp/labyrinth_codex/fx-27/native.sh
```

The launcher runs the windowed visual probe at 1920×1080, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. It writes the eight releases-to-contact-plus-366 ms strips to `/private/tmp/labyrinth_codex/fx-27/native/{before,after}/{shade_bolt,echo,veil_needle,area_ranged}/` with `strip.png`, `native-evidence.png`, `take.json`, and `manifest.json` per take. The after-only four-second silent fight reel is `/private/tmp/labyrinth_codex/fx-27/native/hollow-mimic-shade-bolt.mp4`. The full-size reel contact evidence and the manifest go under `native/after/recording/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-27 && /private/tmp/labyrinth_codex/fx-27/native.sh --dry-run
```

Headless comparisons emit per-take JSON under `/private/tmp/labyrinth_codex/fx-27/headless/{before,after}/`. [Headless log](/private/tmp/labyrinth_codex/fx-27/dry-run.log)

## Verification

| Check | Observed result |
| --- | --- |
| fx-12 | `FX-12 VERIFY: 120 checks, 0 failures` · `TEST RESULT: PASS` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx12.log) |
| fx-14 with affected suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1991 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx14-final.log) |
| fx-17 | `FX-17 VERIFY: 132 checks, 0 failures` · `TEST RESULT: PASS` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx17.log) |
| fx-20 | `FX-20 VERIFY: PASS (172 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx20.log) |
| fx-22 dry run | `FX-22 VERIFY: PASS (266 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx22.log) |
| fx-24 dry run | `FX-24 VERIFY: PASS (452 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx24.log) |
| fx-25 dry run | `FX-25 BASELINE: PASS (17 checks, 0 failures)` · `FX-25 VERIFY: PASS (569 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx25.log) |
| fx-26 dry run | `FX-26 VERIFY: PASS (315 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/fx26.log) |
| fx-27 dry run | `FX-27 VERIFY: PASS (164 checks, 0 failures)` · [Log](/private/tmp/labyrinth_codex/fx-27/dry-run.log) |
| Python default group | `Ran 194 tests in 38.288s` · `OK` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/python-final.log) |
| Rules text | `Ran 3 tests in 0.089s` · `OK` · `PASS: Rules text lint (16 existing hits)` · [Log](/private/tmp/labyrinth_codex/fx-27/verification/rules-text.log) |
| Task runner parse checks | Exit 0 for all 11 changed GDScript files using `--check-only`. [Parse logs](/private/tmp/labyrinth_codex/fx-27/verification/parse) |

Shell syntax, Python syntax, proof-contract JSON, protected-path diff, and `git diff --check` returned exit 0. The concurrent Python run reported `AssertionError: False is not true : Child did not start` in the runner's five-second process-group fixture. The default group passed at base and in the isolated final run. The concurrent fx-14 diagnostic missed its asynchronous resize deadline. Both standalone runs passed the original assertion. Godot logged the macOS certificate startup warning on successful headless runs. The Python runner completed the tests and reported the expected denial updating its scratch timing cache in Git metadata.

## Files

- `scripts/maquette_cutout_runtime/{action,contact_actions,effect_sockets}.gd` selects the Mimic bolt, submits its windup flight, and reads its posed launch bone.
- `scripts/{shot_fx,run_scene}.gd` maps that flight to the shared shot clock, delivers the ranged Shadow-area arrival, and uses the shared Lightning hop hit map.
- `tools/fx22/native.sh`, `tools/fx24/verify.gd`, `tools/fx25/{stage.py,native_capture.gd,verify.gd}` and `tools/fx26/verify.gd` maintain the united verifier runs.
- `tools/fx27/` contains the launcher, before staging, GDScript native and headless probes and their UID sidecars, strip and reel proof contracts, and this report.

## Chosen defaults

- The debug fixtures inherit fx-25's seed, health, cleared stone lanes, camera, and 60 Hz pacing. The fog target is an Illusion at (4, 3), with the hero on (4, 5) and a radius-zero light at the Mimic's tile (4, 2). The hidden-source take retains the hero at (4, 4) under Eclipse and has no added light.
- Each seven-column strip uses 640×480 crops centred on the projected source, aim and footprint. Samples are release, one-third and two-thirds of the release-to-contact interval, contact, and contact plus 6, 14 and 22 samples. The 240-frame reel and 300-second native capture timeout follow fx-25.

## Remaining procedural effects

The new Mimic flights and arrival are atlas-backed. The procedural paths inventoried by fx-26 still apply, including Slag Mortar's rig-owned lob, protected dragon breath and fallback casts, conductive floor paths and legacy electrical branches, explicitly unmapped projectiles, Glacial Mirror's Shadow return path, and Hoarfrost Seer wind and intent previews. [fx-26 inventory](../fx26/result.md)

## TODO_DESIGN

None.

## Open issues

Native frame and reel inspection require the design owner's window server. This task ran the headless proof only.
