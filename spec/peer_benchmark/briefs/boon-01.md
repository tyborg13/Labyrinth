# boon-01 — Opening boons from the emaciated man + heirloom (owner-approved design 2026-10-17)

## Header
- Owner asked for more starting build diversity; approved design: the emaciated man offers 3 boons at the start of a
  run (one from each column), the player takes one; the heirloom is one possible option, never automatic.
- Triage §3 (spec/peer_benchmark/triage_playtest9.md): every run starts with the same 16 cards; starter equipment
  Training Sword / Splintered Shield / Patched Cloak / Skirmisher Boots / Cracked Lantern; starter magic Pale Spark ×2,
  Dull Bolt ×2, Waning Pulse ×2 (deck-01: magic goes straight into the deck); run creation in
  `run_engine.gd:create_new_run`; the emaciated man lives in the start room (`start_room_map_flow.gd`,
  `dialogue_engine.gd:_emaciated_man_dialogue`); his services unlock after his first-run awakening
  (`progression_store.gd:emaciated_services_unlocked`).
- Base `codex/peer-benchmark`. Owned: run_engine.gd (run creation, boons, heirloom), dialogue_engine.gd /
  start_room_map_flow.gd (his offer), progression_store.gd (heirloom persistence), run-end flow (heirloom prompt), a new
  boon offer UI (follow spec/visual_design_system.md, $create-labyrinth-ui), data file for boons, analytics, tests.
  Follow AGENTS.md: balance heuristic for any card/relic grants, analytics for run-start/run-end flow.

## Design (director-authored; exact)
1. **When:** from the first run AFTER his awakening (never during the guided tutorial / first run), each new run, the
   first time the player talks to the emaciated man in the start room; until a boon is taken or declined he keeps
   offering it on talk. One choice per run. A "Decline" option exists ("Take nothing").
2. **Offer:** three cards side by side, one per column, each rolled once at run creation (seeded by the run seed, saved
   in the run state so save/resume shows the same offer). Rolled contents are shown up front (the actual spells,
   equipment piece, relic or element), so the choice is informed.
   - Column 1 — build seed (uniform among eligible): **Elemental Gift** "Choose 1 of 3 rare <Element> spells." (random
     element; the 3 spells are rolled now and chosen on accept) · **Armory** "<Item> replaces your <starter piece>."
     (a random uncommon equipment piece for a random slot; the starter piece and its cards leave) · **Heirloom** "Start
     with your <Item>, left here last run." — when an heirloom exists it ALWAYS fills column 1.
   - Column 2 — shaping: **Purge** "Remove 2 starter spells." (choose on accept from the 6 starter spells) · **Focus**
     "Swap your 6 starter spells for 4 common <Element> spells." (element and the 4 spells rolled now) · **Vitality**
     "+6 max HP." · **Trinket** "<Relic>." (a random common relic).
   - Column 3 — bargain: **Blood Price** "Lose 5 max HP. Choose 1 of 5 rare spells." (5 spells rolled now, any element)
     · **Pawned Light** "<Relic>. Start at half HP." (a random rare relic; current HP = ceil(max/2)) · **Debt** "+120
     Embers. Your first Scavenger visit costs 50% more." (prices ×1.5, rounded up, at the first Scavenger room only).
3. **Dialogue (exact):** offer opener: "You'll want something in your hands down there. Choose." · on taking a boon:
   "Good. Go on." · on declining: "Then go with nothing." · heirloom prompt at run end (death or victory, before the
   run summary): "What will you leave with me? I'll keep it until you come back down." with one option per equipped
   piece plus "Leave nothing"; confirmation "I'll keep it." Speaker name and portrait as his existing dialogue.
4. **Heirloom rules:** one heirloom at a time (a new one replaces the old; "Leave nothing" keeps the existing one);
   stored in progression; returns at its base level (no upgrades/grafts); if its slot's starter is replaced at run
   start, the starter's cards leave and the heirloom's join. Removed from progression when taken into a run (it can be
   left again at that run's end).
5. **Rules interplay:** spells granted go straight into the deck (deck-01). Relic grants use the normal relic pickup.
   Embers go to the run wallet. All offer texts use the gold keyword tokens where they name glossary terms.
6. **UI:** a centred modal over the start room with the three boon cards (column label above each: "Build seed",
   "Shaping", "Bargain"), each card showing the rolled content (spell/item/relic icons with hover previews as
   elsewhere) and its one-line text; a "Take nothing" text button below. Keyboard/controller navigable. Use existing
   card/relic/equipment presentation components; no new icons (if a boon needs an icon, use the rolled content's own).
7. **Analytics (additive):** run_start_boon_offered {columns, rolled contents}, run_start_boon_chosen {boon, content |
   declined}, heirloom_left {item | none}.
8. **Balance:** run the heuristic for any granted spells (no new cards); report the expected power of each boon option
   (rough, using the heuristic's per-card scores) in the result so the director can compare columns.

## Proof
- Tests: offer rolled deterministically and saved/resumed; each boon's effect; heirloom persistence and replacement;
  Debt pricing only at the first Scavenger; tutorial run never offers; analytics events.
- Real-renderer captures at 1920x1080 (director runs): the offer modal with an heirloom present and without; the run-end
  heirloom prompt. Plus a short demo clip via tools/demo_clips if simple (offer → take Elemental Gift → choose spell).
- Full Godot suite + Python discovery PASS.
