# Dragon encounter and reward revision

Content revision: `dragon_feedback_v2`, 2026-09-27. The first revision completed
native-game studies, but user playtesting found insufficient pressure and visual
clarity. The feedback revision is in progress; see
[its acceptance matrix](../playtest/dragon_feedback_revision_20260927.md). Earlier
playtest conclusions are baseline evidence, not acceptance of this revision.

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
| Vyraketh | 60 / 13 | Meteorfall (5): five declared 4-Fire impacts leave Fire; Cinder Breath (5): held range-3 fan with first-row shoulders, 8 Fire; Crownfire (5): surviving marked Fire detonates for 8; Cinder Maw (5): Move 2 and live melee 10 Fire | Escape the breath without crossing Fire, deny the later blast, or preserve Fire beside the dragon for self-damage. |
| Tharokh | 64 / 15 | Stonewake (4): four spread 4-HP spires, maximum four, plus melee 4 Earth; Worldspine Claw (5): Move 2 and held crescent, 12 Earth / Sunder 1; Bedrock Breath (5): held range-4 lane, 10 Earth and Rubble; Faultline (6): 8 Earth within radius 2 of surviving spires | Break a spine to open a safe route, navigate the lane and Rubble before the rupture, or defend while retaining melee access. |
| Vaeloryx | 58 / 12 | Skyhook (5): Move 2 and live range-4 shot, 4 Air / Pull 2; Razor Dive (5): held Move 3 and swept route perimeter, 8 Air / Bleed 1; Hollow Gale (6): adjacent body perimeter, 6 Air / Push 2; Eye of the Storm (6): retreat up to 3, then 8 Air at body distance 3–5 | Approach the safe eye, leave the storm entirely, or accept displacement while preserving attack access. |
| Iskaldra | 62 / 14 | Crystal Mantle (4): one layer, at most two, plus adjacent physical 3; consume one Ice under the body for one extra layer; Whiteout Lance (5): held two-wide range-4 lane, 6 Ice and full Ice trail; Rime Talon (5): Move 2 and live melee 10 Ice; Shatterstorm (6): physical 7 at body distance up to 1 + remaining layers (maximum 3), then spend layers | Use cheap hits to shrink the later danger ring, deny Ice fuel, or budget movement across the Ice trail. |
| Zekarion | 60 / 14 | Skybreak (6): three held marks, 6 Lightning / Electrified; Storm Lash (5): Move 1 and live range-3 shot, 5 Lightning / Electrified; Overload (5): 6 Lightning on all still-present charges announced at reveal, then consume those charges; Call Wisps (6): range-4 shot, 4 Lightning, plus one Wisp up to two alive | Deal with Wisps while choosing when to leave, replace or exploit charged ground before Overload. |
| Noctyrax | 72 / 14 | Night Coil (6): held range-3 lane, 6 Shadow / Pull 1, snuff one marked brazier; Last Eclipse (6): 8 Shadow outside current Light, Eclipse duration 2, replace one Acolyte up to two alive; Void Claw (5): Move 2 and live melee 12 Shadow / Expose 1; Starless Breath (6): held range-5 lane, 8 Shadow / Pierce | Relight a refuge before Eclipse, create Light, or fight through the darkness while managing replacement Acolytes. |

Tharokh's first Stonewake opens at clock 12. Worldspines cannot occupy actors,
traps or existing terrain, preserve player routes, and leave at least two legal
one-step exits for the dragon's whole 2×2 body. Destroying one creates Rubble;
overlapping Faultline areas do not charge the same actor once per spine.
Bedrock Breath precedes Faultline, so surviving spires constrain the lane escape
and its Rubble can raise movement costs during the subsequent rupture warning.
This order brings terrain decisions into the first cycle without increasing HP,
damage, spire durability or burst radius. Clearing a spine while hitting the boss
remains useful counterplay.
When no spines remain and the player is at least three tiles from the dragon's
body, the first mark prefers a legal diagonal neighbour of the declared player,
nearest the dragon. This reserves an approach flank that need not disappear in
the same adjacent attack as the boss. It uses the same route and body-exit
checks; unavailable flanks fall back to the existing spread score. Remaining
marks retain the original separation preference, and close-range placement is
unchanged. Marks never move to follow the player after declaration.

Vyraketh's Fire uses ordinary shared terrain. Meteorfall includes two near
approach tiles, the declared player tile when legal, and separated additional
positions. That Fire persists across Cinder Breath. Crownfire detonates surviving
Fire at the remembered coordinates and can hit Vyraketh; replacing or consuming
the Fire denies it. Unrelated Fire does not join the detonation. Cinder Breath
authors `pattern_min_flank: 1`, producing open-board rows of 4/4/6 tiles. This
closes the diagonal corner gap found in native play without widening the later
rows or removing the lateral route around the body. Other and saved fans retain
their default first-row width.

Iskaldra's latest Whiteout replaces its previous owned trail, preserving surfaces
painted by others. One active authored trail bounds long-fight Ice accumulation.
Mantle layers negate one positive direct hit each and are visible on the boss bar;
breaking a layer reports prevented damage. Removing layers during Shatterstorm's
warning immediately shrinks its danger radius. The burst spends remaining layers.
Iskaldra remains Freeze-immune, Vaeloryx Immobilize-immune, and Zekarion Shock-immune.

Vaeloryx's swept Dive uses only the actual surviving movement path. Preview and
animation use that same path; overlapping wake cells hit each actor once. A blocked
or interrupted approach cannot damage the unreachable landing. Eye of the Storm
uses Manhattan distance from the whole 2×2 body, leaving distance 1–2 and distances
beyond 5 safe. Radial displacement pushes away from the actual dragon body.

Zekarion starts with two Lightning Wisps; Call Wisps counts them toward its cap.
Overload snapshots Electrified tiles when announced. Replacing a charge removes
its danger; charges painted later do not enlarge the warning or conduct the burst
outward. Each actor is hit once, and only remaining announced charges are consumed.
Noctyrax starts with two Veilbound Acolytes and replaces one per Eclipse while below
the cap. New helpers enter the queue once and first act after the next queued player
activation, or later if their ordinary delay requires it. Saves preserve that slot.

Two Noctyrax braziers occupy oriented (2,5) and (6,3), clear of terrain and traps;
displaced loot is relocated without changing its count. Night Coil snuffs the
farther refuge first and alternates identities on later cycles, including after
resume. Snuffing follows its resolved attack: Bleed killing the dragon first cancels
it. Eclipse then announces darkness using current Light and never snuffs again.
Walking or Blinking onto an unlit brazier relights it immediately, making it safe
before the announced Eclipse. Braziers never restore themselves. Lit refuge cells
render beneath actors so safety stays visible without hiding the character.

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
