# ux-02 implementation handoff

All changes are uncommitted and confined to the three owned new tool/probe files and this staged text directory. No production copy, data, UI, assets, analytics, saves, assertions or queue files were changed. Commit, peer review, inspection preparation and publication remain with the design owner as instructed.

## Numbered requirements

1. **String inventory:** [inventory.json](inventory.json) and [inventory.csv](inventory.csv) contain 6,136 source/derived records with stable ids, surfaces, exact text/markup, source pointers or locations, format operands, word counts, number policies and presentation locations. [coverage.json](coverage.json) preserves source hashes, excluded literals and dynamic display expressions. Extraction is conservative: legacy definitions and conditional fallbacks remain identifiable; unbounded state and upgrade combinations stay parameterized.
2. **Icon inventory:** [inventory_icons.json](inventory_icons.json) contains 420 icon records with art paths, code concepts, per-surface pointer/focus coverage, current tooltip definitions/templates and missing-definition flags. Relic findings appear first. Owned relic badges have a parent name/description tooltip; relic choices and inline symbols lack independent concept definitions. Four registry keys (`eclipse`, `raise_cover`, `reclaim_cover`, `surface_convert`) have no visible consumer identified and are retained without invented surface claims.
3. **Glossary seed:** [glossary_seed.json](glossary_seed.json) contains 444 concepts, verbatim definitions and source-linked naming candidates. The Time and Chilled discrepancies cite rules code. Shared namespaces, chapter headings and capitalization differences are marked for review rather than all being asserted as mistakes.
4. **Capture probe:** [probe](../../../../tests/text_audit_capture_probe.gd) and [contract](../../../../tests/text_audit_capture_probe_contract.json) cover 28 numbered fixtures, including all twelve required cases. Headless semantic validation passes at 1920×1080, 100% scale. [captures.md](captures.md) maps each capture to inventory ids; [capture_index.json](capture_index.json) expands the surface index. [Headless observations](proof/observations_headless.json) record 1,064 text nodes, including 613 with verbatim inventory-source candidates. Repeated copy retains all candidates; dynamic/transformed text is marked. These observations are not PNG or renderer proof. Actual captures and visual inspection are pending the design owner's windowed run.
5. **Metrics:** [summary.md](summary.md) contains counts and top fifteen strings per surface, the two tooltip records over 35 words, card-font line measurements, and missing/partial icon tooltip counts per surface. Five prose-face cards exceed three shaped lines in at least one measured profile. Action-row cards are separated from prose-fit diagnostics. [runtime.json](runtime.json) retains all production-helper results and measurements.

## Observed verification

| Command | Exact result lines | Evidence |
| --- | --- | --- |
| `python3 tools/text_audit.py --check` | `TEXT AUDIT CHECK RESULT: PASS (6136 strings; 10 artifacts; unknown sources: 0)` | [check.log](proof/check.log) |
| `python3 tools/text_audit.py --self-test` | `Ran 12 tests in 0.003s` / `OK` / `TEXT AUDIT SELF-TEST RESULT: PASS` | [self-test.log](proof/self-test.log) |
| `python3 tools/godot_task_runner.py --task-id ux-02 --timeout 300 --stream -- godot --headless --path . --script tests/text_audit_capture_probe.gd -- --validate-only` | `TEXT AUDIT CAPTURE HEADLESS VALIDATION RESULT: PASS (28 fixtures)` | [probe.log](proof/probe.log), [observations_headless.json](proof/observations_headless.json) |
| `python3 tools/godot_task_runner.py --task-id ux-02 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd` | `FULL SUITE RUNTIME: 684.300 seconds (budget 900 seconds)` / `TEST RESULT: PASS` | [godot-suite.log](proof/godot-suite.log) |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | `Ran 397 tests in 220.448s` / `OK (skipped=61)` | [python-suite.log](proof/python-suite.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 2.955s` / `OK` | [ui-lint.log](proof/ui-lint.log) |

The full suites ran before the final audit/probe-only refinements. The final version passed the audit self-tests, rebuild/check and 28-fixture headless validation afterward. `git diff --check` passed; an explicit whitespace check also passed for the new source files, which are untracked and therefore outside `git diff`.

Godot logs contain non-fatal macOS certificate diagnostics, resource/ObjectDB exit diagnostics and diagnostics from negative-path fixtures. The full suite still printed `TEST RESULT: PASS`; no existing assertion was rewritten. The latest probe printed its 28-fixture PASS and a subsequent ObjectDB exit warning. The windowed proof must still be inspected.

## TODO_DESIGN and chosen defaults

No `TODO_DESIGN` placeholders were needed; no player-visible choice was introduced.

All chosen defaults are named tool/probe constants: export timeout 180 seconds; source digest length 12; fixture seed 321; shop seed 73491, 720 Embers and the existing Scavenger probe stock; hand `quick_stab`, `bone_dart`, `sidestep_slash`; relics `ember_lens`, `pilgrim_boots`, `mirror_shard`; 2 status stacks; measurement hand sizes 3/8; disabled-event Embers 0; 600 readiness frames; 5 settling frames; 1.2-second presentation wait; 0.6-second native-tooltip wait; 0.025-second treasure polling; proof tooltip position (1200,350), 24-pixel margin and z-index 4095. Reporting thresholds and 1920×1080/100% are mandated by the brief. None changes production behavior.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-02 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/text_audit_capture_probe_contract.json --result-manifest /private/tmp/ux-02-text-captures.json tests/text_audit_capture_probe.gd --task-id ux-02
```

PNG destination: `user://probes/text_audit/1920x1080/01_card_hand.png` through the 28 named files in [captures.md](captures.md), under the runner's unique HOME. The absolute output directory is printed; `/private/tmp/ux-02-text-captures.json` records capture paths. No PNG has been produced or inspected in this sandbox, and no windowed run was attempted. No `inspection_fixture.py` command is required by this inventory-only brief.

Remaining work belongs to the design owner: execute and inspect windowed captures, decide rewrites using the reported tooltip/naming/rules findings, and perform the assigned review/commit/publication workflow. The audit is source-backed and reproducible; it does not prove every conditional runtime branch was rendered.
