# fx-14 result

The single-shot renderer is installed on the production combat board. The changes are uncommitted on `codex/fx-14`. Native renderer proof is ready for the design owner to run.

## Changes

- `scripts/shot_fx.gd` owns shot resolution, atlas selection, the retained canvas items, their clocks, and resize loading. `shaders/shot_fx.gdshader` paints the indexed frames, clips cells, and batches the chain links.
- `scripts/combat_board_view.gd` binds those items to the floor and effects layers, resolves the existing launch and contact anchors, and bypasses the former single-shot paint for matched effects. RunScene’s existing resolution tracker provides the committed base card ID through Illusion echoes.
- `assets/art/effects/shots/shot_*.png.import` and the five new Godot UID sidecars provide lossless texture imports and stable resource IDs. `tests/approved_asset_pins.json` adds the seven director PNGs in inventory order.
- `tests/umbra_action_animation_probe.gd` checks the retained reduced-motion hit at the visible target where it previously checked the old elemental scene-depth pass.
- `tools/fx14/{fixtures.gd,verify.gd,native.gd,native.sh,native_proof.json}` define the headless and native proofs. The executable entry point was also copied to `/private/tmp/labyrinth_codex/fx-14/native.sh`.

## Acceptance criteria

1. **Which shot.** Selection checks the base card, enemy and intent pair, intent, then element. An explicit empty entry keeps the current drawing. Matching pale hero shots use the equipped bow or repeater motion. The resolver covers distant pulls and pushes. An Illusion echo uses the committed card mapping and the effect’s Illusion origin.
2. **Path and clock.** The launch and destination reuse the existing anchors. Travel applies the authored ease and lift, and heading follows the screen tangent. The second die uses the authored lateral offset and spin phase. Chain links fill the launch-to-head span in one draw. The head reaches the original contact anchor, then retracts or follows the submitted moving-body position. Default ranged contact is 0.66. Enemy descriptors whose primary kind is push or pull follow their existing 0.50 feedback boundary.
3. **Ground shadow.** The retained floor item paints the shadow on the straight tile-centre line below bodies. Sunlance and hook skip it.
4. **Hit.** Contact starts one eight-frame hit above the target on a separate clock. The new single-shot path bypasses the old ice, earth and air travel, scene-depth impact and floor light. Surface changes continue through the existing outcome renderer.
5. **Size.** The grd-11 size function is copied verbatim. The shader snaps anchors after the canvas transform and fetches integer atlas texels using the director palette. Headless checks cover the four requested tile widths at both heights, and the GPU probe checks exact pixel replication.
6. **Umbra.** The shader gates each head, tail, shadow and link cell by the visible intervals. For a visible-origin shot that crosses darkness, the board samples the line using the existing interval convention. Hit rendering checks current target visibility.
7. **Load.** The settled board installs one sheet during preparation. Resize decoding runs on a thread while the current sheet remains bound. Board startup queues the shader warm draw. An isolated `all_resources` pack exposed the metadata and all seven imported sheets without a dedicated JSON include filter.
8. **Reduced motion.** The retained hit shows the director’s frame 1 for 180 ms at contact. Flight, chain and shadow stay hidden.
9. **Cost.** A single head and shadow use two retained draws. A double die uses two heads and one shared shadow item. A hook uses one head and one chain item. The shot clock updates retained items without allocating per-frame drawing geometry or queuing the board’s other layers.

## Verification

| Check | Observed result |
| --- | --- |
| `tools/fx14/verify.gd -- --affected` | `FX-14 DATA: 102 ranged and distant-force action rows` · `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1796 checks, 0 failures)` |
| `tools/fx14/native.gd -- --validate-fixture` | `FX-14 NATIVE FIXTURE: PASS (25 cases, 0 failures)` |
| Mounted isolated export pack | `FX-14 PACK: metadata and 7 of 7 sheets available (0 failures)` |
| UI identity lint | `Ran 25 tests in 8.231s` · `OK` |
| Rules text lint in the Python default group | `PASS: Rules text lint (16 existing hits)` |
| Python default group | `Ran 194 tests in 46.575s` · `FAILED (failures=1)` |
| Sidecar guard with the handoff files included in its inventory | `FX-14 SIDECARS WITH HANDOFF FILES: PASS` |
| Protagonist ranged gameplay probe | `ERROR: razor_gale applies its exact damage once` · `PROTAGONIST RANGED GAMEPLAY PROBE: FAIL`. The same two lines reproduced with the original fx-14 board code. |
| Umbra visual probe parse, proof shell syntax, and diff whitespace | Exit 0 for each. |

The Python default group’s sole remaining failure is `Missing tracked Godot sidecars (7)`. The seven PNG import sidecars are present in the worktree. The check reads the Git index, so the owner’s staging step makes them visible to it. The initial Python pass also caught an incorrect pin hash format. The final pass cleared the asset pin check after switching the seven new entries to Git blob hashes.

- [Headless verifier log](/private/tmp/labyrinth-godot-home/fx-14-1795397997906220000-26873/godot.log)
- [25-case RunScene fixture log](/private/tmp/labyrinth-godot-home/fx-14-1795397997906153000-26874/godot.log)
- [Python default group results](/private/tmp/labyrinth_codex/fx-14/python-default-verified/summary.json)
- [Ranged gameplay probe manifest](</private/tmp/labyrinth-godot-home/fx-14-1795397525031725000-23936/Library/Application Support/Escape the Umbra Parallel fx-14-1795397525031725000-23936/probes/protagonist_ranged_v01/manifest.json>)
- [Original board probe manifest](</private/tmp/labyrinth-godot-home/fx-14-1795397668236992000-25705/Library/Application Support/Escape the Umbra Parallel fx-14-1795397668236992000-25705/probes/protagonist_ranged_v01/manifest.json>)

## Proof for the design owner

The native script runs the visual probe at 1920×1080 and 100% UI scale with the cel look and combat HUD. It validates the GPU’s palette, cell size and clipping, then saves six native frames and a strip of six 640×480 crops for each of the 25 cases. It also encodes a four-second reel of Hurl Spear, Snake Eyes and Icicle Lance.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-14 && /private/tmp/labyrinth_codex/fx-14/native.sh
```

The script prints the capture directory under the isolated Godot profile. The result manifest and MP4 go in `/private/tmp/labyrinth_codex/fx-14/native/`. No PNGs or video were captured in the headless sandbox.

The existing Umbra visual probe can check the updated reduced-motion assertion on its full sequence.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-14 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id fx-14 --expect-size 1920x1080 --proof-contract tests/umbra_action_animation_probe_contract.json tests/umbra_action_animation_probe.gd
```

## TODO_DESIGN placeholders

None.

## Chosen defaults

- The capture harness uses room-entry seed 8585, fixture seed 97131, hero tile (3, 4), target tile (5, 4), and hidden source tile (7, 4). The pull fixture supplies a debug-only body position from the target towards (4, 4).
- Each crop is centred on the shot’s tile-centre midpoint, clamped to the framebuffer. The four-second reel uses 60 fps and three 80-frame segments. The visual runner is allowed 300 seconds to write 415 PNGs.
- The renderer preallocates two hit slots and 64 visibility intervals. These are storage bounds, independent of the authored shot tuning.

## Open issues

- Native frame content, shader pixels and the four-second recording await a window-server run.
- The owner’s Git staging step is required for the tracked-sidecar guard. The original Razor Gale gameplay assertion remains a separate baseline failure.
