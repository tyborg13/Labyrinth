# fx-19 implementation result

The working tree contains the implementation and proof tooling for the design owner's review. The source baseline is `7d1ba7df9`. The task changes are uncommitted.

## Acceptance criteria

1. Departure plays the existing `summon_rear` and `summon_front` rows on the first transit submission. Both stamps use fx-13's original footprint placement and scene depth.
2. Full-motion arrival starts on the board clock at `max(0, arrival − reveal_seconds("summon"))` after departure. Hero Blink and ordinary Veil transit use the existing six 40 ms samples. Fade uses the first authored phase sample that applies `blink_after`. Ambush with a strike uses the existing contact sample that updates the retained body. Shadowstep uses the existing caption-only interval.
3. Glassway Compass and Empty Husk share one pair at each hero endpoint. The traded Illusion retains its existing body placement.
4. Resolved Blink submits no procedural transit overlay. The former wash, line, three bands, edge strokes, motes, rings, mouths, puffs and afterimage drawing helpers were removed. The authored aim preview and its texture-free fallback submit the same commands and arguments as the base.
5. The existing fx-13 Illusion cue owns its tile in Afterimage and Voidsilk Molt. An Expose badge gain also reserves its tile for existing fx-13 pool feedback.
6. `spawn_self` gates both endpoints through the submitted board's visibility. Shadowstep's hidden origin adds zero rows. Umbra-clipped Stalker effects match their presented endpoints and place the stamps on the resolver's actual tiles.
7. Reduced motion uses fx-13 still frame 5. Departure uses the first transit submission and arrival uses the first landing submission.
8. The tear stamps run on the board clock. The existing playback and audio awaits control action duration.

## Blink sites

| Site | Playback |
| --- | --- |
| Direct card Blink | Trapdoor, Gravewind Gate, Dust Skip, Spur Vault, Gravewind Step, Voidsilk Molt, Cloudstep Loop, Smoke Bomb, Kestrel Dive, Grapple and Seek the Light use the direct hero path. |
| Ghost Stride | Armed movement resolves through the direct hero path. |
| Afterimage and Voidsilk Molt | The Illusion creation pair plays at the origin and the tear pair plays at the landing. |
| Glassway Compass and Empty Husk | Glassway Move uses the segmented movement path. Glassway with a Blink action and Empty Husk use the direct path. The two legs share the endpoint tears. |
| Unclouded Sun | Each resolved Light relay in a Move uses the segmented Blink path. A following walk can submit the first destination position before the hero's logical state updates. This relay entry point was additional to the examples in the brief. |
| Gloam Stalker | The authored Fade and Ambush and the legacy Stalker adapter are covered when they submit a resolved Blink. The existing fog-filtered action path can present a hidden enemy's visible movement as a walk. |
| Shadowstep | The battlefield-rule receipt carries before and after unit snapshots. Its existing caption-only beat can move one or more hidden enemies. This caption-only base path now plays a tear at each visible destination. |
| Aim preview | The authored texture and fallback continue through the existing draw path, including Glassway's two preview legs. |

