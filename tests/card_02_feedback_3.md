# card-02 feedback 3 handoff

All four findings are addressed. Changes remain uncommitted on `codex/card-02`. No commit, branch change, peer review, publication, windowed run, card-data change or asset change was performed.

## Numbered findings

1. **Exact snapshots and collision handling.** Definition reuse compares an immutable deep snapshot of the actual selected source values and effective condition results. Source dictionaries are retained as values, never replaced with hashes. Hashes only locate context/identity buckets: contexts verify their exact inputs, and both projection and definition buckets verify their exact card/catalog/upgrade identity. Display application compares exact card/display content. Pile content and pooled-definition comparisons also retain exact snapshots. The reviewer's production relic sets reproduce the matching source hashes through the real Scavenger detail: Quick Stab updates **6 → 13 → 6**, without clearing the cache, including an in-place relic-array edit. A separate fixed card-identity collision exercises two distinct authored upgrade options in the same bucket, across both context-local and retained-definition lookups.
2. **Player dependencies and unchanged Bleed.** Definitions select player inputs from their actual actions and applicable relic schemas. Bloodglass records its half-Health/no-defense predicate. Stonefist records the effective Stoneskin damage, including its cap. Surface bonuses and Hobnail use the existing engine's surface/player-condition readers. Most attacks record no player dependency. Follow-up/Empower action edits and derived blast actions are included when selecting dependencies. The projection itself still uses the shared hand computation. The unchanged-Bleed benchmark verifies every definition, rendered text, row and badge, zero projections/signals, and the 2 ms maximum. The 60-unique case passes at **0.484 ms median / 0.569 ms maximum**. No residual budget failure was observed in the requested case.
3. **Binding and eviction guards.** Retained Stonefist traverses Stoneskin 0, 3, 6, 7 and back to 0; it updates below the cap and reuses the projection above it. Retained Frostbolt with Hobnail follows Ice appearing under the hero, the hero moving off it, Ice appearing at the new tile, and that tile changing to Fire. All rows match a fresh independent resolution. A single bound face exercises 520 distinct variants, verifies the 512-entry limit during insertion, crosses context eviction, checks the exact retained FIFO set, and proves that touching an old entry does not promote it. A separate matrix compares cached/fresh output for all 309 cards across 51 source/player/spatial states: **15,759 comparisons**.
4. **Opening-boon remnants.** Removed unused `Data`, unread `boon_inspection_card` metadata and the unused `id` parameter. Updated the production caller and tooltip proof caller. The older proof's plain Control fixture now uses the real Lantern Shot CardWidget required by the existing signal/summary-row interface; its assertion is unchanged.

## Files changed

- `scripts/card_display_bindings.gd`: exact identity buckets, exact snapshot/content equality and bounded FIFO bookkeeping.
- `scripts/card_display_dependencies.gd`: exact source values and selected player/rule-result dependencies.
- `scripts/card_display_overrides.gd`, `scripts/run_scene.gd`: exact pile snapshots and pooled card-definition comparisons.
- `scripts/opening_boon_inspection.gd`, `scripts/opening_boon_overlay.gd`: remove remnants and update the caller.
- `tests/helpers/card_display_cache_regressions.gd` (new), `tests/helpers/card_display_regressions.gd`: collision, retained player/surface, overflow/FIFO and catalog matrix guards.
- `tests/card_display_performance_test.gd`: unchanged-Bleed timing, byte comparisons and zero-projection/signal assertions.
- `tests/run_card_display_mutations.py`: source/identity collision guards and all four dependency/eviction mutants.
- `tests/helpers/short_card_tooltips_proof.gd`: actual CardWidget inspection fixture and updated caller.
- `tests/card_02_feedback_3.md`: this handoff.

## Focused verification

Godot entries used `python3 tools/godot_task_runner.py --task-id card-02 --stream -- godot --headless --path . --script <entry>`, with flags after `--`. No full Godot or Python suite ran. The benchmark ran in isolation. Final non-mutated runs exit zero with no script errors; the existing macOS certificate diagnostic and exit-time ObjectDB/resource warnings remain visible in their logs.

