# Guardians of the Six Dragons — third design pass

**14 September 2026 · Current encounter proposal, revised one-click rewards, and concrete source art**

This is the current review proposal. Every card retains its original single target or confirmation. Cragbound cover is a separate utility action; Procession Illusions can move through darkness using the shared independent movement pool. The Ashen Reaver now wears a closed iron helmet and uses simpler pixel clusters. The front/rear paint has undergone a separate anatomy and scale pass.

Start with the [visual review](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/README.md), or read the complete encounter and reward plan below. The [reward input contract](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/REWARDS.md) collects the exact revised interaction rules.

The game is unchanged. These are proposed encounters and staged static assets. Animation rigging, gameplay integration, balance testing and real-renderer proof belong to the next pass after visual alignment. Numbers below are prototype starting points, not measured balance results.

## The revised roster

| Element / dragon | Guardian and supporting threats | The choice the fight creates | Guaranteed relic |
|---|---|---|---|
| Fire / Vyraketh | **Ashen Reaver + two Ash Hounds** | Clear a flank, or exploit the Reaver's recovery while the hounds remain dangerous? | **Ashen Brand:** shape connected Fire into a larger, denser Detonate |
| Ice / Iskaldra | **Rimejaw + Rime Whelp + Rime Spitter** | Stop the Ice painter, clear the dry approach, or punish the predator's missed pounce? | **Winter's Spur:** skate along prepared Ice routes |
| Lightning / Zekarion | **Storm Cantor + Lightning Wisp + Bell Tender** | Remove the permanent circuit builder, suppress the returning wisp, or rush the Cantor? | **Resonant Clapper:** damage increases with successive enemy hops in an existing Chain |
| Air / Vaeloryx | **Gallows Roc + two Fledglings** | Open an escape side before the pull, or accept their attacks to stay on the Roc? | **Galehook Talon:** Push or Pull a line of enemies together |
| Earth / Tharokh | **Craghide + two Stoneback Mites** | Break a threatening outcrop, kill a blocker, or reach the beast before the quake? | **Cragbound Gauntlet:** convert stored Stoneskin into recoverable cover with a separate action |
| Shadow / Noctyrax | **Last Lamplighter + one or two Wick Shades** | Spend attacks clearing a dark approach, wait for its light to return, or pursue the guardian? | **Procession Lantern:** spend independent movement to reposition Illusions, including through darkness |

Keep **Guardian combat** as the working category. Standard combat remains ordinary encounters; **Dangerous combat** remains the reserved name for harder ordinary-enemy compositions. Each dragon section offers one optional Guardian combat. Dragons remain the section finales.

## What makes the supporting threats matter

Every fight begins with multiple threats. Most begin with the guardian and two weaker enemies; the Lamplighter begins with one shade and can bring out a second. Their positions and clocks must create different choices. Two enemies stacked beside the guardian and caught by every attack would not achieve the intended effect.

**Finite helpers:** Ash Hounds, Rime Whelp, Rime Spitter, Bell Tender, Fledglings, and Stoneback Mites never return. Killing one permanently removes its pressure. Their active-action kills use the ordinary non-summoned kill rule: +1 card play when eligible. This makes a well-timed kill useful without erasing the card, damage, movement, and Time spent reaching it.

**Renewable helpers:** the Cantor's wisp and all Wick Shades are reinforcement actors from their first appearance. They grant no kill card play and no Embers. Replacement uses a revealed guardian intent, a legal visible spawn marker when observable, and the normal clock; nothing attacks immediately on arrival. No fight has more than two living helpers. Spawn failure does not add an attack or bank a later double summon.

**Guardian defeat ends the encounter.** Surviving helpers flee, collapse, or fade. Their departure grants no additional kill rewards. This gives focus fire a concrete payoff and avoids cleanup after the central threat is dead. The exclusive relic and encounter payout are granted once, through the victory flow. All guardian helpers have zero Ember payout; the current summoned flag alone is not assumed to enforce that.

Add HP should generally put them within one substantial attack, or two light attacks, for the section. They need clear movement and attack poses, separate intent portraits, and small readable silhouettes. Stationary attackers still occupy board cells and use ordinary enemy damage/status rules; lack of voluntary movement does not make them immune to displacement or Freeze.

