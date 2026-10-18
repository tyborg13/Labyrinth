# rr-07 feedback 1: director decisions for your TODO_DESIGN placeholders

1. **`TODO_DESIGN_source_hoarfrost_seer_front_raw`: fixed.** The approved raw is now committed at
   `spec/art_identity/jobs/hoarfrost_seer/mq5_front/refs/raw_approved.png` (sha256 `5bafa6be…`, matching your
   recorded expectation). I copied the same file into your worktree at that path; integration has it as 4e0816a6a.
   Continue the Seer registration from it.
2. **Bone attachments (the hierarchy; joint positions come from the maquette's `joints_px.json`):**
   - **`TODO_DESIGN_seer_collar_attachment`:** the collar (mantle) is a child of `torso`, pivoting at the neck base.
     The head bows independently above it.
   - **`TODO_DESIGN_seer_skirt_half_attachments`:**
     - The Seer has no pelvis, so the torso is the root body part.
     - `skirt_near` and `skirt_far` are children of `torso`, each pivoting at the waist (the belt line) above its own
       half. They follow the torso's lean, and the robe folds with the body in death.
     - `foot_near` and `foot_far` are children of the root (body), not the torso, at their own ankle joints, so the
       feet stay planted when the torso leans.
   - **`TODO_DESIGN_seer_staff_crystal_death_binding`:** `staff_crystal` is always a child of `staff_shaft`, at the
     shaft tip; `staff_shaft` is a child of `hand_far`. In every clip the crystal moves with the shaft. In death it
     topples with the shaft about the grip.
   - **`TODO_DESIGN_thrall_collar_attachment`:** the collar ring, with its chain stub, is a child of `torso`,
     pivoting at the neck base. The head bows independently.
   - **`TODO_DESIGN_thrall_loincloth_attachment`:**
     - The Thrall has no pelvis. `torso` and the two thighs are children of the root (body). The thighs pivot at the
       hips and the torso at the lower back.
     - `loincloth` is a child of `torso`, pivoting at the waist, so it follows the hunch and folds in death.

Record these in each case's `rig_recipe.json` as director decisions, then continue with the brief (rigs, features,
production, gates). Native proof commands come to me as before.
