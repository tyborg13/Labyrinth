# Authored events and omens

Event rooms use the protected, director-authored `data/events.json` catalog rather
than a fixed encounter. `EventRules` owns selection, requirements, ordered effect
transactions and previews. `OmenRules` owns timed combat modifiers. No art or
sound is required by this stopgap panel.

## Schema and validation

Schema version 1 has `events` and `omens` dictionaries keyed by persistent ids.
An event has `title`, `body` (at most 70 words), `pool`, `min_section`,
`max_section`, positive `weight`, and two or three `choices`. Pools are `any`,
`earth`, `fire`, `air`, `ice`, `lightning`, or `shadow`; section bounds are
inclusive indices 0–5. Choice ids are unique within their event; labels are at
most 28 characters. A choice has `id`, `label`, ordered `effects`, optional
`requires`, and optional `result`. Random outcomes have positive `weight`,
`effects`, and optional `result`; weights sum to 100.

An omen has `name`, `kind` (`blessing` or `bane`), `description`, positive
`fights`, and one known `effect`. `EventRules.validate_data()` reports catalog
problems, including unknown requirement/effect types and missing referenced
omens. `GameData` caches the file once and exposes `events()`, `event_def(id)`,
`omens()`, and `omen_def(id)`.

Art paths are derived only by `EventRules.art_path(id)` as
`res://assets/art/events/<event_id>.png`. Missing art is allowed. The temporary
panel does not load art.

## Selection

First entry persists `room.event_id`. The element comes from the section's
seeded dragon, with Noctyrax mapped to `shadow`. Eligible events match that
element or `any`, include the current section within their bounds, and are
absent from `seen_events`. Sort ids before a weighted RNG draw seeded only by
run seed, room coordinate and selection purpose. Selection is independent of
catalog insertion order. If no eligible event exists, use any unseen `any`
event ignoring section bounds, then `lost_cartographer`.

Entry does not mark the event seen. Resolving a choice does. The persisted id
survives save/load on either page. Legacy mid-event saves without an id use
`lost_cartographer`; its `embers` and `survey` ids are preserved.

## Requirements

Disabled choices remain visible, with the exact reason as their tooltip.

| Requirement | Check and disabled reason |
| --- | --- |
| `hp_above {amount}` | Current HP strictly above amount; `Requires more than N Health.` |
| `max_hp_above {amount}` | Max HP strictly above amount; `Requires more than N max Health.` |
| `embers_at_least {amount}` | Held Embers at least amount; `Requires N Embers.` |
| `has_item` | Consumable in pack or equipped; `Requires an item.` |
| `has_equipment {slot}` | Equipped piece in slot; `Requires an equipped <slot name>.` |
| `has_attuned_magic` | At least one attuned spell; `Requires an attuned spell.` |

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
| `relic {rarity}` | Random unowned treasure-offerable relic of rarity; lower rarities then any offerable rarity; excludes retired, Guardian and dragon exclusives. Empty pool substitutes 40 Embers and records `substitution_for`. Uses the ordinary relic claim bonuses. |
| `card {rarity, element}` | Random reward-pool magic card into reserve, marked NEW/unread; requested rarity, lower rarities, then any rarity; empty pool substitutes 40 Embers. |
| `card_choice {count, element, min_rarity?}` | Distinct reward-pool magic offers using existing reward rarity/card weights, with a minimum rarity floor; deferred until Continue. |
| `equipment {rarity, slot?}` | Random unowned gear into pack, marked NEW/unread; lower rarity then any; empty pool substitutes 40 Embers. |
| `reforge {slot, rarity_step}` | Random different same-slot piece at stepped rarity, capped at Legendary; fall back to the old rarity, then any rarity. Success destroys old gear/grafts, equips replacement and rebuilds the deck. An empty pool preserves old gear/grafts and substitutes 40 Embers. |
| `item {count}` | Random consumables into pack through the Scavenger acquisition semantics. |
| `lose_item` | One random pack consumable, or equipped consumable when pack is empty. |
| `transform_magic {count, rarity_step}` | Random distinct attuned slots, fewer if necessary; different reward spell at stepped rarity, then old rarity, then any rarity, any element. Preserves slot, records from/to and rebuilds deck. An empty pool leaves the slot unchanged and records `nothing_changed`. |
| `omen {id}` | Add or refresh the timed omen, without stacking. |
| `defiance {amount}` | Increase this run's capacity and remaining charges; persist the run bonus, never progression. |
| `scout {amount}` | Increase current-section uses. |
| `reveal {hops}` | Existing Cartographer descendant reveal; record newly identified coordinates. |
| `random {outcomes}` | Weighted seeded outcome; recursively apply its effects and use its result text. |

