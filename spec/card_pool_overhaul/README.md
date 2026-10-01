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

Status: all four waves are applied (`apply_pool.py --wave 4`, idempotent): 305 live cards
and 72 gear pieces. Wave-4 data contract notes: Mirror Feint, Reflected Threat and Empty
Husk are pure illusion cards and drop their `role_emblem` overrides; Hall of Mirrors
(illusion over Block) and Gale Ward (block over a damage-free shove) author theirs. Flash
Powder's text states its radius-2 Expose area inside the radius-3 Light. Rules text names
the implemented limits (Worldbreak: an outcrop you raised; Changing Winds: one-tile
enemies; Petrify: not dragons; Empty Husk: Block becomes the husk's extra health).
Earlier status: waves 1-3 gave 246 live cards and 61 gear pieces. Wave-3 data contract notes: Undertaker Stand needs no `role_emblem`
override (Block + Retaliate already reads as defense), and Rite of the Pyre's
`surface_damage_bonus` carries `"owner": "player"` so it boosts only the hero's Fire
("your Fire tiles"). Real-card coverage lives in `tests/suites/card_pool_overhaul_suite.gd`.
