# fel-26 feedback 1

The revision is uncommitted on `codex/fel-26`, based on `8117632e4`. The design owner ran the first native review in `tools/fel26/captures/fel26.eccNcC/` and the first timing pairs in `tools/fel26/captures/perf.H0gayp/`.

## Acceptance

| Requirement | Revision |
|---|---|
| 1. Exterior only | The asset bake writes opaque `#0F0B0A` to texels below alpha 0.5 with an eight-neighbour at or above 0.5. Every other texel is transparent. The original static checker and base rim shader are restored from fel-16. A small exterior clip applies only to a rear x-ray rim that intersects an edge and preserves the unit checker fill. The exterior sprite draws after the tile’s checker and before its actor children. |
| 2. Frame cost | Shared source-size edge textures are baked and cached when assets enter the board. Sprites use ordinary nearest-filtered canvas texture drawing. Geometry is cached across fades. In `window`, the existing show-through fade changes opacity, including the opacity used to clip overlapping late rims. In `always`, edge opacity stays at 1.0 without a fade update. The first native median was +0.207 ms over off. The new native median awaits the owner’s interleaved run. |
| 3. Deterministic comparison | Both sides render synchronously in a single SceneTree frame. Zero-length render steps hold shader `TIME` fixed. The probe pauses the tree and blocks render signals that can update wall-clock-driven presentation, then checks an identical render after restoring the variant. It compares RGBA bytes and reports changed and outside counts and bounding boxes. Failed comparisons with available readbacks save reference and control PNGs. |

