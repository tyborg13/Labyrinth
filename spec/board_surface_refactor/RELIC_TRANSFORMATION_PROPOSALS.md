# Nine relic transformations for the surface refactor

> Historical design record from the initial surface refactor. The current rules
> are in [DESIGN.md](DESIGN.md), version 5. In the feedback pass, Fire became
> 2 damage on entry / 3 at turn start, Chilled +2 attack damage, Frozen triple
> attack damage, and Rubble charges on departure. Ordinary Electrified survives
> conduction and Chain; Stormcoal Fire is still consumed. Lightning specialist
> Shock now requires an Electrified-assisted hit instead of separately paid fuel.
> The proposals below retain their original rationale and are not current rules.

Design proposals only. No game data, art or approved numerical balance changes. These replace nine existing relic roles; they are not nine additional relics. Stable IDs preserve ownership and save mappings. The owning `DESIGN.md` v4 supplies the common combat contract.

The user's direction is to make a substantial part of the relic pool change how a build plays, especially across elemental strategies. A bridge should change a route, targeting rule, resource conversion or terrain decision. It need not end with bonus damage, draw, Block or another generic reward. These nine use different mechanisms; they are not a template to apply to every relic.

The relic skill and `spec/relic_design_rubric.md` were consulted. Their build-glue and rarity principles apply; their retired intensity examples and old trigger-feasibility counts do not describe the new rules. Existing rarity is a starting review category, not numerical signoff. Final icons require the normal polished 96×96 asset workflow; existing icon artwork has not been visually re-reviewed in this proposal pass.

## Common rules these proposals preserve

- There is one elemental slot—Fire, Ice or Electrified—and an independent Rubble layer. Light is separate. No new ordinary surface types, strengths, duration meters or per-tile counters are introduced.
- Fire and Ice activate occupant effects only on actual entry or the affected actor's eligible turn start. Painting terrain underneath an existing actor does not immediately damage or Chill it. Rubble changes entry cost directly; Electrified is immediately usable ground, not an occupant status.
- Freeze consumes all enabling Ice under the actor's footprint. Frozen cannot refresh or regain Chilled, including during its skipped activation; it thaws after that activation. Neither a relic-created Ice tile nor an Ice painter retroactively activates a completed hit.
- Ordinary damaging Lightning conducts only through its cardinally contiguous Electrified component, hitting its enemy occupants under the core conduction contract and consuming that energized component. It does not jump air gaps. Chain can bridge gaps through individual conductive tiles using its printed hop reach; this proposal does not introduce an additional-target-count reinterpretation.
- Conductive Fire is the user-approved exception: Fire behaves as conductive ground as well as Fire, and Lightning consumes it when used. Both sides can use it. Electrical consumption never automatically causes Detonate.
- A printed placement followed by Lightning or Detonate can use the new ground immediately. Only passive occupant effects wait for entry/start. Reusable relic hooks must respect that printed order.
- Global terrain properties affect everyone. Player equipment techniques belong to the player because the relic explicitly grants that technique; they do not create safe personal Fire, private Ice or hazard immunity.
- Optional costs and geometric choices appear in the action's targeting preview before commitment. Do not introduce interrupting post-hit confirmation dialogs or silently spend defense on an attack the player aimed without that cost.

## Curated shortlist

