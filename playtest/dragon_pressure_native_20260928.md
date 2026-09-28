# Dragon pressure revision: native playtests — 2026-09-28

Scope: all six dragons. This journal tests the new pressure prototype; prior wins
and the earlier fun signoff are not acceptance for this revision. No hands, draws,
HP, boss state, or outcomes are rewritten during an attempt. Reopening a paused
attempt uses its existing autosave, not fixture regeneration. Only public UI and
card rules inform decisions; JSONL is read afterward to audit the actions.

## Vyraketh 01 — completed adaptive continuation

Native Godot 4.6.1, isolated fixture `dragon-pressure-vyraketh-01`, depth 4,
balanced acquired build, natural hand. Started at 20/24 HP against 60 HP.
The first four enemy activations were paused on player turn 5 at 8/24 HP
against 30 HP for independent correctness regressions. The same autosave was
resumed without regeneration and won on T7, clock 114, at 6/24 HP before the
reward heal. The isolated window used Windowed and 100% UI scale for native
interaction; dedicated presentation proof separately covers 1920x1080.

| Warning | Actual decisions | Observed result |
| --- | --- | --- |
| Meteorfall | Chain Bolt 4; free movement 2 from (1,4) to (2,3); Gust Step 3 with its movement skipped, pulling the body | Avoided all seven held marks but the live bolt hit for 4. 20→16 HP; boss 60→53. Two offensive plays plus the nearby safe tile were not free. |
| Cinder Breath + heat | Butcher Chop 12; Cleaver Hook 6 and Push 1; free two-step movement around the top crates to (3,2) | Escaped the lingering heat but still took the broader held breath for 8. 16→8 HP; boss 53→35. Defending or spending a movement play was a real alternative to keeping both damage plays. |
| Crownfire + pursuit | Root Snare 2 creates Rubble/Light; Warded Advance moves 2 with Block 7; free movement 2 further around the right edge | Safe at 8 HP; boss 35→33. Four cells of travel bought a relief turn but two card plays produced only 2 damage. Root Snare was initially misread as a bind by the pilot; it is Rubble/Light, not immobilize. |
| Maw + held marks | Sidestep Slash used for Move 2; its melee target was skipped by the floor-target flow. Kite Bash 3, Block 6 and Push 1; free movement 2 away from the new position | Safe at 8 HP; boss 33→30. Displacement plus extra movement avoided the pursuit and held field. The skipped 5-damage strike is a pilot/control-path issue, not proof that the boss forced that entire damage sacrifice. |

The first two turns deliberately tried the user's rejected approach: preserve
two offensive plays and solve the warning with ordinary movement. They cost 12
HP. The following turns demonstrate two available ways to recover positioning:
extra movement and displacement. At that partial checkpoint they did not prove the tuning across a full
fight or that every alternative was costly. A stronger pilot can retain more
attack value on the fourth turn. The unchanged continuation is audited below.

Control lesson: select cards and inspect their current target phase after a
movement choice. Clicking a floor square can commit the movement while skipping
the later strike. Click the enemy as the final target when the combined card
solver can route to it; do not assume a second click after card resolution will
add the missing attack. Boss attacks trigger once both card plays and ordinary
movement are exhausted; do not press Pass again after the fresh hand appears.

Post-action audit: isolated `analytics/events-2026-09-28.jsonl`, sequences 1–73.
Enemy resolution records confirm Meteor bolt 4, Breath 8, no Crownfire or Maw HP
loss; card records confirm 4+3, 12+6, 2+0, 0+3 damage respectively. The runtime
revision stamp was still `dragon_feedback_v2` because the GDScript data constant
had not yet been updated with the scorer; this is an instrumentation correction
required before final evidence, not a claim that these events used old enemies.

Independent review of the partial cycle: these are two *observed* costly offense
lines, not a proof that every two-attack/free-movement route loses HP. Gust's
Pull made the bolt easier to reach, so do not call all four damage unavoidable.
Root Snare's low output is not an earned cost without showing its actual Rubble
replacement mattered. Assess the fourth turn against an 8-damage Sidestep+Kite
line, not the accidental 3-damage line. At that checkpoint, acceptance still required a later cycle,
element-specific decisions, and a competent adaptive win. No HP or damage
retuning followed from the partial attempt alone.

### Vyraketh continuation — complete post-action audit

The continuation used the existing six-card T5 hand and ordinary level-1 build:
Iron Cleaver, Ward Kite, Patched Cloak, Skirmisher Boots and Cracked Lantern;
Iron Buckler was the only starting relic. There were no skills, Defiance,
Crowncoal or Worldheart effects during combat. Two ordinary movement points
were available per activation. No healing card or item was used; a Pitch
Firebomb was picked up on T5 and remained unused alongside Crimson Draught.

| Player activation / clock | Committed decisions and route | Audited outcome |
| --- | --- | --- |
| T5 / 68→84 | Stone Plate: 4 Stoneskin, 4 Time, 2 actual draws including Iron Buckler. Lantern Shot: 4 damage, 3 Time, no draw because the hand was capped. Ordinary movement spends both points from (7,4) to (6,5), collecting the Firebomb. | Meteorfall's seven cells miss the endpoint. Its separate live bolt consumes exactly 4 Stone, with zero HP loss. Boss 30→26 by Lantern, then 26→23 by an enemy-owned Fire start tick. Player remains 8 HP. This is an actual dedicated defensive play with useful absorption. |
| T6 / 84→101 | Frostbolt deals 4 at (5,2), creating Ice. Shadow Step pays 4 Time, Blinks three cells (6,5)→(3,5) and draws the last card. Ordinary movement spends both points to (3,3). | Both Breath and its separate heat field miss. Ice applies Chilled to the boss at its activation. Boss remains 19 HP; no enemy damage reaches the player. The next turn draw reshuffles the empty pile and costs 2 Fatigue: player 8→6. |
| T7 / 101→114, victory | Shrapnel Burst deals 9 (7 + Chilled 2), Time 6. Low Sweep's enemy shortcut moves one cell to (4,3), deals 5 (3 + Chilled 2), and applies Immobilize, Time 4. Ordinary movement spends both points retreating to (2,3). | Boss 19→10→5. Crownfire's shared blast kills the remaining 5 HP while the hero is outside it. The boss dies before its movement/melee follow-up, so Immobilize is **not** credited with preventing that attack. Player remains 6 HP. |

The fourteen card records total **52 boss damage**, and the only other boss
losses are 3 from its own Fire and the final 5 actually lost to its own
8-damage Crownfire. Total player HP loss is **14 = live bolt 4 + Breath 8 +
Fatigue 2**. The second bolt spends 4 Stoneskin, not HP. There are no card-play
refunds, healing, active skills or prior-dragon trophy damage in this study.
All seven activations spend both ordinary movement points (14 total); cards
add eight cells of movement/Blink. The first six activations pay 47 card Time
plus six base costs of 9, reaching clock 101. The last two cards would return
the player at 120; the boss instead kills itself at clock 114. Enemy resolution
records often use the settled next-player envelope clock, so those envelope
values are not substituted for the actual enemy queue times.

Costs must be stated narrowly. Initial T5 destination clicks before selecting
the hero did not move or spend anything; they are pilot input errors, not a
blocked escape or boss-imposed cost. T5 proves guard can replace an offensive play
and absorb the live layer while movement avoids the fixed layer. T6's Blink
crosses the central crate and preserves access to the northern flank, but it
was the pilot's chosen route. The recorded fan and heat tile sets leave
(6,7) unmarked, and the room geometry suggests the ordinary route
(6,5)→(6,6)→(6,7) as a cheaper retreat. That route was **not played or run through
the engine**, and ends farther from melee access; it is a counterfactual to
check, not a verified free full-cycle strategy. Do not count all five cells of
T6 movement as forced. Low Sweep retained its attack correctly, unlike the
first-cycle Sidestep mistake, but the final shared blast makes its Root benefit
unnecessary in the observed outcome.

Bounded design verdict: retain the current Fire pressure prototype for this
cohort, subject to independent review. It offers distinct, readable options:
spend health to keep damage during the opening, absorb the live bolt while
leaving its marks, cross the fan/heat field using mobility, and preserve the
boss's own Fire for its shared payoff. The adaptive continuation was winnable
from 8 HP without healing or hidden-information help. That conclusion depends
on the actual guard use and recurring compound warnings, not the low ending
HP, the earlier targeting mistake, or an assertion that every chosen movement
was necessary. This one level-1 run does not prove later-gate balance, remove
the cheap-retreat counterfactual, or accept the other five dragons. No extra
HP/damage tuning is justified by this run alone.

The native milestone displayed Crowncoal Heart, +110 Embers, +6 actual HP and
one first-dragon Moltshard. Continue reached the cleared section-I map. Normal
quit is confirmed by runner session `62936`, exit 0. The saved room state has
12/24 HP, 110 held/unbanked Embers, Iron Buckler plus Crowncoal, an empty pending
reward, and one Moltshard receipt; run statistics are 60 dealt / 14 received.
The final save/profile and compact event audit are preserved at
`/private/tmp/dragon-pressure-native/vyraketh-01-complete/`.

Evidence: the same append-only JSONL now contains 143 lines, run
`run_95605824_a6efa2bc`, combat `run_95605824_a6efa2bc_c001`. The original session
has sequences 1–73; resumed session `session_58601675_e4a4d2ae` has sequences
1–70, so sequence numbers alone are not unique across this file. Continuation
card records are file lines 83/86, 111/113 and 126/127; defended bolt is 108,
Breath/heat misses 121/122, and victory/reward/claim are 140–143. The resumed
records correctly use `dragon_pressure_v3`. Source JSONL SHA256:
`de7cea1f42ed02d9a50d28656fd735b88f6dabaefdcb26ffc685c5aca5089061`.
No future deck order or hidden state informed native decisions; this audit was
performed only after the normal quit.

## Noctyrax 01 — first cycle, paused before the player-anchor revision

