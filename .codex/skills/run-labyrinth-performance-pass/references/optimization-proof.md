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

Keep these measurements distinct in reports and conclusions:

- input-handler latency: synchronous work before the handler returns;
- rendered frame interval: player-visible frame pacing after input and during animation;
- action completion: total awaited gameplay/animation duration, which is not itself a hitch.

Screenshot capture is proof tooling, not game work. Synchronous viewport readback and PNG encoding must be excluded from gameplay frame samples while the screenshots remain in the run. For animated action proof, finish all samplers and completion timers, replay the same public-input action, and capture that untimed replay; excluding the capture frame is insufficient because GPU readback can stall later frames. Use section timers and threshold-frame diagnostics to separate CPU work from vsync quantization, compositor noise, and probe overhead.

## Prove Equivalence and Stability

Run focused semantic tests, rendering-equivalence probes, and the full suite required by the task risk tier. For rendering changes, capture fresh native 1920×1080 screenshots for at least:

- idle populated gameplay;
- selected/hovered interaction;
- active effect or impact;
- the maximum-content stress workload.

Inspect the images, not only file dimensions. Check sprite and alpha order, particle density, animation state, HUD placement, tooltips, selection/focus, text, icon identity, and edge clipping. Exercise every elemental or content variant whose batching/atlas/cache path differs.

The benchmark itself must assert semantic errors are empty, object/node counts remain bounded, orphan nodes are zero, and retained-layer or cache invariants expected by the optimization are active.

## Finish the Pass

Commit the benchmark, comparison tooling, tests, and documentation with the optimization. Keep durable measurement rationale in the owning code or specification. Obtain independent peer-review signoff, create the verified task-local inspection fixture, and wait for user inspection before publication as required by `$parallel-labyrinth-task`.

In the handoff, lead with:

- the reproducible bottleneck;
- base-versus-candidate median and p95 frame time;
- frames over 16.67 ms and 33.33 ms;
- draw/rebuild/allocation changes;
- memory and node deltas;
- semantic, test, and visual proof;
- remaining risks and which hardware was actually measured.
