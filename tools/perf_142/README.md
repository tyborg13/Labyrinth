# perf-142 New Run proof

Use the task worktree and the existing release worktree at
`e5a6d3f53fd6ee96bd0f367b3bd9649a540fe24c`. Both takes run the real startup
scene with a fresh demo profile, seed 7, 1920×1080 at 100% UI scale, and four
seconds of title idle. The probe routes a mouse click through the real New
Run button. It observes the loading cover release input, then routes the
opening-dialogue clicks and stops at the first interactive map. The report
keeps the two milestones separate.

## Round 0 measured result

[Round 1](round1.md) documents worker ownership and cancellation.
[Round 2](round2.md) moves seed reservation and graph preparation into title
idle and records the final timing and export proof.

The raw takes and all over-16-ms frames are in
`/private/tmp/labyrinth_codex/perf-142/verified/`. Frame intervals are
headless process-frame proxies on Godot 4.6.1. The stand-in used macOS
`taskpolicy -c background`.

| Profile | Longest frame, release → candidate | Press to first map, release → candidate | Receipt |
| --- | ---: | ---: | --- |
| Normal | 408.659 → 45.234 ms (−88.9%) | 3,398.902 → 2,367.275 ms | Match |
| Stand-in | 2,399.236 → 206.098 ms (−91.4%) | 16,892.864 → 15,528.504 ms | Match |

Release's largest named stand-in UI span was 1,015.750 ms in opening
dialogue. The candidate's longest stand-in interval occurred during the
presentation-readiness wait and had under 1 ms of recorded CPU spans.
All 52 candidate stand-in intervals over 100 ms have named wait or
work context. The probe records wall intervals and cannot assign every
scheduling gap to CPU work. A preceding stand-in pair measured
1,051.573 → 205.104 ms (−80.5%).

For `spec/peer_benchmark/perf_log.md`:

- **perf-142** (2026-11-19): move seeded map generation and opening-dialogue paint off the main thread and budget cold asset publication across loading frames. Demo seed 7 headless maximum normal 408.659 → 45.234 ms, stand-in 2,399.236 → 206.098 ms (−91.4%), run and first-map receipts match, native proof pending.

## Headless proxy

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-142
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
release_dir=/Users/borgerding/workspace/Labyrinth.worktrees/release
probe_path="$PWD/tools/perf_142/new_run_probe.gd"
proof_dir=/private/tmp/labyrinth_codex/perf-142/replay
python3 tools/godot_task_runner.py --task-id perf-142 --stream -- godot --headless --path "$release_dir" --script "$probe_path" -- --output="$proof_dir/release-normal"
python3 tools/godot_task_runner.py --task-id perf-142 --stream -- godot --headless --path . --script "$probe_path" -- --output="$proof_dir/candidate-normal"
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-142 --stream -- godot --headless --path "$release_dir" --script "$probe_path" -- --output="$proof_dir/release-background"
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-142 --stream -- godot --headless --path . --script "$probe_path" -- --output="$proof_dir/candidate-background"
python3 tools/perf_142/report.py "$proof_dir/release-normal" "$proof_dir/candidate-normal" --output "$proof_dir/normal.md"
python3 tools/perf_142/report.py "$proof_dir/release-background" "$proof_dir/candidate-background" --output "$proof_dir/background.md"
```

Use `--title-idle=0` for the immediate-click fallback. Headless timing uses
process-frame signals. The report lists every interval over 16 ms, with
phase spans and loads when available. The wait context identifies the
in-flight startup step for long intervals without a measured CPU span.
The full live and saved states are in each take. The comparison ignores
only the random analytics run ID and elapsed play clock. It also compares the
opening dialogue's baked image hashes and the first map's destinations.

## Proof for the design owner

Run the windowed captures on a display that supports the requested viewport.
The visual runner validates five images per take. The probe captures the
settled title, the first loading-cover draw, the first fully interactive
frame, the first interactive map draw, and the map after its crossfade.
The renderer proof and timing are separate takes so viewport readback and PNG
writes stay out of the timings.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-142
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_HITCH_TRACE=1
release_dir=/Users/borgerding/workspace/Labyrinth.worktrees/release
probe_path="$PWD/tools/perf_142/new_run_probe.gd"
contract_path="$PWD/tools/perf_142/visual_proof.json"
proof_dir=/private/tmp/labyrinth_codex/perf-142/windowed
python3 tools/visual_probe_runner.py --project "$release_dir" --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract_path" --result-manifest "$proof_dir/release-images.json" "$probe_path" -- --capture --output="$proof_dir/release-visual"
python3 tools/visual_probe_runner.py --project . --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract_path" --result-manifest "$proof_dir/candidate-images.json" "$probe_path" -- --capture --output="$proof_dir/candidate-visual"
python3 tools/perf_142/report.py "$proof_dir/release-visual" "$proof_dir/candidate-visual" --output "$proof_dir/visual-receipts.md"
```

For timing, keep the game window visible. Read the per-frame focus flags before
interpreting long intervals. Run the same renderer and display configuration on
both takes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-142
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_HITCH_TRACE=1
release_dir=/Users/borgerding/workspace/Labyrinth.worktrees/release
probe_path="$PWD/tools/perf_142/new_run_probe.gd"
proof_dir=/private/tmp/labyrinth_codex/perf-142/windowed
python3 tools/visual_probe_runner.py --project "$release_dir" --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 120 "$probe_path" -- --output="$proof_dir/release-normal"
python3 tools/visual_probe_runner.py --project . --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 120 "$probe_path" -- --output="$proof_dir/candidate-normal"
/usr/sbin/taskpolicy -c background python3 tools/visual_probe_runner.py --project "$release_dir" --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 120 "$probe_path" -- --output="$proof_dir/release-background"
/usr/sbin/taskpolicy -c background python3 tools/visual_probe_runner.py --project . --task-id perf-142 --no-headless --display-driver macos --audio-driver Dummy --min-images 0 --timeout 120 "$probe_path" -- --output="$proof_dir/candidate-background"
python3 tools/perf_142/report.py "$proof_dir/release-normal" "$proof_dir/candidate-normal" --output "$proof_dir/normal.md"
python3 tools/perf_142/report.py "$proof_dir/release-background" "$proof_dir/candidate-background" --output "$proof_dir/background.md"
```
