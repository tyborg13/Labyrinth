# Local Analytics

`chronicle_opened` is an additive, local-only event emitted once on opening the
Chronicle from the main menu. Its payload is `{records, runs}`: the current
visible record count (at most 50) and the uncapped Chronicle lifetime run total.
It uses the ordinary append-only JSONL writer and session/install metadata; it
does not rewrite existing history or emit on record selection. Probe-only opens
can suppress emission.

Runtime frame-time/render-load collection is specified separately in [performance_telemetry.md](performance_telemetry.md). Gameplay analytics and performance telemetry use distinct files and schemas so high-frequency performance sampling cannot inflate or destabilize the append-only gameplay-event contract below.

The game now records local-only analytics as append-only JSON Lines under `user://analytics/` by default. The storage format is intentionally boring so it can later be uploaded to S3 and queried or compacted into Parquet without changing the in-game emitter.

## Storage

- File format: newline-delimited JSON (`.jsonl`)
- Default path: `user://analytics/events-YYYY-MM-DD.jsonl`
- Metadata: `user://analytics/meta.json`
- Schema version: `1`
- `balance_revision`: loaded content revision (`dragon_pressure_v3` for coupled dragon pressure, trophies, and milestones).
- `balance_transition`: empty for fresh encounters; resumed older combats record
  `{from, to, saved_intents_preserved: true}`. Already committed intents and paid
  checkpoints retain their saved payload until the next ordinary selection.
  Filter these transitional encounters separately when comparing content balance.
  Existing JSONL history is never rewritten.

Each event includes a stable `install_id`, per-launch `session_id`, monotonic
`sequence`, `run_id`, and `combat_id` when available. Emitters that can be
replayed after a crash may also provide a top-level `idempotency_key`; writing
an already-recorded non-empty key succeeds without appending a second line.

Run and combat events also include the current character progression snapshot in
their context when available:

- `progression_level`
- `progression_stats`, retained as an empty deprecated compatibility field for
  existing JSONL readers
- `progression_skills`, as the ordered learned skill ids
- `relics`, as the ordered run relic ids active for the event
- `moltshards`

Combat-mode events also include initiative context when combat state is
available:

- `initiative_clock`
- `current_actor_kind`
- `current_actor_key`
- `umbra_stage`
- `umbra_radius`
- `visible_enemy_count`
- `objective_type`
- `defiance_capacity`
- `defiance_remaining`
- `combat_unit_scale`, currently `1` for natural whole-number combat units

## Current Event Types

- `run_started`
- `run_start_boon_offered`
- `run_start_boon_chosen`
- `heirloom_left`
- `run_resumed`
- `run_ended`
- `run_scored`
- `combat_started`
- `combat_resumed`
- `combat_ended`
- `reward_offered`
- `reward_choice`
- `reward_claimed`
- `card_drawn`
- `card_became_playable`
- `card_played`
- `player_moved`
- `player_move_undone`
- `player_turn_ended`
- `enemy_action_resolved`
- `enemy_status_tick`
- `defiance_triggered`
- `progression_level_up`
- `progression_skill_learned`
- `progression_skill_reset`
- `progression_moltshard_gained`
- `progression_moltshard_exchange`
- `skill_triggered`
- `equipment_equipped`
- `equipment_grafted`
- `magic_attuned` (historical)
- `magic_purged`
- `item_equipped`
- `item_picked_up`
- `merchant_trade`
- `guided_tutorial_started`
- `guided_tutorial_step_completed`
- `guided_tutorial_completed`
- `guided_tutorial_dismissed`
- `guided_tutorial_restarted`

## Run score (meta-01)

`run_scored` adds `{total, lines, feats}` after a completed defeat, victory or
Ember Hearth withdrawal is recorded. Rows carry `id`, `label`, `detail`,
`points`, `subject` and `feat`; the two lists retain the run-end brief's order
and omit zero-point rows. `total` is the sum of both lists. Scoring and counters
are defined in [run_end.md](run_end.md).

The event uses the original run analytics id and progression/relic context.
`ProgressionStore` queues it in the existing durable progression outbox using
`<result_id>:run_scored` as its idempotency key. Existing local JSONL delivery
and acknowledgment retain retry semantics; the ledger returns the originally
scored result on terminal replay. Delivery occurs at an existing outbox
reconciliation, including boot. No existing event, Steam stat or historical
JSONL record is changed. Production Embrace stages its score before the existing
banked-profile save and displays the recap only after that save succeeds.

Completed results add nullable `score`, `lines`, `feats`, `killer`, `section`,
`biome`, `outcome` and `new_best_score`; the progression adds strict monotonic
`best_score`. Legacy scores remain null for Chronicle's later “—” display. The
existing metric personal bests and 32-result ledger retain their policies.

## Umbra Depths (meta-03)

`run_started` and `run_ended` add integer `depth` to their payloads. This is the
run's immutable Umbra Depth (0–20), distinct from the existing `room_depth`
context and run-result room-depth metric. A legacy run without `umbra_depth`
emits zero. Existing local-first, append-only JSONL, schema version, analytics
ids and event counts remain unchanged; historical events are never rewritten.

The `run_scored` base rows add the final `Umbra Depth N` bonus row only at
nonzero depth, before feats. Its points are rounded half up from the complete
pre-bonus score including feats × N × 5%. The existing `total` remains exactly
the sum of emitted base and feat rows. Durable ledger replay preserves both
score and unlock idempotency. See [Umbra Depths](depths.md) for progression,
save compatibility and proof.

## Player activation ends

`player_turn_ended` records one committed hero activation end. `end_reason` is
`pass`, `auto`, or `frozen` (Freeze takes precedence). Its payload contains
`plays_made` (slots spent on cards, excluding status forfeits),
`base_plays_waited`, `unused_bonus_plays`, `card_time` (paid before ending),
`wait_time`, `sundial_reduction`, `borrowed_extra_turn`, `next_turn_eta`
(scheduled hero Time minus clock), and `enemy_activations_before_next_turn`
(enemy entries before the first scheduled hero in the post-schedule rail
projection, including repeat entries).

The initial enemy-phase checkpoint stages the event in the existing durable
progression analytics outbox before JSONL append. The stable key is
`player_turn_ended|<combat_id>|<turn>|<actor_seq>`; append/acknowledgment replay
keeps a single record. Pass and card previews never stage or write it. Existing
event payloads and the append-only schema are unchanged. Timing follows
[turn_clock.md](turn_clock.md).

Guided tutorial events are local-only like the rest of the stream. Start events
are idempotent per run and tutorial version. Step events
record `tutorial_version`, the action-committed `milestone_id`, the transient
`phase_id` that produced it, and `completed_step_count`. Dismissal records the
phase and completed count so onboarding drop-off can be diagnosed without
logging hover or other high-frequency input. Completion and replay record the
tutorial version. These events never rename or replace combat-action events;
movement, card, reward, and room choices continue to emit their normal records.
Version 2 milestones include the authored first-combat sequence: the two-play
counter acknowledgement, Bone Dart setup, Quick Stab kill, observed kill refund,
and Brace spending that refunded play. Their normal `card_played` records remain
the source of truth for damage and `death_bonus_card_plays_gained`.

