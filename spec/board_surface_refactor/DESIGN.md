# Board surfaces and the complete card refactor — implementation contract v4

Status: full implementation authorized by the user on 2026-09-06; publication remains subject to inspection and explicit approval. Based on master `11a62f65e4070ae397d651778b550668bda0c854`. Numbers below record the accepted initial tuning, not playtest results. Implemented details, repeatable checks and measured evidence are indexed in [IMPLEMENTATION.md](IMPLEMENTATION.md).

The goal is to make building a deck change how the player shapes and uses the battlefield. Setup should create useful positions, routes and targets. Payoffs should depend mainly on where those things are and often consume them. Painting irrelevant corners should not become the replacement for filling the intensity meter.

## 1. Scope and decisions

User requirements: remove elemental intensity completely; remove Poison; rework the entire card pool; emphasize persistent, animated board effects; include enemy interactions, relic and ability reworks across the complete roster; support mixed-element combinations; use very few board-count conditions; design first, then implement the whole pass.

**Confirmed during this design:** surfaces and their hazards are shared by everyone, including the player and illusions. The user also requested center-only trap damage, a four-neighbor cardinal surface wake, and outward pushes for Air traps instead of surfaces. Follow-up decisions: use the name Electrified and the term elemental layer; remove Burn as well as Poison; retain Rubble entry cost and the minimum-progress rule; tie Chilled to Ice occupancy, activate occupant effects only on entry or turn start, and consume the supporting Ice when Freeze succeeds. Electrified relays are usable immediately; they do not apply an occupant status. Ownership is not a safety exemption. Direct attacks keep their normal targeting rules; shared surface consequences are shown explicitly.

Accepted implementation defaults:

- Two layers: Rubble plus one of Fire, Ice or Electrified. A different elemental surface replaces the old one. Identical placement is a no-op.
- Electrified has two uses: ordinary damaging Lightning conducts through contiguous patches and strikes their occupants; Chain can also use individual Electrified tiles as relay nodes across its normal jumps. Used ground is consumed. The surface itself causes no entry damage or Shock.
- Ice activates Chilled on actual entry or the affected unit's turn start. Chilled then persists while occupying Ice. Freeze consumes its supporting Ice. No extra thawing-protection status is needed. Recommended initial Chilled vulnerability remains +1 per direct hit, subject to tuning.
- Preserve Chain's current runtime meaning: its number is maximum jump reach, not a target-count cap. Correct contradictory glossary text. The proposed additional-target redesign and universal two-tile ordinary-Lightning hops are discarded.
- Burn removal is confirmed: migrate damaging Burn effects onto Fire tiles and remove the unit status. Never remove top-level `burn: true`, which is the internal Exhaust field. This item is settled, not pending.

The card appendix covers **all 159 definitions**: 56 normal rewards, 78 nonstarter equipment cards, 14 starters, 10 consumables and one inactive legacy definition. The normal reward pool contains 9 Fire, 10 Ice, 9 Lightning, 9 Air, 10 Earth and 9 neutral cards. There are 42 equipment definitions to review, including shared card grants. Direct intensity/Poison removals affect 63 distinct cards; every other card still receives a role, balance and compatibility review.

## 2. Small surface vocabulary

| Element | Primary contribution | Main payoff |
|---|---|---|
| Fire | Fire tiles create dangerous territory | Detonate selected Fire for immediate area damage, consuming it |
| Earth | Rubble changes movement costs; Stoneskin remains persistent defense | Hold targets in other hazards; a few local Rubble bonuses or conversions |
| Ice | Entry or turn start activates Chilled while occupying Ice | Ice attacks Freeze eligible Chilled targets and consume the supporting Ice |
| Lightning | Chain jumps between nearby opponents; Electrified prepares connected ground and extends Chain routes | Any damaging Lightning can discharge a connected patch into its occupants; Chain also relays through individual tiles |
| Air | Push, pull and player movement | Arrange every other element's setup, escape hazards, change attack angles |

Air does not need its own surface. Displacement and self-mobility already give it two useful dimensions. Neutral weapons retain credible physical damage, defense, utility and positioning roles; they benefit from the board without automatically becoming elemental painters.

## 3. Persistence and overlap

A tile has independent Rubble and elemental slots. Its elemental slot is empty, Fire, Ice or Electrified. Each is binary: no strength stacks or duration number. Chilled is activated by entry/start and sustained by actual Ice occupancy; idempotent repainting does not switch it off or create a new status application. Placing Ice under a previously unchilled unit does not activate it yet. Surfaces remain until replaced, cleared, consumed, or combat ends. Starting and repainting the same surface do not increase its power or retrigger contact.

