# perf-126 proof tools

`replay.py` copies scripts/tools to a disposable project and symlinks unchanged
project inputs. It instruments explicit GDScript `load()` / `ResourceLoader.load`
call sites and AssetLoader's private source-image decoder. The threshold is
strictly greater than 2,000 µs; worker-thread decodes are deliberately excluded.
Original call-site line numbers are preserved. Engine-internal dependencies and
GPU upload spans are not mislabelled as explicit synchronous GDScript calls.

Each take starts a new Godot process and resets progression/settings with the
inherited census demo session (seed 7). Startup, New Run and controller routing
are real. Headless mode supplies the inherited synthetic post-draw signals; this
is CPU-only evidence. Cold/warm means first/repeated process order with warm
filesystem/import caches; these tools do not purge OS caches or claim native
shader-cache measurements. Every Godot invocation uses the task runner and an
85-second hard timeout for a 60-second route.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && python3 tools/perf126/replay.py --output /private/tmp/labyrinth_codex/perf-126/before
# After the product patch, freeze the second snapshot:
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && python3 tools/perf126/replay.py --output /private/tmp/labyrinth_codex/perf-126/after
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && python3 tools/perf126/run_pairs.py --before /private/tmp/labyrinth_codex/perf-126/before/project --after /private/tmp/labyrinth_codex/perf-126/after/project --output /private/tmp/labyrinth_codex/perf-126/pairs
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && python3 tools/perf126/report.py /private/tmp/labyrinth_codex/perf-126/pairs --output /private/tmp/labyrinth_codex/perf-126/report
```

The report includes every observed call above the threshold and its complete
caller stack. The transition is the census's empty-screen interval: its dynamic
CanvasLayer has no `scene_file_path`. Loading wall time sums that contiguous
interval, including the existing reveal. Frame time is the headless interval
from one process signal to the next. `texture_frame_peak_ms` also identifies the
subset with an observed texture call; it is not substituted for the overall
transition peak in the acceptance verdict.

Owner-only pixel proof (not run by the implementation worker):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && python3 tools/perf126/prepare_capture.py --project /private/tmp/labyrinth_codex/perf-126/capture-project
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-126 && LABYRINTH_HITCH_TRACE=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DEMO=1 LABYRINTH_PROBE_WINDOW=1 SteamDeck=1 python3 tools/visual_probe_runner.py --project /private/tmp/labyrinth_codex/perf-126/capture-project --task-id perf-126 --no-headless --display-driver macos --audio-driver Dummy --timeout 85 --startup-timeout 15 --expect-size 1920x1080 --proof-contract tools/perf126/proof.json --result-manifest /private/tmp/labyrinth_codex/perf-126/capture-manifest.json tools/perf126/capture.gd -- --driver=demo --seed=7 --seconds=60 --output=/private/tmp/labyrinth_codex/perf-126/captures
```

The capture copy changes only census proof configuration to 1920×1080/100% and
retains the route's controller inputs. It captures the first room and first map
open after 60 settle frames. For pixel A/B, prepare another project with `--baseline-project
/private/tmp/labyrinth_codex/perf-126/before-valid/project` and use separate
project/output/manifest paths. No inspection fixture is
requested by this unit; the design owner owns inspection and publication.
