# Graftwright workshop cutout

The workshop NPC uses the maintained character cutout workflow and production
protagonist Skeleton2D loader. The current editable case is
`experiments/cutouts/graftwright/v02`, forked from the approved `v01` idle.
Only the front workshop idle and the requested needle gesture are supported;
there are no combat, rear, walking or attack actions.

## Paint and articulation

Five bones own the fixed lower root, chest, masked head, occupied needle hand,
and lantern. The original 2.4-second coordinated idle sampler is unchanged:
chest 1.4 logical pixels, head an additional 0.9, slightly delayed hand 1.2 and
lantern 0.24. There are no periodic rotations or cloth waves. Reduced motion
restores the same assembly to its bind pose.

The larger gesture required an actual rigid forearm cutout. The original idle's
broad shared hand weights would stretch the palm, needle and neighboring coat
when rotated. `recipes/segment_gesture.py` instead assigns the original exposed
forearm, hand, needle and silk to a rigid painted mesh; the sleeve and coat return
to the torso. A fifth, lower mesh supplies only the concealed torso exposed when
the forearm moves. Its paint comes from the built-in ImageGen edit retained in
`source/hidden_torso_generated.png`; the exact prompt, source and output hash are
in `source/generation.json`. Only the explicit arm mask admits that generated
paint. The visible original portrait, face, hand, needle and costume are reused,
not replaced by the generated portrait. `source/gesture_ownership.json` records
the native ownership contours and the two-pixel antialias margin.

The `graft` action lasts 2.96 seconds: it eases the forearm around its painted
cuff at logical (140,146) to 0.40 radians during the first 0.43 seconds, holds
through card transfer, then recovers from 2.20 to 2.91 seconds during dissolution.
The palm, fingers and needle keep a rigid basis. The lower body, head and lantern
stay planted during this brief deliberate action. The view begins card transfer
after 0.44 seconds, preventing the card from preceding the gesture.

## Registration and integration

Logical registration stays 255×255 on the fixed 512×512 authoring canvas.
Production textures remain native 1448×1448 squares, with the original 1086×1448
portrait offset by (181,0). Original body placement and linear filtering remain
unchanged. Native source pixels are extracted rather than resampled; only the
hidden generated backing is registered to the original source rectangle.
The bench and traced countertop props retain their foreground precedence.
During the gesture only, `Skin_needle_hand` uses canvas layer 3 so the original
hand and needle visibly cross in front of the sacrifice panel; idle restores
layer 0. The case records the same discrete draw-order track for editable proof.

`recipes/segment_gesture.py` reconstructs this case using retained sources and
native ownership, with no sibling-case dependency. `--promote` explicitly copies
the reviewed layout and paint into `assets/units/graftwright_cutout/`. The case
and `scripts/graftwright_cutout/motion.gd` share an identical sampler. Production
uses only the production assets/scripts and common loader; export presets include
the JSON and raw-keep PNGs. `v01` remains intact as provenance. This is a paint
ownership/rig extension, so validation uses its actual new layout; an
animation-only `--protect art` claim would be inappropriate.

## Proof

The maintained validate/render/verify-render commands cover 48 idle samples over
two cycles plus 72 gesture samples, preparation/hold/recovery, fixed bounds,
rigid bases, editable scene tracks, and pixel-identical scene save/reload.
`graftwright_motion_probe.gd` covers the actual encounter, foreground occlusion,
unchanged idle sampler poses, the needle pose before transfer, stage ordering,
stationary completion and the reduced-motion transaction. The package smoke
exercises both clips in the unmodified non-editor runtime. Authoring board proof
is registration evidence only, not a claim of NPC combat integration.
