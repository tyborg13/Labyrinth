# Authored events and omens

Event rooms use the protected, director-authored `data/events.json` catalog rather
than a fixed encounter. `EventRules` owns selection, requirements, ordered effect
transactions and previews. `OmenRules` owns timed combat modifiers. `EventView` presents those rules using the approved illustrated assets and existing UI cues.

## Schema and validation

Schema version 2 has `events` and `omens` dictionaries keyed by persistent ids.
An event has `title`, `body` (at most 70 words), `pool`, `min_section`,
`max_section`, positive `weight`, and two or three `choices`. Pools are `any`,
`earth`, `fire`, `air`, `ice`, `lightning`, or `shadow`; section bounds are
inclusive indices 0–5. Choice ids are unique within their event; labels are at
most 28 characters. A choice has `id`, `label`, ordered `effects`, optional
`requires`, and optional `result`. The protected director catalog contains 45
events and 11 unchanged omens. `random` is a retired, invalid effect type;
validation rejects it, including in a newly supplied catalog.

An omen has `name`, `kind` (`blessing` or `bane`), `description`, positive
`fights`, and one known `effect`. `EventRules.validate_data()` reports catalog
problems, including unknown requirement/effect types and missing referenced
omens. `GameData` caches the file once and exposes `events()`, `event_def(id)`,
`omens()`, and `omen_def(id)`.

The brief permits delayed delivery of the 18 new paintings. This checkout
already includes all 45 event paintings in the approved provenance manifest.
Missing paintings still leave the existing painting control empty and never
prevent an event opening. Existing approved art/provenance checks remain intact;
a debug-only missing-art fixture verifies the fallback without changing assets.

Art paths are derived only by `EventRules.art_path(id)` as
`res://assets/art/events/<event_id>.png`. `EventView` loads this derived path through `AssetLoader`.

## Selection

First entry persists `room.event_id`. The element comes from the section's
seeded dragon, with Noctyrax mapped to `shadow`. Eligible events match that
element or `any`, include the current section within their bounds, and are
absent from `seen_events`. Next remove the ids in the run’s `event_memory`; use
that filtered pool only when at least six candidates remain, otherwise ignore
memory. Apply the existing fallback order after this filter. Sort ids before a weighted RNG draw seeded only by
run seed, room coordinate and selection purpose. Selection is independent of
catalog insertion order. If no eligible event exists, use any unseen `any`
event ignoring section bounds, then `lost_cartographer`.

At run creation, `event_memory` owns a snapshot of the ids in the standalone
`user://recent_events.json` convenience file. Older saves load an empty memory,
without consulting the file. The snapshot stays fixed throughout the run and
continues to use the ordinary run serializer.

Entry does not mark the event seen. Resolving a choice does. The live flow,
after saving the result, also appends the event id to the independent history
file, retaining the last sixteen in order, including repeats. The console flow
uses the same transition check. Rejected input, repeated results and Continue
do not append. `RecentEventStore` writes a small `{recent_events: [ids...]}` JSON
object to a sibling temp file, flushes and closes it, then atomically renames it
over the destination.

This file is disposable: a missing, corrupt or unreadable file reads as empty;
a write failure is silently ignored by the game flow and never blocks a choice,
Continue, run checkpoint or permanent award. History is absent from progression,
does not advance any profile/run revision, is never repaired from a save, and
has no Steam Cloud requirement. Legacy profile `recent_events` is discarded on
normalization without migration into the file. The failed-award regression
checks that a subsequent history write leaves profile/checkpoint bytes unchanged
and that ordinary resume repair still restores the earned Moltshard.

The persisted event id survives save/load on either page. Legacy mid-event saves
without an id use `lost_cartographer`; its `embers` and `survey` ids are preserved.

## Requirements

Disabled choices remain visible, with the exact reason as their tooltip.

| Requirement | Check and disabled reason |
| --- | --- |
| `hp_above {amount}` | Current HP strictly above amount; `Requires more than N Health.` |
| `max_hp_above {amount}` | Max HP strictly above amount; `Requires more than N max Health.` |
| `embers_at_least {amount}` | Held Embers at least amount; `Requires N Embers.` |
| `has_item` | Consumable in pack or equipped; `Requires an item.` |
| `has_equipment {slot}` | Equipped piece in slot; `Requires an equipped <slot name>.` |
| `has_attuned_magic` | At least one spell in the deck (id kept for save/data compatibility); `Requires a spell in your deck.` |

