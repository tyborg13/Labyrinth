# purge-02 feedback 3 — review fixes (final round)

The Codex review of 0791b64f3 asked for changes. Director decisions:

1. **Scroll in whole rows (Medium; decided).** At intermediate scroll offsets a fully visible card's badge is cut at the
   viewport edge. The grid now scrolls in whole-row steps (row pitch = card height + 20 px gap) for mouse wheel,
   trackpad, keyboard, controller and focus-follow. The viewport shows exactly two complete rows plus the 24 px badge
   room, so no row is ever partly visible and every visible badge is whole. Also clamp the scroll range to whole rows.
2. **Guard checks badge bounds on their own (Medium).** `tests/helpers/pile_copy_badge_checks.gd` ~69 skips badges whose
   card no longer intersects the viewport. Check every badge's visible bounds independently of its parent card: each
   is fully inside or fully outside the viewport. Test at every reachable scroll position, with 15 identities × 2 copies.
3. **Fixed badge host (Low; decided).** Use a fixed 52 × 52 medallion host with the text centred separately. Text: 22 px
   for ×2–×9, 18 px for ×10–×99, and "×99+" at 16 px for 100 and above. The ring centre never moves. Extend the count
   coverage to 2, 9, 10, 99 and 100+.
4. **Disc opacity coverage (Low).** Assert the centre disc's actual paint colour and alpha (`INK_0` at 0.92), so the
   alpha mutation fails.

Proof: the magic deck tests, the pile viewer test, text-fit, the mutations, the UI identity lint and the registration
audit. Then stop; the director recaptures. No full suites. This is purge-02's last fix round.
