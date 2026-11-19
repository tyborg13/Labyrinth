# perf-145 feedback 1

The first interactive title frame performs no New Run preparation. Startup
requests the title scene on the same timeline as release. The title makes no
run-scene request, including after crossing the old idle threshold. The
production New Run button samples its seed when it creates the cover.
The cover presents before it starts the threaded scene, owned graph and
opening-paint workers, and asset staging. Audio and texture staging share
the existing 4 ms frame budget. The previous draw and the existing error
dialog remain in charge of loading and failed entry.

An engine request that Godot has accepted cannot be canceled using its
public resource API. The coordinator cancels the owned graph, paint and
asset producers and keeps the loop alive to collect engine tokens. It
allows normal teardown only once those tokens and the CPU drains settle.
If an accepted request stalls, the 2.5 s watchdog bounds the
process lifetime. The covered boot cannot promote another checkpoint after
the cancellation request. [Godot ResourceLoader documentation](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html)

## Headless proof

The release worktree used here is `a869b8ba3`, a descendant of
`1abb070fd`. The timing pairs run base/candidate and then candidate/base.
The four-second hold is the existing seed-7 comparison and gives release's
idle preload its normal opportunity to run. The zero-hold pair measures a
press as soon as the title is interactive. Both comparisons are retained
because they exercise different amounts of release preloading.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-1/matched
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1 LABYRINTH_HITCH_TRACE=1
proof="$PWD/output/perf-145/feedback-1/matched"
probe="$PWD/tools/perf_142/new_run_probe.gd"
take() {
  profile="$1"
  label="$2"
  project="$3"
  shift 3
  if [ "$profile" = background ]; then
    /usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-145 --stream -- godot --headless --path "$project" --script "$probe" -- --output="$proof/$profile/$label" "$@"
  else
    python3 tools/godot_task_runner.py --task-id perf-145 --stream -- godot --headless --path "$project" --script "$probe" -- --output="$proof/$profile/$label" "$@"
  fi
}
for profile in normal background; do
  take "$profile" release-a ../release
  take "$profile" candidate-a . --require-cold-title
  take "$profile" candidate-b . --require-cold-title
  take "$profile" release-b ../release
  take "$profile" release-immediate ../release --title-idle=0
  take "$profile" candidate-immediate . --title-idle=0 --require-cold-title
  for pair in a b immediate; do
    python3 tools/perf_142/report.py "$proof/$profile/release-$pair" "$proof/$profile/candidate-$pair" --output "$proof/$profile/pair-$pair.md"
  done
done
```

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-1
export LABYRINTH_DEMO=1 LABYRINTH_CEL_LOOK=all LABYRINTH_DISABLE_STEAM=1
python3 tools/perf_142/review_proof.py --task-id perf-145 --output output/perf-145/feedback-1/review
python3 tools/perf_142/integrity_proof.py --output output/perf-145/feedback-1/integrity
python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
/usr/sbin/taskpolicy -c background python3 tools/godot_task_runner.py --task-id perf-145 --timeout 600 --stream -- godot --headless --path . --script tools/perf_142/startup_stress.gd
python3 tools/qa105/typed_array_scan.py --base codex/release
LABYRINTH_HITCH_TRACE=0 python3 tools/export_smoke.py --preset 'Steam macOS' --output-dir /private/tmp/labyrinth_codex/perf-145-feedback-1-smoke-current
LABYRINTH_HITCH_TRACE=0 python3 tools/export_game.py --task-id perf-145 --preset 'Steam Demo Windows' --pack-only --output "$PWD/output/perf-145/feedback-1/steam-demo-windows-current.pck"
```

## Interleaved timing diagnostics

All six pairs matched the seed-7 receipts. Time is in milliseconds.

| Profile and pair | Engine start to interactive title | Press to interactive map | Longest frame |
| --- | ---: | ---: | ---: |
| Normal a | 4047.013 → 3948.616 | 2842.624 → 4955.121 | 372.677 → 48.221 |
| Normal b | 3946.970 → 3931.053 | 2597.845 → 4325.774 | 360.425 → 42.544 |
| Normal immediate | 3846.952 → 3998.948 | 5075.856 → 4590.263 | 345.426 → 42.263 |
| Background a | 7872.023 → 7796.046 | 12112.246 → 14158.044 | 1138.093 → 205.848 |
| Background b | 7669.951 → 7817.997 | 11540.646 → 14144.702 | 1197.314 → 206.033 |
| Background immediate | 7646.368 → 7994.868 | 16302.037 → 14535.732 | 1193.998 → 206.152 |