Fire + Rubble, Ice + Rubble and Electrified + Rubble are valid. Fire + Ice is not: applying Ice replaces Fire, and applying Fire replaces Ice. Electrified similarly replaces the existing elemental surface. Changing the elemental surface preserves Rubble. No universal Steam, Lava, electrified-water or all-pairs reaction table is introduced. Individual relics may explicitly transform these rules. The user's conductive-Fire relic makes Fire also behave as Electrified without adding a third baseline layer; electrical use consumes the Fire itself. Such exceptions must be visible and taught by their owning relic. Replacement still supplies readable counterplay.

Replacement happens only in the new effect's printed area, never across an entire connected field. Show the old surface disappearing and the new surface arriving in the aim preview. Placement alone applies no occupant effect. Actual entry or the affected unit's turn start activates Fire/Chill. Rubble changes movement costs immediately, and Electrified tiles can serve as relays immediately; these are properties of ground rather than status applications.

Light, traps, loot and blocking objects remain separate systems. Surface glow is visual and does not grant vision unless the card explicitly creates Light. Newly created blocking terrain clears surfaces on its occupied tiles; those surfaces do not remain as hidden future traps beneath it. An attack that destroys terrain can then create its printed surface on the newly exposed floor. Indestructible walls never receive surfaces. Combat ends before any reward/navigation flow can suffer remaining surface damage.

## 4. Exact initial rules

### Fire and Detonate

Initial Fire tuning: **1 damage per burning tile entered; 2 damage when the affected unit's turn begins.** The actor takes one contact hit per movement step, even if a large footprint enters several burning tiles. Start damage happens once per actor, regardless of footprint. Creating Fire under a unit causes no immediate damage. It becomes dangerous on actual entry or at that unit's next activation start. This also ensures a trap wake applies terrain to its neighbors without immediately damaging them. An attack's printed hit still resolves before its Fire appears.

Fire does not also apply ordinary Burn. Temporary Block expires before that actor's start-of-turn Fire damage; Stoneskin can absorb it. Surface damage does not receive attack bonuses, Chill/Freeze vulnerability, lifesteal, on-hit riders or critical effects. Walking a route in separate clicks must produce exactly the same damage as walking it in one command. This is why contact damage is per actual step rather than per UI movement action.

**Detonate X:** consume Fire in the printed target pattern. Each consumed tile contributes its own tile and four orthogonal neighbors to a combined blast. Hit each actor in that union once for X direct Fire damage. Initial normal payoff target: **6 damage**, tuned by range, area, other printed actions and Time. More Fire expands coverage; overlapping explosions do not multiply damage. Unselected Fire reached by the blast is not recursively consumed. Rubble stays.

Confirmed Detonate timing: an explicit Detonate action may consume newly placed Fire immediately. No tile-age or activation flag is required. Only passive occupant effects wait for entry/start. Respect printed action order: Fire placement followed by Detonate can work in the same card if deliberately authored and priced, while the normal pool separates its setup and payoff.

Detonate is a printed attack, so ordinary direct-attack modifiers can apply. Its blast affects everyone, and the preview must show self-damage. Ordinary attacks do not detonate Fire unless printed. Most common payoff cards have a modest normal hit even when no Fire is available; pure setup-dependent detonators are a small, intentional part of the pool.

Consume the selected Fire atomically, snapshot the blast's actors, resolve the whole event, then evaluate victory/defeat and death spawns. Simultaneously killing the leader cannot erase lethal damage to the player. A newly spawned death replacement is not an extra target in the original blast.

### Rubble

Entering Rubble costs **2 movement instead of 1**. Leaving it adds no separate cost. Printed Move and the player's independent movement use the same weighted costs. For a large actor, use the maximum entry cost of its newly occupied footprint tiles, not the sum.

A fresh positive movement allowance can always take one adjacent passable step, spending its remaining allowance if that first step costs more than it has. This prevents Move-1 enemies from becoming permanently trapped. The exception belongs to the allowance, not every click; an already partly-spent movement pool cannot repeatedly use it. There is no stored movement debt.

Forced movement ignores Rubble's surcharge but triggers the surfaces along its path. Blink ignores intervening tiles and triggers only its landing. Rubble is difficult ground, not a wall; it never blocks attacks or line of sight. Strong Earth cards may explicitly clear/consume local Rubble for a bounded bonus or a fixed Stoneskin reward. Do not turn all Rubble into automatically destructible objects.

