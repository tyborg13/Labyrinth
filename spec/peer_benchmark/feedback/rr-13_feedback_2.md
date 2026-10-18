# rr-13 feedback 2 — peer-review fixes (gates and tests only)

The Codex peer review of `5b486cfb5..4c3f86339` asked for changes; the review is in
`spec/peer_benchmark/feedback/rr-13_review_4c3f86339.md` on integration (excerpts below). Fix findings 1, 2, 5 and 6
here. Findings 3 (foot IK / knee-bend walking) and 4 (Seer specifics in the generic modules) move to rr-11, the second
humanoid; don't touch them now.

Keep motion data, paintings, the exception list, the runtime and other creatures unchanged.

1. **Hole gate locality (Medium).** `tools/humanoid_cutout/silhouette_gates.py` (~line 103) skips any hole that
   extends past the seam neighbourhood. With the committed elbow fixture, a 3×3 deletion is flagged `[9]` but a 7×7
   deletion returns `[]`.
   - Fix: decide locality by overlap with the seam band, and never exempt a component for being large.
   - Keep the approved calibrations unchanged: the hole counts only where ≥80% of its boundary is one joint pair, and
     staff-bounded holes stay exempt.
   - Regression: the 7×7 elbow deletion is flagged; the 3×3 case still is.
   - Re-run the native gates over the existing captures in `proof/native/` without recapturing (art and motion are
     unchanged). If the stricter rule raises new flags on real frames, don't add exceptions: list each one (view, clip,
     frame, pixel count) in your result and stop. The director inspects them.
2. **Bone evidence can't pass empty (Medium).** `tools/humanoid_cutout/gates.py` (~line 149) checks only the rows it is
   given. With `samples=[]`, `ok=false` and an explicit error, `rr10_gates.py` printed `BONE/CUT GATES: PASS (0 errors)`.
   - Fix: require `ok: true`, an empty error list, current binding hashes, and a complete sample inventory: every
     authored clip × frame, in both views, for authored and presented samples.
   - Regressions: an empty sample list, `ok: false`, a reported error, a stale binding hash and one missing clip frame
     each FAIL.
3. **Surviving mutations (Low).**
   - Add explicit torso and head limit regressions: over the limit fails and at the limit passes, for normal clips
     (4°/6°) and for death (25°/20°). Removing either check must then fail a test.
   - In `tests/test_rr10_silhouette_gates.py` (~line 83), keep both owners in the 70% negative fixture so it tests the
     percentage. Lowering `JOINT_BOUNDARY_FRACTION` to 0.7 must then fail a test.
4. **Layout copies (Low).** The game reads `assets/units/hoarfrost_seer_cutout/humanoid_v2/{front,rear}.json`; the
   case layouts serve authoring and proof; the top-level `assets/units/hoarfrost_seer_cutout/{front,rear}.json` are
   copies written by `rr10_density.py` (~line 41).
   - If nothing besides the density tool reads the top-level copies, point the tool at `humanoid_v2/` and delete them.
   - Otherwise keep them and add a normalized-parity regression across all three copies, for both views.
   - Keep `proof/samples.json`; the native gates and fixtures consume it.
5. **Proof (headless).** Focused tests only: the rr10 Python tests, `test_rr07_production`, `test_maquette_rear_turn`
   and the headless rr10/rr07 Godot runtime tests. Report caught vs survived for the mutations above. Don't run the
   full Godot or Python suites; the director runs them at merge.
