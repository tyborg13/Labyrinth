# mq-12 — feedback 3 (Codex re-review of 852a7320f: one blocker; round cap reached after this)

Fix only the blocker below, with the concrete fix the review names: an exact, hash-bound successor receipt that
authorizes exactly these two mq-12 delivery trees in mq-11's preservation checks, keeping the historical inventory and
strict rejection of any other or later edit. Run tests.test_mq11_accessories (PYTHONPATH=tests) plus the focused mq-12
and mq-09 tests. No other changes.

## Review
**Blocking — mq-12 breaks mq-11’s preservation workflow and tests.** [preservation.py:37](/private/tmp/labyrinth_codex/review/mq-12-852a7320f/spec/art_identity/maquettes/hollow_mimic/owner_review/preservation.py:37) compares every live delivery against its immutable historical inventory. The approved Herald/Gloam replacements now make this fail, blocking [workflow preparation:48](/private/tmp/labyrinth_codex/review/mq-12-852a7320f/spec/art_identity/maquettes/hollow_mimic/owner_review/workflow.py:48).

Reproduction: `PYTHONPATH=tests python3 -B -m unittest tests.test_mq11_accessories` produces two errors and two failing subtests at lines 107, 313 and 329. Restoring **only** Herald/Gloam’s pre-mq12 delivery hashes in memory makes all three affected tests pass.

**Concrete fix:** add an exact, hash-bound successor receipt authorizing these two mq-12 delivery trees in mq-11’s preservation checks. Retain the historical inventory and strict rejection of unrelated or subsequent edits.

All three Round 1 findings are resolved:

- **Inventories:** mq-09 checks pass. Independent comparisons protect all eight other compiled specs and their 791 delivery files.
- **Motion:** `shifted = points.copy()` and near-side protection `0 → 1` are **caught in all four modes**, each producing a 0.2 m audit error.
- **Curation:** both trees pass verification exported from `git archive HEAD`; all 20 previously missing receipts are committed. Both remain below 6 MB.

The broader review covered the shared compiler/build/cloth/cache/pose changes, proof tools, deliveries and preservation tests. All 70 deleted files have matching archived hashes. No GDScript changed; Windows typed-array compatibility is inapplicable. No additional scope, dead-code, stray-file or gameplay-tunable concerns found.

Verification: 33 focused tests and 111 art-identity tests pass. The broader Python run executes 266 tests with the blocker above and two Blender skips. All **27 review mutations were caught; zero survived**. Blender regeneration was unavailable; current source inventories, recorded geometry/capture hashes and fresh Python fit measurements check out. The unrelated Godot-driven suite was stopped and excluded from these counts. All mutations were restored; checkout is clean.

CHANGES REQUESTED