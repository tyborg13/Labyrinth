# Dragon feedback native studies — 2026-09-27

This journal records actual game input through the native Metal renderer after the
player-feedback revision. Earlier studies in `dragon_boss_revision_notes.md` are
historical evidence for the first implementation, not acceptance of this revision.
Staged probes and focused tests are separate evidence.

## Method

Use independently verified isolated saves, realistic acquired builds, the natural
shuffle, and normal game controls. Read only visible cards, previews and the clock
when choosing actions. Record mistakes and losses. Never regenerate a started
attempt to replace its draw or undo a decision. Technical restarts retain the same
autosave. For each activation, record health, location, threat/clock, the meaningful
alternatives, the chosen action and its result. Evaluate pressure, counterplay,
readability, pacing and reward flow before deciding whether to tune and replay.

## Vyraketh — first gate, attempt 01

Fixture `/private/tmp/dragon-feedback-native/vyraketh-01.json`, verified before
launch. Run ID `dragon-feedback-vyraketh-01`; depth 4, balanced, level 1,
20/24 HP. Acquired Iron Cleaver and Ward-Kite plus three starter equipment pieces,
five common spells and one rare, Iron Buckler and Crimson Draught. No upgrades.
Natural opening: Stone Plate, Chain Bolt, Cleaver Hook, Gust Step, Warded Advance.

Acceptance questions: Does damaging Meteorfall create a costly route choice while
Cinder Breath is pending? Can the player use, replace or escape the remaining fuel
before Crownfire without every turn being a free attack? Are all four actions
readable before resolution? Does the milestone feel earned and smoothly deliver
the trophy before returning to the map?

Status: native attempt completed; assessment and next iteration below.

Controls learned: select the player tile or movement counter before clicking a
reachable floor tile. Card selection then target selection is normal. When both
card plays and movement reach zero the turn automatically ends; let animation
settle and recheck the clock before clicking Pass.

- T1, clock 0, 20/24 HP, player (1,4), boss 60/60 at (4,3).
  Meteorfall at 17 declared five cells, including the player and two approach cells.
  Used two free movement to (3,4); Cleaver Hook (4 Time, 6 damage) pushed the boss
  to (5,3). Chose Warded Advance (3 Time) over another 5-Time attack so the next
  activation would occur at 16, before Meteorfall. Moved to safe (4,4), gained
  7 Block, and automatically ended. Boss 54/60.
- T2, clock 16: INPUT MISTAKE. I clicked Pass before noticing T1 had automatically
  ended, so passed the entire fresh activation. Kept the result; no reload.
  Meteorfall at 17 missed the player and left five scattered Fire tiles. HP 20/24.
- T3, clock 25, player (4,4), boss 54/60. Cinder Breath at 34 held a west-facing
  fan over the player. Fire restricted the western route and a crate blocked
  (4,5). Butcher Chop (5 Time, 12 damage), then two free movement through warned
  (4,3) to safe (4,2), then Chain Bolt (5 Time, 4 damage). Kept Sidestep Slash
  because its automatic approach would put me back in the fan. Breath missed.
  T4 at 44, HP unchanged, boss 38/60. Current danger: Crownfire at 51; (4,2)
  is safe. Thus far there are useful Time/route choices, but only one escape
  route was needed and the player has taken no damage, even after the empty pass.
  Do not infer adequate pressure from visual coverage alone.

- T4, clock 44: moved one free step to (5,2), still outside Crownfire.
  Cleaver Sweep (4 Time, 6 damage) and Sidestep Slash (3 Time, 5 damage; approach
  skipped because already adjacent), then Pass with one movement unused.
  Crownfire at 51 hit Vyraketh himself for 8 and missed the player. Boss 19/60,
  player 20/24. This was a free full-damage activation; the initial Hook push
  incidentally placed the boss in his own later fuel blast, which is a readable
  interaction but made this attempt easier.
- T5, clock 60: live Cinder Maw (Move 2, 10 Fire) due at 68. Chose Low Sweep
  (4 Time, 3 damage + Rooted), stepped one tile back to (4,2), then Lantern Shot
  (3 Time, 4 damage + draw). Turn-end forecast changed from -10 to SAFE after
  the retreat. Boss 12/60. Control now had a concrete purpose, though the first
  three enemy actions had been avoided with no health loss. Passed with one
  movement unused; checking the settled result next.

Additional control note: Cleaver Sweep is a self-centered area attack. Select it
then click the player tile; clicking the adjacent enemy only shows its preview.
The movement counter did not select movement in this native session; selecting
the player tile consistently did. Use that reliable path in later studies.

- T5 settled: Cinder Maw missed after Rooted + one-step retreat. HP 20/24.
- T6, clock 76, Meteorfall due85: Gust Step selected once then enemy clicked
  once, dealt3 and pulled2 without a second target prompt. Frostbolt dealt4.
  One free step from (4,2) to (5,2) escaped the declared Meteorfall tile; Pass
  with one movement unused. The marked area remained fixed after the pull.
  Meteorfall missed the player and left Fire; boss remained5/60.
- T7, clock93: Cinder Breath announced into the +x fan while the stationary
  player at (5,2) was already outside its area near the boss's diagonal corner.
  Shrapnel Burst killed the remaining5 HP before it resolved. Victory at20/24,
  zero damage taken, no healing or potion used. One rare spell, Shrapnel Burst, was used only for
  the final hit. Defensive cards were retained through most of the fight.
- Reward: Dragon Vanquished panel showed Crowncoal Heart, +110 Embers,
  +4 HP recovery and +1 Moltshard with first-dragon explanation. Continue
  visibly highlighted the acquired relic, then arrived on the section map.
  Sparse native screenshots do not independently establish every intermediate
  animation/fade frame; use the separately inspected timed reward probe for
  that part of acceptance. Closed the native app normally; runner exit0.

### Attempt 01 assessment and next iteration

Not accepted as sufficiently refined. The first Time choice and the Maw control
choice were useful, and fixed marks survived player displacement correctly.
However, two regular attacks plus free movement were consistently enough to
avoid the other threats. Seven activations (including one accidental empty pass)
won with no incoming damage. A skilled no-hit win is fine, but several of these
turns did not require much sacrifice, matching the user's original concern.

Read-only peer analysis after the fight confirmed the close-corner breath gap:
for a 2x2 body at(3,3) and hero(5,2), cardinal fan first rows exclude the target
in both plausible directions. The current fan flank is distance-1. Test a narrow
Vyr-only minimum flank of1: it adds the two first-row shoulders while preserving
later rows, fixed direction, cover, and displacement. In this attempt that would
also cover the old T3 two-free-step escape at(4,2), making a movement card, control,
block or a longer retreat relevant. Replay from a new declared attempt after
verification; preserve this original result and save.


## Vyraketh feedback attempt 02 — breath shoulders

Fresh verified fixture `/private/tmp/dragon-feedback-native/vyraketh-02.json`,
run `dragon-feedback-vyraketh-02`, same depth-four balanced acquired build and
same opening run-state hash as attempt01. No hand or deck manipulation. Only
Cinder Breath changes: Vyr-only `pattern_min_flank: 1` adds first-row shoulders.
Focused committed-pattern suite passed, including all four adjacent corners,
unchanged held direction, predicted/actual eight damage, and safe escape.

Status: native replay complete. Attempt01 and attempt02 saves and outcomes are
preserved. Do not regenerate either started attempt.

- T1 clock0 repeats the useful opening: move2 to(3,4), Hook6 pushes dragon
  to(5,3), Warded Advance to(4,4) for7Block. Autoend at16, HP20/24, boss54.
- T2 clock16: no accidental empty pass this time. Meteorfall due17, current
  tile safe. Butcher Chop12 + Sidestep Slash5 (approach skipped) cost8Time,
  scheduling next player at33 before breath34. Passed with both movement
  unused. Boss37, HP20/24. This is a payoff for the first turn's short-card
  initiative choice; attempt01 accidentally threw away this activation.

- T3 clock33, player(4,4), boss37 at(5,3), breath34. Two free north steps to
  (4,2) leave the forecast at -8; this was the old safe corner. Spent Gust Step
  as a floor-only move to(5,2), which completes with no extra target prompt and
  intentionally gives up its damage/pull. Forecast becomes SAFE. Chain Bolt4
  uses the other play, next player51. Boss33, HP20/24. Thus escaping now costs
  the extra movement card; alternatively Stone Plate plus Kite Bash could
  defend while keeping position. Autoend after zero plays/movement.

- T4 clock51: breath missed, HP20/24. Crownfire also due51 but player wins
  this tie. Held safe(5,2), used Cleaver Sweep6 self-target and Lantern Shot4
  (draws Patch Up), retained Root/Low Sweep rather than push Vyr away from his
  fuel. Pass with2movement unused; Crownfire self-hit8, boss15.
- T5 clock67: Cinder Maw68 forecast-10. Low Sweep3 roots, one free step to
  (4,2) escapes adjacency, Frostbolt4. ForecastSAFE, boss8. Pass with1move
  unused. Kept Shadow Step in hand rather than spend its longer escape.

- T5 settled: rooted Maw missed, HP20/24.
- T6 clock84: Meteorfall85 marked the current player tile(4,2). Root Snare
  visibly reduced boss8 to4 (observed total, not an assertion that printed base
  damage changed), then Shrapnel Burst7 killed the remaining4 before resolution.
  No movement needed because combat ended. Victory at20/24, zero incoming damage,
  no healing or potion. Reward again showed Crowncoal Heart,+110Embers,+4HP,
  +1Moltshard; Continue highlighted the trophy and reached the section map.
  Closed normally; native runner98743 exit0.

### Attempt 02 assessment

The close-corner gap is fixed in actual play: two free steps were insufficient,
so the breath forced a complete card play spent solely on movement. The bite also
required a control card and retreat. These are concrete decisions and validate the
small geometry change. This first-gate build still won without incoming damage;
Meteorfall's first miss and Crownfire's safe attack window were forgiving. The
initial push placing Vyraketh in his own fuel remains legitimate counterplay.
The replay used better inputs than attempt01 (no accidental empty turn), so the
faster six-activation victory is not a controlled difficulty comparison. Keep the
all-boss refinement goal open; assess the other identities before deciding if
Vyraketh needs another distinct threat rather than indiscriminate damage increases.


## Tharokh feedback attempt 01 — second gate

Verified fixture `/private/tmp/dragon-feedback-native/tharokh-01.json`, run
`dragon-feedback-tharokh-01`, initial run hash
`cadedc3437ae36133458850979b4630806aebb282d77442a5cf035551643081e`.
Depth8 balanced LV2 Quick Wits,20/24HP, Iron Cleaver/Ward-Kite/Boiled Leather,
Pilgrim Boots (+1 free movement), Iron Buckler, previous-gate Stormroad Coil;
ordinary six attuned spells, no upgrades, Crimson Draught. Natural hand Gust Step,
Warded Advance, Leather Roll, Cleaver Sweep (legacy needle_flurry ID), Lantern Shot.
Root owns native renderer lease; session19347. Never regenerate this started save.

Questions: do four spread spires make clearing compete with attacking, rather than
only clutter? Is the committed Claw escapable at meaningful cost, and does Faultline
force a second route/clear choice? Preserve genuine area-attack counterplay.

- T1 clock0: boss70, hero(1,4). Stonewake12 declares four spires plus melee5.
  Move2 to(3,4), Lantern Shot4 Time3 draws Cinch Straps; Cinch Straps7Block
  Time3 draws Shrapnel Burst, retaining movement cards. Pass with1free move.
  Stonewake12 resolves, block absorbs strike; T2 clock15, HP20/24,boss66.
  Early card clicks during movement animation were ignored and reissued after
  settling; no extra play or turn was spent. Read the settled cost queue, not a
  mid-animation value.
- T2 clock15: Claw29 Move2/13/Sunder1 held crescent. Butcher Chop12 Time5,
  Cleaver Sweep6 Time4 from(3,4) also destroys nearby spire(2,4) for4HP.
  Boss48. Staying now forecasts-13. Selected a three-step free route north then
  west toward(1,3); animation in progress. The path avoids the cleared Rubble,
  so do not claim breaking that spire was essential for this escape. It does
  remove one future Faultline center.
- T2 settled: Claw29 missed after the three-step route via(3,3),(2,3) to(1,3).
  HP20/24. Two spires remained visible (upper and bottom). Retrospective actual
  attack tiles confirm (2,3) was already safe: the third step was optional,
  so this escape did not require Pilgrim Boots' third movement.
- T3 clock33: free step to(2,3), Shrapnel Burst7 and Root Snare2 against boss.
  Boss39, next player52. Passed with2 free movement. Faultline47 missed and
  consumed the remaining spires; HP20/24. Both plays were safe ranged damage.
- T4 clock52: Gust Step3 directly targeted Tharokh within range, skipped movement
  and pulled him from(4,3) to(3,3); Kite Bash3/6Block pushed him back to(4,3).
  Boss33. Two free steps via(1,3) to(1,2) escaped Bedrock Breath66. Passed
  with1 movement unused; breath missed, HP20/24, next player69.
- T5 clock69: Stonewake84, four spires plus melee5. Moved one free step onto
  Rubble at(1,3), then Frostbolt4 launched from range3. Second cycle underway.
- T5 settled: Frostbolt4 then Chain Bolt4, boss25. Passed with2 movement;
  Stonewake missed, four spires formed. T6 clock87, Chilled boss.
