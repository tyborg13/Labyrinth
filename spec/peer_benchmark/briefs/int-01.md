# int-01 — Integration fix: event view stays open after Continue on the merged branch

## Header
- Goal: on `codex/peer-benchmark` at e1032c6e9 (ev-01 + ev-02 + feel-01 + biome-01 + map-01 merged) the event view
  suite fails 1 check: `tests/suites/event_view_suite.gd` `_integration` → "Event closes after Continue" (after
  choosing Moth-Eaten Library "search" and pressing Continue, mode becomes `reward` with the event card choice, but
  the EventView stays visible). It passed on codex/ev-02 before the map-01 merge (map-01 changed run_engine room entry
  dispatch for mystery rooms, section_map_* presentation and combat_board_view door emblems).
- Base: `codex/peer-benchmark` (current HEAD e1032c6e9).
- Owned files: whatever the root cause requires, minimal; `tests/suites/event_view_suite.gd` only if the test itself is
  wrong (explain why).
- Rules: find and state the root cause first; add a regression check that fails before and passes after; no
  behaviour changes beyond the fix; Windows typed-array rule.
- Contract: risk tier standard. Acceptance: event_view suite 0 failures; event_rules, section_map v2, section_map,
  full suite pass.

## Proof
- Root cause written in the result.
- Suites listed above green.
