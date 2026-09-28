# Dragon encounter and reward revision

Content revision: `dragon_pressure_v3`, 2026-09-28. User playtesting rejected
the preceding revision's difficulty for **all six** dragons. This revision couples
body attacks with geographically independent secondary threats. Its native
acceptance is still pending; the earlier wins are baseline evidence only. See
[revision ledger](../playtest/dragon_pressure_revision_20260928.md) and
[independent rejection criteria](../playtest/dragon_pressure_design_review_20260928.md).

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
surfaces and traps apply during pursuit. Ordinary melee and ranged actions use live
pursuit and targeting; their approach can still threaten a player who changes position.
Previews include the current route, projected landing, held shape, surface fuel,
and conducted danger. Fixed Fire/strike/Worldspine marks remain on their declared
tiles. The same saved intent survives a content revision and resume; new intents
use current definitions. See [save compatibility](save_persistence.md).

| Dragon | HP / base initiative | Repeating cycle (intent Time) | Main decision |
| --- | --- | --- | --- |
| Vyraketh | 60 / 13 | Meteorfall (5): seven held 4-Fire marks in a bent band plus a live range-4 shot for 4; Cinder Breath (5): held range-3 fan for 8 plus 4 within one tile of surviving marked Fire; Crownfire (5): detonate marked Fire for 8, then Move 2 / live bite 6; Cinder Maw (5): Move 2 / live bite 10 and renew a seven-cell band for 3 | Clear a passage through the Fire, defend the live attack, or preserve Fire beside the dragon for Crownfire self-damage. |
| Tharokh | 64 / 15 | Stonewake (4): four paired 4-HP spires (cap four) plus a held range-4 lane for 4; Worldspine Claw (5): held Move 2 / crescent 12 / Sunder 1 plus radius-1 spire pulse 4; Bedrock Breath (5): held range-4 lane 10 / Rubble plus radius-2 pulse 4; Faultline (6): radius-2 spire burst 8, consume spires, plus live range-4 shot 4 | Break a specific spine to earn a corridor before the body attack, or defend to retain melee access; surviving terrain matters throughout the cycle. |
| Iskaldra | 62 / 14 | Crystal Mantle (4): two layers (cap three, one extra from consumed Ice under body) plus live range-4 shot 4; Shatterstorm (6): held Move 1 / physical 7 within 1 + layers (cap four), then consume layers; Whiteout Lance (5): range-3 crossed two-wide lanes, 6 Ice / Ice trail; Rime Talon (5): live Move 3 / bite 10 plus 5 on surviving declared trail Ice | Spend cheap hits to shrink the immediate Shatter, deny Ice fuel, or clear/route around a trail while avoiding the live pursuit. |
| Vaeloryx | 58 / 12 | Skyhook (5): live Move 2 / range-4 shot 4 / Pull 2; Razor Dive (5): held Move 3 / swept-body perimeter 8 / Bleed 1, retain actual wake; Hollow Gale (6): body distance 1–2 for 6 / Push 2 plus fixed Dive wake 5; Eye of the Storm (6): held retreat up to 3 / outer ring distance 2–5 for 8 plus live close bite 4 | Leave both body and wake, counter displacement, or enter the weaker close strike to avoid the stronger outer ring. |
| Zekarion | 60 / 14 | Skybreak (6): seven held band marks, 6 Lightning / Electrified; Storm Lash (5): live Move 1 / range-3 shot 5 / Electrified plus radius-1 announced charge pulse 3; Overload (5): 6 within one tile of announced charges, retain them, plus live range-4 shot 4; Call Wisps (6): live range-4 shot 4, replace one Wisp up to two alive | Clear enough charge to earn space, defend the remaining live shot, or use the conductors while controlling helpers. |
| Noctyrax | 72 / 14 | Night Coil (6): held four-wide range-3 lane, 6 / Pull 1, snuff nearest refuge; Last Eclipse (6): 8 outside current Light plus fixed radius-3 sweep 5 around the declared player position, replace one Acolyte up to two; Void Claw (5): live Move 2 / bite 12 / Expose 1 plus radius-2 held ground sweep 4; Starless Breath (6): held range-4 fan 8 / Pierce plus fixed radius-1 held ground sweep 4 | Maintain Light while leaving the held sweep, spend movement/Time, or defend its weaker hit; player-made Light cannot erase the separate ground threat. |

All six first warnings resolve at initiative clock 12. Normal repeat initiative
is unchanged. No HP inflation supplies this revision's pressure. Every individual
area hits each actor once; explicitly separate actions can both hit. Compound
warnings include each live attack and fixed field. Body-held approach remains
fixed; intents flagged `live_body` keep ordinary pursuit while their field remains
anchored. Revealed surface snapshots store centers and derive live neighborhoods
from surviving centers. Later charge cannot enlarge the snapshot. Legacy saved
Overload has no neighborhood and still consumes only its original charges.

Fire and Lightning bands fold against arena edges, avoiding enemy footprints
and blocking terrain. A new
band retires only surfaces still owned by that dragon, preserving player or helper
replacements. Vyraketh remembers only its latest cinder coordinates. Replacing or
consuming their Fire shrinks both heat and Crownfire. Crownfire uses the ordinary
shared detonation, including self-damage when the dragon is nearby. Breath keeps
its held 4/4/6 fan. Fire does not grow permanently from repeated bands.