- T6 clock87 was an empty activation: a premature repeated Pass during settling
  advanced to T7 clock96. The live notes originally missed this activation and
  called the following choices T6. This is an operator error, not a controlled
  same-turn comparison. Replay must inspect the settled scene after every Pass.
- T7 clock96: Rubble prevented reaching(3,3) on free movement alone. Took one step
  (1,3) to(2,3), spending2 movement (Rubble costs2 to leave). Sidestep Slash
  moved to(3,3), dealt7 observed vs printed5, boss18. Forecast-13 and only
  1 free movement, insufficient to walk out of Rubble. Cleaver Hook6 pushed
  Tharokh to(5,3), changed forecast toSAFE, and boss fell to4 total after all
  interactions. Analytics confirms 14 = base6 + Chilled2 + Earth trap6 at(6,4).
  Sidestep's7 similarly includes its base5 + Chilled2.
  Passed with1 unusable free movement. This turn did require a movement card
  and displacement; the earlier Ice setup enabled a strong damage interaction.

- T8 clock112: HP18/24, boss4, pending Faultline threatens9. The live note
  originally mislabeled this T7 clock103 and its pending slot as110; the
  append-only analytics instead records the kill at T8 clock112. Lantern Shot4
  kills before the burst. The2HP is the first reshuffle's Fatigue: draw pile0
  at T6, both T7 card HP deltas0, Claw target losses empty, then draw pile10 and
  HP18 at T8. The engine's first reshuffle costs2; this attribution uses those
  transitions and the rule, since there is no separate Fatigue analytics event
  and the combat log was retired on Continue. No potion/healing used. Worldheart milestone displays
  cap2,+110Embers,+6HP, first-dragon Moltshard already earned. Continue plays
  acquisition and reaches section map. Normal quit; runner19347 exit0.
- Visual defect: a WOODEN CRATE3/3HP tooltip from combat remained over the
  victory panel until pointer input. Assigned for narrow lifecycle repair.

### Attempt01 assessment

The first cycle has excessive slack: the only western spine was removed as
collateral while damaging the boss; remaining bursts missed the safe ranged lane
and consumed themselves before Breath. The second cycle was better: Rubble
made free movement insufficient, and the damage-plus-displacement card solved
an otherwise dangerous Claw. Prototype the order Stonewake→Claw→Bedrock→Faultline
with unchanged stats. Replay the same realistic cohort to see whether persistent
spires constrain the first breath escape and the new Rubble affects the burst.
This attempt is useful iteration evidence, not final acceptance.

Audit source: `dragon-feedback-tharokh-01/Library/Application Support/Escape the
Umbra Parallel dragon-feedback-tharokh-01/analytics/events-2026-09-27.jsonl` under
`/private/tmp/labyrinth-godot-home/`. Sequences74–88 establish the empty activation,
Hook components and reshuffle; sequence91 records victory at T8 clock112.


## Tharokh feedback attempt 02 — order-only replay

Verified fixture `/private/tmp/dragon-feedback-native/tharokh-02.json`, run
`dragon-feedback-tharokh-02`, initial hash identical to attempt01
`cadedc3437ae36133458850979b4630806aebb282d77442a5cf035551643081e`.
Same depth8 balanced build/hand. Native session72182. Only encounter iteration:
Stonewake → Worldspine Claw → Bedrock Breath → Faultline. Never regenerate this started save.

- T1: repeated the first opening: free2 to(3,4), Lantern Shot4, Cinch Straps
  7Block/draw. Pass; Stonewake blocked, HP20/24 boss66.
- T2 clock15: Butcher Chop12 then Cleaver Sweep6, western spire(2,4) cleared
  as collateral. Boss48. Same three-step clear route via(3,3),(2,3) to(1,3);
  the third step is optional for Claw safety. Zero moves/plays autoends.
- T3 clock33: two spires remain (upper and bottom). Bedrock Breath47 holds
  its two-wide west lane. Move1 to(2,3), Shrapnel Burst7 plus Root Snare2
  (Time6+4), boss39. Two remaining free steps via(1,3) to(1,2) escape,
  autoending. This uses the full3-movement budget but no movement card; the
  persistent distant spires do not constrain this clear route.
- T4 clock52: HP20/24, boss39; Faultline65. All3 free movement spent
  going(1,2)→(1,3)→(2,3), paying2 to leave new Rubble. Gust Step3
  pulls boss to(3,3); Kite Bash3/6Block pushes it back to(4,3).
  The western cell remains outside the two surviving spire bursts, so both
  plays are safe despite no free movement remaining. Autoend.
- T5 clock69: stayed at(2,3), Frostbolt4 plus Chain Bolt4; boss25.
  Stonewake84 missed the range2 position and raised four fresh spires.
- T6 clock87: direct approach through(3,3) was blocked by a new spire.
  Cleaver Hook was unavailable here: its underlying push action targets enemies,
  not terrain; ordinary melee can break spires. Free movement2 went to(2,4).
  Sidestep Slash then moved to(3,4), paying the second Rubble exit from its
  card movement. **Pilot error:** choosing the floor forfeited its attack;
  an enemy target from(2,4) should have preserved that attack. Do not credit
  the lost7 damage (including Chilled) as encounter pressure. Hook then dealt14
  (6base+2Chilled+6Earth-trap damage), pushed Tharokh to(5,3), and left a safe
  Claw forecast despite only1 free movement remaining. Pass once; Claw101 missed.
- T7 clock103: HP18/24 after first reshuffle Fatigue2, boss11.
  Lantern Shot4 plus Root Snare2 lowered boss to5. A Rubble exit costing2
  moved(3,4)→(3,5), clear of the held western Breath lane. Pass once.
- T8 clock119: player wins the initiative tie against Breath119. Frostbolt4
  plus Chain Bolt finishes the boss before that breath. No enemy HP damage,
  no healing or potion; unused Quick Wits. Final HP18/24 before reward.
  Worldheart panel correctly shows conversion cap2,110Embers,+6HP and prior
  first-dragon shard receipt. The stale board tooltip is absent. Continue
  animates acquisition and reaches section map. Normal quit; runner72182 exit0.

### Attempt02 analytics audit

The append-only log confirms eight actual activations, victory at T8 clock119
with18HP (sequence100), and reward healing6 immediately afterward. T6 Hook's14
damage is6 base +2 Chilled +6 Earth trap (sequences84–85). The move-only Sidestep
has selected targets `(3,4),(-1,-1)` and zero enemy damage (sequence78). First
reshuffle Fatigue2 explains the T7 health change: turn draws move the empty draw
pile to10 cards (sequences88–89), while enemy hits and player-card health deltas
report no HP loss. Unlike attempt01, this attempt has no empty extra activation.

**Audit footnote — corrections to the live interpretation:** the fourth opening
mark at `(6,3)` was not occupied by the player. Moving the hero to `(3,4)` closed
the dragon's left body exit; the two lower crates already closed down. Raising
the right-hand mark would leave only the upper exit, so the two-exit safeguard
correctly rejected it. At T3, the6-damage Earth trap at `(3,2)` was triggered by
Claw's area (sequence35), not by the dragon stepping onto it. Both actor-loss
arrays are empty: this produced Rubble, not additional boss or player damage.
The first Faultline's20 recorded cells exclude `(2,3)` (sequence59), confirming
the safe western lane despite the revised order.

Audit source: `dragon-feedback-tharokh-02/Library/Application Support/Escape the
Umbra Parallel dragon-feedback-tharokh-02/analytics/events-2026-09-27.jsonl` under
`/private/tmp/labyrinth-godot-home/`. The preserved opening save supplies the four
declared marks and crate geometry; the final save is correctly the cleared room.

### Attempt02 assessment (analytics cross-checked)

The new order makes the first Breath consume the cohort's entire3-move budget
and makes Rubble matter on the return to the boss. Pilgrim Boots earns a real
benefit here; a2-move build could not repeat that exact two-attack escape.
The second Stonewake blocks the direct western approach, making the movement
card and displacement interaction useful. Retain these positives. The first
Faultline still allows two attacks from the same cleared western corridor;
that is the narrower remaining pressure question. The misplaced Sidestep input
extends this win by a turn, so this is not a clean difficulty comparison with
attempt01 and should not be used to justify a damage increase. Ask independent
review to judge whether a small placement change would improve the break-or-
avoid choice without eliminating valid escape routes or the Boots payoff.


## Iskaldra feedback study 01 — completed and audited

Fresh verified native fixture `/private/tmp/dragon-feedback-native/iskaldra-01.json`, run `dragon-feedback-iskaldra-01`, depth 12 balanced level 3, 20/24 HP, realistic acquired Rapier/Ward Kite and prior Stormroad Coil/Worldheart trophies; Quick Wits and Measured Breath owned, no active skill or potion used. Opening run-state hash `8f7b79a0b517e88ceded8f1c17e469900de14defd832a5499a2c02d7fd5474eb`. Boss 72 HP, initial Mantle at clock 15.

- T1 clock 0: free 2 from (1,4) to (3,4), Sidestep Slash enemy shortcut for 5 (Time 3, stays adjacent), Parry Rhythm 5 Block + draw (Time 3). Pass once with 1 movement. Choosing the cheap defense instead of Chain Bolt earns the player-first tie at clock 15; Worldheart converts 2 Block to Stoneskin and deals its 1-point nearby ping (boss 66).
- T2 clock 15: Needle Thrust 7 (Time 4), free 2 to (2,3), then deliberately Pass with one unspent play. Next player clock 28 occurs before Whiteout at 30; using any second available card would surrender that reaction window. Mantle misses at range, adds one prominently visible layer. Measured Breath banks the play. Boss 59, HP20, Stoneskin2.
- T3 clock 28: Frostbolt 4 (Time4) breaks Mantle, preventing all damage; boss bar layer label disappears, no Chilled applied on nullified hit. Low Sweep enemy shortcut (Time4) moves to (3,3), deals3 and Roots (boss56), and picks up the Jaw Trap item later used at T6. Free all3 to (1,2), avoiding the visible bear trap. Pass once with 1 banked play held, next activation45 before Rime46. This preserves tempo: a third play would allow pursuit before the next activation. **Audit qualification:** the settled (1,2) tile was already outside the eventual Rime reach, so this pass is not evidence that another play would necessarily cost health. Whiteout30 resolves next.

Provisional: timing decisions are stronger than simple two-attacks/retreat. Native screenshot sampling saw Mantle badge before and after removal, but missed the transient break popup; use accepted staged proof for its legibility. Do not attribute a missed sample to absence of feedback.

- T4 clock45: free1 to(1,3) for attack range; Shrapnel Burst9 and Chain Bolt6 including Chilled, then banked third play Cinch Straps7Block. Free1 back to(1,2); **Ice costs one movement to leave** (unlike Rubble). Pass once, next68. Rime46 pursues from(4,3) to(2,3) but misses; Shatter62 radius1 also misses after the earlier Mantle removal. HP20, Stoneskin4 after Worldheart conversion; boss41.
- T5 clock68: Lantern Shot6 then Riposte Lunge enemy shortcut moves to(2,2), deals7 and grants4Block; boss28. Remain adjacent deliberately with sufficient Block/Stoneskin instead of retreating. Pass once, next85. Worldheart ping1 lowers boss27 and converts2 Block, then Mantle79 consumes remaining2Block and2Stoneskin: HP20, Stoneskin4. Mantle consumes its owned Ice and visibly reaches2layers.
- T6 clock85: the picked-up Jaw Trap is consumed, breaks the first layer with no HP damage and still applies Root; Kite Bash breaks the second, grants6Block and pushes boss to(2,4) despite the prevented damage. Free2 from(2,2) to(1,3), outside the held north breath. Pass once, next102. Both card plays were used to remove armor; the push and defense still matter, while Root expires on the stationary Whiteout and does not prevent the later Rime pursuit. Boss27. Floor clicks before selecting player movement had no effect and consumed nothing; not encounter pressure.

- T7 clock102: HP18/24 at the first reshuffle (Fatigue2, verified), boss27. Free1 to(2,3), Needle Thrust7. Warded Advance (Time3) moves2 to(4,3) and grants7Block; remaining2 free movement reaches(5,2). Zero plays/moves autoends at next118. Rime110 pursues from(2,4) to(2,2), reentering Ice and becoming Chilled, but misses the player. Worldheart raises Stoneskin to8. This turn uses a movement card plus the remaining free budget to cross the arena while retaining one attack.
- T8 clock118: Chain Bolt6, Low Sweep enemy shortcut moves1 to(4,2), deals5 and Roots, boss9. Free1 back to(5,2), Pass with2 unused movement, next136. Shatter126 is only Ring1 after both armor layers were broken and misses. HP18, Stoneskin8.
- T9 clock136: Sidestep Slash enemy shortcut moves1 to(4,2), deals7; boss2. Gust Step's enemy shortcut moves outward to(4,1), targets body tile(3,2), and deals the remaining2HP to finish the boss. Victory HP18, no healing potion or active skill; the picked-up Jaw Trap was the consumed item. Reward shows Winter's Hourglass with Time icons, storage3/cap3/minimum cost1,110Embers,+6HP, prior first-dragon shard receipt. Continue animates acquisition and returns to the section map; native runner94822 exits0 after normal quit.

### Study01 analytics audit

