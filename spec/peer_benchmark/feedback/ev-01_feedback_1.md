# ev-01 feedback 1 (director decisions for your TODO_DESIGN items + ownership)

Good work. Resolve these, then rerun the event suite, section_map suite, dragon_boss suite and the full suite.

1. TODO_DESIGN_vision_radius → `data/events.json` now has `"radius": 2` on `lantern_sight` (director edit, already in
   your worktree). Apply it as the Vision `amount` (same semantics as card `vision` actions: amount 2, duration 3).
2. TODO_DESIGN_acquisition_outcome → result rows, one per concrete outcome, past tense, exact templates (inline icons
   stand alone):
   - hp −N: "Lost N @icon(health)." · heal/heal_percent: "Healed N @icon(health)." (actual amount healed)
   - max_hp +N: "+N max @icon(health)." · −N: "−N max @icon(health)."
   - embers +N: "Gained N Embers." · −N: "Paid N Embers."
   - relic: "Gained <Relic name>." · equipment: "Gained <Gear name>." · card: "Gained <Card name>."
   - card_choice: "Next: choose 1 of N spells."
   - item: "Gained <Item name>." (one row per item) · lose_item: "Lost <Item name>."
   - reforge / transform: "<Old name> became <New name>."
   - omen: "<Blessing|Bane>: <Name> (<fights> fights)."
   - defiance: "Gained 1 @icon(defiance) for this run." · scout: "+N Scout." · reveal: "Revealed N rooms."
   - any substitution to Embers: "Gained 40 Embers instead."
3. Empty-pool fallbacks:
   - reforge: if no different piece of that slot at the target rarity, try the old piece's rarity, then any rarity
     (different piece); if none at all, keep the old piece and grant 40 Embers (substitution row).
   - transform_magic: target rarity → same rarity → any rarity (different card); if none, leave that slot unchanged and
     add the row "Nothing changed."
   - card: lower rarity, then any rarity; if none, 40 Embers (substitution row).
4. Ownership exception granted: update `tests/suites/dragon_boss_suite.gd` traversal and `tools/inspection_fixture.gd`
   (and any other test/tool traversal that calls `event embers`/`resolve_map_event` with the old strings) so an event
   room resolves by choosing the FIRST AVAILABLE choice, pressing Continue, and skipping any event card choice. Do not
   weaken any other assertion.
5. Copy fix in preview templates (Change 8): equipment slot noun phrases are
   weapon → "a random <R> weapon", offhand → "a random <R> offhand", armor → "a random <R> armour",
   boots → "random <R> boots", trinket → "a random <R> trinket", none → "a random <R> piece of gear";
   the line is "Gain " + phrase + "." (e.g. "Gain random Common boots."). Reforge keeps
   "Reforge your <slot noun> into a random <next R> one." for weapon/armour.
6. Keep the stopgap panel; the director will run your windowed probe after this round.
