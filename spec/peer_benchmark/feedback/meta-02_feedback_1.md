# meta-02 feedback 1 (director)

The Chronicle matches the mockup and its changes. Fix:

1. **Native capture**: the windowed probe failed "Real renderer at 1920x1080" ×4 and wrote 3024×1701 PNGs (it reads the
   Retina window texture). Render the probe into a 1920×1080 `SubViewport` (`UPDATE_ALWAYS`) and capture its texture,
   exactly like `tests/movement_undo_probe.gd`; keep the 100% UI scale assertion.
2. **Path icons**: the room icons show square dark corners outside their round rings (very visible on the dragon icon).
   Clip each icon to a circle 2 px inside its ring (34 px rooms, 44 px dragon, the 34 px defeat ring), so nothing
   square shows; same for any other circular icon slot on the screen.
3. **Main-menu first-click input test**: adapt its fixture to the new menu order (Continue, New Game, Chronicle,
   Settings, Quit) so its existing assertions check the same behaviours (no weakening); it must pass.
4. Leave the run-end recap test (7) and menu-resume test (4) failures alone — they reproduce on the base and belong to
   the QA unit; list them with one-line causes if you know them.

Proof: Chronicle suite + full suite + the first-click test green; list the windowed command again.
