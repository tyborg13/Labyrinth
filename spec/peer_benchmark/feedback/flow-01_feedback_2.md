# flow-01 feedback 2 — peer review CHANGES on cf9d7737a

Review: `spec/peer_benchmark/feedback/flow-01_review_cf9d7737a.md`. Fix all four findings:

1. **Blocking: older cleared-boss saves get stuck after an entry-save failure.**
   - When a save predates `section_transition_reward`, reconstruct or migrate the already-claimed reward summary
     before the transition starts. Never grant anything twice.
   - The reversal must land on a reward screen with a working CONTINUE.
   - Cover failure → retry and failure → quit → resume for both old-format and new-format saves.
2. **Medium: tests.**
   - Assert music handoff and playback-start counts after the transition completes and deferred callbacks have run:
     exactly one arrival.
   - Compare the failure notice against the literal string
     `Could not save. Your rewards are still here; try Continue again.`, not the production constant.
   - Kill the four survivors: the one-time arrival guard, the already-entered section guard, the claimed-reward retry
     bypass, and destination validation.
3. **Medium: dead references.**
   - Update `tests/section_map_review_probe.gd` to exercise the automatic transition and the history navigation that
     follows it. No `_continue` or "Next section".
   - Update `spec/section_map.md` to describe the automatic advance.
4. **Low: cursor in the demo.**
   - Use `CursorFeedback.set_glyph_visibility_suppressed()` for the transition, and restore it on completion and on
     exit.
   - This applies in-game too, not only in the demo: no cursor glyph should show over the title card. Input is
     contained during the transition anyway.

Re-run the transition suites and the updated probe. I re-run the windowed proof and the demo.
