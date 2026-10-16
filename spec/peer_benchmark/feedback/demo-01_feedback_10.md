# demo-01 — round 10 (director's real-renderer probe run of round 9)

`pipeline.py probe --output output/demo-clips-2026-10-15/round-9-probes`: 20/21 PASS. weaver_thornwall FAILS:
"real mouse hover did not reach the actor tile" and "Weaver hover did not expose a non-empty board intent"
(Godot exit 1; proof: output/demo-clips-2026-10-15/round-9-probes/proof/weaver_thornwall/). The hover is now routed
into the fixed 1920x1080 SubViewport — check the coordinate mapping from the SubViewport/stretch to the board tile
(Retina 2x window: 3024x1701 window vs 1920x1080 viewport) and that the hover event reaches the same input path the
recording used. Add a regression that maps a known tile centre through the probe's input routing headlessly.
Focused tests only; do not commit; list the single windowed command to re-probe weaver_thornwall.
