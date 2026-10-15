# ux-04 — round 1 (director decisions for the two TODO_DESIGN items)

Work on top of the current uncommitted state. Do not commit.

1. **`TODO_DESIGN_KEYWORD_STYLE`**: keyword/term tokens (`@kw`, `@term`) render in `UiPalette.GOLD_BRIGHT` (#f0cf8a),
   same font, size and weight as the host text, no underline — on cards, relic text, event text and inside glossary
   definitions (the style guide's "existing keyword style" now means this token). Hover behaviour unchanged. Put the
   colour behind one named style constant so it can be retuned in one place. Update `spec/text_style_guide.md` to name it.
2. **`TODO_DESIGN_GRAFTWRIGHT_DONOR_VERB`**: the result line reads `"<Item> destroyed"` (e.g. "Iron Gauntlet destroyed").
3. Re-run budgets, glossary tests, text probe logic and the full suite; list the two windowed proof commands again.
