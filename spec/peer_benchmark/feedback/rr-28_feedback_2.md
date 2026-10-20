# rr-28 feedback 2 (director; Codex re-review of 569e385b5 requested changes)

All six coherent clip expansions are caught now. Recipes, texels and all 794 capture inputs still match `60cf6c5da`, so
the director's windowed proofs stay valid. Two validator gaps remain; fix both, validator and tests only.

1. **Medium: a missing evidence view bypasses validation.**
   - `rr28_build.py:68` skips layouts whose view is absent from the evidence definitions.
   - Removing the Seer's `rear` evidence section and appending `bolt` to every `rear.torso` layout passed: the builder
     wrote four files and kept the unsupported activation.
   - Validate every layout's recipes before writing anything, including recipes whose evidence view is missing. A
     missing view fails.
   - Add this exact regression.
2. **Low: the missing-clip guard has no test.**
   - Deleting the `expected - declared` comparison at `rr28_build.py:47` survived.
   - Add a regression: remove one declared clip from a multi-clip recipe while keeping its evidence. It must be
     rejected before any write.
3. Don't change recipe data or capture inputs. Focused tests only, plus the mutation table.
