# Stormstring Bow provenance

Generated with the built-in `image_gen.imagegen` tool. Each call produced one image of one object. All calls used `transparent_background: false`. The two delivered PNG files are byte-for-byte copies of the selected raw tool outputs. No raster processing, cleanup, normalization, resizing, keying, trimming, compositing, or code drawing was performed outside the image tool. Reference files were not modified, moved, or deleted.

The prompts requested the largest supported portrait resolution closest to 47:134, specifically 1344 × 3840. The actual tool-returned sizes are recorded below; final native target size is 47 × 134 for both objects.

## Delivered files

| File | Actual output pixel size | Mode |
|---|---:|---|
| stormstring_bow_front.png | 742 × 2118 | RGB PNG |
| stormstring_bow_rear.png | 742 × 2119 | RGB PNG |

## Verification and remaining deviations

The generated bows have pale ash/bone limbs, dark steel fittings, wrapped central grips, and bright blue-white lightning along both limbs and the strings. The front upper tip points up-left; the rear upper tip points up-right. Each contains only the isolated equipment piece, with green surrounding it and no clipping at the image edges.

The image tool did not achieve an exact uniform #00FF00 background despite explicit prompts and revisions. The front corner RGB values are [[17,239,19],[20,242,16],[16,242,18],[16,243,15]], and the rear corner RGB values are [[17,239,17],[22,242,17],[16,242,19],[16,243,13]]. The raw green variation was preserved according to the user's instruction prohibiting cleanup outside the image tool.

The canvas aspect ratios approximate 47:134, but the object bounding boxes do not meet the requested exact 47:134 ratio or equal 6% margins. Read-only estimates treating pixels with green > 180, red < 60 and blue < 60 as background give a front bounding box of 582 × 1940 pixels (ratio 0.300000) and a rear bounding box of 546 × 1937 pixels (ratio 0.281879); target ratio is 0.350746. Composition revisions requested the exact ratio and margins, but these remain tool-output limitations. No changes were made to correct them outside the image tool.

## stormstring_bow_front.png

Selected final source: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-f6eeab13-9878-415a-b8e6-7ace09865b81.png`

Output pixel size: **742 × 2118**.

SHA-256: `b859053bef45ae9e75bbbbef542cf34c36d331fefdde8cf7a79f1c25c16f9e09`

### Initial generation

Reference images supplied:

- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/ref_hero_front.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/approved_example_war_maul_front.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/approved_example_hunting_spear_front.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/icon_stormstring_bow.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/guide_stormstring_bow_front.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-f717fa26-5ec8-46fd-bfa5-500c1f417567.png`

Output pixel size: **742 × 2118**.

Exact prompt:

