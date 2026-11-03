# mq-15 — Chainbound Gaoler, feedback 3

The approved mq3 paintings already have the board's 3/4 facing. This delivery
fits the approved front and supplies its true 180° turn for the rear repaint.
`measurements.json` remains the canonical Blender-native input on the approved
CC0 humanoid armature. Its original surface profiles, widths, radii, cloth
patterns and chain dimensions are retained. The opt-in `surface_pose` changes
pose through rigid transforms and continuous section/root bends. The bucket
stays level; the rounded collar follows the head without changing its volume;
cloth roots stay under the belt. No new art, fonts, audio or dependencies.

## Numbered requirements and retained gates

1. Front silhouette IoU is **0.829251**, after one best-fit translation
   **(+26, −8) px at 255px**, against the approved minimum 0.82. All seven
   semantic centroid distances are below 5px. The [full tables](delivery/proportion_table.md)
   include every offset, source/native mass and cloth measurement, limits and
   methods. The [4× front outline overlay](delivery/front_fit_overlay.webp)
   uses that same translation; no label has its own registration. The original
   mass/cloth polygons are reused; additional ring/cuff, hook and far-foot
   polygons are explicit in [fit_annotations.json](fit_annotations.json).
2. All prior mass, cloth and proportion rows pass. Shoulder rise is
   **36.210px**, expected **36.204px**, error **0.006px**; 3D level difference
   is **0m**. Both native soles remain at **Z=0m**. The native head-to-sole
   heights are **828px front / 841px rear**, a **+1.570%** difference, within
   ±3%. Both views have zero forbidden/background pixels in the inspected
   collar-to-belt region, zero trousers above the belt, and zero unfilled part
   holes. The front opening is **43px**, the rear opening **61px** (minimum
   40px). Far shin and boot remain visible below the tabard. Ragged native
   hems have 6 points per tail and 3 on the tabard. Collar extensions remain
   **41.05px** each side of the helm. Cross straps remain absent.
3. Rear IoU is **0.782309**, informational only. It uses the proper half-turn
   `diag(-1,-1,1)`, determinant +1. Labels retain their body sides; the chain
   hand is screen-right in the rear, and the lower foot is screen-right in
   both views. No mirrored or independently fitted rear is used.

The [contact sheet](delivery/contact_sheet.webp) places both clays beside the
approved paintings, retained Lancer r3 and Gloam clays at the same scale. The
mq-14 delivery is absent at this checkout; the retained Lancer r3 reference is
explicitly labelled. The [proportion overlay](delivery/proportion_overlay.webp),
[source mass landmarks](delivery/source_mass_landmarks.webp) and
[cloth landmarks](delivery/cloth_landmarks.webp) retain the measurement proof.
Proof annotations use lossless WebP, with decoded RGBA equality checked. Native
clay PNG bytes are copied unchanged; mask packing preserves alpha and every
visible RGBA value. All 40 required solos are nonempty.

## Adopted review findings

1. The native probe hashes the **opened** meshes with the builder's exact
   `mesh_hash` algorithm: world vertices, ordered faces and owner label. It
   compares both the object inventory and combined hash with the build report.
   Changing the helm while retaining the old report is rejected.
2. Finger curls come from native sweep-ring means; the link check uses the
   opened link's vertices. Neither observation reads recipe path coordinates.
   Flattened native fingers and a native link displaced 5m are rejected while
   the recipe remains unchanged.
3. The thumb must overlap the finger group laterally and vertically by at
   least **10mm**, have a closest native vertex gap no larger than **35mm**,
   and cross the knuckle face. The observed overlaps are 129.10/96.88mm and
   the gap 1.85mm. Sideways and forward 2m detachments are rejected.
   These proof-only bounds are named in [chosen_defaults.json](chosen_defaults.json).
4. Historical mq-12 successor tests now filter to their pinned inventories.
   They still reject edits, removals and additions inside pinned trees; a
   focused regression proves that a new figure's delivery is independent.
   No foreign preservation code or receipt was changed.

[Native mutation evidence](delivery/validation/native_mutations.json) records
four grip corruptions and the stale-hash helm mutation, all caught after a
passing opened-scene baseline. The supplied reviewer's hash mock also rejects
its stale baseline and changed helm, with different computed hashes. Its grip
fixture omitted native link points; the original incomplete baseline now fails
closed. Supplying that omitted point cloud, without changing mutant actions,
reproduces all three original grip failures. See
[reproduction receipt](delivery/validation/reviewer_reproductions.json).

## Delivery, preservation and chosen defaults

`delivery/` retains clays, maps, solos, joints, manifests, native reports and
recomputed hash-bound acceptance. Cold builds, independent cold builds and
cache replay must match. The clean regeneration uses copied inputs, its own
compiler and an empty cache, with no saved model reused. `COMMIT_MANIFEST.txt`
inventories the figure under 6MB; discarded models, captures and logs are
hashed before removal in `discarded_proof_sha256.json`. No blend/cache is
retained. Sources use LF. [Preservation](preservation.json) checks 14 foreign
compiled recipes and 15 complete foreign figure trees; all 20 original
Gaoler provenance files and both paintings remain byte-identical.

Chosen defaults are proof/numerical fields only: alpha threshold 128, a 512px
FFT workspace for exhaustive integer registration, existing pixel/endpoint
classification tolerances, native ring topology sampling, and the explicit
thumb/link bounds. All are recorded in `chosen_defaults.json`, together with
synthetic fixture and disposable fit-search parameters. Design limits stay
unchanged. There are no `TODO_DESIGN` placeholders.

## Proof for the design owner

All Blender operations use the director's already running bridge, allow-listed
for this worktree and its approved CC0 bundle. Each job has `timeout_s=110`;
the caller stops if unanswered after 120s including queue time. These are
headless authoring commands. No Godot/windowed capture or inspection fixture
is required for this unit; no windowed proof is outstanding.

```bash
python3 -B -m spec.art_identity.maquettes.chainbound_gaoler.proof verify
python3 -B -m unittest tests.test_mq15_maquette tests.test_mq15_cloth tests.test_mq15_pose_fit tests.test_mq15_native_geometry tests.test_maquette_closed_loft -q
python3 -B -m spec.art_identity.maquettes.chainbound_gaoler.mutations --out spec/art_identity/maquettes/chainbound_gaoler/proof/owner_mutations
python3 -B -m spec.art_identity.maquettes.chainbound_gaoler.proof prove --out spec/art_identity/maquettes/chainbound_gaoler/proof/owner_native
python3 -B -m spec.art_identity.maquettes.chainbound_gaoler.proof regenerate --out spec/art_identity/maquettes/chainbound_gaoler/proof/owner_clean
```

Regeneration requires a fresh empty destination. To repeat the opened-scene
mutants before curation, submit this script through `proof.job`:

```python
from spec.art_identity.maquettes.chainbound_gaoler.proof import FOLDER, job
p = FOLDER / 'proof/owner_native'
job(FOLDER / 'review_native_mutations.py',
    [p / 'spec_native.json', p / 'capture', p / 'native_mutations.json'],
    p / 'bridge', 'review_mutations')
```

Only focused suites are used. No full project/Godot suite, peer review,
commit, publication or task-queue mutation is part of this worker handoff.
