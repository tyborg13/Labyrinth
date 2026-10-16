# demo-01 implementation and proof

This unit changes only `tools/demo_clips/`, focused demo tests/fixtures, and ignored outputs.
It does not edit game scripts, source assets, director values, saves, analytics,
trailer tools, the task queue, Git history, or the design owner's task metadata.

`clips.json` must be a byte-for-byte import of
`spec/peer_benchmark/staged/demo-01/clips.json`. The pipeline checks equality
before running and records their capture-input hashes. There are 21 clips in three reels.

## Acceptance contract

Risk: **high**, because authentic combat presentation, clock conversion, audio
capture and deterministic output must agree. The design owner owns preflight,
commit, peer review, inspection and publication. `parallel_task.py status` in
this worktree reported an empty contract; this document records the unit's
acceptance criteria without changing owner-managed metadata.

1. Stage the real run scene with the listed enemies, offsets, traps, hand,
   forced intents, speeds and volumes. Use the card/board input handlers, the
   actual pass button and a mouse-motion event. Validate staged state and each
   action. Keep 0.6 seconds of pre-roll and 1.4 seconds after settling.
2. Record a fresh windowed 1920×1080 Movie Maker process at fixed 60 fps for
   each clip using the project's renderer, with no method/driver overrides.
   Require a `Metal … - Forward Mobile` startup log. Write MJPEG + PCM AVI at
   quality 1.0, loaded from per-clip startup overrides. Extract PCM without
   conversion for immediate sync/duration analysis. Retain each AVI until all
   reels encode and pass media probing, then delete only those source AVIs.
   Require 8 GB free before every clip and print free space at the start/end.
   Preserve the game's audio buses except muted music; serialize native GUI
   recording. Report capture wall time, raw frames, seconds/frame and total
   clip wall time.
3. Encode H.264 CRF 16 / slow / yuv420p / 60 fps and AAC 192k / 48 kHz. Burn
   director captions for 2.2 seconds with their final 0.3-second fade. Assemble
   reels in listed order with hard cuts and 6 ms fades on the audio at internal
   cuts. Every ffmpeg command uses two threads; execution is sequential.
4. Drive wall-time consumers from fixed movie frames through test-only,
   in-memory script instrumentation and the existing injectable sound clock.
   Preserve gameplay, cue timing, lengths and mixing.
5. Audit recorded WAV against logged final board submissions, per cue. Flag measured offsets
   outside sfx-04's 0–30 ms peak window; aligned cues also require +15 ±1 ms.
   Flag measured status/trap tails above 1.2 seconds at −40 dBFS. Report
   measurement limits as unmeasured with reasons. Flags and unmeasured rows
   are informational; neither blocks recording or encoding. Print summaries
   after record/encode and retain them in the manifest. Report lightning-trap
   duration for both trap clips, or explicitly explain why it is unmeasured.
6. Compare exact action, cue and frame logs from two headless processes. Record
   one native take per clip and compare it against that headless reference.
   Pair events and board rows by order with identical kinds, payloads and
   states, with the director's absolute float tolerance of 1e-4. Every paired
   native minus headless frame must be in [−2, +2], including clip bounds,
   except explicitly reviewed per-item presentation waits. Lead/lag may rise
   or fall. Report the initial offset, every change and every exemption with
   its cause. Repeat comparison and verify media hashes before encoding.
   Sync/duration always use untouched native times.
7. Check positions, hand, intents, traps, speed and volumes; card completion,
   trap removal, Thornwall's actual growth presentation, following-turn intents
   and a real hover that expands non-empty board intent rows.

Required proof is headless validation/determinism for all 21 clips, the clock
test, synthetic encoder/sync tests, disk guard and media lifecycle tests, the
full Godot suite, and the full Python suite for the initial implementation.
Round seven runs only focused demo tests as directed. Windowed proof belongs to the
design owner: inspect the native captures, hear the WAV/MP4, inspect the sync
manifest and native/headless comparison, and read the final output size.

## Implementation

`demo_clip.gd` / `.tscn` drive inputs. `fixture.gd` derives the depth-one room,
hero stats, enemy HP and trap damage from production defaults. It retains the
production seed-410 biome, 9×9 room and default camera, opens the floor as
directed, and uses the production eastward-travel entrance for the brief's +x
enemy direction. Only the hand is replaced: the production draw pile remains,
so an invented empty deck cannot introduce fatigue on end-turn.