Native isolated fixture `dragon-pressure-noctyrax-01`, depth 24, level 4,
balanced acquired build with Pilgrim Boots and the five earlier dragon trophies.
Started at 20/24 HP against 101 HP. Four player activations completed; the
attempt is paused on player turn 5, clock 72, at 11/24 HP against 69 HP. This
records the prototype whose secondary fields targeted the nearest brazier.
It is neither a victory nor acceptance of the later player-anchored fields.

| Player activation / clock | Committed actions and movement | Audited result |
| --- | --- | --- |
| T1 / 0→19 | Two ordinary steps (1,4)→(2,4)→(3,4); Needle Thrust 7, Time 4; Storm Beacon 3, Time 6; final ordinary step to (3,5). | Boss 101→91. Beacon also chained 3 to the initial helper, so its aggregate card damage is 6, not 6 to the boss. Night Coil hit for 9 HP and pulled the hero to (4,5); the near brazier was snuffed. HP 20→11. |
| T2 / 19→37 | Clockwork Mark 5, Time 4, draw 1; Frostbolt through Stormroad's charged relay kills the helper's remaining 3 HP, Time 4, refunding one play; Gust Step moves to (4,6), deals 3 and pulls the body one cell, paying only 1 Time after Hourglass spends 3. Ordinary steps (4,6)→(3,6)→(2,6)→(2,5). | Boss 91→83; no HP loss. Current Light stops Eclipse darkness and the final tile lies outside the far-brazier sweep. Eclipse replaces one helper, scheduled at clock 49 after the next player activation at 37: a real response window. There is no automatic brazier relight. |
| T3 / 37→55 | Cinch Straps grants 7 Block and actually draws 2, Time 3; Shrapnel Burst deals 7 to the boss, Time 6. Ordinary steps (2,5)→(1,5)→(1,4)→(1,3). | Boss 83→76; no HP loss. Void Claw and its ground field miss. Worldheart converts 2 Block, but the remaining guard is **not unused**: the replacement Acolyte's Closing Shade subsequently consumes 4 Block. |
| T4 / 55→72 | Ordinary step (1,3)→(1,4); Kite Bash deals 3, grants 9 actual Block and pushes the body from (2,4) to (3,4), Time 4. Spur Vault moves one cell onto (2,4), deals 4 and pushes the body to (4,4), Time 4. Ordinary steps back through (1,4) to (1,3). | Boss 76→69; no HP loss. The Vault crosses Crowncoal Fire for 2 absorbed damage. Both pushes translate the held-direction Starless fan away from the final tile; its separate near-brazier field also misses. Worldheart converts 2 more Block. |

The completed inputs total nine cards, twelve ordinary movement points, two
additional cells of card movement, and 36 paid card Time. Four base activation
costs of 9 give the observed clock 72. Damage totals are 32 to the boss and 6 to
the defeated helper; the sole HP loss is Night Coil's 9. No potion, active skill,
healing or reward has been used. The fire event records 2 damage and zero health
lost; the established Block-before-Stoneskin rule and preceding 9-Block gain
explain its absorption. The replacement helper's 4-Block hit is explicit in the
enemy-resolution event, rather than inferred from the absence of HP loss.

Pilot observations qualify the costs. Shrapnel was selected as the drawn hand
shifted; this is an input/selection mistake, not evidence that the boss forced
that choice or an offensive sacrifice. T2's extra card is an earned kill refund,
and its movement card costs only 1 Time after the Ice reserve. T4 retains both
offensive plays while gaining substantial defense and displacing the boss; its
success cannot be described as paying a dedicated defensive turn. T1's injury
shows the chosen route was unsafe, not that every two-attack route was unsafe.

Independent partial-cycle assessment: Pilgrim Boots' automatic Light repeatedly
removes the need to use the brazier refuges, while the nearest-brazier sweeps can
be irrelevant to the route. The helper does spend some guard, and displacement
changes the breath geometry, but these four turns do not establish a costly
repeatable tradeoff across the fight. They also do not demonstrate an entirely
free two-attack cycle: T3 spent one card on guard/draw and the helper used part
of that guard. The player-anchor revision needs fresh native evidence, including
viable choices among extra movement, guard, and earlier return; isolated geometry
results are not a replacement for that evidence. No fun acceptance or win is
claimed here.

Post-action audit: `/private/tmp/labyrinth-godot-home/dragon-pressure-noctyrax-01/Library/Application Support/Escape the Umbra Parallel dragon-pressure-noctyrax-01/analytics/events-2026-09-28.jsonl`,
sequences 5–76, run `run_102367523_546358fc`, combat
`run_102367523_546358fc_c001`, balance revision `dragon_pressure_v3`.
Card records are 15/17, 26/32/34, 49/52, 68/70; the helper's Block hit is 61,
absorbed Fire is 69, and the displaced breath is 73. Enemy records are appended
at the settled next-player clock, so that envelope clock is not presented as
the exact enemy activation time. The future hand/deck and hidden helper routes
are not used to prescribe subsequent play.

## Noctyrax 02 — completed player-anchored-field study

Native isolated fixture `dragon-pressure-noctyrax-02`, depth 24, balanced level-4
acquired build. The verified manifest is
`/private/tmp/dragon-pressure-native/noctyrax-02.json`. Gear: Duelist Rapier,
Ward Kite, Boiled Leather, Trapdoor Spurs, Clockwork Arrowhead; ordinary relics
Iron Buckler, Pilgrim Boots and Reinforced Shield, plus all five earlier dragon
trophies. Skills: Quick Wits, Measured Breath, Ghost Stride. Started at 20/24 HP
against 101 HP with one Defiance charge. The pilot used the natural hand and
three ordinary movement points, with no manual skill or healing item use.

Victory was on T11, clock 178, at 6 HP, **after consuming Defiance**. The unchanged
6-HP display at the last player return initially hid a lethal sequence; it was
not a safe Claw escape. The saved reward state and append-only events confirm
the correction below. This replaces the pilot's initial end-state interpretation.

| Player activation / clock | Committed decisions and routes | Outcome at the next player turn |
| --- | --- | --- |
| T1 / 0→20 | Beacon deals boss 3 + helper 3 (Time 6); Frostbolt finishes the helper's remaining 3 HP (Time 4), refunding a play and storing 3 Hourglass Time. Leather Roll moves (1,4)→(3,4), grants 6 Block, costs only 1 Time and draws 1. Ordinary steps to (3,5)→(3,6), then Pass with one unused. | HP 20, boss 98. Coil misses. Choosing the helper over Needle's boss damage buys a kill refund; the extra movement card is therefore not evidence of a lost ordinary attack slot. |
| T2 / 20→36 | Gust Step moves to (3,5), pulls the body two cells onto old Ice, deals 3, draws through Pinion, and pays 3 Time using the last Hourglass point. Needle deals 9 including Chill's +2, Time 4. Ordinary steps (2,5)→(1,5)→(1,4). | HP 20, boss 83: 12 card damage + 3 Crowncoal Fire. The fourth cell supplied by Gust exits the radius-three Eclipse field while Pilgrim Light prevents darkness. Eclipse replaces a helper, queued at 49 after the player returns at 36. |
| T3 / 36→53 | Kite Bash deals 5 including Chill's +2, grants 9 Block and pushes; Spur Vault moves one cell to (2,4), deals 4 and pushes again (4 Time each). Ordinary steps (2,5)→(2,6); Pass with one unused. | HP 20, boss 71: 9 card damage + 3 Fire. Claw/ground miss; the original helper consumes 4 Block. Do not call both control cards forced: the pilot identified Clockwork + Kite with another free step as a plausible alternative, not a tested line. |
| T4 / 53→72 | Shrapnel kills both adjacent helpers for 12 total damage, **zero boss damage**, Time 6. Only the original helper refunds a play. Clockwork deals boss 5 and draws 1, Time 4. Ordinary steps through the cleared corridor (2,6)→(2,5)→(2,4)→(2,3). | HP 20, boss 63: Clockwork 5 + Fire 3. Breath/ground miss. Measured Breath banks the unused play. This is actual target prioritization, but its refund must be counted rather than calling Shrapnel an unrecouped play loss. |
| T5 / 72→96 | Three plays: Reprise costs 1 HP, grants 8 Block and draws only 1 because of the hand cap, Time 6; Spur Trip moves two cells to (4,4), deals 5/Root, Time 4; adjacent Riposte deals 5 and grants 7 Block, Time 5. Three ordinary points via (3,3), then (3,4)→(2,4); two entries cross own Fire. | HP 17, boss 47: 10 card damage + two Fire ticks totaling 6. Both Coil and the following Eclipse resolve during this long turn. Fire spends 4 Block; Eclipse's fixed field spends 8 Block while Light stops darkness. Reprise costs 1 HP and the next draw reshuffle costs 2 Fatigue. Its nearly capped draw is pilot inefficiency. |
| T6 / 96→114 | Riposte moves two cells to (3,3) and grants 7 Block, Time 5, but the floor target explicitly skips its melee. Frostbolt deals boss 4, replaces Fire with Ice, and stores 3 Time, Time 4. Ordinary movement spends 2 through the near brazier to (2,2), then 1 to (1,2). | HP 17, boss 43. The route actually relights the near brazier (arrival event 117); Claw/ground miss. The skipped attack is a targeting error, not boss-imposed lost damage. The replacement helper takes its first turn after a full player response window. |
| T7 / 114→127 | Ordinary step to (1,3); Spur Vault moves two cells to (2,4), deals 4 and pushes the body south, paying 1 Time from Hourglass. Cinch grants 10 Block/draws 2, Time 3. Remaining ordinary steps (1,4)→(1,5). | HP 6, boss 39. The moved body carries the held-facing Breath one row south and it hits (1,5) for 11 Pierce, bypassing all guard/Stone. The pilot chose the wrong escape direction despite the warning. Guard was not a valid substitute for evading this piercing primary hit. |
| T8 / 127→143 | Spur Trip moves to (2,5), deals boss 5/Root, Time 4; Warded Advance moves two cells to (4,5), grants 10 Block/draws 1, Time 3. Ordinary steps to (5,5)→(6,5); Pass with one left after a helper obstructs the proposed further move. | HP 6, boss 31: card 5 + Fire 3. The paid flank route escapes Coil. Own Fire at the first card landing spends 2 carried Stoneskin before Warded grants Block. Worldheart's end pulse finishes the replacement helper's last HP. This is the chosen repositioning line, not a proved minimum movement requirement. |
| T9 / 143→159 | Leather Roll moves two cells to (5,6), grants 9 Block/draws 1, Time 3. Ordinary steps (4,6)→(4,7) leave the radius-three field centered at (6,5); Needle deals 7, Time 4. Pass with one movement unused. | HP 6, boss 20: Needle 7 + Worldheart pulse 1 + Fire 3. Light still prevents darkness, while four cells of movement independently evade the ground field. This is a second actual Eclipse movement solution, with one non-attacking movement/guard play. Replacement is scheduled at 175 after the next player return at 159. |
| T10 / 159→178 | Shrapnel 7 + Clockwork 5/draw 1, Time 6+4. Three ordinary steps (4,7)→(5,7)→(5,6)→(5,5), preserving both attack plays. | Boss 5 after the cards and Fire 3. **The route does not escape live Claw:** its 15 spends all 12 Stone and 3 HP. The following helper hit removes the remaining 3 HP; Defiance consumes the sole charge and restores 6. The final health display therefore remains 6 despite lethal incoming damage. |
| T11 / 178, victory | Beacon deals the boss's remaining 3 plus the helper's last 1, Time 6; Kite grants 6 Block and deals the boss's final 2 (printed 3), Time 4. | Victory at 6/24 HP, Defiance 0. Crimson Draught remains held. No further enemy turn occurs. |

