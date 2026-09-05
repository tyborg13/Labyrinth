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
