# pol-76 candidate 6 results

Candidate 6 is `33d6d09f22c7d846358accccfb7125e6cc43d90f` on `codex/mrg-17`. Before ran that worktree. After ran the uncommitted `codex/pol-76` worktree. Both used the live game controls, an exact 1920 × 1080 SubViewport, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. The director ran the candidate 6 native probe. The implementation sandbox supports the headless runtime checks and leaves the native after trace to the director.

## Item 1 — Main-menu Chronicle edges

**STALE.** On a new profile and on a seeded profile with seven runs, open Settings, close Settings, open Chronicle and then close Chronicle. Settings left all title layers and the footer visible. Chronicle hid all four title layers and the whole profile block on both profiles. The title and footer returned on close. The Chronicle frame rect was `(60, 110, 1800, 860)` on both profiles.

The visibility handler already hides the title layers under Chronicle's existing crossfade. The title layout suppresses the profile block while Chronicle is visible. [Title visibility](../../scripts/main_menu.gd#L1257), [Profile visibility](../../scripts/main_menu.gd#L859), [Chronicle crossfade](../../scripts/chronicle_panel.gd#L214)

These are the visible empty-state controls at viewport coordinates, in `(x, y, width, height)` order. The frame draws its own surface. The close ornament shares the button rect. [Empty-state construction](../../scripts/chronicle_panel.gd#L131)

| Control | Rect |
| --- | --- |
| Chronicle frame | (60, 110, 1800, 860) |
| CHRONICLE | (108, 144, 600, 22) |
| Your Descents | (108, 166, 600, 60) |
| Lifetime totals row | (1301, 180, 511, 34) |
| Runs chip | (1301, 180, 83, 34) |
| Runs content row | (1315, 187, 55, 20) |
| Runs value | (1315, 187, 11, 20) |
| Runs caption | (1332, 187, 38, 20) |
| Escapes chip | (1396, 180, 109, 34) |
| Escapes content row | (1410, 187, 81, 20) |
| Escapes value | (1410, 187, 11, 20) |
| Escapes caption | (1427, 187, 64, 20) |
| Best score chip | (1517, 180, 127, 34) |
| Best score content row | (1531, 187, 99, 20) |
| Best score value | (1531, 187, 11, 20) |
| Best score caption | (1548, 187, 82, 20) |
| Dragons slain chip | (1656, 180, 156, 34) |
| Dragons slain content row | (1670, 187, 128, 20) |
| Dragons slain value | (1670, 187, 11, 20) |
| Dragons slain caption | (1687, 187, 111, 20) |
| Chronicle close | (1786, 136, 47, 44) |
| Close ornament | (1786, 136, 47, 44) |
| ChronicleEmpty | (108, 240, 1704, 718) |

The before and after contracts each include `chronicle_empty.png` and `chronicle_runs.png`.

## Item 2 — Turn-order projection chip

**STALE.** Continue into combat fixtures with three and eight enemies and hover Tempest Form. Each rail contained one live projected player entry and zero card-name chips. The fitted queued-portrait size multipliers were 0.9662 and 0.7200 respectively. The projected entry had no label, so the effective glyph size is unavailable at both scales. The rail keeps player Time numerals and motion and reserves its remaining badge path for enemy Stagger and Petrify. The 12 px constant still exists for that path. [Badge construction guard](../../scripts/turn_order_slots.gd#L209), [Badge typography](../../scripts/run_scene.gd#L11957), [Rail layout solver](../../scripts/turn_order_layout.gd#L14)

The before and after contracts each include `rail_3_enemies.png`, `rail_8_enemies.png` and their `_2x.png` variants.

## Item 3 — Old notice during Purge

**STALE in both checked paths.** Carry the prior Spark Dart acquisition notice into the Ember Hearth and into the Scavenger shop. Activate each Purge control and confirm Pale Spark. The Hearth displayed the prior notice before opening. The Scavenger already hid its prior notice behind the shop. The label was empty and hidden in both exhaust beats. It stayed empty during the Hearth's board result. Both paths committed exactly one Purge and the settled label contained the new Purged notice. The candidate audit found 0 of 255 Hearth frames and 0 of 93 Scavenger frames containing the visible prior notice. The task worktree audit found 0 of 265 and 0 of 92.

The common commit handler already clears and hides the message box before calling `play_exhaust()`. The Hearth additionally plays the board result after the shared animation. The live Scavenger button calls the same entry point. The separate `MagicPurgeConfirmation.play_exhaust()` definition has no production callers. [Hearth entry](../../scripts/run_scene.gd#L15979), [Scavenger entry](../../scripts/magic_purge_overlay.gd#L538), [Shared commit and Hearth result](../../scripts/run_scene.gd#L35064), [Full-panel notice visibility](../../scripts/run_notification_queue.gd#L70)

The before and after contracts each include `purge_campfire_exhaust.png`, `purge_campfire_result.png` and `purge_scavenger_exhaust.png`.

## Item 4 — Double hover tick

**Reproduced on candidate 6.** The native probe moved the OS cursor from the board onto Tempest Form. Entry played one `card.hover` at 20205 ms. With the cursor still at `(734, 1046)`, Cinch Straps drew Pale Spark and the redraw played the cue again at 21982 ms. Playing Brace redrew the hand and played it again at 23681 ms. Both redraws logged `motion_events=0`, `hovered=0` and `played=1`. The candidate probe printed `POL-76 real-pointer double tick: REPRODUCED`. [Native candidate output](/private/tmp/labyrinth_codex/native_inserts/9a061_pol76b.log), [Game sound trace](/private/tmp/labyrinth_codex/pol-76/before-windowed.VjBZVc/hover_sound.log)

`_queue_hand_pointer_resolve()` clears `_hovered_card_index` for a hand rebuild and defers the pointer hit test until the hand rests. `_resolve_hand_pointer()` restores hover through `_on_card_hover_started()`. The old index is now `-1`, so the handler sees a changed index and plays the hover cue even when the same card is still under the same pointer position. [Queue and deferred resolver](../../scripts/run_scene.gd#L16786), [Hover owner and cue](../../scripts/run_scene.gd#L20865)

**Fix.** The deferred resolver passes `play_hover_cue=false`. Native GUI enter signals and pointer restoration after cancelling selection also resolve silently. The mouse input observer still updates position and resolves hover on button events, and only a motion event with movement enables the cue. The focus navigation call retains its existing cue behavior. The shared hover handler keeps the index update, lift, rest wait, rail and presentation refresh. The patch leaves card selection and its sound on the existing code path. [Mouse input observer](../../scripts/hand_pointer_input.gd#L6), [GUI enter](../../scripts/run_scene.gd#L16748), [Focus navigation](../../scripts/run_scene.gd#L2929), [Selection cancellation](../../scripts/run_scene.gd#L21546)

Changed lines in `scripts/run_scene.gd` are `16752–16753`, `16823`, `20865`, `20876–20878`, and `21550`. The movement check and cue argument are in `scripts/hand_pointer_input.gd` at `9–12` and `29`.

The updated native probe checks one played tick on the first OS move onto Tempest Form, a silent draw and play with the cursor stationary and the live fan lifting the hovered card after both, then one played tick on a real move onto Pale Spark. It prints `POL-76 real-pointer double tick: FIXED` only after those checks pass. The trace logs each settled hovered index and lifted card ID. The before phase still reports the original reproduction. The updated launcher passed its headless dry-run. The windowed after trace remains to be run.

Item 5: covered by pol-62 on codex/release

## Item 6 — Pre-battle Equip icon

**STALE.** Collect and equip Grave Greatsword, enter a pre-battle room and inspect Equip and the weapon socket. Both live controls held the same `res://assets/art/equipment/grave_greatsword.png` texture. The button obtains the equipped weapon's item texture on both initial build and retained refresh. [Initial build](../../scripts/pre_battle_view.gd#L453), [Retained refresh](../../scripts/pre_battle_view.gd#L119), [Equipped weapon lookup](../../scripts/pre_battle_view.gd#L485), [Weapon socket source](../../scripts/pre_battle_view.gd#L542)

The before and after contracts each include `equip_weapon.png`.

## Proof for the design owner

Run these on the windowed host. Each phase prints a fresh absolute output directory, every PNG path, and the sound log path. The visual runner writes `visual_manifest.json` in the same directory. Full frames are 1920 × 1080. The rail crops are unscaled source regions enlarged 2× with nearest filtering. The two headless phases emitted sound trace files and runtime measurements. PNG readback and native pointer input require the windowed phases.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-76 && /private/tmp/labyrinth_codex/pol-76/native.sh before
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-76 && /private/tmp/labyrinth_codex/pol-76/native.sh after
```

## Verification

| Check | Observed result |
| --- | --- |
| Candidate 6 launcher dry-run | `POL-76 PROBE: PASS (headless dry-run)`, `TEST RESULT: PASS` |
| pol-76 launcher dry-run | `POL-76 PROBE: PASS (headless dry-run)`, `TEST RESULT: PASS` |
| Chronicle focused test | `CHRONICLE TEST RESULT: PASS` |
| Pre-battle focused test | `PRE-BATTLE VIEW TEST: PASS`, `TEST RESULT: PASS` |
| Magic deck rules | `MAGIC DECK TEST: PASS`, `TEST RESULT: PASS` |
| Magic deck input | `MAGIC DECK INPUT TEST: PASS`, `TEST RESULT: PASS` |
| UI identity lint | `Ran 25 tests in 6.330s`, `OK` |
| Rules text lint | `Ran 3 tests in 0.066s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| Existing projection probe on candidate 6 | Exit 1. `ERROR: No selectable playable card available for turn order projection probe.` |

The headless console transcripts are `/private/tmp/labyrinth_codex/pol-76/before-verified.log` and `/private/tmp/labyrinth_codex/pol-76/after-verified.log`. The dry-run sound traces are `/private/tmp/labyrinth_codex/pol-76/before-headless.9OWgQA/hover_sound.log` and `/private/tmp/labyrinth_codex/pol-76/after-headless.dNuSFB/hover_sound.log`.

The Godot processes also printed the sandbox's `get_system_ca_certificates` error. The pre-battle test printed its baseline exit-time resource warnings after the passing result. No baseline assertions were edited.

## Round 2 verification

| Check | Observed result |
| --- | --- |
| Updated native launcher, candidate 6 and fixed worktree headless | Both printed `POL-76 PROBE: PASS (headless dry-run)` and `TEST RESULT: PASS`. The fixed trace logged `sfx card.select played` on each card play. |
| Existing keyword focus check, controller and pointer | Both printed `KB02 KEYWORD FOCUS TEST RESULT: PASS`. |
| Existing resting-pointer check, `--hover-only` | Both printed `HAND POINTER TEST RESULT: FAIL`. Every failure in the fixed worktree also occurred on candidate 6. Candidate 6 additionally failed `Returning the same card to hover should not tick again`. |
| UI identity lint | `Ran 25 tests in 4.993s`, `OK` |

The headless launcher transcripts record the exact output directories and sound trace paths. The standalone resting-pointer test assertions are unchanged. [Candidate dry-run](/private/tmp/labyrinth_codex/pol-76/round2-before-final.log), [Fixed dry-run](/private/tmp/labyrinth_codex/pol-76/round2-after-final.log), [Candidate resting-pointer test](/private/tmp/labyrinth_codex/pol-76/round2-pointer-baseline.log), [Fixed resting-pointer test](/private/tmp/labyrinth_codex/pol-76/round2-pointer.log)

## Chosen defaults

The proof uses the existing Chronicle and Scavenger fixtures, a seed selected by the existing pre-battle fixture, Grave Greatsword, Spark Dart as the prior acquisition, Pale Spark as the purged spell and draw result, and Ash Hounds with 5 HP on available floor tiles. Tempest Form, Cinch Straps, Brace and Quick Stab populate the combat hand. Proof-only constants set the initial board cursor at `(500, 300)`, the rail crop to `(1680, 0, 240, 900)`, capture samples at 0.30 s into exhaust and 0.50 s after Hearth exhaust, the choice and redraw watchdogs at 3 s and 12 s, and the visual runner timeout at 120 s. The host preview is fitted inside the available screen area while the capture canvas stays exact.

## Files and open issues

The worktree contains the two hover audio edits in `scripts/run_scene.gd` and `scripts/hand_pointer_input.gd` and the proof tooling and report under `tools/pol76/`. The temporary launcher is installed. There are no TODO_DESIGN placeholders. The native after captures and sound verdict remain open.
