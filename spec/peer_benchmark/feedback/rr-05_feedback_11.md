# rr-05 feedback 11: dark slabs from hidden support (director review of the Bloomer native frames)

Do this after feedback 10 (exact texel ties), in the same worktree. Evidence is in
`spec/peer_benchmark/feedback/rr-05_fb11/` in the integration worktree:
- `bloomer_rear_shell_strip.png`: rear Shell frames 0–54.
- `bloomer_rear_left.png`, `bloomer_rear_top.png`: zoom on rest, idle 0, Shell 14 and Burst 22.
- `hidden_dark_parts.png`: rear `root_stem_c`, rear `root_tip_r`, front `root_stem_c` and front `root_tip_r` hidden
  textures at 4x.

## What the owner would see
The gem is fixed and the front view reads well. In the **rear** view during Shell (frames ≈12–48) and Burst:
- flat near-black slabs appear beside the left and right tendrils;
- a dark spike pokes above the petals.

This is the same class of "distracting breakage" the owner rejected. The Wisp native frames look clean, so this
round changes the Bloomer only, unless the new gate finds Wisp failures.

## Root cause (director diagnosis)
- `continuity.underlays()` ("hidden complete bone support") dilates each hidden part's support by 7 px and fills it
  with `nearest_existing`. The nearest donor is almost always the painted dark outline, so the margin becomes flat
  outline colour: (20,16,21), plus keyed fringe (6,13,13).
- Hidden-only parts grew far past their painted fills. Painted fill at rr-04 (7aa3d17ab) vs now:

  | Part | rr-04 px | Now px | Share (20,16,21) |
  |---|---:|---:|---:|
  | rear `root_stem_c` | 1,088 | 6,217 | 82% |
  | rear `root_tip_r` | 452 | 4,115 | 88% |
  | front `tendril_mid_l` | 631 | 5,694 | 89% |
  | front `root_stem_l` | 866 | 5,712 | 84% |

  Most other hidden parts grew 2–10× too. `proof/continuity.json` shows `original_seed_pixels` of 4,578 for rear
  `root_stem_c`. Find out why the seed grew: transfers or orphan attachment.
- The rear trunk's painted hidden fill has a dark socket dome at the top. When the petals and core move, it shows above
  the petal silhouette.

## Decisions
1. **New blocking gate: exposed hidden material must not read as dark slabs.**
   - In every posed CPU frame of every clip and view, take the pixels whose topmost painter is hidden material or a
     seam underlay (anything never visible at rest).
   - Within that mask, mark the outline class: pixels whose colour is in the case's outline palette, or whose luma is
     ≤ the 5th-percentile luma of the approved visible paint.
   - **Fail** if any connected outline-class component in the exposed mask contains a full 3×3 block.
   - One- or two-pixel outline lines are fine: that's how pixel-art edges look.
   - Report per clip and view the exposed hidden pixel count and the largest dark component. Native agreement still
     applies.
2. **Fill support from interior colour, not outline.**
   - Donors for `nearest_existing` and the bleed replication exclude outline-class pixels. Use the same class as the
     gate. The donor is the nearest non-outline painted pixel of the same part or bone.
   - Keep a 1 px outline only where the support forms the posed outer silhouette, if that's simple. Otherwise use none:
     the gate allows thin lines anyway.
3. **Don't grow hidden-only parts past what motion needs.**
   - For parts with no visible owner in a view (rear `root_stem_c` and `root_tip_r`, front `tendril_mid_l` and
     `root_stem_l`), the support is the approved painted fill plus the joint margin. No seed growth from other parts'
     pixels.
   - If gaps then open in Shell, Burst or death, report them. Don't invent fill.
4. **Rear trunk socket.**
   - Where the dark socket in the rear trunk's painted hidden fill gets exposed above the petal silhouette, recolour
     those exposed pixels to the nearest non-outline trunk colour. I authorize this for that region only.
   - Record it in the hidden-fill provenance as a director-authorized derived edit.
   - The rest of the painted fills stay byte-identical.
5. Everything else stays as is: features and gem ownership, stepped and snapped presentation, held shimmer 0, the 1%
   boundary residual, rest identity 0, seams, motion and timing.

## Proof
- The new gate passes for both creatures. Show the per-clip table, plus the before and after for the four parts above.
- A CPU contact sheet in the same crops as my evidence, before and after: rear Shell 0–54, Burst 22, death 30.
- All existing CPU gates, all `tests/test_maquette_*.py`, the full Godot suite through the parallel runner, and the
  Python suite.
- The director command to recapture native frames and finish adoption for both creatures. The derivation changes
  textures, so the native captures must be redone; give the full proof command, not `--from-native`.
