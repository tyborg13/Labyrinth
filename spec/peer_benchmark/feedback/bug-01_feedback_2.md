# bug-01 feedback 2 — native floor proof still fails; I need per-case native diffs

I ran both commands under the director lock. Logs: `output/bug-01/director_native/bug01_native2.log` and
`bug01_mut.log`.
- **Proof:** exit 1. `RESTORED EMPTY BOARD NATIVE: FAIL`, 106 cases, 38 `pixel_differences` (30 errors are
  "complete board pixels must match original submissions"): HP only, active door, same door gains exit label,
  locked door, door hidden, the elemental floor cases at 0.0/0.38/0.79/1.0, combined effects, partial reactivation
  and new room.
- **Mutation:** exit 1, as expected, but it fails for the same reasons, so it proves nothing yet.

Freezing the clocks didn't remove the differences, so the earlier hero-idle explanation was only part of it. These
may be real presentation differences between the cached floor and a freshly drawn one, for example alpha blending of
overlays at 0.38/0.79, premultiplied alpha in the cache texture, or a missing layer.

1. **Native diagnostic dump.**
   - Add an opt-in mode (env `LABYRINTH_BUG_01_DIFF_DUMP=1`). For every case with differences, it writes
     original-submission, restored and fresh captures cropped to the board, plus a diff mask and a JSON with the
     differing pixel count, bounding box, max per-channel delta and mean delta.
   - Keep it under `user://bug_01_diff/`, and print the absolute paths.
   - Hand me the exact command. I run it and give you the outputs; you can't render natively.
2. **Classify each case once you have those outputs.**
   - Actor/animation residue: freeze it properly.
   - Precision-level difference (max delta ≤ 2 per channel, with the cause stated): it may be tolerated only with a
     documented per-pixel tolerance that the mutation still fails.
   - A real visual difference a player would see: that's a production bug. Fix it with a regression.

   Don't add the tolerance until the dump has shown which kind each case is.
3. The mutation must fail for the mutated pixel alone: make the error list name it distinctly.

For now, deliver step 1 only, with headless checks passing, so I can run the dump. Then we finish.
