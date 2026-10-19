# rr-26 feedback 2 (director): the Seer hem-tip policy

**`TODO_DESIGN_SEER_HEM_CONTINUATION_POLICY` (decided): fix it by attachment.**
- The five failing frames (front `move` 11, 12, 15; rear `move` 10, 13) are thin ragged robe-hem tips that skinning
  pulls one pixel away from the robe.
- Re-attach those tips: each tip texel takes the same skin weights as its 8-connected neighbour in the robe body, so
  it deforms with the robe and never separates. Don't bridge into source air, and don't change paint.
1. Rest identity and visible paint stay exact. Only the deformation of the re-weighted tip texels may change.
   - Report every pose row that changes, by frame and part.
   - The Seer's other 1,258 rows stay byte-identical.
2. Re-run the strict census: Mimic, Seer, Mirror and Capacitor at zero unmatched detached components.
   - The Thrall stays deferred to rr-24's cut.
3. The Mirror scope-guard failure comes from uncommitted authorised Seer files and clears once committed. Leave its
   assertion unchanged.
4. Focused tests only. List both windowed sequences.
