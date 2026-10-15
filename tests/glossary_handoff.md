# ux-03 implementation handoff — round 5

Uncommitted changes on top of `db82e2cfb`, in the supplied `codex/ux-03` checkout. The starting tree was clean. This worker performed implementation and headless verification under the existing unit split; commits, peer review, windowed inspection and publication remain with the design owner. No windowed execution was attempted.

Risk: **high**, because the change affects shared tooltip placement and verifies controller focus routing. Acceptance: all panels avoid the hovered card, including overflow; the short overflow row aligns away from its owner; screen/HUD/margin checks remain unconditional; the permanent suite no longer depends on a frozen card baseline; removing the controller preparation call fails a test; the handoff identifies every cumulative run-scene integration line.

## Implementation

1. **Hovered card protection.** In the reported above-row impossible-fit case, a short last row is right-aligned when the owner is left of the block's centre, and left-aligned otherwise. Panel order, natural dimensions, gaps and TopBar protection are preserved. The live banner boundary is included in the layout cache. An above-row fallback first tries clear space above or below the banner; overlap is reported as impossible only after neither region fits. The probe checks every panel against the hovered card in every choice case, including reported overflow. Viewport enclosure and vertical margins have no overflow exemptions. A non-hovered card intersection is accepted only in a reported impossible fit. The generic bounding box may span empty space over the owner; the actual panels may never cover it.
2. **Permanent versus migration checks.** `_card_structure` and its `glossary_card_structure_before.json` dependency now live only in standalone `tests/glossary_test.gd`. This remains the one-time 309-card migration proof. The permanent `glossary_coverage_suite.gd`, already wired into `tests/run_tests.gd`, retains raw-definition coverage and scans every current card for the independent invariant that a one-line contextual heading has an empty body. It contains no frozen card count, panel order, line-count baseline or text comparison. Currently nine contextual tooltips exercise the invariant.
3. **Controller call site.** The focused live-scene test first opens an owned relic through production controller routing, then clicks elsewhere to clear persistent glossary focus while leaving native focus on the badge. Calling the real `_controller_candidate_for_control` and `_controller_set_focus_candidate(candidate, true)` must re-pin the stack without a fresh `focus_entered` signal. Removing `run_scene.gd:3112–3113` fails this assertion.
4. **Visible regression fixtures.** The windowed probe now captures Witchglass Lantern and Hollow Puppet in both left and right choice positions at each requested size. These four images supplement the existing 16 captures, making the repaired short-row alignment directly inspectable. All three proof contracts require them.

## Above-row fit reports

Round 5's stricter banner rule is implemented: a fitting above-row block avoids the banner. A synthetic test introduces an avoidable banner intersection and verifies that the unchanged block moves above it without an overflow report. For an unavoidable banner intersection, the production probe independently checks that the block cannot fit in either clear vertical region between TopBar and the card row. This prevents treating every banner intersection as automatically permissible.

At **1536×864**, there are **12 reported impossible fits**: Witchglass Lantern, Hollow Puppet, Phoenix Ember and Breaking Wheel, each in all three positions. All panels stay on screen and every hovered card remains clear. The first two relics have the original 1260×293 block at y=85 after the TopBar ends at y=73; their Collision panel now sits away from the owner even though a non-hovered card's top corner may be covered. Phoenix Ember and Breaking Wheel fit above the cards, but their 188 px and 251 px block heights exceed the 146.316 px clear region above the banner, and the 12 px-gap region below the banner has no available height. They retain above-row placement and explicitly report the banner obstruction. Five columns exceed this viewport's horizontal margins, so these layouts retain four.

No impossible fits are reported at 1920×1080 or 1670×1043. Viewport enclosure, TopBar exclusion, panel-versus-owner exclusion and margins are checked without overflow skips at all sizes. Only banner and non-hovered-card intersections have the explicitly permitted impossible-fit exception.

## Exact cumulative run_scene integration lines

These exact locations are verified against `db82e2cfb`. Round 5 extends the binding at line 16393 to include the banner; the other integrations remain unchanged:

| Line(s) | Integration |
| --- | --- |
| 3044 | Empty analog-cursor detail for controls carrying `glossary_relic`. |
| 3112–3113 | Call `prepare_navigation_focus(control)` before `grab_focus()` for a glossary owner. |
| 11064 | Construct owned relic badges as `CardFocusTooltipStack.RelicOwner`. |
| 11154 | Bind owned badges with the live `relic_bar` tray boundary. |
| 11849 | Explicit styled-tooltip opt-in for the interactive skill-status description. |
| 16023 | Explicit styled-tooltip opt-in for `DragonRewardRules`. |
| 16375 | Construct relic-choice cards as `CardFocusTooltipStack.RelicOwner`. |
| 16393 | Bind choice cards with their row, live `top_bar` boundary and, in round 5, `_relic_choice_banner`. |
| 22095 | Force `hide_stack(true)` when opening the large map. |

The controller mutation temporarily removed lines 3112–3113 and restored them byte-for-byte. This round's final `run_scene.gd` diff is only the additional banner argument at line 16393.

## Verification

Commands run from this worktree:

