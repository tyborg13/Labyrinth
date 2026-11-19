# perf-145 save integrity and quit proof

The controls are `codex/release` at `987546fd8` and `codex/perf-144` at `f18685c1e`. Each run has isolated user storage. The checkpoint probe puts a directory at the transaction's temporary file path, clears it after the first failed attempt, and hashes the actual checkpoint after Godot exits. The clock probe substitutes a fixed wall-clock second in a disposable project view and uses the same profile across two launches. It leaves the system clock alone.

| Review finding | Release and perf-144 | Candidate |
| --- | --- | --- |
| 1. Failed replacement retries on exit | Both queue the rejected checkpoint and change the save after the obstruction clears. Perf-144 adds a covered close route that exposes the same retry. | The replacement attempt bypasses the retry queue. The old checkpoint is byte-identical after exit. |
| 2. Failed fresh boot reveals a placeholder | Both reveal a scene with neither seed nor map sections and create a checkpoint after the obstruction clears. | The loading cover returns to the existing error dialog. No run is revealed and the save stays absent. |
| 3. Early-load quit exceeds the deadline | Both exceed 4 s with an injected 1.5 s scene-loader delay. Release finalizes without pumping another frame. Perf-144 pumps frames, but begins its uncancellable request before the idle threshold and retains the visible window until teardown. | Required scene loads finish during startup or title construction. Quit minimizes the main window, cancels CPU jobs, and pumps the main loop before final teardown. A 2.8 s watchdog covers blocked app-level I/O. |
| 4. Profile advances before checkpoint promotion | Both advance the run counter and expire the recovery marker while seed 144 remains durable. | Still reproducible by design. |
| 5. Steam shutdown is ignored | Both lack a signal connection and can commit seed 145 after shutdown. Perf-144 adds the in-flight graph window. | The signal cancels the held graph through the native-close coordinator. No replacement commits. |
| 6. Late debug seed waits on stale graph | Release has no asynchronous job and installs seed 146. Perf-144 remains parked on the held seed-145 job. | The pending seed-145 job is canceled and seed 146 is installed and saved. |
| 7. Seed reuse after clock rollback and relaunch | Both allocate 1795090000 on each launch after abandon. | Still reproducible by design. |

For finding 4, make the durable checkpoint promotion the commit point. Embed the descent identity and progression effects in that checkpoint, then reconcile the profile idempotently on restart. Reconciliation must preserve a newer profile and apply the run counter and marker expiry exactly once.

For finding 7, keep a durable automatic-seed allocator in the profile or a separate metadata record. Advance it only for an installed automatic run, recover it from the last durable checkpoint after an interrupted write, and retain it across abandon. Explicit debug seeds can bypass the allocator.

