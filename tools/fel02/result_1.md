# fel-02 round 1

The existing x-ray pass now uses a 2×2 checker for hidden-unit fill. It anchors the checker to the board's projected tile origin and uses the existing pixel-sheet fit from the FX-13 Block shield. Each on cell uses the team colour at the `UNIT_FILL_ALPHA` value of 0.75, multiplied by the live silhouette, rim fade and occluder reveal alpha. Off cells contribute zero fill. The rest/hover opacity, rim thresholds, layer order and visibility rules follow the approved fel-02 implementation.

The fill material gets the fitted cell size in framebuffer pixels and converts it back to board coordinates. The shader locates each fragment in board space before applying checker parity. Sprite motion leaves the grid phase fixed relative to the board, and a camera pan moves the grid with the board. The headless proof checks the shader wiring, live fill bindings against the actual Block player, and a repeating 2×2 pattern before and after a production pan.

## Fixture 01 sword

The Training Sword already renders inside the hero's cutout viewport with the rest of the equipped gear. The fill shader samples that same viewport texture. The coverage gate separately uses the gear-aware rest texture. The focused probe projected the actual Training Sword artwork into board space and counted 2,147 opaque sword texels behind the front pillar at tile `(4, 6)`. The hero's full resting silhouette had 23.7192% coverage, below the 30% threshold to start an x-ray, so the hero had no ally fill in this fixture. The weapon requires no separate mask.

```text
FEL02 HERO GEAR training_sword hidden_sword_texels=2147 rest_coverage=0.237192 xray=off
```

## Proof run

| Check | Observed result |
|---|---|
| `tools/fel02/witness.gd` | `FEL02 WITNESS PASS states=3 solid_sources=29 fills=7 hovered_sconces=3 failures=0` |
| `tools/fel02/focused.gd` | `FEL02 FOCUSED PASS checks=122 failures=0` |
| `tools/rd02/focused_checks.gd` | `RD02 FOCUSED: PASS (5472 checks, 0 failures)` |
| `tools/fx13/verify.gd` | `FX-13 VERIFY: 96 checks, 0 failures` and `TEST RESULT: PASS` |
| `tests/snare_ui_test.gd` | `Snare UI/fixture suite: 0 failures` |
| `tools/fel02/native.sh --samples --dry-run` | `FEL01 DRY RUN PASS states=3` |
| Python default group, including rules-text lint | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.647s`, `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.332s`, `OK` |
| `bash -n tools/fel02/native.sh` and `git diff --check` | Exit 0 |

[Witness log](/private/tmp/labyrinth_codex/fel02-round1-witness.log) · [Focused log](/private/tmp/labyrinth_codex/fel02-round1-focused.log) · [FX-13 log](/private/tmp/labyrinth_codex/fel02-round1-fx13.log) · [Python log](/private/tmp/labyrinth_codex/fel02-round1-python.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-02 && tools/fel02/native.sh --samples
```

The command writes a fresh `tools/fel02/captures/native.*/` directory with the 1920×1080 rest, hover and targeting PNGs at 100% UI scale, contact sheets and the proof manifest. The prior flat-fill reference is `tools/fel02/captures/native.2em0r8/`. GPU playback and the round 1 PNGs are pending the windowed run.

## Handoff

- Round 1 changes are uncommitted in `scripts/board_occlusion_silhouettes.gd`, `scripts/board_occlusion_silhouettes.gdshader`, `tools/fel02/witness.gd`, `tools/fel02/focused.gd` and this report.
- TODO_DESIGN placeholders are empty. The test requests a 17×11 board-coordinate pan. The capture configuration uses the existing fel-01 fixture and timing settings.
- The Godot macOS certificate lookup logged the same startup error as round 0. The Python suite passed and the external Git timing cache write returned `Operation not permitted`.
