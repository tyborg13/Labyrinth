# Weapon and shield motion study — Unit 1

Scope: case-owned art copies, layouts, samplers and proof only. Production integration is Unit 2. Changes remain uncommitted per the implementation assignment; no peer review or publication is part of this unit.

Acceptance: fresh production seeds; registered front/rear maul, knife and shield; existing poses preserved; heavy contact at authored 0.42 over 0.72 s, stab contact at 0.42 over 0.40 s, and shield guard over 0.30 s. Preserve painted arm lengths, rigid terminals, planted support, identity phase curves and the existing restrained cloth. No new idle motion.

Proof: protected-art validation, real-renderer 1920×1080 SubViewport study captures at 100% UI scale, complete native cycles, pixel-identical editable-scene roundtrips, timed reels, exact-phase keys, 2× contact sheets and 0.77× board thumbnails. Focused workflow and case motion checks. Risk: tier 2 local visual study; no gameplay, save, analytics or balance changes. Inspection: case review directories and toolkit inspector; this is not live combat integration proof.

## Implementation and ownership

Only this directory was authored for Unit 1. Each case includes the full locally
copied production seed, registered gear art, `layouts/{front,rear}.json`, a
case-owned `motion.gd`, `cutout.json`, retained seed provenance and the registered
art baseline. Production files and production assertions were left to Unit 0.

| Case | New clip | Frames / seconds | Notes and every adjusted key |
| --- | --- | --- | --- |
| `heavy_v01` | `attack_heavy` | 43 / 0.72 | [Heavy review notes](heavy_v01/review/README.md) |
| `stab_v01` | `attack_stab` | 24 / 0.40 | [Stab review notes](stab_v01/review/README.md) |
| `shield_v01` | `block_shield` | 25 / 0.30 | [Shield review notes](shield_v01/review/README.md) |

The added top-level dispatch and the new helpers at the end of each `motion.gd`
are the Unit 2 port surface. All eight existing sampler branches and their
behavior remain identical to `source/seed_motion.gd`; the seed's real sword
playback curve is retained. Both new weapon clips have identity phase curves and
contact at 0.42. Arm and leg paint lengths, gloves, weapons and new shield guard
rigidity are preserved. The planted-feet fit applies minimal pelvis corrections;
the maul applies a minimal shared shoulder translation instead of sleeve stretch.
No idle changes or new cloth oscillation were introduced.

The shield has a documented topology exception: `gear_offhand_mount` is a child
of `forearm_l`, with the sprite registered at the same source offset and z-index.
Only the new block counter-rotates this pivot about the shield centre. Directly
parenting to the forearm cannot meet the rear wrist and upright attitude together
with fixed arm lengths. Existing clips leave the pivot at identity. Rear cast
and shoot consequently inherit the original arm's affine stretch (basis error
0.613214); their visuals and possible face/HP-bar overlaps still require capture.

## Observed verification (2026-10-05)

- All three `validate --protect art` runs returned `"ok": true`, `"errors": []`.
- `GEAR_ACCEPTED_POSES: PASS (8 clips × 2 facings × 201 phases × 3 cases)`
- `GEAR_MOTION_CONTRACTS: PASS`
- `python3 tests/test_cutout_workflow.py`: `Ran 16 tests in 0.595s`, `OK`.
- `key_pose_probe.gd --check-only`: exit 0 via the task runner, with no editor scan.
- Python registration/review collector syntax and collector import/CLI checks pass.
- Full suite in the shared worktree: `TEST RESULT: FAIL (5 failure(s))`.

The five full-suite failures are unchanged production assertions:

1. `The player has cutout source art for detached layout inspection`
2. `Chainbound Gaoler board art should read nearly as tall as the player`
3. `Detached board layout should use promoted cutout rest art`
4. `Illusions should resolve the player texture for drawing`
5. `Illusion previews should resolve the player texture for drawing`