The first landing submission is observed from the board's visible body snapshot. A direct Blink continues submitting the before-state through its samples, then submits the resolved body. A relay can first show a destination through `unit_world_positions` on the next segment. The reduced-motion hook uses the same starting override and departure comparison as the rift relay cue. Enemy landing uses the existing post-Blink snapshot. Shadowstep first shows the new tile when the board submits its resolved beat.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-19 && /private/tmp/labyrinth_codex/fx-19/native.sh
```

The tracked launcher is `tools/fx19/native.sh`. It stages the two base sources from Git for matched captures and runs each take through `tools/visual_probe_runner.py`. The seven 960×720 crops in each strip are ordered departure, +67 ms, +133 ms, +200 ms, arrival, +100 ms and +233 ms. Each is cropped from a real 1920×1080 SubViewport at 100% UI scale with the combat HUD and cel look. Planned outputs follow.

- `/private/tmp/labyrinth_codex/fx-19/native/{base,current}/full/{hero3,glassway,shadowstep}/strip.png`
- `/private/tmp/labyrinth_codex/fx-19/native/{base,current}/full/{hero3,glassway,shadowstep}/native-evidence.png`
- `/private/tmp/labyrinth_codex/fx-19/native/current/full/recording/two-blinks.mp4`

Each directory also receives `take.json` and `manifest.json`. The sandbox has no macOS window-server access. Native pixels and video remain for owner inspection.

## Verification

`FX-19 MATCHED HEADLESS PASS (16 cases)` and `FX-19 CAPTURE PLAN PASS (6 strips, 1 recording)`. The matched cases use real resolver and RunScene playback. Every measured action completion and landing frame matches the base. Full-motion reveal is within one frame of the first landing submission. Reduced-motion reveal is on that submission. The per-tile row, scheduled start, sampled reveal, depth and footprint are in each take receipt. [Exact headless result lines](/private/tmp/labyrinth_codex/fx-19/proof-summary.log)

| Case | Full landing / reveal / complete | Reduced landing / reveal / complete |
| --- | --- | --- |
| Hero Blink 2 | 36 / 36 / 95 | 28 / 28 / 68 |
| Hero Blink 4 | 36 / 36 / 95 | 28 / 28 / 68 |
| Ghost Stride | 15 / 15 / 24 | 15 / 15 / 24 |
| Glassway exchange | 15 / 15 / 29 | 15 / 15 / 29 |
| Shadowstep | 37 / 36 / 37 | 37 / 37 / 37 |
| Afterimage | 36 / 36 / 95 | 28 / 28 / 68 |
| Fade | 39 / 39 / 49 | 0 / 0 / 1 |
| Ambush | 33 / 32 / 68 | 15 / 15 / 22 |

Receipts are under `/private/tmp/labyrinth_codex/fx-19/{native,movement,foes}/verify/{base,current}/{full,reduced}/<case>/take.json`. The capture dry run wrote seven receipts under `/private/tmp/labyrinth_codex/fx-19/native/plan/`. The five-second plan observed two hero Blink cues on frames 36 and 131. [Native plan log](/private/tmp/labyrinth_codex/fx-19/native-plan-matched.log)

- `FX-19 FOCUSED PASS (2332 checks, 0 failures)`. Ran the existing board layout, battlefield rule, CBT-01, skill, relic, enemy and player movement suites through the focused harness. [Focused Godot log](/private/tmp/labyrinth_codex/fx-19/focused-final.log)
- `PASS: Rules text lint (16 existing hits)`.
- `SFX SYNC HARNESS RESULT: FAIL (289 observations, 22 failures)`. All 22 current failures reproduced with the base RunScene source. All seven Blink timing rows match, including the three composite relay fixtures. [Current SFX log](/private/tmp/labyrinth_codex/fx-19/sfx-final.log), [base SFX log](/private/tmp/labyrinth_codex/fx-19/sfx-base.log)
- Python default group reported `Ran 194 tests in 46.873s` and `FAILED (failures=2)`. One failure named the same two missing tracked `tools/flt01/` UIDs present in the first run and absent at the base revision. The runner-start test reported `Child did not start` during parallel verification. In isolation it reported `Ran 1 test in 3.001s` and `OK`. [Default Python log](/private/tmp/labyrinth_codex/fx-19/python-default-final.log), [isolated runner log](/private/tmp/labyrinth_codex/fx-19/python-runner-followup.log)

The headless import bootstrap timed out at 300 seconds. Verification used the 21 matching imported burst and strike textures from the local fx-15 cache after checking source and artifact checksums. [Import log](/private/tmp/labyrinth_codex/fx-19/import.log)

## Chosen defaults

- Proof fixture reuses the existing inspection seed, hero health and combat-room fixture. The hero starts at `4:4`. The 4-tile hero, Fade and Ambush cases use the existing en-03 proof grid, with the long hero target at `6:2` and the Stalker at `6:4`.
- Glassway uses a 2-tile exchange. Ghost Stride and Afterimage use a level-6 proof profile. The Shadowstep take uses the existing rule suite's 3-tile dial, with hero `5:5` and enemy `5:1`.
- The capture crop centers between the tiles with 150 px of body headroom. The capture and fixed-frame proof use 60 fps and the existing fx-15 runner limits. The recording allocates 300 frames for the requested five seconds.

No `TODO_DESIGN_*` placeholders were needed.
