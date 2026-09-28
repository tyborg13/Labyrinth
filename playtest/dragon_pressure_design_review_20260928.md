# Dragon pressure design review — 2026-09-28

Reviewer: `boss_fun_review`, read-only design assessment of baseline
`caea023d25edde6712cdbcd7524eb0afd15be5d9`. Scope is **all six dragons**. The
latest user playtest supersedes the earlier fun acceptance: repeated approach,
two attacks and a cheap sidestep still dominate. The earlier mechanical, save
and visual proofs remain useful correctness evidence; they do not establish
adequate encounter pressure. No production edit or Godot launch was made for
this review.

## Why the previous acceptance was too weak

The old notes credited a movement card once, a successful early Pass, an
incidental defensive rider or a harmless setup turn as sufficient evidence of
interesting combat. They also correctly separated pilot errors and Fatigue from
enemy damage, but did not consistently reject the safe offensive loop that
remained afterward. A decision can be meaningful without losing HP; nevertheless,
the existence of movement or defense is not evidence of an opportunity cost.

Player movement costs neither a card play nor Time. The normal allowance is two,
and the realistic balanced later cohort has three. Player return is base 9 plus
card Time; two fast 3-Time cards return at 15. Unmodified dragon cycles average
17.5–20 Time before depth/status changes. Most warnings therefore let the player
make ordinary attacks and solve one geometric problem with the independent
movement pool. Fire, Earth and Lightning also spend separate turns preparing
and consuming fields that the player has already left. Air offers a range-two
perch between its adjacent Gale and minimum-range-three Eye. Ice lets ordinary
attacks spend Mantle several activations before Shatter. Noct's out-and-back
relight fits inside two free moves and leaves both attacks available.

The required change is **coupled pressure**, not higher HP or mandatory damage:
one response to the body attack must interact with a different threatened area,
deadline, destructible object or finite defensive resource. A displaced/rooted
dragon can lose its body threat while a previously announced world-space field
still matters. Clearing that field should buy an earned opening.

Source anchors: `data/enemies.json:956–1592` holds the six cycles;
`dragon_combat_rules.gd:78` deliberately separates Meteor cells,
`:97` spreads spires, and `:152` spaces Skybreak marks two tiles apart.
`committed_pattern_shapes.gd` defines footprint-relative lanes, rings and wakes.
`combat_engine.gd:5726–5840` consumes the complete Earth/Fire payoff fields;
`:5890–5932` implements Light protection. The existing native journal is baseline
evidence, especially Fire02, Thar03, Zek01 and Noct01's admitted Breath error.

## Six concrete prototype directions

These are starting designs for implementation and native rejection testing,
not accepted tuning values. Keep current boss HP. Limit each intent to two
readable threat families; show their union and action order. Damage numbers
below are base values before the existing sequence scaling.

### Vyraketh — crossing heat versus losing attack access

**Exploit:** five scattered cells leave cheap corridors; the later blast hits
old ground, while pushing/rooting the body makes Maw easy. Player Fire can kill
the boss during otherwise empty turns.

Prototype cycle:

1. **Meteorfall:** five connected Fire marks forming a bent approach barrier,
   plus a live, blockable range-four bolt for 4. Prefer a four-cell strip beside
   the facing body edge with one bent shoulder, rather than maximally separated
   dots. Commit the field before the player responds.
2. **Cinder Breath:** the existing broad fan for 8, oriented so its cheap lateral
   escape meets that surviving barrier. The opposite longer route stays legal.
3. **Crownfire:** the announced Fire burst for 8 **and** a live two-step approach
   with a smaller 6-damage bite. Leaving the blast cannot automatically mean
   leaving the approaching body threat.
4. **Cinder Maw:** the 10-damage live pursuit renews a bounded connected Fire
   approach field for the following cycle. Treat this as replacement/top-up of
   at most five owned marks, not unlimited Fire accumulation.

Question: cross one Fire entry to keep a heavy attack, spend an overwrite/clear
action, take the longer route and lose access, or defend the weaker threat?
Keep shared self-damage and displacement payoff. Player-created Fire must not be
silently erased by the owned-field cap. Reject a design where every fan is still
solved by attacking from the same corner and taking one free lateral step.

### Tharokh — earn a corridor by spending damage on terrain

