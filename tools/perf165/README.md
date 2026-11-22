# perf-165 canvas pipeline proof

The route uses the startup scene, seed 7, cel look `all`, demo build, and the
Steam Deck smoothing default. The isolated fixture has already completed the
guided tutorial. Scripted joypad presses go through production input and its
normal focus paths. New Run goes through opening dialogue and the section map
to the first fight. The route plays a card, presses Pass, then selects Save
and Quit and Continue Run with the controller. The resume checkpoint is the
one the route saved.

The shipping warmup uses a private 2D world and never exposes its texture.
It submits two recipes per frame at most, borrowing only already cached
resources. Misses stay pending for the next batch while ready recipes can
proceed. The loading label and shade submit during the Maker's Seal hold,
with a fallback for title scenes opened directly. This primes the cover
before first-frame Continue. The remaining title recipes share the existing
one-second idle window. Input cancels pending title batches. An Edge
smoothing change re-arms the window for the new sample count and reuses any
existing scene load. Run-entry recipes use the existing loading cover and
room-entry recipes use door/map travel and asset preparation.

The application acknowledges completed native draws before resuming the
presentation continuation. Quit and Save and Quit disable active workers
immediately. The hooks add no presentation waits, so remaining compiles
under very short covers need native attribution.

The inventory lives in
[scripts/canvas_pipeline_recipes.gd](../../scripts/canvas_pipeline_recipes.gd).
New entries specify the production shader path or shared factory, command
geometry, and target settings. Keep textured and untextured polygon and
mesh formats distinct. The floor bake submits both polygon formats, bevel
line primitives, and the grid stroke. The shadow sample submits XYZ
positions. The headless check compares its full mesh flags to a live shadow
and records the format set directly from the live floor methods. The
portrait mask/coverage and strike trail
omit UVs. Atmosphere motes use the same indexed 2D MultiMesh format as
Godot's CPU emitter, with no emitter construction or RNG consumption.
Cel textures and rarity uniforms share shader programs. Use the attribution
table before extending the inventory to an additional native variant.
[Godot 4.6.1 canvas pipeline implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp)
[Godot 4.6.1 CPU particle implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/2d/cpu_particles_2d.cpp)

## Headless

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-165
export LABYRINTH_CEL_LOOK=all LABYRINTH_DEMO=1 SteamDeck=1 LABYRINTH_PROBE_WINDOW=1
base=/Users/borgerding/workspace/Labyrinth.worktrees/release
proof=/private/tmp/labyrinth_codex/perf-165/headless
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/lifecycle.gd
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/command_shapes.gd
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/title_idle.gd
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/title_idle.gd -- --smoothing
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/load_retry.gd
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/review_edges.gd
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path "$base" --script "$PWD/tools/perf165/probe.gd" -- --mode=headless --output="$proof/base"
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/probe.gd -- --mode=headless --output="$proof/candidate"
python3 tools/godot_task_runner.py --task-id perf-165 --stream -- godot --headless --path . --script tools/perf165/compare_receipts.gd -- "$proof/base" "$proof/candidate"
```

## Proof for the design owner

Use a visible display and a prepared `codex/release` base. Use a fresh output
directory for each invocation. The runner starts each take with an isolated
HOME and runs the same Mobile backend on both sides. Neutralize other host
load before the normal and background runs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-165
base=/Users/borgerding/workspace/Labyrinth.worktrees/release
proof=/private/tmp/labyrinth_codex/perf-165/native
python3 -B tools/perf165/native.py attribution --base "$base" --renderer metal --output "$proof/attribution"
python3 -B tools/perf165/native.py pairs --base "$base" --renderer metal --output "$proof/pairs"
python3 -B tools/perf165/native.py pixels --base "$base" --renderer metal --output "$proof/pixels"
python3 -B tools/perf165/native.py cache --renderer metal --output "$proof/cache-metal"
python3 -B tools/perf165/native.py cache --renderer vulkan --output "$proof/cache-vulkan"
```

- **Attribution** runs base and candidate once each under normal and
  `/usr/sbin/taskpolicy -c background`. Each take writes `attribution.md`
  and `frames.jsonl`. Use frame stage and viewport paths to distinguish
  the offscreen warm draw from a main-viewport appearance. RID, shader
  path or inline-source hash, and CanvasItem type are visibility
  candidates. Godot's aggregate counters cannot directly map a
  compilation to a candidate. A nonzero result requires an owner
  explanation backed by native evidence.
- **Pairs** runs five interleaved pairs per profile, alternating which side
  goes first. The report gives first-render p99/max and compile counts for
  New Run A, Continue A, first combat A, and Pass. It also gives twelve
  post-activation draws for context. The title context can include compiles
  shifted into the loading cover. Raw intervals and window-focus status
  remain in each take. Timing only reads back the backing size before
  the action windows. It disables the scene scan.
- **Pixels** captures the settled controller title, the first loading-cover
  draw after the title button activates, and the first ready fight at
  1920×1080 and 100% UI scale. Both runs use the game's reduced-motion
  option so ambient motion can settle.
  `pixels.txt` requires zero differing decoded pixels, with no mask or
  tolerance. Capture paths are `pixels/{base,candidate}/{title,loading_cover,first_fight}.png`.
- **Cache** uses the existing shader-01 fixture to invoke the production
  Steam account-directory switch within an isolated HOME. It checks
  directory aliases, idle warmup compilation frames and cache files
  visible from both roots after shutdown. On Metal, Godot 4.6.1 has
  shader bytecode caching and in-process pipeline reuse. A persistent
  native pipeline archive is backend-dependent. The Vulkan check also
  looks for the common RenderingDevice pipeline cache file.
  [shader-01 cache behavior](../../tests/shader_01_proof.md)