The data slot `armor` is displayed as `armour`; other slot names are weapon,
offhand, boots and trinket. A choice consisting only of `reveal` is unavailable
when no new rooms can be revealed: `Nothing new to reveal.`

## Ordered effect transactions

A choice works on an owned copy, applying effects in their listed order. It
commits the result page, concrete outcomes, seen-event receipt and analytics
together. Repeated input on the result page cannot apply the choice again.

| Effect | Resolution |
| --- | --- |
| `hp {amount}` | Health delta; costs never reduce HP below 1. |
| `heal {amount}` | Heal, capped at max HP. |
| `heal_percent {percent}` | Round max HP × percent / 100, then heal with the same cap. |
| `max_hp {amount}` | Max HP never below 1; increases also increase current HP; decreases clamp current HP. |
| `embers {amount}` | Existing held/unbanked add/spend helpers; never banks progression currency. |
| `relic {rarity}` | Seeded unowned treasure-offerable relic of rarity; lower rarities then any offerable rarity; excludes retired, Guardian and dragon exclusives. Empty pool substitutes 40 Embers and records `substitution_for`. Uses the ordinary relic claim bonuses. |
| `card {rarity, element}` | Seeded reward-pool magic card straight into the deck, marked NEW/unread; requested rarity, lower rarities, then any rarity; empty pool substitutes 40 Embers. |
| `card_choice {count, element, min_rarity?}` | Distinct reward-pool magic offers using existing reward rarity/card weights, with a minimum rarity floor; deferred until Continue. |
| `equipment {rarity, slot?}` | Seeded unowned gear into pack, marked NEW/unread; lower rarity then any; empty pool substitutes 40 Embers. |
| `reforge {slot, rarity_step}` | Seeded different same-slot piece at stepped rarity, capped at Legendary; fall back to the old rarity, then any rarity. Success destroys old gear/grafts, equips replacement and rebuilds the deck. An empty pool preserves old gear/grafts and substitutes 40 Embers. |
| `item {count}` | Seeded consumables into pack through the Scavenger acquisition semantics. |
| `lose_item` | One seeded pack consumable, or equipped consumable when pack is empty. |
| `transform_magic {count, rarity_step}` | Seeded distinct spells in the deck, fewer if necessary; different reward spell at stepped rarity, then old rarity, then any rarity, any element. Preserves its deck position, records from/to and rebuilds deck. An empty pool leaves the spell unchanged and records `nothing_changed`. |
| `omen {id}` | Add or refresh the timed omen, without stacking. |
| `defiance {amount}` | Increase this run's capacity and remaining charges; persist the run bonus, never progression. |
| `scout {amount}` | Increase current-section uses. |
| `reveal {hops}` | Existing Cartographer descendant reveal; record newly identified coordinates. |

Card element `section` resolves from the section dragon; shadow resolves to any.
`any` includes the existing elemental/radiance magic reward pool. Explicit
elements filter that pool. Concrete reward identities use run seed, room coordinate and
choice id; acquisition pools are sorted before draws.

Outcomes record actual deltas and selected ids, including `hp`, `max_hp`,
`embers`, acquired `relic`/`card`/`equipment`/`item` ids, `card_choice.cards`,
`reforge`/`transform_magic` from/to and slot, omen id/duration, Defiance, Scout,
and revealed rooms. Acquisition RNG chooses the concrete identity in advance;
each choice has a fixed ordered tradeoff with no probability branches.

## Event continuation and rewards

`mode` stays `event` while `event_state` contains `{event_id, page, choice_id,
result_text, outcomes}`. Pages are `choices` and `result`. The choice’s authored result is used. Empty text is omitted. A legacy save
already on the result page keeps its stored result text and concrete outcomes,
including outcomes from retired probability branches; they never replay. A
legacy save on the choices page reads the rewritten current catalog choices.
Continue marks the room cleared and removes `event_state`, returning to `room`.

If the transaction generated card offers, Continue instead opens the existing
reward chooser with `pending_reward.kind = event`, the saved cards,
`heal_amount = 0` and `skip_label = Skip`. Claim uses the combat-reward deck
acquisition path; Skip grants nothing. Deferred-choice healing and rerolls do
not replace this authored event offer. Both return to the cleared room and the
existing map flow.

