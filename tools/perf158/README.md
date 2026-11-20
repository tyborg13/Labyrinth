# perf-158 preparation proof

The base is perf-156 at `fab6afc2a040416b79d2607e153f67cec730e909`. Its room, encounter and section manifests still set the asset boundaries. Covered work borrows perf-151’s shared 11 ms preparation budget. Native preparation advances at post-draw and headless preparation advances at process-frame boundaries. Slow room entry can borrow up to 40 ms after accounting for observed frame overhead. An atomic Godot import or upload can overrun its estimate.

The encounter factory retains the synchronous fallback and exact-input guards. Covered preparation may yield between intent candidates and opening steps. The first pre-battle reveal waits for construction of the hidden preview. Crawler and maquette foes build their existing rig trees in bone, sprite and mesh steps. The opening NPC uses the rig slice under the New Run cover.

## Proof for the design owner

Run the three commands sequentially in a focused macOS session. Each command stages a disposable perf-156 project from the pinned Git blobs and a candidate project from the current worktree. Both use private copies of the warm import cache, the same controller replay, cel assets, and isolated user data.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-158
mkdir -p output/perf-158
touch output/perf-158/.gdignore
proof_dir=$(mktemp -d "$PWD/output/perf-158/native.XXXXXX")
python3 -B tools/perf158/proof.py visual --output "$proof_dir/pixels"
python3 -B tools/perf158/proof.py timing --profile normal --output "$proof_dir/normal"
python3 -B tools/perf158/proof.py timing --profile background --output "$proof_dir/background"
```

The visual replay uses Metal and compares the SHA-256 hashes of viewport pixels at the first uncovered New Run draw and the first pre-battle draw. The native runner validates the two PNGs per arm at 1920×1080 and 100% UI scale. The replay sets a fixed backing viewport after the controller route verifies its title configuration. It prints each absolute PNG path so the runner can discover it. Accepted take directories are listed in `pixels/focus.json`. Each contains `run_start.png`, `room_entry.png`, `windows.json` and `images.json`.

Each timing profile runs five consecutive interleaved pairs in ABBAABBAAB order with no artificial CPU workers. Timing keeps perf-151’s 1280×800 backing size, 115% UI scale, seed 7, normal combat speed and disabled VSync. The background profile uses macOS `taskpolicy -c background`. Timing uses controller-press to post-draw wall time and post-draw frame intervals. Screenshots run in separate processes. Focus loss invalidates the take. The runner retakes that arm in place in the schedule, with up to three retries. Discarded logs and accepted pairs are recorded in `focus.json`.

Each profile writes `timing.md` with paired deltas, median paired deltas and min–max spread for the worst frame and wall time. On normal QoS, both run-start medians must improve and every pair’s worst frame and wall time must be at most 10% above base. On background QoS, the median run-start worst frame must improve and the median run-start wall delta must be at most +5%. Room entry measurements appear alongside run start. Raw traces, commands and semantic witnesses are stored per take.

## Headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-158
python3 tools/godot_task_runner.py --task-id perf-158 --stream -- godot --headless --path . --script tools/perf158/focused.gd
smoke_dir=$(mktemp -d "$PWD/output/perf-158/headless-replay.XXXXXX")
python3 -B tools/perf158/proof.py smoke --output "$smoke_dir/pair"
```

The focused test verifies a shared preparation interval, exact sliced factory output with untouched inputs, and exact ordered Crawler and Bile Bloomer rig trees, poses and still textures. The headless replay checks the same public controller route and logical capture geometry on both arms.
