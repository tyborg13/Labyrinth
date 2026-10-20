# ui-03 feedback 2 (director; windowed proof review of 4b15ff5ff)

The stills match the approved mockups: seal, rim, cost 4 → 6, blocked slash, controller and reduced-motion variants.
Two proof defects remain, and one requirement is unproven. Focused tests only.

Director commits since your round 1 (keep them):
- `61d02eaa6`: the clip adapter starts `--windowed`.
- `4b15ff5ff`: the clip root uses viewport stretch at exactly 1920x1080. A HiDPI window otherwise cropped the layout.

1. **The real desktop mouse leaks into the clip.**
   - Evidence: `output/ui03/empower-interactions.avi`, frames ~140–175. After the seal click charges Overhead Smash,
     the hand re-lays out. Quick Stab is then hovered at the OS cursor's position (the drawn cursor sits at ~(500, 990)),
     and its tooltip stack covers the charged card for ~0.5 s before the drag starts. The same stray cursor shows in
     later frames.
   - Fix: isolate the clip from the desktop.
     - Run the scene in a 1920x1080 `SubViewport`, shown full-window by a plain `TextureRect` with no input
       forwarding.
     - Push every synthetic event into that SubViewport.
     - MovieWriter keeps recording the root.
   - Never warp the real mouse.
   - Before each press, the probe moves the pointer to the press point, so hover always matches the action shown.
2. **The seal tooltip is unproven** (requirement 4 hover, and requirement 5 tooltip lines).
   - `seal_hover_tooltip.png` shows the seal hovered but no tooltip. The clip holds on the seal for 0.5 s, under the
     tooltip delay.
   - First establish, with a headless test using routed pointer motion on the real `RunScene` root, whether hovering
     the seal shows its tooltip in the game.
     - If it doesn't, fix it. Then the test fails before your change and passes after.
     - If it does, the capture is the defect. Make the still show the real tooltip as the player sees it.
   - Clip: hold on the unlit seal until its tooltip has been fully visible for 0.4 s, then click. After the charge,
     keep the pointer on the seal until the charged tooltip has been visible for 0.4 s.
   - Expected text: line 1 `Empower: +2 Time · Stagger +4`; line 2 "Click the seal or press E", then "Charged. Click to
     cancel."
3. Keep everything else unchanged.
   - List the exact windowed stills and clip commands under "Proof for the design owner".
