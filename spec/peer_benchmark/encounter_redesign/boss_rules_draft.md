# Dragons and Guardians on the six battlefield rules: draft for the director (2026-10-27)

Status: draft for the director's review, not an approved spec. Owner direction 2026-10-27: "Yes, that sounds right for
the dragons and guardians." Binding sources: `../element_rules/design.md` (rules, dials, cadence, forecast) and the
approved page `element_rules_v3.html`. Unapproved inputs: the Oct 20 proposals `enc-dragons` and `enc-guardians` in
`body.html`. Grounded in this worktree: `data/enemies.json`, `data/battlefield_rules.json`, `scripts/guardian_library.gd`,
`scripts/room_generator.gd` (`_pick_boss_enemy_positions`), `scripts/battlefield_rules/*.gd`.

Difficulty context: these figures come from the meas-02 bot (`baseline_revision7.md`; policy v2, 24 HP, no relics). By
director decision 2026-10-21 they are a relative benchmark only. Dragons are measured on the tier-3 deck, 50 runs each:
Tharokh 74%, Vaeloryx 50%, Iskaldra 50%, Vyraketh 36%, Zekarion 14%, Noctyrax 0%. The Guardian rates are my own count
from the raw `bot-t{1,2,3}-guardian.json.gz` records (90–109 runs each); the report does not split them. They are
Storm Cantor 99%, Gallows Roc 98%, Craghide 48%, Ashen Reaver 25%, Rimejaw 22%, Last Lamplighter 3%.

## Principles applied
- **One rule instance per fight, from the six.** Each fight is `{rule, source, cadence, dials}` using only design.md's
  anchors and dials. A dragon and its Guardian share an element, so they share a rule but never its dials. No helper's
  own intent may install a second instance (so no Gale Heralds: Call the Wind would replace the fight's rule).
- **The beat replaces the bespoke secondary field.** dragon_pressure_v3 bolted a separate field onto most dragon
  attacks: neighbourhood pulses, a wake snapshot, Ice and charge riders, player-anchored sweeps, and the spire pulses.
  Each is removed, and the element's beat does that job with existing pieces. The rules get fewer, and what remains is
  forecast on the board and stated in one sentence.
- **Fuel, then a player turn, then the beat.** A beat never fires in the same activation that lays its fuel. So every
  tile it will catch, freeze, strike or raise is on the board, and in the forecast, a full player turn before. The
  cadence ties the beat to a revealed intent (`on_intent`) or to a fixed count, so it always sits on the turn clock.
- **No exemptions.** A boss and its helpers are hit, pushed or thrown by their own rule unless an existing status or
  flag protects them: Anchored, Iskaldra's Freeze immunity, Zekarion's Shock immunity. The levers come from this:
  shove helpers onto the catching tiles, and lure the boss onto its own Ice or network.
- **Helpers are existing regular enemies, and they are finite.** Dragon lieutenants and Guardian attendants come from
  the section's biome group. They use the existing helper slots: the dragon slots (2,3) and (6,5) beside the dragon at
  (4,3), and the Guardian slots (2,3) and (6,3), oriented. Each one either feeds the rule or punishes the free step.
  Guardian helpers stop being re-summoned on every Guardian activation (`GuardianCombatRules.with_reinforcements`).
  Only existing summon intents (Call the Spark, Snuff, Call Wisps, Last Eclipse) bring helpers back.
- **Difficulty moves by numbers only, and is measured first.** Fights near the floor (Noctyrax 0%, Zekarion 14%,
  Lamplighter 3%) only lose bespoke pressure in this draft. Fights near the ceiling (Cantor 99%, Roc 98%) first get
  their designed initiative back.
- **Identity and art stay.** No new creatures or keywords. Two intent names collide with a rule name and must be
  renamed (one signal per concept): Rimejaw's "Frostbite" and Craghide's "Upheaval".
- **No phases in any fight.** A dial change at half Health appears only as a separate request (New dial request 1).

## Dragons

### Vyraketh, the Cinder Crown (Fire)
- **Today:** 60 HP, initiative 13. Its cycle is Meteorfall (lays 7 Fire marks), Cinder Breath (fan 8, plus 4 within 1 of
  surviving marks), Crownfire (detonates its marks for 8, then a bite) and Cinder Maw (a bite, then it renews the band).
  It fights alone. Bot win rate 36%.
- **Rule:** `{rule: wildfire, source: {kind: enemy, id: vyraketh}, cadence: {anchor: on_intent, intent: cinderfall},
  dials: {spread: all}}`
- **On screen:** "When Vyraketh breathes, every Fire tile spreads 1 tile in all four directions." (13 words)
- **Lieutenants:** 2 × `cinder_droplet` (4 HP, initiative 9), in the dragon slots (2,3) and (6,5). Spatter leaves Fire on
  the tile it hits, so the Droplets seed Fire next to you, away from the band. The breath then spreads it, so the
  Droplets are worth killing early.
- **Owner complaints:**
  - *Sidestep:* stepping out of the fan and coming back now means crossing ground that caught after the breath.
  - *Secondary threats:* two Droplets seed Fire from other angles.
  - *Shown:* one sentence, with the catching edges lit a turn ahead.
  - *Repeat:* the Fire's shape depends on where you and the Droplets left it, not on a fixed band.
- **Lever:** spread `all` also grows Fire toward the dragon. Crownfire's ordinary detonation hurts Vyraketh when it
  stands near its own Fire. Ice replaces Fire and cuts the spread.
- **Changes:** add the beat and two lieutenants. Remove Cinder Breath's second action (4 within 1 of surviving marked
  Fire), which the real spreading Fire replaces. Keep Meteorfall, Crownfire, Cinder Maw, HP, initiative and the
  clock-12 opening.
