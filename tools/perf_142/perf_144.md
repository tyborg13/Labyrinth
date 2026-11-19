# perf-144 review proof

All runs use isolated user storage. The retry repro uses a disposable project
view and restores the run scene into that view after the first request fails.
The close proof checks the same save file again after Godot exits.

## Directed repros, stress and export

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-144
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1
base=/Users/borgerding/workspace/Labyrinth.worktrees/perf-142
proof=/private/tmp/labyrinth_codex/perf-144
python3 tools/perf_142/review_proof.py --project "$base" --output "$proof/base-final"
python3 tools/perf_142/review_proof.py --output "$proof/candidate-final"
python3 tools/godot_task_runner.py --task-id perf-144 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-144 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
python3 tools/godot_task_runner.py --task-id perf-144 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd
python3 tools/godot_task_runner.py --task-id perf-144 --stream -- godot --headless --path . --script tests/main_menu_input_test.gd
python3 tools/godot_task_runner.py --task-id perf-144 --stream -- godot --headless --path . --script tests/sfx_sync_bank_test.gd
python3 tools/qa105/typed_array_scan.py --base codex/release
LABYRINTH_HITCH_TRACE=0 python3 tools/export_smoke.py --preset 'Steam macOS' --output-dir "$proof/export-smoke-runtime"
LABYRINTH_HITCH_TRACE=0 python3 tools/export_game.py --task-id perf-144 --preset 'Steam Demo Windows' --pack-only --output "$proof/steam-demo-windows.pck"
```

The cold Settings and Quit repros delay the actual threaded scene request by
1.5 seconds via a probe-only loader. Settings opens at the existing title idle
threshold. The frame limit for the directed repros is 120 FPS. The settings
sample runs for 180 ms and compares the longest interval to round 2's
342.671 ms release take. The quit probe checks that frames keep advancing
within a 16.667 ms frame budget while the accepted request drains, records
elapsed time through teardown, and checks the log for shutdown warnings.
The seed fixture selects a near-future saved seed and waits for the system
clock to match this seed after Continue and Abandon.

## Headless interleaved timing

Every pair matched the seed-7 receipts. Timings are wall-clock milliseconds.
The first pair overlapped the Windows export and stress jobs. The later
pairs ran serially with alternating branch order.

| Take | Profile | Press to map, perf-142 → perf-144 | Longest frame, perf-142 → perf-144 |
| --- | --- | ---: | ---: |
| Concurrent | Normal | 1406.840 → 1709.922 | 59.917 → 102.829 |
| Concurrent | Stand-in | 38689.497 → 64568.664 | 405.882 → 881.267 |
| Serial 1 | Normal | 2680.355 → 2572.506 | 66.444 → 63.922 |
| Serial 1 | Stand-in | 7664.880 → 9566.891 | 205.975 → 353.981 |
| Serial 2 | Normal | 1213.881 → 1208.741 | 41.129 → 39.650 |
| Serial 2 | Stand-in | 30065.704 → 10289.995 | 207.492 → 250.459 |
| Serial 3 | Stand-in | 10490.356 → 10588.055 | 217.759 → 206.026 |

The last stand-in candidate beat both archived round-2 values. The latest
normal candidate beat the archived longest frame and took 65.078 ms longer
to reach the map. Stand-in comparisons with the live control vary across
takes. The raw traces and reports are in the `timing*` directories under
`/private/tmp/labyrinth_codex/perf-144/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-144
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
base=/Users/borgerding/workspace/Labyrinth.worktrees/perf-142
proof=/private/tmp/labyrinth_codex/perf-144/timing
probe="$PWD/tools/perf_142/new_run_probe.gd"
take() {
  label="$1"
  project="$2"
  shift 2
  "$@" python3 tools/godot_task_runner.py --task-id perf-144 --stream -- godot --headless --path "$project" --script "$probe" -- --output="$proof/$label"
}
take base-normal "$base"
take candidate-normal .
take base-background "$base" /usr/sbin/taskpolicy -c background
take candidate-background . /usr/sbin/taskpolicy -c background
python3 tools/perf_142/report.py "$proof/base-normal" "$proof/candidate-normal" --output "$proof/normal.md"
python3 tools/perf_142/report.py "$proof/base-background" "$proof/candidate-background" --output "$proof/background.md"
```

## Proof for the design owner

Use a visible display at 1920×1080 and 100% UI scale. The New Run probe records
the title, loading cover, first interactive frame, first map and settled map.
The Settings capture is separate so its readback stays outside the timing sample.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-144
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
base=/Users/borgerding/workspace/Labyrinth.worktrees/perf-142
proof=/private/tmp/labyrinth_codex/perf-144/windowed
mkdir -p "$proof"
probe="$PWD/tools/perf_142/new_run_probe.gd"
contract="$PWD/tools/perf_142/visual_proof.json"
python3 tools/visual_probe_runner.py --project "$base" --task-id perf-144 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract" --result-manifest "$proof/base-images.json" "$probe" -- --capture --output="$proof/base-visual"
python3 tools/visual_probe_runner.py --project . --task-id perf-144 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract" --result-manifest "$proof/candidate-images.json" "$probe" -- --capture --output="$proof/candidate-visual"
python3 tools/perf_142/report.py "$proof/base-visual" "$proof/candidate-visual" --output "$proof/visual-receipts.md"
python3 tools/visual_probe_runner.py --project . --task-id perf-144 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/perf_142/review_visual_proof.json --result-manifest "$proof/settings-images.json" tools/perf_142/review_probe.gd -- --case=settings --capture-dir="$proof/settings"
python3 tools/visual_probe_runner.py --project . --task-id perf-144 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 tools/perf_142/review_probe.gd -- --case=close
python3 tools/visual_probe_runner.py --project . --task-id perf-144 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 tools/perf_142/review_probe.gd -- --case=quit
```