The preserved opening save establishes level3,20/24HP,72 boss HP and the natural
hand. Prior trophies are Stormroad Coil and Worldheart, alongside Iron Buckler
and Pilgrim Boots. The first Mantle is queued at15. The completed JSONL confirms
nine player activations at0/15/28/45/68/85/102/118/136 and18 played cards, with no
empty activation. The due enemy clocks recorded above also agree with the
depth-adjusted base11 plus each executed intent's Time. Enemy-resolution event
envelopes use the settled player activation's clock, so those envelopes alone
must not be read as the original enemy due times.

- Mantle breaks prevent4 damage from Frostbolt (sequence39),4 from Jaw Trap
  (83), and5 from Kite Bash (85):13 direct damage prevented across three layers.
  The latter two actions leave1 then0layers. Jaw Trap's play is explicitly an
  item with `consume_on_play:true` (84), following its pickup at sequence44.
- The second Mantle consumes owned Ice at(2,3) (76). Its pulse is the only
  recorded enemy hit:4damage at(2,2), absorbed by2Block and2Stoneskin with0HP
  loss (78). Root applies through the broken layers but expires on stationary
  Whiteout; the Rime paths still execute in full (68 and112).
- Whiteout paints all six western cells (48–53). After the push to(2,4), its
  held north-facing lane reanchors to six cells (94–101); five old owned Ice
  cells are removed, with the sixth already consumed as Mantle fuel (89–93).
  Both Shatters resolve only their radius-one body perimeter (69 and119).
- Initial Fatigue is2 and cycle0; the T6 draw pile has1card, then T7 draws
  report10 after reshuffle (79–80,102–103). With no card health payment, healing
  or health lost to enemy attacks, this explains the entire20→18 health change. Worldheart's
  two observed one-point pings reconcile the72 boss HP against70 total card
  damage. No Defiance or active-skill use is recorded; Measured Breath's two
  automatic banking triggers are explicit (38 and58).
- Victory at T9 clock136 with18HP is sequence125. The milestone grants110
  Embers and6 actual healing (126), followed by its durable claim (127).

Audit source: `dragon-feedback-iskaldra-01/Library/Application Support/Escape the
Umbra Parallel dragon-feedback-iskaldra-01/analytics/events-2026-09-27.jsonl` under
`/private/tmp/labyrinth-godot-home/`. The final saved room contains Winter's
Hourglass; both preserved opening snapshots retain the initial cohort.

### Study01 assessment — native observation, analytics cross-checked

Iskaldra supplies meaningful timing and armor decisions: cheap defense earns
the opening initiative tie, the T2 pass restores movement before Whiteout, and
the T3 pass preserves earlier attack access without proving necessary damage
avoidance. A later choice accepts an absorbed Mantle hit to preserve damage;
the next two attacks strip armor while retaining push and Block. Roots were
applied, but did not stop either observed Rime approach. The T7 response spends
a movement card and crosses the arena while retaining one attack; removing
armor also earns Shatter's smaller escape radius. The realistic prior Worldheart
trophy cushions one deliberate hit, and the picked-up Jaw Trap supplies one
armor-breaking card. Enemy attacks causing no health loss is consistent with
these paid costs in plays, Time, movement and defense. Retain the mechanics for
this cohort; this evidence does not justify a damage increase. It is one planned
build study, not proof that every build or alternative line has equivalent pressure.

## Tharokh — approach-flank placement, attempt 03 (completed and audited)

Fresh verified fixture `/private/tmp/dragon-feedback-native/tharokh-03.json`, run
`dragon-feedback-tharokh-03`, opening run-state hash
`fab6e1b1b585ede1e12f3c7abcf04fcfc1303424f49a59136f71c3779adc0394`.
This repeats attempt02's depth8 balanced level2 cohort:20/24HP,70 boss HP,
ordinary acquired Cleaver/Ward Kite, Iron Buckler, Pilgrim Boots and the prior
Stormroad Coil trophy. Quick Wits is owned but unused. The preserved opening
saves have the same natural five-card hand: Gust Step, Warded Advance, Leather
Roll, Cleaver Sweep and Lantern Shot. No potion, active skill or item is used.
The sole encounter change from02 is the distant first-spine placement preference;
cycle order, HP, damage, Time, count and safety checks are unchanged.

- T1 clock0: free2 from(1,4) to(3,4); Lantern Shot4 (Time3), then Cinch
  Straps7Block/draw (Time3). Pass once with1 unused movement. Stonewake15
  creates spires at(2,3),(1,6),(4,1); its5-damage strike is entirely blocked.
  Boss66, player20. The fourth declared mark(6,3) is still rejected by the
  two-body-exit safeguard after the player occupies the western approach.
- T2 clock15: Butcher Chop12 (Time5), then deliberately spend1 free movement
  to(3,3), aligning Cleaver Sweep6 (Time4) with both boss and the new(2,3)
  spine. Sweep destroys the spine and triggers the adjacent Earth trap(3,2).
  The trap's wake puts Rubble under the player at(3,3); leaving for(2,3)
  costs the remaining2 free movement. Zero moves/plays autoends to33.
  Claw29 misses and destroys the two lower crates. Boss48, player20.
- T3 clock33: Shrapnel Burst7 (Time6), Root Snare2 (Time4), boss39.
  Spend all3 free movement from(2,3), via(1,3), to(1,2), including the Rubble
  exit. Autoend to52. Bedrock Breath47 misses, covers its six western lane
  cells and leaves Rubble; four surface-created events are new because two
  covered cells already have Rubble.
- T4 clock52: spend all3 free movement to return from(1,2) to(2,3).
  Gust Step's enemy shortcut skips its Move1 because no legal Rubble exit
  fits that budget; its3-damage Pull2 still pulls the boss(4,3)→(3,3).
  Kite Bash3 and6Block (Time4 each card) pushes it back to(4,3); boss33.
  Autoend to69. Faultline65 consumes the two surviving spires and misses
  the cleared western corridor. The player earned that corridor at T2.
- T5 clock69: stay at(2,3), Frostbolt4 (Time4) then Chain Bolt4 (Time5),
  boss25; Pass once with all3 movement unused. Stonewake84 has no adjacent
  strike target, applies Chilled from the boss's Ice and raises four spires
  at(3,3),(1,5),(6,2),(5,5). The close layout is unchanged from02.
- T6 clock87: the(3,3) spine blocks direct approach. Free2 goes around to
  (2,4), then Sidestep Slash's enemy shortcut moves to(3,4) and deals7
  (5base+2Chilled, Time3). This correctly retains the attack that attempt02's
  floor target forfeited. Hook (Time4) deals8 direct plus6 Earth-trap damage,
  pushes the boss to(5,3), and leaves it at4HP. Pass once with1 unused
  movement. The displaced Claw101 misses the hero and breaks the(6,2) spine.
- T7 clock103: first-reshuffle Fatigue2 leaves18/24HP. Lantern Shot4 kills
  from(3,4), targeting(5,3). Victory is seven actual activations and13 cards,
  with no empty activation. The milestone shows Worldheart's cap2,110Embers,
  +6 actual healing and the prior first-dragon shard receipt. Continue animates
  acquisition and returns to the section map, without a stale Rubble tooltip.
  Root inspected these native transitions and quit normally; runner99388 exit0.

### Attempt03 analytics audit

The completed95-event JSONL and both preserved opening saves agree with the
cohort above. Player activations are0/15/33/52/69/87/103; all13 card plays have
zero player health delta and total70 boss HP damage, including the6-damage trap
inside Hook's14. Victory is sequence93, reward offered94, durable claim95.
The claim records24/24HP after healing; the final save is the cleared room with
Worldheart added.

- New spires appear at sequences19–21. Sweep destroys exactly one4HP spine
  (35); it creates Rubble on(2,3) (30). **Source correction:** Rubble under
  the hero at(3,3) comes from Sweep triggering the trap at(3,2), not from the
  spine collapsing onto its neighbour (31–34). The trap causes no actor HP
  loss here. The1-move alignment and subsequent2-cost exit are explicit
  player-moved events29 and36.
- Breath's six resolved cells and no target losses are sequence50. Faultline
  resolves16 cells, consumes the two remaining spires and excludes(2,3)
  (60). This is a cleared safe route, not an unhandled burst.
- Gust Step records `(-1,-1),(4,3)`,0 movement and3 damage (56), confirming
  the legal skipped movement plus retained attack. Sidestep records
  `(3,4),(4,4)`,1 movement and7 damage (79), correcting attempt02's pilot error.
  Hook records6 base damage,14 total HP damage and the6-damage trap(6,4)
  (85–86); Chilled supplies the other2 direct damage.
- Stonewake's opening strike is the only recorded enemy hit:5Block,0HP loss
  (23). Both Claws, Breath and Faultline have empty actor-loss arrays. The
  opening deck has cycle0/Fatigue2; T6 draw reaches0 and T7 reshuffles to10
  (75–76,89–90). With no health payment, healing or surface damage, first
  reshuffle explains the complete20→18 health change.

Audit source: `dragon-feedback-tharokh-03/Library/Application Support/Escape the
Umbra Parallel dragon-feedback-tharokh-03/analytics/events-2026-09-27.jsonl` under
`/private/tmp/labyrinth-godot-home/`. Enemy event envelopes use the settled player
clock; the earlier enemy due clocks above come from the native clock and fixed
cycle timing, not from treating those envelopes as enemy activation timestamps.

### Attempt03 assessment — native observation, analytics cross-checked

Retain this bounded placement refinement. The new first spine stops a stationary
boss Sweep from clearing the approach incidentally. A deliberate step earns the
combined hit; that alignment also triggers the trap wake, so escaping the held
Claw uses the cohort's whole3-move budget. Clearing the spine then earns the
safe Faultline corridor. Later terrain blocks direct approach again, and a
movement card plus a well-placed push converts the trap into damage while moving
the held Claw off the player. These are visible position, movement, defense and
control decisions without requiring unavoidable HP loss.

The encounter remains forgiving for this Cleaver/Boots/control build: all13
cards retain their useful effects, no play is spent solely to move, and
the second Faultline is never reached. The result demonstrates a cleaner paid
route than02, not a general difficulty increase or proof for a2-movement build.
This study does not justify additional HP/damage or removing the earned safe
corridor. Further tuning would need a distinct observed failure, not the high
remaining health alone. This assessment is worker evidence for the placement
change, not independent signoff on the worker's own implementation.

## Vaeloryx feedback study 01 — completed and audited

Fresh verified fixture `/private/tmp/dragon-feedback-native/vaeloryx-01.json`,
run `dragon-feedback-vaeloryx-01`, depth16 balanced level3,20/24HP against72HP.
Ordinary acquired Duelist Rapier/Ward-Kite, Boiled Leather, Trapdoor Spurs and
Cracked Lantern; Iron Buckler, Pilgrim Boots and Reinforced Shield plus the
prior Stormroad Coil, Winter's Hourglass and Crowncoal Heart trophies. Quick
Wits and Measured Breath are owned; no active skill, potion or item used so far.
Natural opening: Riposte Lunge, Parry Rhythm, Gust Step, Shrapnel Burst and
Spur Vault. Preserved opening save and profile are in
`/private/tmp/dragon-feedback-native/vaeloryx-01-opening/`; the save file's SHA256
is `0623740b73a226f288585421050eadd5ee8e58e4d89aa1c74b87d97589c13512`.

- T1 clock0: Riposte Lunge's enemy shortcut moves(1,4)→(3,4), deals5 to
  body tile(4,4), gains4Block and costs5Time. Crowncoal paints Fire on(4,4).
  Parry Rhythm gains5Block and draws2 for3Time: printed Draw1 plus Iron
  Buckler's first non-attack defense-card Draw1. Riposte contains an attack,
  so does not spend that relic trigger. Free3 moves via(2,4),(2,3) to(1,3),
  then autoends to17. The preview showed13 incoming against9Block.
- Skyhook13: Crowncoal's activation-start Fire tick deals3 to the boss,
  67→64. Skyhook deals6 and pulls the hero(1,3)→(2,3)→(3,3), triggering the
  Air trap for7. The combined13 consumes9Block and4HP: player16/24. The
  trap's east wake contacts the boss's body at(4,3), pushing its anchor to
  (5,3). This is trap displacement, not a voluntary Skyhook retreat.
  **Pilot error:** the chosen exit still allowed Pull2 to reach the trap.
- T2 clock17: Shrapnel Burst7 (Time6), Lantern Shot4 (Time3), boss53.
  Lantern draws Frostbolt and Crowncoal paints(5,3). Free1 retreats from
  (3,3) to(2,3); Pass once with2 movement unused. Dive26 first takes a
  3-damage Crowncoal tick, then follows its held path(5,3)→(5,2)→(4,2).
  Its18 resolved sweep cells miss(2,3). T3 starts35, boss50, player16.
- T3 clock35: Frostbolt4 (Time4) paints Ice on body cell(4,3) and stores3
  Time. Chain Bolt4 spends those3, paying2Time instead of5. Remain(2,3)
  and Pass once with all3 movement unused. Gale39 takes another3 Crowncoal
  damage from Fire on its other body cell(5,3), acquires Chilled from(4,3),
  and misses the hero with its close perimeter. T4 starts50, boss39, HP16.
  These are measured cost and positioning results; the saved3Time is not
  by itself proof of damage avoidance.
