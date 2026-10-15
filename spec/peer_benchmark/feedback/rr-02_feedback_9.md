# rr-02 — round 9 (Codex peer review of 83c3a65fa: CHANGES REQUESTED)

Work on top of round 8. Do not commit. Full review: /private/tmp/labyrinth_codex/review/rr-02-83c3a65fa.md. Finding 2
(categorical masks through screenshot validation; hard-coded 300 s timeout) is round 8's scope — make sure it is fully
covered. Fix the rest:

1. **Blocking — the leg-value gate checks previews, not rendered textures.** [motion_gates.py:255](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py:255) reads `hidden_fills/*.png`. Changing runtime `hidden/rear/thigh_far.png` to RGB 220, then refreshing motion samples, still passed all 458 frames. Actual median L* was **87.76**; the gate reported **15.96** from the unchanged preview. Rest identity remained exact. **Fix:** measure runtime/rendered fill pixels using ownership and hidden-region provenance, and verify preview/runtime agreement.


3. **Medium — the committed derived artifacts do not reproduce completely.** Fresh build/fill reproduced runtime images and layouts, but changed both ownership recipes, `build_report.json`, and the baseline. Ownership differs at **532 front pixels and 227 rear pixels**. [segmentation.json:4](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/experiments/cutouts/chainbound_gaoler/mq3/segmented/front/segmentation.json:4) already references the fresh recipe’s hash, not the committed recipe’s hash. [build_report.json:2333](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/experiments/cutouts/chainbound_gaoler/mq3/build_report.json:2333) reports 76/58 parts instead of 83/62. **Fix:** regenerate these artifacts together and add a complete gaoler rebuild comparison.

4. **Medium — the next creature’s camera transform is unsupported.** [projected:133](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/tools/maquette_cutout.py:133) assumes front/rear yaw 0°/180°, whereas [Gust Shrike uses 135°/315°](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/spec/art_identity/maquettes/gust_shrike.py:119). Its head projection differs by **287.6 raw pixels**, so valid exported joints would fail [the camera check](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/tools/maquette_cutout.py:719). Depth ordering shares that assumption. **Fix:** support explicit view transforms or authoritative exported projection/depth metadata, with a wing/tail fixture.


6. **Low — the documented headless command fails.** [README.md:140](/private/tmp/labyrinth_codex/review/rr-02-83c3a65fa/experiments/cutouts/chainbound_gaoler/mq3/README.md:140) supplies a relative case path, producing “Missing cutout image” errors. The absolute-path version passed all 460 poses. **Fix:** use `$PWD/.../cutout.json`.

Director note on 4: rr-03 (Gust Shrike, maquette yaw 135°/315°) is next, so the tool must take the maquette's actual
view transforms (or authoritative exported projection/depth metadata) — add a wing/tail fixture. On 5: the rear torso
lean (0.07 rad × hit) and shoulder lift (−3 px × prep) are director values that live in the case recipe data; the
generated sampler must read them (test that changing them changes motion).

Proof: focused/gate/full suites, a complete gaoler rebuild comparison (every derived file identical), the rendered-fill
leg gate, and the windowed sequence ending MOTION GATES: PASS and MAQUETTE_PROOF: PASS (capture
`/private/tmp/rr-02-mq3-render-v09`).
