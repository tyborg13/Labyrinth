# card-02 implementation handoff

Changes remain uncommitted on `codex/card-02`. No branch, queue, card data, assets, saves, rules, balance, analytics, or layout was changed. The design owner retains commit, review, inspection-fixture preparation, and publication.

## Requirement 1 and the recorded task acceptance criterion

The hand's action/keyword/damage/Tempo simulation is extracted unchanged into `scripts/card_display_overrides.gd`. `RunScene._card_widget_display` delegates to it. The optional definition carries the authored upgraded flag and preview numbers; previews resolve that definition again when the run changes. Definition-level transformations still come from `GameData.card_def_for_progression`.

The shared application computes the display arguments, updates the definition, and calls `set_display_overrides`. When the definition already renders the exact effective rows and needs no Time surcharge, it retains the old empty overrides. This preserves the existing no-modifier representation, rendered text, summary-row bytes, and staged reward equivalence.

Covered screens: deck/current-deck card inspection; campfire removal and retained upgrade current/preview cards; purge picker and confirmation; Scavenger offer, sell, receipt, and retained detail cards; opening boon spell choices and their live glossary stack; Graftwright source/target cards and exact-rules inspection.

Additional ID-built surfaces found and covered: ordinary/event rewards; combat draw/discard/exhaust piles, including pooled cards; Character and Grimoire card/equipment previews; equipment-granted card tooltips; merchant and battlefield item-pickup tooltips; out-of-combat purge/reward animation proxies. Existing combat hand/proxy behavior continues through its original wrapper. The Chronicle retains its historical definition snapshots rather than being rebound to a live run.

## Requirement 2

Bound card faces refresh at `RunScene._refresh_ui_finish`, using combat state during combat and current run state elsewhere. Each refresh preserves the card's existing interaction flags and geometry. Scavenger configuration also refreshes retained detail cards even when the selected ID does not change. Graftwright's existing configuration rebuild now uses the shared projection. Open boon tooltips listen to effective card changes. Pending upgrade previews retain their option while resolving fresh run modifiers.

The focused test compares effective rows, rendered rich-text/label bytes, and glossary entries against the hand. It removes/restores relics without replacing the retained faces; tests Scavenger detail identity; exercises actual Graftwright and boon inspections; checks unmodified bytes and source-state immutability; and uses Bloodglass Knife to exercise runtime damage projection on upgraded previews. Mutations omit each production binding, the live refresh, or Graftwright's rules projection in a disposable copy.

## Files changed

Runtime:

- `scripts/card_display_overrides.gd` — shared projection, binding, refresh, and text-only inspection.
- `scripts/card_widget.gd` — definition-only update, effective-row accessor, display-change signal.
- `scripts/run_scene.gd` — hand delegation, run refresh, rewards, piles, upgrades, preview state, and out-of-combat proxies.
- `scripts/pile_dialog_view.gd`, `scripts/magic_purge_confirmation.gd` — deck/removal/purge faces.
- `scripts/scavenger_shop_view.gd`, `scripts/graftwright_view.gd` — NPC card views and inspection.
- `scripts/opening_boon_overlay.gd`, `scripts/opening_boon_inspection.gd` — boon faces and tooltips.
- `scripts/item_preview_builders.gd` — live run previews; historical snapshots remain historical.

Tests and proof:

- `tests/card_display_overrides_test.gd`, `tests/helpers/card_display_fixture.gd`.
- `tests/run_card_display_mutations.py`.
- `tests/card_display_overrides_probe.gd`, `tests/proof_contracts/card_display_overrides.json`.
- `tests/helpers/card_legibility_audit.gd`, `tests/helpers/card_legibility_contexts.gd`, `tests/helpers/card_legibility_sources.gd` — updated production provenance and exact-rules measurement for the changed Graftwright projection; existing hidden/empty/duplicate-body assertions remain intact.
- `tests/headless_test_programs.json` — focused test and headless proof-plan registration.
- `tests/card_02_handoff.md` — this handoff.

## Tests and probes run

All Godot entries below were invoked through `python3 tools/godot_task_runner.py --task-id card-02 --stream -- godot --headless --path . --script <entry>` with any listed arguments after `--`. The full Godot/Python suites were not run, per the unit brief.