The card log contains **24 plays**, not 22. The completed first ten activations
pay 88 card Time plus ten base costs of 9, yielding clock 178. The final two
cards accumulate 10 more Time within the winning activation without advancing
that clock. The opening enemy entry is 12; subsequent boss times, reconstructed
from that saved entry and the production 10-base plus resolved-intent costs, are
28, 44, 59, 75, 91, 107, 122, 138, 154, 170 (next Breath 185 is never reached).
This agrees with every observed player return and the final saved queue.

The T5 Time choice is concrete: the third Riposte adds 5 damage and 7 Block but
moves the return from the player-first tie at 91 to 96. That permits the second
boss activation and its 8-Block ground hit before another player decision.
Keeping the extra attack and defending, versus returning before Eclipse to
move again, is a real alternative. Noct's three Eclipse resolutions were
handled by extra movement, guard during the long turn, and extra movement
again; Pilgrim Light never removed their separate ground threat.

Damage accounting reconciles with the save's 131 dealt / 20 received. Of the
boss's 101 HP, cards remove 76, eight player-owned Crowncoal start ticks remove
24, and Worldheart removes 1. Five helpers account for the remaining 30: cards
19, Crowncoal entry/start Fire 10, Worldheart 1. Surface-event and status-popup
records describe the same Fire ticks and must not be counted twice. Player HP
costs are Reprise 1 + Fatigue 2 + Breath 11 + Claw 3 + lethal helper loss 3 = 20;
Defiance restores 6. The explicit enemy hits consume 4 Block, 8 Block, and 12
Stone respectively; own Fire additionally consumes 4 Block on T5 and 2 Stone
on T8. Guard granted by a hybrid attack or retained through Worldheart is still
a resource, but it is not equivalent to sacrificing a separate attack play.

The replacement helper was obscured during part of its approach. It becomes
visible in the resolution records, so `hidden_attack_damage_received=0` does
not prove its intent was available when the T10 route was selected. Its lethal
follow-up is recorded as an outcome and **not** used to justify difficulty
through hidden information. The visible boss's Claw already proves this exact
two-attack/three-step route failed; it does not prove every route failed. A guard
or extra-movement card would compete with the 12 damage and its earlier kill
window, but that counterfactual was not played.

Queue observation: the pilot briefly read a projected player `28` versus boss
`26` during animation, then received a fresh turn before Starless. There is no
captured settled rail/hover state at that instant. Production intentionally
holds rail entries during `_turn_order_animating`, and card hover adds a
projected Time delta; the known native return times reconcile with committed
card Time. A transient/hover interpretation is plausible, but the evidence
cannot identify that frame's cause. **No incorrect-preview bug is established**
from this observation. Any renewed concern needs a settled before-Pass image
with the hovered/selected card state, not a replay inferred from final HP.

Independent fun verdict: this is a material improvement over Noct01. Repeated
Eclipses now create visible choices despite automatic Light; the long-turn
guard line, helper cleanup/refund/banking, and later non-attacking movement
play give the fight more than one paid escape followed by unrestricted offense.
The chosen two-offense shallow retreat eventually fails against the visible
chase. Retain this tuning while testing the other five dragons. The result is
a viable adaptive win with one spent recovery charge, not a clean no-hit proof
or a claim of optimal play. Neither the wasted Reprise draw, skipped Riposte,
wrong Breath escape, nor hidden helper lethality counts as required tactical
cost. One strong acquired build cannot exclude every dominant strategy; this
study does not accept all six encounters or the entire branch.

Persistence boundary: normal native quit was reported as wrapper 29124 exit 0.
The persisted run remains on the prepared dragon reward, not completed ascent:
150 held/unbanked Embers, +6 milestone healing (run HP 12; frozen battle board
HP 6), Eclipse Mantle gift prepared in the profile, no extra Moltshard. There is
no `reward_claimed` event or completed-run profile receipt in this study. The
saved Crimson Draught confirms it was not consumed. Save SHA-256:
`fa480e8c389e596a149a7bca18e546fc891efbc2e9beb73c8c9497ec0f9059bb`.

Audit source: `/private/tmp/labyrinth-godot-home/dragon-pressure-noctyrax-02/Library/Application Support/Escape the Umbra Parallel dragon-pressure-noctyrax-02/analytics/events-2026-09-28.jsonl`,
191 records, combat `run_61296017_628a5764_c001`, balance
`dragon_pressure_v3`. The decisive corrections are events 108 (Eclipse Block 8),
137 (Breath HP 11), 179 (Claw Stone 12 + HP 3), 182/184 (helper lethal + Defiance),
190 (victory), 191 (prepared milestone). Read-only binary-save decoding confirms
the final HP, charge, stats, relics and reward boundary. No combat was simulated
or restarted for this audit.


## Tharokh 01 — opening verified, native control interrupted

The depth-8 balanced fixture `dragon-pressure-tharokh-01` was generated and
reload-verified successfully, manifest
`/private/tmp/dragon-pressure-native/tharokh-01.json`. Its untouched opening is
also preserved under `/private/tmp/dragon-pressure-native/tharokh-01-opening`.
The native menu displayed Continue Run, depth 8, 20/24 HP. No combat action or
Continue transition succeeded, and the run-save modification time remained
13:28:09 local. This provides no gameplay or difficulty evidence.

The pilot's app attachment took 410 seconds, then coordinate input returned
`noWindowsAvailable`; its turn subsequently ended with `Bad Request`. Root
rebound by bundle ID, used native accessibility menus to leave full screen and
select the exact window, and reset the CUA connection. Coordinate input still
failed and sent keys produced no visible transition. Native menu actions did
work. Root quit the test through its native application menu; its owner polled
runner 65622 and confirmed exit 0. A second Project Manager window appeared
under the same playtest bundle and was also closed. This is a possible app
instance mismatch, not a proven gameplay defect or lost save.

Resume the same namespace directly after the pending visual-probe batch; do
not regenerate the fixture or rewrite its hand/HP. Use the exact running bundle
ID `org.labyrinth.dragonplaytest` only after the task runner has launched, and
confirm there is one test app process. The ordinary `/Applications/Godot.app`
process predates this test and must be left alone. Root owns the next native
attempt; the independent fun reviewer remains available for its post-action
audit. The user was asked whether the test desktop is unlocked/visible while
independent renderer proof continued.


### Tharokh 01 — recovered native session; first five activations audited

Root closed the stale playtest instance and its extra Project Manager window,
then launched the unchanged namespace once. Coordinate input recovered. The
native application resumed the original save successfully; no fixture was
regenerated and no cards, HP or outcomes were changed. This does not establish
which process/control binding caused the earlier tool error.

The real opening is 20/24 HP versus **70 HP** after depth scaling. Pilgrim Boots
provide three ordinary movement points. Through five completed activations the
boss is at 25 HP and the player at 15 HP. T6 is saved midway at clock 87, player
(5,5), one play and one ordinary movement point remaining, after Warded Advance
(Time 3, Block 7). Native wrapper 33452 quit normally with exit 0 so the UI
counterplay repair below can be tested before resuming this same save.

| Activation / clock | Actual actions | Audited result |
| --- | --- | --- |
| T1 / 0→16 | Lantern Shot 4/draw 1, Time 3; ordinary (1,4)→(2,4)→(3,4); Cleaver Sweep 6, Time 4; final ordinary step (3,5). | Stonewake's held lane misses. HP 20, boss 60. This opening does allow two attacks and a short retreat; it is not evidence of a forced cost. |
| T2 / 16→36 | Shrapnel Burst targets the (3,4) spire: destroys its 4 HP and splashes boss 7, Time 6. Ordinary step into (3,4); Butcher Chop 12, Time 5; retreat to (2,4) costs both remaining movement points. | Claw's main arc misses, but the retained spires pulse for 5 HP. HP 15, boss 41. The pilot intended to continue to (1,4), overlooking the actual two-point terrain entry cost. Record the route's cost; do not claim every offense route was unsafe. |
| T3 / 36→52 | Low Sweep moves one cell to (3,4), deals 3/Root, Time 4. Cinch Straps grants 7 Block and actually draws 2, Time 3. Ordinary move to (3,5) costs 2, then (4,5) costs 1. | Breath and spire pulse both miss. HP 15, boss 38. Cinch's guard is unused: it cannot be described as a required defensive sacrifice. |
| T4 / 52→69 | Kite Bash 3/Block 6/Push 1, Time 4, shifts the boss to (4,2). Ordinary (4,5)→(5,5); Root Snare 2/Rubble/Light, Time 4; ordinary (6,5); Pass with 1 movement unused. | Leaves the radius-two spire explosion. Faultline's separate live shot consumes 5 Block, zero HP. HP 15, boss 33. Guard is useful, but it comes from an offensive hybrid rather than a separate defensive play. |
| T5 / 69→87 | Frostbolt 4 then Chain Bolt 4, Time 4+5. Ordinary (6,5)→(6,4) costs 2; Pass with 1 movement unused. | Stonewake misses and creates four new spires. HP 15, boss 25. This is another cheap setup-turn escape; Chill begins on the subsequent enemy activation, so Chain receives no +2. |

