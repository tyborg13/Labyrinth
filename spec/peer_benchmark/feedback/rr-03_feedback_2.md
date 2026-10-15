# rr-03 — round 2 (director decisions; make the gates pass)

Work on top of the current uncommitted state. Do not commit.
1. **`TODO_DESIGN_head_snap_clock`**: the rig samples at 30 fps; each idle head snap **starts** at its key time and
   completes two frames (2/30 s) later, then holds until the next key. Record it in the motion data.
2. **Specks (326/904 poses)**: fix at the cause — apply rr-02's traced island repair to this case (islands disconnected
   from their part's main component, including those connected at rest only through another part), then re-run. Gate stays
   at zero small disconnected components.
3. **Hidden-value gate** (front wing_near ΔL* 14.08, rear head 11.83, limit 8): the fills sample the wrong value
   distribution; use the same part's visible pixels (mid-tones included) as the value reference, and for sparse parts the
   rr-02 sparse-reference rule (same view, same material, nearest part). Keep the limit at 8.
Then refresh motion samples and gates headlessly (all gates PASS, design complete = true) and list the windowed
rest/render/verify/gates/proof commands plus the production board capture.
