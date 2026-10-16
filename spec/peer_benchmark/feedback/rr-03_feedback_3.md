# rr-03 — round 3 (director review of native_v01 + production probe)

Rig proofs all pass (rest, render, verify, motion gates, MAQUETTE_PROOF). Motion review of the front reel:
move/dive/hover read well. Changes:
1. **Motion data r2**: the director updated `spec/peer_benchmark/staged/rr-03/motion_tracks.json` (also copied to
   `experiments/cutouts/gust_shrike/motion_tracks_director.json`): idle amplitudes up (it barely read at board scale),
   death rolls ~70° onto its side and drops (25° read as alive), stronger hit. Re-import it exactly, rebuild, refresh
   motion samples and gates.
2. **Production probe**: failed with `ERROR: 1920x1080 production viewport` — the window gets clamped on this Retina
   display. Capture the production board through a fixed-size 1920×1080 SubViewport (as other probes do) and keep the
   76 real board frames; the probe must pass natively.
Do not commit. List the windowed command sequence again (native_v02).
