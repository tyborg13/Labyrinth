# rr-05 feedback 12 — derived-material scope

The dark-slab gate now blocks derived source texels only. Approved painted shadows are informational. Both derivations and CPU gates pass without changing any texture, authored motion or round 11 donor/support/socket rule. The Wisp tail TODO_DESIGN is resolved by the director's scope decision; its approved shadow is preserved.

[CPU gate results](results.json) · [verification and logs](verification.json) · [preservation](preservation.json) · [owner commands](owner_commands.md).

## Requirements

1. The blocking 3×3 check uses the provenance of each exposed source texel, sampled through its actual cropped part transform. Original hidden-request paint is verified against the approved preview, registered mask and original RGBA digest. Visible partitions retain approval only at their exact approved source RGBA. Dilation, bleed, seam bands, recoloured original texels and other generated edits remain derived. Seams are always derived, even if their donor colour matches approved paint. Approved pixels cannot connect thin derived lines into a blocking slab.
2. The gate JSON reports per-clip/view maxima for approved painted exposures. The table below includes both the whole approved painting and the exposed approved hidden-fill subset, so the Wisp tail shadow remains identifiable. These measurements never block derive, the proof script or promotion.
3. The dark-class definition, donor exclusion, immutable-seed fix and authorized Bloomer socket edit are byte-identical to round 11. All 835 protected art/data/implementation files and all 1,758 sampled pose rows are unchanged. Existing native captures are preserved. No art, seams, poses, timing, tolerances or motion values changed.
4. Tests cover the identical dark 3×3 block in derived material (blocking) and approved hidden paint (report-only), mixed approved/derived components, provenance under rotation and cropping, equal-colour dilation, edited original texels, seam classification and generated edits in visible nodes. The saved pre-fix Bloomer case still fails in 719 poses under the narrowed scope; the fixed case has zero slab failures. The generic slab, thin-line, donor, immutable-seed and promotion regressions remain in place.

## Informational painted-fill exposures

All counts are canvas pixels. Every maximum has its own pose; poses are included in the table and gate JSON. "Approved all" includes visible paint and approved hidden-request paint. "Approved hidden" counts only the latter when it is the topmost painter. "Derived dark" is the largest dark component made solely of derived texels; it blocks only if it contains a full 3×3 block. Derived slab failures are zero for both creatures.

| Creature | View/clip | Derived dark max | Approved all dark max | Approved hidden dark max | Derived slab poses |
|---|---|---:|---:|---:|---:|
| shale_bloomer | front_idle | 0 @ 0000 | 56 @ 0000 | 34 @ 0138 | 0 |
| shale_bloomer | front_move | 0 @ 0000 | 57 @ 0008 | 12 @ 0007 | 0 |
| shale_bloomer | front_burst | 0 @ 0000 | 65 @ 0016 | 18 @ 0046 | 0 |
| shale_bloomer | front_shot | 0 @ 0000 | 56 @ 0000 | 29 @ 0043 | 0 |
| shale_bloomer | front_shell | 0 @ 0000 | 65 @ 0017 | 50 @ 0017 | 0 |
| shale_bloomer | front_hit | 0 @ 0000 | 57 @ 0005 | 36 @ 0009 | 0 |
| shale_bloomer | front_death | 0 @ 0000 | 65 @ 0019 | 51 @ 0022 | 0 |
| shale_bloomer | rear_idle | 0 @ 0000 | 30 @ 0018 | 19 @ 0042 | 0 |
| shale_bloomer | rear_move | 0 @ 0000 | 28 @ 0004 | 10 @ 0005 | 0 |
| shale_bloomer | rear_burst | 0 @ 0000 | 34 @ 0030 | 13 @ 0035 | 0 |
| shale_bloomer | rear_shot | 0 @ 0000 | 28 @ 0010 | 12 @ 0006 | 0 |
| shale_bloomer | rear_shell | 0 @ 0000 | 45 @ 0016 | 21 @ 0016 | 0 |
| shale_bloomer | rear_hit | 0 @ 0000 | 28 @ 0003 | 21 @ 0005 | 0 |
| shale_bloomer | rear_death | 0 @ 0000 | 55 @ 0041 | 41 @ 0050 | 0 |
| lightning_wisp | front_idle | 0 @ 0000 | 48 @ 0060 | 2 @ 0000 | 0 |
| lightning_wisp | front_move | 0 @ 0000 | 36 @ 0000 | 7 @ 0013 | 0 |
| lightning_wisp | front_strike | 0 @ 0000 | 49 @ 0032 | 8 @ 0019 | 0 |
| lightning_wisp | front_cast | 0 @ 0000 | 47 @ 0040 | 8 @ 0017 | 0 |
| lightning_wisp | front_hit | 0 @ 0000 | 49 @ 0007 | 5 @ 0007 | 0 |
| lightning_wisp | front_death | 9 @ 0066 | 49 @ 0014 | 12 @ 0040 | 0 |
| lightning_wisp | rear_idle | 0 @ 0000 | 43 @ 0018 | 12 @ 0108 | 0 |
| lightning_wisp | rear_move | 0 @ 0000 | 41 @ 0008 | 29 @ 0012 | 0 |
| lightning_wisp | rear_strike | 0 @ 0000 | 54 @ 0008 | 31 @ 0019 | 0 |
| lightning_wisp | rear_cast | 0 @ 0000 | 72 @ 0014 | 31 @ 0020 | 0 |
| lightning_wisp | rear_hit | 0 @ 0000 | 81 @ 0006 | 75 @ 0006 | 0 |
| lightning_wisp | rear_death | 3 @ 0050 | 112 @ 0036 | 111 @ 0036 | 0 |

