# perf-154 combat input proof

Arm A uses release behavior from `1420bd286` through the debug-only
`LABYRINTH_PERF154_BASELINE=1` switch. Arm B uses the controller selection
forecast worker. Both arms use the same archived encounter and renderer
settings. The effective runtime changes from release are in
`run_scene.gd`, `retained_pass_preview.gd`,
`selected_card_forecast_work.gd`, and `pass_forecast_presentation.gd`.

## Round-0 attribution and disposition

The original paired attribution is in
`output/perf154/attribution-final/{1-A,2-B}/navigation.json`. The table gives
mean section milliseconds per input using the original three sampled
intervals. Frame share is the section delta divided by the corresponding
baseline input window. Sections include their callees and share a run with
the other round-0 changes, so the shares overlap.

| Round-0 change | Measured section and baseline → candidate | Frame share removed | Disposition |
| --- | --- | ---: | --- |
| Retain committed threat descriptors | Board D-pad threat isolation, normal 0.326 → 0.209 ms, Tharokh 0.336 → 0.137 ms | 0.8%, 0.9% | Reverted. Small section gain with no consistent focus-frame win. |
| Presentation-only submission and hover metadata path | Board D-pad stage submission, normal 1.066 → 0.191 ms, Tharokh 7.837 → 8.441 ms | 6.3%, −2.8% | Reverted. Tharokh absorbed the savings on the normal board. |
| Cache controller geometry | Stick candidate section, normal 0.560 → 0.172 ms, Tharokh 0.450 → 0.278 ms | 5.5%, 3.2% | Reverted. The isolated section savings were under 0.4 ms per input. |
| Skip revalidation, hydration and prompts on focus | Stick focus section, normal 0.309 → 0.259 ms, Tharokh 0.247 → 0.305 ms | 0.7%, −1.1% | Reverted. D-pad prompt time had no separate section. |
| Retire replaced hand dwell and suppress duplicate owner refresh | Hand D-pad stage section, normal 1.969 → 1.317 ms, Tharokh 3.257 → 2.914 ms. Both arms submitted 16 stages per encounter. | 4.2%, 2.0% for the whole stage section | Reverted. The attribution could not assign those savings to dwell or duplicate-owner handling. |
| Cache the right rail plan | Hand D-pad rail layout, normal 2.487 → 1.870 ms, Tharokh 2.152 → 2.014 ms | 4.0%, 0.8% | Reverted. The section included slot updates and other layout. |
| Avoid repeated hand margin writes | Shoulder dock layout, normal 0.981 → 0.681 ms, Tharokh 0.624 → 0.715 ms | 1.8%, −0.5% for the whole dock section | Reverted. Theme invalidation had no separate frame attribution. |
| Seed A aim early and use the retained choice path | A stage section, normal 10.257 → 8.342 ms, Tharokh 10.602 → 14.003 ms. Choice and tracker, normal 11.862 → 7.225 ms, Tharokh 2.133 → 3.610 ms. | Stage 2.2%, −6.7%. Choice 5.4%, −2.9%. | Reverted as a standalone optimization. Round 1 seeds the legal aim and pending Pass face as part of the immediate selection. |
| Defer alternate-target warming by a loop boundary | No separate round-0 timing for the warm step. The measured synchronous enemy forecast still cost 6.159 ms on normal A and 2.926 ms on Tharokh A. | Unmeasured | Replaced with the selected-target worker. |

The original normal retake and background pair both missed the timing gate.
See `output/perf154/{pairs-normal-quiet,pairs-background}/summary.json`.

## Round-1 selection

The A press presents the selected card, legal tiles, default aim, and the
card's own board effect. The existing disabled Pass face remains visible and
its forecast rows are inactive while the exact selected target is pending.
The worker begins after the first draw. It shares perf-149's per-rendered-frame
preparation lane and separates source resolution, scheduling, engine slices,
summary, Pass publication, rail projection, and board intent publication.

A target change retargets the worker using the full Pass cache key. A new
selection revision or cancellation invalidates the queued callback and its
partial result. Confirm and cancel retain their ordinary input handlers.
Once published, the worker uses the same Pass memo, summary builder, rail,
and board consumers as the synchronous path.

The navigation probe checks immediate legal aim and own-effect tiles, a
disabled pending Pass face, exact settled summaries and rows, cached Pass
totals, and turn-order delays. It also exercises cancellation before any
worker slice and after two boundaries. Every measured select starts after
the public navigation route returns through the hero's tile. Both arms
record a 20-interval window after selection and retargeting. Ordinary focus
cohorts keep the three-interval window.

## Headless commands

Use fresh output directories. Timing runs two ABBA pairs with four CPU load
workers. The background take applies macOS background QoS to the runner and
Godot. Attribution records section costs separately from the timing gate.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-154 && \
  fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
