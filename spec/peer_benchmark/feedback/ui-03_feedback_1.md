# ui-03 feedback 1 (director; Codex review of 75fc0bdcc)

Seal clicks, persistence, E precedence, Iron Lung payment, the multi-target lock, preserved aim, the copy and the
analytics all checked out. Fix these, focused tests only:

1. **Blocking: the right stick cancels a drag instead of charging.** At `run_scene.gd:2384`, controller activity
   triggers the drag cancellation before Empower routing. With a real routed right-stick event, `drag=0, charged=false`
   became `drag=-1, charged=false`.
   - Keep drag ownership for the right-stick Empower through the mouse-to-controller handoff, so it charges the dragged
     card.
   - Add a regression that uses routed input, not a direct method call.
2. **Medium: two guards lack effective tests.** Removing the options refresh (`card_empower_controller.gd:72`) or the
   Quick Wits charge clear (`run_scene.gd:14801`) still passes the committed suite.
   - Drag test: start uncharged, charge mid-drag, then commit and assert the card played empowered.
   - Live Quick Wits tests: identical survivors keep or clear their charge correctly, and an immediate reshuffle or
     redraw never carries a charge onto a new copy.
3. **Low: obsolete helpers.** `_empower_command_text` and its cost helper (`run_scene.gd:34064`) have no production
   callers, and `card_empower_controller.gd:6` preloads an unused Router.
   - Remove them.
   - Assert the real seal tooltip and state instead.
4. The renderer stills and the clip are the director's job (queued). Hand back the same windowed commands.
