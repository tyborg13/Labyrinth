# map-01 feedback 2 — integration with ev-01 (already merged into this worktree at bff5a2385)

After merging codex/peer-benchmark (event engine ev-01) into map-01, `tests/event_rules_test.gd` fails 1 check:
`_persistence_and_rewards` → "Legacy Cartographer choice ids remain accepted" — on a revision-4 map every room in
sections I–V is already revealed, so the `reveal` effect has nothing to reveal and the survey choice is unavailable.

Decision (ownership of `scripts/event_rules.gd` reveal effect + its preview/outcome strings and
`tests/suites/event_rules_suite.gd` granted for this):
1. On revision-4 layouts, the `reveal{hops}` effect SCOUTS mystery rooms instead: every unentered, unscouted mystery
   room among the current room's descendants within `hops` in the current section gets `scouted: true` (exactly as a
   Scout use does, without spending Scouts). In Section VI (fogged) it keeps the legacy reveal behaviour AND scouts any
   mystery rooms it reveals. Older layouts: unchanged.
2. Availability: a choice whose only effect is `reveal` is unavailable when nothing would change ("Nothing new to
   reveal." unchanged).
3. Strings on revision-4 layouts (I–V): preview "Reveal what the unknown rooms up to N rooms ahead hold."; result row
   "Revealed N unknown rooms." (singular "Revealed 1 unknown room."). Section VI and older layouts keep today's strings.
4. Fix the test fixtures so the Cartographer survey path is exercised with at least one mystery room in range on a
   revision-4 map, and keep a legacy-layout fixture for the old behaviour.
Rerun: event_rules suite, section_map v2 + section_map suites, dragon_boss, full suite.
