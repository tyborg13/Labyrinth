# rr-05 feedback 3 — Bloomer passes natively; Wisp still fails (director run 2)

I ran `proof_for_design_owner.sh --from-native` under the director lock. Log: `output/rr-05/director_windowed_run2.log`.
- Shale Bloomer: native capture, pixel/feature verification and the review MP4 all pass. MP4 at
  `output/rr-05/shale_bloomer_review.mp4`, 1212 frames.
- Lightning Wisp: native capture passes, but verification fails with 14 errors
  (`output/rr-05/wisp-native/pixel_gates.json`). The script stopped there.
  - `front/feature_eye` frames 0–5: "native part does not match its source transform".
  - `rear/arc_left` 8 errors, two of them "unexplained shimmer (13px, ~0.018)", in frames 12 and 18.

Notes for diagnosis:
- The Wisp's veins (`arc_left`, `arc_right`, `crown`) are painted on the cloud and must ride `core`. rr-04's rule is
  "rig them as part of core, no independent motion".
- The eye is a feature owned by `core`.

So both failing nodes should share core's exact transform. Check whether the eye feature node or `arc_left` gets its
own pivot, offset or snapping path, and whether that path differs from core's in the native runtime. If it does,
that is a runtime bug: fix the runtime. If the native output is right and the model is wrong again, fix the model,
with the same evidence standard as feedback 2.

Never loosen tolerances. Keep `--from-native` resumable, and add a `--creature lightning_wisp` filter so I can re-run
only the Wisp. Delete the stale `output/rr-05/wisp-native` once the diagnosis is recorded. Leave the Bloomer outputs
and MP4 in place.
