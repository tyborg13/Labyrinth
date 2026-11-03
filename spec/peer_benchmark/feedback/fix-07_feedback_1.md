# fix-07 feedback 1

Good. Two items:

1. **Scorer: Petrify's Block is now part of the keyword, and the card's score must stay 2.47.** Decision: the scorer and
   its spec own this too. In `tools/card_heuristic.py` (~1168-1171) a `petrify` action without a `block` field uses a
   scorer constant `PETRIFY_BLOCK = 5` (an explicit `block` still wins, for future variants). Add a Python test that
   reads `PETRIFY_BLOCK` from `scripts/maneuver_rules.gd` and asserts it equals the scorer's constant, so they can't
   drift. Update the Petrify line in `spec/card_balance_heuristic.md` (~835) to say the 5 Block is built into the keyword.
   Report the petrify score (must be 2.47) and run the existing heuristic tests.
2. **Name the probe by what it shows**, not the unit: `tests/fix_07_probe.gd` → `tests/petrify_card_probe.gd`,
   `tests/proof_contracts/fix_07.json` → `tests/proof_contracts/petrify_card.json`, captures under
   `user://petrify_card_probe/`. Update references; give me the updated windowed command.

Re-run only the heuristic tests, the new consistency test and the probe's headless contract check. No full suites.
