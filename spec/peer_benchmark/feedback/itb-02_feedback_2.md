# itb-02 feedback 2 — native probe still fails 2 checks (director run, 1920x1080, macOS Metal)

1. "Drawn hero alpha reaches 1.0 by 0.2 seconds" fails natively. Print the sampled alpha, the elapsed time and whether
   the fade coroutine is still running. Find the root cause (e.g. the fade stops before setting exactly 1.0, a frame
   stall during the capture, or a second rig) and fix the behaviour so the drawn rig always ends at exactly 1.0 once
   0.12 s has elapsed (set alpha = 1.0 explicitly on completion and on any interruption).
2. "Hiding undo leaves the resource dock unchanged" fails natively: the movement chip's global rect differs before
   showing the button vs after hiding it. Print both rects. The dock must not move when the button appears or hides
   (the button must not take part in the dock's layout; position it as an overlay below the chip, or reserve nothing).
   Fix the layout, keep the assertion.
Add the printed values to the probe metadata. The director reruns the native probe.
