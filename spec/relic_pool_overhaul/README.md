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

Rules that ship are documented in the relic design rubric and trigger feasibility specs.