| Existing ID | Proposed display name | Main change | Bridge / decision |
|---|---|---|---|
| `coalheart_crucible` | Stormcoal Crucible | All Fire is conductive and can be spent by Lightning | Fire territory becomes Lightning infrastructure; choose whether to preserve it for hazards/Detonate |
| `updraft_bottle` | Updraft Bottle | A chosen Push/Pull carries existing elemental ground with its target | Air relocates another element's setup instead of merely increasing force or awarding resources |
| `briar_winch` | Quarry Winch | Spend Rubble beneath a target to redirect Push/Pull sideways | Earth preparation unlocks new Air/physical control angles |
| `thornmail_brooch` | Faultline Brooch | Spend Stoneskin to turn a melee hit into a terrain-shaping cross | Persistent defense becomes attack geometry and future Rubble |
| `frost_prism` | Shatterglass Prism | A directly killed Frozen enemy leaves a Rubble formation | An Ice finisher changes movement and prepares Earth/Air play |
| `rimecatcher_vial` | Rimecatcher Vial | A successful Freeze redistributes one consumed Ice tile to an adjacent floor tile | Ice setup moves forward into a new lane without preserving Ice beneath the Frozen body |
| `worldroot_idol` | Worldroot Idol | Consume a connected Rubble tile to originate a single-target attack there | Earth builds and spends a network for radically different attack angles |
| `basalt_calendar` | Basalt Kiln | Detonate can crush Rubble as an alternative fuel, leaving Fire afterward | Earth control can be cashed into a Fire attack, with a changed board afterward |
| `thunder_relay` | Thunder Relay | An opted-in Chain exchanges its first and last surviving targets after the attack | Lightning becomes a deliberate formation-changing tool without inventing another Chain hit budget |

**Best four examples to lead with:** Stormcoal Crucible, Updraft Bottle, Faultline Brooch and Shatterglass Prism. Together they demonstrate a shared terrain property, displacement-based relocation, defense-to-geometry conversion, and a finisher that changes the battlefield. The other five fill distinct Earth, Air, Ice and Lightning decisions rather than repeating those triggers for every element pair.

## 1. Stormcoal Crucible — `coalheart_crucible`

**Current identity:** a rare Fire-intensity spender. The earlier surface draft made it a capped card-play refund for consuming three Fire tiles. Replace that refund with the conductive-Fire rule.

**Proposed rule:** All Fire tiles in the encounter also conduct Lightning. They retain normal Fire entry/start damage and remain valid Detonate fuel. Fire and Electrified connect into one conductive route/component when cardinally adjacent. A normal damaging Lightning attack conducts through the connected component; Chain can instead use individual conductive tiles across its legal hop gaps. Conductive Fire actually used by either operation is consumed just like Electrified.

**Cost and consequence:** A lightning payoff burns away persistent Fire territory and its future Detonate opportunity. A component discharge can remove a large prepared field. Enemy Lightning can use that same field against the player and illusions. No Shock-on-entry effect, automatic detonation or additional damage packet is created when Fire is consumed electrically.

**Timing and limits:** No once-per-turn flag is needed: the terrain is the spent resource. Fire just placed by an earlier printed action is immediately conductive. Fire's own passive damage never starts conduction. Each core Lightning attack still deduplicates actors and large footprints.

**What it changes:** A Fire-heavy draft can value Lightning for connected-area payoff; a Lightning draft can use broad Fire painters to construct a network while creating real shared danger. The choice between Lightning and Detonate depends on the formation, not a higher off-board count.

**Name/art disposition:** Rename Coalheart Crucible to Stormcoal Crucible. Keep stable ID. Redesign the existing `assets/art/relics/coalheart_crucible.png` as a charred vessel with a legible lightning filament through glowing coals; avoid a generic Fire icon plus a generic Lightning icon pasted together. Rare is the initial review category; mixed setup and shared downside must be evaluated before rarity is finalized.

## 2. Updraft Bottle — `updraft_bottle`

**Current identity:** a rare Blink/intensity engine; the earlier draft awarded draw and Block after moving an enemy onto a hazard. Replace the resource proc with transporting terrain.

**Proposed rule:** When aiming a player Push or Pull, the player may choose to carry the elemental ground beneath that target to its final position. The target follows the normal forced-movement path first. After actual movement, translate the surviving starting elemental footprint by the target's actual displacement: remove it from the origin and place it beneath the final footprint. Rubble stays where it was.

**Cost and consequence:** This moves ground; it does not leave a copy or paint the whole path. Transport can clear a useful hazard behind the enemy or overwrite valuable Fire/Ice/Electrified at the destination. Existing path surfaces and traps resolve normally during movement. The newly transported ground applies no immediate occupant effect. Carrying Ice beneath a previously un-Chilled target therefore does not immediately Chill it; it waits for an eligible entry/start. Frozen is not cleansed by this relocation.

