# ux-19 implementation handoff

Branch `codex/ux-19`. Medium-risk keyboard and Settings change. The work is uncommitted
for the design owner's inspection and commit.

## Acceptance criteria

| Requirement | Implementation and proof |
| --- | --- |
| 1. Six keyboard bindings | The Pass, Hurry, Empower, Undo a walk, Show enemy intents, and Map key tokens in `data/controls.json` have their specified action IDs. The other keycaps remain read-only. |
| 2. Start listening | The existing keycap face sits on a focusable button. Click, Enter, and controller A were exercised in the real title-screen Settings panel. `Press a key` widens the selected cap at the existing row height. |
| 3. Capture and cancel | The early Settings input handler consumes the captured press, release, and echo. Esc, an inside or outside click, and controller B cancel. Backspace and Delete write zero and display `—`. Both sets of 1–9 and the reserved modifier and navigation keys leave the prompt listening. |
| 4. Swap | An occupied key swaps with the old binding, including a swap from an unbound action. Both keycaps play and retire one selection pulse. The pulse uses the existing UiSkin selection treatment and the established choice-feedback timing. |
| 5. Restore keys | The section's secondary button disables at the defaults. Its confirmation uses `Restore default keys?`, `Cancel`, and `Reset All`. Cancel retains the edited keys. Confirm restores the six defaults while preserving the fixture's other preferences. |
| 6. Key display | See the inventory below. Simulated AZERTY confirms that a physical Q displays A and that default Undo resolves the key that types Z. Live combat proof covers the rebound Pass, Details, Map, Undo, and Empower marks and the unbound states. |
| 7. Real handlers | The live run accepted Q, F, G, V, J, and K and ignored the corresponding old keys in the Pass, Hurry, Empower, Undo, Details, and Map handlers. Release ended the Hurry hold. Ctrl+Z and Cmd+Z still undid a walk after rebinding. |
| 8. Storage | `user://settings.json` persists normalized physical keycodes in `key_bindings`. A second Godot process loaded the six edits. Missing and invalid entries fell back separately. Malformed JSON and an existing file with reads denied gave defaults and were byte-for-byte intact after loading. |
| 9. Windows typed arrays | The changed-script audit found zero new and zero pre-existing findings. |

## Player-facing key inventory

| Surface | Source | Bound and unbound behavior |
| --- | --- | --- |
| Controls keycaps for P, Space, E, Z, I, and M | `data/controls.json`, `scripts/settings_panel.gd`, `scripts/settings_key_button.gd` | Localized key label or the Controls em dash. |
| Pass face | `scripts/pass_key_hint.gd`, seated by `scripts/retained_pass_preview.gd` | Localized mark beside PASS. An unbound key hides the mark. The existing disabled tint and controller visibility rules still apply. |
| Details face and native button text | `scripts/combat_hud_intents.gd`, `scripts/run_scene.gd` | Localized `IntentKey` and `DETAILS [key]` button text. An unbound key hides the mark and removes the bracketed suffix. |
| Details tooltip | `scripts/run_scene.gd`, `scripts/device_shortcut_tooltips.gd` | `Show every enemy's full plan` or `Hide full plans` keeps the active key suffix in pointer mode. With no key, the suffix disappears. |
| Walk undo face | `scripts/movement_undo_button.gd` | Localized `UndoKey` or a hidden mark. |
| Empower seal key mark | `scripts/input_router.gd`, `scripts/card_empower_controller.gd`, `scripts/card_empower_seal.gd` | Localized mark in the existing seal seat for the raised card, including the dragged card. With no key, the mark is hidden. The controller uses the existing glyph. |
| Minimap and section Map HUD tooltips | `scripts/run_scene.gd`, `scripts/device_shortcut_tooltips.gd` | `Map [key]` in pointer mode. The mark disappears when unbound. |
| Start-room map hint | `scripts/start_room_map_flow.gd` | The bracketed mark after `Choose your path on the map` displays the bound key. It disappears when unbound. The controller glyph still occupies its existing seat. |

Space appears as a Hurry key in Controls. The other two Space checks in production handle board panning
and transition skip. The SFX cue trigger descriptions are authoring metadata.

### Sentences awaiting unbound copy

The authored Grimoire paragraphs in `data/grimoire.json` are routed at display time through
`scripts/input_wording.gd`. Only the key token changes in the bound case.

| Surface | Existing sentence or instruction | Unbound placeholder |
| --- | --- | --- |
| Grimoire combat overview | `Press I for every enemy's full plan.` | `TODO_DESIGN_UNBOUND_enemy_intents` |
| Grimoire combat overview | `Undo move (Z) takes back free Movement until you play a card.` | `TODO_DESIGN_UNBOUND_undo_walk` |
| Grimoire Empower | `Charge the card with the Empower seal on its top-right corner (or press E; the right stick on a controller).` | `TODO_DESIGN_UNBOUND_empower` |
| Uncharged Empower seal tooltip | `Click the seal or press E` | `TODO_DESIGN_UNBOUND_empower` |

