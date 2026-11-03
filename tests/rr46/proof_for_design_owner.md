# rr-46 proof for the design owner

All commands start in this worktree. Native proof is pending: this sandbox has no macOS window-server access. No windowed command was attempted. Use fresh output/manifest paths on repeated runs; the runner refuses to overwrite evidence.

## Inspect the real fire Warband

The design owner owns fixture creation, peer review, commit and publication. This command regenerates/verifies the pre-action save before opening it. The 1000 HP override is a named proof-only survival fixture, not production tuning.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 tools/inspection_fixture.py --task-id rr-46 --scenario warband --warband-biome fire --warband-tier 2 --warband-case encounter --seed 83 --player-hp 1000 --player-max-hp 1000 --manifest /private/tmp/labyrinth-inspection-manifests/rr46-fire.json --summary 'rr-46 movement and death parity, fire Warband' --launch
```

The wrapper command was checked with `--dry-run`; no inspection fixture or launch was performed by this worker.

## Record the real fight, retreats and death

This probe inherits the existing persisted Continue boot and root-window readback. It records three ordinary Pass rounds with the real AI/resolver, then three **explicitly labelled staged** keep-distance retreats and a staged lethal hit, on the same Warband board. Recording JSON distinguishes `real_fight`, `staged_keep_distance` and `staged_death`; no staged sequence is presented as naturally occurring combat. It writes 1920×1080 PNG frames and timestamps. Inspect the record to confirm the required moves and complete death are present.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT=/private/tmp/labyrinth_codex/rr46/feedback3-fight-1 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-46 --timeout 300 --expect-size 1920x1080 --proof-contract tests/rr46/fight_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/rr46/feedback3-fight-1-result.json tests/rr46/fight_probe.gd -- --scenario warband --warband-biome fire --warband-tier 2 --seed 83
```

Create a variable-duration movie from the recorded timestamps using the repository's existing FFmpeg dependency. The concat file preserves wall-clock pacing even when PNG readback skips a frame.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 - <<'PY'
import json
from pathlib import Path
root = Path('/private/tmp/labyrinth_codex/rr46/feedback3-fight-1')
frames = json.loads((root / 'recording.json').read_text())['frames']
assert frames, 'Native recording has no frames'
lines = ['ffconcat version 1.0']
for index, frame in enumerate(frames):
    lines.append("file '%s'" % (root / frame['file']))
    duration = frames[index + 1]['elapsed_seconds'] - frame['elapsed_seconds'] if index + 1 < len(frames) else 1 / 30
    lines.append('duration %.9f' % duration)
lines.append("file '%s'" % (root / frames[-1]['file']))
(root / 'recording.ffconcat').write_text('\n'.join(lines) + '\n')
PY
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && ffmpeg -f concat -safe 0 -i /private/tmp/labyrinth_codex/rr46/feedback3-fight-1/recording.ffconcat -fps_mode vfr -c:v libx264 -pix_fmt yuv420p /private/tmp/labyrinth_codex/rr46/feedback3-fight-1/rr46-fire-fight.mp4
```

## Feedback 3: ownership ID proof, 20 jobs

The round-2 colour oracle is obsolete. Its lit production/unlit reference crops cannot establish depth errors. Run into fresh `feedback3-native` folders. Logical output is fixed at 1920×1080, 100% UI scale, regardless of Retina backing size.

The production ID pass uses the actual retained floor/tile callbacks and actor routing. Each callback paints the corresponding isolated sprite silhouette in an opaque unique RGB ID, with an unshaded material, no lights/shadows/post-effects and nearest sampling. Static sprite silhouettes are rendered once per job, cached and reused by both passes. The actor silhouette comes from a separate, tile-order-independent actor pass at the current production motion/dissolve phase. Colour crops remain evidence only. The expected ownership map independently sorts primitives by depth plane, ground Y, ground X and the fixed same-origin sprite rank; it never asks production for painter order. Floors occupy the board's existing lower plane, and their front/behind coverage labels still use ground Y. The archive verifier independently reconstructs every retained expected ID map from the saved primitive IDs and actor mask. Reversed composition, an actor/prop swap and a reversed production painter remain failing mutation tests.

Each job starts with an actor-alone ID calibration on its real production layer, with the occluder set explicitly empty in both ID passes. It must have actor pixels, zero overlap and zero ID mismatches. A failure saves diagnostic ID maps and stops before the sweep.

Final scope is all ten rigs on `fire_t1_r6` and `earth_t3_r7`. Earth supplies the other biome's tier-3/revision-7 prop sprites and legal routes on both sides of their ground Y. **A board with real visible boundary-wall overlap is impossible in current production:** `combat_board_view.gd` sets `OUTER_WALL_RENDERING_ENABLED = false`; `_should_render_tile` removes all boundary wall tiles. Interior wall cells render as pillars and count as props. The inventory explicitly lists all 32 culled wall tiles on each board and exempts `wall_front`/`wall_behind` only with `production_culls_kind`, recording this exact cause. No wall is enabled just for proof. Both floor classes and both prop classes remain mandatory for every job (80 required classes across 20 jobs). Native overlap coverage is pending, never inferred from bounding boxes.

The proof captures every second source frame of move/retreat, including both endpoints, and every death frame. Eight move directions, a resolver `keep_distance` route and a complete death remain mandatory. A mandatory diagonal `(3,3) → (2,4)` targets real pillar/body overlap at a shared projected X, avoiding the old torch-glow-only witness. Extra legal move routes are selected for missing classes, up to the proof-only 16-route cap. Missing overlap or exhausted time is a failure. The archive verifier checks the exact frame indices, phases, directions, authored/scaled death clocks and required evidence cadence. It rejects endpoint-only death archives and an empty first/last/failing `frame_file`.

Full colour frames are saved only at first/last/failing samples and calibration. Colour crops, actual/expected ID maps and actor masks are saved for failures, every tenth passing sample and route endpoints. Primitive ID images are saved once per job. Two MB are reserved for the findings metadata inside the storage ceiling. Each report prints actual elapsed seconds and bytes; the checker fails above **300 seconds or 250,000,000 bytes**. The verifier measures the archive size as well. No current native cost measurement is available from this sandbox. The director's obsolete round-2 fire Slag job cost 956 seconds and approximately 1.8 GB; do not treat that as a measurement of this replacement.

First run the fire Slag job:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-46 --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/rr46/feedback3-fire-slag-result.json tests/rr46/depth_probe.gd -- --board fire_t1_r6 --actor slag_mortar --output /private/tmp/labyrinth_codex/rr46/feedback3-native/fire_t1_r6/slag_mortar
```

