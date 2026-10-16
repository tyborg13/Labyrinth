# int-02 — round 1 (integration Python failures)

1. Merge the integration branch (now includes the director's glossary fix 'Character' copy within budget —
   text_budget_test passes there) into codex/int-02.
2. Fix the demo-recording tests that fail on integration: `test_reviewed_weaver_pairs_report_presentation_exemptions`
   (ERROR: events[6] offset +47 not exempted) and `test_weaver_exemptions_survive_record_compare_and_encode_reports`.
   Cause: the reviewed Weaver exemptions are bound to live source fingerprints that changed when unrelated units merged.
   The portable tests must use committed fixture fingerprints (and the production exemption check must keep binding to
   the exact reviewed sources — when those sources really change, re-recording/re-review is required, which is fine).
   Do not weaken the exemption guard itself.
3. Full Python discovery and the full Godot suite must both PASS. Then list the windowed command (already given).
Do not commit.