- **Uncertain:** whether beat-placed Fire counts as Vyraketh's own. The resolver tags it with the source id, so Maw and
  Meteorfall should retire it, which keeps the existing "Fire does not grow permanently" invariant. Whether Crownfire
  detonates spread tiles or only its remembered marks needs checking in code.

### Tharokh, the Worldspine (Earth)
- **Today:** 64 HP, initiative 15. Its cycle is Stonewake (4 paired 4-HP spires, plus a lane 4), Worldspine Claw (crescent
  12, plus a radius-1 spire pulse 4), Bedrock Breath (lane 10, plus a radius-2 pulse 4) and Faultline (radius-2 burst 8
  around its spires, which it consumes, plus a shot 4). It fights alone. Bot win rate 74%, the easiest dragon.
- **Rule:** `{rule: upheaval, source: {kind: enemy, id: tharokh}, cadence: {anchor: after_player_turn, every: 2},
  dials: {pattern: line_between, length: 5, health: 4}}`
- **On screen:** "After every second turn of yours, Tharokh's marked tiles rise as Outcrops." (12 words)
- **Lieutenants:** 2 × `burrow_grub` (12 HP), in slots (2,3) and (6,5). Burrow marks your tile and Erupt Pushes 1, which
  sends you into a freshly risen spine (Collision) or onto the marks. The Grub's warning says "move" while the marks and
  the crescent say where not to go.
- **Owner complaints:**
  - *Sidestep:* the spine rises between you and Tharokh, so coming back in costs a detour or a 4-HP break.
  - *Secondary threats:* the Grubs' Erupts.
  - *Shown:* the marks stay visible from the moment they're placed.
  - *Repeat:* stone accumulates until Faultline consumes it, so each cycle's board differs.
- **Lever:** break one tile of a spine (it leaves Rubble) to open a lane, push a Grub onto the marks to throw it, and
  stay clear of Tharokh's stone when Faultline comes.
- **Changes:** the rule's Outcrops become Tharokh's spires: one terrain kind, owned by the source.
  - *Removed:* Stonewake's paired raise (Stonewake keeps its lane 4); the Claw's and Breath's spire pulses.
  - *Retired:* the separate `dragon_spire` kind.
  - *Kept:* Faultline still bursts around, and consumes, Tharokh's own stone. Because more stone now feeds it, its
    radius drops from 2 to 1.
- **Uncertain:** the existing route guard (the Worldspine keeps floor connectivity and two exits for the 2×2 body) doesn't
  exist for `line_between`; see New dial request 2. If that request is refused, use length 3. Whether Tharokh's lanes
  pass through or stop at its own Outcrops (`preserve_owned_terrain`) needs checking.

### Iskaldra, the Rime Tyrant (Ice)
- **Today:** 62 HP, initiative 14, immune to Freeze. Its cycle is Crystal Mantle (layers, plus a shot 4), Shatterstorm
  (7 within 1 plus layers), Whiteout Lance (6 on crossed lanes, leaving an Ice trail) and Rime Talon (a live bite 10,
  plus 5 on surviving trail Ice). It fights alone. Bot win rate 50%.
