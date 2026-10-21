# rr-30 — director feedback 3

The active case now imports rr-31 motion. See [the rr-31 implementation and
proof report](../rr31/README.md) for current budgets, failures and owner commands.
The report below preserves round-3 history; its native acceptance records do
not certify the current motion and construction.

Implementation is uncommitted. The design owner owns commit, peer review,
inspection and publication. No windowed run was attempted. Current exact
results and remaining acceptance are recorded in `proof/results.json` and
`proof/logs/feedback3-*.log`. Only focused tests were run this round; previous
full-suite transcripts remain historical.


## Joint construction fix (feedback 3)

Before changing construction, the director evidence and CPU lob0000/lob0016/
lob0032 frames were inspected. [The attribution](proof/joint_cleanup/root_cause.md)
identifies the producing pieces and source texels. The compressed pixel table
records 12,014 pixels in the flagged arm/wrist/knee/hem windows. Original layers,
UV maps and source materials are retained for the construction-disabled fixture.

Broad solo/sweep surfaces were exposing dark torso donors inside the arm and
warm limb material past the silhouette. Original dark outer-edge texels then
read as slashes because those covers surrounded them. Joint surfaces now use
adjacent approved painted material, excluding the painting's existing outline
tones as donors. Visible source paint and the approved painting remain exact.

The limit is evaluated against the painted joint contact interface posed from
both adjacent pieces, using exact Euclidean point-to-segment distance. The
pending clarification is explicitly named
`TODO_DESIGN_joint_cover_distance_basis` in `rr30_joint_covers.py`. A literal
three-pixel disk about a hinge cannot cover a contact spanning roughly twenty
pixels from that hinge; the implemented contact interpretation follows the
joint-cover intent. No tolerance above three pixels is added.

A complete canonical sweep cuts every source cover texel that could appear
outside that joint neighbourhood, including underlying surfaces revealed when
another cover is removed. These are static source-alpha cuts in the rig,
not frame masks or gate exceptions. Always-occluded material stays in place
so the bare forearms and covered body surfaces remain connected. Existing
head/waist action fills retain their authorized clips and are bounded too.

The front near-elbow hinge is registered to the endpoint centroid of its
approved painted contact instead of the native point about eleven pixels away.
The rear near foot's heel/toe hull transfers 174 intervening sole pixels from
the shin to the rigid foot; no RGBA changes. Foot joints and gait values stay
unchanged. This keeps a coherent rigid sole without an exposed cover bridge.

The native density-treated rest PNG bytes are retained when promotion copies
the unchanged untreated source rest. Existing density rest records remain
provenance for the prior renderer run; they do not certify the new construction.
The director reruns the prepared windowed stages below. The scoped sidecar
helper skips transient capture directories.

`tests/test_rr30_joint_surfaces.py` runs fresh Godot samples through the complete
CPU coverage and joint gate in both views, every clip. Its source-disabled
fixture fails both lob0016 and lob0032 for cover distance and dark seam pixels;
the original painted rest passes. Exact original dark painting pixels are
exempt, as requested. Full source/proof transcripts use `feedback3-*` names.

## Supplied inputs and construction

Both views use the certified source spec, labels, solos and joints in
`tests/mq11_proof/director_08/slag_mortar/capture`. The front painting is the
approved mq11 front; the rear is the wide round-2 raw at the same supplied
path, including the director's 15% flap desaturation recorded in the paint
README, with the mq11b prompt and reference directory. Protected inputs are
read and copied without modification. Both paintings are processed at K=4;
the front retains the mq9 match recipe and the rear matches that front. The
identity builder invalidates old verdicts before changing bound pixels. It
records the supplied director PASS dated 2026-10-20 only after strict recipe,
provenance, measurement and pair certification passes. Certification errors
write FAILED_CERTIFICATION and raise; no previous PASS survives a failed build.
Fresh visual re-judging of the current sheets still belongs to the owner.

The rigid logical parts are head, torso, crucible, pelvis, belt, flap, and
upper/fore/hand/bracer/thigh/shin/foot on each side. Bracer sprites are their
own children of the forearm bone. `joint_meshes` is empty in both views.
No texel attachments or arm/leg weight fields participate in the active rig.
The source assembly is 0 pixels different in both views. Invisible RGB under
alpha zero is normalized only in the derived runtime calibration, retaining
an untouched approved copy separately.

