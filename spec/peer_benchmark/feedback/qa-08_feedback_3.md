# qa-08 feedback 3 — every child under 110 s under load

The registration through qa-07's scheduler is accepted: 399–457 s with all 116 supplemental programs included. I
committed it and merged integration (it brings fix-05, whose performance regression now runs inside the map v5
suite).

Two children are too slow under load:
1. **Map v5 took 115.5 s once.** fix-05 added a performance regression (seed 1792271957 plus the 20 slowest seeds) to
   `tests/suites/section_map_v5_suite.gd`. Move that regression into its own program child (for example
   `suites/section_map_performance_program`), registered and guarded like the others. Keep its assertions.
2. **EN06 timed out at 180.2 s in one loaded run.** Nine focused runs passed.
   - Profile EN06 under load across 5 runs and report the distribution.
   - If its typical loaded time is over 90 s, split it into two or more programs, counting and preserving its
     assertions.
   - If the timeout came from one stuck wait rather than steady work, find that wait and fix it. Never loosen the
     180 s cap.

Then show three consecutive full runs under concurrent load (the Python suite running alongside), with every child
≤ 110 s and the total ≤ 600 s, and report the per-child maxima.
