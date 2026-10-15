# chr-02 — fix round 4 (peer re-review of 526e3c6cc: one change requested)

Everything else in 526e3c6cc is verified (save size, boot time, tooltip placement, focus ring, 718 px layout,
deleted-card backs). One performance regression remains, plus two small test gaps.

## 1. Normalization rebuilds every stored card delta (Medium) — fix by simplifying
`ChronicleRules.normalized_record` calls `card_definition_delta` for each stored `deck_card_definitions` entry, which
recomputes `GameData.card_def_for_progression(id, {})` and walks both definitions. It runs on every profile load and
save. With card-modifying relics, normalizing 50 records costs 12.7 ms (leaden_pommel + tailwind_fletching, 5 changed
cards per record) and 85.4 ms (crown_of_surplus, 42 per record), against 1.0 ms with no relics. Your 1.24 ms figure
used a history with no stored definitions.

Decision: `deck_card_definitions` exists only since chr-02, and full snapshots were written only by the unlanded first
commit 636adaa8b, so no real profile holds them. **Normalization must not rebuild deltas.** For each deck id whose stored
value is a non-empty Dictionary, keep `_public_card_value(value)` (strips `_` keys, ints to floats); drop entries for
ids not in the deck, non-Dictionary values and empty dictionaries. Do not call `card_definition_delta` or GameData card
lookups from `normalized_record`. Saving at run end (`deck_card_definitions(state)`) keeps computing deltas as now.
Update the comment above `card_definition_delta` (it no longer needs to resolve "older full snapshots").

## 2. Tests
- `tests/chronicle_performance.gd`: add a relic-heavy history — 50 records, each with crown_of_surplus plus
  leaden_pommel and a 45-card deck whose stored definitions come from `deck_card_definitions` on a real state with those
  relics. Assert normalization median ≤ 5 ms for it (the no-relic case stays ≤ 5 ms too) and report both numbers.
- Regression: a record saved with relic-modified cards, normalized, then resolved through `card_definition` must equal
  the printed definitions (no `_` keys) for every deck card.
- Focus tooltip: add a case whose preview is too large for every side, so the last-resort placement is exercised
  (currently a mutant there survives). Assert it stays on screen.

## Proof
Chronicle test, performance harness numbers (both histories), UI lint, full suite. No windowed rerun needed unless the
layout changes (it should not).
