**Medium — required native replay evidence is unavailable.** Both `output/rr-05/{shale,wisp}-native` directories are absent, including their frame, pixel, and seam manifests. The certificates match current inputs, but I cannot independently recheck the full native captures at HEAD. **Fix:** provide the refreshed capture bundles and referenced PNGs, then rerun the native pixel gate and `native_errors` for both creatures.

The three code fixes pass:

- Recolour-after-certification rejects promotion before copying; fresh material verification detects the **1,239-pixel slab**.
- The **23-pixel boundary erasure** rejects; all three retained native fixtures pass.
- Native-alpha passes with `output/rr-05` absent.

Verification: **167 focused tests pass** (2 expected skips), both CPU pixel gates pass with zero errors, **111 art-identity tests pass**, and the full Godot suite passes in **412.9 seconds**, including **40,178 maquette checks**. Density and registration checks pass.

[Mutation results](/private/tmp/rr05-review-mutation-results.json): **12 caught, 0 survived**. No new Windows typed-array, tunable, dead-code, scope, or stray-file issues found in the rr-05 fixes. All mutations were restored; HEAD is unchanged and the checkout is clean. No windowed runs occurred.

CHANGES REQUESTED