**Timing and limits:** No movement means no transport. Snapshot the initial ground, use only the displacement that actually resolves, and never resurrect a source surface that was consumed or replaced during the movement event. For a large actor, translate the actual starting elemental footprint once as a pattern; do not multiply it per occupied tile or apply contact damage a second time. No once limit is required because no terrain or card plays are created.

**What it changes:** Air can move a Lightning network's endpoint, shift a Fire zone into a threatened lane, or clear Ice from beneath a Chilled actor. The destination replacement is a meaningful choice. The normal Push/Pull mode remains available when carrying the ground would spoil the play.

**Name/art disposition:** Retain Updraft Bottle and stable ID. Review/redraw the bottle's contents as a clear contained spiral carrying small material fragments. The icon must communicate transport rather than a potion granting speed. Keep rare as the initial category.

## 3. Quarry Winch — `briar_winch`

**Current identity:** common extra forced distance against Poisoned enemies; the earlier surface draft changed that to extra distance against targets on Rubble. Replace the numerical extension with a new direction choice.

**Proposed rule:** When a Push/Pull target stands on Rubble, the player may consume the Rubble beneath it to choose any legal cardinal direction for that forced movement, including a sideways shift. Printed force distance and damage stay the same. Ordinary Push/Pull direction restrictions still apply when this option is not used.

**Cost and consequence:** Rubble is the anchor being spent. This sacrifices difficult terrain to place the enemy somewhere that normal closer/farther movement cannot reach. Consume the Rubble under a large target's occupied footprint once; its elemental ground remains. The redirected movement then applies ordinary traps, Fire contact, Ice entry and collision rules.

**Timing and limits:** Validate a legal actual displacement before spending terrain. The target cannot be moved through walls or actors by this relic. No extra movement action, copied hit, bonus card play or free direction change after the force has resolved. No once cap is needed; repeated redirects need fresh Rubble and paid force actions.

**What it changes:** An Earth setup lets Air and physical weapons solve a different positional puzzle: shift a blocker out of a lane, send a target sideways onto Ice, or align opponents for a Chain. It does not merely make every push longer.

**Name/art disposition:** Rename Briar Winch to Quarry Winch; keep `briar_winch`. Replace its artwork with a compact winch/cable gripping a fractured stone anchor. Start rarity review from common; the new directional freedom may warrant rare depending on live directional targeting and setup access.

## 4. Faultline Brooch — `thornmail_brooch`

**Current identity:** epic reactive damage whenever Stoneskin is gained. Replace repeated damage procs with a deliberate defense-spending attack mode.

**Proposed rule:** A player with enough Stoneskin may spend a fixed amount when aiming a single-target melee attack to reshape that attack into a cross centered on the legal primary target. The expanded attack uses the printed attack's damage and applicable direct-attack riders, hitting each eligible actor once. After the hit, create Rubble on the cross's legal floor tiles.

**Provisional price:** Start testing at **4 Stoneskin per expanded attack**. This is a tuning proposal, not an approved value. The attack still spends its normal card play, Time and printed health/Exhaust costs. It does not first grant compensating Stoneskin or Block.

**Cost and consequence:** The player trades durable protection for coverage and a changed route. Expanding a weak setup strike versus a heavy finisher is a real choice. The resulting Rubble can hinder the player's escape as well as enemy movement and can prepare a later Quarry Winch or Earth payoff.

**Timing and limits:** Spend the visible Stoneskin cost before the expanded hit; spending defense is never a Stoneskin-gain trigger. A Flurry repeat must pay its own price to expand, and can use the ordinary printed attack when the price is not paid. Do not add a second copy of the primary hit or expand already-area/Chain/Detonate actions recursively. No once-per-turn limit is needed if each expansion really spends defense.

**What it changes:** A defensive deck can draft melee attacks as board-shaping tools; a weapon deck can value Stoneskin as a choice between survival and area control. This is an Earth/physical bridge without making every defensive relic manufacture attack damage automatically.

