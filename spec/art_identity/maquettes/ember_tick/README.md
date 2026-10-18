# Ember Tick — mq-05 fitted native maquette

`measurements.json` is the canonical Blender build input, bound by SHA-256 to the untouched approved front/rear processed paintings. It contains source landmarks, measured/fitted three-dimensional surfaces, the exact 18 director part labels and explicit feature ownership. `spec_native.json` is generated compiler output and is not retained in the curated tree.

One capitulum with mouthparts, one displaced domed abdomen with continuous geometrically carved ember cracks, and eight articulated legs with upper/lower ownership and modelled bend joints. Cracks remain wholly owned by shell.

The native board frame remains +X forward, orthographic azimuth 45°/elevation 30°, 2.4 m camera scale. Front and rear share one immutable model and rig. Ordered sphere/convex-chip topology and explicit displacement weights make cold, replay and independent-cold meshes repeatable without a saved model or simulation cache. Native editable source modifiers/bindings are retained in regenerated Blender builds; delivery contains the frozen clay/part/solo captures for painting and later rig cuts.

## Delivery and proof

`COMMIT_MANIFEST.txt` lists every retained file and `discarded_proof_sha256.json` inventories removed builds, candidates, caches and replay copies by actual byte length/SHA-256. Curation enforces the 6,000,000-byte per-figure limit. No `.blend` is an input or a retained delivery artifact.

`delivery/` contains native 1024 front/rear clays, depth-tested part maps, unoccluded solos, `joints_px.json`, capture/build/facing/ownership manifests, cold and unrounded native replay proof, hash-bound provenance, the approved-art fit overlay, per-view fit/part coverage, native mutation evidence, and clean regeneration proof. Native clay PNG bytes are unchanged. Mask PNG exports are losslessly compacted before staging: alpha and every nontransparent RGBA value are unchanged; only undefined RGB beneath zero alpha and volatile metadata are removed. Original raw export hashes are retained, and staging copies the final capture PNG bytes unchanged. Regeneration compares temporary canonical copies of **both** clays and part maps; it does not rewrite delivery PNGs.

