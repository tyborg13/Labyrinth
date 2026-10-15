# Player-facing text style guide

Owner direction (2026-10-15): UI text must be "really clean and crisp and easy for players to understand"; tooltips
today are often too thin, too wordy, or missing (icons with no explanation). This guide governs every player-facing
string. The director writes and approves the text; implementers wire it from data and never invent wording.

## 1. Principles
1. **Say what happens, in game terms.** Effects first, in the order they resolve. No narration, no "this card", no
   "the player". Imperative present tense: "Deal 6 damage. Push 1."
2. **One concept, one name.** Every keyword, status, resource and icon has exactly one name, defined once in
   `data/glossary.json`. Text uses the name; it never re-explains it inline (the glossary panel does).
3. **Short beats complete.** If a rule needs more than the budget below, the mechanic belongs in a keyword with a
   glossary entry, not a longer sentence.
4. **Numbers are numerals** ("Deal 3 damage", "2 Time"), never words. Show the live value where the UI can compute it;
   otherwise the printed value.
5. **Every icon explains itself.** An icon that carries meaning has a glossary entry and a tooltip on every surface it
   appears on (hover, keyboard and controller focus).

## 2. Sentence patterns
| Situation | Pattern | Example |
| --- | --- | --- |
| Plain effect | Verb + amount + object. | "Deal 6 damage." |
| Several effects | Separate sentences, resolution order. | "Deal 4 damage. Chill 1." |
| Condition | `If <condition>: <effect>.` | "If the target is Chilled: deal 4 more damage." |
| Trigger (relics, statuses) | `<Trigger>, <effect>.` with a fixed trigger phrase (§3) | "At the start of combat, gain 3 Ward." |
| Choice | `Choose one: <A> or <B>.` | |
| Limit | Trailing clause after a comma. | "Draw 1 card, once per turn." |
| Cost | `Costs <n> <resource>.` only where cost isn't already shown by the UI. | |

Avoid: "will", "currently", "in order to", "allows you to", "you may" (use "can" only for real choices), parentheses for
rules, double negatives, stacked conditions (split into two sentences), and synonyms for defined keywords.

## 3. Fixed phrases
Use these exact trigger phrases (and no variants): "At the start of combat", "At the start of your turn", "At the end
of your turn", "When you play a <element/type> card", "When an enemy dies", "When you take damage", "When you move",
"The first time each combat", "Once per turn". Directions: "push" moves away from the source, "pull" toward it. Time is
the turn-clock resource: "costs 5 Time", "Wait" (capitalized keyword).

## 4. Budgets (hard limits; the audit flags overruns)
| Surface | Budget |
| --- | --- |
| Glossary definition (keyword, status, icon) | ≤ 20 words, one or two sentences |
| Relic description | ≤ 25 words |
| Card rules line (where cards use text) | ≤ 12 words per line, ≤ 3 lines |
| Status tooltip | definition ≤ 20 words + one live line ("3 stacks · 2 turns left") |
| Intent tooltip | ≤ 14 words: what the enemy will do and to which tiles |
| Event body | ≤ 60 words; each choice ≤ 10 words + its outcome line |
| Button / menu label | ≤ 3 words, Title Case |
| Flavour line (optional) | ≤ 12 words, italics, separate line, never inside a rules tooltip |

## 5. Tooltip structure
1. **Title**: the thing's name (Title Case), with its icon.
2. **Body**: the rules text per §2–4.
3. **Live line** (statuses, intents, resources): current values in the value style, e.g. "3 stacks · 2 turns left".
4. **Glossary panels**: one per keyword/icon in the body, in first-appearance order, at most 6 (the shared tooltip stack).
5. Flavour, if any, last and visually quieter.

## 6. Formatting
- Explicit keyword/term tokens (`@kw`, `@term`, including `|Form` inflections) use
  `InlineIconText.KEYWORD_COLOR`, backed by `UiPalette.GOLD_BRIGHT` (`#f0cf8a`), on cards, relics, events and inside
  glossary definitions. They inherit the host text's font, size and weight, with no underline. Existing glossary
  hover behaviour is retained. This shared token is the "existing keyword style"; retune its named constant in
  `scripts/inline_icon_text.gd`.
- Numbers that change with upgrades or modifiers use the value style; modified values keep the existing modifier
  marker.
- Element names are capitalized when they are keywords (Fire, Ice, Lightning, Air, Earth).
- Sentence case for body text; Title Case for names, buttons and headers; small caps only where the design system
  already uses them (section labels).

## 7. Process
1. The ux-02 audit inventories every string, icon and current definition (`spec/peer_benchmark/staged/text/`).
2. The director rewrites by surface into data (glossary, relic/card/status text, UI strings), following this guide.
3. Implementers wire the data and add the budget/coverage checks; a capture review at 1920×1080 by an independent judge
   checks readability before the owner sees it.
