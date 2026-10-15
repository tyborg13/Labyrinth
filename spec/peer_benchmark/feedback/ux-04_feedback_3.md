# ux-04 — round 3 (Codex delta review of 4840e8503: one medium finding)

Work on top of 4840e8503. Do not commit. Full review: /private/tmp/labyrinth_codex/review/ux-04-4840e8503.md.

**Medium — Unicode whitespace still bypasses GDScript validation; previous finding 2 is only partially fixed.** [inline_token_syntax.gd:6](/private/tmp/labyrinth_codex/review/ux-04-4840e8503/scripts/inline_token_syntax.gd:6) uses `\s`, and lines 18–19 use `strip_edges()`, whose whitespace handling differs from [Python’s validator](/private/tmp/labyrinth_codex/review/ux-04-4840e8503/tests/text_budget_test.py:41).

Appending either snippet to Quick Stab, using actual U+00A0 characters (escapes shown for visibility), reproduces the mismatch:

- `@kw\u00A0(health)` renders literal markup.
- `@kw(health|\u00A0)` renders a blank keyword.

Fix: one token grammar with identical whitespace semantics in GDScript and Python (ASCII-only token syntax; any other whitespace or Unicode space inside a token is invalid and fails loudly in both); shared test vectors run by both validators. Proof: budgets, coverage suite, token rendering tests, full suite.
