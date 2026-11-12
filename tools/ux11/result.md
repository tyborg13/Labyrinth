# ux-11 implementation result

Implemented in `codex/ux-11`, based on release `c9121c833`. All changes remain uncommitted. Risk tier: standard, demo-critical. No Git writes, publication, peer review, reviewer agents, task-queue changes, windowed runs or native play sessions were performed.

## Files changed

- `scripts/run_scene.gd`: routes targeting tuck and lift suppression through the output decision; restores the pre-ux-10 desktop pointer poses; uses the frozen measured desktop hand top for board fit.
- `scripts/board_hud_budget.gd`: caches the compact decision per encounter/output, includes physical output size in invalidation, and measures the full desktop row synchronously while preserving the live tuck state.
- `tests/suites/card_drag_play_suite.gd`: adapts four existing ux-10 pointer tuck assertions to the output-specific contract. Existing compact/controller assertions remain in place; no new permanent test module was added.
- `tools/ux11/capture.gd` and its `.uid`: exact-size SubViewport real-scene capture and headless checks.
- `tools/ux11/focused.gd` and its `.uid`: invokes the existing affected test domains without executing the full suite.
- `tools/ux11/proof.py`: creates an archived release snapshot without Git writes, copies the existing approved cel variants, uses the verified combat fixture for both builds, runs the required runners, and compares every compact measurement exactly.
- `tools/ux11/proof_contract.json`: requires all nine size/state captures per build.
- `tools/ux11/result.md`: this report.

## Numbered requirements / acceptance criteria

1. **One output decision:** `_compact_board_layout()` delegates to the HUD budget's memoized `compact_layout()`. It uses precisely `UiTypography.is_handheld_output(scene) or InputRouter.platform_is_steam_deck()`. Encounter/output changes invalidate the decision; input-device changes do not. Headless checks cover false at 1920x1080 and 1920x1200, true at 1280x800, and resizing in both directions.
2. **Compact unchanged:** the collapsed-strip calculation, targeting tuck, and lift suppression remain intact. The real release and candidate scenes report exactly equal values in every 1280x800 state. The existing resting-hand overlap at compact idle is retained, as required.
3. **Desktop pointer:** card aim, drag aim, hero movement, surface aim and rotation retain the 324px desktop row and zero tuck margin. Clicked/dragged card emphasis uses the pre-ux-10 behavior from `git show 7190f8c62^:scripts/run_scene.gd`. Explicit pointer tuck and its targeting lift suppression are retained. Existing drag/click targeting tests were adapted and passed.
4. **Desktop fit:** the bottom is the measured full row top minus the existing 8px `HAND_BOTTOM_GAP`. Measurement temporarily sorts the full desktop row and restores the live layout before drawing, so starting with controller focus or an explicit tuck reserves the same space. The board solver/drawing, HUD exclusions/12px gap, maximum width, horizontal centering and vertical placement are unchanged. Both desktop sizes clear the hand in all three measured states.
5. **Desktop controller:** existing controller focus/tuck logic is retained. The headless capture checks both the frozen fit and the actual board tile width/origin across device handoff, plus re-capture while already tucked.
6. **Proof:** the capture script loads the verified `inspection_fixture.py --scenario combat` save into the real run scene. It uses exact-size SubViewports for all three sizes, 100% UI scale, and the existing cel look. The harness now rejects cel fallback and emits nine PNGs plus measurements per build in windowed mode. Headless proof is complete; renderer capture and visual inspection are pending with the design owner because this sandbox has no window-server access.

## Tests and probes

All commands ran from `/Users/borgerding/workspace/Labyrinth.worktrees/ux-11`.

| Check | Exact observed result | Evidence |
|---|---|---|
| Existing hand-layout, drag/click targeting, controller input/hand-focus, board-layout/framing domains via `tools/ux11/focused.gd` | `UX11 FOCUSED ASSERTIONS: 1851` / `TEST RESULT: PASS` (exit 0) | `/private/tmp/labyrinth_codex/ux-11-focused-final.log` |
| Headless release/candidate comparison with approved cel variants | `UX11 HEADLESS RESULT: PASS` for release and candidate; `UX11 COMPACT COMPARISON: PASS (all reported values exactly equal release in all three 1280x800 states)` (exit 0) | `/private/tmp/labyrinth_codex/ux-11-proof-headless-cel.log` |
| Python default group | `Ran 189 tests in 36.195s` / `OK` (exit 0; default group only, 20 modules) | `/private/tmp/labyrinth_codex/ux-11-python-default-final.log` and `python-default-final/summary.json` |
| UI identity lint | `Ran 25 tests in 6.095s` / `OK` (exit 0) | `/private/tmp/labyrinth_codex/ux-11-ui-lint-final.log` |
| Combat fixture generation and verification | `Inspection fixture verified.` / `INSPECTION_FIXTURE_VERIFIED` with `"ok":true` | `/private/tmp/labyrinth_codex/ux-11/inspection-fixture.json` and `fixture-headless.log` |
| Output-folder guard | Completed, exit 0; existing required output subtrees retained | `python3 tools/output_gdignore.py` |
| Python proof syntax | `UX11 Python syntax: PASS` | In-memory compilation (no files written outside the worktree) |
| Whitespace | `git diff --check`, exit 0 | No diagnostics |

