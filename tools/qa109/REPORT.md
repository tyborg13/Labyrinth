# qa-109 release probe audit

Base `5e1d4c13f11e173efb74e56d5aa6bf55feaac344` (`codex/release`). Both repairs are probe-only.

## 1. First-parent history

| Check | First-parent boundary | Evidence |
|---|---|---|
| Grimoire Upheaval | `60a46b2d9` (txt-13) | The original probe passed on `b8de863ef` and failed the Upheaval assertion on its immediate child `60a46b2d9`. The approved ship-02 merge `191c95e8b` added the article and its original expectation together. Txt-13 introduced the display-copy mapping that rewrites the final sentence. |
| Turn consumption | `c1f120e0d` introduced the timing-sensitive check. Its parent `1fc350a26` had no turn-order animation probe. | The original full probe reported the same zero-exits failure at `570f9d4bd` (before atk-10), `190c4c6c9` (atk-10), `191c95e8b` (before perf-135), `abe43eff7` (before perf-137) and release HEAD. The failure is frame-schedule-dependent, so a full-probe binary search for a stable pass/fail transition has no reliable predicate. |

The first-parent source search used `git log --first-parent -G` on the Upheaval display sentence and on `func _assert_single_turn_order_exit`. At `c1f120e0d` the probe already waited 100 ms plus a process-frame signal and counted a slot by position or opacity. The tween starts after a process-frame yield and uses cubic ease-in. A slow setup frame can put the sample at the start of that tween. `0d8a97e8c` lengthened the exit from 0.18 s to 0.22 s and adjusted the offset. It kept the same fixed sample. A controlled headless replay used the historical sampler threshold and each revision's tween parameters, with tween setup delayed to the 100 ms timer. This isolated replay covers the introduction commit. Full fight runs cover the later checkpoints in the table.

```text
HISTORICAL EXIT SAMPLER c1f120e0d initial_count=0 alpha=0.9992 y=-0.0191 later_count=1
HISTORICAL EXIT SAMPLER 0d8a97e8c initial_count=0 alpha=0.9996 y=-0.0035 later_count=1
HISTORICAL EXIT SAMPLER HEAD initial_count=0 alpha=0.9996 y=-0.0035 later_count=1
```

## 2. Classification and repairs

- **Grimoire — stale.** The live article's parsed text contains the owner's sentence verbatim. Txt-13's replacing sentence about breaking Outcrops reads “Outcrops can be broken like any terrain, even from inside when they surround you.” The probe still checks the complete visible article against literal expected copy.
- **Turn-order exit — stale probe timing.** The reported assertion samples the active player's consumed turn, a slide and fade. Enemy defeat runs in a separate case. On unchanged release production code the repaired probe detects the active player's real slide, collapse and insertion from observed controls and waits for settlement. It also uses the current rail geometry for the active portrait and includes the engine's pending Wait in the equal-time fixture.
- **Enemy defeat — verified on release.** The first death case targets the same enemy as its rail assertion. The former Burn fixture assumed the retired stack mechanic. Its replacement creates a real fight with the selected foe at 1 Health on Fire, then goes through the production Pass handler. The checks observe the board death first, the advancing dissolve on both scheduled portraits, their removal and combat input release. Reduced Motion and the other existing rail checks remain covered.

| Production Pass frame | Board dissolving | Both portrait progress values |
|---|---|---|
| 331 | Yes | No dissolve yet |
| 381 | Yes | 0.37654 |
| 382 | Yes | 0.39033 |
| 383 | Yes | 0.39551 |
| 556 | Finished | Both portraits gone |

## 3. Exit resources

The original report logged `ERROR: 16 resources still in use at exit (run with --verbose for details).` The verbose release reproduction logged `ERROR: 17 resources still in use at exit.` and listed the run scene, its scripts, a font and a pending GDScript function state among the objects and resources retained. The original assertion called `quit(1)` during rail motion and bypassed the probe's explicit scene teardown.

A controlled pair on release forced the same early sample. Both logged `ERROR: Expected exactly one turn order entry exiting; found 0.` and exited with failure. The immediate-quit case reported `ERROR: 2 resources still in use at exit.` The drain case waited for motion, freed the scene and produced no ObjectDB, resource, RID or allocator exit diagnostic. The repaired full passing probe likewise exited cleanly. Resource counts vary with the work pending at quit. This evidence attributes the reported diagnostic to early probe teardown.

## Headless results

```text
GRIMOIRE STEAM KEYBOARD: PASS
UPHEAVAL RENDERED: Marked tiles rise as Outcrops when the rule fires. A unit on a rising tile is pushed to a free tile beside it; the tile stays flat if a wall, a trap, a brazier or a unit that can't be pushed off is on it. Outcrops can be broken like any terrain, even from inside when they surround you.
GRIMOIRE SEARCH PROBE RESULT: PASS

TURN ORDER CONSUMED PLAYER: slide alpha=0.959 y=-0.33
TURN ORDER DEFEAT defeat actor=enemy:enemy_2 board_first=true overlap=true progressing_frames=70 board_finished=true
TURN ORDER DEFEAT pass_fire actor=enemy:enemy_2 board_first=true overlap=true progressing_frames=99 board_finished=true
TURN ORDER ANIMATION PROBE RESULT: PASS
```

Both headless commands used Godot 4.6.1 through the task runner. The Grimoire and Turn Order engine logs and the latter's frame traces are in the isolated run homes below. The macOS runner printed the existing CA certificate lookup message, `ERROR: Condition "ret != noErr" is true. Returning: ""`, in both runs.

- Grimoire log: `/private/tmp/labyrinth-godot-home/qa-109-1795082272091829000-20301/godot.log`
- Turn Order log: `/private/tmp/labyrinth-godot-home/qa-109-1795082420731018000-20579/godot.log`
- Turn Order traces: `/private/tmp/labyrinth-godot-home/qa-109-1795082420731018000-20579/Library/Application Support/Escape the Umbra Parallel qa-109-1795082420731018000-20579/probes/turn_order_defeat.jsonl` and `turn_order_pass_fire.jsonl` in the same directory.

## Proof for the design owner

Run the following on the macOS desktop. The visual runner prints the isolated output paths and writes the validated manifests. The Grimoire proof includes `grimoire_search_upheaval.png`. The Turn Order proof includes 19 phase images and the JSONL traces. The production Fire images are `turn_order_motion_v5_13_fire_board_death_active.png`, `turn_order_motion_v6_14_fire_overlapping_dissolve.png`, `turn_order_motion_v6_15_fire_board_settled.png` and `turn_order_motion_v5_16_fire_death_settled.png`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-109 && python3 tools/visual_probe_runner.py --task-id qa-109 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/grimoire_search_probe_contract.json --result-manifest .godot/qa109/grimoire-native.json tests/grimoire_search_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-109 && python3 tools/visual_probe_runner.py --task-id qa-109 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/qa109/turn_order_proof.json --result-manifest .godot/qa109/turn-order-native.json tests/turn_order_animation_probe.gd
```

## Chosen defaults and open proof

- Probe-only lethal fixture Health is 1. Scene setup uses the probe's existing seed 123 and the current Fire surface helper.
- Motion observation is bounded by 4 s and the full Pass by 12 s. These bounds apply only to the probe.
- `TODO_DESIGN` placeholders: none.
- Native screenshots and their visual validation are pending desktop execution. The headless frame traces record the live scene controls and animation state.