No assertion was rewritten. The full suite includes Unit 0's concurrent production
changes, so these are observed shared-worktree failures, not a claim about a
fresh `master` run. Its deliberate analytics-acknowledgment failure injection
also printed `Failed to acknowledge progression analytics event batch`; that
injection already exists on `master`. Retained evidence:
[results.json](verification/results.json), [full_suite.log](verification/full_suite.log),
[motion measurements](motion_contract_results.json), and the three protected-art
validation reports under `verification/`.

## Native proof blocked

The exact-phase probe and all three maintained toolkit `render` commands were
attempted through `tools/visual_probe_runner.py`. Each failed before Godot
initialized: macOS LaunchServices / `com.apple.hiservices-xpcservice` returned
`Connection invalid`, then the runner reported `Godot did not initialize within
8.0 seconds` and `godot.log was never created`. No startup timeout was extended.
The failed [key probe result](key_probe_result.json) contains no images.

The requested output paths were `/private/tmp/protagonist-gear-heavy-v01`,
`/private/tmp/protagonist-gear-stab-v01` and
`/private/tmp/protagonist-gear-shield-v01`. **None contains successful proof.**
All three `verify-render` attempts returned `"ok": false` because their
`capture_input_sha256.json` does not exist. There are no capture paths, reels,
contact sheets or editable scenes to hand off, and no board-scale readability
claim can be made. Each review note lists every requested key as unassessed.

## Reproduce after native GUI startup is available

Run from this worktree. Each output must remain fresh; if another attempt has
created it, select a new proof version and update the collector's paths. Keep the
shared production inputs stable through capture and verification: the maintained
toolkit binds proof to the complete rendering dependency closure.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/visible-equipment-on-the-protagonist-cutout-vertical-slice
python3 tools/cutout_workflow.py render experiments/cutouts/protagonist_gear/heavy_v01 --output /private/tmp/protagonist-gear-heavy-v01 --task-id visible-equipment-on-the-protagonist-cutout-vertical-slice
python3 tools/cutout_workflow.py verify-render experiments/cutouts/protagonist_gear/heavy_v01 --output /private/tmp/protagonist-gear-heavy-v01
python3 tools/cutout_workflow.py render experiments/cutouts/protagonist_gear/stab_v01 --output /private/tmp/protagonist-gear-stab-v01 --task-id visible-equipment-on-the-protagonist-cutout-vertical-slice
python3 tools/cutout_workflow.py verify-render experiments/cutouts/protagonist_gear/stab_v01 --output /private/tmp/protagonist-gear-stab-v01
python3 tools/cutout_workflow.py render experiments/cutouts/protagonist_gear/shield_v01 --output /private/tmp/protagonist-gear-shield-v01 --task-id visible-equipment-on-the-protagonist-cutout-vertical-slice
python3 tools/cutout_workflow.py verify-render experiments/cutouts/protagonist_gear/shield_v01 --output /private/tmp/protagonist-gear-shield-v01
python3 tools/visual_probe_runner.py experiments/cutouts/protagonist_gear/key_pose_probe.gd --task-id visible-equipment-on-the-protagonist-cutout-vertical-slice --no-headless --expect-size 1920x1080 --expect-size 512x512 --result-manifest experiments/cutouts/protagonist_gear/key_probe_result.json
python3 experiments/cutouts/protagonist_gear/collect_review.py --keys <successful-user-data-path>/probes/protagonist_gear_keys
```

`key_pose_probe.gd` prepares the 50 exact authored phases requested by the brief
(plus retained hit/attack keys), in both facings. Its board surface is a
1920×1080 `SubViewport` at 100% UI scale; native poses are the separate padded
512×512 puppet surface, retaining 1× source pixels. Neither capture reads the
root window texture. It checks source hashes before and after capture.
`collect_review.py` refuses failed/stale proof, copies reels, scenes and the
exact-phase PNGs to each `review/`, and builds a labeled sheet per clip with 2×
poses and 0.77× thumbnails at one shared source registration. Its packing path
is prepared but could not execute without successful native inputs. Inspect the
actual cycles and sheets before adding the deferred readability judgments.