- T4 clock50: Spur Trip's enemy shortcut moves(2,3)→(3,3), dealing7
  (5base+2Chilled). Needle Thrust then deals9 (7base+2Chilled), for4Time
  each; boss23. Free1 advances to(3,2), changing the Eye forecast from10
  incoming to Safe. Pass once with2 movement unused.
- Eye53 resolution: Crowncoal deals3 more, boss20. The held retreat goes
  (4,2)→(4,1)→(5,1); Eye's21 resolved annulus cells miss the player. The
  area also triggers Air trap(2,2). Its east wake reaches the safe(3,2)
  tile and can push the hero right without HP damage; the event log confirms
  no actor losses. The settled next activation is T5 clock67, HP16, tied
  with the next Skyhook. The second Skyhook decision remains in progress.

### Opening audit and counterfactual qualification

JSONL sequences12–21 establish Crowncoal placement/tick, Parry's two actual
draws and the6+7 damage combination. Fire's event reports anchor(4,3) even
though the painted contact is(4,4), because surface ticks use the whole2×2
footprint. Sequence21 aggregates the direct hit and triggered trap in one
enemy-action loss entry; it is not a13-base-damage Skyhook. Staying at the
pre-move(3,4) tile also allows a pull onto(3,3), consistent with that preview.

**Code/geometry inference, not a native replay:** after the same two cards,
full3-movement routes `(3,4)→(2,4)→(1,4)→(1,5)` or
`(3,4)→(2,4)→(2,5)→(2,6)` preserve both plays and avoid the trap.
Skyhook should remain in reach, deal6 fully into9Block, then pull to(1,3)
or(2,4) respectively. Wooden crates block movement but do not block sight.
With this trap-free movement budget the player cannot leave range4, measured
from the nearest body cell; the avoidable part is the extra trap damage.
Neither route was executed and neither replaces the recorded mistake.

The first four player activations are cross-checked through sequence64 at the
settled T5 clock67 boundary. Time storage/spending is explicit at41/43; the
Chilled bonuses at53/54 agree with the status applied at46. All HP loss so far
is the opening4; no later hit or card health payment is recorded. Audit source:
`dragon-feedback-vaeloryx-01/Library/Application Support/Escape the Umbra
Parallel dragon-feedback-vaeloryx-01/analytics/events-2026-09-27.jsonl` under
`/private/tmp/labyrinth-godot-home/`. Enemy event envelopes report the settled
player clock, not the earlier enemy due clock.

### Provisional observations

Skyhook makes defense and pull destinations relevant; the opening trap mistake
should not be counted as unavoidable pressure. The first Dive needs only one
free retreat step and the following Gale allows two ranged attacks from the same
safe tile. Eye reverses that spacing decision and asks the player to advance,
but an attacking movement card plus one free step is sufficient in this cohort.
Prior trophies contribute12 Fire damage across the first cycle and a3-Time
discount. Keep these observations neutral until the second Skyhook and remaining
fight are observed; this is not a completed balance or fun judgment.

### Continuation — second Skyhook, audit through sequence69

- T5 clock67: the intended Kite Bash attack did not commit on the body click.
  Clicking the player's tile then committed only6Block for4Time, with
  `selected_targets:[(-1,-1)]` and0 enemy damage (65). **Pilot targeting
  error:** do not credit this as a necessary sacrificed attack or claim3damage.
  Pass once with1 card play and all3 movement unused to reach the player-first
  tie at80 before Dive. Measured Breath banks the unspent play (69).
- Skyhook67 deals6 into6Block, with0HP loss, and pulls the player to(4,1)
  without triggering another trap (66). The boss remains(5,1), outside the
  prior Fire, at20HP. T6 begins at80, player16/24HP. This establishes a
  successful defended hit and a paid early pass; the remaining fight is still
  in progress.

### Continuation — three-play control turn, audit through sequence87

- T6 clock80 starts with the banked third play, player(4,1), boss(5,1)/20HP.
  Cinch Straps grants7Block for3Time; only the last Crimson Draught is drawn
  (70–71). **Draw-order audit:** the hand was already7 after the turn draw
  (67), so printed Draw1 is capped. Finishing the card removes it before Iron
  Buckler grants its draw, leaving room for that one remaining card. This
  does not trigger a reshuffle during the play.
- Spur Vault targets(5,1), skips its movement component and deals6 for4Time,
  pushing the boss south to(5,2) (75). **Damage correction:** this is4 direct
  plus2 Fire-entry damage, not Chilled. The new footprint enters old Crowncoal
  Fire at(5,3) (73); afterward this turn's first qualifying hit paints new
  Fire at the original target(5,1) (74). Boss14.
- Gust Step also skips movement, deals3 for4Time, then pulls left twice,
  (5,2)→(4,2)→(3,2), boss11. Chilled is acquired during the first pull step
  when the footprint contacts Ice(4,3) (76–77); it was not present for Spur
  Vault's damage. Both cards record `(-1,-1)` for their skipped movement,
  retaining their attack and force effects without moving the hero.
- Free2 moves the hero(4,1)→(5,1)→(6,1). Crossing newly painted Fire costs2
  defense with0HP loss (78–79): Block7 becomes5. Pass once with1 movement
  unused and no card plays, next activation100. The three cards spend11Time.
- Dive80 resolves a local eight-cell perimeter from(3,2), with no movement
  event and no player hit. It triggers Air trap(3,1); the trap's southern
  wake pushes the boss to(3,3), newly entering old Fire at(4,4) for2 damage
  (80–81,84). Gale93 then takes3 activation-start Fire damage and misses the
  hero at(6,1) (82–85). Boss6. The first reshuffle draws the next two cards
  from a replenished ten-card pile (86–87), costing Fatigue2: T7 clock100
  starts at14/24HP. Neither Dive nor Gale caused that health loss.

The second Skyhook made a cheap defense plus an early pass useful, and the banked
play paid for this three-card control turn. Push/Pull also generated Fire damage
and changed where the held attack resolved. The recorded line still keeps every
offensive effect, and the missed Kite attack from T5 remains an input mistake.
These observations remain provisional until the fight ends.

### Completion — finisher and milestone, audit through sequence96

- T7 clock100: the hero starts at(6,1),14HP, boss6HP at(3,3), still
  Chilled from its footprint touching Ice(4,3). A free step to Fire(5,1)
  costs2HP,14→12 (88). **Pilot route mistake:** this health loss is separate
  from the earlier Fatigue and from the boss's attacks.
- Spur Trip's enemy shortcut selects landing(5,3) and target(3,3), moving
  two cells through(5,2) (93). Landing on old Crowncoal Fire(5,3) costs
  another2HP,12→10, before the strike (90). The strike has5 base plus2
  Chilled potential; actual HP damage is the boss's remaining6. It kills at
  T7 clock100 (91,94). This is a second Fire entry during the card, not a
  printed health cost, an additional enemy hit, or a12HP victory. The chosen
  automatic movement route must be read along with the attack outcome.
- Native Dragon Vanquished presents Unbound Pinion,110Embers,+6 actual
  healing and the previously earned first-dragon shard receipt. One Continue
  click, followed by waiting for acquisition to settle, reaches The Hollow
  Gale sectionIV map. Root inspected the transition and quit normally;
  runner57246 exits0. The reward offer and durable claim are sequences95–96.

The final save independently decodes as `mode:room` at(16,0), with16/24HP,
Unbound Pinion appended,110 held/unbanked Embers, empty pending reward and empty
combat state. Progression retains1Moltshard; this later boss awards no additional
one. The recorded milestone receipt is `run:0:seed:7262030:dragon:16,0`.

### Completed-study accounting and assessment

Seven player activations at0/17/35/50/67/80/100 contain13 played cards and no
empty activation. Final combat HP is10 before reward healing. The20→10 loss is
4 from the combined opening Skyhook/trap,2 first-reshuffle Fatigue and4 from the
two final-turn Fire entries. T6's earlier Fire crossing spends2Block and no HP.
The only other enemy hit is the second Skyhook, fully absorbed by6Block. Both
Dives, both Gales and the first Eye miss. No potion, item, active skill or Defiance
use is recorded; Measured Breath's automatic bank is the sole skill event.

Direct card damage contributes53 of72 boss HP. Crowncoal contributes19 from five
3-point activation ticks and two2-point entries. The card damage aggregates sum
to55 because Spur Vault includes its caused2-point Fire entry; do not count that
entry twice when reconciling the fight. The relic also creates both final-turn
player hazards. Winter's Hourglass saves3Time on T3. For final health, use the
explicit surface-loss payloads, `combat_ended.remaining_player_hp:10` and saved
reward state: the last movement/card analytics envelopes still carry their
pre-action14/12HP context, while their resulting losses correctly report2 each.

Retain the encounter for this cohort. The live opening tests defense and where
a pull will land; the pilot's northern retreat accepts a trap that the audited
southern route should avoid. The second Skyhook rewards one cheap defense and
an early pass: any additional paid card would lose the player-first clock80
tie before Dive. That banked play then enables the three-card control turn.
Eye reverses the usual retreat and asks the player to approach its safe center.
Push/Pull relocate the held attack and create paid Fire interactions. These are
distinct tactical questions, even when successful defense and positioning avoid
enemy health damage.

The first Dive/Gale pair remains forgiving: one retreat step followed by a
stationary ranged turn preserves full offense, and the first Eye needs only an
attacking movement card plus one free step. This late-gate build has three prior
trophies, ample defense, Boots and several force/movement cards; Crowncoal's19
damage is a substantial earned advantage. The missed Kite attack and final Fire
entries must not be credited as required encounter sacrifices. The evidence
supports readable timing, force and spacing decisions, not uniform pressure on
every activation or every build. No HP/damage increase is justified by this one
planned study; no further Vaeloryx tuning is proposed from it.

## Zekarion study 01 — completed and audited

This fresh depth-20 balanced cohort uses level 4 with Quick Wits, Measured Breath
and Ghost Stride, ordinary unupgraded acquired gear, 20/24 starting HP and an
80-HP dragon. Its four prior dragon trophies are Worldheart, Crowncoal Heart,
Winter's Hourglass and Unbound Pinion, alongside Iron Buckler, Pilgrim Boots and
Reinforced Shield. These earned advantages belong in the pressure assessment.
The 17-card deck is naturally shuffled. The visible opening hand is Crimson
Draught, Needle Thrust, Kite Bash, Spur Trip and Riposte Lunge; future draws and
unrevealed helper intents are not used for play planning or this running audit.

Fixture generation/verifier runner 87537 exits 0. Manifest:
`/private/tmp/dragon-feedback-native/zekarion-01.json`.
The preserved opening is under
`/private/tmp/dragon-feedback-native/zekarion-01-opening/`, with raw save SHA256
`712d19561576402b4c7a7290c49737aaaa6010591be108e146cd89cc955dada5`
and raw progression SHA256
`835b83ab6e37810a46e08dcf6aea5aea97ebfaeb315fe794550fb2648666b71e`.
The verifier reports state hash
`b3fb671f0d94e813f868291c3059bf64fa9ee79d9c48d76f80aca5df1d91f31b`
and progression state hash
`0064420463987e5608817d17fa40f0b33266dcfd8261b4c7f15f244719de19ec`.
Native session 38984 runs the official Metal renderer. Its append-only audit log is
`/private/tmp/labyrinth-godot-home/dragon-feedback-zekarion-01/Library/Application Support/Escape the Umbra Parallel dragon-feedback-zekarion-01/analytics/events-2026-09-27.jsonl`.

### Opening and observation boundary

At T1 clock 0 the hero is at (1,4), with no Block or Stoneskin. Zekarion's
2×2 body starts at (4,3); Skybreak declares (1,4), (1,2) and (1,6), with
scaled 8 damage and first activation 16. Two Lightning Wisps start alive. The
visible nearby Wisp at (2,3) threatens Static Lash before the dragon. Resume and
visible-hand records are sequences 5–10. The action audit follows below.

The native questions are whether fixed marks, live Lash and helper turns compete
for movement/defense/offense; whether declared Overload charges create a useful
leave/replace/defend choice; and whether replacement Wisps permit a real player
reaction before their first activation. Queue visibility, an actual helper turn,
and a helper killed before it acts are separate observations. Focused test and
renderer results are not substituted for native evidence. The completed fight,
bounded assessment and persisted reward reconciliation appear after the turn log.

### T1 — helper execution timed through Crowncoal, audited through sequence 28

- Riposte Lunge uses the nearby Wisp's enemy shortcut, moving (1,4)→(1,3),
  dealing 5, gaining 4 Block and spending 5 Time (11–12). Crowncoal paints
  Fire at the Wisp's (2,3). The pilot deliberately leaves its remaining 3 HP
  for the activation-start Fire tick rather than spending a second card on it.
- Free movement spends all 3 along (1,3)→(1,2)→(2,2)→(3,2) (14), avoiding
  that Fire. Spur Trip then uses the boss shortcut, landing at (4,2), hitting
  body cell (4,3) for 5 and applying Immobilize for 4 Time (15). Both attacks
  retain their damage; the two plays plus exhausted movement end the activation.
- **Skill attribution correction:** the golden movement path is Pilgrim Boots'
  Light, not an automatic Ghost Stride. The movement event says `move`, and
  committed skill flags/events remain empty. Ghost Stride is a manual ability;
  exhausting movement makes it unavailable and can reduce the HUD ready count
  without consuming its charge. The saved Light sources match the three free
  movement cells; attack-card movement does not receive this Boots rider.
