# gfix-53 round 2 proof

The original native capture and a headless trace of `bd2f2f823` agreed on the failure. The first snapshot was taken while the hand layout was pending and the production HUD budget still had `desktop_hand_top=0`. The resulting board fit was `1920×1`, with 1-pixel tiles, even though the renderer had 49 tile positions and the Eclipse sight mask contained 13 tiles. Once the same scene finished its production HUD budget, the fit was `1920×738` and tile width was `159.7` pixels, with the same Eclipse state. [Original native capture](</private/tmp/labyrinth-godot-home/gfix-53-1795539542610100000-77774-native-1/Library/Application Support/Escape the Umbra Visual Probe gfix-53-1795539542610100000-77774-native-1/gfix53/01_shadowstep_stayed.png>) · [Headless diagnosis](/private/tmp/labyrinth-godot-home/gfix-53-1795543228739837000-1209/godot.log)

## Proof changes

- The probe waits for RunScene's hand fit, frozen HUD budget, and board-centering tween. The production framing solver supplies the fit and tile positions.
- The Shadowstep check uses the generated Last Watch arena at depth 22. Its proof setup positions the hero, Shade and Lamplighter, snuffs the east brazier, and sets the same Eclipse stage as round 1. Before the beat the Shade is hidden, the closer tile is blocked by an Illusion, and the farther tile is visible and open. The beat fires once and the Shade stays at (5, 4). A Light action then reveals that position while Eclipse remains active and the west brazier lights floor near the hero.
- Before saving, the probe requires the hero's production body rectangle to fit inside the viewport and visible floor samples to have combat-scale tile geometry. The Shadowstep case also requires the Shade and Lamplighter's body rectangles in frame. The windowed path compares the rendered floor samples against a frame with the board canvas hidden and rejects missing board pixels. Each saved capture remains at 1920×1080 and 100% UI scale.

## Headless receipts

```text
GFIX-53 NATIVE SHADOWSTEP: beat=1, Shade=(5, 4), stage=eclipse, actors in frame=true
GFIX-53 FRAME 01_shadowstep_stayed | fit=(1920.0, 738.0) | tile width=159.7 | hero in frame=true | visible floor tiles=20
GFIX-53 FRAME 02_ghost_stride_blink_2 | fit=(1920.0, 738.0) | tile width=163.9 | hero in frame=true | visible floor tiles=49
GFIX-53 FRAME 03_sunpath_lit_line | fit=(1920.0, 738.0) | tile width=163.9 | hero in frame=true | visible floor tiles=24
GFIX-53 NATIVE DRY RUN: 3 combat cases, 1920x1080, UI scale 100%, 0 failures
GFIX-53 WITNESSES: 8 checks, 0 failures
```

Commands were `tools/gfix53/native.sh --dry-run` and `python3 tools/godot_task_runner.py --task-id gfix-53 --stream -- godot --headless --path . --script tools/gfix53/witnesses.gd`. Both exited 0. Godot printed the same resource-in-use shutdown warning as the round 1 dry run. [Final dry-run log](/private/tmp/labyrinth-godot-home/gfix-53-1795543445672468000-5156/godot.log) · [Round 1 witnesses log](/private/tmp/labyrinth-godot-home/gfix-53-1795543393898754000-2374/godot.log)

A temporary diagnostic bypassed the layout wait and reproduced the `1920×1` fit with 1-pixel tiles. The new floor assertion rejected `01_shadowstep_stayed` and the probe exited 1. [Negative check](/private/tmp/labyrinth-godot-home/gfix-53-1795543455535992000-5203/godot.log)

## Native capture

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-53 && tools/gfix53/native.sh
```

The windowed run is pending with the design owner. The script prints the absolute output paths and validates the three files in the isolated `user://gfix53/` directory.

## Chosen proof defaults

The Shadowstep setup uses room coordinate (2, 1), depth 22 and Lamplighter tile (7, 3). The framing wait is bounded at 3 seconds. The geometry guard requires 24-pixel tile width and at least three visible floor samples. The native image comparison uses the repository's existing combat-proof thresholds of 0.04 luminance and 0.08 RGB distance. These values apply inside the probe.

The proof changes are uncommitted on `bd2f2f823`.
