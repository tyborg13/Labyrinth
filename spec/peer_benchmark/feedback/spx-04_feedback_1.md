# spx-04 feedback 1 (director: native order frames judged; three decisions)

The windowed probe passed (7 captures; sheet at
`/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/spx-04/sheet_round0.png`). Barrage's two
plus-shapes, the held wind's slide previews, the Oracle's five-pillar wall, the Dynamo's lowered threshold and the
Prior's veil and reveal all read clearly.

1. **High: the Thornmother's order isn't telegraphed.** `earth_telegraph.png` shows her banner zone but nothing marks
   where the 5-tile Thornwall will rise. Every order must show before it can hurt you.
   - When her intent is Thornwall, preview the exact tiles the brambles will grow on, in the existing marked-intent
     tile style other telegraphed intents use. Keep it consistent with the rest of the board's telegraph language, and
     use no new colour literal.
   - The preview must match where they actually grow, including the 5-tile length and the legal-tile trimming.
   - Re-capture `earth_telegraph.png` with it visible, and add a headless assertion that the preview equals the grown
     tiles.
2. **`TODO_DESIGN_PERSISTENT_WIND_LABEL`, decided:** the chip title reads `Wind · held`. Its tooltip appends a line:
   `Held by the Stormcaller until it falls.`
3. **`TODO_DESIGN_THORNWALL_EQUIDISTANT_CENTER_TIE`, decided:** among equally distant legal centres, prefer the one
   nearest the player, then the one nearest the Thornmother, then the existing scan order.
4. **`TODO_DESIGN_DIAGONAL_ORDER_AXIS`, decided:** keep the existing projection onto the line's dominant cardinal
   axis. On an exact diagonal (|dx| == |dy|), use the x axis. This applies to both Barrage's side and the Oracle's
   wall orientation.
5. Focused tests only. The director re-runs the windowed probe.
