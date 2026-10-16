Audited integration HEAD `602a51fc7`. Tracked files remain unchanged. Runtime checks used Godot **4.6.1 headlessly**, with throwaway scripts outside the checkout. Visual behavior below is traced from code; no windowed runs were made.

## 1. Map branching

**Status: partially fixed.** The generator supports branching, merging, distinct room choices, and advance planning. Topological variety remains limited: **26 of the 30 sampled sections used the same fallback topology for their section length**.

The current generator is revision 4 in [section_map_graph.gd:62](scripts/section_map_graph.gd:62). The older revision-3 generator remains in the file for compatibility.

| Section | Rooms traversed, including boss, excluding entry | Interior progression rows | Total progression positions, including entry and boss | Target fights, including boss |
|---|---:|---:|---:|---:|
| I | 10 | 9 | 11 | 6 |
| II | 11 | 10 | 12 | 6 |
| III–V | 11 | 10 | 12 | 7 |
| VI | 12 | 11 | 13 | 7 |

There are **four lanes**, with **2–4 nodes per interior row**, exactly **three opening combat nodes**, one entry, and one boss. The UI lays progression **left to right**, with lanes vertically arranged (`section_map_panel.gd:407`).

Generation rules (`section_map_graph.gd:142`, `:174`, `:204`, `:279`):

- Combines **five random walks**. Each edge advances one row and changes lane by at most one.
- Shared nodes and edges merge; routes can split again afterward. Consequently, five generating walks can produce substantially more than five playable routes.
- **Crossing edges are rejected**. Shared endpoints are allowed.
- Physical door compatibility rejects some consecutive forks.
- The midpoint row is Treasure; the penultimate row is Campfire.
- Fork destinations must have different types, except three-way Combat forks.
- Every route has at least one service encounter, at most one Guardian, and fight counts within **±1** of the table’s target.
- Each section contains at least two Guardian nodes, at least one Scavenger, and a route bypassing Guardians.
- Guardians appear from row 3 through `room_count−3`; Scavengers start at row 3; Graftwright requires at least three preceding fights.

Initial room-type weights are **Combat 46, Mystery 22, Guardian 10, Scavenger 10, Graftwright 6, Event 6**. These are **candidate weights, not final frequencies**: repair constraints and fixed rows alter the result; higher Umbra Depth can alter Guardian weighting. Mystery contents initially roll **Event 70%, Combat 20%, Treasure 5%, Scavenger 5%** (`section_map_graph.gd:42`).

Across the five generated runs, the **984 interior nodes** were:

| Type | Count | Frequency |
|---|---:|---:|
| Combat | 453 | 46.0% |
| Mystery | 159 | 16.2% |
| Treasure | 89 | 9.0% |
| Campfire | 88 | 8.9% |
| Guardian | 64 | 6.5% |
| Scavenger | 56 | 5.7% |
| Event | 51 | 5.2% |
| Graftwright | 24 | 2.4% |

**Five headless samples.** Each cell is **total nodes / distinct entry-to-boss routes**. These count node sequences, including recombinations at merges.

| Seed | I | II | III | IV | V | VI |
|---|---|---|---|---|---|---|
| 1 | 29 / 10 | 35 / 10 | 35 / 10 | 35 / 10 | 35 / 10 | 39 / 18 |
| 2 | 33 / 18 | 35 / 10 | 35 / 10 | 35 / 10 | 35 / 10 | 39 / 18 |
| 3 | 33 / 18 | 35 / 10 | 35 / 10 | 35 / 10 | 32 / 46 | 39 / 18 |
| 4 | 33 / 18 | 35 / 10 | 29 / 20 | 35 / 10 | 35 / 10 | 39 / 18 |
| 5 | 30 / 16 | 35 / 10 | 35 / 10 | 35 / 10 | 35 / 10 | 39 / 18 |

The sample median is **10 routes per section**; range **10–46**. The common fallback has two straight outer routes and repeated split/merge diamonds in the middle.

For an exact compact representation of Section I topology, each string below gives lanes at rows 1–9; connect consecutive digits, merge identical positions, connect entry to all starts and all ends to boss:

