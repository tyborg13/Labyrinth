# en-05 feedback 1 (director)

Decisions for every TODO_DESIGN (replace each placeholder; update the spec, tests and preview to match).

1. **TODO_DESIGN_DIVE_SIDE_DIRECTION**: every unit the shrike passes is pushed 1 tile to the dive's RIGHT-hand side:
   rotate the dive direction 90° clockwise on the board grid (x right, y down: direction (dx, dy) → side (−dy, dx)).
   This applies whether or not the shrike was already aligned. If that tile is blocked or impassable, the normal
   collision rules apply (no fallback to the other side). The side-push preview shows this exact tile.
2. **TODO_DESIGN_DIVE_HERO_SIDE_PUSH**: the hero is never side-pushed by Dive. Only units strictly between the shrike's
   start tile and the hero are pushed. The hero takes 4 air damage when the shrike lands adjacent.
3. **TODO_DESIGN_DIVE_BLOCKED_LANDING**: if the landing tile (the path tile before the hero) is still occupied after
   the pushes resolve (e.g. a collision kept a unit there), the shrike stops on the last free path tile before it and
   the hero takes no damage. The telegraph shows this outcome (threat tiles end at the stop tile; no damage on the hero).
4. **TODO_DESIGN_DIVE_TOOLTIP**: "Dive: flies straight at you (up to 4 tiles), knocking each unit it passes 1 tile
   aside, then strikes for 4." (numbers from data, as in other tooltips).
5. **TODO_DESIGN_FLYING_TOOLTIP**: "Flying: moves over traps, surfaces, Bramble and Ice Pillars and takes no surface
   damage. Can still be pushed."

Art note: both sprites will be replaced by the visual identity gate re-art (art-02); do not touch the art now.

## Proof
- Suite cases for 1–3 (aligned and unaligned dives; blocked side tile; blocked landing), tooltip strings; suites green.
- Re-capture the dive telegraph at rest and after the dive; list the windowed command.
