# anim-01 — round 4 (director: native frame spikes)

Round 3 is committed. Native matched benchmark (`output/anim-01/feedback3/benchmark-native/comparison.json`, Apple M5
Pro, 3 pairs): steady idle CPU mean 0.20–0.53 ms (parent 0.03–0.14), but p99 up to 3.3 ms and max 3.5–5.0 ms with
**zero mesh builds during samples** (parent max 0.06–0.33 ms); pair 1 had 78 frames above 2 ms. New-state draw max
1.55 ms (target ≤ 1 ms).

1. Find what runs in the slow frames (instrument them: which enemies redrew, glow scans, texture uploads, GC). Likely
   cause: every static enemy advances its 12 Hz state on the same frame, so all redraw together every 5th frame.
   If so, stagger each enemy's tick phase (deterministic, e.g. from its board slot) so at most ceil(n/5) enemies change
   state per frame; the visible cadence per enemy stays 12 Hz.
2. Bring new-state draw ≤ 1 ms: prebuild the next state one tick ahead (at most one build per frame) instead of on the
   frame it is first drawn.
3. Targets (native, matched pairs, idle board with every static enemy type present): mean ≤ 1 ms, **p99 ≤ 2 ms**, max
   reported (not gated: OS noise). Report all three pairs.
4. Do not commit the `output/anim-01/` benchmark files; keep them untracked.

Proof: idle tests, mutation runner, full suite; list the native benchmark and probe commands for me.