| Entry | Observed result |
|---|---|
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16630 checks, 0 failures)` |
| Same program's matrix | `CARD02 PLAYER INPUT MATRIX: 15759 cached/fresh comparisons; 309 catalog cards` |
| `tests/card_display_unmodified_test.gd` | `CARD02 UNMODIFIED COVERAGE: 309 catalog cards in every ID-built factory; current/available upgrade previews`; `CARD DISPLAY OVERRIDES TEST RESULT: PASS (30266 checks, 0 failures)` |
| `tests/card_display_performance_test.gd` | `CARD DISPLAY CACHE PERFORMANCE RESULT: PASS (0 failures)` |
| `python3 tests/run_card_display_mutations.py` | `CARD DISPLAY MUTATION RESULT: PASS (23 cases, 0 survivors)`; all rejections are assertion failures, with no script errors |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (845 checks, 0 failures)` |
| `tests/card_legibility_test.gd -- --context-smoke` | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 625 checks, 0 failures)` |
| Same entry, `--reading-layouts` | `CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)` |
| Same entry, `--focused-shared` | `CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)` |
| `tests/card_display_overrides_probe.gd -- --plan` | `CARD DISPLAY PROOF PLAN: PASS (0 failures)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 tests/test_test_registration_audit.py` | `Ran 32 tests` / `OK` |

Mutation replay uses the focused program's `--binding-guards` flag: every production-view, collision, retained status/surface, upgrade, surcharge and cache-limit guard runs; the independent 15,759-comparison matrix runs in the normal focused program. The mutation runner retains its existing three-worker isolation and 60-second per-child timeout.

Headless evidence: `proof/card-02/feedback3/{overrides,performance,unmodified,short-tooltips,context-smoke,reading-layouts,focused-shared,proof-plan}.log`; timing data: `proof/card-02/feedback3/performance.json`. Mutation evidence is copied to `proof/card-02/feedback3/mutations/{baseline.log,summary.json,<case>.log}`. The identity collision was established through the same task runner; `identity-collision-search.log` records the fixed pair. `git diff --check` exits zero.

## CPU measurements

Each row contains 25 samples. Values are median / maximum milliseconds. Only actual visible text changes are exempt from the 2 ms assertion.

| Cards | Definitions | Health 13–23/24, unchanged text | Bleed 1–25, unchanged text | Hidden Health | Pile snapshot | Visible Health 12 ↔ 24/24, changed text (exempt) |
|---:|---|---:|---:|---:|---:|---:|
| 20 | duplicate | 0.063 / 0.090 | 0.094 / 0.132 | 0.016 / 0.052 | 0.008 / 0.015 | 7.308 / 8.884 |
| 20 | unique | 0.131 / 0.197 | 0.186 / 0.261 | 0.015 / 0.037 | 0.041 / 0.070 | 7.432 / 11.744 |
| 60 | duplicate | 0.159 / 0.398 | 0.187 / 0.240 | 0.025 / 0.056 | 0.010 / 0.019 | 23.169 / 24.994 |
| 60 | unique | 0.429 / 0.503 | 0.484 / 0.569 | 0.026 / 0.120 | 0.118 / 0.189 | 30.273 / 40.715 |

Every unchanged-Health/Bleed row reports `extra_projections=0 display_signals=0`. General/unrelated UI maxima are at most 0.008 ms. Actual text changes remain synchronous, with their full cost reported above; no deferred updates or altered visual timing were introduced.

## Proof for the design owner

No windowed runs or captures were attempted in the worker's window-server-free sandbox. Initial fixture text and layout remain unchanged; the stale collision case now updates to the correct text. The existing real-fixture proof plan passes. Director command at 1920×1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-02 && python3 tools/visual_probe_runner.py --task-id card-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/card_display_overrides.json --result-manifest /private/tmp/labyrinth-inspection-manifests/card-02-feedback-3-render-v1.json tests/card_display_overrides_probe.gd
```

Capture paths are printed under a fresh `user://card_02_<ticks>/{hand,deck,campfire,scavenger,bloodglass_full,bloodglass_injured}.png` directory and recorded by the validated manifest. These are pending renderer outputs, not worker-created captures.

## TODO_DESIGN, chosen defaults and open issues

No TODO_DESIGN placeholders or player-facing defaults were added. Runtime limits remain eight contexts and 512 retained definitions, with the existing FIFO behavior made explicit. New test-only fields are `OVERFLOW_VARIANTS = 520`, `IDENTITY_VARIANTS = [27006, 122826]`, Stoneskin fixtures 0/3/6/7 and hero surface positions `(2,2)`/`(3,2)`; the catalog matrix uses named player/status/spatial patches. The disposable collision-search proof uses `SEARCH_LIMIT = 300000`. Timing samples remain 25. No open implementation issue is known; renderer inspection remains with the design owner.
