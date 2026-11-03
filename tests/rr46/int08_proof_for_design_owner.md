# int-08 proof for the design owner

No windowed run was attempted: this sandbox has no macOS window server. No new native capture, screenshot or archive verification result is claimed. The existing `depth_probe.gd` and `depth_proof_contract.json` remain unchanged and enforce 1920×1080 at 100% UI scale, full frames, calibration and ownership evidence.

The fresh headless export is installed at `tests/rr46/native_inventory.json`. Its SHA-256 is `0fc1fab9f32fa30c11562a3b940356d4e42062ae6de17d4b458e77d8178c893a`. Compared with int-07 at `698720ea1`, exactly three source hashes changed: Lancer integration (rr-45), board view (sum-01 / enc-04 / rr-46 / rr-47), and room generator (bos-02). All coverage, timing, sampling, cost, board primitive and route fields are identical. `native_extensions.json` retains both hashes and the responsible units; mutation tests reject every changed source and the old archive seal.

The observed headless export command was:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-08 && python3 tools/godot_task_runner.py --task-id int-08 --stream -- godot --headless --path . --script tests/rr46/depth_probe.gd -- --list-only --output res://output/int-08/native-inventory-candidate.json
```

## Exactly 20 windowed jobs

Use this fresh archive: `/private/tmp/labyrinth_codex/int-08/native-698720ea1-int08`. Choose a new archive path if repeating a capture; do not overwrite existing evidence. The two boards × ten actors below enumerate all 20 jobs. Every job retains eight movement directions, retreat, every death frame, midpoint neighbours and the mandatory `(3,5) → (2,6)` corner route. Existing per-job limits remain 300 seconds and 250,000,000 bytes. The 330-second outer timeout is the existing capture allowance for shutdown and validation.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-08 && for int08_board in fire_t1_r6 earth_t3_r7; do
  for int08_actor in hoarfrost_seer arc_thrall glacial_mirror briar_weaver hollow_mimic slag_mortar gale_herald gloam_stalker frostglass_lancer chainbound_gaoler; do
    python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id int-08 --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest "/private/tmp/labyrinth_codex/int-08/native-698720ea1-int08-${int08_board}-${int08_actor}-result.json" tests/rr46/depth_probe.gd -- --board "$int08_board" --actor "$int08_actor" --output "/private/tmp/labyrinth_codex/int-08/native-698720ea1-int08/${int08_board}/${int08_actor}" || exit 1
  done
done
```

Verify all jobs together. The result file must remain outside the capture archive:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-08 && python3 tests/rr46/verify_native.py /private/tmp/labyrinth_codex/int-08/native-698720ea1-int08 --inventory tests/rr46/native_inventory.json --result-file /private/tmp/labyrinth_codex/int-08/native-698720ea1-int08-verification.json
```

Expected verifier line: `RR46 NATIVE ARCHIVE: PASS`, with 20 jobs and no errors. This is an expectation, not an observed result. The director captures and commits the verification result. Inspection is not applicable under the recorded contract: test/pin repair with no player-facing change. No `tools/inspection_fixture.py` command is required.
