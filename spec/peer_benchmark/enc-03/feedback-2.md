# enc-03 — director feedback 2

Status: the two-cross copy is implemented and headlessly verified. The perceived
caption occlusion needs the director's styling/placement decision; no new
callout surface or overlay placement has been invented. All changes remain
uncommitted. Accepted measurements and the quarantined HUD test are unchanged.

## 1. Layering investigation and pending decision

The supplied aiming PNG was inspected, including a magnified detail at
`output/enc-03/feedback-2/director-callout-detail.png`. The letters “Fire.” are
painted **over** the crest. The crest is visible through the Label's transparent
background, including the spaces around the letters. This is a visual overlap,
but the supplied evidence does not show an inverted draw order.

The two paths are:

- `scenes/run_scene.tscn`: `UiLayer` is canvas layer 1; the shared `ActionBanner`
  Label is its descendant (`StageRoot/ActionBanner`), with z=0.
- `CombatBoardView._draw_hud_render_layer` draws Health bars, statuses, leader
  crests and intent chips in `HudRenderLayer` under `BoardUnderlay`, canvas
  layer 0, z=0. Lob medallions draw on the retained effects pass on that same
  board canvas. The action caption canvas already composites after them.

The real fire Warband aiming state reproduces these screen rectangles:

| Item | Screen rect (x, y, width, height) | Canvas layer |
| --- | --- | --- |
| Action caption, two-cross copy | 629.5, 82, 661, 30 | 1 |
| Leader crest | 1241.366, 89.18613, 34, 34 | 0 |

Their rectangles intersect. `tests/enc03_lob_probe.gd` now checks this real
fixture intersection and asserts the action caption canvas draws after the
board HUD/effects canvas. Both assertions pass **before a layering change**.
It would be incorrect to claim a failing pre-fix draw-order regression or that
raising z fixes this transparent-background overlap.

`TODO_DESIGN_callout_occlusion_treatment` (a field in feedback-2-proof.json):
choose whether to keep board overlays out of the caption rectangle or give the
caption an opaque backing using an existing approved UI surface. An async
clarification is pending. The implementation brief reserves new visible
styling/placement decisions for the director. No production layering change
has been made while that choice is unresolved.

## 2. One- and two-cross copy

Both turns now carry the actual cross count as presentation-only metadata.
Aiming counts the actual `Lob.centers` result; landing counts the saved
`lob_centers`, so a clipped barrage that only fits one cross remains singular.
HUD records omit saved centres, so formatting resolves their actor ID against
the combat snapshot before choosing the text.

With one cross the current sentences are retained. With two crosses the exact
approved strings are used by the callout, full intent tooltip, token tooltip
and tile tooltips:

- Aiming: `Lob Slag: lands next turn on the marked tiles: {centre} in each centre, {arm} around them, and leaves Fire.`
- Landing: `Lob Slag lands: {centre} in each centre, {arm} around them, and leaves Fire.`

The badge remains the lob icon and actual centre damage only. Tests cover both
counts on both turns at scaled 6/4 damage, including full HUD tooltips.

Changed this round: `scripts/action_icon_library.gd`,
`scripts/enemy_mechanics/lob.gd`, `scripts/enemy_mechanics/lob_view.gd`,
`tests/suites/enc03_slag_suite.gd`, `tests/enc03_lob_probe.gd`, and
`tools/enc03_proof.py` (a fresh result-manifest option preserves the director's
round-1 manifests). No enemy tuning, assets or analytics changed.

## Focused verification

- `ENC03 SLAG TEST: PASS (717 checks; 0 failures)`
- `EN04 ENEMIES TEST RESULT: PASS (420 checks, 0 failures)`
- `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)`
- `ENC03 LOB PROBE: PASS (3 states; 0 failures)` — headless; includes actual
  screen-rect overlap and the existing canvas order.
- UI identity: 25 tests, `OK`.
- Python measurement/proof-tool checks: 18 tests, `OK`.

The native after phase was attempted once with a fresh manifest path. It
exited 1 before launching a renderer:

`error: Timed out waiting 30.0 seconds for GUI render lease /private/tmp/labyrinth-gui-render.lock`

Log: `output/enc-03/feedback-2/after-windowed.log`. No new native images or
result manifest were produced. No retry was made. The director's round-1
before/after PASS manifests and PNGs remain intact.

`tests/combat_hud_badges_test.gd` is known/quarantined in
`tests/quarantine.json` (qa-08); neither file was changed or executed this round.
No full suite, peer review, commit or publication was performed.

Chosen defaults: fresh feedback-2 output paths; diagnostic crop rectangle
`[1130, 75, 160, 50]`, displayed at `960x300` for inspection only. The crop is a
detail of existing evidence, not a fresh renderer capture. No player-facing
values were chosen.

## Commands for the director

Use fresh result paths to preserve earlier evidence. Run sequentially:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase before --result-manifest output/enc-03/feedback-2/director-before-visual-result.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/enc03_proof.py --phase after --result-manifest output/enc-03/feedback-2/director-after-visual-result.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/enc-03 && python3 tools/inspection_fixture.py --task-id enc-03 --run-id enc-03-feedback-2-fire-warband --manifest output/enc-03/feedback-2/fire-warband-inspection.json --scenario warband --warband-biome fire --warband-tier 2 --warband-case pre_battle --launch
```

Both capture contracts remain 1920x1080 at 100% UI scale. Expected native image
names remain `{before,after}_{pre_battle,aiming,landing}_1920x1080.png` under the
runner's isolated `user://probes/enc03_lob/`; a successful manifest records the
absolute image paths.
