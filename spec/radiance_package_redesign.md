# Radiance package redesign

Status: design-review approved for implementation on 2026-08-09.

## Design lodestar

The strongest additions transform an existing action without adding a new interaction path. Movement may leave Light across its path, Chain may light every struck enemy, and illusions may carry or leave Light. The player still targets and plays the original card normally; the action's tactical aftermath changes.

Conditional numeric bonuses remain useful connective tissue, but they must not dominate the changed slice. This pass does not add source-selection prompts, card-selection prompts, new trap actors, vague action mirroring, or relic-ID-specific engine branches.

## Pool targets

- 60 relics total: 18 common, 20 rare, 14 epic, and 8 legendary.
- 20 meaningful Radiance relics: 6 common, 8 rare, 4 epic, and 2 legendary.
- Radiance is approximately one third of weighted offer mass. Seeded offer proof must measure the actual frequency of three-relic offers containing at least one Radiance relic.
- 35 current relics remain unchanged; 8 are revised; 4 are replaced in place to preserve their IDs in saves; 13 are new.

## Approved relic changes

### Revised

| Relic | Rarity | Approved effect |
| --- | --- | --- |
| Pilgrim Boots | Common / Radiance | Non-attack Move and Blink actions gain 1 range. Moves leave radius-1 Light for 2 activations on every tile entered; Blinks light their origin and destination. |
| Reinforced Shield | Common | While the player has Stoneskin, Block actions grant 3 additional Block. |
| Static Soles | Common / Radiance | The first Lightning card each turn that Moves or Blinks raises Lightning intensity by 1 and grants Vision 1 for 2 activations. |
| Cinderbrand Tongs | Common / Radiance | The first attack each turn that applies Burn raises Fire intensity by 1 and creates radius-1 Light at its target for 2 activations. |
| Mirror Shard | Rare / Radiance | The first illusion-creating card each turn grants 1 card play and Vision 1 for 2 activations. |
| Thawing Charm | Rare / Radiance | Excess healing still becomes Stoneskin up to its cap. The first actual conversion each turn creates radius-1 Light at the player for 2 activations. |
| Widow Thread | Rare | While an illusion exists, attacks inflict 1 additional Expose. |
| Phoenix Ember | Legendary / Radiance | Preserve its current Defiance package and also Dispel 2 Umbra when Defiance triggers. |

### Replaced in place

| Existing ID | New identity | Rarity | Approved effect |
| --- | --- | --- | --- |
| `ember_lens` | Brightglass Lens | Rare / Radiance | Ranged attacks against enemies in Light gain Chain 1. |
| `hollow_die` | Open-Eyed Pin | Common / Radiance | When a card grants Vision or Truesight, create radius-1 Light at the player for the effect's final duration. If both occur, use the longer duration. |
| `voltaic_tuning_fork` | Stormglass Beacon | Rare / Radiance | The first Chain attack each turn creates radius-1 Light for 2 activations beneath every enemy it hits. |
| `tectonic_abacus` | Captured Noon | Epic / Radiance | At 3 active Light sources, suppress Umbra by one stage; at 6, suppress it by two. Suppression is reversible and never goes below Clear. |

### New

| Relic | Rarity | Approved effect |
| --- | --- | --- |
| Dawnbrand Filament | Common / Radiance | The first direct attack each turn creates radius-1 Light at its target for 2 activations. |
| Glowstone Matrix | Common / Radiance | Cards containing a Stoneskin action also grant Vision 1 for 2 activations. |
| Briar Winch | Common | Push and Pull actions move Poisoned enemies 1 additional tile. |
| Hourglass Awl | Common | Attacks on cards costing 7 or more Time gain Pierce. |
| Beaconrunner Spurs | Rare / Radiance | The first Move or Blink each turn that ends in Light grants 1 card play and 3 Block. |
| True North | Rare / Radiance | While the player has Truesight, ranged actions gain 2 range. |
| Dawnstitch Cord | Rare / Radiance | The first card each turn containing a Radiance action grants 4 Block. |
| Starless Astrolabe | Rare / Radiance | While the player has Truesight, attacks that Freeze or Shock create radius-1 Light for 2 activations beneath affected enemies. |
| Witchglass Carapace | Epic | Ranged enemy attacks deal at most 1 damage to illusions. |
| Witchglass Lantern | Epic / Radiance | Living illusions add 2 radius to their tethered Light. It ends immediately when the illusion is removed. |
| Sunlit Edge | Epic / Radiance | While the player stands in Light, attacks gain Pierce. |
| Glassway Compass | Legendary | The first Blink each turn creates a 2-health illusion on the tile the player left. |
| Unclouded Sun | Legendary / Radiance | Once per combat, when a room that began with Umbra first becomes Clear, gain 12 Stoneskin, draw 3, and gain 3 card plays. |

