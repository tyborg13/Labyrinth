# Board surface presentation

The owning mechanics are in [DESIGN.md](DESIGN.md). `BoardSurfacePresentation` draws persistent floor treatment; `CombatBoardView` owns visibility and perspective depth. Each patch renders in the tile pass before props and actors. The user explicitly requires detailed **procedurally drawn, hand-animated** surfaces that match the procedural elemental attacks. The material identities are sheets of fractured Ice, crackling electrical ground, tongues of Fire and blocky stone Rubble. The user explicitly confirmed that the procedural effects themselves should be hand-animated. Imported floor illustrations and raster animation sheets are not part of this renderer.

The materials reuse `ElementalSpellFx`'s procedural cloud field, feathered light and shaded fragments. Fire combines an ember bed, overlapping hot/cooling volumes and broad asymmetric rooted contours following Bézier folds with deliberately staged gather, climb, curl and tip-shedding beats. Pockets use different phase offsets so a field does not pulse in unison. Ice is an irregular Voronoi-fractured sheet with a chipped perimeter, overlapping translucent shaded plate thickness, mineral/frost detail and restrained reflected glints; it stays physically still. Rubble uses substantial chipped multi-face blocks, smaller gravel and contact shadows. The matte grain is a deterministic noise field generated once in code, like the existing spell clouds, not a raster floor asset. Electricity has a full forked network, a soft ionized substrate and a traveling bright front followed by a brief flash/decay. Reduced motion freezes the supplied presentation clock while retaining every material layer.

Rubble itself remains still: rocks need material depth and stable placement rather than an unrelated idle wobble. Elemental overlays remain visually independent, including mixed Rubble and elemental ground. A surface may disappear only when its rules remove or consume it; changes of art or idle phase do not alter combat state.

Fresh Ice is visible ground, while active Chilled is an actor badge. The authoritative hover resolver previews ground creation/consumption, status changes and damage, including automatic prior-impact Detonate. Its blast area is displayed once across the union. Preview computation never emits analytics. Movement paths that enter or leave ground use the full resolver so entry damage, departure from Ice, and Rubble cost remain exact. If a trap creates Rubble during a walk, the animation uses the original route only through the committed endpoint, preserving corners and stopping before the unaffordable tile.

Shared damage previews include player and illusion HP, Block, Stoneskin and lethal exposure. Explicit friendly labels sit above their actor HUDs, avoid adjacent health bars and remain within the viewport. Preview simulation starts from committed visible information, removing hidden traps, ground and enemies before they can create misleading damage or a visible wake. An opaque-enemy marker prevents missing unknown enemies from manufacturing a forecast victory; committed action state remains separate.

The action-step strip applies the same damage modifiers as the card and resolver. Its selected prefix is replayed from known information; unresolved steps forecast sequential one-use bonuses without inventing hits or health changes. Skipped or unavailable attacks preserve their bonus, and targeted placeholders retain their slot. During animation, each current step uses its actual pre-state while completed values stay fixed. Fresh native scenes show Rekindle Edge’s 17→15 strip matching its card and shared 15-damage preview.

Prismatic Instinct and Confluence use `SurfaceAimFlow` behind the existing Abilities entry. Ground/layer buttons, cancellation, source selection and destination selection share mouse and controller paths. Relic techniques stay in the original card aiming controls. Command buttons wrap at three columns and avoid the raised card. Cross and Worldroot are mutually exclusive; the latest selection wins. A prior-impact Detonate's optional Rubble fuel choice is shown before the initiating attack commits.

Board right-click/B routes active terrain aiming through contextual cancellation, including Confluence after selecting a source. Cancellation clears the selection without spending the ability. Detonate shares the card's direct-attack damage-display path, including conditional bonuses and preview modifier consumption. Native release-review captures exercise these paths; a Bloodglass-active Rekindle Edge displays its adjusted Detonate value alongside its adjusted melee value.

`ChainAttackFeedback` consumes resolver traces. Native AoE victims share the initial cast beat. A contiguous electrical component shares one discharge beat and follows the resolver's cardinal paths on the floor. Actor hops and short empty-floor relays have distinct beats. Reserved ground remains visible until the appropriate contact. Damage text continues on the existing timeline without a final wait. Ordinary AoE traces never invent Chain feedback.