### Ice, Chilled and Frozen

**Confirmed delayed activation:** placing Ice beneath a unit does not immediately Chill it. Chill activates when a non-Frozen unit actually enters an Ice tile or starts its own turn occupying Ice. Once activated, the unit remains Chilled while at least one tile in its footprint is Ice. Hits and standing still do not spend Chill. Leaving the last Ice tile, or replacing/removing that Ice, immediately clears it. There is no duration, stack count or visited-tile ledger; the active exposure flag exists only to distinguish unactivated new ground from an entry/start that has actually occurred.

**Recommended initial tuning:** Chilled adds **+1 damage to each direct damaging attack** while active. This replaces v1's +2 on the next hit: the sustained bonus applies to every Flurry/Chain/multi-hit and has a substantially larger budget. It does not manufacture damage on support/status actions or amplify passive hazards and damage-over-time. Exact values remain provisional pending whole-pool balance.

An Ice attack against an eligible, actively Chilled target applies **Frozen after resolving its damage**, and **consumes the Ice supporting that target**. Consume every Ice tile overlapped by its current footprint, once per tile. This avoids arbitrary anchor-tile rules for large enemies or leftover Ice under the same body immediately preserving Chill. Ice outside that footprint and underlying Rubble remain. A blocked but connected attack may still Freeze; a miss, immunity rejection or an already-Frozen target does not consume Ice.

The attack reads the state immediately before each hit. Surface creation follows the hit, so a basic painter cannot use the Ice it is currently placing to Freeze in that same hit. Placing Ice, then merely attacking again does not activate it either: there must be actual entry or the affected unit's turn start. Forced movement counts as entry, so a separate Push/Pull can deliberately activate a prepared tile during the same player turn. The delay is an intervening board event, not a blanket requirement to wait a full round.

**Frozen:** preserve the recognizable payoff—skip the next activation and take double direct-attack damage while Frozen. Use its damage modifier instead of adding the Chilled modifier on top. Frozen cannot stack, refresh or gain Chilled. The unit effect persists if displaced off its original tile. Passive Fire, traps and damage-over-time receive neither vulnerability bonus.

**Skipped-turn ordering:** expired Block clears and start hazards such as Fire still resolve. If the actor was Frozen for this start phase, suppress Ice/Chill activation throughout that phase. Then finish the skipped activation and clear Frozen. Do not clear Frozen first and immediately reacquire Chill during the same turn-start event. This uses the existing Frozen state; there is no Thawing status, immunity timer or additional recovery counter.

An attack can create new Ice after its successful Freeze consumes the old Ice, but new placement does not activate Chill, and that Frozen actor's skipped turn cannot activate it. The Ice remains for a later eligible entry or turn start. This prevents a placement-only repeat-freeze loop without erasing renewed paid setup: deliberately moving a thawed actor onto Ice and freezing it again can still work, and its cost/value must be tested honestly.

Keep current occupancy and active Chill exposure synchronized during movement, Blink, spawn, surface replacement, footprint changes and load. Spawning directly on a hazard counts as arrival/entry, unlike putting a new surface beneath an already present actor. Fire still uses entry damage and its separate turn-start damage. Relics responding to “became Chilled” trigger only on a real false-to-true activation, not every start while already Chilled or on repainting.

A premium Shatter-style card can consume Frozen for a distinct finisher if explicitly authored, but this is separate from the ordinary Freeze contract and does not restore the consumed Ice. Elemental replacement clears Chill when it removes the last supporting Ice; it does not implicitly cleanse Frozen.

### Chain and Electrified — corrected two-use contract

**Confirmed user distinction:** ordinary Lightning conducts through an actual contiguous Electrified patch; Chain can make its normal jumps and treat individual Electrified tiles as additional relay nodes. A lone tile midway across bare floor is not enough to extend an ordinary non-Chain Lightning attack between separated actors. That previous recommendation is superseded.

**Ordinary Lightning conduction:** when a damaging Lightning impact strikes Electrified floor, or an actor occupying it, the connected patch carries the attack to all eligible opponents occupying that patch. Recommend cardinal adjacency, matching the rest of the grid vocabulary: no diagonal-only connection, empty-floor gap, or jump to a nearby actor standing outside the patch. Three or five contiguous Electrified tiles with enemies on the distant ends work. The original attack need not have Chain. A non-damaging Lightning support action does not discharge ground.