**Exploit:** incidental Sweep clears the only relevant spine; remaining spires
are too remote to affect the next escape. Faultline then destroys the entire
pressure field harmlessly. The approach-flank change improved one route but did
not remove the dominant attack-and-retreat policy.

Prototype cycle:

1. **Stonewake:** retain four 4-HP spires, but place two interlocking pairs across
   approach/escape routes instead of maximizing mutual separation. Add a held
   range-four ground shot for 4 so distant setup is not empty.
2. **Worldspine Claw:** existing advancing crescent, plus a 4-damage radius-one
   pulse around surviving spires. This pulse does **not** destroy them.
3. **Bedrock Breath:** existing Rubble lane, plus the same radius-one spire pulse.
4. **Faultline:** radius-two rupture for 8, with a modest live close attack when
   the body can reach; only this payoff consumes the announced spires.

Question: break a second rock to open a corridor, spend movement/Time going
around it, or block the small pulse while avoiding the larger body attack?
Preserve connectivity and two body exits. One incidental boss-hitting Sweep must
not clear both relevant route constraints. Deliberately destroying the field
may produce a genuinely safe payoff; do not regenerate it immediately and erase
that earned benefit. A nonconsuming pulse needs an explicit action flag/verb;
the current `terrain_burst` destroys every Worldspine.

### Vaeloryx — chase the eye or accept controlled displacement

**Exploit:** range two defeats Gale, and is also safe inside Eye. A sidestep
outside Dive's committed path gives several ranged-offense activations. Skyhook
is the main recurring threat; its trap damage must not carry the whole fight.

Prototype cycle:

1. **Skyhook:** retain the live approach/shot/Pull. If a previous wake remains,
   pulse its announced cells as the separate spatial constraint.
2. **Razor Dive:** retain the actual swept approach, but remember its surviving
   wake through the next Gale. Mark that future pulse immediately.
3. **Hollow Gale:** push from body distance one **and two**, while the fixed Dive
   wake deals a modest 4. The nearest outside-ring step should meet the old wake
   in the pressure witness; simply increasing the radius is insufficient.
4. **Eye:** retreat and hit the outer ring for 8, leaving only distance one as
   the eye. A small, blockable close strike threatens that eye; escaping beyond
   the outer ring remains the damage-free alternative at lost attack access.

Question: follow the retreat with paid mobility, accept the small close strike
and maintain offense, or disengage far enough to lose attacks? Never cover all
legal floor with the two damage regions. If arena clipping removes the far
escape, weaken/omit the close strike for that declaration. The fixed wake must
remain at the actual traversed route, not translate when the dragon is pushed.

### Iskaldra — spend hits on armor now or surrender ground

**Exploit:** ordinary offensive play removes one/two layers before Shatter, so
its large-radius threat rarely matters. A single line of Ice is easy to leave;
the later melee can then be rooted or outrun without interacting with the Ice.

Prototype cycle:

1. **Crystal Mantle:** capped armor plus an actual ranged frost attack instead
   of only an adjacent tap. Avoid a free distant setup activation.
2. **Shatterstorm immediately next:** retain the armor-dependent radius and
   live shrink-on-layer-break, coupled with a modest live approach/close strike.
   One reaction activation now asks whether to spend attacks stripping layers.
3. **Whiteout:** a bounded crossed two-wide trail, with committed axes, rather
   than one line that leaves the whole other axis neutral.
4. **Rime Talon:** live pursuit plus a declared Ice pulse on the surviving owned
   Whiteout trail. Show Chill/Freeze consequences in the forecast. Replace the
   old owned trail on the next Whiteout; do not accumulate a frozen board.

Question: use cheap/multi-hit attacks to reduce Shatter, retreat and defer boss
damage, overwrite an Ice escape route, or accept a guarded hit and its status?
Do not increase layers to create a health sponge. Player Ice overwrites and
secondary-damage builds remain valid advantages; they must be tested rather
than removed. A surface-snapshot pulse needs an explicit owned/announced tile
set so unrelated player Ice does not silently join it.

### Zekarion — cut the circuit or pay to remove its operators

**Exploit:** stepping between three isolated Skybreak marks avoids both that
attack and the later Overload. Once the two initial helpers die, the single
replacement can be cleared during its guaranteed reaction window; empty fuel
then makes Overload a free turn.

Prototype cycle:

