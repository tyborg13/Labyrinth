# perf-145 feedback 2

The title sends the same single run `PackedScene` request as release after
one second without input and after viewport input unlocks. Input restarts
the idle timer. The watcher issues one request and leaves, without polling or
collecting it on the title. The cover claims the token and retains the
successfully loaded scene for the session. The accepted-request registry
drains on live frames or reaches the 2.5 s watchdog if the engine load stalls.
The graph, paint, audio and image work retain the feedback-1 start points
after the first covered presentation.

## Headless timing against release a869b8ba3

Engine start to the first interactive title frame excludes the four-second
idle hold. The run order was release A, candidate A, candidate B, release B
within each profile. Background uses macOS `taskpolicy -c background`.
The candidate probe asserted that the run-scene request was absent at the
interactive title and present before the press, with no graph or paint job.
All four seed-7 receipts matched.

| Profile and pair | Engine start to interactive title | Press to interactive map | Longest frame |
| --- | ---: | ---: | ---: |
| Normal A | 3769.501 → 3760.448 ms | 2536.242 → 2019.647 ms | 319.061 → 49.120 ms |
| Normal B | 3657.376 → 3654.357 ms | 2255.763 → 1824.815 ms | 292.387 → 46.688 ms |
| Background A | 7862.215 → 7391.934 ms | 11871.952 → 13906.033 ms | 1143.535 → 205.970 ms |
| Background B | 7551.018 → 7749.178 ms | 11980.191 → 13522.018 ms | 1155.070 → 206.105 ms |

The background press-to-map allowance remains open. The two deltas were
+2034.081 and +1541.827 ms. All maximum frames met their profile's cap.
Title startup was effectively even in the normal takes and varied in both
directions in the background takes. No additional work moved before the press.
The normal takes preceded the extraction of the scene-load discard path for
shutdown and abandonment. The background takes used the final extraction.

### Background post-press breakdown

These are wall-clock phase times from the transition receipts, in
milliseconds. The last row accounts for the cover's first frames, scene
attachment, reveal, input handoff, and opening-to-map interaction.

| Phase | Release A → candidate A | Release B → candidate B |
| --- | ---: | ---: |
| Remaining threaded scene wait | 5818.6 → 6087.8 | 5632.5 → 5924.9 |
| Covered asset preparation | 2049.3 → 4467.2 | 1957.3 → 4640.4 |
| Staged run UI | 2958.7 → 2457.4 | 3369.9 → 2050.9 |
| Presentation readiness wait | 205.2 → 165.1 | 207.9 → 175.7 |
| Other frames through interactive map | 840.1 → 728.7 | 812.5 → 730.1 |

The largest increase was covered asset preparation. Candidate A/B spent
approximately 1265/1334 ms waiting during scene texture preparation,
1963/1854 ms during board preparation, and 1241/1455 ms joining the early CPU
asset job. These are frame intervals labeled by the active wait. In the
covered asset phase, the candidate traces attributed 2150/2041 ms to main-thread
texture import spans and 358/334 ms to audio preparation spans. Those spans
are part of the phase, and may overlap the wait labels. Staged run UI was
faster by 501/1319 ms, partially offsetting the increase.

## Headless shutdown results

The table gives request-to-process-exit time in milliseconds. Window hide
requires the windowed probe. Each covered case and the injected idle-load
case preserved the previous checkpoint byte for byte. Candidate shutdowns
reported no resource-in-use warnings. The watchdog handled the rows marked
with an asterisk.

| Quit fixture | Normal release | Normal candidate | Background release | Background candidate |
| --- | ---: | ---: | ---: | ---: |
| Title before idle threshold | | 131.723 | | |
| Title after four seconds | 167.759 | 283.501 | 6512.191 | 2838.342* |
| Injected title-idle scene load | 7368.083 | 2540.665* | 14233.840 | 2716.726* |
| Early covered preload | | 2525.002* | | 2612.767* |
| Mid-graph | | 2527.333* | | 2809.120* |
| Loading cover after scene load | | 125.732 | | 817.496 |
| Combat | | 325.135 | | |
| Startup fade | | 436.906 | | |
| Injected stalled write | | 2591.628* | | |
| Injected stalled covered scene | | 2560.184* | | 2805.813* |

The normal four-second title take had an in-flight scene load on the
candidate when Quit was pressed. The release scene load had settled. The
background takes both had an in-flight scene load. The four-second release
takes reported a resource-in-use warning on exit.

The focused receipts include `PERF145 replacement: PASS`,
`PERF145 empty: PASS`, `PERF145 steam: PASS`, `PERF145 debug-seed: PASS`,
`PERF145 PROOF: 15/15 expected outcomes`, and background shutdown
`PERF145 PROOF: 5/5 expected outcomes`. The existing profile-promotion and
clock-rollback findings both reproduced, as expected. Their classifications
and fix sketches are in [the original perf-145 notes](perf_145.md).

## Focused verification receipts

The logs and JSON receipts are under `output/perf-145/feedback-2/`.

