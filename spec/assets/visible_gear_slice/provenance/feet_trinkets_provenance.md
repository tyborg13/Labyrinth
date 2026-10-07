# Image generation provenance

Tool: built-in `image_gen.imagegen` (`image_gen__imagegen`). Each requested file was generated in a separate tool call, with `transparent_background: false`. No artwork was drawn with code. Generated PNG files were copied into this directory without changing their pixels.

The output dimensions below are measured from the saved PNGs. Native sizes are the intended in-game equipment bounding-box dimensions, not the generated image dimensions.

## Validation status

All 14 requested PNG files are present. References were preserved unchanged. The unprocessed image-tool outputs contain small green-background color variations and some silhouette/bounding-box drift. Exact #00FF00 normalization and native-grid/guide fitting are pending the cleanup choice requested from the user.

## ironshod_sabatons_front_foot_r.png

- Saved output pixel size: **1774 × 887**
- Intended native object size: **40 × 20**
- Supplied reference images, in order:
  1. `shape_front_foot_r.png`
  2. `context_front_foot_r.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_ironshod_sabatons.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-067b1fec-fb37-4679-b882-0c46e68f989e.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
Create ONE isolated replacement boot sprite for Escape the Umbra: ironshod_sabatons_front_foot_r.png.
References in order: (1) shape_front_foot_r.png is the GEOMETRY MASTER/edit target; (2) context_front_foot_r.png establishes the viewpoint and the low cuff hidden by trouser wrap; (3) ref_hero_front.png is the mandatory pixel-art hand, palette, outline and lighting master; (4) ref_hero_rear.png is supporting style; (5) icon_ironshod_sabatons.png supplies equipment identity only, not its tall shaft, paired composition or detailed illustration style.
Repaint the first reference as ONE Ironshod Sabaton: articulated, worn gunmetal steel over dark leather; 3 or 4 broad overlapping steel lames over the instep, restrained pointed steel toe-cap, low steel ankle-cuff plate, dark iron-studded sole. Cold muted upper-left highlights. Keep EXACTLY the first reference's silhouette, low profile, perspective, sole line, diagonal toe-to-heel direction and top cuff opening. Toe remains at lower LEFT and cuff/heel at upper RIGHT. This is the foreshortened front-view right foot, NOT a generic tall side-view boot. Do not extend its shaft; trouser wrap covers the cuff. Plate may grow by at most ONE native pixel.
Final native object bounding box: EXACTLY 40 pixels wide by 20 pixels high, ratio 2:1. Draw as an authentic 40x20 hand-painted pixel sprite and enlarge it with square, chunky native pixel clusters, hard stair-step silhouette and near-black outline. Match the hero's artist exactly: 3-5 tones per material, earthy grimy dark fantasy, desaturated worn steel, upper-left light, broad readable surfaces. No texture, scratch, stud or ornament finer than 1/25 of object width; NO smooth curves, anti-aliased vector contours, micro-detail or high-resolution brush grain.
Use the LARGEST supported landscape image size closest to 2:1 (prefer 3840x1920 if supported). Object occupies about 88% of width and height, with about 6% clean margin on EACH side; its own bounding box must remain exactly 2:1 regardless of canvas ratio.
Every pixel outside the boot, including any cuff opening, is perfectly flat opaque chroma green RGB(0,255,0), #00FF00. No gradients or texture in green. No cast shadow, ground, glow halo, reflected green light. One boot only; no pair, hand, arm, leg, trousers, character, text, label, frame, watermark. Never shiny, glossy, cartoonish, cute, neon or photographic. Generate only this ONE image.
```

## ironshod_sabatons_front_foot_l.png

