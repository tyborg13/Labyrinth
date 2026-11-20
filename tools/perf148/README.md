# Tharokh controller redraw proof

A is release `e3d3aba7f306de1f6ac289a6ca6d197c2ea90611` routing. B retains
matching unit HUD pieces on the original release canvases. A fading health bar
repaints only when its primitive alpha or other paint inputs change. Its
connector stays on the same canvas. The original contextual badge painter
creates its number tab on draw, including the first draw after a hidden board
is shown. Resolved HP and forecast, status placement, intent ink, fonts, scale
and material state determine which pieces need a new draw.

Actor bodies, scene props, direct terrain HUD, intent halos and callouts use
the release painters and redraw paths for their visible commands. The retained
unit HUD uses untagged primitives, project-owned textures and fonts, and the
same canvas material as release. Ordinary HUD commands bypass the world-art
UV lanes in `combat_art_treatment.gd`. The retained pieces do not record
actor viewport textures or per-draw world material state.

The debug trace enables A with `LABYRINTH_PERF148_BASELINE=1`. Leave the older
perf138 baseline switch off.

The perf138 route selects and moves through public joypad input, commits the
move on A, and completes an enemy round on Y. It uses the perf134 archived
Tharokh and ordinary combat states, settles the input modality, and validates
the route before comparing timing. The timing report sums exclusive board
`_draw` callback time on the input frame in headless runs and on the first
rendered frame following input in native runs. Each take records that frame
explicitly and rejects absent confirm timings. It also contains the following
frame, draw item paths and individual costs. Stage submission time
is a separate measurement. Attribution mode adds dirty call sites and painter
times. It does extra work and is excluded from the timing gate.

The A/B proof checks that move destinations, end turns, and input witnesses
match. The paint receipts compare routed HUD operations and tooltip regions,
ordered terrain prop commands and tooltip regions, and body placement at
the settled A and Y states. Perf134 separately verifies 14 state
receipts and, on a native renderer, compares each full viewport pixel.

## Headless

Run from the task worktree. Use fresh output directories.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148
fixtures=/private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var
python3 tools/perf148/measure.py --fixtures "$fixtures" --output /private/tmp/labyrinth_codex/perf-148/headless-pairs
python3 tools/perf148/measure.py --inputs-only --load-workers 0 --fixtures "$fixtures" --output /private/tmp/labyrinth_codex/perf-148/headless-attribution
python3 tools/perf148/strict.py --fixtures "$fixtures" --output /private/tmp/labyrinth_codex/perf-148/headless-strict
for baseline in 1 0; do
  env LABYRINTH_PERF148_BASELINE=$baseline LABYRINTH_BOARD_REDRAW_BASELINE=0 LABYRINTH_BOARD_REDRAW_TRACE=inputs LABYRINTH_CEL_LOOK=all SteamDeck=0 \
    python3 tools/godot_task_runner.py --task-id perf-148 --stream -- godot --headless --fixed-fps 60 --path . --script tools/perf148/review_repro.gd
done
```

The timing order is ABBAAB with four continuous background load processes.
There is no host-idle check. A and Y are also reported individually. The gate
requires a 50% reduction in the pooled Tharokh median and p95 and no increase
in either statistic in the ordinary fight.

The archive replay resumes each recorded Tharokh decision with its original
hand, terrain, enemy state and policy plan. It uses the census controller route
and the normal combat input handlers. The perf134 fixture provides the outer
checkpoint and 1920×1080 viewport. Its seed and room map are fixture data.
In B's inputs trace, the replay also forces stable retained health, intent and
status pieces to repaint after each decision's measured input window. It compares
the new draw receipts with the retained versions and requires coverage of each
piece type.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148
fixtures=/private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var
census=/private/tmp/labyrinth_codex/census-03/native-v7/runs/v4-demo-demo-7-normal-warm-on-1795110850531097000
for baseline in 1 0; do
  env LABYRINTH_PERF148_BASELINE=$baseline LABYRINTH_BOARD_REDRAW_TRACE=inputs LABYRINTH_CEL_LOOK=all SteamDeck=0 \
    python3 tools/godot_task_runner.py --task-id perf-148 --stream -- godot --headless --fixed-fps 60 --path . --script tools/perf134/probe.gd -- \
    --headless-check --output="/private/tmp/labyrinth_codex/perf-148/archive-$baseline" --fixtures="$fixtures" \
    --board-redraw-route=res://tools/perf148/archived_route.gd --census-archive="$census"
done
```

## Native proof for the design owner

The strict command runs the perf134 proof contract through
`tools/visual_probe_runner.py` at 1920×1080 and 100% UI scale. It writes 14 PNGs
and 14 state receipts per side under `captures/A` and `captures/B`, with
one unmasked diff JSON per state and `captures/summary.json`. A mismatch is
reported after the complete state list has run. Native timing and attribution use the same
fixture and the public controller route.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148 && python3 tools/perf148/strict.py --native --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output /private/tmp/labyrinth_codex/perf-148/native-strict
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148 && python3 tools/perf148/measure.py --native --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output /private/tmp/labyrinth_codex/perf-148/native-pairs
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148 && python3 tools/perf148/measure.py --native --inputs-only --load-workers 0 --fixtures /private/tmp/labyrinth_codex/perf-138/native-r1/fixtures-v3.var --output /private/tmp/labyrinth_codex/perf-148/native-attribution
```

This single demo take keeps the source census settings (seed 7, Steam Deck,
1280×800 presentation, 115% UI scale, normal combat speed, 1200-second cap).
It traces both A and Y presses while Tharokh is on the combat board and writes
`tharokh-confirms.json` next to the original census logs. This is the replay
settings from `v4-demo-demo-7-normal-warm-on-1795110850531097000`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-148 && env LABYRINTH_BOARD_REDRAW_TRACE=inputs LABYRINTH_CEL_LOOK=all SteamDeck=1 LABYRINTH_PROBE_WINDOW=1 LABYRINTH_DEMO=1 python3 tools/godot_task_runner.py --task-id perf-148 --timeout 1290 --stream -- godot --path . --resolution 1280x800 --windowed --position 24,24 --script tools/perf148/census_trace.gd -- --output=/private/tmp/labyrinth_codex/perf-148/native-census --driver=demo --seed=7 --seconds=1200
```
