# map-02 feedback 1 — boss spacing decision + the windowed probe crashes

The variety results are excellent. Keep the generator as it is.

1. **TODO_DESIGN_BOSS_BUTTON_GAP (director decision).** Keep the boss node's centre exactly where it is now (the
   last step's x). Space every other column (entry through the last interior row) evenly between x = 80 and
   (boss centre x − 175 px). Section VI (13 steps) then has an interior spacing of about 134 px: 122 px nodes with a
   gap of ≥ 8 px.
   - This applies to revision 5 only. Revisions 3 and 4 keep their layout.
   - The layout test must report 0 violations for ordinary and boss buttons across all 200 seeds.
2. **The windowed probe crashes before any capture.** I ran `sh tests/map_02_proof.sh` under the director lock. Log:
   `tests/map_02_director_run1.log`.
   `SCRIPT ERROR: Cannot call method 'get_children' on a null value at SectionMapPanel.select_section
   (section_map_panel.gd:296)`, called from `section_map_variety_probe.gd:55`. The probe calls `select_section`
   before the panel has built its field.
   - Fix the probe's setup order: await the panel's ready or layout signal, matching how the existing section map
     probes open the map.
   - If `select_section` can also be reached in-game before the panel is ready, guard it in the panel too, and add a
     headless regression for it.
   - Make the probe fail fast with a clear message rather than a null call.
3. **The two existing issues you noted.**
   - The `frostglass_lancer/mq4_rear` replay failure was my art commit. It's fixed on `codex/peer-benchmark` at
     146c999cb. Merge `codex/peer-benchmark` into your branch: it also brings the merged mq-02/mq-03 maquette
     builder.
   - The `_event_panel` snapshot note is pre-existing. Leave it.
4. Re-run the variety tool, the v5 suites and the full Godot and Python suites, and report the full-suite time. The
   budget is 900 s and the last integration run took 840 s, so add no runtime: the 200-seed proof stays out of the
   main suite, as you have it.
