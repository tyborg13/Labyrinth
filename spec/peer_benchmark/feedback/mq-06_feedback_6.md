# mq-06 feedback 6 — review fix (review 57d2abd81: CHANGES REQUESTED, one Medium)

The review is in `spec/peer_benchmark/feedback/mq-06_review_57d2abd81.md`. Everything else passed:
- the front frozen;
- the exact 180° turn;
- the margins;
- fixed-IoU scoped to the Seer;
- other figures unchanged;
- curation.

Your branch has one director commit on top (51a48efa4: the rear-turn regression skips crawler deliveries without foot
solos). Keep it.

**Medium — floor validation can omit the feet.** `view_delivery.py:101` validates only the contact rows supplied, and
`floor_contact.py:158` accepts an empty set. Deleting `ankle_far`, or keeping only `hem_min`/`hem_max`, survives sealing
and strict validation.
- Require the complete expected contact inventory per figure and view: every ankle (near and far), the hem boundary
  rows where the figure has a floor-length robe, and every prop foot (the staff butt).
- Derive that inventory from the spec (joints and pieces), not from the report itself.
- Reject empty sets and missing rows.
- Add omission tests that reseal certificates and must fail: missing far ankle, all foot/prop rows omitted, empty
  helper input.

Rerun the focused tests and the full Python suite.
