# Dragon boss live-play log

## Latest completed playtest pass — 2026-09-26

All six revised dragons have now been played through the native game using the
ordinary acquired builds described below. These are individual encounter studies,
not a claim of a single uninterrupted six-gate run or a statistical balance sample.
Historical pending statements below describe the state at that earlier iteration;
this table and the final cohort entries supersede them.

| Dragon | Depth / build | Starting HP | Result before milestone healing |
| --- | --- | --- | --- |
| Vyraketh revision 02 | 4 / balanced, LV1 | 20/24 | Victory, 7 activations, 18/24 HP |
| Tharokh attrition 02 | 4 / balanced, LV1 | 14/24 | Victory, 7 activations, clock 101, 11/24 HP |
| Vaeloryx late 02 | 16 / skirmisher, LV3 | 20/24 | Victory, 10 activations, clock 145, 18/24 HP |
| Iskaldra mid 01 | 12 / balanced, LV3 | 20/24 | Victory, 13 activations, clock 185, 17/24 HP |
| Zekarion late 01 | 20 / balanced, LV4 | 20/24 | Victory, turn 15, clock 242, 7/24 HP |
| Noctyrax final 01 | 24 / skirmisher, LV4 | 20/24 | Victory, 9 activations, clock 145, 13/24 HP |

No manual skills were used in these completed revised cohorts. Later gates include
prior earned trophies; no Defiance charge was spent. Vyraketh and Iskaldra needed
technical native-control resumes with the same saved state. Zekarion's first four
turns preceded the summon scheduler fix; the later continuation separately verified
functional replacements. The earlier Vaeloryx loss is retained. These limitations
are explicit in the individual logs. The 14-HP stress study is first-gate Tharokh,
not an unplayed late-gate cohort.

The final Tharokh and Noctyrax replays support keeping the current tuning. Their
best options changed with the hand, available routes, terrain, action clock and
stored defense. Native victories verified the milestone flow; Noctyrax additionally
verified the next-run gift and the subsequent entrance exchange. Focused persistence
checks cover interruption/replay cases that ordinary successful play cannot prove.

## Method

Use the actual Godot game through task-local verified fixtures. Read the visible
hand, preview and clock; play through the normal interface. Keep full health and
hand state honest. A loss is evidence. Do not reload during a reported attempt,
force a convenient hand, or change stats to complete a fight. Focused staged
mechanic/reward probes are recorded separately from live attempts.

Track each player activation: position, health, intent and countdown, competing
options, choice, observed result. After the encounter rate meaningful decisions,
readability, punishments, pacing, and reward satisfaction. Revise and replay.

## Current controls / lessons

- Movement pool is separate from card plays, but changes the board and previews.
- Read the next activation clock before spending Time on an extra card.
- Hover/focus intent for projected movement and attack. Check actual patterns.
- Guard, positioning, disabling, terrain and accepting a hit can all be valid.
- Health-cost cards must be judged against the next incoming hit and healing.
- Relic draws and multi-action cards can change hand indices: reread the hand.
- The old headless strategy guide contains stale pickup and fixed-first-boss
  advice; use live rules and this log for this revision.

## Baseline attempts

### Vyraketh baseline 01 — victory, 12/24 HP

Fixture `dragon-vyraketh-baseline-01`, depth 4, balanced build, natural shuffle.
20/24 HP; Iron Cleaver, Ward-Kite, three starter pieces, one common relic,
five common spells and one rare. No upgrades or skill purchases.

1. Opening Kindle Ground: moved (1,4) to (3,4), used Cleaver Hook (6),
   pushed Vyraketh to (5,3). Passed with one play unused: next activation at
   13 precedes the boss at 16. Meaningful Time choice.
2. Moved to (4,4), used Butcher Chop (12) and Stone Plate (4 Stoneskin).
   Kept the next activation just ahead of the following boss action.
   Kindle Ground's preview keeps retargeting around the moving player; it
   cannot be used to plan an escape from the coming Fire placement.
3. Crownfire pending in 1 Time, boss 42 HP. Two free moves to (4,2) spend
   2 Stoneskin crossing Fire, but the destination is still in the burst.
   The dragon sprite hides the danger tiles: the turn-end loss preview is
   necessary to catch the mistake. Spent Sidestep Slash to reach (5,2),
   then Chain Bolt, leaving Vyraketh at 38 HP and a safe end-turn preview.
   A movement card provides a worthwhile alternative to blocking the hit.

Technical interruption: native fullscreen input stopped responding during
activation 3. Verified the autosave exactly matched HP, hand, positions and
Crownfire; copied a hash-verified backup, then resumed that same checkpoint in
windowed mode. No gameplay decisions were rolled back or state modified.
This is a resumed baseline, not a clean uninterrupted attempt.

Control notes: select movement by clicking the player's feet; select a legal
tile to commit. Cards recenter after every play. Let each multi-step card show
its next targeting step before selecting the next target. Native windowed
input has been more reliable than fullscreen computer-use input.

4. Crownfire detonated for 8 self-damage; the boss then immediately
   chose Kindle again. Kite Bash (6 Block, 3 damage and push) plus Lantern
   Shot (4) left Vyraketh at 23 HP. Staying put used all 6 Block and the
   remaining 2 Stoneskin to avoid damage. Pushing the dragon out of Fire
   accidentally denied its self-damage: a useful positional tradeoff.
5. Moved one tile, used Cleaver Sweep (6) and Warded Advance without its
   movement (7 Block from Iron Buckler). Cinderfall dealt 1 unblocked
   damage, then persistent Fire dealt 3 on the next activation: 16 HP.
6. Misplayed Low Sweep by clicking a destination instead of the dragon.
   It moved into Fire (2 damage) and skipped the strike. Code inspection
   confirmed this is intentional combined-card input, not a targeting bug.
   The earlier Sidestep Slash also deliberately omitted its strike through
   this same input. Correct input: click an enemy for move + attack;
   click open ground for movement only. Vyraketh remained at 17 HP.

Baseline findings so far: weighted choices can repeat setup/explosion and
postpone the dragon's distinctive attacks. Tracking placement and the Cinderfall
cross do not reward planning around the displayed warning. Shared Fire and
Crownfire self-damage, however, create useful positioning and defense tradeoffs.
The revised prototype preserves those interactions with a fixed sequence and
committed ground patterns. This live attempt is still the original behavior.

