| Measure | Approved x4 px | Native px | Error | Limit | Gate |
|---|---:|---:|---:|---:|---|
| total_height | 808.000 | 817.692 | +1.20% | ±4% | PASS |
| helm_height | 176.000 | 181.594 | +3.18% | ±8% | PASS |
| torso_height | 176.000 | 167.525 | -4.82% | ±8% | PASS |
| pelvis_to_knee | 216.000 | 231.445 | +7.15% | ±8% | PASS |
| knee_to_sole | 224.000 | 230.785 | +3.03% | ±8% | PASS |
| shoulder_width | 240.000 | 241.360 | +0.57% | ±10% | PASS |

| Mass measure | Approved x4 px | Part map px | Error | Limit | Gate |
|---|---:|---:|---:|---:|---|
| helm_width | 156.000 | 141.000 | -9.62% | ±15% | PASS |
| chain_fist | 100.000 | 96.000 | -4.00% | ±15% | PASS |
| near_fist | 104.000 | 96.000 | -7.69% | ±15% | PASS |
| near_shin | 76.000 | 85.000 | +11.84% | ±15% | PASS |
| near_boot | 129.220 | 146.344 | +13.25% | ±15% | PASS |
| upper_near_minimum | 96.000 | 81.000 | -15.62% | ≥65 px | PASS |
| fore_near_minimum | 88.000 | 86.000 | -2.27% | ≥65 px | PASS |
| upper_far_minimum | 84.000 | 94.000 | +11.90% | ≥65 px | PASS |
| fore_far_minimum | 68.000 | 86.000 | +26.47% | ≥65 px | PASS |
| front_coat_near_width | 132.000 | 128.000 | -3.03% | ±15% | PASS |
| front_coat_near_hem | 852.000 | 830.000 | -2.58% | ±8% | PASS |
| front_coat_far_width | 52.000 | 45.000 | -13.46% | ±15% | PASS |
| front_coat_far_hem | 700.000 | 711.000 | +1.57% | ±15% | PASS |
| front_tabard_width | 120.000 | 120.000 | +0.00% | ±15% | PASS |
| front_tabard_hem | 808.000 | 821.000 | +1.61% | ±4% | PASS |
| rear_coat_near_width | 124.000 | 116.000 | -6.45% | ±15% | PASS |
| rear_coat_near_hem | 764.000 | 755.000 | -1.18% | ±15% | PASS |
| rear_coat_far_width | 180.000 | 202.000 | +12.22% | ±15% | PASS |
| rear_coat_far_hem | 884.000 | 872.000 | -1.36% | ±15% | PASS |

| Fit centroid (255px) | Offset X px | Offset Y px | Distance px | Limit px | Gate |
|---|---:|---:|---:|---:|---|
| head | +1.671 | -4.089 | 4.417 | 5 | PASS |
| hand_far | +2.629 | -3.826 | 4.642 | 5 | PASS |
| chain_hook | -0.756 | -0.470 | 0.890 | 5 | PASS |
| hand_near | +4.128 | +1.008 | 4.249 | 5 | PASS |
| foot_near | +3.503 | -2.682 | 4.412 | 5 | PASS |
| foot_far | +1.888 | -4.220 | 4.623 | 5 | PASS |
| tabard | -0.198 | -4.523 | 4.528 | 5 | PASS |

front silhouette IoU: 0.829251; best translation [26, -8] px. Limit ≥0.82.

rear silhouette IoU: 0.782309; best translation [-23, 5] px. Informational; rear follows the true turn.

255px source alpha >=128, with the existing mass and cloth semantic polygons. Head also includes its top ring, feet include their turned cuffs. Additional polygons below transcribe only previously unmeasured hook/far foot and those ring/cuff extensions. Native label masks are downsampled to 255 with Lanczos and thresholded at 128, as is the complete native clay alpha. The hook mask is rasterized from the opened, hash-checked native iron_hook mesh at 255. One global integer translation maximizes silhouette intersection over all possible lags; union includes pixels shifted outside the canvas. No scaling, rotation or per-label registration. Centroid error is Euclidean distance after that one translation. Rear IoU is informational only.

Approved front, original 255px coordinates: hand-traced semantic label masks intersected with original alpha >=128; scanline spans include both endpoint pixels. Scale all source distances by 4, with no figure resizing. Arm thickness uses perpendicular scanlines through the middle 20-80% of each labelled segment. The boot length projects its labelled foot (excluding the turned cuff) onto the board anterior screen axis (-2,1)/sqrt(5). Clay uses visible exact palette labels on the front part map, with the same anatomical landmarks; no clay grayscale threshold or silhouette fit. Scanline masks and axes are displayed on source_mass_landmarks.webp. For the no-see-through region, the native torso envelope is rasterized independently of labels and trimmed by one boundary pixel; 2px antialias blends may inherit an adjacent allowed label, while transparent pixels and exact forbidden labels are never filled. Intentional belt/collar sockets must be covered by opaque body pixels; iron link/ring holes are excluded. Arm minimum uses unoccluded labelled part masks over the identical joint scanlines; visible widths are also retained to expose depth occlusion.

