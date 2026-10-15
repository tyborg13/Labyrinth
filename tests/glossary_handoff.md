# ux-03 implementation handoff — director feedback 3

Uncommitted changes on top of `36db709a4`, in the supplied `codex/ux-03` checkout. Per the director's split, this worker performed implementation and headless verification only. Commits, peer review, real-renderer inspection and publication remain with the design owner. No windowed execution was attempted.

Risk: **high**, because the changes touch shared UI input and tooltip rendering. No glossary copy, gameplay values, art, fonts, audio, analytics or save formats changed in this pass.

## Acceptance and implementation

1. **Inline image hit testing.** `InlineIconText` puts the full glossary tooltip in `RichTextLabel.add_image` argument 9 and the label in argument 12 (`alt_text`). The focused test adds the label to the viewport, waits for layout, and calls `get_tooltip(point)` across its image area. Custom tooltip script installation now requires the fourth `apply_to` argument; the two interactive skill-description callers opt in explicitly. Existing scripts are preserved.
2. **Focus origin.** Pointer clicks clear persistent relic focus. Keyboard/controller navigation can retain it, including controller navigation back to an already focused badge. Both tests and the production-scene probe deliver mouse button events, then move away and require the stack to close. Hand-hover `hide_stack()` preserves an actively hovered/focused relic; explicit owner removal or modal opening can force dismissal.
3. **Choice placement.** Eligible outer columns still use their 12 px gap and existing side-clearance rule. Otherwise the stack tries three, then four panels per row below the tallest card. If the four-column block crosses the 24 px bottom margin, it moves above the entire card row, ending 12 px before its top edge, centered on the owner and clamped horizontally to 24 px margins. Only this final fallback may overlap the banner. All card/owner intersections remain forbidden. Placement is cached until owner/row rectangles, viewport or panel minimum sizes change; a new set of panels invalidates it.
4. **Owned placement.** The preferred anchor remains 8 px below the icon. A column that would cross the bottom margin flows its remaining glossary panels to a second column, 12 px to the right and top-aligned; the name/description stays first. The resulting block clamps horizontally and vertically using the existing 18 px safe margin. Panels retain the shared tooltip component, typography and spacing.
5. **Controller callout.** Real `_controller_candidate_for_control` candidates have empty `detail` for glossary owners. The probe routes them through `_controller_set_focus_candidate(candidate, true)`. Its owned fixture uses a connected starting room with dialogue/map closed, asserts a visible analog cursor, and requires empty detail text and no visible detail panel.
6. **Canonical definitions and titles.** Removed all dead `KEYWORDS.description` copies. Action/skill definitions and canonical card titles read the glossary. The three named legacy suites now read definitions from `Glossary`. Focused tests mutate a glossary entry and verify its live card title/body, without comparing current copy to the frozen migration JSON. Missing/blank definitions emit one warning per concept and fall back to a readable label. Unknown explicit icon tokens retain a fallback panel instead of disappearing.
7. **Coverage.** Raw definitions must be nonempty for every glossary/registry entry, rendered card token, authored data token and literal production status/intent icon. This deliberately checks raw data rather than the runtime fallback. Tests also cover missing/blank entries, warning deduplication, mixed card heights, layout cache invalidation, above-row fallback, owned vertical clamping, explicit script opt-in and owner lifetime.

The exhaustive probe rebuilds each of the 112 relics in all three production choice positions and all three owned-tray positions. It runs at **1920×1080**, **1670×1043**, and **1536×864**: **2,016 placement cases** total. Each block/panel must remain on screen, retain panel order/gaps, and satisfy the applicable margin and overlap rules. The old fractional bottom-margin exception is removed.

The 1536×864 case is the logical viewport equivalent of 1920×1080 at 1.25 UI scale. The probe uses that actual SubViewport size with `ui_scale = 1.0`; it does not apply scale a second time. All captures use `UPDATE_ALWAYS` and wait for `RenderingServer.frame_post_draw`.

## Changed files in this pass

- `scripts/inline_icon_text.gd`, `scripts/glossary.gd`, `scripts/action_icon_library.gd`, `scripts/card_focus_tooltip_stack.gd`: tooltip arguments, canonical copy/fallback, input origin and placement.
- `scripts/run_scene.gd`: controller detail suppression, navigation focus preparation, explicit skill-detail opt-in and forced modal dismissal. `scripts/skill_tree_view.gd`: explicit opt-in for its interactive detail label.
- `tests/suites/en02_enemies_suite.gd`, `tests/suites/en03_enemies_suite.gd`, `tests/suites/turn_clock_copy_suite.gd`: glossary access in the requested existing assertions.
- `tests/glossary_test.gd`, `tests/glossary_tooltip_probe.gd`, the three resolution-specific probe contracts, and this handoff.

