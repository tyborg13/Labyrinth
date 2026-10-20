# int-04 feedback 1 (director; Codex review of c93b4b1d2 requested changes)

Fix both Blocking findings. Focused tests, then both full suites once, because this unit's job is a green merge.

1. **The historical maquette checks must not read today's Lancer data.**
   - The converted checks call a compiler that reads the live Lancer spec (`compile_recipe.py:31`):
     - mq-05 `spec/art_identity/maquettes/blender/test_creature.py:66`;
     - mq-07 `tests/test_arc_thrall_maquette_r2.py:164`;
     - mq-08 `tests/test_glacial_mirror_shoulder.py:193`;
     - mq-09 `tests/test_mq09_maquettes.py:181`.
   - Increasing only the live Lancer's `target[0]` by 0.01 fails all four.
   - Supply the owning unit's historical Lancer input to both compilation paths, including `compile_solids`.
2. **Endpoint self-consistency doesn't prove preservation.**
   - These four read both the foreign recipe and its expected report hash from `UNIT_HEAD`. Two mutations survive:
     - a coordinated recipe and `spec_hash` edit (doubling the Seer's head scale);
     - deleting the Seer's recipe from mq-09's inventory.
   - Add pinned `base..UNIT_HEAD` preservation checks that catch foreign additions, edits and deletions, and keep the
     compilation assertions.
   - Add the coordinated-edit and deletion mutations to `tests/test_int04_preservation.py`. Each must fail.
3. Report the mutation table, then both full-suite result lines.
