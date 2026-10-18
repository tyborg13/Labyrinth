# mq-06 feedback 7 — re-review b919e7ac2: the floor fix is accepted; fix the crawler exemption

The re-review is in `spec/peer_benchmark/feedback/mq-06_review_b919e7ac2.md`.
- The floor-inventory Medium is fixed: all of the reviewer's mutations were caught.
- The new Medium is against the director's own test patch (51a48efa4). Skipping any delivery that lacks
  `front_solo_foot_near.png` can hide a biped; the reviewer used a Mirror fixture.

The director has merged `codex/peer-benchmark` into your branch, with builder conflicts resolved as in rr-10. The actual
Burrow Grub, Ember Tick and Glacial Mirror deliveries are now present. Don't merge again.

Fix:
1. Base the exemption on spec identity, not on a missing file.
   - A figure is a crawler, exempt from the foot check, only when its `measurements.json` labels contain neither
     `foot_near` nor `foot_far`.
   - Any figure whose labels include feet must have both foot solos in both views, or the test fails.
2. Add `glacial_mirror` to the required roster (it is a labelled biped golem).
3. Add the reviewer's omission regression: a biped fixture missing a foot solo must fail, with or without an incorrect
   rear.
4. The real Grub and Tick must be reported as exempt crawlers by name.

Rerun the focused tests and the full Python suite.
