# shader-01 cache continuity

The warmup implementation, loading hook, inventory generator and warmup tests
have been removed. There is no additional loading gate or render work. The
remaining production changes are `engine_cache_directories.gd` and synchronous
calls at the Steam and task-only user-directory switches. No shader, engine,
export-preset, save format or Steam behavior beyond that hook was changed.
Changes for the latest review feedback remain uncommitted under the
implementation/design-owner split.

## Cache paths and behavior

Godot 4.6.1's common RenderingDevice pipeline file is
`user://vulkan/pipelines.<rendering-method>.<device>.cache`. The directory is
created at initialization, before the Steam autoload changes `user://`; saving
uses that same virtual path later. This applies to its shared device code even
when Metal is selected. See
[RenderingDevice, lines 6496–6586](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/rendering_device.cpp#L6496).

Metal also defines `<OS user-data-dir>/metal/pipelines.<device>.cache`, but
upstream 4.6.1's `pipeline_cache_create()` immediately returns false. Thus this
build has no enabled Metal binary archive to recover through a path fix. Both
`vulkan/` and `metal/` are linked so all defined backend paths remain stable.
See [Metal, lines 1430–1480](https://github.com/godotengine/godot/blob/4.6.1-stable/drivers/metal/rendering_device_driver_metal.mm#L1430).

The available native fresh-HOME artifact
`/private/tmp/labyrinth-godot-home/fix-07-1792712926298278000-87139-petrify_card_probe-1`
was inspected read-only: its original user directory contains 29 shader cache
files, an empty `vulkan/`, and no `metal/`. This agrees with the source. No new
native process could be launched in the implementation sandbox.

The director's reproduction was read from local `codex/peer-benchmark` with
`git show` because its file was not present in this worktree. The new probe uses
the same before-shader → user-dir switch → after-shader pattern, with fixed shader
source so the second session can test a real cache hit.
The native probe draws into a fixed 1920×1080 SubViewport, displays its texture
in the desktop window, and captures/samples that SubViewport's image. Retina
window dimensions cannot change the capture or the pixel-check coordinates.

## Acceptance and director observations

Both backends require no `_save_to_cache` errors in either session and zero
shader cache misses throughout session 2. Shader mode also requires a verbose
CanvasShaderRD cache hit inside the deterministic after-shader's log markers.

- **Metal:** pipeline counters and frame timings are reported for information.
  Nonzero pipeline counts do not fail cache acceptance.
- **Vulkan:** session 2 additionally requires zero deterministic-shader pipeline
  compilations and zero compilations on every sampled combat frame.

The director's Metal runs before this final proof adjustment confirmed the cache
fix: shader mode had 36 misses in session 1 and 0 in session 2, no cache-save
errors, and all three links. Combat had 52 misses then 0. The first trap-kill
frame remained approximately 30 ms in both sessions, consistent with Metal
pipelines being created on first use each session. The first shader capture
was 3024×1898 on Retina; the fixed SubViewport corrects that proof issue.
The director reruns the updated native proof; no local native run is claimed.

## Migration contract

`SteamService._apply_steam_user_directory()` captures the absolute original
`user://` immediately before changing either setting. Before returning, it links
`shader_cache`, `vulkan`, and `metal` in the new root to their original absolute
locations through `DirAccess.create_link`. This happens synchronously, before
another frame can render. The task-only `ParallelRuntime` reuses the same helper
instead of its older recursive mirror, preserving its runner-isolated HOME.

- Matching links, including link chains to the same filesystem object, are reused
  only after ensuring their source is a directory. A dangling matching link's
  source is created; a blocked source is reported as an error, never as shared.
- A denied link or an existing real directory gets only missing directories,
  including every original shader/group directory. No cache binaries are copied.
- Files occupying directory paths, foreign links, and dangling foreign links are
  preserved and reported. Unexpected nested links are not followed.
- The helper never removes, renames, replaces or opens any cache file for writing.
  Existing source/destination bytes remain untouched. It reports linked versus
  mirrored persistence and any blocked path; the Steam hook prints the report.

**Mirror fallback persistence:** Godot can save caches under the new user root,
and those files remain there. They do not become visible to reads performed in
the original root before the next switch. In particular, pipeline cache startup
reuse is not guaranteed on a no-symlink path. Programs loaded after switching
may still reuse their new-root shader cache. No destructive migration or binary
copy was added to compensate for this limitation.

## Headless verification

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tests/run_engine_cache_checks.py
```

This runs only the new cache tests, proof-validator tests, existing Steam service
suite, existing settings persistence/audio/presentation assertions, save pipeline,
perf-03 equivalence, and parser checks for the native probes. The existing Steam
and settings assertions are invoked unchanged through an `_initialize` override;
the full-suite body and its child scheduler are never called.

Earlier cache-fix result lines (Steam/settings, save pipeline and equivalence
were not rerun for the final proof-only adjustment):

```text
ENGINE CACHE DIRECTORIES TEST RESULT: PASS (52 assertions)
STEAM SERVICE TEST RESULT: PASS
CACHE SWITCH STEAM/SETTINGS TEST RESULT: PASS (113 assertions)
TEST RESULT: PASS — save pipeline compatibility and cleanup
PERF03 FRAME RESULT: PASS (0 failures) report=res://output/shader-01/equivalence.json
PERF03 BUDGET RESULT: PASS (0 misses)
SHADER01 CHECKS RESULT: PASS
```

For the final adjustment, rerun only:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tools/godot_task_runner.py --task-id shader-01 --stream -- godot --headless --path . --script tests/engine_cache_directories_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 -B tests/test_engine_cache_proof.py
```

Observed final-adjustment results:

```text
ENGINE CACHE DIRECTORIES TEST RESULT: PASS (52 assertions)
Ran 4 tests in 0.000s
OK
```

The proof-validator tests cover backend-specific acceptance, session-2 cache
misses, a cache hit outside the deterministic shader's log markers, missing
counters, a missing trap case, and cache-save errors. Engine output and reports
are under `output/shader-01/`. The macOS certificate error and existing settings
test's ObjectDB exit warning are still visible; neither is an assertion failure.
No full suite, peer review, commit or publication was performed.

### Review regression verification

The latest review runs only the cache, Steam/settings and save pipeline tests,
plus explicit mutations of those tests' production paths:

```sh
python3 tools/godot_task_runner.py --task-id shader-01 --stream -- godot --headless --path . --script tests/engine_cache_directories_test.gd
python3 tools/godot_task_runner.py --task-id shader-01 --stream -- godot --headless --path . --script tests/cache_switch_regression_test.gd
python3 tools/godot_task_runner.py --task-id shader-01 --stream -- godot --headless --path . --script tests/save_pipeline_performance_test.gd
python3 -B tests/run_engine_cache_mutations.py
```

The cache tests cover dangling matching links and blocked matching sources for
each of `shader_cache`, `vulkan`, and `metal`; repair idempotence; nested source
and destination links; untouched foreign destinations; and a source cycle.

The Steam regression switches from both standard and custom original user
directories. It derives the expected absolute account path independently of the
Steam hook, writes progression, a run checkpoint, settings and analytics through
their real stores, reads those bytes at the expected account path, and compares
every original profile file byte for byte. All three account cache folders must
identify the original filesystem directories when native links are supported;
the no-link path checks mirrored groups instead. A repeated hook preserves both
the account path and original profile bytes.

Observed result lines (all normal engine runs exited 0):

```text
ENGINE CACHE DIRECTORIES TEST RESULT: PASS (112 assertions)
STEAM SERVICE TEST RESULT: PASS
STEAM CACHE SWITCH REGRESSION RESULT: PASS
CACHE SWITCH STEAM/SETTINGS TEST RESULT: PASS (209 assertions)
TEST RESULT: PASS — save pipeline compatibility and cleanup
ENGINE CACHE MUTATIONS RESULT: PASS (7/7 detected)
```

Every mutation produced the expected assertion failure and a nonzero test exit;
parser errors are rejected as mutation evidence. The runner restores the exact
source bytes in `finally` and records their SHA-256 values in
`output/shader-01/review-mutations/report.json`.

| Mutation | Assertion that detected it |
| --- | --- |
| Accept matching links without creating/validating the source | `Matching dangling source is created: shader_cache` (also vulkan/metal) |
| Accept `make_dir_recursive_absolute()`'s OK without verifying a directory | `Matching source creation failure is reported: shader_cache` (also vulkan/metal) |
| Remove both Steam user-directory setting calls | `Steam switch resolves user:// to the expected account path: 123` |
| Remove only `use_custom_user_dir = true` | The same expected-account-path assertion from a standard original profile |
| Remove only `custom_user_dir_name = user_dir_name` | The expected-account-path assertion |
| Remove the nested-source-link guard | `Nested source link is rejected` |
| Remove the nested-destination-link guard | `Foreign nested destination is never populated` |

The source-guard mutation uses the non-cyclic nested-source fixture so its
failure is an assertion, without intentionally recursing through a cycle.
The unmodified suite separately exercises the real cycle and its rejection.
Normal logs: `output/shader-01/review-{cache-directories,steam-settings,save-pipeline}.log`.
Mutation logs: `output/shader-01/review-mutations/<mutation>.log`.
The existing macOS certificate error and settings suite's ObjectDB exit warning
remain visible. No native runs, full suites, peer review or `spec/` edits were
performed for this feedback.

## Proof for the design owner

Each command below launches exactly two planned native sessions, serially, in
one fresh isolated HOME. The output path must be new; existing files/caches are
never deleted or overwritten by the proof coordinator. The coordinator nests
`visual_probe_runner.py --no-isolated-home` inside `godot_task_runner.py` with a
fixed run ID. Both sessions therefore inherit the same HOME/XDG roots, while
visual-probe namespaces remain isolated and linked to that original cache.
A tiny task-local executable wrapper adds `godot --verbose`; neither runner is
modified. Launch/parser/timeout failures stop the pair without a retry.

Deterministic shader before/after switch, twice (Metal):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tests/run_engine_cache_proof.py --native --mode shader --backend metal --output output/shader-01/cache-shader-metal-02
```

Perf-03 scenario B, three passes per session, twice in another fresh HOME:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tests/run_engine_cache_proof.py --native --mode combat --backend metal --output output/shader-01/cache-combat-metal-02
```

The same tests on Vulkan/MoltenVK, if available to the director:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tests/run_engine_cache_proof.py --native --mode shader --backend vulkan --output output/shader-01/cache-shader-vulkan-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/shader-01 && python3 tests/run_engine_cache_proof.py --native --mode combat --backend vulkan --output output/shader-01/cache-combat-vulkan-02
```

Under each output directory:

- `session-{1,2}/verbose.log`: full engine output, cache-hit markers, and counters.
- `session-{1,2}/report.json`: deterministic program hashes/frame counters, or the
  unchanged perf-03 scenario reports with added per-monitor counters.
- `session-{1,2}/visual-manifest.json`: native runner validation.
- Shader mode: `session-{1,2}/shader_cache_switch.png`, exactly 1920×1080 at 100%.
  Combat timing intentionally has no screenshot capture work.
- `proof.json`: backend, exact nested commands, shader miss/save-error counts,
  acceptance errors and actual cache files found in the shared HOME after each
  orderly engine shutdown.

Require no `_save_to_cache` errors in either session and zero shader cache
misses in session 2. Shader mode's second session must contain
`Loading cache for shader CanvasShaderRD, variant ...` between its
`SHADER01 AFTER_SHADER_BEGIN/END` markers. Both backends retain complete pipeline
counter reports. Only Vulkan requires zero pipeline counts for the deterministic
shader and every combat frame in session 2. The probes and coordinator **fail**
on misses against that backend's acceptance. Updated native captures and Vulkan
acceptance remain for the director to verify.

**Metal engine limit:** Canvas pipeline maps belong to each `CanvasShaderData`
instance, independently of ShaderRD's disk cache. Thus a disk cache hit and a
new pipeline-creation counter can coexist with correct cache paths and Metal
archives disabled. The director observed that behavior. See
[CanvasShaderData pipeline ownership/counters](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp#L1536).
No counter suppression, warmup or engine patch hides this; Metal's acceptance
checks shader-cache persistence and reports pipeline creation separately.

## TODO_DESIGN, chosen defaults, open issues

No TODO_DESIGN placeholders or player-facing decisions were introduced. New
values belong only to tests: Steam IDs `123`/`456`; original-profile fixture name
`Engine Cache Switch Original`; original/account embers 17/29, master volumes
0.25/0.75 and checkpoint indices 3/7; `SteamSwitchFixtureRD/group` cache fixture;
fixed sentinel bytes, link names and test-only directory names; deterministic shader constants
2 and 3; 64×64 debug quads at (20,20)/(120,20); 12 settle frames and 10 measured
frames per shader; a 0.6 blue-channel render-proof threshold; fixed fixture file contents; and a 240 s native timeout
matching the existing perf-03 proof wrapper. The existing three combat passes
and required 1920×1080/100% proof settings are retained.

Remaining work belongs to native verification: rerun the fixed-size shader
capture and backend-specific gates. The cache fix itself has director-confirmed
Metal cache-write/hit evidence above. No inspection fixture was requested here.
