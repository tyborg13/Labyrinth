# gfix-57 tooltip sweep

The headless probe exercises the production overrides through Godot 4.6.1's embedded native tooltip windows. It sends pointer motion into a SubViewport, confirms the hovered target, waits past the normal tooltip delay, and finds the visible window among the control's internal children. Normal-state signatures cover the queried text, the visible text and the popup dimensions. PASS uses the visible text and dimensions of its retained forecast panel.

## Release and branch observations

The release base is `codex/release` at `e20cebc1918fffd0b686dce084dc69cd68259dc1`. The release check used that revision's three production files in the prepared worktree. The branch files were restored for the second run.

| Override | Empty on release | Empty on gfix-57 | Normal on release and gfix-57 | Source or fix |
| --- | --- | --- | --- | --- |
| `pass_forecast_tooltip_button.gd` | none | none | Opened retained forecast with its text | Native getter returns an empty string and the override returns null. The in-scene forecast owns the normal hover. |
| `pre_battle_controls.gd` / Foe | none | none | Opened enemy preview | `PreBattleView.build_foe` sets an `enemy:` token and the preview has a name, Health and initiative. The pinned-inspection route clears the query and returns an invisible control. |
| `pre_battle_controls.gd` / Strip | none | none | Opened card preview | `PreBattleView._card_strip` sets a `card:` token and the preview renders the card. The pinned-inspection route suppresses hover as above. |
| `pre_battle_controls.gd` / Gear | none | none | Opened equipment preview | A filled socket supplies an `equipment:` token and the preview renders the equipment name and metadata. Empty sockets are noninteractive with `MOUSE_FILTER_IGNORE`. The pinned-inspection route also suppresses hover for filled sockets. |
| `omen_badges.gd` / Badge | n/a, always has text | n/a, always has text | Opened omen preview | `OmenRules.active` only yields known omens with fights left. `Omens.sync` creates badges from those entries and expiry disables mouse routing. The formatter always supplies the fights-left line. |
| `battlefield_rule_hud.gd` | n/a, always has text | n/a, always has text | Opened rule preview | No active rule hides the HUD. Each of the six `data/battlefield_rules.json` icon keys has a label, so `ActionIcons.tooltip` supplies text. The Hoarder panel uses the authored rule sentence formatted with an ordinal. |
| `pre_battle_objective_heading.gd` | none | none | Opened objective preview | Text replacement preserves blank input and the inherited `UiTooltipLabel` guard handles it. The normal query is the objective title and description. |
| `graftwright_choice.gd` | none | none | Opened card-icon preview | A plain spot on the card yields a blank query. The override delegates to CardWidget's guard. A choice without a card face returns null directly. |
| `section_map_panel.gd` / LegendItem | **opened** | **none** | Opened map legend preview | Legacy maps join revealed combat descriptions. With none revealed, the join is empty. Added the guard before the existing text-panel builder. |
| `chronicle_panel.gd` / RecordIcon | n/a, always has text | n/a, always has text | Opened path preview | Path icons always include “Already visited”. Gear builders always include slot/rarity metadata and relics use the shared blank-safe text builder. |
| `chronicle_card_tile.gd` | **opened** | **none** | Opened fallback name preview | Chronicle's display conversion preserves a blank archived deck ID. A missing definition then produces a blank fallback name. Guarded that actual name. The other branches format overflow counts or delegate to the card builder. |
| `card_empower_seal.gd` | **opened** | **none** | Opened offered Empower preview | The card proxy can configure a visible seal with empty detail. Added the guard before the existing Empower panel builder. |
| `pre_battle_inspection_view.gd` / LoopMovePlate | none | none | Opened known move preview | Already checks stripped text before routing to a plain or glossary panel. |
| `pre_battle_inspection_view.gd` / LoopTraitRow | none | none | Opened trait preview | Already checks stripped text before opening the glossary panel. |

The release popups had empty rendered text. The legend and Empower windows measured 250×32, and the Chronicle tile window measured 372×50.

