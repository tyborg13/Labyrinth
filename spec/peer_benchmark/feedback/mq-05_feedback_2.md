# mq-05 feedback 2: review fixes (review 7c3b99203)

The review is in `spec/peer_benchmark/feedback/mq-05_review_7c3b99203.md` in the integration worktree. The director
committed your round-2 state as be0fe927f and merged integration (HEAD 7c3b99203). Work on top.

1. **Fit reports must bind (Medium).**
   - `delivery_validation.py` validates `fit_report.json`: it must pass the thresholds, be bound by hash to the current
     spec and native capture, and its IoU must equal a recomputation during final verification. Do the same in
     curation.
   - The reviewer's failed/zero-IoU and stale-hash mutations must fail for all three figures.
2. **Tick far-third toe off the painted footprint (Medium).**
   - The rear contact projects about 14.4 source px outside the approved silhouette. Reconcile that leg's distal path
     with the approved painting and the protected joint contract, so every toe tip lands on painted pixels.
   - Add a per-foot projection check: each contact within 2 source px of the painted silhouette, in both views.
   - Contact heights: every foot must support the body on one ground plane within the painting's own variation. Use a
     ground-plane tolerance of 0.05 m. Where the painting itself shows a lifted foot, document it as an explicit
     exception.
3. **Disabled modifiers must fail the surface gate (Medium).**
   - `sculpted_mass.py` requires the subdivision, displacement, bevel and fracture modifiers to be enabled for both
     viewport and render evaluation, and checks that the frozen evaluated geometry actually differs from the base mesh.
   - Add tests that each disabled modifier is rejected. Restore the two surviving guard removals as caught:
     `native_contacts` and `native_sculpted_sections`.
4. **Lancer regeneration proof (Medium).**
   - Retain a current-builder regeneration of the Frostglass Lancer that compares both clays and part maps, with input
     hashes, alongside the batch A comparisons.
   - The bridge allows the mq-05 worktree; run it through the bridge from your tree.

Also: the reviewer found fixed internal `rr-*` runner task ids in the broader maquette tests that block a full rerun.
Make those ids unique per run if they're in your owned tests; otherwise just report them.

Proof:
- the fit and contact tables;
- the mutation results;
- the Lancer and batch A regeneration results;
- the delivery, art-identity and full Python suites;
- curation sizes.