- Worldheart converts 2 of the remaining 4 Block into 2 Stoneskin at turn end.
  Its adjacent pulse removes 1 further boss HP, so the boss is 74, not 75.
  The conversion is recorded in the saved combat log; no player HP is lost.
- Wisp #2 dies to its 3-point Fire tick at its queued clock 9, before resolving
  Static Lash (16–17,21). The other starting Wisp advances at clock 10 along
  (6,5)→(6,4)→(6,3)→(6,2) but cannot reach the hero for a hit (23).
  Skybreak resolves its three original marks at clock 16, misses, and leaves
  Electrified at (1,4), (1,2) and (1,6) (18–20,24). Immobilize expires on
  that stationary boss activation; it is not evidence of denying later Lash.
- Player T2 arrives at clock 18 with 20/24 HP and 2 Stoneskin. Reprise and
  Storm Beacon are the newly drawn, now-visible cards (25–28). Event envelopes
  use this settled clock; the enemy clocks above come from the opening queue.

This opener exercises a real helper-versus-boss allocation: a timed Crowncoal
finish saves the second card for the boss, while the three-step route avoids
both the near Fire and the fixed marks. The remaining Wisp's approach already
changes the next turn's nearby threat. It does not yet exercise Overload,
replacement timing, or a successfully resolved helper attack.

### T2 — defended Lash and a trap push, audited through sequence 44

- At clock 18, an initial Needle Thrust target attempt is out of melee range;
  the pilot notices and cancels. It commits no action. One free step moves
  (4,2)→(5,2), leaving 2 movement (29). Needle then deals 7 to Wisp #3 at
  (6,2) for 4 Time, leaving 1 HP and painting Crowncoal Fire there (30–31).
- Kite Bash targets body cell (5,3), spends 4 Time, deals 3 and pushes the
  boss anchor (4,3)→(3,3). Its footprint triggers the Lightning trap at
  (3,4) for another 7: the reported 10 total boss damage is correct, leaving
  64 HP (32–37). The trap paints four Electrified wake cells at (3,3), (4,4),
  (3,5) and (2,4). This useful trap payoff also enlarges the later charged field.
- Kite grants 9 Block, despite its printed 6: Reinforced Shield adds 3 while
  the player's existing 2 Stoneskin is present. It is a passive relic benefit,
  not a manually activated skill or unexplained bonus. The card contains an
  attack, so Iron Buckler does not add a draw.
- The pilot stays at (5,2) and passes once with 2 free movement unused,
  choosing to absorb the live Lash rather than continue walking. Worldheart
  converts 2 Block, leaving 7 Block and 4 Stoneskin. **Finisher correction:**
  its adjacent 1-damage pulse kills the 1-HP Wisp before the clock-18 Wisp turn
  (38, explicitly `source_kind:relic`, `relic_id:worldheart`). The pilot had
  expected Crowncoal to finish it, but no Fire tick or Wisp attack occurs.
- Storm Lash at clock 32 hits from boss anchor (3,3), with no approach needed.
  Its scaled 7 damage consumes exactly the remaining 7 Block; HP and Stoneskin
  are unchanged. It paints Electrified beneath the hero at (5,2) (39–40).
  Player T3 starts at clock 35 with 20/24 HP, 4 Stoneskin and boss 64 HP.
  Parry Rhythm and Spur Vault are the now-visible turn draws (41–44).

This turn uses a defensive attack and displacement to preserve offense while
accepting Lash safely. The existing Stoneskin/Shield/Worldheart combination
substantially discounts that defense and finishes the helper. Both starting
Wisps are now dead; neither has landed an attack, so later replacement pressure
and the first Overload remain necessary native observations.

### T3 — declared Overload avoided, audited through sequence 67

- Reprise at clock 35 spends 6 Time, pays exactly 1 HP (20→19) and grants
  8 Block: printed 5 plus Reinforced Shield's 3 (45–48). It draws **3 actual
  cards**, not its full printed 4 plus a bonus. With five cards initially in
  hand, two printed draws fit before the played Reprise is removed; removing
  it opens one slot for Iron Buckler's extra draw. The three resulting cards
  are Stone Plate, Clockwork Mark and Shrapnel. There is no reshuffle or Fatigue.
- One free step moves (5,2)→(5,3), leaving the charged cell beneath the hero
  and retaining 2 movement (52). Clockwork Mark hits body cell (4,3) for 5,
  spends 4 Time and paints Crowncoal Fire there (53–54). Its printed draw
  produces no card because the seven-card hand remains full until Mark is
  removed. The pilot passes once with both free movement points unused.
- Worldheart converts 2 Block into Stoneskin and pings the adjacent boss for
  1; its Stoneskin total becomes 6. The boss then loses 3 Fire HP at its
  clock-47 activation. Its health reconciles as 64−5−1−3=55. Remaining Block
  is not required to avoid this burst and expires at the next player turn.
- Overload resolves and consumes all eight announced charges at (1,2),
  (5,2), (3,3), (1,4), (2,4), (4,4), (3,5) and (1,6) (55–65). Its actual
  damage area matches the declaration, with no target losses: (5,3) is safe.
  The native case proves leaving the warning and consuming surviving charges;
  it does not exercise replacing a charge or adding one after declaration.
- T4 starts at **clock 54**, not a transient queue-frame value: 35 + base 9
  + Reprise 6 + Mark 4. Call Wisps is scheduled at 62, eight Time away.
  The hero remains at 19/24 HP with 6 Stoneskin and boss 55 HP. Only Frostbolt
  fits the turn draw because the hand has six cards before it (66–67).

The charged field now visibly cashes out, including the player's preceding Lash
tile and the trap wake. With both helpers already cleared, one free step avoids
the whole first Overload. Reprise is a chosen hand-cycling/defense investment,
not required damage avoidance; this window remains forgiving for the cohort.

### T4 — spent persistent defense and a fair replacement, audited through sequence 80

- Frostbolt targets body cell (4,3) for 4 damage and 4 Time, replacing the
  Crowncoal Fire there with Ice and banking 3 Time in Winter's Hourglass
  (68–70). Shrapnel then deals its ordinary 7 and pays 3 Time instead of 6
  (71–72). **Damage expectation correction:** freshly painted Ice does not
  immediately Chill a stationary actor; Shrapnel gets no Chilled bonus.
- The pilot remains at (5,3), passes once with all 3 movement unused, and
  deliberately spends accumulated Stoneskin on Call Wisps rather than playing
  Parry Rhythm. This preserves the second damaging card, leaving boss 44 HP.
  At clock 62 the dragon gains Chilled from Ice under its footprint (73),
  then its scaled 6-damage shot consumes exactly 6 Stoneskin with no HP loss
  (75). No turn-end conversion occurs because the player has no Block.
- Call Wisps creates replacement Wisp #4 with 8 HP. Its first activation is
  explicitly scheduled for **clock 71**, after the player's already queued
  clock 70 turn; `enemy_summon_scheduled` records `reaction_window:true` (74).
  The native turn clock exposes that one-Time difference. This exercises the
  real summon/reaction ordering, but has not yet proved a replacement attack.
- T5 begins at clock 70: 54 + base 9 + Frostbolt 4 + discounted Shrapnel 3.
  Player HP remains 19, Stoneskin is 0, and the boss remains 44 HP. Leather
  Roll and Gust Step are the actual new draws (77–80). The next Skybreak
  is queued at 78, with its new marks shown around the player.

**Coordinate audit:** the initially reported replacement position (4,2) was a
visual misread. Its saved queue position is (3,2), corroborated by the subsequent
Gust Step target and Crowncoal paint at (3,2). Gust later moves it to (4,2).
Those are distinct states, and its outcome will be audited with T5.

Call Wisps supplies a real attack alongside the replacement. Choosing two
offensive cards spends all previously earned Stoneskin here. The previous Fire
field is deliberately traded for Ice and a Time discount; its Fire tick no
longer contributes at this activation.

### T5 — both plays assigned to the replacement, audited through sequence 93

- One initial Gust Step click at the incorrectly read (4,2) commits nothing.
  The correct enemy shortcut targets Wisp #4 at (3,2), moves the hero
  (5,3)→(5,2), deals 3 for 4 Time and pulls the Wisp one cell to (4,2)
  (81–82). The second pull cell is occupied by the hero. Crowncoal paints
  the original target (3,2), so the displaced helper is no longer on that Fire.
- The pilot notices this and changes the intended follow-up from Storm Beacon
  to Spur Vault. Already adjacent, the card skips its movement, retains the
  attack, deals 4 for 4 Time and pushes the Wisp back to (3,2) (85). Fire
  entry has 2 damage potential and removes its final 1 HP (83–84). It dies
  before its scheduled first activation at 71; no Wisp attack occurs.
- Killing this summoned helper grants no ordinary death play. Neither card
  displaces one enemy two cells, so Unbound Pinion does not refill movement or
  draw. The hero has spent both plays while retaining all 3 free movement;
  the pilot passes once at (5,2). Boss HP remains 44: this reaction turn deals
  **zero boss damage** and spends 8 card Time.
- Skybreak at 78 misses the hero and paints its held cells (5,3), (5,5) and
  (5,1), destroying the 3-HP crate at (5,5) (86–89). Player T6 starts at
  clock 87, from 70 + base 9 + 8 paid Time, with 19/24 HP and no Stoneskin.
  Warded Advance and Cinch Straps are the now-visible new draws (90–93).

The replacement has a usable response window and makes the pilot choose helper
removal over boss damage. The two-card route also moves out of Skybreak while
using the newly painted Fire deliberately. That is a real opportunity cost in
this native line, without claiming it was the only viable answer or that a
replacement's own attack has been exercised.

### T6 — exact defense payment and first Fatigue, audited through sequence 101

- Storm Beacon targets body cell (4,3) for 6 Time. It deals 5, from printed
  3 plus the existing Chilled bonus of 2, then replaces Ice with Electrified
  and creates radius-2 Light (94–95). With no living helper, it produces no
  additional actor hit; the boss goes 44→39.
- Cinch Straps spends 3 Time and grants its printed 7 Block. There is no
  Reinforced Shield bonus because Stoneskin is currently zero. The empty draw
  pile reshuffles for the first time, costing 2 Fatigue HP, 19→17. Its printed
  draw and Iron Buckler draw both fit, yielding two actual cards, Gust Step
  and Storm Beacon, and filling the hand (96–98). This is not an enemy hit or
  a printed health cost.
- One free step moves (5,2)→(4,2), restoring adjacency to the dragon (99).
  The pilot passes with 2 movement unused. Worldheart converts 2 Block into
  2 Stoneskin and deals 1 adjacent damage, leaving boss 38 HP.
- Storm Lash at clock 94 consumes exactly 5 Block plus 2 Stoneskin, with no
  HP loss, and paints Electrified under the hero at (4,2) (100–101). The old
  Ice is gone, so the boss no longer retains Chilled at the settled boundary.
  T7 starts at clock 105, from 87 + base 9 + Beacon 6 + Cinch 3, with 17/24 HP
  and no defense. The full hand allows no automatic turn draw.

The chosen defense pays for the entire live shot while adjacency earns a small
Worldheart pulse. The two lost HP are explicitly the first reshuffle's Fatigue.
No active skill, potion or item has been used through this turn.

### T7 — pulled into old Fire, audited through sequence 114

- Gust Step's enemy shortcut targets body cell (4,3), moves the hero
  (4,2)→(4,1), and pulls the boss anchor (3,3)→(3,2) for 4 Time (102–103).
  Its 5 total damage is 3 direct plus 2 Fire-entry damage from the former
  Wisp's Fire at (3,2), leaving boss 33. The second pull step would overlap
  the hero, so actual displacement is one tile and does not trigger Pinion.
- Parry Rhythm spends 3 Time, grants its printed 5 Block and draws two cards,
  Needle Thrust and Riposte Lunge, through its own draw plus Iron Buckler
  (104–106). There is no reshuffle, health cost or Shield bonus this turn.
  The pilot passes with all 3 free movement unused at (4,1).
- Worldheart converts 2 Block to Stoneskin and deals 1 adjacent damage,
  leaving boss 32 before the enemy activation. Fire then ticks for 3 at
  Overload's clock 109, leaving **29 HP** (107,113). The five announced
  charges at (5,1), (4,2), (4,3), (5,3) and (5,5) resolve and are consumed;
  none hits the hero at (4,1) (108–114). Remaining Block expires, preserving
  the 2 Stoneskin for later.
- T8 begins at clock 121, from 105 + base 9 + Gust 4 + Parry 3, with 17/24 HP
  and 2 Stoneskin. The full hand receives no turn draw; Call Wisps is due 124.

The pull turns an old helper hazard into boss damage while leaving the charged
player cell. Parry exchanges the second attack for defense, draws and an earlier
return. **Timing qualification:** replacing Parry's 3 Time with Storm Beacon's
6 would return at 124, where the player wins the exact tie with Call Wisps.
This arithmetic/rules inference was not played; the actual Parry line returns
three Time earlier, but is not uniquely necessary to receive a pre-Call action.

### T8 — two attacks while holding position, audited through sequence 128

- From (4,1), Riposte Lunge targets adjacent body cell (4,2), deliberately
  skips movement, deals 5 for 5 Time and gains 7 Block: printed 4 plus
  Reinforced Shield's 3 while the existing Stoneskin remains (115–116).
  Crowncoal paints Fire at (4,2). Needle Thrust then deals 7 to that body
  cell for 4 Time (117), leaving the boss 17 before turn-end effects.
