# mrg-15 candidate 4 effects integration

The approved trees are composed in the working files on `codex/mrg-15` at `a0094c780`. The working rules assign the merge commits to the design owner and require this implementation to remain uncommitted. [File inventory](/private/tmp/labyrinth_codex/mrg-15/files.txt)

## 1. Composition and conflict resolutions

| Order | Approved tip | Resolution |
| --- | --- | --- |
| 1 | `ba6f5ac47` · fx-23, including fx-17 and fx-20 | `reflect_view.gd` keeps gfix-34's one baked head, actor return tile, Mirror flash and round-trip clock. The existing elemental hit/floor pair supplies the contact for Ember and Spark, whose approved shot-atlas rows have an empty hit field. `shot_fx.gd` combines fx-23's palette, launch anchors and adapter flights with the gfix-34 reversed return and authored shot hit. `run_scene.gd` keeps both contact-burst and acquisition preloads and reset paths alongside Blink. The pending `card_played` receipt and both quit entry points retain their candidate 4 implementation. |
| 2 | `7520d815f` · fx-29 | `reflect_view.gd` and `shot_fx.gd` take the Refraction lance path and sweep while retaining the reflected-player-shot path from step 1. `run_scene.gd` hands the Mirror's reserved area to fx-29's adapter, which starts the Ice stamps as the lance passes. The obsolete fx-20 Refraction cue is removed from the composition. The cutout releases at frame 13 and lands at frame 34 of 66. The sprite fallback lands at 300 ms. |
| 3 | `2f23a3376` · fnd-03, including fnd-02 | Applied cleanly. The approved relic claim, shop, event and dragon milestone changes compose with the combat effects. |

The incoming history was checked across all three pins. `git log a0094c780..HEAD --format=%s` is empty until the design owner's merge commits.

```text
MRG-15 NEVER MERGE: PASS (0 excluded subjects across 13 incoming commits)
```

[Incoming commit log](/private/tmp/labyrinth_codex/mrg-15/approved-ancestry.txt)

### Export and asset inventory

All six presets already contain the union of their 33 include patterns from the four source trees. The explicit data entries in every preset are:

- `data/tooltip_loops.json`
- `data/tile_bursts.json`
- `data/self_bursts.json`
- `data/shots.json` for Ember, Spark, Scatter Shot and the existing Ice lance
- `data/strikes.json`
- `data/acquisition_bursts.json` for the gain screens
- `data/ground_fx_atlas.json`
- `data/ground_surface_style.json`

The Ice lance and relic, shop, event and dragon gains reuse those existing catalogues. The mounted pack check also verified `data/controls.json`. [Filter check](/private/tmp/labyrinth_codex/mrg-15/logs/filter.log) · [Pack check](/private/tmp/labyrinth_codex/mrg-15/logs/pck.log)

The asset inventory retains the candidate 4 pins, registry and all five provenance files. The seven repeated shot-sheet paths use these fx-23 hashes, which match the merged files.

| Sheet | Git blob SHA-1 |
| --- | --- |
| `shot_44.png` | `4fba2cb5eec0762bde459ed27b3342328a7f7eb7` |
| `shot_52.png` | `2c09c195bd943e96d6e325913e9e3e1ec00f0f27` |
| `shot_60.png` | `e59bd33e751470987b6b2fed927e225094d305bb` |
| `shot_68.png` | `3691bc194339e0758d7eec7b87f071d43251953e` |
| `shot_76.png` | `973ae8ef314761faea25f12bd9fcd7a8302699a9` |
| `shot_84.png` | `8f7b48078d1f5c843183ddfa8b56c3d5ebca605c` |
| `shot_92.png` | `be5098876dd86d1c54029a473533930001caa244` |

The older fx-23 manifest carries a stale pin for `assets/art/effects/defense_heal_casts.png`. The file is absent from all four source trees. Candidate 4's approved inventory already records the retirement. Every pin backed by a source file was retained.