## 1. Fire — The Ashen Reaver

**Guardian of Vyraketh · Arena: The Cinder Yard**

![ashen reaver front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/ashen_reaver_front.png) ![ashen reaver rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/ashen_reaver_rear.png)

### Presentation

A grounded dragon-cult enforcer in a closed angular iron helmet, with a low black visor, one jagged shoulder, broad blackened plate and a heavy hooked blade with a dull hot edge. His face and arms are covered. The armor uses simple material planes and chunky pixels; fine realistic skin, chainmail noise and ornate straps are removed. Fire is concentrated along the blade and the ground he cuts. A short red waist cloth carries the allegiance.

The Ash Hounds are lean living canids with singed coarse fur, long jaws, and low flanking postures. Their compact silhouettes should read as faster and more fragile than the Reaver. The new front/rear paint establishes the simplified board-art direction.

### Combat

Two staggered pillars divide a broad central aisle from side approaches. Hounds start on opposite sides, away from the entry halo. The player should be able to remove one and claim that side, while leaving both alive makes simply circling the Reaver less comfortable.

| Reaver intent | Proposed action | Counterplay |
|---|---|---|
| **Raking Flame** · Time 4 | Place Fire on three declared tiles forming a broken lane. No placement damage or free defensive gain. | Choose the gap, replace Fire, or prepare to force an enemy through it. |
| **Hooked Sweep** · Time 5 | Move up to 1 on the declared approach; a short frontal sweep deals 7 and Pushes 1. | Account for the landing tile and the hound threatening that side. |
| **Executioner's Fall** · Time 7 | A stationary three-tile lane attack deals 9. After an attempted strike, the Reaver gains Expose 3. | Leave the lane and use the recovery. Spending that opportunity on a hound remains a real alternative. |

**Ash Hounds:** two, 5 base HP each. Alternate a 2-tile approach and 3-damage bite with a 3-tile circling move. Their approach preferences favor different flanks, subject to actual legal paths. They neither paint Fire nor summon replacements. Their attacks can punish the refuge beside a major telegraph, but their clocks are staggered so every escape cannot become an unavoidable combined hit.

**Example decision:** the Reaver declares his center lane. Moving left avoids him but enters Hound A's next bite; moving right requires crossing Fire. Killing A first opens a lasting dry flank. Staying close and defending the bite may instead let a burst deck exploit Expose and finish the Reaver.

![Fire encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/fire.png)

### Reward — Ashen Brand

![Ashen Brand icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/ashen_brand.png)

**Detonate consumes the entire cardinally connected component of Fire containing its normal target. Each consumed tile contributes the ordinary cross. An actor covered by several crosses takes one combined hit, adding 25% of base Detonate damage per extra overlap.**

There is no cluster-selection mode. The player shapes the result by painting and breaking connections before using the card, then chooses the normal Detonate target. A long Fire route spreads the blast; a dense patch concentrates damage. A base-4 Detonate deals 4, 6, or 8 with one, three, or five overlapping crosses. Round the combined hit once, halves up. Large footprints use the greatest overlap at a single occupied cell.

All affected Fire and the full shared blast are shown before commit, including self-danger. This is an explicit persistent change to Detonate's rules and card preview, not a hidden optional effect or a modal toggle. The relic supplies neither Fire nor Detonate. It does not reveal hidden enemies, count conductive Fire relay use as Detonate, or turn overlapping crosses into repeated damage events.

## 2. Ice — The Rimejaw

**Guardian of Iskaldra · Arena: The Rime Kennel · Main character design retained**

![rimejaw front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/rimejaw_front.png) ![rimejaw rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/rimejaw_rear.png)

The eyeless skull, long ice tusks, swept-back horns, dark exposed muscle, and low stalking silhouette stay. Winter's Spur remains the reward, now using the original Move destination only.

### Combat

A broken crescent of cover leaves two dry crossings. A **Rime Whelp** starts near one crossing; a **Rime Spitter** covers the other from farther away. The whelp is a smaller, narrow-headed member of the predator's family. The spitter is a squat pale cave reptile with an ice-crusted back and a throat that visibly swells before firing a needle.

