# fel-32 attack outlines

## Implementation

1. `ThreatTiles.draw_tile` submits the 5 px `PREVIEW_INK` band at
   `0.8 × alpha` between the existing fill and the existing 2 px red
   outline at `0.75 × alpha`. The band values are named constants.
2. The band uses a closed diamond inset by half its stroke. The band uses
   solid edges to keep its antialias fringe from crossing the boundary.
   [Godot 4.6.1 polyline implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_canvas_cull.cpp#L877)
3. The production paths use this geometry on every surface and preserve the
   fill alpha and hero pulse.
4. The approved patch routes retained floor and battlefield-rule outlines
   through `ThreatTiles.outline_operations` and the targeted repaint
   through `ThreatTiles.draw_tile_outline`. The two caller files contain
   exactly the approved edits. The stroke list is built with an explicitly
   typed array and appends.

### Threat paint producers and consumers

| Path | Use |
| --- | --- |
| `ThreatTiles.draw_tile` | Builds geometry with `tile_geometry` and calls `draw_tile_outline`. The performance reference in `tests/perf/hover_board_reference.gd` uses this entry point. |
| `BoardLayerSlices.threat_paint` | Builds the shared geometry plus alpha and hero membership. `threat_operations` and `rule_outline_operations` use its paint for retained floor and late rule outlines. |
| `CombatBoardView._draw_overlay_render_layer` and `BoardLayerSlices._marker_paint` | Cache or retrieve the marker paint used by `lifted_threat_operations`. Both obtain it from `BoardLayerSlices.threat_paint`. |
| `TargetedTileThreat.present` and `_draw` | `present` is the sole writer of `_paint` and gets it from `BoardLayerSlices.threat_paint`. `_draw` uses the shared outline above the border. |

`scripts/threat_tiles.gd`, `scripts/board_layer_slices.gd`, and
`scripts/targeted_tile_threat.gd` contain the production edits.
`tools/fel32/` contains the replay, headless draw observers, contrast and
adjacency checks, native capture wrapper, proof contract, and media builder.

## Proof method

The replay consumes the seed 30002 input witnesses from the fel-30 census.
The Fire case is Vyraketh in combat 4. The stone case is the opening fight
in room `(1, -1)`, combat 1. Numeric proof covers the first input-ready
frame of each player turn, counting every qualifying tile at each sampled
turn. The probe takes the median of the sampled edge pairs per tile and then
the median across tile observations. [WCAG contrast calculation](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast)

The headless diagnostic pack records arguments at the real CanvasItem
submissions from retained commands, direct board commands, and the targeted
repaint. The production calls still run. The headless renderer exposes no
framebuffer pixels. The script samples the
authored stone textures and the live baked Fire sheet frame, then composites
the recorded stroke geometry and alpha. This measures floor and solid stroke
contrast. GPU lighting, antialias coverage, occlusion and later effect passes
are outside this calculation. The A/B uses the same background and hero pulse
for both builds, so Fire animation phase and pulse phase do not affect the
difference.

## Recorded headless results

Both traced runs completed all 205 inputs and recorded 15 player-turn
moments. The sampled opening fight was seed 30002 combat 1 in room
`(1, -1)`. Vyraketh's census-frame moment, combat 4 turn 3, had 22
telegraphed tiles, including 12 on Fire. The contrast measurements include
all qualifying tile observations across each fight. The replay sampled
retained slice submissions. The adjacent fixture sampled the targeted path
as well. [Matched replay traces and contrast log](/private/tmp/labyrinth_codex/fel-32/feedback-live)

```text
FEL32 REPLAY seed=30002 inputs=205 moments=15
FEL32 FIRE tiles=64 contrast_before_median=2.080 contrast_after_median=3.704 min_after=3.462 PASS
FEL32 STONE tiles=5 contrast_before_median=2.517 contrast_after_median=3.764 PASS
FEL32 ADJACENT PASS
FEL32 PASS cases=3
```

The adjacent case used the live retained slice for the hero tile and
`TargetedTileThreat` for the other diamond. Both red cores stayed intact.
The hero fill was sampled for a second per mode. The motion-on samples
varied across 39 observations. Nine reduced-motion redraws had equal alpha.
[Adjacent and pulse trace](/private/tmp/labyrinth_codex/fel-32/feedback-proof/adjacent.json)

```text
FEL32 HERO PULSE range=0.1194 reduced_motion_range=0.0000 PASS
FEL32 TARGET ABOVE BORDER border_index=14 outline_index=15 PASS
THREATS AT REST TEST RESULT: PASS (15731 assertions; includes compass suite)
PERF09 REDRAW GUARD: PASS (enemy action 12/48; hover 2/8; full-board invalidations 0/0)
```

The Windows typed-array audit covered all 11 changed GDScript sources.
Its only candidate was the existing badge layout read in
`board_layer_slices.gd:213`, outside the approved change.

UI identity lint printed `Ran 25 tests in 110.019s` and `OK`.
[Focused logs](/private/tmp/labyrinth_codex/fel-32/feedback-proof)

The older targeting-highlight probe printed
`PTF09 HIGHLIGHT: FAIL (3655 checks, 14 failures)` on both builds.
The same 14 assertions require the border immediately after the action floor.
The branch probe also reached the 300-second runner limit after printing
its assertion results.
The new fixture independently checked the actual outline and border draw and
their sibling order. The targeted paint and rule repros printed
`RED05 REVIEW REPROS: PASS (0 failing checks)` and
`QA103 RESULT followup_repros.gd: PASS (0 failures)`.

### Python module reruns

Each previously failing module ran by itself. Persistent failures were
checked against `codex/release` at `e20cebc19`.
[Full Python logs](/private/tmp/labyrinth_codex/fel-32/feedback-python)

| Module | Branch output | Release comparison |
| --- | --- | --- |
| `test_approved_content_manifest` | `Ran 1 test in 26.677s`, `OK` | The original 30-second Godot load timeout cleared. |
| `test_demo_build` | `Ran 6 tests in 11.216s`, `OK` | The original 60-second Steam Linux pack-export timeout cleared. |
| `test_godot_task_runner` | `Ran 15 tests in 25.754s`, `FAILED (failures=1)` | Both branches hit the child readiness deadline in `test_killing_runner_mid_godot_test_leaves_no_godot_child`. The original TERM-ignoring descendant failure passed on the branch. |
| `test_python_suite_runner_feedback` | `Ran 12 tests in 76.879s`, `FAILED (failures=1)` | Both hit the 0.5-second startup/log deadline in `test_sleeping_worker_times_out_with_its_log`. The detached-child test passed on the branch and also missed its deadline on release. |
| `test_program_suite_runner` | `Ran 42 tests in 246.090s`, `FAILED (failures=5, errors=3)` | Release printed `FAILED (failures=7, errors=2)`. Both hit the 15-second package-fixture and 30-second real fixture deadlines, the 1.2-second hung-child startup deadline, the package-child readiness deadline, and the 15-second real parent runner deadlines for output, failure and timeout handling. |

The program-runner report-reuse test hit a 15-second staging deadline on
the branch and passed on release. Retested by itself on the branch, it
printed `Ran 1 test in 2.260s` and `OK`. The content manifest and demo
failures were load/export timeouts. The persistent runner failures were
readiness or harness deadlines as listed above.

## Chosen defaults

- Replay timing inherits the fel-30 capture settings. It uses 60 fps, three
  settling frames per input, 4× playback in headless mode, normal playback
  in native mode, and a 120-second input inactivity limit. The headless
  replay allows 300 seconds for loading screens and 1,200 seconds total
  after a concurrent run reached the 120-second limit while loading. The
  native runner uses a 600-second limit.
- The stone comparison uses the first turn in the opening fight with a
  threat on stone. The hero comparison uses the first Vyraketh turn other
  than turn 3 on which the hero stands on a threatened tile.
- The numerical probe samples 16 positions along the middle 70% of each
  edge. The target depths are 1 and 3.5 px into the diamond, snapped to
  screen pixel centers. The adjacent fixture uses the threats-at-rest
  board with the next tile to the right targeted. The pulse check samples
  the existing hero fill for 1 second per setting.
- A crop encloses the largest edge-connected threat group with 8 px of
  padding. Sorted tile coordinates break group-size ties.

No `TODO_DESIGN_*` placeholders were needed.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-32 && bash tools/fel32/native.sh /Users/borgerding/workspace/Labyrinth.worktrees/release /private/tmp/labyrinth_codex/fel-32/native-proof
```

The native command uses the visual probe runner at 1920×1080 and 100% UI scale
with `LABYRINTH_CEL_LOOK=all`. It captures Vyraketh combat 4 turn 3 (census
frame 01), the stone-floor fight, and the hero on a marked tile. It writes
`{fire,stone,hero}-comparison.png` and `{fire,stone,hero}-crop-3x.png` with
release on the left. A fresh output directory is required.
Native captures remain pending because this sandbox has no window-server
access.

The matched headless proof can be regenerated with a fresh output directory.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-32 && bash tools/fel32/headless.sh /Users/borgerding/workspace/Labyrinth.worktrees/release /private/tmp/labyrinth_codex/fel-32/headless-proof
```
