# purge-03 — Purge polish: scroll focus and disc draw coverage (fresh session on top of purge-02)

## Header
- purge-02 (tip a8045f714) built the medallion badge, the 24 px header and whole-row scrolling; the director accepted
  its windowed captures. It is past its fix-round cap, so this fresh unit finishes the last review findings
  (`/private/tmp/labyrinth_codex/review/purge-02-a8045f714.md`).
- Base: this worktree (branched from `codex/purge-02`). Owned: `scripts/magic_purge_row_scroll.gd`,
  `scripts/pile_dialog_view.gd` (no visual change), the magic deck tests and helpers.

## Change
1. **Focus follows the page (Medium; director decision).** Today, scrolling by wheel or trackpad can leave keyboard or
   controller focus on a card that is now off-screen, and Enter or A then selects it unseen. After any manual page
   change, if the focused card isn't on a visible row, move focus to the first card of the visible top row. Only a
   visible card can be activated. Keyboard and controller navigation still scroll to keep focus visible, as today. Add
   interleaved scroll-then-activate regressions (wheel, trackpad, keyboard, controller) with 15 and 20 identities.
2. **Disc draw coverage (Low).** Add a spy regression that exercises the badge's `_draw` and checks that it calls the
   checked disc painter, so replacing that call with `pass` fails.
3. No visual change: badge, header, layout and scroll pitch stay as they are.

## Proof
Magic deck tests, the pile viewer test, text-fit, the mutations (including the two above), the UI identity lint and the
registration audit. No full suites. Say if a windowed recapture is needed (it shouldn't be).