## Proof and remaining work

The full proof commands are in [owner_commands.md](owner_commands.md). Run Bloomer, then Wisp, under the director lock. They derive and recapture native output before review MP4s, promotion, density adoption, rest rebake and production captures. No worker windowed run, production adoption or inspection launch was attempted. The director still judges visible seams in both MP4s.

Round 11's [CPU comparison crops](../feedback11/owner_commands.md#reproduce-the-cpu-comparison) remain valid image evidence because every texture and pose is unchanged. Current CPU gate outputs bind the new provenance oracle. Historical native captures are not current native proof; they predate the round 11 texture changes.

Observed final results:

```text
MAQUETTE DERIVATION: PASS (0 errors)       # both creatures
MAQUETTE PIXEL GATES: PASS (0 errors)      # both creatures
Ran 8 tests in 0.593s
OK
Ran 163 tests in 242.048s
OK (skipped=2)
FULL SUITE RUNTIME: 348.808 seconds (budget 900 seconds)
TEST RESULT: PASS
Ran 764 tests in 665.091s
FAILED (failures=68, skipped=63)
```

All 68 Python failures match the expected pending Bloomer production density-adoption/rest-rebake failures. There are no unexpected failures and no material/Wisp failure. No assertion was changed to conceal failures. [Failure names and paths](python_failures.json); commands, logs and exact result lines are recorded in [verification.json](verification.json). All eight material regressions, all three retained native tie fixtures, the Wisp end-to-end feature fixture and all five owner-script stub tests pass. `git diff --check` and output `.gdignore` checks pass.

## Chosen defaults and files

No player-visible defaults were chosen. New test-only crop, generated-block and rotation fixtures are named fields in [chosen_defaults.json](chosen_defaults.json); existing fixture values are inherited from round 11. The source approval masks are proof data and are never drawn in the product.

Changes are limited to the provenance helper, material measurement/reporting, proof bindings/certificates, acceptance wording, tests and proof documentation. [Files changed this round](files.json). All work remains uncommitted. [Repo size delta](repo_size.json) covers the entire uncommitted rr-05 diff, including retained director changes and earlier evidence cleanup.

## Features, shimmer and exact ties

Rest identity, detached components, feature integrity, held shimmer 0, the 1% boundary residual, native tie candidates and model agreement remain blocking. The tie percentage guard stays removed. Final CPU counts and features are in [results.json](results.json); per-part tie counts are in [ties.json](ties.json). The round 11 feature/tie tables remain numerically unchanged because textures and poses are identical.

<details>
<summary>Per-part exact-tie counts (sampled idle frames)</summary>

Totals include held frames; the wrap comparison is not counted twice. Counts are report-only.

| Creature | View/part | Total tied pixels | Maximum/frame |
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

</details>
