# Image generation provenance

Tool: built-in image_gen.imagegen. Every image was generated separately as a single object, with transparent_background=false.

The eight PNG deliverables are byte-for-byte copies of selected built-in tool outputs. No external image drawing, colour normalization, cleanup, keying, cropping, resampling, or other image edits were performed. Reference files were read only and their SHA-256 hashes are unchanged.

Observed raw-output limitations: green background pixels vary around chroma green rather than being uniformly exact #00FF00. Object bounding-box ratios and approximately 6% margins are generative approximations. Image-tool corrections were attempted; exact colour and geometry were not imposed externally.

## galewhip_front.png

Final output pixel size: 724 × 2172

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-89b6ab5f-f189-431f-8aa7-d7f07fb87607.png`

### Image-tool call 1 (earlier generation/correction)

Output pixel size: 1024 × 1536

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_front.png`
- `approved_example_sunken_anchor_front.png`
- `approved_example_sawtooth_knife_front.png`
- `icon_galewhip.png`
- `guide_galewhip_front.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite for Escape the Umbra: galewhip_front.png, front-view gale whip. This is real image generation of a single isolated object, using supplied images as references only.
Input roles in supplied order: 1 ref_hero_front.png = mandatory native hero pixel-art style; 2 approved_example_sunken_anchor_front.png = approved chunky finish and coarse pixel scale; 3 approved_example_sawtooth_knife_front.png = approved dark outline, muted leather and steel palette; 4 icon_galewhip.png = identity/material/colour reference only, not its coiled pose; 5 guide_galewhip_front.png = exact upright placement, proportions, bounding-box shape and grip-axis reference, cyan circle marks future fist centre.
Subject and shape: one complete dark-leather whip hanging straight DOWN. Overall object bounding-box ratio MUST be 12:88 (0.13636 width/height), very tall and very narrow. A stout wrapped dark-brown leather handle occupies the upper quarter with simple worn iron caps. The straight handle passes through the guide's cyan fist centre; its rounded iron butt is ABOVE that centre, cord attachment BELOW it. No hand is painted. Below the handle, a THICK continuous braided dark-leather cord hangs down in a gentle shallow S-curve. Cord body must be about ONE THIRD of the object's total width, approximately 4 pixels thick when reduced to 12 pixels across. Make braid readable through a few large alternating warm-brown blocks, not fine strands. Lower quarter: a BOLD, compact pale-teal wind swirl wraps around the frayed tip, nearly filling the narrow object's width. Swirl should remain clearly visible as a few large teal and pale-cyan pixel blocks at 12x88, thick arcs with a dark boundary, with only two or three chunky frayed leather ends. All magic colour is solid sprite pixels, no luminous blur.
STYLE: match the supplied hero and approved pieces exactly: dark-fantasy hand-painted PIXEL ART for a segmented 255x255 hero, thick near-black stepped outline, coarse square pixel clusters, chunky readable shapes, only 3-4 flat tones per material, upper-left light, muted earthy grimy colours, desaturated worn iron. Draw as if actually painted at final native 12x88 then enlarged with nearest-neighbour pixels. Every local feature is a big flat block; no detail finer than approximately 1/15 of object width. Avoid fine grain, scratches, noise, smooth gradients, fine ornament, smooth vector curves, glossy metal, cartoon shine or photorealism.
BACKGROUND AND FRAMING: perfectly flat solid chroma green RGB(0,255,0) #00FF00 everywhere except the object, including all holes and negative space. No green on object. No shadow, ground, atmospheric glow or colour spill onto background. Single object only, no hero, no body, no fist, no guide marks, no cyan marker, no labels, no text, no frame. Whole object visible with at least approximately 6% margin from every image edge. The OBJECT bounding box is 12:88 even if canvas cannot be that slender; keep extra side background rather than making whip wider. Output one raw PNG at the largest resolution the built-in tool supports and the closest supported portrait canvas aspect ratio to 12:88. Do not create a sheet, pair, comparison or multiple variants.
```

### Image-tool call 2 (earlier generation/correction)

Output pixel size: 1024 × 1536

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-d1193f41-1ed2-44d6-b559-75f7e4efc6ca.png`

Exact prompt:

```text
Use case: precise-object-edit.
Edit the supplied galewhip image ONLY to correct the background. Keep the whip's exact narrow silhouette, thick dark-leather braided cord, handle, stepped near-black outline, chunky brown palette, pale-teal lower-quarter wind swirl, all object pixels and its pose. Retain one complete isolated whip. Its final native bounding box is 12x88; the cord remains one third of object width.
Replace EVERY background pixel and EVERY hole pixel with the SAME exact RGB value (0,255,0), hex #00FF00, using a perfectly uniform flat opaque colour. The background must have exactly ONE colour, zero grain, zero dithering, zero noise, zero gradients, zero vignette, zero lighting, zero texture, zero shadows, and zero colour spill. Pure maximum digital green. Do not tint the background or make it a photographed green screen. Hard clean pixel-art separation, no antialiasing onto green. Keep the object material colours free of green.
Preserve the native low-resolution pixel-art finish. One object only, no hand, body, text, markers, frame, sheet or extra object. Give the entire object at least 6% margin from every canvas edge; its bounding-box width:height remains 12:88. Output one lossless raw PNG at the largest supported resolution and closest supported portrait aspect ratio. Do not add detail or redesign the whip.
```

### Image-tool call 3 (selected final output)

Output pixel size: 724 × 2172

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-b89629c3-26fe-439b-9686-116d7ae4525a.png`
- `ref_hero_front.png`
- `guide_galewhip_front.png`
- `approved_example_sunken_anchor_front.png`
- `icon_galewhip.png`