Recommend allowing a legal damaging Lightning attack to target visible Electrified floor within its normal attack range when the resulting discharge reaches an eligible opponent. This avoids an additional requirement that the first tile itself be occupied. Ordinary attack targeting/visibility rules still govern the initiating hit. Connected ground follows real passable floor around obstacles; it does not jump across blocked tiles. Preview must respect the existing visibility contract and never reveal hidden actors through the electrical network.

**Consumption recommendation:** discharge the whole activated connected component and consume that component once, including empty connecting tiles and branches. The attack hits each eligible actor once, regardless of occupied footprint or number of contact tiles. A disconnected component remains intact unless a separate native hit or Chain relay reaches it. This whole-patch discharge is the proposed simple cost model; it avoids a hidden minimal-wiring puzzle and makes the visible setup the resource spent. Do not accidentally erase another network because it has the same element.

**Intrinsic Chain:** keep its familiar enemy-to-enemy behavior, with the printed Chain value representing maximum Manhattan jump reach as in the current runtime. Do not add a separate target-count budget or silently reinterpret that number as additional enemies. Chain works without any terrain. It can also visit Electrified tiles as relay nodes within its normal jump reach and visibility rules; only actor visits deal damage. Existing Chain hops do not have an additional line-of-sight check, and this pass does not silently add one. The initiating attack retains its ordinary line-of-sight requirements. This permits gaps between relay nodes that an ordinary non-Chain Lightning discharge cannot cross. A neutral attack granted Chain can use relay nodes without silently becoming a Lightning attack; it does not gain whole-component discharge merely by having Chain.

**Together:** one Lightning attack with Chain has one planned Chain path plus any connected patches its impacts activate. Plan that path and discover affected components from the same pre-consumption board, then union all damage targets. Conduction hits do not spawn a separate Chain from every recipient. An enemy hit by a patch can still be a node in the planned Chain path, but takes damage only once. Keep route visitation separate from damage deduplication so adding ground cannot break a previously valid Chain. AOE native targets are included before extra arcs; large actors count once. Reserved surface nodes remain available only to finish this already-planned attack, never to a later attack.

For every Chain, reject empty dead-end routes; reaching an eligible opponent directly or through an occupied conductive component counts as useful. Empty components must not divert a productive Lightning Chain route. Prefer useful routes with fewer relay tiles, then shorter total travel, then deterministic actor/tile order. For a non-Lightning Chain, consume only Electrified relay tiles actually used to reach another eligible actor. For a Lightning Chain, visiting a relay can activate its connected component, whose full consumption subsumes the relay cost. Show both the route and the complete discharged area. Both sides can use the same ground, while direct attacks retain their normal opponent targeting.

Electrified is immediately usable after placement; it applies no occupant status and needs no entry/turn-start trigger. Walking through it neither hurts nor consumes it. A printed placement before a later attack can enable that attack in the same card. Ordinary post-attack placement cannot retroactively extend the attack that created it. Separate Flurry repetitions see actual remaining ground; a later explicitly repeated placement may legitimately rebuild setup and must be priced accordingly. No hidden created-this-card ban.

Shock remains a separately priced specialist effect, not an automatic consequence of conduction. Relics and cards that reward electrical use should recognize the actual discharge/relay event, rather than requiring Chain and recreating the original access bottleneck. Empty nodes are not actor hits, statuses, deaths or new card plays.

### Explicit relic transformations

**User direction:** many relics should open new combinations across elemental strategies by changing rules, effects, positioning or resource use. Replacing an intensity condition with a small damage/draw/Block reward is insufficient as the dominant design approach. Preserve useful simple relics and existing non-elemental builds, and avoid applying the same hybrid template to every pair of elements.

**Conductive Fire example:** Fire also behaves as Electrified for connection and relaying. Fire and actual Electrified can form one contiguous conductive patch. Fire retains normal entry/start damage and Detonate eligibility until used. The user confirmed that electrical use consumes the Fire itself; Rubble remains. Electrical consumption does not also Detonate Fire, and Detonate does not automatically cause a Lightning discharge. Those are separate actions, not a recursive reaction system.

