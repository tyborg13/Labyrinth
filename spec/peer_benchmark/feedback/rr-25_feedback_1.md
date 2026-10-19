# rr-25 feedback 1 (director; Codex review of 5369d4cb6)

Masks, ownership, the crucible's hidden fill, the coverage gates and the reference figures all checked out. Fix these,
focused tests only:

1. **Blocking: newly detached dark fragments pass without provenance.** `tools/humanoid_cutout/source_space.py:113`
   keeps the outline exemptions that `detached_metrics` applied, and `gates.py:440` accepts those metrics. Removing the
   bridge of an originally connected dark tip gives `certified=[]` and `exempt_outline_components=1` with no error,
   for both rigid and skinned owners. The reproduction is `/private/tmp/rr25-review-detached-repro.py`.
   - Director rule (decisions 2026-10-19): a detached opaque component passes only when it is detached in the
     approved painting and moves rigidly with its owner, whatever its size or darkness.
   - Reject every unmatched detached component in your classifier, and add the review's case as a regression for both
     rigid and skinned owners.
   - If the strict rule now fails any Mortar frame, fix it at the root with own-piece continuations, tuck or ownership.
     No exemptions.
   - rr-26 is making the same rule strict in `rest_space.py` for the Mimic. Keep your change minimal and generic so the
     two can be unified at merge.
2. **Low: duplicated walk tunable.** `assets/units/slag_mortar_cutout/renderer.gd:5` hard-codes `0.85`, duplicating the
   compiled motion. Make `walk_segment_frames()` use `Action.frames_for("slag_mortar", "move")`, so cadence has one
   source.
3. Hand back with the focused results and the windowed sequence.