6 (continued). Root Snare dealt 2 and applied Immobilize; two free moves
   escaped Maw, crossing Fire for another 2 HP. Exhausting both plays and
   movement automatically ended the activation. Vyraketh lost 3 to its Fire.
7. Moved one tile into range, then Butcher Chop dealt the final 12. Victory
   immediately opened the map: no reward screen or victory banner. Closing
   the map revealed only a Moltshard notice and 110 Embers in the HUD.

This seven-activation baseline ended at 12/24 HP. The player spent two card
strikes on movement-only misplays. Persistent Fire and repeated tracking
Crownfire did more work than a readable attack sequence. A screenshot of an
intent can place the dragon at its projected endpoint: distinguish the current
footprint from the movement preview before judging melee range.

Input observation to investigate in renderer proof: the final hand card would
not select from its art at (1145,779) but did from its bottom at (1145,925), in
this 1600x900 client. Other cards worked. Do not mistake an occluded hit region
for an illegal card or native-app input failure.


### Vyraketh revision 01 — interrupted after Maw, 20/24 HP

Fixed Kindle barrier two tiles from the body; deterministic Kindle → Crownfire
→ Maw → Cinderfall. Same first-gate seed/build/shuffle as baseline. This prototype
was stopped at a preserved checkpoint for input diagnosis, not counted as a win.

1–2. Repeated the opening Hook/push, then Chop + Stone Plate. The fixed barrier
was left behind at (2,3), (2,4), (2,5), so the player stayed at (4,4) and the boss
at (5,3), entirely beyond Crownfire. This setup was too easy to invalidate.
3. Correct combined-target Sidestep Slash dealt 5 without moving, then Chain
Bolt dealt 4; Crownfire missed both actors. Vyraketh 33 HP, player 20 + 4 Stoneskin.
Native input was interrupted; resumed exactly the saved checkpoint with logging.
4. Maw threatened 12 from its held front and flanks. Cleaver Sweep (6) and
Lantern Shot (4), followed by both free moves to (2,4), avoided the strike.
Retreat sacrificed melee range and led directly into the next fan's outer row.
5. Cinderfall now threatened 8. Planned Low Sweep back into melee, then free
movement onto the lateral flank. Repeated card-selection input failures stopped
execution before either card play. Saved checkpoint: boss 23 HP; player 20/24,
4 Stoneskin at (2,4); both plays and moves unspent. No decisions rolled back.

The Maw→fan transition asks a better question than independent random attacks:
retreat is safe now but can cost a movement card next activation. Kindle needs
closer placement: two approach melee cells plus the nearer exterior corner exit,
leaving the opposite flank open. Keep Crownfire's shared damage so pushing the
boss away buys space but can forfeit its self-damage.

Input evidence remains separate from design conclusions. Diagnostic logging
confirmed some card clicks reach the root with the correct hovered CardWidget,
no animation lock and legal turn, but without its activation signal. Other
clicks and the menu work. A renderer input probe is needed before blaming native
focus or changing gameplay to work around it.


### Vyraketh revision 02 — victory, 18/24 HP

Latest close L-shaped Kindle: two approach cells and the nearer exterior corner.
Same depth-4 seed/build/shuffle, starting 20/24 HP. Technical save/resumes retained
the exact state; no gameplay decisions rolled back. Normal production startup
reproduces the intermittent card-click failure, ruling out the diagnostic harness.
Temporary event-consumption tracing was removed. A repeated native click can
select when the first press is lost; verify selection before targeting, since
a double activation can also select then cancel. This remains an input defect.

1–2. Hook/push, then Chop + Stone Plate as before: boss 42, player 20 + 4 Stoneskin.
3. Crownfire now threatens the close approach. Sidestep Slash deals 5, then
Kite Bash deals 3, pushes the boss to (6,3), and grants 6 Block. Staying at (4,4)
uses the shield and 2 Stoneskin to absorb the 8 blast. Boss 34; player 20 + 2.
4. Lantern Shot + Chain Bolt deal 8 from range, then both independent moves
retreat to (2,4). Held Maw misses, destroys the crate at (4,5), and arrives at
(5,3). Boss 26. Player remains 20 + 2.
5. Cinderfall threatens the retreat tile. Low Sweep closes to (4,4) and deals 3;
Cleaver Sweep deals 6. Both independent moves go through the newly cleared
(4,5) to (5,5), outside the held fan. Boss 17, player still 20 + 2. A movement
card recovers attack access without spending the movement needed for safety.
6. Second Kindle threatens the new flank. Frostbolt deals 4 and Root Snare 2;
retreat to (3,5), beyond the declared Fire and its adjacent Crownfire tiles.
7. Refill costs 2 HP on reshuffle (18/24, 2 Stoneskin still intact). Shrapnel Burst
hits from safe ground for 7 + 2 Chilled bonus, leaving the boss at 2. Pass rather
than spend a movement card to approach: shared Crownfire deals the finishing hit.
Victory at clock 100 after seven player activations. Post-combat heal restores
24/24 and 110 Embers appear, with the old immediate-map/Moltshard toast flow.

Compared with baseline, the same build uses its defensive card, moving strike,
ranged attacks and independent movement deliberately. The predictable sequence
and readable warnings let this planned attempt avoid enemy health damage; the
2 HP loss is Fatigue. Further builds and later-gate scaling remain necessary.
The fight is materially more legible and tactically varied, but this one win
alone does not establish final difficulty or complete the dragon pass.


### Native input fix and control lessons

The lost first press was a synchronous Godot native-window cursor refresh from
CombatBoardView during mouse-enter dispatch. Deferring and coalescing the board
cursor update fixes the root-window regression (before: 0 presses / 1 release;
after: 1 press / 1 release, with a CardWidget-like STOP control). Targeted cards
selected on their first click throughout the next uninterrupted live attempt.
Targetless cards deliberately preview on the first click and commit on the
second; the small play/cancel symbols distinguish selection from hover.