T6 revealed a genuine targeting defect before either attack card was committed:
Sidestep Slash could not target a visible adjacent Worldspine. Source inspection
found finite-Umbra shortcuts filtered through an enemies-only visibility mask,
which discarded legal visible terrain/traps. Ordinary melee/ranged already
support terrain; Cleaver Hook is specifically a push action and remains
enemy-only by existing rules. Warded Advance was then used to leave (6,4) for
(6,5), spending its two movement budget on one rubble cell; ordinary movement
from (6,5) to (5,5) likewise costs 2. The extra difficulty caused by the failed
Sidestep route is excluded from balance credit. A narrow visible-terrain shortcut
fix and regression are required before resuming. This remains an incomplete
fight and is not yet an Earth fun acceptance.

Read-only audit: isolated `analytics/events-2026-09-28.jsonl`, sequences 1–97,
combat `run_275646199_409562ce_c001`, revision `dragon_pressure_v3`. Card events
12/17, 30/32, 46/49, 64/67 and 80/81 total 45 boss damage. Event 41 records the
sole 5 HP loss; event 74 records the 5 Block shot. Events 33/50/82/97 explicitly
confirm the two-point ordinary movement entries. No future hand/deck contents
were inspected to choose the continuation.


### Tharokh 01 — completed continuation and final accounting

The narrow visible-terrain shortcut repair passed its focused positive and
baseline-negative regression and separate source review. Root resumed the
same T6 save in native wrapper 52410. The actual Sidestep click on the visible
(5,4) Worldspine then succeeded: optional movement skipped, 4 terrain damage,
one card play and 3 Time, no boss damage. The game was not regenerated and the
pilot did not inspect future hands to choose actions.

| Activation / clock | Actual continuation | Audited result |
| --- | --- | --- |
| T6 / 87→102 | After the already-spent Warded Advance and rubble step, Sidestep Slash breaks the (5,4) spire. Pass with one ordinary point unused. | Claw and the three remaining radius-one spires miss at (5,5); Warded's guard is unused. The ensuing reshuffle costs 2 Fatigue, leaving 13 HP versus 25. Clearing this spire opens the subsequent approach, but the workaround route forced by the old UI bug is excluded from difficulty credit. |
| T7 / 102→119 | Gust Step skips movement, hits for 5 including Chill and pulls the body from (4,2) to (4,3). Cleaver Hook hits for 8 and pushes it west to (3,3), Time 4+4. Ordinary (5,5)→(5,4) costs 1; Pass with two points unused. | Player returns on the clock-119 tie before the queued Bedrock Breath. The shifted body no longer occupies the held lane; the cleared spire no longer threatens this approach. This is a cheap two-offense control turn, not a paid defensive sacrifice. |
| T8 / 119 | Frostbolt hits for 6 and applies Freeze; Chain Bolt also hits for 6 against Freeze, Time 4+5. No ordinary move, potion or manual skill activation; acquired passives remain active. | Victory at 13/24 HP. The second Bedrock Breath never resolves. |

All 16 card plays account for all 70 boss HP; two destroyed spires account for
8 additional terrain HP. The player loses exactly 7 HP: the first Claw's spire
pulse 5 plus Fatigue 2. The only observed defensive absorption is Faultline's
live shot consuming 5 Block from an offensive hybrid. Neither unused guard,
the T2 movement-cost mistake, nor the T6 UI workaround establishes required
strategy. The two spire clears, displacement, ground routes and initiative tie
are real choices, but independent review must determine whether their cost is
strong enough; completion alone does not accept Earth difficulty.

Root inspected the native Dragon Vanquished transition, then quit normally;
wrapper 52410 exited 0. A leftover Project Manager under the isolated test app
was also closed. The persisted state remains on the prepared Worldheart reward,
with 110 held/unbanked Embers and +6 healing (run HP 19, frozen board HP 13), no
new Moltshard and Crimson Draught still equipped. There is no reward-claimed
receipt. Run statistics reconcile to 70 damage dealt and 7 received.

Audit source: the same isolated analytics file now has 133 records across two
sessions, combat `run_275646199_409562ce_c001`, revision `dragon_pressure_v3`.
Read-only Variant decoding confirms the final reward, one reshuffle, the
`Fatigue costs 2 health` log and final position. Save SHA-256:
`e7b69290298b3fdb5cc19c54d05d9d98ed7be7d1dc8662bff7ba9b32b8b7335d`.


### Earth01 independent verdict — one further pressure phase required

Independent reviewer `boss_fun_review/fresh_final_review` reconciled all 133
records and recommends **tune**, not difficulty acceptance. The useful hybrid
guard at Faultline and dedicated T6 spire clear are too sparse for the repeated
opportunity-cost gate. Shrapnel still attacks the boss while clearing; setup
turns and the final control/tie line remain cheap. This does not prove a universal
exploit or a correctness defect. Preserve HP, damage and the destructible field.

The bounded follow-up increases only Bedrock Breath's retained-spire radius
from 1 to 2. Claw stays radius 1; Faultline keeps radius 2 and consumes its field.
The old T3 outer corridor now needs guard, farther movement or a relevant clear.
A focused geometry/guard/clear/reload witness and fresh Earth02 native play are
required; Earth01 stays historical radius-one evidence. Quick Wits was acquired
and active throughout; references to unused skills mean no manual activation,
not absence of passive progression benefits.


### Fire01 independent verdict — retain for the tested first gate

Independent reviewer `boss_fun_review/fresh_final_review` reconciled the
143-record log, frozen reward state and 14 card plays, and recommends **retain**
for this depth-4 balanced F2 cohort. After the chosen T2 Butcher/Hook pair, the
player is at (2,3), the boss at (4,3), and northern crates (2,1)/(3,1) remain.
A read-only cardinal unit-cost endpoint upper bound gives ten cells reachable
within two ordinary points; all ten lie in the recorded Breath/heat union.
Ignoring additional entry costs makes that bound generous. It supports a real
cost on this observed line, not an engine replay of every possible card pair.
The opening live bolt and T5's useful dedicated Stone Plate add recurring
pressure. Guard, paid movement and using the boss's Fire provide viable play.

The reviewer excludes the early skipped Sidestep strike, the mistaken reading
of Root Snare as immobilization, T6 Blink necessity, T7 Root prevention and
Fatigue. A cheap T6 endpoint at (6,7) remains a plausible alternative with lost
melee access. Retention here does not accept later-gate Fire or all six bosses.

### Tharokh 02 — radius-two Breath, completed native fight

Root generated and reload-verified a fresh balanced depth-8 encounter with
`tools/inspection_fixture.py`, manifest
`/private/tmp/dragon-pressure-native/tharokh-02.json`, isolated namespace
`dragon-pressure-tharokh-02`. The build begins at 20/24 HP against 70 HP, with
17 natural cards, three ordinary movement from Pilgrim Boots, acquired Quick
Wits and one Crimson Draught. No hand, health, order or mid-fight state was
authored; future draws were not inspected before choosing actions. The only
combat change from Earth01 is Breath's retained-spire radius 1→2. The native
window used the normal production renderer at 100% UI scale; the separate
five-image Earth warning/Grimoire proof uses 1920×1080.

| Activation / clock | Actual play and choice | Audited result |
| --- | --- | --- |
| T1 / 0→16 | Lantern Shot 4 (3 Time), ordinary (1,4)→(2,4)→(3,4), Cleaver Sweep 6 (4 Time), then ordinary (3,5). | Stonewake body lane misses and raises four spires; player 20, boss 60. This setup remains a cheap offense turn. |
| T2 / 16→36 | Shrapnel Burst clears (3,4) and splashes the boss for 7 (6 Time). Step into (3,4) for one point, then deliberately choose Butcher Chop 12 (5 Time) and the known two-point retreat to (2,4). | Player accepts the telegraphed 5-HP pulse for this burst line; Claw body misses. The cost is knowingly chosen this time, not another rubble-budget mistake. It is not proof that every alternative attack pair takes damage. Player 15, boss 41. |
| T3 / 36→52 | Low Sweep moves one cell and hits for 3 (4 Time). Cinch Straps spends the other play/3 Time for 7 Block and draws two through Quick Wits. Ordinary path (3,4)→(3,5)→(4,5) costs all three points. | Body Breath misses, but the retained (3,6) spire now reaches (4,5) at radius 2. Its pulse consumes 5 Block, whereas the old radius-one fight left this guard unused. Player 15, boss 38. |
| T4 / 52→69 | Kite Bash 3/6 Block pushes the body north (4 Time); ordinary to (5,5), Root Snare 2 (4 Time), ordinary to (6,5), Pass with one point unused. | The radius-two Faultline misses and consumes three spires. The separate live shot consumes 5 Block. Root Snare creates Rubble/Light, not immobilization. Player 15, boss 33. |
| T5 / 69→87 | Frostbolt 4 and Chain Bolt 4 cost 4+5 Time; ordinary (6,5)→(6,4) costs two, then Pass. | Setup lane misses. New spires appear at (5,4), (6,3), (2,5), (7,4), constraining the nearby approaches. Ice applies Chill at the boss activation, after these two attacks. Player 15, boss 25. |
| T6 / 87→103 | Sidestep Slash skips its optional movement and spends one play/3 Time solely to destroy the visible (5,4) spire. Ordinary entry to its cleared tile costs one. Cleaver Hook (4 Time) hits the chilled boss for 8 and pushes its footprint onto the (5,1) Earth trap for 6 more. Stay at (5,4), two points unused. | The opened corridor and body displacement avoid Claw/pulse. The clear contributes no boss damage. The natural reshuffle costs 2 Fatigue; player 13, boss 11. The trap damage is real counterplay, not an extra card hit. |
| T7 / 103→118 | Lantern Shot 4 (3 Time); choose Cinch Straps (3 Time) to draw two and return after 15 total Time, one tick ahead of the next Breath. No movement. | Guard is unused and expires; do not count it as absorption. A 4-Time second play would return on the player-first clock-119 tie, so this faster draw line is chosen, not proved necessary. Player 13, boss 7. |
| T8 / 118 | Frostbolt 4 then Chain Bolt's final 3 HP; no movement, item use or manual skill activation. | Victory before the clock-119 Breath. Its second-cycle warning never resolves. |

