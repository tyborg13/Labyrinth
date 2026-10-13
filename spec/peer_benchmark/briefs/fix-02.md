# fix-02 — Keep wall-clock play time out of the deterministic combat state

## Header
- Root cause (director, verified): since meta-01 (merge 6f4bbacfb) `combat_feel_test` fails "Card presentation
  preserves the complete resolver state/RNG"; the only difference is `combat_state.run_stats.run_seconds`
  (scene 0.000079 vs engine 0.0): the run scene accumulates wall-clock play time into the combat state during
  presentation. Combat state must stay a pure function of resolver inputs.
- Base: `codex/peer-benchmark` (director gives the commit).
- Owned files: `scripts/run_scene.gd` (≤ 20 lines), `scripts/run_engine.gd`, `scripts/combat_engine.gd` (only the
  run_stats/run_seconds plumbing), `scripts/run_score_rules.gd`, `tests/suites/run_score_suite.gd`,
  `tests/suites/combat_feel_suite.gd` (no weakening), `spec/run_end.md`.

## Change
1. Track play time in the run scene (unpaused wall-clock while a run is active) and write it into
   `run_state.run_stats.run_seconds` only at existing commit/save points (room exit, save, run end) — never into
   `combat_state` and never during presentation. `combat_state.run_stats` must not carry `run_seconds` at all (or
   carries the run value unchanged through combat).
2. Saves/resume keep accumulating correctly (pause, menus and the run-end screen excluded, as meta-01 specified).
3. Swift feat and the Chronicle (`run_seconds`) keep working.

## Proof
- `combat_feel_test` passes unchanged (its equality check is the regression; it must fail on 6f4bbacfb and pass after);
  run score suite covers run_seconds accumulation across save/resume and paused time; full suite green.