Exact prompt:

```text
Use case: precise-object-edit.
Generate this one front gale-whip sprite from supplied image 1 on a TALL 1:3 PORTRAIT CANVAS, at the maximum supported resolution, approximately 724 pixels wide by 2172 pixels high. The CANVAS must be 1:3, not 2:3 or square. This tall format is needed for a native 12x88 narrow object.
Preserve the existing whip design in image 1: front view, stout dark wrapped leather handle, big worn iron caps, thick braided dark-leather cord one third of the complete object width, hanging DOWN in a gentle shallow S-curve, lower-quarter bold pale-teal wind swirl wrapping around chunky frayed tip, dark stepped outline. Same muted materials, same coarse big square colour clusters, 3-4 flat tones each, UPPER LEFT light. Source 2 is hero style; source 3 placement guide with future fist centre on grip; source 4 approved coarse finish; source 5 inventory colour/material identity. No hand or guide is painted.
The OBJECT bounding box remains exactly 12:88, approximately 261 pixels wide by 1914 pixels high on a 724x2172 canvas. Place it CENTRED horizontally. Handle's top starts at 6% of canvas height, tip ends at 94% of canvas height, leaving six percent green top/bottom margins. Leave ample unused green to the sides instead of widening the whip. Cord remains visibly thick, approximately 87 pixels across if object width is 261; wind swirl fills the lower quarter, solid teal/cyan blocks only with dark boundaries, never a halo.
Do not add details or smooth the sprite. No grain, scratches, noise, fine fibers, ornament, gradient, glossy metal or blur. One object only, no fist, arm, body, text, label, frame or extra object. EVERY background pixel and hole is identical opaque RGB(0,255,0) #00FF00 with no lighting, noise, texture, gradient, vignette, shadow or glow spill. No green on object. Output ONE raw PNG using the tallest supported 1:3 portrait format at maximum resolution.
```

## galewhip_rear.png

Final output pixel size: 724 × 2172

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-edda3cd5-dc8f-43f4-a7e9-e4fe7791b234.png`

### Image-tool call 1 (earlier generation/correction)

Output pixel size: 1024 × 1536

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_rear.png`
- `approved_example_sunken_anchor_front.png`
- `galewhip_front.png`
- `icon_galewhip.png`
- `guide_galewhip_rear.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite for Escape the Umbra: galewhip_rear.png, REAR-view gale whip, seen from behind. This is real image generation of a single isolated object, using supplied images as references only.
Input roles in supplied order: 1 ref_hero_rear.png = mandatory native hero pixel-art style; 2 approved_example_sunken_anchor_front.png = approved chunky finish and coarse pixel scale; 3 galewhip_front.png = matching front counterpart, retain its thick cord, pale-teal wind and chunky finish; 4 icon_galewhip.png = identity/material/colour reference only, not its coiled pose; 5 guide_galewhip_rear.png = exact upright placement, proportions, bounding-box shape and grip-axis reference, cyan circle marks future fist centre.
Rear-facing consistency: show the back side of the same handle fittings and leather braid; gently mirror the S-curve from the front counterpart, keeping upper-left illumination. This is a separately generated rear view.
Subject and shape: one complete dark-leather whip hanging straight DOWN. Overall object bounding-box ratio MUST be 12:88 (0.13636 width/height), very tall and very narrow. A stout wrapped dark-brown leather handle occupies the upper quarter with simple worn iron caps. The straight handle passes through the guide's cyan fist centre; its rounded iron butt is ABOVE that centre, cord attachment BELOW it. No hand is painted. Below the handle, a THICK continuous braided dark-leather cord hangs down in a gentle shallow S-curve. Cord body must be about ONE THIRD of the object's total width, approximately 4 pixels thick when reduced to 12 pixels across. Make braid readable through a few large alternating warm-brown blocks, not fine strands. Lower quarter: a BOLD, compact pale-teal wind swirl wraps around the frayed tip, nearly filling the narrow object's width. Swirl should remain clearly visible as a few large teal and pale-cyan pixel blocks at 12x88, thick arcs with a dark boundary, with only two or three chunky frayed leather ends. All magic colour is solid sprite pixels, no luminous blur.
STYLE: match the supplied hero and approved pieces exactly: dark-fantasy hand-painted PIXEL ART for a segmented 255x255 hero, thick near-black stepped outline, coarse square pixel clusters, chunky readable shapes, only 3-4 flat tones per material, upper-left light, muted earthy grimy colours, desaturated worn iron. Draw as if actually painted at final native 12x88 then enlarged with nearest-neighbour pixels. Every local feature is a big flat block; no detail finer than approximately 1/15 of object width. Avoid fine grain, scratches, noise, smooth gradients, fine ornament, smooth vector curves, glossy metal, cartoon shine or photorealism.
BACKGROUND AND FRAMING: perfectly flat solid chroma green RGB(0,255,0) #00FF00 everywhere except the object, including all holes and negative space. No green on object. No shadow, ground, atmospheric glow or colour spill onto background. Single object only, no hero, no body, no fist, no guide marks, no cyan marker, no labels, no text, no frame. Whole object visible with at least approximately 6% margin from every image edge. The OBJECT bounding box is 12:88 even if canvas cannot be that slender; keep extra side background rather than making whip wider. Output one raw PNG at the largest resolution the built-in tool supports and the closest supported portrait canvas aspect ratio to 12:88. Do not create a sheet, pair, comparison or multiple variants.
Background must have exactly one uniform digital colour #00FF00, no lighting, grain, dither or vignette. No photographed green screen.
```