```text
Seed 1:   333223233 | 222123221 | 000000000 | 333333210
Seed 2:   000000000 | 333333333 | 111111111 | 121212121
Seed 3:   000000000 | 333333333 | 111111111 | 121212121
Seed 4:   000000000 | 333333333 | 111111111 | 121212121
Seed 5:   000001212 | 333332322 | 223333333 | 210111100 | 333333333
```

Full nodes, types, edges, and generating walks for all 30 sections are in [maps.json](/private/tmp/labyrinth_codex/triage/maps.json).

**What is visible ahead:** Sections I–V reveal their entire current section; Mystery identity remains hidden until scouting/entry. Section VI reveals types two hops ahead, outlines three hops ahead, and reveals Guardians, boss, midpoint, and final Campfire landmarks. Each section supplies **two scouts**. Unreached section tabs are disabled; reached sections remain viewable as history (`section_map_graph.gd:54`, `:594`, `:631`; `section_map_panel.gd:270`).

**Smallest fix surface:** `section_map_graph.gd`—walk acceptance, fallback selection, and type constraints. Touch `section_map_panel.gd`/`section_map_canvas.gd` only if changing presentation or visibility.

## 2. AoE / attack previews

**Status: partially fixed. Lethal enemies are retained; destroyed terrain and some other objects still disappear.** The existing lethal-preview suite passed headlessly.

The shared display adapter restores enemies’ committed HP/Block/Stoneskin, including enemies missing from the projected snapshot: [run_scene.gd:18581](scripts/run_scene.gd:18581). Damage previews mark them lethal; the board draws an empty HP bar and pulsing death mark (`combat_board_view.gd:9120`, `:9208`).

The remaining paths are:

| Preview path | What disappears / remains |
|---|---|
| **Selected targetless-card confirmation** | Automatic effects have already run on `_preview_combat_state`. Destroyed terrain remains at projected HP 0 and is skipped by the board. Enemies alone receive restoration. |
| **Any intermediate multi-action preview** | Uses the same projected-state display adapter, so earlier simulated destruction can hide terrain, traps, or illusions while a later choice remains pending. |
| **Triggered/destroyed traps** | Simulation removes the trap from its array. No destroyed-trap silhouette is restored. Under limited Umbra, committed traps are restored by the information-safety adapter; in unrestricted sight they can disappear. |
| **Lethally damaged/consumed illusions** | Projected HP 0 illusions are skipped. They do not receive the enemy restoration pass, so no retained body carries their lethal mark. |
| **Lethal forced-movement destination ghosts** | A destination ghost is omitted when projected HP is 0. The original enemy still carries its lethal marker; displacement path and collision markers can remain. |

References: `run_scene.gd:18517`, `:18641`, `:19515`, `:21519`, `:34444`; `combat_board_view.gd:7372`, `:8281`; `combat_engine.gd:4894`, `:7336`.

**Directly reproduced:** selecting **Whirlwind Slash**, **Cinderweave Guard**, or **Immolation** produced a confirmation preview with a **2-HP crate at HP 0** and a triggered trap removed. The crate’s lethal damage record existed, but its sprite was skipped. There is no terrain death-mark equivalent.

Cards whose automatic damage can enter this confirmation path include:

- **Waning Pulse, Whirlwind Slash, Grave Mortar, Spike Mantle, Sweeping Haft, Phoenix Cleave, Cinderweave Guard, Censer Swing, Frost Nova, Thunderclap, Tremor, Immolation**.
- **White Silence, Searing Light, Stoke** automatically damage selected enemy sets; secondary destruction can follow.
- **Unsealed Gale, Bottled Gale, Gale Ward** automatically force movement, which can cause collisions, trap triggers, and secondary destruction.

Data references: `data/cards.json:141`, `:206`, `:1664`, `:2204`, `:2243`, `:2703`, `:3006`, `:3066`, `:3431`, `:4676`, `:4917`, `:5659`, `:7008`, `:7189`, `:7634`, `:7906`, `:8321`, `:8581`.

