# gfix-39 implementation and proof

## Root cause and baseline

The first-step interruption used the same resolver and playback path as a walk with no traversed tiles. Playback had no collision payload and the next navigation query had no memory of the tile.

The supplied QA-133 checkpoint at seed 133001, decision 3667, has Vaulting Sigil equipped. In candidate 7, acolyte 6 at `(2, 2)` is visible to the hero and acolyte 5 at `(3, 2)` is hidden. Vaulting Sigil permits crossing the visible enemy and offers the apparently empty landing. Its existing occupied-landing check trims both occupied tiles, yielding a zero-step move without advancing the ordinary Umbra interruption counter. The hero bumps toward the first unreached step at `(2, 2)`. The shade and memory mark the hidden landing at `(3, 2)`. The repeat offer and path to that landing disappear. Vaulting Sigil can still cross occupied tiles on routes to other legal landings.

Both baseline paths were `(1, 2) → (2, 2) → (3, 2)`.

| Fixture | Baseline endpoint | Implemented endpoint | Movement spent in both | Interruption counter delta in both |
| --- | --- | --- | --- | --- |
| QA-133 checkpoint | `(1, 2)` | `(1, 2)` | 0 | 0 |
| One-step Eclipse fixture | `(2, 2)` | `(2, 2)` | 1 | 1 |

## Requirements

1. The movement playback uses the reached path and appends the prescribed quarter-tile bump. The forced-movement impact path provides the shared `push.collision` cue through [SfxCueRouter](../../scripts/sfx_cue_router.gd). Its damage reaction has no reusable positional lunge.
2. The bump uses [the Shadowstep shade factory](../../scripts/battlefield_rule_view.gd) and the same board ghost renderer and anchor. The contact frame starts the shade and cue. The shade fades in for 120 ms, holds for 600 ms and fades out for 300 ms. Reduced motion shows the static shade for 900 ms. The board keeps its pre-walk enemy visibility during the bump. In the one-step fixture ordinary sight reveals the crawler when the move finishes.
3. [Umbra movement memory](../../scripts/umbra_movement.gd) is persisted by enemy id, enemy anchor and blocked tile. Hero Move offers and previews read the remembered tiles as occupancy. Movement, reveal, death and combat end prune the memory. The existing Glassway trade cost search bypasses walking memory because the trade skips its intervening tiles.
4. The existing independent-move events carry `blocked_tile` as `{x, y}` and `steps_reached` on bumps. The first-step case emits `player_movement_interrupted`. The one-step case emits `player_moved`. The existing `umbra_movement_interruptions` tally retains its meaning. [Analytics specification](../../spec/analytics.md#surface-rules-v5)
5. The focused state test checks both baseline outcomes, save/resume, disappearance of the repeat offer, Shadowstep, Vision, area death and combat end. The scene probe checks the movement interaction, shade, sound cue, blocked tile and local analytics in both motion settings.

## Changed files

| File | Changes |
| --- | --- |
| `scripts/combat_engine.gd` | Changed lines 148, 1550–1553, 1588, 1672, 1817, 1859, 1868–1869, 1878–1881, 3503–3504, 3526–3529, 7670, 7676–7678, 7686, 7692–7696, 8436, 8438–8439, 12187 and 12205. |
| `scripts/run_scene.gd` | Changed lines 21932, 23319, 23712, 23757–23758 and 23765–23766. |
| `scripts/umbra_movement.gd` and `scripts/umbra_movement_view.gd` | State and playback helpers with adjacent Godot UIDs. |
| `scripts/battlefield_rules/committed.gd` and `scripts/surface_variety_relic_rules.gd` | Prune on accepted transitions and preserve occupied intermediate tiles for Vaulting Sigil. |
| `scripts/movement_undo_rules.gd` | Treat the move summary fields as bookkeeping and report memory changes without expanding enemy ids into analytics. |
| `scripts/battlefield_rule_view.gd`, `scripts/combat_board_view.gd` and `scripts/sfx_cue_router.gd` | Share the shade factory, board ghost drawing and collision cue. |
| `spec/analytics.md` | Explain the two optional fields and the existing counter. |
| `tools/gfix39/` | Fixtures, focused state test, exact-size scene probe, Godot UIDs, proof contract and native launcher. |

## Headless receipts

```text
GFIX-39 BUMP STATE: 13 checks, 0 failures
GFIX-39 STRIP first_normal 39 samples, 103 shade frames, 1 collision cue
GFIX-39 STRIP first_reduced 31 samples, 90 shade frames, 1 collision cue
GFIX-39 STRIP one_step_normal 49 samples, 102 shade frames, 1 collision cue
GFIX-39 STRIP one_step_reduced 42 samples, 90 shade frames, 1 collision cue
GFIX-39 SCENE STRIPS: 4 cases, 0 failures (headless dry run)
GFIX-39 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/gfix-39/headless.FDBewB
```

- Baseline scene run `/private/tmp/labyrinth-godot-home/gfix-39-1795462291674557000-43900/godot.log` printed `GFIX-39 SCENE REPLAY: PASS` and both baseline outcomes. The initial worktree cache had missing imports. Restoring 96 matching ignored cache files from candidate 7 removed those resource errors from later runs.
- Focused state log `/private/tmp/labyrinth-godot-home/gfix-39-1795462923076319000-52629/godot.log`.
- Final scene dry-run log `/private/tmp/labyrinth-godot-home/gfix-39-1795463053634558000-53283/godot.log`. Its output directory contains the per-case saves, settings and analytics. The headless run emits no PNGs. The macOS CA certificate diagnostic appears on the baseline and focused Godot runs.
- UI identity lint printed `Ran 25 tests in 4.367s` and `OK`.
- Rules text lint printed `Ran 3 tests in 0.050s`, `OK` and `PASS: Rules text lint (16 existing hits)`.
- Python default group printed `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 35.560s` and `OK`. Results are at `/private/tmp/labyrinth_codex/gfix-39/python-default/summary.json`. The runner passed and could not write its learned timing cache in the read-only Git directory.
- `git diff --check` passed. The full Godot suite was outside this round's proof.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-39 && /private/tmp/labyrinth_codex/gfix-39/native.sh
```

The launcher captures 1920×1080 at 100% UI scale with `LABYRINTH_CEL_LOOK=all`. Each case has before and after move-offer images and a frame every 30 ms from the click through the first sample after the shade disappears. The launcher prints the absolute PNG paths and writes a validated manifest in a fresh `/private/tmp/labyrinth_codex/gfix-39/native.*` directory. The headless invocation adds `--dry-run` to the same command.

## Chosen defaults

- The synthetic Eclipse fixture uses seed 39001, a hero with 30 fixture Health, a 1-Health crawler at `(3, 2)` a survivor at `(7, 7)` and a one-card Tremor hand.
- The focused clearing proof frees the Shadowstep landing by moving the already-visible acolyte to `(5, 5)` in its private copy. It uses Blink range 2, one Vision activation and a 1-damage area.
- The probe samples a 100 fps clock at three-frame intervals, waits up to 12 seconds for scene readiness, settles for eight frames and allows up to 5 seconds of simulated time for a strip. The native launcher allows 300 seconds for rendering and PNG encoding.

## Open issues

Native render and audio inspection remain pending on a Mac with window-server access. There are no `TODO_DESIGN_*` placeholders. All edits are left uncommitted on `codex/gfix-39`.
