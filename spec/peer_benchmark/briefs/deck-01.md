# deck-01 — Drop the magic-slot limit: spells go straight into the deck (owner decision 2026-10-16)

## Header
- Owner: "the strict limit is trivializing the deckbuilding aspect and having to equip spells after each fight is a huge
  point of friction" → decision: "drop the limit and have spells just go right into the deck."
- Triage §9 (spec/peer_benchmark/triage_playtest9.md): `MAGIC_LOADOUT_LIMIT = 6` (`game_data.gd:69`); rewards go to
  `magic_inventory` ("Added %s to reserve magic."); Character → Magic shows ATTUNED 6/6 + LEARNED (reserve) with swaps;
  repair/migration/fill paths in `run_engine.gd:2255–2294`, swap `:1557`; UI in `run_scene.gd:30287–31543`, `:3487`,
  `pre_battle_view.gd:435`, `:519`. Active deck = gear cards + attuned magic + equipped items.
- Base `codex/peer-benchmark`. Owned: game_data.gd, run_engine.gd (magic/reward/campfire/scavenger paths), the
  Character → Magic panel in run_scene.gd, pre_battle_view.gd count text (coordinate: pb-01 owns the rest of that file —
  touch only the magic count lines), save migration, analytics (spec/analytics.md + instrumentation), tests.
  Follow AGENTS.md analytics and balance rules.

## Change (director's design)
1. **No limit.** Every magic card the player owns is in the deck. Starting deck unchanged (16 cards: gear cards +
   Pale Spark ×2, Dull Bolt ×2, Waning Pulse ×2). Remove attune/reserve/swap concepts and the fill-to-six repair.
2. **Rewards:** taking a magic reward adds it to the deck: notice "Added <Card> to your deck." Skipping (the existing
   3 HP recovery option) stays. Scavenger purchases and events that grant magic also go straight to the deck.
3. **Save migration:** existing saves move all reserve/learned magic into the deck once; log it in the save version.
4. **Character → Magic panel:** becomes "MAGIC IN DECK" — one list of owned magic with copy counts (e.g. "Pale Spark ×2"),
   sorted by element then name, card hover previews as today, no swap controls, header shows the magic count
   ("12 spells"). Gear and item cards stay where they are shown today. Pre-battle shows the total deck size.
5. **Card removal (the new cost of a bigger deck):**
   - Scavenger service **"Purge"**: remove one magic card from the deck for 50 Embers, +25 for each later purge this
     run. Gear and item cards cannot be purged.
   - Campfire gains **"Purge"** as an alternative to its existing rest/heal choice (choose one per Campfire). If the
     Campfire already offers several choices, Purge is one more.
   - Purge UI: the same magic list as the Character panel with a confirm step ("Purge <Card>?").
6. **Balance & analytics:** score whether `spec/card_balance_heuristic.md` assumes a 6-magic loadout; if it does,
   report the assumption and the proposed update (do not change numbers without listing them). Add additive analytics
   fields (reward destination "deck", purge events with source scavenger/campfire and price).

## Proof
- Tests: reward → deck; migration of a save with reserve magic; purge at Scavenger (price progression) and Campfire;
  gear cards not purgeable; compiled combat deck contains all owned magic.
- Real-renderer captures at 1920x1080 (director runs): Character → Magic panel with ~14 spells, Scavenger Purge,
  Campfire choice.
- Full Godot suite PASS.
