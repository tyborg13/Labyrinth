# en-06 feedback 1 (director)

Native captures reviewed (copies: /Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/en-06/).
Mechanics and telegraphs read well.

## Fix
1. **Float numbers**: the capacitor's intent number shows "1.0" (Charge) and "6.0" (Discharge) in the intent pill above
   its health bar. All intent/badge numbers are integers ("+1", "6"). Check the same path for the mimic and any other
   intent whose amount comes from a computed float.

## Decisions (replace every TODO_DESIGN)
2. Charge pips: 4 px gap between pips; the pip row is centred 10 px above the top of the health-bar frame.
3. Discharge ties (non-hero): among equally near candidates, prefer the hero; then the lowest current HP; then the
   lowest tile y, then x (deterministic). Same rule for each jump.
4. Mirror — special target shapes: if the copied card's targeting isn't a direct attack shape (single target, line,
   or pattern area — e.g. self-target, chain, summon, blink, push/pull-only, surface-only), the mimic still mirrors the
   card's base damage but as a single-target ranged hit at range 4 named "Mirror: <card>" (Shade Bolt geometry).
5. Mirror — multiple damaging actions: copy only the first damaging action (its damage and shape); the name stays
   "Mirror: <card>".

## Proof
- Suites green; re-capture 01/02 (integer numbers); list the windowed command again.
