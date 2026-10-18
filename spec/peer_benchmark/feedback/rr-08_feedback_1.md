# rr-08 — parked (2026-10-18)

The owner rejected the rr-07 rig style for humanoids (Seer and Thrall verdicts, feedback.md 2026-10-18). Every
humanoid moves to humanoid rig v2: `spec/peer_benchmark/humanoid_cutout_rig.md`. This unit's old-style result is
checkpointed at bb84ed68e and is NOT merged.

When rr-10 (Seer v2) lands, the director resumes this session to convert the Herald and the Gloam to v2. New motion
data will be staged then; `staged/rr-08` idles are superseded.

Answer to `TODO_DESIGN_herald_front_transparent_rgb`: a pixel with alpha 0 is transparent whatever its RGB. Compare
rest identity on premultiplied (or alpha-0-normalised) pixels. Don't edit the protected bytes.