Unchanged relics are: Iron Lung, Coffin Nails, Iron Buckler, Flint Edge, Mossbound Wraps, Tailwind Fletching, Rimecatcher Vial, Ion Spool, Duelist Whetstone, Frost Prism, Storm Capacitor, Gale Tabi, Anchor Chain, Venom Signet, Ember Siphon, Updraft Bottle, Basalt Calendar, Coalheart Crucible, Chorus Mask, Hourglass Splinter, Bloodglass Knife, Cold Mirror, Thunder Relay, Thornmail Brooch, Vaulting Sigil, Obsidian Heart, Overflow Censer, Funeral Bell, Bloodmoon Chalice, Moonless Compass, Storm Crown, Worldroot Idol, Black Sun Dial, Fivefold Knot, and Borrowed Hourglass.

## Approved card changes

Light carried by an attack is authored on that attack action with `illuminate_radius` and `illuminate_duration`; it is not a preceding standalone Illuminate action. The player makes one attack selection, and only attackable enemies, traps, or terrain are legal targets. Light is created at the snapshotted impact tile after damage, statuses, forced movement, terrain damage, and trap effects resolve, so the rider does not enable Light-conditioned bonuses for its own hit. A standalone `illuminate` action remains available for abilities and cards whose primary purpose is Light and retains free-tile targeting.

All eight newly Radiant cards set `radiance: true`. Lantern Shot, Guiding Flare, and Storm Beacon keep their existing Radiance identity but migrate to the same unified attack-rider representation.

| Card | Change |
| --- | --- |
| Ember Rain | Its ranged attack creates radius-2 Light at the impact for 2 activations after resolving. |
| Trapdoor | Add Vision 2 for 2 activations. |
| Firebrand Volley | Its ranged attack creates radius-1 Light at the impact for 2 activations; remove conditional Burn 2 and retain conditional bonus damage. |
| Icebound Chains | Replace Draw 1 with Truesight for 2 activations. |
| Spark Dart | Its ranged attack creates radius-1 Light at the impact for 2 activations; remove conditional Shock and retain conditional bonus damage. |
| Spark Focus | Add Vision 1 for 2 activations. |
| Squall Shot | Its area attack creates radius-2 Light at the selected attackable center for 2 activations after resolving. |
| Root Snare | Its ranged attack creates radius-1 Light at the impact for 2 activations after resolving. |
| Dawnstep | Increase Vision duration from 1 to 2 activations. |
| Prism Sight | Increase Truesight duration from 1 to 2 activations. |
| Lantern Shot, Guiding Flare, Storm Beacon | Merge each separate Illuminate-plus-attack pair into one attack action with the same radius and duration. |

## Approved Radiance ability branch

| Ability | Tier | Approved effect |
| --- | --- | --- |
| Long Dawn | Root | Temporary Light, Vision, and Truesight created by the player last 1 additional activation. Permanent and tethered effects are unaffected. |
| Sunpath | Branch | The first Move or Blink of 3 or more tiles each turn leaves radius-1 Light for 2 activations on every tile entered; Blink lights origin and destination. |
| Witchlight | Branch | Living illusions add 1 radius to their tethered Light. |
| Dawnbrand | Junction | The first direct attack each turn against an enemy standing in Light inflicts Expose 1. |
| Afterglow | Junction | When an illusion is removed during combat, it leaves radius-1 Light for 2 activations at its final tile. |
| Open Sky | Keystone | While standing in Light, the player has Truesight. |

Witchlight and Witchglass Lantern stack additively on one tethered source: the ability contributes +1 radius, the relic contributes +2, and owning both produces radius-3 Light. The board tooltip lists each contribution so neither choice becomes obsolete or ambiguous.

The original four branches keep their authored positions. Radiance is appended as a fifth branch on a widened 1250×540 fixed canvas, still presented without scrollbars. A complete build remains 19 skills with exactly one keystone. Keystone prerequisites are never waived: completion-aware eligibility blocks an earlier choice if it would leave no authored path to any keystone, while every branch's keystone remains reachable through its visible parents. Legacy 19-point no-keystone saves preserve the maximum deterministic legal subset and insert one prerequisite-valid keystone.

## UI design statement

1. Surfaces: card widgets, relic offers/details, the complete skill tree, combat board/HUD, and Grimoire inspection.
2. Player questions: what does this choice change, which familiar package enables it, and what board state will it create?
3. Primary actions: choose a relic, play an already-familiar card, or learn an ability. No new targeting or confirmation step is introduced.
4. Hierarchy: name and unique icon first, concise rules text second, detailed action tokens and source attribution on inspection.
5. Input: existing pointer, keyboard, controller, and Steam Deck paths remain authoritative because no new interaction mode is added. The fifth skill branch must fit the complete no-scroll tree.
6. Proof: real CardWidget renders for every changed card; real offer/detail renders for every changed/new relic; complete skill-tree states; combat captures for path Light, Chain Light, tethered Light, Afterglow, reversible Umbra suppression, and Light-conditioned rules. Routine proof is 1920x1080 at 100% UI scale.

## Review decision

Independent design review returned **SIGNOFF** on this exact matrix. Optional health-for-extra-Blink range was rejected because it changes tile preview and choice semantics. Shared path Light, tethered actor Light, impact Light, and affected-enemy Light are explicitly approved reusable primitives.

A follow-up independent review rejected an implementation shortcut that would have waived keystone prerequisites only on the final point. The accepted replacement is the generic completion-aware eligibility rule above, with explicit lock copy for a choice that would strand all capstones.
