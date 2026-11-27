# fel-02 implementation and proof

The implementation is uncommitted in `codex/fel-02`. The baseline witness ran before the production edits, when `HEAD` and `codex/fel-01` both resolved to `e5451a38ebdcc99ff93f64ca5b8eec1ab0d29164`. Both runs resumed the same three fel-01 saves through the production Continue path.

## Acceptance criteria

1. Pillars, interior walls, doors and standing terrain draw at full opacity at rest. Removed `FOREGROUND_OBSTRUCTION_TINT`, `FOREGROUND_ACTOR_OBSTRUCTION_TINT` and `PILLAR_ACTOR_OBSTRUCTION_TINT` and retired the cross-tile redraws driven by those overlap tints.
2. The existing x-ray shader samples each unit's live silhouette and the opaque portions of standing objects later in painter order. It composites flat `Palette.DANGER` or `Palette.ALLY` fill under the rim. A unit can still trigger the existing rim hysteresis for another unit, and contributes zero fill pixels. Hidden, burrowed and preview-echo units are absent from the rim sources. Illusions retain their existing rim behavior and receive no fill. The shared prop mask atlas updates with source geometry and the shader handles the intersection without new per-frame CPU work at rest.
3. Only loot and traps qualify for pale object rims. Standing props still contribute to unit occlusion.
4. The sconce, animated flame, halo, floor light and embers all use the pillar shaft's reveal alpha as their opacity multiplier. All three saved hover cases settle at 0.30 for both shaft and sconce.
5. The existing reveal targets, timing, pillar cap and foot bands, unit-on-unit rims, and other board and HUD passes stay in place. The mask uses the blocker reveal alpha so the fill fades as the object fades. The art, cel settings, inputs, saves and analytics were untouched.
6. `UNIT_FILL_ALPHA` holds 0.38 beside `UNIT_ALPHA`. The shader takes this value from the rim material.

## Proof run

```text
FEL02 WITNESS FAIL states=3 solid_sources=29 fills=7 hovered_sconces=3 failures=25
FEL02 WITNESS PASS states=3 solid_sources=29 fills=7 hovered_sconces=3 failures=0
```

[Base witness log](/private/tmp/labyrinth_codex/fel02-base-witness.log) · [Working tree witness log](/private/tmp/labyrinth_codex/fel02-final-witness.log)

| Check | Observed result |
|---|---|
| `tools/fel02/focused.gd`, retained prop paint, unit-only x-ray, fill masks and fade bindings | `FEL02 FOCUSED PASS checks=77 failures=0` |
| `tools/rd02/focused_checks.gd`, layout, actor draw, cutout and intent continuity | `RD02 FOCUSED: PASS (5472 checks, 0 failures)` |
| `tests/snare_ui_test.gd`, door UI and fixture | `Snare UI/fixture suite: 0 failures` |
| `tools/fel02/native.sh --samples --dry-run`, rest, hover and targeting on all three saves | `FEL01 DRY RUN PASS states=3` |
| `tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/fel02-python-default`, includes rules-text lint | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 34.684s` · `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.314s` · `OK` |
| `bash -n tools/fel02/native.sh`, capture ignore rule and `git diff --check` | Exit 0 for each |

The focused proof uses production paint callbacks to record headless prop modulation. It also checks that the existing unit-on-unit rim can turn on without a fill mask, that the atlas preserves transparent pixels, that the procedural stone bodies provide their own masks, that illusions are excluded, and that fill uniforms track both the rim multiplier and the settled hover and exit states. [Focused log](/private/tmp/labyrinth_codex/fel02-focused.log) · [Capture dry-run log](/private/tmp/labyrinth_codex/fel02-native-dry.log) · [Python default log](/private/tmp/labyrinth_codex/fel02-python-default.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-02 && tools/fel02/native.sh --samples
```

The windowed runner writes to a fresh gitignored `tools/fel02/captures/native.*/` directory. Each fixture gets `*-rest.png`, `*-hover.png` and `*-targeting.png` at 1920×1080 and 100% UI scale, plus a 5760×1080 `*-contact.png`. The runner also writes `visual-proof.json` and `runner.log` alongside the images. The headless dry run exercised all three input phases without producing PNGs.

## TODO_DESIGN

None.

## Chosen defaults

- The extra focused check reuses the first fel-01 save. Its synthetic overlap uses an 8×4 mask with an opaque left half and transparent right half.
- The capture runner uses the inherited fel-01 input, camera, 0.35-second settle with two extra frames, and 180-second timeout. It uses the production cel look.

## Open issues

- Native shader rendering and PNG inspection are pending. Windowed runs were unavailable in this sandbox.
- The optional `tests/combat_board_projection_test.gd` returned `COMBAT BOARD PROJECTION TEST: FAIL (1 errors)` after the draw observer failed to compile. Its signatures for `_draw_contact_pool` and `_draw_iso_ground_shadow` already disagree with the parent on `codex/fel-01`. [Projection log](/private/tmp/labyrinth_codex/fel02-projection.log)
- Godot printed the macOS certificate lookup error at startup and continued through the reported passing checks. The Python runner passed and reported `Operation not permitted` when updating its external Git timing cache. The Snare test also logged an ObjectDB leak warning at exit.
