# Unit 3: Scavenger stall

Target: `mockups/scavenger.jpg`. Today's screens: `baseline/scavenger_entry.jpg`,
`baseline/scavenger_pack.jpg`, `baseline/scavenger_sale_selected.jpg`.

Code: `scripts/scavenger_shop_view.gd`, plus `scavenger_ware.gd`,
`scavenger_action.gd`, `scavenger_panel.gd` and `scavenger_materials.gd`.

Today every element sits on the same heavy timber-and-brass plaque, so the eye
has nowhere to land and the painted stall disappears. Keep the authored leather,
timber and brass material for diegetic surfaces (the speech leather, the pack and
detail trays, the mode plates). Strip it from the labels that float on the scene.

## Change

1. **Title.**
   - Remove the big `SCAVENGER'S WARES` plaque.
   - Replace it with text on the scene, top centre over the shelf:
     - an eyebrow `THE SCAVENGER'S STALL` (letter-spaced UI 15, `TEXT_2`, dark
       drop shadow);
     - the title `Wares & Oddments` (display about 50 px, `GOLD_BRIGHT`,
       3 px black shadow plus a soft dark halo so it reads over the curtain).
   - Keep the existing title node or test hooks if tests read the title text;
     update tests to the new string if needed.
2. **Embers.**
   - Replace the `EMBERS 720` plaque with a unit 0 stat chip (ember icon
     `assets/art/icons/ember.png`, value UI 26, caption `EMBERS`) at the top
     right.
   - Keep the currency sync and the purchase/sale count animation, if any.
3. **Category labels** (MAGIC / GEAR / ITEMS).
   - Replace the plaques with short painted brush strokes (reuse
     `assets/art/ui/turn_order_ink/brush_b.png` or `brush_d.png`) tinted deep
     bronze, `Color(0.33, 0.24, 0.15, 0.92)`.
   - Put the letter-spaced label on the stroke (UI 16, `GOLD_BRIGHT`, 0.2 em
     tracking, 2 px dark shadow).
   - Place them on the left post of each shelf row, as in the mockup.
4. **Prices.**
   - Replace each ware's name/price plaque with the approved hanging price tag
     (`assets/art/ui/visual_pass_4/price_tag.png`, about 118×60 on screen,
     hanging from the shelf lip under the ware).
   - Write on the tag in dark ink (`#3a2616`, UI 19): a small ember icon plus the
     number only.
   - Show the ware name as a separate label above the shelf lip: UI 17 `TEXT`
     with a dark shadow, for gear and items. Cards show their own name, so card
     wares get the tag only.
   - **States:**
     - *Unaffordable:* the tag turns faded and greyed and the number turns
       `DANGER`. Keep the existing tooltip.
     - *Sell mode:* the pack tray uses the same tag showing `+N`, with the ink
       number in a dark green (`#2f5a24`).
5. **Wares.**
   - Card wares render about 15 % larger, filling more of their cell. The cell
     layout, focus and hover remain.
   - Add a soft warm lantern pool behind the shelf (a radial light about 16 %
     alpha) and a gentle vignette at the screen edges, so the stall glows from
     within. Both are under the UI and above the backdrop.
6. **Dialogue.**
   - Keep the leather material but shrink the panel to about 520×170 under the
     Scavenger.
   - Put the speaker name as an eyebrow `THE SCAVENGER` (`GOLD`), then the line
     in quotes (body about 23 px, `TEXT`).
   - Keep the typewriter or entry behaviour if any.
7. **Modes and Leave.**
   - Render `Browse wares` and `Sell from pack` as one joined two-segment toggle
     (the active segment raised with the ember underline).
   - Move `Leave` to the far right as a separate quiet plate.
   - Keep the controller labels and focus.

## Keep

- **Behaviour:**
  - all buy/sell/inspect/paging logic;
  - the purchase and sale flight and receipt effects;
  - the detail panel and its card pager;
  - pack filters;
  - the NPC cutout and its motion;
  - reduced-motion behaviour;
  - controller inspection;
  - all text strings other than the title.
- **Scavenger art:** the pre-existing `scavenger_glowup_probe` failure ("Head,
  gripping hand and carried pack articulate separately") is a cutout issue
  outside this unit. Leave it as is.

## Proof

- Update `tests/scavenger_glowup_probe.gd` and `tests/scavenger_shop_probe.gd`
  expectations as needed.
- Capture fresh 1920×1080 screenshots of:
  - entry;
  - mode hover and pressed;
  - the pack (all filters);
  - a sale selected;
  - a purchase;
  - an unaffordable ware;
  - the empty pack;
  - controller inspection;
  - reduced motion.
- Keep the scavenger, merchant and loadout tests green.
