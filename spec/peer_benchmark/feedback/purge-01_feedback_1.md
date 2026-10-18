# purge-01 feedback 1 — confirm step

The director ran your windowed probe (12 captures, all PASS) and inspected them at full resolution. The grid states are
right: keep them exactly as they are. Evidence: `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/purge_r0/` (see `scavenger_confirm_unaffordable.png` and
`scavenger_confirm_affordable.png`).

Fix the confirm step:
1. **No show-through.** At 35% modulate the whole dialog panel turns translucent, so the shop behind it (shelf labels
   MAGIC/GEAR, ware names like Whetstone, Lamp Oil, Parrying Dagger) bleeds through around the confirm card. Keep the
   dialog panel and its frame fully opaque; dim only the dialog's contents: the card grid to 30% modulate and the
   header row to 60%. No shop or campfire content may be visible inside the dialog's rectangle.
2. **Soft crimson halo, not a block.** The glow is a filled red rectangle a few px larger than the card. Replace it with
   a feathered halo that follows the card's outline: `Palette.DANGER`, peak alpha 0.30 at the card edge, falling to 0
   over 56 px outward, nothing drawn under the card body. Reduced motion: the same halo, static.
3. **`TODO_DESIGN_EMPTY_PURGE_LAYOUT` (decided).** The overlay should never open on an empty deck. When the deck has
   no spells, disable the Scavenger's "Purge a spell" plate with the tooltip "You have no spells to purge." (the
   Campfire already disables its Purge choice). Keep the old empty fallback in the overlay only as a defensive guard.
   Add a test for the disabled plate.

Proof: the headless magic deck, input, text-fit and mutation tests. Give the windowed probe command again; the director
reruns the captures. No full suites.
