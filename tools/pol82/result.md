# pol-82 controller status chips

Implementation is uncommitted in `codex/pol-82`, based on `codex/release` at `38a6abf32`.

## Acceptance

1. A focused living hero or enemy exposes the status pills in the board’s retained layout. The controller passes each pill’s existing hover text and actor context to `CombatBoardView._make_custom_tooltip`, which uses the same tooltip panel builder as mouse hover. Panels retain their individual widths and follow chip order, reading each wrapped row left to right. The stack starts at the first chip’s center plus Godot’s native mouse tooltip offset, with no HUD avoidance. The analog cursor presents the stack with the existing focus callout and clears it when focus leaves, card aiming starts, or mouse input takes over. The chipless control case has zero panels.
2. The release and candidate mouse receipts are byte-identical. The same Expose chip opened the same native panel text at 372 × 100, and unit and floor hover resolved to the same tiles and content.
3. The title Grimoire’s 18 creature pages were measured after normal layout at 1920 × 1080 and 100% UI scale. Zekarion had the tallest content at 647 px in a 312 px scrolling area. The held right stick took the scrollbar from 0 to its maximum of 335 px and back to 0.

## Director feedback 1

The original native captures showed `WOODEN BOX` in the two-chip and chipless frames. The same replay on `codex/release` at `38a6abf32` reproduced it headless at `(1051, 387)` in both states. The controller detail key was empty. The pointer had last hovered the box at `(4, 3)` during mouse parity sampling. Its pending hover timer opened a native board tooltip window after the switch to pad, and that window persisted as pad focus moved from the hero to the Crawler. [Original two-chip capture](/private/tmp/labyrinth_codex/pol-82/native.Z95Wd9/combat_status_two_chips.png) · [Original chipless capture](/private/tmp/labyrinth_codex/pol-82/native.Z95Wd9/combat_status_chipless.png)

The board now dismisses open mouse tooltip windows at the handoff and rejects delayed mouse tooltip requests during pad focus. Pointer mode can open native tooltips again. The headless replay waited through the native tooltip delay and checked the two-chip stack against other visible panel rectangles, including those in embedded windows. It found zero intersections. The chipless Crawler kept the same focus and controller callout as release, with the stale mouse popup gone.

## Changed files and line ranges

| File | Candidate lines | Change |
| --- | --- | --- |
| `scripts/controller_status_chips.gd` and `.gd.uid` | New files | Select, build, position, and clear the stack |
| `scripts/controller_analog_cursor.gd` | 5, 16–17, 36–37, 56–58, 66 | Bind stack updates and clearing to cursor visibility |
| `scripts/run_scene.gd` | 2550, 2559, 2574, 3275–3276 | Connect the board, pass the focused tile, and relay pointer modality |
| `scripts/combat_board_view.gd` | 773, 5264–5268, 5270, 5409, 5425 | Retire native mouse tooltips on pad handoff and accept status context at the existing builder entry point |
| `tools/pol82/combat.gd` and `.gd.uid` | New files | Combat replay, mouse parity, and capture assertions |
| `tools/pol82/grimoire.gd` and `.gd.uid` | New files | Creature page measurement and right-stick input |
| `tools/pol82/native.sh`, `proof.json`, and `result.md` | New files | Launcher, PNG contract, and receipts |

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-82 && tools/pol82/native.sh --release ../release
```

The launcher selects `LABYRINTH_CEL_LOOK=all` and runs the same seeded replay and pad inputs against both worktrees through the visual probe runner. It prints an absolute path for each of the six 1920 × 1080 PNGs and writes `renderer_manifest.json` alongside each set. The release chipless image will be at `native.*/release/combat_status_chipless.png` under the output root. Omitting `--release` runs the candidate alone.

```text
/private/tmp/labyrinth_codex/pol-82/native.*/{release,candidate}/combat_status_tooltip.png
/private/tmp/labyrinth_codex/pol-82/native.*/{release,candidate}/combat_status_two_chips.png
/private/tmp/labyrinth_codex/pol-82/native.*/{release,candidate}/combat_status_chipless.png
```

The headless replay can compare against the release mouse receipt.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-82 && tools/pol82/native.sh --dry-run --release ../release
```

The `--release` run passes the release mouse receipt to the candidate and checks their parity. The receipts were byte-identical. [Release mouse receipt](/private/tmp/labyrinth_codex/pol-82/headless.NUQiaw/release/mouse.json) · [Candidate mouse receipt](/private/tmp/labyrinth_codex/pol-82/headless.NUQiaw/candidate/mouse.json)

```text
POL-82 mouse Expose popup: ["EXPOSE", "The next hit that damages an Exposed unit deals 2 more damage."] (372.0, 100.0)
POL-82 RELEASE COMPARISON: PASS
POL-82 release mouse parity: PASS
POL-82 combat_status_tooltip: PASS (1 chip tooltips at (5, 4))
POL-82 two-chip panel overlap: PASS (0 intersecting panels)
POL-82 combat_status_two_chips: PASS (2 chip tooltips at (4, 4))
POL-82 combat_status_chipless: PASS (0 chip tooltips at (4, 5))
POL-82 focus, card aim and mouse handoff: PASS
POL-82 open mouse popup handoff: PASS
POL-82 Grimoire: 18 pages, tallest=enemy:zekarion, content=647.0 px, viewport=312.0 px, scrollbar=true, range=335.0, stick=0.0 -> 335.0 -> 0.0, reached_end_and_back=true
POL-82 PROBE: PASS
```

[Release Godot log](/private/tmp/labyrinth-godot-home/pol-82-1795534155083718000-28069/godot.log) · [Candidate Godot log](/private/tmp/labyrinth-godot-home/pol-82-1795534164698988000-28089/godot.log)

- `python3 tests/test_ui_identity_lint.py` reported `Ran 25 tests in 4.169s` and `OK` after the handoff fix.
- `python3 tests/test_rules_text_lint.py` reported `PASS: Rules text lint (16 existing hits)`.
- `python3 tools/run_python_suite.py --shards 4 --changed-since 38a6abf32 --output-dir /private/tmp/labyrinth_codex/pol-82/python-default-final` reported `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 27.068s` and `OK`. [Log](/private/tmp/labyrinth_codex/pol-82/python-default-final.log)
- Shell syntax, JSON syntax, and Git whitespace checks passed.

## Chosen defaults

- The proof reused pol-81’s seed `919042`, hand, clear-Umbra stage, three-enemy roster, and Expose 2 on the Crawler at `(5, 4)`. It added Shock 1 and Expose 2 to the hero at `(4, 4)` for the two-chip capture in the same fight. The second Crawler at `(4, 5)` was the chipless sample. The pointer’s floor sample used `(4, 3)`.
- The probe uses synthetic device 0, a 60 FPS cap, six layout frames, a 12-second state wait, at most 32 D-pad steps per route, and a 1.5 px comparison tolerance for the integer native popup position. The desktop preview window uses a 64 × 96 margin while captures use the full 1920 × 1080 SubViewport.
- Grimoire holds full right-stick deflection for four seconds in each direction and checks the endpoints within 1 px. The proof launcher creates a fresh output directory for every run.

## TODO_DESIGN

None.

## Open issues

The six revised native PNGs are pending because this sandbox lacks macOS window-server access. The headless comparison produced no PNGs. Godot printed the macOS certificate lookup diagnostic while completing both replays with exit code 0.

The Python runner reported `[Errno 1] Operation not permitted` when writing the optional Git timing cache. The suite returned exit code 0.