- **Rule:** `{rule: frostbite, source: {kind: enemy, id: iskaldra}, cadence: {anchor: on_intent, intent: rime_talon},
  dials: {damage: 3}}`
- **On screen:** "When Iskaldra uses Rime Talon, Frostbite hits everyone on Ice for 3 and Freezes them." (15 words)
- **Lieutenants:** 2 × `rime_spitter` (5 HP, artillery), in slots (2,3) and (6,5). Rime Needle leaves Ice at the end of
  each line, from two angles that differ from the Lance. This follows v3's "fed by her Rime Spitters". The Spitters'
  Ice is not retired by the Lance, so it stays until something removes it.
- **Owner complaints:**
  - *Sidestep:* dodging the Lance onto its own trail is now a Freeze.
  - *Secondary threats:* the Spitters keep laying Ice where the Lance didn't.
  - *Shown:* the freeze tiles are lit a turn ahead.
  - *Repeat:* the Ice map changes with the Spitters' angles and with Frostbite using up the Ice under whoever it Freezes.
- **Lever:** knock a Spitter onto Ice before Rime Talon so the beat Freezes it (triple damage). Fire replaces Ice. Iskaldra
  is immune to Freeze but still takes 3 when she stands on Ice.
- **Changes:** add the beat and two lieutenants. Remove Rime Talon's rider (5 on surviving trail Ice), which the beat
  replaces at the same moment. Keep Crystal Mantle (including its Ice fuel), Shatterstorm, Whiteout Lance and its
  previous-trail replacement.
- **Uncertain:** whether a Mantle layer cancels the Frostbite hit on her. The combined risk of a bite of 10, then 3, then
  Frozen ahead of Crystal Mantle's shot needs measuring. Shatterstorm's reach growing with layers is a candidate for later
  simplification; it is not changed here.

### Vaeloryx, the Hollow Gale (Air)
- **Today:** 58 HP, initiative 12, immune to Immobilize. Its cycle is Skyhook (a live shot 4 with Pull 2), Razor Dive
  (swept perimeter 8, Bleed, recording its wake), Hollow Gale (ring 6 with Push 2, plus 5 on the snapshotted wake) and
  Eye of the Storm (outer ring 8, plus a close bite 4). It fights alone. Bot win rate 50%.
- **Rule:** `{rule: gust, source: {kind: enemy, id: vaeloryx}, cadence: {anchor: after_source_turn, every: 1},
  dials: {tiles: 1, direction: turn_clockwise}}`
- **On screen:** "After each Vaeloryx turn, its wind Pushes everyone 1 tile, then turns a quarter clockwise." (15 words)
- **Lieutenants:** 2 × `gust_shrike` (9 HP, flying), in slots (2,3) and (6,5). Dive drives a side Push across your line.
  The Shrikes are pushed by the wind too: this is v3's own example of shoving a Shrike upwind of a pillar.
- **Owner complaints:**
  - *Sidestep:* the wind moves you after every dragon turn, so the tile you stepped to isn't where you start.
  - *Secondary threats:* Shrike Dives from the flanks.
  - *Shown:* the next direction is announced one beat ahead, with landing ghosts.
  - *Repeat:* the wind turns, so each round's safe side differs.
- **Lever:** shove Shrikes so the next gust slams them into the corner pillars, the arena's terrain or each other. End your
  turn with open floor downwind.
- **Changes:** add the beat and two lieutenants. Remove the recorded dive wake, together with Hollow Gale's wake hit and
  the serialized `dive_wake` it depends on. Keep Skyhook, Razor Dive, Hollow Gale's ring Push and Eye of the Storm.
- **Build notes:** `turn_clockwise` is defined in design.md but not built; it ships with its first user. Its start
  direction isn't defined. I assume the cardinal from Vaeloryx toward the hero at fight start, then clockwise.
- **Uncertain:** whether the forced mover accepts a 2×2 body. If it refuses, Vaeloryx stays put by the existing rule and
  no new rule is needed.

### Zekarion, the Raging Tempest (Lightning)
- **Today:** 60 HP, initiative 14, immune to Shock, starts with 2 Wisps. Its cycle is Skybreak (7 band strikes for 6,
  which Electrify), Storm Lash (a live shot 5, plus a radius-1 charge pulse 3), Overload (6 within 1 of announced
  charges, plus a shot 4) and Call Wisps (summons, cap 2). Bot win rate 14%.
