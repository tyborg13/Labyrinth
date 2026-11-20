# perf-149 controller Pass proof

Combat Y dispatches `controller_pass`. The census keeps a decision's action
label while its animations and continuations run, so a Y-labelled row can be far
past the physical press. In the seed-7 normal/warm trace, 21 combat Y rows exceed
50 ms and the maximum is 97.288 ms. The 97.288 ms row is in the player handoff,
where the HUD refresh took 19.634 ms and the controller-focus continuation
another 3.776 ms. The 22.553 ms warm-wait span likewise includes the synchronous
caller tail after the wait. The measured warm slice on that row took 0.310 ms.

The census report's 31.895 ms for `_resolve_enemy_round:3` is the sum across
five Y rows over 50 ms. The largest individual span in those rows is 7.285 ms.
Three A-labelled rows in that take have the same scope, totalling 19.035 ms
with a 7.274 ms maximum. The input witnesses show a selected card at all three
A presses. They enter the shared resolver through auto-pass after the card
action exhausts resources. Explicit Pass enters that resolver directly through
Y or through activation of the Pass control.
The original continuation snapshots combat and the tracker, builds and reserves
the turn-ended receipt, constructs and submits the resumable checkpoint, and
enters the first playback call. The candidate prepares the receipt before
the atomic save/outbox submission and starts first playback on its own slice.

The three measured routes use a shared archived normal fight and Tharokh,
with normal combat speed on a 1920×1080 viewport at 100% UI scale. The two
Y routes start with hand focus. The A route seeds the controller focus
candidate for the existing Pass button, then dispatches actual Accept input.
The probe times dispatch to the next boundary and complete intervals after
that. The trace separately measures synchronous scopes. In headless mode the process boundary supplies one
synthetic post-draw signal per frame. The optional detail takes also collect
per-call runtime telemetry, whose bookkeeping adds wall time. Use the
ordinary pairs for threshold comparisons.


## Running the round-one proof

Each timing take loads the same perf-140 save bytes in isolated storage.
The original release base is pinned to `e3d3aba7f`. The driver runs
A/B, B/A, A/B and includes the same 1 ms of main-thread load per interval.
The report checks the 33 ms interval count independently on all three routes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-149
fixtures=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
out="$PWD/output/perf149/feedback1"
python3 tools/perf149/pairs.py --output "$out/headless" --fixtures "$fixtures"
python3 tools/perf149/report.py "$out/headless"
python3 tools/perf149/pairs.py --only identity --output "$out/identity" --fixtures "$fixtures"
python3 tools/perf149/report.py --mode identity "$out/identity"
```

The review probes use real viewport input. The starvation case keeps an
unbound key pressed every rendered interval through the next hero turn.
The departure case keeps the save writer busy across the uncommitted
checkpoint continuation. Use the baseline project from a paired run for
the three input controls.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-149
fixtures=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
for repro in details target starvation departure; do
  SteamDeck=1 python3 tools/godot_task_runner.py --task-id perf-149 --stream -- godot --headless --fixed-fps 60 --path . --script tools/perf149/repros.gd -- --fixtures="$fixtures" --case="$repro"
done
```

## Native timing and capture

Use fresh output directories. Timing uses the live renderer and the normal
combat clock. Captures run each arm and encounter in its own process through
the perf-134 movie wrapper with `--write-movie` and `--fixed-fps 60`. The
probe saves the settled ready turn on frame 720 relative to fixture boot,
aligning the idle clocks at that frame. Capture witnesses verify the roster,
turn, frame, viewport and UI scale. The report compares every pixel and
also rejects duplicate imagery across the two encounters.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-149
fixtures=/private/tmp/labyrinth_codex/perf-140/native-r1-pairs/fixtures-v3.var
out="$PWD/output/perf149/feedback1"
python3 tools/perf149/pairs.py --native --output "$out/native" --fixtures "$fixtures"
python3 tools/perf149/report.py "$out/native"
python3 tools/perf149/pairs.py --only captures --output "$out/native-captures" --fixtures "$fixtures"
python3 tools/perf149/report.py --mode captures "$out/native-captures"
```

The images and capture witnesses are in
`native-captures/{A,B}-{normal,tharokh}/`. Each image uses
1920×1080 at 100% UI scale. `images.json` records the visual runner result for
that process.
