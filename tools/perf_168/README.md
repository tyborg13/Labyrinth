# perf-168 map selection and room arrival

The quick-1120 census measured the following raw frame tails under macOS
background scheduling. Its context label describes the room tracked by the
driver. Those buckets also contain idle and input frames, so the matched
arrival replay below is the acceptance workload.

| Census room label | Map/A p99.9 / max (ms) | Room/A p99.9 / max (ms) |
|---|---:|---:|
| Combat | 117.859 / 179.526 | 247.380 / 247.380 |
| Campfire | 318.689 / 318.689 | 195.728 / 195.728 |
| Event | 88.009 / 88.009 | 138.003 / 138.003 |
| Scavenger | 212.741 / 212.741 | 391.229 / 391.229 |
| Treasure | 545.648 / 545.648 | 206.352 / 206.352 |

The catalog grouped the slow map/A frames at p99.9 318.689 ms and max
545.648 ms, and room/A at p99.9 241.970 ms and max 391.229 ms. The top
map/A texture spans were the Scavenger backdrop and inspection frame,
event paintings and Campfire choice art. The room/A frames included the
Scavenger material texture and room/encounter preparation continuations.
The census has no distinct Elite, Guardian or Graftwright row for this action.

## Work placement

| Destination | Work staged on the map | Work in the existing selection and door sequences |
|---|---|---|
| Combat | Biome art | Canonical room state during the map walk. Existing encounter layout, dossier and rigs during the door sequence. |
| Elite | Biome art | Canonical room state during the walk. Existing special encounter factory and preview during the door sequence. |
| Guardian | Biome and known Guardian/helper portraits | Canonical room state during the walk. Existing arena factory and live presentation preparation during the door sequence. |
| Campfire | Choice panels, bonfire, moss and biome art | Canonical room state during the walk. Existing choice and reveal paths on arrival. |
| Event | Deterministic or saved painting and hidden panel shell | Canonical event state during the walk. Existing choice, focus, and opening animation on arrival. |
| Scavenger | Board and stall art, prepared rig source, stock art and hidden shop | Canonical room state during the walk. Selected stock and hidden layout continue under the covered sequence. |
| Treasure | Chest parts, relic offer art and biome art | Canonical room state during the walk. Existing treasure reveal on arrival. |
| Graftwright | Panel art and prepared rig source, hidden workbench shell | Canonical room state during the walk. Existing entry and input on arrival. |

The staged state is detached, and the commit reuses it only while the
source snapshot and destination match. Input can fall back to the canonical
transition immediately. A map close, cancel, replacement save or new
selection invalidates preparation. Both checkpoint calls retain their
original position in the flow. The native diagnostic records their cost.

Room preparations decode eligible import payloads on a CPU worker. The
single-mip PNG and WebP data is the exact payload Godot 4.6.1 uses for those
imports, including any import-time alpha-edge processing. The worker creates
a private Image. The main thread publishes textures through the shared
preparation budget. The ordinary load path covers unsupported layouts and
imports. This preserves the qa-82 protection against threaded texture uploads.
[Godot 4.6.1 compressed texture loader](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/resources/compressed_texture.cpp#L272-L341)

## Native proof

Run from the prepared worktree against a separate runtime-clean perf-162
checkout at `119c9c4271655a1be1f931b8fd6e402da434ae59`. Keep the native
window foreground on a 1920×1080-capable display, with other Godot windows
closed. The visual runner applies a GUI lease. Use fresh output directories
for each proof. All commands use the committed asset inventory.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 -B tools/perf_168/compare.py --base ../perf-162 --output output/perf-168/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 -B tools/perf_168/compare.py --base ../perf-162 --profile background --attribution --pairs 1 --iterations 1 --output output/perf-168/native-attribution
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 -B tools/perf_168/compare.py --base ../perf-162 --capture --output output/perf-168/native-pixels
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && LABYRINTH_CEL_LOOK=off python3 tools/visual_probe_runner.py --task-id perf-168 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --min-images 0 tools/perf_168/room_import_check.gd
```

The first command interleaves the base and candidate five times under
normal scheduling and five times under `taskpolicy -c background`. It
alternates side and profile order, measuring the first traversal and four
repeats for every destination per process. It checks p99.9 and max for map A
and arrival, pooling the matched takes per profile. Reports retain per-take
and per-destination statistics, map-open and door tails, and walk/door
completion times. The background profile approximates a slower CPU.
The first traversal is process-local. Earlier destinations can warm shared art.

The diagnostic separates A dispatch, generation, checkpoint hold/storage,
analytics, and overlay work. It records per-frame resource spans, mounted
nodes by script/class, and renderer and memory monitors. Spans are inclusive,
so checkpoint, analytics, and resource spans can overlap. Base analytics
has no dedicated map flush measurement. Raw per-take `arrival.json` retains
all frame and phase data.

The capture command does a separate 60 fps fixed-step movie-clock replay on
Metal. The runner validates 32 full-size PNGs per side and the comparator
requires every pixel to match. Captures cover the focused map, first walk
frame, first door frame, and first arrival frame for each destination.
Image readback occurs only in the capture replay. Captures and `pixels.json`
are under `output/perf-168/native-pixels`. The separate import probe checks
exact decoded texels against Godot's native imported texture.

## Headless checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 -B tools/perf_168/compare.py --base ../perf-162 --headless --profile normal --pairs 1 --iterations 1 --output output/perf-168/headless-pair
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 -B tools/perf_168/compare.py --base ../perf-162 --headless --profile background --attribution --pairs 1 --iterations 1 --output output/perf-168/headless-background-attribution
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 tools/godot_task_runner.py --task-id perf-168 --stream -- godot --headless --path . --script tools/perf_168/arrival_probe.gd -- --case=scavenger --dwell-frames=1 --iterations=1 --cancel-walk --output="$PWD/output/perf-168/headless-cancel"
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 tools/godot_task_runner.py --task-id perf-168 --stream -- godot --headless --path . --script tools/perf_168/room_import_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 tools/godot_task_runner.py --task-id perf-168 --stream -- godot --headless --path . --script tools/perf_168/partial_rig_check.gd
```

Headless times use process-frame intervals. Use them to verify the replay,
checkpoint and analytics receipts, and diagnostic coverage. The native commands
establish the frame pacing and pixel criteria.

## Director feedback 1

The native timing, attribution, pixel, and texture commands above still apply.
The additional focused checks reproduce the seed-4 shop-to-shop walk, a purchase
under the open Rapier tooltip, window close during the Graftwright map walk,
Godot's prefixed PNG payload, and the inherited card's first reveal.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 tools/godot_task_runner.py --task-id perf-168 --stream -- godot --headless --path . --script tools/perf_168/feedback_ui_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && python3 tools/godot_task_runner.py --task-id perf-168 --stream -- godot --headless --path . --script tools/perf_168/quit_walk_check.gd
```

For focused UI captures at 1920×1080 and 100% UI scale, the same feedback
probe can capture the settled second shop, the two tooltip states, and the
first Graftwright fade. The PNG paths are emitted under the requested directory.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-168 && LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1 python3 tools/visual_probe_runner.py --task-id perf-168 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --timeout 90 --expect-size 1920x1080 --min-images 4 --result-manifest "$PWD/output/perf-168/feedback1-ui.json" tools/perf_168/feedback_ui_check.gd -- --capture-dir="$PWD/output/perf-168/feedback1-ui"
```
