# Element battlefield rules: binding design (director, 2026-10-23)

Owner-approved proposal: `../encounter_redesign/element_rules_v3.html` (inbox `element-rules`, APPROVED 2026-10-23:
"Let's try this as described and we can iterate once I see and feel it in person"). Owner principle: no one-off rules
(memory `design-no-one-off-rules`, feedback.md 2026-10-23). This file is the binding implementation contract. Every
number and sentence here is a director decision; implementers never invent player-facing values. Anything this file
does not decide is reported as `TODO_DESIGN_<what>`.

## 1. What a battlefield rule is
A battlefield rule is one of six beats. Each beat is one existing-primitive effect applied on a trigger. A fight
declares at most one rule instance:
`{rule, source, cadence, dials}`.
- `rule`: `gust` | `wildfire` | `frostbite` | `lightning_storm` | `upheaval` | `shadowstep`.
- `source`: `{kind: "enemy", id}` (it ends when that enemy dies) or `{kind: "room"}` (it lasts the whole fight).
- `cadence` (the beat):
  - `{anchor: "after_source_turn", every: N}`: after every Nth turn the source takes (skipped turns count).
  - `{anchor: "after_player_turn", every: N}`: after every Nth player turn.
  - `{anchor: "on_intent", intent: "<intent id>"}`: when the source resolves that intent.
- `dials`: rule-specific, listed below. Every dial is data; nothing is hard-coded per encounter.

There is no wielder immunity. A unit is protected only by existing statuses (Anchored, Fireproof, Skate and so on).
The Gale Herald holds in its own wind because it is Anchored (its data flag `"anchored": true`), not by a type rule.
Bosses, leaders, guardians and constructs have no exemption; an immobile unit stays put because the forced mover
already refuses it.

Save data: `combat_state.battlefield_rule` holds the instance plus `beats_fired`, the counter toward its next beat, and the optional
`half_health_switched` latch.
The field is additive; older saves have none.

Turn clock: the next beat appears in the existing turn-order projection (`current_turn_order`) as an entry
`{kind: "beat", rule, at}`, placed right after the turn that will trigger it. The view layer draws it (director unit
el-04).

Forecast: every rule exposes a pure `forecast(engine, state) -> Dictionary`. It reports what the next beat will do,
computed by running the real resolver on a copy. Half-Health switching is absent from all damage/action resolvers;
only acceptance of a committed transition can switch. Hover, provisional targeting, activation/turn-clock/PASS
forecasts and at-rest wind queries cannot replace dials/cadence, latch a switch or change the held Gust direction
through a switch. Capture the held direction before the simulated resolver. Collision view markers omit the saved event
sequence, since commit-only switch events can shift that bookkeeping without changing the collision:
- `moves: [{actor_key, from, to}]` (Gust pushes, Upheaval displacements, Shadowstep Blinks);
- `tiles: {catch, freeze, strike, rise}` (tile lists);
- `hits: [{actor_key, damage, statuses}]`;
- `collision_markers` (the existing format).
Hidden enemies never appear in a forecast the player can see; Umbra privacy rules apply, as in `WindView.landing_ghosts`.

Analytics: one additive event `battlefield_rule_fired` with fields `{rule, source_kind, source_type, beat_index,
affected_units, tiles_changed, damage_to_player, damage_to_enemies, half_health_switched}`. Document it in `spec/analytics.md`.

