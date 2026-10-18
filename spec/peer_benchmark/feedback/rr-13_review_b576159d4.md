Two **Low** test gaps remain:

1. **Pinned residuals make two regression assertions vacuous.** [test_rr10_rear.py:97](/private/tmp/labyrinth_codex/review/rr-13-b576159d4/tests/test_rr10_rear.py:97) and [test_rr10_tucks.py:105](/private/tmp/labyrinth_codex/review/rr-13-b576159d4/tests/test_rr10_tucks.py:105) assert only a nonempty result. Ignoring the regression replacement specifically for ward-19 or death-30 **survives** because the baseline `[2]` already satisfies that assertion. Actual replacements produce `[5, 3]` and `[6, 2]`. **Fix:** assert those regression results, or explicitly require additional seam damage beyond the baseline residual.

2. **Continuation-generation guards lack regression coverage.** Removing named-cover clipping, garment-bounds clipping or connectivity filtering from [joint_continuations.py:18](/private/tmp/labyrinth_codex/review/rr-13-b576159d4/tools/humanoid_cutout/joint_continuations.py:18) **survives** both continuation tests. Those tests read committed textures without invoking `domains()`. In a connected-cloth fixture, removing cover clipping produces **47 texels outside the named cover**, versus zero normally. **Fix:** add direct `domains()` tests covering all three constraints.

The requested fixes otherwise check out:

| Mutation | Result |
|---|---|
| Restore whole-hole locality; lower boundary threshold to 70% | Caught |
| Remove torso/head limits | Caught, including normal/death boundaries |
| Relax success, error, hash or inventory evidence guards | Caught |
| Alter any of the six layout copies | Caught |
| Grow either historical residual to `[3]` or `[2, 2]` | Caught |
| Remove the eight repaired fills | Caught |
| Ignore the two pinned regression replacements | **Survived** |
| Remove the three continuation-generator constraints | **Survived** |

The committed assets add exactly **37 front-torso, 26 near-sleeve and 31 rear-torso texels**, all under named covers. Original opaque RGBA pixels are unchanged in case and production assets. Both rest views remain **0 px different**; deformation fields and all **1,258 pose records** are unchanged.

The exception list contains exactly **43 approved flags**, including front death 27–30. Historical owner snapshots match their prior-commit originals. The historical PNGs support fixture regeneration; the `.png.import` files follow the repository’s intentional metadata policy.

Both committed sample and native-review bindings match all **297 current inputs**. CPU posing remains diagnostic; native acceptance still calls the GPU gate. Raw native captures are absent here, so GPU verification is limited to committed receipts and bindings.

All **88 requested Python tests passed**. Headless rr10 passed **10 checks**; rr07 passed **73,057**. No changed GDScript, Windows typed-array violations, unrelated tunables, dead code or stray files found. All mutations were restored; the checkout is clean.

CHANGES REQUESTED