Focused Godot command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && python3 tools/godot_task_runner.py --task-id ux-11 --stream -- godot --headless --path . --script tools/ux11/focused.gd
```

Headless comparison command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && python3 tools/ux11/proof.py --headless
```

Python and lint commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && python3 tools/run_python_suite.py --shards 4 --changed-since c9121c833 --output-dir /private/tmp/labyrinth_codex/ux-11/python-default-final
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && python3 tests/test_ui_identity_lint.py
```

Additional proof-tool checks passed: `UX11 COMPARISON HARNESS: PASS (exact equality accepted; numeric drift rejected)`, `UX11 RELEASE SOURCE PROVENANCE: PASS (owned runtime sources match c9121c833)`, and `UX11 PROOF CONTRACT: PASS (three sizes and nine named states)`. These used a per-test temporary directory and did not add permanent tests.

No full Python or Godot suites were run. The Python runner audits the full module/resource inventory before selecting the default group; no new Python test module requires a resource-table entry.

## Measurements

These are **headless geometry measurements**, not renderer captures. Values are retained at the precision Godot emitted. “Visible cards” counts visible card bounds intersecting the viewport. “Drawn” bounds come from the production `rendered_visual_rects(false)` (floor/props/bodies, excluding unit HUD labels), transformed into viewport coordinates. Renderer measurements will be written separately by the owner command below.

| Build | Size | State | Hand top y | Visible cards | Tile width | Fit rect (x,y,w,h) | Drawn top y | Drawn bottom y | Bound below hand |
|---|---|---|---:|---:|---:|---|---:|---:|---|
| release | 1920x1080 | idle | 746.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1014.68444824219] | 182.439865112305 | 882.382202148438 | True |
| release | 1920x1080 | dull_bolt_aim | 974.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1014.68444824219] | 182.439865112305 | 882.382202148438 | False |
| release | 1920x1080 | hero_movement | 974.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1014.68444824219] | 182.439865112305 | 882.382202148438 | False |
| release | 1920x1200 | idle | 866.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1134.68444824219] | 242.439865112305 | 942.382202148438 | True |
| release | 1920x1200 | dull_bolt_aim | 1094.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1134.68444824219] | 242.439865112305 | 942.382202148438 | False |
| release | 1920x1200 | hero_movement | 1094.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 1134.68444824219] | 242.439865112305 | 942.382202148438 | False |
| release | 1280x800 | idle | 466.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | True |
| release | 1280x800 | dull_bolt_aim | 694.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | False |
| release | 1280x800 | hero_movement | 694.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | False |
| candidate | 1920x1080 | idle | 746.0 | 5 | 163.934112548828 | [0.0, 0.0, 1920.0, 738.0] | 81.6014862060547 | 705.212524414062 | False |
| candidate | 1920x1080 | dull_bolt_aim | 746.0 | 5 | 163.934112548828 | [0.0, 0.0, 1920.0, 738.0] | 81.6014862060547 | 705.212524414062 | False |
| candidate | 1920x1080 | hero_movement | 746.0 | 5 | 163.934112548828 | [0.0, 0.0, 1920.0, 738.0] | 81.6014862060547 | 705.212524414062 | False |
| candidate | 1920x1200 | idle | 866.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 858.0] | 104.097640991211 | 804.0400390625 | False |
| candidate | 1920x1200 | dull_bolt_aim | 866.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 858.0] | 104.097640991211 | 804.0400390625 | False |
| candidate | 1920x1200 | hero_movement | 866.0 | 5 | 184.0 | [0.0, 0.0, 1920.0, 858.0] | 104.097640991211 | 804.0400390625 | False |
| candidate | 1280x800 | idle | 466.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | True |
| candidate | 1280x800 | dull_bolt_aim | 694.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | False |
| candidate | 1280x800 | hero_movement | 694.0 | 5 | 112.339706420898 | [0.0, 0.0, 1280.0, 734.684448242188] | 176.375396728516 | 603.719543457031 | False |

UX11 COMPACT COMPARISON: PASS (all reported values exactly equal release in all three 1280x800 states)

## Proof for the design owner

Run this exact windowed command from the task worktree. It performs both release and candidate runs through `tools/visual_probe_runner.py`, with cel look enabled, the three exact output sizes, and the nine-image proof contract. Its 120-second capture budget covers nine renders plus real scene/hand settling. No windowed run has been attempted in the implementation sandbox.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && LABYRINTH_CEL_LOOK=all python3 tools/ux11/proof.py --windowed
```

