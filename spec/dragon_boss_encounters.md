# Dragon encounter and reward revision

Content revision: `dragon_milestones_v1`, 2026-09-26. All six revised dragons
have completed native-game encounter studies; see the iteration record for
results and limitations. Encounters demand position, tempo, defense, attack,
and health decisions, and each victory grants a visible milestone reward.

## Acceptance and design

Combat keeps the board, committed danger, turn clock and card consequences in
focus. A player must be able to identify safe positions, but reaching one may
cost attack access, movement, time or a card. Avoid universal unavoidable hits,
dead random intents, free permanent safe corners, and health inflation as a
substitute for decisions. Each element retains a distinct tactical question.

Victory/reward surface: answer “what did defeating this dragon earn, and what
can I do next?” Lead with the dragon's defeat, then its unique relic and exact
rules, earned Molt Shard, Embers and recovered health. Claim/continue is primary;
use established reward components, focus navigation and reduced-motion handling.
The opening Emaciated Man service answers “keep this Shard for a reset or trade
it for permanent growth?” Show balances, explicit exchange value, level price,
affordability and a visible result before returning to dialogue.

Preserve pointer, keyboard and controller navigation, activation, cancel/back,
focus recovery and input handoff. Prove changed states with focused tests and
fresh real-renderer screenshots at 1920×1080, 100% UI scale.

## Encounter contract

The first five dragon gates occur at depths 4/8/12/16/20 in seeded elemental
order; Noctyrax is fixed at depth 24. Each uses the production kill-leader
objective, a 2×2 footprint, and completed-sequence scaling. HP and damage below
are base values. An intent's listed Time is added to the actor's base initiative;
it is not the entire interval. The cycle order is deterministic and persisted.

Directional lanes, fans and crescents commit their cardinal facing when revealed.
Moving the player does not rotate a revealed attack. A committed charge follows
its held relative approach, translated if the dragon is displaced and revalidated
against current blockers, movement costs and hazards. It does not reroute toward
the moved player. The held shape reanchors at the actual landing; blocked movement
cannot create an attack at an unreachable predicted landing. Full-footprint
surfaces and traps apply during pursuit. Rime Talon is the live-pursuit exception.
Previews include the current route, projected landing, held shape, surface fuel,
and conducted danger. Fixed Fire/strike/Worldspine marks remain on their declared
tiles. The same saved intent survives a content revision and resume; new intents
use current definitions. See [save compatibility](save_persistence.md).

| Dragon | HP / base initiative | Repeating cycle (intent Time) | Main decision |
| --- | --- | --- | --- |
| Vyraketh | 60 / 13 | Kindle Ground (4): up to three nearby shared Fire tiles; Crownfire (5): shared Fire detonation, 8 damage; Cinder Maw (5): Move 2, held range-2 crescent, 12 Fire; Cinderfall (6): held range-3 fan, 8 Fire | Leave a melee approach, consume or move Fire, or keep the dragon beside its own blast. |
| Tharokh | 64 / 15 | Stonewake (4): up to two 4-HP Worldspines, maximum two; Worldspine Claw (5): Move 2, held range-1 crescent, 12 Earth and Sunder 1; Faultline (6): 8 Earth within radius 2 of surviving spines; Bedrock Breath (5): held range-4 lane, 10 Earth | Spend an attack breaking a spine, reposition around the remaining burst, or defend to maintain melee pressure. |
| Vaeloryx | 58 / 12 | Hollow Gale (6): held range-3 fan, 6 Air and Push 2; Skyhook (5): held range-4 lane, 6 Air and Pull 2; Razor Dive (5): Move 3, held range-1 crescent, 10 Air and Bleed 1; Eye of the Storm (6): retreat 3 and Block 4 | Trade attack Time against the next displacement or charge, then decide whether to follow the retreat. |
| Iskaldra | 62 / 14 | Crystal Mantle (4): Frost Armor 1, maximum two layers, plus one layer from consuming one Ice tile under the body; Whiteout Lance (5): held range-4 lane, 6 Ice and at most two Ice tiles; Shatterstorm (6): held range-1 crescent, 7 physical; Rime Talon (5): Move 2 and live melee 10 Ice | Strip armor with a cheap hit, deny Ice fuel, escape the held sweep, or prepare defense for a pursuit that still tracks the player. |
| Zekarion | 60 / 14 | Skybreak (6): up to three declared strikes, 6 Lightning and Electrified; Tempest Breath (5): held range-3 lane, 7 Lightning, Chain 2 and Shock 1 on conducted hits; Storm Claw (5): Move 2, held range-1 crescent, 10 Lightning and at most one Electrified tile; Call Wisps (6): Block 4, summon one Wisp up to two alive | Weigh Wisp pressure against boss damage and read the conductor network when selecting a safe route. |
| Noctyrax | 72 / 14 | Last Eclipse (6): snuff the marked brazier before an 8-Shadow darkness hit, Eclipse duration 2; Void Claw (5): Move 2, held range-1 crescent, 12 Shadow and Expose 1; Starless Breath (6): held range-3 fan, 8 Shadow with Pierce; Night Coil (6): held range-3 lane, 6 Shadow and Pull 1, then restore both braziers | Use Light or the surviving refuge while preserving access to the boss; account for Pull and the next refuge change. |