Committed `surface_events` are flushed through RunScene persistence, player action/movement, enemy phase and combat outcome paths. Deduplication uses combat ID plus monotonic event sequence, including across resume. Payloads retain source metadata and use rules version 4. The bounded event tail is compared by sequence; it is never treated as one action's entire history.

## Repeatable verification

Run commands from the isolated task worktree. Use its real task ID if different from this refactor's ID.

```sh
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tests/board_surface_presentation_test.gd
python3 tools/godot_task_runner.py --task-id board-surface-refactor --stream -- godot --headless --path . --script tests/board_surface_probe_migration_test.gd
python3 tests/test_icon_identity_policy.py
python3 tools/visual_probe_runner.py tests/board_surface_visual_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 22 --result-manifest output/board-surface-refactor/visual-proof-final.json
python3 tools/visual_probe_runner.py tests/board_surface_loop_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 49 --result-manifest output/board-surface-refactor/surface-loop-proof.json
python3 tools/visual_probe_runner.py tests/board_surface_dense_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/dense-surface-proof.json
python3 tools/visual_probe_runner.py tests/relic_damage_feedback_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 4 --result-manifest output/board-surface-refactor/relic-feedback-proof.json
```

The main probe covers mixed ground, fresh Ice versus Chilled, skill mouse/controller choices, composable relic commands, mutual exclusion, previous-impact Detonate, consumption, empty-floor relays and contiguous conduction. The loop probe produces 48 native frames at a deterministic 24 fps presentation clock. Encode `loop/frame_%03d.png` with the existing ffmpeg tooling for motion review; keep the native PNGs as renderer evidence. The relic probe checks damage split through Block/Stoneskin and paid cross geometry in normal and reduced motion.

The retained ambient probes and benchmarks now use room affinity plus sparse ground fields. Intensity-dependent hand glow checks were retired; live clock animation and pixel comparisons of retained rendering remain covered. Performance workload changes should be compared against this new ground-based fixture baseline, not old all-element ambient-density results.

## Earlier retained-ground baseline (superseded art)

The first retained-ground optimization, before the user requested the detailed material revision above, kept its original vector resolution, texture sampling, animation formulas and existing presentation cadence. Immutable Rubble commands and Ice geometry live in children of the owning perspective tile. Ice updates only its original alpha variation. Fire retains the original textured puffs, glow and embers as sprites in the original painter order; its nine-point tongues retain their live geometry. Ribbon topology, taper values and textured-quad indices are shared. Electrified and conductive Fire overlays keep their original floor order. No frame skipping, raster downsampling or motion simplification was introduced.

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

## Detailed procedural material proof

`tests/board_surface_material_probe.gd` is the repeatable art fixture. It exposes unoccupied Fire, Ice, Electrified and Rubble, all three elemental/Rubble combinations, a separate Stormcoal view, and a 2×2 dragon footprint over mixed ground. Normal and reduced-motion captures use the real 1920×1080 renderer at 100% UI scale. Its 96 frames advance an explicit 24 fps presentation clock over four seconds, covering complete Fire and electrical cycles without relying on wall-clock timing.

```sh
python3 tools/visual_probe_runner.py tests/board_surface_material_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 100 --timeout 90 --result-manifest output/board-surface-refactor/material-procedural-proof.json
```

The matched pre-revision dense measurement is `material-dense-before.json` (72 elemental tiles, 36 additional Rubble layers, five actors, full HUD). It measured normal median 8.009 ms / p95 20.575 ms and reduced median 8.343 ms / p95 8.938 ms on the current Mac. The first fuller material implementation (`material-procedural-dense-01.json`) exposed an unacceptable 62.379 ms / 63.311 ms normal result with 23,207 draw calls. That failed candidate is retained as diagnostic evidence, not accepted performance. The retained electrical geometry and ordered static batching described below resolve that failed candidate’s large regression while keeping the richer material shapes.


The detailed materials keep their geometry in the owning tile's retained children. Fire retains the attack-style noise and light particle topology while its authored filled contours advance on the board's supplied clock. Electrical strips retain their topology and use that same clock, including the fixed reduced-motion phase; no independent shader `TIME` drives them. Width/seed changes invalidate both Ice's plates and its shimmer even when the phase is unchanged.