The remaining overrides use existing suppression or supply their own content. `UiTooltipButton`, `UiTooltipControl`, `UiTooltipLabel`, `UiTooltipPanelContainer`, CardWidget, CombatBoardView, EventViewChoice, OutcomeWell and GlossaryRichLabel guard stripped text. RunScene's base tooltip container does the same. Its gear and card subclasses receive prefixed keys and construct gear or card previews. Empty magic slots delegate to the guarded base, empty item slots are plain panels, and empty character gear slots supply a slot label through the base.

## Reproduction

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-57 &&
python3 tools/godot_task_runner.py --task-id gfix-57 --stream -- godot --headless --path . --script tools/gfix57/popup_probe.gd
```

For releases with the original source files, pass `-- --release` after the script path. That mode expects the three reproduced popups and checks their rendered text is empty.

## Proof for the design owner

The same tool captures each changed control in both states at 1920×1080 and 100% UI scale when run with the native renderer. The capture directory is `user://gfix57_popup_proof` inside the visual runner's isolated HOME. The probe prints its absolute path. Its popup assertions check the empty state, and the contract checks the six image names, dimensions and normal-state regions.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-57 &&
python3 tools/visual_probe_runner.py --task-id gfix-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 75 --expect-size 1920x1080 --proof-contract tools/gfix57/popup_contract.json tools/gfix57/popup_probe.gd
```

## Chosen defaults

- The proof places controls at `TARGET_POSITION` (480, 360) with a 160×48 minimum and parks the pointer at (8, 8). The Graftwright card query samples every 4 pixels. The setup uses ett-01's 1.2-second hover wait at each point.
- Fixture data uses Burrow Grub with 12 Health, Overhead Smash and the starting weapon, Dread with one fight left, a Wind rule, a two-Time PASS forecast, a revision-5 combat room at (1, 0) and a legacy Chronicle card ID. The detached foe and card controls are 152×184 and 250×352.
- The native proof uses two equal-height background bands in the existing `INK_1` and `INK_3` palette colors so controls remain readable at full size.
- The owner-only native probe has a 75-second process limit to accommodate the hover waits and captures.

## Design placeholders

None.

## Verification

- Release and branch hover probes: `GFIX57 PASS candidates=14 fixed=3` on each. All 14 normal-state signatures matched. [Release log](/private/tmp/labyrinth-godot-home/gfix-57-1795829227955542000-96800/godot.log) · [Branch log](/private/tmp/labyrinth-godot-home/gfix-57-1795829265520924000-97906/godot.log)
- Existing focused suites: `GFIX57 FOCUSED tooltip_consistency: 69 checks, 0 failures`, `GFIX57 FOCUSED section_map: 261420 checks, 0 failures`, `GFIX57 FOCUSED omen_rules: 41 checks, 0 failures`.
- Empower feedback and native hover with headless embedded windows: `MAIN DOMAIN ASSERTIONS full_scene_empower_feedback_program: 173`, `TEST RESULT: PASS`.
- Pre-battle semantics and view: `PRE-BATTLE SEMANTICS TEST: PASS`, `PRE-BATTLE VIEW TEST: PASS`.
- Chronicle: `CHRONICLE HOVER PROOF: 5 native popups; 5 pointer targets`, `CHRONICLE TEST RESULT: PASS`.
- Battlefield rule views and HUD: `EL04 RULE VIEWS RESULT: PASS (0 failures)`.
- UI identity lint: `Ran 25 tests in 5.645s`, `OK`.
- Python default input group: `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 38.646s`, `OK`. Included `PASS: Rules text lint (16 existing hits)`. Results are in `/private/tmp/gfix57-python.PkzFgKcm`. The sandbox prevented the runner from updating its timing cache under the common Git directory after the tests finished.

Godot emitted a macOS certificate-store diagnostic during startup. The pre-battle view and Chronicle tests reported ObjectDB instances at shutdown, and the pre-battle view test reported one resource still in use. Both returned passing results. The native captures remain pending on a Mac with window-server access.
