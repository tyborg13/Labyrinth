# rr-15 feedback 2 — rear tube targets (director data) and a reach gate

Thanks for the trace: it showed the director's data was the cause. Decisions:

1. **Per-view key overrides (new; small generic extension).** The protected motion file
   (`spec/peer_benchmark/staged/rr-11/motion_tracks.json`, already edited in this worktree) now has
   `clips.<clip>.view_keys.<view>` maps. In that view, each listed channel replaces the base clip's channel; other
   channels and the other view are untouched. Implement it in the compiler and runtime, documented in the
   motion/anatomy schema. Re-import the file byte for byte.
   - Rear jab: tube_tip forward 209 / lift 50 at contact (0.45), 178/43 at the hold (0.65); wind-up unchanged. The contact
     target (231, 61) sits at about 90% reach toward the rear facing, so the cap clears the silhouette to the right.
   - Rear tether: tube_tip forward 206 / lift 63 from 0.35 to 0.8, target (228, 50).
   - The director sampled every path at 1000 steps: the minimum shoulder-to-target distance is 66.2 (jab) and 64.3
     (tether), against the 56.47 minimum reach. Front data unchanged.
2. **Reach gate (new):** no keyed two-bone target, sampled densely, may fall inside its chain's minimum reach (with a 4
   px margin) or more than 2% beyond its maximum. Run it for both views; a mutation that restores the old rear jab must
   fail it.
3. Keep the direction gate. Front output stays byte-identical; the Seer is unchanged.

Proof: headless focused tests, gates and mutations, the SFX programs and the registration audit. Then stop with the
windowed commands; the director recaptures and inspects. Commit nothing.
