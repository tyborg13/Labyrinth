# meas-03 feedback 1 (from the Codex review of 2285dad8d)

The Skybolt tables reproduce exactly; the report stands. Two tooling fixes so future measurements are right:

1. **Medium: apply overrides before cost and keyword resolution.** `tools/encounter_measurement_engine.gd` ~28 applies
   overrides after standard card resolution, so Skybolt with `time: 9` plus Quicken 2 paid 9 where production would
   charge 7. Apply overrides to the card definition before progression/Tempo resolution. Regression: an overridden card
   pays exactly what an equivalent authored card pays in production (Quicken, Empower, Follow-up).
2. **Low: negative tests for the two unguarded checks** (`tests/test_skybolt_measurement.py` ~103): an altered hit
   count must be rejected by the counter-parity check, and a resume with mismatched override fields must be rejected,
   with the output left unchanged in both cases.

Don't re-run the full measurement. Re-run only the measurement tests and the registration audit.