`run_started` includes the compiled starting deck plus the equipment model used
to build it: `reward_cards`, `equipped_equipment`, `equipment_inventory`, and
`collected_equipment`. It also includes recovery marker fields when a previous
death dropped embers for the new run: `recovery_marker_active`,
`recovery_marker_amount`, and `recovery_marker_coord`.
It retains the serialized magic fields `attuned_magic_cards` and
`magic_inventory`. From magic-deck save version 1, `attuned_magic_cards` means
all owned magic in the deck and `magic_inventory` is empty. `reward_cards`
remains acquisition history, including copies later purged.
Consumable item loadout state is included as `equipped_items` and
`item_inventory`.

Chain attack presentation uses an opt-in resolver trace of hit order and intermediate snapshots. The trace is returned separately from combat state; it is not saved or logged. Damage, keyword resolution, card payment and analytics event boundaries remain the ordinary atomic action. The UI reveals each committed target outcome as its bolt arrives.

Card selection, cancellation and optional aim adjustments remain speculative.
The one-decision card flow commits and emits `card_played` exactly once after
the chosen target resolves all automatic effects. A blocked damaging Push/Pull
records its actual damage and zero forced movement; cancelled previews emit no
play, payment, movement or surface events. Existing append-only payload fields
and event boundaries are unchanged.

## Card Metrics Supported

The current event stream is enough to derive:

- pick rate via `reward_offered` + `reward_choice`
- combats-in-deck via `combat_started.payload.deck_cards`
- equipment and magic build context via `combat_started.payload.equipped_equipment`,
  `reward_cards`, `attuned_magic_cards`, `magic_inventory`,
  `equipped_items`, `item_inventory`, `equipment_inventory`, and
  `equipment_drops`
- `rules_version: 5` and initial surface layout at combat start; historical intensity-era records remain readable
- draw count via `card_drawn`
- playable count via `card_became_playable`
- play count via `card_played`
- immediate observed card value ingredients from `card_played.payload`

Card-performance queries should group or filter by `progression_skills` when
qualitative progression can alter access, timing, card persistence, or target
selection. The event stream records realized outcomes; it does not assign a
scalar value to a learned skill.

They should likewise group or filter by `relics` when evaluating card results.
Relic engines can mutate printed actions or add draw, play, defense, status,
movement, and surface creation/consumption payoffs during the resolved transition.

`card_played.payload` currently logs raw observed ingredients instead of a single heuristic score:

- enemy HP, realized block, and stoneskin removed; future guard intents do not
  count as removable block until that enemy resolves the block action
- pierce actions resolved, sunder actions resolved, and enemy defense bypassed
  by observed HP damage
- terrain HP damage and terrain destroyed from the full resolved transition,
  including incidental AOE damage; trap wakes create ground without adjacent direct damage; traps triggered,
  summed triggered trap damage, and battlefield pickups collected, including
  dropped ember piles reclaimed through `embers_recovered`
- kills secured
- player HP delta
- block, stoneskin, and healing gained
- move distance
- cards drawn during resolution
- card play economy during resolution: plays spent, remaining plays before/after,
  net remaining-play delta, total play capacity gained, kill-granted plays, and
  card-action-granted plays
- Flurry identification via `flurry` plus the snapped repeat/spend count in
  `flurry_plays_spent`; the resolved action list contains every printed action
  for every repeat so realized utility, damage, and target selection remain
  observable. Initiative fields record the single top-level time payment rather
  than multiplying it by `flurry_plays_spent`.
- initiative timing: printed `card_time`, player turn time spent before/after
  the play, and the current `player_base_initiative`
- card keywords (additive, `spec/card_keywords.md`): `follow_up_active` (the
  card's Follow-up bonus applied), `empowered` (the player opted into Empower),
  `empower_cost` (the Empower cost dictionary, e.g. `{"time": 2}`, or null) and
  `stagger_applied` (total turn-clock delay this card added to enemies after
  dragon halving and the per-turn cap). An Empower Time cost is already
  included in `turn_time_spent_after`.
- surface revision before/after, actual creation/replacement/consumption events,
  contact and activation-start damage, Freeze fuel, and Chain/conduction routes
- forced-movement collisions: `forced_collisions` counts the play's
  `force_collision` board events and `collision_damage_dealt` sums their
  `total_damage` (target plus damaged blockers; walls take none) before Block
  or Stoneskin absorption. The events themselves also appear in
  `surface_events` and the `surface_event` stream with direction, blocked tile,
  target and blocker keys ([forced movement](forced_movement.md))
- illusions created and their total created health
- immediate status application deltas for bleed, expose, chilled, freeze, shock,
  and immobilize
- actual resolved action list and chosen targets
- `play_mode`, retained as an additive compatibility field and always recorded
  as `printed` now that cards no longer have basic Attack or Move modes
- the player-facing targeting gesture via `target_decision_count` and
  `target_decision_tile`. Card plays now record one board decision even when a
  combined move-and-melee card internally resolves both its preferred movement
  endpoint and enemy target. The endpoint can come from the legal tile hovered
  immediately before entering the enemy; `selected_targets` retains that actual
  movement request followed by the attack target. Hovering alone emits no event.
  Choosing an empty destination instead records that
  destination and resolves the movement-only branch without the follow-up
  attack. Targetless cards record the protagonist tile used to confirm the
  play.
- consumable item flags via `item_card` and `consume_on_play`
- Radiance and visibility context: `radiance_card`, Umbra stage and radius
  before/after, tiles illuminated, enemies newly revealed, fixed light sources
  created, effective light sources before/after, tethered light sources
  before/after, Light-source Umbra suppression stages before/after, and
  hidden-enemy movement interruptions caused during resolution. Effective
  counts include Light tethered to living illusions; fixed-source creation
  remains a separate delta so analysts can distinguish trails and placed Light
  from actor-bound auras.

Attack-carried Light remains one resolved attack action in this payload. Its
additive `illuminate_radius` and `illuminate_duration` fields identify the
post-hit rider, while the single chosen target remains the enemy, trap, terrain
impact tile, or freely selected AOE center. An AOE center may be empty when its
other pattern squares hit actors, and any attack-carried Light anchors at that
selected center. Standalone `illuminate` actions remain distinct and retain
their free-tile target entry.

Movement-carried Light likewise remains part of one resolved Move or Blink
action. `illuminate_position_mode: "destination"` means the source is created
at the actual resolved endpoint, which may differ from the chosen target after
a hidden-enemy movement interruption; the existing movement-interruption and
fixed-light-source deltas preserve both facts without adding a target event.

`player_moved` records independent movement-pool use separately from card play.
Its payload includes `action_type`, `origin`, requested `target`, resolved
`destination`, tiles `spent`, movement remaining before/after, and total
movement capacity. This preserves split movement and card-interleaved movement
without attributing either to a card. Ghost Stride movement is identified by
`action_type: "blink"`.

`player_move_undone` appends `{tiles, activation_seq}` after a successful free-walk
undo, through the existing combat analytics context. `tiles` counts actual path
tiles taken back (Rubble pool cost is not extra travel); `activation_seq` is the
hero activation containing that walk. Existing `player_moved` records remain in
the append-only stream and can be paired with these undo records. An unavailable
undo, card selection/cancellation, or tutorial-gated press writes no undo event.
Walks with side-effect event/state changes cannot be undone. History is ephemeral
and is never saved. See [movement_undo.md](movement_undo.md).

AOE card actions are logged in that action list with their explicit `pattern`
offsets so offline balance analysis can distinguish close, line, cluster, and
large-area attacks. Runtime-selected AOE aim orientation is additive on the
resolved action as `orientation`; legal push and pull direction choices are
additive as `force_direction`. These runtime direction fields do not change the
card's printed-play classification.

`enemy_status_tick` captures remaining timed status resolution. Bleed uses
`trigger: "action"` plus `action_type` for a resolved move or attack. Fire is
terrain damage, recorded with `source_kind: "surface_fire"` and entry/start phase;
it must not be mislabeled as a persistent unit status.

`enemy_action_resolved` records each resolved enemy movement, attack, defense,
heal, summon, surface creation/consumption, or authored dragon-boss mechanic step.
Its additive `enemy_type`, `ai_role`, and `intent_id` fields identify the actor's
authored tactical role and the revealed intent that produced the action. This
allows playtest analysis to compare realized range closure, retreat, healing,
guarding, and route efficiency by decision policy; authored bosses retain an
empty `ai_role` while still recording their enemy and intent ids.
When immediate range/line-of-sight filtering leaves no useful intent, the
ordinary authored fallback remains selected (for example, Briar Weaver's Lash
after Thornwall when no ally needs healing). Its printed Time still applies.
Resolved fallback actions keep the existing `enemy_action_resolved` actor,
`intent_id`, and realized-outcome fields; an unreachable shot emits no fabricated
hit or action event, matching the existing no-op action policy.
Intent selection and cancelled badges do not add events or rewrite history.
Group support actions include additive `support_targets` entries with each
recipient's actor key, display name, tile, and realized amount; this lets Warden
Bulwark record every protected ally without splitting one intent into misleading
separate actions.
Surface events capture specialist setup, consumed local fuel and the causal
actor. Boss mechanics retain the
specific `action_type`, use `presentation_kind` for their animation family, and
set `boss_mechanic: true`; they do not also emit misleading
`enemy_status_tick` events. Movement payloads include the exact ordered `path`,
`path_steps`, selected `target_key`, actor/terrain losses caused by hazards, and
triggered traps. Attack payloads retain target, terrain, and trap consequences.
This makes route choice, obstacle-clearing efficiency, voluntary trap exposure,
Worldspine and cinder-mark pressure, forced Gale movement, crystal armor, Last
Eclipse pressure, and realized enemy damage observable without changing the
append-only schema.

Zekarion's cutout presentation reads an additive `spawned_enemies` snapshot on
the existing summon animation step. It reveals those already-resolved minions
at the calling gesture's release; it never invokes summoning again. This is
presentation data, not a new saved-state field or analytics event. Claw damage,
lightning launch/arrival, Skybreak results, and the atomic enemy-action event
boundaries retain their existing semantics.

`combat_started.payload` also includes additive `encounter_id` and `biome`.
For revision-4 section regular fights, `encounter_id` is the authored table
composition id and `biome` is the section dragon's element (`fire`, `earth`,
`ice`, `air`, `lightning`, `shadow`). Both come from persisted room metadata,
so resume retains the selected cohort. Non-table fights and older saves without
identity emit empty strings. Previewing a fight does not append encounter history
or emit a combat-start event. Compare section cohorts separately from legacy
hard-coded encounters; objective extras and leader scaling remain identified by
the existing objective fields. See [encounters.md](encounters.md).