Run the remaining 19 jobs, then verify the complete archive. Use fresh paths on repeats; the probe refuses to overwrite evidence.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46
for rr46_board in fire_t1_r6 earth_t3_r7; do
  for rr46_actor in hoarfrost_seer arc_thrall glacial_mirror briar_weaver hollow_mimic slag_mortar gale_herald gloam_stalker frostglass_lancer chainbound_gaoler; do
    if [ "$rr46_board/$rr46_actor" = fire_t1_r6/slag_mortar ]; then continue; fi
    python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-46 --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest "/private/tmp/labyrinth_codex/rr46/feedback3-${rr46_board}-${rr46_actor}-result.json" tests/rr46/depth_probe.gd -- --board "$rr46_board" --actor "$rr46_actor" --output "/private/tmp/labyrinth_codex/rr46/feedback3-native/$rr46_board/$rr46_actor" || exit 1
  done
done
python3 tests/rr46/verify_native.py /private/tmp/labyrinth_codex/rr46/feedback3-native --inventory tests/rr46/native_inventory.json
```

The first native archive contained nine unique empty **move** samples (`move_2_1_-1_1`, frames 42–50), each with an after/before row. Its 63 death samples had actor pixels through phase 0.983870967741935 and zero only at phase 1. The old isolated actor used tile routing; the replacement draws the isolated actor directly and includes the complete expanded dissolve canvas in its crop. It also calls the production `CutoutContext` boundary, which round 2 omitted, so deaths now sample the authored collapse rather than dissolving an idle pose. Runtime is unchanged. Every death row records scaled and authored elapsed time, clip phase and dissolve phase. Gaoler phase 0.62 remains a required-visible negative control.

If bound proof/board/data sources change, regenerate the inventory before new captures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 tools/godot_task_runner.py --task-id rr-46 --stream -- godot --headless --path . --script tests/rr46/depth_probe.gd -- --list-only --output res://tests/rr46/native_inventory.json
```

## Side-by-side production schedules

This probe composes two actual production path-planner submission streams: Slag Mortar beside Ash Hound, two tiles, at each combat speed. JSON retains both source schedules and every submitted frame.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-46 --timeout 120 --expect-size 1920x1080 --proof-contract tests/rr46/comparison_proof_contract.json --result-manifest /private/tmp/labyrinth_codex/rr46/owner-pair-1-result.json tests/rr46/comparison_probe.gd -- --output /private/tmp/labyrinth_codex/rr46/owner-pair-1
```

## rr-40 real-renderer geometry

Fresh and prepared renderers, both views/reflections, independent approved-rest orientation/placement oracle and deliberately inverted/off-tile negative controls:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-46 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-46 --timeout 300 --expect-size 1920x1080 --result-manifest /private/tmp/labyrinth_codex/rr46/owner-geometry-1-result.json tests/rr46/sprite_geometry.gd -- /private/tmp/labyrinth_codex/rr46/owner-geometry-1
```

## Existing headless evidence

- `/private/tmp/labyrinth_codex/rr46/before-timing.json` and `after-timing.json`; the before data is also retained in `tests/rr46/timing_baseline.json`.
- `/private/tmp/labyrinth_codex/rr46/depth-final.json`: all grouped findings and frame indices; 481 actual retained-cache submissions.
- `/private/tmp/labyrinth_codex/rr46/focused.log`, `final-clocks.log`, `depth-final.log`.
- `/private/tmp/labyrinth_codex/rr46/comparison/comparison.json`: headless two-tile schedule validation.
- `/private/tmp/labyrinth_codex/rr46/fight-final-validation/rr46_fire_fight.json`: persisted fixture and Continue validation, no rendered pixels.
- Full-suite and audit results are recorded in `implementation_report.md` after completion.
