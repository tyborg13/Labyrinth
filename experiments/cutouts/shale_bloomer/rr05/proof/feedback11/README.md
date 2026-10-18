# rr-05 feedback 11 — hidden support

Bloomer passes all CPU gates across 1,008 sampled poses. Its new exposed-material gate has zero failing poses (before: 736). Wisp passes the existing CPU gates across 750 sampled poses, but the new gate rejects original approved rear hidden-tail paint in 68 poses (before: 174). That original paint remains unchanged pending a director decision; promotion cannot bypass the new gate.

[Per-clip before/after material table](per_clip.md) · [result JSON](material_results.json) · [exact gap poses and joints](gaps.json) · [verification](verification.json) · [owner commands](owner_commands.md) · [TODO_DESIGN](TODO_DESIGN.json).

## Requirements

0. Removed only the 2% exact-tie guard. Every tie still accepts only its geometric candidates; third colours fail. Non-tie allowances, boundary residual 1%, and held tolerance 0 are unchanged. All three retained native fixtures pass. Counts for every part and view appear below and in [ties.json](ties.json).
1. Added a blocking topmost-painter CPU gate for hidden material and seam underlays. Its outline class combines the recorded palette and approved visible paint's 5th-percentile luma, using the existing project RGB-luma convention. An 8-connected dark component fails only if it contains a full 3×3 block. Synthetic tests cover a block, permitted thin lines, low-luma colours, mixed hidden/seam painters and visible-paint exclusion. Derive, pixel gates and promotion require the new certificate.
2. Generated support, bleed and seam paint use nearest original non-outline paint of the same part/bone, excluding features. Original painted fills are restored after replication; generated material cannot become a donor seed for later derives.
3. Hidden-only parts restart from immutable approved painted fills and receive one existing joint margin. They never receive another bone's ownership pixels. Repeated derivation is byte-identical for all 85 Bloomer and 20 Wisp runtime paint/layout files checked. The smaller support supersedes the old accumulated support/bleed envelope; reopened gaps are reported below, with no invented support.
4. Applied the authorized Bloomer rear trunk socket edit to one exposed original painted texel. Its source mask and authority are recorded in `mq3/support_derivation.json` and `hidden_fills/index.json`. All original painted preview PNGs remain byte-identical. No other original painted fill was recoloured.
5. Both views' rest identity is 0 pixels. Physical parts remain single connected components; detached components are 0; feature pixels, owner bones and single-node painting pass. CPU held and boundary unexplained shimmer are both 0 for both creatures. All 1,758 sampled pose records are unchanged. Features, source paintings, layouts, rig data, motion and timing are preserved. Native agreement requires a fresh director capture because textures changed; no windowed run was attempted.

## Why the seeds grew

The old hidden-support search rewrote its current image in place at each trial. For a hidden-only part, the next trial dilated the previous trial's generated pixels. Trials 0…7 therefore accumulated a radius of 28 pixels rather than applying a single margin of 7 to the approved seed. This was cumulative dilation, not ownership transfers or orphan attachment. The exact replay is in [seed_growth_diagnosis.json](seed_growth_diagnosis.json).

Rear `root_stem_c` grew from its 1,088 painted pixels to a 4,578-pixel seed before trial 7, then 6,082 pixels plus 135 bleed pixels = 6,217. The new path recovers the approved seed from the protected painted preview and registered mask, verifies its original RGBA digest, and never seeds from prior generated support. It does not require Git history or an output cache.

| View/part | Approved fill | Before support | After support | Before outline RGB share | After outline RGB share |
|---|---:|---:|---:|---:|---:|
| rear/root_stem_c | 1,088 | 6,217 | 2,050 | 81.73% | 5.32% |
| rear/root_tip_r | 452 | 4,115 | 1,011 | 88.41% | 6.92% |
| front/tendril_mid_l | 631 | 5,694 | 1,473 | 89.29% | 6.72% |
| front/root_stem_l | 866 | 5,712 | 1,688 | 83.84% | 5.51% |

