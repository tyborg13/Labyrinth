I found **three Medium issues and one Low test gap**.

1. **Medium — Straight legs silently receive an arbitrary knee direction.** The [fallback at humanoid_motion.gd:115](/private/tmp/labyrinth_codex/review/rr-14-fcae304f3/scripts/maquette_cutout_runtime/humanoid_motion.gd:115) is reachable: a straight 5/5 visible-leg fixture passes schema, structure and source checks. With a 2 px pelvis dip, front and rear knees both move 3 px screen-left. That cannot express opposite per-view choices. **Fix:** require a case-owned, per-view bend direction for straight chains and reject missing direction. Preserve rest-derived direction for bent chains.

2. **Medium — Attachment propagation drops authored motion and leaves grandchildren behind.** The [attachment loop at humanoid_motion.gd:128](/private/tmp/labyrinth_codex/review/rr-14-fcae304f3/scripts/maquette_cutout_runtime/humanoid_motion.gd:128) rebuilds immediate children from rest offsets with zero local rotation. In the headless reproduction, a keyed child loses its entire 1 px lift; its grandchild misses the expected parent-relative position by **0.565685 px**. **Fix:** propagate affected descendants in hierarchy order using their authored local transforms, accounting for the held-item pass’s final transform. Add keyed-child and grandchild regressions.

3. **Medium — Anatomy validation is not enforced.** [anatomy.py:7](/private/tmp/labyrinth_codex/review/rr-14-fcae304f3/tools/humanoid_cutout/anatomy.py:7) checks only `schema_version`; embedded anatomy bypasses even that. Removing required `tucks` still loads and passes structure checks. Renaming `grip` to `griip` makes an invalid Seer hand/item depth pass because [gates.py:78](/private/tmp/labyrinth_codex/review/rr-14-fcae304f3/tools/humanoid_cutout/gates.py:78) treats absence as null. **Fix:** validate loaded and embedded anatomy, reject misspelled keys, and require explicit null for absent grip roles. Both supplied cases satisfy the schema’s declared constraints.

4. **Low — Independent knee-direction and foot-target guards lack negative coverage.** [test_rr14_foundations.py:73](/private/tmp/labyrinth_codex/review/rr-14-fcae304f3/tests/test_rr14_foundations.py:73) corrupts foot position and asserts only the length error. Removing the bone gate’s bend-side check or disabling its foot-target check survives **13 relevant rr10/rr14 tests**. **Fix:** add a reflected-knee sample preserving segment lengths and a wrong-target sample preserving lengths and bend side; assert each specific error.

Mutation results: **16 distinct mutations: 12 caught, 4 survived**. All ten supplied mutations were caught.

| Mutation group | Result |
|---|---|
| Each `domains()` guard: cover, bounds, connectivity | Caught |
| Idle anchor, foot dispatch, reach clamp, rest bend, shin rotation, hierarchy, mesh inventory | Caught |
| Independent length and complete target checks | Caught |
| Reverse straight-chain default; remove attachment updates | Survived |
| Remove independent bend check; disable foot-target check | Survived |

[Mutation results and logs](/private/tmp/labyrinth_codex/rr-14/review/mutations/review-summary.json)

All **121 requested Python tests passed**. Headless rr10/rr14/rr07 passed **10 / 104 / 73,057 checks**. The fixture exercises the requested tube, claw, visible legs and loincloth. All **777 identity files** match the base; fresh **1,258-pose** Seer samples are byte-identical outside binding hashes. No Seer change or held-item double application was observed.

No new Windows typed-array violations, remaining Seer identity/root/scale literals in the specified generic modules, unrelated tunables or stray fixture assets were found. Every mutation was restored; the checkout is clean. No windowed runs, commits, pushes or other-checkout changes occurred.

CHANGES REQUESTED