### Image-tool call 2 (selected final output)

Output pixel size: 724 × 2172

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-66502b42-89be-4130-9d01-00ac197b81c3.png`
- `ref_hero_rear.png`
- `guide_galewhip_rear.png`
- `approved_example_sunken_anchor_front.png`
- `icon_galewhip.png`

Exact prompt:

```text
Use case: precise-object-edit.
Generate this one REAR gale-whip sprite, seen from behind from supplied image 1 on a TALL 1:3 PORTRAIT CANVAS, at the maximum supported resolution, approximately 724 pixels wide by 2172 pixels high. The CANVAS must be 1:3, not 2:3 or square. This tall format is needed for a native 12x88 narrow object.
Preserve the existing whip design in image 1: rear view of same equipment, stout dark wrapped leather handle, big worn iron caps, thick braided dark-leather cord one third of the complete object width, hanging DOWN in a gentle shallow S-curve, lower-quarter bold pale-teal wind swirl wrapping around chunky frayed tip, dark stepped outline. Same muted materials, same coarse big square colour clusters, 3-4 flat tones each, UPPER LEFT light. Source 2 is rear hero style; source 3 placement guide with future fist centre on grip; source 4 approved coarse finish; source 5 inventory colour/material identity. No hand or guide is painted.
The OBJECT bounding box remains exactly 12:88, approximately 261 pixels wide by 1914 pixels high on a 724x2172 canvas. Place it CENTRED horizontally. Handle's top starts at 6% of canvas height, tip ends at 94% of canvas height, leaving six percent green top/bottom margins. Leave ample unused green to the sides instead of widening the whip. Cord remains visibly thick, approximately 87 pixels across if object width is 261; wind swirl fills the lower quarter, solid teal/cyan blocks only with dark boundaries, never a halo.
Do not add details or smooth the sprite. No grain, scratches, noise, fine fibers, ornament, gradient, glossy metal or blur. One object only, no fist, arm, body, text, label, frame or extra object. EVERY background pixel and hole is identical opaque RGB(0,255,0) #00FF00 with no lighting, noise, texture, gradient, vignette, shadow or glow spill. No green on object. Output ONE raw PNG using the tallest supported 1:3 portrait format at maximum resolution.
Show the BACK of the wrapped leather handle and iron fittings. Retain the existing rear source's back-facing braid and frayed tip; do not paint a front duplicate. Upper-left lighting still applies.
```

## parrying_dagger_front.png

Final output pixel size: 1042 × 1509

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-5bf9d6f7-4810-448b-b255-6d83771728ef.png`

### Image-tool call 1 (earlier generation/correction)

Output pixel size: 1042 × 1509

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_front.png`
- `approved_example_sawtooth_knife_front.png`
- `approved_example_war_maul_front.png`
- `icon_parrying_dagger.png`
- `guide_parrying_dagger_front.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite parrying_dagger_front.png: a main-gauche parrying dagger in a real downward dagger grip, FRONT-facing view, isolated on pure green. Final native object bounding box 29x42 pixels, width:height 29:42.
Supplied reference roles in order: 1 ref_hero_front.png = native hero style; 2 approved_example_sawtooth_knife_front.png = approved muted steel, dark leather, chunky pixel outline and finish; 3 approved_example_war_maul_front.png = approved coarse material blocks; 4 icon_parrying_dagger.png = identity, steel, leather and main-gauche construction only; 5 guide_parrying_dagger_front.png = mandatory exact ANGLE, silhouette proportions and hold. Do not copy icon pose.
GEOMETRY IS CRITICAL: the axis goes from UPPER LEFT down toward LOWER RIGHT, like a backslash. The blade points DOWN AND OUTWARD TO THE RIGHT, approximately 32 degrees right of downward vertical. Large ROUND IRON POMMEL at the upper-left end, ABOVE the future fist. Short dark leather wrapped grip continues on the SAME straight axis THROUGH the cyan circle's future fist centre. The grip is complete and visible since no hand is painted. Immediately BELOW that centre place a very BOLD WIDE crossguard at a right angle to the blade: the guard slants from lower-left to upper-right, spanning about two thirds of the total bounding-box width, exactly as wide as the guide's magenta guard bar. Both quillon ends curl DOWN toward the blade into chunky blunt ends. A clearly readable ROUND SIDE-RING belongs to the guard adjacent to the blade shoulder; it is not a floating loop at the pommel. Below the crossguard, a BROAD BRIGHT STEEL blade with two pale worn-steel edge planes and one continuous DARK FULLER tapers decisively to the lower-right point. Hilt and guard occupy approximately upper 40% of object; blade lower 60%. Pommel, grip, crossguard and blade are one continuous held dagger. This must read as a fist-held main-gauche, with the pommel showing above a future hand and guard below it. Never a hidden wrist blade, arm-mounted device, sleeve or blade emerging from behind a fist.
Native readability: big pommel about 5 native pixels across, bold guard about 19 native pixels wide, broad blade shoulder about 8 native pixels across, high-contrast pale desaturated steel against dark leather and the black outline. No fine filigree or slender dark blade. No hand at all.
Keep the object wholly inside a centered box from 6% to 94% of canvas height with proportional 29:42 width; no cropping, and no empty space inside an invented frame.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