## Omens

Run state stores `omens` as `{id, fights_left}` entries. Refresh uses the maximum
of the remaining duration and authored duration. `OmenRules.active()` supplies
id, name, kind, description and remaining fights for the room and combat HUD.

Each finished combat decrements active omens and removes entries at zero.
Victory, physical escape, defeat/Last Door retreat, Guardian and boss completion
all use the same completion boundary. A room receipt prevents duplicate ticks;
starting another combat there clears that receipt. Loading or previewing combat
does not tick durations.

| Omen effect | Combat hook |
| --- | --- |
| `start_block`, `start_stoneskin`, `start_expose {amount}` | Add the player's starting status; Expose adds to and is consumed by the next direct hit, including blocked hits. |
| `start_vision_turns {amount, radius}` | Existing Vision action semantics: `radius` is the Vision amount and `amount` its duration. Lantern Sight reads radius 2 and duration 3 from its authored effect. |
| `first_turn_card_plays {amount}` | First activation's bonus play budget; total never below 1; bonus plays never increase Wait. |
| `first_turn_movement {amount}` | First activation's movement capacity/remaining; never below 0; second activation returns to ordinary movement. |
| `start_on_fire` | Fire on the player start tile when surface placement allows it. |
| `umbra_stage_delta {amount}` | Shift starting stage, capped at Heart; never creates boss-only Eclipse. |
| `ember_drop_percent {amount}` | Multiply enemy drop by amount/100; multiple omens multiply; round the final amount half up. |
| `extra_enemies {amount}` | Standard rooms only; normal depth/element pool; legal free floor tiles; part of generated layout and pre-battle dossier. |

No active omens means no additional combat-state fields or changed RNG draws.

## Concrete choice previews

`EventRules.preview_choice(state, choice_id) -> Array[Dictionary]` runs the
ordinary ordered `apply_effects` transaction on an owned copy, seeded with the
same `choice|<choice_id>` purpose as commitment. It returns exactly the concrete
outcomes the choice will commit: ids, actual amounts, from/to, deck destinations,
card offers, omen durations and empty-pool substitutions. It never mutates run
state, progression, map analytics or another choice’s RNG. Invalid/unavailable
choices return an empty outcome array.

`EventRules.preview_lines(state, event_id, choice_id) -> Array[Dictionary]`
returns one `{text, kind, ids}` record per authored effect, in order, including
multiple item grants and transformations grouped into their original effect.
The transient `apply_effects.effect_outcomes` grouping is neither saved nor
logged. For transformations and reforges, ids are ordered from/to pairs; card
choices retain offer order; item grants retain acquisition order. Other named
rows contain their concrete id, and plain/substitution rows have no ids.

`EventView` computes all choice lines once when an event opens and caches them
by event and choice for that screen’s lifetime. Column fit retries, focus,
frame refreshes and the result transition reuse the cache. Presentation attaches
the structured row metadata for evt-02’s hover inspection. The console’s
`choice_effect_lines` adapter returns these same named strings. The existing
cost/gain/bane tones remain unchanged; no new UI design or animation is added.

| Kind | Exact template |
| --- | --- |
| `relic`, `equipment`, `card` | `Gain <Name>.` |
| `item` | `Gain <Name>.` / `Gain <A> and <B>.` |
| `card_choice` | `Choose 1: <A>, <B> or <C>.` |
| `reforge` | `Your <Old> becomes <New>.` |
| `transform` (one) | `<Old> becomes <New>.` |
| `transform` (several) | `3 spells change: hover to see.` (actual count) |
| `lose_item` | `Lose <Name>.` |
| `plain` (empty acquisition pool) | `Gain 40 Embers.` |
| `plain` (HP cost) | `Lose N @icon(health).` |
| `plain` (heal) | `Heal N @icon(health).` |
| `plain` (percentage heal) | `Heal P% of your max @icon(health).` |
| `plain` (max HP) | `+N max @icon(health).` / `−N max @icon(health).` |
| `plain` (Embers) | `Gain N Embers.` / `Pay N Embers.` |
| `omen` | `<Blessing\|Bane>: <Name>. <description> (<fights> fights)` |
| `plain` (Defiance) | `Gain 1 @icon(defiance) for this run.` |
| `plain` (Scout) | `+N Scout.` |
| `plain` (reveal) | Existing layout-specific `effect_lines` survey text. |