- The pilot holds position and passes with all 3 movement unused. Worldheart
  converts 2 Block and pulses for 1. At Call Wisps' clock 124, the boss takes
  one 3-point Fire activation tick despite standing over multiple Fire cells
  (118,124). Boss health reconciles as 29−5−7−1−3=13.
- Call's 6-damage shot consumes 5 Block and 1 Stoneskin, leaving 17/24 HP
  and 3 Stoneskin (125). The combined attacking defense and prior stored
  Stoneskin preserve both chosen attacks without health loss.
- Replacement Wisp #5 spawns on the Lightning trap at (3,1). Arrival triggers
  its 7 center damage, leaving the Wisp at 1/8 HP; the trap's wake paints
  Electrified at (4,1), (3,2) and (2,1), replacing the old Fire at (3,2)
  (119–122). The hero is on a wake tile, not the center, and takes no trap HP
  damage. This weakened replacement is an actual encounter outcome and must
  not be counted as a full-health helper threat.
- Its first activation is scheduled for clock 140, after the queued player
  reaction at 139 (123), and it ties the dragon's next Skybreak. T9 starts
  at clock 139, from 121 + base 9 + Riposte 5 + Needle 4. Kite Bash and Spur
  Trip are the actual new draws (127–128). The parent inspected the settled
  17-HP/3-Stoneskin, boss-13-HP state before beginning T9.

This turn again converts an earned defensive synergy into sustained boss damage.
The second replacement's trap entry sharply reduces its pressure; later outcome
analysis must preserve that fact rather than attribute its easy removal solely
to the pilot's damage allocation.

### T9 — deliberately hold the strike with defense, audited through sequence 138

- Spur Trip targets adjacent body cell (4,2), skips movement, deals 5 and
  applies Immobilize for 4 Time (129). Kite Bash follows for 4 Time, deals
  3 and gains 9 Block, from printed 6 plus Shield's 3 (130). Its downward
  Push moves the dragon anchor (3,2)→(3,3); Immobilize does not prevent
  forced movement. The boss has 5 HP and is now outside Worldheart adjacency.
- An attempted route through (4,0) is outside the arena and commits no movement.
  The hero stays at (4,1), passing with all 3 free movement unused. Worldheart
  converts 2 Block to Stoneskin, leaving 7 Block and 5 Stoneskin. Its 1-point
  pulse kills adjacent Wisp #5 at (3,1) before that helper's clock-140 first
  activation (131). The planned helper clear therefore retains both boss hits.
- Skybreak at 140 resolves its held cells (4,1), (6,1) and (2,1), including
  the hero. It consumes exactly 7 Block and 1 Stoneskin for **zero HP loss**
  (132–136). The fixed center at (4,1) and trap-wake conductor at (2,1) do
  not cause duplicate player damage. The boss's Immobilize expires on this
  stationary activation; it did not cancel the strike.
- **No Shock applies.** The replacement's pending Capacitor Arc could apply
  its conducted Shock rider, but the Wisp dies before acting. Skybreak has
  no such rider. T10 starts at clock 156, from 139 + base 9 + two 4-Time
  cards, with 17/24 HP, 4 Stoneskin and the boss at 5 HP. Shrapnel Burst and
  Clockwork Mark are actual new draws (137–138).

This is a chosen defense-and-adjacency line. The hero accepts a known strike to
preserve two attacks and an earned pulse, while the invalid route click has no
cost. The helper's prior trap damage is essential to the cheap Worldheart clear.

### T10, milestone and persisted map — audited through sequence 144

At clock 156 the player wins the exact tie with the next Storm Lash. From (4,1),
Clockwork Mark reaches body cell (4,3) at range 2 and deals the final 5 for 4 Time
(139–141). Its draw cannot fit in the full hand; the normal kill-play refund has
no further combat use. The dragon dies before Lash resolves. Victory is recorded
at **T10, clock 156, 17/24 HP**, with no remaining helper to clear (142).

The parent inspects the native Stormroad Coil milestone: +110 Embers, +6 actual
healing and the already-earned first-dragon Moltshard notice. One Continue plays
the acquisition/fade and reaches the cleared depth-20 section map. Session 38984
then exits normally with code 0. Events 143–144 contain one reward offer and one
claim for `run:0:seed:7262044:dragon:20,0`.

The post-quit save independently confirms `mode: room`, cleared boss room (20,0),
23/24 HP, Stormroad Coil present, 110 held/unbanked Embers, the same
`last_dragon_milestone`, and empty combat/pending-reward state. Run and profile
retain one Moltshard and the prior first-boss award receipt; this later gate adds
none. Profile Embers remain 0 because the 110 are still the run's unbanked wallet.
The profile analytics outbox is empty. No skill use is recorded, and the single
Defiance charge remains available.

### Completed Zek01 accounting and bounded assessment

The encounter uses **19 cards across 10 player activations**, at clocks
0, 18, 35, 54, 70, 87, 105, 121, 139 and 156. The 3 lost HP are entirely the
printed Reprise cost of 1 and first-reshuffle Fatigue of 2. There is no enemy HP
damage, potion, item play, active skill or Defiance use. Five dragon hits total
34 damage: 24 is absorbed by Block and 10 by Stoneskin. Worldheart converts 14
Block over seven turns, leaving 4 Stoneskin at victory. Other announced attacks
miss. This is meaningful defense payment, not evidence that the dragon supplied
no attacks merely because the HP total stayed high.

Boss damage reconciles to 80: 57 direct card damage, 7 from the displaced
Lightning trap, 11 Crowncoal Fire damage (three start ticks plus one entry),
and 5 Worldheart pulses. The four 8-HP Wisps account for the remaining 32 of the
save's 112 damage dealt. Four prior trophies and the Shield/Buckler/Boots package
materially help: Hourglass saves 3 Time at T4, Crowncoal times a helper kill and
reuses old Fire, and Worldheart stores defense and finishes two helpers. Pinion
does not trigger because no individual card actually displaces an enemy two
cells. These are earned cohort strengths, not a generic starter-build result.

Retain the revised encounter for this acquired depth-20 cohort. Its best native
decision is T5: noticing the displaced Wisp left its Fire changes the follow-up
card, spends both plays on the helper and produces zero boss damage while
escaping Skybreak. Live Lash/Call shots also make defense an actual expense;
T9 instead holds Skybreak to combine attacks, a pulse and stored protection.
Fixed charges make the intended safe cells legible, and replacement timing gives
the player a reaction at 70 before helper 71 and at 139 before helper 140.

The limits remain explicit. Both Overloads are escaped cheaply, and this run
does not natively exercise replacing a declared charge or adding a later charge;
focused rules tests cover those alternatives. Neither replacement attacks: the
first costs two plays to remove, while the second spawns on a 7-damage trap and
falls to a pulse. One initial Wisp advances, but no Wisp attack or conditional
Shock is witnessed. This is not proof of equivalent pressure for every build,
full-health replacement at every spawn, or a continuous descent. No further
mechanical tuning is justified by this one successful line, and no unavoidable
HP damage is added merely to lower the final health total.

## Noctyrax study 01 — completed and audited

Before fixture generation or reading its hand, the parent chooses the existing
depth-24 **skirmisher** cohort. This keeps the acquired Duelist Rapier, Trapdoor
Spurs and Clockwork Arrowhead but uses Buckler of Nails and Duelist Whetstone
instead of the balanced cohort's Ward Kite and Pilgrim Boots. Boiled Leather,
Iron Buckler and Reinforced Shield remain. The purpose is to observe native
brazier routing without passive movement Light, while preserving ordinary
available equipment and the naturally shuffled 17-card deck. No hand or deck
override is used. This is a deliberate coverage cohort, not a random-build or
continuous-descent sample.

The level-4 hero starts at 20/24 HP with Quick Wits, Measured Breath and Ghost
Stride, 2 free movement, 2 ordinary card plays and one unused Defiance charge.
All five prior dragon trophies are present: Worldheart, Crowncoal Heart,
Stormroad Coil, Winter's Hourglass and Unbound Pinion. Crimson Draught is equipped;
Storm Beacon and general skills remain available as legitimate alternatives to
braziers. Their availability must not be confused with actual use.

Fixture generation and verification complete in session 44782, exit 0. Manifest:
`/private/tmp/dragon-feedback-native/noctyrax-01.json`.
The preserved pre-action save/profile are under
`/private/tmp/dragon-feedback-native/noctyrax-01-opening/`.
Their raw SHA256 values are respectively
`7f34b628678214d6108a443c2c09eadc5e1276ce6c543c6255f2b630d48ac4fb` and
`1895f6aa5eff15208887f352892ac5bd870f4f037819b8eb9a1db50c174f7b9b`;
the audit recomputes both and matches the parent report. Canonical verifier hashes
are run `7236135ff3abb5bcb406061e2788c17f6781fac318e0eefcb822c41e7cc69dd9`
and profile `ca348b0b06d22a4e7c9c73def75af43b6dc1780d59afeb528b176be190dee092`.
Native session 72174 starts the official Godot 4.6.1 Metal renderer at 1920×1080.
The expected append-only event log is
`/private/tmp/labyrinth-godot-home/dragon-feedback-noctyrax-01/Library/Application Support/Escape the Umbra Parallel dragon-feedback-noctyrax-01/analytics/events-2026-09-27.jsonl`.

### Opening and observation boundary

At T1 clock 0 the hero is at (1,4), with no Block or Stoneskin. Noctyrax starts
at anchor (4,3), body 2×2, with 101 HP. Two 6-HP Acolytes start at (2,3) and
(6,5). The initial visible Night Coil is due at 16: 9 damage, Pull 1, held
left-facing two-wide lane covering (3,4), (3,3), (2,4), (2,3), (1,4) and
(1,3). It marks brazier #2 at (5,6) for snuffing; both that brazier and #1 at
(3,2) begin lit. Helper queue entries are 22 and 23; their unrevealed actions
are excluded from planning. There are no traps or elemental surfaces initially.
Three 3-HP crates/boxes stand at (6,2), (6,3) and (6,4).

The visible opening cards are Leather Roll, Storm Beacon, Needle Thrust,
Frostbolt and Cinch Straps. No unrevealed future draw order is inspected. The
main native questions are whether Coil's lane/snuff and the following Eclipse
give meaningful attack/movement/defense choices; whether an actual player
arrival relights an extinguished brazier; and whether replacement Acolytes give
a reaction turn while maintaining pressure. Existing Light, player-created Light
and arrival-triggered relighting are recorded separately. No native turn or
balance verdict is claimed at this opening checkpoint.

### T1 — initial helper refund buys a third attack, audited through sequence 28

- One free step moves (1,4)→(1,3), leaving 1 movement (11). Needle Thrust
  hits the initial Acolyte at (2,3) for its remaining 6 HP, from printed
  7 damage, and kills it for 4 Time (13–15). Its ordinary initial-enemy death
  refund restores the spent play: the card begins and ends with 2 plays
  remaining. This is not a relic-generated play. Crowncoal paints Fire on the
  vacated helper cell (2,3); Whetstone does not boost this non-movement card.
- Frostbolt hits body cell (4,3) for 4 and costs 4 Time, placing Ice and
  storing 3 Time in Hourglass (16–18). Storm Beacon then hits the same body
  cell for 3, spends the reserve and costs 3 rather than 6 Time (19–21).
  Beacon replaces the Ice with Electrified before the dragon's activation;
  the dragon is not Chilled and receives no Chilled damage bonus. The card's
  total actor damage is 3 to the boss only; no secondary Chain hit is recorded.
  It creates one radius-2 Light source. Boss HP is 101−4−3=94.
- The last free step moves (1,3)→(1,2), outside the held Night Coil lane (22).
  With no plays or free movement remaining, the activation ends automatically.
  Three cards cost 11 Time, so the next player activation is clock 20, from
  base 9 + Needle 4 + Frost 4 + Beacon 3.
- Night Coil resolves at its previously queued clock 16. Its six declared
  left-facing cells match its resolved cells, and its target-loss list is
  empty (24). Event 23 explicitly snuffs brazier #2 at (5,6). The parent
  observes that far refuge dark and its former helper hidden; no hidden helper
  position or action is read for this audit. There is no restoration event.
  The later public save still records that brazier unlit, while #1 stays lit.
- T2 begins with 20/24 HP, no defense, boss 94 HP and the hero at (1,2).
  Gust Step and Clockwork Mark are the actual new draws (25–28). The audit
  stops at this settled boundary rather than using later turns to plan it.

The opening permits a helper kill, two boss attacks and full lane escape with
the cohort's two free moves. The extra offense is earned by the initial kill
refund and Hourglass sequencing. Snuffing is visibly separate from the upcoming
Eclipse, and no automatic relighting occurs; player-arrival relighting has not
yet been exercised.

### T2 — refuge offense and the first replacement, audited through sequence 47

- Both free moves take (1,2)→(2,2)→(3,2), the already-lit near brazier (29–30).
  This is refuge routing, **not** an extinguished brazier relight. Clockwork
  Mark then targets body cell (4,3), deals 5 for 4 Time and draws Spike Check
  (31–32). The existing Electrified target prevents Crowncoal Fire placement.
