# rr-47 feedback 1 implementation evidence

All feedback-1 edits are uncommitted on `codex/rr-47`, based on the director's round-0 commit `cded9621a`. No Git writes, peer review, windowed runs, full suites, runtime changes or depth-capture changes were performed. The accepted runtime is unchanged.

## 1. Framing diagnosis and verifier correction

The fit comes from `scripts/board_framing.gd::capture`, which freezes an encounter-wide envelope: existing room geometry, each possible enemy type's body envelope at every legal tile, and fixed-pixel health-bar clearance around its head envelope. `origin()` centres those bounds in the available board rectangle. It is not a current-pose or current-HUD-placement measurement.

`tests/rr46/native_cases.gd::export_inventory` reuses one board through all ten rigs. Its navigation content signature does not change for these substitutions because the grid/room coordinate and absent `board_encounter_types` override remain the same. Consequently its room envelope stays fitted to the first rig, Hoarfrost Seer. Each separately launched native job starts a fresh board fitted to its own rig's encounter closure. The renderer/probe uses the same production framing code.

**Production combat framing also depends on the initial encounter roster.** `scripts/run_scene.gd::_board_encounter_types` freezes the initial roster (including reinforcement, summon and death-spawn closure) per room/combat entry and passes it as `board_encounter_types`. `BoardFraming.capture` uses that closure. Changing the encounter can change its initial origin and potentially its fitted tile width; moving, hiding or killing its units does not continuously refit the camera. No production behavior was changed here.

Headless `tests/rr47/framing.gd` exercised 40 fresh production/probe boards (two boards × ten rigs × both actual classes), recorded their body/head/fit bounds and origins, and checked the frozen fit through position, visibility and enemy removal. It also reproduced the inventory's reused-board fit. Output: `/private/tmp/labyrinth_codex/rr47/feedback1-framing.json` and `.log`.

These direct production/probe API measurements use the probe's default fit rectangle, without RunScene's `board_fit_rect` override. In live combat, RunScene supplies the authored hand/header-safe rectangle and keeps `board_view.position` at zero, so the same roster-envelope dependence is visible there; absolute live coordinates can differ from the table. Outside combat, its room-centering offset can compensate the vertical floor position. None of these behaviors changed.

The forty fresh-board measurements use the same available rectangle `[36,8,1848,1064]` and tile width `183.9993019104`. The actual fresh-board origins on both boards include:

| Rig | Production API origin Y | Difference from Seer |
|---|---:|---:|
| Hoarfrost Seer | 225.041259765625 | 0 |
| Glacial Mirror | 229.017547607422 | +3.976287841797 |
| Frostglass Lancer | 230.611755371094 | +5.570495605469 |

For these jobs, the head/HUD envelope determines the fit's top edge: Seer −96.879776 px, Mirror −104.832375 px, Lancer −108.020752 px. The bottom is unchanged, so centering moves the board down by half the top-edge difference. This is the conservative health-bar reservation above the authored head height, not current widget placement.

The Weaver, Herald, Gloam and Mimic failures are only float32 X rounding (ground-coordinate differences up to 0.000122070313 px), not a four-pixel vertical movement. Thus 12 exact-position comparisons failed, but only four jobs had a substantial Y shift.

`tests/rr46/board_coordinates.py` now compares ordered `(id, kind, plane, tie_rank)` tuples exactly, then compares board-local positions. Legacy captures contain enough data to recover tile `(0,0)` using `O = 3 P(1,1) - P(2,1) - P(1,2)`. The verifier records each job's reconstructed `board_origin`, source, float32 uncertainty, inventory origin, translation and maximum relative error in its returned report. `--result-file` saves that report separately, without altering captured metadata or PNGs. The CLI rejects result paths inside the captured archive before reading or writing evidence; a sentinel test proves that capture metadata cannot be overwritten. Values reconstructed from float32 floor centres have small representation error; this is explicitly recorded rather than pretending they are bit-exact production API origins.

