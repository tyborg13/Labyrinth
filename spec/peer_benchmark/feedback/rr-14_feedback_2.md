# rr-14 feedback 2 — one test gap (test-only)

The narrow re-review of 2a644fe44 confirmed all four production fixes and found one Low gap:

- `tests/rr14/runtime_checks.gd` ~line 37 always exits nonzero on the invalid-policy path, and the empty-pose check at
  ~line 170 records a failure that this path never reports. Replacing the rejection `return {}` at
  `humanoid_motion.gd` ~86 with `pass` survives all 21 rr14 tests.
- Fix: emit an explicit rejection result (e.g. a distinct `RR14 KNEE POLICY REJECTED: <case>` line or a JSON result)
  and assert it in Python independently of the expected nonzero exit. The mutation above must then fail.

Change tests only: no production code, case data or binding inputs (the director's windowed Seer proof is running on
2a644fe44). Run the rr14 tests and the mutation; no full suites.