## Reproduction and regressions

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145
python3 tools/perf_142/integrity_proof.py --project ../release --control --output output/perf-145/classification/release
python3 tools/perf_142/integrity_proof.py --project ../perf-144 --control --output output/perf-145/classification/perf-144
python3 tools/perf_142/integrity_proof.py --output output/perf-145/integrity-final
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1
python3 tools/perf_142/review_proof.py --task-id perf-145 --output output/perf-145/perf-144-repros
python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
python3 tools/qa105/typed_array_scan.py --base codex/release
python3 tests/test_ui_identity_lint.py
LABYRINTH_HITCH_TRACE=0 python3 tools/export_smoke.py --preset 'Steam macOS' --output-dir /private/tmp/labyrinth_codex/perf-145-export-smoke-handoff
LABYRINTH_HITCH_TRACE=0 python3 tools/export_game.py --task-id perf-145 --preset 'Steam Demo Windows' --pack-only --output "$PWD/output/perf-145/steam-demo-windows.pck"
```

## Headless results

Both controls reported `PERF145 PROOF: 7/7 expected outcomes`. The candidate reported
`PERF145 PROOF: 12/12 expected outcomes`, including the two findings deliberately
left reproducible. Neither the five graceful quit cases nor the timed I/O stall
reported resources still in use. Exit measurements follow the actual Godot PID.

| Quit case | SceneTree finalization | Process exit | Native window hide |
| --- | ---: | ---: | --- |
| Title idle | 106.042 ms | 229.690 ms | Windowed proof pending |
| Early preload | 88.596 ms | 232.437 ms | Windowed proof pending |
| Mid-graph | 61.284 ms | 304.115 ms | Windowed proof pending |
| Loading cover | 113.961 ms | 350.544 ms | Windowed proof pending |
| Combat | 186.364 ms | 355.478 ms | Windowed proof pending |
| Injected stalled write | Watchdog | 2867.213 ms | Headless fault injection |

The watchdog proof reported `PERF145 watchdog checkpoint_preserved=true`. The
control early-load process exit times were 4616.160 ms on release and 4506.621 ms
on perf-144.

The seed-7 comparison matched the run, checkpoint, progression profile and map
destination receipts in all four serial pairs. Each profile ran base/candidate,
then candidate/base. Background is macOS `taskpolicy -c background`, a synthetic
stand-in. These are headless process-frame intervals.

| Profile and pair | Press to map, perf-144 → perf-145 | Longest frame, perf-144 → perf-145 |
| --- | ---: | ---: |
| Normal A | 1324.398 → 1214.964 ms | 41.323 → 40.402 ms |
| Normal B | 1174.444 → 1164.898 ms | 39.102 → 39.906 ms |
| Background A | 32720.458 → 4976.475 ms | 296.566 → 372.160 ms |
| Background B | 10988.111 → 5004.183 ms | 206.290 → 205.263 ms |

The longest-frame criterion was mixed. The large background outlier was on the
first map click. Its named map-open span was 21.680 ms of the 372.160 ms frame
interval. The candidate also moved scene compilation before the interactive
title. With the same four-second title idle, the first timed frame began
10.06–10.74 s after engine start in normal takes versus 7.77–8.43 s for perf-144.
The background figures were 33.11–66.96 s versus 11.83–12.40 s. This compares
cold editor runs on the same machine. Cold startup and window dismissal on the
packaged Windows demo remain unmeasured.

Full logs and JSON receipts are in `output/perf-145/`. The focused headless
suite covered main menu resume, input/startup transitions, checkpoint boundaries,
Chronicle teardown, SFX stream lengths and alignment, and shutdown reentrancy.
Three stale ignored Ogg import artifacts matched release rather than the
worktree's audio sources. Those caches were copied from the byte-matching
perf-144 control, after which the SFX test passed.

### Chosen defaults

The watchdog fires at 2.8 s and polls every 5 ms. Clean quit lets the mixer
retire stopped voices over two updates with a 100 ms drain allowance.
The probes use a 120 FPS cap, depth 0, seeds 83 and 144–146, a five-Ember
recovery marker at (1, 0), a 200 ms obsolete-job sample, and fixed clock
second 1795090000. Fault injection uses a 1.5 s scene-load delay and a 4.5 s
disk-write delay. The fixture wait is 30 s. Interactive native close has
60 s for input within a 90 s runner timeout.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/timing-final
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
proof="$PWD/output/perf-145/timing-final"
probe="$PWD/tools/perf_142/new_run_probe.gd"
take() {
  label="$1"
  project="$2"
  shift 2
  "$@" python3 tools/godot_task_runner.py --task-id perf-145 --stream -- godot --headless --path "$project" --script "$probe" -- --output="$proof/$label"
}
take normal/base-a ../perf-144
take normal/candidate-a .
take normal/candidate-b .
take normal/base-b ../perf-144
take background/base-a ../perf-144 /usr/sbin/taskpolicy -c background
take background/candidate-a . /usr/sbin/taskpolicy -c background
take background/candidate-b . /usr/sbin/taskpolicy -c background
take background/base-b ../perf-144 /usr/sbin/taskpolicy -c background
for profile in normal background; do
  for pair in a b; do
    python3 tools/perf_142/report.py "$proof/$profile/base-$pair" "$proof/$profile/candidate-$pair" --output "$proof/$profile/pair-$pair.md"
  done
done
```

## Proof for the design owner

The quit proof captures the last visible fixture at 1920×1080 and 100% UI scale. It records when the main window enters the platform's minimized mode and separately watches the actual process exit. The automatic close scenario sends the same root notification and signal as native close. The interactive scenario exercises the actual OS event. Use the close button on one take and Cmd+Q (macOS) or Alt+F4 (Windows) on a second take. The automated scenarios catch the in-flight worker states without depending on interaction speed.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/windowed
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/windowed/quit --case title-idle --case early-preload --case mid-graph --case loading-cover --case combat
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/windowed/native-close --case title-idle --manual
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/windowed/cmd-q --case title-idle --manual
```

On Windows, use the same commands in the Windows worktree with `--display windows` and the corresponding native close input. Check the packaged Steam demo separately to confirm Steam delivers the production callback.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/windowed
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
proof="$PWD/output/perf-145/windowed"
probe="$PWD/tools/perf_142/new_run_probe.gd"
contract="$PWD/tools/perf_142/visual_proof.json"
python3 tools/visual_probe_runner.py --project ../perf-144 --task-id perf-145 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract" --result-manifest "$proof/base-images.json" "$probe" -- --capture --output="$proof/base-visual"
python3 tools/visual_probe_runner.py --project . --task-id perf-145 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract "$contract" --result-manifest "$proof/candidate-images.json" "$probe" -- --capture --output="$proof/candidate-visual"
python3 tools/perf_142/report.py "$proof/base-visual" "$proof/candidate-visual" --output "$proof/visual-receipts.md"
python3 tools/visual_probe_runner.py --project . --task-id perf-145 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/perf_142/review_visual_proof.json --result-manifest "$proof/settings-images.json" tools/perf_142/review_probe.gd -- --case=settings --capture-dir="$proof/settings"
```
