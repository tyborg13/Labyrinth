Feedback 2: image metrics and prior budgets are diagnostic only. No motion
re-authoring or new design decision is required by those historical labels.
See [feedback2.md](feedback2.md) for current source repair and proof.

# Feedback 1 status

The director rejected the thresholds used for these limits. The 47 labels
below are retained as historical evidence and are **withdrawn as current
motion findings**. Calibration must separate all six torn native controls
before budgets can be rerun. See [feedback1.md](feedback1.md). No director
key was changed and no new budget TODO is asserted.

---

# Director budget TODOs

Signed, conservative limits in director channel units. A limit is the last passing sampled value before the first failure; positive and negative directions are separate. The fine grid is 0.25 source px/degrees. `None` means the gait solver’s zero-target pose already fails the rest-image gates. No motion data was changed.

| Placeholder | View | Key values rejected | Negative limit | Positive limit |
|---|---|---|---|---|
| `TODO_DESIGN_budget_idle_torso_lift_px` | front | [-2] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_move_torso_lean_deg` | front | [2] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_move_torso_lean_deg` | rear | [2] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_move_torso_lift_px` | front | [-1] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_move_flap_swing_deg` | front | [-3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_move_flap_swing_deg` | rear | [-3] | 2.0 | 0.5 |
| `TODO_DESIGN_budget_lob_pelvis_lift_px` | front | [-4, -1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_pelvis_lift_px` | rear | [-4, -1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_torso_lean_deg` | front | [-4, -3, 3] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_lob_torso_lean_deg` | rear | [-4, -3, 3] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_lob_torso_forward_px` | front | [-2, 2] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_lob_torso_forward_px` | rear | [-2, 2] | 1.5 | 0.5 |
| `TODO_DESIGN_budget_lob_mortar_angle_deg` | front | [-4, 18, 22] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_lob_mortar_angle_deg` | rear | [-4, 18, 22] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_lob_hand_near_lift_px` | front | [-2, 2, 3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_hand_near_lift_px` | rear | [-2, 2, 3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_hand_far_lift_px` | front | [-2, 2, 3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_hand_far_lift_px` | rear | [-2, 2, 3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_lob_head_lean_deg` | front | [-3, 3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_lob_head_lean_deg` | rear | [3] | 3.5 | 0.5 |
| `TODO_DESIGN_budget_land_torso_forward_px` | front | [2] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_land_torso_forward_px` | rear | [2] | 1.5 | 0.5 |
| `TODO_DESIGN_budget_land_mortar_angle_deg` | front | [-2, 1, 3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_land_mortar_angle_deg` | rear | [-2, 1, 3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_land_head_lean_deg` | front | [3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_land_head_lean_deg` | rear | [3] | 3.5 | 0.5 |
| `TODO_DESIGN_budget_brace_pelvis_lift_px` | front | [-3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_pelvis_lift_px` | rear | [-3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_torso_lean_deg` | front | [4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_brace_torso_lean_deg` | rear | [4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_brace_head_lean_deg` | front | [2] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_brace_head_lean_deg` | rear | [2] | 3.5 | 0.5 |
| `TODO_DESIGN_budget_brace_hand_near_inward_px` | front | [4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_brace_hand_near_inward_px` | rear | [4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_brace_hand_near_lift_px` | front | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_near_lift_px` | rear | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_near_forward_px` | front | [2] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_brace_hand_near_forward_px` | rear | [2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_far_inward_px` | front | [4] | 0.0 | 0.25 |
| `TODO_DESIGN_budget_brace_hand_far_inward_px` | rear | [4] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_far_lift_px` | front | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_far_lift_px` | rear | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_far_forward_px` | front | [2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_brace_hand_far_forward_px` | rear | [2] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_scatter_torso_lean_deg` | front | [-3, 3, 4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_scatter_torso_lean_deg` | rear | [-3, 3, 4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_scatter_torso_forward_px` | front | [-2, 3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_scatter_torso_forward_px` | rear | [-2, 3] | 1.5 | 0.5 |
| `TODO_DESIGN_budget_scatter_mortar_angle_deg` | front | [-3, 10, 14] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_scatter_mortar_angle_deg` | rear | [-3, 10, 14] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_scatter_hand_near_forward_px` | front | [-2, 3, 4] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_scatter_hand_near_forward_px` | rear | [-2, 3, 4] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_scatter_hand_near_lift_px` | front | [2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_scatter_hand_near_lift_px` | rear | [2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_scatter_hand_far_forward_px` | front | [-2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_scatter_hand_far_forward_px` | rear | [-2] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_hit_torso_forward_px` | front | [-3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_hit_torso_forward_px` | rear | [-3] | 1.5 | 0.5 |
| `TODO_DESIGN_budget_hit_torso_lift_px` | front | [-1] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_hit_torso_lean_deg` | front | [-3] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_hit_torso_lean_deg` | rear | [-3] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_hit_head_lean_deg` | front | [-3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_hit_hand_near_forward_px` | front | [1] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_hit_hand_near_forward_px` | rear | [1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_hit_hand_far_forward_px` | front | [1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_hit_hand_far_forward_px` | rear | [1] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_hit_flap_swing_deg` | front | [-5, 1] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_hit_flap_swing_deg` | rear | [-5, 1] | 2.0 | 0.5 |
| `TODO_DESIGN_budget_death_pelvis_lift_px` | front | [-12, -8, 1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_pelvis_lift_px` | rear | [-12, -8, 1] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_pelvis_forward_px` | front | [3, 5] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_pelvis_forward_px` | rear | [3, 5] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_torso_lean_deg` | front | [-2, 6, 14] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_death_torso_lean_deg` | rear | [-2, 6, 14] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_death_torso_forward_px` | front | [3, 6] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_torso_forward_px` | rear | [3, 6] | 1.5 | 0.5 |
| `TODO_DESIGN_budget_death_mortar_angle_deg` | front | [4, 10] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_mortar_angle_deg` | rear | [4, 10] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_head_lean_deg` | front | [2, 3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_head_lean_deg` | rear | [2, 3] | 3.5 | 0.5 |
| `TODO_DESIGN_budget_death_hand_near_lift_px` | front | [-4, -2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_near_lift_px` | rear | [-4, -2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_near_forward_px` | front | [3] | 0.25 | 0.25 |
| `TODO_DESIGN_budget_death_hand_near_forward_px` | rear | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_far_lift_px` | front | [-4, -2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_far_lift_px` | rear | [-4, -2] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_far_forward_px` | front | [3] | 0.0 | 0.0 |
| `TODO_DESIGN_budget_death_hand_far_forward_px` | rear | [3] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_flap_swing_deg` | front | [4, 6] | 0.5 | 0.5 |
| `TODO_DESIGN_budget_death_flap_swing_deg` | rear | [4, 6] | 2.0 | 0.5 |
