# card-02 feedback 1 handoff

Correctness findings 1, 3 and 4 are fixed. Finding 2's repeated-refresh and hidden-card costs are fixed, with per-source/card/upgrade deduplication and lazy hidden faces. The broader interpretation of its 2 ms target remains open: reconstructing all 60 visible cards when their text actually changes is still above 2 ms. No visual timing or deferred text update was introduced to conceal that cost.

All changes are uncommitted on `codex/card-02`; no commit, branch change, push, publication, or peer review was performed.

## Findings

1. **Run state normalization.** `card_display_state.gd` translates run Health, status fields, progression, room element and equipment into the shape used by combat previews. An existing combat `player` remains authoritative. The production Scavenger inspects Training Sword's real Quick Stab: Bloodglass Knife reads Melee 6 at 24/24 HP and Melee 13 at 12/24 HP. Inputs contain no injected combat `player`. Active/inactive oracle checks cover the seven conditional bonus kinds plus first-attack bonuses, using a separately constructed canonical combat state.
2. **Refresh work.** `card_display_bindings.gd` caches immutable relevant-state snapshots and shares projections by card/upgrade option. Currency, notices and deck order do not invalidate faces. Health, statuses, relics, gear, upgrades, keyword/Tempo flags and required spatial conditions do. Visible faces update synchronously; hidden faces resolve their newest context on visibility, before drawing. Pile content signatures hash relevant inputs rather than simulating every card copy. Tests verify zero hidden calculations, one calculation for 60 identical faces, one resolver/projection for duplicate upgrade options, and relevant/irrelevant invalidation.
3. **Behavioral guards.** Upgrade refresh now independently resolves the authored option and compares the definition, Time badge and rows; Fencer's Gloves is activated on the second card so the definition actually changes. A real generated combat opens, closes and reopens the same pooled card after hidden relic changes. Shatterline's real Empower Time surcharge is checked in both the returned arguments and the displayed badge/tooltip. All three requested mutations are added, alongside the original twelve. The mutation runner uses three isolated disposable projects at a time, each through the task runner.
4. **Unmodified representation.** The shared action projection retains `tokens_for_guardian_rule` in the base renderer's order. The all-card sweep compares rich-text/label bytes and summary-row bytes against the previous base rendering for all 309 catalog IDs in every ID-built factory, plus current and available upgraded previews. Cinder Trail and Fan the Flames also pass the real hierarchy legibility audit across 32 contexts.

## Focused verification

Godot commands used `python3 tools/godot_task_runner.py --task-id card-02 --stream -- godot --headless --path . --script <entry>`, with any arguments after `--`.

| Entry | Observed final result |
|---|---|
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (304 checks, 0 failures)` |
| Same entry, `--all-unmodified` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (30266 checks, 0 failures)`; 309 catalog cards |
| `python3 tests/run_card_display_mutations.py` | `CARD DISPLAY MUTATION RESULT: PASS (15 cases, 0 survivors)` |
| `tests/card_legibility_test.gd -- --context-smoke` | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 625 checks, 0 failures)` |
| Same entry, `--card-02-trails` | `CARD LEGIBILITY TEST RESULT: PASS (2 definitions, 32 contexts, 64 samples, 559 checks, 0 failures)` |
| Same entry, `--focused-shared` | `CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)` |
| Same entry, `--reading-layouts` | `CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)` |
| `tests/card_display_overrides_probe.gd -- --plan` | `CARD DISPLAY PROOF PLAN: PASS (0 failures)`; includes both production Bloodglass Health cases |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 tests/test_test_registration_audit.py` | `Ran 32 tests` / `OK` |
| `git diff --check` | Exit 0; no output |

Only focused checks ran. No full Godot or Python suite ran. The existing certificate diagnostic and some existing exit-time ObjectDB/resource leak warnings remain visible in logs; they did not produce a script error or nonzero final exit.

