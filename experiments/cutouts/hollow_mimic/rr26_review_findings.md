**Blocking — detached fragments can pass without source provenance.** [rest_space.py:105](/private/tmp/labyrinth_codex/review/rr-20-901d32789/tools/humanoid_cutout/rest_space.py:105) calls `detached_metrics()`, which exempts tiny dark components near the body. The native gate adopts those metrics at [gates.py:431](/private/tmp/labyrinth_codex/review/rr-20-901d32789/tools/humanoid_cutout/gates.py:431).

Removing the bridge pixel from an originally connected skinned sleeve tip leaves a detached black pixel. It passes with `source_components=[]`, `stray_components=0`, `exempt_outline_components=1`, and no frame errors. [Reproduction script](/private/tmp/rr20-review-detached-repro.py).

**Fix:** strictly reject every unmatched detached component in the provenance classifier. Add this regression case; it stays inside the immutable paint mask, so the outside-paint guard cannot catch it.

Mutation results:

- Real 2×2 hole inside paint: **caught**.
- Pocket touching one tuck texel: **caught**.
- Novel bright detached speck: **caught**.
- Newly detached dark sleeve fragment: **survived**.
- Three independently disabled paint/tuck/provenance guards: **caught by tests**.

Verification: 124 focused rig tests, 111 art-identity tests, all three SFX sync programs, and registration audit passed. The census reproduced all **16,732** passed pockets. Eight largest pocket samples passed an independent inverse-source check and visual inspection. Seer/Thrall retained poses match exactly; Mirror’s changed sampler produces identical transforms. Capacitor gates pass. Protected director imports, own-piece continuations, compact records, Windows typed arrays and unrelated shadow records checked successfully.

Fresh native captures and both density-rest rebakes remain pending, as recorded. No windowed runs occurred. Checkout is clean; no commits or other checkouts were touched.

CHANGES REQUESTED