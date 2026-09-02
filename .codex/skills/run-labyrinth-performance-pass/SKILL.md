---
name: run-labyrinth-performance-pass
description: Profile, optimize, and verify Escape the Umbra runtime performance without changing gameplay, animation cadence, visual quality, input behavior, or player-facing experience. Use for broad optimization passes, frame drops, poor frame pacing, rendering hot spots, runtime allocation or rebuild costs, performance regressions, Steam or Steam Deck telemetry, native Godot benchmarks, or base-versus-candidate performance proof.
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

## Use Steam Target-Hardware Telemetry

When a performance report comes from a Steam build, read [the telemetry specification](../../../spec/performance_telemetry.md) and use the committed Steam aggregates as target-hardware evidence when all of the following are true:

- the affected device materially differs from the available development machine, especially Steam Deck;
- the tested build contains the relevant instrumentation and its stat definitions are published for the app that was actually launched;
- the session was allowed to emit at least one summary through an interval, gameplay-context boundary, or clean shutdown, and the client then had a five-minute store opportunity or completed its clean-shutdown flush.

Query before choosing an optimization when a relevant test has already happened, and query again after the candidate build is tested. Determine whether the user launched the main or Playtest app from the test/build context, then resolve that variant's ID from `steam/steam_build_config.env`; never mix their results. Use a short date range covering the test and save the raw report outside committed source unless the task explicitly calls for a checked-in fixture:

```bash
python3 tools/steam_performance_stats.py report \
  --appid <tested-app-id> \
  --days <test-window-days> \
  --output /tmp/<task-id>-steam.json
```

The report command expects `STEAMWORKS_PUBLISHER_KEY` to already be configured in the trusted development environment. The Steam client needs no publisher Web API key to upload: the authenticated SDK session writes client-set User Stats. The publisher key is only for this developer-side global read. Never request that a user paste the key into chat, print it, commit it, place it in an exported build, or persist it beyond the trusted environment they authorized. Creating/revoking a key, publishing stat definitions, or changing App Admin is an external mutation and still requires explicit user authorization.

If the trusted environment does not have a key, do not stop at “telemetry unavailable” and do not make the user operate Steamworks when an authorized signed-in browser session is available. Prefer this autonomous, secret-safe bootstrap:

1. Use Computer Use or browser control with the existing signed-in Steamworks session.
2. Open **Users & Permissions → Manage Groups**, select the group associated with the exact tested app, and inspect its existing Web API key.
3. If an existing publisher key is available, copy it only long enough to inject it into the report subprocess. Never include it in tool output, chat, shell tracing, files, command history, or source control. Clear the clipboard immediately after the subprocess receives it.
4. Run the report and validate transport/sample denominators before continuing.

Reading an existing key through an already authorized account is the default no-involvement path. If no signed-in browser session or suitable existing key is available, explain that specific limitation. Creating or revoking a key is an external mutation: do it only when the user has explicitly authorized that change. The least-privilege creation path is:

1. A Steamworks partner administrator opens **Users & Permissions → Manage Groups**.
2. Create a dedicated performance-telemetry group, or select an existing least-privilege group.
3. Associate the exact app being queried. Escape the Umbra uses main app `4530510` and Playtest app `4531660`; include both only when the same key should query both variants.
4. Select **Create WebAPI Key**, grant only **General API calls**, optionally restrict it to the trusted machine's stable outbound IP, and save.
5. Do not use an ordinary Steam Community user Web API key: `GetGlobalStatsForGame` requires a publisher key whose group contains the queried app.

On macOS, use Login Keychain as the fallback when browser retrieval is unavailable and the user chooses to store the key locally. Never ask them to paste or export the key into chat. The secure prompt created by the trailing `-w` keeps the value out of shell history:

```bash
security add-generic-password -U -a "$USER" \
  -s "labyrinth-steamworks-publisher-key" -w
```

After the user confirms it is stored, inject it only into the report subprocess without printing it:

```bash
STEAMWORKS_PUBLISHER_KEY="$(security find-generic-password \
  -a "$USER" -s "labyrinth-steamworks-publisher-key" -w)" \
python3 tools/steam_performance_stats.py report \
  --appid <tested-app-id> \
  --days <test-window-days> \
  --output /tmp/<task-id>-steam.json
```

If the account lacks Steamworks administrator rights, identify an administrator from the partner home page; only an administrator can create the publisher key or grant the required access. Never inspect or echo the resulting secret.

Validate transport before interpreting performance:

- An omitted-key/API error is not a zero; it usually means the definitions are unpublished, the app/key is wrong, or access failed.
- Treat an all-zero platform cohort with zero `sessions`, `windows`, and `frame_samples` as absent or insufficient upload evidence, not proof of good performance.
- A zero missed-frame or section value is meaningful only when its paired denominator (`samples`, `windows`, or `calls`) is positive for the same platform prefix and time range.
- Use the exact device prefix, such as `perf_v1_linux_steamdeck`; do not blend desktop and Deck cohorts when diagnosing a device report.

