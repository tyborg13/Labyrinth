# Labyrinth Performance Metric Contract

## Reproducibility

Keep these inputs identical between base and candidate:

- Git revision recorded for each side;
- OS, CPU/GPU, Godot version, renderer, and display driver;
- 1920×1080 viewport at 100% UI scale for the standard native proof;
- workload state, random seed, actor count, particle intensity, presentation data, warmup, and sample count;
- foreground/background state, frame cap, vsync behavior, and unrelated processes where controllable.

Discard shader compilation, initial asset import, and intentionally cold cache setup from steady-state phases, but measure cold paths separately when they are player-visible.

## Required Runtime Metrics

For each phase report:

- frame interval median, p95, p99, maximum, and mean;
- frames above 16.67 ms, 20 ms, and 33.33 ms;
- Godot process time;
- renderer draw calls, objects, and primitives;
- instrumented CPU time by render/refresh section;
- redraw, rebuild, cache-hit/miss, allocation, and node-churn counters relevant to the change;
- static memory, object count, node count, and orphan-node count.

Use frame intervals as the primary user-experience signal. Average FPS hides spikes.

## Workload Phases

At minimum include:

1. Populated idle: ambient effects, idle sheets, pickups, HUDs, and normal room geometry.
2. Interaction: hover, selection, paths, previews, tooltips, and input-driven updates.
3. Action-heavy: simultaneous actor impacts, projectiles/area effects, decals, preview overlays, damage HUD state, floating feedback, and maximum expected on-screen actors.
4. Cold transition: the relevant room, reward, map, save, or UI rebuild when the report includes transition stutter.

Caller-owned state snapshots must be distinct when testing explicit submissions. Mutating the board's retained dictionary in place can make change detection skip the very work the benchmark intends to measure.

## Comparison Rules

- Compare on the same machine and renderer first.
- Prefer repeated samples; report variance when results are noisy.
- Treat a regression greater than 5% in p95 frame interval, steady-state memory, or a directly affected hot-path metric as requiring explanation.
- Do not trade tail latency for a small mean improvement without explicit justification.
- Do not claim universal target-hardware performance from a single machine. Use slower target hardware for the final confidence pass whenever available.
- Visual or semantic changes fail the transparent-optimization requirement regardless of speedup.

## Machine-Readable Output

Print one successful JSON object on a unique marker line. Include a schema version, environment, phase names, semantic error list, and raw counters. Keep field names additive when evolving the schema so saved reports remain comparable.
