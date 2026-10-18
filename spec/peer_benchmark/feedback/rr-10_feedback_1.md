# rr-10 feedback 1 — front review (director windowed proof at 963d00f61)

The director ran `rr10_proof.sh rest`, `idle` and `native`.
- **Idle is right.** Only the upper body moves, 2 px, and the staff arm, robe and feet are byte-still. Keep it exactly.
- **The v2 cut reads much better than rr-07.** No robe tearing or windmilling staff.
- **The native gates fail (815 errors)** and `sheets` refuses to run. Most errors are gate false positives; four real
  defects remain.
- Evidence crops (4×, magenta background):
  `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/rr10_zoom.png`.
  If you can't read it, regenerate it from `proof/native/front_<clip>/pose_<n>.png`: mark 30 and 56, bolt 27, death 64,
  ward 29, move 29.

## 1. Re-import the director data (changed)
`spec/peer_benchmark/staged/rr-10/motion_tracks.json` on `codex/peer-benchmark` (integration worktree
`/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark`):
- `mark.hand_far.lift_px` peak 16 → 26;
- `land.hand_far.lift_px` peak 8 → 12.

Copy it byte for byte and recompile. Nothing else in it changed.

## 2. Gate calibration (false positives; the spec intent is unchanged)
- **Exposed tuck.** A tuck is painted continuation, so seeing it in motion is allowed. That is the point of the still
  staff arm sliding under the collar. Replace "the tuck stays covered" with this check: every exposed tuck or fill
  pixel passes the dark-slab gate, and there are no outline-coloured pixels inside the exposed area.
- **New holes.** The rest pose already has 373 px of enclosed negative space (staff vs robe, arm vs body). That space
  legitimately changes shape when pieces move. Count a new hole as a defect only where two connected pieces meet: an
  enclosed transparent region within 3 px of a joint seam (shoulder, elbow, wrist/grip, belt or robe top, neck,
  hem-to-foot). Negative space between pieces that aren't joined may change freely.
- Rerun the mutations: the 2 px-tuck and robe-split mutations must still fail.

## 3. Real defects to fix
1. **Stray dark specks around the staff hand and the far sleeve** (mark 30, bolt 27, ward 29, move 29, death 64):
   isolated dark outline-coloured pixels and tiny clusters floating just outside the sleeve, hand and staff. Find the
   source (the far sleeve mesh edge, the hand's outline, or a hidden fill's outline) and remove it.
   - Add a stray-pixel gate: no opaque connected component of ≤ 8 px detached from the main silhouette, and no
     outline-dark pixel more than 1 px outside every piece's posed silhouette.
   - It must fail on the current frames.
2. **A thin dark line across the robe just below the belt** (mark 30, about 25 px wide). It is a seam or fold
   artifact. Find it and remove it; the stray-pixel or slab gate should catch it.
3. **Staff depth.** The staff is held on the body's far side.
   - Front view: when it tips (mark, bolt) its lower shaft draws OVER the robe. It must draw behind the torso, sleeves
     and robe, and only the gripping hand_far draws in front of it.
   - Rear view: the staff is on the near side, so it draws in front of the body.
   - Make the depth per view in data and test it.
4. **`TODO_DESIGN_rope_belt_ownership_mask` (decided).**
   - The whole hanging rope belongs to `torso`: the knot and both tails down to their tips. The mask is every pixel of
     the rope colour (warm orange-brown, hue about 15–40°, chroma ≥ 0.08) 8-connected to the belt band, plus its 1 px
     dark outline.
   - The robe under the tails gets hidden fill (painted robe cloth, dark-slab gate), so the 2 px idle bob reveals
     cloth, not a gap.

## 4. Rear
Still pending mq-06 (the rear maquette is being rebuilt) and the director's repaint. Keep the rear data-driven as
before; you'll be resumed with the paths.

## Proof
- Headless gates, mutations and the full suites as before.
- The exact windowed commands again. The director reruns `native` and `sheets`; the sheets must now build.
