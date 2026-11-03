# rr-46 feedback 2 — proof-only correction

Base: `cbd57d80230eb5244d31d03441cb225525d7f151`. No runtime, authored asset, accepted death-clock guard or accepted occupant-sort guard changed. All work is uncommitted.

## 1. Independent expected painting

The shared retained-renderer reference pass was removed. `paint_board.gd` now extracts the actor alone, its body-only mask, and one identified floor/wall/prop primitive at a time. Occluder passes do not create retained scene layers or call a production tile-order helper. Shadows remain in the composite inputs but do not count as sprite overlap; terrain health bars do not count either.

`paint_composite.gd` sorts these isolated inputs by displayed ground Y, ground X and fixed same-origin primitive ranks, then performs source-over composition itself. No `_sync_scene_render_layers`, `desired_tiles`, `_tile_draws_before` or observed production painter order decides the expected frame. Same-origin ranks preserve floor, scene-prop, grid-prop, terrain, actor order. Native calibration with hidden 4×4 color fixtures selects the framebuffer's premultiplied/straight and encoded/linear alpha protocol; failure to match a supported protocol fails the capture rather than guessing. Eight primitive slots batch independent render passes.

Each capture retains the independent primitive PNGs and their ground positions, plus a composition manifest. The Python archive verifier checks the declared composition order independently from that metadata and compares saved actual/composite pixels under the saved body mask.

Negative controls cover reversed composition and swapping one actor/prop pair. Temporary-source mutations reverse the compositor, swap its actor/prop pair, and insert `desired_tiles.reverse()` into a temporary copy of the runtime board. All three fail the paint guard. The production-order check observes actual retained canvas child order against an independently computed ground Y/X condition, not the renderer's cached order array. No working-tree runtime file is mutated.

## 2. Authored dissolve endpoint

Empty actors are permitted only when normalized phase reaches the end of the authored clip plus dissolve timeline. This comes from protected authored timing in the independent inventory and does not inspect the frame's pixels. Gaoler at phase 0.62 is explicitly rejected even when production, expected and actor images are all blank. A nonempty actor mask at the completed endpoint is also rejected.

The verifier independently derives the endpoint from each rig's timing, rejects forged early `terminal_absence`, and checks that recorded actor-pixel counts agree with saved body-mask pixels.

## 3. Required overlap and justified exceptions

The generated, source-hash-bound `native_inventory.json` defines legal routes, rig frame counts, authored timing and applicability for every board/rig/class. Current boards require all 2,160 front/behind classes across 360 board/rig jobs. There are zero structural exemptions in the current matrix.

The only allowed exemption reasons are `no_kind_on_board`, `no_legal_ground_side`, and `no_projected_bounds_on_side`, established geometrically by the inventory generator. Reports must exactly match that trusted inventory; zero observed pixels cannot invent an exemption. A synthetic board without walls/props tests the no-kind reasoning.

Capture jobs first sample mandatory facings, retreat and death. They then search additional legal routes until every required class has body/occluder sprite-alpha overlap. There are 105,840 legal candidate cases across the full matrix; these are search candidates, not a claim of captured native evidence. If exhaustive search cannot cover a required class, the job fails. The archive verifier independently fails any board/rig with zero required overlap and rejects forged exemption reasons.

## 4. Complete route/frame evidence

Every selected route must contain exactly its expected frame indices and phases from the independent per-rig contract, including the complete death. The archive checker validates each route/direction, mandatory route sets, phase values, frame-index completeness and body presence. Endpoint-only fixtures fail.

Every sample now saves a nonempty, unique full-resolution `frame_file`, including all intermediate samples. The CLI opens every full frame and requires 1920×1080, rather than skipping empty paths. First and last frames therefore have the same enforced full-resolution evidence as every other sample. Empty frame paths and incorrect saved-frame dimensions fail dedicated negative controls.

## 5. Unused state

Removed `proof_actor` and its assignment. No retained reference mode remains.

## Verification observed

All logs below are under `/private/tmp/labyrinth_codex/rr46/feedback2/`.

