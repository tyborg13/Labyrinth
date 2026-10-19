- **Medium — Scrolling can strand focus on an invisible card.** [magic_purge_row_scroll.gd:54](/private/tmp/labyrinth_codex/review/purge-02-a8045f714/scripts/magic_purge_row_scroll.gd:54) hides artwork while retaining button focus. With 15 identities, focus the first card and wheel down: offset becomes 296, the focused card is fully offscreen, and Enter or controller A selects it without revealing it. **Fix:** reconcile focus after manual page changes, or reveal the focused row and consume the first activation event. Add interleaved scrolling/activation regressions. [Reproduction](/private/tmp/purge-02-review-focus.gd), [results](/private/tmp/purge-02-review-focus.log).

- **Low — Disc coverage bypasses the actual draw entry.** [pile_copy_badge_checks.gd:69](/private/tmp/labyrinth_codex/review/purge-02-a8045f714/tests/helpers/pile_copy_badge_checks.gd:69) calls `paint_disc` directly. Replacing [the `_draw` call](/private/tmp/labyrinth_codex/review/purge-02-a8045f714/scripts/pile_dialog_view.gd:53) with `pass` survives both the input test and shipped mutation runner. **Fix:** add a spy regression exercising `_draw` and verifying its delegation to the checked painter.

The previous badge-clipping, independent-bounds and large-count findings are fixed with regressions. The 52 px host, 22/18/16 px bands and ×99+ cap pass; changing disc alpha to 0.10 is caught. Whole-row scrolling and ordinary focus-follow pass, including an additional five-row probe with 320 keyboard/controller navigation events.

All requested magic deck tests, pile viewer, headless text-fit and shipped mutations passed. Registration audit passed for 748 scripts, its 32 regressions passed, and the new script/helper have registered execution paths. UI identity lint passed.

Independent mutations: **13 caught, 1 survived**—the disconnected disc draw described above. [Mutation results](/private/tmp/purge-02-review-mutations/results.json). No new Windows typed-array violations, misplaced tunables, scope creep, dead code or stray files found.

All mutations restored; checkout clean at `a8045f7143c71716c323912081a02e515d2820fd`.

CHANGES REQUESTED