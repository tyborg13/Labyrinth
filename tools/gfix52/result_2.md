# gfix-52 round 2 notice placement

The [owner's round 1 capture](../../.godot/gfix52/native/last_door_retreat.png) showed the Last Door and Grimoire notice behind the Emaciated Man's lower gradient and reveal prompt. The focused check on `fa04a21be` measured the same overlap.

```text
GFIX-52 notice_placement | gradient_top=600.0 raised_bottom=1058.0 gap=-458.0 resting_bottom=1058.0 returned_bottom=1058.0 clear_through_fade=false eased=false
GFIX-52 RETREAT CAPTURE DRY RUN: FAIL
```

## Implementation

- [hud_seat_scrim.gd](../../scripts/hud_seat_scrim.gd#L35) exposes the configured bottom gradient's bounds in canvas coordinates. [dialogue_box_view.gd](../../scripts/dialogue_box_view.gd#L424) publishes the top of the visible gradient and ink band as the shared view lays out. The view clears the boundary when the band finishes fading.
- [run_scene.gd](../../scripts/run_scene.gd#L6138) connects the shared band to [run_notice_placement.gd](../../scripts/run_notice_placement.gd). Placement shifts both vertical offsets by the same amount. The stack retains its size, right margin, order, and usual Hearth lift. The notice stays at least 16 px clear while the band draws and returns over 0.2 seconds with the HUD's quadratic ease-out. The existing queue owns notice content, visibility and timing.
- [retreat_capture.gd](retreat_capture.gd#L113) waits for the actual post-retreat dialogue to finish typing and for the actual notice to be visible. It verifies the clearance, unchanged width and right margin, clearance through the close fade, an intermediate return position, and the original rectangle and notice text after closing.

## Verification

The focus check and full retreat dry run shared one task-runner invocation. The candidate left the notice at y=584 against the gradient's y=600, then returned it to y=1058.

```text
GFIX-52 live_retreat | passes=5 fight=(1, -1) returned=(0, 0) Health=1 HUD=1/24 saved=true skill_receipts=1
GFIX-52 notice_placement | gradient_top=600.0 raised_bottom=584.0 gap=16.0 resting_bottom=1058.0 returned_bottom=1058.0 clear_through_fade=true eased=true
GFIX-52 RETREAT CAPTURE DRY RUN: PASS
HEIRLOOM NOTIFICATION TEST RESULT: PASS
```

UI identity lint printed `Ran 25 tests in 5.058s` and `OK`. The Python default group printed `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 31.610s`, and `FAILED (failures=1)`. Its sidecar inventory check failed because Git does not track these three files, which are present in the worktree:

- `tools/gfix52/retreat_capture.gd.uid`
- `tools/gfix52/run_skill_rules.gd.uid`
- `tools/gfix52/witnesses.gd.uid`

All three were already untracked when round 2 started. They are retained, and the new placement script has its adjacent UID. The sidecar check reads the Git index. Both the gameplay and Python verification logs are under `.godot/gfix52/round-2/`.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-52 && sh tools/gfix52/native.sh
```

The launcher uses the visual probe runner, `LABYRINTH_CEL_LOOK=all`, and 1920×1080 at 100% UI scale. It prints both PNG paths on separate lines. The windowed outputs await the owner's run.

- `.godot/gfix52/native/last_door_retreat_dialogue_open.png` shows the settled, fully typed dialogue and the lifted notice.
- `.godot/gfix52/native/last_door_retreat_dialogue_closed.png` shows the same room after the notice returns home.
- `.godot/gfix52/native/round-2-manifest.json` records the validated capture paths and dimensions.

The proof waits up to 12 seconds for the typed line and visible notice, and up to 2 seconds for the return. These are probe-only limits. There are no new design placeholders. The work remains uncommitted on `codex/gfix-52`.