Mass checks: {"barrel_chest": true, "closed_native_forms": true, "cloth": true, "gloved_grip": true, "mass": true, "no_part_holes": true, "no_see_through": true, "open_front": true}

See-through: {"front": {"background_pixels": 0, "forbidden_label_pixels": 0, "forbidden_pixels": 0, "inspected_pixels": 34147, "pants_above_belt_pixels": 0, "passed": true, "unmapped_blend_pixels": 0}, "rear": {"background_pixels": 0, "forbidden_label_pixels": 0, "forbidden_pixels": 0, "inspected_pixels": 49663, "pants_above_belt_pixels": 0, "passed": true, "unmapped_blend_pixels": 0}}

Open front: {"far_lower_leg": {"boot_pixels": 12752, "passed": true, "shin_pixels": 51}, "front": {"minimum_px": 40, "passed": true, "row_px": 683.835, "trouser_run_px": 43}, "rear": {"minimum_px": 40, "passed": true, "row_px": 678.0799999999999, "trouser_run_px": 61}}

Barrel chest: {"passed": true, "ratio": 1.2139542591978787, "shoulder_width_px": 241.36, "width_px": 293}

Collar extensions beyond helm: {"front": {"left_extension_px": 41.049717715769134, "right_extension_px": 41.04972277339107}, "rear": {"left_extension_px": 41.049722773390954, "right_extension_px": 41.04971771576902}}

Largest unfilled part hole: 0 px.

Approved paintings at original 255px resolution, semantic polygons intersected with alpha >=128, multiplied by four without resizing the figure. Width is the widest contiguous horizontal run of visible labelled cloth, never a span across an occluding leg. The front far-tail mask is the exterior sliver to the screen-left of the far trousers. Hem is the lowest labelled pixel row plus one. Native measures use the exact flat ownership palette with the same definitions. Hem limits compare absolute native image rows.

Native ragged hems: {"coat_far": {"tip_count": 6}, "coat_near": {"tip_count": 6}, "tabard": {"tip_count": 3}}

Gloved grip: {"checks": {"complete_gloved_grip": true, "correct_hand_ownership": true, "four_wrapped_fingers": true, "knuckles_forward_of_palm": true, "thumb_over_fingers": true, "top_link_in_grip_envelope": true}, "definition": "Opened native finger rings recover four curled centrelines; native knuckles face forward. The native thumb overlaps the finger group laterally and vertically with a bounded vertex gap. Native top-link vertices in the upper grip band lie inside the hand envelope. This is an envelope/pose check, not a collision-clearance claim.", "finger_curls": {"grip_finger_1": true, "grip_finger_2": true, "grip_finger_3": true, "grip_finger_4": true}, "knuckle_front_m": {"grip_finger_1": 0.08219119326393214, "grip_finger_2": 0.08219119326393214, "grip_finger_3": 0.08219121433735639, "grip_finger_4": 0.08219119326393214}, "palm_front_m": -0.032999979079555736, "passed": true, "thumb_front_m": 0.10784393583036055, "thumb_lateral_overlap_m": 0.12909828365293055, "thumb_nearest_finger_gap_m": 0.0018533846213286385, "thumb_vertical_overlap_m": 0.09688401222229004, "upper_link_samples_in_envelope": 64}

Shoulders: observed 36.210 px; expected 36.204 px; error 0.006 px; 3D level difference 0 m.

Native head-to-sole heights: front 828 px; rear 841 px; difference +1.570% (limit ±3%).

front: chain fist x=200.97, pelvis x=491.24; foot centroids near=[600.5055047474806, 929.0731053765946], far=[391.1721753705935, 862.499502383322]; lower foot=near, lower foot right=True.

rear: chain fist x=823.03, pelvis x=532.76; foot centroids near=[420.246881224447, 820.5399412936366], far=[629.7068596237337, 886.992474674385]; lower foot=far, lower foot right=True.

Native sole minimum Z (m): near=0.000000000, far=0.000000000.

Rear is the proper rotation diag(-1,-1,1), determinant +1; labels do not swap. The tabard emblem is anterior geometry in the tabard label, covered by the cloth from behind.