## 2. The six rules (exact semantics)
1. **Gust** (`gust`). The wind Pushes every unit `tiles` tiles in `direction`, using the existing Wind resolver
   (`Wind.push_all`): farthest downwind first, Anchored excluded, blocked slides become Collisions.
   - Dials: `tiles` (int); `direction`:
     - `aimed` (the existing Stormcaller/Gale Herald announcement, locked when announced);
     - `toward_entry` (the Snare);
     - `toward_source`: the hero-to-source cardinal, using the same dominant-cardinal rule as Wildfire
       `toward_player`, mirrored. Lock at installation and after each beat; hero movement cannot relock the held beat;
     - `fixed:<dir>`;
     - `turn_clockwise`: start with the source-to-hero cardinal when installed. After each beat rotate
       `(0,-1) → (1,0) → (0,1) → (-1,0) → (0,-1)`. The next direction is announced one beat ahead.
       Both new modes use the existing Gust announcement/landing ghosts and forced mover, including Anchored.
       An unanchored 2×2 source moves through that mover when its whole footprint can land; no new exemption.
   - Today's Wind keyword becomes this rule. The Wind glossary entry is renamed Gust and keeps the existing `wind` icon:
     it is the same concept.
2. **Wildfire** (`wildfire`). Take a snapshot of every Fire tile at the start of the beat. For each one, place Fire
   ground on the adjacent tile in each spread direction, using the same placement the player's Fire cards use. Placing
   ground replaces ground, and terrain or walls that can't hold ground stop it, exactly as the primitive does. Damage
   to units comes only from the existing Fire ground rules.
   - Dials: `spread`:
     - `toward_player`: one cardinal direction, the source's cardinal toward the hero, locked one beat ahead and shown;
     - `away_from_entry`;
     - `all`: the four cardinals.
   - Fire placed by the beat follows the existing Fire ground rules. (The `lasting` dial was dropped: Fire ground has
     no expiry today, so it did nothing.)
3. **Frostbite** (`frostbite`). An Ice hit of `damage` (int, may be 0) strikes every unit standing on an Ice tile. By
   the existing rules, a unit on Ice is Chilled, so the hit Freezes it and expends the Ice beneath it.
   - Dial: `damage`.
4. **Lightning Storm** (`lightning_strikes` primitive). Lightning strikes every Electrified tile for `damage`, using the
   existing Lightning Strikes damage and Shock. When `chain > 0`, each unit hit starts the existing Chain primitive
   with that many jumps; Electrified tiles relay as they already do. The strike does not create or replace Electrified
   tiles.
   - Dials: `damage`, `chain` (0 to 3).
5. **Upheaval** (`upheaval`). One beat ahead, tiles are marked by `pattern`. On the beat, each marked tile rises as an
   Outcrop with `health` (existing Raise Terrain). An occupant is displaced exactly as Erupt displaces its occupant,
   with Collisions as usual. Marks are shown as soon as they're placed.
   - Dials:
     - `pattern`:
       - `line_between`: the existing Thornwall geometry, `length` tiles perpendicular between the hero and the
         source;
       - `exit_lane`: one tile of the hero's shortest way out, chosen by the existing Snare rubble-lane selection;
       - `ring_around_player` (later);
       - `beside_terrain` (later).
     - `health`.
   - Guards: `exit_lane` keeps the existing Snare rule: never seal the last open way out.
     Every `line_between` user (including Thornmother) reuses Worldspine's
     `DragonCombatRules.spire_preserves_routes`: preserve floor connectivity and at least two legal one-step
     structural exits for the source's full footprint, ignoring temporary actors. Where the objective declares
     exits, also reuse the Snare exit guard. Test candidates in line order with earlier accepted marks treated
     as stone. Skip only refused marks; keep the remainder. Recheck at resolution, including after displacement,
     so changed terrain or old held marks cannot seal routes. The shared unweighted Snare traversal uses FIFO and
     stops at the first reachable declared exit (or immediately when every goal is blocked). Weighted Rubble
     routing retains its deterministic Dijkstra cost/step/discovery order. There is no third connectivity implementation.
6. **Shadowstep** (`shadowstep`). Every living enemy that is hidden from the player (Umbra-hidden and not revealed by
   Truesight or Light) Blinks up to `blink` tiles toward the hero. The landing is the open tile visible to the player
   within `blink` that is nearest the hero; ties keep the existing deterministic tile order. Process enemies nearest
   the hero first. An enemy with no such tile stays put. The landing triggers ground like any entry.
   - Dials: `blink`; `who`: `all_hidden` (default) or a list of enemy types.