`combat_started` marks recovery combats with `recovery_marker_present` and
`recovery_marker_amount`. It also includes any unclaimed floor equipment ids as
`equipment_drops`, plus the opening Umbra stage, effective vision radius, and
visible enemy count. Survive is temporarily excluded from new room generation;
existing saved Survive encounters retain their objective and analytics fields.
Objective analysis uses the additive `objective_type`,
`objective_target_clock`, `objective_leader_type`, `objective_exit_count`, and
`objective_initial_enemy_count` start fields. `combat_ended` records the final
initiative clock, reinforcement waves, leader-cleared follower count, leader
completion flag, and reached-exit completion tile, door tile, and destination
coordinate alongside the objective type. The route fields identify the exact
door committed by crossing its threshold before the reward-and-escape transition.
This keeps encounter pacing and reward comparisons objective-aware without
renaming the established combat event contract. `combat_ended` also includes
`recovered_embers`, the total embers
reclaimed from dropped piles during that combat, and `collected_equipment`, the
equipment ids picked up during that combat. Its additive `missed_equipment` list
contains equipment ids that were still unclaimed at victory and were resolved
from the cleared room without entering inventory, ownership, discovery, or deck
state. It also records the combat-wide Umbra totals for tiles illuminated,
enemies revealed, movement interruptions against unseen bodies, and damage
received from attacks whose source was hidden when the attack began.

`equipment_equipped` fires when the character overlay equips an owned item
outside combat. Its payload records `slot`, `previous_equipment_id`,
`equipment_id`, the full `equipped_equipment` map, current
`equipment_inventory`, and rebuilt `deck_cards`.

`magic_attuned` is a historical event; the Character panel no longer emits it.
All owned magic enters the compiled deck, with no slot cap. New `reward_choice`
records add `destination: "deck"` for card claims (empty for skips). Scavenger
`merchant_trade` records add `destination: "deck"` on magic purchases. Event
`map_event_resolved.outcomes` add `destination: "deck"` on direct card grants.
Existing events and keys remain readable under schema 1.

`magic_purged` fires after a confirmed removal has been saved. Its payload has
`card_id`, `source` (`scavenger` or `campfire`), `price` (Embers; zero at a
Campfire), `purge_index`, `held_embers_before`, `held_embers_after`, full
`attuned_magic_cards`, and rebuilt `deck_cards`. Selection, hover, cancellation,
invalid requests, and save failures emit no removal. A Scavenger purge costs
50 Embers plus 25 per prior paid Scavenger purge in this run. Campfire consumes
its single service choice and never advances the paid-price counter.

The additive save marker `magic_deck_save_version: 1` and
`magic_deck_migration` receipt record the old/new versions and number of reserve
copies moved. Draining the old inventory makes repeated loads idempotent.
Migrating a combat save changes the compiled deck for later encounters while
preserving that encounter's serialized hand/draw/discard/action boundary.

`item_picked_up` records a newly collected battlefield item, with `loot_id`,
`card_id`, `destination` (`hand`, `draw`, or `inventory`), and the resulting
`equipped_items` and `item_inventory`. Duplicate cards remain separate pickups.
Both live UI and the headless harness emit it. Direct hand acquisitions keep the
existing `card_drawn` event with `reason: item_pickup`; they do not remove a card
from the draw pile. Full-hand acquisitions go on top of draw and produce their
normal `card_drawn` only when actually drawn. Full-slot pickups produce no draw.
Combat snapshots now own item loadout transactions, so checkpoint replay and
reload copy the result rather than granting or consuming items a second time.

Item relics (overhaul U8, [item rules](item_relic_rules.md)) reuse these saved
transactions. Bandolier reports zero `card_plays_spent` and its actual extra
Time in existing card-play fields. Ledger keeps non-healing copies equipped
while sending them to the combat's burned pile; `item_card` and
`consume_on_play` remain authored card classifications, rather than assertions
that the played copy was permanently removed. Retort changes resolved action
values and stored Powder Keg damage in the existing snapshots/events. No new
event types or payload fields are introduced; forecasts emit no analytics.

`item_equipped` fires when the character overlay equips or stows an owned
consumable outside combat. Its payload records `action` (`equip` or `stow`),
`card_id`, `inventory_index`, `equipped_index`, full `equipped_items`,
`item_inventory`, and rebuilt `deck_cards`.

