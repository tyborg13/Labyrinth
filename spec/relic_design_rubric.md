# Relic Design Rubric

Current rules: relic pool overhaul, 2026-10-02 (100 live relics: 88 offered and
12 guardian or boss trophies). The authored record, verdicts and rationale are in
[the relic pool overhaul](relic_pool_overhaul/README.md). The shared-ground rules
remain [Board Surface Refactor](board_surface_refactor/DESIGN.md).

Relics change what a player can do with a deck and board. Some provide a simple,
readable benefit; others change targeting, movement, terrain, or consumption.
Do not force the entire roster into one hybrid-element template.

## Rarity Ladder

Relics added or rewritten in the overhaul record `design_version: 4`; kept relics
retain 3. Every relic records `condition_tier`, `upside_tier`, and at least two
`build_tags`.

| Rarity | Condition tier | Expected setup | Expected payoff |
| --- | ---: | --- | --- |
| Common | 1 | One visible trait, local board condition, or easy turn event | A small modifier or a useful positioning rule |
| Rare | 2 | Prepared terrain, a defense-to-attack sequence, status, or a local consumption choice | A meaningful conversion or a new tactical option |
| Epic | 3 | Cross-card sequencing, risk, or a demanding board arrangement | A turn-shaping payoff or a substantial change to an action |
| Legendary | 4 | A developed terrain route, layered consumption, Defiance, or a demanding card sequence | A rule or payoff that can define the run without free repetition |

Relic offer weights are common 10, rare 8, epic 6, and legendary 5; over 300 seeds a typical route passes about 5.4 treasure rooms, and 82% of typical runs see at least one legendary offer.

## Intrinsic and Extrinsic Value

Every relic is worth something on its own (intrinsic) and grows with the deck
that supports it (extrinsic). The rarer the relic, the more of its value is
extrinsic and the larger the payoff: commons work in almost any deck, while
legendaries change a rule and need a developed card package. The authored record
scores both axes from 0 to 3; the intrinsic share is about 58% for commons, 26%
for rares, 20% for epics and 16% for legendaries.

Relics pay off card packages, alone or in combination, in non-linear ways. Use
six shapes: Transform (change what an action does), Convert (turn one resource or
event into another), Bridge (link two packages), Amplify (raise a package's
payoff), Setup (create a condition other cards use) and Engine (a persistent rule
that compounds). Avoid flat "if X, gain Y" triggers.

Relics add no bespoke controls: every effect is automatic or uses the existing
targeting, movement and Empower controls. Downsides stay rare; risk and reward
belong to events.

Rarity is not a flat efficiency multiplier. A persistent rule can be valuable
because the player must build its board conditions on each encounter. It does
not need a new meter, an arbitrary card-count requirement, or a larger number.

## Effect Architecture

- Prefer reusable effects over relic-ID branches. Use `SurfaceRelicRules` for
  optional transformations and event-scoped terrain rewards. Overhaul families
  live in focused helpers called from small engine hooks:
  `forced_relic_rules.gd`, `tempo_relic_rules.gd`, `common_relic_rules.gd`,
  `defense_relic_rules.gd`, `illusion_relic_rules.gd`,
  `surface_variety_relic_rules.gd` and `item_relic_rules.gd`.
- A cut relic keeps its entry with `retired: true` and a `replacement_id`. Saves,
  profiles, gifts and pending offers migrate to the replacement; offers and
  inspection loadouts never use a retired ID.
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
