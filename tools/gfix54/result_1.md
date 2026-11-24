# gfix-54 round 1

## Condition icons

The shared CardWidget builds each `surface_condition` with its existing icon, labels and spacing. The group, labels and icon ignore mouse input and carry no tooltip text or tooltip-loop route. Clearing the group also removes the fallback that would open a popup when CardWidget walks back up from the icon. At each icon center the native query returns the same result as the card body. The round 0 icon resolver and Headlong fallback are gone. The keyword assembly in `action_icon_library.gd` matches the task's base file byte for byte. [CardWidget condition group](../../scripts/card_widget.gd#L2058) · [Condition scan](../../output/gfix54/round1/condition-scan.log)

The headless context scan mounted actual CardWidget faces in the combat hand, reward offers, Scavenger shelf and detail, Graftwright, deck view, combat draw pile, Grimoire card detail and Grimoire granted cards. It also mounted the event hover and event result previews from their production builder. The Graftwright sample used Iron Wheel on the production source widget to exercise a condition icon. Every context checked the icon at its actual position using its default setting and with native tooltips enabled. Reward GUI focus still published the side stack. The real-hand dry run also checked the pointer lift and controller hand focus. [Context scan](../../output/gfix54/round1/contexts.log) · [Hand dry run](../../output/gfix54/native.9rvIL7/probe.log)

## Side-panel coverage

All 12 cards already provide the relevant panel. The round added no panel copy. The titles below are the exact entry titles. The existing panel renderer displays titles in uppercase.

| Card | Title | Body |
| --- | --- | --- |
| Blinding Bash | If in Light | This bonus applies if the target stands in Light. |
| Dazzle | If in Light | This bonus applies if the target stands in Light. |
| Hallowed Strike | If in Light | This bonus applies if the target stands in Light. |
| Revealing Glare | Light | Hit each visible enemy in Light. |
| Searing Light | Light | Hit each visible enemy in Light. |
| Sunlance | If in Light | This bonus applies if the target stands in Light. |
| Couched Lance | Move | Deal +1 damage per tile you moved this turn, up to +5. |
| Headlong | Move | Walk up to 4 tiles. |
| Iron Wheel | Move | Deal +1 damage per tile you moved this turn, up to +5. |
| Hobnail Drive | If Staggered | This bonus applies if the target's next turn is Staggered. |
| Reflected Threat | Retaliate | Enemies that damage this Illusion take the same damage. |
| Refraction | Illusion | This attack also hits each other enemy adjacent to one of your Illusions once. |

Headlong also has **Next Attack** “Your next attack this turn deals +1 damage per tile you moved, up to +4.” Iron Wheel has a separate **Move** panel for its Move action. [Panel export](../../output/gfix54/round1/branch-panels.json)

The audit compared ordered title, body and display text for 1,950 panels across 626 catalog, projected hand and legacy views. The uncommitted branch and its release base `e3b27e209` produced byte-identical exports. The live `codex/release` ref was `8cfb865a7` when checked. Its independently changed Range and Shock glossary entries account for the differences on 109 cards between the two bases. Applying only this unit's remaining production change in a scratch copy of `8cfb865a7` also produced byte-identical exports before and after. [Panel byte comparison](../../output/gfix54/round1/panel-diff.log) · [Current release with patch](../../output/gfix54/round1/release-patched.log)

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-54 && bash tools/gfix54/native.sh
```

The launcher uses `LABYRINTH_CEL_LOOK=all`, 1920×1080 and 100% UI scale. It saves the viewport and prints each PNG path under `output/gfix54/native.<run>/`.

- `revealing_glare_condition_hover_1920x1080.png`
- `couched_lance_condition_hover_1920x1080.png`
- `revealing_glare_focused_side_panels_1920x1080.png`
- `couched_lance_focused_side_panels_1920x1080.png`

The hover cases verify the pointer stays on the icon, the card remains emphasized, and neither the capture viewport nor the root opens a tooltip during a 2-second dwell. They temporarily enable native tooltips on the witness CardWidget to test the path that could have opened the popup. The focus cases exercise the controller hand focus handlers and verify that the actual visible side panel belongs to the focused card and contains the exact condition title and body. The dry run reached the four states and emitted the planned PNG paths in `output/gfix54/native.9rvIL7/`. Windowed PNGs await the design owner's run. [Capture script](native_probe.gd) · [Dry-run log](../../output/gfix54/native.9rvIL7/probe.log)

## Receipts

| Check | Exact result |
| --- | --- |
| Condition scan | `GFIX54 CONDITION SCAN: PASS (309 cards, 98 condition icons, 0 with tooltip text, 0 with tooltip-loop route, 12 of 12 coverage rows)` |
| Context scan | `GFIX54 CARD CONTEXTS: PASS (11 contexts, reward GUI focus, native query checked)` |
| Panel comparison | `GFIX54 PANEL BYTES: PASS (309 cards, 626 views, 1950 panels, exact matches on both release bases)` |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7772 panels, 15773 checks, 0 failures)` |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.787s` · `OK` |
| Native dry run | `GFIX54 NATIVE PROBE: PASS (headless, 4 capture states)` |

The five changed GDScripts passed `--check-only --script` through the task runner. The launcher passed `bash -n`, and the image contract passed JSON validation. Godot reported the ObjectDB/resource cleanup diagnostic after the passing card display and context checks. The same diagnostic appeared after the round 0 card display check. No full suite or windowed probe ran in this round. [Card panels](../../output/gfix54/round1/card-panel-text.log) · [Short tooltips](../../output/gfix54/round1/short-card-tooltips.log) · [Display overrides](../../output/gfix54/round1/card-display-overrides.log) · [UI lint](../../output/gfix54/round1/ui-identity.log)

## Chosen defaults

The hand captures reuse the STA01 Warden arena, reduced motion and the round 0 pointer parking point `(4, 4)`. The probe waits 12 rendered frames for the hand hover before seeking the condition icon. The context audit waits five process frames for layout and teardown.

No design placeholders were added. The round 1 changes are uncommitted.
