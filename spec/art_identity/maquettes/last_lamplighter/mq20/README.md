# mq-20 — feedback 2 handoff

## Feedback 3 — checks only

The review of `56c475c69` is addressed in `surface_checks.py` without changing
the accepted geometry or delivery. Plate centres are recovered from the back
contour and measured thickness, then checked against both shoulder-relative
X/Y offsets. Every strand length is compared with its individual director
target. Rivet bounds recover each local centre and all three radii, checked
against the specified face position and radius. These use the prescribed
0.01 H tolerance and extend the existing placement, length and finish gates.

The 35-test focused suite rejects the reviewer's seated-mount plate shift,
interior-strand extension and fivefold rivets; it also rejects displaced rivet
centres on either plate. The preservation regression compares `07d541d9f`
with the reviewed `HEAD` (currently `56c475c69`), so it remains meaningful
after subsequent commits too.

`proof verify` still validates the existing delivery. The retained pixel
regeneration receipt may use the independently pinned `56c475c69` bytes of
`surface_checks.py` and `regeneration.py`, or current bytes after a new
regeneration. Geometry, design and renderer inputs remain strictly live;
arbitrary stale validator hashes are not accepted. No receipt was rewritten,
and no Blender job was submitted for feedback 3. Director painting files and
the director's manifest edits are left untouched.

All changes remain uncommitted. The director owns contract, Git preflight,
commit, peer review, inspection approval and publication. This is an offline
Blender maquette; no Godot scene, gameplay, UI, input, analytics, balance or
icon registry changes apply. No full suites or reviewer agents were run.

## Files changed

- Design/recipe: `directives.json`, `design_details.json`, `recipe.py`,
  `robe.py`, `pauldrons.py`, `chosen_defaults.json`.
- Geometry/proof: `geometry.py`, `measure.py`, `surface_checks.py`,
  `native_probe.py`, `acceptance.py`, `proof.py`, `regeneration.py`;
  new `joint_sweep.py` and `capture.py`.
- Regression coverage: `tests/test_mq20_maquette.py`.
- Evidence: new `delivery/`, `measurements.json.xz`, `feedback2_*.json`,
  compressed feedback-2 logs; updated `blocking_issues.json`, this README
  and `COMMIT_MANIFEST.txt`. The manifest enumerates curated unit files.

## Feedback 2 requirements

1. Evaluated all 32 combinations in the prescribed widest-stance / smallest-
   fist order. None reaches 0.03 H. Selected the authorized fallback: stance
   **1.1 × shoulder width**, fist **0.36 L outward**. The opened-native front
   projection overlaps **505 / 10,814 = 4.669872%** of the cap-to-base lantern
   body, below 25%. The lantern is in front on all 505 overlapping pixels;
   minimum depth separation is **0.060411791 H**. The held chain and rings are
   excluded from the denominator, as in the original cap-to-base gap gate.
2. Shifted only zero-based strand 9's `start_s`: **0.93 → 0.919364763332**.
   The selected stance changes the inherited hem arc to **0.496061047908 H**,
   so its actual overrun is **0.005275726646 H**. That exact overrun is removed;
   the end now equals the hem arc. The feedback-1 value **0.005399852285 H**
   was measured at stance 1.3. No other strand value changed.
3. Built and opened the native model through the director bridge, captured
   front/rear clays and every semantic solo, ran cold/replay geometry proof,
   and produced the five-panel comparison. Fresh copied-source regeneration
   and curation results are recorded in `feedback2_verification.json`.

All table entries below are minimum projected gap / H. Required: 0.03 H.

| Stance | 0.30 L | 0.32 L | 0.34 L | 0.36 L | 0.38 L | 0.40 L | 0.42 L | 0.44 L |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.3 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.001063768 | 0.006971020 |
| 1.2 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.004007899 | 0.009974566 |
| 1.1 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.001023374 | 0.007046707 | 0.013070041 |
| 1.0 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.000000000 | 0.004081483 | 0.010158680 | 0.016235877 |

The complete per-piece measurements and specification hashes are retained in
`feedback2_joint_sweep.json`; the selected source overlap and strand records
are `feedback2_overlap_diagnostic.json` and `feedback2_strand_shift.json`.

## Original numbered brief

- **1–3, 5–6:** stoop, head pitch, knee bends, near step, fist height/forward
  position, elbow poles, free arm and claw lengths/angles are measured from
  opened geometry. Feedback 2 overrides only stance and outward fist. The
  inherited shoulder rule, facing and proper 180° turn pass.
- **4:** the larger hexagonal lantern, six panes, cap/base/candle, straight
  chain and wrapped ring grip are present. It remains rigid with the fist.
  The native capture area ratio is **1.000073212** front/rear (0.8–1.25 gate).
  Rear visible area is **0.759800550** of front; the candle is visible in both.
  The depth-overlap fallback replaces the failed gap requirement.