**Ordinary aimed hover** generally leaves the committed target visible and supplies damage overlays; it does not substitute the whole resolved hover snapshot onto the board. This also applies to aimed terrain/illusion destruction such as **Rockburst**, **Worldbreak**, and **Shattered Reflection**. Their resolvers destroy the target in simulation, but that alone is not a disappearance during hover.

**Smallest fix surface:** `run_scene.gd` for retaining terrain/trap/illusion display baselines and reporting removals; `combat_board_view.gd` for destruction markers. Card data and combat damage rules need not change.

## 3. Starting build diversity

**Status: the concern still holds for starting cards and equipment.** Every ordinary new run receives the same **16-card deck**, before tutorial-specific combat setup.

Sources: [game_data.gd:68](scripts/game_data.gd:68), `game_data.gd:224`, `:380`; `data/equipment.json:2`, `:51`, `:96`, `:141`, `:186`.

| Starting equipment | Slot | Cards contributed |
|---|---|---|
| Training Sword | Weapon | Quick Stab, Whirlwind Slash, Bloody Lunge |
| Splintered Shield | Offhand | Brace, Guarded Step |
| Patched Cloak | Armor | Patch Up, Shadow Step |
| Skirmisher Boots | Boots | Sidestep Slash, Hamstring Shot |
| Cracked Lantern | Trinket | Lantern Shot |

The remaining six cards are **Pale Spark ×2, Dull Bolt ×2, Waning Pulse ×2**. All six magic slots start occupied. Reserve magic, spare equipment, items, and ordinary relics start empty. Base maximum/current HP is **24/24**, before Umbra Depth modifiers (`run_engine.gd:118`).

There is **no starting class, deck, equipment, elemental specialization, or random-boon draft**. New Descent chooses an unlocked **Umbra Depth, 0–20** (`main_menu.gd:1040`; `depth_rules.gd:7`). Persistent skill allocation can change passives.

One exception is the first guided combat: it installs an authored hand/draw pile, including `backhand_nick`, for the tutorial; it does not redefine the ordinary run loadout (`guided_combat_scenario.gd:94`).

What persists:

- **Level and chosen skills:** maximum level **20**, **30 available skill definitions**, up to **19 earned skill points**. Level 2 costs **180 Embers**. Defiance capacity gains one per four levels (`progression_store.gd:983`; `data/progression_levels.json`; `data/skills.json`).
- **Moltshards:** first dragon defeated per run awards one; one shard can reset skill allocation. Exchange value is **250 Embers** (`run_engine.gd:1288`; `progression_store.gd:36`, `:1187`).
- **Umbra Depth unlocks**, tutorial/dialogue state, Grimoire discoveries, records and Chronicle.
- **Embers:** victory carries the remaining wallet forward. Defeat drops held Embers into a recovery marker available to the next run (`run_scene.gd:33946`; `progression_store.gd:1286`).
- **Noctyrax’s relic gift:** queued for the next descent, automatically applied, and lasts for that run (`run_engine.gd:192`, `:1302`).

Owned gear, reserve/attuned magic, ordinary relics, consumables, and grafts otherwise reset. Legacy permanent card-upgrade purchase APIs are disabled (`progression_store.gd:1305`).

**Smallest fix surface:** `game_data.gd` starter constants and `run_engine.gd:create_new_run`; add `new_descent_panel.gd`/`main_menu.gd` only for player-selected starting builds. Persistent unlock choices would also involve `progression_store.gd`.

## 4. Immolation

**Status: implemented as described below; the note does not specify a defect to classify.**

Verbatim data description, [cards.json:7906](data/cards.json:7906):

> Detonate 8 on every Fire tile within 1 of you, including yours. You take no damage from it. Empower (2 HP): within 2 instead.

- **Fire, Epic, Time 4**, base health cost **0**, `burn: false`—no base Exhaust cost.
- One action: `detonate`, damage **8**, range **0**, nonrotating five-tile cross including the player’s tile, `spare_player: true`.
- Empower costs **2 HP** and replaces the selection with a **13-tile radius-2 Manhattan diamond**.