Tharokh's first Stonewake opens at clock 12. Worldspines cannot occupy actors,
traps or existing terrain, preserve player routes, and leave at least two legal
one-step exits for the dragon's whole 2×2 body. Destroying one creates Rubble;
overlapping Faultline areas do not charge the same actor once per spine.

Vyraketh's Fire is ordinary shared Fire, not a separate attackable mark entity.
Kindle takes the two near approach tiles and one lateral corner where legal,
leaving the other flank open. Crownfire detonates Fire still present at the
remembered Kindle coordinates and can hit Vyraketh. Moving or consuming that Fire
denies the blast; unrelated Fire elsewhere does not join it. Surface fuel is
consumed once; preview and execution use the same
prepared intent. Iskaldra remains Freeze-immune, Vaeloryx Immobilize-immune, and
Zekarion Shock-immune.

Zekarion starts with two production Lightning Wisps; Call Wisps counts them
toward its two-alive cap. Noctyrax retains two production Acolytes. Two lit braziers are placed at oriented
(2,5) and (6,3), clear of terrain and traps; displaced loot is relocated without
changing its count. The opening Eclipse preserves the nearer refuge. Later
Eclipses alternate the brazier identity, including after resume. Snuffing is a
resolved attack effect: a dragon killed by the Eclipse action's Bleed tick cannot extinguish it. Lit refuge cells render beneath actors so the safe area stays
visible without hiding the character.

## Dragon trophies

All six trophies are legendary, boss-exclusive, and absent from ordinary random
relic offers. Each has a distinct 96px alpha illustration; see
[the art record](dragon_trophy_art.md). Effects use actual resolved actions and
explicit per-player-turn limits, including after save/resume.

| Trophy | Exact behavior |
| --- | --- |
| Crowncoal Heart | Once per turn, a real single-target card attack hitting an enemy on ground without an elemental surface leaves Fire there. The first Detonate consuming at least two Fire tiles that turn grants 6 Stoneskin after the blast. Existing surfaces remain intact, and an ineligible hit does not spend the trigger. |
| Worldheart | At turn end, convert up to 6 remaining Block into Stoneskin. Each Stoneskin gain deals half its amount, rounded down and capped at 4, to adjacent enemies. The pulse is secondary relic damage; it does not become a card hit, gain Frozen's direct-hit multiplier, or claim the surrounding card's kill credit. The cap is per pulse, not a once-per-turn cap. |
| Unbound Pinion | The first card action each turn that actually pushes or pulls one enemy at least two tiles refills movement to its normal cap and draws one card. Displacing two enemies one tile each does not qualify. |
| Winter's Hour | The first newly applied Freeze each turn draws two cards and grants one card play. Reapplying an existing Freeze or failing against immunity does not qualify. |
| Stormroad Coil | The first resolved Move or Blink each turn leaves Electrified at its origin. The first Lightning action that conducts through at least two distinct surface tiles that turn draws one card and grants one play. The conductor surface remains reusable; the bonus remains once per turn. |
| Eclipse Mantle | The first Blink each turn leaves a 2-HP Illusion at its origin. All owned Illusions radiate Light 2 while present. Noctyrax awards this trophy for the next run, since the current run ends at this fight. |