The belt is a pelvis child and the flap a rigid hinged belt child. Painted
source measurements set the hinge at front [128,162] and rear [114,155]. The
rear cut includes the full wide flap and its ragged left hem. Native segment
ownership uses the existing categorical registration and nearest-neighbour
rules; tiny disconnected source islands retain their RGBA and transfer to
their touching painted owner. Every transfer is recorded under `ownership/`.

Joint continuations reuse the receiving piece's own non-outline painted
material or the adjacent painted joint material over the certified domains.
Parent-side shoulder, elbow,
wrist, hip, knee and ankle seam bands are swept through the actual protected
poses using the existing rr27/rr28 method. The iron cuff also covers the
wrist continuation. All continuation layers draw below visible paint, so
the child covers its parent's hidden material while the painting's original
visible depth order is retained. The existing Glacial Mirror rigid-air policy
allows air between pieces and rejects missing immutable material inside a
piece. No gate exception or creature-specific tolerance was added.

Invisible quad storage bounds are recorded in `../rr30_storage_bounds.json`.
The one-time `../rr30_quad_fit.py` calibration chooses transparent padding
against the unchanged rigid-air raster check, retaining every anchor and
opaque source texel. This removes complementary-quad sampling holes without
adding protruding painted guards. The former broad guards and swept domains
are subject to the same static joint-local source cuts as every cover.
The full sweep validates the resulting pieces with their actual captured
Sprite2D matrices; no Bone2D transform is independently re-snapped by the CPU
renderer. These are storage and coverage corrections, not motion tuning.

Retained old skinned-limb/apron PNGs are explicitly inactive in the density
registry; every active rigid texture is adopted and processed.

## Motion and scale

`director_motion.json` and the production copy are byte-identical to protected
`staged/rr-30/motion_tracks.json`. All existing motion, crucible movement and
slag VFX are retained. The compiler/runtime accept `flap.swing_deg` with the
existing projected angle sign. The supplied gait sway is added analytically:
one sine cycle between consecutive actual foot contacts, beginning at zero
at each contact, delayed by 0.06 seconds, amplitude 4 degrees. A smoothstep
ramps from zero to full during the first 12% and back to zero during the last
12%. The Python gate oracle and Godot runtime sample the same explicit policy;
the tests independently check lag, contact zeroes, extrema and the envelope.
Both original TODO_DESIGN placeholders are resolved.

The unchanged 12% stretch gate measures all painted pieces, including hidden
material, in every presented frame. Skins still use complete physical texel
edges if a different case opts into them; those edge lengths now divide out
the validated scale on their declared piece. Rigid pieces use the maximum local
affine singular value divided by their declared uniform scale, detecting
shear and anisotropy as well as extension. Every current piece declares source
scale 1. The Glacial Mirror gait moves the rigid segment joints over the
supplied leg-length projection (maximum 1.22) while leaving the segment bases
rigid; joint spacing is not texture strain. A regression fixture also checks
that an explicitly declared uniform 1.22 scale measures zero strain. Public
`report()` fixtures check zero and exactly 12% normalized strain, reject
12.01% for rigid and skinned pieces, and reject invalid scale declarations.
The two rejection branches were disabled independently in memory: each negative
fixture failed as required.

Fresh task-runner Godot sampling checks the continuous flap angle against an
independent director formula in both views, plus the actual painted sprite
after the existing 1.5-degree quantization. Disabling Godot sway makes this
test fail; the runtime source was restored byte for byte before final proof.

## Headless reproduction

Run from this worktree; stop and inspect any nonzero command. Build/sample/build
calibrates covered joint material from the actual protected poses. Native rest
rebaking and renderer acceptance remain owner-run.

```sh
python3 experiments/cutouts/slag_mortar/rr30_identity.py
python3 experiments/cutouts/slag_mortar/rr30_build.py
python3 experiments/cutouts/slag_mortar/rr30_density.py --refresh-sources
python3 tools/godot_task_runner.py --task-id rr-30 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr30 --output res://experiments/cutouts/slag_mortar/rr30/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr30_build.py
python3 experiments/cutouts/slag_mortar/rr30_density.py --refresh-sources
python3 tools/godot_task_runner.py --task-id rr-30 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr30 --output res://experiments/cutouts/slag_mortar/rr30/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr30_records.py samples
python3 experiments/cutouts/slag_mortar/rr30_gates.py
python3 experiments/cutouts/slag_mortar/rr30_seams.py
LABYRINTH_TASK_ID=rr-30 python3 -m unittest discover -s tests -p 'test_rr30*.py' -v
```