Detonation implementation: `combat_engine.gd:12030`; `surface_card_rules.gd:314`.

- Fuel is **Fire ground**, regardless of who created it.
- Each selected Fire tile is consumed and blasts itself plus its four passable cardinal neighbors. Normal selection can therefore damage tiles up to two steps from the hero; Empower can reach three.
- Each actor is hit once by the combined blast normally; overlapping crosses do not ordinarily multiply damage.
- Enemies and illusions can be hit; destructible terrain takes damage and traps can trigger.
- `spare_player` excludes the hero from the direct blast. It does **not** install general immunity against secondary trap/keg explosions.
- With no Fire in its pattern, it remains playable and produces no blast (`spec/card_mechanics_surfaces.md:120`).

**Twenty cards create Fire that can fuel it**, with data line references:

- Guiding Flare `:350`; Firebrand Volley `:990`; Cinder Bloom `:1010`; Hearth Rush `:1119`; Molten Reach `:1249`.
- Ember Tithe `:2654`; Ember Guard `:3130`; Cinderweave Guard `:3431`; Borrowed Spark `:3909`; Pitch Firebomb `:4128`.
- Cinder Fusillade `:4449`; Cinder Wall `:4721`; Flame Jet `:4838`; Kindle `:5211`; Lamp Oil `:5233`.
- Cinder Trail `:7252`; Ember Ward `:7352`; Fan the Flames `:7373`; Magma Vent `:8040`; Meteorfall `:8068`.

All references above are in `data/cards.json`. Meteorfall creates its Fire at the next player-turn impact; Cinder Trail and Fan the Flames paint movement trails.

Relevant relic setups in `data/relics.json`:

| Relic | Setup |
|---|---|
| Ember Siphon `:489` | Spreads Fire when an enemy dies on it |
| Phoenix Ember `:692` | Defiance trigger places Fire under every enemy |
| Updraft Bottle `:853` | Push/Pull can transport existing elemental ground |
| Basalt Kiln (`basalt_calendar`) `:879` | Optional Rubble detonation produces Fire |
| Overflow Censer `:988` | Elemental overwrites spread ground |
| Black Sun Dial `:1008` | Stored consumed Fire can be released beneath an attack |
| Crowncoal Heart `:1783` | Once-per-turn single-target hit paints Fire on eligible ground |

**Ashen Brand** (`data/relics.json:1644`) expands detonation into connected Fire and adds **25% damage per extra overlapping blast cross**.

**Smallest fix surface:** `data/cards.json` for card parameters/text; `combat_engine.gd:_resolve_board_detonate` for shared detonation behavior; `surface_card_rules.gd` for fuel/aftermath rules.

## 5. Move-and-block cards

**Status: partially holds. There is no normal voluntary “stay here” or “skip movement” control. Automatic omission is possible when movement cannot resolve.**

| Card | Move | Block / extras | Data line |
|---|---|---|---:|
| Guarded Step | Move 2 | 3 Block, +1 Card Play | 32 |
| Warded Advance | Move 2 | 7 Block | 582 |
| Trapdoor | Blink 4 | 5 Block, Vision 2 for two turns | 730 |
| Leather Roll | Move 2 | 6 Block | 2524 |
| Gravewind Step | Blink 3 | 4 Block | 2633 |
| Dust Glide | Move 3 | 3 Block | 2827 |
| Static Pivot | Move 3 | Electrified on arrival, 3 Block | 3653 |
| Zephyr Feint | Move 3 | Draw 1, 2 Block | 3723 |
| Smoke Bomb | Blink 2 | 2 Block; consumed item | 4229 |
| Hotfoot | Move 2 | If turn began on Fire: 4 Block and draw 1 | 7856 |

Lines refer to `data/cards.json`.

Current interaction:

