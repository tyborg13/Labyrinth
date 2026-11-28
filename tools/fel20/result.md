# fel-20 screen-flow census

Production game files are unchanged. The harness starts a fresh profile on the
title screen and uses the deterministic run seed hook. The inherited fel-01
resolver and fel-10 movement preferences choose legal offers. The harness drives
the actual UI with `Viewport.push_input` clicks, key events and hover events.
Neither the hunt dispatch methods nor the OS pointer are used. The defeat route
keeps passing in real combat so seeds 15 and 17 each reach a real recap.

## Measurement

- **First response.** The clock starts immediately before the activating input
  reaches the viewport. Headless observes presentation state at simulated draw
  boundaries. Native compares each full RGBA framebuffer with its predecessor,
  starting with the final pre-input frame. Ambient motion can contribute to a
  native pixel change.
- **Input ready.** Each sampled frame before acknowledgement receives a harmless
  motion event. Once the destination is present, the probe re-enters an
  enabled destination control or hovers the hero's board tile. The witness
  records the resulting GUI hover owner or production board hover. It also
  checks destination-specific input gates, including the opening combat lock,
  transition overlay, event request and pre-battle focus gate.
- **Total.** The last change followed by at least 250 ms without a change and
  after the observed authored beats have ended. Native uses exact framebuffer
  equality. A screen with continuing ambient motion can lack a finite total.
  Timing JSON retains the final observed change and the observation limit.
- **Still runs.** The native analysis uses fel-09's consecutive-frame method
  across all 1920×1080 pixels. Fewer than one changed pixel per thousand counts
  as still. Runs intersected with the input-to-ready interval flag at 150 ms.
  Native pixel timing and still-run analysis use uncompressed frames. MP4
  playback is resampled from the recorded wall timestamps.
- **Hitches and flags.** Consecutive frame timestamps produce the >33 ms and
  >50 ms lines. The hitch interval ends at total or at the observation limit
  when total is unavailable. The first response flag is >100 ms. The ready
  flag is >600 ms for menu actions and >1500 ms for other screens. A native row
  can also flag on a still run. `flagged=M` counts transitions with at least
  one flag. The detailed log and report list individual hits.
- **Beats.** Source locations identify the waits and presentation phases
  sampled by the harness. The dispatch span measures synchronous work inside
  the input delivery. Spans can overlap. The kill and defeat samples begin
  with the input that leads to the ending, such as a confirming click or Pass.
  Headless timings include CPU load and are presentation-state approximations.
  Native timings include renderer readback and the frame spool; per-frame
  readback cost is retained. Encoding and still-run analysis finish between
  measured transitions.

## Chosen defaults

The route uses seed 15 for progression and seeds 15 and 17 for the pass-only
defeat route. The instrumentation frame cap and video time base are 60 fps.
Measured inputs use 1× engine time and the production Normal combat speed.
Unmeasured setup may use 6× engine time and gives controls three frame
boundaries after moving the pointer. Screen probes allow 30 seconds to observe
a handoff and 4.5 seconds after acknowledgement to observe motion. The route
allows 20 seconds for a decision and 90 seconds for a boot or capture write.
The route tries a no-op input at most twice at a combat or map boundary.
Playback spaces extra dialogue Continue taps by 250 ms. The frame writer can
queue 16 raw frames. The native wrapper allows 2400 seconds per replay. These
values are local to the harness.

## Proof for the design owner

Run the full native replay with the real macOS renderer and default audio
driver. Leave the window alone while the viewport sends its inputs.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && bash tools/fel20/native.sh --dry-run
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && bash tools/fel20/native.sh
```

The wrapper calls `tools/visual_probe_runner.py` with the 1920×1080 proof
contract. Both replays run at 100% UI scale with `LABYRINTH_CEL_LOOK=all`.
Each windowed run writes one audio MP4 per transition, a verified renderer
image and manifest, the runner and capture logs, and native timing JSON under
`tools/fel20/captures/native.*/`. The wrapper merges native observations into
`census.md`. No native measurement was taken by the implementation sandbox.

To capture a single transition by its action number, add `--only-action N`.
The default replays the descent prefix. For the pass-only transcript, also
specify `--replay tools/fel20/replay-defeats.jsonl --headless tools/fel20/headless-defeats.jsonl`.

## Checkpoints and headless replay

Each available committed boundary is copied under the headless output
directory's `checkpoints/`. The replay row records its relative path.
The checkpoint bundles the run save, progression and preferences, plus recent
event history where available. It is staged into a new isolated profile before
using production Continue. Transient menus, a selected card, an uncommitted
shop selection and the recap may require replay from an earlier boundary.
After defeat the game clears the active save. Replaying the original prefix
covers those cases.

This direct checkpoint check stages the first pass-only fight's pre-battle save
and replays action 7 on its own.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && python3 tools/godot_task_runner.py --task-id fel-20 --stream -- godot --headless --path . --script tools/fel20/census.gd -- --replay tools/fel20/replay-defeats.jsonl --checkpoint tools/fel20/captures/headless-defeats/checkpoints/00007 --start-action 7 --limit 7 --output-dir "$(mktemp -d /tmp/labyrinth_codex/fel20-resume.XXXXXX)"
```