| Entry | Observed result |
|---|---|
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (192 checks, 0 failures)` |
| `python3 tests/run_card_display_mutations.py` | `CARD DISPLAY MUTATION RESULT: PASS (12 cases, 0 survivors)` |
| `tests/card_keywords_test.gd` | `CARD KEYWORDS TEST RESULT: PASS` |
| `tests/card_legibility_test.gd -- --focused-shared` | `CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: PASS (385 checks, 0 failures)` |
| `tests/card_legibility_test.gd -- --context-smoke` | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 32 contexts, 96 samples, 625 checks, 0 failures)` |
| `tests/card_legibility_test.gd -- --reading-layouts` | `CARD READING LAYOUT RESULT: PASS (352 checks, 0 failures)` |
| `tests/card_legibility_test.gd -- --negative-fixtures` | `CARD LEGIBILITY NEGATIVE FIXTURES: PASS (26 checks, 0 failures)` |
| `tests/staged_reward_choices_equivalence_test.gd` | `STAGED REWARD CHOICES RESULT: {"cases":19,"differences":0,"errors":[],"native":false,"orphans":0}` |
| `tests/card_proxy_pool_test.gd` | `TEST RESULT: PASS — bounded card proxy reuse and reset semantics` |
| `tests/scavenger_regression_test.gd` | `SCAVENGER / MERCHANT / LOADOUT REGRESSION: PASS` |
| `tests/opening_boon_test.gd` | `OPENING BOON TEST RESULT: PASS` and `TEST RESULT: PASS` |
| `tests/card_display_overrides_probe.gd -- --plan` | `CARD DISPLAY PROOF PLAN: PASS (0 failures)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 tests/test_test_registration_audit.py` | `Ran 32 tests` / `OK` |
| `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/card-02-python-resource-audit` | `ISOLATION AUDIT: 227 modules; /private/tmp/card-02-python-resource-audit/isolation-audit.md` |
| In-memory Python compile of `tests/run_card_display_mutations.py` | `CARD DISPLAY MUTATION PYTHON SYNTAX: PASS` |
| `git diff --check` | No output; exit 0. |

Mutation evidence is in `proof/card-02/mutations/{baseline.log,summary.json,<case>.log}`. Existing legibility/layout outputs are in `tests/pt13_03/`; these are ignored proof outputs, not source changes. The audit report is `/private/tmp/card-02-python-resource-audit/isolation-audit.md`.

Headless Godot logs include the environment's `get_system_ca_certificates` diagnostic. Some existing legibility/loadout programs also report exit-time ObjectDB/resource leaks while returning PASS and exit 0. No windowed renderer was attempted. `python3 -m py_compile tests/run_card_display_mutations.py` could not create the default macOS cache directory: `PermissionError: [Errno 1] Operation not permitted: /Users/borgerding/Library/Caches/com.apple.python/Users/borgerding/workspace/Labyrinth.worktrees/card-02`. The same source passed an in-memory Python compile without filesystem cache writes; the mutation runner also executed successfully.

## Proof for the design owner

Run the real-renderer probe once at 1920x1080, 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/card-02 && python3 tools/visual_probe_runner.py --task-id card-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/card_display_overrides.json --result-manifest /private/tmp/labyrinth-inspection-manifests/card-02-render-20261027-v1.json tests/card_display_overrides_probe.gd
```

It emits fresh `hand.png`, `deck.png`, `campfire.png`, and `scavenger.png` beneath a unique `user://card_02_<ticks>/` directory, prints each absolute path, and records them in the validated result manifest. It checks the effective rows and Exhaust transformation before capturing. Scenes use generated production combat/campfire/Scavenger rooms; no synthetic board is built. The headless `--plan` already passed the same semantic setup.

The current catalog's `nail_bomb` is named **Shrapnel Bomb**. Quartermaster's Ledger is the existing **relic** that supplies Consume → Exhaust; Alchemist's Retort supplies its numeric modification. No equipment effect was invented. As an item, Nail Bomb cannot be purged or receive the retained spell upgrade; its deck and campfire captures use the production Character item-inspection card. Upgrade preview proof is covered headlessly using Quick Stab and Bloodglass Knife. The owner should inspect those screenshot contexts with this catalog constraint in mind.

Renderer capture inspection, independent visual judging, inspection-save preparation, peer review, and full integration suites remain with the design owner. The brief did not request a specific `tools/inspection_fixture.py` invocation; no inspection save was created by this worker.

## TODO_DESIGN placeholders

None added. No missing player-facing values were chosen.

## Chosen defaults

Only test/proof configuration was chosen:

- `FIXTURE_SEED = 1016`; real combat seed search `1 .. COMBAT_SEED_LIMIT - 1` with `COMBAT_SEED_LIMIT = 120` to find a legal opening hand containing the equipped item.
- `FIXTURE_CARD = nail_bomb`; `FIXTURE_RELICS = [quartermasters_ledger, alchemists_retort]`; existing catalog stock in `SHOP_STOCK`.
- `TEST_CARDS = [nail_bomb, quick_stab]`; `UPGRADE_RELICS = [bloodglass_knife]`; `UPGRADE_PLAYER = {hp: 1, max_hp: 10, block: 0, stoneskin: 0}` to activate its existing conditional bonus.
- `TEST_VIEW_SIZE = (250, 352)` and `TEST_GRAFT_POSITION = (0, 0)` for factory checks.
- `BOOT_SETTLE_SECONDS = 0.4`, probe `SETTLE_SECONDS = 0.4`, `VIEWPORT_SIZE = (1920, 1080)`, `SCALE = 1.0`; reduced motion for deterministic proof setup.
- Mutation `TIMEOUT_SECONDS = 60`, temporary copied project, isolated runner HOME, and task-owned proof output directory.

## Open issues

Windowed captures and their visual inspection remain unperformed because this worker has no window-server access. The current-catalog relic/item/name differences from the brief's example are documented above. No unresolved implementation or headless-test failure is known after the fixes recorded here.