Where no concrete named outcome exists, the lines read `Gain nothing.`, `Lose an item.`, `Reforge your gear.`, `Transform a spell.` (nothing to transform) or `Nothing changes.` (an exhausted transformation pool). All available choices in the normal catalog preview test have concrete outcomes.

## Concrete result rows

Each concrete outcome gets one row, using the actual delta, selected name or
remaining duration. Healing outcomes retain their original effect type so zero
healing is still reported as healing. Legacy positive `hp` outcomes render as
healing. Asset names come from their existing definitions; item copies each get
a row. No acquisition-copy placeholders remain.

| Outcome | Exact template |
| --- | --- |
| HP cost | `Lost N @icon(health).` |
| Heal / percentage heal | `Healed N @icon(health).` (actual capped amount) |
| Max HP | `+N max @icon(health).` / `−N max @icon(health).` |
| Embers | `Gained N Embers.` / `Paid N Embers.` |
| Relic / equipment / card / item | `Gained <name>.` |
| Card choice | `Next: choose 1 of N spells.` |
| Lose item | `Lost <Item name>.` |
| Reforge / transform | `<Old name> became <New name>.` |
| Omen | `<Blessing\|Bane>: <Name> (<fights> fights).` |
| Defiance | `Gained 1 @icon(defiance) for this run.` |
| Scout | `+N Scout.` |
| Reveal | `Revealed N rooms.` |
| Ember substitution | `Gained 40 Embers instead.` |
| Empty transformation | `Nothing changed.` |

Test/tool route traversal uses the first available authored choice, continues its
result page, and skips any event card chooser. It never assumes an `embers`
choice on arbitrary events. Explicit legacy Cartographer tests keep their
`embers` and `survey` requests.

## Saves, analytics and console

Choice and result pages, room event id, seen ids, additive `event_memory`, outcomes, pending offers,
run-only Defiance bonus and active omens use the existing run serializer.
Legacy event saves migrate only their event identity/state, preserving map
layout, Scout uses, recovery, inventories and progression.

The existing ordered `map_events` outbox records additive `event_id`,
`choice_id`, and `outcomes` on `map_event_resolved`, retaining `choice`, `room`,
`embers`, and `revealed_rooms`. `omen_gained {id, fights}` and
`omen_expired {id}` share that durable append-only outbox and save-then-flush
revision keys. See [analytics.md](analytics.md).

The console command `event` lists choice ids, availability, exact effect lines
and block reasons. `event <choice_id>` resolves; `event continue` advances.
Cartographer retains `event embers` and `event survey`.

## Adding an event

Add an event definition to `data/events.json`, using the schema and supported
effects above. Add referenced omens there if needed; do not add code or assets
for an event using existing effect types. Supply every perceivable value in
data. Run `tests/event_rules_test.gd` through the task runner; its suite validates
the entire catalog, selection, requirements, effects, omens, persistence,
reward continuation and exact previews. evt-01 focused proof additionally covers preview equality for every available
choice over 50 seeds × three Umbra depths × fresh/exhausted inventories,
rotation, both legacy save pages, event view integration and registration.
Full Godot/Python suites belong to the design owner’s merge round.

## Presentation

`EventView` is a full-screen modal over the board. The section map remains
closed until resolution and any deferred card choice have finished. It reads
cached `EventRules.preview_lines`, availability/block reasons and saved
`event_state` pages/outcomes; all rules, saves and analytics stay owned by ev-01.

At **1920×1080, 100% UI scale**:

- The scrim blurs/dims the board and adds radial darkening. The approved CSS
  specifies 2 px blur, brightness 0.35, saturation 0.7, and a radial gradient
  from rgba(8,6,5,0.35) to rgba(4,3,2,0.86) at 75%.
- The 1640×780 panel starts at (140,150), with the existing major-dialog
  `ThemedPanelOrnament` material, gilded hairlines and bold corner brackets
  (CSS: 46 px, 4 px).
- The painting covers (26,26,1062,728) inside the panel. It has no frame. The
  right 18%, top 7% and bottom 10% fade into the panel through an alpha mask.