## Milestone and opening services

Every dragon defeat pauses on the dragon victory milestone, including Noctyrax.
The screen shows the defeated boss, trophy art and exact rules, actual Embers,
actual recovered HP, and either the first-dragon Molt Shard award or its
already-earned status. Ordinary room Embers, including any earned minion payout,
are added to the 30-Ember boss bonus. Healing is 25% of maximum HP, rounded up and
capped by missing HP. Exactly one Molt Shard is earned per run, on its first
successful dragon defeat. Elemental trophies apply to the current run immediately.

Continue leaves an elemental milestone for the opened section. Complete Ascent
leaves Noctyrax's milestone and commits the final run result. Until that action,
`victory` remains false and the pending milestone remains resumable. A stable
`<run-result-id>:dragon:<room-key>` identity prevents replay payouts. Noctyrax's
next-run gift has a profile-owned receipt; a new run saves the granted gift
stamp before acknowledging its removal from the profile. Failed acknowledgement
cannot grant it twice.

The opening Emaciated Man retains all ordinary and warning dialogue before
appending services. They can be reopened at the entrance through Speak. Exchange
one Molt Shard for 250 held Embers, level up at the normal campfire price (level 2
costs 180), open Skills, or Leave. Balances, price and disabled reasons are visible.
Skills returns to the service menu; services remain limited to the entrance NPC.
A level persists as normal progression, while unspent exchanged Embers remain
held run currency and obey ordinary banking rules.

Wallet receipts and analytics outbox entries save to the profile before the run
applies the credit/debit, allowing exact recovery without overwriting subsequent
run earnings. Milestone claims are likewise staged into the durable state before
leaving the reward screen. Intermediate claims retain their outbox in the run;
terminal claims reach the profile before the completed run save is removed.
Append-before-ack replay is idempotent. Save failures keep a recoverable boundary
and allow retry without duplicate banking, Shards, gifts or claim events. See
[analytics](analytics.md) for event names and payloads.

## Inspection build budget

`--scenario dragon` uses the production seeded map/arena, boss stats, initiative,
legal deck compilation and ordinary shuffled hand. It never sets debug boss mode.
At depth 4, balanced uses Iron Cleaver and Ward-Kite (two acquired commons), three
starter equipment slots, five common spells and one rare spell, Iron Buckler
(common relic), a Crimson Draught, no card upgrades, and 20/24 health. Skirmisher
swaps the two acquired equipment pieces and one movement spell. These are modest
first-section builds after five fights and services, not maximal counter-builds.
Later gates include all previously earned seeded dragon trophies. A fresh-profile
cohort uses levels 1/2/3/3/4/4 and cumulative level spending
0/180/430/430/770/770 Embers. General-purpose skills are Quick Wits, Measured
Breath, then Ghost Stride; no keystone. Boiled Leather joins at depth 8, Duelist
Rapier at 12, Trapdoor Spurs at 16 and Clockwork Arrowhead at 20. Reprise and Storm
Beacon join at 12/20. Ordinary relic counts are 1/2/2/3/3/3. Balanced uses Pilgrim
Boots; skirmisher substitutes Duelist Whetstone to expose movement/light costs.
No retired card upgrades are used. Explicit loadout options override the cohort.

## Iteration record

See `playtest/dragon_boss_revision_notes.md` for actual-game actions, observations,
failures and follow-up changes. Automated mechanics tests are correctness evidence,
not evidence of fun or a substitute for live play.