- Saved output pixel size: **1448 × 1086**
- Intended native object size: **40 × 30**
- Supplied reference images, in order:
  1. `shape_front_foot_l.png`
  2. `context_front_foot_l.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_ironshod_sabatons.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-649f6582-057d-4c12-8a11-9b5b2a318826.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: ironshod_sabatons_front_foot_l.png
References in order: image 1 shape_front_foot_l.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_front_foot_l.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_ironshod_sabatons.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Three-quarter front-view boot, broad toe at lower LEFT, short upright ankle cuff at upper RIGHT. Preserve the slanted curved dark sole from lower-left toe to upper-right heel and the original cuff opening/top edge under the trouser wrap.
Equipment: Ironshod Sabatons: articulated worn gunmetal steel over dark leather boots. A few broad overlapping steel lames over instep, restrained pointed steel toe-cap fitted INSIDE existing toe silhouette, steel plate at ankle cuff, iron-studded dark sole. Cold desaturated upper-left highlights, dark seams between lames. Keep icon_ironshod_sabatons.png's identity, but NOT its tall boot shaft, paired composition or finer illustration detail.
Native bounding box: 40x30 pixels. Construct the drawing as if ONLY 40 native pixel columns and 30 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 40:30.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## ironshod_sabatons_rear_foot_r.png

- Saved output pixel size: **1599 × 984**
- Intended native object size: **39 × 24**
- Supplied reference images, in order:
  1. `shape_rear_foot_r.png`
  2. `context_rear_foot_r.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_ironshod_sabatons.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-b316f2f1-296c-46a1-9054-b367e1ece105.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: ironshod_sabatons_rear_foot_r.png
References in order: image 1 shape_rear_foot_r.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_rear_foot_r.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_ironshod_sabatons.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Three-quarter rear-view LOW boot, visible heel/ankle on the LEFT, toe extending to the upper RIGHT. Preserve the wide left heel surface, original slope of sole, low cuff and exact original top edge under the trouser wrap.
Equipment: Ironshod Sabatons: articulated worn gunmetal steel over dark leather boots. A few broad overlapping steel lames over instep, restrained pointed steel toe-cap fitted INSIDE existing toe silhouette, steel plate at ankle cuff, iron-studded dark sole. Cold desaturated upper-left highlights, dark seams between lames. Keep icon_ironshod_sabatons.png's identity, but NOT its tall boot shaft, paired composition or finer illustration detail.
Native bounding box: 39x24 pixels. Construct the drawing as if ONLY 39 native pixel columns and 24 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 39:24.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## ironshod_sabatons_rear_foot_l.png

- Saved output pixel size: **1444 × 1089**
- Intended native object size: **33 × 22**
- Supplied reference images, in order:
  1. `shape_rear_foot_l.png`
  2. `context_rear_foot_l.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_ironshod_sabatons.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-282c4856-a656-4ea6-8e2b-31431009e231.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: ironshod_sabatons_rear_foot_l.png
References in order: image 1 shape_rear_foot_l.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_rear_foot_l.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_ironshod_sabatons.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Foreshortened three-quarter rear-view LOW boot, heel at lower LEFT, toe extending diagonally toward the upper RIGHT. Preserve the short left ankle/heel, oblique top plane, diagonal sole line and low cuff edge under trouser wrap. Do not mistake the upper-right toe for a tall ankle shaft.
Equipment: Ironshod Sabatons: articulated worn gunmetal steel over dark leather boots. A few broad overlapping steel lames over instep, restrained pointed steel toe-cap fitted INSIDE existing toe silhouette, steel plate at ankle cuff, iron-studded dark sole. Cold desaturated upper-left highlights, dark seams between lames. Keep icon_ironshod_sabatons.png's identity, but NOT its tall boot shaft, paired composition or finer illustration detail.
Native bounding box: 33x22 pixels. Construct the drawing as if ONLY 33 native pixel columns and 22 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 33:22.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## emberstriders_front_foot_r.png

- Saved output pixel size: **1774 × 887**
- Intended native object size: **40 × 20**
- Supplied reference images, in order:
  1. `shape_front_foot_r.png`
  2. `context_front_foot_r.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_emberstriders.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-c7582389-47d4-4756-8ea7-949d9eb1b36c.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: emberstriders_front_foot_r.png
References in order: image 1 shape_front_foot_r.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_front_foot_r.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_emberstriders.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Foreshortened LOW boot, toe at lower LEFT and low cuff/heel at upper RIGHT; no tall shaft. Preserve its black sole sweeping diagonally down toward the toe and the original top edge covered by trouser wrap.
Equipment: Emberstriders: scorched dark RED-BROWN leather with broad rusty RED-ORANGE planes so the boot reads red-orange at a glance; blackened toe, heavy dark sole. A few discontinuous ember-orange cracks along sole edge and around cuff, with at most 2 or 3 native bright orange-yellow pixels. Light stays INSIDE leather/sole. No flames, no sparks, no outward glow. Keep icon_emberstriders.png's identity through burnt red leather and glowing sole seams, but do not copy its flames, tall boot shafts, pair or illustration detail.
Native bounding box: 40x20 pixels. Construct the drawing as if ONLY 40 native pixel columns and 20 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 40:20.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## emberstriders_front_foot_l.png

