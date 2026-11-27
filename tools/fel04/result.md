# fel-04 implementation and proof

Each marked area draws one medallion. Tharokh went from 20 to 1 and Craghide went from 16 to 1 in the fixture witness. The owner-run round-0 captures showed both reductions with the red area outline intact. [Round-0 native capture manifest](captures/native.x78tOm/visual-proof.json)

## Feedback 3

The tile tooltip omits a mark when the mark's source enemy has a visible intent label in the same layout the HUD paints. The shared mouse and focus builder retains the other entries in their existing order. A mark stays available while its source's label is absent, including hidden enemies. Player Meteorfall and pending walls retain their entries. When an entry combines sources, every contributing source must have a visible label before the entry is omitted. An empty stack returns empty text and the custom builder rejects both empty text and an encoded empty stack.

The medallion counts and anchors still match the approved grouping. The two marked examples were checked against the director's round-2 recapture. [Faultline before](captures/native.cCdlRU/04-s0-seed1-0-4_0-t9-hover.png) · [Groundsplit before](captures/native.cCdlRU/10-s2-seed8-2-10_-2-t16-hover.png)

| Fixture | Mouse hover | Focus after inspection | HUD label |
| --- | --- | --- | --- |
| Iskaldra, (2, 2) | Ice | Ice | — |
| Tharokh, (2, 3) | Crag Outcrop only | Rubble only | Faultline |
| Craghide, (4, 2) | No popup | No popup | Groundsplit |

The existing Tharokh pointer route resolves a neighboring Outcrop while direct focus on `(2, 3)` resolves Rubble. Both omit Faultline. The witness also focused an Outcrop at `(2, 5)` and obtained the same Outcrop-only stack as the mouse popup. This round leaves the separate square-routing behavior to fel-07. Keyboard board focus uses the same tile-detail route as controller focus and keeps its existing targeting behavior.

Before either source label expanded, the witness found the original Faultline and Groundsplit entries. The edge probe also covered an enemy-sourced Meteorfall, player Meteorfall, hidden enemy marks, and a pending wall.

```text
FEL04 WITNESS PASS states=3
FEL04 EDGE SOURCES player_kept=true enemy_removed=true hidden_kept=true pending_wall_kept=true
FEL04 EDGE PROBE PASS failures=0
BOARD TILE TOOLTIPS: PASS checks=233 failures=0
BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)
BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)
```

UI identity lint reported `Ran 25 tests in 4.749s` and `OK`. Rules-text lint reported `Ran 3 tests in 0.066s` and `OK`. [Dry run](captures/feedback3-dry.log) · [Edge probe](captures/feedback3-edge.log) · [Tooltip suite](captures/feedback3-tile-tooltip.log) · [Routes](captures/feedback3-routes.log) · [Live](captures/feedback3-live.log) · [UI lint](captures/feedback3-ui-identity.log) · [Rules lint](captures/feedback3-rules-text.log)