**Name/art disposition:** Rename Thornmail Brooch to Faultline Brooch; keep `thornmail_brooch`. New art should show a stone brooch splitting along a deliberate cross-shaped fracture, with a distinct silhouette from shields and Rubble's board icon. Retain epic as the initial category.

## 5. Shatterglass Prism — `frost_prism`

**Current identity:** rare extra damage against Frozen enemies plus a kill draw. Replace both bonuses with a battlefield-changing finisher.

**Proposed rule:** When a player direct attack kills an enemy that was Frozen immediately before that hit, its occupied floor tiles and their four-neighbor outer edge become Rubble after the attack's death event resolves. Preserve any existing elemental layer on those tiles. The dead actor does not create an extra damage explosion.

**Cost and consequence:** This requires the genuine Ice setup → activation → freezing attack → finisher sequence. It gives up the earlier flat damage/draw bonuses. Frozen has already consumed its enabling Ice; the relic creates new Earth terrain from the finish instead of restoring that fuel.

**Timing and limits:** Use the attack's pre-hit Frozen state, including an explicitly authored Shatter attack that spends Frozen. Deduplicate footprint and edge tiles. Passive Fire kills do not trigger this direct-finisher relic. Resolve the attack's existing actors/deaths before painting Rubble; new death spawns are not hit by another implied explosion. No once cap is needed: each use requires another actual Frozen enemy death, and no plays, healing or direct damage are generated.

**What it changes:** The best target to finish is sometimes the body positioned at a chokepoint. Its shattered ground can slow surviving enemies, support Earth attacks or enable an Air redirection through Quarry Winch. Ice contributes something valuable even after its control target is gone.

**Name/art disposition:** Rename Frost Prism to Shatterglass Prism; retain `frost_prism`. Redraw or substantially refine the prism as an ice-blue fractured crystal falling into heavy stone-like shards. Keep rare as the initial category. Its material change should be readable without inventing a permanent fifth surface.

## 6. Rimecatcher Vial — `rimecatcher_vial`

**Current identity:** common Freeze/intensity feedback; the previous draft reduced it to Block on Freeze. Replace the stat proc with bounded relocation of setup.

**Proposed rule:** When a player attack successfully Freezes a target and consumes its supporting Ice, the player may redistribute **one** of those consumed Ice tiles onto one legal cardinal floor neighbor outside that target's footprint. All supporting Ice is still removed under the Frozen body. Choose the spill destination in the original aim preview.

**Cost and consequence:** This conserves at most one tile of spent setup in a new position; it never duplicates the source beneath the body or makes an outward wave. If a large target consumed several Ice tiles, all but the single redistributed tile remain gone. The chosen destination replaces its prior elemental layer, so preserving one Ice tile can cost Fire or a valuable Electrified route.

**Timing and limits:** The redistributed Ice is ordinary post-Freeze placement: no immediate Chill, damage or second Freeze. Frozen actors cannot activate it. Only a real successful Freeze and actual Ice consumption qualify; misses, immunity rejection, already-Frozen hits and repainting do not. No stored charge, carried tile inventory or once meter is created. If no legal adjacent destination exists, skip redistribution without blocking the original Freeze.

**What it changes:** A freeze creates a new nearby lane for a later Push/Pull or enemy turn-start exposure. The player chooses where the next Ice interaction can happen, rather than receiving another automatic defense reward.

**Name/art disposition:** Retain Rimecatcher Vial and stable ID. Existing vial artwork can be retained only if visual inspection makes the caught-and-spilled frost identity readable; otherwise repaint its contents and lip rather than inventing an unrelated silhouette. Keep common as the initial review category.

## 7. Worldroot Idol — `worldroot_idol`

**Current identity:** legendary Earth-deck defense/intensity engine; the earlier proposal became Stoneskin for ending movement on Rubble. Replace that incremental reward with attack-origin manipulation.

**Proposed rule:** While the player stands on Rubble, a single-target melee or ranged card attack may originate from a different visible tile in that same cardinally connected Rubble formation. Choose and consume that origin tile's Rubble, then resolve the attack's printed range and line of sight from there. The player does not move.

