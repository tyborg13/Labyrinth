# perf-159 board focus submission

The A/B switch `LABYRINTH_PERF159_BASELINE=1` restores the release hover
submission and plate routing for the benchmark. Both sides use the same
perf-134 save archive, perf-148 HUD retention, and perf-157 targeting routing.
The task started at release snapshot `ecf8e02bc`.

## What a focus move changes

The focused probe drives the same two tiles in both directions by D-pad and
mouse. The stick drives the rightward snap over the same edge after positioning
the virtual cursor at the next tile. The probe checks the reached tiles and
committed-state digest and repeats pointer motion on the settled tile. That
last motion submits no stage on either side.

The hover owner is the only submitted presentation field that changes
in the normal route. In the Tharokh fixture, crossing onto the
dragon also changes isolation and intent expansion, move and attack tiles,
the projected route and destination echo. Crossing out removes those inputs.
The combat, rest threat descriptors, and announced marks remain equal. The
full release submission decorated those inputs, resubmitted persistent
cutouts for the destination echo, rebound retained layers, and routed
overlay, HUD, foreground, effects, and scene-tile redraws. Isolation still
resolves the visible actor and updates the rail. Plates still observe true
durability and update inspection, while their draw request can join the
already queued hover HUD pass.

The focused submission validates the combat render snapshot and accepts only
the passive focus fields. The normal metadata-only path updates the hover
owner and skips layer routing. A changed Tharokh preview updates its affected
overlays, scene tiles, destination echo, and HUD. Stable boss mark and
mechanics slices keep their geometry. If isolation changes their opacity, the
existing slice tween applies it. Stable cutouts continue their own pose
processing. Overlay groups keep their original paint order. Unused slots
clear their paint through the regular draw callback and remain available
for reuse. Targeting,
animation, and structural changes use the general submission path.

## Headless proof

Use fresh output directories. Normal QoS defaults to two pairs. Background
QoS defaults to five pairs in AB, BA, AB, BA, AB order. Both use four
independent CPU load processes. The primary
interval starts at input and ends at the next process boundary in the
headless stand-in. The next two intervals are also recorded. Native uses
post-draw boundaries. The separate attribution run records submission and
slice redraw work with instrumentation enabled. It checks that the same-tile
motion submitted no stage, changed no combat state, and left spare overlay
canvases outside the active plan with empty paint operations.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-159 && \
  fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
