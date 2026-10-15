# ux-03 implementation handoff

Changes are uncommitted on `codex/ux-03`. No branches, task queue, protected design data, art, audio, fonts, gameplay values, analytics or saves were changed. No peer review or windowed execution was performed.

## Acceptance / proof contract

Risk: **high** (shared runtime UI). Task metadata, commits, peer review, inspection fixture and publication belong to the design owner under the supplied workflow split.

1. **Glossary data:** 142 entries with `id`, `name`, `icon`, `definition`, and `aliases`. The 110 original icon/keyword definitions are copied verbatim from `ActionIconLibrary.KEYWORDS`; 30 skill definitions come from `data/skills.json`. Moltshards uses the existing no-shard tooltip from `scripts/dialogue_engine.gd`. Skill Point now uses the name and exact definition supplied in director feedback 1: “Earned as you level up. Spend them on skills in the Character menu.” Aliases preserve existing action aliases and status spellings. Plain-text matching uses authored keyword spelling so ordinary verbs do not become unrelated mechanic panels. Element and surface identities remain distinct; ambiguous plain `Fire`/`Ice` names require explicit icon tokens (current relic descriptions already use them).
2. **Card definitions:** `ActionIconLibrary.description()` and its formatted Dive path now load canonical keyword copy from the glossary. Contextual token overrides and modifier explanations remain intact. The brief's `card_keyword_rules.gd` contains mechanics, not tooltip definitions, so it is untouched. The immutable before-copy and before-stack fixtures are taken from base `847a2d750`; the old stack's empty typed-array initializers were normalized for Windows without changing rendering. The probe compares whole native RGBA images of a focused Quick Stab card and the old/new stacks.
3. **Relics:** the existing stack binds to both production treasure choices and owned HUD badges, with distinct concepts in first appearance order. Treasure choices show glossary panels only; owned badges retain the name/description panel first. The explicit “all if ≤ 6, otherwise first 6” clause governs the contradictory four/six wording. No more-count text is added. The unmarked word “Consume” in Briar Winch is ambiguous between item consumption and surface removal; `TODO_DESIGN_GLOSSARY_CONSUME_PROSE` leaves that word unresolved rather than showing the wrong item definition. Its explicit Rubble, Push and Pull tokens still resolve. Hover, keyboard focus and controller candidate focus use the same stack. Live counters remain in the description; native duplicate popups are suppressed without deleting `tooltip_text` used for controller discovery. Choice stacks top-align on the outer side with a 12 px gap when there is panel-width + 24 px of room and the column fits above the 24 px bottom margin. Middle choices and side fallbacks flow below the whole card row with a 12 px gap. Flow uses up to three panels per row, natural panel widths, 12 px gaps in both directions, first appearance order, and horizontal centering clamped to 24 px screen margins. When that block crosses the bottom margin, it uses up to four panels per row. Owned stacks start 8 px below the icon and align left, clamped horizontally. All current owned relics fit at 1920×1080 in headless layout checks. The exhaustive production-card probe checks all 112 relics at all three positions, including all panel bounds and order. All 336 cases fit on screen; two final four-column cases have a fractional bottom-margin shortfall documented below. Card placement remains its original behavior in the pixel fixture.
4. **Inline hover:** the actual renderer is `scripts/inline_icon_text.gd`, not the brief's filename. Its existing image hit testing now supplies the definition and `UiTooltipPanel` for labels already accepting mouse input. Noninteractive labels stay noninteractive; their relic owner supplies the stack. Existing nested card/board token hover also reads the glossary through `ActionIconLibrary`. Glossary panel bodies support BBCode and inline images using the existing type sizes and panel styling.
5. **Coverage:** the focused runner checks every icon registry entry, aliases, all card token rows, recursive card/relic/skill/enemy/grimoire text, and literal icon tokens across production status/intent scripts. It prints unresolved-definition TODO count. It also tests verbatim card copy, live glossary sourcing, semantic overrides, deduplication/order/cap, owner lifetime, input routing, BBCode, and current relic bounds.

## Files

- `data/glossary.json`: canonical seed data.
- `scripts/glossary.gd`: cached loader, aliases, text lookup and ordering.
- `scripts/action_icon_library.gd`: canonical definition lookup, retaining the compatibility registry and its legacy source assertions.
- `scripts/card_focus_tooltip_stack.gd`: owner binding, relic panels, shared positioning and BBCode body support.
- `scripts/inline_icon_text.gd`: existing inline hover definition/panel hookup and BBCode-aware appending.
- `scripts/run_scene.gd`: **exactly four changed/added lines in the final file**: 11062 (owned badge constructor), 11152 (bind owned badge), 16373 (choice constructor), 16391 (bind choice). No other run-scene lines were edited.
- `tests/glossary_card_copy_before.json`, `tests/glossary_card_stack_before.gd`: immutable pre-change pixel/copy oracle.
- `tests/glossary_fixture.gd`: deterministic treasure fixture shared by tests and probe.
- `tests/glossary_test.gd`: focused coverage and live integration tests.
- `tests/glossary_tooltip_probe.gd`, `tests/glossary_tooltip_probe_contract.json`: real input capture scenarios and semantic/image contract.
- `tests/glossary_handoff.md`: this contract and handoff.

## Verification commands

All Godot runs use the required task runner. Logs are under `/private/tmp/ux-03-*.log`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_tooltip_probe.gd -- --verify-logic
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tests/test_icon_identity_policy.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tools/godot_task_runner.py --task-id ux-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Current results (director feedback 2)