The candidate met the 50/210 ms frame caps. Immediate clicks met the
press-to-map allowance in both profiles. The four-second holds exceeded
it by 1.328–2.204 s. The release control starts its scene request during
that hold. The candidate does all cold scene compilation after the press.
Startup was close to release, with both faster and slower individual takes.

The subsequent background take exposed main-thread publication and audio
collection stalls during scene compilation. Image decode still overlaps the
loader. Main-thread texture publication and audio staging now start after
the scene request returns. These are the final four-second-hold pairs:

| Profile | Engine start to interactive title | Press to interactive map | Longest frame |
| --- | ---: | ---: | ---: |
| Normal | 3961.157 → 3826.319 ms | 2757.338 → 5611.756 ms | 353.152 → 54.263 ms |
| Background | 7418.460 → 7619.916 ms | 12173.040 → 17180.928 ms | 1094.892 → 206.596 ms |

Both pairs matched seed-7 receipts. The latest background title was
201.456 ms slower, and the normal maximum exceeded 50 ms by 4.263 ms.
The press-to-map allowance was missed in both final pairs. Release had
already started its scene loader during the idle hold.

### Title quit after four seconds of idle

| Profile and pair | Release process exit | Candidate process exit |
| --- | ---: | ---: |
| Normal a | 179.105 ms | 178.366 ms |
| Normal b | 214.872 ms | 175.048 ms |
| Background a | 6244.087 ms | 763.029 ms |
| Background b | 11879.890 ms | 814.086 ms |

All four candidate title quits were clean. The immediate release trial
exited faster and reported two resources still in use. In the four-second
background pairs, release was still draining its idle scene request.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-1/title-quit
proof="$PWD/output/perf-145/feedback-1/title-quit"
python3 tools/perf_142/integrity_proof.py --project ../release --control --case title-idle --title-idle-msec 4000 --output "$proof/release-normal"
python3 tools/perf_142/integrity_proof.py --case title-idle --title-idle-msec 4000 --output "$proof/candidate-normal"
/usr/sbin/taskpolicy -c background python3 tools/perf_142/integrity_proof.py --project ../release --control --case title-idle --title-idle-msec 4000 --output "$proof/release-background"
/usr/sbin/taskpolicy -c background python3 tools/perf_142/integrity_proof.py --case title-idle --title-idle-msec 4000 --output "$proof/candidate-background"
```

The 2.8 s watchdog diagnostic exceeded 3 s in the background profile.
The 2.5 s deadline leaves room for OS scheduling. The final background
probes preserved all three previous checkpoints byte for byte. The
detached-cover quit exited normally in 634.452 ms. Cold scene-load and
forced scene-stall quits reached the watchdog and exited in 2719.788
and 2707.007 ms. Native window dismissal requires the windowed probe.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && python3 tools/perf_142/integrity_proof.py --background --case early-preload --case stalled-scene --case loading-cover --output output/perf-145/feedback-1/quit-background-final
```

### Chosen defaults

The coordinator's watchdog deadline is 2.5 s. The polling
interval remains 5 ms. The background quit proof throttles the game
runner and samples process exit from an ordinary-priority observer.
The title quit comparison waits four seconds in both builds. The injected
engine scene stall lasts 4.5 s.

## Windowed proof for the design owner

The quit probe captures the title and covered states at 1920×1080 and 100%
scale. `early-preload` exercises an accepted scene request after the press.
`loading-cover` waits for the detached run scene. The request receipts log the
native minimize timestamp and the process exit. The coverage includes the
previous checkpoint hash after exit.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-145 && mkdir -p output/perf-145/feedback-1/windowed
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/feedback-1/windowed/quit --case title-idle --case early-preload --case mid-graph --case loading-cover --case combat
python3 tools/perf_142/integrity_proof.py --display macos --output output/perf-145/feedback-1/windowed/native-close --case title-idle --manual
```

Use the windowed seed-7 and Settings commands in [the previous proof](perf_145.md#proof-for-the-design-owner)
with the release worktree as the baseline and a fresh output directory.