### Image-tool call 2 (selected final output)

Output pixel size: 1042 × 1509

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-9c110f12-b0a6-47a4-97e9-e1dc7117629e.png`
- `guide_parrying_dagger_front.png`
- `ref_hero_front.png`
- `approved_example_sawtooth_knife_front.png`

Exact prompt:

```text
Use case: precise-object-edit.
Edit only the CROSSGUARD ends in image 1, the newly generated front-view parrying dagger. Keep all other design, placement, perspective, pommel, grip, blade, fuller, side-ring and coarse pixel-art finish. Supporting image 2 is the exact front placement guide, image 3 is the hero style, image 4 is the approved chunky finish.
This single main-gauche has a round pommel at UPPER LEFT, a complete straight short grip angled DOWN RIGHT through the guide cyan fist centre, wide crossguard perpendicular to this axis, broad steel blade tapering DOWN RIGHT. NO hand painted.
CORRECTION: Both crossguard quillon tips must be DOWNTURNED, turned TOWARD THE BLADE POINT at LOWER RIGHT. In image 1 they curl upward toward the pommel; reverse ONLY those curls so BOTH terminal knobs point toward the lower-right blade side of the guard. Keep the two long guard arms at their same perpendicular angle and width. Keep the ROUND SIDE-RING clearly visible beside the blade shoulder. Guard remains thick, wide and easy to read at 29x42 native pixels. This is not a second object or a second dagger.
Retain thick near-black stepped outline, upper-left light, 3-4 flat desaturated tones of worn steel and leather, coarse flat square clusters, no fine grain, no gloss. Entire object bounding-box width:height 29:42. Center it with approximately 6% green margin on each canvas edge. Pure flat #00FF00 RGB(0,255,0) background and all holes; no gradient, texture, lighting or spill on green. No body, text, guide marks, frame, ground, shadow or extra objects. Output ONE raw PNG at largest supported portrait resolution and closest supported aspect ratio.
```

## parrying_dagger_rear.png

Final output pixel size: 1044 × 1507

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-a07f6f94-5170-4749-a886-320647cbac4c.png`

### Image-tool call 1 (selected final output)

Output pixel size: 1044 × 1507

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_rear.png`
- `approved_example_sawtooth_knife_front.png`
- `parrying_dagger_front.png`
- `icon_parrying_dagger.png`
- `guide_parrying_dagger_rear.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite parrying_dagger_rear.png: a main-gauche parrying dagger in a real downward dagger grip, REAR-facing view, seen from behind, isolated on pure green. Final native object bounding box 29x42 pixels, width:height 29:42.
Supplied reference roles in order: 1 ref_hero_rear.png = native hero style; 2 approved_example_sawtooth_knife_front.png = approved muted steel, dark leather, chunky pixel outline and finish; 3 parrying_dagger_front.png = matching front counterpart with correct downturned quillons; preserve same construction, coarse blocks, bright steel and dark leather; 4 icon_parrying_dagger.png = identity, steel, leather and main-gauche construction only; 5 guide_parrying_dagger_rear.png = mandatory exact ANGLE, silhouette proportions and hold. Do not copy icon pose.
GEOMETRY IS CRITICAL: the axis goes from UPPER RIGHT down toward LOWER LEFT, like a forward slash. The blade points DOWN AND OUTWARD TO THE LEFT, approximately 32 degrees left of downward vertical. Large ROUND IRON POMMEL at the upper-right end, ABOVE the future fist. Short dark leather wrapped grip continues on the SAME straight axis THROUGH the cyan circle's future fist centre. The grip is complete and visible since no hand is painted. Immediately BELOW that centre place a very BOLD WIDE crossguard at a right angle to the blade: the guard slants from upper-left to lower-right, spanning about two thirds of the total bounding-box width, exactly as wide as the guide's magenta guard bar. Both quillon ends curl DOWN toward the blade into chunky blunt ends. A clearly readable ROUND SIDE-RING belongs to the guard adjacent to the blade shoulder; it is not a floating loop at the pommel. Below the crossguard, a BROAD BRIGHT STEEL blade with two pale worn-steel edge planes and one continuous DARK FULLER tapers decisively to the lower-left point. Hilt and guard occupy approximately upper 40% of object; blade lower 60%. Pommel, grip, crossguard and blade are one continuous held dagger. This must read as a fist-held main-gauche, with the pommel showing above a future hand and guard below it. Never a hidden wrist blade, arm-mounted device, sleeve or blade emerging from behind a fist.
Native readability: big pommel about 5 native pixels across, bold guard about 19 native pixels wide, broad blade shoulder about 8 native pixels across, high-contrast pale desaturated steel against dark leather and the black outline. No fine filigree or slender dark blade. No hand at all. Rear view: show the back faces of the guard and pommel; the side-ring is attached on the opposite-facing side, partially foreshortened but clearly readable. Upper-left illumination still applies. Both quillon terminal knobs are DOWNTURNED TOWARD THE LOWER-LEFT BLADE POINT; never curl them toward the upper-right pommel.
Keep the object wholly inside a centered box from 6% to 94% of canvas height with proportional 29:42 width; no cropping, and no empty space inside an invented frame.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