The percentage above measures exact RGB `(20,16,21)`, matching the director's comparison. The blocking gate additionally includes the recorded keyed fringe `(6,13,13)` and every colour at or below the view's luma cutoff. [Exact counts and image hashes](part_comparison.json).

## CPU evidence

Inspected the final four before/after sheets in `output/rr-05/feedback11/cpu-evidence/`:

- `before_after_shell.png`: rear Shell 0,6,…54, before in the first two rows and after in the last two.
- `before_after_left.png` and `before_after_top.png`: columns rest, idle 0, Shell 14, Burst 22, death 30; before row then after row.
- `before_after_actions.png`: columns Burst 22 and death 30; before row then after row.

All rear Shell frames 0–54 were also written separately for before and after (110 PNGs). Crops, nearest-neighbour zoom and background reproduce the director's evidence; the fifth detail pose adds the requested death 30. [Named crop data](cpu_crops.json). `contact_sheets.json` in the output directory binds sample matrices, case inputs, the proof tool and sheet hashes. The composition uses the same source transforms as the pixel gates; it is CPU evidence, not a replacement for the director's native MP4.

## Reopened gaps — report only

The director's feedback 9 acceptance keeps tears, negative space and underlay protrusion as reports. Feedback 11 explicitly requests reporting gaps after support is reduced. No motion amplitude or seam geometry was changed to close them. Values below are the largest additional interior-tear count in each requested action, compared with round 10 at that same pose; they are not the absolute per-clip tear maximum.

| Clip/view | Pose | Before tears | After tears | Additional pixels | Largest contributing joint |
|---|---:|---:|---:|---:|---|
| front_shell | 0017 | 1,978 | 2,112 | 134 | petal_near_r↔petal_far_r: 115 |
| front_burst | 0021 | 472 | 499 | 27 | trunk↔petal_near_r: 13 |
| front_death | 0064 | 3,371 | 3,572 | 201 | petal_near_r↔petal_far_r: 138 |
| rear_shell | 0017 | 1,073 | 1,394 | 321 | trunk↔tendril_high_l: 150 |
| rear_burst | 0019 | 341 | 344 | 3 | core↔petal_near_l: 3 |
| rear_death | 0045 | 1,350 | 1,782 | 432 | trunk↔tendril_high_l: 273 |

[gaps.json](gaps.json) contains every clip/view's absolute tear/negative-space/protrusion maxima, root-frame reference, and exact joints for additional gaps. Wisp's silhouette gap metrics are unchanged. Neither creature has a detached component.

## Open design input

`TODO_DESIGN_exposed_hidden_lightning_wisp_tail`: the new gate rejects original approved rear tail paint in strike, cast, hit and death. Rear hit/0006 contains a 75-pixel exposed dark component: 70 pixels are RGB `(29,18,26)` with luma `22.201` (below the approved-visible cutoff `22.49235`); the other five are outline colour. All came from the original fill and none of those source texels is visible at rest. Support donors have already been corrected. Recolouring the Wisp's original fill is outside the Bloomer-only socket authorization, so it was preserved. No tolerance, gate exemption, test skip or assertion change hides this failure.

## Preservation and chosen defaults

[Preservation](preservation.json): 178 Bloomer and 76 Wisp protected files unchanged, including all features, paintings, painted previews, layouts and authored motion/rig inputs. All 57,661 old native capture files were hash-checked unchanged; [native preservation](native_preservation.json). Those captures are retained historical evidence, not after-proof for new textures. [Idempotence](idempotence.json) checks the final donor policy.

Chosen defaults are debug/test-only and recorded as named fields in [chosen_defaults.json](chosen_defaults.json). No player-visible value was chosen. The joint margin 7, seam cap 4, step clock, colours and thresholds follow existing data or director instructions. The two director seam/residual edits and the safe density-registry lookup are retained. Production asset changes already present at the start of this round were left untouched.