| Rimejaw intent | Proposed action | Counterplay |
|---|---|---|
| **Rime Trail** · Time 4 | Retreat up to 2 on a declared route, leaving Ice on vacated cells. | Preserve a dry crossing or use the Ice for your own attack setup. |
| **Harrowing Pounce** · Time 6 | Move up to 3 along a declared approach; make a 7-damage Ice melee attack, then place Ice at the struck tile. | Step aside; account for existing Chill before deciding to absorb the hit. |
| **Frostbite** · Time 5 | A stationary 6-damage Ice melee attack. | Leave its reach or remove supporting Ice before an Ice hit can Freeze you. |

**Rime Whelp:** 6 HP; move up to 2 and bite for 3 physical damage, alternating with a short reposition. It contests the dry approach without adding another Freeze source.

**Rime Spitter:** 5 HP; no voluntary movement. Alternate a declared 3-tile needle line dealing 2 physical damage and placing Ice on its final tile with a recovery intent. The needle itself is physical: it prepares the Rimejaw's Freeze threat. Killing the spitter stops new Ice from that angle; existing Ice stays. Displacing it changes where its future lines can originate.

**Example decision:** kill the spitter for long-term control of the dry floor, clear the whelp for immediate access, or dodge the pounce and spend the opening on Rimejaw. The spitter's value is the lane it corrupts, not its 2 damage.

Ice placement never immediately Chills. Actual entry or an eligible actor start establishes Chill; a later Ice hit may Freeze and consume supporting Ice. Pounce can Freeze a target that was already Chilled. These are shared rules for the guardian and helpers too.

![Ice encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/ice.png)

### Reward — Winter's Spur