python3 tools/perf159/measure.py --mode attribution --fixtures "$fixture" --output output/perf-159/headless-attribution
python3 tools/perf159/measure.py --fixtures "$fixture" --output output/perf-159/headless-normal
python3 tools/perf159/measure.py --qos background --pairs 5 --fixtures "$fixture" --output output/perf-159/headless-background
python3 tools/perf159/measure.py --mode navigation --fixtures "$fixture" --output output/perf-159/headless-navigation
python3 tools/perf159/measure.py --mode forecast --fixtures "$fixture" --output output/perf-159/headless-forecast
python3 tools/perf159/measure.py --mode strict --fixtures "$fixture" --output output/perf-159/headless-strict
```

`navigation.json` records tile, isolation, expanded intent, move and attack
receipts, plus the focus probe's hover owner and inspected plates. Attribution
adds per-stage sections, per-layer and per-slice rebuild times, draw reasons,
and changed input fields. `summary.json` records input-frame and follow-up
histograms, each pair's A minus B input median, and the median and full range
of those deltas. Positive deltas mean the candidate is faster. The background
gate checks every Tharokh pair and requires the median delta to exceed the
range when claiming a gain. The normal gate checks a 10% reduction in each
Tharokh input median. Ordinary encounters and p95 remain in the report.

## Attribution results

The detailed headless take is
`/private/tmp/labyrinth_codex/perf-159/attribution-final`. The times below
are mean milliseconds per input. Redraw routing includes the slice timings,
and the stage section includes routing and retained binding work.

| Route | Stage submission A → B | Redraw routing A → B | Redraw requests A → B |
| --- | ---: | ---: | ---: |
| Normal D-pad | 1.955 → 0.910 | 0.823 → 0.000 | 16.2 → 16.2 |
| Tharokh D-pad | 18.546 → 12.076 | 10.200 → 7.368 | 35.9 → 27.9 |
| Tharokh stick | 18.732 → 12.691 | 11.291 → 8.091 | 31.4 → 23.4 |
| Tharokh mouse tile | 19.368 → 12.610 | 10.305 → 7.475 | 34.6 → 27.6 |

On the Tharokh D-pad route, overlay slice planning took 3.414 → 1.529 ms,
HUD planning 3.363 → 2.979 ms, retained bindings 2.703 → 1.452 ms, and
effects routing 0.270 → 0.000 ms. Board threat isolation still ran
(0.496 → 0.547 ms). Plate visibility requested four redraws on both sides
in the three-frame window. Fixed boss-area badge coverage was empty in this
timed route. The separate `skybreak-marks` strict state covers fixed marks.

## Loaded headless timing

The normal-QoS ABBA take is in
`/private/tmp/labyrinth_codex/perf-159/pairs-normal-final`. All normal
fixture timing checks passed. Tharokh improved and missed the 25% gate
on all three input routes in this take.

| Route | Input median A → B (ms) | Input p95 A → B (ms) |
| --- | ---: | ---: |
| normal/board-dpad | 27.503 → 21.340 | 33.602 → 28.657 |
| normal/stick | 16.755 → 16.224 | 19.987 → 19.453 |
| normal/mouse-tile | 15.355 → 12.432 | 20.863 → 20.066 |
| tharokh/board-dpad | 52.109 → 43.219 | 60.830 → 55.210 |
| tharokh/stick | 51.050 → 42.520 | 57.928 → 46.474 |
| tharokh/mouse-tile | 44.395 → 39.987 | 52.855 → 51.663 |

The normal-QoS D-pad windows recorded three → zero intervals over 33.33 ms
in the ordinary fixture and 32 → 32 in Tharokh. Tharokh peak live nodes were
2,749 in both arms. Eight cleared overlay canvases account for the higher
low-water count in B. The reported orphan counts matched A and B at ten in
the ordinary fixture and eighteen in Tharokh.

The background-QoS ABBA take is in
`/private/tmp/labyrinth_codex/perf-159/pairs-background-latest`. Every
timing check failed in the aggregate. Tharokh D-pad median was
44.901 → 91.668 ms and p95 was 77.018 → 211.922 ms. The four take medians,
in order, were 71.238, 58.585, 184.096, and 22.708 ms. The two arms also
varied substantially between their own takes. Both QoS runs matched all
focus receipts.

The final strict and navigation receipts matched. The auxiliary RD05 check
reported `RD05 FOCUSED: FAIL (68119 checks, 2 failures)` with both release
routing and the candidate. Both failures were `Umbra keeps the still Unknown
Presence texture`.

## Round 1 background reproduction

The existing candidate was measured through five loaded headless pairs.
Raw takes and the summary are in `/private/tmp/labyrinth_codex/perf-159/round1-initial-background`.
All ten takes matched receipt identity. Positive deltas mean the candidate
saved time. Spread is the largest delta minus the smallest.

| Pair | D-pad delta (ms) | Stick delta (ms) | Mouse delta (ms) |
| --- | ---: | ---: | ---: |
| 1 AB | +17.065 | +20.315 | +6.792 |
| 2 BA | +10.356 | +12.127 | +6.925 |
| 3 AB | -4.639 | -2.055 | -5.154 |
| 4 BA | +5.948 | +4.606 | +3.625 |
| 5 AB | -12.290 | -1.026 | -2.595 |
| Median | +5.948 | +4.606 | +3.625 |
| Spread | 29.355 | 22.370 | 12.079 |

Loaded attribution for the existing candidate is in
`/private/tmp/labyrinth_codex/perf-159/round1-original-attribution`.
Both arms built one overlay plan per crossing in that take. The candidate
reused four overlay canvases per Tharokh D-pad crossing, eight per stick
crossing, and 3.5 per mouse crossing on average. The explicit renderer
clear averaged 0.005 ms per D-pad crossing on the headless driver.
The native renderer cost remains open.

The trace recorded a deferred HUD pass after each Tharokh stage submission.
For ordinary D-pad, stick, and mouse inputs, deferred HUD time in the
candidate rose from 0.387, 0.378, and 0.475 ms to 2.476, 3.548, and 1.136 ms.
The request count stayed at one in both arms. The round-1 route keeps plate
inspection synchronous and lets the stage's completed HUD solve satisfy
that input's deferred request. Parked overlay slots clear through the usual
CanvasItem draw, and unchanged rings keep their paint at a validated
projection.

Revised loaded attribution is in
`/private/tmp/labyrinth_codex/perf-159/round1-candidate-attribution`.
Each Tharokh route still rebuilt one overlay plan per crossing. Deferred HUD
solves fell from one to zero per crossing, and tracked overlay draw counts
matched release. Times are means in milliseconds per input.

| Tharokh input | Board submission A → B | Overlay publish A → B | Redraw routing A → B |
| --- | ---: | ---: | ---: |
| D-pad | 9.496 → 6.463 | 1.065 → 0.243 | 4.864 → 3.669 |
| Stick | 11.035 → 8.059 | 1.960 → 0.323 | 6.868 → 4.813 |
| Mouse tile | 9.634 → 7.728 | 1.049 → 0.376 | 4.993 → 4.402 |

## Round 1 revised timing

The five revised background pairs are in
`/private/tmp/labyrinth_codex/perf-159/round1-final-background`.
All ten takes matched focus receipts.

| Pair | D-pad delta (ms) | Stick delta (ms) | Mouse delta (ms) |
| --- | ---: | ---: | ---: |
| 1 AB | +4.053 | +6.195 | -2.443 |
| 2 BA | +8.892 | +16.862 | +11.725 |
| 3 AB | +3.553 | +2.684 | +2.626 |
| 4 BA | +7.572 | +5.089 | +7.874 |
| 5 AB | +70.886 | +22.463 | +8.624 |
| Median | +7.572 | +6.195 | +7.874 |
| Spread | 67.334 | 19.779 | 14.167 |

Mouse was slower in pair 1. The median delta fell below the spread on
all three routes, so none cleared the background gate. Tharokh mouse p95
was 30.448 → 31.615 ms. Ordinary input medians were lower on all routes,
and the ordinary stick p95 was 9.175 → 9.385 ms.

The two revised normal-QoS pairs are in
`/private/tmp/labyrinth_codex/perf-159/round1-final-normal`.
All four takes matched focus receipts. All three Tharokh routes cleared the
10% pooled median gate. Ordinary medians and p95 both fell on every route.

| Tharokh input | Pooled median A → B (ms) | Pooled p95 A → B (ms) |
| --- | ---: | ---: |
| D-pad | 21.540 → 14.738 (31.6% lower) | 43.017 → 19.928 |
| Stick | 18.014 → 13.127 (27.1% lower) | 42.557 → 15.643 |
| Mouse tile | 16.035 → 12.543 (21.8% lower) | 38.669 → 15.404 |

The revised headless identity receipts are in `round1-strict/headless-captures`,
`round1-forecast/{A,B}` and `round1-navigation/{1-A,2-B}` under the same
task output root. The exact result lines were:

```text
PERF-135 RECEIPTS: walk-destination identical (headless)
PERF-159 STRICT RECEIPTS: PASS (14 states)
PERF-140 IDENTITY: PASS (119 forecasts, 15 badge receipts)
PERF-159 NAVIGATION RECEIPTS: PASS (16 cohorts, 2 takes)
```

## Proof for the design owner

Native proof runs through `tools/visual_probe_runner.py` at 1920×1080 and 100%
UI scale. The strict mode reuses the 14 perf-148/perf-134 capture states and
their proof contract. It writes full-viewport comparisons in
`output/perf-159/r1-native-strict/captures/*-diff.json` and matching
screenshots and receipts under
`output/perf-159/r1-native-strict/captures/{A,B}/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-159 && \
  fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
python3 tools/perf159/measure.py --native --mode strict --fixtures "$fixture" --output output/perf-159/r1-native-strict
python3 tools/perf159/measure.py --native --pairs 2 --fixtures "$fixture" --output output/perf-159/r1-native-normal
python3 tools/perf159/measure.py --native --qos background --pairs 5 --fixtures "$fixture" --output output/perf-159/r1-native-background
```
