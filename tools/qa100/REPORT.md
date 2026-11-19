# qa-100 run lifetime

Release base `b23826c3a971554604c22d89310e6a752ff01b84`, Godot `4.6.1.stable.official.14d19694e`, macOS headless. The driver extends the existing run hunt and preserves its natural route selection, 9,999 probe Health, fastest combat, 8× scene clock, and no voluntary run endings. Section indices are zero-based.

The census records every settled room entry, the terminal screen, and the tree two process frames after the hunt queues RunScene for deletion. It records attached and detached nodes by native class and script path, total live objects, resources, and Godot-tracked static bytes. Detached rows also include node names. The final verbose engine log covers process exit after the tree census. Static bytes are whole-process Godot allocation telemetry. Native RSS and renderer residency were outside this headless measurement.

## Reproduce

Use a fresh evidence directory for each invocation. Run once with each of `seed=96101` and `seed=96109`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-100 && \
  seed=96101 && phase=repeat && evidence="$PWD/output/qa-100/$phase/seed-$seed" && \
  mkdir -p "$PWD/output/qa-100/$phase" && mkdir "$evidence" && \
  LABYRINTH_CEL_LOOK=off python3 tools/godot_task_runner.py --task-id qa-100 --timeout 4500 --stream -- \
    godot --headless --verbose --path . --script tools/qa100/lifetime_hunt.gd -- \
    --seed "$seed" --output-dir "$evidence" --no-embrace true > "$evidence/godot.log" 2>&1
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-100 && \
  python3 tools/qa100/room_tables.py output/qa-100/repeat
```

The table tool validates completion in section 5, checks that every inherited room event has a census row, and verifies that every per-type histogram sums to its counter. It writes `rooms.csv` and `node_types.csv` beside each raw `trace.jsonl` and `godot.log`. Evidence lives under the worktree's ignored `output/qa-100/` directory. The repeat probe also records cache entry counts; the original baseline logs have the shared room and type counters.

## Reproduction and ownership

Both release-base runs reached victory in section 5, with 72 room samples apiece. Godot reported one `GDScriptFunctionState` at each exit with reference count 1. Both logs also list the unclaimed names `play_exhaust` and `completed`. The corresponding hunt decisions are a confirmed Magic Purge followed by `leave_browse` calling `_close_magic_purge` while the burn is active. Seed 96101 does this at decisions 200–201 and seed 96109 at 939–940. The independent replay of seed 96101 stopped at decision 201 and reproduced the same leak, isolating it from the run end.

The suspended child is `scripts/magic_purge_overlay.gd::play_exhaust`, which was waiting on its scene-bound tween. Its caller is `scripts/run_scene.gd::_confirm_magic_purge`, reached via the overlay's `confirmed` signal. Detaching and deleting the overlay cancels the tween without emitting `finished`, leaving the caller waiting on the child coroutine's completion. The node census found zero detached nodes after each RunScene teardown.

The overlay now owns the tween and reports its completion from the existing finished signal. Its tree-exit handler kills any active tween and resolves the caller with cancellation. Normal completion still releases the sparks before resuming the caller. The existing burn and reduced-motion durations, successful Hearth and Scavenger continuations, checkpoint, analytics call and audio cue retain their original order.

| Phase | Seed | Result line | Exit evidence |
| --- | ---: | --- | --- |
| Baseline | 96101 | `RUN HUNT: seed=96101 outcome=victory decisions=3063` | `godot.log:4883–4891` |
| Baseline | 96109 | `RUN HUNT: seed=96109 outcome=victory decisions=3159` | `godot.log:5005–5013` |
| Short baseline | 96101 | `RUN HUNT: seed=96101 outcome=replay_point decisions=201` | `purge-before/seed-96101/godot.log:1171–1178` |
| Short fixed replay | 96101 | `RUN HUNT: seed=96101 outcome=replay_point decisions=201` | `purge-after/seed-96101/godot.log:1166`, no ObjectDB or leaked-instance marker |
| Normal completion | Scavenger fixture | `TEST RESULT: PASS` | `purge-completion/godot.log:1021` and `purge-completion/rects.json` |

The baseline runner returned 0 despite the verbose ObjectDB warnings. The raw shutdown messages are the leak evidence. The diagnostic `ERROR: Condition "ret != noErr" is true. Returning: ""` occurs at macOS certificate loading before the hunt opens RunScene. The engine loaded its built-in certificates and both runs continued.

The short fixed replay matched decisions 200–201 and still wrote the purge receipt. The normal completion fixture exercised the existing burn and reduced-motion fade at both supported fixture scales, including repeated input, one paid removal and overlay dismissal.

The two intermediate, Purge-only reruns also reached victory in section 5 and exited without an ObjectDB warning. Their result lines were `RUN HUNT: seed=96101 outcome=victory decisions=3049` and `RUN HUNT: seed=96109 outcome=victory decisions=3158`. Their room tables and logs are under `output/qa-100/after/`. Godot still listed the interned names `process_frame` and `BAYER` at verbose shutdown. Both names also appear in the short aim replays before any completed purge, and `BAYER` is the CPU quantization constant in `scripts/pixel_fx_layer.gd`.

## Board aim canvas retention

The native `Control` rows for `res://scripts/combat_board_view.gd` include active tile layers and per-actor aim canvases. The main board keeps three scene paint layers per rendered tile and retires layers for absent tiles. A separate issue was in `scripts/board_aim_focus.gd::route` and `route_top`. They create child canvases keyed by source instance, paint method and actor key. `begin_draw` hides unused children and `_update_canvases` forgets invalid references, but surviving source layers carried still-valid hidden children and their old draw state to subsequent rooms.