## Verification and files

Observed final results:

```text
MAQUETTE DERIVATION: PASS (0 errors)             # Bloomer
MAQUETTE PIXEL GATES: PASS (0 errors)            # Bloomer
MAQUETTE PIXEL GATES: FAIL (68 errors)           # Wisp: protected original tail paint
Ran 161 tests in 378.988s
FAILED (failures=1, skipped=2)
FULL SUITE RUNTIME: 483.938 seconds (budget 900 seconds)
TEST RESULT: PASS
Ran 762 tests in 909.486s
FAILED (failures=69, skipped=63)
MAQUETTE CPU MATERIAL PROOF: PASS (110 Shell frames; 4 before/after sheets)
OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)
```

[verification.json](verification.json) records commands, logs and exact result lines. All six new material regression tests, the native tie fixtures, held-flip/third-colour negatives, frozen native-alpha fixtures and five owner-script tests pass. The focused failure is the existing isolated Wisp feature-derivation fixture: its debug ownership clone has 151 material-only pose failures and rest identity 0 ([diagnostic](feature_fixture.json)); its assertion was not changed. The production Wisp case has the 68 failures reported above. The full Python suite also retains 68 pending Bloomer density-adoption/rest-rebake failures from the director's interrupted promotion. [Failure names and paths](python_failures.json). No assertions were changed to conceal either blocker. `git diff --check` passes.

Changed implementation files include the new palette, exposed-material, immutable-seed, support, socket-edit and CPU-proof helpers; continuity/bleed/seam derivation; pixel gates and promotion prerequisites; matching GDScript proof-input bindings; and tests. Both experimental cases contain the resulting generated support/seam textures, provenance and certificates. The frozen native-alpha source fixtures copy approved pre-change textures with their original SHA-256 values unchanged. The complete uncommitted file list, including preserved director changes and earlier rr-05 work, is [files.json](files.json).

The 189 archived earlier-round evidence files are byte-identical to HEAD in untracked `output/rr-05/archive/` (30,543,297 bytes); the full SHA listing is in `output/rr-05/feedback11/archive_preservation.json`. Final result JSON files are each below 200 KB. [Repo size delta](repo_size.json) includes all proposed tracked files and existing tracked output, excluding only untracked output. All work remains uncommitted; no review, publication, production adoption or inspection launch was run by the worker.

## Feature integrity and exact ties

The following tables are generated from the final CPU gate JSON. Occluded feature views retain the director's reasons and have zero painted nodes/pixels. Ties are counted over every sampled idle frame, including held frames; total is cumulative, maximum is one frame. High tie occupancy is report-only.

| Creature | Feature/view | Preserved/mask pixels | Painted nodes | Owner bone | Sampled poses |
|---|---|---:|---:|---|---:|
| shale_bloomer | crown_gem/front | 1167/1167 | 1 | core | 504 |
| shale_bloomer | amber_upper/front | 242/242 | 1 | trunk | 504 |
| shale_bloomer | amber_right/front | 295/295 | 1 | trunk | 504 |
| shale_bloomer | amber_left/front | 595/595 | 1 | trunk | 504 |
| shale_bloomer | amber_rear_left/front | 0/0 | 0 | trunk | 504 |
| shale_bloomer | amber_rear_low/front | 0/0 | 0 | trunk | 504 |
| shale_bloomer | crown_gem/rear | 161/161 | 1 | core | 504 |
| shale_bloomer | amber_upper/rear | 0/0 | 0 | trunk | 504 |
| shale_bloomer | amber_right/rear | 0/0 | 0 | trunk | 504 |
| shale_bloomer | amber_left/rear | 0/0 | 0 | trunk | 504 |
| shale_bloomer | amber_rear_left/rear | 328/328 | 1 | trunk | 504 |
| shale_bloomer | amber_rear_low/rear | 178/178 | 1 | trunk | 504 |
| lightning_wisp | eye/front | 166/166 | 1 | core | 375 |
| lightning_wisp | eye/rear | 0/0 | 0 | core | 375 |

