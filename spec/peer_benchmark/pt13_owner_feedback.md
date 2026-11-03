# Playtest 13: owner feedback (2026-10-26, in chat, while playing 831d3c185)

Owner notes in the order received, each with the director's diagnosis and the resulting unit.

1. **"the sun dial relic needs a rework, it's way too complicated."**
   - This is the Black Sun Dial (legendary): a store-and-release meter with four per-ground riders, counting nearly
     every ground removal.
   - Decision: "Each ground tile you Expend gives your next attack +3 damage (up to +9)", built on the existing
     next-attack primitive.
   - Unit: pt13-01.
2. **"the enemy action indicator at their feet can become way too disconnected from deconfliction logic such that its
   not clear who it actually belongs to"** (screenshot).
   - Cause: an unbounded viewport search in `IntentChipPlacement.find_clear`, plus unit and prop rects counted as
     obstacles.
   - Decision: chips avoid only HUD, slide at most 24 px, and otherwise stay at their spot and draw on top.
   - Unit: pt13-02.
3. **"The keeping gear on death UI is horrific. Needs to be more visual, needs some pizazz, and also needs to not
   offer to keep starting gear since you'll have that on the next run automatically anyway."**
   - Today it is a plain dialogue with text option buttons.
   - The director mocks up a visual screen (boon-screen language, gear as large painted cards, a ceremony on choice,
     starter gear excluded, the prompt skipped when only starter gear is equipped). It goes to the inbox for approval
     before the build.
4. **"glacial mirror enemy doesn't quite look like he's realistically standing on the square."**
   - The painting has a wide stride (the far foot 45 source px above the near foot), and the floor anchor
     (127, 231.46) sits near the near foot.
   - The true standing point (the midpoint of the two soles) is about (122, 222), so the golem renders about 9 source
     px high.
   - Decision: register at the two-sole midpoint (front and rear), with four-facing before/after captures.
   - Unit: pt13-06.
5. **Graftwright "Complete three combats first" is a brickwall.**
   - The map already guarantees at least 3 fights on every route before it. The runtime counter ignores mystery rooms
     that turned into fights, so the two disagree.
   - Decision: remove the runtime gate and keep the map placement rule.
   - Unit: pt13-01.
6. **"Ironshod Sabatons has some sort of a text/icon sizing bug... make sure every card is always legible."**
   - Equipment tooltips draw cards at 0.72 scale (rules text about 11.5 px, below the 14 px floor). Iron Wheel and
     Headlong shrink further, cause unknown.
   - Decision: an audit of every card in every context against a 14 px text / 16 px icon floor; equipment previews at
     224 px; no self-shrink below the floor; find the Sabatons' root cause.
   - Unit: pt13-03.
7. **"Damage previews aren't working on boss HP bars like they do for regular enemies."**
   - The boss overlay has its own static ColorRect fed from the same preview maps; the cause is not yet known.
   - Decision: reproduce and find the root cause, then match the regular bars' pulsing amber/red look from one shared
     place.
   - Unit: pt13-04.
8. **"we used to have nice animated flames for our column torches... the fire room now has largely static images."**
   - Measured: all six biome light idle sheets are nearly frozen (0.04–3.25% change per step against the stone
     torch's 11%).
   - Decision: a data-driven generator animates each biome's painting with per-element motion.
   - Unit: pt13-05.

The launches of pt13-01..05 are held while the owner plays (memory: hold heavy jobs while the owner plays).
