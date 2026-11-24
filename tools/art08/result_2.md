# art-08 round 2

## Adoption

- Copied the director's take-6 PNG byte-for-byte to the canonical `processed.png` and production `assets/art/enemies/burrow_mound.png`. Copied `processed_6.json` and `sheet_6.png` to the canonical sidecar and review sheet. Generated the three import sidecars for the numbered raw, processed, and sheet PNGs. Existing import settings and director input bytes were preserved.
- The registry records take 6 and the 2026-11-24 PASS in `judge_6.md`. The art is 156 × 43 px with opaque rows 203–245 and columns 50–205. Exceptions are height `43.0`, `base_v_left = 0.15174069627851158`, and `base_v_right = -0.1547659063625448`. The loose soil flattens the measured base line as described in the judge's first item. Value `0.34334246070328955` is in band.
- The cel builder regenerated the `actor` variant with `burrow_grub/front` defaults. The mound and erupt body reported `ACTOR(4)` with the same ambient and full opacity throughout the launcher fixture.

| Binding | SHA-256 |
| --- | --- |
| Raw PNG bytes | `799445e1623227e131be362e53328306b8e7feddc0dbe0400261b4578efce295` |
| Approved source and production pixels | `02f77175e70069ea796564de334de3eb08e194462caa3583a1ecbbdc2f931d78` |
| Supplied kit bytes | `cde58ea8f31d6acf2a108633f450ac41598197855ab985e47bdf3164c4ed5257` |
| Supplied prompt bytes | `c7d7907da06de40c8ebcbfe614d2a90fbb915c11869318a1965f335fa0c281e3` |
| Prompt hash recorded inside the supplied kit | `3d3d88ef91c2cf7b5fb46521e0db7708e1b47e5a5af6a76b8fc9f59376d4e3bf` |

**Certification remains blocked by the supplied prompt binding.** The kit hash for the prompt matches the prefix before the appended `## Delivery` section. The registry records the actual full prompt hash. The protected kit and prompt retain the supplied bytes. Strict certification reported the following.

```text
FAIL assets/art/enemies/burrow_mound.png: prompt digest changed; recorded prompt digest differs from registry
ART IDENTITY CHECK: FAIL (1 failures, 0 pending_reart warnings, 0 skipped replays)
```

## Placement and health bar

The neutral canvas anchor is `(128, 224)` at the board's projected tile centre. Breath scales about the opaque bottom edge, keeping that edge fixed. The same peak draw rectangle determines the bar's art boundary. The bar uses the existing standing-unit clearance. When the HUD solver needs extra space, the burrowed group can move sideways or upward. The Erupt badge retains its original placement.

All measurements below are in board coordinates. The existing launcher fixture holds the Grub on (3, 4). A scratch check moved it to (6, 4) beside the same hero fixture at (4, 4) on the EN01 board.

| Grub tile | Tile centre Y | Soil middle Y at peak / trough / reduced | Fixed base Y | Peak soil top Y | Placed bar bottom Y | Gap |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| (3, 4) | 416.6653 | 416.5582 / 417.5113 / 417.0347 | 432.9209 | 400.1954 | 396.1954 | 4.0000 |
| (6, 4) | 553.8621 | 553.7550 / 554.7081 / 554.2316 | 570.1177 | 537.3923 | 533.3923 | 4.0000 |

A scratch crowded-placement case blocked both the natural and raised rows. The ordinary 20 × 10 test frame moved down 14 px. The burrowed test frame stayed at its anchor in both regular and incremental placement.

## Checks

| Check | Observed result |
| --- | --- |
| Godot parse | Exit 0 for `burrow_view.gd`, `combat_board_view.gd`, `board_status_layout_cache.gd`, `verify.gd`, `mound_check.gd`, `luma_capture.gd`, and both EN01 scripts |
| Headless launcher | `ART-08 HEADLESS: PASS` for before, after, and reel |
| Pinned-base playback | `ART-08 BASE PARITY burrow: PASS (301 samples, including root alpha, poses, timing and combat state)` and `ART-08 BASE PARITY erupt: PASS (339 samples, including root alpha, poses, timing and combat state)` |
| Extra geometry | `ART-08 ROUND 2 EXTRA GEOMETRY: PASS` |
| EN01 | `EN01 ENEMIES TEST RESULT: PASS` |
| Marked tools and Burrow targeting | `MRK01 MARKED TEST: PASS (69 checks, 0 failures)` |
| Board status plates | `BOARD STATUS PLATES TEST RESULT: PASS (28640 assertions; 0 failures)` |
| Burrow Grub production clip logic | `MAQUETTE PRODUCTION LOGIC: PASS (1106 frames)` |
| UI identity lint | `Ran 25 tests in 3.970s` and `OK` |
| Art identity gate | `Ran 111 tests in 75.705s` and `FAILED (failures=1)`, the same protected kit and prompt mismatch as the strict check |
| Byte copies and staging | The four canonical and production copies match their take-6 sources. The two director-staged renames are intact. Shell syntax and `git diff --check` passed. |

[Launcher log](/private/tmp/labyrinth_codex/art-08/round2-dry-run.log), [geometry log](/private/tmp/labyrinth_codex/art-08/round2-extra-geometry.log), [gate log](/private/tmp/labyrinth_codex/art-08/round2-art-gate.log), [headless after trace](/private/tmp/labyrinth_codex/art-08/dry-run/after/frames.json), and [production clip logic](/private/tmp/labyrinth_codex/art-08/round2-rr12).

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-08 && /private/tmp/labyrinth_codex/art-08/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/art-08 && python3 tools/art08/luma.py
```

The launcher and luma reader are unchanged. The launcher writes the native stills to `/private/tmp/labyrinth_codex/art-08/native/{before,after}`. The owner runs the Hollow Antechamber capture and luma acceptance. This round produced headless geometry and timing evidence. No design placeholders. Work remains uncommitted.