## basalt_pavise_front.png

Final output pixel size: 920 × 1710

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-6fabde49-af42-4e2f-84d9-a019a95c4311.png`

### Image-tool call 1 (earlier generation/correction)

Output pixel size: 921 × 1707

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_front.png`
- `approved_example_splintered_shield_front.png`
- `approved_example_sunken_anchor_front.png`
- `icon_basalt_pavise.png`
- `guide_basalt_pavise_front.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite basalt_pavise_front.png, a FRONT-facing basalt pavise strapped to the hero's left forearm. No arm is painted. Final native object bounding-box ratio 57:106.
Supplied references in order: 1 ref_hero_front.png = mandatory hero's native chunky pixel-art style; 2 approved_example_splintered_shield_front.png = approved shield finish, stepped contour and SIDE-ON foreshortening; 3 approved_example_sunken_anchor_front.png = approved coarse desaturated iron with large material blocks; 4 icon_basalt_pavise.png = identity, dark volcanic stone, dull iron binding and tiny orange lava only; 5 guide_basalt_pavise_front.png = exact placement angle, proportions and narrow side-on bounding box. Do not paint hero or guide.
SUBJECT: ONE solid continuous mass of DARK BASALT, a tall pavise with a gently pointed top, blunt slightly rounded lower corners, and tall foreshortened oval/kite silhouette. View obliquely SIDE-ON as a left-forearm shield, never flat toward viewer. A clearly visible 3-4 NATIVE-PIXEL THICKNESS BAND runs along the LEFT edge, nearest the body: a broad almost-black vertical side plane about 7% of the entire width, clearly distinct from the stone's front surface. Front face recedes toward the right and is foreshortened, following guide. Top very gently peaked; no tower spikes.
Bind this heavy single stone with EXACTLY TWO broad dull iron bands traversing the face, one about 28% down, the other about 68% down. Simple chunky fastenings only. The bands wrap around left thickness edge. Muted worn gray-brown iron, pale desaturated upper-left blocks and dark undersides. Do not build a full rectangular frame or lattice.
BASALT SURFACE: mostly broad uninterrupted charcoal and slate-gray flat masses, only 3 or 4 stone tones, no individual tiles, no panes, no bricks. EXACTLY TWO or THREE short IRREGULAR JAGGED lava cracks, scattered at different diagonal angles and different heights; asymmetrical wandering broken lightning shapes. Each crack contains only a FEW bright ORANGE pixels at native scale with dark burnt-orange edge. Cracks do not form a continuous central seam, do not connect into a grid, do not cross at right angles, and do not partition the stone into regular panels. At least 80% of stone remains solid quiet dark basalt. No giant bright vein, no orange halo or background spill.
Native readability: heavy tall narrow shield, near-black left thickness, bold iron bands, small irregular orange accents. Match approved chunky finish; do not add fine grain or many cracks.
Center whole object inside 6%-94% canvas height and preserve exact 57:106 object bounding-box shape.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

### Image-tool call 2 (earlier generation/correction)

Output pixel size: 921 × 1708

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-25e4f998-eb3d-454d-859e-c7b261e638cb.png`
- `ref_hero_front.png`
- `guide_basalt_pavise_front.png`
- `approved_example_splintered_shield_front.png`

Exact prompt:

```text
Use case: precise-object-edit.
Correct the PROPORTIONS of the isolated basalt pavise in image 1. Image 2 is the native hero style; image 3 the exact front-view placement and proportion guide; image 4 approved shield finish.
Keep exactly one basalt pavise, side-on front view, LEFT near-black thickness band, gently pointed top, rounded blunt base, exactly TWO broad dull iron bands, THREE irregular jagged orange lava cracks, same muted dark stone, chunky worn iron, thick near-black outline and upper-left light. Keep cracks irregular and separate, no grid or tiles.
The existing stone shield is too skinny within its canvas. WIDEN the complete shield by approximately ONE QUARTER while keeping the same height and front oblique view. The OBJECT bounding box must have EXACT width:height 57:106, so a 1490-pixel-high object is approximately 801 pixels wide. Canvas portrait ratio is also 57:106, and the complete shield fills the central 88% of BOTH canvas WIDTH and HEIGHT, leaving approximately 6% flat green margin all four edges. This is a tall foreshortened shield; preserve a distinct 3-4 native-pixel thickness plane on the LEFT edge. Do not rotate it to face the viewer.
Preserve coarse hand-painted PIXEL ART for final native 57x106, simple large flat colour clusters, 3-4 tones per material. No fine grain, scratches, noise, dithering, tiny ornament or smooth rendering. Green background EVERYWHERE else is one perfectly uniform exact RGB(0,255,0) #00FF00, no shadow, gradient, texture, glow or colour spill. No body, hand, text, guide marker, frame or extra object. Generate ONE raw PNG at largest supported resolution, portrait aspect ratio 57:106.
```

