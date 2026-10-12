# biome-01 feedback 1

Native gallery run by the director: all 7 biomes + the Iskaldra Hearth look right. Decisions:

1. Stone legacy reconciliation — `data/biomes.json` updated by the director (already in your worktree):
   stone lighting tint `[1,1,1]` (identity), stone pool colour `[1.0, 0.60, 0.28, 1.0]` (today's shader default),
   `embers` preset direction `[0.15,-1]`, speed `[6,18]`, spread `28`, and `"color_ramp": "legacy"` meaning "use the
   existing authored RGB/alpha ramp". Make the code read these data values (stone must still render byte-identically
   to today — keep your equivalence checks) and delete the three TODO_DESIGN constants and the spec paragraphs about
   them.
2. `TODO_DESIGN_SPARK_FLASH_FRAMES` → frames 4 and 11 (0-based) of the 16-frame idle sheet flash at 1.25.
3. Noctyrax floors are too dark to read the grid: data now has `noctyrax.raw_grade.floor = [1.30, 1.25, 1.35]`. Re-run
   the processing for noctyrax (and zekarion for the spark sheets), keep determinism, update the provenance README.
4. Rerun: biome suite, processing tests, static floor cache test, full suite. The director reruns the gallery probe.