`merchant_trade` fires when a Scavenger transaction succeeds in a non-combat
merchant room. Its payload records `action` (`buy` or `sell`), `merchant_kind`
(`scavenger`), `item_kind` (`magic`, `equipment`, or `item`), `item_id`, ember `amount`,
`held_embers_before`, `held_embers_after`, the current `room`, and the updated
equipment, magic, item, reward-card, and deck state. Scavenger purchase and sale
receipts animate only after that committed event/save; presentation overlap,
reduced motion, or leaving the shop never repeats or defers the transaction.

Every dragon victory emits `combat_ended` and pauses in reward mode. Its
`reward_offered` uses `reward_kind: dragon_milestone` and additive `boss_id`,
`milestone_id`, `awarded_relic`, `next_descent`, `moltshards`, `healed_amount`, and
`ember_amount` fields. The amount includes actual room earnings plus the boss
bonus; health and Shards report the actual credited amounts. The first dragon
of a run awards one Shard; later gates report zero additional Shards.

Continue emits `reward_claimed` with `reward_kind: dragon_milestone`, the same
`milestone_id`, `boss_id`, `relic_id`, and `next_descent`. The claim receipt is
queued before the save that removes the milestone, using
`reward_claimed|<milestone_id>`. Intermediate gates retain the receipt in the
saved run until append and acknowledgment succeed. Final-boss settlement merges
it into the profile before clearing the run. Both recovery paths replay safely
without duplicating rewards, banking held Embers early, or losing an event in
the save/append gap. Intermediate Continue returns to room mode; Noctyrax's
Complete Ascent then records victory and `run_ended`.

Dragon `enemy_action_resolved` payloads include `boss_mechanic`,
`committed_direction`, `action_direction`, `declared_tiles`, and `resolved_tiles`
for the held fan, line, crescent, and fixed strike patterns. Movement paths and
interruption flags distinguish a denied charge from a missed swing. Noctyrax's
brazier changes share the resolved action stream, so refuge loss/restoration and
Eclipse damage can be compared with the player's actual lighting choices.

`defiance_triggered` records each spent extra-life charge from the committed
combat checkpoint. Its payload contains the lethal `cause`, actual
`lethal_hp_loss`, `restored_hp`, post-trigger `charges_after`, `capacity`, and
`combat_unit_scale`. It uses the stable key
`defiance_triggered|combat|<combat_id>|<revision>` and shares the durable
progression outbox and staged-revision checkpoint rules used by combat skill
events, so save/resume cannot duplicate or lose a trigger.

`run_ended` includes the canonical cumulative performance snapshot:
`enemies_killed`, `damage_dealt`, and `damage_received`. Damage fields count
actual natural-unit HP removed after block and stoneskin, capped by remaining HP;
they do not count absorbed defense or overkill. Enemy alive-to-dead transitions
are the sole kill source. The same monotonic `run_stats` dictionary travels in
the committed run/combat snapshot, so save/resume and animation checkpoints
replace a snapshot rather than reapplying a delta.

## Local Personal Bests

The local progression profile stores `run_bests` plus the idempotent
`last_run_result`. Higher values are eligible for personal-best treatment for
enemies killed, damage dealt, depth, rooms cleared, and bosses defeated. Damage
received remains an informational result because celebrating a larger value
would be misleading.

The first observed value for each eligible field establishes its baseline and
does not show `NEW BEST`; there is no invented prior history. Later values show
`NEW BEST` only when they strictly exceed the stored value, never on a tie. A
stable run result id makes repeated recap refresh, terminal retry, replay hooks,
and process restart idempotent while preserving the original badge decision for
the just-finished run. The profile keeps the 32 most recently used completed
result records, including their original stats and badge fields; a non-adjacent
`A → B → replay A` returns A's original decision without changing the monotonic
bests, and refreshes A's recency in that bounded ledger.

Terminal persistence must record the result before profile save and before the
terminal snapshot is cleared. Any committed-boundary save path should pass its
supplied victory/defeat dictionary through
`_terminal_state_with_recorded_run_result`, then adopt the progression embedded
in the returned state before banking/loss processing and `save_data`. Do not
rely only on later `_process_victory_carry` or `_process_defeat_loss` refresh
hooks: a save implementation may set those processed flags during committed
terminal finalization and legitimately bypass the UI-time hooks.

Victory settlement resolves the carried amount from the incoming terminal
snapshot before recording its result. Positive held Embers are authoritative;
when held Embers are already cleared, retain the embedded profile's banked
amount. Canonical victories always include the final boss's Ember award, so
this zero-held case represents a settled snapshot. Later UI refresh, Grimoire
persistence, and terminal retry must preserve that bank and the original recap
amount without adding it again. This does not add or repeat analytics events.

`progression_level_up` fires when Draw Strength commits at an Ember Hearth
(the internal room type remains `campfire`) or at the opening Emaciated Man.
Its `source` distinguishes `campfire` and `emaciated_man`; `transaction_id`
identifies the durable wallet receipt. Its
payload records `level_before`, `level_after`, the unchanged post-purchase
`skill_ids`, `unspent_skill_points_before`,
`unspent_skill_points_after`, ember `cost`, `held_embers_after`, and
`room`. It grants one bankable point and never implies a skill choice. The
shared event context records the resulting Defiance capacity and remaining
charges; a milestone level adds exactly the capacity delta to the active run.

Ember Hearth presentation plays after the existing commit boundaries. Rebuilding
choices, highlighting them, or playing a result does not emit a second level-up
or alter run events. Linger and Embrace retain their existing persistence and
analytics contracts; `campfire_linger` and the room type remain stable.

`progression_skill_learned` fires after one legal skill is saved from the
persistent tree. Its payload records `skill_id`, the complete post-learn
`skill_ids`, `unspent_skill_points_before`,
`unspent_skill_points_after`, and `room`.

`progression_skill_reset` fires only after the whole-tree confirmation is
accepted and saved. Its payload records `skill_ids_before`, the empty
`skill_ids_after`, `skill_points_refunded`,
`unspent_skill_points_after`, `moltshards_before`,
`moltshards_after`, and `room`. Opening or canceling the confirmation emits
no reset event and spends no resource.

`progression_moltshard_gained` records a resource usable for a skill reset or an
opening Ember exchange. Its payload
contains `amount`, `source`, `moltshards_before`, and
`moltshards_after`. The first boss victory of a run uses
`source: "first_boss_victory"`; later boss victories in that run produce no
award event, and repeated resolution of the same award must not emit another
event. The award and a profile-owned analytics outbox entry are persisted
together before JSONL append. Its stable idempotency key is
`progression_moltshard_gained|<run-result-id>:first_boss_moltshard`. The outbox
entry is acknowledged only after append succeeds; loading a profile or saved
run retries pending entries, and append-before-ack replay is a no-op rather than
a duplicate. Analytics acknowledgement must never copy held run Embers into the
banked profile.

`progression_moltshard_exchange` records a committed opening trade. It includes
`source: emaciated_man`, `transaction_id`, `moltshards_before`,
`moltshards_after`, `embers_gained`, and `held_embers_after`. One Shard grants 250
held Embers. Wallet transactions save their receipt and analytics outbox in the
profile first; the run then applies the latest receipt once. A crash between
those saves recovers the exact credit/debit, without replacing subsequent run
earnings. Level-up and exchange context describe the resulting run, including
post-transaction progression, Shards, and Defiance, without stale combat state.
Acknowledgment clears the active and embedded-run outboxes together, and a
second run checkpoint saves that result before UI refresh. A failed profile
acknowledgment retains the entry; replay deduplicates its transaction key.

