1. **Medium — promotion accepts stale material proof.** [maquette_cutout_build.py:99](/private/tmp/labyrinth_codex/review/rr-05-c87609f84/tools/maquette_cutout_build.py:99) trusts saved `ok` flags without binding them to current textures. In an isolated case copy, recolouring hidden support preserved promotion eligibility, while recomputing the material gate rejected a **1,239-pixel derived slab** at `rear/shell/0014`. Bind the certificate to current inputs and reject mismatches before copying production assets.

2. **Medium — exact-tie alternatives admit nonexistent transparent texels.** [raster.py:95](/private/tmp/labyrinth_codex/review/rr-05-c87609f84/tools/maquette_motion/raster.py:95) permits negative neighbor indices, leaving those candidates transparent. Reproduction: render an opaque 12×12 image translated by `(0.5, 0.5)`, then erase its first row and column. The **23-pixel deletion fails ordinary matching but passes tie-aware matching**. Clamp sampling at texture boundaries or restrict alternatives to legal neighbors; add this regression.

3. **Low — a registered test fails in a clean checkout.** [test_maquette_native_alpha.py:53](/private/tmp/labyrinth_codex/review/rr-05-c87609f84/tests/test_maquette_native_alpha.py:53) creates a temporary directory beneath nonexistent `output/rr-05`. The 163-test run had one `FileNotFoundError` and two skips. Creating that parent makes all three tests in the affected module pass. Create it explicitly or use the system temporary directory.

My seven additional mutations produced **five caught, two survived**:

| Mutation | Result |
|---|---|
| Accept third tie colour | Caught |
| Explain candidate flips during held frames | Caught |
| Weaken slab threshold from 3×3 to 4×4 | Caught |
| Allow outline donors | Caught |
| Bypass feature integrity | Caught |
| Erase opaque texture-edge pixels | Survived |
| Recolour support after certification | Survived |

[Reproduction script](/private/tmp/rr05_review_experiments.py) · [Mutation results](/private/tmp/rr05-review-mutation-results.json)

Verification passed: production headless runtime **40,178 checks**, density check, registration audit, 28 runner tests, and 111 art-identity tests. Both rigs retain director masks and motion unchanged, with **0-pixel rest differences** in both views. No new Windows typed-array violations or unrelated Shrike/Lancer edits found. No windowed runs performed; all mutations were removed and the checkout is clean.

CHANGES REQUESTED