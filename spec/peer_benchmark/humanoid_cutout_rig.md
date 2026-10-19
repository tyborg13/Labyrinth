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
- **Negative space vs holes** (director, 2026-10-19; generalises the Mirror's air rule to every humanoid):
  - An enclosed transparent pocket in a presented frame is natural negative space when every one of its pixels maps
    (inverse pose) to air in the approved painting: outside every piece's painted area and tuck. Examples: air between
    a skirt hem and a thigh, or between the hair and the shoulders.
  - It is a hole, and fails, when any of its pixels maps into a piece's painted area or tuck, so a surface is missing.
    A joint tearing open is always a hole.
  - Gates report every pocket they pass, with its bounds.
  - A detached opaque component fails only when it isn't already detached in the approved painting. A painted speck
    that is separate at rest (a hair tip) moves rigidly with its owner piece and passes.

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
- **Walking: both legs step, on the protagonist's walk model** (owner, Mirror 2026-10-19: "One leg is kind of
  shimmying and the other is mostly still like he's limping along"; replaces the stride + trailing shuffle):
  - Reference: `scripts/protagonist_cutout/motion.gd` (`walk_foot_state`, `_solve_leg`, `_fit_walk_pelvis`).
  - A `move` clip declares a `gait` block (§4). The compiler expands it into foot, pelvis and hand tracks; the
    director keys only the rest (torso, head, cloth).
  - Every humanoid walks **6 steps per tile, rest to rest**: an opening half step, four full steps, and a closing half
    step that brings the feet together at rest on the next tile. The `near` foot leads, in both views. The root moves
    linearly over the whole clip.
  - Each foot's cycle is 60% stance (the hero's `WALK_STANCE_FRACTION`). A stance foot is world-planted. A swing foot
    follows the hero's Hermite path and lifts `lift_px × sin(πu)^1.35`.
  - Walking lanes narrow 70% of the way from the painted ankle toward the thigh (hero). A foot changes lane only in
    swing: its first swing narrows it, its last swing restores the painted lane.
  - Leg length follows screen depth, the hero's 2D foreshortening approximation:
    `scale = clamp(1 + (ground.y − lane_anchor.y) / leg_length, 0.78, max)`. `max` is 1.22 for skinned legs and 1.14
    for rigid-piece legs.
    - Skinned legs scale along each segment and keep the painted width (hero `_segment_transform`).
    - Rigid-piece legs keep every piece rigid. The scale spaces their joints along the leg: the overlap shrinks first,
      then air opens between pieces. A shorter leg slides the pieces together.
  - Pelvis: an authored settle per step in the hero's shape: contact, down at 0.16 of the step, passing at 0.5, up at
    0.8. The two half steps use half the amplitude, and the curve is 0 at both ends of the clip. Then the hero's pelvis
    fit lowers the pelvis only as far as both feet need. The pelvis never rises above rest.
  - The arm opposite the swinging leg swings forward and the other back, by `arm_swing_px` at each landing.
  - Knees keep the existing policy: they bend toward the facing; a rest knee within `knee_policy.near_straight_deg` of
    straight counts as straight.
- **Walk gates** (both views, both legs, every frame of `move`):
  - Every stance is planted: target error ≤ 0.7072 px and zero frame-to-frame shift.
  - Every swing peaks at a knee bend of at least 15°, and at its apex the swing knee bends more than the stance knee.
    Lift-off and touch-down frames are naturally near-straight.
  - No leg overreaches after scale and fit.
  - The pelvis fit adds at most 6 px. Report the maximum fit and the maximum total pelvis drop per view.
  - Rigid-piece legs: report the largest opened air per joint; it fails above 3 px.
  - The `stride` and `trailing` leg roles are retired.
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

### Gait block (`move` only)

```json
"gait": {
  "model": "protagonist_walk",
  "steps_per_tile": 6,
  "lead": "near",
  "stance_fraction": 0.6,
  "lift_px": 6,
  "lane_narrowing": 0.7,
  "leg_scale_max": 1.22,
  "settle_px": {"contact": 1.5, "down": 3.0, "passing": 0.8, "up": 0.4},
  "arm_swing": {"near": {"bone": "hand_near", "px": 3}, "far": {"bone": "hand_far", "px": 3}},
  "max_fit_px": 6
}
```

- **Schedule.** With `n = steps_per_tile − 1` and stance half-travel `a = stance_fraction / n` (tile fractions; the
  root moves linearly, so clip phase equals hip travel):
  - Step `i` (1…n) moves the lead foot on odd `i` and the other foot on even `i`, to `i / n` of the tile. It lifts at
    `previous + a` (step 1 lifts at 0) and lands at `i / n − a`.
  - The closing step moves the foot still behind from its last position to 1.0. It lifts at `last + a` and lands at 1.0.
  - For 6 steps: lead swings 0–0.08 (to 0.2), 0.32–0.48 (to 0.6) and 0.72–0.88 (to 1.0); the other foot swings
    0.12–0.28 (to 0.4), 0.52–0.68 (to 0.8) and 0.92–1.0 (to 1.0).
