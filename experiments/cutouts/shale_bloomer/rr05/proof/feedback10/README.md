# rr-05 feedback 10 — exact native texel ties

The native source mismatch is fixed. Bloomer passes its saved native pixel gate with 0 errors. Wisp has 0 source mismatches and 0 held shimmer, but the newly required 2% per-node occupancy guard rejects three explicitly retained valid fixtures (18 held frames). The guard has not been loosened. Its scope needs a director decision.

## Implementation and acceptance

1. `nearest_quad(..., with_ties=True)` exposes the unchanged default, the opposite tied-axis neighbours, independent u/v candidates and a float64 exact-tie mask (1e-6 after 8-bit vertex snapping). Non-ties retain their original sampling.
2. Native source checks accept only exact candidate colours at ties. A third colour fails even if the ordinary 1px + 1% edge allowance would accept it. The non-tie allowance is unchanged.
3. Native ideals use each frame’s valid tie choices. Held comparisons use the cached canonical rigid-change mask, so native candidate flips remain unexplained and fail at zero tolerance.
4. Every part/view is listed below and in `tied_pixels.json`. Painted ties are counted within the union of occupied candidate pixels; transparent padding is excluded. Counts cover the presented idle frames, once each, without double-counting wrap.
5. Retained arc_right frames 18/90 and the added seam frame 12 pass exact candidate matching. Synthetic third-colour, held-flip, independent-axis, guard and stale-runtime/paint mutations are covered. The actual adoption heredoc now has a prop entry without `dir` in its stub registry.
6. Saved captures were re-gated headlessly; the worker ran no windowed capture, MP4, promotion or adoption. The director’s equal-depth ownership, boundary 1% and registry `.get("dir")` edits remain intact.

## Evidence and remaining acceptance conflict

For `rear/seam_core_arc_right/0012`, default and native bounds both equal `[307,267,317,282]`. The three differing pixels at `(308,274)`, `(311,274)`, `(312,274)` have float64 v=7.0. Default row 6 differs by 3 pixels; native row 7 matches an exact candidate with 0 pixel differences. See [diagnosis](diagnosis.json).

| Valid retained fixture | Occupied tied pixels | Occupied candidate union | Fraction |
|---|---:|---:|---:|
| front/arc_right/0018 | 7 | 180 | 3.89% |
| front/arc_right/0090 | 30 | 226 | 13.27% |
| rear/seam_core_arc_right/0012 | 5 | 60 | 8.33% |

`TODO_DESIGN_exact_tie_guard_scope`: all three fixtures are valid GPU tie choices but exceed 2% of their individual painted node’s occupied pixels. Each shares the core bone. The requested per-node guard is retained; the Wisp proof remains blocked pending a decision on its denominator. No paint, pose, motion, seam or numeric tolerance was changed.

Native held residual: 0 pixels for both creatures. Boundary residual: Bloomer 4 pixels, Wisp 3 pixels total; both are within the director’s unchanged 1% per-boundary allowance. The report records exact maxima.

[Native results](native_results.json) · [feature results](features.json) · [seam metrics](per_clip.md) · [preservation](preservation.json) · [verification](verification.json) · [owner commands](owner_commands.md) · [chosen defaults](chosen_defaults.json).

## Verification and open issues

- Full Godot: `FULL SUITE RUNTIME: 373.763 seconds (budget 900 seconds)`; `TEST RESULT: PASS`.
- Focused: `Ran 153 tests in 278.399s`; `FAILED (failures=1, skipped=2)` — Wisp's unchanged idle assertion encounters the new 2% guard.
- Final native/tie suites: `Ran 15 tests in 0.958s`; `OK`. This includes the held-flip integration regression added after bulk discovery.
- Owner script stub suite: `Ran 5 tests in 2.291s`; `OK`, including the actual adoption block with a prop entry lacking `dir`.
- Python: `Ran 755 tests in 788.745s`; `FAILED (failures=69, skipped=63)`. 68 failures concern the director-promoted Bloomer's pending density adoption/native rest rebake (63 image subtests plus five registry/density assertions); one is the Wisp guard conflict. Assertions were preserved. See [pending adoption evidence](pending_adoption.json).
- `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`; `git diff --check` exit 0.
- Both native capture structural/hash checks pass with 0 errors. Saved-capture pixel gates: Bloomer PASS (0 errors); Wisp FAIL (18 guard errors, 0 source mismatches, 0 held shimmer).

[Files changed](files.md) · [repo size delta](repo_size.json) · [TODO_DESIGN data](TODO_DESIGN.json). The 189 archived bulky diagnostics remain untracked under `output/rr-05/archive/`. Test-only chosen defaults are recorded in [chosen_defaults.json](chosen_defaults.json); no player-facing defaults were chosen.

## Tied-pixel counts per part and view

