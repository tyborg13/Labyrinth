# rr-06 feedback 1: director decisions for the three TODO_DESIGN placeholders

Resume after rr-07 (Seer + Thrall rigs) has merged into `codex/peer-benchmark`. Merge integration into your branch
first: rr-07 adds the generic ownership and hidden-material handling, and the native tie rules, which these decisions
reuse.

1. **`TODO_DESIGN_hidden_material_frostglass_lancer`: no painted hidden fills, and none are generated.**
   - Use rr-07's approach: hidden requests with immutable fill previews built from **same-material approved texel
     donors** (rr-05 interior-donor support, outline donors excluded), at the smallest support margin that passes every
     60 Hz pose.
   - The derived-slab gate applies as in rr-05 and rr-07.
2. **`TODO_DESIGN_rear_ownership_frostglass_lancer` / `disconnected_protected_boundary` (tabard, cape_near,
   spear_blade, …).**
   - Follow rr-07: where a part's visible pixels are split by an occluder in front (the spear blade and shaft by the
     hand; a cape section by an arm; the tabard by the tassets), each section becomes its own connected physical crop
     on the **same bone**.
   - Inferred fringe islands outside the part's entire native solo use rr-05 connected-neighbour cleanup.
   - Source coordinates and approved RGBA never move; every physical crop is connected. Boots and cloak in the rear
     view follow the same rule.
   - If a split can't be decided from the native solos, stop with a specific TODO naming the pixels.
3. **`TODO_DESIGN_nonloop_step_clock`: follow rr-05 exactly**, as the owner approved for the Bloomer and Wisp and as
   rr-07 uses.
   - Idle loops present at 10 fps held steps.
   - Action clips play at full rate with whole-pixel translation and 1.5° rotation steps.
   - The rr-06 brief's "play everything through the stepped presentation" means this same rr-05 presentation, not
     10 fps stepping for actions.

## Proof
As in the brief. Both views reconstruct the approved processed art with 0 differing pixels; part integrity passes
with zero failures; everything else as before. Then the windowed `proof_for_design_owner.sh` is mine to run.