Use aggregates to locate the problem, not merely confirm that it exists. Compare missed-frame ratios as `over_* / samples`, section mean cost as `tenths_ms / calls / 10`, and relevant workload cohorts such as `combat_animation` versus `combat_idle`, density, depth, and relic count. Preserve the raw denominators and state the app, prefix, date range, and sample size. Steam aggregates may contain multiple builds or players in the requested window, so do not claim a candidate caused a change unless build exposure makes that inference defensible. Use the richer local JSON/native benchmark to reproduce and attribute any hotspot Steam identifies.

If the current schema cannot answer where the slowdown occurs, add the smallest sparse, additive cohort or paired `calls`/`tenths_ms` section that distinguishes the competing hypotheses. Update the runtime instrumentation, `steam/performance_stats_manifest.json`, `spec/performance_telemetry.md`, and relevant tests together. Every new manifest key also requires publication in the tested app's Steamworks Stats & Achievements admin before a subsequent build can upload it; call that administrative step out explicitly and validate it with a real session before relying on the metric. Missing credentials or unavailable target data should be reported as a limitation, not treated as a blocker to useful matched local profiling.

## Reproduce Player Reality

Treat a static snapshot or direct callback benchmark as a narrow microbenchmark, not interaction coverage. Exercise the same public input route the player uses. For combat-board hover, send `InputEventMouseMotion` through the board's `_gui_input` path so hit testing, hover ownership, cursor feedback, HUD layout, retained-layer invalidation, and preview work all run. For clicks, push pointer motion plus press/release events through the viewport's GUI router; direct handler or node `_gui_input` calls bypass z-order, visibility, `mouse_filter`, and pooled-control lifecycle failures.

Bracket rendered-frame samples on `RenderingServer.frame_post_draw`. An `await process_frame` resumes before that frame's queued `CanvasItem` redraws execute, so a loop can coalesce adjacent interaction states, produce false-zero redraw counters, and report process-callback intervals as if they were player-visible frame pacing. `RenderingServer.force_draw()` also does not execute queued `CanvasItem._draw()` work; use a real post-draw boundary whenever the workload claims to measure visible redraw completion. A retained scene with no dirty draw command may skip rendering entirely, so pulse a dedicated imperceptible probe `CanvasItem` before awaiting the signal; simply calling `queue_redraw()` on a control with no authored draw command can still leave the wait attached to a later unrelated frame.

Keep viewport readback, image resizing, PNG encoding, log serialization, and other proof I/O strictly outside timed samples and settle afterward. Native GPU readback can contaminate later Metal frames, so excluding only the frame that calls `get_image()` is insufficient if the next interaction starts immediately.

Native synthetic-input probes can enter the desktop idle governor because they do not receive real OS pointer wakeups, and macOS can throttle Metal drawable delivery for an occluded/background or inactive-fullscreen-Space window. Run native probes in an explicitly windowed foreground presentation, disable low-processor mode, cap its fallback sleep, and record those timing controls in the report. Verify focus from `DisplayServer` at startup, during rendered samples, and at completion; requesting foreground status is not proof that it succeeded. Treat repeated roughly one-second intervals or any other authored delivery-throttle signature as an invalid run rather than filtering it from percentiles. Otherwise runner sleeps can masquerade as frame or action-completion stalls even when the measured handler and redraw work are fast.

Record `RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS` around cold 2D interactions and repeat the same sweep warm. Canvas pipelines are created on first draw, so cold pipeline work, one-time renderer delivery, and steady gameplay cost must remain distinct instead of being blended into one percentile.

When a report is save-specific, load a private duplicate of the current save into the probe and never write it back. Pair it with deterministic synthetic stress fixtures so the pass covers both the reported state and reproducible worst cases.

For broad combat passes, cover cold and warm forms of each applicable interaction:

- card click/select, target hover, full target sweep, target confirm, and committed action;
- move, blink, line, area, multi-target, trap, terrain, loot, illusion, and pass previews;
- manual abilities, relic-heavy state, large hands/piles, overlays, and inspect/tooltips;
- dense boards, maximum actor footprints, varied enemy compositions, and Umbra stages;
- idle, animation, enemy round, room transition, save/resume, and other implicated flows.

Fixtures must satisfy authored readiness constraints such as hand caps, resources, discard contents, target legality, and animation locks. Assert every intended interaction actually executes and changes the expected committed or presentation state.

Manual-ability coverage must route through the visible sigil, palette paging/tile, Activate button, and any hand or pile selection wrapper. After hand-selection abilities, route another ordinary card click through the viewport so pooled-card visibility and `mouse_filter` restoration are exercised end to end. Direct activation or selection callbacks are semantic microchecks only; they cannot validate the live pooled-control lifecycle.

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

Commit the benchmark, comparison tooling, tests, and documentation with the optimization. Record only durable non-obvious findings with `memento record`. Obtain independent peer-review signoff, create the verified task-local inspection fixture, and wait for user inspection before publication as required by `$parallel-labyrinth-task`.

In the handoff, lead with:

- the reproducible bottleneck;
- base-versus-candidate median and p95 frame time;
- frames over 16.67 ms and 33.33 ms;
- draw/rebuild/allocation changes;
- memory and node deltas;
- semantic, test, and visual proof;
- remaining risks and which hardware was actually measured.
