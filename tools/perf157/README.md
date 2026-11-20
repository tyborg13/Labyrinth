# perf-157 targeting redraw proof

The perf-148 pair tools accept `--perf157` to compare the release targeting
routes with the selective routes in one checkout. Both sides use release
HUD retention, the same fixture, and the same input handlers. The timing
run interleaves ABBAAB. For A, it measures the first rendered frame. For Y,
it measures the second, when the deferred pass presentation reaches the board.

The inputs run adds aim without a selected card, select, cancel, reselect,
retarget, confirm and pass in both rooms. `inputs.json` lists scene tile
coordinates by depth pass and body actor keys, draw counts within the two-frame
transition window, changed paint receipts, and scene tiles with live clocks.
The raw samples in each take's `summary.json` have draw sites and both receipts.
The receipts cover routed depth paint, cached prop commands, resolved body
geometry, textures, compass descriptors, and outline and aim modulation.
Native comparison covers renderer-managed pixels such as live body textures
and shader effects.

## Headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-157
fixtures=/private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var
python3 tools/perf148/measure.py --perf157 --inputs-only --load-workers 0 --fixtures "$fixtures" --output output/perf-157/headless-attribution
python3 tools/perf148/measure.py --perf157 --fixtures "$fixtures" --output output/perf-157/headless-pairs
python3 tools/perf148/strict.py --perf157 --fixtures "$fixtures" --output output/perf-157/headless-strict
```

## Native proof

The strict run uses the perf134 proof contract through the visual probe runner.
It captures the 14 states at 1920×1080 and 100% UI scale, then compares all
viewport pixels. The aim-exit run compares the first rendered frame after
cancel and confirm, in both rooms. Those frames check that the existing body
canvases still paint when the board returns from a forecast that omitted its
room coordinate. The same-room transition keeps the existing CanvasItem and
resets its tint to the value the release recreation would use. It introduces
no new draw-command cache. Use fresh output directories for each run.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-157 && python3 tools/perf148/strict.py --perf157 --native --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output output/perf-157/native-strict
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-157 && python3 tools/perf148/strict.py --perf157 --native-confirm --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output output/perf-157/native-confirm
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-157 && python3 tools/perf148/measure.py --perf157 --native --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output output/perf-157/native-pairs
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-157 && python3 tools/perf148/measure.py --perf157 --native --inputs-only --load-workers 0 --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output output/perf-157/native-attribution
```