Sixteen card receipts account for 70 boss HP including the 6 triggered-trap
HP in Cleaver Hook's receipt; direct card damage alone is 64. Two dedicated
terrain receipts total 8 spire HP (the first also splashes the boss). Player
loss is 7 HP: the consciously accepted first pulse 5 plus Fatigue 2. Useful
defense now absorbs ten damage in two consecutive phases: 5 from the newly
widened Breath pulse and 5 from Faultline's live shot. T7's unused guard,
Fatigue, and any unplayed-route assumptions do not establish difficulty.

The observed line now pays a dedicated defensive play at Breath, a dedicated
clear in the second cycle, and a chosen low-damage draw turn before the next
Breath. The existing hybrid-guard turn remains useful but is not a full lost
offensive play. This supports a meaningful bounded improvement over Earth01;
the separate independent verdict below accepts this cohort. It does not prove
that the observed route or every card choice was optimal.

Root inspected Dragon Vanquished and quit normally; wrapper 17661 exited 0.
The prepared Worldheart reward remains unclaimed with 110 held/unbanked Embers,
+6 healing (run HP 19, frozen board HP 13), no additional Moltshard, and the
Draught unused. Read-only audit preserves the save, decoded Variant and all
118 records under `/private/tmp/dragon-pressure-native/tharokh-02-complete/`.
Combat `run_128835208_4d0652c8_c001`, one session, revision `dragon_pressure_v3`.
Save SHA-256 `b2ba82b1c05c08e9fff4d586ca56d1bf6b02df12f89c99346c4767fa48df4a8a`;
JSONL SHA-256 `2f248befd07324edd963a539d05a144235ea8a38d288a290117aadd44c64bda4`.


### Earth02 independent verdict — retain for the tested second gate

Independent reviewer `boss_fun_review/fresh_final_review` reconciled all 118
records and the persisted save, including hashes, and recommends **retain**
for this depth-8 balanced F3 cohort. The newly useful dedicated guard at Breath
and independently useful hybrid guard at Faultline now provide two distinct
first-cycle defensive responses. The later dedicated clear costs a full play,
3 Time and zero boss damage before opening the approach; the subsequent
push-into-trap hit rewards that counterplay. HP/damage inflation is unnecessary.

Exclude the chosen T2 HP loss as proof all attack pairs fail, unused T7 guard,
Fatigue and the cheap setup turns from forced-cost credit. A 4-Time second card
on T7 would also win the player-first clock-119 tie, so the actual fast draw
line is not evidence of a required timing sacrifice. The terminal kill refund
is unused. No potion or Defiance was spent; Pilgrim, Quick Wits and Coil are
part of this acquired cohort. This scoped verdict does not accept the unplayed
dragons, every build, or the final exact HEAD/publication.


### Iskaldra 01 — completed native depth-12 balanced fight

The reviewer generated and reload-verified one fresh natural encounter with
`tools/inspection_fixture.py`, manifest
`/private/tmp/dragon-pressure-native/iskaldra-01.json`, namespace
`dragon-pressure-iskaldra-01`, seed 7262029. The preserved opening begins at
20/24 HP versus 72 HP, level 3, 17 natural cards, three ordinary movement,
Quick Wits and Measured Breath, no Defiance capacity, and unupgraded
Rapier / Ward-Kite / Boiled Leather / Skirmisher Boots / Cracked Lantern.
Relics are Iron Buckler, Pilgrim Boots, Stormroad Coil and Worldheart. These
are the earlier seeded gate trophies for this fixture; it has no Crowncoal
or Hourglass during the fight. Quick Wits supplies the extra draws. No hand,
health or mid-fight state was rewritten; only public UI and rules informed
live choices. Full motion and 100% UI scale were used in the native window.

| Activation / player clock | Actual play and choice | Audited result |
| --- | --- | --- |
| T1 / 0→15 | Parry Rhythm gives 5 Block and draws two for 3 Time. Sidestep Slash's enemy shortcut moves (1,4)→(3,4), hits for 5 and costs 3 Time. Pass with all three ordinary points unused. | Worldheart converts 2 Block and pulses the adjacent boss for 1. Mantle forms two layers; its shot consumes 3 Block + 2 Stoneskin. Player 20, boss 66. This is useful dedicated defense, not lost HP. |
| T2 / 15→28 | Low Sweep skips optional movement, pays one play/4 Time, deals zero HP damage into Mantle and applies Root. Ordinary retreat (3,4)→(1,3) costs all three points; Pass the second play to bank it. | One layer is broken (three damage prevented); Shatter's radius falls from 3 to 2, Root suppresses its move, and the retreat avoids it. The remaining layer is consumed. Shatter also destroys three crates and triggers two Ice traps. Player 20, boss 66. Do not claim two strips were necessary. |
| T3 / 28→52 | Riposte Lunge moves two to (3,3), deals 5 and grants 4 Block (5 Time). Needle Thrust 7 (4 Time), then the banked Shrapnel Burst 7 (6 Time). Ordinary retreat to (2,2) costs two points; picks up Jaw Trap; Pass with one point unused. | Whiteout misses. The banked play still pays its printed Time. Player 20, boss 47. This is a cheap high-offense window after the prior armor/control investment; Riposte's Block is not required for this escape. |
| T4 / 52→70 | Frostbolt 6 (4 Time) and Chain Bolt 6 (5 Time), each including +2 against Chilled. One ordinary step (2,2)→(2,1); Pass with two points unused. | The boss moves (4,3)→(4,2)→(4,1), but neither live melee nor the retained Ice field hits. Player 20, boss 35. This is a concrete two-attacks-plus-one-step counterexample for Rime. Chill initially came from trap Ice touching the large body, then persisted through the observed attacks. |
| T5 / 70→86 | One ordinary step to (3,1); Kite Bash deals 5, grants 6 Block and pushes the boss (4,1)→(5,1) (4 Time). Lantern Shot deals 6, draws Warded Advance and costs 3 Time. Remaining two movement returns to (2,2). | Mantle forms two layers. Its shot consumes 4 Block + 1 Stoneskin; player 20, boss 24, 3 Stoneskin remains. Useful hybrid defense preserves both attacks, with lower attack damage than a dedicated strike. |
| T6 / 86→98 | The natural full hand is mostly defense, with Gust out of range. Cinch Straps gives 7 Block and draws only the last card, Crimson Draught, because of the hand cap (3 Time). Hold (2,2), bank the second play, leave all movement unused. | Shatter consumes both layers and hits for 8: 5 Block + 3 Stoneskin, zero HP. Player 20, boss 24, 2 Stoneskin. This is a chosen close-position/tempo line. The guard is useful, but ordinary escape was not exhaustively excluded and its necessity is not claimed. |
| T7 / 98→119 | Gust Step's enemy shortcut moves (2,2)→(3,2), deals 5 and pulls the boss one cell to (4,1) (4 Time). Stone Plate grants 4 Stoneskin, pulses the adjacent boss for 2 through Worldheart, and draws two after reshuffling (4 Time). Frostbolt deals 6 (4 Time). One ordinary step to (3,3), Pass two points unused. | Fatigue costs 2 HP; Stone Plate was chosen to cycle a defensive hand, not required to survive Whiteout. Entry onto old Ice applies Chill, but the subsequent Whiteout misses and replaces the owned trail, clearing this tile. Player 18, boss 11, 6 Stoneskin. The one-step Whiteout escape remains cheap. |
| T8 / 119 | Chain Bolt 4 (5 Time), one ordinary step (3,3)→(3,2), Needle Thrust 7 (4 Time). | Victory before the second Rime resolves. Player 18 with 6 Stoneskin. The final step applies Chill but the kill prevents any follow-up; do not credit a second Rime escape. |

All 140 append-only records are audited. Sixteen card receipts account for
71 boss HP, including Stone Plate's 2-HP Worldheart pulse; the first end-turn
Worldheart pulse supplies the remaining 1. Direct card hits therefore total
69 HP and Worldheart pulses total 3. Eighteen incoming damage is absorbed
across three attacks (12 Block, 6 Stoneskin); no enemy or terrain HP damage is
taken. The entire 2-HP loss is the Stone Plate reshuffle. Both Crimson Draught
and the picked-up Jaw Trap remain unused, and no manual skill was activated.
Small no-op selection clicks before T3 movement consumed nothing; there was
no skipped-attack card, repeated Pass, healing or revived death to credit.

The pilot's provisional assessment is **tune a weak compound phase**, pending
the independent verdict. Mantle's live shot and the first layer/Root retreat
create real costs, and the paid armor trade is readable. They do not erase the
observed Whiteout/Rime cheap sequence: 19 damage followed by 12 damage while
spending only two then one ordinary steps, with no dedicated defensive play.
The second Whiteout is again escaped in one step; the second Shatter defense
was chosen with a defensive hand and cannot alone prove recurring forced
pressure. The win and high remaining HP are not themselves a rejection test.
Consider strengthening Rime's relationship to the existing trail, rather than
HP, raw damage or merely making Mantle soak more attacks. No mechanic changed
during this attempt. The later Rime warning was killed before resolution.

