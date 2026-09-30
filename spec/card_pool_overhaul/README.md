# Card pool overhaul

Owning design record for the 305-card pool rework (proposal published 2026-09-30).

- `pool_data.py` is the authored source: every live card's verdict (keep, tweak, rework,
  moved, new, cut), full rules text, rarity, Time and design note, plus the 72 gear pieces.
- `proposal.json` is the generated snapshot (with each changed card's previous text) that
  implementation waves are checked against.

Implementation lands in waves: (1) data-only clean-up plus the forced-movement rule,
(2) Stagger, Follow-up, Empower, (3) Retaliate, Quicken, Rite, (4) bespoke rule families and
boss remixes. Rules that ship are documented in their owning specs
([forced movement](../forced_movement.md), [card balance heuristic](../card_balance_heuristic.md)).
