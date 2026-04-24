<!-- memento:managed -->
## Memento

This repo uses `memento` for code-scoped project memory.

- Before substantive code changes, run `memento brief <paths>` for the files or folders you expect to touch.
- After substantive code changes, record only durable, non-obvious learnings with `memento record ...` when future sessions would benefit.
- Use `shared` for committed repo truth and `local` for private, machine-specific, branch-specific, or temporary notes.
- Supersede or obsolete stale notes instead of adding contradictory duplicates.
- Memento state lives under `.codex/memento/`.
<!-- /memento:managed -->

## GDScript Typed Arrays

- Godot on Windows has caught typed-array assignments that may pass on macOS. When assigning to `Array[T]`, do not rely on bare array literals or conditional-expression branches like `[value] if condition else typed_array`; build the value through a typed helper such as `_vector2i_array(...)` or an explicitly typed temporary first.
- For fallbacks passed into typed-array helpers, keep using plain `[]` only as input to the helper. The typed local should receive the helper result, not the raw literal.

## Card Balance Heuristic

- When creating or modifying cards, consult `spec/card_balance_heuristic.md`.
- Run `python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown` for touched cards and `python3 tools/card_heuristic.py` when comparing against the full pool.
- Treat the heuristic as the default curve check for card work, then call out any deliberate deviations from curve in your notes or review context.
- When combat mechanics or encounter assumptions change, update both `spec/card_balance_heuristic.md` and `tools/card_heuristic.py` in the same change.
- Revisit the heuristic whenever changes touch `scripts/combat_engine.gd`, `scripts/room_generator.gd`, `data/enemies.json`, fatigue rules, cards/draw per turn, status semantics, multi-target behavior, or new action keywords.

## Analytics

- When changing reward flow, draw rules, card play flow, combat outcome flow, or status timing, consult `spec/analytics.md`.
- Keep analytics local-first and append-only unless the task explicitly adds remote upload.
- Preserve the JSONL event contract in `scripts/analytics_store.gd`; prefer additive schema changes over renaming or deleting fields.
- If combat or reward mechanics change, update both the instrumentation and `spec/analytics.md` in the same change so card-balance analysis keeps matching live behavior.