## Files changed

- Settings and bindings — `data/controls.json`, `scripts/key_bindings.gd`,
  `scripts/settings_key_button.gd`, `scripts/settings_panel.gd`, `scripts/settings_store.gd`,
  `spec/settings.md`.
- Game input and key display — `scripts/combat_keyboard_shortcuts.gd`, `scripts/combat_pacing.gd`,
  `scripts/input_router.gd`, `scripts/run_scene.gd`, `scripts/movement_undo_button.gd`,
  `scripts/pass_key_hint.gd`, `scripts/combat_hud_intents.gd`, `scripts/device_shortcut_tooltips.gd`,
  `scripts/start_room_map_flow.gd`, `scripts/card_empower_controller.gd`,
  `scripts/card_empower_seal.gd`, `scripts/input_wording.gd`.
- Proof and handoff — `tools/ux19/probe.gd`, `tools/ux19/combat_proof.gd`, `tools/ux19/proof_contract.json`,
  `tools/ux19/native.sh`, `tools/ux19/result.md`. The requested executable copy is
  `/private/tmp/labyrinth_codex/ux-19/native.sh`.

## Checks run

Godot scripts ran via `python3 tools/godot_task_runner.py --task-id ux-19 --stream -- godot --headless --path . --script <path>`.
Logs are under `/private/tmp/labyrinth_codex/ux-19`.

| Check | Result line |
| --- | --- |
| `native.sh --dry-run` | `UX19 HEADLESS RESULT: 116 passed, 0 failed` |
| Dry-run path and proof-contract check | `UX19 NATIVE PLAN: 7 capture paths and both resolutions match the proof contract` |
| Second Godot process via the dry-run script | `UX19 RESTART RESULT: 1 passed, 0 failed` |
| `tests/settings_qol_test.gd` | `Settings QoL checks: 74 passed, 0 failed` and `TEST RESULT: PASS` |
| `tests/settings_modal_input_test.gd` | `TEST RESULT: PASS — Settings modal input` |
| `tests/main_menu_input_test.gd` | `TEST RESULT: PASS — main menu input and startup transitions` |
| `tests/combat_hud_buttons_test.gd` | `COMBAT HUD BUTTONS TEST: PASS` |
| `tests/enemy_hurry_test.gd` | `ENEMY HURRY TEST RESULT: PASS` |
| `tests/movement_undo_test.gd` | `MOVEMENT UNDO RESULT: 0 failures` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.965s` and `OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.124s` and `OK` |
| `python3 tools/qa105/typed_array_scan.py --base HEAD` | `TYPED ARRAY SCAN: 18 scripts; 0 new; 0 pre-existing` |
| `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/ux-19/python-audit` | `ISOLATION AUDIT: 57 modules; /private/tmp/labyrinth_codex/ux-19/python-audit/isolation-audit.md` |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/ux-19/python-default` | `INPUT GROUP default: always run`, `Ran 192 tests in 41.265s`, and `OK` |

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-19 && /private/tmp/labyrinth_codex/ux-19/native.sh --windowed
```

The windowed command invokes the visual probe runner and uses the approved cel variants.
The dry run printed these planned paths under `/private/tmp/labyrinth_codex/ux-19/captures/`.
Each desktop image is 1920×1080 at 100% UI scale. The Deck image is 1280×800 at 100%
with the Steam Deck glyph family. The runner writes its manifest to
`/private/tmp/labyrinth_codex/ux-19/renderer.json`.

- `desktop_controls.png`
- `desktop_listening.png`
- `desktop_swap.png`
- `desktop_unbound.png`
- `desktop_restore.png`
- `desktop_combat_pass_q.png`
- `deck_controls.png`

## Chosen defaults

- Proof bindings besides Pass/Q are Hurry/F, Empower/G, Undo/V, Details/J, and Map/K on the headless layout.
- Combat uses run seed 123, the existing movement-undo board, and Overclock for the Empower check.
- The proof waits five frames for combat setup, allows 15 seconds for the combat fixture to unlock, and
  waits 0.5 seconds for the Settings layout and the completed swap pulse to settle.
- The proof uses music volume 0.32 to verify that restoring keys preserves other preferences.
  Renderer startup and execution limits are 25 and 120 seconds.

## Open issues

- The sandbox has no window-server access. Native captures and their visual inspection are pending.
- The three unbound-copy placeholders above await the design owner's wording.
- The peer gap document named in the brief is absent from this checkout. The brief supplied the implementation requirements.
- Godot emitted the host's macOS CA lookup diagnostic `Condition "ret != noErr" is true. Returning: ""`
  during headless startup. The Python default group passed and reported that its optional learned timing
  cache could not write under the shared `.git` directory.