`instrument.gd` reuses `tests/sfx_sync_sources.gd` and
`tests/sfx_sync_pacing.gd`. It changes clock providers only in in-memory copies
of the run scene, board, hit-stop, intent callouts and pulsing badges. Retained
board layers share the movie clock. The sound bank receives `set_test_clock`;
registered/lazy legacy cue RNGs use the authored seed. Audio assets, gain,
pitch-jitter ranges, cue deadlines and effect functions remain production code.
No file under `scripts/` changes.

In headless validation only, the harness emits the prior frame's completion
signal because the dummy renderer never emits `frame_post_draw`. Movie Maker
uses the real renderer's signal. Headless logs explicitly say `headless: true`
and cannot authorize an encode as recording proof.

`trace.gd` records the last board submission within each movie frame and the
actual sound bank's emitted PCM, sample choice, pitch and gain. Analytics stays
enabled, with its original append-only JSONL behavior. Only its random session
IDs are excluded recursively from the separate deterministic demo log.

`pipeline.py` validates, records, compares and runs visual probes. Validation
gets a fresh timestamp directory and writes `validate-report.json`. Recording
requires matching validated inputs and records failures per clip while
continuing through the requested list. Re-recording replaces each clip's known
generated files, preserving unrelated files. Capture-input hashes include code,
scene/data files, approved art/audio, font files and import settings. Director
hashes use only `defaults` and each clip's `id`, `enemies`, `traps`,
`forced_intents`, `actions` and `combat_speed`. Titles, subtitles, caption style,
notes and reel labels are excluded. Changing a caption preserves take validity;
changing setup/actions/speed/volume/defaults invalidates it. Pipeline launch
arguments pass this normalized director hash into the scene's event report,
so a caption edit between headless validation and recording also preserves
comparison metadata. Direct diagnostic launches without that argument retain
the raw director hash. Encoding reads the current captions and records the
full source hash as `encoding_director_sha256` in the manifest. Other code or
asset changes still invalidate capture provenance.

`recording.py` runs clips sequentially in director order. `storage.py` calls
`shutil.disk_usage` on the output volume before creating any clip artifacts.
The minimum is 8,000,000,000 bytes (decimal GB). A failed guard stops without
writing that clip or a new error report; an earlier checkpoint remains marked
incomplete. Interrupted PNG sequences for requested clips are removed after
the initial guard, before any capture. Unrequested legacy PNG sequences still
prevent starting a batch. The current capture never creates a PNG sequence.

`capture_setup.py` creates `raw/<clip>/capture-project/`: a byte-identical copy
of `project.godot`, symlinks to the same resources/import cache, and a local
`override.cfg` preserving any root overrides and setting quality to 1.0.
Godot loads this view with `--path`, so the quality applies before MovieWriter
construction. The real project and root overrides are unchanged. Both
`editor/movie_writer/mjpeg_quality` and `editor/movie_writer/video_quality`
are set: [Godot 4.6 renamed the active property to video_quality](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-editor-movie-writer-video-quality).
`capture_settings.gd` reads and logs both the requested legacy value and the
active engine-version value; it never sets quality after startup. Both must
be 1.0. Recording parses the real Godot log for the Metal / Forward Mobile
header and that settings proof; missing or wrong proof fails the clip.

For each clip, `media.py` checks `movie.avi` for MJPEG video at 1920×1080 / 60
fps and stereo PCM at 48 kHz. It copies the audio track verbatim to `movie.wav`
for sync analysis and retained audio evidence; the AVI video is never
transcoded into another intermediate. Sync and duration are audited
immediately; `audit.json` binds those measurements to the AVI, extracted PCM,
cue PCM, renderer/settings log, startup configuration and headless reference.
`native_frame_offset_profile` records the initial native lag and the first
paired item where each change occurs: `item`, `headless_frame`, `native_frame`
and `offset`. It appears in the audit, `record-report.json`,
`compare-report.json` and delivery manifest. Timing failures retain the full
observed profile, including any out-of-range offset.
`comparison.py` merges paired events, board rows and clip bounds on the
headless timeline, using native time within a shared headless frame, to report
offset changes. Every paired item's offset is checked independently.
`comparison_exemptions.json` records only the reviewed Thornwall frame pairs,
bound to the reference payload hash and production source hashes. A matching
pair outside ±2 frames gets a `timing_exemptions` entry in the audit, recording,
comparison and encoding reports, with the measured pair, cause and evidence.
A changed frame pair, state, cue, sequence, clip or source is not exempt.
Payloads, state, counts, ordering and all other metadata remain exact except
the director-supplied `FLOAT_TOLERANCE = 1e-4` comparison of numeric floats.
The native log and WAV are never retimed. Headless repeat comparison keeps
absolute frame equality.
Legacy numbered PNGs are removed in `finally`; current captures use only AVI.
A failed clip is reported and the next clip is attempted. AVIs, logs and any
extracted PCM remain on failure. The full failure list and capture timing
table are printed at the end. `capture_wall_s` includes process startup and
GUI lease acquisition; `seconds_per_frame` divides that elapsed time by the
actual raw AVI frame count, including trimmed startup frames. `clip_wall_s`
also includes parsing, extraction and analysis. A failed take without a valid
frame count reports seconds/frame as unavailable.

