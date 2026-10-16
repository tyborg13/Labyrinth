# rr-04 — round 1 (Codex peer review of 7aa3d17ab: CHANGES REQUESTED)

Fix all three findings as the reviewer proposes (full review: /private/tmp/labyrinth_codex/review/rr-04-7aa3d17ab.md). Facing rule (director): during move the creature faces its travel direction for the whole clip and only turns back to its idle facing after the clip ends, with no single-frame flip. Shadows and HP/HUD follow the visible body during root travel.

1. **Medium — Movement changes direction on its final frame.** [presentation.gd:31](/private/tmp/labyrinth_codex/review/rr-04-7aa3d17ab/scripts/maquette_cutout_runtime/presentation.gd:31) applies idle-facing logic to `move` at phase `1.0`. With enemy `(3,3)`, player `(4,3)`, direction `(0,-1)` and a 96px step, both rigs jump from root offset `(85.865,-42.933)` at phase `0.99` to `(85.865,42.933)` at `1.0`. Preserve travel facing through the endpoint; apply player-facing orientation after returning to idle. Add endpoint tests for all four directions and `blinding_arc:move_away`.

2. **Medium — Shadows and health bars remain behind during movement.** [run_scene.gd:25273](/private/tmp/labyrinth_codex/review/rr-04-7aa3d17ab/scripts/run_scene.gd:25273) replaces the moving actor center with `from_point` to compensate for root travel. Shadows and HUD geometry consume that same center. In the real Wisp movement callback at phase `0.5`, the shadow remains at `(810.6,371.9)` while the body root reaches `(854.1,344.2)`. Confirmed for Shale too. Separate the texture’s draw origin from the moving actor center, and test shadow/HUD alignment through actual movement callbacks.

3. **Low — Remove unreachable legacy preparation paths.** [run_scene.gd:24574](/private/tmp/labyrinth_codex/review/rr-04-7aa3d17ab/scripts/run_scene.gd:24574) and line 24581 require a Wisp/Bloomer attack while excluding types handled by `MaquetteAction`, which always handles both. Remove these dead branches and their unused preparation helpers/imports.

Verification passed: full Godot suite (**774.609s**), 1,624 focused checks, integration, both production logic recorders/gates, semantic-motion tests, density, art and UI checks. Four legacy-tagged child suites also passed when rerun with `rr-04-review`.

**Mutations:** raise-sign flips, dropped keys, broken compiler signs and frozen idle were caught; none survived. All resolved intents route correctly. Wisp death reaches alpha zero and releases its renderer. No Windows typed-array violations, shrike changes, misplaced tunables or stray huge files found. All experiments were reverted; checkout is clean.


Each fix needs a regression that fails before. Focused tests + full suite once; re-run the design_owner_proof.sh steps that cover production capture (skip the inspection-fixture --launch step, which opens a playable window). Do not commit.
