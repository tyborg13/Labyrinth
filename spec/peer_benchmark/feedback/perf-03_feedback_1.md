# perf-03 feedback 1

Good harness and clean attribution. Three things, then the fixes.

## 1. The exact owner event (resolves TODO_DESIGN_TRAP_DEATH_COLLISION_FIXTURE)
The owner's analytics show the hitch event was **Hobnail Drive**, not Pale Spark: the hero moves, kicks an adjacent
enemy for 3 and pushes it 2 (`data/cards.json` `hobnail_drive`). It landed on a **lightning trap** (8 damage; the trap
also created electrified surfaces on three neighbouring tiles), then hit a blocked tile behind it: a **force_collision
for 2**, which killed it (`actor_death` source `force_collision`). Build scenario B from that exact sequence with the
real card and rules: an enemy whose HP makes the 3 kick + 8 trap leave it alive and the 2 collision kill it, a lightning
trap on the push path, and a blocker one tile beyond the trap. Keep the fire-trap variant and the surviving variant.
No debug Push needed any more.

## 2. The 2026-10-08 baseline
The director created the detached checkout you couldn't: `/private/tmp/labyrinth_codex/oct08-baseline` at `816f5e68a`
(already in your writable tmp). Copy or adapt the harness into it (scenario A ordinary hover and scenario B; adapt to the
old API as needed; don't commit there) and report old vs current for both. The director removes the checkout afterwards.

## 3. Measurement under shared load
Other jobs run on this machine. For every budget, run each scenario 3 times and assert on the minimum of the three
per-run maxima (det-03's rule); report all three. Keep p95/median from the same runs.

## 4. Fixes (director decisions; nothing a player sees may change)
- **Checkpoint persistence** (`combat_checkpoint_persist_storage` 4-5 ms, more than once per card): keep building the
  snapshot data where it is today, but serialise and write it off the main frame (WorkerThreadPool on an owned deep
  copy) with the same atomic write. Writes must never reorder: a newer checkpoint can't be overwritten by an older one.
  Flush synchronously on quit, scene exit and run end. Add tests for ordering, crash-safety (the last completed write
  is always valid) and flush on exit.
- **UI rebuilt from scratch at commit** (97 nodes entered, 99 resized and 47 minimum-size changes in one frame;
  `layout_board_bounds` 4-5 ms): find which UI is torn down and recreated, and update it in place. It must look and
  behave the same; prove it with a layout/visual equivalence check.
- **Grimoire sync on every UI refresh** (`refresh_ui_grimoire_sync` up to 5.8 ms): run it only when grimoire-relevant
  state changed (dirty flag), with a test that it still updates when it should.
- **Analytics on the commit frame** (`card_finish_*_analytics` about 2.7 ms): buffer events and append them in order on
  a later frame, or off-thread. The JSONL stays append-only, local-first, in order, with the same fields; flush on quit
  and run end. Update `spec/analytics.md` if you change when events are written.
- **`input_dispatch` 5.5 ms:** attribute it, and fix it if it's avoidable work.
- Don't touch the PASS-preview code (perf-02 owns it).

Targets are unchanged: hover max ≤ 16 ms and p95 ≤ 10 ms; every trap-scenario frame ≤ 20 ms (min of 3 runs). If one is
still out of reach after these, report the attribution and stop.

Re-run: the equivalence checks, save pipeline, analytics suites touched, the focused suites from the brief, and the
harness. No full suites.
