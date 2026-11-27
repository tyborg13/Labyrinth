# fel-15 enemy turn hand-off

The comparison uses `36290dc588e53ecd3a6964f172074d653222cbb9`, the `codex/release` revision merged into the task branch, and the same fel-09 witness on both projects. The 12 fixtures drive production Continue, Pass, and the next accepted hero input. The per-action denominator is the census action count, including movement, reinforcements, and Worldspine pulses. The timer runs from Pass to the existing endpoint.

## Implementation

- Enemy number feedback advances when the last applicable number reaches its own fade start. Normal motion uses `0.64 × 0.48 s` (307.2 ms) and reduced motion uses `0.72 × 0.48 s` (345.6 ms). `FloatingCombatText` exposes the existing fade timings and retains the authored font size for resampling. The existing stagger and fade curves remain the source of the drawn frames.
- `CombatPacing` tracks active numbers by action, tile, and recipient. The shared feedback path and ordinary sampled strikes check the deadline at contact. Specialist clips that submit their own contact frames defer the conflicting number batch at submission, allowing the specialist clip to keep its authored clock.
- Action settle is 0.08 s. The 0.35 s banner lead, 0.25 s action lead, 0.20 s tile cadence, 0.80 action scale and 2.0 hurry multiplier use the established combat clock. Deaths, surfaces and white impact flashes run through completion before the hand-off. The end-of-round drain and hero card feedback play through expiry.
- The census compares the endpoint, final units and their positions, Health, and statuses, the hand, intents, surfaces, and the dispatched steps and geometry. Stacking counts draw submissions that show two live numbers from different actions on the same tile or recipient. A stagger within one action is allowed.

## Headless results

The matched normal-motion receipts are under `output/fel15/headless/release/` and `output/fel15/headless/branch-final/`. Each side writes `timeline.json` and `runner.log`. Fixture 07 also has separate reduced-motion and held-Space receipts. The additional pacing and audio logs are under `output/fel15/tests/`.

| Fixture | Actions | Release ms/action | Branch ms/action | Reduction |
| --- | ---: | ---: | ---: | ---: |
| 01-s0-seed1-0-4_0-t9 | 2 | 2128.1 | 2052.6 | 3.5% |
| 02-s0-seed12-0-1_3-t7 | 6 | 1492.2 | 1342.0 | 10.1% |
| 03-s2-seed8-2-11_-9-t64 | 0 | — | — | — |
| 04-s0-seed8-0--3_2-t5 | 6 | 1612.0 | 1399.1 | 13.2% |
| 05-s2-seed1-2-9_-7-t2 | 5 | 1355.8 | 1132.9 | 16.4% |
| 06-s2-seed1-2-11_-10-t5 | 8 | 1442.6 | 1240.1 | 14.0% |
| 07-s4-seed1-4-19_-19-t4 | 8 | 1550.4 | 1292.6 | 16.6% |
| 08-s1-seed8-1-5_-4-t5 | 1 | 2836.9 | 2460.7 | 13.3% |
| 09-s3-seed12-3-16_0-t15 | 2 | 1886.8 | 1667.5 | 11.6% |
| 10-s3-seed12-3-13_-2-t4 | 2 | 2631.0 | 2430.5 | 7.6% |
| 11-s4-seed12-4-19_-14-t4 | 8 | 1629.9 | 1379.8 | 15.3% |
| 12-s1-seed1-1-7_-3-t3 | 8 | 1293.0 | 1052.5 | 18.6% |

```text
FEL09 PACING PASS fixtures=12 turns=12 actions=56
FEL15 SAME GAME PASS fixtures=12
FEL15 STACKED NUMBERS frames=0
FEL15 MEDIAN FAIL release=1492.2 branch=1292.6 reduction=13.4% target=15%
```

The median across fixtures 02, 04, 05, 06, 07, 11 and 12 improved by 13.4%. The 15% acceptance target remains open. Fixture 05 spends three of its five actions on movement. The fire status turns in fixture 07 still wait for their ground effects and several sampled attacks already run past their numbers’ fade start. Fixture 03 took 1,323.7 ms on release and 1,338.1 ms on the branch across the full turn.

| Fixture 07 variant | Actions | Release ms/action | Branch ms/action | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Reduced motion | 8 | 975.9 | 845.4 | 13.4% |
| Held Space | 8 | 934.9 | 844.6 | 9.6% |

Each variant returned `FEL09 PACING PASS fixtures=1 turns=1 actions=8`, `FEL15 SAME GAME PASS fixtures=1`, and `FEL15 STACKED NUMBERS frames=0`.

### Focused checks