- The right column begins at panel (1060,52), width 540. `EVENT` uses the UI
  eyebrow font at 15 px with 5 px tracking in GOLD_DIM. The title uses the UI
  font at 44 px in GOLD_BRIGHT, reduced in 2 px steps to at least 34 px to avoid
  wrapping. The shared gilded rule follows the title. Body text uses the Text
  font at 22 px, line height 1.42, in TEXT.
- Choices start 32 px after the body. Each existing choice plate is 548 px
  wide, with padding top/right/bottom/left 13/18/13/58, 14 px between plates,
  and the CSS minimum content height of 52 px (78 px including padding).
  Its 26 px key disc has a GOLD_DIM ring and a GOLD numeral 1–3. The label is
  UI 24 px TEXT. Effects use Text 19 px, one row per rules effect line.
- UiPalette event tones: EVENT_COST #e07a6c, EVENT_GAIN #e9cf8f, EVENT_BANE
  #c58cf0, EVENT_BLESSING #f2d27a. Neutral text uses TEXT_2 #b5a58a.
- Hover/focus brightens gilding and adds a 22 px ember glow at 28% opacity.
  Unavailable plates stay focusable at 50% opacity, with TEXT_2 labels and
  exact block reasons in italic Text 17 px TEXT_3. They cannot activate.
- On the result page, italic Text 22 px #d8c9a8 replaces the body. A quiet
  outcome well follows after 30 px; its rows use toned Text 19 px. The
  ember-bronze Continue button uses VARIANT_SELECTED, the approved CSS plate
  height of 78 px, and is anchored 40 px above the panel bottom.
- Layout uses the live font shaper. On overflow, reduce body text to 20 px,
  then effects to 18 px. No text is clipped. The suite and probe assert fit
  for all 45 events and both pages in fresh/rich states. The evt-01 worker
  reports fit regressions for the evt-02 design owner to resolve.

Motion: scrim fade 0.18 s; panel fade/rise 12 px over 0.22 s, ease-out. Painting
starts once the panel reaches 80% opacity, then settles 1.04→1.00 over 0.9 s.
Right-column page changes crossfade over 0.18 s; outcome rows stagger by 0.08 s.
Reduced motion keeps fades and removes rise/zoom/badge pop. Close fades 0.16 s.
Painting fade-in is 0.22 s (`PAINTING_FADE_SECONDS`); individual outcome-row
fades are 0.18 s (`OUTCOME_ROW_FADE_SECONDS`), accepted by the design owner.
The art shader passes vertex modulation to the fragment explicitly: fragment
`COLOR` already contains the texture sample, so multiplying by it would square
source RGB and darken the painting. Only the specified edge mask changes alpha.
The native probe checks the central 40% mean Rec.709 RGB luminance against the
cover-scaled processed source, with at most 8% relative error on settled pages.
Reduced motion is applied through the live settings callback; enabling it during
an event immediately stops rise/zoom while the opacity fades continue.

Sound: existing menu-page-open on opening, shared forged button click on choice
activation, and menu-page-close on Continue. No new audio. Mouse, 1–3, Up/Down,
Enter and controller A activate choices; stick/D-pad navigate, including
unavailable plates. Initial focus is the first available choice. Escape on the
keyboard and Start on the controller open the pause menu over the event; closing
pause restores its focused choice. Controller Back (`ACTION_CANCEL`) is inert
on choices and activates Continue on results. This supersedes the ev-02
Back/Escape wording. The controller prompt names the focused choice.

Active omens appear after relics/Rites in the existing header grid in room and
combat modes. Each unique approved 96 px wax seal is shown at 38×38, with a
bottom-right fights-left numeral in UI 15 px TEXT on a 16 px INK_0 disc. Its
1 px border is GOLD for blessings or UMBRA #9a7cf0 for banes. The shared tooltip
shows the name, Blessing/Bane eyebrow in its event tone, exact description
with inline icons, and `N fights left`. Newly gained badges pop 1.25→1.00 over
0.25 s; expired badges fade over 0.3 s. Result rows retain exact rules text;
the optional 20 px relic/omen icon prefix is not used.