1. **Skybreak:** declare a connected charged band linking one boss flank to the
   player's region, with a branch across the nearest escape. A two-wide short
   band is preferable to a larger number of disconnected points.
2. **Storm Lash:** live shot through that network; retain clear exact conduction
   preview. Safe off-network positions should sacrifice direct attack access.
3. **Overload:** announced charge snapshot plus a modest live, blockable shot.
   Replacing the charges removes the large threat and creates a useful weaker
   turn, not a completely empty resolution.
4. **Call Wisps:** replenish toward the existing cap of two while attacking.
   Prefer clear, separated flank positions, not a lethal trap, existing Fire or
   the same small AoE as the boss. Preserve one full player response window.

Question: attack the boss while defending the visible shots, spend plays on two
operators, or use elemental replacement to cut the field? Helpers need actual
attack opportunities or an observable removal cost. Initial helpers currently
refund a card play on a credited kill; summoned replacements do not. Count that
refund and Crowncoal/Worldheart kills honestly—one helper kill is not always one
lost boss attack. Keep snapshot Overload from secretly expanding through later
charges or conduction.

### Noctyrax — keep a refuge and defend its approach

**Exploit:** broad radius-two Light lets a one-step relight plus return solve
Eclipse while preserving both attacks. The large observed HP loss came from an
avoidable Breath/Pierce mistake. Hiding an Acolyte is not a substitute for a
public tactical constraint.

Prototype cycle:

1. **Night Coil:** lane/Pull plus snuff of the currently used refuge, declared
   in advance. Do not always spare the near refuge on the opening.
2. **Last Eclipse:** darkness damage outside Light plus a separate, held strike
   over one announced refuge region. Reaching the other refuge, creating Light
   elsewhere, or defending the smaller refuge strike are different answers.
3. **Void Claw:** live pursuit while visible Acolytes contest a refuge with an
   announced channel/attack. Killing/displacing a channeler removes that layer.
4. **Starless Breath:** the piercing lane plus visible helper replacement or a
   retained refuge channel. Avoid another attack-only thin-lane free sidestep.

Keep touch-to-relight and player-created Light legitimate. Light cancels the
darkness layer, not the physical/ordinary attack layer. The strike must actually
intersect the useful safe region; a two-wide line clipping one edge of a large
refuge may still leave a free one-step answer. At least one legal relight route
or ordinary defensive alternative must remain. Use public ritual marks and
visible channelers; do not count hidden-helper HP loss as design success.

## Cadence and implementation limits

- Prototype a clock-12 opening for each dragon; Earth already has this. This
  prevents a fast two-card activation from buying a second whole activation
  before the first mechanic. Retain repeat delays initially; coupled pressure
  should do the work before increasing overall speed.
- Preserve a full reaction activation to newly declared lethal geometry. If
  tuning allows a second unseen wind-up to resolve before the player's return,
  announce both beats earlier rather than hiding the follow-up. Evaluate actual
  depth modifiers, ties and Hourglass discounts, not only printed intent Time.
- A compound intent needs per-action regions, origins and ordering. Current
  committed-plan code shares an origin/direction. Appending a second shape can
  accidentally co-align both threats or move fixed marks with the body.
- Preview the resolved sequence: movement, contact hazards, first hit/force,
  then the second region. Do not sum overlapping tiles into duplicate hits or
  preview the second region from the player's pre-Push position. Dead/canceled
  actors and empty committed attacks retain their existing contracts.
- Bound fields and helpers; do not fill the board indefinitely. Do not remove
  player-owned surfaces to enforce an enemy-owned cap. Failed legal placement
  needs a readable reduced/fallback attack, not a silent blank setup.
- Save declared regions, retained fields, ownership, pulse stage and deadlines.
  Existing armed saved intents keep their old rules; new declarations use new
  data. Update the encounter specification, heuristic context/scorer together,
  presentation intent text and additive analytics for new pulse/channel verbs.

## Bounded adversarial diagnostic plan

Use focused engine witnesses for correctness, then actual native play for fun.
Do not revive the old headless playtest agent or use automated wins as fun proof.

For each boss, construct **two critical coupled-warning witnesses**, below,
with both realistic free-movement budgets F=2 and F=3: 24 primary checks. Use
production arena geometry, actual 2×2 body, cards, movement cost, surfaces,
status and queue. Include the common western adjacent state (body anchor 4,3;
hero 3,4) and an approach/ranged state reachable in its production arena; rotate
the witnesses and use actual legal positions when terrain changes them. These
are geometry witnesses, not fabricated native balance wins.

