# cbt-01 feedback 2 — delta review: one Low finding

Review: `spec/peer_benchmark/feedback/cbt-01_review_ef8a46144.md`. Add the reviewer's behavioural regression to the
committed suite.
- Steps: keyboard-target Stay → cancel the card → reselect it.
- Assert that the rendered cursor does not come back without a new keypress, and that keyboard ownership is clean.
- Removing the cleanup at `run_scene.gd:31994` must then fail the focused suite.
- No production change unless the regression exposes one.

Re-run the focused suites only; the full suites aren't needed for a test-only change.