Art processing uses only protected, hash-approved raw inputs. Paintings become
RGB 1152×768 PNGs using Lanczos then PNG optimization. Seals have #00FF00 keyed
and edge colours unmixed, are trimmed to the alpha bounding box, centred in a
square and reduced to RGBA 96×96 with no green fringe. Prompts, source/output
SHA-256 and encoder version are recorded in `spec/assets/events/README.md`
and `hashes.json`; `tests/test_process_event_art.py` audits and reconstructs
all 38 outputs. No raw input, prompt or catalog value is rewritten.

## Design-owner renderer proof

The worker has no macOS window-server access. The following commands materialize
the proof contract headlessly and capture seven real-renderer states windowed:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ev-02 && python3 tools/godot_task_runner.py --task-id ev-02 --stream -- godot --headless --path . --script tests/event_view_probe.gd -- --write-proof-contract res://output/ev-02/proof-contract.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/ev-02 && python3 tools/visual_probe_runner.py tests/event_view_probe.gd --task-id ev-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --proof-contract output/ev-02/proof-contract.json --result-manifest output/ev-02/renderer-proof-result.json
```

The 60 s timeout covers the full fit/branch suite followed by scene setup and
seven timed captures. Captures are in `user://ev-02-events/` in the runner's
isolated namespace; the probe prints the absolute directory:

1. `01_hanged_knight_choices.png` (choice 1 hovered).
2. `02_bloodletters_basin_choices.png` (choice 1 hovered).
3. `03_name_collector_choices.png` (choice 1 hovered).
4. `04_frozen_champion_disabled.png` (0 Embers, blocked choice focused).
5. `05_hanged_knight_result.png` (cut).
6. `06_combat_omens_tooltip.png` (Stone Vow and Hunted, tooltip open).
7. `07_reduced_motion_open.png` (opening frame, no rise/zoom).

The existing inspection fixture tool has no event/room selector; no unsupported
fixture command is advertised. The design owner owns fixture preparation,
commit/review and publication. The event-rules suite now exercises EventView for
availability, exact block reason and Continue while retaining every rules assertion.

## Hero Expose compatibility

Expose on the hero follows the same next-hit rule as Expose on enemies: add its
current amount to the next positive direct hit, before Freeze/Chilled and Block,
then clear it. Non-direct surface, collision and Bleed damage do not consume it.
Dread uses this status; enemy-applied Expose from Bile Bloomer's Shard Mark (2)
and Noctyrax's Void Claw (1) also works. The revealed-intent and lethal/danger
forecasts run the same resolver, including absorption and one-time consumption.
The no-omen compatibility exception is exactly this extra damage, consumed Expose
and its ordinary damage statistic; unrelated player fields remain byte-identical.

`python3 tools/enemy_expose_heuristic.py` evaluates the authored intent packages
with the existing card scorer and weights: remove only the inert Expose rider for
the before case, retain it for after, then average by authored intent weights.
Bile Bloomer: 1.304064 → 1.517118 (Shard Mark 1.5753 → 2.3565).
Noctyrax: 4.548725 → 4.639225 (Void Claw 3.7239 → 4.0859).
These are relative health-equivalent package scores, not an encounter simulation;
boss geometry and unsupported enemy-only actions retain the scorer's existing
limits. No intrinsic card coefficients or protected tuning values changed.

### evt-01 proof for the design owner

The worker cannot access the macOS window server and does not attempt these
windowed commands. The new probe captures five matching choice/result pairs,
including named relics, reforge, transformation, deferred cards and missing art,
with pointer hover and keyboard focus at 1920×1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/evt-01 && python3 tools/godot_task_runner.py --task-id evt-01 --stream -- godot --headless --path . --script tests/evt01_event_preview_probe.gd -- --write-proof-contract /private/tmp/labyrinth_codex/evt-01/preview-proof-contract.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/evt-01 && python3 tools/visual_probe_runner.py tests/evt01_event_preview_probe.gd --task-id evt-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth_codex/evt-01/preview-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/evt-01/preview-renderer-result.json
```

Captures are `01_relic_trade_{choices,result}.png`,
`02_reforge_{choices,result}.png`, `03_transform_{choices,result}.png`,
`04_card_choice_{choices,result}.png` and `05_missing_art_{choices,result}.png`
in the runner’s isolated `user://evt-01-preview/`; the probe prints the absolute
path. Inspection fixture preparation and independent visual review remain
assigned to the design owner.
