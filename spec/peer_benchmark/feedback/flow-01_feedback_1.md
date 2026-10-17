# flow-01 feedback 1 — director windowed review + save-failure decision

I ran the probe (10 captures, PASS) and recorded the demo clip. Evidence: `output/flow-01/director_r0/`
(captures, `v_sheet.png` from the clip around CONTINUE, `title_zoom.png`). The descent, title card and arrival
work. Fix these:

1. **TODO_DESIGN_SECTION_ENTRY_SAVE_FAILURE (decision).** Reuse the existing reward-continue failure pattern exactly.
   - If the section-entry save fails, the transition reverses: fade back to the cleared boss room and re-show the
     dragon reward screen in its post-claim state.
   - Set the existing notice text `Could not save. Your rewards are still here; try Continue again.`
     (`run_scene.gd:16115`). Its CONTINUE retries the whole transition.
   - Never grant rewards twice.
   - Test it with injected one-shot save failures: fail → retry → success, and fail → quit → resume.
2. **The "DRAGON VANQUISHED" banner lingers.** It stays on screen through the descent after the reward panel has
   faded (clip frames 4.3–4.8 s). The reward screen's title banner must fade out with the reward panel, in the same
   0.24 s (0.12 s with reduced motion).
3. **Title card legibility.** The `SECTION II` label (muted gold, 22 px) nearly vanishes on the bright backdrop, and the
   title has no separation from the painting (see `title_zoom.png`).
   - Put a full-width horizontal dark band behind the two lines: black at 50% alpha on the text block's centre line,
     fading linearly to 0 over 130 px above and below. It fades in and out with the text.
   - Draw the label in the bright accent gold token used for tags and keywords, at 24 px. Keep the letter spacing.
   - Both lines get the reward banner title's existing text shadow.
   - Keep the positions: label centred at y 470, title at y 540.
4. **Demo pacing.** The demo presses CONTINUE one frame after the reward appears.
   - Let the dragon's death animation finish naturally, show the reward screen for 2.0 s, then click CONTINUE with the
     real pointer, so the clip shows the real flow.
   - Keep 2 s in the entry room afterwards.
   - Hide the OS or debug pointer during the transition if the capture shows one.
5. Also reported: an existing dragon-rewards final-claim assertion fails before your change too. Leave it, and give its
   exact test file and assertion in the result. qa-08 is auditing tests that nothing runs.

Re-run the probe contract and the section-transition suites. For the full Godot suite, the serial runner is over
budget (qa-07 is fixing it), so a budget timeout alone isn't a blocker. Report it anyway.
