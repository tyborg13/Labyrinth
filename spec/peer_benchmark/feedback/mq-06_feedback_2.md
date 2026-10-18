# mq-06 feedback 2 — accept the corrected front under a rig-relevant gate

Your stop was right: my 0.5% front gate was too strict for what matters. The comparison sheet shows two things:
- the clay difference is render speckle across the whole figure (shading/sampling noise from moved normals);
- the near/far skirt boundary moves where the far hem went deeper.

Neither matters. The approved front painting is fixed, and humanoid rig v2 (`spec/peer_benchmark/humanoid_cutout_rig.md`)
cuts the robe as one piece, skirt_near ∪ skirt_far.

## Replace the front gate with this
1. The whole-figure front silhouette (alpha) is unchanged: 0 px, as your vertex projections imply.
2. Each v2 piece's union silhouette moves ≤ 2 px and changes ≤ 0.5% of its pixels:
   - `head`;
   - `torso` ∪ `collar`;
   - `upper_near` ∪ `fore_near` and `upper_far` ∪ `fore_far`;
   - each hand;
   - `staff_shaft` ∪ `staff_crystal`;
   - `skirt_near` ∪ `skirt_far`;
   - each foot.
3. Front `joints_px.json` moves ≤ 1 px (you measured 0).
4. Report the clay value difference (max and mean per changed pixel) for the record. It does not gate.

If these pass, regenerate and stage the front delivery (clay, parts, solos), then rebuild the rear from the corrected
body. Complete the rest of feedback 1:
- the rear clay, part map, solos, joints and reports;
- the turn regression passing for the Seer;
- rear fit IoU against the old approved rear painting ≥ 0.65;
- the updated 1024 sheet;
- the full Python suite.

## Guard findings
Record the other offenders (Thrall far ankle 0.070 m, Herald far ankle 0.049 m, Lancer spear butt 0.270 m) in your
report. Don't fix them here: the Thrall's is passed to mq-07, and the Herald's and Lancer's go to their v2 units. The
Lancer spear butt may be lifted on purpose. Make the guard accept a per-figure documented exception list, empty for the
Seer.