```text
Use case: stylized-concept
Asset type: isolated equipment sprite for Escape the Umbra, a hand-painted dark-fantasy pixel-art tactics game.
Generate exactly ONE image: stormstring_bow_front.png. This is a new front-view Stormstring Bow, not a reference collage.
Reference roles, in supplied order: 1 ref_hero_front.png is the hero's native sprite style and front camera angle; 2 approved_example_war_maul_front.png and 3 approved_example_hunting_spear_front.png show the approved chunky sprite finish, near-black outlines and flat clusters; 4 icon_stormstring_bow.png is the essential weapon identity, pale limbs, dark metal fittings and powerful coiling blue-white lightning; 5 guide_stormstring_bow_front.png is a placement/angle guide ONLY. Do not render any reference hero, guide mark, circle, rectangle or reference background.
Scene/backdrop: perfectly uniform solid chroma green RGB(0,255,0), hex #00FF00, everywhere outside the object, including inside the bow/string opening. Fully opaque PNG. Absolutely no background shadow, gradient, halo, atmospheric light or glow spill. No green pixels on the bow.
Subject: a BIG, formidable storm-charged recurve WAR BOW, clearly the weapon in the icon. Substantial PALE ASH-GREY / BONE-WHITE recurve limbs; worn charcoal iron/steel reinforcing cuffs and limb tips with small hooked spikes; a short thick charcoal-dark leather wrapped grip at the centre. No red or brown limbs. Show broad plain material planes, no decorative carving. The string is one taut, thin, continuous bright blue-white line of electricity connecting the tips.
Electricity: strong, immediately readable blue-white LIGHTNING, the brightest parts of the object. Bold chunky jagged bolts coil around BOTH limbs from near each reinforced tip toward the centre; a few clear zigzag branches, with icy-white cores and blue edges in FLAT PIXEL CLUSTERS. Lightning must run along the limbs AND the taut string, not merely three small cyan spots. The iconic electric storm looks dangerous at 47x134 pixels. Each bolt is about 2-3 native pixels thick, each zigzag a big readable shape. Any faint pale-blue reflected glow is restricted to the solid bow material. Sharp isolated lightning shapes may project a little from the limbs but no blurred halo or lighting of the green background.
Composition: front view at the hero's front camera angle, isolated full bow. Match the steep outward lean of the front guide: UPPER LIMB points UP-LEFT, away from the absent hero on the right; LOWER LIMB points DOWN-RIGHT, near the absent hero's foot. The bow's convex belly curves toward screen LEFT, AWAY from the hero, and the taut string is on screen RIGHT, nearer the absent body. Preserve an elegant large recurve silhouette; substantial but not a bulky staff. The central dark leather grip must be clearly visible, unobstructed, oriented along the bow, so it can pass through the cyan fist centre in the guide when composited; draw no hand or circle. The weapon spans above the shoulder to near the ground at the guide's scale. Do not turn it into an upright catalogue bow.
Shape and framing: complete object including electricity bounding box aspect ratio EXACTLY 47:134, tall and narrow. Fill the image efficiently with about 6% clear green margin on all sides; nothing touches an image edge. Grip approximately halfway down. Upper tip near top-left and lower tip near bottom-right. No arrow.
Style/medium: match the HERO and APPROVED sprites, hand-painted DARK-FANTASY PIXEL ART. Render as if painted at the FINAL NATIVE bounding size 47x134, then magnified using square hard pixel blocks. CHUNKY stepped outlines, thick near-black outline roughly 1-2 native pixels, big flat colour clusters, just 3-4 flat tones per material. Details other than the thin string must never be finer than about 1/15 of the object's total width. No fine texture, micro-scratches, noise, tiny ornaments, anti-aliased smooth drawing or high-resolution painterly detail. The visible square pixel clusters must match the reference finish. Muted earthy grimy palette and desaturated worn steel; upper-left light. Pale limbs use warm ash-white, muted grey and dark grey shade; leather is charcoal with only a few broad wrap bands. Electricity uses a few clean bright blue/ice-white pixel clusters, no soft luminous cloud.
Output: use the largest supported portrait size closest to 47:134; request 1344x3840 pixels. One full isolated bow only. No character, hand, arm, body, arrow, text, labels, watermark, frame, ground or cast shadow.
```

### Background and presentation revision

Reference images supplied:

- `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-f717fa26-5ec8-46fd-bfa5-500c1f417567.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-9e75694f-e718-4d47-8436-cc816104e57a.png`

Output pixel size: **742 × 2119**.

Exact prompt:

```text
Use case: precise-object-edit
Edit the supplied Stormstring Bow sprite, producing ONE front-view equipment image only. Keep its pale ash-grey/bone-white recurve limbs, exact dark steel fittings and hooked tips, dark wrapped centre grip, intimidating blue-white lightning along both limbs, bright electric string, upper-left lighting, and upper-left-to-lower-right steep lean. Keep the thick stepped near-black outlines and chunky flat pixel-art material planes. The bow's belly stays on screen LEFT and string on screen RIGHT. No hero, hand, arrow or extra object.
Make the presentation conform precisely to an isolated chroma-key sprite: replace ALL green background pixels, including inside the bow/string opening, with ONE perfectly uniform exact colour RGB(0,255,0), hex #00FF00. This is a hard flat digital colour fill, not painted, textured, lit, mottled, compressed-looking, grainy or shaded. Every point outside the bow and its crisp lightning must be exactly the same pure green colour. No green pixels on the bow, no cast shadow, no glow/halo spilling onto the background. Do not inherit the reference image's slightly mottled green.
Fit the complete bow including lightning into a tall bounding box whose width:height is 47:134, with about 6% flat green clear space on every side and nothing touching the canvas edges. Keep the bow large in this bounding box and the centre grip near halfway down. Chunky native-scale sprite intended to reduce to 47x134 pixels; use big hard square flat colour clusters, no fine grain, scratches or tiny ornament. Lightning remains visibly bright jagged 2-3-native-pixel bolts, not a soft halo.
Use the largest supported portrait resolution, closest to 47:134; requested output 1344x3840 pixels at full resolution. Fully opaque PNG, one object, no text, watermark, border or frame.
```

