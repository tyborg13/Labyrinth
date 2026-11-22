# QA-122 text truth audit

Base `dea2395c5ed3346f4f5a9897ff46ceef57b3592e` on `codex/release`. Seeded, headless, report-only.

## Findings

| System | Wrong number | Missing effect | Wrong condition | Wording-only | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hero cards | 5 | 0 | 1 | 0 | 6 |
| Enemy moves | 0 | 0 | 0 | 1 | 1 |
| Status, keywords and Grimoire | 1 | 0 | 5 | 1 | 7 |
| Items | 1 | 2 | 0 | 0 | 3 |
| Relics | 0 | 1 | 0 | 1 | 2 |
| Omens | 0 | 0 | 1 | 0 | 1 |
| Events | 4 | 0 | 0 | 0 | 4 |
| Encounter HUD | 4 | 5 | 7 | 0 | 16 |
| **Total** | **15** | **8** | **14** | **3** | **40** |

A row represents one distinct discrepancy. Shared copy and repeated evidence are cited on the same row. Event numbers are the concrete choice-page offer, compared with the committed grant. Damage comparisons keep raw damage, modifiers, defenses, and actual Health loss separate.

### Hero cards

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Quicken card panel](../../data/card_panel_text.json) and Hourglass Sand item rules | “Your next card this turn costs 4 less Time.” | The next card costs at least 1. A printed 2-Time Quick Stab pays 1 after Quicken 4, a reduction of 1. The active Quicken badge and Grimoire state the floor. | `status/quicken_floor` | Wrong number |
| [Petrify card panel](../../data/card_panel_text.json) and [keyword](../../data/glossary.json) | “Skips its next turn and gains 5 Block.” | The same Petrified enemy remains a legal target. First application grants 5 Block. Applying it again before the enemy's turn grants 0 additional Block. | `status/petrify_repeat` | Wrong condition |
| [Cinder Wall Grimoire](../../data/cards.json) | “Leave Fire on 4 tiles within range 2...” | Range 2 limits the aim tile. Aiming at the adjacent enemy still places one of the four Fire tiles three tiles from the hero. | `cards/cinder_wall`, neutral, aim `[5,5]` | Wrong number |
| [Frost Lane Grimoire](../../data/cards.json) | “Leave Ice on 3 tiles within range 3...” | At the range-3 aim, the two edge tiles are four tiles from the hero. | `cards/frost_lane`, far, aim `[4,2]` | Wrong number |
| [Earthen Rampart Grimoire](../../data/cards.json) | “Raise Outcrops on 3 tiles within range 2 ... Empower (Exhaust): 5 tiles.” | Range 2 limits the center. The base creates edge Outcrops at distance 3. Empower reaches distance 4 around the same center. | `cards/earthen_rampart`, far, aim `[4,3]`, both modes | Wrong number |
| [Meteorfall Grimoire](../../data/cards.json) | “Mark 3 tiles within range 4.” | Range 4 limits the aim. The marks reach distance 5 at `[9,5]`. | `cards/meteorfall`, far, aim `[8,5]` | Wrong number |

### Enemy moves

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Burrow Grub Erupt, pre-battle rows](../../scripts/action_icon_library.gd) | “Erupt 6 · Push 1 · Rubble · Expose 2” and “Self: · Expose 2” | The Grub applies Expose 2 to itself once. The hit target loses 6 Health, is Pushed 1, and gains no Expose. The unqualified attack-row chip duplicates the Self rider. | `enemies/burrow_grub/erupt` at `[6,5]` | Wording-only |

### Status, keywords and Grimoire

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Shock glossary and icon tooltip](../../data/glossary.json) | “On its next turn, it can only Move or Blink.” | A Cleanse action that removes Shock can resolve while the hero is Shocked. Smelling Salts contains that Cleanse. | `status/shock_cleanse` | Wrong condition |
| [Shock Grimoire](../../data/grimoire.json), first rule | “Cancels the affected character's next non-movement action.” | One activation's Shock removes all of the crawler's non-movement actions. It advances, then both the strike and Block are suppressed. | `status/shock` | Wrong condition |
| [Shock Grimoire](../../data/grimoire.json), second rule | “Chain and conducted hits Shock too.” | A normal Chain jump from Storm Jar damages a second enemy without applying Shock. Storm Jar applies Shock to Electrified-assisted hits. | `status/chain_without_shock` | Wrong condition |
| [Card Play glossary and icon tooltip](../../data/glossary.json) | “Kills give one more.” | A player-card kill grants 1 play for the ordinary crawler and 0 for a summoned crawler. The Grimoire includes the summon exception. | `status/kill_card_play` | Wrong condition |
| [Wait glossary and icon tooltip](../../data/glossary.json) | “Each of your first 2 unused Card Plays adds 5 Time to your next turn.” | With the two base plays spent and two plays still available, Wait adds 0. Only unused base plays count. | `status/wait_bonus` | Wrong number |
| [Bleed Grimoire](../../data/grimoire.json) | “Deals its displayed damage before each movement or attack action.” | With Bleed 3, Move to the open tile costs 3 Health. Blink to the same tile costs 0 Health. | `status/bleed_blink` | Wrong condition |
| [Retaliate glossary and short Grimoire rule](../../data/glossary.json) | “Whoever hits this unit up close takes that much damage.” | A melee attack at distance 2 also triggers Retaliate. The range-2 melee fixture deals 6 to the hero and receives 3 in return. The long Grimoire rule defines the melee exception. | `status/retaliate_reach` | Wording-only |