Dragon Vanquished showed Winter's Hourglass, 110 Embers, +6 actual healing and
the already-earned first-dragon Moltshard receipt. Continue was clicked once;
acquisition completed into the cleared section-III map. Native runner 28971
exited 0 after normal quit. The completed save is mode `room`, HP 24, held /
unbanked Embers 110, one Hourglass, empty pending reward and unchanged one
Moltshard. Copies and compact audit are preserved in
`/private/tmp/dragon-pressure-native/iskaldra-01-complete/`.
Save SHA-256: `472f80be1521bbbe51868788eecb0cea80e7c79f94f3b463b37b3e381e107bc1`.
JSONL SHA-256: `0830431909ca06fd70c537d24f34a922d48e5d63285bf0e2ec1fa0bb2fd3d2f3`.
Opening raw save SHA-256:
`f12348a80eb69e094b3f81ae4a8f173b8aa76efa86b6470b15419959878e966a`.

### Ice01 independent verdict — tune Rime, preserve the counterexamples

Independent reviewer `boss_fun_review/fresh_final_review` audited the completed
Ice01 records and recommends **tune**, not acceptance. Useful Mantle defense
and armor interactions do not close the repeated cheap Whiteout/Rime windows.
The reviewer also found a generous ordinary route from the T2 starting (3,4)
to (1,5), via (2,4)/(1,4), outside the original unshrunk Shatter warning. No
occupant, surface or trap blocks that recorded route. Therefore the actual
Low Sweep layer/Root plus early Pass is chosen control/tempo, not proof that
armor stripping was required to avoid damage. T6's guard is likewise useful
but not proven necessary.

The bounded trial changes only Rime pursuit from 2 to 3, retaining damage,
HP, cadence and the existing trail. It catches the observed (2,1) retreat and
the real westward (1,2) alternative. A suggested escape through (1,1) is invalid
because that unchanged tile is a pillar. Static review, focused runtime and
fresh warning proof are separate gates; a fresh Ice02 native fight is still
required before accepting the trial.

### Vaeloryx 01 — completed native depth-16 balanced fight

One fresh natural inspection fixture was generated and reload-verified before
play: `/private/tmp/dragon-pressure-native/vaeloryx-01.json`, namespace
`dragon-pressure-vaeloryx-01`, seed 7262030. Opening save and profile were
preserved under the adjacent `vaeloryx-01-opening/` directory. The build starts
20/24 HP versus 72 HP, level 3, 17 natural cards, three ordinary movement,
Quick Wits and Measured Breath, and no Defiance capacity. Equipment is
unupgraded Rapier / Ward-Kite / Boiled Leather / Trapdoor Spurs / Cracked
Lantern. Relics are Iron Buckler, Pilgrim Boots, Reinforced Shield, Stormroad
Coil, Winter's Hourglass and Crowncoal Heart. There is **no Worldheart** in
this seeded progression. Crimson Draught begins equipped. No hand, health,
order or combat state was rewritten. Only public UI and rules informed play;
full motion and 100% UI scale were used in the native window.

| Activation / player clock | Actual play and choice | Audited result |
| --- | --- | --- |
| T1 / 0→17 | Riposte Lunge moves (1,4)→(3,4), deals 5 and gives 4 Block (5 Time). Parry Rhythm adds 5 Block and draws two (3 Time). Ordinary retreat to (1,4) costs two points; one unused. | Skyhook's 6 is fully blocked and Pull ends at (2,3). Crowncoal's activation Fire deals 3; player 20, boss 64. The retreat deliberately avoids the known northern trap route; dedicated guard is useful. |
| T2 / 17→35 | Shrapnel Burst is centered on (5,3) for 7, avoiding a voluntary splash on the nearby (3,3) trap (6 Time). Lantern Shot hits for 4 and draws Frostbolt (3 Time). No ordinary movement; Pass all three points. | Fire deals 3, then Dive advances (4,3)→(3,3), triggering that Air trap for 7 boss damage. Its wake pushes the hero (2,3)→(1,3), outside the held Dive sweep. Player 20, boss 43. This observed no-movement escape is a one-shot terrain interaction, not evidence that Dive always misses. |
| T3 / 35→50 | Frostbolt 4 costs 4 Time and banks three Hourglass Time; Chain Bolt 4 spends it and costs 2. One ordinary step (1,3)→(1,2); two unused. | Both Gale's live radius-two ring and the old Dive wake miss. Gale triggers the other two Air traps and clears another crate without damaging the player. Fire deals 3 and Ice applies Chill; player 20, boss 32. Two attacks plus one step is a concrete cheap window. |
| T4 / 50→66 | Spur Trip moves (1,2)→(3,2) and deals 7 including Chill (4 Time). Cinch Straps gives 7 Block and draws two (3 Time). Ordinary route to (2,4) spends all three points and auto-ends. | Vaeloryx is immune to immobilize; no Root is applied. Eye retreats (3,3)→(3,4)→(4,4). Its held ring hits for 10: 7 Block + 3 HP. Fire deals 3; player 17, boss 22. The attempted Root and the poorly chosen ring endpoint are pilot errors, not forced damage. The 16-Time return preserves the player-first tie before Skyhook. |
| T5 / 66→83 | Ordinary step to (3,4); Needle Thrust 7 (4 Time), then Kite Bash 3/6 Block pushes the body (4,4)→(5,4) (4 Time). Remaining two ordinary points retreat to (1,4). | The long 17-Time turn spans Skyhook and Dive. Skyhook consumes all 6 Block and pulls the player to (3,4); Dive advances through (5,5)/(4,5) to (3,5), hits for 10 HP and applies Bleed 1. Player 7, boss 12. A Kite-only early Pass would return on the clock-79 player-first tie before Dive, trading the other attack for a fresh reaction. The actual hit is a chosen cadence risk, not unavoidable damage. |
| T6 / 83→99 | Gust Step moves (3,4)→(3,3), deals 3 and pulls the boss one cell to (3,4), entering Crowncoal Fire for 2 more (4 Time). Its movement and Pull each trigger Bleed 1. Choose the equipped Crimson Draught instead of another attack: +2 HP, one play/3 Time, item consumed. Ordinary retreat (3,3)→(1,3) costs two points and one further Bleed HP; one point unused. | Both Gale layers miss after the retreat. Fire deals 3 to the boss. The next natural reshuffle costs 2 Fatigue; player 4, boss 4. Healing does not cure Bleed; the status clears at turn end. The recovery is useful on this chosen line, but an alternative offensive finish was not ruled out. |
| T7 / 99 | Lantern Shot deals the final 4 for 3 Time, with no movement. | Victory before the second Eye resolves. Player 4/24; terminal kill refund is unused. |

All 95 append-only records reconcile. Thirteen card plays include the consumed
Draught. Direct card hits total 48 boss HP; Crowncoal adds 15 activation Fire
and 2 entry Fire; the triggered Air trap supplies 7, totaling 72. Card receipts
include the entry Fire and therefore total 50. No Worldheart pulse or Stoneskin
absorption occurred. Incoming attacks consume 19 Block across two Skyhooks
and Eye. Gross HP loss is 18: Eye 3, Dive 10, Bleed 3 and Fatigue 2; the item
heals 2, so 20−18+2=4. No manual skill activation or Defiance occurred.

The first-cycle Dive/Gale pair is forgiving, but its first escape consumes an
actual room trap; the later linked Skyhook/Dive does punish spending both slow
plays. The dedicated guard at Skyhook, a short guard/draw choice before Eye,
and the later early-Pass alternative are meaningful candidates for the recurring
cost criterion. They must be assessed alongside the one-step Gale window.
The mistaken Root expectation, the T4 ring route, low final HP and victory alone
are excluded from difficulty credit. The T6 healing choice is not claimed
necessary, and the second Eye was killed before resolution. Independent
review is pending; this entry does not accept all-six difficulty.

Dragon Vanquished showed Unbound Pinion, 110 Embers, +6 actual healing and the
already-earned first-dragon Moltshard. Continue was clicked once; acquisition
finished into the cleared section-IV map. Normal quit completed with runner
69661 exit 0. The final save is mode `room`, HP 10, held/unbanked Embers 110,
one newly acquired Pinion, empty pending reward, unchanged one Moltshard and
no equipped Draught. Copies plus compact audit are preserved at
`/private/tmp/dragon-pressure-native/vaeloryx-01-complete/`.
Save SHA-256: `6f83c5971311e20c6d5353c81fa9d623bdea9ea079d593fe1dbebd116c29497a`.
JSONL SHA-256: `3847490bb2f8c11cd48adb2ea054e642ff6bab8b5ff759a48ba71ab2403d769d`.
Opening raw save SHA-256:
`4402dca7b12c941e331b9af4ac6059a5448fea91637971c9ac088e5345cb085d`.

### Air01 independent verdict — retain for the tested fourth gate

Independent reviewer `boss_fun_review/fresh_final_review` reconciled all 95
records, the opening and final saves, and recommends **retain** for this
level-3, depth-16, F3 cohort. Useful dedicated guard against the first Skyhook
and the defended, short-Time Eye line provide distinct paid choices. The later
cadence is exact: enemy base 8 gives slots 12, 25, 38, 52, 66, 79 and 92. Two
4-Time cards from player clock 66 return at 83 and admit Skyhook plus Dive;
a single 4-Time card returns at 79 and wins the player-first tie. Kite-only
also defends Skyhook, while Needle-only does not. This is a concrete attack
versus reaction-time tradeoff, not credit for an unavoidable hit.

The one-step Gale escape remains real; the first Dive's trap-push benefit is
one-use, and the later Dive demonstrates that the whole cycle is not solved
by the same cheap sidestep. Exclude the immunity misread, poor Eye endpoint,
optional healing, Bleed incurred by the chosen Gust line, Fatigue and low
remaining HP from claims of forced difficulty. Retention is bounded to this
acquired build and observed natural line; it is not all-six, all-build or
final-HEAD approval. No Air tuning is justified by this study.


### Iskaldra 02 — completed native test of three-step Rime pursuit

