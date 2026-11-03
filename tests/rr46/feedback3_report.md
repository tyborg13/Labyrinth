# rr-46 feedback 3 implementation evidence

Runtime, authored inputs, accepted death-clock guards and accepted occupant-sort guards are unchanged. All changes are uncommitted proof/test/documentation files on `codex/rr-46` (starting HEAD `f4eb556b0`). No peer review, fixture launch or windowed run was attempted.

## 1. Ownership rather than paint colour

The production ID board uses production's retained tile creation/order, floor callbacks and unit routing. Each floor/prop/actor callback paints a cached, isolated sprite silhouette with its own opaque ID. The material is unshaded, sampling is nearest, and torch light, contact shading, shadows, HUD and post-effects do not enter ownership. There is no unlit-colour-versus-lit-colour assertion. Colour frames/crops are evidence only.

The independent expected map uses those same isolated inputs and visible/culled primitive set, sorted independently by lower floor plane, then displayed ground Y/X and same-origin ranks. Ground Y still determines front/behind coverage labels for all classes. Production never supplies expected painter order. The Python verifier independently reconstructs retained expected ID maps from the saved primitive IDs and actor alpha mask, and verifies the canonical drawn/culled set. Reversed composition, actor/prop swap and reversed production painter mutations remain in the focused tests. A fixture with two matching but incorrectly composed ID maps fails independent primitive reconstruction.

Each native job begins with an actor-alone production-layer ID calibration, explicitly omitting all occluders in both ID passes. It requires actor paint, zero overlaps and zero ID mismatches; diagnostics are saved and the sweep stops if it fails.

## 2. What the supplied native clock evidence actually shows

Read `/private/tmp/labyrinth_codex/rr46/feedback2-native/fire_t1_r6/slag_mortar/findings.json`, the supplied log and the referenced full-frame/crop images. The nine unique early-empty **after** samples are `move_2_1_-1_1`, frames 42–50 (each also has a legacy/before row). They are not death rows. All 63 death rows are present. Death frame 61, phase 0.983870967741935, has 14,997 actor-mask pixels; only frame 62, phase 1, has zero. This evidence does not establish a production death cutoff, and no runtime change is warranted from it.

The old isolated actor depended on tile routing and checked only the source rectangle. The replacement draws the isolated actor directly on its canvas and includes the full expanded dissolve effect rectangle. The production ID pass still uses the real production routing, so a genuine missing actor there remains detectable. Round 2 also omitted RunScene's `CutoutContext.apply_to_presentation`: it dissolved an idle pose. The replacement calls that exact boundary and a headless guard checks the resulting death clip/phase for all ten rigs, including Gaoler 0.62.

`death_progress` is already normalized across the whole parity-scaled sequence. Multiplying it by an unscaled authored total to test completion does not shift the endpoint: completion is still phase 1. The proof records both timelines, clip/dissolve phases and production frame-schedule time. No absence exemption is inferred from rendered pixels.

| Rig | Authored clip + extra dissolve (s) | Duration scale | Playback clip + extra dissolve (s) |
|---|---:|---:|---:|
| arc_thrall | 1.500000 + 0.000000 | 0.690666667 | 1.036000 + 0.000000 |
| briar_weaver | 1.500000 + 1.036000 | 0.408517350 | 0.612776 + 0.423224 |
| chainbound_gaoler | 1.600000 + 1.036000 | 0.393019727 | 0.628832 + 0.407168 |
| frostglass_lancer | 1.600000 + 1.036000 | 0.393019727 | 0.628832 + 0.407168 |
| gale_herald | 1.500000 + 1.036000 | 0.408517350 | 0.612776 + 0.423224 |
| glacial_mirror | 1.500000 + 0.000000 | 0.690666667 | 1.036000 + 0.000000 |
| gloam_stalker | 1.400000 + 1.036000 | 0.425287356 | 0.595402 + 0.440598 |
| hoarfrost_seer | 1.700000 + 0.000000 | 0.609411765 | 1.036000 + 0.000000 |
| hollow_mimic | 1.400000 + 1.036000 | 0.425287356 | 0.595402 + 0.440598 |
| slag_mortar | 1.500000 + 1.036000 | 0.408517350 | 0.612776 + 0.423224 |

