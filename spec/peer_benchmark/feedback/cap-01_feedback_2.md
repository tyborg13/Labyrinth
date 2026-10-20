# cap-01 feedback 2 (director; windowed run of 126a567c3)

The `before` capture completed for both rigs: Seer 1,440 production frames, Mortar 1,515. It sits under
`/tmp/cap01-proof/before/`. Then `validate` stopped the run. Two tool defects:

1. **Production inventories can't demand exact headless frame counts.**
   - `capture_inventory.validate` expected Seer front `hit: 80` and got 79.
   - Windowed production capture runs in real time, so a clip can land a frame more or less.
   - Validate completeness from the capture itself:
     - every clip present;
     - its phases span 0 to 1;
     - every contact phase the case data names is present;
     - the manifest has no errors.
   - Report counts, but don't require them to equal a table.
   - **Equivalence for production:**
     - match before and after frames on (view, stage, phase);
     - every matched frame's pixel hash must be identical;
     - each clip's unmatched frames are at most 2 per side; list them;
     - the gate verdicts and errors must be identical.
   - Native (non-real-time) captures keep exact inventories.
2. **Production gates must see both views.**
   - The Mortar's production gate failed per folder with "rear: missing production walk samples", because the
     director ran it on `production/front` and `production/rear` separately.
   - Run each case's production gate the way its proof script does, on the combined capture, and record one verdict.
3. **Reuse the existing `before` capture.**
   - Add a way to validate, benchmark, capture `after` and compare without re-capturing `before`, for example
     `capture_director.py validate --before …`.
   - The director will run: validate before → benchmark → after → compare.
   - List the exact commands.
4. Focused tests only.
