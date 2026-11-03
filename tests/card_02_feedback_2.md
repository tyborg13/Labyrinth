# card-02 feedback 2 handoff

The three findings are addressed without changing card rules, wording, layout, or the hand projection. Changes remain uncommitted on `codex/card-02`. No peer review, commit, publication or windowed run was performed.

## Numbered findings

1. **Effective dependencies and the 2 ms budget.** Each cached card/upgrade definition records its dependencies. Raw Health and maximum Health are excluded from projection identity; Bloodglass depends on the half-Health/no-defense predicate. Cards without a bloodied bonus do not depend on Health. Elemental attacks with a room bonus depend on `room_element`; other cards do not. Definition sources remain tracked, and spatial/non-Health player inputs remain conservative for status scaling and surface rules. The retained projection survives raw context eviction when these dependency values match. General refresh, per-definition sharing and hidden lazy refresh remain intact. The benchmark now enforces 2 ms for 25 refreshes with 60 unique visible cards at 13–23/24 Health, verifies definition/text/row/badge bytes and zero extra projections/display signals, and exempts only the separately measured real-change case.
2. **Binding-level regression guards.** The production Scavenger detail retains the same Quick Stab face while refreshing through 24/24, 12/24, 24/48 and 48/48 Health. It displays 6, 13, 13 and 6 damage respectively, without an injected combat `player`. A generated map's legal `(0, 0)` → `(1, -1)` transition changes the room element, and a retained bound Frostbolt changes from 4 to 5. Its oracle resolves the destination independently through RunEngine. The dormant room-bonus schema uses a temporary in-memory test relic; room geometry, graph, transition and card are production data. The mutation runner now also removes the `room_element` input and freezes normalized maximum Health at 24.
3. **Unused remnants.** Removed facade `GROUP`, `RESOLVER_META` and `apply()`, the binding `id`, and the context `signature` field. The local signature used for context lookup and projected-content signature used for display application remain in use.

## Files changed

- `scripts/card_display_dependencies.gd` (new): per-definition dependencies and shared effective input values.
- `scripts/card_display_bindings.gd`: retain projections across equivalent raw contexts; remove unread fields.
- `scripts/card_display_overrides.gd`: remove unused extraction remnants.
- `tests/card_display_performance_test.gd`: enforce the unchanged-text budget and record full real-change costs.
- `tests/helpers/card_display_fixture.gd`: production fixture accepts maximum Health.
- `tests/helpers/card_display_regressions.gd`: retained shop Health cases and real room transition.
- `tests/run_card_display_mutations.py`: the two requested guard mutations.
- `tests/card_02_feedback_2.md`: this handoff.

## Focused verification

All Godot programs ran through `python3 tools/godot_task_runner.py --task-id card-02 --stream -- godot --headless --path . --script <entry>`. Flags below follow `--`. No full Godot or Python suite ran.

| Entry | Observed result |
|---|---|
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (314 checks, 0 failures)` |
| `tests/card_display_unmodified_test.gd` | `CARD02 UNMODIFIED COVERAGE: 309 catalog cards in every ID-built factory; current/available upgrade previews`; `CARD DISPLAY OVERRIDES TEST RESULT: PASS (30266 checks, 0 failures)` |
| `tests/card_display_performance_test.gd` | `CARD DISPLAY CACHE PERFORMANCE RESULT: PASS (0 failures)` |
| `python3 tests/run_card_display_mutations.py` | `CARD DISPLAY MUTATION RESULT: PASS (17 cases, 0 survivors)`; both new guards rejected by assertions |
| `tests/card_legibility_test.gd -- --context-smoke` | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 625 checks, 0 failures)` |
| Same entry, `--reading-layouts` | `CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)` |
| Same entry, `--focused-shared` | `CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)` |
| `tests/card_display_overrides_probe.gd -- --plan` | `CARD DISPLAY PROOF PLAN: PASS (0 failures)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 tests/test_test_registration_audit.py` | `Ran 32 tests` / `OK` |

Headless logs: `proof/card-02/feedback2/{overrides,unmodified,performance,context-smoke,reading-layouts,focused-shared,proof-plan}.log`. Timing data: `proof/card-02/feedback2/performance.json`. Mutation evidence: `proof/card-02/mutations/{baseline.log,summary.json,missing_room_element_input.log,frozen_max_health.log}` and the other fifteen case logs. The existing macOS certificate diagnostic and exit-time ObjectDB/resource warnings remain visible; final non-mutated test exit codes are zero, with no script errors. `git diff --check` also exits zero.

## Measurements

All rows use 25 samples; values are median / maximum milliseconds.

| Cards | Definitions | Visible Health 13–23/24, unchanged text | General refresh | Hidden Health | Pile signature | Visible Health 12 ↔ 24/24, changed text (exempt) |
|---:|---|---:|---:|---:|---:|---:|
| 20 | duplicate | 0.052 / 0.076 | 0.005 / 0.009 | 0.017 / 0.030 | 0.007 / 0.018 | 7.984 / 9.411 |
| 20 | unique | 0.076 / 0.103 | 0.006 / 0.008 | 0.018 / 0.028 | 0.019 / 0.033 | 8.169 / 14.573 |
| 60 | duplicate | 0.121 / 0.178 | 0.005 / 0.008 | 0.028 / 0.045 | 0.008 / 0.016 | 25.306 / 26.588 |
| 60 | unique | 0.198 / 0.303 | 0.006 / 0.008 | 0.029 / 0.048 | 0.052 / 0.089 | 32.857 / 43.626 |

The 60-unique unchanged-text case records `extra_projections=0 display_signals=0`. The previous 77.272 ms real-change maximum remains documented in `card_02_feedback_1.md`; this round reports its real-change cost separately rather than counting it toward the unchanged-text budget. No deferred face updates or altered visual timing were introduced.

## Proof for the design owner

The headless proof plan retains the same six expected faces and text as the previous round. This round changes invalidation and adds tests, with no intended rendered text change. No new capture was attempted in the worker's window-server-free sandbox. If the director needs a fresh capture, run at 1920×1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-02 && python3 tools/visual_probe_runner.py --task-id card-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/card_display_overrides.json --result-manifest /private/tmp/labyrinth-inspection-manifests/card-02-feedback-2-render-v1.json tests/card_display_overrides_probe.gd
```

The probe prints absolute paths for `user://card_02_<ticks>/{hand,deck,campfire,scavenger,bloodglass_full,bloodglass_injured}.png`; the validated manifest records those paths. It uses real fixtures and production builders.

## TODO_DESIGN, chosen defaults and open issues

No TODO_DESIGN placeholders or player-facing defaults were added. The new internal default is a 512-entry retained-definition cache limit (`DEFINITION_LIMIT`); the existing eight-context limit and 25 timing samples remain. Test-only Health values are the director's requested fixtures; the room test uses the existing deterministic fixture seed and Frostbolt. No open implementation issue is known. Renderer inspection remains with the design owner under the supplied workflow.
