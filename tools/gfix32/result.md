# gfix-32 result

Implementation is uncommitted on `codex/gfix-32`. The reproduction baseline is `f92582e85f72107cc80abf8c72e3bc4677a93dd9`. All measurements come from the live UI in an exact 1920×1080 SubViewport at 100% UI scale.

## Acceptance

1. **Restore Defaults confirmation.** On the baseline, Esc dismissed Settings in both the title and pause menus. Clicking the backdrop left the confirmation open. Both inputs now dismiss only the confirmation. A primary backdrop press is still consumed before cursor feedback. Cancel and B also dismiss the confirmation, and controller focus goes from Cancel back to Restore Defaults, including after opening with the pointer and switching to controller. Dismissal preserves the fixture's saved preference.
   
   All 26 row rectangles and clipped heights match before and while the confirmation is open in both runs. Row x is 994 px, the scrollbar is 8 px wide in both states, and Reduced motion keeps all 61 px visible. Restore Defaults returns to `(1460, 886, 194, 46)` in the title menu. Its slot stays at that rectangle while it is hidden, with the existing Reset All button as the only visible destructive action. The layout and reset action were already working on the baseline.

2. **Room title under the large map.** The reported bleed did not reproduce in the normal open/close path. In both runs the title is at `(10, 10, 951, 38)`, canvas layer 1, z 0, visible flag true, alpha 1.000. The open map backdrop encloses the title and has alpha 1.000 over the entire 1920×1080 viewport, on layer 1 at z 940. The title is fully occluded. The subtitle rectangle is stable and the title measurements match after closing. The conditional map fix was skipped.

3. **Grimoire notice under an event.** The fixture opens the Hanged Knight with the exact two-entry notice produced by the Grimoire library. In both runs the event panel is at `(140, 150, 1640, 780)` on layer 1 at z 1200. The notice is at `(1500, 952, 398, 106)` on layer 1 at z 0 with alpha 1.000 and its visibility flag false. The queue holds one notice behind the full-panel gate, so there is no notice paint through the event. The conditional notice fix was skipped.

## Checks

| Check | Observed result |
| --- | --- |
| Baseline headless probe | `GFIX-32 BASELINE HEADLESS: 0 failures`. Baseline mode logs the Esc and outside-click failures as observations. |
| After headless probe via the capture launcher dry run | `GFIX-32 AFTER HEADLESS: 0 failures`. All nine Settings assertions logged `PASS`. |
| Godot `--check-only` | Exit 0 for `scripts/settings_panel.gd` and `tools/gfix32/verify.gd`. The final probe also parsed from outside the project root, as the baseline capture requires. |
| UI identity lint | `Ran 25 tests in 6.175s` and `OK`. |
| Python default group | `SELECTED MODULES: 21 of 57`, `Ran 192 tests in 36.899s`, and `OK`. Sidecar check passed on this base. |
| Rules text lint, included in the Python default group | `PASS: Rules text lint (455 existing hits)`. |
| Launcher and contract | `bash -n` and JSON validation exited 0. |

Logs are under `/private/tmp/labyrinth_codex/gfix-32/` in `baseline-headless.log`, `after-headless.log`, `parse.log`, `external-parse.log`, `ui-identity.log` and `python-default.log`.

## Proof for the design owner

Windowed rendering requires a macOS desktop session. The headless dry run printed both sets of paths. The five files below are planned in each of `/private/tmp/labyrinth_codex/gfix-32/before/` and `/private/tmp/labyrinth_codex/gfix-32/after/`.

- `01_settings_closed.png`
- `02_settings_confirm.png`
- `03_room_closed.png`
- `04_map_open.png`
- `05_event_open.png`

The launcher sets `LABYRINTH_CEL_LOOK=all` and uses the visual probe runner with the exact-size contract. To prepare the default baseline path if a pristine checkout at the baseline HEAD is unavailable, run the first block once. An existing checkout can be passed as `BASE_PROJECT` instead. Both projects need the approved cel-look variants.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-32 && git worktree add --detach /private/tmp/labyrinth_codex/gfix-32/base-project f92582e85f72107cc80abf8c72e3bc4677a93dd9
ln -s /Users/borgerding/workspace/Labyrinth.worktrees/gfix-32/cel_look_variants /private/tmp/labyrinth_codex/gfix-32/base-project/cel_look_variants
```

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-32 && bash /private/tmp/labyrinth_codex/gfix-32/native.sh
```

The repo copy is `tools/gfix32/native.sh`. Each capture directory receives a validated `manifest.json`.

## Files changed

- `scripts/settings_panel.gd`
- `tools/gfix32/verify.gd` and `verify.gd.uid`
- `tools/gfix32/native.sh` and `proof_contract.json`
- `tools/gfix32/result.md`

## TODO_DESIGN placeholders

None.

## Chosen defaults

Proof uses the existing event-suite seed 421 for repeatable map imagery, the Hanged Knight event and its first two locked library entries for the notice, a starter profile with the tutorial completed, an Xbox controller route, and a 0.35 fixture master volume to detect any unintended reset. Reduced motion is scrolled fully into view before opening the confirmation. The backdrop click is at (24, 24). The probe waits four layout frames and 0.65 s for event entry. The initial headless baseline used the default fresh-run seed and produced the same measured map-off and map-on rectangles.

## Open issues

- Real-renderer captures and inspection remain pending. This sandbox has no macOS window-server access.
- The Python runner could not update its optional timing cache under the read-only shared Git directory. Its default group exited 0.
- The brief's `tools/fx15/native_capture.gd` is absent on this base. The probe follows the existing `tools/ux17/capture.gd` SubViewport pattern.
