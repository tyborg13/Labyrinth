# Store-copy claim checks — 2026-09-05

These notes ground the public description in current implementation and content. They are not store-page copy. Paths below are repository-relative. The approved visual-polish source worktree is `wishlist-visual-polish-and-steam-trailer`, commit `78f0083383cf21e14513ad728afde0a206ea3bcf`; its capture assertions also verify the featured tactical examples.

## Core promise: positional tactics and deckbuilding

- `scripts/combat_engine.gd` implements grid movement, attack targeting, push/pull displacement, area tile patterns and the player card-play/movement budgets.
- `scripts/game_data.gd:330` (`compile_deck_cards`) composes the live deck from equipped equipment, attuned magic, and equipped items.
- `scripts/run_engine.gd:1312` permits equipment/magic changes in room, campfire, and pre-battle modes. `equip_equipment` and `swap_magic_card` rebuild the deck.
- `data/equipment.json` entries `grave_greatsword` and `duelist_rapier` provide distinct card sets, so the example of changing weapons to change available cards is literal.
- Avoid wording that promises unrestricted deck editing during combat or direct control over every drawn hand.

## Set up the next strike

- `data/cards.json` / `updraft`: raises Air intensity, pushes two tiles, and damages the target.
- `data/cards.json` / `cinder_bloom`: a ranged cross-shaped area attack, with additional damage and Burn when Fire intensity reaches its threshold.
- The v3 source capture in `tools/steam_trailer_capture.gd` asserts Updraft's two-tile displacement, movement into range, and the subsequent Cinder Bloom hit against the arranged group.
- Forced movement can trigger traps. `tests/suites/chain_attack_suite.gd` includes a legal Razor Gale / Light-relic / fire-trap fixture, with trap splash and terrain destruction resolved by the normal engine.
- “Mix card plays with movement” describes actual gameplay and is shown in both v3 tactical sequences. It does not claim every card has a free move.

## Your gear builds your deck

- Equipment adds authored cards; magic and items contribute their equipped/attuned cards through `compile_deck_cards`.
- `scripts/run_engine.gd:1273` (`claim_card_reward`), `:1520` (`buy_merchant_item`), and `:1678` (`claim_relic`) implement the run's reward, shop, and relic acquisition paths. Use function names as stable anchors if line numbers shift.
- Acquired reward/shop spells enter reserve magic; players attune them between fights. They do not all immediately enlarge the active deck. The public copy should say “choose which spells to carry” or “reshape your deck between fights.”
- The player-facing merchant is the Scavenger, even where legacy blacksmith/arcanist identifiers remain for save compatibility.
- Elemental intensity enables specific bonuses and costs; examples are the `intensity_bonus` blocks on Cinder Bloom and Chain Bolt. “Raise elemental intensity to unlock stronger attacks and additional effects” is supported. Avoid saying all cards become stronger with any element, or that intensity is only beneficial: trap strength also scales in `scripts/elemental_intensity_rules.gd`.
- `data/relics.json` includes concrete build interactions. Brightglass Lens (`ember_lens`) adds Chain to ranged attacks against enemies in Light; Coalheart Crucible spends Fire intensity for extra plays and Burn.

## Bring light into the Umbra

- `scripts/combat_engine.gd:187` (`umbra_stage_for_section`, `umbra_stage_for_section_depth`) increases Umbra pressure with deeper sections. This is progression through the run, not a real-time countdown.
- `:279` (`umbra_visible_tiles`) combines the player's current sight radius with placed Light sources.
- `:314` (`is_enemy_visible_to_player`) gates normal enemy visibility, with explicit boss and Truesight exceptions.
- `data/cards.json` / `root_snare` damages and immobilizes a target, then creates impact Light. `chain_bolt` follows connected targets under the normal chain rules.
- The v3 capture asserts Root Snare reveals both neighbors and the follow-up chain reaches the legal visible group. “Light reveals threats” and “opens new targets” are supported.
- Do not promise all future enemy actions are fully visible: Umbra intentionally hides information. Do not present Light as a sixth elemental intensity.

## Choose how far to go

- `scripts/run_engine.gd` provides the run's spatial room map and available route choices. `scripts/room_generator.gd` creates seeded rooms and encounters.
- `scripts/combat_engine.gd:187` documents the elemental-dragon sections and separate Shadow Dragon section; generic “dragons ahead” is supported without a content count.
- `spec/meta_leveling.md` describes campfire choices and their opportunity costs: Linger heals and continues; Embrace carries embers out and ends the run; Draw Strength buys a permanent level/skill point and leaves without the Linger heal.
- `scripts/run_scene.gd` functions `_on_campfire_embrace_pressed` and `_on_campfire_linger_pressed` implement carry-out and recovery. Progression commits before deleting the resumable run.
- “Spend embers to unlock permanent skills” is concise shorthand for purchasing a level/skill point and then learning a skill. Avoid permanent health/damage-growth promises: the skill-tree design adds options and interactions rather than raw stat scaling.
- The header “Choose How Far to Go” reflects pressing forward or ending at a campfire. “Know When to Turn Back” was rejected because it suggests a return journey that the featured choice does not require.

## Copy/source cautions

`spec/prototype.md` still includes stale early-prototype pillars, content targets, and exclusions (for example one-card wording and no-audio scope), so it is not authoritative for current store claims. No counts, run-duration guarantees, controller/Deck certification, multiplayer claims, or new gameplay features were added to the proposed copy.

Peer-store structure references (official Steam pages, read 2026-09-05):

- Across the Obelisk: https://store.steampowered.com/app/1385380/Across_the_Obelisk/ — feature groups separated by imagery.
- HELLCARD: https://store.steampowered.com/app/1201540/HELLCARD/ — positioning is explicitly identified as a differentiating mechanic.

Our proposed structure pairs each claim with a real tactical sequence or build-choice scene. No peer wording or artwork is reused.

## September 6 revision: feature-led copy

The revised public copy describes repeatable systems instead of naming enemies or narrating the captured encounters. The tactical paragraph covers grid positioning, forced movement, terrain/traps, and shared elemental intensity. The equipment paragraph describes deck composition from equipment and attuned magic, with relics changing card interactions rather than directly adding cards. Visibility and campfire paragraphs retain the implementation-grounded claims above. No content counts or guaranteed run outcomes are promised.

References for tone and structure, read September 6, 2026:

- Slay the Spire: https://store.steampowered.com/app/646570/Slay_the_Spire/ — the user supplied its deckbuilding, changing routes, and relic feature paragraphs as examples.
- Alina of the Arena: https://store.steampowered.com/app/1668690/Alina_of_the_Arena/ — describes each core system and the choices it enables.

These references guide organization and level of detail only. The wording is original and the claims concern Escape the Umbra's implemented mechanics.
