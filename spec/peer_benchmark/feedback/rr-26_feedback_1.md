# rr-26 feedback 1 (director): fix the fragments the strict rule found

The strict rule stays: no new detached fragment of any size. The owner has repeatedly flagged stray pixels and
breakages, so fix the components your census found. Scope:

1. **Mimic** (your case): rear `mirror` frames 12 and 19, pixel `(223,312)`.
2. **Hoarfrost Seer** (case `experiments/cutouts/hoarfrost_seer/**`, `assets/units/hoarfrost_seer_cutout/**`; owned for
   this fix only): front `move` frames 11, 12 and 15 near `(265,372)`; rear `move` frames 10 and 13 near `(244,350)`;
   rear `death` frame 76 at `(304,251)`.
   - Find each fragment's owner piece and why it detaches: an outline texel left on a moving piece, a tuck or
     continuation edge, or a hem anchor.
   - Fix it at the root, with own-piece continuation or tuck coverage or by correcting texel ownership. Keep each
     piece's painted silhouette intact.
   - The Seer's poses, motion and rest identity stay exactly as they are. The owner approved them.
3. **Arc Thrall:** leave it. Its rear `move` frame 14 pixel belongs to the old mq7 cut, which rr-24 replaces. The
   director re-runs your census on rr-24's Thrall after it lands.
4. Re-run the five-rig strict census. Mimic, Seer, Mirror and Capacitor must report zero unmatched detached components.
   List the exact windowed sequences for the Mimic and the Seer. Focused tests only.
