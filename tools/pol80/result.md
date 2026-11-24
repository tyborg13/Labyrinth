# POL-80 implementation proof

Candidate baseline `7b3176ac60526b4d249f0e330631e98097a1ed1c` on `codex/mrg-18`. Worktree `codex/pol-80`. Risk tier low.

## 1. Burst

The candidate renders a 26×19 inline image at the start of the Discharge and Shatter rules lines. The raw text starts at “Destroy.” The one separator space follows the cross token. In the supplied native Discharge frames the image slot has no visible diagram. Headless uses a deliberately dimensioned placeholder, which proves the inline slot and its size. It cannot verify native pixels.

Candidate [`pattern_text.gd:110`](../../scripts/pattern_text.gd#L110) returned a live viewport texture to the label before the deferred mount and one-shot draw. Candidate [`inline_icon_text.gd:94`](../../scripts/inline_icon_text.gd#L94) assigned the inline slot immediately. Commit `40df74d0f5` introduced that rendering path. Commit `2d766d9291` attached the cross to the current glossary sentence at [`data/pattern_rule_text.json:3`](../../data/pattern_rule_text.json#L3). The replacement arms the one-shot after the diagram canvas draws, reads the completed viewport, and updates the cached inline texture at its original size. Card, Grimoire, enemy and board-tile tooltips use the same AoE painter. The standard cross has five red isometric tiles. The existing enemy origin variant retains its origin treatment. Native raster output remains for the director to inspect.

Crowncoal Heart had a separate missing-token path. Candidate [`card_focus_tooltip_stack.gd:121`](../../scripts/card_focus_tooltip_stack.gd#L121), from `2d766d9291`, filled the amount before the exact-template pattern lookup. Relic and inline glossary pop-ups now retain the decorated version. The unchanged label still measures the numbered text row so the decorated Crowncoal Heart panel keeps its 412×109 bounds.

| Surface | Raw before and after | Expanded before | Expanded after |
| --- | --- | --- | --- |
| Discharge and Shatter card hover | Destroy the target, then deal 5 damage on that tile and each adjacent tile. | `@pattern(cross)` followed by the raw sentence | Same markup and 26×19 slot, populated by the shared renderer |
| Grimoire Burst | Destroy the target, then deal X damage on that tile and each adjacent tile. The second paragraph begins “Hover the card” and ends “the Ember Tick's Burst.” | `@pattern(cross)` before the first sentence | Same markup and slot, populated by the shared renderer |
| Ember Tick Details and intent pop-up | When this enemy dies, this enemy Bursts 4, leaving Fire. | `@pattern(cross:origin)` followed by the raw sentence | Same markup and slot in the pop-up. The Details board's separately drawn origin cross remains in its existing row. |
| Powder Keg terrain hover | `3/3 Health` followed by “When the keg is destroyed, the keg Bursts 6.” on the next line | `@pattern(cross)` before the second line | Same markup and slot, populated by the shared renderer |
| Basalt Kiln, Black Sun Dial and Ashen Brand relic definitions | Destroy the target, then deal X damage on that tile and each adjacent tile. | `@pattern(cross)` followed by the raw sentence | Same markup and slot, populated by the shared renderer |
| Crowncoal Heart relic definition | Destroy the target, then deal 2 damage on that tile and each adjacent tile. | Raw sentence | `@pattern(cross)` followed by the raw sentence, with the original panel bounds |

The observation JSON records each exact raw string, expanded markup, rich-label text, slot size and measured stack-panel bounds. The dry-run comparison asserts equality of the before and after raw copy, plain output and recorded pop-up bounds.

## 2. Centred room title

Candidate [`run_scene.gd:27254`](../../scripts/run_scene.gd#L27254) supplies “Choose Door” to candidate [`combat_board_view.gd:12044`](../../scripts/combat_board_view.gd#L12044). The board status paint dates to `59d1198f19` and the current prompt to `18a40296ac`. The 1500×900 Character dialog dates to `76dcae7fe`. Its top edge is at y=90 in the supplied native evidence. The retained board paint is carried by the room-centering transform. pol-60 `3960bb9f5` wired the large-map backdrop to the top-left `RoomTitle` label at candidate [`run_scene.gd:5175`](../../scripts/run_scene.gd#L5175). The centred placard had no opacity binding to Character.

The shared pol-60 tween uses sine ease-out at 0.32 s normally and 0.12 s with reduced motion. Character's existing viewport-wide scrim requests the fade across all three tabs. The other watched panels use their painted surface bounds and the placard’s retained screen rectangle. The title, outline, side rules and optional hint fade together. During an opacity-only redraw the board uses the previous text placement. Large-map visibility and its original header alpha remain on the same path. Direct RunScene initialization and staged Continue both install the watcher.

Rects are screen coordinates in `(x, y, width, height)` at 1920×1080 and UI scale 1.0. The Character rows show its dialog. Its full-screen scrim is `(0, 0, 1920, 1080)` and intersects the title.
The settled headless waypoint placed its title above the dialog. The supplied native candidate images show the title clipping at the dialog edge. The Character rule covers both placements.
Pile rows use the empty pile panels in waypoint mode to measure panel clearance against an active title. Combat pile views have no centred title.

| Panel | Panel rect | Centred title rect | Before open → closed alpha | After open → closed alpha | Decision |
| --- | --- | --- | --- | --- | --- |
| Character Gear | (210, 90, 1500, 900) | (842.5, 24, 235, 43) | 1 → 1 | 0 → 1 | Fade through the Character scrim |
| Character Magic | (210, 90, 1500, 900) | (842.5, 24, 235, 43) | 1 → 1 | 0 → 1 | Fade through the Character scrim |
| Character Skills | (210, 90, 1500, 900) | (842.5, 24, 235, 43) | 1 → 1 | 0 → 1 | Fade through the Character scrim |
| Camp | (760, 267, 400, 546) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Panel below title |
| Settings | (550, 122, 820, 836) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Panel below title |
| Grimoire | (400, 220, 1120, 640) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Panel below title |
| Draw pile | (700, 421, 520, 238) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Panel below title |
| Discard pile | (700, 421, 520, 238) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Panel below title |
| Scavenger | (0, 0, 1920, 1080) | (842.5, 68.56, 235, 43) | 1 → 1 | 0 → 1 | Shop canvas intersects title |
| Event | (140, 150, 1640, 780) | Absent | 1 → 1 | 1 → 1 | Event mode supplies no title |
| Large map | (0, 0, 1920, 1080) | (842.5, 24, 235, 43) | 1 → 1 | 1 → 1 | Opaque map and existing header fade |

Normal-motion midpoint samples after the change were 0.258 while opening and 0.736 while closing.
The reduced-motion opening midpoint was 0.133 and settled at 0. Closing restored 1.
The large-map top-left header alpha was 0 while open and 1 after closing on both revisions. Closing the Scavenger opens the map, so that row has its usual map header fade.

The Character input probe gave keyboard focus to Magic, activated it with Enter, and switched to Skills through the controller’s right shoulder button. The staged Continue probe resumed at the Scavenger and observed zero title opacity.

Headless observations and the nine planned frame names per revision. [Before](/private/tmp/labyrinth_codex/pol-80/headless.KGrx14/before/observations.json) · [After](/private/tmp/labyrinth_codex/pol-80/headless.KGrx14/after/observations.json).

## Changed files

- `scripts/pattern_text.gd` supplies the completed texture from the existing painter.
- `scripts/card_focus_tooltip_stack.gd`, `scripts/inline_icon_text.gd` and `scripts/ui_tooltip_panel.gd` preserve the Burst pattern through amount filling and retain the original numbered row bounds.
- `scripts/large_map_backdrop.gd` shares the pol-60 alpha tween.
- `scripts/room_title_panel_fade.gd` observes modal visibility and geometry. `scripts/combat_board_view.gd` applies alpha to the centred status paint.
- `scripts/run_scene.gd` changed lines **1714**, **2083**, **4315–4326**, and **5882** in the working file. They declare the watcher, install it during staged and direct setup, and register Scavenger.
- `tools/pol80/` contains the native launcher, viewport probe, panel and input probe, existing-suite harness, image contract and this report. New Godot scripts include their adjacent UID sidecars. The separate launcher at `/private/tmp/labyrinth_codex/pol-80/native.sh` delegates to the repository script.

## Checks

| Check | Observed result |
| --- | --- |
| Existing card keywords, tooltip consistency, glossary coverage, inline definitions and Grimoire search suites | `POL-80 FOCUSED PASS (6519 checks, 0 failures)` |
| Grimoire focus return | `GRIMOIRE SEARCH PROBE RESULT: PASS` |
| Live tile tooltip routes | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| Native launcher dry run, before and after | `POL-80 before headless PASS (9 Burst routes, 24 panel samples, 9 frames)` and `POL-80 after headless PASS (9 Burst routes, 24 panel samples, 9 frames)` |
| Copy and measured geometry | `POL-80 BURST COPY AND POP-UP BOUNDS: PASS` |
| Character inputs, both revisions | `POL-80 CHARACTER INPUT: PASS (keyboard focus and Enter, controller shoulder)` |
| Staged Continue | `POL-80 STAGED CONTINUE: PASS (Scavenger visible, title alpha 0)` |
| UI identity | `Ran 25 tests in 4.629s`, `OK` |
| Rules text | `PASS: Rules text lint (16 existing hits)` |
| Python default group | `Ran 196 tests in 29.152s`, `OK` |

The candidate and the working tree both reproduce these existing failures. The assertions were kept verbatim.

- `GLOSSARY TEST RESULT: FAIL (6218 checks, 4 failures)`. Meteorfall panel count and two order assertions, plus “Hover displays relic plus deduplicated definitions.”
- `BOARD TILE TOOLTIPS: FAIL checks=233 failures=8`. Trap copy and loop metadata.
- Character menu polish, `ERROR: Points enable the native primary Learn action`.
- Character review, `ERROR: Character uses the shared close socket`.

The Python runner completed without writing its Git timing cache because the sandbox makes Git metadata read-only. Godot logged the sandbox certificate lookup warning on the candidate and working tree.

## Chosen defaults

- Proof seed 919042, resting pointer at (32, 110), Shatter as the second live card hover, Basalt Kiln for the additional native pop-up, Ember Tick for enemy Details, Powder Keg at tile (5, 4) with 3 Health and Burst 6, and Weeping Statue for the event panel.
- Probe readiness 25 s, native process timeout 300 s, pattern pixel readiness 2 s, window fit margins (64, 96), fade samples at half the existing duration, and 0.08 s extra settling for terminal opacity measurements.
- Production uses the existing dimensions, timing, wording, and art. Design placeholders are absent.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-80 && /private/tmp/labyrinth_codex/pol-80/native.sh
```

The command prints the absolute path to every PNG. The two renderer manifests and observation files accompany `hover_discharge.png`, `hover_shatter.png`, `relic_burst.png`, `grimoire_burst.png`, `character_gear.png`, `character_magic.png`, `character_skills.png`, `character_mid_fade.png`, and `character_closed.png` in each revision's output directory. Native capture and pixel inspection remain open because the implementation sandbox has no window server.

The dry run used the above launcher with `--dry-run`. [Dry-run log](/private/tmp/labyrinth_codex/pol-80/native-handoff-dry.log). [Python suite log](/private/tmp/labyrinth_codex/pol-80/python-handoff.log). [Staged Continue log](/private/tmp/labyrinth_codex/pol-80/staged-resume.log).