The coordinate comparison propagates float32 half-ULP intervals through origin subtraction. It does not use a pixel-sized tolerance or normalize scale/shape. On the real archive, the largest allowed component bounds are 0.00048828125 px in X and 0.000213623046875 px in Y; actual normalized errors are at most 0.000122070313 px. Tests reject relative shifts as small as 0.01 px, scale changes, and changes to the origin anchors themselves. Missing, extra, reordered or changed identity fields still fail. An entirely omitted primitive set fails too; the metadata fixture now includes the complete primitive list and consistent actor composition metadata.

The existing inventory and all bound sources are unchanged; its SHA-256 remains `d5a77f8302c8c2bea4d18801110296759e33a05b9ebeb809006bad49559a4f2e`.

## 2. Fight runner discovery

`tools/visual_probe_runner.py::collect_pngs` discovers absolute paths printed by the probe and recursively scans any announced directories. The fight writes recording frames to `LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT`, outside the runner's isolated `user://` directory, but previously announced only the final still's path. The directory already contains 279 PNGs; discovery returned one.

`tests/rr46/fight_probe.gd` now extracts its existing recording-manifest write into `_write_recording_manifest()` and announces that absolute directory after writing it. No recording clocks, actions, images, filenames, frame cadence or final-still behavior changed. The runner is unchanged. The three-image minimum, both final-still and recording-frame filename requirements, and all global per-image quality checks are retained.

`tests/rr47/fight_output.gd` invokes the actual manifest/announcement helper headlessly. The Python test proves the old final-file-only stdout discovers one PNG and fails the minimum; the actual new helper discovers all three software fixture files and passes the contract. Software fixture images are explicitly not native captures.

The existing native recording exposed a second blocker after discovery: its final still and all recording frames are **1600×900**, with manifest `requested_size=[1920,1080]`, `window_logical_size=[1600,900]`, `ui_scale=1.0`, and `errors=[]`. The parent fix-18 probe already approves this physical-window clamp: exact saved/root logical size, at least 1600×900, 100% UI scale, root viewport readback. The child fight contract and command still demanded 1920×1080.

`tests/rr46/fight_proof_contract.json` now copies that already-approved `frame_size_policy` exactly from `tests/fix18/real_fight_capture_probe_contract.json`. Its two required-image regions enforce the same 1600×900 minimum; the probe itself continues to enforce saved/root logical-size equality and UI scale. The incompatible fight-only `--expect-size 1920x1080` flag was removed from the current command. No camera, window sizing, UI scale, image resize, or capture behavior was changed. **The native depth contract remains 1920×1080.** Tests accept both 1920×1080 and the approved 1600×900 logical window and reject undersized frames.

Read-only replay of the director's 279 existing PNGs passed all global pixel-quality checks before the old exact-1920 requirement failed (`feedback1-existing-fight-validation.log`). After policy alignment, all 279 headers match the saved 1600×900 logical-window manifest and the semantic contract passes (`feedback1-recording-contract.log`); the existing final still and first/last recording frames also pass the runner's full quality and semantic validation (`feedback1-recording-samples.log`). These are existing native images, not new captures.

## 3. Verification

- Focused feedback-1 suite: `python3 tools/run_python_suite.py --shards 4 --pattern 'test_rr47_feedback1.py' --output-dir /private/tmp/labyrinth_codex/rr47/feedback1-complete-final`: **`Ran 8 tests in 39.891s` / `OK`**.
- `RR47 FRAMING DIAGNOSIS: PASS (40 fresh production/probe boards; frozen encounter fit; shared inventory fit; native pixels=false)`.
- `RR47 TRANSLATED ARCHIVE: PASS (board origin recorded; ordered identities and relative geometry preserved)`.
- `RR47 SPRITE SET MUTATIONS: PASS (missing, extra, reordered, kind, plane, rank and omitted set rejected)`.
- `RR47 RELATIVE GEOMETRY MUTATIONS: PASS (0.01px X/Y shifts, anchor shifts, scale and non-finite positions rejected)`.
- `RR47 FIGHT WINDOW POLICY: PASS (1920x1080 and approved 1600x900 logical windows; undersized frames rejected)`.
- `RR47 FIGHT RUNNER DISCOVERY: PASS (old stdout finds 1 PNG; actual directory announcement finds 3; three-image/recording contract passes; software pixels)`.
- Complete existing native archive: `python3 tests/rr46/verify_native.py /private/tmp/labyrinth_codex/rr47/native --inventory tests/rr46/native_inventory.json --result-file /private/tmp/labyrinth_codex/rr47/feedback1-native-verification-final.json`: **`RR46 NATIVE ARCHIVE: PASS`**, exit 0; `jobs=20`, `after_frames=6600`, `errors=[]`, 20 `board_origins`. Every retained ID image was independently reconstructed and all existing clock, sampling, coverage, cost and source-binding checks still ran. JSON and console log are under the stated output prefix.

