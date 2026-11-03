# mq-19 feedback 3 — final shoulder drape

The director owns contract, preflight and commit. All feedback-3 changes are left
uncommitted. This is a maquette for the director's paint-over, with no game or
runtime integration; a playable fixture is therefore not applicable.

## Accepted pose

Only chest yaw changes from round 2, from 10° to 6°. Lean 14°, head pitch 15°,
knees 22°/10°, reaching clawed hand and every other numeric pose value remain.
The staff retains the accepted 4° tilt.

Exact level shoulders use −7.715457950° counter-roll. The front shoulder-rise
error is **13.947px**, using the director's figure-specific **15px** allowance.
The standard 10px comparison remains visible in the report. Facing passes at
6° yaw; the staff clearance still passes its 0.03 L minimum. The tabard formula
and all intrinsic body, armour, fork and pennant shapes are preserved.

## Cloth construction and proof

The hem is 1.15× the inherited shoulder span, with 0.05 L near flare. The drape
settles across the anatomical back instead of extending the diagonal shoulder
caliper into a rigid tent. Its body envelope is smoothed to keep armour corners
from creating a horizontal ridge. Back standoff grows from 0.02 H to 0.035 H.

The top seam follows the existing shoulder/hood support hems with the accepted
0.01 H lap. Its two skins sit under the hood and pauldrons. Folds begin smoothly
under that support and grow from zero to 0.02 H at the root; five folds and the
round-2 irregularity weights remain. Native camera rays hide **734/734** top-skin
points in each view. Native below-shoulder-plane coverage is **97.86%**; the
projected-line measurement is report-only, as directed.

Eight incisions start about 0.03 H above their respective roots and widen down
to the cuts. The nine ribbons share their root edges with the main cloth and
relax into flat vertical sheets, with two skins 0.008 H apart. There are no tube
cross-sections or separate horizontal root join. Opened native vertices verify
flat lower ribbons, shared roots, slit heights, manifold rims and thickness.
The width ratios fill the new root arc at **1.284090736×** scale.
Lengths, the 0.06 H tip floor and the 0.10 H near-edge tip remain. Strip 2 is
clamped by the floor. Tears retain their round-2 centres, areas and vertical
2:1 form within the measured polygonal-rim tolerance; notches remain unchanged.

The far-side native silhouette extends at most **0.0289 H** beyond the body and
arms, below the 0.06 H limit, and remains inside the staff hand.

## Verification and delivery

Focused mq-19 tests and the art-identity suite are used; no full project suite
or windowed game run is needed for this isolated maquette. Native build, audit,
complete captures, cold replay and clean copied-source regeneration are the
production proof. Tests also reject non-flat ribbons, an overlong slit and a
far-side sheet that protrudes beyond the allowed silhouette.

The curated delivery retains exact native clay PNG bytes and lossless review
images. Compiler sources are packed as `source_inputs.tar.xz`, with explicit procedural
reconstruction of generated `design.json` recorded in `GENERATED_DESIGN.json`.
Its exact byte hash and fixed
generation command are retained. The archive is unpacked, the design is
regenerated, and the complete input inventory is verified byte-for-byte before
independent compilation; its result must equal the full measured spec. The generated mesh/spec payload is not
duplicated in the bundle. Exact sources, input hashes, reproduction command and
native numeric reports supply it; the full spec remains in the task proof.
The existing 6,000,000-byte bundle limit remains enforced. The contact sheet
retains both mq-17 views at native scale; their unchanged source PNGs are bound
by path and SHA-256 without duplicate image copies in the bundle.

Verification passes: **23 mq-19 tests**, **111 art-identity tests**, archive
roundtrip checks, native build/audit, cold replay, and clean regeneration of
**2/2 clays and 2/2 part maps**. All 44 clean isolation masks are captured. No
saved model or cache was reused. The complete curated bundle is **4,460,334
bytes**, below 6,000,000; its staged delivery, inventory and every file hash are
verified.

- [Five-column contact sheet](feedback3_delivery/delivery/contact_sheet.webp).
- [2× rear-cloak crop](feedback3_delivery/delivery/rear_cloak_2x.webp).
- [2× front far-side crop](feedback3_delivery/delivery/front_far_2x.webp).
- [Native audit](feedback3_delivery/delivery/mq19_native.json),
  [pose table](feedback3_delivery/delivery/pose_table.md),
  [clean regeneration](feedback3_delivery/regeneration/regeneration.json), and
  [exact archive reproduction](feedback3_delivery/measurement_reproduction.json).
- [Curated file manifest](feedback3_delivery/COMMIT_MANIFEST.txt) and
  [verification summary](feedback3_results.json), plus
  [independent peer signoff](feedback3_peer_review.md).

The inherited mq-17 prompts in the bundle retain historical visual context;
feedback-3 measurements and native clays define this figure. Historical mq-17,
feedback-1 and feedback-2 evidence remains intact.


## mq-22 — ratified profiles and proof guards

