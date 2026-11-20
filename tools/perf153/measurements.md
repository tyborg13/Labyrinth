# perf-153 main-thread texture measurements

Godot 4.6.1 on arm64 macOS 26.3.1. Each cell reports the median of 11
synchronous main-thread `ResourceLoader.load` calls to an imported texture,
using `CACHE_MODE_IGNORE` after one untimed load per image. This measures decode
and resource creation in the headless runtime with a warm filesystem cache.
The VRAM column estimates one RGBA8 allocation per texture with no mipmaps.
Background QoS samples had substantial spread. These are host measurements.

| Texture | Before → after dimensions | Normal (ms) | Background (ms) | Estimated VRAM (bytes) |
| --- | --- | ---: | ---: | ---: |
| `campfire_choice_embrace_v2.png` | 1254x1254 → 640x640 | 59.414 → 7.413 | 115.775 → 11.975 | 6,290,064 → 1,638,400 |
| `campfire_choice_linger_v2.png` | 1254x1254 → 640x640 | 60.462 → 7.659 | 133.410 → 11.747 | 6,290,064 → 1,638,400 |
| `campfire_choice_purge_v2.png` | 1254x1254 → 640x640 | 64.535 → 7.238 | 129.334 → 12.512 | 6,290,064 → 1,638,400 |
| `campfire_choice_strength_v2.png` | 1254x1254 → 640x640 | 57.812 → 6.891 | 90.641 → 15.376 | 6,290,064 → 1,638,400 |
| `ritual_clasp.png` | 2172x724 → 744x248 | 47.264 → 2.677 | 61.866 → 4.323 | 6,290,112 → 738,048 |
| `ember_hoarder.png` | 1024x1024 → 128x128 | 12.495 → 0.342 | 23.085 → 0.644 | 4,194,304 → 65,536 |

The six textures went from 35,644,672 to 7,357,184 estimated VRAM bytes,
a saving of 26.98 MiB (79.4%).

To reproduce a cohort after importing the corresponding images, run from this
task worktree.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-153 && python3 tools/godot_task_runner.py --task-id perf-153 --stream -- godot --headless --path . --script tools/perf153/texture_load.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-153 && taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-153 --stream -- godot --headless --path . --script tools/perf153/texture_load.gd
```

The raw samples from this worktree are in `.godot/perf153-proof/` as
`before-normal.log`, `before-background.log`, `after-normal.log`, and
`after-background.log`.
