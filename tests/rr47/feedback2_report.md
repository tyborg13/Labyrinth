# rr-47 feedback 2 implementation and proof

Working from `21119ff68`. All edits remain uncommitted. No Git metadata writes, peer review, windowed run or full suite was attempted. The director owns contract/preflight/commit/review/publication.

## 1. Actual ground-depth hosting

`board_depth.gd` resolves the actual authored ground point along the movement segment. It never rounds inverse-lattice coordinates independently. Equal-depth diagonals keep the start host through the midpoint, then use the end host. Other movement uses the retained paint slot immediately behind the actual ground point, found by binary search over the existing cached tile order and its already-validated tile-centre dictionary. The search does not repeatedly revalidate layout. This places a body between ground rows after every prop in the preceding row and before every prop in the next row. Arrivals retain their destination host; static/reduced-motion input paths and footprint conventions remain supported.

The reported Mimic `(3,5) → (2,6)` case is covered on both boards at phases 0.49, 0.50 and 0.51. Frame 23/48 at phase 0.5 retains `(3,5)` and stays behind pillar `(3,6)`. The same probe with only the helper restored verbatim from `21119ff68` fails on both boards, identifying the off-segment `(3,6)` host and incorrect pillar order.

`tests/rr47/diagonal_check.gd` exhaustively covers every legal diagonal on both proof boards for all ten rigs: **2,240 actor/route combinations, 6,720 samples and 25,260 strict prop-ground-Y comparisons, zero errors**. It observes actual retained canvas child order, retained occupant/host existence, and parity of root-only sampling with the former full-channel sampler. It does not limit assertions to the reported route or overlapping bounds.

The oracle in `depth_sweep.gd` independently walks tile ground positions linearly; production uses a binary search. Expectations come directly from ground Y/X, with no inverse lattice, axis rounding, production comparator or production host helper. `depth_check.gd` uses the same independent oracle, includes phase 0.50 in retained-cache checks and preserves the Seer's authored non-linear travel assertion.

### Necessary tie-rule exception

The literal start-tile tie rule cannot coexist with strict ground-Y prop order on every depth-changing diagonal. The supplied reproducer adapted to Mimic `(3,2) → (2,1)` establishes this on both boards: at phase 0.5 the body is at ground Y **409.0406**, behind pillar `(2,3)` at **455.0404**, but the start host `(3,2)` paints after that pillar. The intermediate literal-tie sweep found **216 strict prop-order failures, all at phase 0.50; zero at 0.49 or 0.51**.

The original unit brief explicitly authorizes the closest implementation when a requirement is impossible. Ground-depth order therefore takes precedence on depth-changing diagonals; start-host midpoint ties remain on equal-depth diagonals, including the reviewer's exact case. This exception is documented beside the runtime branch. No strict prop-order assertion was removed or relaxed. A clarification was offered asynchronously; in the absence of a reply, this follows the brief's impossibility rule and its primary ground-depth requirement.

## 2. Root-only sampling and measured cost

Depth sampling evaluates only root `forward_px` tracks, rather than all joint/channel tracks through `channels_at`. It preserves phase clamping, fractional step scaling and last-track-wins behavior. Protected motion data, lift, timing and artwork are unchanged.

`depth_cost.gd` measures real `set_combat_state` submissions. Counters are injected only into a temporary staged helper, never production. Ten rigs, 48 measured submissions each, 8 warmups each: **480 submissions and 2,400 position lookups per version**. The before helper is loaded verbatim from `21119ff68`. Timing is reported, never asserted as a correctness threshold.

Final observed result (`feedback2-cached-focused.log`, after the cached-centre optimization and named proof defaults):

- Before: **0.4367729167 ms** of position lookup per submission.
- After: **0.1934854167 ms** (**55.7% reduction**).
- Whole headless submission: before 5.0252604167 ms; after 5.2939291667 ms (+5.3% in this run). These single-pass aggregate timings are shared-host-sensitive; no whole-submission speedup or renderer/frame-time improvement is claimed.

The earlier root-only draft measured 0.3687083333 → 0.2254000000 ms. The values above measure the final host implementation and are the acceptance evidence.

## 3. Unused constant

Removed the unused `ALPHA_MODES` from `tests/rr46/paint_composite.gd`. Composition behavior and reverse/pair mutations are unchanged.

## Native proof contract and commands

Every move/retreat keeps stride 2 and additionally samples every source frame within one frame of its midpoint, including Mimic frame 23/48. Every death frame remains required. Midpoint neighbours also require full frames, crops and both ownership maps. Existing calibration, endpoints, failure evidence, cadence, budgets and overlap requirements remain enforced.

The reviewer route `(3,5) → (2,6)` is mandatory on both boards for every rig. Python independently requires matching indices, retention cadence and the legal witness. The complete synthetic archive fixture uses this contract. Omitting midpoint frames fails verification; GDScript/Python sample lists agree for 120 move lengths.

The regenerated inventory changes only sampling metadata, the existing review route's mandatory flag and five source hashes. Primitive geometry, culled tiles, overlap requirements and actor values are unchanged. Rest provenance updates only the exact helper hash; rest byte pins and mutation checks remain intact.

[proof_for_design_owner.md](proof_for_design_owner.md) lists the exact **20 native jobs and verifier command**. Both boards and all ten rigs share the changed helper and sampling. Fresh captures go to `/private/tmp/labyrinth_codex/rr47/feedback2-native/`; older evidence is untouched. Native proof remains 1920×1080 at 100% UI scale. No fight capture/contract changes or fight rerun are needed.