The Godot task runner owns the capture watchdog and child-process termination;
there is no competing outer timeout that can kill the runner and orphan Godot.
Only one native take exists: `raw/<clip>/`, with no A/B native folders. Logs and
WAVs remain available on failure, together with any generated intermediate.
Encoding validates each take independently, so a failed or missing take does
not prevent other valid clips from encoding. A reel still requires every clip
in its authored list. Re-encoding validates sources first, writes a temporary
MP4 beside its destination, and probes it before an atomic replacement. Failure
preserves the previous clip/reel and removes the temporary file. In particular,
a rerun after successful AVI cleanup reports unavailable sources without
deleting existing deliveries. Input/media integrity checks and the disk guard
remain active.

`caption_raster.gd` typesets the supplied strings using Godot's approved
`UiTypography.ui_font()` glyph atlas, including the authored shadow. It needs
no window server or extra dependency. `encode.py` overlays this text raster
over the MJPEG AVI with ffmpeg. This also works with this machine's
ffmpeg build, which has no `drawtext` filter. The generated caption images are
output artifacts, not new art assets. Reels reuse the clip H.264 packets and encode AAC from original
trimmed PCM, avoiding another H.264 generation or repeated AAC encoding.
After all requested reels encode and pass frame-count, codec and rate probes,
`release_avis()` verifies every source AVI hash before deleting any AVI. Any
failed/missing clip, incomplete reel or failed probe retains all AVIs.
`manifest.json` records the source hashes, renderer/quality proof, capture
timings and `intermediate_cleanup`. Extracted PCM, cue PCM, logs and reports
remain. Run `compare` before `encode`: successful encoding consumes the AVIs,
so another comparison/encoding cycle requires a fresh recording.
`record-report.json` and `manifest.json` include `output_size_bytes`; recording
and encoding both print `DEMO OUTPUT SIZE` for the whole output directory.
The value is a snapshot at report generation, including retained validation,
logs, WAVs, intermediates and deliverables; subsequent proof screenshots/logs
can increase it.

`sync.py` locates emitted PCM in the actual recorded mix with waveform
correlation and applies sfx-04's RMS-peak convention. It reports identification
confidence and labels each row `measured` or `unmeasured`. Candidate selection
checks distinct waveform peaks as well as the strongest sample-level matches.
Any distinct competing candidate meeting the 0.65 identification threshold
makes the match ambiguous and unmeasured, regardless of how much stronger the
best match is; peaks at least 5 ms apart count as distinct. Another overlapping
sound can weaken a real occurrence's correlation without changing its timing.
Repeated identical cues cannot silently reuse the cleaner occurrence. Low correlation,
overlap and ambiguous visual contacts carry reasons, with no invented offset
or duration. Only measured offsets outside sfx-04 and measured status/trap
durations above 1.2 seconds produce flags. Status/trap duration is measured from the
matched cue contribution at its observed mix gain, with a recorded-tail check.
Offset and duration are measured independently: a row with at least one
measurement is `measured`, and `offset_status` / `duration_status` plus their
reasons identify any unmeasured metric. This preserves a measured trap duration
when visual-contact association is ambiguous. Trap removal is a contact too.
Both reports and the delivery manifest include `sync_summary` with flags,
unmeasured metrics and explicit `trap_durations` entries for `trap_enemy` and
`trap_hero` (`trap.trigger`, the production cue for the lightning trap).
The same information is printed as a table after recording and encoding.
UI, wind-up, footfall and ambience events remain listed as outside the requested
hit/status/trap measurements; the director's pull-only exception is explicit.
Sync timestamps are relative to raw Movie Maker frame/WAV zero. Subtract
`start_frame / 60` for time in the trimmed deliverable. Full native sync proof
remains pending the owner-run batch; round six audits the retained Meteorfall.

## Approved round-one direction

The encoder reads positions directly from the director data. Round eight
moves captions to bottom-left: title `(48, 930)`, subtitle `(48, 974)`, sizes
34 px and 24 px. There is no separate design override or placeholder file.

The dragon keeps the full 1.4-second post-settle tail, including Vyraketh's
next intent reveal. The obsolete next-intent boundary rejection is removed;
the normal presentation/audio settling and tail logic are unchanged.