All playback totals above are 1.036000 s. The blocking production clock has 63 frames, nominal period 0.016444444 s, rounded period 16,444 μs; final phase 1 is submitted at 1.019528 s and the hold ends at 1.035972 s. These are presentation-clock values; combat speed and the existing enemy-action multiplier apply through the accepted production pacing clocks. Focused mixed-death tests cover all three speeds in both blocking and overlapping contexts.

## 3. Reduced matrix, coverage and cost

Exactly two boards × ten rigs: `fire_t1_r6`, `earth_t3_r7`. Both currently have 49 visible floor primitives, four pillar props and 32 culled boundary-wall tiles. Earth is the allowed second debug board selection, using the other biome's tier-3/revision-7 prop sprites. The mandatory diagonal `(3,3) → (2,4)` targets a real rear-pillar/body intersection at a common projected X; it does not count a torch halo as a prop. Eight directions, the actual resolver retreat and a complete death also remain mandatory. Extra legal routes target any unproven required class, within a 16-route/job cap. Missing sprite-alpha overlap fails.

**The requested board with real visible `wall_front` overlap does not exist under current production rules.** `OUTER_WALL_RENDERING_ENABLED=false` and `_should_render_tile` cull all boundary-wall tiles. Interior wall cells render as pillar props. The inventory lists the exact culled tile coordinates and `production_culls_kind` reasons; the verifier accepts those listed reasons only. No runtime wall visibility changes were made. The 20 jobs require 80 floor/prop classes and explicitly exempt 40 hidden-wall classes. Actual native overlap coverage is pending.

Every second source move/retreat frame plus the final endpoint is required; every death frame is required. A mandatory job contains 313–343 samples, depending on the rig. Full 1920×1080 colour frames are retained at first/last/failing samples and calibration. Colour crops, both ID maps and actor masks are retained for failures, every tenth passing sample and endpoints. Static primitive IDs are saved once/job. Empty required full-frame paths, endpoint-only death archives, incorrect phases/directions, absent retained evidence and wrong clock values fail the verifier.

Native wall time and disk budgets are enforced at 300 s / 250,000,000 bytes per job; two MB are reserved for the report. `RR46 NATIVE JOB` prints actual seconds/bytes and the verifier measures disk use. **Replacement native cost has not been measured** because this sandbox cannot run a windowed renderer. The director's obsolete run measured 956 s / approximately 1.8 GB / 37,332 files. No headless number is presented as native capture cost.

## 4. Director commands

Current exact first-job, remaining-19-job, verification, fixture and fight-recording commands are in `proof_for_design_owner.md`. The existing real-fight probe records to `/private/tmp/labyrinth_codex/rr46/feedback3-fight-1`; JSON labels ordinary combat and staged retreats/death separately. The new ID archive root is `/private/tmp/labyrinth_codex/rr46/feedback3-native`.

## Validation

All outputs are under `/private/tmp/labyrinth_codex/rr46/feedback3/`.

