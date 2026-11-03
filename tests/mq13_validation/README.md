# mq-13 r3 — accepted canonical delivery

The director accepted the built crouch, hunch and plates in feedback 1. The canonical Gloam recipe and complete native delivery are r3. Work remains uncommitted; the design owner owns peer review, inspection and publication.

The elevated rear camera projects the forward-bent head higher. The former `rear_hood_below_back` gate is removed. Its measured 122.311010 px height difference remains in `review/gates.json` and canonical `delivery/articulated_pose_checks.json` as report-only data. `design_resolved` passes and no TODO_DESIGN placeholder remains. All other r3 gates are unchanged and mandatory.

| Requirement | Verified behavior |
|---|---|
| Crouch | Hips fixed; ankles exactly (650,900)/(430,790), horizontal spread 220 px; native leg lengths retained; both knees face forward; soles share the same floor plane. |
| Hunch | Head exactly (440,330); sagittal bend, level shoulder rule and arm/claw offsets retained. Director accepts the rear profile; height is report-only. |
| Plates | Accepted closed pieces scale uniformly to 60%, preserve topology and dimensions, and touch actual cloth within the inherited 0.015 m clearance. Overhang is 23.8815 px in both views; no below-margin samples or cloth intersections. |
| Scope | Labels, colours and source hood/drape/claw/wrap measurements are exact. Nine other figures' compiled specs and 864 protected files match the before inventory. |
| Promotion | Canonical recipe and every clay, part map, solo, joint table, manifest and sealed native report are r3. Original native clay bytes and every visible mask pixel are preserved. Protected Lancer references stay exact. |

[Native comparison sheet](review/mq13_native_sheet.webp): old front clay / new front clay / new front map; old rear clay / new rear clay / new rear map. Every panel is 1024×1024; the sheet is 3072×2048 with joints marked. [Joint table](review/joint_table.md), [all acceptance gates](review/gates.json), [report-only fit](review/fit_report_only.json). IoU against the old paintings is front 0.542843 / rear 0.616884 and remains report-only.

`validation/native/` retains native builds, capture batches, ownership, collision, facing, exact replay and sealed pose reports. `native_render_manifest.json` binds the original raw native images in `review/native/`; `capture_manifest.json` binds the compact canonical image bytes. Mask packing changes only undefined RGB under zero alpha and volatile PNG metadata. Clay PNG bytes are untouched.

`validation/regeneration.json` records input-only regeneration with no cache reuse and identical native geometry and raw clay/map pixels. `validation/canonical_regeneration.json` additionally compares the fresh renders directly against canonical r3. `validation/promoted_delivery.json` seals the exact canonical recipe and full delivery inventory; `canonical_before_promotion.json` pins every replaced mq-12 file. Historical mq-12 assertions run against immutable approved inputs, while mq-13 tests strictly check the new live seal.

The accepted body hash is `1e311a282c7bd71755065bfe5aab1285c397e9e36ac7f32843231ba4a960d9ba`. [Director decision](../../spec/art_identity/maquettes/gloam_stalker/r3/design_status.json) pins this body and all four visible clay/map pixel hashes. Promotion verifies those pins before and after staging. Repeating promotion verifies the existing exact canonical seal without replacing it.

Current native result lines:

```text
MQ13_ACCEPTED_BODY: PASS; hash=1e311a282c7bd71755065bfe5aab1285c397e9e36ac7f32843231ba4a960d9ba
MQ13_REGENERATION: PASS; raster_matches=True; geometry_matches=True
MQ13_CANONICAL_REGENERATION: PASS; clay_and_part_map_pixels_exact=True
MQ13_PROMOTION: PASS; canonical=r3; approved_geometry_and_pixels_exact=True
```

All 22 acceptance gates pass. Current logs use the `*_feedback1.log` suffix. Earlier draft logs and `draft_canonical_unchanged.json` document the state before director acceptance. Final focused test results are in `validation/focused_feedback1.log`; curation results are in `validation/curation_feedback1.log`. Full suites, Godot, runtime rigs and windowed probes are outside this offline unit.

The focused selection reports `Ran 303 tests in 83.614s` / `OK (skipped=2)`. The skips are the two optional broad native Blender checks; this unit's native jobs run separately through the director bridge. The historical `legacy_guard_feedback1.log` records the superseded r2 guard failure. Feedback 2 explicitly approved extending only Hollow Mimic's preservation helper and its tests. The original seven legacy tests now report `Ran 7 tests in 0.429s` / `OK` in `validation/legacy_guard_feedback2.log`. Seven new chain and mutation tests report `Ran 7 tests in 0.358s` / `OK` in `validation/successor_mutations_feedback2.log`. The related freshness, successor, preservation and canonical evidence checks report `Ran 31 tests in 2.548s` / `OK` in `validation/focused_feedback2.log`. Mutating either receipt's bound hash or bytes fails closed. The helper pins `canonical_before_promotion.json` to `a3db93e913d7b069f786f7520daa33c9f22150375019d1b8d7566c3966601959` and `promoted_delivery.json` to `6764593745116482a63132a9e7a752af7df4383ab547e97c6a4cefb2eb73238e`, checks that the predecessor matches mq-12's complete Gloam delivery, and advances only that subtree. Both receipts remain byte-identical. `validation/scope_feedback2.json` records 1,660 other maquette files unchanged, including every other guard and all figure data/delivery. No design defaults were added.

