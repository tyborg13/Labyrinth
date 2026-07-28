# Relic Design Rubric

Relics are run-scoped build engines. A good offer should ask which part of the
current deck the player wants to amplify, not which unconditional stat is
largest.

## Rarity Ladder

Every relic records `design_version: 2`, `condition_tier`, `upside_tier`, and at
least two `build_tags`.

| Rarity | Condition tier | Expected setup | Expected payoff |
| --- | ---: | --- | --- |
| Common | 1 | One visible card trait or an easy once-per-turn event | A small conversion, modifier, or resource nudge that points toward a build |
| Rare | 2 | A two-trait card, deck threshold, status target, or repeated elemental loop | A meaningful draw, play, damage, defense, or intensity engine |
| Epic | 3 | Repeated sequencing, low-health risk, three-resource convergence, or a demanding per-turn threshold | A turn-shaping payoff worth building around |
| Legendary | 4 | A near-combo condition such as five elements, three same-element cards in one activation, Defiance, or a skill-enabled banked play | An explosive payoff that can define the run without being automatic |

Rarity is not a flat efficiency multiplier. Higher rarities must combine a
narrower or later condition with a materially higher peak. A legendary that is
always on is a failure even when its average value is balanced.

## Build Tags

`build_tags` are developer-facing balance metadata. They identify the card,
status, resource, positioning, timing, or permanent-skill packages that can
unlock the relic. They are not player-facing rules text and do not replace an
exact `description`.

## Effect Architecture

- Prefer reusable data-driven effects over relic-id branches.
- Card-trait conditions inspect the complete printed card: action families,
  Time, health cost, Burn, element, and play destination.
- Sequencing effects may count qualifying cards, statuses, deaths, or unique
  elements per turn or combat.
- Rewards use the shared relic reward vocabulary: draw, card play, block,
  stoneskin, healing, elemental intensity, all-enemy damage, and all-enemy
  statuses.
- Free relic draws stop before they would trigger Fatigue. A relic payoff must
  not turn a previously survivable card play into an involuntary defeat.
- Relic effects may combine with other relics and permanent skills, but they
  must not make a previously legal action worse or consume a skill choice
  implicitly.

## Review Gate

For a complete-set pass:

1. Every live relic uses the current design version and rarity tiers above.
2. No relic's primary upside is unconditional max health, opening draw, opening
   block/stoneskin, first-attack damage, or post-combat currency.
3. Every new relic has a distinct 96x96 RGBA icon and direct mechanic proof.
4. Focused tests cover each reusable effect category, the full Godot suite
   passes, and the treasure surface is inspected at normal and constrained
   presentation sizes.
