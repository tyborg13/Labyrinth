# rr-30 feedback 3 (director visual review of 407ca1d9a)

Every windowed stage passed: density, rest, native gates in both views, sheets, walk (fit ≤ 0.098 px), idle, production
(1515 frames, 0 errors) and review. The loincloth, the rear flap and the face are right, and nothing stretches. One
visual defect remains, and it is the tearing the owner asked us to clean up: "noticeably wrong tearing ... around his
face and arms. We need to clean all that up."

Evidence: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/rr-30/rr30_round2_tearing_evidence.png`
(rest vs `front_lob_3x.png` frames lob0016 and lob0032, cyan circles). The rest frame is clean; in motion:

1. **Dark slashes inside the skin at joints.** A 1–2 px near-black diagonal line appears on the near upper arm below the
   shoulder, on the far upper arm above the bracer and at the far elbow. They read as cuts in the arm.
2. **Ragged warm fragments along the outline.** Orange and skin-coloured bits stick out past the silhouette: at the near
   shoulder, beside the near wrist, around both knees and the inner thighs, and at the hem. They are attached to the
   body (a detached-island count finds 0 in front lob), so they are pieces poking out, most likely hidden cover pieces
   or cut edges that the main pieces no longer cover once the limb rotates.

Required:
- **Root cause first.** Attribute every pixel in the flagged frames to its piece (you already have the CPU renderer that
  produces the coverage-gate frames). State which pieces produce each defect and why, before changing anything.
- **Fix it at the source** (cut geometry, cover-piece shape and placement, pivot or draw order), not by masking captures.
  Joint covers must use the adjacent painted skin or cloth, so a covered joint never shows a dark line. Covers must never
  extend the silhouette outside their joint.
- **A gate that fails today and passes after**, over every frame of every clip in both views, in the CPU coverage
  renderer:
  - no visible pixel from a hidden or cover piece more than 3 px from the joint it covers;
  - no near-black seam pixels (luminance below the darkest painted skin value of that body part) inside the skin region
    of a limb, except pixels that are dark in the painting itself at rest.
  Register it in the rr-30 tests, and mutation-check it (disable the fix: the gate must fail on lob0016 and lob0032).
- Keep every other result: 0% stretch, the identity certification, the rear chroma, the flap sway, the walk fit and the
  rest records. Don't change the painting.
- **Native acceptance:** the director reruns the windowed stages after this round. Don't attempt them. Keep the
  bindings refreshable.
- Focused tests only. This is the last fix round for this unit in this session.
