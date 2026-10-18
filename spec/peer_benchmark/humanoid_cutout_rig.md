# Humanoid cutout rig (v2)

Owner direction, 2026-10-18, on the Hoarfrost Seer rr-07 clip: "idle is still more of a rippling effect rather than an
independently cut out bob like our protag (all of our humanoids should generally bob like this), some of the animations
are cutting up nonsensically, it's like you're not even rigging him like we have been in the past, or maybe not cutting
him into small enough parts."

This spec binds every humanoid enemy rig built from a maquette: Hoarfrost Seer, Arc Thrall, Gale Herald, Gloam
Stalker, Frostglass Lancer and later humanoids. The reference rigs are the protagonist (`scripts/protagonist_cutout/`)
and the Dust Acolyte (`scripts/acolyte_cutout/`). Non-humanoids (Bloomer, Wisp, Shrike) keep their rr-05 rigs.

## 1. Cut: pieces bend where a body bends
| Piece | Bones | Kind |
|---|---|---|
| Head (hood, helm, mask) | `head` | rigid sprite |
| Torso: chest, belt, collar, scarf, mantle, fur, pauldrons, carapace | `torso` | rigid sprite. The collar is part of the torso and never moves on its own. |
| Arm or sleeve | `upper_<side>`, `fore_<side>` | one skinned mesh per arm, bending at the elbow |
| Hand or claw | `hand_<side>` | rigid sprite |
| Held item (staff with its crystal, spear, horn, rod) | `<item>`, a child of the hand at the grip | rigid; its sprites never move apart |
| Ground-length robe or skirt | `pelvis` (top), `hem_near`, `hem_far` (children of `root`) | one skinned mesh, as the Acolyte robe. Never split into halves that move separately. |
| Legs, where visible | `thigh_<side>`, `shin_<side>`, `foot_<side>` | one skinned mesh per leg over thigh and shin; the foot is rigid |
| Cloak, cape, banner, tabard, loincloth, veil | attachment bone, then `<piece>_mid`, `<piece>_tip` | one skinned mesh per piece, as the protagonist cape |
| Feet under a robe | `foot_<side>`, children of `hem_<side>` | rigid; they move with their hem anchor |

- Hierarchy: `root` → `pelvis` → `torso` → `head` and both `upper_<side>`. Legs, robes, tabards and loincloths hang
  from `pelvis`. Cloaks, capes and banners hang from `torso`. Hem anchors are children of `root`.
- Joints are covered, never patched. Every bend is either inside a skinned mesh or under an overlapping piece.
- Where one rigid piece slides over another (the torso over the robe top or the hips in the idle bob, the collar over
  the shoulder, the cuff over the wrist, the hood over the collar), the covered piece carries its own painted
  continuation for at least 3 px beyond the covering edge. This is the tuck.
- A moving piece never shows pixels outside its own painted silhouette plus its tuck, and the tuck stays covered.
- When a piece moves away, the area it uncovers shows the covered piece's painted continuation (hidden fill). That fill
  must read as the same surface: never a dark slab, an outline fragment or a sliver.

## 2. Idle: the protagonist's cut-out bob
Exactly three rigid groups. Nothing rotates, scales or deforms, and no mesh changes shape.
1. **Upper body**: torso, head, the free arm, and everything hung from the torso (cloak, cape, banners). It drops
   2 source px and returns.
   - The keys are the protagonist's, as (phase, px down), smoothstep: (0, 0) (0.18, 2) (0.55, 2) (0.91, 0) (1, 0).
   - Period 0.84 s, presented through the rr-05 stepped clock (10 fps holds, whole pixels).
2. **Weapon arm**: the whole arm with its held item, as one rigid group. It makes the same 2 px drop a beat later:
   (0, 0) (0.10, 0) (0.28, 2) (0.60, 2) (0.93, 0) (1, 0).
   - Exception: if the item's lower end rests on the floor in the rest pose (the Seer's staff), the arm and the item
     stay still. The body bobs beside them, and the shoulder slides under the collar.
3. **Lower body**: pelvis, legs, feet, the robe, and the tabard or loincloth. It stays still, and the belt slides over
   the top of these pieces.

- No head tilt, finger flex, breath, cloth sway, banner ripple or hip sway. A figure's character comes from its
  painting and its actions, not from idle wobble.
- Board actors keep their per-actor idle phase seed, so neighbours never bob in lockstep.
- **Proof:** in every presented idle frame, every visible pixel equals its group's rest pixel shifted by a whole-pixel
  offset. The mismatch count is 0.

## 3. Actions, move, hit and death: translation-led
- The body acts by moving, not by spinning. Translations of `torso` and `pelvis` carry the action.
  - Torso lean: at most 4° from rest. Head nod: at most 6° relative to the torso.
  - Death raises both limits: torso 25°, head 20°.
- Rotation lives in the arms:
  - Hands are placed by translation, and a two-bone solve bends the skinned sleeve at the elbow. The elbow keeps its
    rest bend side.
  - A held item keeps its rest world angle unless it has its own keys.
  - A long item turns at most 35° from rest (death excepted). Prefer a thrust along its axis to a sweep.
  - An item pivots only at the grip, except when it is released in death.
