# sfx-04 — round 5 (Codex peer review of 39141f2a3: CHANGES REQUESTED)

Work on top of 39141f2a3. Do not commit. Evidence: /private/tmp/labyrinth_codex/review/sfx-04-39141f2a3/output/sfx/
(review_frame_experiment.py, variable-frame.log).

1. **Variable frame durations break alignment** (blocking). `sfx_cue_router.gd:334` predicts future presentation frames
   from the previous frame's duration and the harness substitutes a constant duration (`sfx_sync_harness.gd:84`). With one
   33 ms frame every seven, swap and cast.arcane peak at +31.7 ms (outside 0..+30) and the meteor roar at −1.6 ms (early).
   Director rule: schedule against an **absolute deadline** in the presentation clock, set when the climax frame is
   submitted (not by extrapolating one frame interval); fire on the first process tick at/after the deadline and
   compensate lateness by skipping that much audio (`from_position += lateness`, keeping the ≥15 ms pre-peak and the 3 ms
   fade rule) so the peak still lands at climax + 15 ms; never fire early. Regression coverage with variable frames:
   periodic 33 ms spikes, steady 30 fps, 144 Hz, and random ±4 ms jitter — all aligned rows within 0..+30 ms
   (target +15 ±2 where frame timing allows).
2. **Dropped primaries pass coverage**: baseline successful-play counts separately from request counts and assert every
   required primary plays; distinguish legitimate cooldown / optional-layer drops explicitly (a mutant that rejects primary
   `hit.pierce` as "priority" must fail).
3. Remove the obsolete `trim_onset()` path in `tools/sfx_lab/sync.py` and unused constants (`REBUILD_ABOVE_MS`).

Proof: harness at 1×/1.5×/2× with fixed and variable frames, bank test, coverage, sound lab, full suite.