`proof/before/` retains the six original worst-frame crops: front brace 19/18,
rear brace 16/18 for near/far arms, and death 78 for both face/neck seams.
`proof/after/` uses the same frames and source windows. `proof/after_full/`
retains those frame choices but includes the entire current rigid limb, which
can extend past the old distorted silhouette. `proof/before_after.png` pairs
the matching windows. These are CPU diagnostics, not native renderer captures.
Identity sheets are in the mq11 front/rear jobs; source-cut annotations are in
`proof/contact_sheets/source_cuts_outlined.png`.

## Resource sidecars

`../rr30_sidecars.gd` prepares only missing UID/import files in this unit's
owned output roots, using Godot's UID allocator and the existing keep importer.
It never scans the editor or changes provided inputs. Run after generating
new outputs and include the sidecars with the owner-staged changes:

```sh
python3 tools/godot_task_runner.py --task-id rr-30 --stream -- godot --headless --path . --script experiments/cutouts/slag_mortar/rr30_sidecars.gd
```

The scoped helper also includes the new density probe UID. Existing sidecars
are retained; provided native inputs are excluded.

## Proof for the design owner

The driver uses the required visual runner, existing semantic contracts,
1920×1080 and 100% UI scale. Density emits two native 255×255 rests and a
1920×1080 summary, as its unchanged rr22 contract requires. The rr30 summary
now renders into a fixed SubViewport instead of reading the OS root window;
window dimensions and backing scale cannot alter its PNG dimensions. An
exact shell-dispatch test verifies all six density commands in order. The
headless probe validates the same viewport builder and both source-rest sizes;
it does not rebake or certify pixels. The driver refreshes result manifests
explicitly so the director can regenerate bindings after a change. These are prepared commands, not observed captures.
No inspection_fixture command was requested; that fixture is assigned to the
owner. The driver stops at failed gates.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-30
sh experiments/cutouts/slag_mortar/rr30_proof.sh density
sh experiments/cutouts/slag_mortar/rr30_proof.sh rest
sh experiments/cutouts/slag_mortar/rr30_proof.sh native
sh experiments/cutouts/slag_mortar/rr30_proof.sh sheets
sh experiments/cutouts/slag_mortar/rr30_proof.sh walk
sh experiments/cutouts/slag_mortar/rr30_proof.sh idle
sh experiments/cutouts/slag_mortar/rr30_proof.sh production
sh experiments/cutouts/slag_mortar/rr30_proof.sh review
```

Planned outputs under `proof/`: `native_rest/`, `native/`, `contact_sheets/`,
`gait_move_native/`, `gait_move_sheet.png`, `idle_native/`,
`slag_mortar_idle_comparison.mp4`, `production_native/{front,rear}/`, and
`slag_mortar_review.mp4`. Production captures use the actual resolver in
`tests/rr30/production_capture.gd`, record genuine production walk samples and
run the combined canonical production gates once across both views.

## Chosen defaults and remaining acceptance

All proof/test/internal choices are named in `proof/chosen_defaults.json`.
Hinges, ownership boundaries, hem boxes and raster continuation cells are
source/proof measurements. No protected art, palette, motion value, wording,
number or sound was redesigned. The two original design placeholders are
resolved by director feedback 1.

The corrected rear measures chroma 0.19884831373817569 against maximum 0.2.
Strict identity certification passes. Source rests are 0 pixels different in
both views. The director reported all windowed stages passing for 407ca1d9a;
those captures are retained as historical evidence. Current construction
requires the director's fresh density, rest, native, sheets, walk, idle,
production and review stages in the order above. Native rest PNG bytes and
their recorded density calibration are retained; they do not certify the
changed moving construction. Density calibration continues to measure the
untreated approved rest separately from the retained native PNG.

## Current focused validation (feedback 3)

- `Ran 33 tests in 347.953s`; `OK` (all rr30 tests at the complete sweep).
- Supplemental density/donor assertions: `Ran 6 tests in 6.091s`; `OK`.
- Unchanged legacy donor tests: `Ran 2 tests in 17.991s`; `OK`.
- Strict art identity: `Ran 111 tests in 36.098s`; `OK`.
- `RR30 FRONT CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 REAR CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 JOINT MUTATION: CAUGHT (source fix disabled; lob0016 and lob0032; cover and dark seams)`.
- `RR30 PRODUCTION LOGIC GATES: PASS (3032 frames; 0 errors; both views)`.
- `RR30 SOURCE/BONE/KNEE GATES: PASS (0 errors; both views)`.
- Maximum exposed cover distance: front 2.999639445366 px; rear 2.999604746901 px.
- All 80 pieces have approximately zero stretch; per-piece maxima are in
  `proof/stretch.json` (largest numerical residue 0.00002399499057226251%).
- Walk fit: front 0.091893 px; rear 0.098218 px. Both source rests remain 0 px.
- `proof/joint_cleanup/before_after.png` compares the two flagged frames;
  the full pixel attribution, mutation result and 862-frame report are beside it.
- All 166 protected inputs and 31,442 tracked other-figure files are unchanged;
  non-Mortar registry records are unchanged. Both native rest PNGs are byte-identical.
- No full suite, windowed capture or peer review was run this round.

## Historical validation (feedback 2)

- `Ran 29 tests in 10.834s`; `OK` (fresh runtime sampling included).
- `Ran 111 tests in 36.351s`; `OK` (art identity).
- `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)`.
- Density focused: `Ran 3 tests in 0.088s`; `OK`.
- `RR30 DENSITY PROBE LOAD: PASS (1920x1080 summary; 255x255 rests; headless structure only)`.
- `RR30 SOURCE/BONE/KNEE GATES: PASS (0 errors; both views)`.
- `RR30 PRODUCTION LOGIC GATES: PASS (3032 frames; 0 errors; both views)`.
- `RR30 FRONT CPU COVERAGE GATES: PASS (431 frames; 0 errors)`;
  `RR30 REAR CPU COVERAGE GATES: PASS (431 frames; 0 errors)`.
- Maximum local stretch: 0.00002507210339341981%; unchanged limit 12%.
- `RR30 STRETCH: PASS (0 errors; 80 pieces)`; per-piece maxima in `proof/stretch.json`.
- Three disabled-behaviour mutations caught; source restored byte for byte.
- Exact command dispatch and proof dimensions: `proof/density_contract_check.json`.
- CPU before/after crops refreshed and inspected; current identity sheet inspected.
- No full suite or windowed capture was run this round.

## Historical validation (feedback 1, not rerun this round)

- Focused: `Ran 20 tests in 10.044s`; `OK`.
- Full Godot, once: `MAIN BODY ASSERTIONS: 378990`;
  `FULL SUITE RUNTIME: 434.349 seconds (budget 900 seconds)`; `TEST RESULT: PASS`.
- Full Python, once: `Ran 1554 tests in 1552.577s`;
  `FAILED (failures=5, errors=3, skipped=66)`.
- Both canonical coverage views: `PASS (431 frames; 0 errors)`.
- Combined production: `RR30 PRODUCTION LOGIC GATES: PASS (3032 frames; 0 errors; both views)`.
- All 80 physical pieces: maximum local extension 0.00002507210339341981%,
  unchanged limit 12%. All 34,480 presented rigid basis checks pass.
- Other figures: 31,442 tracked files byte-identical; non-Mortar identity and
  density records unchanged; protected inputs unchanged.

The full Python transcript is retained without editing. Follow-up checks fixed
retired texture registration, prompt curation records and optional metadata in
two existing reach fixtures. The mid-run helper correction invalidated four
RR20 production input hashes; real captures were refreshed in this unit's
ignored proof output and the unchanged assertions pass across all six reports.
All 1,214 rr30 pose rows remain identical after the fixture compatibility fix.
The 47 initial committed sidecar omissions are repaired on disk and the complete
candidate file set passes the existing validator; the tracked-only check still
requires owner staging. Those are historical outcomes. Feedback 2 resolves the rear chroma; the
owner-run native rest/capture proof remains pending. Exact per-check result
lines and transcript paths are recorded in `proof/results.json`.
