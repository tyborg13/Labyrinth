# spx-07 feedback 1 (director, 2026-10-21)

Checkpoint: a892292ab (your r0 work, committed by the director). The locked wind and the spread spawns are accepted,
pending item 3. Native captures of both fixtures look right. Four items:

## 1. Native frame stalls remain during a pointer sweep (no card selected)

Director native probe `spec/peer_benchmark/director_tools/warband_perf_probe.gd`, 1920x1080, real frames, 6 s sweep:

| Fight | Integration 3fad2e65b: max frame / process p95 (ms) | spx-07 r0: max frame / process p95 (ms) |
|---|---:|---:|
| Ordinary | 71.3 / 71.3 | 52.9 / 52.8 |
| Air T2 | 72.1 / 72.0 | 56.7 / 56.6 |
| Lightning T3 | 64.4 / 64.3 | 44.0 / 43.9 |

Idle frames are 8–13 ms. Your benchmark drains only the queued hover presentation, so it misses the rest of the frame:
board layer `_draw`s, deferred calls, HUD and tooltip work, and `_process` work triggered by the hover change.

- Root cause it with real frames. Write a headless twin of the director probe: same fixtures, same sweep (pointer motion
  pushed through the viewport every frame along the probe's path over the board rect, 6 s). Await real `process_frame`s
  and record per-frame `Performance.TIME_PROCESS`, the board's existing render section timings
  (`_record_render_section_time`) and any other per-frame script cost. `_draw` runs headless too.
- Report the top costs in the worst frames per fight, then fix them.
- Budget, headless twin, script time per frame during the sweep: max ≤ 16 ms and p95 ≤ 10 ms in all three fights. The
  director confirms natively (target: max frame ≤ 20 ms).
- Behaviour and previews stay identical; keep the 729-snapshot equivalence passing.

## 2. Card and drag targeting: budget decided

New budget for card targeting and drags: worst ≤ 20 ms, median ≤ 6 ms (was 12 ms worst). A new target needs a real
simulation, and 20 ms costs at most two frames at 120 Hz. Keep reducing the remaining costs (PASS preview 14–19 ms,
`IntentBadges.build` 9–11 ms): look for redundant deep copies of state and for work that is shared across targets but
recomputed per target. No threads and no deferred or two-stage display. If 20 ms is still out of reach, report the floor
with a profile.

## 3. TODO_DESIGN_SKIRMISHER_LANE_ORDER: decided

- Left and right are as seen walking from the entry toward the captain: side = sign of cross(captain − entry,
  tile − entry); negative is left, positive is right.
- The first skirmisher takes the left side, the next the right, alternating.
- A tile on the line itself (cross = 0) belongs to neither side and never takes a skirmisher.
- Within a side, the existing seeded roll picks among all valid tiles; no further ranking.
- Remove the placeholder constant and the "lower lane" wording; update `spec/encounters.md` and the spawn tests (add a
  check that no skirmisher sits on the line).

## 4. Full Python suite

r0 left it unobserved. Run it once at the end and report the result.

## Proof wanted

- The headless twin's table: base 3fad2e65b versus your HEAD, max and p95 per fight, with the top worst-frame costs.
- The targeting table (median and worst per fight and mode).
- Spawn tests, the wind-lock suite, the 729-snapshot equivalence.
- Focused tests while fixing; both full suites once at the end. List the windowed commands again.