- Gust Step targets the same body cell, skips the player's movement and pulls
  the dragon anchor two actual cells (4,3)→(2,3) for 4 Time (34–36). Direct
  damage is 5: printed 3 plus Whetstone's 2 for this turn's first qualifying
  movement-and-attack card. That condition uses the card's action types even
  when the movement step is skipped. Entering the old helper's Fire at (2,3)
  adds 2, giving 7 total card-attributed damage.
- The two-cell enemy displacement triggers Unbound Pinion. It refills the
  spent free-movement allowance to capacity 2 and draws Nail Parry (35–36).
  The pilot elects to stay at (3,2) and passes those two restored moves.
  Neither an extra card play nor an active skill is used.
- At Eclipse's queued clock 32, the boss takes 3 Fire damage (37,39), then
  Eclipse checks current Light. The hero on the lit brazier takes no hit
  (41). There is no new snuff or restoration event, and the far brazier remains
  unlit. Boss health reconciles as 94−5−7−3=79.
- Eclipse replaces the killed helper with visible summoned Acolyte #4, 6 HP
  at (2,2). Its first turn is scheduled for **52**, after the player's next
  activation at **37**, providing 15 Time to respond (38,42). The ordinary
  summon delay already leaves this window; it is not a same-clock arrival
  attack. No hidden original helper position or intent is exposed by the audit.
- T3 begins at clock 37 = 20 + base 9 + Mark 4 + Gust 4, with the hero still
  20/24 HP at (3,2), no defense, and the boss at 79 HP. Parry Rhythm and
  Spur Vault are the actual new draws (43–47).

The first Eclipse allows offense from an existing refuge and rewards the
two-cell pull with old Fire damage plus Pinion resources. It introduces a nearby
replacement with a visible reaction window. This is a forgiving opening for the
acquired control build; arrival-triggered relighting and the replacement's own
pressure still need actual play evidence.

### T3 — Push instead of root, helper shot defended, audited through sequence 61

- Nail Parry targets body cell (3,3), deals 3, grants 5 Block and costs 3
  Time (48–49). Its Pierce/Sunder have no extra defense to remove here.
  Crowncoal paints Fire at that contact tile. Spur Vault then skips player
  movement, deals 6 from printed 4 plus Whetstone's 2, and costs 4 Time (50).
- **Pilot rules correction:** Spur Vault applies **Push 1**, not Immobilize.
  It moves the dragon anchor (2,3)→(2,4), with no root event. Spur Trip is
  the distinct card that immobilizes. The later dragon movement is therefore
  valid; this turn does not demonstrate an Immobilize failure.
- The hero spends both free moves along (3,2)→(4,2)→(5,2), automatically
  ending the activation (51–52). Worldheart converts 2 of Nail Parry's Block,
  leaving 3 Block and 2 Stoneskin. The displaced dragon is outside pulse range.
- Void Claw at clock 48 advances its anchor (2,4)→(3,4)→(3,3). The final
  step enters the player's Fire and deals 2 to the boss (53,56). From this
  anchor its nearest body cell remains Manhattan distance 2 from the hero at
  (5,2), so no melee attack follows. This explains the extra boss damage:
  79−Nail 3−Vault 6−Fire 2=68, with no Worldheart damage that turn.
- The now-visible Acolyte at (5,3) fires for 4, consuming 3 Block and 1
  Stoneskin, with zero HP loss (55). **Identity correction:** this is the
  original second Acolyte, not the newly summoned one. The replacement receives
  its scheduled first activation at 52 and performs movement without an
  attack (57). Its destination is now hidden and is excluded from this audit.
  This is actual native activation evidence, separately from a damaging attack.
- T4 begins at clock **53**, from 37 + base 9 + Nail 3 + Vault 4, with hero
  20/24 HP and 1 Stoneskin at (5,2), boss 68 HP at (3,3). Shrapnel Burst and
  Stone Plate are the actual new draws (58–61).

Defense pays for a real helper shot while displacement and both free steps deny
the live Claw. The pilot's intended root was a card-rule mix-up; the successful
escape came from Push and movement. The helper identities and damage source are
corrected explicitly rather than attributing the protection or pressure to the
wrong actor.

### T4 — original helper kill and saved defense, audited through sequence 72

- Shrapnel Burst targets the visible original second Acolyte at (5,3) for
  6 Time. Its cross removes that helper's 6 HP, deals 7 to the boss and
  destroys a 3-HP crate (62–63). The initial-enemy death refund restores
  the play, leaving 2 available; this is distinct from a summoned-helper kill.
- One free step moves (5,2)→(4,2) (64). Spike Check then deals 3 to body
  cell (4,3), grants 7 Block (printed 4 plus Reinforced Shield's 3 because
  1 Stoneskin remains), applies Bleed 1 and pushes the anchor (3,3)→(3,4)
  for 4 Time (65). The resulting public footprint is (3,4), (4,4), (3,5),
  (4,5). This push moves the body off its previous Fire.
- Stone Plate spends 4 Time and grants 4 Stoneskin. It draws **two** actual
  cards, its printed draw plus Iron Buckler's first qualifying defense-card
  draw (66–68); Reprise is among those committed draws. No reshuffle or
  health cost occurs. The 2-point Worldheart pulse from that Stoneskin gain
  cannot reach the now-displaced dragon, so the card reports zero damage.
- The last free move returns (4,2)→(5,2), ending the activation (69).
  Worldheart converts 2 Block into Stoneskin but its 1-point pulse also has
  no adjacent target. Stoneskin is now 1 + Plate 4 + conversion 2 = **7**;
  5 Block remains temporarily.
- Starless Breath at clock 63 keeps its held upward direction from the
  displaced anchor. Its resolved two-wide lane is columns 3–4, rows 1–3,
  which excludes the hero at (5,2). Bleed deals 1 when that attack resolves
  (70–71). No Fire start tick occurs because the push removed the body from
  Fire. There is no player damage or defense consumption before the next
  activation; unused Block expires. Hidden helper position/action details
  are excluded from the audit.
- T5 starts at clock **76**, from 53 + base 9 + Shrapnel 6 + Spike 4 + Plate 4,
  with hero 20/24 HP, 7 Stoneskin and zero Block at (5,2). Boss HP is
  68−Shrapnel 7−Spike 3−Bleed 1 = **57** at anchor (3,4), with Bleed spent.
  No next-hand contents are reported. Darkness is back to the base Heart
  stage with no active Eclipse duration or card-created Light. The near
  brazier remains lit and the far brazier unlit; no relight event occurs.

The extra kill play lets the pilot bank defense while damaging and displacing
the boss. That stored defense is not credited as an absorbed hit this turn:
the last movement step avoids Breath, and all 7 Stoneskin survive to T5.

### T5 — approach the dark refuge before Eclipse, audited through sequence 91

- One free step moves (5,2)→(5,3) (79). Riposte Lunge targets body cell
  (4,4), moves the hero to (5,4), deals 7 (printed 5 plus Whetstone 2),
  gains 7 Block (printed 4 plus Shield 3) and costs 5 Time (80–81).
  Crowncoal paints Fire on that body cell.
- Spur Trip then skips its movement, hits the adjacent same cell for 5,
  applies Immobilize and costs 4 Time (82). Whetstone has already triggered
  on Riposte, so this second movement-and-attack card receives no bonus.
  The last free step moves (5,4)→(5,5), automatically ending the turn (83).
- The final position remains adjacent to the boss. Worldheart converts 2
  Block into Stoneskin and pulses for 1: boss 57−7−5−1=44; player Stoneskin
  rises from 7 to 9, leaving 5 temporary Block.
- At Night Coil's clock 79, Fire deals 3 to the boss, leaving **41 HP**
  (84,86). The upward held lane misses the hero at (5,5) (88). Coil snuffs
  near brazier #1 at (3,2) (85), so **both braziers are unlit** at the next
  activation's opening. The previous far snuff has not reset automatically.
  Immobilize expires on this stationary action (87); it does not prevent
  movement or an attack here and is not credited as meaningful control.
- T6 starts at clock **94**, from 76 + base 9 + Riposte 5 + Trip 4, one
  Time before the queued Eclipse at 95. No enemy damage or defense loss
  occurs on the transition, and unused Block expires. The two turn draws
  trigger the first deck reshuffle: the public combat log explicitly says
  **“Fatigue costs 2 health.”** The resulting state is **18/24 HP and 9
  Stoneskin**, not 20 HP (90–91; new card identities deliberately omitted).

The route keeps two attacks while positioning one step from the extinguished
far brazier. Snuffing the other refuge before Eclipse makes that next arrival
an actual prospective choice. This audit ends at the T6 opening, before the
subsequent movement or relighting action.

### T6 — actual arrival relights the refuge, audited through sequence 101

- From (5,5), the first free step enters the extinguished far brazier at
  (5,6). Event **92** explicitly records `dragon_light_restored`, brazier #2,
  `trigger: player_arrival`; movement event 93 confirms the arrival. The
  parent observes the plate change to lit radius-2 refuge text and the
  turn-end forecast change from **−9 Stoneskin / −2 HP** to **Safe**. This
  is native player-triggered relighting, distinct from an already-lit refuge,
  a Storm Beacon, or an automatic boss reset.
- The second free step returns (5,6)→(5,5), staying in the restored Light
  while retaining melee access (94). Both moves are ordinary `move` actions.
  **Skill attribution:** Ghost Stride is the manual next-movement Blink 2
  ability, remains unused, and provides no Time discount. Nail Parry's next
  play costs its ordinary printed **3 Time**; empty skill flags/events agree.
- Nail Parry hits body cell (4,5) for 3 and grants 8 Block (printed 5 plus
  Shield 3), with Crowncoal painting that target Fire (95–96). Spur Vault
  skips player movement, deals 6 (printed 4 plus Whetstone 2), spends 4 Time
  and pushes the anchor left (3,4)→(2,4) (97). This leaves boss 41−3−6=32.
  Actual one-cell displacement does not trigger Pinion.
- Exhausted movement and plays end the activation. Worldheart converts 2
  Block to Stoneskin, bringing it from 9 to **11**, with 6 temporary Block.
  The push has removed the boss from both adjacent pulse range and its Fire
  cells, so neither a Worldheart hit nor an activation-start Fire tick follows.
- Eclipse at clock 95 checks the newly restored Light and misses the hero
  at (5,5) (100). It does not snuff the refuge again or automatically restore
  the near one. A replacement is summoned (101), and event99 schedules its
  first activation for **116**, after the player's next activation at **110**.
  The parent's two hidden queue warnings at +4/+6 match 114/116, but hidden
  positions and action identities are deliberately omitted.
- T7 opens at clock **110**, from 94 + base 9 + Nail 3 + Vault 4, with
  18/24 HP, 11 Stoneskin, boss 32 HP and hero (5,5). No enemy damage consumes
  defense, and unused Block expires. Near brazier #1 remains unlit; far #2
  remains lit. No next-hand contents are reported.

This closes the native arrival-relight observation. Prior positioning and both
free moves buy a safe refuge while preserving two attacks; the visible forecast
change communicates its value. It does not establish that relighting was the
only viable answer—the cohort also has substantial defense and Light options.
The new helper has a real player reaction window; its subsequent pressure is
not claimed before it acts.

### T7 — ranged damage, retreat and a short return, audited through sequence 118

- From (5,5), Frostbolt targets body cell (3,5), deals 4 for 4 Time, places
  Ice and stores 3 Time in Hourglass (104–106). Both free moves retreat
  through the already-lit brazier (5,6) to (5,7) (107–108). Passing over a
  lit brazier creates no new restoration event.
- Cinch Straps spends 2 stored Time and costs **1**, the allowed minimum,
  preserving 1 reserve (109,112). It grants 10 Block (printed 7 plus Shield 3)
  and draws two cards through its printed draw and Iron Buckler (110–112).
  Gust Step is the pilot-observed committed draw; the next activation's hand
  is not reported. There is no further Fatigue or health cost.
- Worldheart converts 2 Block into Stoneskin, increasing the stored defense
  from 11 to **13**. The boss is outside the final hero position's adjacent
  pulse radius. The unused 8 Block will expire without absorbing damage.
- At Claw's clock 111, the boss **does become Chilled** while its body covers
  the newly placed Ice (113). It then advances (2,4)→(2,5)→(2,6) (116).
  The final footprint no longer covers that Ice, so the shared
  `BoardSurfaceRules.sync_chilled()` rule clears Chilled on departure. No
  Freeze or subsequent Chilled damage bonus is earned. At anchor (2,6), the
  nearest body cell is still Manhattan distance 2 from the hero at (5,7),
  and the Claw produces no melee hit.
- Both intervening helper activations resolve movement only, with no player
  losses (117–118). This includes the newly summoned helper's actual first
  turn after the earlier player reaction window. Their hidden positions and
  intent identities remain excluded from the audit.
- T8 opens at clock **124**, from 110 + base 9 + Frost 4 + discounted Cinch 1,
  with 18/24 HP, 13 Stoneskin, reserve 1, hero (5,7) and boss **28 HP** at
  (2,6). The upcoming Starless Breath is due 126. No enemy hit, Fire tick or
  Worldheart boss damage changes the 32−4 accounting.

The pilot chooses ranged damage and stored defense while retreating, retaining
a player activation before Breath. The considered Riposte approach had higher
printed attack payoff and would approach the player's Fire, but it was not
played; it is not counted as actual damage or a required sacrifice. Ice supplies
the Time reward here while the dragon's movement denies a lasting Chilled setup.

### T8 — the lit refuge is still inside Breath, audited through sequence 132