| Boss | Witness A | Witness B | Minimum pressure the pair must demonstrate |
| --- | --- | --- | --- |
| Fire | Connected wall plus Breath | Crownfire plus pursuit | The cheapest fire-free body escape crosses the other region; a safe alternative loses attack access, clears fuel, or spends a real defensive resource. |
| Earth | Claw plus small spire pulse after one incidental Sweep | Rubble Breath plus retained spire field | The remaining relevant spine still constrains the cheap escape; a dedicated break changes a specific dangerous route to safe. Full deliberate clearing earns relief. |
| Air | Gale plus fixed Dive wake, starting at body distance two | Retreat/Eye plus close strike | The range-two parking loop fails; following versus retreating has different paid movement, damage or defensive costs. |
| Ice | Mantle immediately before Shatter | Whiteout trail plus Rime | One normal reaction window cannot both preserve full unrestricted damage and erase every constraint; cheap layer breaks or trail replacement visibly improve safety. |
| Lightning | Charged band plus live Lash/Overload shot | Attack plus two separated replacement Wisps | Off-charge sidestep does not solve the live shot; ignoring helpers or removing them each has an observable cost after refunds/passive kills are counted. |
| Shadow | Snuffed used refuge plus Eclipse/refuge strike | Claw/Breath while a public refuge channel is active | Out-and-back relight plus two attacks fails to solve both layers; own Light or removing the channeler provides a distinct viable answer. |

At each witness, enumerate only short legal free-move routes up to F, but allow
the movement **before, between and after** two ordinary attacks. Use actual
movement cost: Rubble costs two to leave, the first-step exception is not reset
by split movement, Fire entry costs HP, Ice applies statuses, and movement-card
shortcuts may skip their move. Also try the legal normal control attack (Root,
Push or Pull) and a normal attack-with-Move/Block card when currently available.
Do not inspect future draw order or stack the hand for the native attempts.

Record the best legal attack-then-dodge plan's actual boss damage, free movement,
card Time, defensive depletion, net HP loss, status, field/helper removal and
next player/boss slots. Compare against the same available hand's credible
offensive alternative. An incidental rider on an already-best attack is not
automatically an opportunity cost. Count granted plays and conditional movement
refills, not just the printed two-play/F-movement allowance.

For fairness, demonstrate at least two different viable responses per witness
across ordinary hands: e.g. clear/attack versus guard/reposition. At least one
damage-free route should exist through advance positioning, paid movement,
clearing or defense; it need not fit the free allowance. Do not require a
specific rare card, a bespoke relic, Defiance or deliberately missing an input.

Add six opening checks at each F (12 checks): the first meaningful resolution
must occur before a second full fast offensive activation, with no unavoidable
spawn hit. Then test one earned-relief state per boss: field cleared, layers
broken, operator killed or refuge secured. Counterplay must actually remove a
threat and advance the cycle, rather than immediately restoring the same tax.

## Native rejection and acceptance criteria

Run a deliberate cheap-policy attempt and a competent adaptive attempt for
**every** dragon with realistic acquired gear and all earned earlier trophies.
Use both F=2 and F=3 cohorts where available. Across the first five dragons,
cover first-gate and later-gate budgets; Noct remains depth 24. No optimized
counter-build, future-hand knowledge or artificially increased boss HP to make
the mechanic last longer. Preserve actual actions and analytics in the journal.

Reject the iteration if any of these remains repeatable:

1. Two good attacks plus free movement solve a whole repeating cycle from the
   same safe perch or two-position loop. One movement-card expenditure early
   in the fight followed by free offense is **still rejection**.
2. The paired field never intersects the useful body-attack escape, or the boss
   loses most of its HP before its defining pressure can matter.
3. Removing one incidental target makes all later setup/payoff turns empty.
   Distinguish this from deliberately paying to clear the complete field.
4. The claimed cost is only Fatigue, an optional card, hidden information, an
   input mistake, a trap misread or unnecessary movement. Low final HP alone
   proves nothing. Conversely, a genuinely costly no-hit win can pass.
5. One response dominates every warning: constant cheap Root, range-two parking,
   a single overwritten tile, automatic Light, or passive helper kills. Keep
   those tools useful; the second threat must stop any one from erasing the
   whole encounter.