Shared fit table, all per-part/leg coverage and the single common-scale roster contact sheet (batch B + Lancer + batch A) are in [Ember Tick's review directory](../ember_tick/delivery/review/). The acceptance bars are front IoU ≥0.70 and rear ≥0.65. Whole-silhouette registration uses source/native top, bottom and ground-contact centroid, retaining the same normalisation as batch A without inventing humanoid landmark rules for crawlers. `delivery/fit_report.json` is the authoritative current fit/coverage result. The contact sheet is lossless WebP to stay within the per-figure budget; its decoded RGBA pixels are verified identical to the composed composed sheet. Technical proof does not confer design-owner paint/quality approval.

Regenerate from an empty input-only project, through the owner bridge:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-05 && python3 -B -m spec.art_identity.maquettes.blender.regenerate_delivery spec/art_identity/maquettes/ember_tick --out spec/art_identity/maquettes/ember_tick/regenerated --verify --discard-build
```

Omit `--discard-build` to retain the regenerated editable `.blend` for local inspection. Output must be new/empty. This is offline Blender proof: no GDScript, scenes, production art, analytics or saves changed; Godot/windowed probes and `inspection_fixture.py` are not applicable to this unit.

## Contract, implementation and validation

1. Native source geometry, the exact labels/bindings and 3/4 facing are validated by the build/capture reports.
2. Fit overlays and per-part/leg visible/solo/pure-colour coverage are validated against protected art, with only explicit painted occlusions accepted.
3. Native captures/solos/joints, manifests, the contact sheet, discarded-file hashes, 6 MB curation and clean regeneration follow the mq-04 format.
4. Cold/replay/independent-cold geometry, unrounded mesh/joint replay, actual material mutations and the hash-bound fail-closed delivery validator apply to every figure. Rigid solids have no cloth simulation cache; legacy cache-integrity/context mutation regressions are also retained.

Shared builder additions: `creature_recipe.py`, `creature_rig.py`, `sculpted_mass.py`, `mass_topology.py`, `surface_relief.py`, `compact_capture.py`, `solid_features.py`, `solid_review.py`, `solid_workflow.py`, `inspect_solid_replay.py`, and portable `test_creature.py`, with guarded integration into existing compilation/build/validation/facing/delivery modules. Existing batch A recipes use their unchanged path; their compiled spec hashes and clean native raster regenerations are checked separately.

Task risk is high for shared offline builder changes; required proof is focused maquette/delivery/art-identity plus full Python discovery, native gates, regeneration and batch A regression. The design owner supplied the prepared branch/task contract/preflight and retains commit, peer review, inspection approval and publication. This engineer makes no Git publication or review/signoff action.

No `TODO_DESIGN_` placeholders remain. Chosen non-player defaults are named: `proof_defaults.part_palette` (unique debug ownership colours), `MASS_DEFAULTS` (64×32 sphere sampling and numerical epsilon), `SOLID_DEFAULTS` (12 crack samples/segment and implementation revision), `RELIEF_DEFAULTS` (stateless noise hash/octaves), `TOPOLOGY_DEFAULTS` (clip tolerance), `FEATURE_DEFAULTS` (30 m inspection rays/1e-5 m coincidence tolerance), `PACKING_DEFAULTS` (lossless mask export bookkeeping), `REVIEW_DEFAULTS` (native cells/proof captions/layout and lossless WebP encoding), `WORKFLOW_DEFAULTS` (900 s known multi-capture job budget, matching batch A, and shared review owner index 1), `BRIDGE_DEFAULTS.lease_timeout_s` (120 s busy-lease deadline), and `TEST_DEFAULTS` (synthetic mask fixtures). Model dimensions/contours/pose fit the brief and approved paintings; no new player art, text, tuning, audio, font or icon is generated.

## Director feedback 1 — organic form revision

All eight legs now have curved, swollen coxa/femur sections, an unchanged knee boundary between upper/lower, curved tapering tibiae and small hooked toes. Near-side sections are broader. Integral small spines and annular joint relief are actual mesh volumes. The shell has a flatter plated crown, a perimeter rim, fine pitting and deeper/wider whole measured crack grooves. The capitulum has a shaped dorsal cap, two short palps and curved mouthparts. The protected paired-art distal joints remain unchanged. Feedback 2 fits the lower paths onto a shared support plane while retaining the authored knees and raised tibia contours; the earlier common-plane limitation is superseded by the measured result below.

The original labels and joint coordinates are SHA-256 locked in `feedback_1_contract`; reviewed baseline clay/sheet hashes are also retained. Approved source art and all batch A inputs remain untouched. New opt-in helpers are `sculpt_profile.py`, `limb_mesh.py`, `mass_fracture.py`, `solid_contacts.py`, `inspect_mass_stacks.py` and `test_sculpt_forms.py`. Their guarded paths leave legacy recipes unchanged. Native Boolean/bevel/subdivision/displacement stacks remain editable on sources; every delivered render uses their applied, immutable mesh.

The shared updated roster sheet and fit table remain in Ember Tick’s `delivery/review/`. All eight figures use one 75% sheet scale (768-pixel cells from native 1024 captures, 2.4 m cameras) to retain the 6 MB curation budget after adding the requested crops. Delivery clays remain native 1024 PNGs. Each figure also has `delivery/review/front_clay_2x.webp` with a hash-bound crop recipe: a tight alpha crop plus 16 native pixels of proof padding, enlarged exactly 2× with nearest-neighbour pixels. No paint is generated or retouched.

Additional non-player defaults are `PROFILE_DEFAULTS.seed_subdivisions` (uniform level 5 seed; the large Tick shell explicitly uses level 6 to resolve its measured cracks), `LIMB_DEFAULTS` (10 axis samples per span, 16 radial samples and numerical epsilon), `CONTACT_DEFAULTS.ground_epsilon` (1e-5 m), and the named common sheet scale / 2× crop / padding fields in `REVIEW_DEFAULTS`. Artist-facing shape dimensions and sculpt fields are explicit canonical recipe data implementing the director’s feedback; no gameplay values change.

## Director feedback 2 — bound fit and evaluated geometry

Final delivery validation and curation require the current fit report and recompute its IoU, part coverage and any foot projections. The report binds the recipe, approved source hashes, current compiled spec, packed capture manifest and original native render manifest; its own bytes are sealed in the matching cold proof. Failed, zero-IoU, stale and forged passing reports cannot be sealed.

Every modelling modifier must evaluate in both viewport and render modes. Subdivision levels must match in both modes; frozen mass geometry must differ from the editable base mesh. Portable rejection fixtures and guard-removal mutation results are retained with the shared Python proof in Burrow Grub's `delivery/validation/feedback_2/`.

Tick's eight contacts are checked in both registered approved paintings (distance at most 2 source pixels), and the actual evaluated foot meshes must meet one support plane within 0.05 m. The fitted plane is 0.25 m; no lifted-foot exception is used. Locked labels and joint coordinates retain their original hashes. The contact table and exact source projections are in Ember Tick's `delivery/review/contact_table.md` and `delivery/fit_report.json`.

Fresh current-builder comparisons for all three figures, all four batch-A figures and Frostglass Lancer compare both clays and both part maps. Baseline comparisons, bridge receipts and clean input hash inventories are retained in Burrow Grub's `delivery/validation/feedback_2/baselines/`. Existing batch-A and Lancer inputs and deliveries are untouched.

Additional non-player defaults: `feedback_2_contact_fit.fitting_defaults` names the offline fitting grid, search bounds, objective weights and numerical support margin; fitting is an explicit operation, never part of verification. `FOOT_LIMITS` contains the director's exact 2 px / 0.05 m acceptance tolerances. `FIT_PROOF_DEFAULTS.overlay_opacity` retains the existing 40% inspection overlay. `FEEDBACK_TEST_DEFAULTS` names synthetic image/mesh fixtures and deliberate invalid offsets/hashes. No new dependencies, art, runtime changes or design placeholders were introduced.
