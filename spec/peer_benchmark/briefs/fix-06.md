# fix-06 — Keyword tooltips list each keyword once

## Header
- **Why.** A charged card's tooltip stack lists a keyword twice. Charged Overhead Smash (Empower: `set stagger 4`) shows
  STAGGER with "Modified by: Empower +4" and a second, plain STAGGER. The action row carries the modified token, then
  `keyword_rows_for_card` re-emits the bonus as a plain token (`tokens_for_keyword_bonus`,
  `scripts/action_icon_library.gd` ~918-963). `_append_tooltip_entry` (~633) dedupes on icon + full tooltip text, and
  the "Modified by" suffix makes the two texts differ. Follow-up bonuses, relic, equipment and tempo modifiers hit the
  same path whenever a plain token with the same meaning also appears.
- **Base:** `codex/peer-benchmark`. **Risk tier:** low.
- **Owned:** `scripts/action_icon_library.gd` (tooltip stack building only), `tests/suites/tooltip_consistency_suite.gd`,
  `tests/suites/empower_seal_tooltip_suite.gd`. Don't grow `scripts/run_scene.gd`.

## Change (all decided)
1. **Identity of an entry** = icon key + the entry's *base* tooltip: the token's tooltip text without the
   "Modified by:" block (for keyword surface conditions, `token_tooltip` without modifiers). Time and Turns keep
   different base texts, so they stay two entries (Lantern Shot test).
2. **One entry per identity**, placed where the identity first occurs in reading order.
3. **Modified wins.** If any occurrence of an identity is modified, the single entry shows the base tooltip followed by
   "Modified by:" and the modifier lines of every modified occurrence, in reading order, identical lines once. The
   wording and line format of the modifier lines stay exactly as today (`_modifier_tooltip_lines`). An unmodified
   identity shows exactly what it shows today.
4. Entry fields (`icon`, `texture`, `title`, `description`, `tooltip`, `semantic_key`) keep their meaning;
   `semantic_key` becomes the identity above. Title and description are rebuilt from the final tooltip text with the
   existing `_tooltip_entry_copy`.
5. No other surface changes: single-token native tooltips (`token_tooltip` on card widgets, the board) are untouched.

## Tests
- Update `_test_card_tooltip_entries`: with the existing rows the keys become `["time","time","ranged","aoe","range"]`;
  the single RANGED entry carries "Modified by" and "Stormstring Bow"; the Turns entry is unchanged.
- New cases in `tooltip_consistency_suite.gd`:
  - plain then modified, and modified then plain, of the same identity → one entry, modified text, at the first
    position;
  - two different modifiers on the same identity (e.g. Empower +4 and a relic +1) → one entry listing both lines once
    each; the same modifier twice → listed once;
  - same icon, different base text (Time vs Turns) → two entries.
- `empower_seal_tooltip_suite.gd` (live, fixture `kwtest_empower_time`): after charging, the focus tooltip stack has
  exactly one STAGGER entry, and it contains "Modified by:" and "Empower". Add the same one-entry check for a card
  whose Follow-up modifies a keyword (pick a real card from `data/cards.json`; name it in the result).
- Mutation checks (report each): restore full-text dedupe → fails; keep the first (plain) entry instead of the modified
  one → fails; dedupe on icon only → the Time/Turns case fails.

## Proof
Focused: `tooltip_consistency_suite` (via `tests/run_tests.gd` program or its runner), `tests/empower_seal_tooltip_test.gd`,
`tests/card_keywords_test.gd`, `python3 tests/test_ui_identity_lint.py`. No full suites.
Under "Proof for the design owner", list the exact windowed command that shows the charged Overhead Smash focus
tooltip stack at 1920x1080 (an inspection fixture or visual probe) so the director can capture it.

## Out of scope
Tooltip visuals, wording, ordering rules other than above, the board or card-widget native tooltips.
