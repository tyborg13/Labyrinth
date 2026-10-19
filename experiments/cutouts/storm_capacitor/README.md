# rr-17 — Storm Capacitor

Implemented in `codex/rr-17`, with all changes uncommitted. The design owner
owns commit, review, inspection and publication. No windowed command, peer
review or art generation was run. Full Godot/Python suites are deferred to the
director as the unit brief specifically requires.

The complete inventory is `rr17_files.json`; the case is `mq5/`, production is
`assets/units/storm_capacitor_cutout/`.

1. **Pieces.** The supplied cap mask partitions the existing production
   painting exactly into column and cap. The protected vent is composited below
   the column's own pixels, then the cap is drawn above it. Both views use the
   same paint, never reflection. The cap pivots at (131, 75). Offline rest
   reconstruction differs by **0 pixels**, including transparent RGBA. Every
   protected file is copied byte for byte and bound by SHA-256. All three
   referenced images were inspected.
2. **Channels.** Director rows compile without editing their values. Body
   forward, cap lift/lean and integer column glow are applied through the
   rr-05 bone sampler and stepped pixel presentation. Translation units remain
   source painting pixels as the protected `_doc` specifies. Five column
   textures include the hidden fill; only pixels satisfying B−R > 20 and
   B−G > 40 are recoloured. Alpha and all other pixels remain exact. Hold
   interpolation retains the previous value until the ending key, including
   equality. Angles retain the float64 half-step decision before 1.5° snapping.
3. **Production.** Board, pre-battle, inspection and turn portrait paths use
   the shared renderer. Exact selectors map `charge:gain_charge` and
   `discharge:chain_discharge`; `reset_charge` applies its existing snapshot
   without replay. The first charge/chain effect and sound begin at exact
   authored contacts. Existing per-hop VFX, sound, snapshot and popup order are
   retained; rules, saves, analytics, tuning and source audio remain unchanged.
   Hit routes to the hit clip. Death finishes its 1.4 s motion before the
   existing 28 × 0.037 s dissolve; reduced motion retains the same rig. Board
   actors use the existing LiveActor slot/slot-count idle seed distribution,
   and hit recovery restores the seed. Paint/rest/density records and two new
   shadow cache keys are registered. All 66 existing shadow entries are exact.
4. **Gates.** Independent signed-bone checks cover keys, midpoints and contacts
   (328 authored poses). All 696 sequential 60 Hz front/rear samples pass exact
   glow, rest, source provenance, snapped transforms, strict detached 1–8 px
   component and held-frame shimmer gates. Held shimmer residual is zero.
   The dark-slab gate exempts only the protected vent; all other pixels require
   approved painting/table provenance. Mutations cover signs, bones, omitted
   contacts/actions, frozen glow/sprites, detached sizes 1–8, dark slabs,
   frozen progression, early VFX and native/tie behavior.

The production capture uses actual resolver steps and RunScene callbacks,
including four chain hops followed by reset; it never seeks an action phase.
It observed **1011 headless callback frames**: idle 120, charge 156,
discharge 167, hit 80, death 488. Charge/discharge sounds and VFX first appear
at phase 0.5/0.45. This is logic evidence, **not native renderer evidence**.

## Open design conflict

`TODO_DESIGN_hit_changing_frames` is recorded in the case, production
integration data and the independent gate constant. The protected hit is all
hold keys: it has **four transitions and four unique presented states**.
The brief requires six changing frames per action. The implementation keeps
those tracks exact and leaves the strict production gate failing; no motion,
threshold or assertion was altered to manufacture a pass. Charge has seven
unique pixel states, discharge twelve, death twenty-nine per facing offline;
idle deliberately has two states.

## Observed verification

Exact commands, results and paths are in `mq5/proof/verification_results.json`.

```text
RR17 RUNTIME: PASS (48 checks, 0 failures; headless logic only)
RR17 SAMPLES: PASS (328 authored bone poses; 696 sequential poses; headless transforms only)
RR17 HEADLESS GATES: PASS (0 errors)
Ran 66 tests in 41.115s
OK
Ran 128 tests in 46.530s
OK
Ran 32 tests in 31.391s
OK
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
RR12 RUNTIME: PASS (44988 checks, 0 failures; headless logic only)
EN06 ENEMIES TEST RESULT: PASS (177 checks, 0 failures)
PB-01 LIVING FOES TEST: PASS (43 identities; exact objective copy; reduced-motion rest)
RR17 NATIVE CAPTURE PARSE: PASS
RR17 SHADOW PRESERVATION: PASS (66 existing entries unchanged)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
MAQUETTE PRODUCTION LOGIC: FAIL (1011 frames)
RR17 PRODUCTION GATES: FAIL (1 errors)
TODO_DESIGN_hit_changing_frames: fewer than six changing presented states (4)
```

