# rr-02 — round 6 (director decisions for the four TODO_DESIGN items)

Work on top of the current uncommitted state. Do not commit.

1. **`TODO_DESIGN_tabard_global_colour_gate`** — scope the gate. It applies only to parts whose maquette label lies under
   the tabard's dilated (6 px) front-view silhouette: pelvis, both thighs, both shins, both coat panels (front view; in
   the rear view: pelvis and thighs only). Helmet, hook, chain, belt, forearm/hand leather and boots are excluded (their
   rust/copper is protected material). Threshold ΔE76 < 12 to the tabard median. Gate: zero such pixels owned by those
   parts in every sampled motion frame; report the count per part and clip.
2. **`TODO_DESIGN_sparse_value_reference_front_thigh_far`** and **`…_rear_thigh_far`** — when a part has fewer than 40
   visible pixels, its value reference is the **same view's near thigh** visible trouser pixels (same material) with the
   median L* lowered by 6 (the far side sits in shadow); chroma/hue from the trousers material. Record the substitution
   in the fill provenance.
3. **`TODO_DESIGN_rear_torso_lean`** — rear view only, `strike` and `manacle_pin`: torso rotation
   `0.07 rad × hit` (lean into the punch, away from the camera; head and both arms inherit it), plus the fist-side
   shoulder raised `Vector2(0, -3) × prep` during the wind-up. Pelvis forward drive unchanged; front view unchanged.
   The fist stays fully occluded (keep the round-5 gate at zero).

Proof: focused tests, gate tests, full suites, validation ok, rest identity 0, zero magenta, the scoped colour gate at
zero, motion gates. List the windowed commands with capture path `/private/tmp/rr-02-mq3-render-v06`.