Acceptance needs at least **two distinct opportunity-cost decisions in the
first complete pressure cycle**, plus evidence that they recur or change when
the body/field moves. At least one must concern the boss's element-specific
counterplay, not only a generic guard card. Each accepted decision records the
available alternative and what it would have cost or gained. The adaptive line
must then demonstrate a fair win without relying on pilot mistakes. Retain an
earned recovery opportunity after successful counterplay; constant unavoidable
damage and inflated HP are not acceptable substitutes.

This is a design proposal and adversarial test contract. All six revised fights
remain unaccepted until their new coupled rules meet it in actual play.

## Implemented diagnostic scope

`tests/dragon_pressure_escape_probe.gd` is an isolated screen requested after
this design review. It samples all four warnings, not only the two proposed
critical witnesses: six bosses × four intents × two movement budgets gives
48 warning records by default. Each record includes a move-only control and
searches MM, MR, RM and RR with the production Quick Stab and Dull Bolt.
Moves may occur before, between or after
the attacks; the engine validates targets, applies damage/layer breaks, spends
ordinary movement and pays card Time. The declaration is never regenerated
inside a search branch.

The default starting position is a legal reachable adjacent tile in the
production arena; `--start entry` uses the ordinary entrance instead. Defaults
are Fire depth 4, Earth 8, Ice 12, Air 16, Lightning 20 and Shadow 24. Boss/depth,
intent and seed filters allow bounded follow-ups. Three movement uses actual
Pilgrim Boots, **including its path Light**, so the Noct result cannot quietly
omit that passive advantage. Two movement has no relics. Neither profile has
skills or prior trophies; realistic acquired-build play remains a separate gate.

Setup follows the real queue with empty Passes, replenishing setup-only HP and
Block so earlier damage does not terminate the geometry fixture. Each tested
warning removes that protection and player statuses, restores 24 HP, and
supplies only the two primitive cards. The engine carries actual terrain,
surfaces, helper positions, body movement and declarations between warnings.
This is a staged geometry trajectory, not a legal native fight or an estimate
of the probability of a particular hand. Boss HP is never increased.

Every terminal record reports its input sequence, attack damage, armor stripped,
movement expenditure, Time, current and post-warning attack access, HP and
status consequences. Direct warning resolution and the engine's forecast until
the next player return are separate. A warning that has not resolved before
that return is explicitly reported; zero HP loss alone never earns a pass.
The full-roster preview can include hidden helpers and is labeled accordingly.
No difficulty score, balance threshold or fun verdict is emitted.

