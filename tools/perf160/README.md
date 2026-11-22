# Enemy-round handoff proof

The production resolver commits combat and its receipts before the authored draw.
Preparation uses the already committed next player turn and the same post-draw
scheduler as the Pass forecast. The presentation payload carries the combat
snapshot and its preview revision. Publication checks both after header
reconciliation. It validates the prepared Pass face against the actual forecast
and Defiance cost. Current focus, pointer state, reservations and geometry are
resolved by the existing live controls. A missed or invalidated slice falls
through to the same synchronous queries. The draw proxies, board and locked
Pass control continue to own their existing presentation until one synchronous
publication updates the board, Pass and live hand.

Release base is `742158475c8bb50cb8ed180eabf0b1175ab45f07`. Both arms use
the same fixture bytes and imported assets. The paired routes dispatch controller
Y on the ordinary and Tharokh boards and controller A on the ordinary Pass
control. The separate `auto` mode confirms Stone Plate with A and checks the
resulting auto-Pass receipt and first ready frame.

The native timing probe measures full intervals at actual post-draw boundaries.
The callback span belongs to the following interval. The proof validates focus
during sampled native intervals and checks the first ready board, live hand and
enabled Pass control at that boundary. Capture takes use a separate movie run.
Headless proof uses synthetic boundaries over the normal combat clock at fixed
60 FPS and is a CPU diagnostic.

Timing alternates AB, BA, AB, BA, AB separately at normal and background QoS.
Four CPU load workers run through the take sequence and both sides receive
the existing 1 ms per-interval probe workload. The report records pooled
median, interpolated p95, maximum, range, per-pair maxima and counts strictly
over 33 ms by route. It gates background p95 and max at 60% of the release
baseline and compares normal-profile frame counts route by route. Detailed
attribution has additional probes and is kept separate from the timing gate.
Its per-step timers are inclusive. The initial snapshots and checkpoint
submission precede the ready callback. The final checkpoint, commit/sync
and enemy/event analytics also complete before it, apart from the existing
asynchronous skill-event reconciliation, which has its own trace span.

## Native proof for the design owner

Use fresh output directories. The first-ready and settled images are under
`native-captures/{A,B}-{normal,tharokh}/`. The strict run writes its 14 full
viewport comparisons under `native-strict/captures/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-160
fixtures=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
python3 tools/perf160/proof.py detail --native --fixtures "$fixtures" --output output/perf160/native-detail
python3 tools/perf160/proof.py pairs --native --fixtures "$fixtures" --output output/perf160/native-pairs
python3 tools/perf160/proof.py captures --native --fixtures "$fixtures" --output output/perf160/native-captures
python3 tools/perf160/proof.py strict --native --fixtures "$fixtures" --output output/perf160/native-strict
```

## Headless checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-160
fixtures=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
for mode in detail auto identity strict repros; do
  python3 tools/perf160/proof.py "$mode" --fixtures "$fixtures" --output "output/perf160/headless-$mode"
done
for case in focused_tests action_checks preview_checks forecast_cases defect_checks; do
  python3 tools/godot_task_runner.py --task-id perf-160 --stream -- godot --headless --path . --script "tools/ptf08/$case.gd"
done
python3 tests/test_ui_identity_lint.py
```