- Cloth deforms; it never pivots:
  - A robe moves only through `pelvis` and its hem anchors. The anchors move with steps, a lunge or the death spread.
  - Cloak, cape and banner chains trail the body by at most 4 px of follow-through, and they settle by the end of the
    clip.
- Feet and hem anchors stay planted, except in move and death.
- **Walking legs bend at the knee** (owner, Thrall 2026-10-18: "Walk is unnatural with no knee bend"):
  - Feet are two-bone targets for thigh and shin, and the knee keeps its rest bend side.
  - Knees bend toward the figure's facing: screen-left in the front view, screen-right in the rear view. A leg that is
    straight at rest declares this per view in its case anatomy (required; missing data fails).
    A rest knee within the case's `knee_policy.near_straight_deg` of straight (Thrall: 6°) counts as straight.
  - **Leg roles per view:** `stride` is the long camera-side leg, which plants world steps; `trailing` is the
    foreshortened leg, which follows the body with a small shuffle and is never world-planted. In flat 2D a
    foreshortened leg can't reach a planted foot one step away.
  - The pelvis never rises above its rest height in walks or actions; it dips after each stride landing. A planted foot
    stays within about ±0.08 of a step of the hip (Thrall geometry), or the near-straight legs overreach.
  - Knee gate: for each stride swing, the peak bend is at least 15°, and at the apex the swing knee bends more than the
    stance knee. Lift-off and touch-down frames are naturally near-straight.
  - Each foot steps on the floor: planted while in stance, lifted and carried forward in swing.
  - The pelvis dips 1–2 px at each passing, so the stance knee visibly flexes.
  - The swing knee bends more than the stance knee.
  - Use the protagonist's walk as the reference.
- **Shoulders attach at the real shoulder** (owner, Thrall: "Right arm doesn't seem to connect high enough to match
  the left"):
  - Each `upper_<side>` pivots at the top of the deltoid, under the collar or trapezius edge, on the maquette's
    shoulder line.
  - The near and far shoulders differ in height only by the 3/4 perspective.
  - Neither arm may appear to grow out of the chest side.
  - Measured on the maquette's front `joints_px.json` (1024 px): the far shoulder must sit higher than the near one,
    by `0.15 × |x_near − x_far|` ± 10 px.
  - mq-04 shipped the far shoulder below the near one for the Thrall (52 px low), the Gloam (56 px) and the Seer
    (12 px).
- **Hit** (0.5 s):
  - At 0.18: the torso moves 3 px back (opposite forward) and 1 px down, with a 3° lean back. It recovers by 0.6.
  - The head nods 4° back. The free hand trails 1 px.
  - The lower body stays planted.
- **Death:**
  - The upper body sinks into the lower body: the pelvis and torso translate down and forward.
  - The robe hem anchors spread outward by at most 4 px each.
  - The head bows, and a held item falls as one rigid piece about its floor end.
  - Then the existing fade plays.
- Presentation stays the rr-05 one: full frame rate in actions, whole-pixel translations, 1.5° rotation steps on
  rigid sprites. Skinned meshes are skinned from those snapped bone transforms. They resample only in actions, never
  in idle.

## 4. Channels (source pixels)
Motion data for v2 rigs uses source pixels, the same unit as the protagonist's 2 px bob. Each channel is per bone and
relative to its parent's animated frame.
- `forward_px`: along the facing's projected forward direction.
- `lift_px`: screen up.
- `inward_px`: screen-horizontal, toward the vertical line through `root`. It is the same meaning in both views and
  when mirrored.
- `lean_deg`: positive tips the top toward forward.
- `angle_deg` (held items): world angle offset from rest; positive tips the top toward forward.
- `release_at` (held items, death only): the phase where the item leaves the hand and pivots about its floor end.
- `forward_mode: "world_step"` (feet and hem anchors in move): values are fractions of the tile step in ground space.
  The runtime subtracts the root's progress, so a planted foot stays put on the floor.
- Hands with `forward_px`, `lift_px` or `inward_px` keys are two-bone targets, and so are feet (thigh, shin). Arms without hand keys follow forward
  kinematics: their `upper_<side>` translation moves the whole arm rigidly. The idle weapon-arm group uses this.

## 5. Per-figure assignment (initial; each unit confirms it)
| Figure | Robe / cloth pieces | Held item and weapon arm | Idle weapon arm |
|---|---|---|---|
| Seer | robe = skirt_near ∪ skirt_far; the collar fuses into the torso | staff = shaft ∪ crystal, far hand | still (staff planted) |
| Thrall | loincloth on the pelvis; the collar ring fuses into the torso | the iron tube sheathes the near forearm (part of the near sleeve; capped, no hand) | lagged bob |
| Herald | tabard on the pelvis; the belt fuses into the torso; cape_near and cape_far are banners on the torso | horn, far hand | lagged bob |
| Gloam | cape_near and cape_far drapes on the torso; the carapace fuses into the torso | the claws follow their forearms | near arm lagged |
| Lancer | cloak on the torso; the split loin cloth on the pelvis; the scarf/mantle fuses into the torso | spear, far hand | still if the butt rests on the floor, otherwise lagged |