Round 3 changed the tile tooltip builder and cache, the popup assembly in `scripts/combat_board_view.gd`, and the witness, wrapper, and report in `tools/fel04/`. The native wrapper's `--dry-run` runs the same witness headless and produced the results above. Windowed recapture remains pending. The protected fixtures and previously approved visuals were left intact.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-04 && bash tools/fel04/native.sh --dry-run
```

## Feedback 2

Grouped Marked badges and the per-tile stack share one formatter. The panel keeps the Marked icon and uses the move name and the existing board intent rows for its copy. The tile stack resolves the standing line for the inspected tile and replaces the previous Marked entry in place. The singleton proof confirmed the existing generic entry for a group of one. The owner-run review still shows the approved placement and floor geometry. [Native sheet](review/native_sheet.png) · [Groundsplit hover before this fix](review/hover10_zoom.png) · [Native manifest](captures/native.PX9g0I/visual-proof.json)

| Fixture | Native recapture hover | Hero tile | Verified move copy |
| --- | --- | --- | --- |
| Iskaldra turn 13 | (2, 2) | — | Ice control, zero marks |
| Tharokh turn 9 | (2, 3) | (4, 4) | Faultline, Burst 8 for each Worldspine, Ranged 4, Range 4 |
| Craghide turn 16 | (4, 2) | (3, 2) | Groundsplit, Melee 8 within 2 tiles of each Outcrop |

The non-anchor mouse panels exactly matched the medallion title, icon, and body with the standing line cleared. The hero tile's stack matched the medallion registration including the standing line. The witness checked the actual popup for each non-anchor hover and compared the shared RunScene focus candidate for each tile. Keyboard movement focus uses that candidate through the controller board path and keeps the existing targeting-time tooltip suppression. The hero's stack was verified through tile focus because passive mouse hover over living units is suppressed.

Groundsplit's full mouse and focus stacks matched. At the existing Faultline capture point, the pointer resolves the nearby Crag Outcrop while tile focus resolves Rubble on `(2, 3)`. Both show exactly the same Faultline entry. The pointer's square routing belongs to fel-07.

```text
FEL04 WITNESS PASS states=3
FEL04 EDGE SINGLETON generic_unchanged=true
FEL04 EDGE PROBE PASS failures=0
BOARD TILE TOOLTIPS: PASS checks=233 failures=0
BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)
BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)
```

UI identity lint reported `Ran 25 tests in 6.708s` and `OK`. Rules-text lint reported `Ran 3 tests in 0.081s` and `OK`. Round 2 changed `scripts/boss_area_marks.gd`, `scripts/board_tile_tooltip.gd`, and the witness and report under `tools/fel04/`. The recapture targets are the two non-anchor tiles from the owner-run native proof. [Witness](captures/feedback2-witness.log) · [Edge probe](captures/feedback2-edge.log) · [Tooltip](captures/feedback2-tile-tooltip.log) · [Routes](captures/feedback2-routes.log) · [Live](captures/feedback2-live.log) · [UI identity](captures/feedback2-ui-identity.log) · [Rules text](captures/feedback2-rules-text.log)

## Feedback 1

1. **Retained anchor refresh.** An occupancy submission queues the effects layer if an effects canvas drew a mark badge in its last draw. The existing submission batch coalesces the request with any redraw already queued. In the edge probe, the hero moved to `(5, 5)` and both retained badges moved to `(4, 5)` in one frame. Adding an Outcrop also moved both anchors. Clearing the marks reset the repaint flag.
2. **Cover-aware anchors.** The shared helper ranks clear, covered, and occupied candidates before comparing screen Y and then screen X. A candidate checks its three screen-front neighbors against the same occupancy map and the blocking grid tiles. The Tharokh witness selected **`(2, 6)`**, a clear floor tile under this rule. Craghide stayed at **`(4, 6)`**. The revised renderer captures are pending.
3. **Group standing line.** Icefall, Erupt, and Meteorfall register the standing line according to group membership. The edge probe inspects the retained Meteorfall and Icefall badge registrations and checks that the line is present when the hero stands on a different tile in the group and absent after leaving. The per-tile index keeps each tile's original copy. The mouse handler displays the per-tile stack and suppresses floor tooltips over living units.

The five painters group marked tiles by source, icon, displayed number, and edge connectivity. Floor treatments, paint parameters, layer order, Meteorfall exclusion, from-boss areas, and rules text use their original paths. The helper visits marked tiles and reads the submitted objects and living footprints without scanning the whole grid.

## Changed files

- Runtime grouping and painting in `scripts/mark_badge_groups.gd`, `scripts/boss_area_marks.gd`, `scripts/enemy_mechanics/lob_view.gd`, `icefall_view.gd`, `burrow_view.gd`, and `scripts/combat_board_view.gd`.
- Proof in `tools/fel04/witness.gd` and `mark_witness.gd`, with `native.sh`, `proof_contract.json`, and this report. The new GDScripts have UID sidecars.
- The protected fixtures and `tools/fel01/` match the checkout. All changes are uncommitted.

## Headless witness

| Fixture | Groups | Base medallions | Branch medallions | Branch anchor | Hover proof |
| --- | ---: | ---: | ---: | --- | --- |
| Iskaldra turn 13 | 0 | 0 | 0 | None | Ice at (2, 2) |
| Tharokh turn 9 | 1 | 20 | 1 | (2, 6) | Marked at (2, 3) |
| Craghide Guardian turn 16 | 1 | 16 | 1 | (4, 6) | Marked at (4, 2) |

The base used the runtime files from `e5451a38e` with the supplied saves. The witness counted the icon rectangles registered by the effects painters and compared the anchors with an independent reference. Each save reported `all_tile_tooltips=true` for the per-tile index.

```text
FEL04 WITNESS FAIL states=3 fixtures=04-s0-seed1-0-4_0-t9,10-s2-seed8-2-10_-2-t16
FEL04 WITNESS PASS states=3
FEL04 EDGE MOVE frame_delta=1 hero=(5, 5) before={ "Meteorfall": [{ "anchor": (5, 5), "standing": false }], "Icefall": [{ "anchor": (5, 5), "standing": false }] } after={ "Meteorfall": [{ "anchor": (4, 5), "standing": true }], "Icefall": [{ "anchor": (4, 5), "standing": true }] }
FEL04 EDGE STANDING inside=true outside=true tile_index_and_pointer=true
FEL04 EDGE CLEARED repaint_flag=false
FEL04 EDGE PROBE PASS failures=0
```

[Base witness](captures/feedback1-witness-base.log) · [Branch witness](captures/feedback1-witness-branch.log) · [Edge probe](captures/feedback1-edge.log)

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id fel-04 --stream -- godot --headless --path . --script tools/fel04/witness.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-04 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id fel-04 --stream -- godot --headless --path . --script tools/fel04/witness.gd -- --edge
```