- Select/drag the card, then choose a destination. The hero’s current tile is explicitly excluded from Move and Blink targets (`combat_engine.gd:1136`).
- The old skip handler exists, but [run_scene.gd:22163](scripts/run_scene.gd:22163) makes `_current_action_can_skip()` **always return false**. The controller’s conditional “Skip Step” label is consequently unreachable.
- If a multi-action card’s movement has no legal destination, its targetless continuation can be resolved automatically (`run_scene.gd:19588`). Immobilized movement is also skipped by the resolver.
- Headlessly verified: immobilized **Guarded Step** reaches confirmation at the same position with **3 Block**.
- **Hotfoot differs:** its conditional reward belongs to the movement action itself, rather than a separate Block action, so skipping that action does not independently award its Block.

**Smallest fix surface:** `run_scene.gd` preview targeting, confirmation, and input prompts. A deliberately legal same-tile move would additionally touch `combat_engine.gd`; the cards already describe multi-action effects.

## 6. Next-section flow

**Status: partially addressed. Navigation exists; the section change still uses the ordinary room handoff.**

After the section’s dragon dies, `run_engine.gd:1285`:

1. Marks the room cleared.
2. Heals **25% of maximum HP, rounded up**.
3. Awards dragon Embers plus the **30-Ember base victory bonus**, subject to Depth rules.
4. Awards the dragon relic and the first-dragon Moltshard if applicable.
5. Opens the dragon reward screen.

Its button reads **“CONTINUE”**, or **“COMPLETE ASCENT”** for the final dragon (`run_scene.gd:15989`). Continuing a nonfinal reward returns to `room` mode with:

> The labyrinth opens outward.

The map then offers **“Next section”**. It appears only while viewing the active section, in room mode, standing in a cleared boss room with an available connection to the next entry: [section_map_panel.gd:643](scripts/section_map_panel.gd:643). It selects that entry through the normal room-selection handler.

Current visuals:

- Relic delivery beam/motes and acquisition flourish.
- Reward fade: **0.24 s**, or **0.12 s** reduced motion.
- Map fade-in: **0.32 s**, or **0.12 s** reduced motion (`run_scene.gd:16006`).
- Next-section selection closes the map, plays the normal door-opening sequence, then swaps to the next entry (`run_scene.gd:22107`, `:27318`).
- Modern section maps explicitly return **false** from `begin_travel_animation`; the legacy moving map token is not used (`section_map_panel.gd:703`).
- Later thresholds have **no authored opening narration**; the narration dictionary is empty (`start_room_map_flow.gd:9`).

**Smallest fix surface:** `section_map_panel.gd:_request_onward`, `run_scene.gd:_on_map_view_room_selected`, and `start_room_map_flow.gd` for section-entry presentation/narration.

## 7. Pre-battle objective text and history

**Status: the verbosity concern still holds for generic objectives; named dragon/Guardian objectives are already concise.**

Authored centrally in [combat_objective_rules.gd:11](scripts/combat_objective_rules.gd:11). Pre-battle displays the description at **19 px**, wrapping; if empty, it displays the title (`pre_battle_view.gd:174`).

| Type | Current title, verbatim | Current description, verbatim |
|---|---|---|
| `kill_all` | Defeat All Enemies | Defeat every enemy in the room. |
| `kill_leader` | Defeat the Leader | Defeat the marked leader. Remaining enemies withdraw. |
| `survive` | Survive | Hold out until the marked time. Reinforcements emerge while the clock advances. |
| `reach_exit` | Reach the Exit | Reach a marked threshold to escape through that door. Enemies and terrain are positioned to bar your path. |

For dragons/Guardians, the title becomes **“Defeat \<enemy name\>”**, and description is empty—for example **“Defeat Tharokh, the Worldspine”** (`combat_objective_rules.gd:221`).

Survive is retained for saved/authored encounters but **removed from new objective rotation**. Ordinary seeded combat currently rolls **50% Defeat All, 25% Leader, 25% Exit**, with onboarding and boss exceptions (`combat_objective_rules.gd:151`).

History:

- **`1df6f21b6` — 2026-08-06, “Add varied combat encounter objectives”** introduced the descriptions. Kill All and Survive already had their current full descriptions.
- Its older Leader description was:
  > Slay the marked leader. The remaining enemies fall when their leader dies.