- **7:** no lamp-house remains. Both plated shoulders are torso-owned and
  connected to the mantle; front crosses, plain backs, rims and rivets are
  measured. The near plate has **31,096 projected pixels, zero occluded**;
  the far plate is partly behind the hood; both backs are visible.
- **8:** ten connected hem strands, four real holes and 3 near / 2 far edge
  notches pass opened-native surface checks. Side strands are the longest.

`delivery/pose_table.md` contains all **89 numeric rows** with target,
observation and tolerance. `delivery/proportion_table.md` compares current
art, mq-18 and mq-20. `delivery/per_part_coverage.csv` retains all 46 semantic
solos and raw owner counts; all parts have coverage or an inherited explicit
occlusion reason, and no solo touches the canvas edge.

## Capture and evidence decisions

Both mq-20 canvases are **1088 × 1088**. Their orthographic scale is mq-18's
scale × 1088/1024, preserving the same physical pixels per world unit. This
provides room for the taller rear projection without clipping or shrinking
it. The contact sheet is **5440 × 1248**: old production art at exact 4×,
all four clays at 1:1 native pixels, sole translations only. Its five panels
follow the requested order. Front clay, rear clay and the assembled sheet
were inspected.

The near-plate visibility gate uses the opened native triangles, including
panel, rims, rivets and cross. The internal mounting stem is excluded because
it joins the mantle. Raw antialiased owner fractions remain in the coverage
report; they are not mistaken for physical plate occlusion. The source test
adds an actual occluder and verifies rejection.

mq-18's two-whole-pane-equivalents rule is retained as a diagnostic for the
replaced lamp: **2.59858 front / 1.86272 rear**. mq-20 gates the specified rear
candle, exposed glass and projected-area ratio. All six glass panes remain
physical geometry; no pane is removed to satisfy a test. The inherited clay
capture uses transparency to expose the enclosed candle; ownership captures
use the complete opaque glass geometry.

Native mutation proof rejects a flattened claw, a rear-shifted cross, a
collapsed robe and a detached lantern, then verifies restoration. Source
mutation tests additionally reject lantern depth reversal and plate occlusion.

The complete specification is stored losslessly in `measurements.json.xz`.
Native clay bytes are unchanged. Semantic masks use the existing lossless
packing. The inherited report packer removes only redundant ray point arrays,
retaining all counts/checks/measurements and hashes of archived raw reports.
The curated unit retains the protected mq-18 front/rear prompt files in its
manifest. Shared builders, mq-18 source/delivery and other figures are unchanged.

## Focused verification

- mq-20: **28 tests passed**.
- mq-18 and rear turn: **53 tests passed**.
- Art identity: **111 tests passed** (existing NumPy/Pillow warnings).
- Native audit, 89 numeric measurements, capture acceptance and cold/replay: **PASS**.
- Fresh regeneration: **2/2 clays and 2/2 part maps match**, no cache or saved model reused.

Exact commands, result lines and compressed log hashes are recorded in
`feedback2_verification.json`. No full suite was run. The existing test module
keeps its temporary-only entry in `tools/python_suite_resources.json`.

## Chosen defaults and design state

No unresolved `TODO_DESIGN` values remain. The existing named keys in
`design_details.json` contain the director's accepted values. Internal
controls are in `chosen_defaults.json`: 1088px proof canvas, fixed physical
scale, 1024px overlap raster, 1e-7 m depth epsilon, 1088px plate-depth raster,
inherited topology, 110s bridge job / 120s response deadlines, XZ preset 6,
and inherited lossless report/mask packing. The shoulder mounting stems span
the approved plate-to-mantle gap at the existing rim diameter without changing
approved panel shape or placement. No new visible design value was selected.

## Proof for the design owner

Inspect `delivery/contact_sheet.webp`, `delivery/front_clay.png` and
`delivery/rear_clay.png`. Current verification commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-20 && python3 -B -m unittest tests.test_mq20_maquette -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-20 && python3 -B -m unittest tests.test_mq18_maquette tests.test_maquette_rear_turn -q
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-20 && python3 -B tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-20 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

Fresh bridge reproduction (choose a new empty output destination):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-20 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof prove --out spec/art_identity/maquettes/last_lamplighter/mq20/proof/director-feedback2-replay
```

The final native captures are under `proof/feedback2-native-r6/capture/`;
fresh regeneration is under `proof/feedback2-clean-regeneration-r2/`. Earlier
r1–r5 and preliminary r6 failures remain diagnostic history in ignored proof
storage. `source_checks.json`, `verification_results.json`, feedback-1 reports
and their old compressed logs are historical evidence, superseded by
`feedback2_verification.json`. Native passes do not constitute design-owner
inspection or publication approval.