- Saved output pixel size: **1448 × 1086**
- Intended native object size: **40 × 30**
- Supplied reference images, in order:
  1. `shape_front_foot_l.png`
  2. `context_front_foot_l.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_emberstriders.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-91304d88-0493-4d2a-9694-37a8d267dcf8.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: emberstriders_front_foot_l.png
References in order: image 1 shape_front_foot_l.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_front_foot_l.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_emberstriders.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Three-quarter front-view boot, broad toe at lower LEFT, short upright ankle cuff at upper RIGHT. Preserve the slanted curved dark sole from lower-left toe to upper-right heel and the original cuff opening/top edge under the trouser wrap.
Equipment: Emberstriders: scorched dark RED-BROWN leather with broad rusty RED-ORANGE planes so the boot reads red-orange at a glance; blackened toe, heavy dark sole. A few discontinuous ember-orange cracks along sole edge and around cuff, with at most 2 or 3 native bright orange-yellow pixels. Light stays INSIDE leather/sole. No flames, no sparks, no outward glow. Keep icon_emberstriders.png's identity through burnt red leather and glowing sole seams, but do not copy its flames, tall boot shafts, pair or illustration detail.
Native bounding box: 40x30 pixels. Construct the drawing as if ONLY 40 native pixel columns and 30 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 40:30.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## emberstriders_rear_foot_r.png

- Saved output pixel size: **1599 × 984**
- Intended native object size: **39 × 24**
- Supplied reference images, in order:
  1. `shape_rear_foot_r.png`
  2. `context_rear_foot_r.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_emberstriders.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-22f162e0-e8a0-4335-be65-13f763c400bc.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: emberstriders_rear_foot_r.png
References in order: image 1 shape_rear_foot_r.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_rear_foot_r.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_emberstriders.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Three-quarter rear-view LOW boot, visible heel/ankle on the LEFT, toe extending to the upper RIGHT. Preserve the wide left heel surface, original slope of sole, low cuff and exact original top edge under the trouser wrap.
Equipment: Emberstriders: scorched dark RED-BROWN leather with broad rusty RED-ORANGE planes so the boot reads red-orange at a glance; blackened toe, heavy dark sole. A few discontinuous ember-orange cracks along sole edge and around cuff, with at most 2 or 3 native bright orange-yellow pixels. Light stays INSIDE leather/sole. No flames, no sparks, no outward glow. Keep icon_emberstriders.png's identity through burnt red leather and glowing sole seams, but do not copy its flames, tall boot shafts, pair or illustration detail.
Native bounding box: 39x24 pixels. Construct the drawing as if ONLY 39 native pixel columns and 24 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 39:24.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## emberstriders_rear_foot_l.png

- Saved output pixel size: **1536 × 1024**
- Intended native object size: **33 × 22**
- Supplied reference images, in order:
  1. `shape_rear_foot_l.png`
  2. `context_rear_foot_l.png`
  3. `ref_hero_front.png`
  4. `ref_hero_rear.png`
  5. `icon_emberstriders.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-fb563fa9-bf8d-40f7-8a27-b335a75f94ab.png`

### Exact prompt sent to the image tool

```text
Use case: precise-object-edit.
File: emberstriders_rear_foot_l.png
References in order: image 1 shape_rear_foot_l.png is the EXACT SILHOUETTE/PERSPECTIVE edit target; image 2 context_rear_foot_l.png shows its place on the hero (context only, do NOT render hero); image 3 ref_hero_front.png is the style master; image 4 ref_hero_rear.png supports style; image 5 icon_emberstriders.png is equipment identity only.
Repaint the boot in image 1 as the new equipment while retaining EXACTLY its silhouette, viewpoint, perspective, sole line and top cuff opening. At most ONE native pixel of expansion for a plate. Foreshortened three-quarter rear-view LOW boot, heel at lower LEFT, toe extending diagonally toward the upper RIGHT. Preserve the short left ankle/heel, oblique top plane, diagonal sole line and low cuff edge under trouser wrap. Do not mistake the upper-right toe for a tall ankle shaft.
Equipment: Emberstriders: scorched dark RED-BROWN leather with broad rusty RED-ORANGE planes so the boot reads red-orange at a glance; blackened toe, heavy dark sole. A few discontinuous ember-orange cracks along sole edge and around cuff, with at most 2 or 3 native bright orange-yellow pixels. Light stays INSIDE leather/sole. No flames, no sparks, no outward glow. Keep icon_emberstriders.png's identity through burnt red leather and glowing sole seams, but do not copy its flames, tall boot shafts, pair or illustration detail.
Native bounding box: 33x22 pixels. Construct the drawing as if ONLY 33 native pixel columns and 22 rows are available, then enlarge those coarse square pixels. The object bounding box ratio is EXACTLY 33:22.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## cracked_lantern_front.png

- Saved output pixel size: **948 × 1659**
- Intended native object size: **12 × 21**
- Supplied reference images, in order:
  1. `guide_cracked_lantern_front.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_cracked_lantern.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-e216f3ec-587a-46d9-8a88-31522f555c90.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: cracked_lantern_front.png