Select free movement by clicking the player's feet, then a highlighted tile.
The movement counter is a display, not a button. When the last card play and
last movement point are spent, the game ends the turn automatically. Wait for
the next hand/intent before pressing Pass; a second pass skips a whole turn.
Patch Up heals 2 and grants 2 Block (not Draw 2), then burns.

### Tharokh revision 01 — victory, 10/24 HP

Uninterrupted native production startup, fixture `dragon-tharokh-revision-01`,
depth 4 balanced build, natural shuffle, 20/24 starting HP. Same acquisition
budget as Vyraketh; no hand manipulation or rolled-back decisions.

1. Sidestep Slash moves from (1,4) to (3,4), hits for 5. Butcher Chop deals 12.
   Boss 47/64. Next player activation 17 precedes Stonewake at 18.
2. Frostbolt deals 4 and leaves Ice; Cleaver Sweep deals 6 and triggers the
   nearby Earth trap. Rubble now covers the player's approach. Boss 37.
   Stonewake raises both declared spires behind the player.
3. Kite Bash deals 3 + 2 Chilled bonus, grants 6 Block and pushes the dragon
   to (5,3), moving its committed claw away from the player. Patch Up heals
   to 22 and adds 2 Block. The claw misses. Boss 32.
4. Faultline threatens 8. Chain Bolt deals 4. One step to (4,4) consumes both
   free movement points in Rubble and remains in the explosion. Shadow Step
   crosses to (5,5), preserving the spires but sacrificing the second attack.
   Automatic turn-end resolves Faultline safely; both spires become Rubble.
5. Operator error: pressed Pass after that automatic turn-end, skipping this
   activation. Bedrock Breath deals 10. Player 12, boss 28. This is retained
   in the reported result, not treated as unavoidable encounter damage.
6. Shrapnel Burst deals 7; Cleaver Hook deals 6 and pushes north. Move to
   (6,4); both resources exhausted, automatic end. Stonewake raises two new
   spires on the previous approach. Boss 15.
7. Choose Lantern Shot (Time 3, damage 4) and Root Snare (Time 4, damage 2).
   Together with base Time 9, the next player activation is 111, just before
   the claw at 112. A slower two-card pair would allow the lethal attack.
8. First reshuffle costs 2 HP, leaving 10. Butcher Chop is drawn and deals
   the last 9 HP before the claw. Victory at clock 111; eight activations.

Assessment: displacement can trade away spire self-damage for safety; Rubble
made a movement card necessary; the final Time decision was clear and useful.
The opening is too generous: four attacks land before any damaging intent.
Investigate an earlier first Stonewake while preserving the later repeat pace.
The one lost turn accounts for all enemy HP damage; further build/seed checks
are still needed. Existing victory still jumps directly to the map, confirming
the missing milestone screen. Actual reward: 80 room Embers + 30 boss bonus,
first-boss Moltshard, and 6 HP healed to 16/24.


### Reward, persistence and UI verification — revision 05

Six distinct generated trophy icons are installed at 96 px with alpha. Native
96/32 px contact-sheet inspection confirms distinct silhouettes: crowned ember,
stone heart, broken-shackle feather, frozen hourglass, lightning coil and mantle.
The milestone panels reuse the victory banner/reveal and show the actual Ember
and HP gain, first-boss Moltshard, and unique trophy. Noctyrax reserves a one-run
gift for the next descent; Continue acknowledges the milestone before the recap.
Focused engine checks cover replay/idempotency, save round-trips, profile-first
wallet failure recovery, a failed gift acknowledgment, and all six relic hooks.

Entrance exchange is 1 Moltshard for 250 Embers. Level 2 costs 180; the rendered
100-Ember / 2-Shard case trades to 350 / 1, then buys level 2 leaving 170. Skills
closes back to the service. Both disabled purchases retain a usable Leave action.
Controller accept no longer advances past option rows; cancel closes dialogue.
The NPC tile is navigable/activatable and a Speak action reopens the service.

Visual iterations caught real failures despite earlier screenshot-count passes:
contact sheet initially behind the scene CanvasLayer; entrance screenshot hidden
by a deferred automatic map; Wisp intent behind the boss header, then card hand.
The final HUD reserves both overlays and permits limited sideways intent shifts.
Noctyrax refuge boundaries now draw on the floor below bodies, not across them.

Independent review caught Crowncoal overwriting the attack's own Ice/conductor.
It now paints only ground without an elemental surface, and does not spend its
trigger on a blocked placement. Focused regression verifies Ice survives and the
next valid hit still paints Fire. This prevents a mandatory trophy from harming
an established Ice build.

Late fixtures now include every prior seeded dragon trophy and an already-earned
first-boss Shard receipt. Retired card_upgrades were removed. Fresh-profile cohort
levels are 1/2/3/3/4/4 at gates 4/8/12/16/20/24: cumulative level spending
0/180/430/430/770/770. Fixed skills: Quick Wits, then Measured Breath, then Ghost
Stride; no keystone. Gear adds Boiled Leather at 8, Duelist Rapier at 12, Trapdoor
Spurs at 16 and Clockwork Arrowhead at 20. Reprise replaces the fifth spell at12;
Storm Beacon replaces Chain Bolt at20. Normal shuffled hand; no boss-specific
loadout adaptation. Balanced uses Pilgrim Boots; skirmisher uses Duelist Whetstone
instead, so automatic light/extra movement does not hide positional questions.
Default 20/24 HP is a comparison baseline, not a claim of a simultaneous campfire
heal and level-up. The prepared 14/24 attrition case is first-gate Tharokh with its revised clock-12 opening. A late-gate 14/24 start has not been independently played. Level4's Defiance
is a run resource and must not be silently refilled during repeated encounters.

Current proof is not completion: live Vaeloryx, Iskaldra, Zekarion and Noctyrax
remain, along with Tharokh's earlier-opening replay. Full suite initially found
stale breath/cycle/reward/dialogue assertions plus entrance layout issues; these
are being resolved before the final committed review.


### Vaeloryx late cohort 01 — defeat at activation 4

Verified fixture `dragon-vaeloryx-late-01`, depth16 skirmisher, level3, Quick
Wits and Measured Breath, 20/24 HP, ordinary acquired gear and three prior
trophies (Stormroad, Winter, Crowncoal). No Pilgrim Boots. Boss72 HP.

