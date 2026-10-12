# itb-02 feedback 1

Director decisions applied directly in your worktree (keep them): `UNDO_BUTTON_HEIGHT = 34`, `UNDO_BUTTON_GAP = 6`,
undo plays `RunSfxLibrary.MENU_CLOSE_ID` (spec/movement_undo.md "Presentation values" updated).

Windowed probe run by the director (`tests/movement_undo_probe.gd`, 1920x1080): captures look right, 2 assertions
fail:
1. "Undo matches movement chip width and sits directly below it" — expected now: y == chip bottom + UNDO_BUTTON_GAP.
   Update the assertion (use the constant).
2. "Hero fades back over the authored 0.12 seconds" — at 0.06 s the sampled rig alpha is not between 0 and 1. Find the
   root cause (likely the board rebuilds the hero rig after the state restore, so the fade targets a discarded rig or
   the new rig starts opaque). The fade must be visible on the rig that is actually drawn after undo. Fix it and keep
   the assertion; also assert the drawn rig alpha reaches 1.0 by 0.2 s.
Then rerun the focused suite and the probe parser check; the director reruns the windowed probe.
