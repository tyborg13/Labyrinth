# int-07 proof for the design owner

No windowed run was attempted: this sandbox has no macOS window server. No new native archive or screenshot exists. The existing `tests/rr46/depth_probe.gd` and its strict `depth_proof_contract.json` implement the required capture; no substitute renderer or synthetic archive was introduced.

## Source binding before capture

The headless export at `output/int-07/native-inventory-candidate.json` is field-for-field identical to the original inventory except five source hashes. int-07 rebinds only the two approved Gaoler sources. Three stale hashes already fail at `ff77c892c`: Lancer `integration.json`, `combat_board_view.gd`, and `room_generator.gd`. Those existing failures remain under the instruction to report pre-existing failures without rewriting their assertions. The original inventory's routes, actors, timing, coverage requirements, budgets and board primitive lists remain untouched. Old captures retain their original inventory digest and cannot be passed off as fresh merged-runtime captures.

If the director elects to repair the three earlier stale bindings and capture this merge, first regenerate the inventory with the existing headless exporter. Audit the resulting diff: from this worker's result, **only those three source-hash values** may change. That owner action also requires updating `test_native_inventory_only_rebinds_approved_gaoler_sources` to audit the newly authorized deltas.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-07 && python3 tools/godot_task_runner.py --task-id int-07 --stream -- godot --headless --path . --script tests/rr46/depth_probe.gd -- --list-only --output res://tests/rr46/native_inventory.json
```

## Native depth archive: exactly 20 jobs

Archive: `/private/tmp/labyrinth_codex/int-07/native-a89628a78`. Use a new archive name on repeats; existing evidence must not be overwritten. The exact job list is the Cartesian product of:

- Boards: `fire_t1_r6`, `earth_t3_r7`.
- Actors: `hoarfrost_seer`, `arc_thrall`, `glacial_mirror`, `briar_weaver`, `hollow_mimic`, `slag_mortar`, `gale_herald`, `gloam_stalker`, `frostglass_lancer`, `chainbound_gaoler`.

Each job retains the rr-47 midpoint-neighbour samples and mandatory `(3,5) → (2,6)` corner route, eight movement directions, retreat, and every death frame. The existing contract requires fresh 1920×1080 frames at 100% UI scale, actor-alone calibration and retained colour/ownership evidence. Storage and elapsed-time ceilings remain 250,000,000 bytes and 300 seconds per job. The outer 330-second runner timeout is the existing rr-46 capture command's allowance for shutdown and validation.

After the source-binding step above, execute this exact loop:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-07
for int07_board in fire_t1_r6 earth_t3_r7; do
  for int07_actor in hoarfrost_seer arc_thrall glacial_mirror briar_weaver hollow_mimic slag_mortar gale_herald gloam_stalker frostglass_lancer chainbound_gaoler; do
    python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id int-07 --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest "/private/tmp/labyrinth_codex/int-07/native-a89628a78-${int07_board}-${int07_actor}-result.json" tests/rr46/depth_probe.gd -- --board "$int07_board" --actor "$int07_actor" --output "/private/tmp/labyrinth_codex/int-07/native-a89628a78/${int07_board}/${int07_actor}" || exit 1
  done
done
```

Verify all 20 jobs together; the result file must stay outside the capture archive:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-07 && python3 tests/rr46/verify_native.py /private/tmp/labyrinth_codex/int-07/native-a89628a78 --inventory tests/rr46/native_inventory.json --result-file /private/tmp/labyrinth_codex/int-07/native-a89628a78-verification.json
```

Expected final verifier line: `RR46 NATIVE ARCHIVE: PASS`, with 20 jobs and no errors. This is an expectation, not an observed result. No inspection-fixture launch was required by this unit brief.
