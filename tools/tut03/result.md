# tut-03 first Umbra video

## Requirements

1. `record.sh` launches Godot Movie Maker with the production cel look at 1920×1080, 100% UI scale, and 30 fps. The recorder preserves the game's stereo mix and verifies H.264 video and non-silent AAC audio before delivery. Native stills require the game's cursor to be visible.
2. The rehearsal starts with the lantern at `(-1, 0)` on the section map. A mouse click on the connected `(2, 1)` room activates its door at `(8, 4)`. Begin is a separate click required by the production entrance. The tool waits for the full entrance and combat intro, performs the reading and hover holds, and clicks Continue. A click on the hero selects movement and a click on `(1, 3)` commits the walk from `(1, 4)`. The tool uses straight smoothstep mouse glides and production control geometry.
3. The route compares the encounter to the tut-02 fixture and fails on a missing pointer, wrong heading, failed hover, missing save receipt, or wrong movement result. It reads the popup's displayed text and confirms `umbra_read` in the isolated profile and run checkpoint on turn 1.
4. A successful native run leaves `flow.mp4`, `contact-sheet.png`, and `checks.log` under a fresh `/private/tmp/labyrinth_codex/tut-03/take.XXXXXX/`. The contact sheet uses six frames from the same recording session, in route order. The recorder removes the AVI and other intermediates after media and still verification. Native delivery and visual inspection are pending a Mac window-server session.

## Files changed

- `route.gd` and `route.gd.uid` drive and check the take through production mouse input.
- `take_fixture.gd` and `take_fixture.gd.uid` restore the preceding room and query valid board tiles.
- `record.sh` and `record.py` launch, log, verify, encode, and deliver the take.
- `proof_contract.json` requires six individually named 1920×1080 source frames.
- `result.md` records the implementation and proof. All changes are uncommitted.

## Headless proof

The route exited 0. Its 598 frames at the requested cadence amount to about 20 seconds. The Godot process emitted the macOS system CA certificate diagnostic and completed every check.

```text
TUT-03 STEP 1 PASS: map=(-1, 0) door=(8, 4) destination=(2, 1) seed=90212
TUT-03 STEP 2 PASS: room=(2, 1) turn=1 intro=settled concealed_enemy=true
TUT-03 STEP 3 PASS: pointer=visible heading=UMBRA title=Fringe Umbra rest_tile=(2, 1)
TUT-03 STEP 4 PASS: popup=visible text="FRINGE UMBRA\n  Personal vision covers these tiles.\nTiles outside your sight or a Light source are obscured. Hidden enemies cannot be targeted and show no intents.\nVision shows hidden enemies."
TUT-03 STEP 5 PASS: card=closed profile=umbra_read checkpoint=umbra_read turn=1
TUT-03 STEP 6 PASS: hero=(1, 4) -> (1, 3) path_steps=1 turn=1
TUT-03 ROUTE PASS: 6 steps, 598 frames after map start
```

The rehearsal receipts are `/private/tmp/labyrinth_codex/tut-03/dry-run.ZHh7Ov/checks.log` and `/private/tmp/labyrinth_codex/tut-03/dry-run.ZHh7Ov/route.json`.

| Check | Observed result |
| --- | --- |
| Shell syntax, Python parse, six-image contract | `TUT-03 WRAPPER AND PROOF CONTRACT: PASS` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.071s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| `python3 -B tools/cel_look.py status` | `CEL_STATUS current` |
| FFmpeg capability checks | `libx264`, `aac`, `atrim`, `trim`, `xstack`, and `volumedetect` are available. |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-03 && tools/tut03/record.sh
```

Keep the recording window focused and leave the pointer alone during the take. The script prints the fresh output directory. Movie Maker runs through the Godot task runner and uses the visual probe runner's renderer selection, GUI lease, and PNG proof validation.

Rehearse the route headlessly with the same entry point.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-03 && tools/tut03/record.sh --dry-run
```

## TODO_DESIGN placeholders

- `TODO_DESIGN_UNTIMED_GLIDE_SECONDS` covers the door, Begin, empty-board rest, hero selection, and move-target legs. The fallback reuses the brief's 0.6-second glide for preview.

## Chosen defaults

- Allow six startup frames for layout and up to 900 frames per readiness check. The Godot task runner supplies its 300-second process cap.
- Pace the headless rehearsal at up to 30 fps so background asset preparation can progress in real time. The native movie uses Godot's fixed 30 fps clock.
- Allow two frames of tolerance where the route's frame receipt and Movie Maker's count meet. Reuse the smoke recorder's 640×360 contact cells, three-column layout, encoding quality, and two FFmpeg threads.