Worldspines preserve floor connectivity and at least two legal one-step exits for
the whole dragon. Pairs are staggered with a preferred two-cell gap and separated
from the next pair; ranged approaches still reserve a diagonal flank when legal.
Tharokh's body attacks preserve its own spires; ordinary player damage still breaks
them. Claw and Breath pulses leave surviving spires intact. Faultline consumes them.
Breaking one creates Rubble and immediately shrinks subsequent live spire danger.

Whiteout replaces only its previous owned Ice trail. Mantle negates one positive
direct hit per layer; the boss bar and feedback expose the remaining layers.
Peeling during Shatter shrinks its warning immediately; remaining layers are spent
on resolution. Iskaldra remains Freeze-immune, Vaeloryx Immobilize-immune, and
Zekarion Shock-immune. Air's wake is the actual resolved Dive area, serialized in
the enemy and snapshotted for the next Gale. It neither translates with a displaced
body nor accumulates across cycles. Gale spends it; no new surface kind is created.

Zekarion starts with two Wisps. Overload retains Electrified; every surviving
announced center threatens its own cell and orthogonal neighbors, once per actor
across overlapping neighborhoods. Surface replacement removes that center's area,
though another nearby center may still threaten it. The additional live shot is
distinct. Skybreak retires the boss's prior charge field before painting the next
band; helper/player-owned conductors retain ordinary surface behavior.

Noctyrax starts with two Acolytes. Both helper caps include opening helpers. Newly
summoned helpers always wait past the next queued player activation. Braziers at
oriented (2,5) and (6,3) remain clear of terrain/traps. Night Coil snuffs the refuge
nearest the player at declaration. Eclipse and later ground sweeps announce a
fixed area around the player at declaration (radii 3 / 2 / 1). This area never
follows later movement, painted Light or body displacement. Relighting by
walking or Blinking onto a brazier immediately removes darkness damage, while
the ground sweep remains guardable. Other Light, movement and alternative
refuges still provide counterplay. Old unflagged sweeps retain their saved
nearest-brazier anchor; only `field_anchor: player` opts into the new rule.
Braziers never automatically relight. Old saved snuff/restore flags retain their
one-time declared behavior. Refuges render below actors.

## Dragon trophies

All six trophies are legendary, boss-exclusive, and absent from ordinary random
relic offers. Each has a distinct 96px alpha illustration; see
[the art record](dragon_trophy_art.md). Effects use actual resolved actions and
explicit per-player-turn limits, including after save/resume.

| Trophy | Exact behavior |
| --- | --- |
| Crowncoal Heart | Once per turn, a real single-target card attack hitting an enemy on ground without an elemental surface leaves Fire there. The first Detonate consuming at least two Fire tiles that turn grants 6 Stoneskin after the blast. Existing surfaces remain intact, and an ineligible hit does not spend the trigger. |
| Worldheart | At turn end, convert up to 2 remaining Block into Stoneskin. Each Stoneskin gain deals half its amount, rounded down and capped at 4, to adjacent enemies. The pulse is secondary relic damage; it does not become a card hit, gain Frozen's direct-hit multiplier, or claim the surrounding card's kill credit. The cap is per pulse, not a once-per-turn cap. |
| Unbound Pinion | The first card action each turn that actually pushes or pulls one enemy at least two tiles refills movement to its normal cap and draws one card. Displacing two enemies one tile each does not qualify. |
| Winter's Hourglass | The first Ice card each turn banks 3 Time, capped at 3. Non-Ice cards spend only the reserve needed to reduce their Time to a floor of 1; unused Time lasts this combat. The relic badge shows the balance and card previews show exact cost. |
| Stormroad Coil | A single-target ranged attack may relay once through visible Electrified. Both legs obey normal range and line of sight, with a visible target. Direct contact is preferred; no extra target choice, damage or infinite network reach. Preview and animation show both legs. |
| Eclipse Mantle | The first Blink each turn leaves a 2-HP Illusion at its origin. All owned Illusions radiate Light 2 while present. Noctyrax awards this trophy for the next run, since the current run ends at this fight. |

## Milestone and opening services

Every dragon defeat pauses on the dragon victory milestone, including Noctyrax.
The screen shows the defeated boss, trophy art and exact rules, actual Embers,
actual recovered HP, and either the first-dragon Molt Shard award or its
already-earned status. Ordinary room Embers, including any earned minion payout,
are added to the 30-Ember boss bonus. Healing is 25% of maximum HP, rounded up and
capped by missing HP. Exactly one Molt Shard is earned per run, on its first
successful dragon defeat. Elemental trophies apply to the current run immediately.

Continue commits the claim, delivers the trophy with the standard relic acquisition
beam and HUD settlement, then fades into the opened section map. Reduced motion
keeps the receipt and final state without beam travel. Complete Ascent
leaves Noctyrax's milestone and commits the final run result. Until that action,
`victory` remains false and the pending milestone remains resumable. A stable
`<run-result-id>:dragon:<room-key>` identity prevents replay payouts. Noctyrax's
next-run gift has a profile-owned receipt; a new run saves the granted gift
stamp before acknowledging its removal from the profile. Failed acknowledgement
cannot grant it twice.

At the entrance after the first dragon milestone, Speak gives the Emaciated Man
one flavorful awakening conversation. Completing its last line saves a permanent
unlock; interrupting it or failing the save leaves it due. His ordinary Speak
dialogue then remains separate from the new Awaken Power room action. Exchange
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