- `focused.log`: `Ran 23 tests in 182.252s` / `OK`. This is the rr46-only Python pattern, including all ten live family-preservation modules. The 2,558 protected files remain byte-identical.
- `registration-guards.log`: `Ran 60 tests in 24.959s` / `OK` (registration audit and strict program-suite runner guards).
- `registration.log`: `TEST REGISTRATION AUDIT: PASS (875 scripts; full suite=511, quarantined=29, windowed probe=335)`.
- `archive-guards.log`: `Ran 2 tests in 1.146s` / `OK`; `RR46 ARCHIVE NEGATIVES: PASS (zero overlap; early absence; endpoint-only; empty frame; forged exemption)`.
- `new-guards.log`: painter mutation controls passed. The first archive attempt in that log correctly rejected a stale inventory because it started before regeneration completed; it was rerun after regeneration (`archive-guards.log` and final focused run).
- `paint-controls-final.log`: `RR46 PAINTED ORACLE: PASS (independent primitive composition; reverse/pair mutations; authored absence; Retina crops)`.
- Final focused run also reports `RR46 PAINTER MUTATIONS: PASS (reversed composite; actor/prop swap; reversed production canvas order)`.
- `inventory-sealed.log`: `RR46 NATIVE CASE INVENTORY: 36 boards; 360 deaths; 360 resolver retreats; 105840 legal candidate cases; 2160 required / 0 justified class exemptions`.
- `native-parser-final.log`: direct Godot `--check-only` of the final probe exited 0. No editor scan was used as parser proof.
- `uids.log`: `RR46 UID SIDECARS: PASS (2 new helper sidecars)`.
- `isolation.log`: 238-module audit passed; the focused run separately audited 11 modules. New helper code only reads source inputs or writes per-test temporary directories, so the existing resource declarations remain valid.
- A nonrequired `py_compile` support command was blocked by the global bytecode-cache path: `PermissionError: [Errno 1] Operation not permitted: '/Users/borgerding/Library/Caches/com.apple.python/Users/borgerding/workspace/Labyrinth.worktrees/rr-46'`. A read-only AST parse of the three Python files passed, followed by the successful actual focused tests. No escalation was attempted.

Full Godot and Python suites were not run this round, as directed. Runtime files did not change.

## Native proof for the director

No windowed capture was attempted. Hardware alpha calibration, actual primitive comparison and achieved overlap coverage are still pending native execution and inspection. A conservative required class with no observed overlap fails; it is not auto-exempted. The exact fire Slag command, full board/rig batch, inventory regeneration command and archive verifier command are in `proof_for_design_owner.md`, using fresh `feedback2-native` paths.

## Chosen proof defaults and design placeholders

New debugging defaults: eight primitive slots, one-tile conservative motion-bound padding, half-tile conservative primitive-bound padding, a 1e-9 phase-comparison epsilon, and 4×4 native calibration colors (background RGBA 0.25/0.5/0.75/1, red 1/0/0/0.5, blue 0/0/1/0.25). Existing 1920×1080, 100% scale, two settled frames, proof HP and one-byte paint tolerance are retained. Color-space transfer coefficients are the standard sRGB transfer function. No player-facing value was chosen.

No new `TODO_DESIGN`. Existing `TODO_DESIGN_SEER_SIX_STEP_GAIT` remains unchanged.

## Files changed

- `tests/rr46/archive_fixture.py`
- `tests/rr46/depth_probe.gd`
- `tests/rr46/feedback2_report.md`
- `tests/rr46/native_cases.gd`
- `tests/rr46/native_inventory.json`
- `tests/rr46/paint_board.gd`
- `tests/rr46/paint_checks.gd`
- `tests/rr46/paint_checks_test.gd`
- `tests/rr46/paint_composite.gd`
- `tests/rr46/paint_composite.gd.uid`
- `tests/rr46/paint_primitives.gd`
- `tests/rr46/paint_primitives.gd.uid`
- `tests/rr46/proof_for_design_owner.md`
- `tests/rr46/verify_native.py`
- `tests/test_rr46_playback.py`