Generic builder files: new `articulated_pose.py`, `posed_surfaces.py`, `grounded_pose.py`, `back_plate_seat.py`, `plate_contact.py`; opt-in wiring in `compile_recipe.py`, `deferred_pose.py`, `delivery_validation.py`, `curate_delivery.py`. Other recipes do not opt in. Gloam implementation: `workflow.py`, `proof.py`, `native_probe.py`, `reference_probe.py`, `contact_probe.py`, `collision_probe.py`, `promote.py`, `curate_candidate.py`, r3 data and documentation. Tests cover pose preservation, fail-closed delivery checks, report-only camera measurement, approved pixels, canonical promotion, regeneration and complete <=6 MB manifests.

The required art-identity check was repeated after the helper change: `python3 -B tests/test_art_identity_gate.py` reports `Ran 111 tests in 36.561s` / `OK` in `validation/art_identity_feedback2.log`. Feedback 2 changes no native geometry, art, delivery or regeneration inputs; its proof is headless and needs no new capture or windowed command.

Proof for the design owner: run sequentially from the worktree; each native job uses the director bridge with a 110-second execution budget and hard 120-second answer limit.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow build
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow observe
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow regenerate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow proof
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow promote
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.workflow verify-candidate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-13 && python3 -B -m spec.art_identity.maquettes.gloam_stalker.curate_candidate
```

Use `--resume` only for identical inputs and builder revision. Curation retains native evidence and inventories generated intermediates by SHA-256 before removal, preserves prior inventory entries, refreshes both manifests and verifies the canonical delivery. No commit, branch change, publication, windowed command or inspection fixture is part of this work.

Chosen defaults: [chosen_defaults.json](chosen_defaults.json) names bridge budgets, numeric tolerances, proof-only markers/captions and synthetic test fixtures. Capture batches, render camera, renderer, source solver settings, source pixel scale and native collision clearance are inherited. No player-facing value or pose was redesigned in feedback 1.

Feedback 3 fixes only the two requested review items. `gloam_stalker/saved_body.py` recomputes the builder's world-space per-object mesh hashes (including part labels) and complete digest from the loaded `.blend`; both the inventory and combined hash must match `build_report.json`. Observations and the new Gloam bounded capture probe use this check before producing output. Captures retain the existing local mesh/attachment/armature signature check through rendering, including the intentional rear root turn. No other figure's probe or guard changed.

Observation and capture bridge receipts now bind `maquette.blend`, `build_report.json` and the verification helper. Exact native replay receipts bind all three saved builds. Resume fails closed for a changed or previously unbound saved-body input; it cannot reuse an old capture receipt. The unused Gloam `solo_batch_size` and builder `SURFACE_DEFAULTS` were removed, along with their obsolete chosen-default entries. Capture still uses the existing mq-12 consumer and its inherited batch size.

Native proof is retained under `validation/feedback3/`. `binding.json` verifies the accepted body hash and catches a temporary moved hood vertex, then verifies exact geometry restoration. `resume_mutation.json` records rejection after changing the real saved `.blend`, followed by byte-exact restoration. The front and rear capture receipts bind that saved body and current probe/helper source. `capture_pixels.json` verifies exact alpha and visible RGBA against all four canonical clays/maps. `scope_feedback3.json` pins all 60 canonical delivery files byte-for-byte and records 1,491 other maquette files unchanged. The canonical r3 recipe, delivery receipts and promotion inventories were not rewritten. Generated intermediates were inventoried by SHA-256 in `validation/feedback3/generated_sha256.json.gz` before removal.

The initial proof logs retain two corrected probe checks: raw part-map RGBA includes undefined RGB below zero alpha, which canonical packing removes; an extra world-space check after rendering also rejected the intentional rear root turn. The final pixel check uses the existing approved alpha/visible-RGBA rule, and the capture verifies world geometry before the view transform plus local geometry through it. `capture_pixels_final.log` records both final bridge captures passing. A focused regression covers the rear-turn case.

Current feedback-3 results: `saved_body_feedback3.log` reports `Ran 7 tests in 0.039s` / `OK`; `focused_feedback3.log` reports `Ran 117 tests in 28.002s` / `OK`; `art_identity_feedback3.log` reports `Ran 111 tests in 37.429s` / `OK`. These cover both new mutations, capture routing, saved-body/report resume bindings, legacy successor guards, maquette true turn, builder wiring, delivery and accepted canonical evidence. Native result lines are `MQ13_SAVED_BODY_BINDING: PASS; moved_hood_vertex_rejected=True; geometry_restored=True`, `MQ13_SAVED_BODY_RESUME_MUTATION: PASS; changed_body_rejected=True; original_restored=True`, and `MQ13_VERIFIED_CAPTURE: PASS; loaded_geometry_verified=True; canonical_visible_rgba_and_alpha_exact=True`.

Chosen defaults added in feedback 3 are only the named synthetic saved-body fixtures and the native mutation displacement `vertex_delta_m = 0.001`; the mutation is restored and never saved. No design values changed. No new windowed proof or Godot command applies.