1. Riposte Lunge clicked on floor(3,4), deliberately omitting its legal strike
   (operator input error). Shrapnel Burst deals7, triggers an Air trap and shifts
   the boss. Free movement to(4,5) avoids the reanchored Gale.20 HP, boss65.
2. Gust Step pulls the boss from(5,3) to(5,5), then moves to(4,6); deals5.
   Crowncoal paints the old target ground; Stormroad paints the movement origin.
   Chain Bolt deals4 but does not conduct through two distinct tiles, so no
   bonus play. Skyhook's held lane misses.20 HP, boss56.
3. Spur Trip floor click to(4,5) again skips its strike: same operator mistake,
   not a footprint-targeting defect. Lantern Shot deals4. Independent movement
   to(5,4) is STILL in the crescent's flank; I inferred safety from facing instead
   of checking the red cells. Razor hits12 and Bleed1; boss loses3 to Fire.
4. Frostbolt clicked the projected sprite rather than the actual footprint,
   hitting empty(4,4). Spur Vault correctly enemy-targeted deals6. Each action
   costs1 HP from Bleed. Quick Wits discards Parry Rhythm and draws Nail Parry;
   it grants Draw1, NOT Play1. Final free movement to(7,4) costs another Bleed HP.
   Spending8 card Time puts player17 after Eye0 and Gale14. Pinned Eye cannot
   retreat; the newly declared north-facing Gale kills the remaining5 HP.

Assessment: loss is dominated by three missed strikes and a false-safe charge
landing; do not lower difficulty from this attempt. Time pressure is real: one
4-Time card on activation4 would return at13 before the14 breath; the second
card gave the boss two actions. Readability caveat: projected dragon bodies
can conceal current actor/tile positions. Click the current footprint/base, and
confirm the attack preview, not the upper sprite. Current card control contract:
enemy click = auto-route + attack; floor click = movement only; there is no
manual landing-then-strike sequence for a combined card. Use independent Move
first when the chosen landing matters. Quick Wits is discard1/draw1.

Full regression `tests/run_tests.gd` now PASS after updating post-victory,
entrance service and committed-intent expectations. Known ObjectDB exit warning
remains; no parser/runtime errors.


### Vaeloryx late cohort 02 — victory, 18/24 HP, activation 10

Fixture `output/dragon-revision/vaeloryx-late-02.json`; native Metal/Mobile,
1600×900 window, 100% UI. Same depth16 skirmisher acquired build and normal shuffle
as the loss. No staged hand or rollback. A CUA mouse `noWindowsAvailable` error
required quitting and reopening the native window at activation6. The autosave
was byte-for-byte verified before resuming; neither gameplay decisions nor RNG
were reset. The intervening wallet-event/Worldheart fixes do not affect this
cohort, which has no Worldheart.

- T1–3: Riposte Lunge, Spur Vault, and Spur Trip each used a short one-card turn.
  Turn Clock boundaries14/27/40 let the player beat Gale14/Skyhook28/Razor41.
  Vault and the Air trap shifted the dragon; Trip's Snare prevented its charge.
  This was control and timing, not an Ice Freeze. HP20, boss46 before T4.
- T4: Frostbolt plus Lantern Shot from range, move to(4,6). The snared Razor
  missed; Eye retreated to(5,1) and gained5Block. Boss38, HP20, clock56.
- T5: approach to(4,4), Shrapnel Burst breaks5Block/deals2, Cinch Straps blocks7
  of Gale8. Deliberately spend9 card Time for one known attack; actual1HP and
  Push2 match the preview. Boss36, HP19, clock74.
- T6: move back to(4,4), Chain Bolt4 plus Stone Plate4 persistent defense.
  Next turn18 stays before Razor21; Skyhook's held lane misses. Boss29, HP19.
- T7: Reprise costs1HP but only draws1 into a nearly full seven-card hand:
  poor hand management, not a boss defect. Quick Wits discards redundant Spike
  Check, but reshuffle costs2 fatigue; Crimson Draught restores2. Move to(2,4)
  safely. Razor and Eye resolve; boss23 after Fire ticks, HP18, clock110.
- T8: Leather Roll moves to(4,4) and grants9Block, Frostbolt strips4 of Eye's
  Block and creates Ice. Free movement then takes the safe adjacent flank(6,4).
  Gale misses, letting movement preserve both attack access and health.
- T9: Needle Thrust and Shrapnel Burst deal9 each (Chill boosts the physical
  hits). Move to(5,3), outside Skyhook's held south lane, before ending19Time.
  Boss5, HP18. Two attacks are affordable here but do not reach Razor23.
- T10, clock145: adjacent Gust Step cannot use its forced-movement attack,
  so cancel before commit; Spur Trip's direct strike finishes the dragon.

The loop rewarded early passing, Snare, defended aggression, guarded approach,
and side changes rather than permanent corner camping. One safe reposition did
sacrifice attacks; the follow-up approach restored them. The late cohort's
Crowncoal Fire mattered, but neither trophy triggers nor healing trivialized the
positioning. No further Vaeloryx damage or timing change is justified by this
replay. The earlier loss remains useful novice/input evidence.

The actual victory displayed DRAGON VANQUISHED, Unbound Pinion with its exact
rules,110Embers (80room+30bonus),6HP recovered, and the already-earned first-dragon
Shard status. Continue opened the section map with the next-section action and
the trophy in the run. UI scaling proof remains the separate1920×1080 rev05 probe.


### Iskaldra mid cohort 01 — completed after native-control interruption

Fixture `output/dragon-revision/iskaldra-mid-01.json`; depth 12 balanced, level 3,
Quick Wits and Measured Breath, 20/24 HP, three movement from Pilgrim Boots.
Acquired gear follows the cohort; prior trophies are Stormroad Coil and Worldheart.
No Crowncoal, Winter's Hour, card enhancements or staged hand. Native Metal/Mobile,
1600×900 at 100% UI. Boss 72 HP; scaled Lance 7, Shatter 8 and Rime Talon 11.

- T1: enemy-target Sidestep Slash moves to (3,4) and deals 5; pass after one card.
  Clock 12 precedes Mantle 15. Boss 67, HP 20.