## Proof for the design owner

Run this exact sequence with matching director source/import files. Every
recording is windowed and uses the real renderer. The round-nine probe smoke
attempt could not initialize the macOS GUI process; its launch block is
recorded below.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py validate
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py record
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py compare
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/encode.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py probe
```

`record` expands all 21 IDs in director order, creating one native take each.
Use this pipeline entry point so every native process is followed immediately
by AVI/PCM inspection and sync/duration checks. It invokes the Godot task
runner with `--write-movie <clip>/movie.avi`, `--fixed-fps 60`, `--windowed`,
1920×1080 and the per-clip project view. No renderer or driver override is
passed. The capture log must prove Metal / Forward Mobile and quality 1.0.

The corresponding individual visual probe is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/visual_probe_runner.py --task-id demo-01 --no-headless --audio-driver Dummy --timeout 300 --expect-size 1920x1080 --proof-contract tools/demo_clips/proof.json --result-manifest output/demo-clips-2026-10-15/proof/stab_normal/proof.json tools/demo_clips/probe.gd -- --probe --clip=stab_normal --output=output/demo-clips-2026-10-15/proof/stab_normal
```

Captures are `raw/<clip>/movie.avi`, extracted `movie.wav`, `events.json`,
`godot.log`, `audit.json`, cue PCM and `capture-project/`. The AVI is deleted
only after successful reel encoding/probing. No PNG sequences are produced.
Deliverables are
`clips/<clip>.mp4`; `reels/{pixel_fx,sound_sync,traps_and_weaver}.mp4`; and
`manifest.json`, all below `output/demo-clips-2026-10-15/`. Probe screenshots
are `proof/<clip>/<clip>.png` with the validated manifest beside them. The
pipeline creates local `.gitignore` and `.gdignore` markers. Failed clips are
not silently omitted from a reel. No `inspection_fixture.py` command is needed:
this brief's fixture is the recording scene itself, reconstructed per process.

Headless commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/godot_task_runner.py --task-id demo-01 --stream -- godot --headless --path . --script tests/demo_clip_clock_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 -m unittest discover -s tests -p 'test_demo*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/godot_task_runner.py --task-id demo-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Chosen defaults

Only non-player-facing implementation/test values were chosen:

- `MAX_CLIP_FRAMES=5400` (watchdog), `PREPARE_FRAMES=30` (startup trimmed from
  deliverables), `PROCESS_TIMEOUT_S=300`, `GUI_LEASE_TIMEOUT_S=30`.
- Clock epoch 10,000,000 microseconds, inherited from the existing sync harness;
  frame zero is still movie time zero in logs.
- Analysis rate 48 kHz in stereo (0.021 ms resolution), ±0.25-second waveform search,
  0.12-second identification window, minimum correlation 0.65. Deliverable audio
  remains 48 kHz. The initial correlation search samples every 48th sample,
  then verifies its candidates at full resolution. Ambiguous analysis is
  reported as unmeasured, without shifting audio. Stereo RMS and max-channel tail levels prevent
  cancellation from hiding an audible cue.
- 1 MiB streaming hash chunks for bounded-memory media integrity checks.
  The AVI format and quality 1.0 are director-specified.
- Synthetic lifecycle media: 320×180 with six frames. Caption/encoding proof
  uses 1920×1080 and 180 frames to exercise the authored bottom-left positions,
  a 440 Hz test tone, deterministic noise fixtures, and a 1.35-second overlong-status test.
  Caption positions use the approved director values.
- Visual probes delegate method/driver selection to the shared visual runner,
  which resolves this project's mobile renderer and 2D MSAA to Metal on macOS.
  The full-image proof region uses luma thresholds 3.0 range / 0.75 standard
  deviation. These do not set a game camera or UI value.

The 1920×1080 resolution, 100% UI scale, 60 fps, seed 410, speeds, pre-roll,
tail, caption sizes/colors, audio settings and encoding settings are specified
by the brief/director, not chosen defaults.

## Round-two verification (prior implementation)

Fresh proof logs are under `output/demo-clips-2026-10-15/` with the
`round-2-` prefix. The owner resolved both director decisions and synchronized
the protected source/import before this round. No design placeholders remain.

- `round-2-validate.log`: `DEMO VALIDATE RESULT: PASS (21 clips, 0 failures)`.
  All 21 staged states, action checks and exact headless log pairs pass. Input
  hashes match the current implementation; source/import SHA-256 is
  `3c237f0963c8c0ea6cb3000cc1ff61fe48f865f0bb01b932f8d1af45e6c8361c`.