References in order: image 1 guide_cracked_lantern_front.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_cracked_lantern.png supplies item identity, not its illustration style or a different angle.
Subject: Cracked Lantern, FRONT view: small iron-and-brass belt lantern with a SHORT thin hook at top, a small ring handle, squat iron cage frame, simple dull-brass cap and base, two broad cracked amber glass panes, dim warm candle glow INSIDE. Follow the guide's straight vertical hang and its exact rectangular cage proportions; top thin stem occupies about the upper 4 of 21 native rows, cage below fills 12x17. Tiny 12-pixel-wide sprite: dark vertical cage uprights, one diagonal crack, only one or two warm candle pixels. No glow outside lantern.
FINAL NATIVE SIZE 12x21 pixels, EXACT object bounding-box ratio 12:21. Draw with ONLY 12 coarse native columns and 21 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## cracked_lantern_rear.png

- Saved output pixel size: **948 × 1659**
- Intended native object size: **12 × 21**
- Supplied reference images, in order:
  1. `guide_cracked_lantern_rear.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_cracked_lantern.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-b9b5c93b-4cfe-4554-bbd6-5e3973288e14.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: cracked_lantern_rear.png
References in order: image 1 guide_cracked_lantern_rear.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_cracked_lantern.png supplies item identity, not its illustration style or a different angle.
Subject: Cracked Lantern, REAR view: same small iron-and-brass belt lantern viewed from the opposite side, slightly darker than front. SHORT thin hook at top, small ring handle, squat iron cage frame, dull-brass cap/base, broad cracked amber glass panes with dim warm candle glow INSIDE. Follow the rear guide's straight vertical hang and exact rectangular cage proportions; thin stem occupies about upper 4 of 21 native rows, cage below fills 12x17. Opposite pane/iron upright more prominent, one coarse diagonal crack, only one or two muted warm candle pixels. No halo.
FINAL NATIVE SIZE 12x21 pixels, EXACT object bounding-box ratio 12:21. Draw with ONLY 12 coarse native columns and 21 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## crown_of_thorns_front.png

- Saved output pixel size: **1983 × 793**
- Intended native object size: **56 × 16**
- Supplied reference images, in order:
  1. `guide_crown_of_thorns_front.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_crown_of_thorns.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-1b959f50-2fd5-43e6-994c-9d0fbeba92a1.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: crown_of_thorns_front.png
References in order: image 1 guide_crown_of_thorns_front.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_crown_of_thorns.png supplies item identity, not its illustration style or a different angle.
Subject: Crown of Thorns, FRONT three-quarter view: thin circlet of braided dried BLACK-BROWN thorny vines worn around head over hair. Isolate the crown alone, empty center green. Match the guide's extremely WIDE SHALLOW ellipse, EXACT outer proportions 56:16, with perspective compressed vertically. Thin vine band, solid continuous heavier near/front lower arc; far/back upper arc thinner and broken into 3 or 4 segments where spiky hair would hide it (show green gaps, NO hair). Large sharp pale-tipped thorns point outward and upward, 2 or 3 thorns faintly dark-red stained. All thorns must stay within 56x16 native bounding box. Keep icon identity as a braided thorn circlet but use dried brown/black vines, no green foliage, no tall spikes that increase height. This is a flat head overlay, not a round wreath or a bowl.
FINAL NATIVE SIZE 56x16 pixels, EXACT object bounding-box ratio 56:16. Draw with ONLY 56 coarse native columns and 16 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## crown_of_thorns_rear.png