| Check | Observed result |
| --- | --- |
| `combat_pacing_regression_suite.gd`, including `combat_action_pacing_suite.gd` | `FEL15 COMBAT PACING TEST RESULT: PASS (0 failures)` |
| Temporary contact and gain-batch witness | `FEL15 NUMBER CONTACT TEST RESULT: PASS (same tile, moved unit, unrelated unit, gain batch, normal and reduced motion)` |
| `enemy_hurry_test.gd` | `ENEMY HURRY TEST RESULT: PASS` |
| `enemy_hurry_round_probe.gd`, caption hold | `COMBAT FEEL PROBE TEST RESULT: PASS` |
| `enemy_hurry_round_probe.gd`, release comparison | `COMBAT FEEL PROBE TEST RESULT: FAIL`. Exact timeline equality and the one-frame hero hand-off tolerance also failed in the release control. The final branch run reported `normal enemy_1/walk hand-off halves within one frame (0.1500 s vs 0.0500 s)`. An earlier run on the same runtime passed the walk tolerance. The final branch run reported `ENEMY HURRY PRESENTATION normal: 5.917s unheld, 2.983s held`. |
| `combat_feel_probe.gd`, normal round | `COMBAT FEEL PROBE TEST RESULT: FAIL` on both sides. `Enemy phase preserves exact resolver state/RNG at normal` failed on the release snapshot as well. |
| `sfx_sync_pacing.gd` through `sfx_sync_harness.gd`, `fixed_60` | `SFX SYNC HARNESS RESULT: FAIL (1695 observations, 12 failures)`. The Saved Purge assertions for scavenger and campfire account for all 12. The release control at 1.0× returned `SFX SYNC HARNESS RESULT: FAIL (289 observations, 2 failures)` for the same two assertions. |
| `test_rules_text_lint.py` | `PASS: Rules text lint (16 existing hits)` |
| `test_ui_identity_lint.py` | `Ran 25 tests in 8.344s` and `OK` |
| `native.sh --dry-run` | `FEL09 PIXEL DRY RUN PASS threshold=0.1% min_still_ms=150 strip_interval_ms=50` and `FEL15 NATIVE DRY RUN PASS release=36290dc588e53ecd3a6964f172074d653222cbb9 paired=07,11,12 branch_still=01-12 variants=reduced,hurry fps=60` |
| Synthetic Movie Maker-format inputs with different end frames | `FEL15 PAIRED MOVIE PASS output/fel15/pair-check/pair-final.mp4 release_left=1920x1080 branch_right=1920x1080 audio_tracks=2` |

Assertion updates reflect the approved timings:

- `combat_pacing_regression_suite.gd` checks the enemy fade-start duration including stagger, the normal and reduced-motion fade thresholds on the presentation clock, and a 0.08 s settle on the ordinary combat clock.
- `combat_action_pacing_suite.gd` checks one 0.08 s settle for its existing action fixtures.
- `combat_feel_probe.gd` checks a 0.08 s settle in the staged round.

The older probes can inject historical pacing with no-op contact hooks. The release hurry control disables a duplicate input-method stub in the temporary snapshot so the original assertions can run against the matching historical script.

## Native proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-15 && bash tools/fel15/native.sh
```

The script archives the matching release project locally, then uses `visual_probe_runner.py` and the fel-09 visual contract. The output is `output/fel15/native.*/07-release-branch.mp4`, `11-release-branch.mp4`, and `12-release-branch.mp4`. Each side uses a 1920×1080 cel render at 100% UI scale. Pass aligns both sides and the earlier endpoint holds through the end of the other side. The MP4 has a selectable audio track for each side. `summary.log` contains the native still-run and stacking lines. Per-take `visual-proof.json`, `timeline.json`, `continue.png`, and `still.json` are kept alongside the comparison. The windowed command is pending in the implementation sandbox.

## Chosen defaults

- Fixture 07 supplies the reduced-motion and held-hurry comparisons. Space is held through the production viewport input path.
- Native proof uses 60 fps, a 180 s renderer timeout, release on the left, and branch on the right. The encoder uses H.264 CRF 15 and 192 kbps AAC per track. The audio check requires a peak above −90 dBFS in each track.
- The temporary contact check uses tiles `(2, 2)` and `(3, 2)` and exercises +2 Block, +3 Heal, and +1 Stoneskin.

## Design placeholders

None.

## Files changed

- Runtime: `scripts/combat_pacing.gd`, `scripts/floating_combat_text.gd`, `scripts/run_scene.gd`.
- Existing probes and suites: `tests/combat_feel_probe.gd`, `tests/enemy_hurry_round_probe.gd`, `tests/suites/combat_action_pacing_suite.gd`, `tests/suites/combat_pacing_regression_suite.gd`.
- Census: `tools/fel09/census.gd`, `tools/fel09/frame_beats.gd`, `tools/fel09/pacing_probe.gd`, `tools/fel09/timeline.gd`.
- Native comparison and report: `tools/fel15/native.sh`, `tools/fel15/movie.sh`, `tools/fel15/pair.py`, `tools/fel15/compare.py`, `tools/fel15/result.md`.

## Open issues

- The renderer's still-run and frame-stacking checks await the native run. The dry run validates the comparison tools and the pixel threshold.
- `spec/visual_design_system.md` and `spec/combat_feel.md` still describe the prior full-number wait and 0.15 s settle.
