# perf-155 map icon measurements

Draw bounds are the physical-pixel extent of the submitted icon shape, including
transparent pixels inside that shape. Desktop is 1920×1080 at 100% UI scale. The
Steam Deck profile uses 1280×800 output, the existing 1503×939 logical viewport,
115% default UI scale and Deck controller glyphs. The X and Y ratios differ
slightly because the logical dimensions are integral.

## Consumer audit

| Surface | Use and maximum extent at desktop | Steam Deck maximum |
| --- | --- | --- |
| Section map node | Ordinary and special room faces are `2 × radius × 0.735`. Their largest reachable pulse is 71.34 px (radius 46, scale 1.055). Activation takes precedence and peaks at 73.71 px (scale 1.09). Bosses use radius 88 and peak at 141.00 px. Current-room lantern substitution can use a boss radius, with a 129.36 px face. | 62.80 px ordinary/special, 120.13 px boss, 110.21 px current-boss lantern. |
| Section map legend, room preview and Scout | Legend faces are 35.28 px (radius 24). The legend swaps its boss ID to the viewed section and shows special seals when present. Current room previews are text. Scout uses its own icon in the 28 px native button cap. The traveling lantern uses radius 34 (49.98 px face). | 30.06 px legend, 23.86 px Scout, 42.58 px traveling lantern. |
| Legacy map, expanded | Interactive node geometry scales linearly over the full continuous 0.58–1.70 zoom range. The current-state envelope is `84 × zoom × 1.12 × 0.245 × 1.70`, giving 22.73, 39.18 and 66.61 px at minimum, default and maximum zoom. Reachable, visited and unavailable nodes have smaller multipliers. The same geometry applies wherever the legacy map resolves an icon from the map registry. | 19.36, 33.38 and 56.75 px. |
| Legacy map, compact, legend and hover card | Compact nodes clamp the base size to 20–32 px and submit at most 14.62 px. The fixed legacy legend and hover card submit 12.14 px (21 px badge) and 17.34 px (30 px badge). Legacy elemental combat variants use their element assets. | 12.47 px compact, 10.34 px legend, 14.77 px hover. |
| Board door destination | Board route destinations use the same room icon library. The 52 px icon-size ceiling, 0.56 radius factor and 0.735 face inset give a 42.81 px bound, even when the camera framing changes tile width. | 36.47 px. |
| Chronicle room path | Round path cells are 34 px for rooms and 44 px for dragons, with a 2.5 px inset on each side. The submitted polygon reaches 29 and 39 px respectively. The terminal-defeat cell is an X, and the room tooltip is text. The run path skips the section-start tile and Scout is an action. | 24.71 px rooms, 33.23 px dragons. |

The audit follows `RoomIconLibrary` through `SectionMapPanel`, `SectionMapNode`,
`SectionMapSkin`, `SectionMapCanvas`, `LabyrinthMapView`, `CombatBoardView` and
`ChroniclePanel`. Pre-battle headers and enemy inspection use the objective,
equipment and actor art paths. Boss presentation uses its actor art. The
Grimoire uses action icons. The only direct alias in encounter data outside the
room registry is Ember Hoarder's rule panel, which uses the existing perf-153
icon. No cel-look manifest entry or generated variant exists for this directory.
Section-map terrain art and guardian emblems live outside this cohort.

The sizing rule uses the larger physical axis across both profiles. The
production section map scrolls at fixed emblem scale. Legacy and board values
are geometry envelopes. The peak-seal probe invokes production node methods and
uses the icon face factor from the draw code. The map still uses its existing
128×128 processed texture and mipmaps for section-map draws. That generated
texture is separate from the imported source allocations below.

## Per-icon load and source allocation

Godot 4.6.1 on arm64 macOS 26.3.1. Each timing is the median of 11 synchronous
main-thread imported loads with `CACHE_MODE_IGNORE` after one warm-up load.
Background QoS uses `taskpolicy -c background`. These headless timings measure
resource load and decode with a warm filesystem cache. Estimated VRAM is one
RGBA8 allocation per source with no mipmaps and applies to both QoS profiles.
Actual renderer allocations and visual equivalence require the owner's native pass.