Static Ice and Rubble aggregate consecutive shaded polygons with their mineral grain in `BoardSurfaceStaticBatch`. A 128×128 runtime atlas contains only the code-generated 64×64 noise field and a white sampling area. Every plate, face, chip and grain polygon retains its original vertices, triangulation, alpha and painter order. The batch flushes before native antialiased lines, shadow lights and the existing spell fragments. This is submission batching, not a flattened picture of a floor tile. `retained_static_batch_enabled = false` (or `LABYRINTH_SURFACE_STATIC_BASE=1` in the dense probe) preserves the unbatched comparison path.

`tests/board_surface_static_equivalence_probe.gd` compares four sets of fractional tile positions, two widths and varied seeds using the real 4×MSAA renderer. `static-material-equivalence-pixels-01.json` passes the unchanged guard: 0–4 pixels above 2/255 per pair, maximum 4/255 and mean channel error at most 0.0000144 in 0–255 units. The electrical and whole-board comparisons must also use the actual board's 4×MSAA and tile-local drawing convention; an earlier standalone electrical probe omitted MSAA and therefore did not provide sufficient evidence for the real board.

```sh
python3 tools/visual_probe_runner.py tests/board_surface_static_equivalence_probe.gd --project . --task-id board-surface-refactor --no-headless --expect-size 1920x1080 --min-images 8 --timeout 60 --result-manifest output/board-surface-refactor/static-material-equivalence.json
python3 tools/check_board_surface_cache_proof.py output/board-surface-refactor/static-material-equivalence.json --output output/board-surface-refactor/static-material-pixels.json
```


The intermediate static-batch isolation pair used identical material code, with only the static batching flag changed. It predates the final exact-quad particle renderer and is not the final runtime performance result. `static-batched-dense-base-01.json` and `static-batched-dense-01.json` contain the native runner receipts; copied screenshots and raw `dense_timing.json` reports are in `material-final/dense-unbatched/` and `material-final/dense-final/`.

| Detailed materials | Motion | Median frame interval | p95 | Maximum | Frames over 20 ms / 33.33 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| Retained, static polygons unbatched | Normal | 26.421 ms | 28.301 ms | 28.719 ms | 90 / 0 |
| Retained, static polygons batched | Normal | 8.223 ms | 23.515 ms | 25.842 ms | 60 / 0 |
| Retained, static polygons unbatched | Reduced | 10.783 ms | 12.591 ms | 13.857 ms | 0 / 0 |
| Retained, static polygons batched | Reduced | 8.338 ms | 8.581 ms | 9.577 ms | 0 / 0 |

Native draw calls fall from 20,490 to 10,664; Godot static memory falls from 233.1 MB to 183.7 MB. Both have 3,365 nodes and zero orphan nodes. The candidate has 7,426 objects, including the one shared runtime atlas. This intermediate Sprite2D candidate returned near the earlier simpler art's 8.009 ms median, but it failed the later full-board MSAA fidelity guard. Its 8.223 ms median must not be reported as the final renderer result. These are idle stress-scene intervals on the current Mac with vsync and scheduling, not a fixed framerate guarantee or certification of other hardware. As in the earlier baseline, the coarse `process_ms` monitor includes stale readback/setup values and is not used as a per-frame CPU result.

`material-procedural-04.json` validates all 100 native images with no drawing errors. `material-final/` contains the clear-material, reduced-motion, Stormcoal and large-footprint stills, the four-second `material-loop.mp4`, and a diagnostic contact sheet. The frame sequence was inspected at multiple points through the cycle: Fire gathers and curls into changing filled silhouettes, Electrical fronts and branches reconfigure, and Ice/Rubble remain physically fixed. The large footprint covers the ground correctly; the separate furnished-save proof covers props and normal actors. These are local inspection artifacts, not Steam publication or trailer replacement.


For the detailed materials, `BoardSurfaceParticle` preserves the procedural renderer's exact four-corner order and tile-local arithmetic for Fire and Electrical light/cloud quads. This matters where transparent shapes overlap under 4×MSAA: native sprite quads use a different interpolation path. Each original electrical ribbon/core command also retains its own mesh surface so MSAA keeps the reference's blend boundaries. Both fixes preserve the authored geometry, texture sampling, material layers and timing; they do not relax the comparison threshold.

