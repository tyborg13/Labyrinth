# ux-03 implementation handoff — round 4

Uncommitted changes on top of `723f52579`, in the supplied `codex/ux-03` checkout. This worker performed implementation and headless verification only, as directed. Commits, peer review, real-renderer inspection and publication remain with the design owner. No windowed execution was attempted.

Risk: **high**, because the changes touch shared tooltip input and placement. Acceptance is the eight round-4 review items below, with fresh focused tests and production-scene probe logic at all three requested sizes, UI lint, icon identity and the full Godot suite.

## Acceptance and implementation

1. **Card structure.** `_tooltip_entry_copy` again returns `"\n".join(body_lines)` without adding a label to an empty body. `tests/glossary_card_structure_before.json` records the actual pre-glossary `847a2d750` ActionIconLibrary output for all 309 current cards: ordered panel icons and body-line counts only. The coverage suite compares every card, including leading Time/Rite panels. No title or description text is pinned by this fixture.
2. **TopBar protection.** Eligible outer columns retain their existing side-clearance rule. The fallback tries three, four, then five columns below the entire row. A candidate must fit the horizontal safe margins. If no below-row layout fits, the last width-fitting layout moves above the row, with its top at least `TopBar.bottom + 12` and the viewport's 24 px top margin. The live TopBar control is passed through `bind_relic`, and its rect participates in layout-cache invalidation. Impossible fits preserve panel dimensions and placement, set `glossary_choice_overflow`, and emit a warning. Every choice probe checks TopBar exclusion, including reported overflow cases.
3. **Wrapped owned tray.** `bind_relic` receives the live tray control. Owned stacks anchor at `max(icon.bottom, tray.bottom) + 8`, retaining the existing second-column flow and viewport clamping. The probe creates 15 distinct relics in five columns and actually hovers indices 0, 4, 9 and 14. Each stack must fit on screen and avoid every tray badge. Tray geometry also invalidates the layout cache.
4. **Opt-in callers.** `DragonRewardRules` explicitly requests the styled inline glossary tooltip; the live builder is exercised in the focused tests. The mouse-ignoring SkillTreeView detail label no longer requests the no-op script installation.
5. **Shared coverage.** `tests/suites/glossary_coverage_suite.gd` now owns raw-definition coverage and the structural card comparison. Both `tests/run_tests.gd` and the focused glossary test invoke it. Coverage includes all 112 glossary entries, 30 skills, registry keys, rendered card tokens, authored data tokens and literal production status/intent tokens (382 scanned tokens). Runtime fallback cannot conceal empty definitions in this check.
6. **One click guard.** A single deferred `_input` guard clears persistent glossary focus after GUI click processing. The owner GUI-input handler and focus-entered suppression are removed. Native focus remains available for Tab traversal. Navigation cancels a pending click clear; `prepare_navigation_focus` can re-pin an already focused owner. Tests exercise actual click-and-leave, click elsewhere, navigation preparation, and all four wheel directions without dismissing a pinned stack.
7. **Skill source.** The 30 actual skill entries have been removed from `glossary.json`; skill icon names and descriptions read `SkillTreeLibrary`, backed by `skills.json`. A live-data mutation test verifies both fields. The 31st `skill_*` entry was `skill_point`, a resource icon with no skill definition; it remains in the glossary, including its existing plural alias. No skill descriptions remain duplicated there.
8. **Lookup cost.** `Glossary._entry` returns a non-copying internal view for `name_for`, `definition` and token matching. Public `lookup` still returns a deep copy, with isolation covered by a test. An alternating, warmed benchmark of 200,000 `ActionIcons.tooltip()` calls over six defined keyword/status keys measured median **1.076 s before / 0.813 s after** versus `723f52579` (about 24% lower time). This is a local measurement, not a timing assertion.

## Reported impossible placement cases

At **1536×864**, Witchglass Lantern and Hollow Puppet cannot fit with the required spacing in any of the three choice positions: **six reported cases**. Their natural four-column block is 1260×293, placed at y=85 after the TopBar ends at y=73. The choice row starts at y=358.326, so the unchanged block extends 19.674 px into the cards (31.674 px beyond the requested 12 px separation). It stays on screen and never intersects the TopBar. This is an explicitly reported impossible fit, not a claim of card exclusion.

Five natural columns require 1578 px, exceeding the 1488 px available inside the 1536 px viewport's safe margins. The implementation therefore retains four columns for the above-row fallback at that size. At the other two sizes, five-column fallback is exercised and no impossible placements are reported. These width handling and Skill Point resource decisions were called out during implementation.

The probe requires an overflow report exactly when the above-row fit is impossible. Only those reported cases relax the card/viewport-fit assertions; TopBar exclusion, above-row anchoring, original panel dimensions, order and gaps remain required. All owned cases, including the wrapped tray, must still fit and avoid every badge.

## Verification

Commands run from this worktree:

```bash
for size in 1920x1080 1670x1043 1536x864; do
  python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_test.gd -- --size="$size"
  python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_tooltip_probe.gd -- --verify-logic --size="$size"
done
python3 tests/test_ui_identity_lint.py
python3 tests/test_icon_identity_policy.py
python3 tools/godot_task_runner.py --task-id ux-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
git diff --check
```