## Checks and result lines

All output paths below are under `/private/tmp/labyrinth_codex/rr47/`.

- `python3 -m unittest tests.test_rr47_feedback2` → `feedback2-cached-focused.log`: **`Ran 4 tests in 128.703s` / `OK`**, exit 0.
- `RR47 DIAGONAL DEPTH: PASS (2 boards; 2240 routes; 6720 samples; 25260 prop comparisons; native pixels=false)`.
- `RR47 MIDPOINT SAMPLING: PASS (GDScript/Python agree for 120 lengths; frame 23/48 required)`.
- `RR47 NATIVE MIDPOINT NEGATIVE: PASS (omitted midpoint fails; review route mandatory on both boards)`.
- `RR47 REVIEW REGRESSION: PASS (21119ff68 rejected on both boards at Mimic frame 23/48)`.
- The earlier 20 affected rr46/rr47 checks, invoked by `python3 /private/tmp/labyrinth_codex/rr47/feedback2_existing.py`, reported **`Ran 20 tests in 463.568s` / `OK`** in `feedback2-existing.log`. Its adapter uses the rr-47 Godot runner for the existing rr46 tests. This includes reverse/pair/production-canvas mutations, exact ID reconstruction, source preservation, archive set/geometry mutations, framing and fight discovery.
- The final runtime-dependent subset, run after the last runtime change by `python3 /private/tmp/labyrinth_codex/rr47/feedback2_final_existing.py`, reported **`Ran 4 tests in 165.890s` / `OK`**, exit 0 (`feedback2-cached-existing.log`). Its exact lines include `RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 111610 old-routing failures; 30 retreat routes; native pixels=false)`, `RR46 ROUTING MUTATIONS: PASS (death opt-in and occupant sorting rejected)` and `RR47 RETAINED ROUTING: PASS (6402 samples; 0 missing callbacks; 562 pillar-front samples; native pixels=false)`.
- Source-provenance negatives: `feedback2-provenance.log`: **`Ran 2 tests in 0.229s` / `OK`**, exit 0.
- Inventory regeneration via the task runner: `feedback2-inventory-cached.log`: **`RR46 NATIVE CASE INVENTORY: 2 boards; 20 jobs; 20 deaths; stride 2 move/retreat plus every midpoint neighbour, stride 1 death; res://tests/rr46/native_inventory.json`**, exit 0.
- `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rr47/feedback2-audit`: **`ISOLATION AUDIT: 241 modules`**, audit only. New module declares `[]`; stage/mutation/output writes are per-test temporary, engine HOME is runner-isolated.
- Final inventory SHA-256: `e38389faafe9c5324f4eea94eecdab7e109b67e1b272f6291bd4ad27b4b470e4`. `RR47 FEEDBACK2 INTEGRITY: PASS (41 bound sources; unchanged geometry/requirements/actors; rest provenance; UID sidecars)`; final whitespace check exit 0.
- Both new GDScript UID sidecars were generated through the task Godot runner: **`RR47 FEEDBACK2 SIDECARS: PASS`**.
- Python compile passed using task-local temporary `PYTHONPYCACHEPREFIX`; the initial macOS default cache directory was unwritable.

### Intermediate failures preserved

The initial new-module run had two failures: the genuine strict ground-order defect in endpoint-only selection, and a profiling-helper parse error (`Depth.call` on a class). The profiling call was corrected to use a typed Script value. The endpoint-only and literal-midpoint variants were superseded by the documented ground-order implementation; their logs remain.

An intermediate six-check run crossed a source-edit boundary: its staged old tie helper and live updated sweep disagreed at midpoint frames, causing the routing mutation test to fail before reaching its expected diagnostic. No mutation assertion was rewritten. The final isolated/stable subset passed after all runtime changes, including the cached-centre optimization. No pre-existing master failure was suppressed.

## Files changed

- Runtime: `scripts/maquette_cutout_runtime/board_depth.gd`.
- Existing proof/helpers: `tests/rr46/{depth_sweep.gd,depth_check.gd,id_pass.gd,native_cases.gd,native_inventory.json,depth_probe.gd,paint_composite.gd,paint_checks_test.gd,verify_native.py,archive_fixture.py,rest_binding_changes.json}`.
- New probes: `tests/rr47/{diagonal_check.gd,depth_cost.gd}` with UID sidecars.
- New tests: `tests/test_rr47_feedback2.py`; registration in `tools/python_suite_resources.json`.
- Handoff: this report and `tests/rr47/proof_for_design_owner.md`.

## TODO_DESIGN and chosen defaults

No unresolved `TODO_DESIGN` values. The necessary tie-rule exception is explained above, rather than silently selecting a different rule.

Non-player-visible proof defaults: `GROUND_ROUNDOFF_PIXELS=0.001`, proof actor HP 10 (existing fixture convention), `WARMUP_SUBMISSIONS=8`, `MEASURED_SUBMISSIONS=48`, `MAXIMUM_SAMPLING_TEST_LENGTH=120` (lengths 1–120) and `MINIMUM_DIAGONAL_ROUTE_CASES=1000` (test lower bound; actual 2,240). The existing runtime `POSITION_EPSILON=0.000001` absorbs projection/arrival roundoff. Requested phases, review route and equal-depth tie behavior come from the director. No assets, tuning, audio, copy, balance or gameplay data changed.

## Open proof

Fresh native captures and their verifier result remain for the director. The sandbox has no macOS window-server access; no windowed command was attempted and no fresh native success is claimed. No full suites were run this round.
