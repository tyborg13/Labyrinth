# rr-15 feedback 1 — rear tube points backward (root cause first)

Native gates now pass with two director-approved exceptions (`gate_exceptions.json`, front jab 22 and death 31:
natural armpit negative space). Windowed proof PASS: density, rest, native, sheets, idle, production, review. The
front view is right. The rear view isn't:

- **Evidence:** `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/thrall_v2/jab_native.png` and `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/thrall_v2/tether_native.png` (native frames; top row front, bottom
  row rear; rest, 25/30%, 45/50% contact, 65/75% hold). In the rear, at jab contact and through the tether hold, the
  tube points to the screen-left (up-left at jab, horizontally left in tether). The rear projection is
  `forward = (0.894, -0.447)` (upper-right), and `staged/rr-11` keys `tube_tip` forward 100/lift 59 (jab) and
  125/92 (tether). So the tip should travel up-right, toward the facing, not away from it. This is the owner's original
  complaint ("swings the gun arm backwards") in the rear view.
1. **Root cause with evidence:** per frame, log the authored `tube_tip` target, the solved tip, the elbow and the
   tube's world angle in both views. Find where the rear direction flips: the target offset, the two-bone solve or bend
   side, the reach clamp, the held-item world-angle policy, or the near-arm depth or parenting in the rear layout.
2. **Fix** it so the rear tube tip moves along the rear forward direction (up-right; it may pass behind the head or
   body, which is correct), using the same data as the front. Front output must stay byte-identical. No motion-data
   changes; if the data itself is the cause, stop and report.
3. **Check the Seer:** confirm with headless samples that the Seer's rear staff actions (mark, bolt, ward) move along
   the rear forward direction. If they share the bug, report it with numbers; don't change the Seer in this unit.
4. Add a gate: in every action clip, a hand or tube target that is keyed forward moves along that view's forward
   projection (dot product above 0), in both views.

Proof: headless focused tests, gates, the new direction gate with a mutation, the SFX programs and the registration
audit. List the windowed commands; the director recaptures. Commit nothing.
