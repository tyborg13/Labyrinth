# Main menu startup proof

The quick census recorded a 358.310 ms native draw interval on background QoS and 85.718 ms on normal QoS. The slow frame included 310.227 ms between process and pre-draw and 47.909 ms between pre- and post-draw. Both profiles recorded five canvas pipeline compilations in the loading row. Those counts are correlated with the menu reveal and belong to perf-165. The sampled button and marker loads totaled about 28 ms on background QoS. The preceding startup row had a 184.986 ms interval and a resource-count increase of 44. Its overlapping load spans included the dragon art and Maker's Seal.

The existing entry path loads the seal and applies preferences on the main thread, requests the menu's PackedScene on Godot's loader, then creates the scene and builds its controls. The hidden Settings panel has its own ready callback. The menu loads progression and the resumable checkpoint, applies its theme overrides and measures title text. The loader and text server handle resource decoding and glyph rasterization. Steam initializes in its autoload, before the splash scene. It is disabled in the census and in matched takes.

The candidate constructs the title in slices while the seal covers it. Godot receives the same asset types and texture import policies from the existing loaders. Main-thread texture publication, hidden control construction and scene instantiation are atomic jobs. First-use glyph bitmap jobs can finish across the reveal. The handoff reads current settings, progression and checkpoint data. If a window or display preference changes during staging, the packed menu runs its normal scene setup at the reveal viewport. This gives all controls, including the title and Chronicle prompts and Settings, the same sizing order as a fresh menu. The prepared assets remain available on this path. Native canvas pipeline creation and any cache misses still due at first draw remain in the measured interval.

## Design-owner commands

The baseline should be the imported release worktree at revision `dea2395c5ed3346f4f5a9897ff46ceef57b3592e`. Keep both windows unobscured, keep other Godot sessions idle, and use unused output directories. Keep the timing run foreground. The visual runner returns desktop focus to the previous app, so leave the capture window visible and the pointer off its controls.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-167 && python3 tools/perf167/native.py timing --baseline ../release --output /private/tmp/labyrinth_codex/perf-167/native-timing
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-167 && python3 tools/perf167/native.py pixels --baseline ../release --output /private/tmp/labyrinth_codex/perf-167/native-pixels
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-167 && python3 tools/perf167/native.py trace --baseline ../release --output /private/tmp/labyrinth_codex/perf-167/native-trace
```

The timing driver runs five alternating A/B and B/A rounds for each QoS. Every side gets a fresh isolated Godot home and immediately repeats in that home. Imports are already present. OS file caches and driver-global caches are shared. The driver records draw intervals, nearest-rank tails, threshold misses, phase timestamps and canvas compilation counts. It disables the later idle run-scene request after observing menu readiness so that the tail still measures startup. The slow comparison gates on at least 50% lower worst-case startup interval and a maximum of 100 ms, separately for cold and warm. Normal QoS compares worst intervals for the same cache cohorts. Phase timestamp deltas use the paired median with a one-frame tolerance at 60 Hz. Existing headless input tests check authored fade durations and exercise pointer, keyboard and controller during and after the input gate.

Pixel proof runs separately from timing with fixed simulation steps and a fixed title particle seed. It compares full RGBA hashes and opacity for black, splash hold, every rendered frame of the two seal fades, the first eight menu fade frames and the first ready frame. The reduced-motion take compares the displayed black, seal and ready frames. Representative PNGs and the visual runner's manifest are under each take. Black and the nearly black early menu images are compared by hash to accommodate the visual runner's blank-image check.

The trace mode covers normal and reduced motion. It records inclusive timings for seal and title texture loads, scene request polling and instantiation, hidden controls and settings, title styling and layout, glyph shape and raster work, progression and checkpoint reads, and menu audio start. It also records Steam init in the candidate. Add `--allow-steam` and use a separate output directory to measure initialization on a machine with the Steam singleton available. The custom theme is installed by Godot before the script entry point. The trace identifies that theme and measures title styling separately. Draw boundaries approximate submission intervals and do not measure scanout or separate native texture upload from the enclosing work.

## Headless regression checks

These checks exercise window close and direct engine exit while the seal holds an attached hidden menu. They also assert the settled button width and resume gap after a resize, the profile and checkpoint written during the hold, and prompt sizing across the review's aspect-ratio change.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-167
for mode in close direct width disk aspect; do
  python3 tools/godot_task_runner.py --task-id perf-167 --stream -- godot --headless --path . --script tools/perf167/review_probe.gd -- "$mode" || break
done
```

The round-two probe compares the title, Chronicle and Settings control trees with release. It covers resized windows, a resize that returns to its original dimensions, saved UI-scale changes, a live UI-scale change, and switching to controller after reveal. The stable case also checks that startup retains the staged menu.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-167 && python3 tools/perf167/verify_startup_edges.py --baseline ../release --output /private/tmp/labyrinth_codex/perf-167/headless-edges
```