| Icon | Desktop max (px) | Deck max (px) | Source dimensions | Normal (ms) | Background (ms) | Estimated VRAM (bytes) |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| `boss_iskaldra.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 17.292 → 1.077 | 37.995 → 1.845 | 6,290,064 → 331,776 |
| `boss_noctyrax.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 19.680 → 1.126 | 39.977 → 2.058 | 6,290,064 → 331,776 |
| `boss_tharokh.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 20.086 → 1.333 | 43.834 → 2.652 | 6,290,064 → 331,776 |
| `boss_vaeloryx.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 19.979 → 1.126 | 43.546 → 3.253 | 6,290,064 → 331,776 |
| `boss_vyraketh.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 19.543 → 1.182 | 43.657 → 3.353 | 6,290,064 → 331,776 |
| `boss_zekarion.png` | 141.00 × 141.00 | 120.08 × 120.13 | 1254x1254 → 288x288 | 19.575 → 1.149 | 47.005 → 2.202 | 6,290,064 → 331,776 |
| `campfire.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 20.706 → 0.459 | 43.874 → 0.825 | 6,290,064 → 102,400 |
| `event.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 12.346 → 0.475 | 25.187 → 0.880 | 6,290,064 → 102,400 |
| `fight.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 19.502 → 0.366 | 37.079 → 0.791 | 6,290,064 → 102,400 |
| `graftwright.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 7.896 → 0.360 | 15.790 → 0.766 | 6,290,064 → 102,400 |
| `lantern.png` | 129.36 × 129.36 | 110.17 × 110.21 | 1254x1254 → 288x288 | 19.787 → 1.041 | 44.635 → 1.725 | 6,290,064 → 331,776 |
| `last_light.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1024x1024 → 160x160 | 13.943 → 0.465 | 32.878 → 1.166 | 4,194,304 → 102,400 |
| `relic.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 19.443 → 0.507 | 42.404 → 1.078 | 6,290,064 → 102,400 |
| `scavenger.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1254x1254 → 160x160 | 18.683 → 0.506 | 39.611 → 1.207 | 6,290,064 → 102,400 |
| `scout.png` | 28.00 × 28.00 | 23.85 × 23.86 | 1254x1254 → 128x128 | 18.986 → 0.432 | 44.124 → 0.860 | 6,290,064 → 65,536 |
| `umbral_snare.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1024x1024 → 160x160 | 5.396 → 0.318 | 10.897 → 0.678 | 4,194,304 → 102,400 |
| `warband.png` | 73.71 × 73.71 | 62.77 × 62.80 | 1024x1024 → 160x160 | 4.155 → 0.271 | 11.333 → 0.472 | 4,194,304 → 102,400 |

Estimated source allocations total 100,643,808 → 3,309,568 bytes (95.98 → 3.16 MiB, 96.7% lower).

Every changed icon falls below the 600 px exception. The original 17 PNGs and
their measured draw sizes are archived under `assets/_masters/perf-155/`, along
with SHA-256 provenance. The resize script calls perf-153's linear-light
premultiplied-alpha Lanczos filter and writes to the original paths. Reimporting
all 17 preserves every sidecar byte for byte.

## Proof

Seed 7 covers all six bosses and all enabled special types. The probe surveys
each generated section without changing its room types or connections and
captures overlapping scroll pages. It also exercises peak activation seals,
the boss-sized current-room lantern and the legacy map at maximum zoom. The
headless capture records geometry and imported dimensions. Godot's dummy
renderer cannot supply screenshot pixels. JSON snapshots and raw timing logs
are in `.godot/perf155-proof/` in this worktree.

Run the native pair serially in this worktree. The baseline command temporarily
installs the archived sources and reimports them, then restores candidate
sources and caches. Each manifest lists the validated PNG paths.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-155 && python3 tools/perf155/visual_proof.py before --result-manifest .godot/perf155-proof/native-before.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-155 && python3 tools/perf155/visual_proof.py after --result-manifest .godot/perf155-proof/native-after.json
```

For headless reproduction, pass `--headless-geometry` instead of
`--result-manifest …`. The timing commands below measure the currently
installed cohort. The table uses the serial benchmark replay in
`matched-before.log` and `matched-after.log`. Use `--benchmark` with either
phase to reproduce it. Each phase imports its cohort and runs both QoS profiles,
and the baseline phase restores candidate textures after measurement.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-155 && python3 tools/godot_task_runner.py --task-id perf-155 --stream -- godot --headless --path . --script tools/perf155/texture_load.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-155 && taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-155 --stream -- godot --headless --path . --script tools/perf155/texture_load.gd
```
