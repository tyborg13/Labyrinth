# art-01 feedback 1 (director)

Approved structure (sheet, check, registry). Three changes:

1. **TODO_DESIGN_TOP_OVERFLOW_POLICY**: never crop. If the processed sprite is taller than 240 px or wider than 251 px,
   BOX-resize it uniformly (premultiplied, then the same alpha binarization) so it fits 240 × 251, place it as usual
   (centre x 128, bottom y 246), and record `fit_scale` in OUT.json and the sheet's metric table (INFO row).
2. **Off-size raw images**: image generation sometimes returns a canvas other than 1024² (one pilot came back 1254²,
   i.e. blocks of ~4.9 px). `process` uses K_eff = K × raw_width / 1024 (raw must be square; reject otherwise) and
   BOX-downscales by K_eff (non-integer allowed: Pillow `resize(..., Image.BOX)` on the premultiplied channels to
   round(w / K_eff) × round(h / K_eff)); record `k_eff` in OUT.json. Test with a synthetic 1280² K=4 input.
3. **`canon-sheet --out PATH [--view front|rear]`**: one image of every canon creature (front or rear) and canon object
   in `canon.json`, each at in-game draw scale × its art_scale on the backdrop row(s), labelled, at 1× and 2× NEAREST
   (same drawing rules as the sheet's rows A/B). The independent judge gets this beside each candidate sheet.

## Proof
Tests (add cases for 1–3), `check` report, a `canon-sheet` image path.
