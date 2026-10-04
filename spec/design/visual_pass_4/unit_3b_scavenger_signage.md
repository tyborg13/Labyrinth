# Unit 3b: one parchment family for the Scavenger stall

**Owner feedback on unit 3:**
- The stall is "maybe a little nicer but not more cohesive".
- The tiny "THE SCAVENGER'S STALL" eyebrow above the large "Wares & Oddments" title is weird.
- The bronze brush-stroke category labels borrow the initiative rail's style and don't belong.
- The parchment price tags are liked, and the side labels should match them stylistically.

**New approved art** (sources in `spec/assets/visual_pass_4/sources/`, painted from the same vellum as `price_tag.png`):
- `shop_banner.png`: a wide parchment banner on a dowel, hung by twine from two brass rings.
- `shelf_label.png`: a small parchment label pinned by a brass tack.

## Change

1. **Process the art.**
   - Extend `tools/process_visual_pass_4_assets.py` to key both pieces the same way as the price tag: green removed, colour un-mixed, cropped, premultiplied downscale.
   - Output `assets/art/ui/visual_pass_4/shop_banner.png` at 1100 px wide and `shelf_label.png` at 360 px wide.
   - Extend `tests/test_visual_pass_4_assets.py` to cover them, including the README hash table.
   - Load both through the mipmapped-texture helper.
2. **Title.**
   - Remove the eyebrow and the free-floating display title.
   - Hang the banner from the top of the stall, centred over the shelf like the old title, about 640×180 on screen, with its rings near the top edge.
   - Write one title on the parchment in the same dark ink as the price tags (`#3a2616`): display font about 46 px, reading "The Scavenger's Wares". Add a faint 1 px lighter inner highlight so it reads as ink on vellum, with no glow.
   - Keep any test hook that reads the title text, updated to the new string.
3. **Category labels.**
   - Replace the brush strokes with the shelf label art pinned to the left post of each shelf row, at about 150×50 on screen.
   - Text is UI 17, letter-spaced 0.16 em, in the same ink as the price tags: MAGIC, GEAR, ITEMS.
   - Place each label so its brass tack sits on the post and its text is horizontally centred on the parchment area to the right of the tack.
4. **Price tags:** keep as they are; they already match. Make sure their ink colour and font exactly match the new labels and title.
5. **Embers:** keep the stat chip.
6. **Keep:** the dialogue panel, the mode toggle, Leave, and all behaviour.

## Proof

- Update `tests/scavenger_glowup_probe.gd` and `tests/scavenger_shop_probe.gd` expectations.
- Capture fresh 1920×1080 screenshots: entry, the pack in sell mode, an unaffordable ware, a purchase, and controller inspection.
- Keep the scavenger tests green.
- `scavenger_glowup_probe`'s cutout articulation assertion is a master failure. Leave it unchanged.
