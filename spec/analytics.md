# Local Analytics

Runtime frame-time/render-load collection is specified separately in [performance_telemetry.md](performance_telemetry.md). Gameplay analytics and performance telemetry use distinct files and schemas so high-frequency performance sampling cannot inflate or destabilize the append-only gameplay-event contract below.

The game now records local-only analytics as append-only JSON Lines under `user://analytics/` by default. The storage format is intentionally boring so it can later be uploaded to S3 and queried or compacted into Parquet without changing the in-game emitter.

## Storage

- File format: newline-delimited JSON (`.jsonl`)
- Default path: `user://analytics/events-YYYY-MM-DD.jsonl`
- Metadata: `user://analytics/meta.json`
- Schema version: `1`

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
- `run_resumed`
- `run_ended`
- `combat_started`
- `combat_resumed`
- `combat_ended`
- `reward_offered`
- `reward_choice`
- `card_drawn`
- `card_became_playable`
- `card_played`
- `player_moved`
- `enemy_action_resolved`
- `enemy_status_tick`
- `defiance_triggered`
- `progression_level_up`
- `progression_skill_learned`
- `progression_skill_reset`
- `progression_moltshard_gained`
- `skill_triggered`
- `equipment_equipped`
- `magic_attuned`
- `item_equipped`
- `item_picked_up`
- `merchant_trade`
- `guided_tutorial_started`
- `guided_tutorial_step_completed`
- `guided_tutorial_completed`
- `guided_tutorial_dismissed`
- `guided_tutorial_restarted`

Guided tutorial events are local-only like the rest of the stream. Start events
are idempotent per run and tutorial version. Step events
record `tutorial_version`, the action-committed `milestone_id`, the transient
`phase_id` that produced it, and `completed_step_count`. Dismissal records the
phase and completed count so onboarding drop-off can be diagnosed without
logging hover or other high-frequency input. Completion and replay record the
tutorial version. These events never rename or replace combat-action events;
movement, card, reward, and room choices continue to emit their normal records.

`run_started` includes the compiled starting deck plus the equipment model used
to build it: `reward_cards`, `equipped_equipment`, `equipment_inventory`, and
`collected_equipment`. It also includes recovery marker fields when a previous
death dropped embers for the new run: `recovery_marker_active`,
`recovery_marker_amount`, and `recovery_marker_coord`.
It also includes the active magic loadout fields `attuned_magic_cards` and
`magic_inventory`; `reward_cards` remains the collected reward-card history.
Consumable item loadout state is included as `equipped_items` and
`item_inventory`.

## Card Metrics Supported

The current event stream is enough to derive:

- pick rate via `reward_offered` + `reward_choice`
- combats-in-deck via `combat_started.payload.deck_cards`
- equipment and magic build context via `combat_started.payload.equipped_equipment`,
  `reward_cards`, `attuned_magic_cards`, `magic_inventory`,
  `equipped_items`, `item_inventory`, `equipment_inventory`, and
  `equipment_drops`
- elemental intensity at combat start via `combat_started.payload.elemental_intensity`
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
movement, and elemental-intensity payoffs during the resolved transition.

`card_played.payload` currently logs raw observed ingredients instead of a single heuristic score:

- enemy HP, realized block, and stoneskin removed; future guard intents do not
  count as removable block until that enemy resolves the block action
- pierce actions resolved, sunder actions resolved, and enemy defense bypassed
  by observed HP damage
- terrain HP damage and terrain destroyed from the full resolved transition,
  including incidental AOE and triggered-trap blast damage; traps triggered,
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
- elemental intensity before/after resolution, gross positive per-element
  intensity gained by the played card, and intensity spent by printed card
  costs or relic payoffs
- illusions created and their total created health
- immediate status application deltas for burn, bleed, expose, freeze, shock,
  immobilize, and poison
- actual resolved action list and chosen targets
- `play_mode`, retained as an additive compatibility field and always recorded
  as `printed` now that cards no longer have basic Attack or Move modes
- the player-facing targeting gesture via `target_decision_count` and
  `target_decision_tile`. Card plays now record one board decision even when a
  combined move-and-melee card internally resolves both its preferred movement
  endpoint and enemy target. Choosing an empty destination instead records that
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

AOE card actions are logged in that action list with their explicit `pattern`
offsets so offline balance analysis can distinguish close, line, cluster, and
large-area attacks. Runtime-selected AOE aim orientation is additive on the
resolved action as `orientation`; legal push and pull direction choices are
additive as `force_direction`. These runtime direction fields do not change the
card's printed-play classification.