Recommend applying this Fire property to all Fire in the encounter, shared by both sides, while the relic applies. That includes enemy-created ground and avoids invisible ownership-based tile types. Show a distinct combined Fire/electrical animation and explicit hover text. This changes behavior through a relic-owned rule, not a hidden third surface slot or a counter that instantly recharges itself. The proposed slot is Coalheart Crucible → Stormcoal Crucible. Eight other varied replacements cover transported terrain, sideways force, defense spent on attack geometry, Frozen finishers, redistributed Ice, remote origins, alternate Detonate fuel and Chain endpoint exchange. Their full rules/name/art dispositions are in `RELIC_TRANSFORMATION_PROPOSALS.md` and synchronized to the 60-relic support audit. Exact prices, rarity and final identity choices remain proposals.

## 5. Resolution and credit

Implement the same rules for player, enemy, illusion, movement, attack, preview and save/load paths. A semantic resolution trace should represent hits, displacement steps, surface replacement, contact, consumption and arcs. Presentation replays that trace instead of independently inferring rules.

Within a damaging action: validate and snapshot relevant pre-hit state; resolve direct hits and their status conversions; resolve printed displacement; place resulting surfaces at the card's explicitly specified hit area or final endpoint. Separate printed actions remain ordered. When an action has a Detonate clause, its Fire selection is based on existing Fire, never Fire created later by the same action.

Trap entry/detonation remains a distinct one-use event under the cardinal-wake rules below; surface contact follows arrival and uses the post-trap board if the actor survives. A Fire surface newly created by the arrival event is not retroactively counted as an entered tile. Ambient Fire does not recursively attack crates or trigger traps. Direct Detonate can hit destructibles/traps under their normal explicit attack rules, with an event queue/visited set preventing repeat resolution of an already consumed trap. Preserve the previewed event order.

Distinguish damage source and causal owner. Passive Fire is not a card hit. A kill caused during the player's card resolution—direct hit, push into Fire, or Detonate—can receive the ordinary one-per-death card-play credit. A passive start-of-enemy-turn death does not bank a future card play. Legitimate embers, XP, encounter objectives and kill records remain. Relic text must distinguish attack, damage and kill triggers; no recursive bonus for a relay tile or duplicate AOE coverage.

## 6. Traps: center damage and a cardinal wake

This incorporates the user's follow-up. Retire the current full 3×3 damage blast. A trap is still single-use and can be triggered by stepping onto it or attacking it.

1. Remove the triggered trap.
2. Apply its direct damage only to the unit whose footprint occupies the trap's center tile. A large unit takes the hit once. An attack that triggers an empty trap does not damage the distant attacker or any neighboring actor.
3. Apply the elemental wake on the four adjacent cardinal floor tiles. The center receives no new wake surface; its existing ground is unchanged. Diagonal tiles are outside the effect.

| Trap element | Center | Four cardinal neighbors |
|---|---|---|
| Fire | Direct trap damage | Create Fire; no immediate damage just for creation |
| Ice | Direct trap damage | Create Ice; occupants become Chilled only on actual entry or their next eligible turn start |
| Earth | Direct trap damage | Create Rubble |
| Lightning | Direct trap damage | Create Electrified tiles |
| Air | Direct trap damage | Push each neighboring actor 1 tile directly away from the trap |

A Lightning trap with an empty center creates four disconnected Electrified neighbors, not a secretly connected cross. Adding Electrified at the center later joins them. Existing conductive ground can also join the arms through an actual cardinal path. Preview real connectivity, including networks split by surface replacement or clearing.

The center hit has no legacy Burn/Poison/Freeze/Shock rider; elemental setup belongs to the wake. Trap damage is fixed by the authored depth curve, not intensity. Use the existing base damage curve as the initial tuning baseline and re-evaluate with the much smaller direct footprint.

Air has no persistent surface. Its center occupant is not pushed because there is no outward direction from the center. For large neighboring actors touching more than one arm, push the actor once along a deterministic legal cardinal direction away from the trap, shown in preview; never apply several independent pushes to one footprint. Blocked pushes stop normally. Actual displacement can cause Fire entry, Ice contact or another trap trigger; those are visible consequences of movement, not extra radial trap damage.

Wake placement follows the same replacement rules: it preserves Rubble when changing the elemental surface, cannot cover blocked cells, and does not remove loot or neighboring traps. Neighboring Fire/Ice/Electrified can be replaced. Merely placing a surface over another trap does not trigger it. Traps no longer damage adjacent crates simply by exploding.

Regular elemental traps and trap-like boss marks should share this contract. Separately authored boss attacks can retain larger telegraphed areas, but must not appear as an ordinary trap with secretly different damage coverage. Update boss pressure/tuning where it previously relied on a trap's 3×3 damage. Paid Detonate card attacks retain their separately printed blast rules; this change is specifically the trap contract.

