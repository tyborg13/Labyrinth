# Relic chest rigid prop case v01

This is a two-part rigid prop, not a character rig. The production closed 96×96 painting supplies unchanged stationary body and exterior lid pixels. `source/open_generated.png` is the untouched built-in image-generation result; its explicit prompt is alongside it. Only its newly revealed underside and cavity are used. The source generation was accepted for its matching material, left end/front projection and complete empty interior.

`register.py` records source ownership polygons and the three affine registration landmarks (back-left hinge, back-right hinge, front-left rim), exports four transparent layers on one padded 128×160 canvas, and asserts byte-identical RGBA reconstruction of the original closed sprite. The logical 96×96 body sits at (16,40). The original front and base never move. `registration.json` binds source/output digests and exact landmarks. Run the script from any working directory to regenerate only this case's production parts.

The runtime `scripts/relic_chest_prop.gd` holds the registered diagonal back hinge fixed. The lid's exterior gives way to the separately painted underside while its projected depth rises. There is no character skeleton, viewport allocation, actor facing change, or idle loop. Closed, partial, fully open and Reduced Motion states use the same body registration and existing board shadow. Opening uses a 0.10s preparation, 0.52s hinge rise and 0.12s settled hold. Reduced Motion presents the full open pose for 0.12s. Relic options appear after this hold. The shader/material is the board's existing prop treatment.

Native board proof and input/lifetime assertions are owned by `tests/treasure_presentation_probe.gd`, run with the required task/visual runners at 1920×1080/UI100. This specialized prop case preserves the cutout workflow's ownership, hidden-material, native-registration and actual-integration proof contracts without introducing the humanoid-only 255×255 skeleton/character playback adapter.

## Validation

`python3 experiments/cutouts/relic_chest/v01/register.py` passed the closed RGBA reconstruction assertion and wrote SHA-256 digests for both sources and all four output layers. `tests/treasure_presentation_probe.gd` additionally samples 101 projections per lid, asserting both hinge landmarks stay fixed and all painted bounds stay inside the padded canvas. Its headless assertions passed on 2026-09-22, including natural map-to-room entry, both native input handoffs, claim/save ordering, retained delivery effects, post-claim resume and cancellation by reload.

Run the actual game integration proof with:

```sh
python3 tools/visual_probe_runner.py tests/treasure_presentation_probe.gd --project . --task-id premium-visual-polish-across-effects-and-interface --no-headless --min-images 15 --expect-size 1920x1080 --result-manifest /private/tmp/treasure-sequence-proof.json --timeout 120
```

For a short opening-cycle reel, run `tests/treasure_opening_reel_probe.gd` through the same visual runner. It captures the real production tween at native resolution with wall-clock timestamps in `timing.json`; images are written only after motion finishes. Encode consecutive frames with those durations to preserve observed timing.

Skeleton2D bone-chain integrity, skin weights, character walk/attack/facing clips, equipment attachment sockets and AnimationPlayer save/reload checks do not apply to this rigid board prop: none exists in the production module. No generic cutout `verify-render` result is claimed. Equivalent evidence is the exact closed-pixel reconstruction, explicit part ownership, painted hidden surfaces, shared registration canvas, fixed hinge/bounds assertions, source/output hashes, and native closed/partial/open/Reduced Motion/game-flow captures. Scene lifetime and saved-run reload are tested in the real run scene.