### Final angle and framing revision — delivered image

Reference images supplied:

- `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-9e75694f-e718-4d47-8436-cc816104e57a.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-f6eeab13-9878-415a-b8e6-7ace09865b81.png`

Output pixel size: **742 × 2118**.

Exact prompt:

```text
Use case: precise-object-edit
Produce ONE final FRONT Stormstring Bow sprite from this reference. Make a targeted composition correction while preserving all equipment design and chunky pixel-art rendering.
The guide's bow leans 18 DEGREES from vertical: upper tip UP-LEFT and lower tip DOWN-RIGHT. Increase this bow's diagonal lean slightly to match that 18-degree angle. Keep its convex pale ash-white/grey limbs and belly on screen LEFT and its thin continuous electric string on screen RIGHT. The leather grip stays around the midpoint. Keep the exact limb construction, dark steel cuffs, hooked tips, wrapped dark grip, strong blue-white lightning coils on BOTH limbs and electrical string, 3-4 flat material tones, hard chunky square colour clusters, near-black stepped outline and upper-LEFT lighting.
REFRAME explicitly: the ENTIRE OBJECT INCLUDING EVERY LIGHTNING BRANCH occupies exactly the central 88% of the portrait canvas width AND exactly the central 88% of its height. Thus its bounding box starts at x=6%, y=6% and ends at x=94%, y=94%; equal proportional green margins on all four sides. The full-object bounding-box width divided by height is 47/134, about 0.35075. This is taller margin and slightly wider silhouette than the supplied reference. No object or lightning is clipped. Do not add a drawn bounding rectangle or grid.
Background is ONLY an exact perfectly uniform solid digital colour fill #00FF00, RGB(0,255,0), including inside the bow/string opening, with no texture, gradient, noise, shadow or glow/halo. No green on the object.
Output ONE isolated front-view war bow only, no hand, body, arrow, extra object, text or frame. Maximum supported full portrait resolution closest to 47:134, request 1344x3840. The object will reduce to native 47x134, so no fine scratches, grain, detail or ornament below approximately 1/15 of the object's width.
```

## stormstring_bow_rear.png

Selected final source: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-50cb2c7a-0887-48fa-b2f6-0939b8537a82.png`

Output pixel size: **742 × 2119**.

SHA-256: `1d92bf52e3b79af1b5301bdd659e415cb5f575be69c19ba721e598f2801f3eed`

For the initial rear generation, the supplied `stormstring_bow_front.png` contained the front background/presentation revision, sourced from `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-9e75694f-e718-4d47-8436-cc816104e57a.png`. The workspace front file was subsequently replaced by the final front angle/framing revision; the source path above identifies the precise reference content used.

### Initial rear generation

Reference images supplied:

- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/stormstring_bow_front.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/guide_stormstring_bow_rear.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/ref_hero_rear.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/approved_example_hunting_spear_front.png`
- `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/1192fff8-0018-41b6-b489-30bcf96f6a52/scratchpad/img/w4/icon_stormstring_bow.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-c99ac31b-db58-484d-a53c-9dee731d81cd.png`

Output pixel size: **743 × 2117**.

Exact prompt:

```text
Use case: stylized-concept
Asset type: isolated rear-view equipment sprite for Escape the Umbra, a hand-painted dark-fantasy pixel-art tactics game.
Generate exactly ONE new image: stormstring_bow_rear.png. This is the SAME large Stormstring war bow as reference 1, seen from BEHIND the hero at reference 2's rear guide angle.
Reference roles, in supplied order: 1 stormstring_bow_front.png is the matching bow identity reference; preserve its pale ash-grey/bone-white recurved limbs, charcoal steel reinforcing cuffs and hooked limb-tip spikes, short dark leather centre grip, and intense blue-white lightning coiling around both limbs and along the taut string. 2 guide_stormstring_bow_rear.png is ONLY the rear orientation/placement guide; 3 ref_hero_rear.png gives the hero's rear camera and native sprite style; 4 approved_example_hunting_spear_front.png shows the approved chunky finish; 5 icon_stormstring_bow.png shows the original identity and powerful storm charge. These are references only. Render no character and no guide marks.
Scene/backdrop: ONE perfectly uniform exact solid chroma green RGB(0,255,0), hex #00FF00. This is a hard flat digital colour fill, not a painted or textured backdrop. The outside, margins, and entire opening between limbs and string must be this identical pure green. Fully opaque PNG. No gradient, noise, grain, shadow, ground, atmosphere, halo or blue light cast onto the green. Do not inherit slight colour variation from any reference background. No green on the object.
Subject: ONE complete BIG intimidating electric WAR BOW; no arrow. Pale ash-grey/bone-white recurve limbs, substantial readable mass, charcoal iron/steel cuffs and reinforced tips with small hooked spikes, dark wrapped leather central grip. Limb colour must stay pale, never red or brown. Same construction and approximate cuff positions as front bow. Rear-facing cuff backs and the back of the wrapped grip are visible; preserve the same weapon with plausible reverse surfaces. No new decorations.
Orientation is mandatory: the rear guide reverses the front screen orientation. UPPER LIMB points UP-RIGHT, steeply away from the absent hero on screen LEFT; LOWER LIMB points DOWN-LEFT, close to the absent foot. Match the rear guide's lean, not an upright catalogue pose. The bow's convex belly curves toward screen RIGHT, away from the absent hero; the thin taut electric string is on screen LEFT, nearer the absent body. Draw the same bow from behind, not its front-facing panels or a digitally mirrored lighting pattern. Upper-left lighting must still come from the image's upper LEFT. Central dark wrapped grip approximately halfway down, kept clearly visible for passage through the cyan fist centre in the rear placement guide; draw no hand, arm, body, cyan circle, magenta shape or yellow bounding rectangle.
Storm electricity: immediately read as charged, electric and dangerous like the inventory icon. Big bright BLUE-WHITE jagged LIGHTNING coils along both pale limbs and a thin continuous electrical string joins both tips. Bold crisp zigzag bolts about 2-3 native pixels thick, icy-white cores with a few vivid blue edge clusters; the brightest element in the sprite. Use a few big readable branches and coiling angular loops, no spidery fine filaments, no mere tiny blue accents. Any pale-blue reflected illumination stays on the bow material only. Lightning silhouettes may project slightly from the limbs, with crisp edges against solid green and NO blurred halo.
Framing: entire object including all lightning has bounding-box width:height 47:134. Large tall narrow composition, about 6% clear green margin on all sides. Nothing touches an image edge. Upper tip top-right, lower tip bottom-left. This should composite at FINAL NATIVE SIZE 47x134, spanning above the shoulder to near the ground, and feel powerful.
Style/medium: CHUNKY hand-painted DARK-FANTASY PIXEL ART that matches the HERO and APPROVED sprite pieces. Paint as if at a logical native 47x134 size, enlarged into hard square pixel blocks. Thick near-black stepped outline roughly 1-2 native pixels, big flat colour clusters, 3-4 flat tones per material; details other than the thin string must not be smaller than about 1/15 of the object's width. Worn desaturated metal, muted earthy ash-grey/bone-white material, plain dark leather with a few large wrap bands. No fine grain, noise, tiny scratches, tiny ornament, smooth anti-aliased contours, high-resolution painterly detail, photographic texture, glossy metal, cartoon cuteness or soft neon glow.
Output: use the largest supported portrait resolution closest to 47:134; requested 1344x3840 pixels at full resolution. Exactly one rear-view bow, no text, labels, watermark, frame, hero, hand, arrow, other object or cast shadow.
```

### Upper-left lighting revision

Reference images supplied:

- `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-c99ac31b-db58-484d-a53c-9dee731d81cd.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-b2dc64f9-44ca-4ca7-bc6b-027b621a58d7.png`

Output pixel size: **742 × 2120**.

Exact prompt:

```text
Use case: lighting-weather
Edit this ONE rear-view Stormstring Bow equipment sprite. Make one targeted correction: the material lighting must come from the UPPER LEFT of the image. On the pale limbs and charcoal metal fittings, place broad light ash-white / muted steel highlight planes on the upper-left-facing facets, and broad grey/charcoal shade on lower-right-facing facets. This is still a muted, grimy flat-tone dark-fantasy sprite, not glossy or smooth. Do not merely mirror the front view's lighting.
Keep the same rear-view bow identity and all geometry: upper tip UP-RIGHT, lower tip DOWN-LEFT, convex bow belly on screen RIGHT and taut electric string on screen LEFT. Keep the same pale ash-grey/bone-white recurve limbs, same dark reinforcing cuffs and hooked tips, same clearly visible dark wrapped centre grip, same thick stepped near-black outline, same coiling bright blue-white chunky jagged lightning along both limbs and along the thin continuous electric string. Electricity remains the brightest element, with hard square pixel clusters and no soft halo.
Final native object bounding size 47x134. Preserve the large steep outward rear-guide orientation and the chunky approved sprite finish: 3-4 flat tones per material, big flat native-scale colour blocks, no fine grain, scratches, texture, noise or tiny ornament.
The entire background including the bow/string opening must be a perfectly uniform flat digital fill RGB(0,255,0), hex #00FF00, one identical solid colour with no shading, mottling, shadow, glow spill or halo. No green on the object. Complete bow including lightning bounding box aspect ratio 47:134, about 6% clear green margin on all sides, no edge contact.
Use the largest supported portrait resolution closest to 47:134; requested full resolution 1344x3840. One opaque PNG image, one bow only, no hand, arm, hero, arrow, text, label, frame, ground or other object.
```

### Final angle and framing revision — delivered image

Reference images supplied:

- `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-b2dc64f9-44ca-4ca7-bc6b-027b621a58d7.png`

Raw generated output: `/Users/borgerding/.codex/generated_images/01a112a6-dbed-7021-9614-7c56964804a7/exec-50cb2c7a-0887-48fa-b2f6-0939b8537a82.png`

Output pixel size: **742 × 2119**.

Exact prompt:

```text
Use case: precise-object-edit
Produce ONE final REAR Stormstring Bow sprite from this reference. Make a targeted composition correction while preserving all equipment design and chunky pixel-art rendering.
The guide's bow leans 18 DEGREES from vertical: upper tip UP-RIGHT and lower tip DOWN-LEFT. Increase this bow's diagonal lean slightly to match that 18-degree angle. Keep its convex pale ash-white/grey limbs and belly on screen RIGHT and its thin continuous electric string on screen LEFT. The leather grip stays around the midpoint. Keep the exact limb construction, dark steel cuffs, hooked tips, wrapped dark grip, strong blue-white lightning coils on BOTH limbs and electrical string, 3-4 flat material tones, hard chunky square colour clusters, near-black stepped outline and upper-LEFT lighting.
REFRAME explicitly: the ENTIRE OBJECT INCLUDING EVERY LIGHTNING BRANCH occupies exactly the central 88% of the portrait canvas width AND exactly the central 88% of its height. Thus its bounding box starts at x=6%, y=6% and ends at x=94%, y=94%; equal proportional green margins on all four sides. The full-object bounding-box width divided by height is 47/134, about 0.35075. This is taller margin and slightly wider silhouette than the supplied reference. No object or lightning is clipped. Do not add a drawn bounding rectangle or grid.
Background is ONLY an exact perfectly uniform solid digital colour fill #00FF00, RGB(0,255,0), including inside the bow/string opening, with no texture, gradient, noise, shadow or glow/halo. No green on the object.
Output ONE isolated rear-view war bow only, no hand, body, arrow, extra object, text or frame. Maximum supported full portrait resolution closest to 47:134, request 1344x3840. The object will reduce to native 47x134, so no fine scratches, grain, detail or ornament below approximately 1/15 of the object's width.
```

## Additional references inspected

All supplied reference PNGs were inspected before generation, including both hero views, both approved examples, the inventory icon, both placement guides, and `rejected_stormstring_bow_front.png`. The rejected bow was inspected for context only and was not supplied to the image-generation tool. The exact supplied reference sets for every successful image-generation call are recorded above.