- Saved output pixel size: **1983 × 793**
- Intended native object size: **58 × 16**
- Supplied reference images, in order:
  1. `guide_crown_of_thorns_rear.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_crown_of_thorns.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-210b944f-6cab-479c-bbea-72e651881014.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: crown_of_thorns_rear.png
References in order: image 1 guide_crown_of_thorns_rear.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_crown_of_thorns.png supplies item identity, not its illustration style or a different angle.
Subject: Crown of Thorns, REAR three-quarter view: same thin braided dried BLACK-BROWN thorn circlet seen from behind on the hero's head. Crown alone, empty center green. Match rear guide's extremely WIDE SHALLOW ellipse with EXACT 58:16 outer proportions. A solid near lower arc of braided vines and a thinner far upper arc broken into 3 or 4 segments where spiky hair hides it, with green gaps and no hair painted. Rear side a little darker, subtly reverse braid joins/thorn arrangement. Readable pale-tipped thorns stick outward/upward, 2 or 3 faint dark-red stained thorn tips. Include all thorns within 58x16 bounds; no taller crown, no round wreath, no bowl. No fresh green vines or foliage.
FINAL NATIVE SIZE 58x16 pixels, EXACT object bounding-box ratio 58:16. Draw with ONLY 58 coarse native columns and 16 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## war_dancer_sash_front.png

- Saved output pixel size: **1606 × 979**
- Intended native object size: **59 × 36**
- Supplied reference images, in order:
  1. `guide_war_dancer_sash_front.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_war_dancer_sash.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-1b113ac1-967b-4e73-9899-39bf88704eae.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: war_dancer_sash_front.png
References in order: image 1 guide_war_dancer_sash_front.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_war_dancer_sash.png supplies item identity, not its illustration style or a different angle.
Subject: War Dancer's Sash, FRONT three-quarter view: crimson silk waist wrap fitted over belt in the guide's pose. Match magenta shape precisely: long narrow waist band slopes slightly DOWN from image LEFT to image RIGHT, band about 7-9 of 36 native rows thick. Compact knot at hero's RIGHT hip, which is IMAGE LEFT, near left end of band. TWO hanging silk tails on IMAGE LEFT, one longer; narrow separated strips descend almost vertically with slight splay, ending in a little coarse fringe. Image-right side below waist band is all green, no fabric apron. Deep muted crimson, darker blood-red broad folds, a thin dull-gold thread trim. Cloth is worn matte silk, no glossy shine. Retain icon's crimson wrap/knot/two-tail identity; user description and guide override icon's purple cords, fangs and ornaments: do not add charms, teeth, ropes or additional hanging objects.
FINAL NATIVE SIZE 59x36 pixels, EXACT object bounding-box ratio 59:36. Draw with ONLY 59 coarse native columns and 36 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## war_dancer_sash_rear.png

- Saved output pixel size: **1586 × 992**
- Intended native object size: **61 × 38**
- Supplied reference images, in order:
  1. `guide_war_dancer_sash_rear.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_war_dancer_sash.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-b360c582-9e49-4124-9be8-e30544c34c3a.png`

### Exact prompt sent to the image tool

