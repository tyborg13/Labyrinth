# Relic Design Rubric

Current rules: board-surface pass, 2026-09-06. This replaces the July 2026
intensity-engine guidance. The accepted rule contract is
[Board Surface Refactor](board_surface_refactor/DESIGN.md); the complete
60-ID migration is recorded in its supporting content audit.

Relics change what a player can do with a deck and board. Some provide a simple,
readable benefit; others change targeting, movement, terrain, or consumption.
Do not force the entire roster into one hybrid-element template.

## Rarity Ladder

Every relic records `design_version: 3`, `condition_tier`, `upside_tier`, and at
least two `build_tags`.

| Rarity | Condition tier | Expected setup | Expected payoff |
| --- | ---: | --- | --- |
| Common | 1 | One visible trait, local board condition, or easy turn event | A small modifier or a useful positioning rule |
| Rare | 2 | Prepared terrain, a defense-to-attack sequence, status, or a local consumption choice | A meaningful conversion or a new tactical option |
| Epic | 3 | Cross-card sequencing, risk, or a demanding board arrangement | A turn-shaping payoff or a substantial change to an action |
| Legendary | 4 | A developed terrain route, layered consumption, Defiance, or a demanding card sequence | A rule or payoff that can define the run without free repetition |

Rarity is not a flat efficiency multiplier. A persistent rule can be valuable
because the player must build its board conditions on each encounter. It does
not need a new meter, an arbitrary card-count requirement, or a larger number.

## Effect Architecture

- Prefer reusable effects over relic-ID branches. Use `SurfaceRelicRules` for
  optional transformations and event-scoped terrain rewards.
- Keep the nine approved transformations distinct: conductive Fire, transported
  ground, Rubble-funded redirection, Stoneskin-funded cross attacks, Frozen-kill
  Rubble, spilled Freeze fuel, remote Rubble origins, Rubble Detonate, and Chain
  endpoint exchange. Do not add an every-pair elemental reaction table.
- Preserve useful simple and non-elemental relics alongside these bridges.
- All ground is shared. Fire and Ice placement never causes contact; actual
  entry or that unit's turn start does. Electrified is immediately usable.
  Repainting the same surface does not count as creation or activation.
- Costs consume real, local resources. A cancelled or invalid optional choice
  spends nothing. A preview uses the exact action and board rules of the commit.
- Optional transformations can create risk, change targeting, or consume terrain,
  so the player must explicitly choose them. Owning the relic alone cannot
  silently turn an ordinary action into the risky alternative.
- Chain's printed number is hop reach, not a target cap. Ordinary Lightning
  conducts through a cardinal component; only native Chain bridges air gaps.
  Conductive Fire is consumed by electrical use and does not auto-Detonate.
- Direct hits, passive hazards, trap damage, and secondary relic damage retain
  distinct sources. Direct-hit modifiers do not amplify Fire contact damage.
  A causal healing reward must not grant a passive death a banked card play.
- Retained card-trait conditions may inspect action families, Time, health cost,
  Exhaust, element, and destination. Top-level `burn: true` means Exhaust;
  damaging Burn, Poison, and elemental intensity are retired.
- Use bounded turn/combat limits where a resource reward could repeat. Do not
  use once limits to conceal a broken consume/recreate loop. Terrain-only
  transformations should normally be limited by their real fuel and paid action.
- Free relic draws stop before Fatigue. Larger draws should have a usable play
  window and hand room. Repeatable healing is not a normal relic engine.
- Sparse tile-count or variety rewards inspect the actual visible board; do not
  recreate a global intensity meter or uncapped passive damage scaling.

## Review Gate

1. Check every live relic against the current data version and exact rules text.
2. For each transformation, prove its cost, cancellation, shared danger, legal
   footprints, ordering, and interaction with replacement or consumed terrain.
3. Preserve distinct 96×96 RGBA art and purpose-built mechanic icons.
4. Check enabling card/ability density, ordinary 3–5 enemy encounters, expected
   combat length, repeat cadence, and the strongest feasible combination in
   [Relic Trigger Feasibility](relic_trigger_feasibility.md).
5. Cover positive and negative trigger cases: unchanged repaint, wrong damage
   source, passive turn-start deaths, native Chain versus conduction, and
   first-use flags across preview, commit, and save/resume.
6. Run focused rules tests and the full suite. Inspect actual offers, card
   targeting, and board feedback at 1920×1080 and 100% UI scale.

`build_tags` remain developer metadata. They help audit compatible packages but
never substitute for exact player-facing rules text.
