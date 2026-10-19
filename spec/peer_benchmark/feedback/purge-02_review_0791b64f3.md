- **Medium — Scrolling clips badges on fully visible cards.** [magic_purge_overlay.gd:143](/private/tmp/labyrinth_codex/review/purge-02-0791b64f3/scripts/magic_purge_overlay.gd:143). With 15 identities, two copies each, scroll offset 276 leaves the last card fully visible at y=609–885, but its badge extends to y=905 beyond the viewport’s y=889 boundary. **Fix:** manage badge visibility as a whole at scroll boundaries, and add duplicate-overflow cases at intermediate scroll positions.

- **Medium — The clipping guard misses detached badge remnants.** [pile_copy_badge_checks.gd:69](/private/tmp/labyrinth_codex/review/purge-02-0791b64f3/tests/helpers/pile_copy_badge_checks.gd:69) skips badges whose parent card no longer intersects the viewport. At offset 296, a badge spans y=241–293 across the viewport’s y=275 top edge, yet the guard returns `[]`. **Fix:** inspect visible badge bounds independently of parent-card intersection; test partially visible and completely offscreen badges.

- **Low — Large copy counts break attachment and padding.** [pile_dialog_view.gd:117](/private/tmp/labyrinth_codex/review/purge-02-0791b64f3/scripts/pile_dialog_view.gd:117). `×1000` expands the Label to 63×52, shifts the ring centre 5.5 px, and exceeds the right viewport boundary by 7 px. **Fix:** use a fixed 52×52 medallion host with separately centred text, reserve its rendered overflow, and extend count coverage beyond 12.

- **Low — Centre-disc opacity lacks regression coverage.** [pile_dialog_view.gd:20](/private/tmp/labyrinth_codex/review/purge-02-0791b64f3/scripts/pile_dialog_view.gd:20). Changing alpha from `0.92` to `0.10` survived the input test. **Fix:** verify the disc’s actual paint colour and opacity.

[Reproduction script](/private/tmp/purge-02-review-scroll.gd):

```sh
python3 tools/godot_task_runner.py --task-id purge-02-review --stream -- godot --headless --path . --script /private/tmp/purge-02-review-scroll.gd
```

All requested focused checks passed: magic deck tests, pile viewer, headless text-fit, UI identity lint, registration audit and its 32 regressions. Header sizes are correct; combat retains separate, unbadged copies. The pile test’s assertions and both helpers have registered execution paths. No new Windows typed-array violations, misplaced gameplay tunables, dead code, or stray files found.

Independent source mutations: **10 caught, 1 survived**. Caught singleton/missing badges, inset, ring tint, title size, both padding dimensions, disabled viewport guard, combat deduplication, and combat badges. Disc alpha survived. Shipped text-fit and viewport mutations were caught.

All mutations were restored. Checkout is clean at the reviewed HEAD.

CHANGES REQUESTED