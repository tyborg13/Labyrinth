# rr-02 — round 8 (director: native motion gate contract)

Round 7 is committed (83c3a65fa); the v07 reel looks right (walk clean in both views). The native motion gate still fails
for a tooling reason: the visual probe runner rejects the probe's own data captures as screenshots —
`.../probes/maquette_motion/front_chain_reel/rest_dark_0000.png has too little pixel variation` — so `motion_gates.py`
reports "Native ownership probe failed" and `proof.py` cannot find `motion_gate_capture/sha256.json`.
Fix: ownership/rest-dark/mask captures are data, not screenshots — write them outside the runner-validated screenshot set
(or mark them as data in the proof contract so the variation check skips them), keep real screenshots validated; make
the native probe's timeout configurable and sized for 460 poses under load (it timed out at 300 s once). The windowed
sequence must end with `MOTION GATES: PASS` and `MAQUETTE_PROOF: PASS`. Do not commit. List the windowed commands with
capture path `/private/tmp/rr-02-mq3-render-v08`.