```text
Use case: stylized-concept.
File: war_dancer_sash_rear.png
References in order: image 1 guide_war_dancer_sash_rear.png is an EXACT placement, viewpoint, angle and proportions guide: ONLY turn the MAGENTA equipment area into the isolated object, using yellow rectangle as native bounding box. Neither magenta nor yellow guides nor hero should appear in output. Image 2 ref_hero_front.png is the mandatory style master. Image 3 ref_hero_rear.png supports rear perspective. Image 4 icon_war_dancer_sash.png supplies item identity, not its illustration style or a different angle.
Subject: War Dancer's Sash, REAR three-quarter view: same crimson silk waist wrap from behind. EXACT magenta silhouette and angle: long nearly horizontal slim waist band, about 7-8 of 38 native rows thick; compact knot at hero's RIGHT hip, which in the rear guide is IMAGE RIGHT. TWO separate hanging tails at IMAGE RIGHT, gently slanted down toward the right: inner/image-left tail LONGER, outer/image-right tail SHORTER, both end in a few coarse fringe pixels. Image-left side below waist band entirely green. No apron, no giant bow. Deep muted crimson with dark red broad fold shapes and thin dull-gold thread trim; rear a little darker. Keep icon's crimson wrap/knot/two-tail identity but do not copy icon's purple cords, teeth, pendants or ornaments.
FINAL NATIVE SIZE 61x38 pixels, EXACT object bounding-box ratio 61:38. Draw with ONLY 61 coarse native columns and 38 rows worth of pixel detail and enlarge square pixels. Keep the guide's width, height, angle and placement of all parts within the object. Extract equipment conceptually from guide and show the equipment ONLY, enlarged and centered with margin.
Project: Escape the Umbra. Asset type: one isolated, independently animated equipment cutout for the 255x255 hero.
STYLE MASTER: ref_hero_front.png. Match EXACTLY the hero's hand-painted dark-fantasy PIXEL-ART sprite hand, palette and block size. Chunky readable shapes, hard square stair-step native pixels, dark near-black silhouette outline, 3-5 discrete tones per material, upper-left light. Muted earthy grimy palette, desaturated worn metal. Never shiny, glossy, cartoonish, cute, neon, photographic or smooth vector. Paint as native-size pixel art enlarged, with no texture or ornament finer than about 1/25 of object width. Prioritize large forms that survive native-size reduction.
OUTPUT: ONE equipment object only. No hand, arm, leg, body, hair, face, character, text, labels, frame or watermark. Center the isolated object in a perfectly flat opaque #00FF00 / RGB(0,255,0) background everywhere else, including holes. The background MUST be the EXACT same single color everywhere, no compression noise, color shifts, texture, gradients, cast shadows, ground or glow halo. No green light on the object. Leave about 6% margin on every side; nothing touches an image edge. Use the LARGEST supported image size whose aspect ratio is closest to the specified native bounding-box ratio. The object's own bounding box MUST have that exact native width:height ratio regardless of canvas ratio. Render only ONE image for this request.
```

## Design-owner review and Cracked Lantern V2 revision — 2026-10-05

The design owner approved the raw original equipment outputs, including all eight boots, both crowns and both sashes, and requested no cleanup or normalization. The earlier pending-cleanup note is superseded by that review. All existing PNG files, including the original lantern pair and every reference image, remain unchanged.

The two new lantern files below were generated with the built-in image tool and copied byte-for-byte from the selected image-tool outputs. No image was edited outside the image tool. Each pass generated one image with `transparent_background: false`.

### cracked_lantern_front_v2.png