### Image-tool call 3 (selected final output)

Output pixel size: 920 × 1710

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-a4ba84c6-760e-4e69-bdbf-ba077418fc8a.png`
- `guide_basalt_pavise_front.png`
- `approved_example_splintered_shield_front.png`

Exact prompt:

```text
Use case: precise-object-edit.
Edit the SINGLE front basalt pavise in supplied image 1 to correct its bounding-box height and framing ONLY. Same sprite design: solid dark basalt, three irregular lava cracks, exactly two worn iron bands, no grid, side-on front view, thick dark LEFT side plane, gently peaked top and rounded blunt base. Image 2 is exact placement/proportions guide; image 3 approved pixel style.
The current object is too tall for its width. Keep the existing WIDTH of the complete shield, approximately 776 output pixels. SHORTEN the object's HEIGHT by TEN PERCENT, from approximately 1606 to approximately 1444 output pixels. This makes its object bounding-box width:height exactly 57:106 (776:1444). Do not make its height grow. Keep the canvas size approximately 921x1708, portrait 57:106.
CENTER this shortened shield vertically: top near y=132 (7.7% canvas height), bottom near y=1576 (92.3%). Keep existing left/right margins, around 7-9%. Nothing touches edges. This changes only overall proportions/framing; preserve the side-on view, left thickness plane, material identity, wide bands, chunky outlines and irregular cracks.
All native features stay broad coarse pixel clusters for 57x106. Upper-left light, 3-4 flat tones per material, no fine grain, scratches, smooth gradients, glossy shine or new detail. Background and all holes must be ONE flat opaque exact RGB(0,255,0) #00FF00 with zero noise, lighting, vignette, texture, shadow, halo or colour spill. No hands, arm, body, text, marker, frame or extra object. Generate exactly ONE raw PNG at maximum supported resolution and portrait canvas ratio 57:106.
```

## basalt_pavise_rear.png

Final output pixel size: 896 × 1756

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-0bd7271d-be91-451d-b93a-af4bba400b97.png`

### Image-tool call 1 (earlier generation/correction)

Output pixel size: 896 × 1756

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_rear.png`
- `approved_example_splintered_shield_front.png`
- `basalt_pavise_front.png`
- `icon_basalt_pavise.png`
- `guide_basalt_pavise_rear.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE new equipment sprite basalt_pavise_rear.png: the REAR view of the basalt pavise, seen from behind, side-on, with its iron-strapped BACK and a grip visible. Final native OBJECT bounding box is 51x100, width:height exactly 51:100.
Supplied reference images in order: 1 ref_hero_rear.png = native hero rear style; 2 approved_example_splintered_shield_front.png = approved pixel finish and SIDE-ON foreshortened shield; 3 basalt_pavise_front.png = matching front counterpart, identity, two bands, material palette and coarse pixel scale; 4 icon_basalt_pavise.png = dark basalt with dull worn iron binding and very few orange lava pixels; 5 guide_basalt_pavise_rear.png = mandatory placement, angular proportions and rear narrow side-on bounding box.
ONE solid mass of dark basalt, tall pavise with gently pointed top and blunt rounded lower corners, oblique SIDE-ON foreshortened kite/oval, never flat toward viewer. The dark thick side plane is now on the RIGHT EDGE, nearest the body: exactly 3-4 NATIVE pixels of thickness, about 8% of object width, visible the entire edge. Back plane recedes toward LEFT, following rear guide. This is the back, not a front shield with reversed cracks.
Rear face: mostly quiet charcoal solid basalt in 3-4 broad flat gray tones. EXACTLY TWO broad muted worn iron binding bands around the shield at about 27% and 68% height; two simple dark attachment straps supporting ONE stout short horizontal iron grip, wrapped with dark leather, clearly visible between those bands around mid-height. Grip and straps integrated into this one shield, no loose accessory. No hands. Use a few broad steel-gray highlight blocks on grip/fastenings, never glossy.
Only TWO tiny irregular jagged lava cracks with a FEW bright orange native pixels each, separated and asymmetrical near the outer back stone. The rear is darker and iron-strapped; no full-height central vein, no grid, no rectangular panes, no tiles, no window frame, no connected crack network. Leave at least 85% of back stone dark and uninterrupted. No glow spills onto green.
Object shape matters: complete bounding-box width:height must be 51:100, at native scale 51 pixels wide and 100 tall. Use a portrait canvas 51:100 and make object fill the centered 88% of BOTH width and height, leaving approximately 6% green edge margin on every side. Retain oblique side-on view while matching this ratio.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

### Image-tool call 2 (selected final output)