- **Rule:** `{rule: lightning_storm, source: {kind: enemy, id: zekarion}, cadence: {anchor: on_intent, intent:
  tempest_breath}, dials: {damage: 5, chain: 1}}`
- **On screen:** "When Zekarion uses Overload, lightning strikes every Electrified tile for 5, with Chain 1." (14 words)
- **Lieutenants:** unchanged: 2 × `lightning_wisp` at the start, and Call Wisps keeps one-for-one replacement up to two.
  No helper is added at 14%.
- **Owner complaints:**
  - *Sidestep:* leaving the band isn't enough, because Chain reaches you from anyone struck beside you.
  - *Secondary threats:* the Wisps, which are now also conductors.
  - *Shown:* the strike tiles are lit a turn ahead.
  - *Repeat:* the network is whatever Skybreak, the Wisps and you left.
- **Lever:** lure Wisps onto the network before Overload: the strike hits them for 5. Zekarion takes 5 on its own network,
  without the Shock. Between beats, your Lightning conducts through its network.
- **Changes:** remove Overload's neighbourhood hit and Storm Lash's charge pulse (both `surface_snapshot` riders). Overload
  keeps its shot 4 and becomes the beat. Damage is set to 5, one below today's 6, because Zekarion is the
  hardest elemental dragon; tune it by measurement.
- **Uncertain:** whether design.md's "chain = jumps" and the glossary's "within that many tiles" mean the same thing
  for a storm.

### Noctyrax, the Last Eclipse (Shadow)
- **Today:** 72 HP, initiative 14, final boss, starts with 2 Acolytes, two braziers. Its cycle is Night Coil (lane 6, Pull
  1, snuffs the nearest refuge), Last Eclipse (8 outside Light, a sweep of radius 3 around your declared tile, summons
  an Acolyte), Void Claw (bite 12 with Expose, plus a radius-2 sweep) and Starless Breath (fan 8 with Pierce, plus a
  radius-1 sweep). Bot win rate 0%.
- **Rule:** `{rule: shadowstep, source: {kind: enemy, id: noctyrax}, cadence: {anchor: on_intent, intent: void_claw},
  dials: {blink: 3, who: all_hidden}}`
- **On screen:** "When Noctyrax uses Void Claw, enemies hidden in the dark Blink 3 tiles toward you." (15 words)
- **Lieutenants:** unchanged: 2 × `veilbound_acolyte`, and Last Eclipse keeps one replacement up to two. Shroudstep keeps
  them at range, so they sit in the dark until the beat brings them in.
- **Owner complaints:**
  - *Sidestep:* after the Eclipse, the dark delivers enemies to the tiles nearest you.
  - *Secondary threats:* Acolytes arriving beside you.
  - *Shown:* the beat is on the clock right after the Claw, and the Eclipse's darkness is visible a turn before.
  - *Repeat:* who steps in depends on what your Light and sight hold.
- **Lever:** keep enemies in sight with the braziers, your Light or Truesight, because a visible enemy doesn't step. Lay
  Fire, Ice or network around you so arrivals land on it.
- **Changes:** remove the three player-anchored sweeps (radii 3, 2 and 1, `field_anchor: player`); the beat takes their
  place, once per cycle. Keep Night Coil, Last Eclipse's darkness damage and summon, Void Claw, Starless Breath and the
  braziers.
- **Why on Void Claw, not Eclipse:** the Eclipse makes the dark (the fuel), so beating on it would break "a player turn
  between fuel and beat".
- **Uncertain:** how `umbra_eclipse` changes sight, which decides how many enemies are hidden at the beat. With
  `all_hidden`, a hidden Noctyrax also Blinks, and Umbra privacy means there is no ghost for it (Open question 4).

## Guardians
The six Guardians keep their identities, arenas, helper ids and relics. Every helper becomes finite. Only the existing
summon intents (Call the Spark, Snuff) bring one back.