The final complete 72-tile board passes the unchanged guard in normal and reduced motion at both supplied clocks (`combined-one-frame-cache-final-01.json` / `combined-one-frame-cache-final-pixels-01.json`): maximum error 4/255, mean channel error at most 0.00004694 in 0–255 units, and 8–10 pixels above 2/255 in a 2,073,600-pixel image. Twelve replacement, consumption, visibility and room transitions restore exactly 2,357 board-subtree nodes on every cycle; the same-phase Ice width/seed invalidation checks pass. The focused presentation suite also exercises the unchanged UI, aiming, analytics and feedback rules.


The final particle helper shares one immutable four-vertex mesh. Its per-instance shader uniforms receive the exact CPU-calculated corners and tint; no shader rotation approximates those corners, and there is no independent shader clock. Uniform updates leave the native draw command resident. An intermediate exact-quad callback implementation rebuilt vertex buffers and measured 38.302 ms normal median; it was discarded. Repeated explicit redraw requests were also removed because they were unnecessary for resident mesh uniforms.

The final native comparison captures each direct/cached clock after **exactly one rendered frame**, following initial fixture layout settling. This proves actual visible uniform updates rather than a revision counter assigned during configuration. All four normal/reduced image pairs pass. Four additional one-frame clocks check Fire tongues' actual drawn phases; pinned-phase Ice resize/reseed and all 12 visibility/consumption/replacement/room cycles pass. `material-presentation-final.log` records the final frozen-source focused presentation suite PASS.

The final 72-tile receipt is `combined-uniform-dense-final-01.json`, with raw timing and four native frames copied into `combined-uniform-dense-final-01/`. Source hashes match before and after the measurement. This includes the exact particle quads and preserved electrical command boundaries and supersedes the earlier Sprite2D and callback prototypes.

| Final detailed renderer | Mean frame interval | Reported upper median | p95 | Maximum | Frames over 20 ms / 33.33 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal motion, 72 elemental + 36 Rubble | 17.979 ms | 25.687 ms | 26.965 ms | 27.887 ms | 90 / 0 |
| Reduced motion, same board | 8.356 ms | 8.325 ms | 9.424 ms | 15.198 ms | 0 / 0 |

Normal mode has exactly 90 faster and 90 slower intervals, with 90 of 180 above 16.67 ms; the harness reports the upper middle sample as its median, consistently with the earlier receipts. This crowded case is not a steady 60 fps result. It uses 14,203 draw calls, 3,365 nodes, zero orphan nodes and approximately 203.6 MB of Godot static memory. The initial detailed-material failure's 62.379 ms median/63.311 ms p95 is resolved, but the final renderer retains the measured 27 ms stress-case tail. No art, resolution, antialiasing or supplied-clock animation was reduced to obtain these results.


A separate practical-density measurement uses the same harness, HUD, five actors, 60-frame warmup and 180 samples, with eight Fire, eight Ice and eight Electrified tiles plus 12 Rubble layers (16 conducting tiles with Stormcoal). It is explicitly a different workload, `shared_surfaces_24_elemental_12_rubble_live_hud_v1`, and must not replace the 72-tile matched stress comparison.

| Final renderer, 24 elemental + 12 Rubble | Mean | Reported upper median | p95 | Maximum | Frames over 16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal motion | 8.334 ms | 8.240 ms | 10.388 ms | 14.148 ms | 0 / 180 |
| Reduced motion | 8.328 ms | 8.330 ms | 8.500 ms | 8.657 ms | 0 / 180 |

This case has 5,079 draw calls, 1,949 nodes, zero orphan nodes and approximately 157.2 MB static memory. Its receipt is `material-24-tile-timing-final-01.json`; the isolated fixture source is retained at `output/board-surface-refactor/board_surface_24_tile_probe.gd`. It demonstrates the practical-density cost on this Mac without claiming a framerate guarantee on other hardware. `MATERIAL_PROOF_INDEX.json` indexes the final image, pixel, motion and timing receipts. Final standalone electrical proof (`electric-native-final-02.json` / `electric-native-final-pixels-02.json`) differs by at most 1/255 and has zero pixels over 2/255.
