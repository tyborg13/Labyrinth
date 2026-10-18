# rr-10 feedback 5 — the rear, plus the last front fills

## Status at cdea088f5 (director windowed proof)
- Idle PASS (252 frames).
- Native gates: 344 → 50 errors. The tuck work closed the wrist, foot and belt gaps.
- What remains is one persistent real opening plus a few small ones, all in
  `experiments/cutouts/hoarfrost_seer/rr10/proof/native_gates.json`.

## 1. Last front fills
- **ward 11–40 (28 frames, one region).** An 8 px, 1 px-wide sliver of background opens between the near sleeve's
  inner edge and the chest, at native (302–304, 262–267), while the near hand is pulled to the chest. It is the
  armpit/shoulder seam.
  - Extend the torso's hidden continuation 4 px outward under both shoulders and armpits, covering the area the
    sleeve covers at rest.
  - Extend each sleeve's inner-edge tuck by 3 px.
- **The remaining flags:** move 7–48 (10), mark 19/20/50/53, hit 4/8/9, death 83/84/87, bolt 28, plus the move 41
  detached pair.
  - Close each one the same way: a hidden continuation on the covered piece at that seam.
  - Report any flag that turns out to be staff-bounded negative space, with a crop, instead of patching it.
- Rerun the headless suites. The director reruns `native` and `sheets`, and the gate must pass with 0 errors.

## 2. The rear
`codex/peer-benchmark` now has the rear inputs. Merge it into your branch before starting; the director has merged
mq-06:
- Rear maquette delivery (mq-06, a true 180° turn with planted feet): the rear files in
  `spec/art_identity/maquettes/hoarfrost_seer/delivery/` and `joints_px.json`. The front delivery is byte-unchanged.
- Rear painting (approved, identity gate PASS, palette-matched to the front):
  `spec/art_identity/jobs/hoarfrost_seer/mq6_rear`.
- Rear rope mask (director data, 242 px: the belt band across the back plus its 1 px outline):
  `spec/peer_benchmark/staged/rr-10/rope_mask_rear.png`. Every masked pixel belongs to `torso`.

Build the rear exactly as the front:
- the same pieces, weights, tucks (including the item 1 fills), runtime, staff depth (near side: in front) and gates;
- rest identity 0 px against the approved rear painting.

Then:
- complete production promotion (board, pre-battle, portraits, both views);
- the density rest records;
- the review MP4 command.

Stop when the headless suites pass. The director runs the windowed proof, including `review`.