| Guardian (element) · today | Rule instance | On-screen sentence | Helpers: ids, count, placement, why |
|---|---|---|---|
| **Ashen Reaver** (Fire) · 40 HP, init 10; bot 25% | `wildfire`; source Reaver; `after_player_turn`, every 2; `spread: toward_player` | "After every second turn of yours, the Reaver's Fire spreads 1 tile toward you." | 2 × `ash_hound`, slots (2,3) and (6,3), opposite flanks. Their bites punish the dry side you step to, while the Fire creeps from the Reaver's lanes. |
| **Rimejaw** (Ice) · 38 HP, init 10; bot 22% | `frostbite`; source Rimejaw; `after_player_turn`, every 1; `damage: 0` (the one unusual dial) | "After each of your turns, Rimejaw's Frostbite Freezes everyone standing on Ice." | `rime_whelp` + `rime_spitter`, slots (2,3) and (6,3). The Spitter's needles and Rimejaw's trail and Pounce lay the Ice; the Whelp contests the dry crossings. |
| **Storm Cantor** (Lightning) · 38 HP, init 20 (designed 11); bot 99% | `lightning_storm`; source Cantor; `on_intent: peal`; `damage: 3, chain: 2` (widest Chain) | "When the Cantor uses Peal, lightning strikes every Electrified tile for 3, with Chain 2." | `lightning_wisp` (renewable via Call the Spark, cap 1) + `bell_tender` (finite), slots (2,3) and (6,3). The Tender lays connectors toward you; the Wisp pressures dry ground and conducts. |
| **Gallows Roc** (Air) · 36 HP, init 20 (designed 9); bot 98% | `gust`; source Roc; `after_player_turn`, every 1; `tiles: 1, direction: toward_source` | "After each of your turns, the Roc's wind Pushes everyone 1 tile toward it." | 2 × `roc_fledgling`, slots (2,3) and (6,3). The wind drags them in toward the Roc too; they peck where you land. Two arena Air traps stay. |
| **Craghide** (Earth) · 44 HP, init 12; bot 48% | `upheaval`; source Craghide; `after_source_turn`, every 2; `pattern: line_between, length: 3, health: 2` (brittle) | "After every second Craghide turn, the marked tiles rise as Outcrops." | 2 × `stoneback_mite`, slots (2,3) and (6,3). Driving Claw Pushes you onto marks or beside stone; a dead Mite leaves Rubble. |
| **Last Lamplighter** (Shadow) · 44 HP, init 10; bot 3% | `shadowstep`; source Lamplighter; `after_player_turn`, every 1; `blink: 1, who: all_hidden` (shortest step) | "After each of your turns, enemies hidden in the dark Blink 1 tile toward you." | 1 × `wick_shade` at the start, slot (2,3). Snuff brings a second (cap 2) from the darkened side; the shades linked to that outage fade on Last Procession, as today. |

| Guardian | Answers the four complaints | Changes from today / removed |
|---|---|---|
| Ashen Reaver | *Sidestep:* punishing Executioner's Fall (Exposed 3) means crossing the Fire that crept from its lanes. *Secondary:* the Hounds no longer respawn, so killing one opens a lasting dry flank. *Shown:* one sentence and the catch edges. *Repeat:* the Fire accumulates (Fire ground doesn't expire), so the yard closes over the fight. | Add the beat. Remove the per-activation re-summon. Every intent unchanged. |
| Rimejaw | *Sidestep:* you can't end a dodge on its trail. *Secondary:* the Spitter's Ice and the Whelp. *Shown:* the freeze tiles are lit at the end of your turn. *Repeat:* the safe floor shrinks as the trails and needles spread. Lever: push Rimejaw (not Freeze-immune) onto Ice and end your turn, and it is Frozen: it skips its turn and takes triple damage. | Add the beat. Rename its "Frostbite" intent (name to be chosen by the director). Remove the re-summon. Uncertain: damage 0 is allowed by design.md but no shipped instance uses it, so check that a 0-damage Ice hit still Freezes a Chilled unit. |
| Storm Cantor | *Sidestep:* every connected tile strikes, and Chain 2 reaches past the edge of the network. *Secondary:* the Tender extends the network; the Wisp returns only through its intent. *Shown:* the strike tiles are lit a turn ahead. *Repeat:* the network grows from where the Tender and Cantor place it. | Peal's single-conductor impact (6, with Shock on a conducted hit) is replaced by the beat; Peal keeps Move 1. Initiative restored: Cantor 20 → 11, Tender 19 → 12. Remove the re-summon. Keep the Wisp's Guardian initiative override (19) until measured. |
| Gallows Roc | *Sidestep:* the wind drags you back toward the Roc before it acts, so dodging Razor Pinion means ending upwind of open floor. *Secondary:* the Fledglings at your landing tile. *Shown:* landing ghosts. *Repeat:* the traps and the pillars change each pull. | Add the beat. Restore initiative: Roc 20 → 9, Fledgling 19 → 12. Remove the re-summon. Proposed: the existing `anchored` flag on the Roc (Gale Herald precedent), so "toward it" is literally true (Open question 5). `toward_source` is defined in design.md but not built. |
| Craghide | *Sidestep:* a ridge rises between you and the beast, and Groundsplit hits beside its stone, so the cover is also the quake's reach. *Secondary:* the Mites' Pushes. *Shown:* the marks are visible. *Repeat:* brittle stone accumulates and breaks into Rubble. | Its raise action (2 `crag_outcrop`, cap 2) is replaced by the rule. The rule raises the same Outcrop kind, owned by the Craghide, so Groundsplit counts it with no change. The intent keeps Move 2 and needs a new name (it is called "Upheaval"). Remove the re-summon. |
| Last Lamplighter | *Sidestep:* the dark creeps in behind you every turn. *Secondary:* the Shades step closer unless they're lit. *Shown:* one sentence; hidden enemies are never forecast (Umbra privacy). *Repeat:* which side is dark changes with Snuff and Procession. | Add the beat. Remove the re-summon outside Snuff. It is the hardest Guardian, so it gets the gentlest dial (Blink 1). |