## 2. Shipped playback

The FX-17 and FX-20 verifiers exercise single hits, collisions, one burst per tile, and the existing Shadow contact. FX-23 exercises Ember and Spark, including Scatter Shot, without a feature flag. FX-29 covers the cutout and fallback Ice lance, hidden tiles, cancellation and reduced motion. FND-01, FND-02 and FND-03 cover board and reward pickup, relic claims and Guardian trophies, and shop, event and dragon reward gains, respectively. The shipped macOS pack has the same data bytes and all 48 referenced sheets.

## 3. Reflected shots

The original gfix-34 verifier checks path, headings, visibility and the hero's authored hit. The mrg-15 extension reuses that verifier's flight checks for Scorch and Arc Flash and checks one Fire or Lightning hit on the hero at the existing contact. Hurl Spear exercises the plain shot.

```text
GFIX-34 TIMING spear before=7 after=7 total=0.272000s
MRG-15 TIMING ember frames=7 total=0.272000s impacts=[[(4, 4), 17]] expected_row=17
MRG-15 TIMING spark frames=7 total=0.272000s impacts=[[(4, 4), 33]] expected_row=33
```

## 4. Scope and verification

Game changes come from the approved tips and the conflict resolutions listed above. The integration-specific proof change in `tools/fx20/native_capture.gd` reads gfix-34's visible reflected head for the existing heading assertions. `stage_proof.py` pairs historical comparison boards with their corresponding painter scripts and atlas so the references and clocks are exercised together. The protected design data and assets retain their approved values.

The 104-path inventory includes the shot sheets and catalogue, Mirror cutout adapter, combat and acquisition playback, approved incoming tests and tools, the pin updates and the mrg-15 proof files. The mrg-14 brief path was absent from this checkout. Its checked-in `tools/mrg14/result.md` and pack probe supplied the previous candidate's proof procedure.

All Godot runs used `python3 tools/godot_task_runner.py --task-id mrg-15 --stream`. [Run logs](/private/tmp/labyrinth_codex/mrg-15/logs)

| Check | Observed result |
| --- | --- |
| `tools/gfix34/verify.gd` | `GFIX-34 VERIFY: 308 checks, 0 failures` |
| Reflected Ember and Spark extension | `MRG-15 REFLECTION VERIFY: 68 checks, 0 failures` |
| `tools/fx17/verify.gd` | `FX-17 VERIFY: 128 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fx20/verify.gd` and affected suites | `FX-20 VERIFY: PASS (172 checks, 0 failures)` · `FX-20 VERIFY: PASS (3394 checks, 0 failures)` |
| `tools/fx23/verify.gd` | `FX-23 VERIFY: PASS (258 checks, 0 failures)` |
| `tools/fx29/verify.gd` | `FX-29 VERIFY: 4258 checks, 0 failures` |
| FND-01 pickup and reward regression | `FND-01 VERIFY: 111 checks, 0 failures` · `TEST RESULT: PASS` at the authored test clock of 60 fps. An exploratory wall-clock run reported `FND-01 VERIFY: 111 checks, 2 failures` in the frame-timed pickup assertions. |
| `tools/fnd02/verify.gd` | `FND-02 VERIFY AFTER: 194 checks, 0 failures` · `TEST RESULT: PASS` |
| `tools/fnd03/verify.gd` | `FND-03 VERIFY AFTER: 352 checks, 0 failures` · `TEST RESULT: PASS` |
| FX-14 affected shots and combat suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1991 checks, 0 failures)` |
| Shot pixel identity | `FX-23 PIXEL IDENTITY: PASS (196 regions across 7 atlases, indices and colours)` · `FX-23 EMBER IDENTITY: PASS (7 regions against 2fbbd06c0, indices and colours)` |
| Approved pin and resource test | `Ran 1 test in 10.835s` · `OK` |
| macOS export, filters, pack | `CEL_PACK_TEST paths=3089 failures=0` · `MRG-15 EXPORT FILTERS: PASS (6/6 presets)` · `MRG-15 PCK: PASS (8/8 data files, 48/48 sheets)` |
| UI identity and rules text | `Ran 25 tests in 4.838s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| Python default group | `ISOLATION AUDIT: 59 modules` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 37.670s` · `OK` |

## Proof for the design owner

The launcher uses the four existing native capture harnesses in sequence with `LABYRINTH_CEL_LOOK=all`, an exact 1920×1080 SubViewport and 100% UI scale. It captures the integrated revision. FND-03 compares its capture timing to the already recorded pinned-base takes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-15 && /private/tmp/labyrinth_codex/mrg-15/native.sh
```