The board now releases those child canvases where it already retires room-owned surface layers. The source layers and the aim canvas reuse within a room keep their existing paths and timing. The focused seed 96109 replay uses the first guardian boundary at decision 169 to compare retention with and without the board fix. Evidence is under `aim-before/seed-96109/` and `aim-after/seed-96109/`.

| Decision | Room | Aim canvases alive before | Aim canvases alive after | Visible before and after |
| ---: | --- | ---: | ---: | ---: |
| 7 | Combat | 5 | 4 | 4 |
| 38 | Combat | 11 | 4 | 4 |
| 87 | Combat | 26 | 4 | 4 |
| 151 | Campfire | 32 | 4 | 4 |
| 165 | Treasure | 32 | 4 | 4 |
| 169 | Guardian | 32 | 4 | 4 |

Both replays printed `RUN HUNT: seed=96109 outcome=replay_point decisions=169`. The focused targeting audit printed `PTF09 FOCUSED: PASS (5566 checks, 0 failures)`. The board tooltip test printed `BOARD TILE TOOLTIPS: PASS checks=227 failures=0`, with warnings for missing glossary definitions `bramble` and `ice_pillar`. Logs are under `output/qa-100/checks/`.

## Intended retention and remaining footprint

- `card_widget.gd` keeps one active summary layout and at most four detached variants per card. The cache evicts old rows and frees the retained variants on `NOTIFICATION_PREDELETE`. Room-boundary orphan spikes consisted of `SummaryToken_*` subtrees, including their containers, labels and icons. These return to zero at subsequent boundaries or at scene teardown.
- `run_card_pool_lifetime.gd` bounds the hidden hand pool by the combat hand limit of seven. Its closed pile pool is bounded by the existing viewport and card layout calculation. An open pile owns the cards it is displaying. Each pool can expand from an empty cold start as the route first uses it.
- `combat_board_view.gd` retains three scene layers per tile of the current board. It retires removed tiles and their children. The extra `Node2D` rows using `pixel_fx_layer.gd` include per-painter hosts and room-owned surface feedback. `PixelFxLayer.finish` releases unused runs and their targets, and the room boundary retires the surface feedback. `Bone2D` and `Sprite2D` counts also move with the active or prepared encounter roster. Labels and texture controls include the warmed card pools and current overlays.
- `asset_loader.gd` owns a process-wide texture cache keyed by asset path, plus audio and derived-asset caches. Authored paths bound the texture and audio identity sets in these routes. Generated-texture alpha bounds and polygons use source-lifetime guards. The remaining static bytes include asset warming and other Godot allocations. The totals alone cannot apportion bytes to a specific cache.

For a lower Steam Deck memory ceiling, the larger follow-up is a residency profiling pass and a cache-policy change. Attribute decoded texture, audio and text allocations first, then give the largest shared cache a byte budget with current-scene and next-encounter assets pinned. Validate eviction against consecutive runs, room entry and resume hitches on the native renderer. Estimate one profiling unit and one implementation unit.

