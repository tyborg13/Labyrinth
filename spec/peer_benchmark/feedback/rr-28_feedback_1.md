# rr-28 feedback 1 (director; Codex review of 60cf6c5da requested changes)

The tear closure was verified:
- all 31 Seer and 85 Mimic original pockets are covered;
- 1,658 frames have zero pocket, split-pocket or detached failures;
- density outputs are byte-identical;
- pose rows are exact.

One Medium. Focused tests only.

1. **Each recipe's clip list must be justified by tear evidence.**
   - `tests/test_rr28_continuations.py:74` derives the expected activation from the recipe's own `clips` list.
   - Appending `mark` to the Seer's `front.sleeve_near.clips` in `rr28/joint_continuations.json` and replaying the
     builder passes everything, although that recipe only has tear evidence for `move`.
   - Validate each recipe's clips independently against the recorded tear evidence (view, clip, frames). A clip with
     no evidence fails, naming the recipe and clip.
   - Add that coherent rebuild mutation as a regression. It must fail.
2. Don't change the recipes' texels or clips, or any data the director's windowed run is capturing. This is a test and
   validator change only, so the director's captures from `60cf6c5da` stay valid.
