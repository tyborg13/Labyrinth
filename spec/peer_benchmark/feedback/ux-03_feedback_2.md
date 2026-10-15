# ux-03 feedback 2 (director)

TODO_DESIGN_GLOSSARY_CHOICE_OVERFLOW → decision:
- **Below-row placement flows horizontally**: glossary panels sit in rows of up to 3 panels side by side (each at its
  normal width, 12 px gaps), the block centred under the hovered card (clamped to the screen with a 24 px margin), rows
  stacked downward with 12 px gaps, first-appearance order left-to-right, top-to-bottom.
- **Outer-side placement** keeps a single column; if that column would cross the screen's bottom margin (24 px), use the
  below-row flow instead.
- If even the flowed block would cross the bottom margin, reduce to 2 rows by placing up to 4 panels per row (narrower
  screens); assert in the probe that every current relic's stack fits at 1920×1080 for all three card positions.
Keep everything else. Do not commit. Then run the probe headless-logic and list the windowed command.
