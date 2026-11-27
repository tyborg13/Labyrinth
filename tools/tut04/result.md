# tut-04 first-Umbra tutorial

## Requirements

1. The card displays `UMBRA`, `The Umbra`, and exactly `Enemies on dark tiles are hidden: you can't target them or see their intents.` Both input modes read `UMBRA_RULE` from the same phase definition.
2. The HUD tooltip contains the stage label and `UMBRA_RULE` as its two text lines. The popup keeps the shared uppercase heading style. All six visible stages passed the exact text check. A real hover opened the Fringe popup with the card still visible.
3. The retained Umbra world pass takes the floor subset of its darkening mask and traces only exposed tile edges. The contour pass uses the guide's accent, widths, halo and pulse, including the static reduced-motion treatment. It draws at floor level before actors and scene props. The dimmer opens a frameless hole over the board's floor bounds and keeps the stage label lit without its frame. Continue and prompt suppression clear the outline. The headless fixture verified complete, closed contours and a live mask update.
4. The trigger witness verified the first qualifying turn, animation and profile suppression, save/resume before Continue, controller acknowledgement, profile and run persistence, and the single `guided_tutorial_step_completed` receipt for `umbra_read`. The existing integration suite passed its other lesson and spotlight checks. The Grimoire and combat-rule files were outside this unit's changes.

## Files changed