**Cost and consequence:** Each remote attack spends a piece of the structure and can disconnect later origins. The player also commits their actual position to difficult terrain. This grants neither vision nor a private route through walls. Both the origin and target must already be legally visible; the new origin cannot reveal hidden enemies or treat Rubble as transparent blocking geometry.

**Timing and limits:** Connectivity is validated before consuming the chosen origin. The printed attack retains ordinary target, damage, elemental and Chain rules; its initial range/line originates at the consumed tile. It is not an extra attack. Area attacks and Detonate do not acquire this mode. Separate Flurry repeats must each choose and spend a still-connected origin. No once-per-turn cap is required: the network itself collapses as it is used.

**What it changes:** Earth can build a casting/striking position in advance, and a melee card can become useful from an unexpected angle without becoming a generic long-range card. The choices are where to stand, which branch to spend first, and whether to preserve Rubble for movement control or other payoffs.

**Name/art disposition:** Retain Worldroot Idol and stable ID. Refine or replace its icon with a rooted stone effigy whose roots visibly connect separated stones, distinct from Rubble itself. Keep legendary as the initial category: the required positional network is demanding, while the changed attack geometry can define a run. This is the most implementation-intensive proposal and needs especially clear origin/target previews.

## 8. Basalt Kiln — `basalt_calendar`

**Current identity:** rare Earth-deck scaling; the earlier draft became a three-Rubble threshold for Stoneskin. Replace that board-count reward with an alternate consumption mode.

**Proposed rule:** A printed Detonate action gains an optional Crush mode that uses selected Rubble instead of selected Fire as its fuel. It consumes the selected Rubble, constructs the ordinary union of those tiles and their cardinal-neighbor blast areas, and resolves the printed direct Fire damage once per actor. After the blast, create Fire on the consumed Rubble tiles.

**Cost and consequence:** Earth control becomes fuel for Fire's attack geometry. The player loses difficult terrain and leaves shared dangerous ground afterward. Existing Fire on a selected Rubble tile is not a second blast or extra damage multiplier; fuel contributions still combine into one actor-deduplicated attack. Normal Fire-fuel Detonate remains available.

**Timing and limits:** Remove selected Rubble before the attack; paint Fire only after its damage/death resolution. Newly placed Fire does not immediately hurt its occupants or recursively detonate. It can be consumed by a deliberately later printed Detonate or Lightning action, as the shared rules already permit. Crush-mode damage has normal Detonate shared danger, including the player and illusions. No once cap or board threshold is needed; the card action and real Rubble are spent.

**What it changes:** An Earth-heavy deck can use a Fire payoff without first drafting a matching Fire painter. Choosing the mode determines what ground survives: normal Detonate spends Fire and keeps Rubble; Crush spends Rubble and leaves Fire. The decision is a terrain trade, not merely whether enough tiles exist.

**Name/art disposition:** Rename Basalt Calendar to Basalt Kiln; keep `basalt_calendar`. Replace calendar/dial imagery with a cracked miniature stone furnace containing a bright core. Keep rare as the initial category, but evaluate the alternate-fuel access and sequential Fire/Electrified synergies before assigning final offer weight.

## 9. Thunder Relay — `thunder_relay`

**Current identity:** epic Shock/intensity discharge. The earlier proposal added an extra Chain target; that is obsolete under the retained hop-reach meaning of Chain. Replace that duplicate extension with endpoint exchange.

**Proposed rule:** When aiming a Chain attack, the player may choose to exchange its first and last actual enemy targets after the complete attack resolves. The preview shows the full normal Chain route and both final positions. The exchange occurs only if those two distinct actors survive and both final footprints are legal.

**Cost and consequence:** The player must arrange a real Chain route that reaches both desired endpoints and spend its printed attack; consumed Electrified or conductive Fire stays consumed. Damage that kills one endpoint can intentionally or unexpectedly prevent the exchange, so preview the actual outcome rather than promising a swap independent of damage. The attack gains no additional targets, jump range or free card play.