- Its older Exit description was:
  > Reach any marked threshold. Enemies and terrain are positioned to bar your path.
- **`6bc6835ac` — 2026-08-06** extended Exit to its current wording.
- **`bb8b0bae3` — 2026-09-14** changed “Kill” titles to “Defeat” and shortened Leader to its current description.
- **`2db65733d` — 2026-09-15** removed the named dragon/Guardian description.
- **`0fcc557b8` — 2026-10-04** made descriptions the prominent wrapping pre-battle text. Immediately before that commit, the prominent headings were **“OBJECTIVE · DEFEAT ALL ENEMIES”**, **“OBJECTIVE · DEFEAT THE LEADER”**, **“OBJECTIVE · SURVIVE”**, and **“OBJECTIVE · REACH THE EXIT”**; descriptions were secondary **13 px clipped/ellipsized** labels.

Thus the recent change chiefly **promoted existing long copy**, rather than introducing a new wordy rewrite.

**Smallest fix surface:** `pre_battle_view.gd:174` for a concise heading with rules retained in tooltip; `combat_objective_rules.gd:11` only if rewriting shared rules text.

## 8. Pre-battle enemies and available idles

**Status: the static-enemy concern still holds. Animation assets already cover most enemy identities.**

Pre-battle uses each enemy’s **static full-body `art_path` texture** in a `TextureRect`, with an ink pool, HP badge, name, and threat captions: [pre_battle_view.gd:297](scripts/pre_battle_view.gd:297). Relative scale and feet alignment come from `ActorPresentation` (`pre_battle_foe_layout.gd:10`). The inspection dialog uses a cropped version of the same static art (`pre_battle_inspection_view.gd:39`).

The equipment-menu hero already uses a live **ProtagonistCutout**, with current gear, front/rear rigs in a transparent **512×512 SubViewport**, cropped to the registered **255×255** figure. It runs an **0.84-second idle cycle**; reduced motion uses a rest pose (`run_scene.gd:30169`; `protagonist_cutout/renderer.gd:20`, `:212`; `gear_portrait.gd:4`).

Of **43 enemy definitions**, **32 have integrated idle-capable cutout renderers**:

- **18 established identities:** Tunnel Crawler, Dust Acolyte, Bone Harrier, Stone Warden, Cinder Ooze, Cinder Droplet, Shale Bloomer (`bile_bloomer`), Chainbound Gaoler, Grave Surgeon, Frostglass Lancer, Lightning Wisp, Veilbound Acolyte, and dragons Tharokh, Vyraketh, Vaeloryx, Iskaldra, Noctyrax, Zekarion.
- **13 Guardian/helper identities:** Ashen Reaver, Rimejaw, Storm Cantor, Gallows Roc, Craghide, Last Lamplighter, Ash Hound, Rime Whelp, Rime Spitter, Bell Tender, Roc Fledgling, Stoneback Mite, Wick Shade.
- **Gust Shrike**, whose integration manifest is marked ready.

Registry references: `combat_board_view.gd:1086`; `guardian_cutout/renderer.gd:9`; `gust_shrike_cutout/renderer.gd:28`. Rigs live under `assets/units/<identity>_cutout/` or `assets/units/guardians/<id>/`.

The **18 established identities also have legacy idle sheets**. Most resolve from `<art_path stem>_idle.png`; Warden, Gaoler, and Zekarion have sheets at older paths, and Veilbound Acolyte shares Dust Acolyte’s sheet. Examples:

- `assets/placeholders/units/crawler_anime_trial_idle.png`
- `assets/art/enemies/cinder_ooze_idle.png`
- `assets/art/enemies/chainbound_gaoler_idle.png`
- `assets/placeholders/units/zekarion_idle.png`

Sheet lookup/layout: `combat_board_view.gd:15098`; layout metadata is in `data/enemies.json`.

The **11 without integrated idle rigs or matching idle sheets** are Hoarfrost Seer, Gale Herald, Arc Thrall, Gloam Stalker, Burrow Grub, Ember Tick, Storm Capacitor, Hollow Mimic, Briar Weaver, Slag Mortar, Glacial Mirror.

