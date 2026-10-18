Three findings prevent signoff.

1. **Blocking — Delivery can pass failed native capture checks.** [quality_delivery.py:68](/private/tmp/labyrinth_codex/review/mq-04-3d3be3d02/spec/art_identity/maquettes/blender/quality_delivery.py:68) ignores capture `passed`, facing results and ownership checks. Setting those fields to false in a copied Thrall delivery still produced exit 0 and `MAQUETTE_QUALITY_DELIVERY: PASS`. [curate_delivery.py:145](/private/tmp/labyrinth_codex/review/mq-04-3d3be3d02/spec/art_identity/maquettes/blender/curate_delivery.py:145) likewise accepted failed collision/capture reports. **Fix:** require current, passing build and capture reports, bind them to the cold-build proof, and add rejection tests.

2. **Medium — Regeneration verification ignores part maps.** [regenerate_delivery.py:63](/private/tmp/labyrinth_codex/review/mq-04-3d3be3d02/spec/art_identity/maquettes/blender/regenerate_delivery.py:63) compares only clay PNGs. Controlled builder output containing correct clays and completely red front/rear part maps still passed full `--verify`. **Fix:** canonicalize and compare both part maps, reject missing/mismatched maps, and retain fresh four-figure regeneration results.

3. **Medium — Frozen r3 clay PNG bytes were changed.** [curate_delivery.py:78](/private/tmp/labyrinth_codex/review/mq-04-3d3be3d02/spec/art_identity/maquettes/blender/curate_delivery.py:78) repacks every clay. All four frozen clays differ from their recorded r3 file hashes; Thrall front changed from `26f0030444d4aef0…` to `83ebf2860499ab41…`. All eight Seer/Thrall clay/parts images match the paint-over kits’ pixel hashes after the kits’ green compositing, so this is an encoding change. **Fix:** retain the original frozen PNG bytes and normalize temporary copies for regeneration comparisons.

Mutation results: **5 caught, 4 survived**. Caught: simulation, per-view cloth, side-label and sewn-cache guards, plus corrupted parts in final delivery. Survived: the three verifier failures above and removal of required-part rejection from the 61-helper-test suite.

Verification passed: 114 focused tests (2 skipped), 111 art-identity tests, 670 full Python tests (63 skipped), baseline delivery gates and retained legacy compatibility evidence. All figure inventories match their manifests and remain below 6 MB. No changed GDScript, tracked caches, Blender files or out-of-scope paths were found.

Fresh native regeneration was refused because the bridge excludes this disposable review root. All experiments were reverted; HEAD is unchanged and the checkout is clean.

CHANGES REQUESTED