- Output pixel size: **935 × 1683**
- Intended final native object size: **15 × 27** (aspect **15:27**, or **5:9**).
- Selected generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-fc1dd69e-0ebd-4742-93c0-82e1705ea079.png`

#### Initial front V2 generation

- Image-tool output pixel size for this pass: **935 × 1683**
- Supplied reference images, in order:
  1. `ref_hero_front.png`
  2. `icon_cracked_lantern.png`
  3. `cracked_lantern_front.png`
  4. `guide_cracked_lantern_front.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-6d6ca46d-a02a-4b6e-b5cd-3b58a2adf467.png`

Exact prompt sent to the image tool:

```text
Use case: stylized-concept.
Asset: cracked_lantern_front_v2.png, ONE isolated FRONT-view Cracked Lantern equipment sprite for the segmented 255x255 hero in Escape the Umbra.
Reference images in order:
1. ref_hero_front.png is the mandatory ARTIST/STYLE/PIXEL SCALE master. Match its hand-painted dark-fantasy sprite style exactly.
2. icon_cracked_lantern.png supplies the recognizable lantern identity: small ring handle, short top attachment, capped iron cage, cracked glass and flame within.
3. cracked_lantern_front.png is the previous version, used only for lantern identity and front three-quarter perspective. REVISION: its brown/brass cap and cage and tiny dim glow must be replaced by blackened iron and a substantially larger luminous glass area. Do not preserve its brass palette or tiny flame.
4. guide_cracked_lantern_front.png shows the straight belt-hanging orientation and front perspective only. Its original 12x21 size is superseded by the new 15x27 native size. Do not render the hero, magenta shape or yellow guide.
DESIGN: One small hand lantern hanging vertically, with a compact ring handle and a SHORT hook at the very top. The cap, cage uprights, base and handle are DARK BLACKENED IRON, predominantly near-black/charcoal with only a few dull desaturated grey highlights from UPPER LEFT. Keep the iron matte, worn and grimy. No brass or brown metal. A dark near-black silhouette and cap must contrast strongly with the hero's brown leather.
The glass panes are noticeably LARGER, with slender cage uprights leaving a broad unobstructed luminous amber centre. Strong WARM AMBER panes surround a bright YELLOW-ORANGE flame core that occupies the CENTRE THIRD of the entire lantern, approximately 5 native pixels wide by 9 native pixels tall within the central cage. This is a large connected, clearly readable point of candlelight, not one tiny isolated bright pixel. The broad yellow-orange core is the main visual cue at native size. Use 3-5 warm discrete tones in the glass/fire, including muted orange-amber margins and a bright golden-yellow heart. One pane has ONE visibly cracked, coarse diagonal line. Keep the crack readable without bisecting or hiding the bright core.
All emitted light is confined INSIDE the glass/cage silhouette. No light rays, halo, bloom, exterior flames, sparks or glowing background. Iron cap and base remain very dark; a minimal warm inner-rim accent may be contained within the object.
FINAL NATIVE OBJECT SIZE: EXACTLY 15 pixels wide by 27 pixels tall, object bounding-box aspect ratio 15:27 = 5:9. Design this as an authentic 15x27 pixel sprite enlarged: coarse square pixel clusters, thick readable silhouette, hard stair-step outline, simple large shapes, no more detail than those 15 columns and 27 rows can carry. Short hook and SMALL ring at top, squat cap, broad glass cage and simple base. No texture or ornament finer than about 1/25 of the object's width. Match the hero's painted pixel hand and upper-left illumination, 3-5 tones per material, muted earthy grimy dark fantasy with warm candlelight as the only bright element. Never shiny, glossy, photographic, vector-smooth, cartoonish, cute or neon.
OUTPUT: Use the LARGEST supported portrait image size closest to the 5:9 native ratio. Centre the object enlarged, leaving about 6% clean margin on EACH side, nothing touching the image edges. The object's OWN bounding box must have EXACTLY 15:27 proportions independently of the canvas ratio.
Everywhere outside the lantern, including the ring opening, is a perfectly flat opaque chroma green #00FF00, RGB(0,255,0). No green gradient, texture, cast shadow, ground, glow spill or green reflections on the object. ONE lantern only. No hand, arm, character body, belt, background scene, text, label, frame or watermark. Generate ONLY this one image.
```

#### Blackened-iron correction — selected final

- Image-tool output pixel size for this pass: **935 × 1683**
- Supplied reference images, in order:
  1. `cracked_lantern_front_v2.png`
  2. `ref_hero_front.png`
- The `cracked_lantern_front_v2.png` input to this correction was the initial front V2 generation from `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-6d6ca46d-a02a-4b6e-b5cd-3b58a2adf467.png`.
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-fc1dd69e-0ebd-4742-93c0-82e1705ea079.png`

Exact prompt sent to the image tool:

```text
Use case: precise-object-edit.
Target: the supplied cracked_lantern_front_v2.png. Reference 2 ref_hero_front.png is the painted pixel-art style master.
Make ONE targeted correction: darken and desaturate EVERY structural metal component of this lantern into BLACKENED IRON. This includes ring, short top hook/attachment, entire cap, cage uprights, lower rails and entire base. Metal palette must be approximately near-black #0B0D10, charcoal #171B20, dark cool grey #292F35, with only a FEW small dull grey #444A50 upper-left highlights. Predominantly near-black, soot-black dark metal, matte and worn. Remove all tan, brown, beige, gold and brass metal coloration and all broad pale highlights; the frame must read as BLACK at first glance against brown leather. Keep the dark near-black silhouette outline.
Keep the front-view lantern identity, geometry and placement unchanged, with the same small ring handle and short top hook, large open glass panes, ONE visibly cracked pane and large connected warm amber/yellow-orange flame core. Preserve the strong bright golden-yellow central flame and luminous orange-amber panes exactly in spirit and size; do not dim the light. Bright flame core occupies about the centre third of the lantern. No external light spill. Maintain the hero's chunky hand-painted square-pixel style, 3-5 tones per material, upper-left lighting, native 15x27 detail density, no high-resolution grain, ornament or glossy shine.
ONE isolated lantern only. Final native object bounding-box ratio EXACTLY 15:27 (5:9), centered with about 6% margin on every side, nothing touching edges. Use the largest supported portrait output nearest to 5:9. Background everywhere outside the object and through the ring is perfectly flat opaque #00FF00 RGB(0,255,0), no cast shadow, no ground, no halo, no reflections or green light on object. No hand, arm, body, belt, text, label, frame or watermark. Generate only ONE image.
```

### cracked_lantern_rear_v2.png