- `round-2-focused-tests.log`: `Ran 21 tests in 2.012s` / `OK`.
- `round-2-clock-test.log`: `DEMO MOVIE CLOCK TEST: PASS (2 cue events)`.
- `round-2-python-suite.log`: `Ran 543 tests in 308.685s` /
  `OK (skipped=61)`.
- `round-2-godot-suite.log`: `FULL SUITE RUNTIME: 732.625 seconds (budget 900 seconds)` /
  `TEST RESULT: PASS`. Godot also emitted certificate and ObjectDB exit warnings.

`handoff.json` indexes this evidence and records a current output-size snapshot.
`OUTPUT GDIGNORE: PASS (13 folders; 2 referenced roots)` and `git diff --check`
also passed. No commit, peer review, publication or windowed run was performed.

The focused tests exercise lossless RGB frame equality, encoding from the
intermediate after source deletion, captions/fades, reel cuts, the exact 8 GB
guard boundary, no writes below the threshold, rechecking before the second
clip, one native take per clip, immediate audit, cleanup on conversion/sync/
comparison failures and capture exit 120, retained logs/WAVs/intermediates,
media tamper rejection, and output-size accounting. Native capture is mocked
in lifecycle tests: none of those tests opens a window.

The synthetic artifacts are `synthetic-proof/clip.mp4`, `reel.mp4` and
`fire_volley-caption.png`; these are 320×180 test assets, not gameplay proof.
A full native run, its WAV sync results, visual probes, final gameplay reels
and their total output size still require the owner-run windowed commands.

## Round-three verification (prior comparison policy)

Only the focused demo checks and full 21-clip headless validation were rerun:

- `round-3-focused-tests.log`: `Ran 27 tests in 2.032s` / `OK`.
- `round-3-clock-test.log`: `DEMO MOVIE CLOCK TEST: PASS (2 cue events)`.
- `round-3-validate.log`: `DEMO VALIDATE RESULT: PASS (21 clips, 0 failures)`;
  staged states, action validation and exact headless repeat logs all pass
  21/21, with current input hashes.

The native comparison tests accept uniform offsets −2 through +2, reject
mixed/larger offsets, payload/state/order changes and missing rows, and verify
that sync and duration retain native timestamps. The probe command test uses
the shared runner's resolver without opening a window and confirms mobile /
Metal at 1920×1080 for this project on macOS. No full suite or windowed command
was run in this round.

The retained Fire Volley capture does **not** have a single constant offset:
four setup/input/UI events have +0 and four later events have +1; 56 board
rows have +1 and two have +0. All non-frame payloads match. The strict
director-requested single-offset rule therefore still rejects this capture.
`round-3-retained-capture-comparison.json` records the evidence. Round four
supersedes the constant-offset policy with bounded, non-decreasing native lag.

The previous failed native capture and probe results are preserved under
`archive/round-2-windowed/`, including the WAV, lossless intermediate, logs,
audit and recording report. Default `raw/` and `proof/` paths are clear for
a new run; no recorded media was deleted or altered.

## Round-four verification (prior comparison policy)

The comparison now permits only native lag in [0, 2], non-decreasing over
time. Initial lag and every change are reported with both frame coordinates.
The director's described +0 startup followed by +1 from the first effect cue
passes the focused regression test. Native sync/duration timestamps remain
untouched, including when the lag grows during a clip.

- `round-4-focused-tests.log`: `Ran 32 tests in 2.211s` / `OK`.
- `round-4-clock-test.log`: `DEMO MOVIE CLOCK TEST: PASS (2 cue events)`.
- `round-4-validate.log`: `DEMO VALIDATE RESULT: PASS (21 clips, 0 failures)`;
  all 21 staged states, action checks and exact headless pairs pass with
  matching current input hashes.

Tests also reject native leads, lag above two frames, lag decreases within
either stream or between streams, and payload/state/order changes. Recording
and comparison report tests cover growing profiles, rejected profiles, and
unchanged native sync/duration inputs. No full suite, windowed process or Git
commit was run this round.

The actual retained Fire Volley take has a different board-row pattern:
`H29/N29 → +0`, `H86/N87 → +1`, `H88/N88 → +0`, `H90/N91 → +1`.
It therefore still fails the rule at `frames[1]`, where lag drops from +1 to
0. All paired non-frame payloads match. The read-only result and full profile
are in `round-4-retained-capture-comparison.json`. No startup-row exception
has been added; the director was asked to resolve this discrepancy with the
expected passing example. The archived take remains unchanged.

## Round-five verification (prior timing range)

