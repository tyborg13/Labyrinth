# Saved-native alpha regression

The saved Wisp `front_death/pose_0070.png` has zero nontransparent pixels. Its sampled core alpha is `0.00287754205055535`; the old CPU coverage model rounded `255 × alpha` to 1 and invented a 13,007-pixel body mask. The preceding frame (`0069`) contains 12,995 nontransparent pixels.

`pixels.modulated_alpha` now represents the native 8-bit canvas modulation before texture-alpha coverage. Snap/clock rounding and every authored alpha/motion value are unchanged. The frozen native copies and their sampled transforms are under `tests/maquette_cutout/alpha_fixtures/` with source-paint hashes. The regression compares the complete composed mask exactly in both frames, then injects the previous rounding model and verifies its 13,007 phantom pixels.

Observed headless result:

```text
Ran 3 tests in 0.776s
OK
MAQUETTE REFERENCE MASKS: PASS (8 Godot image-operation masks = independent Pillow; no renderer claim)
MAQUETTE NATIVE ALPHA: PASS (death/0069 and /0070: 0px mask diff; old /0070 model invented 13007px)
```

The native capture now also records separate GPU-rendered rest/interior reference masks and their actual full-source transform in every pose. They live in private proof viewports. The gate checks their dimensions, source transform, body attachment, hashes and coverage, using the existing source-transform tolerances. The hard tear tolerance remains 0 pixels. Fresh native-after proof still belongs to the director.

Historical native-before measurements explicitly use the corrected CPU replay of that run's reference, because those old captures did not contain native reference-mask layers. Wisp's corrected native-before failing-pose count is 669; the earlier 671 included the two almost-transparent final frames.
