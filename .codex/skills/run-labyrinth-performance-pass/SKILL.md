---
name: run-labyrinth-performance-pass
description: Profile, optimize, and verify Escape the Umbra runtime performance without changing gameplay, animation cadence, visual quality, input behavior, or player-facing experience. Use for broad optimization passes, frame drops, poor frame pacing, rendering hot spots, runtime allocation or rebuild costs, performance regressions, native Godot benchmarks, or base-versus-candidate performance proof.
---

# Run Labyrinth Performance Pass

## Purpose

Turn reported frame drops into reproducible workloads, measured hot spots, transparent code changes, and durable regression tooling. Preserve the current experience exactly; performance work is not permission to remove effects, lower update rates, reduce animation smoothness, simplify assets, change rules, or hide work behind lower quality.

## Establish the Task

Use `$parallel-labyrinth-task` for substantive implementation and follow its contract, preflight, proof, review, fixture, and publication gates. Run `memento brief` for the expected paths before editing.

Record these acceptance criteria in the task contract:

- A repeatable workload reproduces idle, interaction, animation, and action-heavy behavior.
- Metrics cover frame intervals and tail latency, not only average FPS.
- Every optimization is tied to profiler evidence.
- Gameplay state, presentation semantics, visual order, animation cadence, input, and asset quality remain unchanged.
- Base and candidate use the same viewport, renderer, workload, duration, warmup, and machine state.
- Native 1920×1080 at 100% UI scale visual proof is inspected.
- The full risk-tier test breadth passes.

Read [references/metric_contract.md](references/metric_contract.md) before authoring a new benchmark or interpreting a comparison.

## Profile Before Editing

Inspect prior performance work and instrumentation before adding parallel systems:

```bash
git log --all --oneline --grep='perf\|optim'
rg -n 'Performance\.|Time.get_ticks_usec|PERF RESULT|instrumentation|benchmark' scripts tests tools spec
```

Capture the base revision before implementation. From the matching isolated base worktree, run:

```bash
python3 tools/performance_pass.py run \
  --task-id <task-id>-base \
  --native \
  --output /tmp/<task-id>-base.json
```

Native probes need a real renderer. Use `tools/visual_probe_runner.py` through the wrapper; do not infer render performance from headless/dummy-driver results. Keep raw report paths in the task notes.

Build a workload map before choosing changes:

- idle board with ambient and sprite animation;
- pointer/selection/preview interaction;
- explicit presentation submissions such as projectiles and impacts;
- maximum expected units, particles, HUDs, decals, loot, terrain, and effects;
- map, save, reward, or other non-combat flows when the report implicates them.

Use section timers and redraw/rebuild counters to narrow expensive work. Instrumentation must be cheap when active, resettable between phases, and report machine-readable JSON.

## Optimize Transparently

Prefer eliminating unnecessary work over performing visible work less often. Typical safe targets include:

- retained render layers invalidated only by data they consume;
- cached layout, geometry, signatures, texture regions, and derived presentation data;
- batched draw geometry that preserves original sprite order and blending;
- indexed lookup instead of repeated full-array scans;
- bounded allocation, logging, and node churn;
- cold-path work moved out of per-frame code;
- duplicate redraw, refresh, save, or preview submissions removed.

Do not accept any of the following as an optimization unless the user explicitly changes the product requirement:

- fewer animation frames or a lower animation/update cadence;
- culled visible effects, particles, units, HUD details, or feedback;
- reduced resolution, texture quality, antialiasing, lighting, or visual density;
- delayed input, stale previews, hidden state changes, or altered rules;
- reordered alpha-blended art that changes the rendered composition;
- benchmarks that mutate retained caller snapshots or otherwise skip real work.

When player-facing UI code is touched, also use `$create-labyrinth-ui`. State the surface, player question, action, hierarchy, preserved inputs, and proof states before editing.

## Measure Each Candidate

Change one evidence-backed area at a time and rerun the focused workload. Revert experiments that move cost without improving frame pacing, compromise equivalence, add unstable renderer errors, or increase memory disproportionately.

After a viable candidate, capture the same structured report:

```bash
python3 tools/performance_pass.py run \
  --task-id <task-id>-candidate \
  --native \
  --output /tmp/<task-id>-candidate.json

python3 tools/performance_pass.py compare \
  /tmp/<task-id>-base.json \
  /tmp/<task-id>-candidate.json
```

Interpret medians together with p95/p99/max and threshold misses. A lower average with worse tail latency is not automatically an improvement. Call out hardware and renderer explicitly; do not generalize one machine's absolute FPS to every target.

## Prove Equivalence and Stability

Run focused semantic tests, rendering-equivalence probes, and the full suite required by the task risk tier. For rendering changes, capture fresh native 1920×1080 screenshots for at least:

- idle populated gameplay;
- selected/hovered interaction;
- active effect or impact;
- the maximum-content stress workload.

Inspect the images, not only file dimensions. Check sprite and alpha order, particle density, animation state, HUD placement, tooltips, selection/focus, text, icon identity, and edge clipping. Exercise every elemental or content variant whose batching/atlas/cache path differs.

The benchmark itself must assert semantic errors are empty, object/node counts remain bounded, orphan nodes are zero, and retained-layer or cache invariants expected by the optimization are active.

## Finish the Pass

Commit the benchmark, comparison tooling, tests, and documentation with the optimization. Record only durable non-obvious findings with `memento record`. Obtain independent peer-review signoff, create the verified task-local inspection fixture, and wait for user inspection before publication as required by `$parallel-labyrinth-task`.

In the handoff, lead with:

- the reproducible bottleneck;
- base-versus-candidate median and p95 frame time;
- frames over 16.67 ms and 33.33 ms;
- draw/rebuild/allocation changes;
- memory and node deltas;
- semantic, test, and visual proof;
- remaining risks and which hardware was actually measured.

