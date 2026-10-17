# mq-03 feedback 4 — peer review CHANGES REQUESTED on 91eb24aaf

The full review is `spec/peer_benchmark/feedback/mq-03_review_91eb24aaf.md` (integration branch). Fix all six findings.
The owner-approved Lancer painting came from the r3 maquette, so r3 geometry, facing and pose must not change. Only
ownership labels may change, and only as specified below.

1. **Legacy compatibility (blocking).** Prove it through the Blender bridge. It is running for this worktree, so use
   the client you added in round 3. For Lancer r1, Lightning Wisp, Shale Bloomer, Gust Shrike and Gaoler, build the old
   and new outputs and compare the solos (every part IoU ≥ 0.98, joints within 1 px). Write the results into
   `proof_mq02/compatibility_summary.md` and make `maquette_fit.py compat --require-gate` exit 0. If a figure fails,
   fix the builder; never loosen the gate. If the bridge does not answer a job within 120 s, stop and report it under
   "Proof for the design owner" with the exact queue JSON, and I'll restart it.
2. **Stale fit mattes.** Record the capture mode and per-image hashes in the capture manifest. The loader accepts
   only images the manifest names for the current spec hash and mode. A full capture deletes leftover fit-only mattes.
   Add a regression test for the reviewer's reproduction: 500-px stale masks next to a 2,000-px current capture must
   be rejected.
3. **Cloak ownership (director decision).** Split the r3 cloth cloak per view by depth:
   - Faces whose centroid is farther from that view's camera than the torso's centre plane are `cape_far`; the rest
     are `cape_near`. The torso's centre plane passes through the torso bone's midpoint, perpendicular to the camera
     view vector projected onto the ground.
   - Ties at the plane go to `cape_near`.
   - Front and rear are computed independently.
   - Both solos must be non-empty in both views for the Lancer r3.
   - Validation checks that every rig label the spec requires has a non-empty solo, and that polygon material
     ownership matches the weight winner.
   - Add mutation tests: all weighted faces `torso`, all material index 0, two winning regions, and a stable tie.
   - Re-render the r3 delivery solos, then report the new cape_near/cape_far pixel counts per view. The clay and
     beauty renders must stay byte-identical.
4. **Bezier conformance.** Handle `bezier_points` (the coordinate plus both handles) as well as `points`. Add
   behavioural tests for both spline types that count projection calls and check the moved control points.
5. **Facing probe.** Reflect about pixel centres consistently, including centreline sampling. Add a symmetric frontal
   fixture that must report a mirror difference of 0 and fail the facing check.
6. Remove the tracked `__pycache__/*.pyc` files and ignore Python bytecode under `spec/art_identity/maquettes/`.

Re-run the focused maquette suites and the art-identity tests. Report the four survived mutations from the review as
caught.
