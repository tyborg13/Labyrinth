# rr-24 feedback 2 (director; Codex review of 7cdcebb1e)

Collar priority, skirt depth, the re-pins and raw mq7b ownership all checked out. Fix these, focused tests only:

1. **Medium: continuations keep obsolete mq7 colours.** `rr24_build.py:159` keeps old hidden colours unless they
   contain green residue. In front jab frame 11, 46 exposed skirt-continuation pixels and 7 far-sleeve pixels use
   colours absent from their mq7b pieces.
   - Regenerate every hidden colour field from the current own-piece edge texels, keeping coverage.
   - Validate donor provenance: every exposed hidden texel's colour must come from its own mq7b piece.
   - Make `source_errors` catch the review's foreign skirt-colour mutation, which survived in both views.
2. **Medium: the native capture compares against the wrong rest source.** The build selects the cleaned
   `presentation.png` (`rr24_build.py:148`), but `tests/rr11/native_capture.gd:125` loads the raw `processed.png`. A
   correct render therefore gets "native rest mismatch" (2 front / 5 rear pixels).
   - Make the Thrall capture paths use the layout's `rest_source`.
   - Keep raw mq7b identity as its own assertion.
3. **Medium: walk crops don't fit their cells.** `rr24_crops.py:58` unions bounds across root travel before the 2×
   zoom, which gives 382 px front and 338 px rear, wider than the 320 px cells.
   - Stabilise each crop relative to its frame's root, so the sheet contract stays as it is.
   - Add the metadata-only reproduction as a test.
4. Note: shared code is getting a strict detached-component rule (rr-26). After your merge, the director re-runs that
   census on your Thrall, so keep the cut free of fragments that aren't detached in the painting.
5. Then list the exact windowed sequence again. Proof captures stay gitignored.
