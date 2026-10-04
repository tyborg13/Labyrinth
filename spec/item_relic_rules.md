# Item relics (relic pool overhaul U8)

`scripts/item_relic_rules.gd` owns the data-driven item transformations. It is
called from `GameData.card_def_for_progression`, so the same values feed card
faces, hover forecasts and combat resolution. Existing item art and the Time,
card-play and Exhaust presentations are reused.

- `item_no_card_play` makes an item spend zero card plays. Its `time` surcharge
  is paid after printed-cost discounts and the Time reserve, like Empower's
  extra Time. The shared payment, action annotations, hand playability and
  initiative projections all use that payment. A free item cannot spend a
  banked play or trigger Borrowed Time; Frozen restrictions still apply.
- `item_value_multiplier` scales damage, Block, healing and Stoneskin by
  `numerator / denominator`, rounding upward. It includes nested rewards and
  stored damage such as Powder Keg's `burst_damage` and Whetstone's next-attack
  bonus. Health of a placed object, range, Time, draw/play rewards, statuses,
  and the shared damage of Fire tiles are unchanged. Stored values are scaled
  when placed, persist with the object through saves, and are never scaled a
  second time when the object triggers.
- `item_once_per_combat` changes a non-healing item's Consume into Exhaust.
  The derived face uses the existing Exhaust icon and a once-per-combat
  tooltip. Each physical copy enters `deck.burned`, never discard, and stays in
  `equipped_items`. Run reconciliation therefore keeps it in the next combat's
  compiled deck. Duplicate copies each have one use. Healing actions (including
  conditional rewards and keyword healing) retain ordinary Consume and its
  existing skill interaction. Non-item Exhaust preservation, rewards and
  return effects do not apply to item Exhaust; Makeshift cannot preserve a
  Ledger item because it no longer has Consume.

No new saved state is needed: the existing combat piles, Time/play counters,
terrain values and equipped-item loadout persist the complete behavior.
No analytics event types or payload fields are added. The existing card-play
event reports the actual zero play spend and paid Time, and existing pile
tracking reflects item Exhaust. The authored `consume_on_play` flag remains a
printed-card classification. Powder
Keg events retain their ordinary schema and record the boosted stored damage.

Proof: `tests/suites/relic_u8_suite.gd` (`tests/relic_u8_test.gd`) and the
1920×1080, 100% UI-scale `tests/relic_u8_probe.gd`.