The 66 checks comprise rr-17 painting/runtime-frame mutations, actual callback
mutations, `tests.test_test_registration_audit`, and existing native raster/tie
regressions. The 128 cover art identity, icon identity and native ties. The 32
cover program registration and affected density derivation/coverage/calibration.
An initial native-tie unittest invocation lacked `PYTHONPATH=tests`; rerunning
with that existing test import requirement passes. The old pre-battle oracle
expected a static Capacitor; only its explicit registration and roster counts
were updated (37 cutouts / 6 stills). No pre-existing master failure assertion
was weakened.

`process_board_density.py --only storm_capacitor_cutout --check` correctly
reports the two missing native rest rebake records. Exact derived paint passes;
rest records must be written only after real native proof. The inherited macOS
CA-certificate warning appears in successful headless runs; runner exit status
and result lines are retained in their logs.

## Proof for the design owner

Run the exact sequence from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && sh experiments/cutouts/storm_capacitor/rr17_proof.sh
```

`rr17_proof.sh` contains every expanded command in order: windowed native rest;
headless signed motion/pixel samples and gates; windowed native rendering;
native verification with exact-tie handling and supplemental exact contacts;
real-time MP4 and every-frame 3× contact sheets; verified native rest recording;
density check; scoped shadow refresh; windowed production capture and strict
production gate. All windowed captures use `tools/visual_probe_runner.py`,
1920×1080, 100% UI scale. No windowed command has been attempted here.

The review MP4 centres one Capacitor at 2× nearest-neighbour on #1E1E24, with
the clip name at top centre: idle ×3, charge ×2, discharge ×2, hit ×2, death
once plus a one-second terminal hold. The encoder verifies 60 fps, dimensions
and exact frame count. Each contact sheet contains every presented 60 Hz
frame, including holds, at 3× with one fixed union crop per clip. Supplemental
exact contacts are separately captured and verified without changing the reel
clock. Expected native outputs:

- `mq5/proof/native_rest/{front_rest,rear_rest,rest}.png`
- `mq5/proof/native/verification.json`
- `mq5/proof/storm_capacitor_review.mp4`
- `mq5/proof/contact_sheets/*_all_frames_3x.png`
- `mq5/proof/production_native/frames.json` and `verification.json`

The strict production capture will continue to return the named hit conflict
until the director resolves it. Earlier native rest/reel stages can still run.
A concrete director-owned inspection fixture command is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-17 && python3 tools/inspection_fixture.py --task-id rr-17 --run-id rr-17-inspection --scenario combat --enemy-types storm_capacitor,crawler,crawler,crawler --enemy-positions 2:4,3:4,5:4,6:5 --enemy-charge 2 --summary 'rr-17 Storm Capacitor: Charge then Arc Burst'
```

## Chosen defaults

Only unperceived coordinate gauges and test/proof choices were selected or
reused; no new player-facing value was chosen:

- `rr17_build.BIND_ORIGIN = [0, 0]`: coordinate gauge for two nonrotating bones.
- `rr17_contract.TOLERANCE = 0.0001`, runtime `EPSILON = 0.0001`: inherited
  Bone2D float32 verification tolerance, never a motion or pixel allowance.
- Native proof `LABEL_Y = 60`, `LABEL_HEIGHT = 60`; inherited 512 px action
  canvas and 128 px source origin. Dimensions, 2× and background are brief-owned.
- `rr17_review.PROOF_DEFAULTS`: six sheet columns, 24 px labels, 3 px crop margin.
- Production proof reuses eight settle frames, 30 HP hit fixture, 1/60 s idle
  query, en-03 seed/grid, en-06 four-hop fixture, and the existing fixed 6000 µs
  presentation-clock tick. These affect proof only.
- Python `FIXTURE_SIZE = 32`; sample timeout 60 s and production timeout 180 s.
  Windowed budgets 120 s rest / 900 s sequential native and production are the
  existing rr-12 budgets. Runners retain startup/GUI watchdog behavior.

The death helper's 28 × 0.037 s fade clock is inherited from Board and pinned
against its constants. The cap pivot, keys, levels, colours, rounding, 10 fps
idle holds and 1.5° steps come from the brief/protected data.
