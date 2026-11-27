# fel-01 round 1

Packaged 12 real combat checkpoints from the approved 9,999-Health diagnostic campaign. The cohort includes eight dragon fights, two normal fights, one objective fight and one Guardian fight. The three normal-Health samples remain in `tools/fel01/samples/`. [Full census and fixture index](census.md)

## Selection and provenance

The campaign covered all four fight kinds and all six sections. The cohort has three states each from Sections I–III, one from Section IV, and two from Section V. Section VI's highest score was 13 and the lowest selected score was 18. The combined selected score was 352 across 12 distinct fights.

The original diagnostic scores determined selection. Tied totals favored the largest visible enemy sprite rectangles in screen pixels, then the most visible pillar tiles. `candidate_probe.gd` measured both from the production board after Continue and checked the same capture phases as the native probe. All 72 retained states passed the resume comparison. Three states had no playable targeted card at the recorded turn and were ineligible for the three-phase cohort. Those were seed 8 fights `0-1_1` and `0-2_2`, and seed 12 fight `3-15_-3`. [Seed 1 screen](/private/tmp/labyrinth_codex/fel01-round1-screen-1.log) · [Seed 8 screen](/private/tmp/labyrinth_codex/fel01-round1-screen-2.log) · [Seed 12 screen](/private/tmp/labyrinth_codex/fel01-round1-screen-3.log)

Each `score.json` records campaign ID `fel01-round0-diagnostic-9999`, the source seed directory, and the two measured tie-break values. The package audit compared each save, profile and witness byte for byte with its source. [Census packager log](/private/tmp/labyrinth_codex/fel01-round1-census.log) · [Package audit](/private/tmp/labyrinth_codex/fel01-round1-package-audit.log)

| Seed | Retained / eligible | Campaign endpoint | Wall seconds |
|---:|---:|---|---:|
| 1 | 25 / 25 | Fight limit after 2,618 decisions in Section V, combat room (19, −12) | 1,034.227 |
| 8 | 14 / 12 | Fight limit after 1,506 decisions in Section III, Umbral Snare room (11, −9) | 502.646 |
| 12 | 33 / 32 | Victory after 2,106 decisions in Section VI, dragon room (24, 0) | 884.450 |

## Headless proof

```text
FEL01 CANDIDATE SCREEN retained=69 skipped=3
FEL01 CENSUS PASS seeds=3 fights=72 selected=12
FEL01 PACKAGE PASS states=12 unique_fights=12 max_per_section=3 source_matches=12
FEL01 DRY RUN PASS states=12
```

The dry run confirmed rest, settled hover fade and active targeting over the recorded tile for all 12 states. Six tiles were outside the selected card's legal target set. [Dry-run log](/private/tmp/labyrinth_codex/fel01-round1-dry.log)

The separate witness-only run returned these lines. [Witness log](/private/tmp/labyrinth_codex/fel01-round1-witness.log)

```text
FEL01 RESUME PASS 01-s1-seed1-1-8_0-t13 boundary units positions surfaces intents hand
FEL01 RESUME PASS 02-s1-seed8-1-8_0-t12 boundary units positions surfaces intents hand
FEL01 RESUME PASS 03-s0-seed12-0-4_0-t12 boundary units positions surfaces intents hand
FEL01 RESUME PASS 04-s0-seed1-0-4_0-t9 boundary units positions surfaces intents hand
FEL01 RESUME PASS 05-s2-seed1-2-12_0-t29 boundary units positions surfaces intents hand
FEL01 RESUME PASS 06-s3-seed12-3-16_0-t15 boundary units positions surfaces intents hand
FEL01 RESUME PASS 07-s0-seed8-0-4_0-t26 boundary units positions surfaces intents hand
FEL01 RESUME PASS 08-s1-seed12-1-8_0-t7 boundary units positions surfaces intents hand
FEL01 RESUME PASS 09-s2-seed8-2-11_-9-t64 boundary units positions surfaces intents hand
FEL01 RESUME PASS 10-s2-seed8-2-10_-2-t16 boundary units positions surfaces intents hand
FEL01 RESUME PASS 11-s4-seed12-4-17_-11-t5 boundary units positions surfaces intents hand
FEL01 RESUME PASS 12-s4-seed1-4-19_-19-t4 boundary units positions surfaces intents hand
FEL01 WITNESS PASS states=12
```

The default Python group returned `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.899s`, and `OK`. It included `PASS: Rules text lint (16 existing hits)`. The runner's Git timing-cache write reported `Operation not permitted` after the tests. Both Godot proof runs also printed the macOS system CA startup error and then passed. [Python default log](/private/tmp/labyrinth_codex/fel01-round1-python-default.log)

The isolated rank check returned `FEL01 RANK PASS score first, enemy sprite area second, pillar count third`. The diff check was clean.

## Proof for the design owner

Run in the native macOS session:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-01 && tools/fel01/native.sh
```

The director's 90-frame plus 2-second native wait after Continue is preserved. The runner writes PNGs, contact sheets and a proof manifest under a fresh `tools/fel01/captures/native.*/` directory. The round-1 native captures remain pending.

All round-1 changes are uncommitted under `tools/fel01/`.
