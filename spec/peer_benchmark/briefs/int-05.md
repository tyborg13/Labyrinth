# int-05 — Scope the last re-pinned cross-unit identity pins

## Header
- Base: integration HEAD (after the rr-28 and cap-02 post-merge repairs).
- The full Python suite fails 9 subtests of
  `tests/test_rr14_seer_identity.py::test_approved_assets_layouts_compiled_motion_and_samples_are_byte_identical`.
- That test is rr-14's guard ("rr-14 changed nothing in the approved Seer"). It pins the Seer's files in **today's
  tree**, so every authorized Seer change breaks it:
  - int-03 re-pinned it for rr-26;
  - rr-28 broke it again.
- int-04's sweep missed it because the re-pin made it look like an own-figure pin.
- Owned: tests and preservation helpers only.

## Change
1. Convert `test_rr14_seer_identity` to the int-04 form:
   - rr-14's own commit range, base `merge-base(e08e4e296^1, e08e4e296^2)` to unit head `5a97e2b28`, must not change
     any listed Seer file;
   - the binding-only files may change only in their `inputs` object.
   - Use `experiments/cutouts/hollow_mimic/rr20_preservation.py`-style range helpers, or a shared one if int-04 left
     one.
   - Remove the today's-tree pins.
2. **Sweep again, this time for re-pinned guards.** Find every test that pins another unit's figure files by hash
   whose expected values were later updated (git log the pin file), and convert each the same way. List them.
3. Mutation-test one converted check: inject a Seer change inside rr-14's range and it must be caught.
4. Focused tests, then both full suites once. Report the result lines.