Example focused command, only while holding the runtime lease:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange && python3 tools/godot_task_runner.py --task-id dragon-pressure-escape-v1 --stream -- godot --headless --path . --script tests/dragon_pressure_escape_probe.gd -- --boss vyraketh --intent cinderfall --output /private/tmp/dragon-pressure-escape-v1-vyr.json
```

Remove the boss/intent filters for the complete screen. A nonzero exit means
an invalid fixture, changed source, or a diagnostic error; it does not mean the
fight was hard. Source hashes bind the report to the exact files it inspected.
Static diff and Windows typed-empty-array checks passed. The Vyraketh
`cinderfall` smoke completed in 4.148 seconds; the full screen then completed
all 48 warning records in 137.804 seconds. Both exited 0 with `failures: []`
and unchanged source hashes. This is successful diagnostic execution, not a
difficulty verdict. The runtime lease was returned immediately afterward.

- Smoke report: `/private/tmp/dragon-pressure-escape-smoke-v1.json`; task run
  `dragon-pressure-escape-smoke-v1-1790611044199850000-63300`.
- Full report: `/private/tmp/dragon-pressure-escape-all-v1.json`; task run
  `dragon-pressure-escape-all-v1-1790611219972655000-63595`, runner session
  60753, exit 0. Its immutable log is under the matching
  `/private/tmp/labyrinth-godot-home/` directory.
- Compact exact-input extract:
  `/private/tmp/dragon-pressure-escape-witnesses-v1.json`. This is derived
  from the full report and repeats its source hashes; it is not a second run.

The existing high-risk task contract explicitly includes this screen. A new
worker preflight attempt correctly rejected the already dirty shared checkout;
the worker preserved it and continued under the coordinator's earlier clean
preflight and explicit shared-worker authorization. No production file belongs
to this diagnostic worker.

## First screen findings and fixture audit

These are isolated-warning witnesses, not a linked four-turn strategy. Every
reported clean route below includes both the direct warning and the complete
known engine timeline through the next player start. Two Quick Stabs are 18
damage/4 card Time when armor is absent; they deliberately stress cheap melee
access and do not claim that a realistic acquired hand contains two copies.

| Boss | Bounded result | Native follow-up |
| --- | --- | --- |
| Fire | F2 has no direct zero-damage result in these four staged warnings. With F3, Crown permits two attacks then `(3,4)→(2,4)→(2,5)→(1,5)`; Maw permits two attacks then `(3,4)→(3,5)→(3,6)→(2,6)`. Both spend all three moves and retain ranged, not melee, access after pursuit. | Continue the genuine ongoing attempt. Check whether retreat/re-entry and the next field produce recurring costs; a single safe recovery turn is not itself a failure. |
| Earth | **The field setup is degenerate: Stonewake declares zero spines.** The one-step Stonewake/Breath and Claw escapes therefore do not measure the intended paired-spine pressure. Faultline's damage here comes from its live shot, not retained spines. | Resolve the temporary-occupant safety gate below, then test actual four-spine pressure before tuning its damage or claiming failure. |
| Ice | Shatter permits one free step plus two attacks, but both attacks deal zero HP damage while removing Mantle 2→0. That is earned counterplay. Whiteout permits two melee attacks between `(3,4)→(3,5)→(3,6)`; F3 Rime permits two ranged attacks then a three-step retreat. | Check Mantle deadlines plus the following trail in a linked cycle, and whether acquired trophies erase the apparent cost. Do not label the armor-breaking turn free offense. |
| Air | Dive permits two attacks then `(4,5)→(3,5)`. Gale permits two attacks then `(4,5)→(3,5)→(2,5)`. Skyhook/Eye have no clean free escape in these staged states. | Challenge the recurring Skyhook/Eye decisions. Two recovery windows can be fair if they follow paid counterplay; do not reject solely because Dive/Gale can be dodged. |
| Lightning | Skybreak has direct safe routes, but the best F2 two-melee witness still loses 5 HP to helpers before return. The other three warnings have no direct clean escape here. | Verify visible helper costs and a fair adaptive line. Full-roster/hidden losses are not difficulty evidence, and lack of an ordinary-free route does not prove fairness. |
| Shadow | F3 with actual Pilgrim Boots has a clean two-offense route in every isolated warning. Eclipse needs only `(3,4)→(2,4)` after the attacks. F2's Void Claw spatial escape is not a clean timeline escape: helpers cause damage/status. | Prioritize a native F3 linked-cycle challenge, preserving real helpers and prior trophies. Do not use the earlier no-Boots cohort to dismiss the passive-Light concern. |

The generator path was compared with `tools/dragon_boss_inspection.gd` and
`RunEngine.begin_pre_battle_combat` / `_combat_layout_for_room`. Both use
`RoomGenerator.generate_room` then `CombatEngine.create_combat`. The generator
already configures Noctyrax braziers and preserves both attendants; RunEngine
does not later clean up boss crates or inject missing helpers. This screen's
Noct opening queue contains the real two Acolytes at `(2,3)` / `(6,5)`, due at
21 / 23, with Noct due at 12. Lightning likewise retains two Wisps, due at 9 /
10. No helper was deleted from any search.

The screen is still deliberately different from a playable factory fixture:
the boss/depth are explicitly selected instead of selected through a seeded
run graph; room connections and progression/equipment-drop context are omitted;
the two-card deck changes RNG consumption before initial helper intent sampling;
the adjacent start is staged before re-declaring **only the boss**; subsequent
setup is pass-only with replenished protection. Ordinary native entrance
warnings, realistic hands, acquired relic interactions, and helper intent
samples are not reproduced. These limits apply to all six results.

### Earth zero-field cause, not an accepted design finding

The seed's four normal crates occupy `(6,4)`, `(6,3)`, `(6,5)`, `(5,5)`.
For the 2×2 body at `(4,3)`, crates block the east and south anchor steps.
The staged player at `(3,4)` blocks the west anchor step. Only north remains.
`DragonCombatRules.spire_preserves_routes` requires at least two exits using
`CombatEngine._enemy_path_blockers`, which includes the player. Consequently
every candidate is rejected and `declared_tiles=[]`. This is a real engine
outcome of the staged adjacent state, not proof that a four-spine field is easy.

Normal entrance declaration can differ, but the same predicate is rechecked
by `_enemy_raise_dragon_spires` at resolution. Thus an actual entry→advance
witness is needed: transiently standing on one escape can potentially cancel
all previously declared spines even when none would worsen the permanent
layout. The narrow candidate repair is to exclude the transient player from
the structural exit calculation, retaining occupied-tile rejection for actual
placement and the existing floor connectivity check. Also consider preserving
the pre-placement structural exit count when random crates already leave fewer
than two; do not silently weaken the no-entrapment rule. Root owns that choice,
its focused regression, and the subsequent native verification.

### Bounded strengthening options after native challenge

For Earth, first prove actual spines exist. If its paired field still misses
both body escapes, reserve two valid spines across the cheap exit corridors
instead of optimizing separation alone. At body `(4,3)` / player `(3,4)`,
candidates near `(2,3)` and `(3,6)` would contest west `(2,4)` and south `(3,5)`
with radius-one pulses, subject to current safety and occupancy checks. Keep
count four, 4 HP, current Time and pulse damage. Require a farther escape and
a specific destructible spine that opens a useful route; a single incidental
boss Sweep must not remove both constraints. A second bounded option is a
small pulse that also follows adjacent Rubble, rather than increasing every
pulse's radius. Neither option is authorized or accepted by this review alone.

For Noctyrax, `refuge_tiles` currently marks the nearest brazier even when it is
unlit; it does not mark the Light actually used by Pilgrim Boots. In this
Eclipse witness the field is centered at `(3,2)` and the player `(3,4)` is
already on its outer edge. One step exits it and automatically supplies Light.
A minimal prototype could mark a fixed radius-three sanctuary-break around the
player's declared location/used Light for Eclipse alone, with normal guardable
damage. All Light would continue to stop the separate darkness damage. Paid
movement, an earlier Pass/reposition, guard, or travel to the other refuge
would remain alternatives. Keep smaller Claw/Breath windows for recovery; do
not chase newly painted Light or remove the relic's protection at resolution.

A stronger but larger alternative assigns that fixed patch to one existing,
visibly identified Acolyte channeler, whose death cancels it. Retain the helper
cap and a full reaction window. Count ordinary kill refunds, Crowncoal and
Worldheart kills before claiming that removing the channel costs an attack.
Neither option should become blanket unavoidable damage or a Light immunity
exception. First test whether the current isolated routes actually connect in
a native Pilgrim build; that is the unresolved acceptance question.

## Targeted v2 screen after spire routing and player-anchored Shadow fields

The two requested reruns completed under an exclusive runtime lease, then the
lease was returned before analysis. Each inspected four warnings at F2 and F3,
for eight records; both exited 0 with `failures: []` and unchanged source hashes.
The same probe, seed, staged adjacent start, primitive cards and protected
pass-only setup were used. These results replace the affected v1 geometry
observations; they do not establish difficulty, fairness, or native acceptance.

- Earth: `/private/tmp/dragon-pressure-escape-tharokh-v2.json`, 13.823 seconds;
  task run `dragon-pressure-escape-tharokh-v2-1790613356056811000-65650`,
  runner session 36934, exit 0.
- Shadow: `/private/tmp/dragon-pressure-escape-noctyrax-v2.json`, 21.361 seconds;
  task run `dragon-pressure-escape-noctyrax-v2-1790613393625710000-65717`,
  runner session 75181, exit 0.
- Exact-input comparison, derived without another simulation:
  `/private/tmp/dragon-pressure-escape-earth-shadow-comparison-v2.json`.
  Full reports retain per-source SHA-256 values and all terminal outcomes.

Earth now retains four 4-HP spires at `(2,4)`, `(3,5)`, `(3,1)`, `(1,3)` after
this staged-adjacent Stonewake. The old setup retained none. This layout differs
from the separately tested ordinary entry→advance warning, whose held spires
are `(2,3)`, `(1,2)`, `(1,6)`, `(2,5)`; do not conflate the two fixtures. The
structural route fix preserves terrain/whole-body connectivity and still denies
actually occupied placement marks. Its actual-entry regression failed exactly
one of 26 checks before the fix and passed all 26 after it; the suite extraction
preserves the meaningful entry, occupied-mark, and bottleneck checks.

| Warning | F2 result with two attacks | F3 result with two attacks |
| --- | --- | --- |
| Earth Stonewake | A clean two-step route `(3,4)→(3,5)→(4,5)` retains melee access. | The same cheap opener remains. It is not evidence that the later spines are harmless. |
| Earth Claw | No direct zero-damage route in the search; minimum direct loss 5. | Two attacks can precede the three-step escape through `(3,3)→(3,2)→(2,2)`. Clean through player return, but melee access is lost. |
| Earth Breath | No direct zero-damage route; minimum direct loss 5. | Three steps through `(3,3)→(2,3)→(2,2)` can retain two attacks. Clean through return, with ranged access but no melee access. |
| Earth Faultline | No direct zero-damage route; minimum direct loss 14. | Same result. This protected setup deliberately leaves all spires intact and does not search terrain attacks or paid movement. It is not proof that 14 damage is unavoidable in real play. |
| Shadow Night Coil | Two ordinary steps to `(4,5)` permit both attacks and retain melee access. | Same cheap route remains. |
| Shadow Eclipse | No direct zero-damage route; minimum direct loss 8. | No direct zero-damage route even with actual Pilgrim Light; the fixed radius-three ground sweep closes the old one-step escape. Minimum direct loss 8. |
| Shadow Void Claw | No direct zero-damage route; minimum direct loss 7. | Two attacks followed by `(3,4)→(3,5)→(3,6)→(3,7)` are clean through return and retain ranged, not melee, access after pursuit. |
| Shadow Starless Breath | The two-step route to `(4,5)` retains melee access. | Same relief route remains. The two-ranged-card line resolves the warning before return; the faster two-melee-card line returns before the warning, so its direct check must not be presented as a completed timeline resolution. |

All minima above describe the supplied two-attack search from these particular
warnings with no defense. F3 carries only Pilgrim Boots, not the five earned
trophies or an acquired deck. No guard, terrain clearing, helper kill/refund,
control, paid movement or early-Pass follow-up strategy was searched. Each
warning has its own reset; the listed routes have not been connected into a
legal full-cycle policy. Full-roster forecasts include helpers regardless of
player visibility; hidden losses do not count as readable encounter pressure.
Line-of-sight clips the fixed ground diamonds, so radius alone does not prove
the same escape cost from every pillar or arena edge.

The native questions therefore remain concrete. For Earth, verify that a
visible destructible spine can be cleared at a worthwhile cost before the
otherwise dangerous later field; test whether incidental boss attacks erase
that cost. For Shadow, demonstrate viable guard, paid-movement or earlier-return
choices against Eclipse with Pilgrim Light intact, then test whether cheap
Coil/Breath turns make those costs trivial over repeated cycles. The previous
nearest-brazier Noct01 partial study is recorded separately in the native
journal; it cannot accept the new anchor rules. No live Noct02 state was read
for this diagnostic or review.

### Native Noct02 follow-up, bounded independent verdict

The completed Noct02 audit in `dragon_pressure_native_20260928.md` now exercises
the current fixed player fields with the actual balanced F3/Pilgrim build and
all prior trophies. It wins T11/clock178 at 6 HP **after one Defiance**, not with
an unused charge. Three Eclipses require, in the chosen lines, an extra movement
cell, 8 actual Block during a deliberately long three-card turn, and another
four-cell escape using a non-attacking movement/guard card. T5's third attack
crosses the next Eclipse deadline; leaving it unplayed would return at the
player-first tie and preserve a new response. Helper cleanup produces a real
refund/banking choice, rather than an assumed full lost play.

These recurring visible tradeoffs support retaining current Noct tuning while
the other five native fights proceed. This is scoped evidence of improvement,
not an optimal-policy proof. The T6 skipped strike and T7 wrong-way Breath dodge
are pilot errors. T10's shallow free retreat actually takes Claw 15 (12 Stone
+ 3 HP), then a helper causes the lethal 3-HP loss and Defiance restoration;
unchanged final health must not be read as safety. Hidden helper damage is not
used as a fun criterion, and the actual failed route does not prove every
two-offense route fails. No arbitrary extra Noct run is required solely for
these acknowledged mistakes; a reproduced settled-preview discrepancy or a
concrete repeatable cheap strategy would justify another targeted iteration.