### Items

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Bottled Gale item rules](../../data/cards.json) | “Consume. Push 3.” | Pushes each orthogonally adjacent enemy 3 tiles away from the hero. Two adjacent enemies move in different directions, and the enemy two tiles away stays put. The card face includes the area diagram. | `status/bottled_gale_area` | Missing effect |
| [Powder Keg item rules](../../data/cards.json) | “When destroyed, it deals 6 damage.” | The keg hits its tile and four neighbors. The hero and an adjacent enemy each lose 6, while a farther enemy stays at 100. The card's Detonate tooltip shows the blast. | `status/powder_keg_burst` | Missing effect |
| [Lamp Oil item rules and Grimoire](../../data/cards.json) | “Leave Fire on 3 tiles within range 3.” | At the range-3 aim, the two edge tiles are four tiles from the hero. | `cards/lamp_oil`, far, aim `[4,2]` | Wrong number |

### Relics

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Hobnail Cleats](../../data/relics.json) | “Ice doesn't make you Chilled. While you stand on Ice, your Ice attacks deal 2 more damage.” | Cleats also prevent the hero from being Frozen by battlefield Frostbite. With no prior Chill, the same Frostbite freeze hook sets Freeze 1 without Cleats and 0 with them. | `relics/hobnail_cleats.special` | Missing effect |
| [Borrowed Hourglass](../../data/relics.json) | “Take another turn at once. This turn's Time is added to it.” | The extra activation is scheduled at the current clock time. The ensuing delay carries the first activation's unpaid 2 card Time **and** 10 Wait. The relic's existing production suite checks the ensuing schedule. | `relics/borrowed_hourglass.special`, `focused.gd` relic U4 | Wording-only |

### Omens

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Deepening Dark](../../data/events.json) | “The [Umbra icon] is one stage deeper in each combat.” | Clear becomes Fringe. Heart stays Heart because the omen cannot enter Eclipse. | `omens/deepening_dark` | Wrong condition |

### Events

All four choices below are available at 98/99 Health. The result line correctly reports the one point actually awarded.

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Whispering Well, Drink](../../data/events.json) | “Heal 8 [Health].” | Health increases by 1. | `events/whispering_well/drink`, seed 122018 | Wrong number |
| [Moth Library, Burn](../../data/events.json) | “Heal 6 [Health].” | Health increases by 1. | `events/moth_library/burn`, seed 122018 | Wrong number |
| [Hoarfrost Spring, Bathe](../../data/events.json) | “Heal 10 [Health].” | Health increases by 1. | `events/hoarfrost_spring/bathe`, seed 122018 | Wrong number |
| [Ash Confessional, Some](../../data/events.json) | “Heal 8 [Health].” | Health increases by 1. | `events/ash_confessional/some`, seed 122018 | Wrong number |

### Encounter HUD

For Frostbite damage, the hero and the adjacent crawler stand on Ice with Chilled and no defenses. The third Ice tile is empty. `half=true` reproduces the latched alternate rule.