## Focused verification

```text
ENC04 FORECAST TEST: PASS (128 configurations; 1554 checks; 0 failures)
EN01 ENEMIES TEST RESULT: PASS
FEL04 FOCUSED en02_enemies_suite.gd PASS checks=226 failures=0
FEL04 FOCUSED card_mechanics_surfaces_suite.gd PASS checks=255 failures=0
FEL04 FOCUSED boss_area_rules_suite.gd PASS checks=311 failures=0
FEL04 FOCUSED dragon_area_presentation_suite.gd PASS checks=15 failures=0
FEL04 FOCUSED mrk01_marked_suite.gd PASS checks=69 failures=0
BOARD TILE TOOLTIPS: PASS checks=233 failures=0
BRS02 FOCUSED RESULT: PASS (442 checks; 0 failures)
```

[Focused suites](captures/feedback1-focused.log) · [Tile tooltip suite](captures/feedback1-tile-tooltip.log) · [BRS02 regression log](captures/feedback1-brs02.log)

UI identity lint reported `Ran 25 tests in 6.094s` and `OK`. Rules-text lint reported `Ran 3 tests in 0.083s` and `OK`. The native wrapper passed `bash -n`, and `git diff --check` passed. There were no Python source changes in this round, so the round-0 Python default result remains the latest. [UI identity lint](captures/feedback1-ui-identity.log) · [Rules-text lint](captures/feedback1-rules-text.log) · [Round-0 Python default log](captures/python-default.zKdFHO/runner.log)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-04 && bash tools/fel04/native.sh
```

The command writes six 1920×1080 PNGs at 100% UI scale under `tools/fel04/captures/native.*/`, alongside `visual-proof.json` and `runner.log`. Each fixture ID prefixes the rest and hover PNGs. Iskaldra's hover shows the existing Ice tooltip because the supplied save has zero marks. No windowed command ran in this sandbox.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The native probe reuses the fel-01 settle of 0.35 seconds plus two frames, its entrance wait of 90 frames plus 2 seconds, the tile-tooltip probe hover wait of 1.5 seconds, and a 180-second timeout. The pointer starts off the board.
- The edge probe uses an existing En02 board at 1920×1080. Its test-only tiles, damage, and initial four-frame settle are named in `mark_witness.gd`. Each update is inspected on the first frame after its submission.
- The hover probe reuses the owner-run non-anchor tiles for Tharokh and Craghide. The control picks the first tile with an existing tooltip.
