# mq-04 — round 4 delivery

All four native maquettes meet the current director gates (front >= 0.70; rear >= 0.65). Hoarfrost Seer and Arc Thrall retain their accepted geometry and every native clay RGBA sample. All changes remain uncommitted.

| Figure | Front IoU (≥0.70) | Rear IoU (≥0.65) | Native geometry | Visible part-views |
|---|---:|---:|---|---:|
| hoarfrost_seer | 0.739408 | 0.755073 | PASS | 30/30 |
| gale_herald | 0.735791 | 0.680294 | PASS | 38/38 |
| arc_thrall | 0.722267 | 0.703515 | PASS | 34/34 |
| gloam_stalker | 0.716127 | 0.718813 | PASS | 34/34 |

1. **Native specification and quality.** `measurements.json` is each figure's canonical measured input. The compiler uses the protected Lancer r3 registration, approved CC0 anatomy and armature, and native cloth. Herald now has one closed cowl and one continuous pointed mask, two broad cloth folds per banner, ragged ends, and separately documented rear banner cloth state. Its body, horn, plates and legs match r3. Gloam has a separately mapped torso-attached carapace, fitted native thighs/feet, two forearm-attached single-piece crescent claws, and longer source-measured tattered cloth hems. Native exact cutouts give the rigid carapace clearance around the solved cloth without deforming the cloth.
2. **Fit and coverage.** All eight final IoUs pass. All 136 part-views have genuine part-colour pixels and unclipped full solos. The full visible/solo counts and fractions are in [per_part_coverage.csv](per_part_coverage.csv). Gloam's front `fore_near` is mostly occluded by its claw (1 pure pixel remains); its full solo is supplied. No gate was lowered beyond the director's feedback-2 change.
3. **Captures and review.** Each `delivery/` contains front/rear native 1024 clays, part maps, unoccluded solos, joints and capture manifests. [Four-figure 40% overlays](fit_overlay_contact_sheet.png). [Five-figure native-scale clay comparison](../../../arc_thrall/delivery/review/clay_comparison_lancer_r3.png) copies the 1024 cells at 1:1, at the same 2.4 m orthographic scale as the Lancer. The approved Lancer PNG inputs are retained byte-for-byte in Gloam's delivery reference folder.
4. **Native proof.** All native anatomy and carapace collision samples and triangle-pair checks pass the unchanged 3 mm margin. Facing, per-view part ownership and actual polygon-material mutations pass. Fresh cold/cache replay/independent-cold builds match, including unrounded native float32 geometry, topology, materials and joint matrices. Seer and Thrall's native geometry hashes match their accepted r3 versions. The four mq-03 mutations are caught; none survive.
5. **Commit curation.** Each figure's `COMMIT_MANIFEST.txt` lists its complete tracked payload. Generated `spec_native.json`, all saved models, caches, replay copies, candidates and superseded proof were hashed and removed. The generated native spec is rebuilt automatically inside a clean input-only tree; it is not a tracked source input. Native clays preserve every RGBA sample and colour chunk; volatile PNG stamps are removed so clean regeneration can match the delivered PNG SHA-256. Other capture maps additionally zero RGB behind alpha=0. The clean Arc rebuild matches both delivered canonical PNG hashes. Exact original hashes and deleted-proof inventories are retained.

The final test result lines and hashes are in `../validation/test_results.json`; full logs are retained beside it. Native results are in `../validation/native_checks_final.json` and each figure's native proof JSON. Exact bridge-only regeneration and test commands are in [proof_commands.txt](../validation/proof_commands.txt). No windowed or inspection-fixture command applies to this offline unit; no GDScript or game scene changed.

**TODO_DESIGN:** none. **Chosen defaults:** implementation/test/debug fields are listed in [chosen_defaults.json](../validation/chosen_defaults.json), including six shell radial steps, one collision-voxel clearance padding, 900 s job budgets, PNG compression 9, and the debug carapace map colour. Production facing/render styling is inherited. Character extents are source measurements; fit thresholds and collar/chain dimensions are director decisions.

**Open issues:** no failing specified gates. Visual approval of the new Herald and Gloam clays remains with the design owner, as requested; no peer review, commit or publication was performed.

Observed checks:

```text
Ran 61 tests in 0.943s
OK
Ran 98 tests in 130.588s
OK (skipped=2)
Ran 111 tests in 67.852s
OK
Ran 670 tests in 602.932s
OK (skipped=63)
MQ03_MUTATIONS: PASS; caught=4; survived=0
MAQUETTE_COMPAT: PASS
MAQUETTE_QUALITY_DELIVERY: PASS
CURRENT_NATIVE_RELEASE: PASS; figures=4; actual_material_mutations_caught=4
CLEAN_REGENERATION: PASS; arc_thrall; canonical_png_sha256=true
```

Initial tree size versus curated tracked payload (decimal MB; exact sizes and pre-curation snapshots are in `../validation/disk_usage.json`):

| Figure | Initial MB | Curated MB |
|---|---:|---:|
| hoarfrost_seer | 722.83 | 2.66 |
| gale_herald | 373.97 | 4.36 |
| arc_thrall | 322.00 | 5.84 |
| gloam_stalker | 343.70 | 4.27 |