This fresh fixture tests production `cf826c8fbc2e67929b38a2ccf68e57e97ea49cb3`:
only Rime's pursuit changed from two to three since Ice01. The generated and
reload-verified manifest is `/private/tmp/dragon-pressure-native/iskaldra-02.json`,
namespace `dragon-pressure-iskaldra-02`, seed 7262029. Generator/verifier wrapper
8762 exited 0. Opening save and profile are preserved in `iskaldra-02-opening/`.
The natural build is the same depth-12, level-3 balanced family as Ice01:
20/24 HP versus 72 HP, 17 cards, F3, Quick Wits and Measured Breath, no Defiance,
unupgraded Rapier / Ward-Kite / Boiled Leather / Skirmisher Boots / Cracked
Lantern; Iron Buckler, Pilgrim Boots, Stormroad Coil and Worldheart. There is
no Crowncoal or Hourglass during the fight. No hand, health, card order or
combat state was rewritten; live decisions used only public UI and rules.
The native window ran full motion and 100% UI scale.

| Activation / player clock | Actual play and choice | Audited result |
| --- | --- | --- |
| T1 / 0→15 | Parry Rhythm 5 Block/two draws for 3 Time; Sidestep Slash moves (1,4)→(3,4), hits 5 for 3 Time. Pass all three ordinary points. | Worldheart converts 2 Block and pulses 1. Mantle's live shot consumes 3 Block + 2 Stoneskin. Player 20, boss 66. |
| T2 / 15→28 | Low Sweep skips optional movement, removes one Mantle layer, applies Root, pays 4 Time and deals zero HP damage. Ordinary retreat to (1,3) costs all three points; bank the second play. | Root suppresses the move, reduced Shatter misses, and its remaining layer is consumed. Three crates are destroyed and two Ice traps trigger. Player 20, boss 66. As established in Ice01, this is chosen control/tempo: a different ordinary route could avoid the original full ring without stripping it. |
| T3 / 28→52 | Riposte Lunge moves to (3,3), hits 5 and gives 4 Block (5 Time); Needle 7 (4 Time); banked Shrapnel 7 (6 Time). Two ordinary points reach (2,2) and collect Jaw Trap; Pass one point. | Whiteout misses. Player 20, boss 47. This remains a cheap high-offense window, with the banked card still paying Time. The unused Block supplies 2 Stoneskin through Worldheart. |
| T4 / 52→69 | Instead of the previously successful one-step Rime retreat, ordinary move (2,2)→(3,2) puts the recovered Jaw Trap in range. Consume it for 4 damage including Chill, Root and 4 Time; Frostbolt hits 6 for 4 Time. Hold unmarked (3,2), Pass two movement points. | Immobilize suppresses pursuit; the retained Ice field misses. Player 20, boss 37. This spends a finite item and one play for control, with 2 less immediate damage than Frost + Chain. Whether a free F3 two-offense alternative still exists is the decisive independent review question, not the resulting HP. |
| T5 / 69→85 | One ordinary step to Ice (3,3) applies Chill. Kite Bash hits 5, grants 6 Block and pushes the boss (4,3)→(5,3) (4 Time). Lantern hits 6 and draws Warded Advance (3 Time). Two ordinary points retreat to (2,2), auto-ending. | Mantle's 5 is absorbed by 4 Block + 1 Stoneskin. Player 20, boss 26, 3 Stoneskin. Useful hybrid defense and displacement preserve both attacks; do not call the approach Chill forced. |
| T6 / 85→94 | The hand is mostly defensive and Mantle has two layers. One ordinary step (2,2)→(1,2) makes the full Shatter forecast Safe. Play no card; Pass both plays and two movement points, banking one play. | Shatter moves (5,3)→(4,3), misses, and consumes both layers. Player 20, boss 26. No guard or armor-strip cost is credited. Damage stalls for this chosen wait, but a defensive hand alone is not proof of forced opportunity cost. |
| T7 / 94→116 | Ordinary step back to (2,2); Gust's shortcut moves to (3,2), hits 5 and pulls the boss two cells to (2,3) (4 Time). Chain hits 6 (5 Time). Stone Plate gives 4 Stoneskin, pulses the adjacent boss for 2 through Worldheart and draws only the final Draught (4 Time). Remaining two ordinary points end at (4,1). | Entry at (4,1) applies Chill, then the new Whiteout replaces its owned trail and clears that tile; the attack misses. Its area triggers the third Ice trap. Boss 13, Stoneskin 7. The following natural turn-draw reshuffle costs 2 Fatigue, bringing HP to 18; Stone Plate itself has zero HP delta. A mistaken Cinch selection was canceled without spending a play. |
| T8 / 116→132 | Frostbolt hits 4 (4 Time). The pilot attempts to approach for Kite via (3,1), overlooking Ice under Light and applying Chill. Recover with Warded Advance (3 Time): move two to (5,1), gain 7 Block and draw Needle. One ordinary step reaches (6,1); Pass the last point. | Rime pursues (2,3)→(2,2)→(2,1)→(3,1), but neither its melee nor field hits. Player 18, boss 9, 9 Stoneskin after Worldheart conversion. Exclude the paid recovery as forced: the initial eastward route from (4,1) was cheaper. No Freeze actually applied. |
| T9 / 132 | One ordinary step (6,1)→(5,1), then Needle deals 9 including Chill for 4 Time. | Victory before the next Mantle. Player 18/24 with 9 Stoneskin; unused terminal kill refund. |

All 155 append-only events reconcile. Sixteen card plays include the consumed
Jaw Trap. Direct card hits total 69 boss HP, Stone Plate's Worldheart pulse
adds 2, and the first end-turn Worldheart pulse adds 1, totaling 72. Card
receipts therefore total 71 rather than 72. Two Mantle shots consume 10 defense
(7 Block, 3 Stoneskin); no enemy, trap, Ice or Umbra HP damage occurs. The only
2-HP loss is the natural T8 reshuffle. Crimson Draught remains held, and no
manual ability or Defiance was used. The banked plays came from Measured
Breath at T2 and T6. No claimed difficulty credit comes from the canceled
selection, the T8 approach mistake, Fatigue, high remaining HP or victory.

The first Rime differs materially from Ice01's demonstrated one-step free
escape: it was answered with a finite control item, at a small damage cost.
The second Rime actually completes its full three-step pursuit, but the pilot's
recovery line cannot establish that a paid move was necessary. Whiteout remains
an offense window and the second Shatter has a cheap ordinary retreat. Retain
versus further tuning therefore depends on the first Rime's legal F3 alternatives
and the linked cycle, not a claim that every chosen defensive card was required.
Independent difficulty review is pending; this study does not accept all six.

Dragon Vanquished displayed Winter's Hourglass, 110 Embers, +6 actual healing
and the already-earned first-dragon Moltshard. Continue was clicked once and
settled into the cleared section-III map. Native runner 96734 exited 0 after
normal quit; the runtime lease was explicitly returned to root. The final save
is mode `room`, HP 24, held/unbanked Embers 110, one Hourglass, empty pending
reward, one Moltshard, and Crimson Draught still equipped. Final save/profile,
all JSONL records and compact audit are preserved in
`/private/tmp/dragon-pressure-native/iskaldra-02-complete/`.
Save SHA-256: `7ad83f90e1fba150a435e13ff144640f3bff9524ed21c02bea5ebd6764cea9e8`.
JSONL SHA-256: `7b4cf2cd8b4f40f8dd9b02e337c633a533fd1a216f107019e87eb28f252495b6`.
Opening raw save SHA-256:
`efe610b4819bcba21337cbb9413590563cd0d02dd8252ebfdf6668f09c478851`.


### Ice02 independent verdict — retain the three-step pursuit

Independent reviewer `boss_fun_review/fresh_final_review` recommends **retain**
at production `cf826c8fbc2e67929b38a2ccf68e57e97ea49cb3`. Its reconstructed
first-Rime board admits a trap-free Move3 bite against all 15 ordinary F3
endpoints, including the six outside the recorded Ice field. A deliberately
escape-favoring Gust bound also admits a bite for all 10 legal cast/body pairs
and 136 movement allocations. This is a geometric legal-route check, not
an exhaustive engine replay or proof of every AI tie-break; it ignores LOS,
visibility and the second attack's range in the player's favor. The pillar
at (1,1) remains blocked. Even a no-card return at 61 follows Rime at 60.

The consumed Jaw Trap/Root therefore answers a real control/defense/movement
question, rather than the old free offensive retreat. Recurring useful Mantle
guard provides another paid choice. Whiteout and some Shatter states retain
cheap windows. Exclude T2's chosen layer strip, T6's freely avoided Shatter,
T8's mistaken approach/recovery, Fatigue and final HP from difficulty credit.
This is bounded depth-12 acquired-build acceptance, not all-six, all-build or
final-HEAD approval. No further Ice tuning is justified by this study.

Independent review and reproducible route bound are preserved beside the
completed evidence in `iskaldra-02-complete/`.
Review SHA-256: `a6e787f4e0f444143abc8b8b7d32360125bb3215d62b774d66bf32d9424f9715`.
Route script SHA-256: `713ea18519af899312406ae8f21061d1895fa52d6156b5a518388928b0744008`.
Route JSON SHA-256: `d7dadeadf9f6bed9939a62fa59ea60ad276ad80290641f934d941070b2beb09e`.


### Zekarion 01 — preserved native defeat, rules mistakes excluded

This fresh depth-20, level-4 balanced fixture ran unchanged production
`cf826c8fbc2e67929b38a2ccf68e57e97ea49cb3`, seed 7262044, namespace
`dragon-pressure-zekarion-01`. Generation and reload verification exited 0
(wrapper 23257); the manifest is `/private/tmp/dragon-pressure-native/zekarion-01.json`.
The natural 17-card build starts at 20/24 HP against 80 HP with F3,
unupgraded Rapier / Ward-Kite / Boiled Leather / Trapdoor Spurs / Clockwork
Arrowhead, Crimson Draught, Iron Buckler, Pilgrim Boots, Reinforced Shield and
the four earned trophies Worldheart / Crowncoal / Hourglass / Pinion. Selected
skills are Quick Wits, Measured Breath and Ghost Stride. Level 4 supplies one
normal Defiance charge; the absence of a separately selected Defiance skill
does not remove it. Opening save/profile were preserved before any combat
input. No hand, HP, draw order or save was rewritten. Decisions used public
UI/rules; logs were read only after normal quit. Native official 4.6.1 ran
Metal/Mobile, full motion and 100% UI scale in a window.

