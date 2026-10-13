# itb-03 — Threats at rest v2: order discs at the health bar, intent chips at the feet

## Header
- Owner verdicts (2026-10-12): the floating pills over heads don't look right; keep the per-enemy order number but next
  to the health bar; keep a small attack chip at the enemy's feet that shows when it can hit you now; remove the ground
  compass emblem under enemies; area danger tiles must show whose they are; chips must not look like default boxes —
  they must match the game's visuals; chips stay at the feet (never relocate to the health bar).
- Approved mockups: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/mockups/threats_v2/option_D_open_crop.png` and
  `option_D_crowded_crop.png` (ignore the crawler chip docked at its health bar in the crowded image — rejected; see 4),
  `option_C_pulse.gif` (pulse timing). Generator with exact drawing: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/mockups/threats_v2/make_d.py` (`chip`,
  `order_disc`).
- Base: `codex/peer-benchmark` (director gives the commit). Owned files: `scripts/intent_badges.gd` (rewrite to the new
  look), `scripts/threat_tiles.gd` (zone tags), `scripts/combat_board_view.gd` (stop drawing the ground compass emblem at
  rest; draw calls/plumbing only), `scripts/run_scene.gd` (≤ 15 lines), `tests/suites/threats_at_rest_suite.gd` +
  `tests/threats_at_rest_test.gd` + `tests/threats_at_rest_probe.gd` (update to v2; SubViewport capture),
  `spec/threats_at_rest.md`, `spec/visual_design_system.md` (one bullet).
- Rules: presentation only; Umbra privacy unchanged (hidden enemies show nothing); reduced motion; Windows typed-array
  rule; `TODO_DESIGN_<name>` only if something below is impossible.

## Change (numbered, testable)
1. **Remove** the floating intent pills over heads and the ground compass emblem/ring under enemies at rest (keep the
   compass code only if Details/hover views still use it).
2. **Order disc** beside each acting enemy's health bar: 24 px circle centred 14 px left of the health-bar frame's left
   edge, vertically centred on the bar; fill `#15100c` at 94%, 2 px ring GOLD `#c9a25e`, numeral Crumble UI 15 px
   GOLD_BRIGHT `#f0cf8a`. An enemy acting twice shows "1·3" in a capsule of the same style that grows to fit. Enemies
   that won't act before the hero's next turn show no disc. Order = the existing projection (unchanged).
3. **Intent chip at the feet** (the HUD resource-chip language, see `make_d.py chip()`):
   - Medallion: 32 px circle, fill `#3a2d1f`, 2 px ring, 1 px inner keyline at half the ring colour's brightness, the
     intent's primary action icon (ActionIconLibrary) at 24 px centred.
   - Plate: starts 6 px right of the medallion centre, height 22 px, fill `#140f0b` at 92%, 1 px top and bottom rims in
     the ring colour; the primary number in Crumble UI 19 px TEXT `#efe3c8` starting 24 px right of the medallion
     centre; one secondary rider (same priority as itb-01: Push/Pull → Immobilize → Freeze/Chilled → Shock → Bleed →
     Expose → Stagger) as a 16 px icon + 15 px number after a 6 px gap; the plate ends 12 px after the content with a
     10 px diamond finial in the ring colour. Intents with no number (move-only): medallion only, no plate.
   - Ring colour: GOLD `#c9a25e` normally; GOLD_DIM `#7c6240` for defence/support/move intents.
   - **Danger state**: when the intent will hit the hero's current tile (or, during a card/move preview, the previewed
     hero tile), ring, rims and finial turn DANGER `#c7453b` and a soft halo pulses behind medallion and plate:
     Gaussian blur radius 6 px, DANGER at alpha 35%→75%→35% over 1.1 s (sine); reduced motion: steady 55%.
4. **Placement** (always at the feet): anchor = the unit's base/feet point; default medallion centre = anchor +
   (26, 4) px (lower right). If the chip's rect would overlap another unit's sprite bounds, another chip or a terrain
   prop's bounds, use the mirrored lower-left placement (chip's right edge 26 px left of the anchor, same orientation).
   If both overlap, keep the lower-right placement and draw it above everything. Chips never move to the health bar.
5. **Area zone tags**: for area/pattern attacks, the threat tiles keep their current style and gain one 20 px tag on the
   zone tile nearest the attacker: fill `#46140f` at 94%, 2 px DANGER ring, the attacker's order numeral in Crumble UI
   13 px GOLD_BRIGHT. Single-target attacks: no tag.
6. **Keep** (from itb-01): threat tile style, hover/focus isolation (others dim to 40%, including discs and chips),
   Details [I], Cancelled/Redirected callouts, controller paths, previews re-aiming chips and tags live.

## Proof
- Suite: disc order and "1·3"; chip content per intent type; danger state true/false cases (adjacent melee, ranged in
  range, area including the hero tile, attack aimed elsewhere, preview moving the hero out of danger); placement:
  default, flip on overlap with a unit/prop/chip, both blocked → default; zone tags only on area attacks.
- Windowed probe (SubViewport, 1920×1080): open board (the itb-01 fixture), crowded board (harrier at hero+(3,1) in
  front of the crawler at hero+(2,0); a wooden box in front of the acolyte), danger pulse at peak, reduced motion, a
  preview that removes danger, Umbra-hidden enemy.
- Keep green: full suite, enemy intent preview, compass suite (adapted if the compass is no longer drawn at rest),
  movement undo, en-01..03 suites.