- Focused glossary tests: **PASS, 6,309 checks / 0 failures at each size**. Logs: `/private/tmp/ux-03-r4-focused-{1920,1670,1536}.log`.
- Production probe logic: **PASS at all three sizes**. Each covers 112 relics × three choice positions, 112 relics × three owned positions, plus four wrapped-tray positions: **676 placements per size / 2,028 total**, in addition to the pointer, keyboard and controller fixtures. Logs: `/private/tmp/ux-03-r4-probe-{1920,1670,1536}.log`.
- UI identity lint: **25 tests, PASS**. Icon identity: **7 tests, PASS**. Logs: `/private/tmp/ux-03-r4-ui.log`, `/private/tmp/ux-03-r4-icons.log`.
- Full Godot suite: **PASS**, exit 0, **775.153 seconds** within the 900-second budget; log `/private/tmp/ux-03-r4-full-godot.log`.
- `git diff --check`: **PASS**.

| Logical viewport | Outer column | Three columns | Four columns | Five columns | Reported overflow | Owned two-column cases |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1920×1080 | 222 | 109 | 3 | 2 | 0 | 0 |
| 1670×1043 | 218 | 109 | 3 | 6 | 0 | 0 |
| 1536×864 | 0 | 294 | 42 | 0 | 6 | 9 |

The four/five-column totals include above-row placements. The 1536×864 viewport models 1920×1080 at 1.25 UI scale through logical dimensions; settings remain at 1.0 so scale is not applied twice.

Two negative checks were run sequentially and restored before the full suite:

- Restoring the reviewed empty-body fallback failed **exactly nine cards**: Crosswind, Rockburst, bottled_gale, cyclone_seal, dust_devil, gale_ward, shattered_reflection, unsealed_gale and vortex. Log: `/private/tmp/ux-03-r4-mutant-body.log`.
- Removing the TopBar clamp failed three assertions: the clamped top coordinate, TopBar exclusion, and impossible-fit reporting. Log: `/private/tmp/ux-03-r4-mutant-clamp.log`.

Temporary mutation and benchmark fixtures were removed; the working files contain the fixes. Benchmark log: `/private/tmp/ux-03-r4-lookup-bench.log`. The focused tests intentionally warn for missing-definition fixtures and a synthetic impossible fit. Existing macOS certificate diagnostics and teardown warnings remain visible in logs.

## Windowed proof commands for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/ux-03`. These commands have **not** been run by this worker. The native proof includes the optional original-card pixel comparison; omit that flag for future copy changes.

```bash
python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-03-r4-visual-1920.json -- --size=1920x1080 --compare-original-card

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1670x1043 --proof-contract tests/glossary_tooltip_probe_contract_1670x1043.json --result-manifest /private/tmp/ux-03-r4-visual-1670.json -- --size=1670x1043

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1536x864 --proof-contract tests/glossary_tooltip_probe_contract_1536x864.json --result-manifest /private/tmp/ux-03-r4-visual-1536.json -- --size=1536x864
```

The isolated output directory is printed as `GLOSSARY_PROOF_DIR`; each image path is printed as `GLOSSARY_CAPTURE`. Expect **16 normal captures**:

- `relic_choice_hover`, `relic_choice_keyboard`, `relic_choice_controller`, `relic_choice_middle`, `relic_choice_right`, `relic_choice_flow_four`, `relic_choice_outer_flow`.
- `owned_relic_hover`, `owned_relic_keyboard`, `owned_relic_controller`, `owned_relic_flow`.
- `owned_relic_wrapped_0`, `owned_relic_wrapped_4`, `owned_relic_wrapped_9`, `owned_relic_wrapped_14`.
- `card_keywords_after`.

Each filename ends in `.png`. `--compare-original-card` adds `card_keywords_before.png` and requires `CARD KEYWORD PIXEL IDENTITY: PASS (exact RGBA equality)`. The historical `relic_choice_flow_four` filename captures Witchglass Lantern; its actual column count and above/below placement depend on the viewport. At 1536×864 it shows a reported impossible fit. `owned_relic_flow` captures Breaking Wheel, which uses two columns at 1536×864. All captures use the requested native dimensions, `UPDATE_ALWAYS`, and a `frame_post_draw` wait. Fresh image inspection and independent UI identity review remain with the design owner.

## Changed files and retained artifacts

This round changes `data/glossary.json`; `scripts/action_icon_library.gd`, `scripts/glossary.gd`, `scripts/card_focus_tooltip_stack.gd`, `scripts/run_scene.gd`, `scripts/skill_tree_view.gd`; the focused test, production probe and its three contracts; `tests/run_tests.gd`; and this handoff. It adds `tests/suites/glossary_coverage_suite.gd` and `tests/glossary_card_structure_before.json`.

The existing `glossary_card_copy_before.json` and `glossary_card_stack_before.gd` remain migration artifacts from `847a2d750`, used only by the opt-in pixel comparison. `TODO_DESIGN_GLOSSARY_CONSUME_PROSE` remains: unmarked “Consume” in Briar Winch requires an explicit concept token to disambiguate surface removal from the item keyword. No new art, gameplay rules, save formats or analytics were introduced.