```bash
for size in 1920x1080 1670x1043 1536x864; do
  python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_test.gd -- --size="$size"
  python3 tools/godot_task_runner.py --task-id ux-03 --stream -- godot --headless --path . --script tests/glossary_tooltip_probe.gd -- --verify-logic --size="$size"
done
python3 tests/test_ui_identity_lint.py
python3 tools/godot_task_runner.py --task-id ux-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
git diff --check
```

- Focused glossary tests: **PASS, 6,322 checks / 0 failures at each size**. Logs: `/private/tmp/ux-03-r5-focused-{1920,1670,1536}.log`.
- Permanent glossary suite run in isolation with the migration snapshot absent: **PASS, 2,573 checks / 0 failures**. It covers 112 entries, 30 skills, 382 scanned tokens and all 309 current cards. Log: `/private/tmp/ux-03-r5-coverage-independent.log`.
- Production probe logic: **PASS at all three sizes**, including all 12 impossible-fit reports at 1536×864. Each invocation checks 112 relics × three choice positions, 112 × three owned positions, and four wrapped-tray positions: **676 placements per size / 2,028 total**, plus pointer, keyboard and controller fixtures. Logs: `/private/tmp/ux-03-r5-probe-{1920,1670,1536}.log`.
- UI identity lint: **25 tests, PASS**. Log: `/private/tmp/ux-03-r5-ui.log`.
- Full Godot suite: **PASS**, exit 0, **708.508 seconds** within the 900-second budget. Log: `/private/tmp/ux-03-r5-full-godot.log`.
- `git diff --check`: **PASS**.

Negative checks, restored before the full suite:

- Remove the production controller preparation call: **one failure**, “Production controller routing re-pins an already focused badge.” Log: `/private/tmp/ux-03-r5-mutant-controller.log`.
- Restore the empty-body label fallback and run only the permanent suite, with the migration snapshot still absent: **nine failures**, one for each reviewed card. Log: `/private/tmp/ux-03-r5-mutant-one-line.log`.
- Disable the new short-row alignment: the probe reports the exact two reviewed owner collisions, `witchglass_lantern choice position 0` and `hollow_puppet choice position 0`, both at `CardFocusTooltip_04_Collision`. Log: `/private/tmp/ux-03-r5-mutant-overflow.log`. This negative check is repeated against the final banner-aware source; the only hovered-card collisions are the two reviewed cases.

Temporary drivers were removed, and the migration snapshot and production files were restored. Existing macOS certificate diagnostics, intentional failure-fixture errors and teardown warnings remain visible in the logs.

## Windowed proof commands for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/ux-03`. These commands have **not** been run by this worker. All sizes are logical viewport dimensions with `ui_scale = 1.0`; 1536×864 represents the requested 1.25-scale equivalent without applying scale twice.

```bash
python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-03-r5-visual-1920.json -- --size=1920x1080 --compare-original-card

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1670x1043 --proof-contract tests/glossary_tooltip_probe_contract_1670x1043.json --result-manifest /private/tmp/ux-03-r5-visual-1670.json -- --size=1670x1043

python3 tools/visual_probe_runner.py --timeout 120 --no-headless --display-driver macos --audio-driver Dummy tests/glossary_tooltip_probe.gd --task-id ux-03 --expect-size 1536x864 --proof-contract tests/glossary_tooltip_probe_contract_1536x864.json --result-manifest /private/tmp/ux-03-r5-visual-1536.json -- --size=1536x864
```

`GLOSSARY_PROOF_DIR` identifies the isolated output directory; `GLOSSARY_CAPTURE` prints each image path. Expect **20 normal captures**:

- `relic_choice_hover`, `relic_choice_keyboard`, `relic_choice_controller`, `relic_choice_middle`, `relic_choice_right`, `relic_choice_flow_four`, `relic_choice_outer_flow`.
- `relic_choice_witchglass_lantern_left`, `relic_choice_witchglass_lantern_right`, `relic_choice_hollow_puppet_left`, `relic_choice_hollow_puppet_right`.
- `owned_relic_hover`, `owned_relic_keyboard`, `owned_relic_controller`, `owned_relic_flow`.
- `owned_relic_wrapped_0`, `owned_relic_wrapped_4`, `owned_relic_wrapped_9`, `owned_relic_wrapped_14`.
- `card_keywords_after`.

Every filename ends in `.png`. The optional `--compare-original-card` adds `card_keywords_before.png` and requires exact RGBA identity with the retained migration artifact. The historical `relic_choice_flow_four` filename captures Witchglass Lantern in the middle position; the actual column count varies by viewport. Captures use native dimensions, `UPDATE_ALWAYS`, and `frame_post_draw`. Fresh image inspection and independent UI identity review remain with the design owner.

## Changed files and retained design item

This round changes `scripts/card_focus_tooltip_stack.gd` and the binding argument at `scripts/run_scene.gd:16393`; `tests/glossary_test.gd`, `tests/suites/glossary_coverage_suite.gd`, `tests/glossary_tooltip_probe.gd`; the three probe contracts; and this handoff. The migration JSON, gameplay data and glossary definitions stay at `db82e2cfb`.

`TODO_DESIGN_GLOSSARY_CONSUME_PROSE` remains unchanged: unmarked “Consume” in Briar Winch needs an explicit concept token to disambiguate surface removal from the item keyword.