- T2: Riposte Lunge deals 5 and grants 4 Block. Stone Plate grants 4 Stoneskin,
  draws a card, and Worldheart pulses for 2. End-turn conversion adds 4 Stoneskin
  and another 2-damage pulse. Boss 58, HP 20, Stoneskin 8. Clock 30 ties Whiteout;
  the player acts first. Mantle has one armor layer.
- T3: Low Sweep's 3 damage strips the armor without HP damage, applies Snare.
  Move to (2,2), picking up Jaw Trap. Choose a second attack, Shrapnel Burst,
  because this position lies outside both the committed Lance and the following
  close Shatter crescent. It deals 7 and breaks the crate at (3,3), creating a
  future approach. Both boss attacks miss. Boss 51, HP 20, clock 49.
- T4: use three movement to (5,2), leaving Electrified at (2,2). Needle Thrust
  deals 7. Next player activation is 13 Time away, Rime Talon is 14 away: plan
  an early pass, then defend and attack on the next activation. Boss 44, HP 20,
  Stoneskin 8; one ordinary play plus a banked play remains. The pass has NOT
  committed because the native input tool returns `noWindowsAvailable`.

Technical restart history: the tool lost mouse control during T4, before Needle.
Repeated launches used the same task-local autosave and did not roll back any
choice. A separately identified temporary copy of the same official Godot runtime
restored control briefly, allowing Needle to resolve. The next click failed again.
Screenshots still show the unchanged T4 state. This is incomplete play evidence,
not a win or a difficulty finding. Continue from this autosave; do not regenerate
its inspection fixture. Pending checks include Rime pursuit and armor/fuel later
in the cycle. The current meaningful choices were cheap armor stripping, spending
extra Time in a position safe from two different shapes, and a one-card tempo turn.


Continuation: after all renderer tests had exited, a clean restart of the same
isolated runtime and autosave restored native input for the rest of the fight.
The interrupted T4 pass committed without resetting choices or the shuffle.

- T5, clock62: Cinch Straps (internal `rallying_breath`) plus Lantern Shot leave
  the next player turn before Mantle. End-turn Worldheart deals3; Rime Talon
  spends1Block and10Stoneskin. Boss37, HP20, Stoneskin4.
- T6, clock77: Kite Bash deals3 and pushes the entire boss onto the Ice trap,
  adding8 trap damage. Follow one tile to(5,3); pass after one card. Worldheart
  adds6Stoneskin and deals3. Boss23, HP20, Stoneskin10, clock90.
- T7: Chain Bolt strips one mantle layer; Parry Rhythm grants5Block and draws2
  (its printed draw plus the first-block skill trigger). Move three tiles around
  the north to(3,4), outside Whiteout's held lane but still adjacent. End-turn
  Worldheart deals2. Lance misses. Boss21, HP20, Stoneskin15, clock107.
- T8: Frostbolt strips the second layer. Reprise refills two hand slots from the
  reshuffle, costing5HP total including its health cost and fatigue. Move around
  to(4,2), sacrificing the adjacent Worldheart pulse to avoid Shatterstorm. Pass
  at19Time, one before the upcoming Rime activation. Boss21, HP15, Stoneskin20.
  The selected-card health preview showed 16 before the actual 15 result. Code
  review confirmed that the forecast omitted Reprise's final 1 HP payment:
  first reshuffle 2 + Chilled 2 + printed cost 1 = 5 HP. This prompted the
  completed-card forecast fix and dedicated rendered regression.
- T9, clock126: Lantern Shot deals6 to the chilled dragon; move to(4,3) and use
  Cinch Straps. Worldheart deals3, then Rime costs1Block+12Stoneskin (13 with
  Chill). HP15 survives, but the ice hit while chilled causes Freeze.
- T10, clock141: Freeze prevents both cards and movement. Passing loses the
  attack window and allows Crystal Mantle to rebuild two layers. This is the
  important cost of defending on Ice: health protection does not preserve tempo.
- T11, clock150: cancel Gust Step's unavailable forced-movement attack before
  committing. Shrapnel Burst and Sidestep Slash strip the two layers. Move from
  (4,3) to the dry flank(3,4); Lance misses. Boss12, HP15, Stoneskin14.
- T12, clock168: Stone Plate pulses2 and draws Kite Bash. Bash deals5 to the
  chilled boss, pushes east, grants6Block. Follow to(4,4), accepting Shatter's8
  against Stoneskin so Worldheart can pulse3. Boss2, HP15, Stoneskin16.
- T13, clock185: Crimson Draught restores2HP; Frostbolt finishes before another
  Rime. Actual victory:17/24HP, no Defiance spent. No choice rollback.

The encounter supported cheap armor stripping, early passes, alternate flanks,
using traps with the whole boss footprint, spending persistent defense, and
accepting health loss to cycle a clogged hand. The defensive cohort was forgiving
of damage but not Freeze or fatigue. Thirteen activations include one lost Freeze
turn and deliberately inefficient hand retention; this replay alone does not
justify increasing boss damage or weakening the prior trophy.

The earned milestone displayed Winter's Hour,110Embers (80room+30bonus),6HP
recovered, and the already-earned first-dragon Shard status. Continue opened the
section map. Telemetry confirms victory turn13/clock185/17HP and exactly one
`reward_claimed` for the milestone with23HP after healing. Native1600×900 evidence
complements the separately inspected1920×1080 reward proof.


### Zekarion late cohort 01 — paused at T5 for a confirmed summon fix

Fixture `output/dragon-revision/zekarion-late-01.json`; depth 20 balanced,
level 4, 20/24 initial HP, three movement, one Defiance. Prior trophies:
Crowncoal Heart, Worldheart, Winter's Hour and Unbound Pinion; normal acquired
unenhanced deck and ordinary support relics. Native Metal/Mobile, 1600×900,
100% UI. Boss 80 HP; scaled Skybreak 8, Breath 9, Claw 12 and Call Block 6.
Initial Wisps have 8 HP and base initiative 8. No skills were activated.

