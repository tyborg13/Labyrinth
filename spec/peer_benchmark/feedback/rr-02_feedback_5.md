# rr-02 — round 5 (director review of the v04 reel)

Round 4 helped: chain_reel reads well in both views, most of the red is gone. Remaining defects, each with a gate that
checks **rendered motion frames**, not just the rest pose (rest identity stays exact). Evidence (scratchpad):
`rr02v4_front.png`, `rr02v4_rear.png`, `rr02v4_walkzoom.png`, `rr02v4_rearwalk.png` from /private/tmp/rr-02-mq3-render-v04.

1. **Tabard paint still rides on the far shin** (front walk frames 0, 7, 47: a red strip from the tabard hem down the far
   shin to the boot). Extend the round-4 reassignment to every part whose maquette label lies under the tabard's dilated
   (6 px) silhouette in the front view: pelvis, both thighs, **both shins**, both coat panels. Gate: in every sampled
   motion frame (all 7 clips, both views), zero pixels within ΔE76 15 of the tabard median are owned by a non-tabard part.
2. **Stray specks** remain (front walk: small dark marks right of the near foot; rear walk: brown dots left of the far
   leg). Find each one's owner by rendering an ownership map at those poses and fix the root cause (island size,
   diagonal connectivity, or pixels that are connected at rest only through another part). Gate: in every sampled motion
   frame, no opaque 8-connected component under 12 px is disconnected from the main silhouette.
3. **Rear leg fill too dark**: under the rear cloak the swinging leg shows a near-black column (`rr02v4_rearwalk.png`).
   Hidden leg fills must match the visible same-part value distribution, not its shadow cluster: fill median L* within
   8 of the visible pixels' median L*, with the visible part's mid-tones present. Report per part.
4. **Rear strike fist**: the far fist still pops out above the left shoulder as a black blob (rear strike frames 2–3).
   From behind, a forward punch is hidden by the body: constrain the rear `strike` and `manacle_pin` fist path so no
   fist-arm pixel renders outside the union silhouette of torso, head and coat; sell the punch with the shoulder and torso
   lean (keep the pelvis forward drive). Gate in the motion samples. The front view is unchanged.

Proof: focused tests, gate tests, full suites, validation ok, rest identity 0 pixels, zero magenta, and the new motion
gates' counts. List the windowed commands with capture path `/private/tmp/rr-02-mq3-render-v05`.
