# gfix-48 director feedback 2

## Native failure

Godot's own log from the director's Metal run records `first_reduced_offer_before.png` first, then `GFIX-48 PROBE FAILURE the reduced-motion popup intersects the caption scrim or loses opacity` on line 33 and `INSPECTION FIXTURE ERROR: first_reduced` on line 34. The reduced scene had opened, selected Movement and captured its offer. The fixture message came from the inherited `_fail()` after `_replay()` returned false. The wrapper captures stdout and stderr separately, so redirected output placed the stderr summary before the buffered stdout. This chronology was checked against the actual native Godot log and rendered offer PNG. [Godot log](/private/tmp/labyrinth-godot-home/gfix-48-1795533893801275000-27247-scene_probe-1/godot.log) · [Native offer PNG](/private/tmp/labyrinth_codex/gfix-48/native.zRv7Qf/first_reduced_offer_before.png)

The native check read `_floating_text_last_layout` from `EffectsRenderLayer`. The production threat-isolation draw plan puts `_draw_floating_texts` on an animated child canvas, so the parent has no matching painted layout. The old headless branch computed a layout directly on the parent and missed the ownership error. The probe now finds the canvas that owns the actual draw operation, matches the cached entry by layout key, and checks its opacity and painted rectangle against the live caption scrim in viewport coordinates. Headless computes placement on the same canvas. Both reduced cases identified `EffectsRenderLayer/RetainedSlice4` in the dry run. Diagnostics distinguish fixture opening, missing painted layout, opacity, and scrim intersection.

## Capture Health

The Last Eclipse capture uses the production starting Health calculation at the checkpoint's saved Umbra Depth. That yields **24/24**. The capture writes those values into both the run and combat player fields in its own save copy. The original QA-133 checkpoint remains available to the separate state repro.

## Receipts

```text
GFIX-48 WORKTREE STATE: 12 checks, 0 failures
GFIX-48 STRIP first_normal: contact=100 ms, popup=490 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP first_reduced: contact=0 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_normal: contact=360 ms, popup=480 ms, 6 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 STRIP one_step_reduced: contact=300 ms, popup=900 ms, 0 shake half-cycles, 1 collision cue, save/resume PASS
GFIX-48 SCENE STRIPS: 4 cases, 0 failures (headless dry run)
GFIX-48 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/gfix-48/headless.XSpGDy
```

All four scene outcome receipts match round 1 after substituting the requested Last Eclipse capture Health. Both raw state-repro outcome lines match round 1 exactly. [Dry-run log](../../output/gfix48/native-round2-dry.log) · [State repro log](../../output/gfix48/worktree-round2.log)

## Native verification

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-48 && tools/gfix48/native.sh
```

The launcher retains the 30 ms strips and each full-frame contact +60 ms capture. The updated native run remains pending on a Mac with window-server access. This round changes only the task-local scene probe and this report. Changes remain uncommitted.
