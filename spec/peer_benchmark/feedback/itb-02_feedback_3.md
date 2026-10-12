# itb-02 feedback 3 (final round)

Director native run after adding an extra settle before the baseline (my edit in tests/movement_undo_probe.gd,
keep it): fade now passes; the dock check still fails:
  MOVEMENT UNDO DOCK RECTS: before=[439.8, 838.8, 228, 58] shown=[439.8, 778.9, 228, 58] hidden=[439.8, 778.9, 228, 58]
So the movement chip moves up 60 px between "before walk" and "after walk", and it does NOT move between shown and
hidden — the undo button is not what moves it.
1. Determine whether the same 60 px move happens on the base commit without the undo feature (walk in the same
   fixture, compare the movement chip rect before/after). Report the root cause either way.
2. If it is pre-existing (unrelated to undo): change the probe to assert shown == hidden (the button never moves the
   dock) plus "dock after undo == dock after walk", and note the pre-existing move in spec/movement_undo.md.
   If it is caused by this unit: fix it so before == shown == hidden.
Then rerun the focused suite and the probe parser.