The wrapper invokes this exact headless fixture command first (do not add `--launch`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-11 && python3 tools/inspection_fixture.py --task-id ux-11 --run-id ux-11-proof-fixture --scenario combat --seed 83 --hand dull_bolt,quick_stab,brace,patch_up,guarded_step --player-position 2:4 --enemy-types harrier --enemy-positions 4:4 --manifest /private/tmp/labyrinth_codex/ux-11/inspection-fixture.json
```

Outputs:

- Release PNGs: `/private/tmp/labyrinth_codex/ux-11/release-windowed/{1920x1080,1920x1200,1280x800}_{idle,dull_bolt_aim,hero_movement}.png`.
- Candidate PNGs: the same names under `/private/tmp/labyrinth_codex/ux-11/candidate-windowed/`.
- Each build's `measurements.json` lives beside its PNGs.
- Validated renderer manifests: `/private/tmp/labyrinth_codex/ux-11/{release,candidate}-renderer.json`.
- Full 18-row numbers table: `/private/tmp/labyrinth_codex/ux-11/comparison-windowed.md`.
- Required terminal results: `UX11 CAPTURE RESULT: PASS` for each build, then `UX11 COMPACT COMPARISON: PASS (all reported values exactly equal release in all three 1280x800 states)`.

Outputs must be fresh. If repeating, move the prior `*-windowed` directories and `*-renderer.json` manifests aside first, or choose a fresh `--output-dir`. The release snapshot is a disposable output, not a Git checkout; the harness reuses it at the fixed release hash. All original game assets and design-owned files remain untouched.

## TODO_DESIGN placeholders

None. The brief supplies all player-visible decisions needed for this unit.

## Chosen defaults

Only proof/test settings were chosen:

- Combat fixture: seed 83; five-card hand `dull_bolt,quick_stab,brace,patch_up,guarded_step`; hero tile `(2,4)`; one `harrier` at `(4,4)`. These are named `FIXTURE_*` fields in `proof.py`.
- Probe readiness: `SETTLE_SECONDS = 0.5`, `SETTLE_FRAME_LIMIT = 240`.
- Probe timeout: `CAPTURE_TIMEOUT_SECONDS = 120`.
- The pre-battle fixture pattern's 4x 2D MSAA and separate World2D; forced pointer input/Xbox family for deterministic fixture setup and Xbox controller for handoff checks.
- Task-local output/storage paths under the supplied `/private/tmp/labyrinth_codex/ux-11/` and runner-isolated `user://` namespaces; focused-domain root size 1920x1080.

No player-visible tuning, wording, assets, colours, fonts, audio or rules were chosen or changed.

## Open issues and execution notes

- Renderer captures and visual inspection remain pending with the design owner, as explicitly assigned. No screenshot exists yet; the paths above are the planned capture outputs.
- Commit, peer review, fixture handoff/publication and full integration suites remain with the design owner under the supplied workflow split.
- Headless Godot emits the existing macOS certificate diagnostic `ERROR: Condition "ret != noErr" is true. Returning: ""`; the focused suite also emits existing raw-image export warnings from its arrow asset checks. The observed focused runs exited 0 with `TEST RESULT: PASS`; no failing assertion was removed or weakened outside the prescribed tuck changes.
- The default Python run cannot update its optional Git timing cache because Git metadata is read-only; suite results remain available in the output directory.
- The first `python3 -m py_compile tools/ux11/proof.py` attempt was blocked while Python tried to create its macOS bytecode cache outside the writable roots. In-memory compilation passed instead.
- Initial archived-release headless runs warned about absent ignored cel assets. The final harness copies the approved existing cel cache and asserts that no fallback occurred. No art was generated.