Windowed single-action replay also accepts `--checkpoint PATH --start-action N`
when the saved screen matches that action's recorded source. Use
`--only-action N` or a later action on that same transcript.

## Recorded headless evidence

The continuous seed-15 descent ended against Vaeloryx in the first section
after 317 viewport actions. It chose Skip & Recover at both combat rewards and
bought one ware from its only Scavenger visit. A section change never came up.
The pass-only transcript contains two fresh descents through their recaps and
returns to title.

The replay resolves the campfire choice by its production choice ID and
skips one early treasure click that did not commit a choice. Action numbers
still refer to the original discovery transcript.

| Run | Runner result | Capture directory |
|---|---|---|
| Seed 15 descent | `FEL20 CENSUS DONE transitions=47 flagged=27` | [headless-descent](captures/headless-descent/) |
| Seeds 15 and 17, pass only | `FEL20 CENSUS DONE transitions=8 flagged=8` | [headless-defeats](captures/headless-defeats/) |
| Pass-only transcript replay | `FEL20 CENSUS DONE transitions=8 flagged=8` | [headless-defeats-replay](captures/headless-defeats-replay/) |
| Direct Scavenger checkpoint | `FEL20 CENSUS DONE transitions=3 flagged=2` | [checkpoint-shop](captures/checkpoint-shop/) |
| Direct pre-battle checkpoint | `FEL20 CENSUS DONE transitions=1 flagged=1` | [checkpoint-prebattle](captures/checkpoint-prebattle/) |

The census uses the two discovery runs. Replay checks are separate. Other scoped
checks ran during portions of discovery, so the headless frame gaps include
that load. The raw timing JSON and runner logs retain the individual samples.

To regenerate the discovery data, use fresh output directories.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && python3 tools/godot_task_runner.py --task-id fel-20 --timeout 1800 --stream -- godot --headless --path . --script tools/fel20/census.gd -- --seeds 15 --limit 700 --output-dir "$(mktemp -d /tmp/labyrinth_codex/fel20-descent.XXXXXX)"
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && python3 tools/godot_task_runner.py --task-id fel-20 --timeout 800 --stream -- godot --headless --path . --script tools/fel20/census.gd -- --seeds 15,17 --pass-only true --limit 140 --output-dir "$(mktemp -d /tmp/labyrinth_codex/fel20-defeats.XXXXXX)"
```

The saved map at descent action 222 also replayed the Scavenger entry,
purchase and exit through actions 222–225. That is a second timing of the
same shop. It counts as one visit in the continuous descent.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && python3 tools/godot_task_runner.py --task-id fel-20 --stream -- godot --headless --path . --script tools/fel20/census.gd -- --replay tools/fel20/replay.jsonl --checkpoint tools/fel20/captures/headless-descent/checkpoints/00222 --start-action 222 --limit 225 --output-dir "$(mktemp -d /tmp/labyrinth_codex/fel20-shop-check.XXXXXX)"
```

The descent replay was verified in segments. The title-to-guardian prefix
produced the first 37 measured transitions before a relic selection missed
its live control. With current geometry resolution, replay from the committed
combat checkpoint immediately before the claim reached the same guardian
reward, shop, final fight, recap and title. The union matched every measured
action in the descent trace.

- `FEL20 HEADLESS REPLAY COVERAGE 47/47 (37 title prefix, 10 checkpoint tail)`.
  [Prefix log](captures/descent-replay-prefix/godot.log)
- `FEL20 CENSUS DONE transitions=10 flagged=8`.
  [Checkpoint tail log](captures/descent-replay-tail/godot.log)

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-20 && python3 tools/godot_task_runner.py --task-id fel-20 --timeout 700 --stream -- godot --headless --path . --script tools/fel20/census.gd -- --replay tools/fel20/replay.jsonl --checkpoint tools/fel20/captures/headless-descent/checkpoints/00216 --start-action 216 --output-dir "$(mktemp -d /tmp/labyrinth_codex/fel20-descent-tail.XXXXXX)"
```