## Variety check
No two bosses share a rule with the same source kind, cadence, dials and helpers. The same-element Warband and Snare
instances are in the last column, so the boss fights don't restate them.

| Boss | Rule | Cadence | Dials | Helpers | Same-rule neighbours and the difference |
|---|---|---|---|---|---|
| Vyraketh | Wildfire | on_intent cinderfall | spread all | 2 cinder_droplet | Reaver: toward_player, every 2nd player turn, hounds. Slagmaster: toward_player, every 2nd source turn. Snare: room, away_from_entry. |
| Ashen Reaver | Wildfire | after_player_turn 2 | spread toward_player | 2 ash_hound | Vyraketh: all, on its breath. Slagmaster: same spread, but counted on its own turns, mortar captain. |
| Tharokh | Upheaval | after_player_turn 2 | line 5, health 4 | 2 burrow_grub | Craghide: line 3, health 2, source turns, mites. Thornmother: line 5, health 3, source turns. Snare: room, exit_lane. |
| Craghide | Upheaval | after_source_turn 2 | line 3, health 2 | 2 stoneback_mite | Tharokh: longer, sturdier, player-turn count. Thornmother: line 5, health 3, weaver captain. |
| Iskaldra | Frostbite | on_intent rime_talon | damage 3 | 2 rime_spitter | Rimejaw: damage 0, after every player turn. Oracle: damage 2, every 2nd source turn. Snare: room, damage 1. |
| Rimejaw | Frostbite | after_player_turn 1 | damage 0 | rime_whelp + rime_spitter | Iskaldra: damage 3, once per cycle. Snare: room, damage 1, same cadence. |
| Vaeloryx | Gust | after_source_turn 1 | 1 tile, turn_clockwise | 2 gust_shrike | Roc: toward_source, after player turns. Stormcaller: aimed. Snare: room, toward_entry. |
| Gallows Roc | Gust | after_player_turn 1 | 1 tile, toward_source | 2 roc_fledgling | Vaeloryx: turning, source turns. Snare: room, toward_entry, same cadence. |
| Zekarion | Lightning Storm | on_intent tempest_breath | damage 5, chain 1 | 2 lightning_wisp (renewable) | Cantor: 3 / chain 2, on Peal. Dynamo: 4 / chain 0, on discharge. Snare: room, 3 / 0. |
| Storm Cantor | Lightning Storm | on_intent peal | damage 3, chain 2 | lightning_wisp + bell_tender | Zekarion: 5 / chain 1. Dynamo: chain 0, thralls. |
| Noctyrax | Shadowstep | on_intent void_claw | blink 3, all_hidden | 2 veilbound_acolyte (renewable) | Lamplighter: blink 1, every player turn. Prior: blink 3, every 2nd source turn, followers. Snare: room, blink 2. |
| Last Lamplighter | Shadowstep | after_player_turn 1 | blink 1, all_hidden | wick_shade (+1 via Snuff) | Noctyrax: blink 3, once per cycle. Snare: room, blink 2, same cadence. |

Built today: the rules, the anchors, Wildfire (all three spreads), Frostbite, Lightning Storm, Shadowstep (`who`
included), Upheaval `line_between`, and Gust `fixed`, `aimed` and `toward_entry`. Not built but defined in design.md:
Gust `turn_clockwise` (Vaeloryx) and `toward_source` (Roc).