![Winter's Spur icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/winters_spur.png)

**During your voluntary Move, enter a straight run of Ice for one base movement step and continue straight along that Ice without further base step cost. Turning, reversing, leaving Ice, or starting another Move begins normal charging again.**

Pick one destination. The existing path preview shows the exact route and movement cost. There is no extra choice of where to begin skating or which intermediate tiles to visit. Pathfinding uses the new movement prices with a stable tie-break and the game's normal hazard presentation; it never silently chooses a different route at commit.

Three straight Ice steps cost one base step; six also cost one. Two connected straight segments with a bend cost two. The change applies to movement budget, so a printed Move allowance can cover more physical distance along a prepared route. It does not add a second destination to a card or override another action's fixed target binding.

Every cell is still traversed. Rubble surcharges, obstruction, surface contact, traps and Chill remain. Forced movement and Blink are unchanged. The discount belongs to movement of the relic-owning player, not to an Illusion moved by Procession Lantern.

## 3. Lightning — The Storm Cantor

**Guardian of Zekarion · Arena: The Broken Choir · Main character design retained**

![storm cantor front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/storm_cantor_front.png) ![storm cantor rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/storm_cantor_rear.png)

Keep the narrow iron-ribbed spear-priest, suspended cracked bell, forked helm, and indigo wrappings. A **Bell Tender** is a short, hunched attendant with a small bronze face mask and a forked striking staff. A **Lightning Wisp** uses the existing creature identity.

### Combat

Two sparse Electrified runs approach a central gap. The Bell Tender can create one connector; the Cantor can create the larger pattern. The mobile wisp pressures dry space. Remove the Tender for a permanent reduction in circuit construction, or kill the faster wisp to buy time even though it can return.

| Cantor intent | Proposed action | Counterplay |
|---|---|---|
| **Lay the Choir** · Time 4 | Place up to three declared Electrified tiles. | Leave the network or replace a connector. |
| **Peal** · Time 6 | A 6-damage Lightning impact into a declared legal conductor within range 3; normal conduction, with Shock 1 only on a conducted hit. | Break or leave the component while respecting the wisp's nearby attack. |
| **Broken Rhythm** · Time 5 | Move up to 1 and make a 7-damage spear attack at range 2. | Close, reposition an enemy, or use the network yourself. |
| **Call the Spark** · Time 6 | If the wisp is absent, summon one on the declared legal cell. If it survives, the Cantor spends this beat tending its bell. | Killing the wisp early buys the longest respite; attacking the Cantor exploits this non-attacking beat. |

**Lightning Wisp:** existing 6-HP enemy, marked as a reinforcement from the start. Existing intent damage and movement remain the reference, including its fast base-7 + Time-4 cadence. No replacement before the dedicated Call slot, and never more than one living wisp.

**Bell Tender:** 5 HP; no voluntary movement. Alternate placing one declared Electrified connector within range 2 with a narrow 3-damage physical staff-bolt within range 3. No summon or rebuild. Its placement cannot create an unpreviewed same-instant discharge. Both it and the wisp can be used as ordinary enemy Chain targets by the player.

**Example decision:** the player can step from the charged center toward the wisp's reach, attack the Tender to stop it repairing a connector, or break that connector with a surface card and reserve damage for the Cantor. Conductors remain useful after enemies die, so removing an actor does not automatically erase the circuit.

![Lightning encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/lightning.png)

### Reward — Resonant Clapper

![Resonant Clapper icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/resonant_clapper.png)

**An existing Chain attack gains 25% of its base direct damage for each successive distinct enemy hop.**

Keep the original target selection and the game's deterministic route. Show the ordered damage in its normal preview. A base-4 Chain deals **4 → 5 → 6 → 7** across four enemies, for 22 instead of 16. There is no additional click to choose the route or a final victim.

Printed Chain remains hop reach. Empty conductor relays help reach more enemies but do not advance the damage step; conduction-only victims do not advance it or inherit the bonus. Preserve one hit per enemy across native Chain and conduction. Multiple native heads each start at zero; resolve the ordinary route ownership/deduplication before calculating each victim's single hit. No free Chain, stored charge, or unrelated secondary bonus is added.

## 4. Air — The Gallows Roc

**Guardian of Vaeloryx · Arena: The Hanging Roost · Main character design retained**

![gallows roc front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/gallows_roc_front.png) ![gallows roc rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/gallows_roc_rear.png)

Keep the bone beak, slate blade-wings, perching posture, and hanging streamers. The two **Fledglings** have compact bodies, blunt shorter wings, and sharp hopping silhouettes; their footprint remains on the board even during a wingbeat animation.

### Combat

Staggered cover and two visible Air traps make displacement matter. A Fledgling covers each side of the central pull lane. Killing one creates a lasting escape side; keeping both alive makes a pull dangerous even when it misses a trap.

| Roc intent | Proposed action | Counterplay |
|---|---|---|
| **Hookwind** · Time 4 | A declared line within range 4 deals 3 and Pulls 2 toward the Roc. | Break the line or choose a position whose landing avoids the next fledgling attack. |
| **Razor Pinion** · Time 5 | A short frontal sweep deals 7 and Pushes 2. | Leave its arc; read trap and helper threats at the landing. |
| **Grave Dive** · Time 7 | Move up to 3 on the declared approach; melee 8 and Bleed 1. | Sidestep the committed approach; consider Bleed before spending later movement and attack actions. |

**Fledglings:** two, 5 HP each. Alternate a 2-tile circling move with a 1-tile approach and 3-damage peck. They start on opposite flanks and have different initial clock slots. No summoning, immunity while airborne, or free off-clock reaction attacks.

**Example decision:** remove the left Fledgling, then leave the Roc's sweep to that side; push the right Fledgling onto a trap; or tolerate a peck to keep attacks on the Roc. Their threat origins should pull the player in different directions rather than simply add damage to the Roc's marked cells.

Use existing trap activation and forced-movement rules. No collision damage or Air surface is added. Preview displacement step by step, including each hazard landing and possible trap cascade.

![Air encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/air.png)

### Reward — Galehook Talon

![Galehook Talon icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/galehook_talon.png)

**A Push or Pull automatically carries the maximal contiguous collinear group of enemies containing its original target, along the original force axis.**

The original target determines the axis, direction, and group. There is no group-selection toggle or extra confirmation. Preview every member's path and landing as part of the original card. To change the formation moved, change your position, the enemy arrangement, or the original target before committing.

All included enemies translate by the printed force distance, one group step at a time, and stop together when any full footprint would hit an outside obstruction. Do not include the player, an Illusion, or a non-enemy object. The original damage still affects only its original targets; the relic adds no collision damage or force distance.

After a complete group step, resolve normal contacts and traps in a stable order. If a trap independently displaces a member, or a death breaks the contiguous line, stop remaining group travel. Show that interruption in the preview. Push 2 can move one enemy two steps, or a prepared row of three enemies six total enemy-steps.

## 5. Earth — The Craghide

**Guardian of Tharokh · Arena: The Shattered Burrow**

![craghide front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/craghide_front.png) ![craghide rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/craghide_rear.png)

### Presentation

A savage burrowing animal with a wedge head, short chipped tusks, massive forequarters, and huge digging claws. Its living hide carries coarse fur and naturally mineral-encrusted scutes. Weight, anatomy, scars, and dirty ivory claws make it threatening. Its shoulders and short neck distinguish it from Rimejaw's long, low predatory shape.

Stoneback Mites are small six-legged cave beetles with flint-colored overlapping shells and biting mandibles. Their low, broad shapes read as blockers without requiring a large health pool.

### Combat

Two permanent pillars and wide side gaps leave room for the Craghide to claw up breakable outcrops. Mites occupy different approaches. An outcrop is a danger source before a quake; a killed mite leaves Rubble that can still slow the newly opened route.

| Craghide intent | Proposed action | Counterplay |
|---|---|---|
| **Upheaval** · Time 4 | Raise up to two declared jagged outcrops, 3 HP each, on legal empty floor. At most two of its outcrops exist. | Break one early, go around it, or position a mite beside it. |
| **Groundsplit** · Time 6 | Deal 7 to opposing actors on the cardinal neighbors of its surviving outcrops. An actor caught by both is hit once. | Destroying an outcrop removes that portion of the telegraph; walk beyond the remaining one. |
| **Crushing Rush** · Time 6 | Move up to 2 on the declared approach; melee 8 with Sunder 1. | Leave the approach or interrupt/reposition the beast; do not rely only on stored defense. |

**Stoneback Mites:** two, 6 HP each. Alternate moving up to 1 and biting for 3 with a short bracing intent granting 2 Block. On death, each leaves ordinary Rubble on its tile. They do not return. Their Block does not persist indefinitely or replenish the Craghide's defenses.

**Example decision:** break a 3-HP outcrop to remove quake coverage, kill a 6-HP mite to open a route that now costs more Move because of Rubble, or take the long clear flank and preserve attacks for the Craghide. Rubble left by the encounter remains a usable player resource.

Upheaval has no HP damage and cannot raise terrain under an actor or seal every legal route. Existing outcrops are never refreshed for free. Groundsplit is scoped to this guardian's surviving outcrops; it does not turn every player-created cover piece into an enemy attack source. Destroyed outcrops leave normal Rubble and are eligible to be replaced on the next Upheaval slot.

![Earth encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/earth.png)

### Reward — Cragbound Gauntlet

![Cragbound Gauntlet icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/cragbound_gauntlet.png)

**Keep cover, but make it a separate use of stored armor and independent movement. It does not alter a card's targeting or resolution.**

**Raise Cover:** select this utility command, then one legal empty tile within range 2. Spend 1 independent Move and convert **all current Stoneskin** into a destructible cover piece with that much HP. Require at least 1 Stoneskin and 1 Move. There is no amount selection and no request to aim cover after an attack card.

**Reclaim Cover:** select the command, then one adjacent cover piece you own. Spend 1 independent Move, remove the piece, and regain its surviving HP as Stoneskin. Reclaiming does not create Rubble or another placement opportunity. Destroyed cover leaves normal Rubble and the lost armor is gone.

A card that attacks and grants 6 Stoneskin still uses its original single target and finishes normally. On a later independent action, the player can keep that armor or spend it on a 6-HP wall. If some Stoneskin has already been lost, the same command makes a weaker wall. The decision moves to timing, location, and whether to spend movement on defense or escape. Repeated use is bounded by the actual armor and movement available.

This adds a useful command to the existing contextual utility/action language, with distinct Raise Cover and Reclaim Cover icons. It does not add a persistent rules panel, a new card, a slider, or a prompt after every Stoneskin gain. Each utility action has the familiar selection → one target commit flow. Existing pointer and focus/activation/cancel paths must all reach it in the implementation.

Cover blocks movement and sight, obeys ordinary terrain placement, and can be attacked. No placement under actors or special arena objects. Enemies must be able to break weak cover when it obstructs their route. That AI work remains part of implementation. Keep owner and remaining HP across saves; never refund destroyed HP. Raised cover is visually distinct from the Craghide's jagged quake outcrops.

## 6. Shadow — The Last Lamplighter

**Guardian of Noctyrax · Arena: The Last Watch · Main character design retained**

![last lamplighter front](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/last_lamplighter_front.png) ![last lamplighter rear](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/units/last_lamplighter_rear.png)

Keep the long bent silhouette, pale cracked mask, shutter-like shoulders, hollow torso, and low lantern. **Wick Shades** are short, ragged humanoid shadows with thin limbs and a dim wick-like face. They are clearly smaller than the Lamplighter and have ordinary board footprints.

### Combat

Two arena braziers light separate approaches around broken cover. One shade is present at entry. The Lamplighter temporarily snuffs one brazier and brings a second shade from that side. The other brazier remains lit; player-created Illuminate remains fully useful.

| Lamplighter intent | Proposed action | Counterplay |
|---|---|---|
| **Snuff** · Time 4 | Extinguish one declared arena brazier until the end of Last Procession; summon one shade if fewer than two exist. | Move before the refuge closes, clear its occupant, or create your own Light. |
| **Mourning Hook** · Time 5 | A declared line within range 3 deals 4 and Pulls 1 toward the Lamplighter. | Choose a landing that avoids the shade's next attack and preserves useful sight. |
| **Last Procession** · Time 7 | Move up to 2 on the declared approach; melee 8. Then restore the snuffed brazier and dissolve any shades linked to that outage. | Wait out that shade pressure or kill it to take the approach sooner. Attack the guardian during its approach/recovery. |

**Wick Shades:** 4 HP, move up to 2 and melee 2, alternating with a short drifting reposition. The initial shade is persistent until killed or the guardian dies. A summoned shade is linked to that specific brazier outage and fades when the brazier restores. All shades, including the initial one, use the reinforcement reward policy. Cap two alive, including any initial survivor.

Snuff's duration is tied to the loop slot completing: the light still restores and linked shades still fade if Freeze or Shock suppresses Last Procession's attack. Preventing an attack must not accidentally extend the darkness. Player-created Light reveals the ordinary dark cells but does not automatically kill shades or count as relighting the arena brazier.

**Example decision:** kill the temporary shade to reach the Lamplighter now, defend and wait for it to dissolve, or use Light and move around it. The persistent shade is the better long-term kill; the temporary shade may block the more valuable immediate route.

Visibility remains authoritative. Hidden enemies are not directly targetable; their exact identity, clock entry, or intent is not revealed through a design-only helper overlay. Surface glow is not Illuminate. The diagrams show the designer's board state and are not a proposal to expose unseen enemies in play.

![Shadow encounter decision sketch](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v2/diagrams/shadow.png)

### Reward — Procession Lantern

![Procession Lantern icon](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/relics/procession_lantern.png)

**Select one of your existing Illusions and move it using your shared independent Move allowance. It can move through darkness.**

The interaction mirrors selecting and moving the player: select the Illusion, preview a legal route, click the destination. Both use the same remaining movement pool. A player with 2 Move can spend both on themselves, split one step each, or spend both moving the decoy. Cards keep their existing target and action bindings; a printed Move action is not redirected to the Illusion by this relic.

Remove the requirement for illuminated path cells. Darkness does not make a known legal tile ineligible for this command. Normal board movement, occupancy, footprint, hazards and costs apply; the decoy gets no free health or Light. Existing visibility boundaries still protect hidden enemies and unknown occupancy from preview leaks. Moving an unlit decoy does not grant vision or make a hidden enemy targetable.

Moving a decoy changes future enemy target decisions under the existing closer-Illusion rule. It does not rewrite an already committed attack lane. Position it to draw enemies away from you, gather them near Fire, or interrupt a useful approach, at the cost of your own movement. An existing Light-emitting relic on an Illusion remains useful but is not required.

## Map presentation — retained direction

Use the guardian's own head or face in a small version of the dragon-style medallion. A shared bronze frame with three angular buttresses identifies the family. The individual portrait supplies identity. Approximate future-node diameter remains **Standard 1.0× · Guardian 1.45× · Dragon 3.0×**. The dragon is still the dominant landmark.

| Guardian | Portrait cue at map scale |
|---|---|
| Ashen Reaver | Closed angular helmet, low black visor, jagged shoulder edge; ember accent |
| Rimejaw | Eyeless long skull and twin downward ice tusks |
| Storm Cantor | Forked helm and narrow bell/visor opening |
| Gallows Roc | Hooked bone beak and swept feather crest |
| Craghide | Broad snarling face, short tusks, heavy brow and flint ridge |
| Last Lamplighter | Pale slit mask inside an asymmetric dark hood |

The generic guardian category icon can retain the sentinel faceplate in the legend. It does not replace the unique portrait on a named node. Distinction relies on shape, frame, and scale as well as color. Standard availability/current/focus/visited treatments still apply; being visible through fog does not make a distant guardian immediately selectable for travel.

![Six concrete guardian emblems and proposed landmark scale](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/review/map_emblems.png)

Map tooltips use a short effect summary. Expanding the relic exposes the automatic target-derived group and exact movement rules. An encounter preview also lists the helpers and states whether they return, so the route decision includes the real composition.

**Placement remains proposed as before:** one per relevant section, visible from that section's entry, replacing an ordinary combat on an optional branch. Both approach and bypass must be viable. Preserve the 66-room / 40-fight full-run budget and existing section budgets. Target the middle of the section, after at least two ordinary combats and with at least two non-boss visits afterward. The final guardian also needs at least two subsequent fights, including Noctyrax, to give its reward useful remaining play.

The first five guardian/dragon pairs follow the existing shuffled elemental section order; Shadow remains last. The exact relic can be inspected before route commitment. Its value may be high or low for the current deck; that information is part of the optional risk decision. It is not randomly replaced by another trophy at victory, and these exclusive relics do not enter ordinary reward pools.

The earlier corridor-reveal idea remains an **unsettled proposal**: reveal enough approach/bypass topology to act on the landmark while keeping unknown room identities hidden. This pass does not treat that fog exception as approved. The map image illustrates the emblem and preview direction, not a validated generated route.

## Difficulty: budget the whole fight

Reduce the main enemy's HP from the solo draft, then account for helper attacks, movement pressure, and setup turns. Adding two enemies on top of the old solo budget would risk making these disproportionately punishing.

| Encounter | Guardian base HP | Helper base HP | Opening enemy HP / living maximum | Guardian base initiative |
|---|---:|---|---|---:|
| Reaver | 40 | 5 + 5 | 50 / 50 | 10 |
| Rimejaw | 38 | 6 + 5 | 49 / 49 | 10 |
| Cantor | 38 | 6 + 5 | 49 / 49; wisp can return | 11 |
| Roc | 36 | 5 + 5 | 46 / 46 | 9 |
| Craghide | 44 | 6 + 6 | 56 / 56, plus up to 6 terrain HP | 12 |
| Lamplighter | 44 | 4 initially; up to 4 + 4 | 48 / 52; temporary shades can return | 10 |

These are raw design values before existing local-depth and section scaling. They exclude future damage prevention and cumulative replacement HP. Use the current HP formula, `ceil(ceil(base × local_factor) × (1 + 0.08 × section_index))`, and existing per-section attack/support increments as a first comparison. For example, a raw 5-HP helper becomes 7 HP at section index 4 with local factor 1.0. Verify that “weak helper” still means an attainable quick kill in each section; override content tuning if the inherited scaling defeats that role.

Target new helper repeat intervals around 16–19 clock units before initial stagger: proposed base initiative 12 with Time 5 actions for hounds/whelp/fledglings, base 12 with Time 6 for spitter/Tender/mites, and base 12 with Time 4 for shades. The existing wisp's 11-unit repeat is deliberately faster and must be included in Cantor tuning. Guardian repeat intervals are base initiative plus the listed intent Time. These are separate actors' clocks, not synchronized rounds.

At the current baseline, a player spending two Time-5 cards advances roughly 19 clock units. A helper can therefore act about once per such activation, while a wisp may act more often. Damage assessment must include all actors that resolve in that interval. The initial guardian setup and staggered helper slots should give room to react without making a free mass opening attack.

The intended successful fight lasts roughly 5–7 player activations and costs meaningful resources or HP when the player mismanages threats. Prepared burst, Freeze, Chain, or displacement may win faster. This is an intended feel to test, not a fixed minimum duration or a license for immunity phases.

Every encounter needs a survivable approach with basic movement and defense. At 24 starting HP, combine the actual landing, Fire contact/start damage, Chill/Freeze consequence, Bleed, and helper clocks before judging a printed 7-damage attack. Full-board safety is not required; a readable way to improve the position is.

## Rules and implementation boundaries for a later task

The existing game supplies the action/status vocabulary, surfaces, terrain, traps, Light, Illusions, and initiative clock. These designs use those rules but still require new encounter and relic capabilities.

**Combat commitments.** Use the existing 9×9 grid and 1×1 gameplay footprints for the first prototype. Keep a safe entry halo. Major lanes, spawn cells, ground changes, and quake origins are declared in advance and saved with the intent. They do not silently rotate to follow a dodge. Preview changes caused by real displacement or destroyed terrain are accurate. Skipped guardian attack slots advance the loop; essential cleanup such as temporary light restoration still happens. Recovery Expose applies only after an attack attempt. No elemental immunity, new stun, damaging Burn, Poison, collision damage, or Air surface is added.

**Reward combinations.** Preview all automatically derived modifications from the original target and the same committed state. Galehook moves the group through real contact rules; Ashen Brand later consumes the Fire actually remaining at its own resolution. Winter's Spur changes movement cost, not the number of cells traversed. Procession can use a decoy's existing light source but cannot duplicate a Move action; a Winter's Spur discount applies only to movement of the relic-owning player. Cragbound spends independent movement and all currently stored Stoneskin on a separate Raise Cover command; reclaiming also costs movement and refunds only surviving HP. Resonant Clapper changes native direct Chain hit damage, not Fire contact, traps, or conduction-only hits. Persist ownership, loop state, temporary summons, owned cover HP, and reward claim state. None of these six relics uses a once-per-turn bonus charge.

**Planned new work.** Guardian map/selection and reward transactions; authored multi-actor compositions and saved telegraphs; capped summons and guardian-death cleanup; automatic connected-Fire Detonate with overlap damage; Ice movement pricing; ordered Chain damage preview; group force resolution; independent Raise/Reclaim Cover commands and AI cover handling; Illusion movement targeting. Separate reusable rules from individual enemy identities.

**Proof needed after design approval.** Compare clearing adds, controlling adds, and focusing the guardian with several ordinary deck shapes at every eligible section. Specifically test renewable-helper kill rewards, peak incoming clock windows, legal basic-movement responses, helper HP scaling, Earth obstruction AI, Ice minimum-progress rules, Chain/conduction deduplication, mixed-footprint force, temporary-light cleanup during skipped slots, and original-target and utility-action cancellation/save-resume. Validate route budgets and optionality over deterministic map seeds. Include final-section reward usefulness and combinations of multiple guardian relics.

Follow the repository's isolated implementation workflow at that time, with acceptance criteria, tests, a committed branch, separate peer review, and a playable inspection fixture. Real UI proof must use 1920×1080 at 100% scale and the supported input paths. New portraits/icons require their own registered identities and the icon identity test. Update the combat/reward analytics documentation and local append-only events together; capture actual add kills, guardian focus, spawn counts, damage cost, and trophy source without treating preview as a route choice. Update the balance heuristic and scorer together when the encounter assumptions are implemented and measured.

## Review focus for this pass

Review character identity, front/rear coherence, relative size, icon readability and the six rewards' input model. The [visual review](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/README.md) contains every new painted asset family. The [asset inventory](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/ASSETS.md) identifies what is new and what is reused. The [inspection record](/Users/borgerding/workspace/Labyrinth/output/guardian-design-2026-09-14/v3/REVIEW.md) records the perspective repairs and technical export checks.

The six encounter diagrams remain independent hypothetical decision states from v2. They are not gameplay captures or simulated timelines. The portrait and map imagery above now use the current source assets, including the helmeted Reaver. Historical v1/v2 concept plates remain available for comparison but are superseded by this pass.

Grounded in local master `74cc164e819c83a1a4f96c4529623e580fa9e145`: the current enemy/relic data, combat engine, section map, UI/icon policy, combat heuristic and analytics specifications. No runtime files, registries or live game rules were edited.
