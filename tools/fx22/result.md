# fx-22 implementation handoff

The headless comparison uses `8f38fb277` and the uncommitted changes on `codex/fx-22`.

1. Removed `_draw_bile_bloomer_fragments`, its overlay call and `BileBloomerFx.draw_fragments`. The new `shot_for_intent.bile_burst` key selects Rock for a targeted Shale Burst. FX-14's retained Earth shot now starts at the existing Bloomer socket and ends at the existing ground point. The real resolver fixtures use Shard Mark's authored ranged action under the Shale Burst ID because the production Shale Burst has only an area action. Rock already defines `hit_chips`, so both a Health hit and a fully absorbed hit play that FX-14 asset. The existing FX-17 ranged fallback handles Earth hit/floor if a selected shot has no hit. The `burst_for_intent.bile_burst` empty override stays in place. The production AoE lost its radial fragments and still has its existing area wash and contact decal. Its radial effect had no directed flight target or directed flight timing. A baked replacement for that specific case is open.
2. Removed the Cinder Bloom overlay call and `CinderOozeActionFx.draw_bloom`. The four authored tiles already use FX-12 Fire pairs, all one tile from the Ooze. The surviving terrain witness needed a hit-row correction. No second pair or mapping was added. Both revisions submit the four pairs on sample 23 with a 0.033-second board-clock delay, and first display them on sample 32. The Ooze's authored pose samples match.
3. Removed `_draw_vaeloryx_wind_feedback`, its draw submission and `VaeloryxWind.draw`. Direct force steps and the live Skyhook ranged pull use the existing FX-18 cue and FX-12 Air pairs. The line starts on the closest footprint tile and ends on the original target tile. Health loss and spent Block both select Air hit on that last tile. A zero-loss pull selects Air floor throughout. The proof checks the original and final positions and the submitted displacement samples. The live Hollow Gale area retains its authored area playback. The direct push fixture exercises the resolver's direct Push transport with Hollow Gale's existing damage and push distance.
4. The verifier checks one impact per tile, both depth layers, the release-to-contact thresholds, fog clipping and reduced-motion stills. The fog witness omits (4,2) without shifting the surviving sweep thresholds. Exact authored and rendered frame counts and authored durations match. Capture-frame indices can differ by one sample at a clock boundary. Rock's first directed hit appears on capture sample 19 before and 18 after in the unblocked witness, at its existing authored contact on both takes. The completion frame matches in the final run.
5. Unmapped Fire and Lightning shot travel is still present. Other legacy drawing observed while tracing the board includes the Shale Burst AoE area wash and impact decal, the Cinder Ooze melee splash fallback, and procedural Shadow travel. These are separate from the three removed draw entries.

## Frame counts

| Resolver witness | Action frames before / after | Take completion before / after |
| --- | ---: | ---: |
| Targeted Shale, Health loss | 44 / 44 | 69 / 69 |
| Targeted Shale, all damage absorbed by Block | 44 / 44 | 69 / 69 |
| Authored Shale AoE | 60 / 60 | 89 / 89 |
| Cinder Bloom | 48 / 48 | 76 / 76 |
| Cinder Bloom, surviving terrain loses Health | 48 / 48 | 76 / 76 |
| Vaeloryx direct push, Health loss | 6 / 6 | 66 / 66 |
| Vaeloryx direct pull, all damage absorbed by Block | 66 / 66 | 99 / 99 |
| Vaeloryx direct pull, zero pool loss | 66 / 66 | 92 / 92 |
| Vaeloryx direct pull, Umbra | 66 / 66 | 101 / 101 |
| Authored Skyhook pull | 66 / 66 | 101 / 101 |

The direct push submits Air on samples 3, 6 and 15 from tile (4,2) to (4,4). The pull submits on 24, 31, 37 and 43 from (4,2) to (4,5). Each uses the existing action phase, including hit stop on the direct push. The target does the same movement in each revision.

Reduced-motion Shale, Cinder Bloom and blocked pull each submit one action frame on both revisions. The Rock still uses FX-14 frame 1. Fire and Air use FX-12 frame 3.

## Files

- `data/shots.json` adds `shot_for_intent.bile_burst`.
- `scripts/combat_board_view.gd` removes the old draws and supplies the Bloomer socket to retained Earth flights.
- `scripts/run_scene.gd` selects the scheduled Air cue, prevents the fallback shot and landing decal, and supplies the terrain hit row for Cinder Bloom.
- `scripts/bile_bloomer_cutout/bloom_fx.gd` and its UID are removed. `scripts/cinder_ooze_cutout/action_fx.gd` retains the distinct melee contact. `scripts/vaeloryx_cutout/wind_feedback.gd` supplies the Air cue and retains the strike trail's `handles` entry point.
- `tools/fx22/` holds the resolver fixtures, native launcher, capture and verifier scripts, two size-specific proof contracts and the GDScript sidecars.