python3 tools/perf154/measure.py --mode attribution --load-workers 0 --fixtures "$fixture" --output "$PWD/output/perf154/r1-attribution-replay"
python3 tools/perf154/measure.py --fixtures "$fixture" --output "$PWD/output/perf154/r1-normal-replay"
python3 tools/perf154/measure.py --qos background --fixtures "$fixture" --output "$PWD/output/perf154/r1-background-replay"
python3 tools/perf154/measure.py --mode forecast --fixtures "$fixture" --output "$PWD/output/perf154/r1-forecast-replay"
python3 tools/perf154/measure.py --mode strict --fixtures "$fixture" --output "$PWD/output/perf154/r1-strict-replay"
```

## Round-1 loaded results

The raw takes and summaries are in
`output/perf154/r1-pairs-{normal,background}/`. Both ABBA runs matched
navigation receipts, including the landed forecast summaries and rows.
The independent perf140 run matched 119 forecasts and 15 badge receipts.
The headless strict run matched all 14 states.

| Headless metric | Normal QoS, A → B | Background QoS, A → B |
| --- | ---: | ---: |
| A select median | 55.599 → 32.553 ms (−41.4%) | 62.782 → 39.464 ms (−37.1%) |
| A select p95 | 90.971 → 37.339 ms | 104.801 → 56.568 ms |
| Focus median | 10.832 → 10.359 ms | 11.793 → 12.127 ms |
| Focus p95 | 21.441 → 20.112 ms | 26.092 → 26.996 ms |
| All sampled intervals over 33 ms | 32 → 15 | 33 → 34 |

Each candidate recorded zero intervals over 33 ms after the select or
retarget frame. The per-cohort timing gate still failed. Normal QoS added
one 38.539 ms hand D-pad interval and background QoS added one 49.901 ms
board D-pad interval. Both occurred in the focus sweep before the first
card selection in their take.

## Round-2 pending presentation

The button uses the same disabled face as release during card aim. The panel
now starts its normal fade when selection starts and keeps its last painted
rows until the worker publishes. A valid retarget keeps the fade at its current
opacity. Cancel still uses the ordinary fade-out. The selection worker and
settled receipt formats are unchanged.

The strip compares 9 consecutive 60 FPS movie-clock frames after each of
three controller actions in the ordinary and Tharokh encounters. The first
image is the first draw that can paint the input. Each action writes the Pass
and panel crops, a two-row strip with release A above candidate B, and one full
frame per arm. The report lists exact composited pixel differences in each
crop, including the background visible through the panel. It also lists
differences in the sampled button state, bounds, opacity, and row content.

The headless witness matched the button and the panel opacity throughout.
The first selection still paints the previous rows at their original bounds
before publication, on frames 1–4 in the ordinary fixture and 1–5 in Tharokh.
The retarget and cancel witnesses matched throughout.

Omit `--native` to check the route and paint inputs with the dummy renderer:

```sh
python3 tools/perf154/measure.py --mode frame-strip --fixtures "$fixture" --output "$PWD/output/perf154/r2-strip-inputs-replay"
```

## perf-154b forecast truth and navigation receipts

Both arms now include the release changes through `751727cec`. A still
uses the debug-only synchronous selection path. On fresh selection, B
conceals the previous panel and its repeat badges until the initial
aim's rows are ready, then starts the existing fade from zero. The
first aim is bound after controller selection establishes it. Retarget
uses the release hover refresh before the next draw, with the current
fade intact. A retarget during the initial forecast retires the queued
work for the old aim. Release's speculative cache warming resumes
when the initial worker settles or is retired. Cancel keeps the
ordinary fade-out.

The strip compares each painted select and retarget frame to the
fully visible rows for that action and arm. It fails on stale rows,
different settled rows, or any retarget face or panel frame that
differs from release. It also checks that the retarget forecast is
ready on the first draw, including a retarget before the initial
worker's first slice. A hidden frame has no painted rows.

In both archived native QoS takes, only the first
`tharokh/mouse-tile` receipt differed. Both arms already reported tile
`(4, 3)` before and after the timed motion, with no selected card and
an empty forecast payload. A recorded `["enemy_1"]` for both
`isolated_enemy_actor_keys` and `expanded_enemy_actor_keys`, and
`[(1, 3), (2, 4), (1, 5), (3, 4), (2, 5)]` for move tiles. B recorded
three empty lists. Both then reported the same populated presentation
on the first mouse-card sample and all later mouse-tile samples. The
ordinary encounter also showed three empty lists on the first native
sample in both arms.

The old probe used a screenshot helper that sent mouse motion as it
chose the tile. It sampled the already-started, deferred hover
presentation at the end of a three-draw timing window that began
with a second motion. The navigation probe now picks the tile without
dispatching input and reads mouse identity once the hover refresh
queues are clear, with a one-second diagnostic timeout. It records
the timing-boundary presentation separately for diagnosis.
The timed window still contains three intervals. Headless receipts
show the first Tharokh move going from no hovered tile to `(4, 3)`
and both arms publishing the same populated presentation.

## Native proof for the design owner

The strict command runs the same 14 captures as perf148 strict through
`tools/visual_probe_runner.py` and the perf134 proof contract. It writes
`captures/{A,B}/*.png`, state receipts, and full-viewport pixel differences.
Each native take uses the renderer post-draw boundary and validates that
the window stayed focused.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-154b
fixture=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
python3 tools/perf154/measure.py --native --mode frame-strip --fixtures "$fixture" --output "$PWD/output/perf154b/feedback1-final/native-strip"
python3 tools/perf154/measure.py --native --mode strict --fixtures "$fixture" --output "$PWD/output/perf154b/feedback1-final/native-strict"
python3 tools/perf154/measure.py --native --fixtures "$fixture" --output "$PWD/output/perf154b/feedback1-final/native-normal"
python3 tools/perf154/measure.py --native --qos background --fixtures "$fixture" --output "$PWD/output/perf154b/feedback1-final/native-background"
```

The strip writes `summary.json` and `{normal,tharokh}/{select,retarget,cancel}-{face,panel}-strip.png`.
Individual crops, full-frame references and frame witnesses are under each
encounter's `A/` and `B/`.