**Smallest fix surface:** pre-battle foe construction/layout plus a reusable live-actor presentation wrapper. Existing cutout assets can supply the 32 animated identities; the remaining 11 require new animation assets if all foes must animate.

## 9. Magic-slot limit: six

**Status: still holds. Six is a fixed active-loadout limit, with unlimited reserve storage.**

The canonical value is [game_data.gd:69](scripts/game_data.gd:69): `MAGIC_LOADOUT_LIMIT = 6`.

End-to-end behavior:

- Runs start with **six attuned copies**: Pale Spark ×2, Dull Bolt ×2, Waning Pulse ×2.
- New magic comes from ordinary combat rewards, Scavenger purchases, and events. Ordinary fights offer **three cards**, normally **two matching the room’s element plus one general** (`run_engine.gd:2708`).
- Taking a reward adds it to **`magic_inventory`**, not directly to the deck. Current notice:
  > Added %s to reserve magic.
- Alternatively, ordinary combat rewards offer **3 HP recovery**, before bonuses. Guardians award trophies; dragons use their milestone rewards (`run_engine.gd:1320`, `:1456`, `:1866`).
- Character → Magic shows **“ATTUNED MAGIC”**, **“6 / 6”**, and **“LEARNED MAGIC”** for reserve. Mouse drag swaps reserve and attuned cards; keyboard/controller activation selects a source and then a card in the opposite column (`run_scene.gd:30287`, `:31081`, `:31543`).
- Changes are allowed in **room, Campfire, and pre-battle** modes. Combat locks the loadout (`run_engine.gd:1507`).
- Swapping replaces one attuned copy and returns the outgoing copy to reserve. There is no ordinary empty-slot/unequip operation (`run_engine.gd:1557`).
- Active deck = **equipped gear’s cards + attuned magic + equipped items**. Gear-provided elemental cards do not consume magic slots. There is no global six-card deck limit (`game_data.gd:380`).
- Each fight creates a fresh shuffled combat deck from that compiled list; discard/Exhaust piles reset. Consumed item ownership is separately reconciled (`combat_engine.gd:822`, `:896`; `run_engine.gd:1209`).
- Attuned/reserve magic persists through the current run and save/resume, then resets on a new run.

**Deck, Grimoire, Chronicle are separate:**

- **Deck:** presently equipped combat cards.
- **Reserve / “Learned Magic”:** owned magic copies in this run.
- **Grimoire:** persistent discovered reference entries; discovery does not grant a playable copy or gate the reward pool (`grimoire_library.gd:404`, `:776`, `:994`).
- **Chronicle:** historical run records, including compiled deck counts/definitions; retains **50 records**, without granting those cards (`chronicle_rules.gd:8`, `:68`).

Every production location using the limit:

| Purpose | Location |
|---|---|
| Definition/accessor | `game_data.gd:69`, `:227` |
| Overflow repair: move copies beyond six into reserve | `run_engine.gd:2255` |
| Legacy reward-to-loadout migration | `run_engine.gd:2276` |
| Fill missing slots with starter magic | `run_engine.gd:2294` |
| Swap bounds, after repair | `run_engine.gd:1557` |
| Character header and six attuned rows | `run_scene.gd:30293`, `:30297` |
| Character deck-group count text | `run_scene.gd:30352`, `:30581` |
| Retained-row preparation/key enumeration | `run_scene.gd:30483`, `:30499` |
| Controller initial-focus enumeration | `run_scene.gd:3487` |
| Pre-battle count and retained refresh | `pre_battle_view.gd:435`, `:519` |

The deck compiler itself does **not** clamp magic count; normal run creation and repair maintain the six-slot invariant.

**Smallest fix surface:** `game_data.gd` limit and starter list. Existing UI loops follow the accessor. Changing from mandatory filled slots to optional slots would also require `run_engine.gd` repair/swap behavior and Character Magic interactions.

TRIAGE COMPLETE