- `/private/tmp/ux-03-flow-glossary.log`: `GLOSSARY TEST RESULT: PASS (3069 checks, 0 failures)`; `GLOSSARY COVERAGE: 142 entries, 438 tokens checked`; `GLOSSARY TODO_DESIGN: 0 []` plus the known Consume prose TODO.
- `/private/tmp/ux-03-flow-logic-final.log`: `GLOSSARY ALL-RELIC CHOICE FIT: PASS (112 relics, 336 positions, 1920x1080)`; `GLOSSARY CHOICE LAYOUTS: column=222, three=109, four=5`; `GLOSSARY PROBE LOGIC RESULT: PASS`. Exit 0; headless mode creates no images.
- `/private/tmp/ux-03-flow-ui.log`: `Ran 25 tests in 2.567s`; `OK`.
- `/private/tmp/ux-03-flow-full-godot.log`: `FULL SUITE RUNTIME: 702.587 seconds (budget 900 seconds)`; `TEST RESULT: PASS`. Exit 0.
- Most recent full Python run (before feedback 2): `/private/tmp/ux-03-feedback-python.log`, `Ran 397 tests in 248.183s`; `OK (skipped=61)`. Icon identity also passed: 7 tests, `OK`. Feedback 2 changes no identities, assets, Python tools or dependencies.
- `git diff --check`: exit 0.

The layout TODO is resolved by director feedback 2 and removed from runtime and coverage. Tests force the four-column fallback using unequal panel heights, verify its return to an outer column, and cover the exact side-clearance threshold. The probe builds each relic's actual production card three times, then validates every slot. It asserts all panels remain on screen, natural panel sizes, row gaps/order, outer-column eligibility, four-column fallback eligibility, and no card/banner/owner overlap. Owned-tray checks and card pixel comparison remain intact.

**Fractional margin observation:** Witchglass Lantern and Hollow Puppet in the middle slot use the prescribed four-column fallback, ending at y=1056.6288 and leaving **23.3712 px** below. Both are fully on screen. Their normal panel heights plus the required 12 px gap cannot yield a full 24 px bottom margin with the current fractional card-row position. The probe reports this exact clearance explicitly; it retains the final fallback's on-screen assertion. Panel dimensions, card-row placement and gaps are unchanged.

The Godot logs include the existing macOS CA-certificate diagnostics and scene-teardown warnings. No existing master assertions were rewritten. No windowed execution, peer review or Git publication was performed.

## Proof for the design owner

The sandbox has no window-server access. No windowed execution was attempted by this worker. The director reviewed the initial captures and confirmed card pixel identity, but those captures failed native size checks. The revised probe renders and captures a fixed 1920×1080 SubViewport with `UPDATE_ALWAYS`, after `frame_post_draw`; fresh windowed proof remains pending. Run:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-03 && python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-03-glossary-visual-proof.json
```

The runner uses an isolated `user://`; the script prints its absolute `GLOSSARY_PROOF_DIR` and each `GLOSSARY_CAPTURE` path. Under that directory expect:

- `relic_choice_hover.png`, `relic_choice_keyboard.png`, `relic_choice_controller.png`
- `relic_choice_middle.png`, `relic_choice_right.png`
- `relic_choice_flow_four.png`, `relic_choice_outer_flow.png`
- `owned_relic_hover.png`, `owned_relic_keyboard.png`, `owned_relic_controller.png`
- `card_keywords_before.png`, `card_keywords_after.png`

The twelve captures must be native 1920×1080 at 100% scale. The card pair must print `CARD KEYWORD PIXEL IDENTITY: PASS (exact RGBA equality)`. The probe refuses ordinary headless capture and never fabricates/resizes images. `--verify-logic` checks all scenarios headlessly and produces no images. The design owner still needs to inspect the actual images and arrange independent UI identity review. The brief delegates inspection-fixture preparation to the design owner and does not request a fixture command for this unit.

## TODO_DESIGN


- `TODO_DESIGN_GLOSSARY_CONSUME_PROSE` — the capitalized, unmarked “Consume” in Briar Winch requires a design-owned concept token to distinguish surface removal from the Consume item keyword. The script excludes this ambiguous prose word; explicit `@icon(consume)` still resolves.

## Chosen defaults

Only test/proof values were chosen:

- `Fixture.SEED = 7321`; proof offers/owned relics are Iron Lung, Brightglass Lens and Pilgrim Boots; focused card is Quick Stab. All reuse production data/art.
- `REVEAL_STEPS = 160`, `REVEAL_POLL_SECONDS = 0.025`; card settling `CARD_SETTLE_SECONDS = 0.5` seconds. Frame settling uses two frames for tests and three for proof. The exhaustive 336-case native probe uses a 120-second process timeout for its production-scene rebuilds and frame settling; the startup watchdog is unchanged.
- Proof card position `(700,320)` and size `(250,352)`; parked pointer `(8,8)`; headless tray owner position `(1800,80)`, size `(60,60)`; synthetic choice cards at x=`400,800,1200`, y=`200`, size `(100,100)`. The side-clearance test moves the left card to exactly panel-width + 24 px, then 1 px inward. The four-column test uses y=600 and two 200 px minimum-height panels. Fallback captures use Witchglass Lantern and Breaking Wheel.
- Isolated progression/run/settings filenames and `user://glossary_tooltip_probe` output directory. Frozen card presentation prevents animation time from changing the before/after comparison. The 1920×1080 resolution, 100% scale, six-panel limit, styles, margins, and spacing come from the brief, director feedback 1/2, or existing components.
- Debug strings/tokens for lookup-source, overlap, seven-concept cap and BBCode tests; semantic capture region `(18,18,1884,1044)` with minimum luma range 16 and standard deviation 3.
- The full-suite timeout is 900 seconds, matching the repository's documented suite budget.