The current rule checks each paired item's offset independently in [0, 2].
Lag may rise or fall; the monotonic check and its rejection tests are removed.
Payloads, order, states and other metadata still require exact equality, and
offset profiles remain in all reports. Native sync timestamps are unchanged.

`round-5-focused-tests.log`: `Ran 29 tests in 2.137s` / `OK`. Replacements
verify that +1, 0, 0, +1 passes, every item rejects offsets outside [0, 2],
and payload/order/state changes still fail. The retained Fire Volley capture
now passes; `round-5-retained-capture-comparison.json` preserves its full
profile. This resolves the round-four discrepancy without changing the take.

Only focused Python demo tests and the read-only retained-take comparison
were run. No validation run, full suite, windowed process or commit was made.
The prior validation report retains its original input hashes; run `validate`
before a new `record` to refresh provenance for the changed comparator.

## Round-six verification

Kept the director's `_same()` and `FLOAT_TOLERANCE = 1e-4` unchanged. The
focused test accepts a 2e-6 progress difference and rejects 1e-2.
`round-6-focused-tests.log`: `Ran 37 tests in 4.514s` / `OK`.

Tests cover informational measured flags/unmeasured rows through recording
and encoding, measured trap duration despite ambiguous contact, explicit
unmeasured trap reasons, obscured tails without invented durations, all 21
capture attempts with two failing takes, failure summaries, replacing prior
takes/interrupted PNGs, preserving unrelated files, and encoding valid takes
when another is missing. The existing disk bound and frame cleanup checks pass.

`round-6-meteorfall-audit.json` / `.log` use the retained native take without
changing its media or receipt: native/headless comparison passes; `hit.claw`
is measured at 28.021 ms; `status.bleed` is unmeasured at correlation 0.487;
`spell.fire` has ambiguous contact. There are zero flags and two rows with
unmeasured metrics. The native trap takes do not exist yet because the owner's
previous run stopped at Meteorfall, so their actual durations remain pending.

Only focused demo tests and this retained-take analysis ran. No validation,
full suite, new windowed process or commit was performed. Refresh validation
before the next recording; raw take directories no longer need manual clearing.


## Round-seven verification

Capture uses the project renderer and MJPEG/PCM AVI with pre-start quality
1.0. No production renderer/project setting was edited. Comparison policy,
float tolerance, sync-report policy, disk guard, continue-past-failures,
captions, delivery codecs and fades are unchanged.

- `round-7-focused-tests.log`: `Ran 42 tests in 5.428s` / `OK`.
- The real headless startup test loads the per-clip project view and verifies
  requested and active quality values both equal 1.0; root config is unchanged.
- `round-7-parser.log`: focused `demo_clip.gd` `--check-only` exits 0.
- Synthetic AVI tests verify MJPEG/PCM input, byte-identical extracted PCM,
  caption positioning/fades, trimming, reel cuts and successful reel probes.
  Lifecycle tests cover wrong-renderer failure with continued capture,
  per-clip timing, all 21 attempts, unchanged disk guards, retaining all AVIs
  for failed/incomplete/unprobed reels, source-hash checks before deletion,
  and successful deletion while preserving WAV/logs.

Native capture and renderer logs are mocked only in lifecycle tests. The
`DEMO VISUAL PROOF` line in the Python log comes from the mocked probe-command
test, not a GUI run. No windowed capture/probe, full suite or commit was made.
Actual Metal capture speed, native quality proof, full AVI sync results and
final gameplay reels remain for the owner-run sequence above. Prior native
media was not modified during this round. Refresh validation first because
capture-tool source hashes changed.


## Round-eight verification

Kept the director's `Engine.get_write_movie_path()` fix. The guard regression
executes the actual scene's startup guard through the existing compile seam,
with injected empty/nonempty engine-path values while real OS command arguments
omit `--write-movie`. It verifies the quality branch runs only for the nonempty
path. Actual headless Movie Maker frame capture crashes in this installed
Godot dummy renderer (`MovieWriter::add_frame` reads a null texture), so the
focused regression does not write frames. Native quality/renderer proof is
already present in the owner's retained batch.

The generic per-item tolerance is now [−2, +2]. The retained `enemy_bite`
passes: `events[5]` is its first card-draw cue at H146/N145; later items lead
by the same one frame. Native sync and duration timestamps are unchanged.

### Thornwall presentation wait

Both logs contain the same 23 events and 120 board rows, with identical
payloads and states within the existing 1e-4 float tolerance. Growth renders
at H123–139 / N123–139. The first delayed items are `events[6]`, the first
`card_draw_deal` cue, and `frames[42]`, at H153/N200 (+47). The second draw cue
is H162/N209 (+47). `events[8]`, the first end-turn completion, is H188/N229
(+41); subsequent events, board rows and the end bound retain +41.