## 7. Full roster migration, not a sample package

The companion `CARD_MIGRATION_AUDIT.md` and machine-readable JSON/TSV give every existing definition a disposition. These are proposed roles; final damage, Time and rare-item budgets are implementation tuning, not falsely settled numbers.

- Fire gets different single-target, line and cross painters, local detonators and mobility/Light/defensive support. Detonators do not routinely also repaint their own fuel.
- Ice distinguishes painters from reach, Pierce, holding and finisher cards. A painter is not automatically its own full Freeze combo.
- Lightning distinguishes useful single-tile gap filling, efficient contiguous line/patch painters, normal Chain and scarce prepared Shock. Damage attacks gain ordinary connected-ground conduction without needing Chain. Setup coverage must make small connected patches practical; do not retain a whole pool of isolated one-tile placements and call it solved.
- Air retains meaningful common Push/Pull/Move options. Remove the old self-enabled intensity refunds rather than making them unconditional. Hazard access must be paid for in damage, Time or other utility.
- Earth removes Poison from melee, support and area cards; uses geometry, Stoneskin, Immobilize and a small number of local Rubble conversions. Do not append Rubble to every defense card.
- Neutral, starter, equipment and item cards get the same compatibility review and new heuristic. Reliable plain attacks and shields remain important, but displacement, mobility, defense, multi-hit and draw must be revalued against the new board.
- Retire the inactive Bone Dart definition with a stable legacy mapping rather than leave an orphaned Poison effect. Preserve stable ownership IDs where a card is renamed/reworked. Review elemental names and art against actual element tags, including currently neutral cards with elemental names; no hidden effect inferred from artwork.

Most common cards should be independently useful. Each element must have common access to its core setup and payoff without requiring one particular rare. Keep cards readable at their actual game size; fewer purposeful rows are preferable to preserving every old bonus as a new clause.

## 8. Relics, skills, enemies and rooms

There are 12 intensity-linked relics, 2 Poison-linked relics and 2 intensity-linked skills in the current data. Their proposed replacements are in `SUPPORT_CONTENT_MIGRATION_AUDIT.md`, which covers all 42 equipment packages, 60 relics and 30 skills. Review the entire relic pool for meaningful choices and indirect surface abuse, especially draw, card-play, kill, defense and multi-hit hooks. Classify each retained/reworked relic by the new action or deck decision it enables. Many should be transformative bridges; elemental pairing alone plus a small stat reward does not meet that intent.

Prefer local conditions: target stands on Rubble, attack consumed Electrified tiles, push crossed Fire, or opponent that genuinely entered the Chilled condition. Allow only a few whole-board thresholds, as requested—initial cap of 2–3 deliberately authored cards/relics. Conditions should be binary and capped, such as a small benefit while at least three relevant tiles exist. No uncapped damage-per-tile scaling, global tile meter, or broad ecosystem of competing surface-count currencies. Tooltips may highlight the counted visible tiles.

All 18 enemy definitions now have explicit dispositions, intent changes and player counterplay in `ENEMY_MIGRATION_DESIGN.md`. This is a deliberate interaction pass, not only compatibility maintenance. Elemental specialists create/use/consume local terrain; controllers manipulate actors into it; support may clear a threatened ally's elemental ground. Physical attackers retain distinct pursuit, screening and firing-position roles with terrain-aware decisions. Concrete proposals include Cinder Ooze using local Fire for defense; Shale Bloomer using Rubble/Expose; Gaoler pulling through hazards; Surgeon clearing threatened ground; Lancer preparing Ice lanes; Vyraketh exposing a shared Fire/Detonate setup that the player can deny; and Zekarion/Wisps creating shared Electrified relays. Bosses and generated variants use the common contract with explicitly retained narrow immunities. No matching-element or ownership exemption is added.

All 30 skill definitions (29 active plus retired Layaway) have specific dispositions in `ABILITY_MIGRATION_DESIGN.md` / `.json`. Prismatic Instinct creates a real chosen surface; Confluence relocates a real layer; Sure-Footed is rewritten for center hits/Air pushes and persistent wakes. Movement, Stoneskin, decoys, Light, card recovery and reward skills retain useful distinct roles with explicit new interactions. Relocation clears origin support and applies ordinary destination placement: no instant Chill, duplicated terrain or consumption-payoff shortcut. These proposals include activated player skills and enemy abilities; equipment-granted abilities are covered by the complete card manifest.