- `PERF144 REVIEW: 7/7 passed`
- Settings probe on the final script `PERF144 REVIEW: 1/1 passed`
- Normal `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=10 retries_while_reaping=20 max_cover_free_usec=6796 press_lifecycle_checks=6`
- Background `PERF142 STRESS: PASS cold_runs=50 seed_mismatches=10 paint_in_flight_cancels=10 graph_in_flight_cancels=10 retries_while_reaping=20 max_cover_free_usec=11557 press_lifecycle_checks=6`
- `TEST RESULT: PASS — main menu input and startup transitions`
- `TEST RESULT: PASS — main menu resume safety`
- `CHRONICLE TEST RESULT: PASS`
- `QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)`
- `QA-74 SHUTDOWN REENTRANCY TEST RESULT: PASS (14 assertions; 0 failures)`
- `TYPED ARRAY SCAN: 38 scripts; 0 new; 4 pre-existing`
- UI identity lint `Ran 25 tests in 4.124s`, `OK`
- `EXPORT_SMOKE RESULT: PASS (83.94 seconds)` for `Steam macOS`
- `EXPORT_SMOKE_LOADED scripts=742 scenes=9`
- `CEL_PACK_TEST paths=3089 failures=0` for the Steam Demo Windows PCK

## Reproduction

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-2
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
proof="$PWD/output/perf-145/feedback-2"
probe="$PWD/tools/perf_142/new_run_probe.gd"
take() {
  label="$1"
  project="$2"
  shift 2
  "$@" python3 tools/godot_task_runner.py --task-id perf-145 --stream -- godot --headless --path "$project" --script "$probe" -- --output="$proof/$label"
}
candidate() {
  label="$1"
  shift
  "$@" python3 tools/godot_task_runner.py --task-id perf-145 --stream -- godot --headless --path . --script "$probe" -- --output="$proof/$label" --require-release-idle
}
take normal/release-a ../release
candidate normal/candidate-a
candidate normal/candidate-b
take normal/release-b ../release
take background/release-a ../release /usr/sbin/taskpolicy -c background
candidate background/candidate-a /usr/sbin/taskpolicy -c background
candidate background/candidate-b /usr/sbin/taskpolicy -c background
take background/release-b ../release /usr/sbin/taskpolicy -c background
for profile in normal background; do
  for pair in a b; do
    python3 tools/perf_142/report.py "$proof/$profile/release-$pair" "$proof/$profile/candidate-$pair" --output "$proof/$profile/pair-$pair.md"
  done
done
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-2
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1
proof="$PWD/output/perf-145/feedback-2"
python3 tools/perf_142/integrity_proof.py --output "$proof/integrity"
python3 tools/perf_142/integrity_proof.py --background --case idle-scene-load --case early-preload --case mid-graph --case loading-cover --case stalled-scene --output "$proof/quit-background"
python3 tools/perf_142/integrity_proof.py --project ../release --control --case title-idle --title-idle-msec 4000 --output "$proof/normal/quit-release"
python3 tools/perf_142/integrity_proof.py --case title-idle --title-idle-msec 4000 --output "$proof/normal/quit-candidate"
python3 tools/perf_142/integrity_proof.py --background --project ../release --control --case title-idle --title-idle-msec 4000 --output "$proof/background/quit-release"
python3 tools/perf_142/integrity_proof.py --background --case title-idle --title-idle-msec 4000 --output "$proof/background/quit-candidate"
python3 tools/perf_142/integrity_proof.py --project ../release --control --case idle-scene-load --output "$proof/normal/idle-quit-release"
python3 tools/perf_142/integrity_proof.py --background --project ../release --control --case idle-scene-load --output "$proof/background/idle-quit-release"
python3 tools/perf_142/review_proof.py --task-id perf-145 --output "$proof/review"
python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
python3 tools/qa105/typed_array_scan.py --base codex/release
LABYRINTH_HITCH_TRACE=0 python3 tools/export_smoke.py --preset 'Steam macOS' --output-dir /private/tmp/labyrinth_codex/perf-145-feedback-2-smoke
LABYRINTH_HITCH_TRACE=0 python3 tools/export_game.py --task-id perf-145 --preset 'Steam Demo Windows' --pack-only --output "$proof/steam-demo-windows.pck"
```

## Windowed proof for the design owner

Captures are 1920×1080 at 100% UI scale. The `idle-scene-load` case injects a
4.5 s delay after the idle scene request enters the engine. It records the
prior checkpoint SHA-256 and checks it after Godot exits. The watchdog
deadline and the release idle threshold retain their existing values.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-2/windowed
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/feedback-2/windowed/quit --case title-idle --case idle-scene-load --case early-preload --case mid-graph --case loading-cover --case combat
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/feedback-2/windowed/native-close --case title-idle --title-idle-msec 4000 --manual
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/feedback-2/windowed/cmd-q --case title-idle --title-idle-msec 4000 --manual
```

Use the close button in `native-close` and Cmd+Q in `cmd-q`. On Windows,
use `--display windows` and Alt+F4 for the keyboard take. The Settings and
New Run capture commands are in [the original perf-145 proof notes](perf_145.md#proof-for-the-design-owner).