- **Swing path:** the hero's Hermite (`walk_foot_state`), parameterised by the swing's `u`, with the endpoint tangents
  matching the planted speed; lift `lift_px × sin(πu)^1.35`.
- **Lane:** the foot's lateral anchor moves from its painted ankle toward the thigh's x by `lane_narrowing`, eased over
  the foot's first swing, and back over its last swing.
- **Leg scale and pelvis fit:** §3. `leg_scale_max` defaults to 1.22 for skinned legs; rigid-piece legs declare 1.14.
- **Settle:** a pelvis drop per step between consecutive landings (`contact` at 0, `down` at 0.16, `passing` at 0.5,
  `up` at 0.8, smoothstep), half amplitude on the two half steps, 0 at the clip's ends.
- **Arm swing:** per side, a two-bone target bone (`hand_<side>`, or a case target such as the Thrall's `tube_tip`).
  At each landing, the arm opposite the landed foot is at `+px` forward and the same-side arm at `−px`; half amplitude
  on the half steps; 0 at both ends. Omit a side to leave that arm alone.
- **Generated channels:** `root.forward_px` (linear 0 → 1, `fraction_of_step`), each foot's `forward_px` (`world_step`),
  `lift_px` and lane, `pelvis.lift_px`, and the `forward_px` of each arm-swing bone. Director keys in the same clip may
  add any other channel (torso, head, cloth, hand lift). A key on a generated channel is a compile error.

### Per-view channel overrides

An authored clip may add `view_keys`, a map from a declared view (`front` or
`rear`) to a partial channel map with the same syntax as `keys`. The effective
map is `keys` with that view's entries replaced. Replacement applies to the
whole channel, including its phases/interpolation; it does not append keys or
add values. Unlisted channels and every other view retain the base data.
`forward_mode` and `release_at` entries follow the same replacement rule.
Role names and projected angle signs resolve **after** this merge.

The compiler emits the resulting complete `view_tracks[view][clip]`; runtime
sampling uses only that facing's effective tracks. Raw `view_keys` does not
leak into shared clip metadata. A view-specific release policy is emitted in
`view_release_at[view][clip]`; other clips retain the existing shared
`clips[clip].release_at` representation. Rigs without overrides keep their
compiled bytes and arithmetic. Author files and their imported copies remain
byte-identical; the compiler never rewrites director keys.

For example, rr-15 rear jab replaces only `tube_tip.forward_px` and
`tube_tip.lift_px` through `clips.jab.view_keys.rear`. The front uses the base
channels. The supplied rear contact values are 209/50 at .45 and hold values
178/43 at .65; the wind-up remains the base sequence.

### Dense target reach gate

Every keyed two-bone target, including hands, custom terminals and visible-leg
feet, is checked in both views before the runtime reach clamp. Sample 1000
equal phase intervals including both endpoints, plus every authored key phase.
With rest segment lengths `L1` and `L2`, require:

- target distance ≥ `abs(L1 - L2) + 4` source px;
- target distance ≤ `(L1 + L2) × 1.02`.

Measure the unclamped FK target in its animated parent frame, including the
effective per-view channels and the existing step/scale modes. A solve that
clamps successfully does not make an unreachable authored path pass. The gate
reports each path's extrema and phases; it does not change keys, stretch a
chain, or infer a per-figure exception. The positive forward-direction gate
remains separate and retains its strict dot-product requirement.

## 5. Per-figure assignment (initial; each unit confirms it)
| Figure | Robe / cloth pieces | Held item and weapon arm | Idle weapon arm |
|---|---|---|---|
| Seer | robe = skirt_near ∪ skirt_far; the collar fuses into the torso | staff = shaft ∪ crystal, far hand | still (staff planted) |
| Thrall | loincloth on the pelvis; the collar ring fuses into the torso | the iron tube sheathes the near forearm (part of the near sleeve; capped, no hand) | lagged bob |
| Herald | tabard on the pelvis; the belt fuses into the torso; cape_near and cape_far are banners on the torso | horn, far hand | lagged bob |
| Gloam | cape_near and cape_far drapes on the torso; the carapace fuses into the torso | the claws follow their forearms | near arm lagged |
| Lancer | cloak on the torso; the split loin cloth on the pelvis; the scarf/mantle fuses into the torso | spear, far hand | still if the butt rests on the floor, otherwise lagged |