Relic awards use explicit source, phase and event contracts in the support audit. Enemy consumption cannot award the player plays; per-turn caps mean the player activation cycle. Passive Fire deaths never bank future plays through Funeral Bell or a leftover pending-relic-play path. Real placement excludes idempotent repainting. Secondary relic damage is separately classified and cannot recursively inherit direct-card riders or generate card-play awards. Each area consumption payoff selects one deterministic previewed origin where applicable.

Remove room-start intensity, passive buildup, spend actions, threshold variants and intensity-scaled trap damage/visuals. Room elements remain useful for encounter composition and atmosphere. Reauthor themed traps as center-only damage with the cardinal wake above; Earth trap Poison becomes Rubble. New starting surfaces, if used, stay sparse and never remove an initial escape route. Do not populate entire rooms with free elemental resources.

AI uses actual weighted paths and damage predictions. It should avoid unnecessary hazards, but treat them as finite costs rather than impassable walls. Exact intent previews update after placement, replacement, displacement and consumption. Neither pathfinding nor relay previews may disclose hidden enemies.

## 9. Visuals and feedback

Use the current elemental attack art direction for tile-sized, seamless loops: low fire tongues/embers, slow Ice shimmer and cracks, restrained Electrified filaments, and a clear Rubble silhouette with occasional dust. Reuse existing assets where they genuinely fit; create finished, distinct new art where they do not. Do not ship crude procedural placeholder icons.

Place floor effects in the board's depth-aware tile rendering. Units, pillars and foreground geometry occlude them correctly. Fire+Rubble must visibly retain both identities without twice the brightness or particles. Electrified, Ice and Fire must differ in motion and shape, not just color. Share animation frames and vary phases; do not create a large independent processing/tween stack for every tile. Include reduced-motion and dense-board frame-pacing checks.

Hover/selection explains exact ground rules, movement cost and coexisting traps. Aiming distinguishes fresh Ice beneath an un-Chilled occupant from an already active Chilled condition, including the next eligible turn-start consequence. Aiming shows what will be created/replaced/consumed, the resulting actor statuses and hazard damage, the complete Chain route, and all friendly Detonate exposure. Creation and AOE hits can animate together; displacement contact and Chain hops retain short sequential beats. Counters must not delay gameplay, and the removed intensity HUD leaves room for the board rather than a new meter.

## 10. Implementation structure and migration

One integrated pass can be built in dependency order without handing back a partly converted game:

1. Version the encounter rules/data; build centralized surface state, pure queries, weighted movement and source-aware damage/semantic events.
2. Implement shared Fire, Rubble, Ice/Chill/Freeze, Electrified/Chain, placement/removal and targeted Detonate behavior in both real and projected resolution.
3. Reauthor all cards, equipment grants, affected relics/skills, enemies, traps, upgrades and room assumptions together. Remove intensity and Poison runtime/UI paths rather than leaving a disabled parallel system.
4. Complete card summaries/tooltips/icons, floor animation, status art, input previews, tutorials and Grimoire. Rename/redraw semantic mismatches.
5. Update heuristic and analytics, migrate saves, run full-pool balance/playtests, inspect real rendering, fix problems and obtain separate peer review of the complete pass.

Old saves retain account progression, unlocked skills, equipment and card ownership through stable IDs/remaps. Strip retired intensity/Poison fields and unsupported old upgrade modifiers; convert/refund affected permanent upgrade investments explicitly rather than silently losing them. Snapshot old saves before migrating. Design the in-progress-combat conversion separately: preserve an action-boundary state when possible; if incompatible, provide a defined encounter restart preserving pre-encounter run state. Do not invent lost pre-encounter information. If that snapshot is unavailable, report the compatibility limitation and choose the fallback before shipping.

Add a rules-version field to new analytics; retain historical append-only events unchanged. Record surface creation/consumption, contact and start damage, displacement contribution, Chain relay routes, Freeze setup, and indirect kill attribution. Remove obsolete intensity fields from new event construction while retaining old log readers where needed. Update the scorer and its owning specification together; a new surface must not receive an arbitrary permanent-uptime value regardless of geometry.

The live Steam description currently promises elemental intensity, so shipping this refactor also requires correcting that sentence and any other now-false rules text. Retain the reusable media pipeline. Recapture the affected tactical scenes and replace stale gameplay media after the new game pass is approved; the old footage should not be presented as the new ruleset.

## 11. Completion criteria

