# Dragon pressure revision: native playtests — 2026-09-28

Scope: all six dragons. This journal tests the new pressure prototype; prior wins
and the earlier fun signoff are not acceptance for this revision. No hands, draws,
HP, boss state, or outcomes are rewritten during an attempt. Reopening a paused
attempt uses its existing autosave, not fixture regeneration. Only public UI and
card rules inform decisions; JSONL is read afterward to audit the actions.

## Vyraketh 01 — first cycle, ongoing

Native Godot 4.6.1, isolated fixture `dragon-pressure-vyraketh-01`, depth 4,
balanced acquired build, natural hand. Started at 20/24 HP against 60 HP.
First four enemy activations completed; paused on player turn 5 at 8/24 HP
against 30 HP to run independent correctness regressions. This is not a win
or an accepted complete fight. The isolated window was set to Windowed and
100% UI scale for interaction; dedicated presentation proof covers 1920x1080.

| Warning | Actual decisions | Observed result |
| --- | --- | --- |
| Meteorfall | Chain Bolt 4; free movement 2 from (1,4) to (2,3); Gust Step 3 with its movement skipped, pulling the body | Avoided all seven held marks but the live bolt hit for 4. 20→16 HP; boss 60→53. Two offensive plays plus the nearby safe tile were not free. |
| Cinder Breath + heat | Butcher Chop 12; Cleaver Hook 6 and Push 1; free two-step movement around the top crates to (3,2) | Escaped the lingering heat but still took the broader held breath for 8. 16→8 HP; boss 53→35. Defending or spending a movement play was a real alternative to keeping both damage plays. |
| Crownfire + pursuit | Root Snare 2 creates Rubble/Light; Warded Advance moves 2 with Block 7; free movement 2 further around the right edge | Safe at 8 HP; boss 35→33. Four cells of travel bought a relief turn but two card plays produced only 2 damage. Root Snare was initially misread as a bind by the pilot; it is Rubble/Light, not immobilize. |
| Maw + held marks | Sidestep Slash used for Move 2; its melee target was skipped by the floor-target flow. Kite Bash 3, Block 6 and Push 1; free movement 2 away from the new position | Safe at 8 HP; boss 33→30. Displacement plus extra movement avoided the pursuit and held field. The skipped 5-damage strike is a pilot/control-path issue, not proof that the boss forced that entire damage sacrifice. |

The first two turns deliberately tried the user's rejected approach: preserve
two offensive plays and solve the warning with ordinary movement. They cost 12
HP. The following turns demonstrate two available ways to recover positioning:
extra movement and displacement. They do not yet prove the tuning across a full
fight or that every alternative is costly. A stronger pilot can retain more
attack value on the fourth turn. Continue the attempt and test the other five.

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
line, not the accidental 3-damage line. Acceptance still requires a later cycle,
element-specific decisions, and a competent adaptive win. No HP or damage
retuning follows from this pilot's partial attempt alone.

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
| T8 / 119 | Frostbolt hits for 6 and applies Freeze; Chain Bolt also hits for 6 against Freeze, Time 4+5. No ordinary move, potion or skill. | Victory at 13/24 HP. The second Bedrock Breath never resolves. |

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