- T1: Riposte Lunge and Kite Bash kill the western initial Wisp, granting its
  ordinary encounter kill bonus. Move around the first Crowncoal Fire and use
  the bonus play on Spur Trip. Boss falls to 72 after Worldheart. The surviving
  Wisp attacks twice during the long activation; 4 Block and 6 Stoneskin absorb
  the ten damage. Skybreak's fixed opening marks miss. HP 20.
- T2, clock 31: move adjacent to the eastern Wisp. Needle Thrust leaves it at
  1 HP; Storm Beacon kills it but cannot bridge the remaining gap to the boss.
  Spend its bonus play on Reprise, paying 1 HP to draw four without a reshuffle.
  Move back outside the held northward Breath. The 25-Time turn also crosses
  Claw, which spends 5 Stoneskin and 7 HP. Boss 72, HP 12. This is a real cost
  of using the bonus play, not merely a free extra action.
- T3, clock 56: move beside the boss. Stone Plate provides 4 Stoneskin and a
  2-damage Worldheart pulse; Frostbolt deals 4 and leaves Ice. Pass at 17 Time.
  Call grants 6 Block and creates an adjacent Wisp. Boss 66, HP 12, Skin 4.
- T4, clock 73: Shrapnel Burst hits the new Wisp for 7 and the chilled boss for
  9, spending its 6 Block and leaving 63 HP. Clockwork Mark kills the 1-HP Wisp
  and draws Warded Advance. Its summoned death correctly grants no extra play.
  Move from (4,2) via (3,2) to (3,3), outside the marked Skybreak. Pass 19 Time,
  before Breath's 21. Skybreak misses.
- T5, clock 92: autosave preserved at (3,3), 12/24 HP, 4 Stoneskin, boss 63/80,
  no living Wisps. Breath in 2 Time; Claw in 17. Three movement, two ordinary
  plays plus a banked play remain. Draw pile empty, discard ten. Hand: Crimson
  Draught, Parry Rhythm, Spur Vault, Leather Roll, Gust Step, Warded Advance,
  Cinch Straps. No further choice was committed before quitting for the fix.

The replacement Wisp never appeared on the turn clock despite its visible attack
intent. Independent code review confirmed `_enemy_summon_minions` assigned an
intent but never scheduled an activation. The initial Wisps functioned correctly.
The first four turns remain useful evidence for the boss's held patterns and Time
tradeoffs, but do not establish reinforcement pressure. The fix schedules each
living arrival once using the existing spawn delay. Resume the saved fight with
this code, and obtain fresh full-fight evidence if the reinforcement balance is
still uncertain. Do not silently count the earlier inert helper as a live threat.

#### Runtime repairs verified before resuming

The focused dragon test now drives Call Wisps through the real activation queue,
checks one delayed entry per replacement, serializes/resumes it, observes the
ordinary Wisp attack, and checks its single rescheduled turn. It passes.
`tests/run_tests.gd` also passes after the scheduling and forecast changes (the
existing exit-time ObjectDB warning remains).

Completed targetless-card previews now finalize a separate forecast copy. The
board and turn forecast include HP payment, Time and completion effects; cancel
and repeated refresh leave committed HP, piles, RNG and charges unchanged.
Limited Umbra uses known causes for displayed durability and keeps hidden actors
in the turn forecast. A lethal payment visibly says `CARD COST / DEFIANCE -1`
while retaining the separate turn-end warning. Actual confirmation pays once.

`output/dragon-revision/health-cost-preview-05.json` passes six real Metal/Mobile
1920×1080, 100% UI witnesses; all six images were inspected. They show Reprise
20→15 with chilled fatigue, 20→17 with ordinary fatigue, the same known result
under Umbra, lethal defeat, Defiance restoring 1→6, and that charge warning beside
an unknown enemy turn. Earlier failed probe reports were fixture/visibility
assertion iterations and are not accepted proof. The scoped independent reviewer
found no further confirmed defect; this is not final exact-HEAD task signoff.


#### Zekarion continuation after scheduling repair — victory

The same autosave and shuffle resumed, with no rollback. Decision-turn labels
below continue the manual notes; engine telemetry is one turn higher from clock31
onward, so the outcome is engine turn15/clock242 (14 recorded decision turns).

- Clock92: Cinch Straps grants10Block; Spur Vault hits the chilled boss for6.
  Move to(4,2). Breath chains onto that flank, spending4Block+5Stoneskin and
  applying Shock. HP stays12. The next reshuffle costs2HP.
- Clock108: Shock suppresses Spur Trip's attack and Warded Advance's Block.
  Their movement steps still provide an escape to(4,1); Fire entry spends2Skin.
  Claw misses. HP10, Skin3. These were status restrictions, not target-click bugs.
- Clock124: Crimson Draught heals2. A one-card12-Time pass crosses Call and the
  replacement Wisp's first activation. The Wisp takes2 Fire on entry and3 on its
  activation, then attacks for5, spending3Skin and2HP. It is visibly queued and
  active after the repair. HP10; Wisp3/8.
- Clock136: Frostbolt kills that Wisp. Cinch Straps grants7Block and draws2.
  Move to(4,3), outside Skybreak. Convert6Block to Skin; no HP lost.
- Clock152: Kite Bash deals3 and pushes east; Spur Vault deals4 and pushes south.
  The second displacement moves the held Breath lane away. HP10; boss50. This
  uses forced movement to change danger, rather than merely gaining damage.
- Clock169: Riposte Lunge5 and Needle Thrust7 deal12. Retreat to(4,2) outside
  Claw; Crowncoal Fire ticks during Claw and Call reduce the boss another6.
  HP10, Skin15; a fresh8HP Wisp appears with a real scheduled activation.
- Clock187: Shrapnel Burst strips Call's6Block, deals1HP to the boss and7 to the
  Wisp. Move to(5,3), then Stone Plate grants4Skin and Worldheart's2-damage
  adjacent pulse kills the Wisp. Move to(5,4), outside Skybreak. Boss28 after
  another Fire tick; HP10, Skin19. The next reshuffle costs3HP.
- Clock206: Clockwork Mark5 and Storm Beacon3 reduce boss28→20. Move three tiles
  to(5,7), collecting the dropped Storm Jar while escaping Breath. The pickup is
  an attack consumable, not a healing tonic. HP7, Skin19.