- A manifest covers all 159 card definitions and all 42 equipment definitions. Every active card resolves, displays, upgrades and enters the correct acquisition pools. Every retained card has a stated role and revised balance disposition.
- No active runtime/content/HUD/tutorial/upgrade path uses intensity or Poison. Historical migration/log readers are explicitly isolated exceptions; deleting historical evidence is not required. Burn is removed as a damaging unit status; the unrelated Exhaust cost remains.
- One movement path versus split clicks gives identical cost/damage. Move-1 and large actors behave correctly. Push/Pull/Blink, traps, hidden collisions and actor deaths match previews.
- Ice placement never immediately Chills or Freezes. Entry/start activates Chill; it remains through hits while on Ice and clears when no supporting Ice remains. Successful Freeze consumes all occupied Ice and rejected Freeze consumes none. A Frozen actor cannot reacquire Chill during its skipped start phase. Test repainting, large footprints, Push/Pull, Shock, Shatter and save/load. Chain cannot duplicate actors, invent hidden targets, loop through relays or silently reorder placement. Ordinary Lightning discharges only contiguous ground, hits its eligible occupants and consumes the selected components; it cannot use bare-floor air gaps. Chain retains jump reach and can relay across those gaps. Mixed Chain/conduction plans have one actor damage set and no extra Chain heads. Conductive Fire is consumed by electrical use and never automatically detonates.
- Overlapping Detonate hits each actor once, shows self-danger, consumes only the selected Fire and handles simultaneous lethal outcomes correctly.
- Trap direct damage is center-only; cardinal wakes never affect diagonals. Empty-center triggers, Fire creation without immediate damage, delayed entry/start Chill, replacement, Air outward pushes, large footprints and movement-triggered trap cascades match preview.
- All 18 enemies, 60 relics and 30 skill definitions have implemented dispositions matching their manifests. Verify meaningful enemy setup, player denial, shared-resource use, relic payoffs and ability manipulation through the ten authored enemy proof encounters and ability/relic contract checks. Bosses, summons, decoys, exit objectives and reward transitions work. AI does not become suicidal or permanently immobilized by ordinary Rubble.
- Full pool scoring is updated by source/role, followed by seeded playtests for mixed and single-element builds. Explicitly stress Fire+Rubble funnels, push/pull farming, Freeze/Shock locks, Electrified networks, Flurry, kill refunds and board-filling incentives.
- Fresh inspected real-renderer proof at 1920×1080/100% UI scale covers each surface, each combination, targeting, large actors, Umbra, card/reward/shop/loadout readability and dense-board performance. Supported mouse/controller paths remain usable.
- Save migration and round trips pass, analytics reflects actual results, current documentation matches, and separate peer review covers the complete committed implementation. Publication still follows user inspection/approval.

## Companion records

- `CARD_MIGRATION_AUDIT.md`: all 159 card roles and proposed migrations.
- `SUPPORT_CONTENT_MIGRATION_AUDIT.md` / `.json`: all gear packages, relics and skills, including relic source/event contracts.
- `ENEMY_MIGRATION_DESIGN.md`: all 18 enemy identities, concrete intent reworks, counterplay, AI requirements and ten proof encounters.
- `ABILITY_MIGRATION_DESIGN.md` / `.json`: all 30 skill definitions, concrete reworks, retained interactions and activation/migration contracts.
- `CARD_MIGRATION_AUDIT.json` / `.tsv`: implementation tracking inputs.
- `RELIC_TRANSFORMATION_PROPOSALS.md`: proposed varied cross-element rule changes, mapped to existing relic IDs.
- `runtime-audit.md`: observed current semantics and source touchpoints. Its alternatives are audit notes; this document owns the recommended rules, especially Electrified layering, indirect kill credit, Fire creation without immediate damage and the newly requested cardinal trap wakes.

Agreed follow-ups: Electrified naming, elemental layer, Burn removal, accepted Rubble entry rule, delayed entry/turn-start occupant effects, Freeze consuming Ice, immediately usable Electrified relays, and immediate eligibility of newly placed Fire for Detonate. The proposed recovery status has been removed. Initial +1 Chilled vulnerability and other numerical values remain tuning proposals. Versions 1–3 and LIGHTNING_SIMPLIFICATION_PROPOSAL.md remain in the original design output archive only for decision history and are superseded by this document. V4 records the user's connected-ground/Chain distinction and confirmed conductive-Fire consumption. Whole-component discharge, cardinal adjacency and shared relic scope are explicit recommendations where the user did not specify the detail.
