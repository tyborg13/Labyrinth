# gait-01 feedback 1 (director; Codex peer review of dbdfebf13)

The walk itself checked out: schedule, Hermite path, lift, lanes, settle, arm signs, linear root, width preservation,
rigid bases. Fix these, focused tests only:

1. **Medium — rigid-air measurement skipped when any joint mesh exists.** `tools/humanoid_cutout/walk_gates.py:114`
   skips every rigid joint whenever `joint_meshes` is nonempty, so a 4 px leg gap passes once an unrelated arm mesh is
   declared.
   - Classify each leg from its mesh weights, exactly as the runtime's `humanoid_gait.gd` `skinned()` does, and measure
     every rigid leg.
   - Add both mutations to the shipped gait tests: a 4 px gap with an unrelated arm mesh, and removing the rigid-air
     integration. Both must be caught.
2. **Medium — the Thrall's runtime diagnostic crashes.** `tests/rr11/runtime_checks.gd:78` still reads the retired
   `layout["leg_roles"]`.
   - Derive support behaviour from `planted_bones`.
   - Register this diagnostic in the focused tests so a retired field can't crash it again.
3. **Low — preservation checks compare with `HEAD`.** `tests/test_gait01.py:145` compares with `HEAD` and its scope
   check sees only uncommitted changes. Pin both to the director-data commit `80d5ec39b` and compare the committed
   range.
4. **Low — oversized proof records.** `rr11_gates.py:35` and `rr18_gates.py:50` serialize complete overlapping
   reports: `knees.json` and `supports.json` total about 2.9 MB.
   - Commit summaries, extrema, swing records and failures only.
   - Write the full per-frame diagnostics to the gitignored proof outputs.
   - Apply the same rule to the shared walk-gate writer, so the parked rigs inherit it.
5. Remove the dead names at `gait.py:112` and `walk_gates.py:9`.

No motion or art changes. Hand back with the focused results. I run the windowed proofs.