`tests/glossary_card_copy_before.json` and `tests/glossary_card_stack_before.gd` remain unchanged as migration artifacts from `847a2d750`. The before/after pixel comparison runs **only with `--compare-original-card`**. Default tests/probes do not pin their old text, allowing ux-04 copy changes.

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
python3 -m unittest discover -s tests -p 'test_*.py' -v
git diff --check
```

Current results:

- Final focused tests: **PASS (3,291 checks, 0 failures)** at each resolution, covering 142 entries and 438 tokens; logs `/private/tmp/ux-03-f3-glossary-{1920,1670,1536}.log`.
- All three production-scene logic probes: **PASS**, including all 2,016 placements and actual pointer/keyboard/controller routes. Logs `/private/tmp/ux-03-f3-probe-{1920,1670,1536}.log`. Native probe also ran the optional before-stack construction path headlessly; no pixel comparison is claimed from a headless run.
- Choice layouts (column / three / four): **222 / 109 / 5** at 1920×1080; **218 / 109 / 9** at 1670×1043; **0 / 294 / 42** at 1536×864. Four-column counts include above-row placements.
- Owned second-column cases: **0 / 0 / 9**, respectively.
- UI lint: **25 tests, PASS** (`/private/tmp/ux-03-f3-ui.log`). Icon identity: **7 tests, PASS** (`/private/tmp/ux-03-f3-icons.log`).
- Python suite: **397 tests, PASS (61 skipped)** in 246.756 seconds (`/private/tmp/ux-03-f3-python.log`).
- Final full Godot suite: **PASS** in **746.906 seconds** (900-second budget), exit 0 (`/private/tmp/ux-03-f3-full-godot-final.log`).
- `git diff --check`: PASS.

The focused tests intentionally emit one warning for each injected missing-definition fixture. Existing full-suite calls for retired `burn`/`poison` keys also exercise the new fallback warning. The usual macOS certificate diagnostics and teardown warnings remain visible in the logs.

## Windowed proof commands for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/ux-03`. These commands have **not** been run by this worker. The original 1920×1080 card identity proof is explicitly opt-in here; omit that flag for future glossary-copy work.

```bash
python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-03-f3-visual-1920.json -- --size=1920x1080 --compare-original-card

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1670x1043 --proof-contract tests/glossary_tooltip_probe_contract_1670x1043.json --result-manifest /private/tmp/ux-03-f3-visual-1670.json -- --size=1670x1043

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1536x864 --proof-contract tests/glossary_tooltip_probe_contract_1536x864.json --result-manifest /private/tmp/ux-03-f3-visual-1536.json -- --size=1536x864
```

The isolated output directory is printed as `GLOSSARY_PROOF_DIR`; each image path is printed as `GLOSSARY_CAPTURE`. Expect twelve normal captures:

- `relic_choice_hover`, `relic_choice_keyboard`, `relic_choice_controller`, `relic_choice_middle`, `relic_choice_right`, `relic_choice_flow_four`, `relic_choice_outer_flow`.
- `owned_relic_hover`, `owned_relic_keyboard`, `owned_relic_controller`, `owned_relic_flow`.
- `card_keywords_after`.

Each filename ends in `.png`. `--compare-original-card` adds `card_keywords_before.png` and requires `CARD KEYWORD PIXEL IDENTITY: PASS (exact RGBA equality)`. The panel named `relic_choice_flow_four` can sit above the row under the new final fallback; `owned_relic_flow` captures Breaking Wheel, which uses two columns at 1536×864. Captures must match the requested native dimensions. No images are fabricated or resized. Fresh image inspection and independent UI identity review remain with the design owner.

## Known design item and proof defaults

`TODO_DESIGN_GLOSSARY_CONSUME_PROSE` remains: the unmarked “Consume” in Briar Winch is ambiguous between surface removal and the item keyword. The script does not attach the item definition to that prose; explicit `@icon(consume)` still resolves.

The existing deterministic seed (7321), Iron Lung/Brightglass Lens/Pilgrim Boots input fixtures, Quick Stab card, shared UI styles, six-concept cap and reveal polling remain. Proof-only fixtures choose card/owner positions, unequal panel/card heights, synthetic sentinel text and the three required viewport sizes. The 120-second visual timeout accommodates all 672 placement checks per invocation; the startup watchdog is unchanged. The full-suite budget remains 900 seconds.