## 3. Instances (first wave)
Sentences are exact and owner-facing (the panel's one line). The panel title is the rule name.

| Fight | Rule | Source | Cadence | Dials | Panel sentence |
|---|---|---|---|---|---|
| Warband · The Stormcaller | gust | captain | after_source_turn, 1 | tiles 1, direction aimed | After each of the Stormcaller's turns, its wind Pushes everyone 1 tile. |
| Warband · The Slagmaster | wildfire | captain | after_source_turn, 2 | spread toward_player | After every second Slagmaster turn, its Fire spreads 1 tile toward you. |
| Warband · The Rime Oracle | frostbite | captain | after_source_turn, 2 | damage 2 | After every second Oracle turn, Frostbite hits everyone on Ice for 2 and Freezes them. |
| Warband · The Dynamo | lightning_storm | captain | on_intent discharge | damage 4, chain 0 | When the Dynamo discharges, lightning strikes every Electrified tile for 4. |
| Warband · The Thornmother | upheaval | captain | after_source_turn, 2 | line_between, length 5, health 3 | After every second Thornmother turn, the marked tiles rise as Outcrops. |
| Warband · The Hollow Prior | shadowstep | captain | after_source_turn, 2 | blink 3 | After every second Prior turn, its followers hidden in the dark Blink 3 tiles toward you. |
| Umbral Snare · earth | upheaval | room | after_player_turn, 1 | exit_lane, health 3 | After each of your turns, a marked tile on your way out rises as an Outcrop. |
| Umbral Snare · fire | wildfire | room | after_player_turn, 1 | spread away_from_entry | After each of your turns, the Fire spreads 1 tile away from the entry. |
| Umbral Snare · air | gust | room | after_player_turn, 1 | tiles 1, toward_entry | After each of your turns, a headwind Pushes everyone 1 tile toward the entry. |
| Umbral Snare · ice | frostbite | room | after_player_turn, 1 | damage 1 | After each of your turns, Frostbite hits everyone on Ice for 1 and Freezes them. |
| Umbral Snare · lightning | lightning_storm | room | after_player_turn, 1 | damage 3, chain 0 | After each of your turns, lightning strikes every Electrified tile for 3. |
| Umbral Snare · shadow | shadowstep | room | after_player_turn, 1 | blink 2 | After each of your turns, enemies hidden in the dark Blink 2 tiles toward you. |
| Last Light · every section (spx-08) | shadowstep | room | after_player_turn, 1 | blink 2, all_hidden | After each of your turns, every enemy hidden in the dark Blinks 2 tiles toward you. |
| Ordinary fight with a Gale Herald | gust | that Herald | after_source_turn, 1 | tiles 1, aimed, for the call's rounds | After each of the Gale Herald's turns, its wind Pushes everyone 1 tile. |

Changes to existing behaviour, all intended:
- The Stormcaller's held wind and ordinary Wind now push after the source's own turns, not after every enemy's turn.
- Shadow Snare: Shadowstep is added, and the existing Umbra rings stay.
- Ice Snare: Frostbite is added. The thresholds stay Ice.
- Lightning Snare: the Thralls' lines become Electrified ground (see 4), struck by the storm.
- Earth Snare: Outcrops replace the Rubble lane.
- Fire Snare: the existing `fire_rows` becomes Wildfire `away_from_entry`, seeded by Fire on the entry row at the
  start, with no change for the player.

## 4. Ordinary enemies use the same pieces (owner-approved)
- **Briar Weaver, Thornwall:** marks its existing `line3_perpendicular_front_of_hero` and raises Outcrops (health 3)
  there on its next turn, as an Upheaval with the same displacement. Bramble is retired as a keyword and terrain kind.
- **Hoarfrost Seer, Icefall:** the marked tiles take the shown damage and become Ice ground; no Ice Pillars. Ice
  Pillar is retired everywhere: the Rime Oracle's pillar wall becomes its Frostbite row, and the Gust Shrike's Dive
  drops its Ice Pillar handling.
- **Arc Thrall, Tether:** Lightning Strikes along the line between two aligned Thralls, with the same partner, length
  and damage, so the line becomes Electrified ground. Tether is retired as a keyword. Arc Jab is unchanged.
- **Warband orders replaced:** `thornmother_wall`, `slagmaster_barrage` (Barrage's two crosses stay; the spread is
  added), `dynamo_tether` (the 2-Charge threshold is removed), `prior_veil` (it keeps hiding followers beyond 2 tiles;
  Shadowstep is added) and `stormcaller_wind` all become their table rows above. Order texts are rewritten to the panel
  sentences.

## 5. Not in this wave
Guardians, dragons, Last Light and the Ember Hoarder. The patterns `ring_around_player` and `beside_terrain`
ship later. Gust `toward_source` / `turn_clockwise` and the generic half-Health switch are implemented in bos-01
for the approved boss wave; this unit changes no encounter data.

## 6. Generic half-Health switch (boss-rules approval, 2026-10-27)
Any enemy-sourced instance may additionally declare:
`"at_half_health": {"cadence": {...}?, "dials": {...}?, "sentence": "<exact text>"}`.
The cadence and dials are optional partial dictionaries; the replacement sentence is required. A room source
cannot declare a Health threshold. Validate the resulting cadence/dials by the same rules as the initial instance.

After each committed hero or enemy action resolves, a living source at `hp * 2 <= max_hp` switches once at the
single accepted-transition boundary (`battlefield_rules/committed.gd`), alongside that action's committed events.
It applies before the next action or beat resolves. All remaining hits/effects within the same action keep the old
dials. Use resolved Health after the whole action, not a raw hit estimate: defense can leave the source alive below
half even after a raw lethal hit. Accepted activation-start/end effects and beats cross the same boundary before
further actions/beats. Raw resolvers and every query stay switch-free, without a preview marker or saved context. A dead source ends its rule. Merge only declared cadence/dial keys; preserve other
keys, `counter`, `beats_fired`, and the completed-player-turn guard. An `every: N` cadence continues counting
from the already-counted turns. Preserve held geometry unless its dial changes; prepare changed geometry at the
accepted action boundary, before another action or beat. The saved instance latch `half_health_switched` prevents
another switch, including after Continue or reinstalling the same rule/source in this fight.

The rule panel reads the replacement sentence and the turn clock redraws the next beat immediately. Show once
`"{SOURCE NAME} GROWS FIERCER"`, uppercase source display name, through the existing TurnBanner style and timing.
That banner has no cue today, so play none. Preview copies cannot play the banner; Continue baselines the saved
event sequence so an old switch is not replayed. Normal combat entry resets that cursor because each new fight
starts a new surface-event sequence. No changes to turn banners' input, size, colors, motion or timing.

Fire, Ice and Outcrops made through a beat's placement path belong to its source: ground stores that id at
`elemental_source.actor_id`; Outcrops store it at `owner_id` with `owner_kind: enemy`. Existing owner checks read
those fields. No current six-rule resolver creates Ice; its shared ground-placement path is covered with an Ice
fixture under the beat's source context. Frostbite `damage: 0` still hits every Chilled unit on Ice, Freezes it and
expends the supporting Ice, preserving existing Skate and immunity rules.

`battlefield_rule_fired` adds the boolean `half_health_switched` (false for undeclared/unswitched instances).
The switch adds one `battlefield_rule_switched {rule, source_type, beat_index}` event; `beat_index` is the number
of beats already fired when the crossing action is accepted. Both retain the saved surface-event sequence and
append-only JSONL delivery. See `spec/analytics.md` for retry keys.
