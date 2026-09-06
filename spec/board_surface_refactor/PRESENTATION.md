# Board surface presentation

The owning mechanics are in [DESIGN.md](DESIGN.md). `BoardSurfacePresentation` draws persistent floor treatment; `CombatBoardView` owns visibility and perspective depth. Each patch renders in the tile pass before props and actors. Fire reuses the spell renderer's feathered heat ribbons and textured volume. Ice uses a translucent slab, cracks and shaded frost-edge fragments. Rubble is stable, shaded debris. Electrified uses low animated filaments; Stormcoal overlays them on the actual Fire layer. Reduced motion freezes idle variation.

Fresh Ice is visible ground, while active Chilled is an actor badge. The authoritative hover resolver previews ground creation/consumption, status changes and damage, including automatic prior-impact Detonate. Its blast area is displayed once across the union. Preview computation never emits analytics. Movement paths that enter or leave ground use the full resolver so entry damage, departure from Ice, and Rubble cost remain exact. If a trap creates Rubble during a walk, the animation uses the original route only through the committed endpoint, preserving corners and stopping before the unaffordable tile.

Prismatic Instinct and Confluence use `SurfaceAimFlow` behind the existing Abilities entry. Ground/layer buttons, cancellation, source selection and destination selection share mouse and controller paths. Relic techniques stay in the original card aiming controls. Command buttons wrap at three columns and avoid the raised card. Cross and Worldroot are mutually exclusive; the latest selection wins. A prior-impact Detonate's optional Rubble fuel choice is shown before the initiating attack commits.

`ChainAttackFeedback` consumes resolver traces. Native AoE victims share the initial cast beat. A contiguous electrical component shares one discharge beat and follows the resolver's cardinal paths on the floor. Actor hops and short empty-floor relays have distinct beats. Reserved ground remains visible until the appropriate contact. Damage text continues on the existing timeline without a final wait. Ordinary AoE traces never invent Chain feedback.

Committed `surface_events` are flushed through RunScene persistence, player action/movement, enemy phase and combat outcome paths. Deduplication uses combat ID plus monotonic event sequence, including across resume. Payloads retain source metadata and use rules version 4. The bounded event tail is compared by sequence; it is never treated as one action's entire history.

## Repeatable verification

