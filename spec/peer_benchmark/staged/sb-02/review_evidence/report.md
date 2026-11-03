# sb-01 final peer review

HEAD: `f0d6170e799af4f37e6f1fbe5a81d8241f4e0033`  
Base: `codex/peer-benchmark`  
Previous review: `03e6d50130923a02c9cc1bea2521e4d1b23b9200`  
Disposition: **CHANGES REQUESTED**

## Findings, ordered by severity

### 1. Medium — the new group solver pushes HUDs off their actors and beneath the hand

`scripts/board_hud_group_placement.gd:11–24` searches downward without a displacement or board-area limit. `scripts/board_status_layout_cache.gd:14–26` adds each previously placed group as an obstacle, so successive groups cascade downward. This pass only starts with the boss frame and does not reserve the hand or actor art. Its result is used for the actual bar/pill drawing (`scripts/combat_board_view.gd:9185–9186`, `:9572–9575`).

Reproduce using the exact mixed-mechanics population from the new `tests/suites/board_hud_group_suite.gd:34–46`: eight distinct neighboring foes, the Ball Lightning illusion, and its authored status/defense decoration. `live_hand.gd` first submits that state to a standalone board, then loads it through a real `run_scene` with its hand and normal presentation. Everything is headless, at 1920×1080.

In the full scene:

- Hero `(4,4)` moves **350 px** down: anchored bar `(889,301.481,142,32)` becomes `(889,651.481,142,32)`, centered on board tile **(7,7)**. The hero's floor center is `(960,452.171)`.
- The storm capacitor, enemy_5 `(5,4)`, moves **500 px** down: bar `(966.198,830.308,138,34)`, Immobilized pill `(979.416,862.074,120,22)`. Both leave the board's floor polygon and overlap the live card rectangle `(856,761,208,292.864)`.
- Enemy_7's bar/pills and enemy_8's bar/pills also cross the card rectangle. There are **16 group-piece/card intersections** across these three actors.
- The standalone version also puts the hero's bar on the enemy_8 tile `(5,5)`, rather than at its own head. Some groups sit on other actors' art. The layout supplies no connecting HUD tether.

The new sweep's zero HUD/HUD overlaps therefore does not prove readable placement: its assertions at `tests/suites/board_hud_group_suite.gd:98–104` do not check board containment, hand exclusion, or actor association.

**Fix:** constrain group placement to the usable board region and reserve live screen UI, rather than accepting unlimited downward escape. Resolve crowded groups jointly with bounded displacement/appropriate reflow; preserve a clear association to the owning actor if displacement is necessary. Keep the fixed discs and approved internal plate/pill spacing. Extend this exact crowded fixture to assert hand exclusion and owner-relative/board bounds as well as pairwise HUD clearance.

Evidence: `live_hand.gd`, `live_hand.log` (`LIVE_PLACEMENT`, `HAND_RECT`, `HAND_OVERLAP`), plus `live_geometry.log` and `geometry.log`.

### 2. Medium — interpolation now rebuilds the entire crowded HUD every frame

`scripts/combat_board_view.gd:9031` disables the existing moving-HUD path whenever more than one HUD unit exists. Ordinary movement submissions consequently run `_rebuild_hud_health_rects_cache` and `_build_hud_layout_data`, including the sequential group solve at `:9110`. The exact world-position signature is unique on every interpolation frame, so this also inserts deep full-layout snapshots into the LRU instead of retaining the old movement path's lightweight update.

`movement.gd` uses **12 distinct units** (hero plus 11 crawlers, no overlapping origin tiles), collapsed intents, unchanged combat/status state, and one enemy's `unit_world_positions` moving by 0.123 px per submission. There are 20 warmup and 100 measured submissions per run. All versions use the same workload, same machine, same headless runner and current unrelated helpers. Historical board/cache/plate sources are loaded from Git into disposable test scripts, never another checkout. Two serial matched runs:

| Version | Submission p50 (µs), runs 1 / 2 | Submission p95 (µs), runs 1 / 2 | HUD phase mean (µs), runs 1 / 2 |
| --- | --- | --- | --- |
| Base `codex/peer-benchmark` | 807 / 795 | 1361 / 902 | 93 / 79 |
| Previous `03e6d5013` | 902 / 891 | 1647 / 1092 | 181 / 157 |
| HEAD | **3554 / 3823** | **3955 / 5102** | **2810 / 3061** |

HEAD's mean median is **4.11× previous HEAD** and **4.60× base**. Instrumentation localizes the added work to HUD layout; derived-cache work remains about 24–30 µs. This is CPU submission evidence, not a full-frame/GPU timing claim.

The committed `status_plates_performance_probe.gd` still passes, but it draws artificial frames directly with no populated neighbor-group pass and never submits moving actors. Its stable signature workload cannot catch this regression.

**Fix:** retain an incremental interpolation path that updates the moving group's placement and affected neighbors while reusing unaffected groups; avoid deep full-layout/LRU rebuilds for each interpolation sample. Do not simply restore the old early path without updating dependent neighbors. Add a matched movement submission benchmark with populated group obstacles and report the restored cost.

Evidence: `movement.gd`, `performance.py`, `movement_comparison.json`, `movement_{parent,base,candidate}_{0,1}.log`. `movement_initial_comparison.json` is a discarded exploratory 13-unit workload that included an occupied hero tile; the numbers above use only the corrected legal 12-unit population.

## Previous requested fixes verified

