# Enemy-turn scene redraws (perf-09)

The board keeps its static floor cache, retained surface floor, and three
canvases per depth tile. `board_scene_dirty_tiles.gd` compares ordered entries
per tile (including removed entries), local surface keys, terrain preview
keys, and old/new Bramble transition owners. Known maquette motion fields
redraw the addressed actors and changed obstruction owners; animation metadata
has no canvas commands. Unknown fields retain the conservative fallback.

`board_prop_command_cache.gd` belongs to each existing scene canvas. It retains
ordered stone, terrain body (including outcrop/spire fracture planes), and scene-prop body commands against
owned, equality-checked source inputs. Unused slots are discarded at that
canvas's next draw. Actors, shadows, paths, torch flicker, Bramble flecks,
outcrop rise/destruction inputs, terrain bars and tooltips keep their authored
paint positions and animation clocks. Nothing is batched or moved to a shader.
Cache inputs snapshot mutable atlas region, margin, clipping and nested source
texture identity as values, so editing the same resource invalidates baked UVs.

Terrain changes can alter the opacity of another tile's foreground prop.
`board_scene_prop_redraws.gd` compares the original tint function against both
old/new obstruction lists. Motion must also route actor tiles even when its
viewport texture RID is stable: facing and pixel registration can move.
Attack-target membership independently queues each affected terrain tile: a
full-health terrain bar can change even when the damage preview contains only
units. Entering, changing and clearing targets follow the same ownership rule.

## Repeatable headless proof

Run all engine work serially through the task runner. Output directories are
private proof state, never save-game inputs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-09 && python3 tools/godot_task_runner.py --task-id perf-09 --stream -- godot --headless --path . --script tools/perf09_soak.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-09/proof-states
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-09 && python3 tools/godot_task_runner.py --task-id perf-09 --stream -- godot --headless --path . --script tools/perf09_state_cases.gd -- --output-dir /private/tmp/labyrinth_codex/perf-09/other-states
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-09 && python3 tools/perf09_command_proof.py --output-dir /private/tmp/labyrinth_codex/perf-09/commands-final --states /private/tmp/labyrinth_codex/perf-09/proof-states/states.bin /private/tmp/labyrinth_codex/perf-09/other-states/states.bin
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-09 && python3 tools/godot_task_runner.py --task-id perf-09 --stream -- godot --headless --path . --script tests/perf09_scene_redraw_test.gd
```

The oracle reads the entire original board from pinned commit
`8af9feebcb3605968348cb25891ad25dfa4f58b0` with read-only Git. It generates private
copies of the original changed drawing helpers as well, redirecting CanvasItem primitives and RenderingServer
triangle submissions to identical argument sinks. It compares original output
with candidate cold/warm commands and models retaining every canvas that was
not queued. Texture resources are identified by unchanged source assets or
owning viewport path/dimensions; mesh surface arrays and StyleBox properties are
compared. Actor viewport implementations and assets are unchanged. Optional command sinks in the stone helpers change submission only; the complete original helpers are the reference. The wall
clock is fixed at 42 seconds and idle sampling at 0.375 seconds on both sides.
The soak supplies real hover, movement, attack, death and later-round states;
production inspection fixtures add Vyraketh, Craghide and ordinary combat.
The state-case generator also includes target enter/change/clear, Bramble
growth/expiry, actual Upheaval Outcrop events, production movement undo and
save/load, navigation pan/zoom, and in-place atlas mutations. Additional state
files can be appended to `--states`, including the review's extended cases.
Generated script paths normalize Windows separators and escape string literals;
the oracle checks a Windows path containing a quote after GDScript parsing.

`changed_layer_transitions` counts changed canvas output between consecutive
states. Unqueued transitions are separate errors. For a negative control, add
`--drop-target-queue` and use a separate output directory: only the generated
candidate omits the terrain target queue call, and the oracle must exit with
unqueued target canvas errors. Production sources remain intact.

The default-suite count guard allows at most 48 scene-layer draws for twelve
explicit enemy pose samples and eight for twelve submissions of one hover.
The hover includes enemy intent expansion and a unit damage forecast. It requires zero full-board invalidations, one hover event, and one path
geometry build. These are test bounds, not tuning or frame-time thresholds.
The guard also checks target select/cancel with unit-only damage previews and
atlas region, margin and source identity mutations against fresh commands.

For CPU evidence without snapshot-copying overhead, use the unchanged
`tools/fight_soak.gd` command from `tools/fight_soak.md`. Snapshot capture is a
separate workload; its whole-frame intervals are not native pacing evidence.

## Native confirmation (design owner)

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-09 && env -u LABYRINTH_CEL_LOOK python3 tools/visual_probe_runner.py --task-id perf-09 --no-headless --display-driver macos --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tests/fight_soak_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/perf-09/native-dev-off/manifest.json tests/fight_soak_probe.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-09/native-dev-off
```

Use the same quiet machine, debug binary and focused window as perf-08. This
captures rounds 1, 10 and 20 at 1920×1080 and 100% UI scale. Confirm enemy-turn
p95 ≤16.7 ms and over-33-ms frames ≤1%, hover p95 ≤16.7 ms, and unchanged idle.
The dummy renderer proves CPU/commands, not native frame pacing.
