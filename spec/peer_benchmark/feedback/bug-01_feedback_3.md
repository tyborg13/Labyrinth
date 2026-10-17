# bug-01 feedback 3 — the native dump crashed before writing anything

I ran your dump command. Log: `output/bug-01/director_native/bug01_dump_run1.log`. Exit 1 and no files: every case
hit
`SCRIPT ERROR: Invalid call. Nonexistent function '_resolved_board_geometry_inputs' in base 'Control
(ClockedReference)'` at `tests/fixtures/static_floor_diff_capture.gd:43`, followed by
`Invalid access to property or key 'errors' on a base object of type 'Dictionary'`.

1. Fix the dump's calls against the clocked reference node. Add a headless smoke test that drives
   `static_floor_diff_capture.gd` end to end with the same node types, so the native-only path can't ship broken
   again.
2. **Hypothesis to test in the dump.** The failing cases are elemental floor surfaces at several intensities, doors,
   an HP bar, and "new room". These may animate through the shader's built-in `TIME`, which your script clock freeze
   can't stop. Write `TIME`-independence evidence per case:
   - capture the same state twice, 0.25 s apart, with nothing changed;
   - if those two differ, the comparison is measuring shader animation, not the cache.

   Then either drive those shaders from a controllable uniform for proof runs (production behaviour unchanged), or
   compare at a pinned global shader time if Godot allows it. Report which.
3. Hand me the fixed dump command. As before, deliver it with headless checks passing.
