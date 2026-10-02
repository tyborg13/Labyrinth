# Relic pool overhaul

Owning design record for the 100-relic pool (proposal reviewed 2026-10-02).

- `relic_data.py` is the authored source: every relic's verdict (keep, tweak, rework, new,
  cut), final rules text, rarity, shape, packages, intrinsic and extrinsic scores, combos
  and design note, plus the twelve cuts with their save replacements and the builds the
  relics support.
- `proposal.json` is the generated snapshot the implementation is checked against.

Review decisions: no relic needs a bespoke control (six designs were reworked so their
effects are automatic or use existing targeting, movement and Empower controls); The
Breaking Wheel keeps its Freeze; relic offer weights are common 10, rare 8, epic 6,
legendary 5. Over 300 seeds a typical route passes about 5.4 treasure rooms (a
treasure-seeking route about 9.4); with these weights 82% of typical runs see at least one
legendary offer.

## Implementation

All 100 relics are live in `data/relics.json`. Each family's runtime rules live in a
focused helper module called from small hooks in `combat_engine.gd`, `game_data.gd`
and `run_scene.gd`:

| Family | Module | Rules record |
| --- | --- | --- |
| Commons | `scripts/common_relic_rules.gd` | [u2_common_effects.md](u2_common_effects.md) |
| Forced movement | `scripts/forced_relic_rules.gd` | [forced movement](../forced_movement.md) |
| Tempo | `scripts/tempo_relic_rules.gd` | [wave-3 keywords](../card_keywords_wave3.md) |
| Defense, Rites, Exhaust | `scripts/defense_relic_rules.gd` | [wave-3 keywords](../card_keywords_wave3.md) |
| Illusions, Lightning | `scripts/illusion_relic_rules.gd` | [illusions and terrain](../card_mechanics_illusions_terrain.md) |
| Surfaces, variety, movement | `scripts/surface_variety_relic_rules.gd` | [u7_runtime.md](u7_runtime.md) |
| Items | `scripts/item_relic_rules.gd` | [item relic rules](../item_relic_rules.md) |

Each family has a focused suite, `tests/suites/relic_u2_suite.gd` through
`relic_u8_suite.gd` (wrappers `tests/relic_u*_test.gd`, registered in
`tests/run_tests.gd`), and a 1920x1080 visual probe `tests/relic_u*_probe.gd`.
`tests/suites/relic_u1_suite.gd` covers the pool composition, the authored copy,
retired-ID migration and the offer weights.

Bonded Set reads an `element` field on equipment. A piece has one when every
elemental card it grants shares that element (24 pieces); the rest are neutral.

Rules that ship are documented in the [relic design rubric](../relic_design_rubric.md)
and [trigger feasibility](../relic_trigger_feasibility.md) specs.
