# perf-163 controller hand cycling

Use the unchanged perf134 fixture bundle to resume ordinary and Tharokh combat.
The probe enters the hand through the production viewport's joypad input and
verifies that L1, R1, D-pad Left and D-pad Right move hover to the wrapped hand
index. It checks the committed combat snapshot before and after the route. Both
rapid presses and presses after hover settles are included.

The debug-only `LABYRINTH_PERF163_BASELINE=1` switch runs the original hand,
rail, tooltip and prompt paths with the same instrumentation. Both arms keep
the deferred selected-card forecast enabled.

- `attribution` records inclusive and exclusive section timings on the press
  frame and through the sampled hover window in `{A,B}/sections.json`. The
  stage and rail are inside the focus-change interval. The keyword build can
  occur during a later dwell frame. `cycle.json` retains the full section data.
- `timing` runs five interleaved pairs in A/B, B/A, A/B, B/A, A/B order. Each
  take samples ten presses per direction, encounter and cadence. The primary
  sample is the draw interval containing the press, with viewport push time
  and the next two draw intervals recorded separately. `summary.json`
  retains per-take median, p95, p99, maximum, interval thresholds and paired
  spread. The gate checks the median paired percentage change in median and
  p95 separately for shoulders and hand D-pad. The threshold is 30% under
  background QoS and 0% under normal QoS.
- `frames` compares panel, rail, hand, focus, glyph and forecast receipts.
  Native proof captures the press frame, the following two frames, and an
  additional settled frame for each settled press. It uses the fixed-rate
  movie clock and compares the full 1920×1080 viewport with no masks.
  Both arms also check that RB and D-pad Right restart the Chain demo at frame
  zero while cycling a hand with one or two copies of Storm Beacon.
- `strict` runs the existing perf148 capture comparison over the 14 perf134
  fixtures. `forecast` checks the existing perf140 headless receipts.

Run these from the task worktree with fresh output directories. The normal
profile leaves process QoS unchanged. The background profile invokes
`taskpolicy -c background` for the runner and its Godot child.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-163
fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
out=/private/tmp/labyrinth_codex/perf-163-native
python3 tools/perf163/proof.py --native --mode attribution --qos background --fixtures "$fixture" --output "$out/attribution"
python3 tools/perf163/proof.py --native --mode timing --qos normal --fixtures "$fixture" --output "$out/normal"
python3 tools/perf163/proof.py --native --mode timing --qos background --fixtures "$fixture" --output "$out/background"
python3 tools/perf163/proof.py --native --mode frames --fixtures "$fixture" --output "$out/frames"
python3 tools/perf163/proof.py --native --mode strict --fixtures "$fixture" --output "$out/strict"
```

Frame images are in `frames/{A,B}/` and `strict/captures/{A,B}/`. The
comparison reports are `frames/summary.json` and
`strict/captures/summary.json`.