Card element `section` resolves from the section dragon; shadow resolves to any.
`any` includes the existing elemental/radiance magic reward pool. Explicit
elements filter that pool. Random choices use run seed, room coordinate and
choice id; acquisition pools are sorted before draws.

Outcomes record actual deltas and selected ids, including `hp`, `max_hp`,
`embers`, acquired `relic`/`card`/`equipment`/`item` ids, `card_choice.cards`,
`reforge`/`transform_magic` from/to and slot, omen id/duration, Defiance, Scout,
and revealed rooms. Random wrapper effects produce their concrete inner results.

## Event continuation and rewards

`mode` stays `event` while `event_state` contains `{event_id, page, choice_id,
result_text, outcomes}`. Pages are `choices` and `result`. The choice's result is
used unless a random outcome supplies its own result. Empty text is omitted.
Continue marks the room cleared and removes `event_state`, returning to `room`.

If the transaction generated card offers, Continue instead opens the existing
reward chooser with `pending_reward.kind = event`, the saved cards,
`heal_amount = 0` and `skip_label = Skip`. Claim uses the combat-reward reserve
acquisition path; Skip grants nothing. Deferred-choice healing and rerolls do
not replace this authored event offer. Both return to the cleared room and the
existing map flow.

## Omens

Run state stores `omens` as `{id, fights_left}` entries. Refresh uses the maximum
of the remaining duration and authored duration. `OmenRules.active()` supplies
id, name, kind, description and remaining fights for a future HUD.

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

## Preview templates

`choice_effect_lines()` returns one line per effect, except random effects which
return one line per outcome. Icons use existing `@icon(name)` markup with spaces
around them. Rarity is capitalized; element is capitalized and omitted for any.

| Effect | Exact template |
| --- | --- |
| HP cost | `Lose N @icon(health).` |
| Heal | `Heal N @icon(health).` |
| Percentage heal | `Heal P% of your max @icon(health).` |
| Max HP | `+N max @icon(health).` / `−N max @icon(health).` (U+2212 minus) |
| Embers | `Gain N Embers.` / `Pay N Embers.` |
| Relic | `Gain a random <Rarity> relic.` |
| Card | `Gain a random <Rarity> <Element> spell.` |
| Card choice | `Choose 1 of N <Element> spells.` / `Choose 1 of N <Element> spells, <Rarity> or better.` |
| Equipment | `Gain a random <Rarity> <slot name>.` / `Gain random <Rarity> boots.` / `Gain a random <Rarity> piece of gear.` |
| Reforge | `Reforge your <slot name> into a random <next Rarity> one.` |
| Item | `Gain a random item.` / `Gain N random items.` |
| Lose item | `Lose a random item.` |
| Transform | `Transform a random spell.` / `Transform N random spells.` / `Transform a random spell into a higher rarity.` |
| Omen | `<Blessing\|Bane>: <Name>. <description> (<fights> fights)` |
| Defiance | `Gain 1 @icon(defiance) for this run.` |
| Scout | `+N Scout.` |
| Reveal | `Reveal the routes up to N rooms ahead.` |
| Random | `<weight>%: <inner lines joined with a space>` / `<weight>%: Nothing.` |

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

Choice and result pages, room event id, seen ids, outcomes, pending offers,
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
reward continuation and exact previews. Runtime regression proof also includes
the section-map, dragon-boss and full Godot suites.

## Design-owner renderer proof

The focused test script also supplies a `--probe` mode and an embedded proof
contract. This worker cannot access the macOS window server and does not run
that mode. The owner can materialize its contract headlessly, then run the
windowed probe at 1920×1080, 100% scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ev-01 && python3 tools/godot_task_runner.py --task-id ev-01 --stream -- godot --headless --path . --script tests/event_rules_test.gd -- --write-proof-contract /private/tmp/ev-01-event-proof.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/ev-01 && python3 tools/visual_probe_runner.py tests/event_rules_test.gd --task-id ev-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract /private/tmp/ev-01-event-proof.json --result-manifest /private/tmp/ev-01-event-proof-result.json -- --probe
```

Captures are `user://ev-01-events/01_choices.png`, `02_blocked_focus.png`, and
`03_result.png` in the visual runner's isolated namespace; the probe prints the
absolute directory. Script assertions check disabled-choice retention and the
result Continue action. Inspect the fresh captures before accepting visual
layout. The existing inspection fixture tool has no event/room selector, so no
unsupported `--event` fixture invocation is advertised or added.
