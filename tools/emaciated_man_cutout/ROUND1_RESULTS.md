# emac-02 round 1 observed results

All runs were headless. Focused checks only; no full suites, peer review or Git
writes. Native visual proof after these corrections remains pending.

| Check | Observed result |
| --- | --- |
| `python3 tests/test_art_identity_gate.py` | `Ran 111 tests in 73.542s` / `OK` |
| `LABYRINTH_TASK_ID=emac-02 python3 -m unittest tests.test_approved_content_manifest` | `Ran 1 test in 8.641s` / `OK` (production pack smoke also `APPROVED CONTENT SMOKE: PASS`) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.572s` / `OK` |
| Runner → `tests/opening_boon_test.gd` | `OPENING BOON TEST RESULT: PASS` / `TEST RESULT: PASS` |
| Runner → `tests/dragon_reward_feedback_test.gd` | `Dragon reward feedback logic: PASS` |
| `python3 tools/cutout_workflow.py validate experiments/cutouts/emaciated_man/emac02` | `"ok": true`, 11 joints / 13 parts / 1 mesh / 1656 vertices, no errors |
| Runner → `tools/emaciated_man_cutout/sample_motion.gd` | `EMAC MOTION: PASS; samples=321; max_near_hand_slide_px=0.00000000; static_supports=4; loop=8.0s` / `EMAC FAR HAND: PASS; pinned_mesh_vertices=200` |
| `python3 tools/emaciated_man_cutout/round1_checks.py` | `EMAC ROUND1 CPU: PASS; poses=321; sack_changed_pixels=0; green_pixels=0; glow_cutoff=0.75` |
| Runner → `tools/emaciated_man_cutout/editable_probe.gd` | `EMAC EDITABLE: PASS; idle=8.0s; transform_and_glow_keys=4` |
| Runner → `tools/emaciated_man_cutout/game_probe.gd -- --verify-only` (cel look) | `EMAC GAME PROBE: PASS; waypoint=cutout; dialogue=portrait_region; reduced=rest; sheet=unused` |
| Strict art registry check, this entry | `ART IDENTITY CHECK: PASS (0 failures, 0 pending, 0 skips)` |
| Source/cel sheet | `ART IDENTITY SHEET: spec/art_identity/jobs/emaciated_man/mq_front/sheet.png` (inspected) |
| Python compile / `git diff --check` | exit 0 |

The runner prefix for every Godot command above was
`python3 tools/godot_task_runner.py --task-id emac-02 --stream -- godot --headless --path . --script`.
Godot logs and focused Python logs are copied into the case's `proof/round1_*`.
The two production geometry logs and corrected portrait crop are alongside them.

## Native-dependent density check

`python3 tools/process_board_density.py --check --only emaciated_man_cutout`
returned exit 1, exactly:

```
rest rebake needed: assets/units/emaciated_man_cutout/front/rest.png: rest pixels changed since recorded rebake
```

The global `--check` also reports:

```
rest rebake needed: assets/units/chainbound_gaoler_cutout/humanoid_v2/front/rest.png: rig part pixels changed since recorded rebake
rest rebake needed: assets/units/chainbound_gaoler_cutout/humanoid_v2/rear/rest.png: rig part pixels changed since recorded rebake
rest rebake needed: assets/units/emaciated_man_cutout/front/rest.png: rest pixels changed since recorded rebake
```

Gaoler production files have no diff; its registry/output records match HEAD.
They were left untouched. The emac record must follow the owner's fresh native
rebake, as listed in README.md. No headless CPU assembly was certified as native.

## Negative control against the director's previous native reel

```
EMAC NATIVE PIXELS: FAIL; {"frames": 160, "max_changed_sack_pixels": 92, "max_green_pixels": 9, "ok": false, "peak_sack_frame": 28, "static_sack_pixels": 1035}
```

This is the expected result for the old reported defects. Fresh native frames
have not been produced here. The new gate requires zero changed non-glowing
sack pixels and zero opaque green-dominant pixels across every native frame.
The game probe additionally requires actual hero/NPC body pixels rather than
only valid semantic state, labels or a nonempty floor capture.

Existing macOS certificate and NumPy/Pillow warnings appeared on passing runs.
No active TODO_DESIGN placeholders remain. Chosen proof defaults: RGB change
threshold 8/255 and minimum changed actor-box fraction 0.10. The director's
0.75 glow cutoff and all brief motion values remain unchanged.