Selected section-entry type counts are ordered from section 0 through section 5. The board script row counts all attached instances of that script. The aim census counts its specific child canvas owners.

| Seed | Native type and script | Before | After both fixes |
| ---: | --- | --- | --- |
| 96101 | Control · combat_board_view.gd | 184, 311, 266, 308, 374, 312 | 184, 280, 258, 280, 280, 280 |
| 96109 | Control · combat_board_view.gd | 184, 319, 363, 381, 320, 307 | 184, 280, 280, 280, 280, 280 |
| 96101 | Node2D · pixel_fx_layer.gd | 0, 72, 78, 72, 80, 56 | 0, 72, 78, 72, 80, 56 |
| 96109 | Node2D · pixel_fx_layer.gd | 0, 77, 92, 96, 48, 82 | 0, 75, 92, 95, 48, 82 |
| 96101 | Button · card_widget.gd | 0, 15, 14, 15, 15, 15 | 0, 15, 14, 15, 15, 15 |
| 96109 | Button · card_widget.gd | 0, 16, 18, 18, 16, 15 | 0, 16, 18, 18, 16, 15 |
| 96101 | Label | 181, 279, 244, 321, 318, 358 | 181, 279, 244, 321, 318, 358 |
| 96109 | Label | 181, 294, 301, 373, 355, 333 | 181, 294, 301, 373, 355, 333 |
| 96101 | Bone2D | 66, 55, 55, 55, 55, 99 | 66, 55, 55, 55, 55, 99 |
| 96109 | Bone2D | 66, 60, 55, 104, 99, 55 | 66, 60, 55, 104, 99, 55 |

| Seed | Section 5 entrance | Attached | Orphans | Objects | Resources | Static bytes |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 96101 | Before | 3,004 | 0 | 23,594 | 1,572 | 1,413,269,769 |
| 96101 | After | 2,972 | 0 | 22,944 | 1,571 | 1,399,443,477 |
| 96109 | Before | 2,795 | 0 | 22,949 | 1,587 | 1,454,360,005 |
| 96109 | After | 2,768 | 0 | 22,406 | 1,586 | 1,437,513,198 |

## Final verification

Both full reruns with both fixes reached victory in section 5 and validated 72 room rows each. The runner returned 0 for both. The verbose logs contain zero ObjectDB warnings and zero leaked-instance records. The two interned string names noted above still appear.

| Seed | Exact result | Peak attached before → after | Peak static bytes before → after | Final log |
| ---: | --- | ---: | ---: | --- |
| 96101 | `RUN HUNT: seed=96101 outcome=victory decisions=3049` | 3,830 → 3,786 | 1,459,506,128 → 1,445,616,386 | `after-all/seed-96101/godot.log:4860` |
| 96109 | `RUN HUNT: seed=96109 outcome=victory decisions=3158` | 4,895 → 4,868 | 1,569,939,120 → 1,527,358,145 | `after-all/seed-96109/godot.log:4997` |

The census observed at most six aim canvases alive at a room boundary in either final run and four at each warmed section entrance. Each final run also observed maxima of seven hidden hand entries and twelve pile entries, matching the measured closed-pile limit of twelve at 1920×1080. The room counts and bounds support the room-scoped fix. The seeded policy made different numbers of decisions in the reruns, so whole-run peaks compare observed ranges across the same seeds.

| Seed | Final phase | Attached | Orphans | Objects | Tracked static bytes | Texture cache entries |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 96101 | Victory | 2,898 | 22 | 22,745 | 1,314,959,824 | 2,623 |
| 96101 | RunScene freed | 12 | 0 | 10,444 | 1,080,817,683 | 2,623 |
| 96109 | Victory | 3,304 | 38 | 23,552 | 1,344,843,601 | 2,678 |
| 96109 | RunScene freed | 13 | 0 | 10,574 | 1,115,810,730 | 2,678 |

Both texture caches started at 627 entries. The remaining tracked bytes measure whole-process allocations while those caches are still warm. The final after tables and full logs are under `output/qa-100/after-all/` and the baseline evidence is under `output/qa-100/before/`.
