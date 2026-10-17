# mq-03 — round 3 (owner review of the lancer r3 paint-over)

Owner: "Middle looks directionally correct, but the loin cloth probably needs another stab and he's actually more
straight on now than before ... Making all the characters in the correct 45 degree isometric view?"
1. **Facing (blocking, builder-level):** the v2 builder leaves the base body facing the camera. Every v2 maquette must
   face the board convention used by all rigs: the figure's forward is +X (board lower-left) so the FRONT render shows
   chest/visor turned toward the image's lower-left at 3/4 (as r1/r2 and the shrike/bloomer/wisp do), and the REAR
   render shows the back turned toward the upper-right. Fix in the builder (base asset yaw + armature forward axis), not
   per spec. Add a check that fails if the front render's facing is frontal: e.g. project the body's forward axis and
   require it to point down-left in screen space within the board's 45° convention, and compare left/right silhouette
   asymmetry of the torso.
2. **Loin cloth / tabard:** replace the two flat panels with ONE cloth-simulated front panel hanging from the belt,
   about as wide as the hips at the top, flaring slightly, splitting into 3–4 ragged strips from mid-thigh, hem just
   above the knees, with natural folds; keep the two short tassets over the hips. (Source reference: the blue split
   tabard under the belt.)
3. Re-run the fit against the source after the facing change (proportions stay; the silhouette will change because the
   view is now 3/4 again — the gate must still pass) and deliver front/rear parts + clay, overlay, gallery via the bridge.
The bridge is running again. Do not commit.
