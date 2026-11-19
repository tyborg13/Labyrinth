# perf-147 save-path proof

Terminal checkpoints remain authoritative in Continue and Windows rotation. The
clear path verifies that both recovery entries are absent before deleting live.
A read fault preserves both checkpoints, including when a Windows-style
rotation is requested. The Store keeps the byte-compatible Variant framing.

Save and Quit joins ordinary shutdown when a window or Steam close arrives
during the save. The departure path holds the input lock until the title is
ready or the app exits. It waits for the same FIFO across frames, preserving
checkpoint-before-append and append-before-acknowledgment ordering for the
existing analytics receipts. The watchdog is armed before the first save and
remains in effect through final cleanup. A successful Save and Quit still
returns to the title.

An explicitly requested run boot can resume a terminal checkpoint whose
embedded wallet revision is ahead of the profile. It repairs the profile
using the existing progression transaction. Title Continue still uses the
public resume summary, and the selected terminal file remains authoritative.

Synchronous disk barriers enforce the same eight-second save deadline. A
stalled filesystem call with an unknown outcome ends the process so gameplay
cannot continue before that write settles. The previous transaction remains
recoverable through the existing live and backup ordering.

## Headless

Use fresh output directories for each call.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-147 &&
proof=$(mktemp -d /private/tmp/labyrinth_codex/perf-147.XXXXXX)
python3 tools/perf_142/perf147_proof.py --output "$proof/candidate"
python3 tools/perf_142/perf147_proof.py --project ../perf-146 --control --output "$proof/control"
python3 tools/perf_142/perf147_proof.py --case sync-barrier --output "$proof/barrier"
python3 tools/perf_142/integrity_proof.py --task-id perf-147 --case stalled-io --output "$proof/perf145"
```

The clear probe uses macOS's user-immutable file flag or a Windows sharing
handle that permits reads and blocks deletion. The read probe inserts an
explicit post-open read fault at the read boundary in an isolated project
overlay. Gameplay scripts in the worktree have no fault-injection hooks.
The quit probe stalls the write after the temporary header reaches disk and
checks a late process-frame receipt, process exit time and the live SHA-256
before relaunch. Godot executes each of these steps through the task runner.

## Renderer proof for the design owner

Use a new output directory for each run. These commands capture 1920×1080 at
100% UI scale and validate the title's Continue state and the normal
Save and Quit transition with a finite worker stall.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-147 &&
proof=$(mktemp -d /private/tmp/labyrinth_codex/perf-147-visual.XXXXXX)
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all
for mode in victory-none victory-chosen defeat-none defeat-chosen abandoned embrace victory-pending defeat-pending
do
  mkdir "$proof/$mode"
  python3 tools/godot_task_runner.py --task-id perf-147 --stream -- godot --headless --path . --script tools/perf_142/perf147_probe.gd -- --case=prepare --mode="$mode" --output="$proof/$mode"
  python3 tools/visual_probe_runner.py --task-id perf-147 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/perf_142/perf147_terminal_visual_proof.json --result-manifest "$proof/$mode/images.json" tools/perf_142/perf147_probe.gd -- --case=relaunch --capture --mode="$mode" --output="$proof/$mode"
done
mkdir "$proof/save-and-quit"
python3 tools/godot_task_runner.py --task-id perf-147 --stream -- godot --headless --path . --script tools/perf_142/perf147_probe.gd -- --case=prepare --mode=room --output="$proof/save-and-quit"
python3 tools/visual_probe_runner.py --task-id perf-147 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/perf_142/perf147_save_quit_visual_proof.json --result-manifest "$proof/save-and-quit/images.json" tools/perf_142/perf147_probe.gd -- --case=save-and-quit --capture --output="$proof/save-and-quit"
python3 tools/perf_142/perf146_proof.py --case resume-modes --display macos --output "$proof/perf146"
```