- Gust Step targets body cell (3,7) from hero (5,7), skips its movement,
  deals 5 (printed 3 plus Whetstone 2) and spends the last reserve Time,
  costing 3 (119–121). It pulls the anchor (2,6)→(3,6), only one actual
  cell because a second would overlap the hero. Pinion does not trigger.
  Crowncoal paints the original contact (3,7), now still under the body.
- Riposte Lunge skips its movement, deals 5 to (4,7), grants 7 Block
  (printed 4 plus Shield 3) and costs 5 Time (122). Whetstone is already
  spent. The hero takes one free step (5,7)→(5,6), onto the lit far brazier,
  then passes with 1 free move unused (123).
- Worldheart converts 2 Block to Stoneskin, increasing 13→15, and pulses
  for 1 against the adjacent dragon. At the boss's clock 126, Fire ticks for
  3 (124,127), so boss health becomes 28−Gust 5−Riposte 5−pulse 1−Fire 3=14.
- **Pilot targeting/route mistake:** the hero remains in the two-wide
  right-facing Starless Breath lane. Tile (5,6) appears in **both** the
  declared and resolved areas after the pull (128), so this is not an
  unannounced expansion into a formerly safe destination. The lit refuge
  protects against Eclipse; it does not cancel the separate Breath attack.
  Breath's scaled **11 Pierce** bypasses all Block and Stoneskin, taking
  HP **18→7**, exactly as the target-loss event records.
- The first replacement Acolyte also resolves a 4-damage melee during this
  transition; 4 of the remaining 5 Block absorbs it, with no HP or Stoneskin
  loss (129–130). This is actual replacement-attack pressure after its fair
  initial reaction turn. The other helper has no player damage (131).
  Hidden destinations and unobserved intent details are excluded.
- T9 starts at clock **141**, from 124 + base 9 + Gust 3 + Riposte 5, with
  hero 7/24 HP, 15 Stoneskin, no Block at (5,6), and boss 14 HP at (3,6).
  The final unused Block expires. No further Fatigue, Fire entry or printed
  health cost contributes to this turn's 11-HP loss.

The known Breath explains all health loss. The hidden-HP-damage counter remains
zero, but that HP-only counter does not prove which uncertain helper warning was
displayed before passing. The separately defended helper hit is not substituted
for the announced piercing lane. The pilot's admitted misread is recorded
candidly; neither the telemetry nor the observation establishes a UI defect.

### T9 — let earned Fire finish before Coil, audited through sequence 143

From (5,6), Spur Trip targets adjacent body cell (4,6), skips movement and
deals 7 (printed 5 plus Whetstone 2), with Immobilize, for 4 Time (134–135).
Crowncoal adds Fire at that contact. Clockwork Mark then deals 5 for 4 Time and
draws the now-observed Shrapnel Burst (136–137), leaving the boss 2 HP. The pilot
holds position and passes both unused free moves. No Block is gained, so no
additional Worldheart conversion or pulse occurs.

At the boss's clock **142**, its activation-start Fire has 3 damage potential
and removes the final **2 actual HP** (138–139). Noctyrax dies before Night Coil
can attack or snuff the far refuge again. Immobilize is not needed to prevent
that stationary attack. The final visible helper is cleared by the leader
objective without a kill reward; `objective_followers_cleared` is 1 (142).

Victory is **turn 9, clock 142, 7/24 HP and 15 Stoneskin**. The queued player
activation at 158 is never reached. The native milestone shows Eclipse Mantle
for the next run, +150 Embers, +6 actual healing and the already-earned
first-dragon Moltshard notice, with **Complete Ascent** (143).

### Final milestone persistence boundary and normal exit

The parent preserves the pre-claim save/profile under
`/private/tmp/dragon-feedback-native/noctyrax-01-preclaim/`.
The audit recomputes and matches raw save SHA256
`64d7c8108b3eb2f29bcc5dba8f65d490723dad4917d773cf8ec6e4a37c067bfb`
and profile SHA256
`135e42db881310a0a57d5434feb73d86793727b870eaa3171ad2c21c3fde6494`.
The run is still `mode: reward`, with 13/24 HP after healing, 150 held/unbanked
Embers, `victory: false`, `game_over: false` and a pending final dragon milestone.
Eclipse Mantle is not added to the just-ended combat's relic inventory.

Before Complete Ascent, **both profile and run progression already contain one
durable starting gift**, identified by `run:0:seed:7262026:dragon:24,0` and
`relic_id: eclipse_mantle`. Profile Embers are still 0, `completed_run_results`
is empty and `last_run_result` is empty. Gift preparation is therefore durable
at reward preparation; banking and run completion remain deferred until claim.
This checkpoint is not described as an unawarded gift or a completed run.

The parent clicks Complete Ascent and inspects **Ascent Complete**: 13/24 HP,
150 banked Embers, 4 kills, 119 damage dealt, 13 received, depth 24, 6 rooms
and 1 boss. Those fixture statistics describe the staged run state, not a
continuous six-boss descent. Main Menu has Continue disabled and shows the
150-Ember profile; normal Quit ends session 72174 with verified exit 0.

The preserved post-claim profile is
`/private/tmp/dragon-feedback-native/noctyrax-01-postclaim/progression.json`,
whose recomputed SHA256 matches
`3abaf797c21aa870cf595ef96ba7088adcf12658b0f9108d41fd0b2f86ac7f80`.
It contains 150 Embers, one Moltshard with its unchanged earlier award receipt,
one pending Eclipse Mantle gift and exactly one completed result,
`run:0:seed:7262026`. The analytics outbox is empty and the current-run save is
absent after the terminal/menu transition. The append-only log contains one
reward offer (143), one claim (144) and one `run_ended` event (145). A new run
is not started in this cohort, so gift consumption is not claimed here.

Audit-process boundary: turn-by-turn outputs masked hidden helper details and
future draws. After victory, the first persistence extraction inadvertently
expanded the saved reward's nested board state; it was replaced with a
metadata-only extraction. None of that post-combat data informed native choices
or hidden-position claims in this journal.

### Completed Noct01 accounting and bounded assessment

The pilot commits **20 cards over nine activations** at clocks
0, 20, 37, 53, 76, 94, 110, 124 and 141. The two original helper kills refund
the two extra plays; neither refund is attributed to a summoned helper. The
20→7 HP loss is **2 Fatigue + 11 piercing Breath**. No potion, item card,
manual skill, printed health-cost card or Defiance is used; the single Defiance
charge remains. Two helper hits total 8: 7 Block and 1 Stoneskin absorb them.
Six Worldheart conversions supply 12 Stoneskin, Stone Plate supplies 4, and
1 is spent defending, leaving 15 at victory. Storing substantial defense does
not neutralize the separate piercing lane.

Boss damage reconciles exactly: **83 direct card + 15 Crowncoal Fire + 2
Worldheart + 1 Bleed = 101**. Whetstone contributes 12 of that direct total.
Hourglass saves 6 Time across Beacon, Cinch and Gust; Pinion refills two free
moves and draws once after T2's two-cell pull, although those restored moves
are passed. The post-combat ledger shows the second replacement dies to 6
Fire damage without a dedicated card; its hidden location is not part of the
assessment. Boss 101 + the two original helpers' 12 + that replacement's 6
matches 119 dealt. The remaining helper's leader-collapse is excluded from
damage and kill rewards.

Retain the revised Noctyrax encounter for this acquired depth-24 skirmisher
cohort. The natural T6 arrival relights a previously snuffed brazier, immediately
changes the visible forecast to Safe, and protects against the subsequent
Eclipse without an automatic reset. Planning the approach one turn earlier and
spending both free moves preserves offense while securing that refuge. Live
Claw pursuit makes retreat matter; Hourglass enables the short T7 return before
Breath. The first replacement receives a reaction turn and later lands a defended
attack, so its scheduling is verified by actual native activation, not only a
queue label. These are distinct position, timing and defense decisions.

The limits are equally material. Both initial helper kills efficiently refund
plays, much of the early route remains forgiving, and the five earned trophies
plus Shield/Buckler/Whetstone strongly aid the cohort. The second replacement
succumbs to existing Fire. Relighting is observed once, not across indefinite
alternation; both Eclipses miss in Light, and accepting Eclipse outside Light is
not played. There is no requirement to lose HP to demonstrate pressure. The
11-HP Breath hit is an admitted avoidable lane/Pierce error, not evidence of an
unfair hidden hit or a demonstrated UI defect. Keep that candid error and the
contrast between Eclipse refuge and ordinary attack lanes in the play guidance;
this study does not justify another mechanical revision or establish universal
build balance. It is a completed native cohort, not final branch signoff.


## Final interaction fixtures — native input checks

The three focused inspection fixtures were exercised through normal native game
input after generation/reload verification. These are authored demonstrations,
not additional realistic boss cohorts. They used Metal and the app's fullscreen
setting; the observed CUA screenshots were 3024×1900. The separately retained
1920×1080/100% probes supply the required layout proof. CUA images remain in the
conversation, rather than being claimed as exported PNG artifacts.

All three native runners exited normally with code 0: Man session33136,
Hourglass/Coil session63872, Gust/Worldheart session5900. The coordinator's API
interruption left the last game idle after its completed turn; recovery closed
that same process normally. No save was regenerated to change these results.
Post-play save, profile, analytics and log copies with SHA256 bindings are under
`/private/tmp/dragon-feedback-inspection/native-checks-v1/receipt.json`. These
copies preserve the completed demonstrations before the user fixtures are reset.

### Emaciated Man

Run `dragon-feedback-inspect-man` starts with two Moltshards, 100 Embers, LV1 and
24/24 HP. Continue automatically opens the three-line awakening introduction,
starting with “A dragon has fallen. I felt it...”; no preliminary Speak click is
required. After finishing it, ordinary Speak and Awaken Power are separate room
actions. Awaken Power opens the exchange/level service. Initially Level Up costs
180 and is disabled. Trading one Moltshard grants 250 Embers: one shard and 350
Embers remain, and Level Up enables. Clicking Level Up spends 180, reaches LV2
with 170 Embers, and opens Character with one unspent point and one Moltshard.
No skill is automatically learned. Closing Character returns to the service;
the next 250-Ember level is disabled. Leave returns to the room. Speak then opens
ordinary “Hehehe. You're back...so soon.” dialogue without repeating awakening
or opening the service.

The append-only log records exactly one exchange at sequence4 and one level-up
at sequence5, with wallet transaction IDs ending `wallet:1` and `wallet:2`.
The preserved profile and run agree on LV2, one Moltshard, 170 Embers, no learned
skills and `emaciated_awakening_seen: true`. The durable outbox still contains
those two keyed events; this check does not claim an empty outbox or a separate
post-relaunch acknowledgment test.

### Winter's Hourglass and Stormroad Coil

Run `dragon-feedback-inspect-hourglass-coil`: player(2,1), Crawler(6,1) at14HP,
Electrified relay(4,1), hand Frostbolt/Pale Spark/Brace, both relics. Select
Frostbolt and click the enemy once: 4 damage, one play remains, next player slot
9→13, Ice appears under the enemy and Hourglass settles at3. Pale Spark visibly
costs1 instead of3. Select it and click the same enemy once: 3 damage, zero plays,
next player slot14 and Hourglass settles at1. No enemy turn is needed.

Analytics sequences11 and15 confirm both relayed attacks use (2,1)→(4,1)→(6,1).
Sequence13 records Frostbolt paying4 and gaining3 stored Time; sequence16 records
Pale Spark paying1, spending2 and leaving1. The completed save has enemy7HP,
player24HP, two played cards and5 spent Time. Live input, target acceptance,
visible counters and exact payment pass. Sparse CUA observations do not establish
every animation frame of both relay arcs; the inspected trophy probe owns that
visual claim.

### Gust Step and Worldheart

Run `dragon-feedback-inspect-gust-worldheart`: player(2,1), Warden(5,1) at18HP,
hand Gust Step/Brace/Stone Plate, Worldheart. Select Gust Step, then click the
enemy once. It approaches to(3,1), deals3 and pulls the Warden to(4,1), leaving
one card play and both ordinary movement points. No second target input occurs.
`STEP 1/2` and the brief resolving second stage describe the card's two printed
effects; independent source/test review confirms the enemy shortcut commits both
targets from that one decision. Blue floor choices deliberately permit a
movement-only use. Analytics sequence10 records `target_decision_count: 1`,
selected targets(3,1)/(5,1), one movement,3 damage and one spent play.

Brace on the player grants8 Block, spends the last play and schedules the next
player at14. Pass converts only2 Block into2 Stoneskin and pulses the adjacent
Warden from15 to14HP. The settled next turn displays the fresh hand and restored
play/movement allowances. The post-play save independently confirms turn2,
clock14, player(3,1) at24HP with exactly2 Stoneskin and0 Block, Warden(4,1) at14HP,
and two movement points. The native check passes the requested one-click flow,
conversion cap and retained adjacent pulse.


Follow-up to the Man audit: independent review confirmed those retained entries
were restored by UI refresh from stale embedded progression. The bounded
[wallet acknowledgment repair](dragon_wallet_ack_review_20260927.md) synchronizes
and saves that boundary in both purchase handlers. Its actual-RunScene regression
fails on the original code and passes108 checks after correction, including
injected acknowledgment failure and reload. The pre-fix native evidence above
remains preserved; no second manual native session is claimed.