Evidence: `proof/card-02/mutations/{baseline.log,summary.json,<case>.log}`, `proof/card-02/feedback1/performance.json`, and the fresh trail audit in `proof/card-02/feedback1/trails/{audit.json,result.md}`. The tracked historical `tests/pt13_03/audit.json` and `result.md` were restored byte-for-byte after copying the new task-specific evidence.

## CPU measurements

The performance program measures 25 samples at 20 and 60 bound cards, with both repeated and distinct card identities. It measures general refresh, unrelated UI changes, hidden Health invalidation, pile signatures, and real visible Health-driven row reconstruction separately. A frame drains queued row controls after each visible-content sample. The 2 ms cache/hidden-work assertions exclude reconstruction; the full visible cost is explicitly reported below and is an unresolved limit, not a passing 2 ms result.

| Cards | Identities | General refresh median / max (ms) | Hidden Health invalidation | Pile signature | All visible Health text changes |
|---:|---|---:|---:|---:|---:|
| 20 | duplicate | 0.006 / 0.008 | 0.019 / 0.094 | 0.008 / 0.026 | 12.633 / 17.166 |
| 20 | unique | 0.006 / 0.008 | 0.013 / 0.099 | 0.023 / 0.182 | 13.779 / 20.691 |
| 60 | duplicate | 0.006 / 0.009 | 0.025 / 0.202 | 0.010 / 0.078 | 43.252 / 61.383 |
| 60 | unique | 0.006 / 0.029 | 0.030 / 0.434 | 0.070 / 0.745 | 65.428 / 77.272 |

Observed performance result: `CARD DISPLAY CACHE PERFORMANCE RESULT: PASS (0 failures)`. Cache, hidden and signature maxima are below 2 ms; the visible-content column is excluded from that assertion and does not meet the requested strict budget.

## Files changed

- `scripts/card_display_state.gd` and `scripts/card_display_bindings.gd` (new).
- `scripts/card_display_overrides.gd` and `scripts/run_scene.gd`.
- `tests/card_display_overrides_test.gd`, `tests/card_display_unmodified_test.gd` (new wrapper), `tests/card_display_performance_test.gd` (new), `tests/helpers/card_display_regressions.gd` (new).
- `tests/helpers/card_display_fixture.gd`, `tests/card_legibility_test.gd`, `tests/headless_test_programs.json`.
- `tests/run_card_display_mutations.py`.
- `tests/card_display_overrides_probe.gd`, `tests/proof_contracts/card_display_overrides.json`.
- `tests/card_02_feedback_1.md` (this report).

## Proof for the design owner

Run once from this worktree at 1920x1080 and 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-02 && python3 tools/visual_probe_runner.py --task-id card-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/card_display_overrides.json --result-manifest /private/tmp/labyrinth-inspection-manifests/card-02-feedback-1-render-v1.json tests/card_display_overrides_probe.gd
```

The probe emits `hand.png`, `deck.png`, `campfire.png`, `scavenger.png`, `bloodglass_full.png`, and `bloodglass_injured.png` under a fresh `user://card_02_<ticks>/` directory. It prints absolute paths and records them in the validated manifest. All states use production rooms and builders; no synthetic board is built. Windowed captures were not attempted by this worker.

## TODO_DESIGN and chosen defaults

No TODO_DESIGN placeholders and no player-facing values were added. New internal defaults are an eight-context bounded cache, 25 timing samples, three independent mutation workers, and test-only 24/24 and 12/24 HP fixtures. Existing proof resolution/scale and native card geometry remain unchanged. Debug-only condition relics are temporary in-memory fixtures and are erased after testing.

## Open issue

The strict 2 ms target is not met if it includes rebuilding every one of 60 visible card controls on a real text change. The cache and hidden-card paths meet that budget; the full-content cost is preserved in the table and JSON rather than hidden by a frame delay. A scope question about that distinction was sent to the director, with no response received during this implementation pass.