1. **Original hero/Grave Surgeon reproduction is fixed.** The hero remains at `(4,4)`, Block 6/Stoneskin 4; Grave Surgeon `(5,3)`. The fixed enemy disc remains `(1048.999,434.0355,24,24)`. The hero Block plate now sits at `(1033,467.0701,46,24)` and Stoneskin at `(1082,467.0701,47,24)`; both clear it. `defense_disc.log` re-runs the original review script unchanged.
2. **Expanded Air Warband seed 83 is fixed.** Re-running the original `extra_geometry.gd` reports no chip/intent/crest or plate/pill cross-unit overlaps. The production chip path now includes cached intent lines and actual crests. The committed suite independently passes the same seed in collapsed and expanded modes.
3. **All four surviving cache mutants now fail.** Freeze, nested keyword contents, both Truesight inputs, and ordinary defense values/fallbacks are covered at stable keys/frames. The original independent cache oracle still passes all **804 comparisons** at unmodified HEAD.

Source-based classes, exact words/counts, stable order, semantic palette tokens, zero/positive charge, predicted pills, style reuse, wrap and tooltip coverage remain intact. Live `_get_tooltip` queries match all **97** sampled plate/pill tooltips after placement and focus changes. All **13** sampled controller-focus intent global bounds match the placed cached intent rectangles. The wider tutorial inspection-bound API still omits status/defense extensions in some cases; no new normal controller-intent or plate-tooltip mismatch was reproduced, so this is not asserted as an additional finding.

## Mutation testing

Each source mutation was restored byte-for-byte before the next. No result relies on a parse/compile failure.

| Mutation | Committed focused suite result |
| --- | --- |
| Omit Freeze dependency (previous survivor) | Caught, 12 failures |
| Omit keyword dependency (previous survivor) | Caught, 15 failures |
| Omit both Truesight dependencies (previous survivor) | Caught, 15 failures |
| Omit ordinary Block/Stoneskin and preview fallback dependencies (previous survivor) | Caught, 24 failures |
| Disable complete-group collision offset | Caught, 418 failures |
| Omit neighbor geometry from cache signature | Caught, 4 failures |
| Omit placed intent-line obstacles from threat placement | Caught, 5 failures |
| Omit crest obstacles from threat placement | **Survived**, 28,181 assertions pass |
| Disable final intent/crest clearance helper | Caught, 4 failures |

**8 caught / 1 survived.** The surviving crest ablation shows the sampled suite does not make threat/crest clearance decisive. The production code includes the obstacle; no unmodified threat/crest collision was reproduced. Add a fixture that puts both default chip candidates/search choices against actual placed leader crests to improve this guard. See `mutations.json`, `mutations.py`, and `mutant_*.log`.

## Verification and limits

- `tests/board_status_plates_test.gd`: PASS, **28,181 assertions**; all 20 authored crowded states report zero HUD/HUD intersections.
- `enemy_intent_preview_test.gd`: PASS.
- `enemy_intent_continuity_test.gd`: PASS, **1,882 checks**.
- `threats_at_rest_test.gd`: PASS, **612 assertions**, including compass.
- `combat_hud_buttons_test.gd`, `combat_hud_dialogue_input_test.gd`: exit 0.
- `combat_hud_badges_test.gd`: the same three failures already reproduced at base by the previous review: semantic Intents label, ON text/border, complete controller inspection text. No new failure added.
- `status_capture_probe.gd --check-only`: PASS; five order discs retained in capture states. `status_capture_compare.py --geometry-only`: PASS, **six nameplates within 3 px**. Semantic JSON is preserved under `semantic-capture/`.
- `status_plates_performance_probe.gd`: PASS, stable 12 layouts / 12 rebuilds / 5 styles / 7 trim-cache entries / 300 resources. This run's p50 was 902 µs; it is not a matched comparison to previous timings and does not address moving-group cost.
- `python3 tests/test_ui_identity_lint.py`: PASS, 25 tests; `python3 tests/test_icon_identity_policy.py`: PASS, 8 tests. No policy baseline changes.

Reviewed the whole production diff and new helper/test/probe areas against the brief and all three feedback rounds. No new gameplay tunables that belong in data, gameplay rule changes, new distinct icon identities, unrelated production scope, or stray runtime files found. Numeric constants belong to approved geometry, existing clearance conventions or bounded caches. The obsolete integration patch was removed. No added Windows typed-array literal/conditional assignment violation found by source inspection; Windows execution was unavailable. No full game suite was requested or run. The known unchanged enemy-no-action test preload defect remains covered by the previous review's base comparison, rather than patched again here.

The director's accepted windowed capture judgment for this exact HEAD is taken as supplied evidence. This review did **not** open a window, run an editor scan, or claim fresh renderer proof. The headless experiments expose additional crowded-state geometry that the accepted mock fixture does not exercise.

## Reproduction and integrity

From `/private/tmp/labyrinth_codex/review/sb-01-f0d6170e7`:

```sh
python3 /private/tmp/sb01-final-review/reproduce.py live_hand
python3 /private/tmp/sb01-final-review/reproduce.py movement
python3 /private/tmp/sb01-final-review/performance.py
```

The helper copies exactly one saved experiment into a new temporary `tests/` file and removes it in `finally`. All Godot commands use `python3 tools/godot_task_runner.py --task-id sb-01-review --stream -- godot --headless ...`. The matched comparison also removes all historical source fixtures after each version.

No commits, pushes, branch changes, Git metadata writes, or edits to another checkout. Final HEAD and clean-tree checks are in `integrity.txt`. All review sources/logs remain outside the checkout in `/private/tmp/sb01-final-review`.