- Clock225: move to(5,6); Gust Step pulls the entire boss two tiles west and deals3.
  Unbound Pinion visibly restores movement. Kite Bash deals3 and pushes north
  onto Ice, applying Chill. Follow to(5,5) for Worldheart's3-damage end pulse.
  Accept Claw12 into3Block+9Skin; HP7, Skin16, boss11.
- Clock242: Spur Trip deals7 to the chilled boss; the collected Storm Jar deals4
  and wins. No Defiance or manual skill activation. Reward screen visibly grants
  Stormroad Coil,110Embers,+6HP, and says the first-dragon Shard was already earned.
  Continue opens the section map. Analytics records one milestone claim at13HP.

The live replacements now demand attention; the original inert T3 helper remains
excluded from reinforcement-balance evidence. Later turns demonstrate timed Wisp
removal, area attacks, defensive trophy damage, forced-movement lane changes,
using an arena pickup, and knowingly spending persistent defense to keep pressure.
The first long turn's extra kill play was costly, while later conservative hand
retention made the fight longer than necessary.

A concrete HUD ambiguity also contributed: the meter displayed `0 card plays`
and a badge reading only `NEXT` when a banked play was available right now. I
mistook that for no remaining action. The counter now shows total current plays,
with `1 BANKED` identifying the included stored play. This changes presentation,
not action capacity. Future play should use that extra play when its Time is
worthwhile; earlier runs remain valid conservative-play evidence, not optimal play.


### Noctyrax final cohort — completed in the native game

Manifest: `output/dragon-revision/noctyrax-final-01.json`; native run ID
`dragon-noctyrax-final-01`. Depth24, level4 skirmisher, 20/24HP, two movement,
ordinary acquired equipment without upgrades, all five previously earned dragon
trophies, Storm Beacon as a deliberate Light option, and a normal shuffled hand.
No manual skills or Defiance were used. Nine turns, clock145, victory at13HP.
The following numbers are reconciled with the local gameplay analytics, not just
hover forecasts. In particular, a board HP display during a preview is not the
committed HP for the turn.

- T1 clock0: Frostbolt4 leaves the near6HP Acolyte at2. Storm Beacon kills it,
  chains3 to Noctyrax, and supplies Light. Use both movement points to(3,4), then
  spend the kill play on Needle Thrust7. The first Eclipse preserves the upper
  refuge; no damage taken. Crowncoal Fire ticks3; boss88/101.
- T2 clock23: Clockwork Mark5, then retreat two tiles to(2,3). Cinch Straps7Block
  draws2. The held Void Claw misses; convert6Block to Stoneskin. Boss80 after Fire.
- T3 clock39: Leather Roll moves2 to(3,2) and grants9Block. Free Move2 to(5,2).
  Spur Vault deals6 and pushes the boss west one tile. The held Breath shifts
  with the body and misses. HP20, Skin12, boss71. This costs a movement card plus
  the entire free movement budget to preserve an attacking position.
- T4 clock55: Gust Step pulls the boss one tile east (terrain stops the second
  tile), deals7 including the resolved arrival, and moves to(5,1). Shrapnel7
  also destroys one crate. I misread the shifted Coil lane: Night Coil spends
  9Skin and pulls me back to(5,2). HP20, Skin3, boss54. Acolyte advances around
  the other flank; it is a live pursuing threat, not an inert hidden unit.
- T5 clock74: the second Eclipse preserves the lower refuge. Spike Check3
  pushes Noctyrax south and grants7Block. A planned escape encounters another
  crate; the uncommitted Spur Trip is cancelled. Nail Parry3 grants8Block.
  Free moves cross Fire to(5,3), then(4,3). The Eclipse spends5Block+6Skin with
  no HP loss. The Acolyte's piercing strike spends3Skin and1HP; Fire start costs
  3HP and the reshuffle costs2HP. End at14HP, boss41 after the Worldheart pulse,
  Fire and Bleed. This is a successful defensive choice with costly routing.
- T6 clock90: Riposte Lunge kills the6HP Acolyte and grants4Block plus a kill play.
  Move through its Crowncoal Fire to(3,4), spending2Block. Nail Parry3 grants5Block.
  The claw forecast shows the flank is still in its crescent. Choose the3-Time
  Parry Rhythm for5Block and2draw instead of a longer third card: total turn20
  reaches the next player activation before the Breath at the same clock. Claw15
  spends6Block+6Skin+3HP. HP11, boss32. The short defensive play matters.
- T7 clock110: Move2 into the lower refuge at(3,6), outside the held Breath.
  Frostbolt4 and the carried Crimson Draught heal2. Breath misses. HP13, boss25
  after Fire. This is a recovery turn that still makes progress.
- T8 clock126: Storm Beacon deals5 to the chilled boss and places Light2 at(4,5).
  Move to(3,5); Spur Trip7 applies Immobilize. Pass with one movement unspent.
  Night Coil misses, both braziers relight, and the third Eclipse returns to the
  upper refuge. The beacon protects the player beside the now-unlit lower
  brazier. Two Fire ticks leave the boss7HP; HP remains13.
- T9 clock145: Shrapnel7 wins through ordinary combat. Actual milestone shows
  Eclipse Mantle for the next run,150Embers,+6HP, and the already-earned Shard.
  Claim reaches the ordinary Victory screen at19HP. New Run visibly carries the
  Mantle, preserves the opening dialogue, and the Emaciated Man trades the
  retained1Shard for250Embers (150→400, Shards1→0). The450-Ember level remains
  unavailable, as expected. There is one milestone-claim and one exchange event.

Three Eclipses establish the near/far/near alternation in live play. The
no-boots build must account for routes, while beacon Light is a valuable way to
keep pressure. Worldheart supports knowingly taking a darkness hit; it does not
remove the cost of getting trapped, Fire routes, piercing helpers or long turns.
Both breath turns allowed a readable route out. The preserved acolyte eventually
closed and dealt damage, making its removal worthwhile. The independent fun
reviewer found no additional tuning blocker; this is not final exact-HEAD signoff.

### Final HUD and copy polish