Where this draft departs from the v3 table:
- Vyraketh beats once per cycle on its breath, not every other round. This makes it a one-for-one replacement of the
  breath's rider.
- Tharokh uses `line_between`, not "beside its spires", which has no geometry yet.
- Iskaldra beats on Rime Talon, not every other round, replacing that intent's rider.
- Noctyrax beats on Void Claw, with Blink 3 rather than v3's Blink 2.
- The Reaver spreads toward you, not all four ways. `all` is Vyraketh's spread, and unexpiring Fire in every direction
  would fill the yard.
- Rimejaw beats after your turns, not on Pounce. Pounce lays Ice on your tile in the same activation, so that beat
  couldn't be forecast a turn ahead.
- The Cantor uses Chain 2, not 1.
- The Roc beats after your turns, not every round.
- Craghide uses a 3-tile line, not a ring, which has no geometry yet.
- The Lamplighter uses Blink 1, not Blink 3, because it is the hardest Guardian.

## New dial requests
1. **Half-Health switch (dragons only).** This changes one cadence or dial value once, when the source first drops to
   half Health or below. The panel sentence is replaced, the turn clock redraws, and one banner shows. Guardians stay
   flat (v3: "a Guardian sets one dial unusually").
   - *Why:* v3, the approved framing, says "a dragon turns the dials up at half health", but design.md defines no
     trigger for it. Gust, Shadowstep and Lightning Storm don't accumulate, so without it turn six can still feel like
     turn one.
   - *Basis:* the existing half-Health predicates (the card condition `half_hp`, "if Target at half health", and the
     relic trigger `bloodied`); the Umbra-depth `boss_enrage` modifier, which already changes a boss's numbers;
     `dispatcher.install`, which already re-installs an instance mid-fight (the Gale Herald's repeated Call).
   - *Proposed values, only if approved:*
     - Vyraketh: on_intent cinderfall → after_source_turn 2.
     - Tharokh: after_player_turn 2 → 1.
     - Iskaldra: on_intent rime_talon → after_source_turn 2.
     - Vaeloryx: tiles 1 → 2.
     - Zekarion: chain 1 → 2.
     - Noctyrax: none until it measures above 0%.
2. **Route guard for `line_between`.** Skip a mark that would break floor connectivity or leave the source with fewer than
   two legal one-step exits.
   - *Why:* Tharokh's 5-tile spine on a 7-wide floor with random arena terrain could box in its 2×2 body or split the
     floor. Thornmother and Craghide are 1×1, so the risk is smaller there.
   - *Basis:* Tharokh's existing Worldspine guard (`DragonCombatRules.spire_preserves_routes`) and the Snare's
     "never seal the last open way out" guard on `exit_lane`.
   - *If refused:* Tharokh uses length 3.

## Open questions for the director
1. **Escalation:** adopt request 1 for the dragons, or ship them without phases and decide after the owner plays them?
2. **Ownership of beat-made ground and stone:** this draft treats Fire and Outcrops placed by a beat as the source's own.
   The resolvers already tag them with the source id. Then Vyraketh's band renewal retires spread Fire, Tharokh's
   Faultline consumes the rule's Outcrops, and Craghide's Groundsplit counts them. Confirm that this is the intended
   reading, and that Crownfire detonates only its marks.
3. **A helper as the source:** should one fight take its rule from a helper, so that killing it ends the rule? The
   strongest case is the Cantor's storm sourced from the 5-HP Bell Tender: kill the bell-ringer and the storm stops. It
   uses an existing dial and is the clearest answer to "too few secondary threats", but the rule could be gone by turn 2.
4. **Noctyrax `who`:** with `all_hidden`, a hidden Noctyrax also Blinks in, with no forecast ghost (Umbra privacy). Keep
   it (no exemptions), or limit the step to `["veilbound_acolyte"]`?
5. **Gallows Roc:** add the existing `anchored` flag, so its "toward it" wind leaves it in place as the Gale Herald's
   does, at the cost of the player's Push on it? And define `toward_source` as the cardinal from the hero to the
   source, locked one beat ahead (the same lock as Wildfire `toward_player`)?
6. **Lieutenant counts and the order of the tuning steps:** two lieutenants for each solo dragon, or scaled to measured
   difficulty (for example one for Vyraketh at 36%, two for Tharokh at 74%)? Should the Cantor and Roc initiative
   restore be measured on its own before their beats are added?

## Dropped from the Oct 20 proposals
- **Dragons' three acts and Wrath at half health.** This covered the roar and banner, the arena changing for good, the
  harder act-two rotation, and Noctyrax's acts at 66% and 33%. It is a phase system, not dials. The only part that can
  survive is one value change at half Health, and that needs a new trigger (request 1).
- **Cataclysms with shelter** (Worldbreak, Crown of Cinders, Hollow Sky, Absolute Zero, Thunderhead, Totality), and
  their return as a fifth step. Each is a second, near-board-wide attack. A larger beat with its own dials can't be
  expressed as one instance. The idea survives only as each dragon's ordinary beat on its signature intent.
- **The Break meter** (14 + 2 per section; a broken dragon loses its next action and takes +6). The owner already dropped
  it in v3 as a rule of its own.
- **The act-two arena changes:** the outer ring turning to Rubble or Ice, the Umbra closing a ring per act, Fire that
  stops burning out, charged ground that stops resetting, and a Standing Wind after every enemy turn. All were bespoke.
  The turning wind survives as Vaeloryx's rule from turn one. Accumulation now comes from the rules themselves.
- **The lieutenants' new jobs:**
  - *Dropped:* Mites repairing spires; Spitters giving Iskaldra Mantle layers; Wisps as Overload conductors within 2
    (Chain covers it); Acolytes as brazier-snuffers (Night Coil already snuffs). Mites and Acolytes keep their existing
    intents.
  - *Kept, using existing intents:* Droplets leaving Fire (Spatter) and Shrikes shoving you sideways (Dive's side Push).
    Shrikes no longer shove you into a wake; that half was dropped, because the wake was removed.
- **The Guardians' signature rules:**
  - Pyre: Fire that never burns out does nothing, since Fire has no expiry; Blazing +2 was a new status.
  - The Hunt: marking the Pounce landing is a preview question for the clarity layer, not a rule.
  - The Choir: this is now just Lightning Storm.
  - The Gallows: +2 on Collisions, and Grounded after a missed Dive.
  - Crag Armour: half damage while touching an outcrop.
  - The Vigil: +3 damage in Light, and Shades rising in darkness.
  Each was a per-boss keyword.
- **Guardian Fury at half health** (two Fire lanes, Pounce twice, Peal on two conductors, Hookwind pulls 3, three
  outcrops, both braziers snuffed). This was a phase. The Guardians stay flat and are told apart by their one unusual dial.
- **Kept from the Oct 20 proposals:** two lieutenants that feed the mechanic, finite helpers with no free re-summon, the
  pace fix (Cantor and Roc back to their designed initiative), "the same language for all six", unchanged base HP, and
  the clock-12 opening warnings.

## Director decisions on the draft (2026-10-27)
1. **Escalation: adopt New dial request 1 for dragons.** The approved v3 page already says "a dragon turns the dials
   up at half health". It is generic (any rule instance can declare one `at_half_health` dial change), not a per-boss
   rule. Use the draft's per-dragon values; Noctyrax gets none for now. Guardians stay flat.
2. **Ownership:** Fire, Ice and Outcrops placed by a beat count as the source's own. Vyraketh's renewal retires spread
   Fire, Faultline consumes the rule's Outcrops, and Groundsplit counts them. Crownfire detonates only its own marks.
3. **Helper as source:** no. The Cantor stays the storm's source. The fight is already the easiest (99%), and losing
   the rule by turn 2 would make it easier still.
4. **Noctyrax `who`:** its followers only (`["veilbound_acolyte"]`). A hidden 2×2 boss arriving with no forecast ghost
   breaks "shown a turn ahead".
5. **Gallows Roc:** add the existing `anchored` flag. `toward_source` is the cardinal from the hero to the source,
   locked one beat ahead.
6. **Lieutenants:** two each for Vyraketh, Tharokh, Iskaldra and Vaeloryx. Zekarion and Noctyrax are unchanged. Measure
   the Cantor and Roc initiative restore as its own ablation inside the same measurement pass.
7. **New dial request 2 (the `line_between` route guard): approved,** reusing the Worldspine and Snare guards.
8. **Names:** Rimejaw's "Frostbite" intent becomes **"Rime Bite"**, and Craghide's "Upheaval" intent becomes
   **"Crag Heave"**.

Owner approval is needed before any build (inbox `boss-rules`).