`enemy_status_tick` captures delayed enemy status resolution. Burn and poison
use `trigger: "turn_start"` when the affected enemy's initiative activation
starts; bleed can use `trigger: "action"` plus `action_type` when a wounded enemy
resolves a move or attack action during that activation. It is useful for later
value-model work, but it is not yet card-source attributed.

`enemy_action_resolved` records each resolved enemy movement, attack, defense,
heal, summon, elemental-intensity build, or authored dragon-boss mechanic step.
Group support actions include additive `support_targets` entries with each
recipient's actor key, display name, tile, and realized amount; this lets Warden
Bulwark record every protected ally without splitting one intent into misleading
separate actions.
Its additive `elemental_intensity_gained` and `elemental_intensity_spent` maps
capture specialist builders and attached enemy payoff costs. Boss mechanics retain the
specific `action_type`, use `presentation_kind` for their animation family, and
set `boss_mechanic: true`; they do not also emit misleading
`enemy_status_tick` events. Movement payloads include the exact ordered `path`,
`path_steps`, selected `target_key`, actor/terrain losses caused by hazards, and
triggered traps. Attack payloads retain target, terrain, and trap consequences.
This makes route choice, obstacle-clearing efficiency, voluntary trap exposure,
Worldspine and cinder-mark pressure, forced Gale movement, crystal armor, Last
Eclipse pressure, and realized enemy damage observable without changing the
append-only schema.

`combat_started` marks recovery combats with `recovery_marker_present` and
`recovery_marker_amount`. It also includes any unclaimed floor equipment ids as
`equipment_drops`, plus the opening Umbra stage, effective vision radius, and
visible enemy count. Objective analysis uses the additive `objective_type`,
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

`magic_attuned` fires when the character overlay swaps a reserve magic card into
one of the six attuned slots outside combat. Its payload records the reserve and
attuned indices, the attuned `card_id`, full `attuned_magic_cards`,
`magic_inventory`, `reward_cards`, and rebuilt `deck_cards`.

`item_picked_up` records a newly collected battlefield item, with `loot_id`,
`card_id`, `destination` (`hand`, `draw`, or `inventory`), and the resulting
`equipped_items` and `item_inventory`. Duplicate cards remain separate pickups.
Both live UI and the headless harness emit it. Direct hand acquisitions keep the
existing `card_drawn` event with `reason: item_pickup`; they do not remove a card
from the draw pile. Full-hand acquisitions go on top of draw and produce their
normal `card_drawn` only when actually drawn. Full-slot pickups produce no draw.
Combat snapshots now own item loadout transactions, so checkpoint replay and
reload copy the result rather than granting or consuming items a second time.

`item_equipped` fires when the character overlay equips or stows an owned
consumable outside combat. Its payload records `action` (`equip` or `stow`),
`card_id`, `inventory_index`, `equipped_index`, full `equipped_items`,
`item_inventory`, and rebuilt `deck_cards`.

`merchant_trade` fires when a blacksmith, arcanist, or scavenger transaction
succeeds in a non-combat merchant room. Its payload records `action` (`buy` or `sell`),
`merchant_kind`, `item_kind`, `item_id`, ember `amount`,
`held_embers_before`, `held_embers_after`, the current `room`, and the updated
equipment, magic, item, reward-card, and deck state.

Intermediate dragon victories emit `combat_ended` and return the run to room
mode without `reward_offered` or `run_ended`; only defeat and the depth-24
Noctyrax victory emit `run_ended`.

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

`progression_level_up` fires when Draw Strength commits at a campfire. Its
payload records `level_before`, `level_after`, the unchanged post-purchase
`skill_ids`, `unspent_skill_points_before`,
`unspent_skill_points_after`, ember `cost`, `held_embers_after`, and
`room`. It grants one bankable point and never implies a skill choice. The
shared event context records the resulting Defiance capacity and remaining
charges; a milestone level adds exactly the capacity delta to the active run.

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

`progression_moltshard_gained` records an earned skill-reset resource. Its payload
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
slot, never while validating a drag or repeating a no-op equip. Confluence emits
one combat-scoped activation when another element's higher intensity first
satisfies a committed card condition or intensity bonus that combat. Later
Confluence benefits remain fully active without producing duplicate events.

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
- elemental intensity production, gating, spending, enemy use, trap scaling, or
  room-start rules
- Umbra stage progression, visibility, hidden-enemy information, or Radiance
  actions
- card actions that create, remove, or redirect combat actors
- combat outcome flow
- status timing or turn sequencing
- any fields used by the balance heuristic or future card-performance dashboards
