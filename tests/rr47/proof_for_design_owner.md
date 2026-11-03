# rr-47 feedback 2 — current director commands

Round 1 is committed at `21119ff68`. This round changes the shared rig-v2 depth-host helper and native sampling, so the earlier archive remains historical evidence. Do not overwrite it or rebind its metadata. No windowed run was attempted in the worker sandbox.

## Scope and capture contract

Re-run **fire_t1_r6 and earth_t3_r7 × all ten rig-v2 enemies** listed below (20 jobs). Every rig uses the changed host helper, and every job now includes the mandatory reviewer route `(3,5) → (2,6)` beside pillar `(3,6)`. The checker samples every second move/retreat frame plus every frame within one source frame of the midpoint, including Mimic frame 23/48. Death still samples every frame. Midpoint neighbours retain full frames, crops and actual/expected ownership maps even when passing. Existing first/last/failing frames, calibration, cadence, budgets, overlap requirements and mutations remain required.

The worker regenerated `tests/rr46/native_inventory.json` headlessly (SHA-256 `e38389faafe9c5324f4eea94eecdab7e109b67e1b272f6291bd4ad27b4b470e4`). Only sampling metadata, the mandatory flag on the existing legal review route and five source hashes changed; drawn primitives, culled tiles, actor tuning and overlap requirements are unchanged. All captures bind this new inventory. The old archive's inventory hash must therefore fail with the current inventory.

All native depth proof remains **1920×1080, 100% UI scale**, through the windowed visual runner. Use these fresh paths; existing evidence is never overwritten.

The exhaustive headless sweep passes all 6,720 samples and 25,260 strict prop-depth comparisons. Equal-depth diagonals retain the start host through the midpoint. On depth-changing diagonals, strict ground-depth order takes precedence: a literal start-host midpoint rule can paint behind-ground bodies in front of props. The numerical conflict and the brief-authorized closest implementation are documented in [feedback2_report.md](feedback2_report.md).

## Proof for the design owner

Run exactly these 20 jobs, then the verifier:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-47
for rr47_board in fire_t1_r6 earth_t3_r7; do
  for rr47_actor in hoarfrost_seer arc_thrall glacial_mirror briar_weaver hollow_mimic slag_mortar gale_herald gloam_stalker frostglass_lancer chainbound_gaoler; do
    python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id rr-47 --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest "/private/tmp/labyrinth_codex/rr47/feedback2-${rr47_board}-${rr47_actor}-result.json" tests/rr46/depth_probe.gd -- --board "$rr47_board" --actor "$rr47_actor" --output "/private/tmp/labyrinth_codex/rr47/feedback2-native/$rr47_board/$rr47_actor" || exit 1
  done
done
python3 tests/rr46/verify_native.py /private/tmp/labyrinth_codex/rr47/feedback2-native --inventory tests/rr46/native_inventory.json --result-file /private/tmp/labyrinth_codex/rr47/feedback2-owner-verification.json
```

Expect 20 passing jobs, `RR46 NATIVE ARCHIVE: PASS`, `errors: []` and 20 translation-normalised `board_origins`. Inspect `*_hollow_mimic_move_3_5_-1_1_f023_frame.png` and its crop/ID maps on both boards: the body remains behind the pillar. Frame 23 is now explicitly sampled and retained. The independent oracle still rejects reversed composition, actor/prop swaps, reversed canvas order, missing/reordered sprites and relative shifts.

No fight-capture code or fight contract changed in this round; no fight rerun is needed. Round-1 fight commands remain available at `21119ff68:tests/rr47/proof_for_design_owner.md`. No inspection fixture command is required by this feedback; the director owns fixtures, Git preflight, contract, commit, review and publication.
