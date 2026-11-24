Use your built-in image generation tool again (real image generation, not code drawing), editing from your last image (burrow_mound-v4.png). Same canvas, same #00FF00 background, same 4x4 block grid, same size and placement. Do not palette-map or post-process the result in code; return the generated pixels.

The brightness is now right: keep every value, every shape, the clods, stones, crack and hide arc exactly where they are. The only problem is colour: the soil has gone orange, much more saturated than the rest of the game. Change only the hue and saturation, keeping each area's lightness:

1. **Soil becomes a cool grey-brown, like dry dust, not orange clay.** Lit soil on the crest and clod tops #a69886, the brightest crumbs on the very top #c2b5a2, mid soil #7c6e60, shadow soil on the lower-right faces #4e443a.
2. **Dark foot.** The lowest 2 to 3 blocks along the heap's lower edge #2a241e.
3. **Crack** around the grub's back #211c18.
4. **The grub's hide arc** is the only warm colour on the mound: top face #ccb48c, grooves #8e7a5c.
5. **Stones** top faces #a8a49c, shadow #625e58.

Overall: the same bright heap with a dark foot, in dusty grey-brown, with the hide arc the one warm accent.
