# Card-completion stall investigation — 22 September 2026

Base: local master `539a74976ceddcc8ff42c41843cedabb2e1cb610`. Task: `codex/isolate-card-completion-stalls`.

## Contract and result

Target isolated expensive completion frames and their causal chains, preserving gameplay, input, effects, quality settings and authored animation cadence. Accept a change only with at least 10 ms improvement in each paired block and no completion/whole-action upper-tail or severe-frame regression. Do not count improvements to unrelated inexpensive frames as success.

The combined change eliminates all >50 ms frames in the 24 measured actions, reducing median completion maxima by 29–52 ms. It does **not** establish sustained 30 FPS: 12 completion frames still exceed 33⅓ ms, including every measured Wildfire Halo completion. These results are from one powerful Mac, not weak-hardware certification.

## UI intent

The combat hand must return to correct, responsive pointer or controller focus after a card resolves, with existing emphasis, tooltip, playability, fan, dock and visual effects. Preserve activation/cancellation and input handoff. Native proof covers 1920×1080 at 100% scale, stationary-pointer completion, retained-card index changes, draw/pool/wrapper transitions and controller focus.

## First cause: a synthetic hover cascade

The original full-hand rebuild reset every retained outer card slot to position zero, zero rotation and unit scale. As each card became mouse-interactive, it temporarily covered the same physical pointer. A traced six-card completion emitted enter0, exit0, enter1, … exit4, enter5. Every callback synchronously rebuilt stage previews and turn order. The fan later restored real positions, but the native cached route could remain on card5 although transformed hit testing identified card0.

A baseline diagnostic Gust Step completion spent 38.126 ms in the hand rebuild, including 33.173 ms in eleven hover callbacks. Their nested stage and turn-order work accounted for 17.243 and 9.610 ms. These are inclusive diagnostic spans: do not add children to parents or use instrumented timing as the clean endpoint. Deferred board-rectangle synchronization cost only 0.224 ms in that frame.

The fix retains fan-owned outer transforms only for confirmed live retained slots; size and inner native geometry are still repaired. Pooled/new slots and selection-wrapper crossings keep the full reset. Retained widgets preserve local hover; global hover is remapped by widget identity. After revision-guarded layout completes, Godot's native `Viewport.update_mouse_cursor_state()` re-evaluates ownership at the unchanged physical pointer. Controller focus keeps its existing path. This reduces eleven artificial callbacks to one genuine entry, without suppressing hover updates or visual effects ([API contract](https://docs.godotengine.org/en/4.6/classes/class_viewport.html#class-viewport-method-update-mouse-cursor-state)).

## Second cause: stacked persistence at completion

After the hand fix, a Shadow Step diagnostic took 46.960 ms with 31.472 ms of named CPU work, versus Gust Step's 28.795/20.852 ms. Relic refresh cost 10.511 versus 0.899 ms, explaining 9.612 ms of the 10.620 ms named CPU difference. Hand costs were similar: 8.747 versus 8.615 ms.

Within Shadow's relic refresh, combat skill analytics reconciliation cost 9.521 ms: persist gameplay/outbox, append JSONL and save profile acknowledgment, then save run acknowledgment. The user explicitly permits losing unfinished actions/analytics on interruption. This pass uses that permission conservatively: the initial coherent action checkpoint remains transactional, while completion-triggered reconciliation runs as three ordered main-thread slices separated by real rendered frames. This is asynchronous scheduling, not an OS worker thread or a reduction in total persistence work.

A diagnostic queue trace places those stages after completion: 4.618, 2.049 and 4.707 ms of named work, in delivered intervals of 12.700, 7.223 and 7.618 ms. A `frame_post_draw` continuation runs after that draw's sampling callback, so its cost belongs to the **following** interval. Attribution uses event timestamps and completed-draw timestamps rather than equating Engine frame IDs.