| Source | Shown text | Actual behavior | Fixture | Severity |
| --- | --- | --- | --- | --- |
| [Slagmaster](../../data/battlefield_rules.json) | “Its Fire spreads 1 tile toward you.” | Fire owned by the hero spreads too. With only hero-owned Fire, 3 new Fire tiles appear. | `battlefields/slagmaster` | Wrong condition |
| [Ashen Reaver](../../data/battlefield_rules.json) | “The Reaver's Fire spreads 1 tile toward you.” | Fire owned by the hero spreads too. With only hero-owned Fire, 3 new Fire tiles appear. | `battlefields/ashen_reaver` | Wrong condition |
| [Hollow Prior](../../data/battlefield_rules.json) | “Its followers hidden in the dark Blink 3 tiles toward you.” | The hidden Prior itself is eligible and moves from `[7,5]` to `[5,5]`. The selector has no follower-only condition. | `battlefields/prior` | Wrong condition |
| [Gallows Roc](../../data/battlefield_rules.json) | “The Roc's wind Pushes everyone 1 tile toward it.” | One global direction is aimed from the hero toward the Roc. A unit already beyond the Roc moves from `[8,5]` to `[9,5]`, away from it. | `battlefields/gallows_roc` | Wrong condition |
| [Last Light](../../data/battlefield_rules.json) | “Every enemy hidden in the dark Blinks 2 tiles toward you.” | A hidden enemy with no visible, unoccupied landing in range stays at `[7,5]`. A different hidden enemy moves just one tile, from `[6,5]` to `[5,5]`. | `battlefields/last_light` | Wrong condition |
| [Oracle](../../data/battlefield_rules.json) | “Frostbite hits everyone on Ice for 2 and Freezes them.” | The Chilled hero and crawler each take 4. The 2-point printed amount is the base of a direct Ice hit. | `battlefields/oracle` | Wrong number |
| [Ice Snare](../../data/battlefield_rules.json) | “Frostbite hits everyone on Ice for 1 and Freezes them.” | The Chilled hero and crawler each take 3. | `battlefields/snare_ice` | Wrong number |
| [Iskaldra, Rime Talon](../../data/battlefield_rules.json), also [Grimoire](../../data/grimoire.json) | “Frostbite hits everyone on Ice for 3 and Freezes them.” | The Chilled hero and crawler each take 5. | `battlefields/iskaldra`, `half=false` | Wrong number |
| [Iskaldra, half Health](../../data/battlefield_rules.json) | “Frostbite hits everyone on Ice for 3 and Freezes them.” | The Chilled hero and crawler each take 5. | `battlefields/iskaldra`, `half=true` | Wrong number |
| [Iskaldra, Rime Talon](../../data/battlefield_rules.json) | “... hits everyone on Ice ... and Freezes them.” | Iskaldra on Ice loses 3 Health, remains unfrozen, and keeps the Ice tile. | `battlefields/iskaldra`, `half=false`, actor 1 | Wrong condition |
| [Iskaldra, half Health](../../data/battlefield_rules.json) | “... hits everyone on Ice ... and Freezes them.” | Iskaldra on Ice loses 3 Health, remains unfrozen, and keeps the Ice tile. | `battlefields/iskaldra`, `half=true`, actor 1 | Wrong condition |
| [Oracle](../../data/battlefield_rules.json) | “... on Ice for 2 and Freezes them.” | Ice is removed under both newly Frozen units. Empty Ice remains. | `battlefields/oracle` | Missing effect |
| [Ice Snare](../../data/battlefield_rules.json) | “... on Ice for 1 and Freezes them.” | Ice is removed under both newly Frozen units. Empty Ice remains. | `battlefields/snare_ice` | Missing effect |
| [Rimejaw](../../data/battlefield_rules.json) | “Rimejaw's Frostbite Freezes everyone standing on Ice.” | Both newly Frozen units lose the Ice under them even on this zero-damage beat. | `battlefields/rimejaw` | Missing effect |
| [Iskaldra, Rime Talon](../../data/battlefield_rules.json) | “... on Ice for 3 and Freezes them.” | Ice is removed under both newly Frozen units. | `battlefields/iskaldra`, `half=false` | Missing effect |
| [Iskaldra, half Health](../../data/battlefield_rules.json) | “... on Ice for 3 and Freezes them.” | Ice is removed under both newly Frozen units. | `battlefields/iskaldra`, `half=true` | Missing effect |

## Coverage and proof

1. The hand projection supplied face rows, icon numerals, area tokens, tooltips and the Time value. The player resolver supplied legal targets, per-action before/after receipts, combat events, and finish receipts. All 305 active card IDs completed once in base mode, and all 14 authored Empower modes completed once. The four retired IDs resolve to replacements and were excluded. The 1,970 distinct single-step upgrade choices are hypothetical legacy variants. The current run strips old card growth. QA-122 injected a production legacy definition only for each variant and used the same action and finish resolver. The hypothetical Add Move 1 options on Rooted Stance and Shield Wall did not complete. Their already-resolved self-Immobilize prevented the appended Move.
2. Four origins per move yielded 548 enemy activations from 44 enemy definitions and 137 authored intents. The receipts record pre-battle rows, live intent badge values, playback captions and committed transitions. The status export includes 139 glossary and 375 Grimoire entries plus focused resolver cases. The 24 items are included in the card sweep. The run export includes all 100 active relics, all 11 omens, and all 45 events across 128 choice definitions. The battlefield sweep includes 31 standard/alternate HUD states and three Ember Hoarder tiers. Each standard state fired on the sampled correct trigger and stayed quiet on the sampled wrong trigger.
3. The tables contain verified discrepancies. The comparison script emits raw candidates separately. For example, Iron Wheel's higher post-move damage and Cinder Wall's higher Block on Fire are already explained by their visible riders. The cases below still need claim-level coverage.