Godot advances the canvas shader clock by the supplied render step. The `SubViewport` renders into its texture during a forced draw, and `force_sync()` precedes readback. [Godot 4.6.1 shader clock](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_rd/renderer_compositor_rd.cpp#L97-L106), [Viewport draw](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/renderer_viewport.cpp#L814-L820), [RenderingServer API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw)

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-26 && tools/fel26/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-26 && FEL13_PERF_SET=fel26 tools/fel13/native.sh --perf
```

The native launcher writes the five 1920×1080 stills per variant, three-up sheets, the 2× nearest P3 crop, and the two 30 fps motion comparisons with game audio under `tools/fel26/captures/fel26.*/`. The timing launcher writes the six paired samples under `tools/fel26/captures/perf.*/`. The native gates require exact RGBA equality on all five off stills and `outside=0` for the two edge variants. This sandbox ran the headless launchers and did not produce native media.

### Fixture and proof settings

`TODO_DESIGN_P8_CRATE_LOOT_FIXTURE` still points to P2, fel-16’s authored loot-under-crate fixture. P8 remains the hero and pillar still. The headless release witness uses reduced motion for matching pickup geometry across processes. The paired native stills freeze the actual presentation after settling. The motion takes use the ordinary settings and viewport input. The P3 crop uses the reviewed pillar at tile (5, 3).

## Changed files

- `scripts/board_occlusion_alpha.gd` and `scripts/board_occlusion_silhouettes.gd` bake and bind the exterior texture and keep the opacity update separate from the geometry.
- `scripts/board_occlusion_silhouettes.gdshader` is byte-identical to the fel-16 release shader.
- `tools/fel26/edge_probe.gd` verifies the exterior texel mask and performs the synchronous three-readback comparison.
- `tools/fel26/proof.py` validates the exterior-only proof rows. This report records the revision and evidence.


## Headless evidence

The initial release witness and off still dry run hit the existing board layout guard on one fixture each. Both passed on retry with the same guard. The first board-surface run found a freed sprite in the retained edge map after its scene layer retired. The revision checks instance validity before using cached nodes. The surface test passed on retry.

### Exterior witness and release parity

The 20-case release retry and the three 20-case mode logs are in `tools/fel26/captures/fel26.Azv2gb`. The base rim shader also matched the release file byte-for-byte.

```text
FEL26 EDGE off 01-s0-seed1-0-4_0-t9 edge_texels=0 PASS
FEL26 EDGE off 02-s0-seed12-0-1_3-t7 edge_texels=0 PASS
FEL26 EDGE off 03-s2-seed8-2-11_-9-t64 edge_texels=0 PASS
FEL26 EDGE off 04-s0-seed8-0--3_2-t5 edge_texels=0 PASS
FEL26 EDGE off 05-s2-seed1-2-9_-7-t2 edge_texels=0 PASS
FEL26 EDGE off 06-s2-seed1-2-11_-10-t5 edge_texels=0 PASS
FEL26 EDGE off 07-s4-seed1-4-19_-19-t4 edge_texels=0 PASS
FEL26 EDGE off 08-s1-seed8-1-5_-4-t5 edge_texels=0 PASS
FEL26 EDGE off 09-s3-seed12-3-16_0-t15 edge_texels=0 PASS
FEL26 EDGE off 10-s3-seed12-3-13_-2-t4 edge_texels=0 PASS
FEL26 EDGE off 11-s4-seed12-4-19_-14-t4 edge_texels=0 PASS
FEL26 EDGE off 12-s1-seed12-1-5_3-t2 edge_texels=0 PASS
FEL26 EDGE off P1 edge_texels=0 PASS
FEL26 EDGE off P2 edge_texels=0 PASS
FEL26 EDGE off P3 edge_texels=0 PASS
FEL26 EDGE off P4 edge_texels=0 PASS
FEL26 EDGE off P5 edge_texels=0 PASS
FEL26 EDGE off P6 edge_texels=0 PASS
FEL26 EDGE off P7 edge_texels=0 PASS
FEL26 EDGE off P8 edge_texels=0 PASS
FEL13 WITNESS PASS side=branch fixtures=20 subjects=458 required=74 umbra_hidden=5 failures=0
FEL26 EDGE window 01-s0-seed1-0-4_0-t9 edge_texels=0 PASS
FEL26 EDGE window 02-s0-seed12-0-1_3-t7 edge_texels=3210 PASS
FEL26 EDGE window 03-s2-seed8-2-11_-9-t64 edge_texels=1070 PASS
FEL26 EDGE window 04-s0-seed8-0--3_2-t5 edge_texels=3874 PASS
FEL26 EDGE window 05-s2-seed1-2-9_-7-t2 edge_texels=4944 PASS
FEL26 EDGE window 06-s2-seed1-2-11_-10-t5 edge_texels=4024 PASS
FEL26 EDGE window 07-s4-seed1-4-19_-19-t4 edge_texels=2140 PASS
FEL26 EDGE window 08-s1-seed8-1-5_-4-t5 edge_texels=2954 PASS
FEL26 EDGE window 09-s3-seed12-3-16_0-t15 edge_texels=2140 PASS
FEL26 EDGE window 10-s3-seed12-3-13_-2-t4 edge_texels=4944 PASS
FEL26 EDGE window 11-s4-seed12-4-19_-14-t4 edge_texels=1884 PASS
FEL26 EDGE window 12-s1-seed12-1-5_3-t2 edge_texels=2140 PASS
FEL26 EDGE window P1 edge_texels=1070 PASS
FEL26 EDGE window P2 edge_texels=664 PASS
FEL26 EDGE window P3 edge_texels=3210 PASS
FEL26 EDGE window P4 edge_texels=0 PASS
FEL26 EDGE window P5 edge_texels=0 PASS
FEL26 EDGE window P6 edge_texels=1734 PASS
FEL26 EDGE window P7 edge_texels=1070 PASS
FEL26 EDGE window P8 edge_texels=1070 PASS
FEL13 WITNESS PASS side=branch fixtures=20 subjects=458 required=74 umbra_hidden=5 failures=0
FEL26 EDGE always 01-s0-seed1-0-4_0-t9 edge_texels=4280 PASS
FEL26 EDGE always 02-s0-seed12-0-1_3-t7 edge_texels=9378 PASS
FEL26 EDGE always 03-s2-seed8-2-11_-9-t64 edge_texels=5908 PASS
FEL26 EDGE always 04-s0-seed8-0--3_2-t5 edge_texels=7086 PASS
FEL26 EDGE always 05-s2-seed1-2-9_-7-t2 edge_texels=7086 PASS
FEL26 EDGE always 06-s2-seed1-2-11_-10-t5 edge_texels=5908 PASS
FEL26 EDGE always 07-s4-seed1-4-19_-19-t4 edge_texels=2140 PASS
FEL26 EDGE always 08-s1-seed8-1-5_-4-t5 edge_texels=6572 PASS
FEL26 EDGE always 09-s3-seed12-3-16_0-t15 edge_texels=2140 PASS
FEL26 EDGE always 10-s3-seed12-3-13_-2-t4 edge_texels=5758 PASS
FEL26 EDGE always 11-s4-seed12-4-19_-14-t4 edge_texels=1884 PASS
FEL26 EDGE always 12-s1-seed12-1-5_3-t2 edge_texels=2954 PASS
FEL26 EDGE always P1 edge_texels=1070 PASS
FEL26 EDGE always P2 edge_texels=3106 PASS
FEL26 EDGE always P3 edge_texels=4024 PASS
FEL26 EDGE always P4 edge_texels=814 PASS
FEL26 EDGE always P5 edge_texels=0 PASS
FEL26 EDGE always P6 edge_texels=6572 PASS
FEL26 EDGE always P7 edge_texels=5350 PASS
FEL26 EDGE always P8 edge_texels=1734 PASS
FEL13 WITNESS PASS side=branch fixtures=20 subjects=458 required=74 umbra_hidden=5 failures=0
FEL26 RELEASE CHECKER INPUT PARITY PASS off cases=20
FEL26 RELEASE CHECKER INPUT PARITY PASS window cases=20
FEL26 RELEASE CHECKER INPUT PARITY PASS always cases=20
FEL26 OCCLUDER EDGE PASS cases=60
```

### Fel-16 content dry path

```text
off
FEL16 NATIVE CONTENT PLAN cases=20 subjects=47
FEL13 DRY RUN PASS fixtures=20
window
FEL16 NATIVE CONTENT PLAN cases=20 subjects=47
FEL13 DRY RUN PASS fixtures=20
always
FEL16 NATIVE CONTENT PLAN cases=20 subjects=47
FEL13 DRY RUN PASS fixtures=20
```

### Native launcher dry path

The launcher logs are in `tools/fel26/captures/fel26.1YnFt0`. The successful off-still retry and the synthetic pixel diagnostic are under `tools/fel26/captures/checks/`. Bbox reporting includes alpha-only differences.

```text
FEL26 PIXEL DIAGNOSTICS PASS changed=2 outside=1 bbox=[P: (1, 0), S: (3, 3)] outside_bbox=[P: (3, 2), S: (1, 1)]
FEL26 STILLS PASS variant=off cases=5
FEL13 MOTION DRY PASS M1a
FEL13 MOTION DRY PASS M2
FEL26 STILLS PASS variant=window cases=5
FEL13 MOTION DRY PASS M1a
FEL13 MOTION DRY PASS M2
FEL26 CROP PLAN P3 bbox=[P: (1050, 260), S: (148, 189)]
FEL26 STILLS PASS variant=always cases=5
FEL13 MOTION DRY PASS M1a
FEL13 MOTION DRY PASS M2
```

### Focused regressions

| Check | Observed result |
|---|---|
| Fel-13 focused | `FEL13 FOCUSED PASS checks=42 failures=0` |
| Fel-02 focused | `FEL02 FOCUSED PASS checks=122 failures=0` |
| RD02 focused | `RD02 FOCUSED: PASS (5472 checks, 0 failures)`. The inherited detached shot shader logged `SHADER ERROR: Expected a positive integer constant.`. |
| Surface presentation | `TEST RESULT: PASS board surface presentation` on retry |
| Traps | `TRP01 TRAP RULES: PASS (376 checks, 0 failures)` |
| Snare | `Snare UI/fixture suite: 0 failures` |
| Tile tooltip | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| Board projection | `COMBAT BOARD PROJECTION TEST: FAIL (1 errors)`. The existing draw observer’s contact pool and ground shadow overrides disagree with the base signatures. |
| UI identity | `Ran 25 tests in 64.181s`, `OK` |
| Rules text | `Ran 3 tests in 0.078s`, `OK` |
| Python default, first run | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 137.159s`, `FAILED (failures=6, errors=1)`. Runner and content subprocess deadlines accompanied the existing sidecar failure. |
| Python default, retry | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 88.874s`, `FAILED (failures=5)`. Three program suite subprocess checks reached their 15-second limits, the task runner’s descendant check did not see its child start, and seven fel-10 UIDs remain absent from the tracked sidecar inventory. |

The earlier RD02 silhouette probe still refers to absent `OBJECT_ON` and `OBJECT_OFF` constants. The OCC02 survey still needs a certified fixture profile. The focused suite logs are in `tools/fel26/captures/checks/`.

### Paired headless timing

The timing dry run completed all six 600-frame samples. The median paired p50 difference was −0.046 ms, and the median paired p99 difference was +0.420 ms. Pair 3’s off sample reached 208.805 ms p99. The headless run verifies the launcher and sample order. Native rendering and the 0.15 ms gate remain to be measured. Logs are in `tools/fel26/captures/perf.PLq6Wp`.

| Pair | Order | Off p50 | Always p50 | Off p99 | Always p99 |
|---|---|---:|---:|---:|---:|
| 1 | Off, always | 6.822 | 6.776 | 9.760 | 10.180 |
| 2 | Always, off | 6.769 | 6.827 | 9.876 | 11.085 |
| 3 | Off, always | 11.001 | 6.843 | 208.805 | 8.607 |

Times are in milliseconds.

```text
FEL26 PERF LAYER variant=off edges=0
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=off renderer=headless frames=600 p50=6.822 p99=9.760 max=10.138
FEL26 PERF LAYER variant=always edges=4
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=always renderer=headless frames=600 p50=6.776 p99=10.180 max=15.839
FEL26 PERF LAYER variant=always edges=4
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=always renderer=headless frames=600 p50=6.827 p99=11.085 max=33.945
FEL26 PERF LAYER variant=off edges=0
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=off renderer=headless frames=600 p50=6.769 p99=9.876 max=10.152
FEL26 PERF LAYER variant=off edges=0
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=off renderer=headless frames=600 p50=11.001 p99=208.805 max=292.126
FEL26 PERF LAYER variant=always edges=4
FEL13 PERF fixture=01-s0-seed1-0-4_0-t9 side=always renderer=headless frames=600 p50=6.843 p99=8.607 max=11.342
FEL26 PERF pair=1 off_p50=6.822 always_p50=6.776 off_p99=9.760 always_p99=10.180
FEL26 PERF pair=2 off_p50=6.769 always_p50=6.827 off_p99=9.876 always_p99=11.085
FEL26 PERF pair=3 off_p50=11.001 always_p50=6.843 off_p99=208.805 always_p99=8.607
FEL26 PERF HEADLESS renderer=headless p50_deltas_ms=[-0.046, 0.058, -4.158] p50_median_ms=-0.046 p99_deltas_ms=[0.42, 1.209, -200.198] p99_median_ms=0.42
```

## Commands run

From the task worktree:

```sh
tools/fel26/native.sh --headless
tools/fel26/native.sh --dry-run
FEL13_PERF_SET=fel26 tools/fel13/native.sh --dry-run --perf

FEL13_MODE=focused python3 tools/godot_task_runner.py --task-id fel-26 --stream -- godot --headless --path . --script tools/fel13/session.gd
for variant in off window always; do
  FEL13_MODE=content FEL13_SIDE=branch LABYRINTH_CEL_LOOK=all LABYRINTH_OCCLUDER_EDGE="$variant" \
    python3 tools/godot_task_runner.py --task-id fel-26 --timeout 360 --stream -- godot --headless --path . --script tools/fel13/session.gd
done
for probe in tools/fel02/focused.gd tools/rd02/focused_checks.gd \
  tests/board_surface_presentation_test.gd tests/trap_center_ground_test.gd \
  tests/combat_board_projection_test.gd tests/snare_ui_test.gd tests/board_tile_tooltip_live_test.gd; do
  LABYRINTH_OCCLUDER_EDGE=window python3 tools/godot_task_runner.py --task-id fel-26 --stream -- godot --headless --path . --script "$probe"
done

FEL26_PARITY=1 FEL26_BASELINE_SOURCE="$PWD/tools/fel26/captures/fel26.Azv2gb/release-overlay.txt" \
  FEL26_RELEASE_BASELINE=1 FEL26_AUDIT=1 FEL13_MODE=witness FEL13_SIDE=branch LABYRINTH_CEL_LOOK=all LABYRINTH_OCCLUDER_EDGE=off \
  python3 tools/godot_task_runner.py --task-id fel-26 --stream -- godot --headless --path . --script tools/fel13/session.gd
python3 tools/fel26/proof.py headless tools/fel26/captures/fel26.Azv2gb
LABYRINTH_CEL_LOOK=all LABYRINTH_OCCLUDER_EDGE=off FEL13_MODE=fel26_still \
  python3 tools/godot_task_runner.py --task-id fel-26 --stream -- godot --headless --path . --script tools/fel13/session.gd

python3 tests/test_ui_identity_lint.py
python3 tests/test_rules_text_lint.py
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir tools/fel26/captures/checks/r1-python
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir tools/fel26/captures/checks/r1-python-retry
git diff --check
```