Repeated requests coalesce. Action locks/held presentation state pause the queue and restart it against current state. Profile acknowledgment is copied into in-memory run state before yielding. Failures stop without falsely acknowledging or automatically retrying every frame. Ordinary explicit saves flush synchronously; terminal saves preserve the original recovery fallback. Cancellation generations and run/combat/storage scope checks prevent stale work from overwriting an explicit checkpoint or writing into a replacement run. See [save persistence](save_persistence.md#ordinary-combat-analytics-scheduling) and [analytics](analytics.md).

## Measurement design

Separate clean timing, causal tracing and visual/input proof. Complete setup, state copies and geometric observations before a fresh completed draw immediately before sampling. Clean timing disables section, board-submission and CardWidget layout instrumentation. Record the entire authored action and at least 500 ms following the first delivered draw observing unlock after lock. Verify queue/layout/pose quiescence while still sampling, then include an additional delivered draw so a last post-draw slice cannot escape the capture.

The primary endpoint is each action's **maximum completed-draw interval** from two draws before unlock through the post-completion tail. Whole-action maxima and all severe-frame counts detect displaced work. Native pointer returns once during animation and receives no post-completion repair motion. Full before/after combat states, targets, lock count and settings must match; only the fresh process's randomized combat analytics identity is normalized. Raw identities remain archived and must stay constant within each action.

The final combined implementation uses two paired blocks in AB/BA order, four measured actions per build per block, and one separately archived warmup per process: eight measured actions per card per build. Every block passes the predeclared 10 ms reduction gate. No final block is excluded. Earlier hand-only Wildfire captures rejected for physical pointer movement remain archived and are not combined with these final results. The earlier hand-only Gust experiment had 32 measured actions per build and independently removed all 32 >50 ms frames; it is intermediate evidence, not extra samples for this final implementation.

Hardware: Apple M5 Pro, 24 GiB RAM; macOS 26.3.1, Godot 4.6.1 official, native Metal/mobile, 1920×1080, 100% UI scale, normal motion and existing effects/settings. Absolute frame times vary by block; slower blocks are retained.

| Action | Median completion maximum, master → candidate | Worst completion, master → candidate | Completion frames >33⅓ ms | Whole-action frames >50 ms |
|---|---:|---:|---:|---:|
| Gust Step | 60.425 → 30.940 ms | 63.955 → 34.727 ms | 8 → 4 | 8 → 0 |
| Shadow Step | 81.099 → 28.877 ms | 83.620 → 31.366 ms | 8 → 0 | 8 → 0 |
| Wildfire Halo | 69.133 → 35.815 ms | 72.180 → 39.032 ms | 8 → 8 | 8 → 0 |

With eight actions per build, nearest-rank p95 equals the observed maximum; this is not a high-confidence population-tail estimate. Both completion and whole-action p95 improve for every card. Counts are actual over-budget frames, not average FPS.

## Validity and correctness proof

`tools/card_completion_stall.py` records raw frames, source bytes, commands, effective settings, process status and capture failures. Schema 2 hashes recursive runtime inputs (including scripts, scenes, shaders, data, themes, addons, fonts and assets), the focused harness and the executing tool. Comparison requires per-side source consistency across blocks and rechecks capture validity; an archived failed process cannot later pass comparison. A separate clean-tree verification binds these maps to the intended baseline and final committed candidate.

Captures reject source changes, orphan/node growth, focus interruption, physical pointer movement over two pixels, window changes, wrong lock cycles, unsettled work, mismatched frame observers or inadequate tail coverage. Python tests inject wrong targets, mixed candidate sources, failed captures, node growth and a displaced 200 ms stall to verify rejection.

Verified checks:

- Native stationary-pointer/hand helper: 698 assertions, including removal/reorder, 7→6→7 pooling, Quick Wits cancel, resize/restore and pointer exit. It compares transformed geometry, native route ancestry, global/local hover, emphasis, sizes and tooltip identity.
- Native queue unit test: 26 checks for ordered frames, coalescing, scope/readiness restart, cancellation, failure and explicit flush.
- Native save integration: 79 checks covering no immediate I/O, ordered real writes, locked warmup, actions before append/after acknowledgment, held-state explicit save, scope/namespace replacement, failure/retry/deduplication and victory/defeat recovery with a pending outbox.
- Existing analytics crash-window and save/resume boundary suites pass. Full Godot suite passes. Python comparator suite: 13 tests pass.
- Native hand/controller and draw-flow probes pass. Fresh 1920×1080 screenshots of pointer/controller focus, completed draw and dense fire impact were inspected; existing effects and geometry remain visible and intact.
- The existing drag-overlay probe emits `short targeting should leave the hovered target and cursor unobscured` on **both unchanged master and candidate**. Its synthetic point lies below the visible board near the selected card. The generic runner reports success despite `push_error`; this is explicitly a known failing probe, not counted as passed. Both logs/screenshots are retained. No unrelated drag geometry change is included.

## Remaining attribution and scope

The earlier Shadow trace left 15.488 ms outside named CPU spans. A separate native diagnostic now brackets `SceneTree.process_frame`, `RenderingServer.frame_pre_draw` and `frame_post_draw`, and reads existing per-frame board redraw counters without changing the clean harness.

Two measured Wildfire completions in the final diagnostic take 32.841 and 29.902 ms. Time from the preceding completed draw to `process_frame` is only 0.052/0.060 ms; process-to-pre-draw takes 30.663/27.523 ms; the native viewport-update/draw bracket takes 2.119/2.328 ms. Same-frame named CPU totals are 21.061/21.214 ms, while queued board redraw callbacks contribute 4.438/1.498 ms. Roughly 5 ms remains unattributed inside the process interval. These phase counters have slightly different observation boundaries, so they are not a claim of exact exhaustive allocation. All 78 authored Wildfire animation frames are rendered with zero skipped frames; observed authored-clock duration is about 1.288 seconds for a 1.280-second authored sequence.

A 15-second macOS `sample` capture also sees the main thread waiting in `CAMetalLayer.nextDrawable`, but that aggregate call tree does not correlate waits with particular hitches. The bracketing evidence does not support blaming those waits for the measured completion stall. Native GPU timestamps remain unavailable and Xcode Instruments (`xctrace`) is not installed. Diagnostic runs vary and are not substituted for the clean comparison. The remaining work is primarily before native drawing in these samples; further attribution must cover uninstrumented process/deferred callbacks before attempting another targeted change. No additional small optimization or visual-quality concession is claimed as a solution to the residual misses.

Final proof, raw captures, rejected intermediate runs, native screenshots, commands, source binding and review are archived outside the branch at `output/card-completion-stalls-20260922` in the primary checkout. A verified pre-action inspection fixture is generated after exact-HEAD peer review; publication remains separately approved.