### Checks requiring additional work

- The action probes complete each live card/mode, but do not cover every legal aim, rotation, body footprint, secondary status branch, or interaction among several modifiers. A zero-delta step can be optional or require a different setup. Generated weapon graft combinations, stacked legacy mods, and all possible relic/skill combinations were not enumerated.
- Enemy context includes range and fixed marks, but does not exhaust the alternate declaration and target rules for unusual geometry, optimized Warband orders, difficulty scaling, or blocked and protected targets. Matching badge and caption numbers cannot prove all area tiles or all riders.
- Shared tooltips and Grimoire entries were inventoried. Trigger chains, procedural conditions, and progression prose outside the focused status fixtures still require source review or new fixtures. The active relic sweep applies each relic through the opening, activation-end and representative card paths. A receipt alone does not establish that every conditional or multi-turn hook fired.
- The event probe includes seeded legal and blocked choices and three Health states. Numeric comparison skips cases where one preview line maps to multiple outcome entries. Outcome localization, preview hover diagrams, inventory exhaustion across arbitrary seeds, and event narrative text were not independently compared by this audit.
- The rule sweep exercises the installed dispatcher and the HUD sentence with seeded boards. It does not enumerate every generated room or verify native renderer behavior.

### Chosen defaults

Seed `122017` for combat, with event seeds `122017–122019`. The combat board is an 11×11 test grid with a wall border, the hero at `[4,5]`, 100 maximum Health, and a fixed draw pile. Profiles vary distance, setup ground, statuses, defenses and prior card play. Target selection prefers a legal target on the primary enemy and a movement endpoint that keeps a subsequent strike in reach. The four enemy origins are `[5,5]`, `[6,5]`, `[8,5]` and `[6,7]`. The report uses headless semantic output and named fixture coordinates. No `TODO_DESIGN` placeholders were added.

### Proof for the design owner

From the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-122 && python3 tools/godot_task_runner.py --task-id qa-122 --stream -- godot --headless --path . --script tools/qa122/audit.gd -- /private/tmp/labyrinth_codex/qa122-proof all
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-122 && python3 tools/qa122/compare.py /private/tmp/labyrinth_codex/qa122-proof --candidates /private/tmp/labyrinth_codex/qa122-proof/candidates.jsonl
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-122 && python3 tools/godot_task_runner.py --task-id qa-122 --stream -- godot --headless --path . --script tools/qa122/focused.gd
```

To reproduce a single source, replace `all` with the family and the catalog ID, for example `battlefields iskaldra`, `enemies burrow_grub`, or `status petrify_repeat`. Write a filtered replay to its own output directory so it cannot replace the full evidence file. This report-only brief calls for headless proof. Windowed captures and playable inspection are inapplicable.

### Observed result lines

The audit wrote JSONL receipts to `/private/tmp/labyrinth_codex/qa122-proof/`. The candidate file is `candidates.jsonl` in that directory.

```text
QA122 cards: 5103 receipts -> /private/tmp/labyrinth_codex/qa122-proof/cards.jsonl
QA122 enemies: 548 receipts -> /private/tmp/labyrinth_codex/qa122-proof/enemies.jsonl
QA122 events: 384 receipts -> /private/tmp/labyrinth_codex/qa122-proof/events.jsonl
QA122 omens: 11 receipts -> /private/tmp/labyrinth_codex/qa122-proof/omens.jsonl
QA122 relics: 100 receipts -> /private/tmp/labyrinth_codex/qa122-proof/relics.jsonl
QA122 battlefields: 34 receipts -> /private/tmp/labyrinth_codex/qa122-proof/battlefields.jsonl
QA122 status: 542 receipts -> /private/tmp/labyrinth_codex/qa122-proof/status.jsonl
QA122 candidates: 28
QA122 MECHANICS: 6777 checks, 0 failures
SHORT CARD TOOLTIPS TEST RESULT: PASS (763 checks, 0 failures)
BATTLEFIELD FUEL TEST RESULT: PASS (78 checks, 0 failures)
RELIC U7 TEST RESULT: PASS
Event preview equals result: 37500 choices; 50 seeds × 3 depths × fresh/exhausted; 4650 substitutions
Event preview matrix suite: 0 failures
```

The final headless runs exited successfully. Godot also printed a macOS system CA certificate diagnostic at startup. Native renderer captures and the full merge suites were outside this audit.
