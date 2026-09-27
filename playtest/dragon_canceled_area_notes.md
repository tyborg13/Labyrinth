# Canceled dragon area presentation

A resolved area with no affected tiles previously inherited the generic `to`
position, which is the player when Crownfire has no surviving Fire or Faultline
has no surviving Worldspines. That created a false impact on a safe tile.

`DragonPresentation.tiles` now allows this fallback only for a genuine
single-target melee/ranged/push/pull delivery. Explicit empty area/focus sets
remain empty; nonempty areas preserve every resolved tile. Combat is unchanged.

`tests/dragon_area_presentation_test.gd` uses actual declared Crownfire and
Faultline warnings, removes their Fire or spires through existing rules, and
resolves the turn. It checks empty warning/impact sets and unchanged player HP.
Actual Skyhook and Cinder Breath resolutions protect the single-target fallback
and complete held-area behavior.

`tests/dragon_canceled_area_probe.gd` prepares eight production RunScene images:
warning and canceled cast for each boss in normal and reduced motion, all at
1920×1080 / 100%. During actual animation it checks that the safe player tile
receives no elemental depth layer, HP stays unchanged, and the reduced rig is
at rest. These are staged counterplay witnesses, not encounter balance studies.

Validation: focused actual-resolver test PASS through the official 4.6.1 task
runner, run `dragon-boss-encounters-milestone-rewards-1790533825546276000-30109`.
The separately requested Zekarion cutout test also passed, run
`dragon-boss-encounters-milestone-rewards-1790533835937684000-30144`.

Native Metal/Mobile addendum `output/dragon-revision/canceled-area-01.json` exited
0 and validated all eight images. Every image was inspected at original
1920×1080 resolution. Cast snapshots show Crownfire/Faultline preparation and
recovery without an impact on the safe player tile `(2,4)`; HP remains 20/24.
Reduced motion keeps the same absence of target FX and a rest-pose rig. The
witnesses report empty `effect_tiles`, only the boss origin in `depth_tiles`,
and no failures. Stable proof: `/private/tmp/dragon-canceled-area-proof-01`.

Independent review by the cutout repair worker found no blocker. Its launcher
namespace suggestion was applied. The reviewer independently inspected all eight
original-resolution images, the actual-resolver and Zekarion PASS logs, empty
impact/depth witnesses, and unchanged reviewed source hashes. Scoped runtime and
pixel signoff is recorded in `playtest/dragon_feedback_static_review_20260927.md`;
this is not whole-branch signoff. `git diff --check` passed.