| Files | Change |
| --- | --- |
| [contextual_combat_tutorial.gd](../../scripts/contextual_combat_tutorial.gd#L90) | Shared Umbra sentence and phase title |
| [contextual_combat_prompt.gd](../../scripts/contextual_combat_prompt.gd#L286) | Frameless dimmer support and shared frame styling |
| [run_scene.gd](../../scripts/run_scene.gd#L7839) | Outline lifecycle, board hole, and two-line HUD tooltip |
| [combat_board_view.gd](../../scripts/combat_board_view.gd#L6223) | Floor outline geometry and draw pass |
| [tut02/proof.gd](../tut02/proof.gd#L77), [tut02/witness.gd](../tut02/witness.gd) | Updated title, body, tooltip, spotlight and truth expectations. The trigger proof samples the displayed body in both modes. The truth witness retains its original fixture and removes TRUTH 3. |
| [outline_check.gd](outline_check.gd), `outline_check.gd.uid` | Headless boundary, mask, tooltip and lifecycle proof |
| [route.gd](route.gd), `route.gd.uid`, [record.sh](record.sh), [record.py](record.py), [proof_contract.json](proof_contract.json) | tut-03 route and holds against the new card and popup, with an additional still from the first rendered frame after Continue |
| `result.md` | Implementation and proof receipts |

The two existing Godot test suites passed with their original expectations.

## Headless proof

```text
TUT-02 TRUTH 1: "Enemies on dark tiles are hidden" enemy=roc_fledgling tile=(5, 6) distance=7 personal_radius=6 light_sources=1 darkened=true hidden=true
TUT-02 TRUTH 2: "you can't target them or see their intents." enemy=roc_fledgling card=Skybolt targetable=false intent=circle displayed=false
TUT-02 UMBRA TRUTH WITNESS: PASS
TUT-02 INPUT COPY: identical=true body="Enemies on dark tiles are hidden: you can't target them or see their intents."
TUT-02 FIRST UMBRA: seed=90212 room=(2, 1) turn=1 first=visible animation_locked=hidden
TUT-02 SAVE/RELOAD: before=unread restored=visible
TUT-02 CONTINUE: controller=accepted profile=stored run=stored card=closed
TUT-02 ANALYTICS: guided_tutorial_step_completed {"completed_step_count":16.0,"milestone_id":"umbra_read","phase_id":"umbra","tutorial_version":2.0}
TUT-02 TRIGGER WITNESS: PASS
TUT-04 OPEN: dark_tiles=12 outline_parts=2 drawn_edges=24
TUT-04 TOOLTIP: stages=6 text="Fringe Umbra\nEnemies on dark tiles are hidden: you can't target them or see their intents."
TUT-04 LIVE UPDATE: dark_tiles=11 outline_parts=2 drawn_edges=22
TUT-04 SUPPRESSION: checked cleared and restored outline
TUT-04 CONTINUE: card_visible=false outline_parts=0
TUT-04 OUTLINE CHECK: PASS
```

| Check | Observed result |
| --- | --- |
| `tests/contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| `tests/guided_combat_tutorial_integration_test.gd` | `PROMPT PARENT COMPARISON: 72 cases / input orders / first and drawn prompts / 0.5x, 1x, 2x / reduced motion / zero and nonzero uptime` · `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.077s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.377s` · `OK` |
| Shell syntax, Python parse and image contract | `TUT-04 WRAPPER AND PROOF CONTRACT: PASS` |
| `git diff --check` | Exit 0 |

Godot `godot.log` receipts are under `/private/tmp/labyrinth-godot-home/`. The successful processes emitted the macOS system CA certificate diagnostic.

| Check | Run directory |
| --- | --- |
| Truth witness | `tut-04-1795796280563070000-78109` |
| Trigger witness | `tut-04-1795796618649108000-79640` |
| Outline check | `tut-04-1795796523121072000-78946` |
| Catalog and save | `tut-04-1795796438250581000-78595` |
| Integration | `tut-04-1795796523119414000-78947` |

The recorder rehearsal exited 0. Its [checks.log](/private/tmp/labyrinth_codex/tut-04/dry-run.nz13hE/checks.log) and [route.json](/private/tmp/labyrinth_codex/tut-04/dry-run.nz13hE/route.json) share the same take directory.

```text
TUT-04 STEP 1 PASS: map=(-1, 0) door=(8, 4) destination=(2, 1) seed=90212
TUT-04 STEP 2 PASS: room=(2, 1) turn=1 intro=settled concealed_enemy=true
TUT-04 STEP 3 PASS: pointer=visible heading=UMBRA title=The Umbra rest_tile=(2, 1)
TUT-04 STEP 4 PASS: popup=visible text="FRINGE UMBRA\nEnemies on dark tiles are hidden: you can't target them or see their intents."
TUT-04 CONTINUE STILL PASS: card=closed outline=absent frame=405
TUT-04 STEP 5 PASS: card=closed profile=umbra_read checkpoint=umbra_read turn=1
TUT-04 STEP 6 PASS: hero=(1, 4) -> (1, 3) path_steps=1 turn=1
TUT-04 ROUTE PASS: 6 steps, 522 frames after map start
TUT-04 NATIVE DRY RUN: PASS
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-04 && tools/tut04/record.sh
```

Keep the recording window focused and leave the pointer alone during the take. The wrapper selects the production cel look, the visual probe runner's native renderer and GUI lease, and the task-local Godot runner. It prints the fresh output directory under `/private/tmp/labyrinth_codex/tut-04/take.XXXXXX/`.

- `flow.mp4`, `contact-sheet.png`, and `checks.log`
- `umbra-card.png` with the card, floor outline and undimmed board
- `umbra-hud-popup.png` with the stage popup and card visible together
- `after-continue.png` from the first rendered frame after Continue closes the card

All three delivered stills are 1920×1080 at 100% UI scale. The six contact-sheet images retain the tut-03 route order and holds.

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The focused outline check uses the existing 1920×1080 fixture setup and changes one tile in a copy of the submitted visibility mask to check the live update. The generated encounter uses seed `90212`, room `(2, 1)` and turn 1 as specified.
- The recorder retains tut-03's 30 fps, six layout frames, 900-frame readiness limit, two-frame media verification tolerance, and 640×360 contact-sheet cells in three columns. The recorder samples the first available rendered frame after the prompt closes for the new still.

## Open issues

Native capture, visual inspection and the identity judge are pending a window-server session with the design owner. Replay the archived tut-03 recorder from its original branch, where its copy constants are available. The unit is uncommitted.

## Round 1 — Board silhouette

The owner's round-0 take showed the bright rectangle cutting across the scenery above and left of the board. The board now supplies a viewport-space convex hull of the rendered floor diamonds and their slab depth faces, including the stone bases beneath doors and pillars. The Umbra dimmer grows that hull by `SPOTLIGHT_GROW` and leaves the label's frameless rectangular hole in place. The card, copy, pop-up, and floor outline use their round-0 paths. [Round-0 card](/private/tmp/labyrinth_codex/tut-04/take.Y98j6f/umbra-card.png) · [Round-0 Continue](/private/tmp/labyrinth_codex/tut-04/take.Y98j6f/after-continue.png)

Round-1 changes are in [combat_board_view.gd](../../scripts/combat_board_view.gd#L8297), [run_scene.gd](../../scripts/run_scene.gd#L7664), [contextual_combat_prompt.gd](../../scripts/contextual_combat_prompt.gd#L348), [outline_check.gd](outline_check.gd#L102), and [route.gd](route.gd#L163). This section records the new proof.

### Chosen defaults

The polygon offset uses rounded joins. The dimmer adds a vertical partition through the silhouette's horizontal midpoint to its existing rectangle grid. Each remaining cell subtracts the silhouette and paints the resulting simple polygons. A cell cannot enclose the full silhouette, so subtraction never creates a polygon with a hole. Other lessons keep the rectangular grid path.

### Headless results

Every projected floor diamond and slab face fit inside the grown hole. The area ratio and maximum growth both met the specified limits.

```text
TUT-04 OPEN: dark_tiles=12 outline_parts=2 drawn_edges=24
TUT-04 DIMMER: hole_vertices=28 hull_vertices=16 area_ratio=1.0209 max_growth_px=3.000 holes=2 frames=0
TUT-04 CONTINUE: card_visible=false outline_parts=0
TUT-04 OUTLINE CHECK: PASS
CONTEXTUAL COMBAT TUTORIAL TEST: PASS
GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS
TUT-04 CONTINUE STILL PASS: card=closed outline=absent frame=472
TUT-04 ROUTE PASS: 6 steps, 598 frames after map start
TUT-04 NATIVE DRY RUN: PASS
```

Rules text lint printed `Ran 3 tests in 0.083s`, `OK`, and `PASS: Rules text lint (16 existing hits)`. UI identity lint printed `Ran 25 tests in 7.777s` and `OK`. `git diff --check` exited 0. The Godot processes emitted the macOS system CA certificate diagnostic and exited 0.

The rehearsal wrote [checks.log](/private/tmp/labyrinth_codex/tut-04/dry-run.kHNDBE/checks.log) and [route.json](/private/tmp/labyrinth_codex/tut-04/dry-run.kHNDBE/route.json).

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-04 && tools/tut04/record.sh
```

Round-1 native capture and inspection are pending. The take writes the same six deliverables under a fresh `/private/tmp/labyrinth_codex/tut-04/take.XXXXXX/`. There are no `TODO_DESIGN` placeholders. Round-1 changes are uncommitted.

## Round 2 — Alcove silhouette and darkened door

The floor cutout now follows the union of the rendered tile diamonds and the two slab faces under each tile. The union preserves the alcove's concave notches and fills enclosed gaps before applying the 3 px rounded grow. The dimmer still uses the vertical split and per-cell subtraction. [Round-1 card](/private/tmp/labyrinth_codex/tut-04/take.DKfMW9/umbra-card.png) · [Director annotations](/Users/borgerding/workspace/Labyrinth/.codex/tasks/feedback/tut-04/r1_defects.png)

The retained world pass applies a nonzero dark fill to the visible door tile at `(4, 0)`. The outline now includes that tile from the same `hidden_lookup` as the other dark floor tiles. A door displayed as a wall keeps the wall exclusion.

Round-2 changes are in [combat_board_view.gd](../../scripts/combat_board_view.gd), [contextual_combat_prompt.gd](../../scripts/contextual_combat_prompt.gd), [run_scene.gd](../../scripts/run_scene.gd), [outline_check.gd](outline_check.gd), [route.gd](route.gd), and this report.

### Chosen defaults

The union is cached in half-tile coordinates so shared edges meet exactly at every zoom. The proof waits up to 900 frames for the saved hand and floor layout to settle before sampling. A separate geometry check uses a 3×3 ring missing its center tile and one isolated slab to verify the treatment of interior gaps and separate components.

### Headless results

```text
TUT-04 OPEN: dark_tiles=13 outline_parts=3 drawn_edges=28 door_tiles_added=[(4, 0)]
TUT-04 DIMMER: silhouette_vertices=11 hole_vertices=29 area_ratio=1.0230 max_growth_px=3.000 holes=2 frames=0
TUT-04 SCENERY: sample_step_px=4 samples=42316 beyond_floor_px=4 silhouette=0 round_1_hull=1074
TUT-04 SLAB UNION: parts=2 interior_gap_filled=true
TUT-04 LIVE UPDATE: dark_tiles=12 outline_parts=2 drawn_edges=24 door_tiles_added=[]
TUT-04 CONTINUE: card_visible=false outline_parts=0
TUT-04 OUTLINE CHECK: PASS
CONTEXTUAL COMBAT TUTORIAL TEST: PASS
GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS
TUT-04 CONTINUE STILL PASS: card=closed outline=absent frame=422
TUT-04 ROUTE PASS: 6 steps, 548 frames after map start
TUT-04 NATIVE DRY RUN: PASS
```

Rules text lint printed `Ran 3 tests in 0.282s`, `OK`, and `PASS: Rules text lint (16 existing hits)`. UI identity lint printed `Ran 25 tests in 22.784s` and `OK`. The whitespace check passed. The Godot processes printed the macOS system CA certificate diagnostic and exited 0.

The rehearsal wrote [checks.log](/private/tmp/labyrinth_codex/tut-04/dry-run.X8vo4q/checks.log) and [route.json](/private/tmp/labyrinth_codex/tut-04/dry-run.X8vo4q/route.json).

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-04 && tools/tut04/record.sh
```

The round-2 native take and visual inspection are pending. The recorder writes the 1920×1080 stills, video, contact sheet and log under a fresh `/private/tmp/labyrinth_codex/tut-04/take.XXXXXX/`. There are no `TODO_DESIGN` placeholders. Round-2 changes are uncommitted.
