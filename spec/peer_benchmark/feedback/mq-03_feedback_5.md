# mq-03 feedback 5 — cloak split, corrected (director)

Findings 1, 2, 4, 5 and 6 are accepted. On finding 3, my depth rule was wrong. The cloak hangs behind the torso in
the front view and in front of it in the rear view, so a depth split puts the whole cloak in one part per view. The
classification work, validation and mutations you added stay. Only the rule changes:

1. **Split the cloak by body side, not by depth**, matching how the limb labels already work (`hand_far` is the spear
   hand in both views).
   - The sagittal plane passes through the torso bone's midpoint and contains the armature's forward and up axes.
   - Faces whose centroid is on the `shoulder_near` side are `cape_near`. Faces on the `shoulder_far` side are
     `cape_far`. Ties go to `cape_near`.
   - Compute it once in body space, so a face keeps its label in both views.
   - Geometry, pose, facing and joints stay frozen. Clay and beauty renders stay byte-identical.
   - Re-render the r3 delivery solos and parts maps.
   - `MQ03_OWNERSHIP_PROOF` must pass, with both cape solos non-empty in both views. Report the per-view pixel counts.
2. **Deterministic cache replay.** Replaying the cloth cache must give byte-identical raw mesh hashes to the fresh
   build. Canonicalise the polygon and loop order, or store the order with the cache. Add a test that builds, replays
   and compares the hashes. The delivery keeps using the approved saved geometry.

Re-run the focused maquette suites, the art-identity tests, the compatibility gate and the mutations.
