# Guardian rewards — third design pass

**Current reward proposal · 14 September 2026**

Every card keeps one target click or one confirmation. Relics never append a second targeting stage, a quantity slider, a route-drawing step, or a confirmation after the card has begun resolving. Effects derived from the target appear in the normal preview and commit with that original click.

| Relic | Current rule | Player input |
|---|---|---|
| Ashen Brand | Detonate spreads through the targeted Fire component; overlapping crosses increase damage. | The card's original target only. |
| Winter's Spur | A straight stretch of Ice costs one base movement step. | One Move destination; the normal path preview includes the discount. |
| Resonant Clapper | Each successive enemy hop of an existing Chain gains 25% of base damage. | The original Chain target only. |
| Galehook Talon | Push/Pull carries the contiguous enemy line along its force axis. | The original forced-movement target only. |
| Cragbound Gauntlet | A separate command converts stored Stoneskin into cover; surviving cover can be reclaimed. | Independent utility actions, each with one target. Cards gain Stoneskin normally. |
| Procession Lantern | Existing Illusions can spend your independent movement, including through darkness. | Select the Illusion, then a Move destination, as for moving your character. |

## Ashen Brand

**Detonate consumes the entire cardinally connected component of Fire containing its normal target. Each consumed tile contributes the ordinary cross. An actor covered by several crosses takes one combined hit, adding 25% of base Detonate damage per extra overlap.**

There is no cluster-selection mode. The player shapes the result by painting and breaking connections before using the card, then chooses the normal Detonate target. A long Fire route spreads the blast; a dense patch concentrates damage. A base-4 Detonate deals 4, 6, or 8 with one, three, or five overlapping crosses. Round the combined hit once, halves up. Large footprints use the greatest overlap at a single occupied cell.

All affected Fire and the full shared blast are shown before commit, including self-danger. This is an explicit persistent change to Detonate's rules and card preview, not a hidden optional effect or a modal toggle. The relic supplies neither Fire nor Detonate. It does not reveal hidden enemies, count conductive Fire relay use as Detonate, or turn overlapping crosses into repeated damage events.

## Winter's Spur

**During your voluntary Move, enter a straight run of Ice for one base movement step and continue straight along that Ice without further base step cost. Turning, reversing, leaving Ice, or starting another Move begins normal charging again.**

Pick one destination. The existing path preview shows the exact route and movement cost. There is no extra choice of where to begin skating or which intermediate tiles to visit. Pathfinding uses the new movement prices with a stable tie-break and the game's normal hazard presentation; it never silently chooses a different route at commit.

Three straight Ice steps cost one base step; six also cost one. Two connected straight segments with a bend cost two. The change applies to movement budget, so a printed Move allowance can cover more physical distance along a prepared route. It does not add a second destination to a card or override another action's fixed target binding.

Every cell is still traversed. Rubble surcharges, obstruction, surface contact, traps and Chill remain. Forced movement and Blink are unchanged. The discount belongs to movement of the relic-owning player, not to an Illusion moved by Procession Lantern.

## Resonant Clapper

**An existing Chain attack gains 25% of its base direct damage for each successive distinct enemy hop.**

Keep the original target selection and the game's deterministic route. Show the ordered damage in its normal preview. A base-4 Chain deals **4 → 5 → 6 → 7** across four enemies, for 22 instead of 16. There is no additional click to choose the route or a final victim.

Printed Chain remains hop reach. Empty conductor relays help reach more enemies but do not advance the damage step; conduction-only victims do not advance it or inherit the bonus. Preserve one hit per enemy across native Chain and conduction. Multiple native heads each start at zero; resolve the ordinary route ownership/deduplication before calculating each victim's single hit. No free Chain, stored charge, or unrelated secondary bonus is added.

## Galehook Talon

**A Push or Pull automatically carries the maximal contiguous collinear group of enemies containing its original target, along the original force axis.**

The original target determines the axis, direction, and group. There is no group-selection toggle or extra confirmation. Preview every member's path and landing as part of the original card. To change the formation moved, change your position, the enemy arrangement, or the original target before committing.

All included enemies translate by the printed force distance, one group step at a time, and stop together when any full footprint would hit an outside obstruction. Do not include the player, an Illusion, or a non-enemy object. The original damage still affects only its original targets; the relic adds no collision damage or force distance.