The director ratified the delivered feedback-3 cloak and its painted pixels.
`cloak_acceptance.json` is the current profile specification. It supersedes
feedback 2/3's historical interpolation wording without changing `design.json`,
`cloak_generator.py`, any geometry, the delivery, or any image:

- Fold amplitude: **0.02 × t × H**, linear from zero at the shoulders to
  0.02 H at the root; tolerance **±0.004 H**.
- Back standoff: **(0.02 + 0.015 × t × (2 − t)) × H**, ease-out quadratic;
  midpoint **0.03125 H**; tolerance **±0.005 H**.
- Cloth width: shoulder span × **(1 + 0.15 × t × (2 − t))**, ease-out
  quadratic from 1.0 to **1.15**; tolerance **±2%** of the expected width.

`profile_checks.py` independently fits every live cloth row in the measured
back frame. It derives the sagittal torso/pelvis envelope from live faces,
then smooths it using the existing construction's 0.02 H envelope radius.
It removes the existing smoothstep support blend through t=0.12 before
measuring the drape parameters. At the singular t=0 support seam the drape
weight is zero: the observer extrapolates the measured limit from the first
two drape rows and separately retains the exact approved attachment check.
X has no free fit intercept that could absorb a ballooned row. Width, amplitude
and standoff are separate fitted coefficients; all rows also require a full-rank
surface fit. Native audits supply opened body and cloth vertices/faces through
the same observer; portable proof uses the exact compiled geometry whose entire
specification is independently reconstructed from the sealed archive.

`live_ribbons.py` derives ribbons as connected components of the live lower
skin faces. Shared root-edge chains register each component to the main cloth.
Live boundary minima supply tips; edge traversal supplies every measured row.
No declared strip tip, tip station, strip root list or ribbon-row list supplies
a measurement. Orphans are excluded. Missing half ribbons shorten the actual
measurement; missing whole ribbons report eight; detached fragments fail root
connectivity. `mutation_probe.py` operates only on copied arrays, reseals both
skins and requires a passing baseline plus failure of each named guard.

The parent mq-17 proof compares all 2,051 preserved foreign files to Git object
contents at its sealed revision `ec03a241c458c899bc68a36b6983b20abe17ca53`.
Its original unit range (`b5e181e0a^` to that revision) must still contain no
foreign changes, including additions. Later legitimate foreign changes are not
historical failures. mq-17's inventory excludes every numbered `mqNN/` subtree.
`proof_inventory.py`, its compressed preservation receipt, and the historical
regeneration receipt are unchanged. Validation stays in `proof.py`, already
excluded from live production-input hashing by the existing receipt policy.

mq-19's own `COMMIT_MANIFEST.txt` inventories this subtree, including
`prompt_front.md` and `prompt_rear.md`. `director_files.json` identifies these
as protected director files and binds both to their Git objects at `8eb6d3ef3`.
They are not regeneration inputs. The original 83-file delivery manifest and
bundle are unchanged. Full `proof verify` checks every delivery hash against
the sealed Git inventory, existing native acceptance, all four canonical
regeneration comparisons, source archive reconstruction and the current guards.
The discarded clean run's raw manifest is not available: its raw hashes remain
historical, Git-sealed receipt evidence. They are not compared to the staged
manifest, whose image hashes changed during lossless packing. No fresh native
run or regeneration is claimed.

The reviewer's Low about `solve_iterations` is deliberately skipped: editing
the generator would invalidate the protected regeneration input receipt.

### Chosen defaults

New non-player defaults are the 1e-30 squared-segment denominator floor in
`live_ribbons.MEASUREMENT_DEFAULTS`, and mutation fixtures in
`mutation_probe.FIXTURE_DEFAULTS` (0.20 H balloon, 0.008 H fold change, 1.08 width
scale, middle-row selection). The orphan fixture position is named in
`tests/test_mq19_maquette.py`. The fit uses the existing 1e-6 H numerical
surface residual threshold. Envelope sampling (257 stations, three Gaussian
sigmas), support blend and smoothing radius describe the unchanged construction;
they are not new geometry choices. All perturbations and limit extrapolation
are proof-only. No player-facing value or TODO_DESIGN placeholder was added.

### Proof for the design owner

Run from the task worktree; all commands are portable and read-only except
for their explicitly named temporary outputs. No Blender, Godot, windowed
capture, new image or inspection fixture command applies to this proof-only unit.

```sh
python3 -B -m unittest tests.test_mq17_maquette tests.test_mq19_maquette -q
python3 -B tests/test_art_identity_gate.py
python3 -B -m spec.art_identity.maquettes.storm_cantor.proof verify
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq19.proof verify
python3 -B -m spec.art_identity.maquettes.storm_cantor.mq19.mutation_probe --out /private/tmp/labyrinth_codex/mq-22/mutations.json
python3 -B tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/mq-22/python-audit
python3 -B tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/mq-22/python-suite
```

`mq22_results.json` records observed results; `mq22_preservation.json` lists
before/after delivery hashes and the protected geometry/image comparison.
The mutation table is retained in `mq22_mutations.json`. Full suites are run
once after code changes. Changes remain uncommitted; no peer review or signoff
belongs to this implementation worker.
