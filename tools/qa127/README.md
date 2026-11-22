# QA-127 release hunt

The hunt uses the production RunScene and the existing seeded legal-input policy. The audit checks the displayed Pass numbers when the forecast discloses the full turn. It compares the replay with the live board when that board is still available after resolution.

## Reproduce headless

Run from the qa-127 worktree. Campaign output directories must be empty.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && python3 tools/qa127/campaign.py --seed 101016 --runs 1 --processes 1 --no-embrace --stop-after 424 --output-dir output/qa-127/repro/slag-mortar
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && python3 tools/godot_task_runner.py --task-id qa-127 --stream -- godot --headless --path . --script tests/combat_texture_preparation_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && python3 tools/godot_task_runner.py --task-id qa-127 --stream -- godot --headless --path . --script tools/qa127/skill_receipt_cancel.gd
```

The arena check compares reserved canvas instance IDs with the tile slices in
the live board after Begin.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && for fixture in guardian:last_lamplighter dragon:tharokh; do
    take_dir="$PWD/output/qa-127/repro/${fixture#*:}"
    mkdir -p "$take_dir"
    LABYRINTH_CEL_LOOK=all LABYRINTH_DEMO=0 LABYRINTH_PROBE_WINDOW=1 python3 tools/godot_task_runner.py --task-id qa-127 --stream -- godot --headless --path . --script tools/qa127/arena_opening.gd -- "--fixture=$fixture" "--output=$take_dir" --frame-state || break
done
```

## Proof for the design owner

The Reflect probe captures each approved aim, commits the same click and compares the outcomes. The arena probe records the first three rendered frames after Begin. Both use 1920×1080 at 100% UI scale. Use a fresh output directory for each invocation.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && mkdir -p output/qa-127/native/reflect
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && LABYRINTH_CEL_LOOK=all PLA01_OUT="$PWD/output/qa-127/native/reflect" python3 tools/visual_probe_runner.py tools/qa127/reflect_commit.gd --task-id qa-127 --no-headless --display-driver macos --audio-driver Dummy --timeout 240 --expect-size 1920x1080 --proof-contract tools/pla01/reflect_preview_contract.json --result-manifest output/qa-127/native/reflect/images.json

cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && for fixture in guardian:last_lamplighter dragon:tharokh; do
    capture_dir="$PWD/output/qa-127/native/${fixture#*:}"
    mkdir -p "$capture_dir"
    LABYRINTH_CEL_LOOK=all LABYRINTH_DEMO=0 LABYRINTH_PROBE_WINDOW=1 python3 tools/visual_probe_runner.py tools/perf171/arena_probe.gd --task-id qa-127 --no-headless --display-driver macos --rendering-method mobile --rendering-driver metal --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tools/perf171/first_frames.json --result-manifest "$capture_dir/images.json" -- "--fixture=$fixture" "--output=$capture_dir" --capture || break
done
```

The Reflect PNG names are `pla01_reflect_*_1920x1080.png`. Each arena writes `arena_first_0.png` through `arena_first_2.png`.

The existing deferred-analytics timing tests can also run with a native renderer. Their own small debug windows exercise callback ordering.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && python3 tools/visual_probe_runner.py tests/deferred_reconciliation_queue_test.gd --task-id qa-127 --no-headless --display-driver macos --audio-driver Dummy --min-images 0
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-127 && python3 tools/visual_probe_runner.py tests/deferred_skill_analytics_test.gd --task-id qa-127 --no-headless --display-driver macos --audio-driver Dummy --min-images 0
```