- Output pixel size: **935 × 1683**
- Intended final native object size: **15 × 27** (aspect **15:27**, or **5:9**).
- Selected generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-ed28d520-d40b-4bf9-8237-31e391d2fd7a.png`

#### Rear V2 generation — selected final

- Image-tool output pixel size for this pass: **935 × 1683**
- Supplied reference images, in order:
  1. `cracked_lantern_front_v2.png`
  2. `ref_hero_front.png`
  3. `ref_hero_rear.png`
  4. `icon_cracked_lantern.png`
  5. `guide_cracked_lantern_rear.png`
- Generated source: `/Users/borgerding/.codex/generated_images/01a10e65-9342-75d0-a99f-3b957e1560f6/exec-ed28d520-d40b-4bf9-8237-31e391d2fd7a.png`

Exact prompt sent to the image tool:

```text
Use case: stylized-concept.
Asset: cracked_lantern_rear_v2.png, ONE isolated REAR-view Cracked Lantern equipment sprite for Escape the Umbra.
References in order:
1. cracked_lantern_front_v2.png is the NEW V2 LANTERN DESIGN MASTER. Render this same lantern from its opposite/rear side, with matching BLACKENED IRON structure and large bright amber/yellow-orange light. Keep its equipment identity, compact ring handle/short hook, cap, broad panes, cage and base coherent with this front version.
2. ref_hero_front.png is the mandatory hand-painted dark-fantasy PIXEL-ART style/artist master.
3. ref_hero_rear.png establishes the rear hero viewpoint and supports palette/style.
4. icon_cracked_lantern.png supplies recognizable Cracked Lantern identity only. New near-black iron palette and larger V2 light override its brass palette and small flame.
5. guide_cracked_lantern_rear.png shows the vertical belt-hanging orientation and rear-side perspective. Use it only for orientation; its old 12x21 size is superseded by the new 15x27 native size. Do not render hero, magenta area or yellow box.
SUBJECT: A small iron cage lantern, opposite/rear three-quarter view of image 1. Small ring handle and SHORT hook at the top; squat capped cage with broad glass panes and simple iron base. The ring, hook, cap, cage uprights, rails and base are BLACKENED IRON: predominantly soot-black/near-black #0B0D10 and charcoal #171B20, dark cool grey #292F35, only a FEW dull grey #444A50 upper-left highlights. Worn matte desaturated metal, slightly darker rear side. No tan, brown, beige, gold or brass metal. Its silhouette must read BLACK against the hero's brown leather.
The glass is LARGE and strongly luminous WARM AMBER, with thin dark uprights leaving a broad open bright centre. A connected bright YELLOW-ORANGE flame core occupies the CENTRE THIRD of the lantern, approximately 5 native pixels wide by 9 pixels tall. Keep this rear view's golden-yellow heart as instantly visible as the front view; do not reduce it to a tiny dot or dim smudge. One rear/side pane is visibly cracked with a SINGLE coarse diagonal crack, shifted to the opposite pane for the reverse view. Show the same lantern hardware from behind, with an opposite-side cage seam/upright and cap/base perspective subtly changed; do not simply duplicate the front view.
All light is confined INSIDE the glass/cage silhouette. No bloom, outward glow, light rays, sparks, exterior flames or green reflections. Dark metal remains dark and outlines the bright panes.
FINAL NATIVE OBJECT SIZE EXACTLY 15x27 pixels; object's OWN bounding-box ratio EXACTLY 15:27 = 5:9. Draw as an authentic 15-column by 27-row hand-painted pixel sprite enlarged, with chunky coarse square pixel clusters, hard stair-step near-black silhouette outline, 3-5 tones per material, no tiny ornament finer than about 1/25 of width, no high-resolution grain or smooth curves. Match the hero's grimy earthy dark-fantasy hand, upper-left lighting and readability. Warm amber candlelight is the only bright element. Never glossy, shiny, photographic, vector-smooth, cartoonish, cute or neon.
OUTPUT: ONE lantern only, no hand, arm, character body, belt, scene, text, label, frame or watermark. Use the LARGEST supported portrait size closest to 5:9. Center enlarged lantern with about 6% margin on EVERY side and nothing touching the image edges. Background EVERYWHERE outside lantern, including ring hole, is perfectly flat opaque chroma green #00FF00 RGB(0,255,0), no background texture, gradient, shadow, ground or glow spill. Generate only ONE image.
```
