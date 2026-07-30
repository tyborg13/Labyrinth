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
| Rare | 2 | A two-step state sequence, progressive deck commitment, status target, or repeated elemental loop | A meaningful play, damage, defense, or intensity engine |
| Epic | 3 | Cross-card sequencing, low-health risk, three-resource convergence, or a demanding per-turn state | A turn-shaping payoff worth building around |
| Legendary | 4 | A near-combo condition such as five elements, three same-element cards in one turn, Defiance, or a skill-enabled banked play | An explosive payoff that can define the run without being automatic |

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
- Prefer combat state and sequencing bridges over requiring one card to print
  every relevant trait. "While you have block, Push and Pull..." lets separate
  defensive and control cards assemble a line.
- Card-trait conditions may inspect the complete printed card when the card
  itself is the point: action families, Time, health cost, Burn, element, and
  play destination.
- Sequencing effects may count qualifying cards, statuses, deaths, or unique
  elements per turn or combat.
- Rewards use the shared relic reward vocabulary: draw, card play, block,
  stoneskin, block conversion, healing, elemental intensity, all-enemy damage,
  and all-enemy statuses.
- Free relic draws stop before they would trigger Fatigue. A relic payoff must
  not turn a previously survivable card play into an involuntary defeat.
- Draw is not a default payoff. Keep it when the condition naturally opens
  hand space and pair larger draws with enough card plays to use them.
- Repeatable healing is not a normal relic engine. Healing relics use a combat-
  or run-scoped limit; repeatable defense should use block or stoneskin.
- Deck commitment scales progressively and caps. Starting intensity must not
  erase the element-building game at combat start.
- Relic effects may combine with other relics and permanent skills, but they
  must not make a previously legal action worse or consume a skill choice
  implicitly.

## Review Gate

For a complete-set pass:

1. Every live relic uses the current design version and rarity tiers above.
2. No relic's primary upside is unconditional max health, opening draw, opening
   block/stoneskin, first-attack damage, or post-combat currency.
3. Every new relic has a distinct 96x96 RGBA icon and direct mechanic proof.
4. A trigger-feasibility table checks the live card/skill pool, normal encounter
   size, expected combat length, repeat cadence, and worst-case scaling.
5. Focused tests cover each reusable effect category, the full Godot suite
   passes, and the treasure surface is inspected at normal and constrained
   presentation sizes.
