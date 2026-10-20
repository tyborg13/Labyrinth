# int-04 — Scope the remaining cross-unit preservation pins (and sweep for the rest)

## Header
- Base: integration `e03fda6b9`, after the rr-27 merge.
- Godot passes. Python has 3 failures, all the pattern int-03 fixed elsewhere: a unit's test pins **other figures'**
  bytes in today's tree, so a later authorized unit breaks it. Log:
  `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/merge_rr-27_python.log`.
  - `test_rr20_cutout.HollowMimicTests.test_approved_inputs_and_prior_figures_are_byte_identical` and
    `test_director_residue_cleanup_preserves_sources_and_resolves_placeholder`.
    - Cause: `experiments/cutouts/hollow_mimic/gates.py` `protected_errors()` compares today's Thrall and Seer files
      against `protected_inputs.json`, with a hand-kept coverage ledger (`rr26_source_coverage.json`).
    - rr-27's authorized Thrall changes (layouts, continuation recipes) trip it.
  - `test_rr24_feedback2.Feedback2Tests.test_colour_rebuild_preserves_every_alpha_and_layout_field`: a layout hash
    changed (`fc840be5…` vs `3a25e4e3…`) by rr-27's authorized recipe edits.
- Owned: tests and preservation helpers only. No product, art, motion or record change.

## Change
1. **Scope these three to their own unit's history**, using the pattern int-03 applied: a pinned `base..unit_head` diff,
   like `experiments/cutouts/glacial_mirror/rr23_preservation.py` `protected_changes(..., end=UNIT_HEAD)`.
   - The Mimic gate still proves the Mimic unit touched no other figure. It stops policing today's tree.
   - Retire the coverage ledger if the range check makes it redundant.
   - For `test_colour_rebuild…`, keep what it really guards: alpha and every layout field the colour rebuild must not
     touch. Then either compare at rr-24's unit head, or exclude the fields later units are authorized to change.
     Pick whichever keeps the intent. Report why.
2. **Sweep.** Find every other test or gate that compares today's bytes of **another** unit's figure against a fixed
   pin. Search for `protected_inputs`, `baseline`, `byte_identical`, `prior_figures`, `every_other_figure`, pinned
   sha256 tables, and so on.
   - Convert each one to the same unit-scoped form.
   - List each: file, what it guarded, how it is scoped now.
   - Tests that pin **their own** figure stay as they are.
3. Mutation-test one converted check per pattern: inject a change to another figure inside that unit's own range. It
   must still be caught.

## Keep
- Assertion intent.
- Windows typed-array rule.

## Proof
- Focused tests first.
- Then both full suites once:
  - `python3 tools/godot_task_runner.py --task-id int-04 --timeout 1100 --stream -- godot --headless --script tests/run_tests.gd`
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
- Exact result lines.