All feature checks pass. Original occlusion reasons are in [features.json](features.json).

| Creature | View/part | Tied pixels total | Maximum/frame |
|---|---|---:|---:|
| shale_bloomer | front/seam_root_tip_l_root_tip_r | 0 | 0 |
| shale_bloomer | front/seam_petal_near_l_tendril_high_l | 0 | 0 |
| shale_bloomer | front/seam_tendril_high_l_root_tip_c | 0 | 0 |
| shale_bloomer | front/seam_root_stem_c_root_tip_c | 0 | 0 |
| shale_bloomer | front/seam_tendril_high_r_tendril_low_r | 0 | 0 |
| shale_bloomer | front/seam_root_stem_r_root_tip_l | 0 | 0 |
| shale_bloomer | front/seam_root_stem_r_root_tip_r | 0 | 0 |
| shale_bloomer | front/seam_petal_near_r_tendril_high_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_petal_near_l | 0 | 0 |
| shale_bloomer | front/seam_trunk_petal_near_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_tendril_high_l | 0 | 0 |
| shale_bloomer | front/seam_trunk_tendril_high_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_tendril_low_l | 0 | 0 |
| shale_bloomer | front/seam_trunk_tendril_low_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_root_stem_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_root_stem_c | 0 | 0 |
| shale_bloomer | front/seam_trunk_root_tip_r | 0 | 0 |
| shale_bloomer | front/seam_trunk_root_tip_c_component_01 | 0 | 0 |
| shale_bloomer | front/seam_trunk_root_tip_c_component_02 | 0 | 0 |
| shale_bloomer | front/seam_tendril_low_l_root_tip_c | 0 | 0 |
| shale_bloomer | front/seam_core_petal_far_l | 0 | 0 |
| shale_bloomer | front/seam_petal_near_l_petal_far_l | 0 | 0 |
| shale_bloomer | front/seam_petal_far_l_petal_far_r | 0 | 0 |
| shale_bloomer | front/seam_core_petal_far_r | 0 | 0 |
| shale_bloomer | front/seam_petal_near_r_petal_far_r | 0 | 0 |
| shale_bloomer | front/seam_core_petal_near_l | 0 | 0 |
| shale_bloomer | front/seam_core_petal_near_r | 0 | 0 |
| shale_bloomer | front/seam_petal_near_l_petal_near_r | 0 | 0 |
| shale_bloomer | front/trunk | 0 | 0 |
| shale_bloomer | front/core | 0 | 0 |
| shale_bloomer | front/petal_near_l | 0 | 0 |
| shale_bloomer | front/petal_near_r | 0 | 0 |
| shale_bloomer | front/petal_far_l | 0 | 0 |
| shale_bloomer | front/petal_far_r | 0 | 0 |
| shale_bloomer | front/tendril_high_l | 0 | 0 |
| shale_bloomer | front/tendril_high_r | 0 | 0 |
| shale_bloomer | front/tendril_low_l | 0 | 0 |
| shale_bloomer | front/tendril_low_r | 0 | 0 |
| shale_bloomer | front/root_stem_r | 0 | 0 |
| shale_bloomer | front/root_stem_c | 0 | 0 |
| shale_bloomer | front/root_tip_l | 0 | 0 |
| shale_bloomer | front/root_tip_r | 0 | 0 |
| shale_bloomer | front/root_tip_c | 0 | 0 |
| shale_bloomer | front/hidden_trunk | 0 | 0 |
| shale_bloomer | front/hidden_core | 0 | 0 |
| shale_bloomer | front/hidden_petal_near_l | 0 | 0 |
| shale_bloomer | front/hidden_petal_near_r | 0 | 0 |
| shale_bloomer | front/hidden_petal_far_l | 0 | 0 |
| shale_bloomer | front/hidden_petal_far_r | 0 | 0 |
| shale_bloomer | front/hidden_tendril_high_l | 0 | 0 |
| shale_bloomer | front/hidden_tendril_high_r | 0 | 0 |
| shale_bloomer | front/tendril_mid_l | 0 | 0 |
| shale_bloomer | front/hidden_tendril_low_l | 0 | 0 |
| shale_bloomer | front/hidden_tendril_low_r | 0 | 0 |
| shale_bloomer | front/root_stem_l | 0 | 0 |
| shale_bloomer | front/hidden_root_stem_r | 0 | 0 |
| shale_bloomer | front/hidden_root_stem_c | 0 | 0 |
| shale_bloomer | front/hidden_root_tip_l | 0 | 0 |
| shale_bloomer | front/hidden_root_tip_r | 0 | 0 |
| shale_bloomer | front/hidden_root_tip_c | 0 | 0 |
| shale_bloomer | front/feature_crown_gem | 0 | 0 |
| shale_bloomer | front/feature_amber_upper | 0 | 0 |
| shale_bloomer | front/feature_amber_right | 0 | 0 |
| shale_bloomer | front/feature_amber_left | 0 | 0 |
| shale_bloomer | rear/seam_tendril_low_l_root_stem_l | 0 | 0 |
| shale_bloomer | rear/seam_root_stem_l_root_stem_r | 0 | 0 |
| shale_bloomer | rear/seam_petal_far_l_tendril_high_l | 0 | 0 |
| shale_bloomer | rear/seam_tendril_high_l_root_tip_c | 0 | 0 |
| shale_bloomer | rear/seam_trunk_core | 0 | 0 |
| shale_bloomer | rear/seam_trunk_petal_far_l | 0 | 0 |
| shale_bloomer | rear/seam_trunk_petal_far_r | 0 | 0 |
| shale_bloomer | rear/seam_trunk_tendril_high_l | 0 | 0 |
| shale_bloomer | rear/seam_trunk_tendril_high_r | 0 | 0 |
| shale_bloomer | rear/seam_trunk_tendril_mid_l | 0 | 0 |
| shale_bloomer | rear/seam_trunk_tendril_low_r | 0 | 0 |
| shale_bloomer | rear/seam_trunk_root_stem_l | 0 | 0 |
| shale_bloomer | rear/seam_trunk_root_tip_l | 0 | 0 |
| shale_bloomer | rear/seam_root_stem_l_root_tip_l | 0 | 0 |
| shale_bloomer | rear/seam_core_petal_near_l | 0 | 0 |
| shale_bloomer | rear/seam_petal_near_l_petal_near_r | 0 | 0 |
| shale_bloomer | rear/seam_petal_near_l_petal_far_l | 0 | 0 |
| shale_bloomer | rear/seam_core_petal_near_r | 0 | 0 |
| shale_bloomer | rear/seam_petal_near_r_petal_far_r | 0 | 0 |
| shale_bloomer | rear/seam_core_petal_far_l | 0 | 0 |
| shale_bloomer | rear/seam_core_petal_far_r | 0 | 0 |
| shale_bloomer | rear/trunk | 0 | 0 |
| shale_bloomer | rear/core | 0 | 0 |
| shale_bloomer | rear/petal_near_l | 0 | 0 |
| shale_bloomer | rear/petal_near_r | 0 | 0 |
| shale_bloomer | rear/petal_far_l | 0 | 0 |
| shale_bloomer | rear/petal_far_r | 0 | 0 |
| shale_bloomer | rear/tendril_high_l | 0 | 0 |
| shale_bloomer | rear/tendril_high_r | 0 | 0 |
| shale_bloomer | rear/tendril_mid_l | 0 | 0 |
| shale_bloomer | rear/tendril_low_l | 0 | 0 |
| shale_bloomer | rear/tendril_low_r | 0 | 0 |
| shale_bloomer | rear/root_stem_l | 0 | 0 |
| shale_bloomer | rear/root_stem_r | 0 | 0 |
| shale_bloomer | rear/root_tip_l | 0 | 0 |
| shale_bloomer | rear/root_tip_c | 0 | 0 |
| shale_bloomer | rear/hidden_trunk | 0 | 0 |
| shale_bloomer | rear/hidden_core | 0 | 0 |
| shale_bloomer | rear/hidden_petal_near_l | 0 | 0 |
| shale_bloomer | rear/hidden_petal_near_r | 0 | 0 |
| shale_bloomer | rear/hidden_petal_far_l | 0 | 0 |
| shale_bloomer | rear/hidden_petal_far_r | 0 | 0 |
| shale_bloomer | rear/hidden_tendril_high_l | 0 | 0 |
| shale_bloomer | rear/hidden_tendril_high_r | 0 | 0 |
| shale_bloomer | rear/hidden_tendril_mid_l | 0 | 0 |
| shale_bloomer | rear/hidden_tendril_low_l | 0 | 0 |
| shale_bloomer | rear/hidden_tendril_low_r | 0 | 0 |
| shale_bloomer | rear/hidden_root_stem_l | 0 | 0 |
| shale_bloomer | rear/hidden_root_stem_r | 0 | 0 |
| shale_bloomer | rear/root_stem_c | 0 | 0 |
| shale_bloomer | rear/hidden_root_tip_l | 0 | 0 |
| shale_bloomer | rear/root_tip_r | 0 | 0 |
| shale_bloomer | rear/hidden_root_tip_c | 0 | 0 |
| shale_bloomer | rear/feature_crown_gem | 0 | 0 |
| shale_bloomer | rear/feature_amber_rear_left | 0 | 0 |
| shale_bloomer | rear/feature_amber_rear_low | 0 | 0 |
| lightning_wisp | front/seam_core_crown | 0 | 0 |
| lightning_wisp | front/seam_core_tail | 0 | 0 |
| lightning_wisp | front/seam_core_arc_left | 0 | 0 |
| lightning_wisp | front/seam_core_arc_right | 0 | 0 |
| lightning_wisp | front/core | 12 | 2 |
| lightning_wisp | front/crown | 0 | 0 |
| lightning_wisp | front/tail | 6 | 1 |
| lightning_wisp | front/arc_left | 0 | 0 |
| lightning_wisp | front/arc_right | 222 | 30 |
| lightning_wisp | front/hidden_core | 6 | 1 |
| lightning_wisp | front/hidden_crown | 6 | 1 |
| lightning_wisp | front/hidden_tail | 6 | 1 |
| lightning_wisp | front/hidden_arc_left | 6 | 1 |
| lightning_wisp | front/hidden_arc_right | 6 | 1 |
| lightning_wisp | front/feature_eye | 0 | 0 |
| lightning_wisp | rear/seam_core_crown | 0 | 0 |
| lightning_wisp | rear/seam_core_tail | 0 | 0 |
| lightning_wisp | rear/seam_core_arc_left | 30 | 5 |
| lightning_wisp | rear/seam_core_arc_right | 30 | 5 |
| lightning_wisp | rear/core | 0 | 0 |
| lightning_wisp | rear/crown | 0 | 0 |
| lightning_wisp | rear/tail | 0 | 0 |
| lightning_wisp | rear/arc_left | 0 | 0 |
| lightning_wisp | rear/arc_right | 0 | 0 |
| lightning_wisp | rear/hidden_core | 6 | 1 |
| lightning_wisp | rear/hidden_crown | 6 | 1 |
| lightning_wisp | rear/hidden_tail | 0 | 0 |
| lightning_wisp | rear/hidden_arc_left | 6 | 1 |
| lightning_wisp | rear/hidden_arc_right | 6 | 1 |