Run commands from the isolated task worktree. Use its real task ID if different from this refactor's ID.

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tests/board_surface_presentation_test.gd
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tests/board_surface_probe_migration_test.gd
python3 tests/test_icon_identity_policy.py
python3 tools/visual_probe_runner.py tests/board_surface_visual_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 18 --result-manifest output/board-surface-refactor/visual-proof-final.json
python3 tools/visual_probe_runner.py tests/board_surface_loop_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 49 --result-manifest output/board-surface-refactor/surface-loop-proof.json
python3 tools/visual_probe_runner.py tests/board_surface_dense_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/dense-surface-proof.json
python3 tools/visual_probe_runner.py tests/relic_damage_feedback_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/relic-feedback-proof.json
```

The main probe covers mixed ground, fresh Ice versus Chilled, skill mouse/controller choices, composable relic commands, mutual exclusion, previous-impact Detonate, consumption, empty-floor relays and contiguous conduction. The loop probe produces 48 native frames at a deterministic 24 fps presentation clock. Encode `loop/frame_%03d.png` with the existing ffmpeg tooling for motion review; keep the native PNGs as renderer evidence. The relic probe checks damage split through Block/Stoneskin and paid cross geometry in normal and reduced motion.

The retained ambient probes and benchmarks now use room affinity plus sparse ground fields. Intensity-dependent hand glow checks were retired; live clock animation and exact static raster-cache equivalence remain covered. Performance workload changes should be compared against this new ground-based fixture baseline, not old all-element ambient-density results.

## Retained ground rendering and performance proof

The floor keeps the original vector resolution, texture sampling, animation formulas and existing presentation cadence. Immutable Rubble commands and Ice geometry live in children of the owning perspective tile. Ice updates only its original alpha variation. Fire retains the original textured puffs, glow and embers as sprites in the original painter order; its nine-point tongues retain their live geometry. Ribbon topology, taper values and textured-quad indices are shared. Electrified and conductive Fire overlays keep their original floor order. No frame skipping, raster downsampling or motion simplification was introduced.

`BoardSurfacePresentation.retained_cache_enabled = false` retains the original drawing path for comparison. `LABYRINTH_SURFACE_CACHE_BASE=1` selects it in the dense probe. Cached children are hidden on replacement, consumption and loss of visibility, and are freed with their owning tile when room geometry changes. This costs additional bounded nodes in exchange for avoiding repeated draw-command construction.

The matched native fixture fills all 72 interior tiles with 24 Fire, 24 Ice and 24 Electrified patches, with Rubble on 36 tiles and conductive Fire enabled. Five actors and the full HUD remain present. Both modes use 60 warmup frames and 180 measured frame intervals. PNG readback occurs after each timed window. The September 6, 2026 result used Godot 4.6.1, Metal Mobile on an Apple M5 Pro at 1920×1080 and 100% UI scale.

| Ground renderer | Motion | Median frame interval | p95 | Maximum | Frames over 20 ms / 33.33 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| Original | Normal | 62.557 ms | 64.372 ms | 67.807 ms | 180 / 180 |
| Retained, candidate 4 | Normal | 7.985 ms | 19.920 ms | 21.131 ms | 7 / 0 |
| Original | Reduced | 8.317 ms | 10.747 ms | 12.534 ms | 0 / 0 |
| Retained, candidate 4 | Reduced | 8.332 ms | 8.741 ms | 9.196 ms | 0 / 0 |

The normal-mode candidate mean is 10.507 ms; 45 of 180 samples exceed 16.67 ms. This deliberately crowded board still has a roughly 20 ms tail. These are current-Mac idle frame intervals including vsync and scheduling, not a steady 120 fps promise, a Windows certification or an action-heavy gameplay benchmark. The final fixture has 2,861 scene nodes, 6,862 objects, no orphan nodes and about 165.9 MB of Godot static memory. The first baseline did not collect those resource monitors, so it does not support a matched memory comparison.

Use `frame_interval_ms` for this comparison. The diagnostic `process_ms` field samples Godot's coarsely refreshed `Performance.TIME_PROCESS` monitor, which can repeat stale setup or screenshot-readback values across many sampled frames. Its 478 ms normal and 375 ms reduced peaks are not isolated per-frame CPU measurements of this window. They are preserved in the raw report for transparency and are excluded from the performance conclusion. Instrumented layer totals separately show normal scene-tile command work falling from 8,020,516 to 643,918 microseconds across the respective 180-frame windows.

Native comparisons cover the original and retained renderer at two identical clocks in both motion modes. The images are not byte-identical: 8–17 of 2,073,600 pixels differ by more than 2/255 in a channel, with a maximum of 13/255 and a whole-image mean channel error of 0.000057–0.000071 in 0–255 units. Inspection places these differences at isolated antialiased edges from native transform arithmetic; shape, texture detail, color, layering and timing remain intact. The reusable inspector requires at least 99.999% of pixels within 2/255 per channel, maximum error at most 16/255, and mean error at most 0.0001 in 0–255 units.

The native probe also advances four clocks and verifies, after a single rendered frame, that every visible Fire tongue's actual drawn phase equals its sibling sprites' configured phase. Twelve replacement, Rubble-consumption, visibility and room-size transition cycles restore exactly 1,888 board-subtree nodes every time. Normal/reduced toggles and four paired screenshots pass; no stale retained ground or growing cache was found. The final 48-frame motion loop was regenerated and inspected after the cache changes.

```sh
LABYRINTH_SURFACE_CACHE_BASE=1 python3 tools/visual_probe_runner.py tests/board_surface_dense_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/dense-surface-base.json
python3 tools/visual_probe_runner.py tests/board_surface_dense_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/dense-surface-candidate.json
python3 tools/visual_probe_runner.py tests/board_surface_cache_equivalence_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 8 --timeout 60 --result-manifest output/board-surface-refactor/surface-cache-equivalence.json
python3 tools/check_board_surface_cache_proof.py output/board-surface-refactor/surface-cache-equivalence.json --output output/board-surface-refactor/surface-cache-pixel-check.json
```

Final task evidence lives under `output/board-surface-refactor`: `dense-surface-proof.json` and `dense-base/` hold the original measurement; `dense-surface-candidate-04.json` and `dense-final/` hold the accepted measurement. `surface-cache-equivalence-final.json`, `cache-proof-final/` and `surface-cache-pixel-check.json` hold the native comparisons and transition proof. `surface-loop-cache-final.json` records the post-cache loop, and `final-presentation/` contains the selected native scenes, dense normal/reduced frames and `surface-loop.mp4`. These local artifacts are reproducible proof, not new Steam trailer footage or publication approval.