Output pixel size: 896 × 1756

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-552f1acd-63a9-4e82-adf7-801de1caa091.png`
- `guide_basalt_pavise_rear.png`
- `approved_example_splintered_shield_front.png`

Exact prompt:

```text
Use case: precise-object-edit.
Edit the SINGLE rear-view basalt pavise in supplied image 1 to correct its object proportions and framing ONLY. Supporting image 2 exact rear placement guide; image 3 approved shield chunky pixel finish.
KEEP this same solid dark basalt pavise with its rear back-facing iron straps and horizontal leather-wrapped grip, EXACTLY TWO wide dull iron bands, only TWO separate tiny irregular orange lava cracks, thick near-black outline, gently pointed top, rounded base, and thick dark RIGHT-edge side plane. Keep this a SIDE-ON REAR VIEW, never a front face. No grid or panes.
PROPORTION CORRECTION: existing object is approximately 658 pixels wide by 1620 high and is too narrow. WIDEN the complete object by SEVENTEEN PERCENT to approximately 768 pixels, and SHORTEN its height by SEVEN PERCENT to approximately 1506 pixels. The complete OBJECT bounding box MUST be width:height 51:100, exactly 0.51; approximately 768x1506. Do not increase object height or keep the skinny previous proportions. Preserve the oblique view and RIGHT thickness band, which remains 3-4 native pixels thick.
Use same portrait canvas aspect ratio 51:100, approximately 896x1756. Center corrected whole object with approximately 7% margin all four edges: left x≈64, right x≈832, top y≈125, bottom y≈1631. Nothing touches the canvas edges.
Retain coarse hand-painted dark-fantasy PIXEL ART for native 51x100, big flat colour clusters, only 3-4 desaturated dark stone/iron/leather tones, UPPER LEFT light, no fine grain, scratches, noise, dithering, glossy shine or new details. EVERY background pixel is the exact same opaque RGB(0,255,0) #00FF00, no gradient, lighting, noise, vignette, texture, shadow or glow spill. No hand, arm, body, text, marker, frame or extra object. Output ONE raw PNG at largest supported resolution and portrait canvas ratio 51:100.
```

## grapple_hook_front.png

Final output pixel size: 1024 × 1536

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-1bf067ce-8bd8-4793-91a5-54f8ce07bb2a.png`

### Image-tool call 1 (selected final output)

Output pixel size: 1024 × 1536

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_front.png`
- `approved_example_sunken_anchor_front.png`
- `approved_example_war_maul_front.png`
- `icon_grapple_hook.png`
- `guide_grapple_hook_front.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE equipment sprite grapple_hook_front.png: a BOLD three-pronged iron grappling hook hanging DOWN on a short pale-hemp rope, FRONT view. Final native OBJECT bounding box is 40x60, width:height 2:3.
Reference image roles in order: 1 ref_hero_front.png = native hero chunky hand-painted pixel-art style; 2 approved_example_sunken_anchor_front.png = approved thick dark outline, bold heavy iron geometry and coarse readable metal blocks; 3 approved_example_war_maul_front.png = approved worn-metal and leather finish; 4 icon_grapple_hook.png = identity and three curved iron prongs with attached hemp coil; 5 guide_grapple_hook_front.png = exact placement and bounding proportions, cyan circle is future fist centre, near 60% of object width and 13% of its height.
SUBJECT AND HOLD: the top quarter is a CHUNKY COIL of PALE HEMP ROPE looped over the future fist at the guide's cyan centre. The future fist is absent; paint the rope loop complete, with its thick rope crossing where the fist will be. Coil is a compact bundle of THREE large pale rope loops, upper-left lit ivory/beige, tan shadow, near-black outline, no fine fibers. Coil sits at the TOP, does not hang halfway down beside hook or dominate the silhouette. A SHORT thick rope end descends from that coil to the hook's iron eye and collar, ending by roughly 35% of overall height.
The IRON HOOK occupies the LOWER TWO THIRDS of total height and nearly the full native 40-pixel width: large central shank, THREE distinct chunky prongs, two wide lateral curved prongs and one strongly foreshortened forward prong. The hook hangs down with shank below rope, prongs curving out and upward to bold barbed tips, matching the icon's recognizable iron tool. The THIRD prong is visibly a curved hook, not just a downward needle. This is a single connected grappling-hook assembly, not three hooks. No giant rope bundle replacing the iron object.
HIGH-CONTRAST METAL: large bright WORN-STEEL highlight planes along the upper-left-facing surfaces of all three prongs, pale desaturated steel-gray/ivory, with muted medium gray body and deep charcoal undersides. Keep prongs thick and broad, around 5-7 native pixels through their bodies, unmistakable against dark legs and cloak after compositing. At least a third of each prong's visible area is a strong pale steel block. Only a couple broad muted rust patches, no dark brown all-over metal, no shiny/glossy rendering.
Use coarse pixel clusters as though painting directly at 40x60, no fine rope fibers or grain. Center object in the central 88% of BOTH width and height on a 2:3 portrait canvas, approximately 6% green margins. Complete object bounding box exactly 40:60.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

## grapple_hook_rear.png

Final output pixel size: 1024 × 1536

Selected raw output: `/Users/borgerding/.codex/generated_images/01a11218-66fc-7730-bb81-ce546053e3a9/exec-a6573d50-a44a-4428-8a6e-ab1c061c412a.png`

### Image-tool call 1 (selected final output)

Output pixel size: 1024 × 1536

Reference images supplied, in order (workspace files are listed by the exact filename used; generated references reflect their then-current version):
- `ref_hero_rear.png`
- `approved_example_sunken_anchor_front.png`
- `grapple_hook_front.png`
- `icon_grapple_hook.png`
- `guide_grapple_hook_rear.png`