Headless replay:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-15 && /private/tmp/labyrinth_codex/mrg-15/native.sh --dry-run
```

| Planned output folder | Still and reel | Observed headless result |
| --- | --- | --- |
| `/private/tmp/labyrinth_codex/mrg-15/native/gfix34` | `strip.png`, `mirror-return.mp4` | `GFIX-34 NATIVE DRY RUN strip: 6 checks, 0 failures` · `GFIX-34 NATIVE DRY RUN reel: 6 checks, 0 failures` |
| `/private/tmp/labyrinth_codex/mrg-15/native/fx23` | `<case>/strip.png`, `fire-lightning.mp4` | `MRG-15 FX-23 CAPTURE PLAN: PASS (17 strips, 240 reel frames)` |
| `/private/tmp/labyrinth_codex/mrg-15/native/fx29` | `strip.png`, `refraction.mp4` | `FX-29 NATIVE DRY RUN strip: 17 checks, 0 failures` · `FX-29 NATIVE DRY RUN reel: 6 checks, 0 failures` |
| `/private/tmp/labyrinth_codex/mrg-15/native/fnd03` | `after/<case>/strip.png`, `acquisition-gains.mp4` | Five `TEST RESULT: PASS` and five matching pacing receipts · `FND-03 REEL PLAN: 480 frames at 60 fps with audio` |

[Capture plan log](/private/tmp/labyrinth_codex/mrg-15/logs/native-plan.log) · [Headless capture receipts](/private/tmp/labyrinth_codex/mrg-15/native-plan)

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The supplemental reflection verifier reuses the gfix-34 board, seed, actor positions and frame sampling. It uses the existing Scorch and Arc Flash cards as the Ember and Spark witnesses.
- The capture launcher uses a 300-second native watchdog and the existing 60 fps, 64×64 MovieWriter host. The four probes use their existing 1920×1080 camera, crops and production UI settings.

## Open issues

- Three merge commits and windowed capture remain for the design owner. The headless launcher completed and wrote capture receipts.
- The extra QA-131 and analytics runs retain an outdated expectation that Tremor and the overlapping powder keg each submit a burst. FX-20 gives Tremor's area the overlap. The QA-131 interruption recorded 26 stamps across 13 tiles, one front/rear pair per tile. The raw results were `QA131 LIVE EFFECTS: 75 checks, 2 failures`, `GFIX-34 ANALYTICS APPLICATION: 48 checks, 2 failures` and `GFIX-34 ANALYTICS MENU: 48 checks, 2 failures`. Both analytics logs still report `control=1 quit=1 fields_equal=true` for both fixtures, and the resume receipts report a single preserved `card_played` event. The older assertion remains in place. [QA-131 log](/private/tmp/labyrinth_codex/mrg-15/logs/qa131.log) · [Application quit](/private/tmp/labyrinth_codex/mrg-15/logs/analytics-app.log) · [Save and Quit](/private/tmp/labyrinth_codex/mrg-15/logs/analytics-menu.log)
- Godot emitted the existing macOS certificate warning and the gain verifiers emitted resource diagnostics at exit. The Python runner's optional timing-cache write was denied by the read-only Git metadata. The requested verifiers and Python default group passed.