`output/dragon-revision/banked-meter-01.json` passes a real Metal/Mobile render at
1920×1080, 100% scale. All three screenshots were inspected:3 total plays with
1BANKED,1 usable banked play, and0 after actually spending that banked play.
The full `tests/run_tests.gd` suite passes after the updated meter expectations
(session67355); only the existing exit-time ObjectDB warning remains.

The native final reward exposed inconsistent new wording beside the existing
Ascent Complete screen. New reward labels now use NEXT RUN and COMPLETE ASCENT;
relevant save notices say run. The entrance balance now says1Moltshard in the
singular. Internal receipt and analytics keys remain compatible. Reward probe 06
passes all 13 semantic captures at 1920×1080, 100% scale, Metal/Mobile. The two
changed screens (Noctyrax reward and the one-Shard entrance balance) were freshly
inspected; the other eleven retain the layouts inspected in revision 05.


### Tharokh attrition 02 — final opening replay completed

Fixture `output/dragon-revision/tharokh-attrition-02.json`, run namespace
`dragon-tharokh-attrition-02`. Depth 4 balanced, LV1, 14/24 HP, no skills or
Defiance, ordinary first-gate equipment, one common relic, normal shuffled hand.
Native Metal/Mobile, 1600×900 at 100% UI. This tests the final clock-12 Stonewake
opening, rather than the earlier clock-18 version. No resets or state edits.

- T1, clock 0: Frostbolt deals 4 and puts Ice under the 2×2 boss. Sidestep Slash
  approaches (1,4)→(3,4) and deals 5. Keep both free moves unused and pass at
  next clock 16. Stonewake at 12 places the two promised spines before T2;
  Tharokh becomes Chilled from the Ice. Boss 55, player 14.
- T2, clock 16: Butcher Chop deals 14 including Chill; Low Sweep deals 5 and
  immobilizes the boss. Two cards delay the next activation to 34, behind Claw
  at 30. The attempted northern route is unavailable. Move (3,4)→(2,5) through
  the visible Earth trap at (3,5), paying 5 HP and creating Rubble. This was a
  costly route choice, not Claw damage. Immobilize stops pursuit and the fixed
  west Claw misses. Boss 36, player 9.
- T3, clock 34: Cleaver Sweep destroys the adjacent 4-HP spine at (2,4), visibly
  shrinking Faultline's warning and opening a safe pocket. Patch Up heals 2,
  grants 2 Block and draws Shadow Step. Rubble limits movement: reaching
  (3,5) consumes both free points. The two cheap cards put the player at 49,
  tied with Faultline; the player acts first. Boss 36, player 11.
- T4, clock 49: Chain Bolt deals 6 including Chill. Gust Step pulls Tharokh two
  tiles west, deals 5 from the hit and 5 from the Earth trap at (2,3). Skip its
  movement because the current pocket is safe and now adjacent to the boss.
  Pass with free movement unused. Faultline consumes the remaining spine and
  misses the player. Boss 20, player 11; next clock 67.
- T5, clock 67: Cleaver Hook deals 6 and pushes the boss north; the committed
  south-facing Bedrock Breath shifts with its body. Crimson Draught heals 2.
  Move one tile east from (3,5) to (4,5), outside the two-column breath lane.
  Pass with one movement left. Breath at 69 misses. Boss 14, player 13.
- T6, clock 83: Shrapnel Burst deals 7 and Lantern Shot deals 4, drawing the
  final unreshuffled card. Retain Shadow Step as an approach option through
  the next spines; pass from the current safe tile. Stonewake at 88 creates
  the next two spines and replaces the old Ice surface. Reshuffle at T7 costs
  2 HP. Boss 3, player 11.
- T7, clock 101: the newly drawn Frostbolt kills the boss from range before
  Claw at 106. The Blink-plus-Kite Bash alternative is no longer necessary.
  Native milestone shows Worldheart, 110 Embers, +6 HP and +1 first-dragon
  Moltshard. Continue reaches the section map; the claim records 17/24 HP.

Analytics confirms victory at turn 7 / clock 101 / 11 HP and exactly one
milestone claim. It distinguishes the 5-HP trap error from the avoided Claw,
records the boss's own trap damage, and confirms actual spell/card damage.
The faster opening removed the old four-attacks-before-setup allowance. This
stress case still recovers through a defensive/terrain turn, affordable healing,
and displacement. No further Tharokh timing or damage change is justified.

### Accepted proof index

- `tests/run_tests.gd`: complete suite passed after summon scheduling, completed
  health-cost forecasting and banked-play HUD fixes (session 67355). Final
  subsequent production changes were reward/save-notice grammar only.
- Focused `tests/dragon_rewards_test.gd` and
  `tests/dragon_committed_patterns_test.gd`: passed. Rewards include deliberately
  injected failed saves, idempotent replay and all six trophy hooks.
- Python surface/card heuristic, progression and icon identity checks passed;
  `balance-assumptions.json` and `card-scores.json` retain the scoring output.
- Real Metal/Mobile at 1920×1080, 100% UI: `all-dragons-patterns-02.json`,
  `rewards-05.json` plus changed-copy `rewards-06.json`,
  `health-cost-preview-05.json`, `banked-meter-01.json`,
  `input-cursor-after-01.json`, and `skill-ui-renderer-03.json`.
  Relevant images were inspected as described in their owning log entries.
- Encounter fixture manifests retain self-healing generation/verification
  commands. User handoff fixtures will be regenerated after committed review.
- Superseded diagnostic/render attempts are archived locally under
  `/private/tmp/dragon-revision-scratch-20260926/`; failed iterations are not
  counted as accepted proof. Their findings remain in this log.


### Final peer-review rules copy follow-up

Final review caught two old Gale Grimoire entries describing an arena-wide hit
and an Eclipse entry that omitted the snuffed-brazier timing. The Gale pages
now explain the fixed-direction fan and safe flank. Eclipse explicitly snuffs
the marked brazier before the hit and names the surviving refuge or own Light
as protection. This is a rules-copy correction; encounter mechanics are unchanged.

The existing reward renderer probe now also opens these three actual Grimoire
pages. `output/dragon-revision/rewards-07.json` passes all16 captures at
1920×1080,100% UI, Metal/Mobile. All three changed Grimoire pages were inspected:
correct titles and icons, readable complete paragraphs, no clipped rules.
