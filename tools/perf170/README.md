# perf-170 controller X and B

The perf134 fixture bundle provides an ordinary fight and a Tharokh fight. The
probe uses viewport joypad input for X to open the hand, tuck it, or cancel a
targeted card and reopen the hand. B tucks the hand or cancels a targeted card
back to the board. Idle B supplies a timing control. The route asserts focus,
targeting, and unchanged committed combat.

The debug-only `LABYRINTH_PERF170_BASELINE=1` option restores the original
paths for both changes. The selected-card forecast and hand-cycling
optimizations from the base stay enabled in both arms.

- **Attribution** records one press per phase and encounter per arm. It
  distinguishes synchronous viewport input, native signal intervals, scene
  and board submission sections, HUD canvas reuse, and subsequent draw
  intervals. The signal spans overlap the instrumented sections. Headless
  runs provide CPU-side attribution.
- **Timing** alternates five A/B pairs in AB, BA, AB, BA, AB order, with
  ten measured presses per phase and encounter after warming each phase.
  The gate uses the median of five paired percentage reductions in p95 and
  maximum press-frame intervals per button. The background profile requires
  at least 30% for each metric and the normal profile requires at least 0%.
  Idle B is reported separately and excluded from B's gate. The report keeps
  each phase, the next two frame intervals, input time, renderer monitors,
  memory and node counts.
- **Frames** compares exact receipts and full-viewport pixels across both
  arms on the press frame, the next two frames and the settled frame.
  It runs separately from timing, at 1920×1080 and 100% UI scale with the
  existing 60 fps movie clock. With On Hover and Aim and Details enabled,
  it also samples every enemy intent tab for 12 consecutive frames after X,
  B, same-frame X then B, and mouse selection followed by either cancel.
  These routes capture the first and final frames. Headless runs drive the
  tab presentation from the routed chip and let Godot advance the normal
  reveal tween. The mode also compares the Erupt tooltip before and after
  the B press and after the next draw. The single-card Storm Beacon case
  compares the Chain demo restart on D-pad Right and RB against the release
  path selected by the perf-163 baseline switch. Run just these three routes
  with `--mode edges`.
  `strict` compares the existing 14 archived perf134 states using the
  perf148 comparison.
- **Forecast** and **cycle** compare the existing perf140 forecast and
  perf163 hand cycle receipts headlessly.

## Native commands

Run with the benchmark window in the foreground and the machine quiet. The
wrapper uses the visual probe runner and native Metal. Background timings
apply `taskpolicy -c background` to the runner and its Godot process.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-170
fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
out=$(mktemp -d /private/tmp/labyrinth_codex/perf-170-native.XXXXXX)
python3 tools/perf170/proof.py --native --mode attribution --qos background --fixtures "$fixture" --output "$out/attribution"
python3 tools/perf170/proof.py --native --mode timing --qos background --fixtures "$fixture" --output "$out/background"
python3 tools/perf170/proof.py --native --mode timing --qos normal --fixtures "$fixture" --output "$out/normal"
python3 tools/perf170/proof.py --native --mode frames --fixtures "$fixture" --output "$out/frames"
python3 tools/perf170/proof.py --native --mode strict --fixtures "$fixture" --output "$out/strict"
```

Attribution reports are in `attribution/{A,B}/sections.json`. The timing
reports are in `{background,normal}/summary.json`. Images are in
`frames/{A,B}/` and `strict/captures/{A,B}/`, and the frame comparison reports
are in `frames/summary.json` and `strict/captures/summary.json`. The Erupt and
Chain comparison is in `frames/edges/summary.json`.
