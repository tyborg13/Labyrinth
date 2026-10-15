# ux-03 — round 5 (re-review of db82e2cfb: findings 1–8 fixed; two blockers)

Work on top of db82e2cfb. Do not commit.

1. **Never cover the hovered card, overflow included** (blocker). At 1536×864, Witchglass Lantern and Hollow Puppet at
   position 0 put the Collision panel over the hovered card (46×19.7 px). In the overflow (impossible-fit) case, align
   the short last row **away from the hovered card** (right-align it when the owner sits left of the block's centre,
   left-align when right of it). Covering the banner and a non-hovered card's corner stays allowed only in this case.
   Probe: check every panel against the hovered card in all cases, overflow included (remove the skips at
   `glossary_tooltip_probe.gd:151-158`, `:170`, `:193`).
2. **Card-structure check out of the permanent suite** (medium). Move `_card_structure` (the exact 309-card,
   per-panel body-line comparison with `tests/glossary_card_structure_before.json`) to the standalone
   `tests/glossary_test.gd` as this unit's one-time migration proof. The suite keeps coverage plus a base-independent
   invariant: a one-line contextual tooltip yields zero body lines (for every card).
3. Test the controller call site: removing `run_scene.gd:3112-3113` (`prepare_navigation_focus` call) must fail a test.
4. Handoff: list the exact run_scene lines touched (3044, 3112-3113, 11064, 11154, 11849, 16023, 16375, 16393, 22095).

Proof: glossary tests, suite, probe logic at 1920/1670/1536 (no overflow skips), UI lint, full suite; the three windowed
probe commands.