The code path is `_resolve_enemy_round()` → `CombatPacing.finish_enemies()`
→ `_drain_turn_orders()` → `_animate_turn_order_transition()`. `finish_enemies`
awaits `_order_running`; the transition helper awaits remove/reflow/insert and
activation tweens. This is presentation work after the last growth submission
and before `_animate_draw_cards_fx()` schedules its first cue. No pickup or
fatigue animation intervenes in this fixture. The focused headless trace in
`round-8-diagnostic/run.log` directly observes this wait from H139 to H153.
The native completion at N200 is inferred from the next cue/board submission
and this code path; the extracted retained-video sheet
`round-8-diagnostic/turn-order.jpg` shows Turn Clock motion through that gap.
There is no combat-state or action-order divergence.

The six-frame reduction from +47 to +41 follows `_settle()`: headless card
draw/UI work finishes at H181 (also in the diagnostic trace), while the Earth
cue requested at H123 lasts 1.071064 seconds and keeps the harness waiting
until H188. Native draw/UI work ends at N229 after that sound has already
settled. The existing audio wait overlaps the longer native presentation wait.

The exemption is deliberately limited to these 96 observed item/frame pairs,
with a matching reference-payload fingerprint and unchanged production source
hashes. All payload/order/state checks run before exemptions. It grants no
clip-wide timing range and does not authorize other large offsets. The cause
and exact pairs are retained in `comparison_exemptions.json` and repeated in
comparison reports. The read-only 21-clip regression is
`round-8-retained-comparison.json`; no owner media, receipt or delivery was
rewritten. Refresh validation/recording once for this changed implementation;
subsequent caption-only edits preserve that new recording contract.


Round-eight observed results:

- `round-8-focused-tests.log`: `Ran 47 tests in 8.585s` / `OK`.
- `round-8-parser.log`: `demo_clip.gd --check-only` exit 0.
- `round-8-retained-comparison.json`: all 21 retained pairs pass; the Weaver
  lists 96 exact timing exemptions, and every other clip lists none.
- Director source/import remain byte-identical at raw SHA-256
  `bf1679785c0703cfd5e4e05a22ccd5c7aa9f5ebe35cad960ee4d203c75173b65`.
- `git diff --check` passes. No full suite, new windowed run, encode of owner
  media, or commit was performed. Existing native receipts/deliveries remain
  unchanged; the diagnostic comparison report is a separate artifact.


## Round-nine peer-review fixes

1. `probe.gd` stages each reconstructed game scene in a fixed 1920×1080
   `SubViewport`. Its texture is captured directly, with an explicit image-size
   check. Hover events use that viewport's local coordinates; probe input does
   not warp the OS pointer. Recording scenes remain outside this probe wrapper.
2. Clip/reel replacements use a sibling temporary MP4 and atomic rename after
   successful encoding and media probing. Missing sources, ffmpeg errors or
   failed probes preserve previous deliveries. The cleanup/rerun lifecycle
   regression preserves both clips and the reel after source AVIs are removed.
3. Repeated identical hit occurrences are reported as unmeasured with a named
   ambiguity reason and no false offset flag. The regression uses contacts at
   0.500/0.600 seconds with correctly aligned peaks at 0.515/0.615 seconds.
4. `tests/fixtures/demo_clips/weaver_reference.json.gz` is a portable reference
   payload. Tests generate native timing from the reviewed frame pairs and
   reject changed reference payloads, each source fingerprint, and each native
   or headless frame coordinate. None of these tests reads ignored owner logs.
5. The clock test asserts raw and presentation clock values on every frame at
   scales 0, 1 and 2, plus cue dispatch at frame 3 under scale 1 and frame 11
   after pause/scale 2. Removing time scaling now fails both clock values and
   the dispatch-frame check. The host-wall-delay repeat remains covered.

The ffmpeg wrapper regression checks decoder/filter thread options at 2; the
clip/reel encoding regression also checks its output thread arguments.

Observed focused proof:

- `round-9-focused-tests.log`: `Ran 51 tests in 10.367s` / `OK`, no skips.
- `round-9-clock-test.log`: `DEMO MOVIE CLOCK TEST: PASS (3 cue events)`.
- `round-9-viewport-test.log`: `DEMO PROBE VIEWPORT TEST: PASS (1920x1080; hover input)`;
  the test uses a 3024×1701 root to reproduce the backing-size mismatch.
- `round-9-parser.log`: `demo_clip.gd --check-only` exits 0.
- `round-9-mutation-checks.log`: removing reference/source fingerprints, exact
  frame matching or two-thread ffmpeg settings is caught. The isolated clock
  mutation in `round-9-clock-mutation.log` fails as expected when time scaling
  is removed. Production sources were never mutated for these checks.