## Verification

| Check | Observed result |
| --- | --- |
| FX-22 resolver matrix and dry run | `FX-22 VERIFY: PASS (255 checks, 0 failures)` |
| FX-20 regression matrix | `FX-20 VERIFY: PASS (172 checks, 0 failures)` |
| Focused actor presentation, enemy surface and dragon suites | `FX-22 VERIFY: PASS (1255 checks, 0 failures)` |
| Dragon committed patterns | `Dragon committed patterns passed.` |
| Legacy Vaeloryx gameplay probe, headless logic only | `VAELORYX GAMEPLAY PROBE: FAIL` on both revisions with the same 33 assertion messages |
| Changed GDScript parse | Seven separate `--check-only` invocations returned exit 0 |
| Cel look | `CEL_STATUS current` |
| Rules text | `PASS: Rules text lint (16 existing hits)` |
| Python default group | `Ran 194 tests in 46.924s` · `FAILED (failures=2)` |

The Python failures are inherited from the baseline. The pin file names `assets/art/effects/defense_heal_casts.png`, which is absent from the baseline tree and worktree. The baseline has no tracked `tools/flt01/fight_probe.gd.uid` or `tools/flt01/renderer_check.gd.uid`. The runner also could not update its cache in the read-only Git directory. None of those paths was edited. The worktree lacked texture imports for the effect atlases. The matching cached artifacts were restored from FX-20 after comparing the source PNG and import sidecar bytes. This changed only the local `.godot` cache.

- [FX-22 resolver matrix](/private/tmp/labyrinth_codex/fx-22/verify.log)
- [FX-20 regression matrix](/private/tmp/labyrinth_codex/fx-22/fx20-complete.log)
- [Focused suites](/private/tmp/labyrinth_codex/fx-22/focused-complete.log)
- [Legacy Vaeloryx logic probe, before](/private/tmp/labyrinth_codex/fx-22/vaeloryx-logic-base.log) and [after](/private/tmp/labyrinth_codex/fx-22/vaeloryx-logic-headless.log)
- [Python default summary](/private/tmp/labyrinth_codex/fx-22/python-default-complete/summary.json)
- [Parse logs](/private/tmp/labyrinth_codex/fx-22/parse)

## TODO_DESIGN placeholders

- `TODO_DESIGN_SHALE_AOE_REPLACEMENT` in `cases.gd` and the AoE take reports. The live Shale Burst's protected empty area mapping provides no existing FX-12 area. Applying a targeted flight to its former radial release would require a design decision about the destination and phase. The targeted Rock route is implemented and exercised separately.

## Chosen defaults

The proof inherits FX-20's seed, 60 Hz MovieWriter clock, 30 Health, 20 Block witnesses and 900-frame take limit. The worktree's standard attack values feed the fixtures. The push and pull use a column of open stone tiles, with the pull target at (4,5) and the dragons at (4,1). The terrain witness starts with seven Health at (5,3). The zero-loss pull sets fixture damage to zero so it can demonstrate the floor row. The fog witness uses Heart-stage visibility. Crops are centered on the projected bounds of the test source and affected tiles. The native runner has a 300-second budget per take.

## Proof for the design owner

The launcher captures a 1920×1080 SubViewport at 100% UI scale with the combat HUD, cel look, and the five requested samples. The standard crops are 640×480. Vaeloryx crops are 960×720. The six default case IDs each produce a before and after strip. The launcher also accepts individual case IDs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-22 && /private/tmp/labyrinth_codex/fx-22/native.sh
```

The windowed outputs are `/private/tmp/labyrinth_codex/fx-22/native/{before,after}/<case>/{strip.png,native-evidence.png,take.json,manifest.json}`. The dry run wrote the corresponding `/private/tmp/labyrinth_codex/fx-22/headless/{before,after}/<case>/take.json` reports and reduced-motion controls under `headless/{reduced-before,reduced}/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-22 && /private/tmp/labyrinth_codex/fx-22/native.sh --dry-run
```

## Open issues

The Shale AoE replacement design, inherited Python and legacy Vaeloryx probe failures, and native renderer inspection remain open. All changes are uncommitted.
