# perf-03 feedback 2 (from the Codex review of 6e23ba348; evidence output/perf-03-review/ in the review copy, summarised below)

The review found two blocking durability defects in the worker-thread writes:
- a failed checkpoint is dropped, so the newer snapshot vanishes;
- an interrupted analytics append glues the next record onto a partial line.

**Director decision: no worker threads for saves or analytics.** Keep the frame-time win by moving the work off the
expensive frame, not off the main thread.

1. **Deferred main-thread writes.** Replace `ordered_background_writer.gd`'s WorkerThreadPool use with a main-thread
   FIFO that runs the EXISTING synchronous write code (same atomic tmp + rename, same error handling) on a later idle
   frame:
   - at most one checkpoint write and one analytics batch per frame;
   - never on a frame that's resolving a card or an enemy action;
   - at the latest 0.5 s after it was queued.
   Superseding: a queued checkpoint replaced by a newer one before it runs may be skipped; the newest always gets
   written.
   - Failure: a failed write keeps its snapshot queued (it isn't dropped) and retries at the next idle frame and at
     every barrier until it succeeds or a newer checkpoint is written successfully. Barrier callers get the failure
     result exactly as the old synchronous path reported it.
   - Barriers flush synchronously and in order: quit, scene exit, run end, new run, Continue,
     `has_saved_run()`/load, and the save-and-quit path.
2. **Analytics:** queued records append in order through the existing append path on idle frames, with the same fields,
   order and idempotency. Before the first append of a session, and after any failure, recover an unterminated tail:
   keep every complete line and start the next record on a new line. Regression: write one complete event plus a
   partial record, kill the process (subprocess), restart, append, and `load_all_events()` returns both complete
   events.
3. **Tests the review showed missing:**
   - a read while a write is still pending (delete the `has_saved_run()` flush and the test must fail);
   - board redraw routing through the production boundary (old and new path tiles actually redrawn; an empty loop must
     fail).
4. **Windows typed-array rule:** `tests/perf/visual_rects_reference.gd` ~23 assigns bare `[]` to `Array[Rect2]`; fix
   it.
5. Remove the dead `_append_jsonl()` wrapper (`analytics_store.gd` ~212).

Keep everything else (board fixes, turn-order slot reuse, Grimoire dirty sync, proxy preparation). Re-run the save
pipeline, analytics, background-persistence (now deferred-persistence) and kill/restart tests, equivalence, controls and
keywords. Report the per-frame cost of a deferred checkpoint write and an analytics batch on the frame they land on.
No full suites; the director measures frames on an idle machine.