The native archive was reused exactly as requested; no new captures are needed for the verifier correction. Current two-command director handoff: `tests/rr47/proof_for_design_owner.md`.

Additional focused checks:

- Existing archive-negative and independent-image guards: `Ran 2 tests in 3.497s` / `OK` (`feedback1-existing-guards.log`); the early-absence, endpoint-only, zero-overlap, forged-exemption, empty-frame, budget and ID-calibration negative controls remain effective.
- Isolation audit: `ISOLATION AUDIT: 240 modules`, exit 0 (`feedback1-audit.log`). New `test_rr47_feedback1: []` writes only unique test temporary directories and isolated Godot homes.
- `RR47 FEEDBACK 1 SIDECARS: PASS`; `RR47 FEEDBACK 1 SOURCE BINDINGS: PASS (41 unchanged source hashes)`; `RR47 FEEDBACK 1 WHITESPACE: PASS` (`feedback1-integrity.log`). New GDScript UID sidecars were generated through the required Godot runner.
- Earlier focused runs: `Ran 5 tests in 54.462s` / `OK` and `Ran 6 tests in 66.452s` / `OK`. The final eight-test run adds float32 zero/subnormal interval and approved-window-policy coverage. The first eight-test attempt exposed sampling aliasing in the synthetic one-pixel-stripe fixture at 1600×900; broad two-tone software bands removed that test-fixture alias without changing validator assertions.
- Final coordinate-specific checks: `Ran 5 tests in 0.407s` / `OK` (`feedback1-coordinate-final.log`).
- `RR47 EXISTING FIGHT CONTRACT: PASS (279 recorded PNGs; all match [1600, 900] logical window at 100% UI scale; no new capture)`.
- `RR47 NATIVE FIGHT WITNESSES: PASS (existing final still, first recording frame, last recording frame; full runner quality and semantic contract; no new capture)`.

## Files changed

- `tests/rr46/verify_native.py`: strict ordered identity/relative-coordinate check and per-job origin result output.
- `tests/rr46/board_coordinates.py`: independent floor-lattice origin reconstruction and float32 interval propagation.
- `tests/rr46/archive_fixture.py`: complete primitive/composition metadata in synthetic archive fixtures.
- `tests/rr46/fight_probe.gd`: actual recording-directory announcement.
- `tests/rr46/fight_proof_contract.json`: alignment with the parent probe's already-approved logical-window policy.
- `tests/rr47/framing.gd` and `.uid`, `fight_output.gd` and `.uid`: headless production-framing and actual output-protocol probes.
- `tests/test_rr47_feedback1.py`: focused translation, identity, geometry and discovery regressions/mutations.
- `tools/python_suite_resources.json`: new module's temp-only resource entry.
- `tests/rr47/proof_for_design_owner.md`, this report: current commands/evidence.

## TODO_DESIGN placeholders and chosen defaults

No new TODO_DESIGN placeholders or player-visible defaults. Proof-only named fields: 300-second headless subprocess deadline; translation fixture `(17.25,-23.5)`; 0.01-pixel shift / 1.01 scale mutation fixtures; synthetic PNG luma `(20,230)`; inherited proof HP 10. The software image size 1920×1080 is the required proof resolution. IEEE float32 precision constants are representation facts, not tuning.

## Open proof

The director re-runs the verifier over the existing archive and the fight command with fresh `feedback1-fight` output paths. A fresh windowed fight-runner exit 0 was not observed by the worker because the sandbox has no macOS window-server access. The software discovery/contract regression and existing native recording witnesses pass. No new player-visible values were selected; the minimum size and UI-scale policy come from the approved parent probe. Commit and review remain the director's.
