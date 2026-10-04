# Unit 4: Graftwright atelier

Target: `mockups/graftwright.jpg`. Today's screens: `baseline/graftwright_entry.jpg`,
`baseline/graftwright_workbench.jpg`, `baseline/graftwright_preview.jpg`.

Code: `scripts/graftwright_view.gd`, `graftwright_choice.gd` and
`graftwright_thread_effect.gd`, plus the `graftwright_*.gdshader` files. The atelier
already has a cohesive violet-velvet and gilt language (workmat panels, ornate
rims, needle-flanked action plates). Keep that language. The equipment picker and
the result screen are good as they are; only touch them to adopt the new header.

## Change

1. **Header.**
   - Replace the plain top-left `Graftwright` label (it also floats over the
     picker) with a header centred over the work area (x about 610–1870):
     - an eyebrow `THE GRAFTWRIGHT'S ATELIER` (letter-spaced UI 15, pale violet
       `#c8b2d8`, dark shadow);
     - a title `Graftwright` (display about 52 px, `GOLD_BRIGHT`, 3 px black
       shadow plus a dark halo).
   - The picker and result screens use the same header, with their own panel
     title unchanged.
2. **Intro dialogue.**
   - Replace the flat `make_plain_card_style` box with the atelier's own panel
     material, the workmat/rim treatment used by the Sacrifice/Improve panels,
     at about 1160×300.
   - Inside:
     - the speaker as an eyebrow (`GRAFTWRIGHT`, letter-spaced, pale violet);
     - the line in the text font about 25 px `IVORY`;
     - `Skip` as the existing quiet plate (not bare text);
     - `Browse equipment` as the existing needle-flanked action plate.
   - Keep both dialogue variants (with and without a pair) and their focus order.
3. **Workbench panels.**
   - Narrow both panels to about 500 px wide and place them at about x 610 and
     x 1370. That leaves a 260 px gap where the atelier shows through.
   - Lower the panel body opacity to about 0.8 so the scene reads behind, and
     keep the rims.
   - Re-centre the content in each panel:
     - the equipment well and name;
     - the fate line (`WILL BE DESTROYED` / `WILL BE EQUIPPED`) as letter-spaced
       eyebrows in their existing colours;
     - `Change piece` as a small underlined text button (it replaces the
       `CHANGE` caption under the well; same action);
     - the instruction eyebrow;
     - the two cards, each with its state label.
   - **State labels:** the existing labels (`LOST`, `CARRY FORWARD`,
     `REPLACED`) stay. Add a `KEPT` label for the unchosen improve card, and
     shorten `CARRY FORWARD` to `CARRIED` only if a test doesn't pin the string.
     Otherwise keep it.
4. **The graft thread.**
   - When both a carried card and a replaced card are chosen, draw a stitched
     violet thread from the top of the carried card, arcing up through the gap
     between the panels past a small needle glyph, and down to the replaced card.
     - Reuse `graftwright_thread_effect.gd` / `graftwright_silk.gdshader` with
       a gentle idle sway.
     - Under reduced motion, draw a static dashed thread.
   - In the gap under the thread, add a small summary plate in ink glass:
     - eyebrow `GRAFT`;
     - the carried card's name in pale violet;
     - eyebrow `replaces`;
     - the replaced card's name in rose.
   - The plate replaces today's bottom `Coffin Brace → Shadow Step` line. Keep
     that string available to tests if they read it.
5. **Actions.**
   - Make `Graft` the primary action: when enabled, its needle-flanked plate
     gets a violet halo (glow about `Color(0.67, 0.43, 1.0, 0.55)`). When
     disabled it stays the dim plate it is today.
   - `Skip` stays bottom-left.

## Keep

- **Behaviour:**
  - all selection rules;
  - the picker (categories, grid, back);
  - card inspection;
  - the ritual animation and unravel shader;
  - result and save/retry;
  - controller focus order;
  - reduced motion;
  - foreground props;
  - the NPC cutout and its motion.
- **Text:** all rules text.

## Proof

- Update `tests/graftwright_probe.gd` (and `graftwright_feedback_probe.gd` /
  `graftwright_motion_probe.gd` if affected).
- Capture fresh 1920×1080 screenshots of:
  - the entry dialogue, both variants;
  - the workbench, empty and with a full preview;
  - the thread under reduced motion;
  - the donor grid;
  - the result;
  - controller focus.
- Keep the graftwright tests green.