After a complete group step, resolve normal contacts and traps in a stable order. If a trap independently displaces a member, or a death breaks the contiguous line, stop remaining group travel. Show that interruption in the preview. Push 2 can move one enemy two steps, or a prepared row of three enemies six total enemy-steps.

## Cragbound Gauntlet

**Keep cover, but make it a separate use of stored armor and independent movement. It does not alter a card's targeting or resolution.**

**Raise Cover:** select this utility command, then one legal empty tile within range 2. Spend 1 independent Move and convert **all current Stoneskin** into a destructible cover piece with that much HP. Require at least 1 Stoneskin and 1 Move. There is no amount selection and no request to aim cover after an attack card.

**Reclaim Cover:** select the command, then one adjacent cover piece you own. Spend 1 independent Move, remove the piece, and regain its surviving HP as Stoneskin. Reclaiming does not create Rubble or another placement opportunity. Destroyed cover leaves normal Rubble and the lost armor is gone.

A card that attacks and grants 6 Stoneskin still uses its original single target and finishes normally. On a later independent action, the player can keep that armor or spend it on a 6-HP wall. If some Stoneskin has already been lost, the same command makes a weaker wall. The decision moves to timing, location, and whether to spend movement on defense or escape. Repeated use is bounded by the actual armor and movement available.

This adds a useful command to the existing contextual utility/action language, with distinct Raise Cover and Reclaim Cover icons. It does not add a persistent rules panel, a new card, a slider, or a prompt after every Stoneskin gain. Each utility action has the familiar selection → one target commit flow. Existing pointer and focus/activation/cancel paths must all reach it in the implementation.

Cover blocks movement and sight, obeys ordinary terrain placement, and can be attacked. No placement under actors or special arena objects. Enemies must be able to break weak cover when it obstructs their route. That AI work remains part of implementation. Keep owner and remaining HP across saves; never refund destroyed HP. Raised cover is visually distinct from the Craghide's jagged quake outcrops.

## Procession Lantern

**Select one of your existing Illusions and move it using your shared independent Move allowance. It can move through darkness.**

The interaction mirrors selecting and moving the player: select the Illusion, preview a legal route, click the destination. Both use the same remaining movement pool. A player with 2 Move can spend both on themselves, split one step each, or spend both moving the decoy. Cards keep their existing target and action bindings; a printed Move action is not redirected to the Illusion by this relic.

Remove the requirement for illuminated path cells. Darkness does not make a known legal tile ineligible for this command. Normal board movement, occupancy, footprint, hazards and costs apply; the decoy gets no free health or Light. Existing visibility boundaries still protect hidden enemies and unknown occupancy from preview leaks. Moving an unlit decoy does not grant vision or make a hidden enemy targetable.

Moving a decoy changes future enemy target decisions under the existing closer-Illusion rule. It does not rewrite an already committed attack lane. Position it to draw enemies away from you, gather them near Fire, or interrupt a useful approach, at the cost of your own movement. An existing Light-emitting relic on an Illusion remains useful but is not required.

## Interaction acceptance for the next implementation pass

- Select each modified card and resolve it with the same one target/confirmation as before. Verify mixed attack + Stoneskin, Move + attack, Chain, Detonate, and Push/Pull cards.
- No mid-card modal, post-hit target request, resource-allocation slider, route drawing, per-card relic toggle, or second target state may appear.
- Preview the automatic Fire component, complete Chain route, automatic force group, and chosen Move route before the original commit. Preview and commit must agree under the same state.
- Selecting an Illusion changes the movement actor, not the card target model. Move cost is shared and darkness is legal under ordinary board constraints.
- Raise/Reclaim are independent commands, each with one target and a visible cost. An invalid or cancelled action consumes nothing; no card pauses while waiting for these commands.
- Present exact rules in relic/card inspection and compact current costs in contextual action controls. Reuse existing selection/focus/cancel feedback and avoid extra persistent UI. Real-renderer and input proof belongs to the implementation pass.

The v2 combat compositions, guardian identities, optional map placement, and midpoint landmark sizes remain the encounter proposal. This file supersedes every earlier reward description and input rule.