`skill_triggered` records each automatic, manual, contextual, or passive skill
activation. Its payload contains `skill_id`, `activation`, `trigger_revision`,
`trigger_scope`, `turn`, and `message`. `trigger_scope` distinguishes combat
and run event streams. Revisions are monotonic within their stream.

The run stream uses its revisioned event list as a durable outbox. The run state
containing a new trigger is committed before JSONL append; the logged-revision
cursor advances only after append succeeds and is then committed separately.
Each run trigger uses the stable key
`skill_triggered|run|<run_id>|<revision>|<skill_id>`.

Combat triggers are copied into the shared `progression_analytics_outbox`
carried by profile and run progression. The combat snapshot advances
`combat_skill_event_revision_staged` in the same checkpoint as those outbox
entries; this cursor means staged, not appended or acknowledged. That gameplay
checkpoint is persisted before JSONL append. Each combat trigger uses the stable
key `skill_triggered|combat|<combat_id>|<revision>|<skill_id>`. The outbox entry
is acknowledged only after append succeeds, and that acknowledgement is
persisted separately. Loading a profile or saved run retries pending entries; a
crash after append but before acknowledgement replays the stable key as an
idempotent no-op rather than producing a duplicate.

Ordinary combat HUD refreshes schedule this three-stage protocol after a rendered
frame instead of stacking its writes inside card completion. The stages share a
single coalescing main-thread queue with player-turn warming. New actions pause
and restart it against current authoritative state; explicit checkpoints flush
it, and lifecycle/namespace changes invalidate stale requests. Per-action
completion no longer promises that analytics reconciliation is already durable.
Unfinished work may be lost or replayed after interruption, as authorized by the
performance contract; accepted jobs are never reported as successful appends.
Stable keys, local append-only JSONL, acknowledgment-on-success, terminal rewards
and the banked/held-Ember separation remain unchanged. See
[save persistence](save_persistence.md#ordinary-combat-analytics-scheduling).

Nonterminal HUD refreshes also defer run-stream reconciliation until after a
rendered frame. A separate coalescing queue runs the complete existing
outbox-save, append, cursor-save protocol synchronously in one later slice;
there is no yield between those three operations. It reads current authoritative
events, waits for held presentation to release, and cancels on lifecycle or
storage changes. A successful same-run checkpoint after the final HUD refresh
keeps its pending request alive, including reward-reveal completion.

Each unchanged pending trigger retains an owned copy of its first HUD context
and payload turn, so an immediate following action cannot reattribute it to a
new room, HP, or turn. This presentation-time cache is not a save-schema change;
loading uses the existing saved-state replay context. Explicit Save & Quit and
window close synchronously flush the live stream before saving the held/current
checkpoint. A newer held trigger that is not yet in the live display remains in
that durable checkpoint for replay, preserving the existing held-state rule.


Priming and effect realization do not create a second activation event.
Realized card, damage, defense, movement, and resource outcomes remain in their
existing events rather than being converted into a guessed skill score.

For Rehearsed Escape, Makeshift Tool, and Carry the Guard, pre-arming is intent
rather than a realized activation. Their single `skill_triggered` event is
recorded when the qualifying card is redirected to discard or the remaining
block is converted at activation end, which is also when the once-per-combat
charge is spent.

Persistent passives also record only realized benefits. Open Arsenal emits a
run-scoped activation after a successful non-trinket equip into the trinket
slot, never while validating a drag or repeating a no-op equip. Prismatic
Instinct and Confluence emit one combat-scoped activation only after a legal
placement or relocation actually changes the board. Cancelling aiming and
idempotent placement do not spend or record an activation.

## Surface Rules v4

New records carry top-level `rules_version` and `surface_revision`. The JSONL
schema remains append-only; old logs keep their original intensity/Poison/Burn
fields, and readers must group mechanics comparisons by rules version. New
construction omits retired intensity fields rather than emitting a zero meter.

Combat state holds a monotonic `surface_event_sequence` and bounded recent
`surface_events` for previews and presentation. Analytics flushes unseen events
at resolved action/start boundaries, using combat ID plus event sequence for
idempotency. A boundary derives its common context once and synchronously appends
its ordered unseen tail in one JSONL batch. The in-memory cursor advances only
after the batch flush succeeds; stable event keys make partial-append retries
and restart replay idempotent. Preview copies never append gameplay analytics. Records include
creation, replacement, removal reason, source actor/card/relic, tile and layer;
Fire entry/start contact; successful Freeze and consumed Ice; actor death source;
and the native Chain route alongside connected-component side hits. A direct
hit, conduction hit, passive hazard, trap and secondary relic pulse remain
separate sources. Actors hit by multiple occupied tiles or overlapping branches
appear once in the damage set. Consumption records show the actual removed
surface, including Fire used as a conductor under Stormcoal Crucible.
The additive `rubble_underlay` on `surface_removed` records whether Rubble
coexisted at the instant of removal, after any earlier terrain payment in the
same action. Layered-consumption rewards use this event-time fact rather than
the action's initial board snapshot.

Card-caused displacement can cause a hazard kill, but passive activation-start
Fire cannot inherit a stale card instance or bank a future card play. Preserve
placement owner separately from the immediate damage cause. Simultaneous blast
deaths retain their individual source records before final outcome selection.

## AWS-Friendly Expectations

If this gets uploaded later, keep the event contract compatible with object storage and batch processing:

- prefer additive schema changes over renaming existing keys
- keep top-level fields flat and stable
- avoid Godot-native object serialization in payloads
- continue converting vectors to `{x, y}` dictionaries
- keep per-event payloads self-contained enough for Athena or Spark jobs

## Maintenance

Update analytics instrumentation when changes affect:

- reward offering or reward selection flow
- equipment ownership, drops, equip rules, or deck compilation
- consumable item ownership, equip rules, use-on-play consumption, or deck compilation
- ember carry, loss, extraction, or campfire level-up flow
- skill learning, whole-tree reset, Moltshard awards, or skill activation
- draw rules, opening hand, reshuffle, or fatigue
- combat-unit migrations or Defiance capacity, restoration, spending, or
  persistence
- card play targeting or independent player movement rules
- surface production, replacement, consumption, contact timing, conduction,
  enemy use, trap wakes, or room-start rules
- Umbra stage progression, visibility, hidden-enemy information, or Radiance
  actions
- card actions that create, remove, or redirect combat actors
- combat outcome flow
- status timing or turn sequencing
- any fields used by the balance heuristic or future card-performance dashboards

### Surface rules v5

New surface events carry rules_version 5. `surface_conducted` records each
unique conductor tile used by an attack, with its surface, tile, route reason
(`chain` or `conduction`) and attack source. It does not imply removal.
Ordinary Electrified persists; Stormcoal Fire also emits `surface_removed`.
Existing sequence-based append-only event deduplication applies unchanged.
Historical v4 events and source metadata are preserved when a save upgrades.

A validated independent movement request now includes `resolved: true` in
`last_player_movement`. A request can resolve without a step when Bleed kills
the player first or an unseen actor interrupts travel. Commit that state; do
not infer non-resolution from zero distance. These zero-spend requests emit
`player_movement_interrupted`; successful movement still emits `player_moved`.
Both include the requested target, actual endpoint and movement expenditure.

### Boss section map v1

New section-map runs persist an ordered `map_events` outbox and
`map_event_revision`. Both the live game and headless console append these events
after the corresponding save succeeds. The stable key
`section_map|<run_result_id>|<revision>` prevents replay after reopening a save
from duplicating events. Existing JSONL storage and vector normalization apply.

| Event | Payload |
| --- | --- |
| `section_entered` | Section index, boss id, remaining Scout uses |
| `route_revealed` | Source (`proximity`), section index, newly identified rooms |
| `map_scout_used` | Section, `scope: mystery` when scouting a revision-4 mystery, otherwise `scope: room` (older layouts and ordinary Section VI unknown rooms), selected `target`, exactly one revealed room, newly `outlined_rooms`, uses remaining; `branch` retained as a legacy alias for the selected coordinate |
| `route_choice_committed` | Section, origin, destination, known room ids, known room metadata (type, element, step, landmark), remaining Scout uses |
| `mystery_resolved` | Revision 4 only: `room`, resolved `type`; emitted once on entry, never by Scout |
| `map_event_resolved` | Room, legacy `choice`, Embers delta, newly revealed rooms; additive `event_id`, `choice_id`, concrete ordered `outcomes` |
| `omen_gained` | `id`, `fights` (new or refreshed duration) |
| `omen_expired` | `id` |

Authored event choices commit their result page and effects with the saved
`map_event_resolved` receipt. Concrete outcomes include actual resource deltas,
selected asset ids, from/to transformations, revealed rooms, card offers and
omen durations; empty resource pools identify their Ember substitution.
Continue, previews and repeated choices emit no second resolution. Omen gains
and expirations share this ordered outbox, including combat completion on escape,
Last Door retreat, Guardian and boss encounters. Existing reward-choice analytics
also records event card claims/skips through the ordinary chooser; event Skip
heals zero. See [events.md](events.md) for schema and save compatibility.

Room selection records what the player could know at commitment, before moving
and revealing the next horizon. Invalid/empty Scout and repeated event requests
emit nothing. Physical Reach the Exit destinations are committed by the existing
combat outcome and reward flow; the route event is emitted when that saved
transition enters its destination. Opening/closing the map and browsing history
are presentation actions, not room visits or reward choices. Direct room
activation uses the same saved route-commit boundary as the former confirmation
button, after its brief visual acknowledgement. Starting or cancelling that
acknowledgement emits nothing, and repeated input cannot schedule duplicate
commits. Hover/focus previews and entering or cancelling Scout targeting emit
nothing; `map_scout_used` is emitted only after a valid unknown-room reveal is
saved. The additive scope/target/outlined-room fields distinguish this behavior
from older saved branch reveals; no historical events are rewritten. Revealing
neighbor outlines does not grant their identities or record a route choice.
Showing a physical exit on the board remains an inspection action.

### Graftwright inheritance

`equipment_grafted` uses the saved section-map outbox and its existing stable
revision key. Its payload contains `recipient`, `donor`, native equipment `slot`,
`room`, `recipient_equipped`, `card_id`, `replaced_card_id`, zero-based `index`,
original donor `source`, and `before_cards`/`after_cards`. Exactly one event is
staged for a successful transaction. Previewing, cancelling, invalid requests,
and replaying a used encounter emit no additional graft event. The live scene
persists before the ritual; the console flushes after saving its session.

Run-start, combat-start, equipment-equip, and merchant-trade payloads also include
additive `equipment_grafts` snapshots. Compiled deck and card-play events continue
to use effective cards. No card effects or historical JSONL records are rewritten.
See [graftwright.md](graftwright.md) for the run-only state model and limits.

## Guardian encounters and trophies

Guardian encounters retain `kill_leader` as the objective identifier. Common
context now adds `room_type`, `guardian_id`, `boss_id`, and the resolved
`objective_name`; presentation uses “Defeat” and named characters. Group ordinary
fights, guardians and dragons by `room_type` when comparing encounter outcomes.

A guardian victory records `reward_offered` with `reward_kind: guardian_trophy`
and `offered_relics`. Claiming the exclusive trophy records `reward_choice` with
`choice: claim`, `relic_id` and `guardian_id` after the saved claim boundary.
Room completion and ownership prevent duplicate awards on replay.

Treasure chest opening and relic delivery are presentation-only. Relic ownership,
the saved `relic_claimed` boundary, and the existing guardian `reward_choice`
event still commit synchronously before visual delivery. The chest reveal and
the delayed map presentation add no reward or outcome events; the map opens
after the beam, its staggered motes, and the destination settlement complete.

Guardian `enemy_action_resolved` records add `guardian_mechanic`, `declared_tiles`
and `resolved_tiles`; broken cover can shrink a previously declared quake or
blocked lane. They also add `interrupted`; interrupted Guardian status steps
remain in this event stream instead of disappearing with their cancelled attack.
Conduction resolution tiles include the entire affected network. Replacement
summons use the same Guardian helper event on every successful return. Reinforcement creation, brazier outages/restoration, outcrop creation
and Illusion relocation use the existing append-only `surface_event` stream and
its combat/sequence idempotency keys. Illusion movement consumes shared Move but is not counted as `player_moved`.
Its payload records Illusion id/path, movement spent, and source relic.
The gauntlet no longer emits cover commands. Shared `terrain_created` outcomes
record `terrain_id`, `terrain_kind`, `tile`, `health`, `element` and normal
card/enemy `source` metadata. Historical command records remain readable.
Ground-targeted cards retain the ordinary card-play event and selected tile;
empty attacks produce no synthetic victim or defeat records.
Intent focus and elemental feedback are presentation only and emit no combat actions.
Native Chain trace hits add `enemy_hop`, unmodified `base_damage`, and
`chain_bonus_damage`; connected conduction side hits never receive hop credit.
Preview copies do not append analytics. No changes to historical JSONL are required.

Guardian light restoration surface events retain `guardian_light_restored` and add `tiles` (only newly relit braziers) plus `trigger_intent` (`last_procession`). The matching intent refresh carries the completed Guardian board snapshot so restoration and departed Shades are presented at the actual boundary. Input recovered from a non-tutorial save does not emit tutorial milestone events.

### Dragon feedback events

The existing append-only `surface_event` stream includes additive
`crystal_mantle_broken` records with enemy `id`, `tile`, `prevented_damage`,
`layers_remaining` and causal `source`; `dragon_light_restored` with `brazier_id`,
`tile`, `trigger: player_arrival` and player source; and `enemy_summon_scheduled`
with enemy `id`, `enemy_type`, `activation_time` and `reaction_window: true`.
These use the ordinary sequence cursor and preview-copy exclusion. They allow
layer negation, player recovery of Light and summon reaction time to be inspected
without attributing blocked damage as health loss or replaying UI animations.

### Dragon reward presentation and awakening service

Dragon Continue still commits the existing `reward_claimed` outbox receipt before
relic delivery, HUD settlement, or the map transition. These presentation phases
do not emit additional acquisition/claim events. The Emaciated Man's one-time
awakening dialogue and separate Awaken Power entry do not spend resources; the
existing profile-first `progression_moltshard_exchange` and
`progression_level_up` events remain the only wallet mutation records.


### Dragon trophy Time and ranged relay events

The existing append-only `surface_event` stream now admits
`relic_time_reserve`: `relic_id`, `card_id`, `gained`, `spent`, `remaining`,
`card_time_paid` and player/relic `source`. This records only actual changes to
the stored Time balance at the card completion boundary. A free Borrowed Time
card does not consume the reserve. The ordinary card-play event still records
the actual paid Time; no synthetic play is emitted.

`relic_ranged_relay` records `relic_id`, `from`, `relay`, `target`, normal `range`,
and the original card `source`. A direct shot emits no relay event. This event
describes range extension only; ordinary hit, defeat, and surface-conduction
events retain their own damage and causal source. Both records use the existing
combat sequence/idempotency cursor, with no analytics emitted by forecast copies
or by presentation. Historical JSONL remains readable.

Dragon pressure uses additive surface events: `dragon_status_consumed` records
the enemy, consumed status, amount and source after Shatterstorm.
`dragon_spire_pulse` records `tiles`, `radius`, `consumed` and causal `source` for
persistent Claw/Breath pulses and consuming Faultline. `dragon_field_replaced`
records `surface`, removed `tiles` and dragon `source` when a new owned band retires
its predecessor. Individual removals retain their ordinary `surface_removed`
records with reason `dragon_field_replaced`; player/helper replacements remain.
`replaced_trail` identifies retiring owned Ice. New Overload retains charge; only
legacy saved consuming Overload emits removal reason `overload`. Night Coil emits
`dragon_light_snuffed` before Eclipse. Existing damage/surface/initiative events
continue through local append-only JSONL. Forecast and presentation do not append
separate analytics.

Worldroot automatic origin selection is part of the same card commit: the chosen Rubble origin is consumed by the ordinary surface event path. It does not add an origin-pick event or a second card play. Cancelling a drag revokes commit input before snapback animation, so a concurrent release emits no card-play event.

### Wave-4 family B (area forces, Swap, self flags, Cleanse, Petrify, Mantle)

`card_played` gains additive fields, identical in RunScene and
`tools/headless_playtest.gd` (`ManeuverRules.analytics_fields(before, resolved)`):
`self_flags_gained` (flag ids newly active: `ice_skate`, `no_move`, `anchored`,
`fire_immune_turn`), `statuses_cleansed` (player statuses removed),
`mantle_gained` (Crystal Mantle layers added), `petrified_enemy_ids`,
`swapped_with` (`enemy`, `illusion` or null) and `force_area_displaced` (enemies
an area force moved). The append-only `surface_event` stream adds `force_area`
(`center`, `radius`, `force`, `amount`, `expose`, `consumed`, per-enemy `from`/`to`),
`swap` (`from`, `to`, `other_kind`, `other_key`), `petrified` (`enemy_id`,
`block`), `statuses_cleansed` (`statuses`), `mantle_gained` (`amount`, `layers`),
and `crystal_mantle_broken` with `actor_kind: player`. Area-force and Squall
collisions use the existing `force_collision` event. Existing fields keep their
meaning.

### Wave-3 card keywords (Retaliate, Quicken, next attack, Rites)

`card_played` gains three additive fields, identical in RunScene and
`tools/headless_playtest.gd` (`TempoRules.analytics_fields` on the committed state):
`quicken_spent` (int, Time removed from this card by pending Quicken; Rite discounts are
not counted), `next_attack_bonus_used` (`{action_type, damage, chain, pierce, sources}`
for the buffs this card's attack spent, else null; a zero-damage push/pull never spends
them, so `action_type` names the damaging hit) and `rite_started` (the card id when
the card began a combat-scoped Rite, else null). Existing fields keep their meaning;
`card_time` and `turn_time_spent_*` already report the discounted Time.

Retaliate uses the existing append-only `surface_event` stream. `retaliate_triggered`
records `enemy_id`, `actor_key`, `attack_type`, `damage` (total Retaliate including Rite
thorns), `thorns`, `hp_loss`, `block_loss`, `stoneskin_loss`, `bleed`, `shock`, `push`,
`from`/`to` tiles, `killed`, `attacker_before`, `sources` and a player `source`
(`source_kind: "retaliate"`, `player_card: false`). Kills keep their ordinary
`actor_death` record with that source; no card play is granted. The presentation step
that animates it also appears as an `enemy_status_tick` with `label: "Retaliate"`,
`trigger: "retaliate"`, `action_type: "retaliate"` (kind `status_damage`, or `status`
when only riders applied); analysis should prefer the surface event. `rite_surface_pulse` records Rite turn-start pulses (`surface`, `element`,
`damage`, `enemy_ids`, `relic_id`). Rite effects otherwise reuse relic events and flags,
keyed by `relic_id` `rite:<card_id>:<n>`.

### Wave-4 surface family (spec/card_mechanics_surfaces.md)

No new event types and no `card_played` field changes. The existing append-only
`surface_event` stream gains these kinds: `meteor_marked` (`tiles`, `damage`, `surface`,
player card `source`), `meteor_impact` at the next player turn start (`tiles`, `damage`,
`element`, `surface`, `victims` actor keys, `losses` per actor, `source` with
`source_kind: "meteor_marks"`, `player_card: true`), `surface_converted` (`surface`,
`from_surface`, `tiles`, `enemy_ids`, `damage`), `surface_discharge` (`tiles` network, `area`,
`enemy_ids`, `damage`), `selector_strike` (`selector`, `enemy_ids`, `damage`, `element`),
`attack_consumed_surface` (`surface`, `tiles`, `bonus_damage`), `card_result_reward`
(`when`: froze|killed, `enemy_id`, `rewards`) and `frozen_splash` (`target_id`,
`enemy_ids`, `damage`, `tiles`). Placed, replaced and removed surfaces keep their ordinary
`surface_created`/`surface_replaced`/`surface_removed` records (removal reasons `consume`,
`discharge`, `detonate`). A Meteorfall landing also animates as an enemy-phase
`status_damage` step with `trigger: "meteor_marks"`; analysis should prefer the surface event.

### Wave-4 illusion and terrain cards

New action types (`illusion_swap`, `destroy_illusion`, `burst_terrain`) and the new
`illusion`/`outcrop` fields appear unchanged in `card_played` action lists; there are no new
payload fields. Outcomes use the existing append-only `surface_event` stream
(spec/card_mechanics_illusions_terrain.md):

- `illusion_retort` — `trait` (`on_damaged` | `reflect`), `enemy_id`, `actor_key`,
  `illusion_id`, `illusion_key`, `illusion_tile`, `source_name`, `damage`, `element`,
  `shock`, `hp_loss`, `block_loss`, `stoneskin_loss`, `killed`, `attacker_before` and a
  player `source` (`source_kind: "illusion_retort"`, `player_card: false`). Kills keep their
  ordinary `actor_death` with that source. The animating step also appears as an
  `enemy_status_tick` with `trigger`/`action_type: "illusion_retort"`.
- `illusion_ranged_origin` — `illusion_id`, `from` (the illusion tile), `target`: a ranged
  attack fired from a Doppelganger.
- `illusion_swapped` — `illusion_id`, `illusion_key`, `from`, `to`, `block_transferred`.
- `illusion_shattered` — `illusion_id`, `tile`, `tiles` (blast tiles); the illusion's own
  `actor_death` precedes it.
- `terrain_shattered` — `tile`, `tiles`, `terrain_id`, `terrain_kind` (Rockburst/Worldbreak).
- `powder_keg_burst` — `tile`, `tiles`, `damage`, `terrain_id`, `owner_kind`, `actor_keys`
  and the triggering `source` with `source_kind: "powder_keg_burst"` (`causal_owner: player`
  for a hero keg). Chained kegs record one event each.
- `worldspine_pulse` — `tiles` (spires), `enemy_ids`, `damage_by_enemy`, player `source`
  (`source_kind: "worldspine_pulse"`, `player_card: false`).

Player-raised kegs and Worldspines use the existing `terrain_created` event with
`terrain_kind` `powder_keg` / `worldspine`.

### Surface and movement relics (relic pool overhaul U7)

The existing append-only `surface_event` stream gains a `source` dictionary on
`surface_removed`, copied from the active damage context. This distinguishes
hero consumption from enemy or trap consumption for stored-ground relics;
replacement and transport do not count as spending ground. Placement and death
spreads continue to use the ordinary surface-created/replaced events.

Independent `player_moved` payloads gain `light_refunds`, the number of movement
points returned by hero-created Light during that request. `spent` remains the
actual movement-pool expenditure, now net of those refunds. A successful Move
with zero net expenditure emits `player_moved`; it is not an interruption.
Stagger continues to use the existing turn-flag totals and rail projection.
Previews emit no analytics. No new event types or card-play fields are introduced.

### Forced-movement relics (relic pool overhaul U3)

Collision relics retain the existing `force_collision` schema and sequence cursor.
Per-party `damage`, `target_damage`, `blocker_damage`, `blockers[].damage` and
`total_damage` include the party's collision modifiers and Quarry's event-time
Rubble bonus before Block/Stoneskin. Protected outcrops report zero damage.
Battering Yoke records each knock-on collision separately in resolution order;
card-play collision counts and sums therefore include those events. Knock-on
kills retain the original card context and normal death/reward records.

Millstone creates ordinary `surface_created` Rubble records, with the original
force context and its source relic. Breaking Wheel uses `surface_removed` with
reason `force_collision` (Ice successfully freezing still uses the normal `freeze`
removal/status event). Both layers on the contact tile are consumed. Siege and
Wheel Stagger remain part of the existing `stagger_applied` card summary; Freeze
and Shock keep normal status state and Freeze events. Forecast copies emit no
analytics. No new event types or payload fields are required.

### Relic overhaul U4 tempo

No new event kinds are introduced. Borrowed Hourglass uses the ordinary saved
hero-turn start boundary and records the new activation normally. Pendulum
Weight deaths use existing `actor_death` events with `source_kind: relic`,
`player_card: false` and `relic_id`; overflow never grants a card-play kill.
Existing Quicken, Follow-up, Empower and next-attack card-play fields continue
to describe these relics. Echoing Blade's next-card damage is a `card_scoped`
next-attack buff (all attacks of that card); ordinary buffs remain first-attack.
Card action snapshots may add `_tempo_card_time` and `_tempo_plays_spent`
(derived projection/payment inputs), `_empower_repeat_available` on the first
action and `_empower_repeat_first` on its automatic repeat. These additive
runtime annotations do not represent extra played cards. Preview copies never
append gameplay analytics; local append-only JSONL and existing event cursors
are unchanged.

### Relic overhaul U5 defense, health and Exhaust

No new event kinds or payload fields are introduced. Retaliate damage and its
actual health loss retain the existing `retaliate_triggered` event; Gorget's
Block is measured from damage before force riders. Chalice uses the existing
`next_attack_bonus_used` field and includes pre-hit Bleed in that hit's bonus.
Printed health and Empower cost fields retain their meaning; the ordinary
health/Stoneskin state deltas and damage-received totals reflect the actual
Iron Lung payment. Liturgy's ordinary `card_plays_spent` is zero for Rites, while
paid Time remains recorded. Urn's hand return uses the normal turn draw and
`draw_revision` accounting. Exhaust Time rewards use the physical card's final
payment and do not turn item Consume into Exhaust. Additive runtime action
annotations `_card_plays_spent` and `_player_bleed_paid` share the payment and
pre-hit timing with previews; preview copies never append gameplay analytics.

### Illusion and Lightning relics (relic pool overhaul U6)

The existing append-only `surface_event` stream adds `illusion_echo` with
`illusion_id`, `from`, `target`, and the original card `source` (its `source_kind`
is `illusion_echo`). Echo attacks and Chain returns retain normal card kill
credit; illusion-death blast damage uses `source_kind: illusion_relic_shatter`,
`player_card: false`, and `causal_owner: player`. Hollow Puppet's health damage
uses `source_kind: illusion_force_shatter`; its existing `force_collision` event
reports the illusion health as marker `damage`, `target_damage: 0`, and that
health as `blocker_damage`/`total_damage`. Destruction is a separate actor death.
Glassway reuses `illusion_swapped` without changing its fields. Rattle changes
normal Expose and Stagger state/summary. Copper's `surface_conducted` events gain
optional `virtual: true` and report `surface: electrified` for owned construct
relays; they do not imply creation or consumption of actual ground. Storm Crown
return deaths use `source_kind: chain_rebound` and the original card context.
Forecast copies and presentation append no external analytics.

## Event card rewards

Event card claims and skips retain the ordinary `reward_choice` payload and add
`reward_kind: "event"` plus the pending reward's `event_id`. `choice_kind` remains
`card` for a claim and `heal_skip` for a skip. Combat rewards use `reward_kind:
"combat"` and an empty event id. This is additive within schema 1; historical
append-only JSONL files are never rewritten.

EN06 Charge (`gain_charge`) is an ordinary `enemy_action_resolved` event rather
than an `enemy_status_tick`; its status-shaped animation does not make it a
turn-start status decrement. Discharge and Mirror use the existing ranged/area
classification. Event types, local JSONL storage and source attribution stay
unchanged; no new enemy-mechanic analytics event is introduced.

## Opening boons and heirlooms (boon-01)

These additive schema-1 events use the existing local, append-only JSONL writer.
A run persists its opening offer before the first deliberate conversation:

- `run_start_boon_offered`: `{columns, rolled_contents}`. `columns` contains the
  three ordered labels; each rolled content record includes `boon`, `column`
  and its actual `element`, `spells`, `item`, `starter`, `slot` or `relic` as
  applicable. Emit on the first talk that presents the offer, not run creation.
- `run_start_boon_chosen`: `{boon, content, choices, declined}`. `content` is the
  selected rolled record; `choices` identifies accepted spell copies. Decline
  has an empty boon/content/choices and `declined: true`. Back/cancel emits no
  decision and never rerolls.
- `heirloom_left`: `{item, none}`. Empty `item` and `none: true` mean Leave
  nothing, which retains the existing progression heirloom. The selected base
  equipment id replaces the old heirloom; no graft or upgrade data is stored.

Receipts travel in `opening_boon_events` with the committed run. The scene emits
only after saving the gameplay boundary, and replays receipts on resume using
`<run_id>:opening_boon:<index>:<type>` idempotency keys. Repeated conversations,
refreshes and crash recovery cannot append duplicates. Terminal saves retain
unanswered heirloom choices and unflushed receipts. `heirloom_terminal_wallet`
preserves the already processed victory carry or death loss while that prompt
is resumable, avoiding a second wallet settlement or recovery-marker erasure.
No historical JSONL is rewritten, and the existing run/combat event payloads,
source attribution and progression wallet policy remain in use.
