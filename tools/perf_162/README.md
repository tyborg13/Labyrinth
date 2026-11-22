# perf-162 noncombat confirms

The quick-1120 warm background census attributed most of its worst intervals
to process and refresh work. The controller callbacks alone did not account
for those intervals. These are its raw native milliseconds.

| Census screen | Background p99 / max | Normal p99 / max |
|---|---:|---:|
| Campfire | 190.920 / 489.509 | 11.710 / 89.933 |
| Event | 12.785 / 307.267 | 11.508 / 68.572 |
| Reward | 34.525 / 250.852 | 11.712 / 51.335 |
| Treasure | 21.493 / 199.360 | 12.296 / 42.562 |

The census grouped Scavenger under room input and did not isolate Graftwright.
Its census rows are context for this task. Use the matched replay below as
the release control for the threshold. The original runtime baseline is `f9b159baf`. The comparison accepts later runner-only revisions of the release worktree.

| Confirm | Work to inspect |
|---|---|
| Campfire Linger | Heal and mode change, checkpoint, board result, route refresh. The census found an Earth moss texture load. Its existing texture paths now enter the campfire's room preparation. |
| Campfire Strength and Embrace | Wallet and run result rules, profile write, run checkpoint, receipt append and acknowledgment, result and Skills/recap layout. Profile, checkpoint and outbox barriers run in release order on the committing frame. |
| Event choice and Continue | Resolve effects or clear the room, persist the result, emit map events and update rotation history before the confirm returns. Reuse the painting, warm assets from the opening preview, and build the result column under its existing transition. Continue can expose the route or event draft. |
| Reward and treasure | Validate the selected offer, acquire or heal, save, update HUD or emit reward analytics, animate the existing receipt. Use retained reward choices where the offer is unchanged. |
| Graftwright | Validate both equipment slots, save the atomic graft and append its map record. Prepare result controls during the ritual, retain them through the final refresh, and save separately on Continue. |
| Scavenger | Apply wallet and inventory changes and refill stock, save, emit a trade receipt, update the shelf and detail, and play fanfare. Prepare candidate replacement textures at selection and keep the live shop mounted across refresh. |

Run the matched protocol from the prepared task worktree. The script alternates
release/candidate order and QoS order over five pairs per profile. Each take
uses one untimed primer and five controller A repetitions per action. It
reports nearest-rank frame percentiles, max, threshold counts, node/memory
counters, receipt parity and the median and range across takes. Time the
foreground window on the same Metal renderer and hold host conditions steady
through the pairs. macOS background QoS requests scheduling preference.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-162 &&
python3 -B tools/perf_162/compare.py --base ../release --output output/perf-162/round1/native
```

Run diagnostic attribution separately from the acceptance takes. The raw JSON
contains controller dispatch wall time, action completion wall time, native
intervals, instrumented section totals and busiest-frame section spans, and
texture loads. Checkpoint storage time on the game thread includes its synchronous wait. The
report breaks out this storage span, serialization, and disk worker wall time.
It measures presentation duration separately. Spans over the full action can
include later frames, such as the Campfire or card reward commitment after its
authored selection animation. The release's existing
`combat_checkpoint_persist_*` spans also cover its synchronous noncombat
checkpoint calls.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-162 &&
python3 -B tools/perf_162/compare.py --base ../release --profile background --attribution --pairs 1 --output output/perf-162/round1/native-attribution
```

Run the separate image proof at 1920×1080 and 100% UI scale. The manifests
validate dimensions and nonblank content for every before/after capture.
Compare the visible focus, text, images and receipts between worktrees after
capture. Viewport readback stays outside acceptance samples.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-162 &&
export LABYRINTH_CEL_LOOK=all LABYRINTH_PROBE_WINDOW=1 SteamDeck=1
for side in release candidate; do
  project=../release
  if [ "$side" = candidate ]; then project=.; fi
  python3 tools/visual_probe_runner.py --task-id perf-162 --project "$project" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --timeout 240 --expect-size 1920x1080 --proof-contract "$PWD/tools/perf_162/visual_contract.json" --result-manifest "$PWD/output/perf-162/round1/visual/$side.json" "$PWD/tools/perf_162/confirm_probe.gd" -- --capture --output="$PWD/output/perf-162/round1/visual/$side"
done
```

The headless checkpoint probe replays 500 ms checkpoint stalls. Embrace and
Lost Cartographer use disposable fixtures and expect process termination after
printing their receipts. The trophy case requests the application's window-close
path and leaves its checkpoint and JSONL under its output directory. An
independent Embrace observer can also force a kill inside release's inherited
profile-first transaction.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-162
for side in release candidate; do
  project=../release
  if [ "$side" = candidate ]; then project=.; fi
  for scenario in embrace trophy-close history-kill event-start embrace-in-flight; do
    python3 tools/godot_task_runner.py --task-id perf-162 --stream -- godot \
      --headless --path "$project" --script "$PWD/tools/perf_162/checkpoint_probe.gd" -- \
      --case="$scenario" --output="$PWD/output/perf-162/round1/boundaries/$side-$scenario"
  done
done
```

The pre-existing case where `current_run.save.tmp` is a directory is recorded
in the review. A later quit can save the event result after the directory is
removed, with the corresponding rotation history absent.

Run the renderer-dependent skill analytics test separately.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-162 &&
python3 tools/visual_probe_runner.py --task-id perf-162 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --min-images 0 tests/deferred_run_skill_analytics_test.gd
```

## Feedback 1 results

One matched headless take per side under `taskpolicy -c background` matched
all 12 durable gameplay and analytics receipts, including event rotation.
The generated `output/perf-162/round1/background/report.md` includes the
full action-window and checkpoint-frame breakdowns. These are process-frame
measurements. Native 1920×1080 timing and pixel results are pending.

Checkpoint storage on the game thread took 6.83–32.14 ms across the 12
candidate actions. It accounted for 16.09 ms on Event Continue, 17.82 ms on
Treasure claim, and 13.45 ms on Graftwright commit. Encoding took 0.56–3.74 ms.
Other work dominates some actions. The Scavenger buy refresh took 64.90 ms,
including 18.37 ms of shop inventory work.

After Embrace's synchronous boundary, both revisions retained 720 banked
Embers and cleared the resumable checkpoint. With the independent observer
forcing termination after the profile write and before terminal promotion,
both revisions still had a campfire checkpoint, and New Descent cleared the
bank to zero on both. This is the inherited profile-first crash window.

A 500 ms trophy checkpoint stall followed by window-close kept the relic and
one `guardian_trophy` receipt on both revisions. Lost Cartographer's result
and its recent-event entry both existed before the original reviewer's
queued worker stall and kill. Reload showed the result and 750 held Embers.
Start queued during the event confirm opened pause once the save returned.

## Proposal for a cheaper synchronous checkpoint

Measure the time from submission to worker start separately from the
transaction's live and backup inspection, temporary validation, and rename.
The observed encoding cost is small enough that pre-encoding alone is
unlikely to meet the tail target. If queue wake-up dominates, test a faster
handoff for an idle writer while retaining FIFO order, the same timeout, and
the blocking completion barrier. If inspection dominates, look for redundant
reads within one transaction and preserve the current validation and recovery
decisions. Require identical crash-point outcomes at every existing boundary
before using either change.