| Activation / player clock | Actual play and choice | Audited result |
| --- | --- | --- |
| T1 / 0→22 | Riposte moves (1,4)→(1,3), hits the near initial Wisp for 5 and gives 4 Block (5 Time). Ordinary steps reach (2,2). Kite hits its remaining 3 and gives 6 Block (4 Time), refunding one play for this initial room enemy. Spur Trip moves to (4,2), hits the boss for 5 and applies Root (4 Time). Last ordinary step reaches (4,1). | Skybreak's seven fixed marks miss. The surviving Wisp advances, then its Static Lash consumes 5 Block. Worldheart retained 2 Stoneskin. Player 20, boss 75. Root does not prevent a move in this nonmoving boss phase. The paid guard is useful against the helper; there is no live Skybreak bolt. |
| T2 / 22→41 | One ordinary step to (5,1); Needle hits the second initial Wisp at (6,1) for 7 (4 Time). The pilot wrongly expects Crowncoal Fire to finish its last HP despite existing Electrified ground. Two ordinary steps return via (4,1) to (4,2). Reprise spends 1 HP, gives 8 Block and draws five (6 Time). | The surviving Wisp fires twice for 5 each, with Storm Lash's live 7 between them. Those attacks consume 6 Block + 4 Stoneskin and 7 HP; the held field misses. Worldheart pulses the adjacent boss for 1. Player 12, boss 74. The failed Fire assumption and resulting helper damage are pilot errors, not required encounter cost. |
| T3 / 41→57 | Clockwork Mark kills the initial Wisp's last HP for 4 Time, refunds a play and draws zero at the full hand cap. All three ordinary steps reach (7,2). Parry Rhythm gives 5 Block and draws two (3 Time). Pass the refunded spare play, banking one through Measured Breath. | Overload's fixed field misses, but its live 6 consumes 3 Block + 2 Stoneskin and 1 HP. Player 11, boss 74. The short 16-Time turn returns before Call Wisps at 58; another card would cross it. This is a real tempo/guard choice on the played line, not proof that every alternative attack pair is unsafe. |
| T4 / 57→74 | Frostbolt deals 4 (4 Time) and banks three Hourglass Time. Two ordinary steps reach (6,3). Adjacent Spur Vault skips movement, hits 4 for discounted 1 Time and pushes the anchor (4,3)→(3,3); no trap triggers. Leather Roll deliberately skips movement, grants 6 Block and draws Gust (3 Time). Last ordinary step reaches (6,4). | Call's live 6 consumes 4 Block + 2 Stoneskin. A replacement Wisp is scheduled at 75, after the player's next activation at 74. Player 11, boss 66. The third play was banked previously; Leather is used as dedicated guard, not necessary movement. |
| T5 / 74→90 | Gust skips movement, hits 3 and pulls the boss (3,3)→(4,3), entering Ice and applying Chill before Crowncoal paints its struck bare tile (4 Time). Warded Advance moves (6,4)→(7,5) and grants 7 Block (3 Time). Pass all three ordinary points. | Skybreak misses and its owned seven-cell field replaces the prior band. Boss Fire deals 3. The replacement Wisp takes its response-window turn at 75, advances again at 83 and lands Spark Dart for 4 Block. Worldheart retains 2 Stoneskin. Natural reshuffle Fatigue costs 2 HP: player 9, boss 60. The two-cell displacement was available ordinarily; do not credit the card's movement as forced. Its defense does absorb a real helper attack. |
| T6 / 90→105, defeat | Shrapnel at (6,4) hits the Chilled boss for 9 and the Wisp for 7 (6 Time). Frostbolt kills the summoned Wisp's last HP (4 Time), banks three Hourglass Time, and correctly refunds no play. The planned third guard is unavailable. Quick Wits is then misread as a play gain: it actually discards Storm Beacon and draws Leather Roll. Ghost Stride turns the next ordinary move into Blink: (7,5)→(6,6) spends two points, then (5,6) spends the third and auto-ends. | The 19-Time turn would return at 109, admitting Lash at 90 and Overload at 105. Lash's live 7 consumes 2 Stoneskin + 5 HP; its expanded field hits for 4, triggering Defiance and restoring 6. Overload's field then deals 6 and kills before its later shot. Both boss activations take 3 Fire: final boss 45. The chosen endpoint remains in the displayed field, and the missing-refund/skill assumptions are pilot errors. |

All 148 append-only records reconcile. Fourteen card plays deal 49 actual
HP across enemies: 25 to the boss and 24 to the three Wisps. Worldheart's
one pulse and three Crowncoal Fire ticks add 10, matching the terminal 59
damage dealt. No player trap, Fire-entry, Shock or Umbra HP damage occurs.
Enemy attacks consume 22 Block and 10 Stoneskin and deal 23 HP; Reprise costs
1 and Fatigue costs 2. Defiance restores 6, so `20 − 23 − 1 − 2 + 6 = 0`.
Quick Wits and Ghost Stride are the only manually activated skills; Crimson
Draught remains unused. The last on-screen boss value 48 was before the final
Overload activation's Fire tick, not the terminal value 45.

The opening and replacement helpers create actual target/guard competition;
the replacement has a complete reaction opportunity before it acts. Guard
is consumed in several phases, and T3's early Pass plus T4's carried play
makes timing useful. Nevertheless, this attempt's loss is not difficulty
acceptance. T1/T5 Skybreak had ordinary escape routes, Reprise's long draw
turn follows a mistaken helper finish, and T6 spends both plays before trying
to solve defense. The fixed warnings did not become unfair merely because
the pilot misread rules or selected a dangerous endpoint.

Known alternatives must stay qualified: after T2 Needle, the already-held
Storm Beacon could legally finish the 1-HP Wisp instead of Reprise, trading
guard/draw/health cost for removal and an initial-enemy refund. T6's single
6-Time card plus early Pass returns on the player-first clock-105 tie before
Overload; it still must solve the intervening Lash/helper pressure. Available
guard, the held two-HP Draught, or earlier finite-skill use are choices, not
claims of a proven safe winning line. No damage or HP change is justified by
this defeat alone. The separate independent verdict follows below.

Pilot reminder for future natural attempts: summoned Wisp kills do not
refund a play; Quick Wits discards/draws without adding a play; Crowncoal does
not replace existing Electrified ground. Ghost Stride changes movement type,
not the ordinary movement allowance. Read Skybreak as fixed marked strikes,
not a live bolt; assess the helper queue separately. Check the whole next
activation interval before spending a second slow card, and choose an actual
field-free endpoint or pay defense while a play remains.

Run Ended showed three enemies killed, 59 dealt, 26 received, depth 20,
five prior rooms cleared, zero bosses defeated and zero held Embers lost.
No boss reward was granted. The terminal flow removed `current_run.save`;
the old migration backups are not final saves. The profile has one completed
result `run:0:seed:7262044`, zero Embers, one unchanged Moltshard and no trophy
award. Normal quit finished native runner 5501 with exit 0; an exposed leftover
Project Manager was separately quit, and the runtime lease returned to root.
Preserved JSONL/profile/settings/manifest, opening hashes and compact audit are
under `/private/tmp/dragon-pressure-native/zekarion-01-complete/`.
JSONL SHA-256: `975b73780844dfbb790d44a8722c4e79f91d5dfbcaaf30c26a82efd5d432cbe4`.
Final profile SHA-256: `0934a22541bc3c227baae380e5b95b75ee53db9c0ad33c1a17fcf00e4be72de0`.
Opening raw save SHA-256:
`6ef7553d2e1f6158379eeae96ce0af88ba7a980c387927ae9800cb1a4174faeb`.


### Lightning01 independent verdict — retain, with mistake-driven defeat excluded

Independent reviewer `boss_fun_review/fresh_final_review` recommends **retain**
for this depth-20, level-4 F3 cohort on production
`cf826c8fbc2e67929b38a2ccf68e57e97ea49cb3`. Repeated paid choices survive
removal of the pilot's failed helper plan: its read-only geometry check finds
all 11 ordinary T2 endpoints within a legal Move1/range3 Lash shot, and all
16 T3 endpoints within Overload's range4. T6's 11 ordinary endpoints, also
reachable with the budget-consuming Ghost Blink, remain in the held field.
These are generous static geometry bounds, not a replay of all AI choices or
card sequences. The actual consumed guard, helper removal and early-Pass
cadence support recurring pressure; Skybreak remains a cheaper escape phase.

The reviewer also identifies a concrete held-card alternative before spending
T6's two plays: Frostbolt on the already Chilled boss can Freeze it, then
Hourglass discounts Cinch Straps to 1 Time for 7 Block. The five paid Time
returns at 104 before Overload at 105; Freeze skips Lash. Even two maximum
six-damage helper attacks fit the available 9 defense plus 9 HP. This is
source-based fair-counterplay evidence, not a natively executed or guaranteed
winning line. The held Draught provides another finite choice without proving
that healing was required.

Exclude the missed Crowncoal finish, summoned-kill refund assumption, Quick
Wits misread, wasted movement expectation, chosen unsafe endpoint, Fatigue,
Defiance consumption and defeat from forced-difficulty credit. No Lightning
HP/damage retuning or extra native replay is justified by this study. This
verdict covers one acquired build and the recorded opportunities, not every
build, all possible strategies or final-HEAD approval.
The independent review and static route artifacts are preserved in
`/private/tmp/dragon-pressure-native/zekarion-01-complete/`.
Review file: `independent-difficulty-review.md`.
Review SHA-256: `efc809b7f687acb626b7f7e493cc982f53012609a472fe37ea3a5555b821daaa`.
Route script SHA-256: `7c9f2cbf0bcb8cc98e00579b380772129b74429cb003e4eaf97b7b8c47f1e584`.
Route JSON SHA-256: `5ebafe967eaf931ab9ee25129b70a60984d9dc83ddd73e5fc02c6dd258796e02`.
The artifacts bind the opening save and full JSONL hashes recorded above.
