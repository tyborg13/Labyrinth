# Surface v5 save and guided-opening compatibility

The persistence contract is in ../save_persistence.md. The v4 upgrade preserves
paid resources, actual HP and defenses, active Chilled, all piles, RNG/initiative,
the exact event tail, source metadata and deduplication watermarks. New copies of
electrical conditions use conduction; already-resolved enemy payments are not
replayed. Ion Spool's turn claim follows the renamed effect. Untagged historical
events retain a board-level v4 provenance fallback; new events carry v5 directly.

The guided opening is authored at 12 target HP for Pale Spark 3 + Quick Stab 9.
Only an untouched v1/v2 opening target is adjusted. A partly paid older opening
keeps its real remaining HP and completed milestones and releases the obsolete
scripted-kill gate. It neither heals the target, replays paid actions nor awards
a fake kill. The tutorial progress schema remains version 2 so existing
milestones do not reset when the scenario becomes version 3.

Focused checks passed:

- `tests/surface_save_migration_test.gd`: v4 status/event/payment preservation,
  copied conditions, Ion Spool claims, idempotence, byte-exact archives and
  conflicting-archive refusal, plus old/new event provenance.
- `tests/surface_parent_review_test.gd`: actual RunScene merge of a paid legacy
  opening releases the obsolete gate even if the separate profile is active.
- `tests/contextual_combat_tutorial_test.gd` and the guided integration suite:
  current milestones and ordinary 12 → 9 → 0 damage/payment flow.
- `tests/contextual_combat_tutorial_probe.gd`: **22 native assertions passed**
  at 1920×1080 and 100% UI scale. The Pale Spark 3, final Quick Stab 9 and actual
  kill-refund frames were inspected; the probe completes the full curriculum.

Proof is retained under
`output/board-surface-refactor/feedback-pass/migration/`. The final focused
provenance check is `surface-save-migration-provenance.log`; native proof is
`guided-native-01.json` with copied frames in `guided-native/`. The probe's
historical filename/directory labels mentioning Bone Dart or v4 are retained for
contract stability; the captured card, rules and scenario are current.
