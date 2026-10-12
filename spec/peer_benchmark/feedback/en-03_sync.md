# en-03 — resolve the integration sync (director)

Approved after round 1. I started `git merge codex/peer-benchmark` in your worktree; it stopped with conflicts in 13 files
(en-01 Burrow Grub / Ember Tick landed first and touched the same registries). Do NOT run git commands (I commit).

1. Resolve every conflict keeping BOTH units' additions: `data/enemies.json` (all four enemies), `action_icon_library.gd`
   (burrow/erupt/burst AND tether/veil), `enemy_intent_compass.gd`, `enemy_strike_points.gd`, `combat_engine.gd`,
   `combat_board_view.gd`, `run_scene.gd` (portraits for all four), `contextual_cutout_suite.gd` (all four static
   enemies), `spec/card_balance_heuristic.md` + `tools/card_heuristic.py` (all four rows), `spec/assets/enemies/raw_sha256.txt`
   (union), `spec/assets/board_pixel_density/{outputs,registry}.json` (union of entries).
2. Regenerate generated artefacts instead of hand-merging them: `assets/generated/unit_shadow_cache.res` (the shadow
   cache tool) and re-run the density `--record-rests`/`--check` so outputs/registry are consistent.
3. Verify: no conflict markers anywhere (`git diff --check` and a grep for `<<<<<<<`), JSON parses, then run the en-01
   suite, the en-03 suite, the encounter tables suite, threats-at-rest, sfx bank, icon audit, density tests and the full
   suite — all green. Report the list of files you resolved and the results.