Exact prompt:

```text
Use case: stylized-concept.
Generate ONE equipment sprite grapple_hook_rear.png: a BOLD three-pronged iron grappling hook hanging DOWN on a short pale-hemp rope, REAR view, seen from behind. Final native OBJECT bounding box is 40x60, width:height 2:3.
Reference image roles in order: 1 ref_hero_rear.png = native hero chunky hand-painted pixel-art style; 2 approved_example_sunken_anchor_front.png = approved thick dark outline, bold heavy iron geometry and coarse readable metal blocks; 3 grapple_hook_front.png = matching front counterpart, same heavy three-pronged iron tool, bright-steel highlights, rust blocks and chunky pale-hemp coil; 4 icon_grapple_hook.png = identity and three curved iron prongs with attached hemp coil; 5 guide_grapple_hook_rear.png = exact placement and bounding proportions, cyan circle is future fist centre, near 40% of object width and 13% of its height.
SUBJECT AND HOLD: the top quarter is a CHUNKY COIL of PALE HEMP ROPE looped over the future fist at the guide's cyan centre. The future fist is absent; paint the rope loop complete, with its thick rope crossing where the fist will be. Coil is a compact bundle of THREE large pale rope loops, upper-left lit ivory/beige, tan shadow, near-black outline, no fine fibers. Coil sits at the TOP, does not hang halfway down beside hook or dominate the silhouette. A SHORT thick rope end descends from that coil to the hook's iron eye and collar, ending by roughly 35% of overall height.
The IRON HOOK occupies the LOWER TWO THIRDS of total height and nearly the full native 40-pixel width: large central shank, THREE distinct chunky prongs, two wide lateral curved prongs and one strongly foreshortened third prong seen from the back. The hook hangs down with shank below rope, prongs curving out and upward to bold barbed tips, matching the icon's recognizable iron tool. The THIRD prong is visibly a curved hook, not just a downward needle. Rear-facing construction: coil shifts to the upper-left so its loop is centred near 40% of bounding-box width, matching guide. Show back faces of iron eye, collar and prong bases. The third prong passes behind the central shank, with its bent hooked tip still clearly visible below; change the occlusion from the front counterpart instead of merely copying it. Maintain upper-left lighting and bright worn-steel readability on all three prongs.
This is a single connected grappling-hook assembly, not three hooks. No giant rope bundle replacing the iron object.
HIGH-CONTRAST METAL: large bright WORN-STEEL highlight planes along the upper-left-facing surfaces of all three prongs, pale desaturated steel-gray/ivory, with muted medium gray body and deep charcoal undersides. Keep prongs thick and broad, around 5-7 native pixels through their bodies, unmistakable against dark legs and cloak after compositing. At least a third of each prong's visible area is a strong pale steel block. Only a couple broad muted rust patches, no dark brown all-over metal, no shiny/glossy rendering.
Use coarse pixel clusters as though painting directly at 40x60, no fine rope fibers or grain. Center object in the central 88% of BOTH width and height on a 2:3 portrait canvas, approximately 6% green margins. Complete object bounding box exactly 40:60.
STYLE AND OUTPUT: Match supplied native hero and approved equipment: hand-painted dark-fantasy PIXEL ART for Escape the Umbra's segmented 255x255 hero. Thick near-black stepped outline, chunky readable geometry, big contiguous square colour clusters, 3-4 flat tones per material, UPPER LEFT light, earthy grimy muted palette, desaturated worn metal. Paint as if at the stated final native size and enlarge with nearest-neighbour pixel blocks. No feature finer than about 1/15 of object width. No fine grain, scratches, noise, dithering, tiny ornament, smooth gradients, glossy shine, neon, cute/cartoon style, photography or vector curves.
One isolated equipment object ONLY, no hand, arm, body, hero, text, labels, frame, guide graphics, cyan marker, shadow or ground. Every background and hole pixel is the same exact flat chroma green RGB(0,255,0) #00FF00; exactly ONE background colour, zero noise, lighting, texture, vignette, gradient, colour spill or glow. No green on object. Give all sides approximately 6% image-edge margin. Object bounding box MUST match stated final native width:height, regardless of canvas ratio. Use the largest output pixel size this built-in tool supports and closest supported portrait canvas ratio to the object's bounding box. Output ONE raw PNG, never a pair, sheet or variants.
```

## Read-only verification

All eight final files match their selected raw image-tool outputs byte-for-byte. All 25 provided reference PNGs retain their original hashes.

Approximate object bounds below use a loose green-background threshold for inspection only; no masks or processed images were saved.

| File | Output pixels | Approximate object bounds |
| --- | --- | --- |
| galewhip_front.png | 724 × 2172 | 278 × 1920 |
| galewhip_rear.png | 724 × 2172 | 268 × 1912 |
| parrying_dagger_front.png | 1042 × 1509 | 828 × 1291 |
| parrying_dagger_rear.png | 1044 × 1507 | 854 × 1292 |
| basalt_pavise_front.png | 920 × 1710 | 685 × 1304 |
| basalt_pavise_rear.png | 896 × 1756 | 730 × 1540 |
| grapple_hook_front.png | 1024 × 1536 | 895 × 1389 |
| grapple_hook_rear.png | 1024 × 1536 | 895 × 1382 |