**Timing and limits:** Swap the actors atomically, validating their complete footprints and explicit forced-movement immunities. Treat the relocation as forced Blink: no intermediate path contacts, but ordinary arrival effects and traps at each landing. Frozen remains Frozen and cannot acquire Chilled; other actors can activate destination Ice on arrival. This is not a Push/Pull action and does not silently invoke Updraft Bottle's ground-transport technique. No extra attack or recursive Chain follows the exchange. No once cap is necessary if each exchange requires another paid, legal Chain attack.

**What it changes:** A Chain can remove a front-line blocker, bring a distant enemy into reach, exchange a protected unit with one on dangerous ground, or set up the next attack's formation. It gives Lightning its own positional payoff instead of another damage, draw or target-count bonus.

**Name/art disposition:** Retain Thunder Relay and stable ID. Review/redraw as two connected copper relay terminals with a clearly crossing arc, distinct from Stormcoal Crucible and a generic lightning-bolt icon. Keep epic as the initial category; endpoint control and Chain targeting determinism need direct mechanical proof before numerical approval.

## Interaction and feasibility checks for the implementation design

These are acceptance cases for the proposed rules, not a request to expand scope:

1. **Fire → Lightning:** With Stormcoal, a damaging Lightning hit conducts across cardinally touching Fire/Electrified and consumes the component. A one-tile air gap stops ordinary conduction; printed Chain can bridge it within hop reach. Neither route causes an unprinted Detonate or passive Fire tick.
2. **Push carrying Ice onto Fire:** Resolve actual Fire contact on the destination as it existed at arrival, then transport surviving source Ice. The replaced Fire is gone; new Ice under the target is unactivated. Chilled cannot be manufactured retroactively by this transport.
3. **Rubble sideways redirect:** Quarry Winch consumes only the target's starting Rubble and preserves Fire/Ice/Electrified. Redirected force uses the real path. Walls and zero-distance outcomes do not spend Rubble for a nonexistent move.
4. **Spend Stoneskin → expand melee:** The cost is paid once per selected attack/repeat, never counted as a defense gain. Area recipients are unique actors; no duplicated primary hit or recursive expansion. Rubble arrives after the hit.
5. **Freeze → redistribute → shatter:** A real Freeze consumes Ice under the body; the Vial can place one tile outside it without activating anyone. A later direct Frozen kill creates the Prism's Rubble. The two relics do different work and do not regenerate a free repeated Freeze under the same actor.
6. **Remote strike → collapsing origin:** Worldroot validates a currently connected, visible origin, consumes it, then uses its location for that printed attack. Future attacks cannot keep using the consumed tile. Large actors and hidden targets retain the common footprint/visibility rules.
7. **Rubble → Crush → Fire → Lightning:** Basalt Kiln can turn a paid Earth setup into Fire; Stormcoal can then make that Fire useful to Lightning. Every transition consumes something or spends a printed action. No relic produces card plays or healing, and no terrain event alone recursively runs the whole sequence.
8. **Chain endpoint exchange:** Resolve the normal route and component consumption, then exchange the two surviving endpoints only when both footprints and movement rules allow it. Landing triggers are real entry; there is no mid-route contact or new Chain attack.
9. **Shared danger and source classification:** Friendly exposure, surface removal and replacement are in the preview. Passive hazards do not acquire attack riders; expanded/remote/Crush attacks remain the underlying printed attack with the correct direct-damage category. Relic terrain placement is not an extra hit, kill or card-play event.

## What should remain varied in the rest of the pool

Do not retrofit these mechanics onto every relic or create one for every ordered pair of elements. Preserve a substantial set of simpler weapon, defense, movement, health-cost, illusion and Radiance identities. Examples worth retaining or reviewing on their own merits include Iron Lung's health-cost/defense bridge, Coffin Nails' Block/Bleed interaction, Sunlit Edge's Light/Pierce relationship and ordinary attack or movement modifiers.

Some numerical relics are useful because they make an offer easy to understand and support a straightforward build. The problem was using damage/draw/Block as the default ending for almost every newly proposed elemental interaction. This shortlist supplies distinct changes in play while leaving room for those simpler relics.