**Real-renderer verification remains blocked, 0/21 fresh captures produced.**
The smoke attempt in `round-9-probe-smoke.log` failed before Godot created its
log: macOS GUI service connections were invalid, with `_LSModifyNotification`
and `com.apple.hiservices-xpcservice` errors. The computer-use tool also refused
Terminal access for safety reasons. No startup-timeout override or alternate
renderer was used to hide the launch failure. Existing takes, WAVs, receipts,
owner screenshots and deliveries were not changed. No full suite or commit ran.

Run all 21 fresh real-renderer probes with the same project-aware visual runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py probe --output output/demo-clips-2026-10-15/round-9-probes
```

This stages its own scenes and does not re-record any takes. A native pass must
produce 21 validated 1920×1080 images with Metal / Forward Mobile logs; the
headless viewport/input check and mocked Python probe test are not that proof.


## Round-ten probe hover fix

The director's round-nine real-renderer run passed 20/21 probes at the correct
image size. Weaver failed because its first scripted mouse motion reached the
SubViewport's `_input` listeners but not the production board's `_gui_input`.
A real pointer warp in the recording path established mouse entry; the probe
intentionally did not warp the OS pointer and never established that state.

`pointer.gd` now shares the hover route between recording and probing. It maps
the board-local tile centre through `get_global_transform_with_canvas()` into
that board's own viewport, calls `notify_mouse_entered()` for a SubViewport,
and sends a real `InputEventMouseMotion` through `Viewport.push_input(...,
true)`. No root-window backing/stretch factor belongs in those already-local
viewport coordinates. Root-window recordings keep their existing pointer warp
and normal GUI input path. No production board handler or hover state is
replaced or set directly by the hover helper.

The headless regression now uses the actual CombatBoardView and Weaver
fixture, not only a generic `_input` listener. Under a 3024×1701 root with
1920×1080 content, translated canvas/board coordinates, 0.9 board scale and
container stretch 1× / 1.575× / 2×, it verifies the GUI event's board-local
position, tile `(4, 4)`, and non-empty expanded intent rows. Each case starts
with the SubViewport mouse outside. Removing mouse entry reproduced all three
failures in `round-10-hover-before.log`; the fixed test passes and is also
included in focused Python discovery.

Observed proof:

- `round-10-focused-tests.log`: `Ran 52 tests in 14.213s` / `OK`.
- `round-10-viewport-test.log`: `DEMO PROBE VIEWPORT TEST: PASS (1920x1080; board tile (4, 4); GUI hover; Retina stretch)`.
- `round-10-parser.log`: `demo_clip.gd --check-only` exits 0.
- `git diff --check` passes. No full suite, commit, take recording or windowed
  probe was run in this round. The Python mocked probe-command test does not
  constitute real-renderer proof.

Only Weaver needs a new windowed probe, into a fresh proof directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/demo-01 && python3 tools/demo_clips/pipeline.py probe --clip weaver_thornwall --output output/demo-clips-2026-10-15/round-10-probes
```


## Round-eleven delta-review fixes

Removed the near-best correlation margin from ambiguity rejection. Every
distinct candidate meeting the existing identification threshold is now a
competing match, even when another occurrence correlates more strongly.

The new mixed-audio regression places identical correctly aligned hits at
0.500/0.600 seconds (peaks at 0.515/0.615). An unrelated voice overlaps only
the first hit at gain 0.75. The test first verifies that this weaker match is
still individually identifiable, then adds the clean second hit and requires
both audit rows to be unmeasured with ambiguity reasons and no offset flags.
Before the fix, `round-11-mixed-before.log` reproduces the false +115.000 ms flag.

The ffmpeg wrapper test now checks exact option counts before values: the
media wrapper requires one each of `-threads`, `-filter_threads` and
`-filter_complex_threads`; PCM decoding requires two `-threads` options and
one `-filter_threads`. Removing any required option is a failure even when
there are no remaining values to inspect.

Observed focused proof:

- `round-11-focused-tests.log`: `Ran 53 tests in 13.919s` / `OK`, no skips.
- `round-11-mutation-checks.log`: removing all PCM thread flags, one PCM
  `-threads`, or `-filter_threads` is caught. Restoring the near-best-only
  ambiguity rule is also caught by the mixed-audio regression. Mutations were
  in memory only and restored immediately; production files were not mutated.
- `git diff --check` passes. No full suite, windowed run or commit was made.
  Existing owner media, receipts and deliveries were not modified.