| Creature | View | Part | Total | Max/frame | Max occupied fraction |
|---|---|---|---:|---:|---:|
| shale_bloomer | front | seam_root_tip_l_root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_near_l_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_tendril_high_l_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_root_stem_c_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_tendril_high_r_tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_root_stem_r_root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_root_stem_r_root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_near_r_tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_tendril_low_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_root_stem_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_root_tip_c_component_01 | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_trunk_root_tip_c_component_02 | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_tendril_low_l_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_core_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_near_l_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_far_l_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_core_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_near_r_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_core_petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_core_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | seam_petal_near_l_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | trunk | 0 | 0 | 0.000000% |
| shale_bloomer | front | core | 0 | 0 | 0.000000% |
| shale_bloomer | front | petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | tendril_low_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_stem_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_trunk | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_core | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | tendril_mid_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_tendril_low_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | root_stem_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_root_stem_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | front | hidden_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | front | feature_crown_gem | 0 | 0 | 0.000000% |
| shale_bloomer | front | feature_amber_upper | 0 | 0 | 0.000000% |
| shale_bloomer | front | feature_amber_right | 0 | 0 | 0.000000% |
| shale_bloomer | front | feature_amber_left | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_tendril_low_l_root_stem_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_root_stem_l_root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_petal_far_l_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_tendril_high_l_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_core | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_tendril_mid_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_root_stem_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_trunk_root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_root_stem_l_root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_core_petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_petal_near_l_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_petal_near_l_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_core_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_petal_near_r_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_core_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | seam_core_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | trunk | 0 | 0 | 0.000000% |
| shale_bloomer | rear | core | 0 | 0 | 0.000000% |
| shale_bloomer | rear | petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | tendril_mid_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | tendril_low_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_stem_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_trunk | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_core | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_petal_near_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_petal_near_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_petal_far_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_petal_far_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_tendril_high_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_tendril_high_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_tendril_mid_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_tendril_low_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_tendril_low_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_root_stem_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_root_stem_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_stem_c | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_root_tip_l | 0 | 0 | 0.000000% |
| shale_bloomer | rear | root_tip_r | 0 | 0 | 0.000000% |
| shale_bloomer | rear | hidden_root_tip_c | 0 | 0 | 0.000000% |
| shale_bloomer | rear | feature_crown_gem | 0 | 0 | 0.000000% |
| shale_bloomer | rear | feature_amber_rear_left | 0 | 0 | 0.000000% |
| shale_bloomer | rear | feature_amber_rear_low | 0 | 0 | 0.000000% |
| lightning_wisp | front | seam_core_crown | 0 | 0 | 0.000000% |
| lightning_wisp | front | seam_core_tail | 0 | 0 | 0.000000% |
| lightning_wisp | front | seam_core_arc_left | 0 | 0 | 0.000000% |
| lightning_wisp | front | seam_core_arc_right | 0 | 0 | 0.000000% |
| lightning_wisp | front | core | 12 | 2 | 0.028054% |
| lightning_wisp | front | crown | 0 | 0 | 0.000000% |
| lightning_wisp | front | tail | 6 | 1 | 0.033478% |
| lightning_wisp | front | arc_left | 0 | 0 | 0.000000% |
| lightning_wisp | front | arc_right | 222 | 30 | 13.274336% |
| lightning_wisp | front | hidden_core | 6 | 1 | 0.012203% |
| lightning_wisp | front | hidden_crown | 6 | 1 | 0.012203% |
| lightning_wisp | front | hidden_tail | 6 | 1 | 0.020799% |
| lightning_wisp | front | hidden_arc_left | 6 | 1 | 0.012203% |
| lightning_wisp | front | hidden_arc_right | 6 | 1 | 0.012203% |
| lightning_wisp | front | feature_eye | 0 | 0 | 0.000000% |
| lightning_wisp | rear | seam_core_crown | 0 | 0 | 0.000000% |
| lightning_wisp | rear | seam_core_tail | 0 | 0 | 0.000000% |
| lightning_wisp | rear | seam_core_arc_left | 30 | 5 | 1.483680% |
| lightning_wisp | rear | seam_core_arc_right | 30 | 5 | 8.333333% |
| lightning_wisp | rear | core | 0 | 0 | 0.000000% |
| lightning_wisp | rear | crown | 0 | 0 | 0.000000% |
| lightning_wisp | rear | tail | 0 | 0 | 0.000000% |
| lightning_wisp | rear | arc_left | 0 | 0 | 0.000000% |
| lightning_wisp | rear | arc_right | 0 | 0 | 0.000000% |
| lightning_wisp | rear | hidden_core | 6 | 1 | 0.012404% |
| lightning_wisp | rear | hidden_crown | 6 | 1 | 0.012404% |
| lightning_wisp | rear | hidden_tail | 0 | 0 | 0.000000% |
| lightning_wisp | rear | hidden_arc_left | 6 | 1 | 0.012404% |
| lightning_wisp | rear | hidden_arc_right | 6 | 1 | 0.012404% |