- `python3 tools/run_python_suite.py --shards 4 --pattern 'test_rr46*.py' --output-dir /private/tmp/labyrinth_codex/rr46/feedback3/focused`: **`Ran 23 tests in 174.505s` / `OK`** (`focused.log`). Includes protected reference sets, rr-40 headless geometry, 39 timing rows, gait gates, 173,718 depth frames, mixed clocks and routing/painter mutations.
- After archive/budget changes, playback module: `python3 tools/run_python_suite.py --shards 4 --pattern 'test_rr46_playback.py' --output-dir /private/tmp/labyrinth_codex/rr46/feedback3/final-playback`: **`Ran 13 tests in 166.494s` / `OK`** (`final-playback.log`).
- After the final legal witness adjustment, the four affected `PlaybackTests` methods (`test_native_archive_requires_complete_painted_coverage`, `test_native_image_guard_requires_full_frames_and_independent_order`, `test_painted_oracle_and_native_case_inventory`, `test_independent_painter_mutations_are_rejected`): **`Ran 4 tests in 26.959s` / `OK`** (`final-guards.log`). Results include **`RR46 PAINTER MUTATIONS: PASS (reversed composite; actor/prop swap; reversed production canvas order)`**, **`RR46 ARCHIVE NEGATIVES: PASS (zero overlap; early absence; endpoint-only; empty frame; forged exemption; budget; ID calibration)`** and **`RR46 PAINTED ORACLE: PASS (independent primitive composition; reverse/pair mutations; authored absence; Retina crops)`**.
- `python3 -m unittest tests.test_test_registration_audit tests.test_program_suite_runner`: **`Ran 60 tests in 27.575s` / `OK`** (`registration-guards.log`).
- `python3 tools/test_registration_audit.py`: **`TEST REGISTRATION AUDIT: PASS (875 scripts; full suite=511, quarantined=29, windowed probe=335)`** (`registration-final.log`).
- `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rr46/feedback3/isolation`: **`ISOLATION AUDIT: 238 modules`**, exit 0 (`isolation.log`). No new discoverable Python test module; existing `test_rr46_playback: []` remains correct after auditing temp-only writes.
- Named Godot runner `--headless --path . --script tests/rr46/depth_probe.gd --check-only`: exit 0 (`parser-final.log`). This is a parser check, with no editor scan or renderer claim.
- Named Godot runner `--headless --path . --script tests/rr46/depth_probe.gd -- --list-only --output res://tests/rr46/native_inventory.json`: **`RR46 NATIVE CASE INVENTORY: 2 boards; 20 jobs; 20 deaths; stride 2 move/retreat, stride 1 death`** (`inventory-final.log`). Independent load validates all 37 source hashes, both legal mandatory rear-pillar witnesses and the exact 20-job scope.
- `RR46 UID SIDECARS: PASS (2 new proof helpers)` (`uids.log`).
- `git diff --check`: exit 0. Diff for `scripts/`, `assets/`, `spec/`, `tools/` and the accepted death-clock/occupant-sort guard files is empty.

An initial targeted unittest command named a nonexistent method and reported `AttributeError`; the corrected archive pair passed (`Ran 2 tests in 0.654s / OK`) and the final four guards above pass. The inventory audit also caught the first proposed witness ending on a pillar; the legal `(3,3) → (2,4)` route is now checked as mandatory on both boards. Godot emitted the existing sandbox CA-certificate warning; all reported passing runner exits were observed as 0.

Full suites are intentionally not run this round: no runtime file changed. No native replacement capture or native budget success is claimed.

## Files changed

- `depth_probe.gd`: reduced ID sweep, calibration, production death context, sampling/retention, clocks, budget reporting.
- `id_pass.gd`, `id_pass.gd.uid`: flat ownership encoding and frame/budget constants.
- `native_archive.gd`, `native_archive.gd.uid`: bounded evidence writes and actual-cost reporting.
- `native_cases.gd`, `native_inventory.json`: 20-job contract, targeted witness, canonical drawn/culled sets and clock inputs.
- `paint_board.gd`, `paint_primitives.gd`: ID callbacks, isolated actor/occluders and production culling.
- `paint_composite.gd`, `paint_checks.gd`: independent floor/world depth and exact ID comparison.
- `paint_checks_test.gd`: ID invariance, scaled death phases, budget guard and retained mutation checks.
- `verify_native.py`, `archive_fixture.py`, `../test_rr46_playback.py`: new archive rules and positive/negative fixtures.
- `depth_proof_contract.json`, `proof_for_design_owner.md`, `feedback3_report.md`: evidence contract, commands and this report.

## Chosen defaults

All are proof-only: eight static primitive slots; at most 16 routes/job; the `(3,3) → (2,4)` witness and Earth board choice above; ID colour multiplier 7,919; two MB report reserve; 1,024-byte report-size accounting tolerance; runner timeout 330 s. Existing proof-only settle count 2 and actor HP 10 remain. The director supplied the 1920×1080/UI scale, sampling cadence and 300 s / 250 MB budgets.

## TODO_DESIGN / open issues

No new design placeholder. Existing `TODO_DESIGN_SEER_SIX_STEP_GAIT` remains: the protected Seer data authors four shuffles. Wall overlap is impossible under the current production visibility rule; it is listed explicitly rather than manufactured. The director must run the native 20-job matrix and real fight to establish actual painted coverage, runtime cost and visual acceptance.
